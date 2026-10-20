# Preserved broken-crate prototype. Develop the replacement raft separately.
extends Node2D

const BACKGROUND = preload("res://assets/art/c_zone_debug/forest-panorama.png")
const Fan = preload("res://scripts/prototypes/c_zone_broken_crate/fan_art.gd")
const LIGHT = preload("res://assets/shaders/cinematic_light_cone.gdshader")
const SCREEN := Vector2(1280, 720)
const INK := Color("050606")

var level: Node2D
var clock := 0.0
var camera_x := 0.0
var background: Sprite2D
var mid: Node2D
var terrain: Node2D
var props: Node2D
var crate_art: Node2D
var surface: Node2D
var water_volume: Polygon2D
var water_impacts: Array[Dictionary] = []
var water_impact_count := 0
var foreground: Node2D
var atmosphere: ColorRect
var lens: ColorRect
var cone: ColorRect
var fan_pickup: Node2D
var mid_view: SubViewport
var fore_view: SubViewport

func _ready() -> void:
	var back_layer := CanvasLayer.new()
	back_layer.layer = -10
	add_child(back_layer)
	background = Sprite2D.new()
	background.centered = false
	background.texture = BACKGROUND
	background.scale = Vector2.ONE * 1.13
	background.position = Vector2(-90, -95)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var back_shader := Shader.new()
	back_shader.code = """shader_type canvas_item;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 2.5;
	vec4 c = texture(TEXTURE, UV) * 0.4;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.15;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.15;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.15;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.15;
	float v = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(v * 0.83 + 0.075), 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = back_shader
	background.material = mat
	back_layer.add_child(background)
	mid_view = _blur_layer(back_layer, 8.0)
	mid = Node2D.new()
	mid.draw.connect(_draw_mid)
	mid_view.add_child(mid)
	atmosphere = ColorRect.new()
	atmosphere.size = SCREEN
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.material = _atmosphere_material(false)
	back_layer.add_child(atmosphere)
	cone = ColorRect.new()
	cone.size = Vector2(950, 790)
	cone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light_material := ShaderMaterial.new()
	light_material.shader = LIGHT
	light_material.set_shader_parameter("intensity", 0.12)
	light_material.set_shader_parameter("light_tint", Vector3(0.70, 0.70, 0.70))
	cone.material = light_material
	back_layer.add_child(cone)
	terrain = Node2D.new()
	terrain.z_index = -2
	terrain.draw.connect(_draw_terrain)
	add_child(terrain)
	props = Node2D.new()
	props.z_index = 2
	props.draw.connect(_draw_props)
	add_child(props)
	crate_art = Node2D.new()
	crate_art.z_index = 2
	crate_art.draw.connect(_draw_crate)
	add_child(crate_art)
	_build_water_volume()
	fan_pickup = Fan.new()
	fan_pickup.position = level.FAN_SPOT + Vector2(0, -10)
	fan_pickup.rotation = 0.48
	fan_pickup.z_index = 1
	add_child(fan_pickup)
	surface = Node2D.new()
	surface.z_index = 9
	surface.draw.connect(_draw_surface)
	add_child(surface)
	var front_layer := CanvasLayer.new()
	front_layer.layer = 15
	add_child(front_layer)
	fore_view = _blur_layer(front_layer, 6.0)
	foreground = Node2D.new()
	foreground.draw.connect(_draw_foreground)
	fore_view.add_child(foreground)
	lens = ColorRect.new()
	lens.size = SCREEN
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens.material = _atmosphere_material(true)
	front_layer.add_child(lens)

func _build_water_volume() -> void:
	water_volume = Polygon2D.new()
	water_volume.z_index = 8
	water_volume.polygon = PackedVector2Array([Vector2(1156, 573), Vector2(2060, 573), Vector2(1880, 850), Vector2(1310, 850)])
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform float water_y = 575.0;
uniform float clock = 0.0;
varying vec2 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float wave = sin(world_position.x * 0.035 + clock * 1.6) * 0.55;
	float depth = world_position.y - water_y - wave;
	if (depth < 0.0) { discard; }
	float distortion = sin(world_position.y * 0.14 + clock * 2.1) * 0.85;
	distortion += sin(world_position.x * 0.07 - clock * 1.3) * 0.35;
	vec2 refract_uv = SCREEN_UV + vec2(distortion, 0.0) * SCREEN_PIXEL_SIZE * smoothstep(0.0, 16.0, depth);
	vec3 submerged = texture(scene_color, refract_uv).rgb;
	// Establish a visible wet silhouette just below the surface, then lose
	// contrast gradually with depth instead of retaining almost-black timber.
	float near_transmission = mix(0.94, 0.66, smoothstep(0.0, 12.0, depth));
	float transmission = near_transmission * exp(-max(depth, 0.0) / 110.0);
	vec3 water = mix(vec3(0.46), submerged, transmission);
	float reflection = (1.0 - smoothstep(0.0, 3.0, depth)) * 0.06;
	COLOR = vec4(mix(water, vec3(0.60), reflection), 1.0);
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	water_volume.material = material_value
	add_child(water_volume)

func reset_water_impacts() -> void:
	water_impacts.clear()
	water_impact_count = 0

func emit_water_impact(x: float, speed: float, spread: float) -> void:
	water_impacts.append({"x": x, "age": 0.0, "strength": clampf(0.42 + speed / 380.0, 0.42, 1.0), "spread": clampf(spread, 8.0, 52.0)})
	water_impact_count += 1
	if water_impacts.size() > 8:
		water_impacts.pop_front()

func _blur_layer(parent: Node, radius: float) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = viewport.get_texture()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float radius = 3.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * radius;
	vec4 c = texture(TEXTURE, UV) * 0.20;
	c += texture(TEXTURE, UV + vec2(px.x, 0)) * 0.12;
	c += texture(TEXTURE, UV - vec2(px.x, 0)) * 0.12;
	c += texture(TEXTURE, UV + vec2(0, px.y)) * 0.12;
	c += texture(TEXTURE, UV - vec2(0, px.y)) * 0.12;
	c += texture(TEXTURE, UV + px) * 0.08;
	c += texture(TEXTURE, UV - px) * 0.08;
	c += texture(TEXTURE, UV + vec2(px.x, -px.y)) * 0.08;
	c += texture(TEXTURE, UV + vec2(-px.x, px.y)) * 0.08;
	COLOR = c;
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("radius", radius)
	sprite.material = material_value
	parent.add_child(sprite)
	return viewport

func _atmosphere_material(is_lens: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float clock = 0.0;
uniform float scroll = 0.0;
uniform bool lens = false;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	if (lens) {
		float edge = smoothstep(0.30, 0.79, length((UV-0.5)*vec2(0.93,1.0)));
		float grain = hash(floor(UV*vec2(1280,720))+floor(clock*12.0));
		COLOR = vec4(vec3(0.0), edge * 0.34 + grain * 0.018);
	} else {
		float a = noise(UV*vec2(3.2,8.0)+vec2(clock*0.018+scroll*0.0001,0));
		float b = noise(UV*vec2(5.0,12.0)-vec2(clock*0.030,clock*0.008));
		float band = exp(-pow((UV.y-0.65)*4.4,2.0));
		COLOR = vec4(vec3(0.72), (a*0.65+b*0.35)*band*0.15);
	}
}"""
	var result := ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("lens", is_lens)
	return result

func sync(delta: float, new_camera: float, active: bool) -> void:
	visible = active
	clock += delta
	camera_x = new_camera
	background.position.x = -90.0 - camera_x * 0.10
	cone.position = Vector2(370.0 - camera_x * 0.22, -155)
	(cone.material as ShaderMaterial).set_shader_parameter("clock", clock)
	for plane in [atmosphere, lens]:
		(plane.material as ShaderMaterial).set_shader_parameter("clock", clock)
		(plane.material as ShaderMaterial).set_shader_parameter("scroll", camera_x)
	fan_pickup.visible = level.fan_revealed and not level.fan_owned
	crate_art.position = level.crate.position + level.CRATE_SIZE * 0.5
	crate_art.rotation = level.crate_tilt
	(water_volume.material as ShaderMaterial).set_shader_parameter("clock", clock)
	for i in range(water_impacts.size() - 1, -1, -1):
		water_impacts[i].age += delta
		if water_impacts[i].age > 1.6:
			water_impacts.remove_at(i)
	for plane in [mid, terrain, props, crate_art, surface, foreground]:
		plane.queue_redraw()

func _draw_mid() -> void:
	# These sparse trees move independently of the distant bitmap and playable bank.
	for spec in [Vector3(110, 95, 0.27), Vector3(1710, 56, 0.25), Vector3(2230, 120, 0.32)]:
		var x: float = spec.x - camera_x * 0.29
		var w: float = spec.y
		var c := Color(spec.z, spec.z, spec.z, 0.22)
		mid.draw_colored_polygon(PackedVector2Array([
			Vector2(x-w*0.4,-30),Vector2(x+w*0.5,-30),Vector2(x+w*0.3,330),
			Vector2(x+w*0.55,470),Vector2(x+w,555),Vector2(x-w,555),
			Vector2(x-w*0.5,470),Vector2(x-w*0.24,300)
		]), c)
		mid.draw_colored_polygon(PackedVector2Array([Vector2(x-5,229),Vector2(x+80,172),Vector2(x+180,140),Vector2(x+87,163),Vector2(x+3,207)]),c)

func _draw_terrain() -> void:
	terrain.draw_colored_polygon(level.LEFT_PROFILE, INK)
	terrain.draw_colored_polygon(level.RIGHT_PROFILE, INK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4721
	for i in range(255):
		var x := rng.randf_range(220.0, 2540.0)
		if x > 1250.0 and x < 1980.0:
			continue
		var y: float = level.ground_y(x)
		var height := rng.randf_range(3.0, 14.0)
		var lean := rng.randf_range(-7.0, 9.0) + sin(clock * 0.8 + i) * 1.0
		terrain.draw_colored_polygon(PackedVector2Array([
			Vector2(x-0.7,y+3),Vector2(x+lean,y-height),Vector2(x+0.8,y+3)
		]), INK)
		if i % 5 == 0:
			terrain.draw_circle(Vector2(x,y+2),rng.randf_range(2.0,5.0),INK,true,-1,true)

func _beam(canvas: Node2D, a: Vector2, b: Vector2, width: float, seed_value: float) -> void:
	var normal := (b-a).normalized().orthogonal() * width * 0.5
	var points := PackedVector2Array()
	for i in range(7):
		var t := float(i)/6.0
		points.append(a.lerp(b,t)+normal*(0.88+sin(i*2.7+seed_value)*0.15))
	for i in range(6,-1,-1):
		var t := float(i)/6.0
		points.append(a.lerp(b,t)-normal*(0.9+sin(i*1.8+seed_value)*0.17))
	canvas.draw_colored_polygon(points,INK)

func _draw_props() -> void:
	# Right upright is broken above the crate: the pull-out route stays open.
	_beam(props,Vector2(379,550),Vector2(369,403),10,2)
	_beam(props,Vector2(363,407),Vector2(555,416),11,1)
	_beam(props,Vector2(547,417),Vector2(550,447),7,8)
	_beam(props,Vector2(377,447),Vector2(414,410),6,3)
	if level.fan_swing > 0.0:
		var origin: Vector2 = level.player.position + Vector2(13,20)
		var progress: float = 1.0 - level.fan_swing / 0.48
		for i in range(4):
			var x: float = origin.x + level.facing * (25.0 + progress * 140.0 + i*14.0)
			var y := origin.y - 28.0 + i*16.0
			props.draw_line(Vector2(x,y),Vector2(x-level.facing*32.0,y+3),Color(0.9,0.9,0.9,(1.0-progress)*0.20),1.2,true)
	if level.completed:
		props.draw_circle(Vector2(2460,517),3.0,Color(0.76,0.76,0.76),true,-1,true)

func _draw_crate() -> void:
	crate_art.draw_set_transform(-level.CRATE_SIZE * 0.5)
	_beam(crate_art,Vector2(-3,91),Vector2(107,91),11,4)
	_beam(crate_art,Vector2(7,90),Vector2(5,1),10,6)
	_beam(crate_art,Vector2(93,91),Vector2(98,5),12,2)
	# The full load-bearing top matches the collider. Damage belongs below it,
	# not in an invisible gap in the surface where the player can stand.
	crate_art.draw_colored_polygon(PackedVector2Array([
		Vector2(0,0), Vector2(102,0), Vector2(105,5), Vector2(98,7),
		Vector2(102,11), Vector2(82,9), Vector2(67,12), Vector2(41,10),
		Vector2(18,12), Vector2(-2,8)
	]), INK)
	_beam(crate_art,Vector2(8,12),Vector2(93,82),12,4)
	_beam(crate_art,Vector2(9,68),Vector2(42,69),8,6)
	_beam(crate_art,Vector2(58,46),Vector2(94,43),8,8)
	_beam(crate_art,Vector2(23,90),Vector2(24,49),7,3)

func _draw_surface() -> void:
	for i in range(34):
		var x := 1180.0 + fposmod(i*73.79+clock*(1.6+float(i%3)),850.0)
		var y := 578.0+float(i%7)*11.0+sin(clock*0.6+i)*1.8
		var alpha := 0.025 + sin(clock*0.5+i)*0.012
		surface.draw_line(Vector2(x,y),Vector2(x+18.0+float(i%5)*8.0,y),Color(0.83,0.83,0.83,alpha),1.0,true)
	if level.floating:
		var span: Vector2 = level.crate_waterline_span()
		var center := Vector2((span.x + span.y) * 0.5, level.WATER_Y)
		for x in [span.x, span.y]:
			surface.draw_line(Vector2(x-9.0,level.WATER_Y),Vector2(x+11.0,level.WATER_Y),Color(0.74,0.74,0.74,0.20),1.2,true)
		for i in range(3):
			var phase := fposmod(clock*0.65+i/3.0,1.0)
			surface.draw_set_transform(Vector2(center.x,579.0),0.0,Vector2(1.0,0.13))
			surface.draw_arc(Vector2.ZERO,55.0+phase*52.0,0,TAU,40,Color(0.74,0.74,0.74,(1.0-phase)*0.14),1.7,true)
			surface.draw_set_transform(Vector2.ZERO)
	for impact in water_impacts:
		_draw_water_impact(impact)

func _draw_water_impact(impact: Dictionary) -> void:
	var t: float = impact.age
	var strength: float = impact.strength
	var origin := Vector2(impact.x, level.WATER_Y)
	# Short displaced-water lobes, then ballistic droplets and expanding ripples.
	if t < 0.30:
		var height := sin(t / 0.30 * PI) * 19.0 * strength
		for side in [-1.0, 1.0]:
			var base := origin + Vector2(side * impact.spread, 0)
			var points := PackedVector2Array([base + Vector2(-9, 1), base + Vector2(side*8, -height), base + Vector2(side*16, -height*0.6), base + Vector2(side*22, 1)])
			surface.draw_colored_polygon(points, Color(0.65,0.65,0.65,(1.0-t/0.30)*0.48))
	for i in 22:
		var side := -1.0 if i % 2 == 0 else 1.0
		var vx := side * (20.0 + fposmod(i * 17.7, 67.0)) * strength
		var vy := -(60.0 + fposmod(i * 29.3, 90.0)) * strength
		var point := origin + Vector2(side * impact.spread * 0.45 + vx * t, vy * t + 180.0 * t * t)
		if point.y > level.WATER_Y or t > 0.9:
			continue
		var alpha := (1.0-t/0.9) * 0.64
		var tail := Vector2(vx, vy + 360.0*t).normalized() * (1.5 + strength*2.0)
		# Slightly offset dark mass keeps spray readable against bright mist.
		surface.draw_line(point+Vector2(0,0.7),point-tail+Vector2(0,0.7),Color(0.16,0.16,0.16,alpha*0.5),2.2,true)
		surface.draw_line(point,point-tail,Color(0.79,0.79,0.79,alpha),1.3,true)
	for i in 2:
		var age := t - i * 0.12
		if age < 0.0:
			continue
		surface.draw_set_transform(origin + Vector2(0,2),0,Vector2(1,0.14))
		surface.draw_arc(Vector2.ZERO,impact.spread+age*70.0,0,TAU,48,Color(0.70,0.70,0.70,maxf(0.0,1.0-age/1.6)*0.30),1.4,true)
		surface.draw_set_transform(Vector2.ZERO)

func _draw_foreground() -> void:
	var x := -70.0 - camera_x*1.10
	if x > -260.0:
		foreground.draw_colored_polygon(PackedVector2Array([Vector2(x-40,-30),Vector2(x+116,-30),Vector2(x+96,150),Vector2(x+55,345),Vector2(x+35,540),Vector2(x-25,590)]),Color("090a0a"))
		foreground.draw_polyline(PackedVector2Array([Vector2(x+70,140),Vector2(x+176,85),Vector2(x+264,52)]),Color("090a0a"),28,true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for i in range(90):
		var wx := rng.randf_range(-150.0,3150.0)
		var sx := wx-camera_x*1.14
		if sx < -60.0 or sx > 1340.0:
			continue
		var height := rng.randf_range(20.0,85.0)
		var lean := rng.randf_range(-38.0,38.0)+sin(clock*0.35+i)*2.0
		var width := rng.randf_range(2.0,4.0)
		foreground.draw_colored_polygon(PackedVector2Array([Vector2(sx-width,744),Vector2(sx+lean,744-height),Vector2(sx+width,744)]),Color(0.012,0.014,0.014,0.85))
	for i in range(12):
		var age := fposmod(clock*0.019+i*0.117,1.0)
		var mote := Vector2(fposmod(i*137.0-camera_x*0.40+age*30.0,1280.0),580-age*420.0)
		foreground.draw_circle(mote,0.7,Color(0.88,0.88,0.88,sin(age*PI)*0.13),true,-1,true)
