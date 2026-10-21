extends Node2D

const BACKGROUND = preload("res://assets/art/c_zone_debug/forest-panorama.png")
const Fan = preload("res://scripts/demos/c_zone_debug/fan_art.gd")
const CrookedTree = preload("res://scripts/demos/c_zone_debug/crooked_tree_art.gd")
const LIGHT = preload("res://assets/shaders/cinematic_light_cone.gdshader")
const SCREEN := Vector2(1280, 720)
const ActorStyleHostRef = preload("res://scripts/actors/actor_style_host.gd")
const PoseRef = preload("res://scripts/actors/actor_pose_state.gd")
const INK := Color("050606")

var level: Node2D
var clock := 0.0
var camera_x := 0.0
var background: Sprite2D
var mid: Node2D
var terrain: Node2D
var props: Node2D
var crate_art: Node2D
var raft_front: Node2D
var bank_grass: Node2D
var surface: Node2D
var water_volume: Polygon2D
var water_impacts: Array[Dictionary] = []
var water_impact_count := 0
# The water surface is a row of columns (one every WAVE_DX px) that obeys a damped wave equation: whatever disturbs the water
# (a body falling in, the raft's bow, a stroke of the drowning boy) pushes the columns, and the swell runs outwards, rocks the
# raft and fades by itself. The shader draws it, the raft reads it (wave_at / wave_slope_between).
const WAVE_X0 := 1100.0
const WAVE_DX := 4.0
const WAVE_N := 264
const WAVE_SPEED := 150.0  # px/s: how fast a swell travels
const WAVE_DAMP := 1.9  # 1/s: the swell loses about half its height every 0.75 s
const WAVE_LEAK := 1.3  # 1/s
const WAVE_MAX := 15.0  # px
var wave_h := PackedFloat32Array()
var wave_v := PackedFloat32Array()
var wave_damp := PackedFloat32Array()
var wave_kicks: Array[Dictionary] = []
var wave_texture: ImageTexture
var wave_energy := 0.0
const WAKE_BOW := 1.1  # px/s of swell added per second per px/s of the raft's speed
const HULL_PRESS := 1.5
const HULL_TIP := 120.0
const WADE_PUSH := 1.2
var ground_dust: Array[Dictionary] = []
var dust_layer: Node2D
var dust_texture: GradientTexture2D
var dust_gap := 0.0
var spray_rng := RandomNumberGenerator.new()
var foreground: Node2D
var atmosphere: ColorRect
var lens: ColorRect
var cone: ColorRect
var cone_act_two: ColorRect
var fan_pickup: Node2D
var mid_view: SubViewport
var fore_view: SubViewport
var mid_blur_sprite: Sprite2D
var fore_blur_sprite: Sprite2D
var bank_noise := FastNoiseLite.new()

func _ready() -> void:
	bank_noise.seed = 6317
	bank_noise.frequency = 0.018
	bank_noise.fractal_octaves = 3
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
	// A real 5x5 gaussian (sigma about 1.3 texels). The earlier 5-tap cross left four shifted
	// copies of every hard edge, which showed up as stepped bands beside the trunks.
	vec4 c = vec4(0.0);
	float total = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			float w = exp(-float(x * x + y * y) / 3.4);
			c += texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE) * w;
			total += w;
		}
	}
	c /= total;
	float v = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(v * 0.83 + 0.075), 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = back_shader
	background.material = mat
	back_layer.add_child(background)
	mid_view = _blur_layer(back_layer, 8.0)
	mid_blur_sprite = mid_view.get_meta(&"output_sprite") as Sprite2D
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
	# The same dim window of light returns over the marsh, so the backdrop keeps one mood.
	cone_act_two = ColorRect.new()
	cone_act_two.size = Vector2(950, 790)
	cone_act_two.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var light_two := ShaderMaterial.new()
	light_two.shader = LIGHT
	light_two.set_shader_parameter("intensity", 0.12)
	light_two.set_shader_parameter("seed", 0.37)
	light_two.set_shader_parameter("light_tint", Vector3(0.70, 0.70, 0.70))
	cone_act_two.material = light_two
	back_layer.add_child(cone_act_two)
	terrain = Node2D.new()
	terrain.z_index = -2
	terrain.draw.connect(_draw_terrain)
	add_child(terrain)
	props = Node2D.new()
	props.z_index = 2
	props.draw.connect(_draw_props)
	add_child(props)
	var tree := CrookedTree.new()
	tree.position = Vector2(190,520)
	tree.z_index = 2
	add_child(tree)
	crate_art = Node2D.new()
	crate_art.z_index = 2
	crate_art.draw.connect(_draw_crate)
	add_child(crate_art)
	raft_front = Node2D.new()
	raft_front.z_index = 7
	raft_front.draw.connect(_draw_raft_front)
	add_child(raft_front)
	dust_texture = _soft_texture()
	dust_layer = Node2D.new()
	dust_layer.z_index = 8
	dust_layer.draw.connect(_draw_ground_dust)
	add_child(dust_layer)
	bank_grass = Node2D.new()
	bank_grass.z_index = 7
	bank_grass.draw.connect(_draw_bank_grass)
	add_child(bank_grass)
	_build_water_volume()
	fan_pickup = Fan.new()
	fan_pickup.position = level.FAN_SPOT + Vector2(0, -10)
	fan_pickup.rotation = 0.48
	fan_pickup.z_index = 1
	add_child(fan_pickup)
	surface = Node2D.new()
	surface.z_index = 9
	surface.draw.connect(_draw_surface)
	var shore_clip := Shader.new()
	shore_clip.code = """shader_type canvas_item;
uniform sampler2D bank_height : repeat_disable, filter_linear;
varying vec2 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	float bed = texture(bank_height,vec2(((world_position.x+120.0)/4.0+0.5)/706.0,0.5)).r*1024.0;
	if (world_position.y >= bed) { discard; }
}
"""
	var shore_material := ShaderMaterial.new()
	shore_material.shader = shore_clip
	shore_material.set_shader_parameter("bank_height",water_volume.material.get_shader_parameter("bank_height"))
	surface.material = shore_material
	add_child(surface)
	var front_layer := CanvasLayer.new()
	front_layer.layer = 15
	add_child(front_layer)
	fore_view = _blur_layer(front_layer, 6.0)
	fore_blur_sprite = fore_view.get_meta(&"output_sprite") as Sprite2D
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
	# The shader uses the same sampled contour as the visible soil, never a shore fog mask.
	water_volume.polygon = PackedVector2Array([Vector2(-120,573),Vector2(2700,573),Vector2(2700,900),Vector2(-120,900)])
	var heights := Image.create(706,1,false,Image.FORMAT_RF)
	for i in heights.get_width():
		heights.set_pixel(i,0,Color(_bank_edge_y(-120.0+i*4.0)/1024.0,0,0,1))
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D bank_height : repeat_disable, filter_linear;
uniform sampler2D waves : repeat_disable, filter_linear;
uniform float wave_x0 = 1100.0;
uniform float wave_dx = 4.0;
uniform float wave_n = 264.0;
uniform float water_y = 575.0;
uniform float clock = 0.0;
varying vec2 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 wave_uv = vec2(((world_position.x - wave_x0) / wave_dx + 0.5) / wave_n, 0.5);
	float swell = texture(waves, wave_uv).r;
	float swell_slope = (texture(waves, wave_uv + vec2(1.0 / wave_n, 0.0)).r - texture(waves, wave_uv - vec2(1.0 / wave_n, 0.0)).r) / (2.0 * wave_dx);
	float wave = sin(world_position.x * 0.035 + clock * 1.6) * 0.55 - swell;
	float depth = world_position.y - water_y - wave;
	if (depth < 0.0) { discard; }
	float bed = texture(bank_height,vec2(((world_position.x+120.0)/4.0+0.5)/706.0,0.5)).r * 1024.0;
	float clearance = bed - world_position.y;
	if (clearance <= 0.0) { discard; }
	float edge_aa = smoothstep(0.0, max(fwidth(world_position.y),0.5), clearance);
	float distortion = sin(world_position.y * 0.14 + clock * 2.1) * 0.35;
	distortion += sin(world_position.x * 0.07 - clock * 1.3) * 0.15;
	distortion *= smoothstep(0.0,4.0,clearance);
	// a moving swell bends what is seen through it, most near the top
	vec2 bend = vec2(distortion + swell_slope * 30.0 * exp(-depth / 40.0), swell_slope * 7.0 * exp(-depth / 25.0));
	vec2 refract_uv = SCREEN_UV + bend * SCREEN_PIXEL_SIZE * smoothstep(0.0, 16.0, depth);
	vec3 submerged = texture(scene_color, refract_uv).rgb;
	// Retain sharp submerged silhouettes; no blur or rapid milky depth extinction.
	float transmission = mix(0.90,0.60,smoothstep(0.0,12.0,depth));
	float water_tone = mix(0.47,0.29,smoothstep(0.0,260.0,depth));
	vec3 water = mix(vec3(water_tone), submerged * 0.82, transmission);
	float world_pixel = SCREEN_PIXEL_SIZE.y / max(fwidth(world_position.y),0.001);
	vec2 reflected_uv = vec2(refract_uv.x,SCREEN_UV.y-(depth*2.0+wave)*world_pixel);
	vec3 reflected = texture(scene_color,clamp(reflected_uv,vec2(0.0),vec2(1.0))).rgb;
	water = mix(water,reflected,0.07*exp(-depth/65.0));
	float surface_band = (1.0-smoothstep(0.0,2.4,depth)) * (0.08+0.03*sin(world_position.x*0.019+clock*0.6));
	surface_band *= 1.0 + abs(swell_slope) * 7.0 + abs(swell) * 0.12;
	water = mix(water,vec3(0.63),clamp(surface_band,0.0,0.7));
	// the faces of a swell catch the light just under the surface
	float glint = clamp(abs(swell_slope) * 2.4, 0.0, 0.45) * (1.0 - smoothstep(0.0, 9.0, depth));
	water += vec3(0.22) * glint;
	COLOR = vec4(water,edge_aa);
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("bank_height",ImageTexture.create_from_image(heights))
	_init_waves()
	material_value.set_shader_parameter("waves", wave_texture)
	water_volume.material = material_value
	add_child(water_volume)

func _init_waves() -> void:
	wave_h.resize(WAVE_N)
	wave_v.resize(WAVE_N)
	wave_damp.resize(WAVE_N)
	for i in WAVE_N:
		var x := WAVE_X0 + i * WAVE_DX
		# the banks soak the swell up (it does not bounce back off the mud like off a wall)
		var shore := minf(absf(x - 1156.0), absf(x - 2060.0))
		var outside := 1.0 if (x < 1156.0 or x > 2060.0) else 0.0
		wave_damp[i] = WAVE_DAMP + 5.0 * (1.0 - smoothstep(0.0, 70.0, shore)) + 8.0 * outside
	wave_texture = ImageTexture.create_from_image(Image.create_from_data(WAVE_N, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))

func reset_water_impacts() -> void:
	_clear_waves()
	water_impacts.clear()
	ground_dust.clear()
	gust_age = -1.0
	gust_leaves.clear()
	gust_ripples.clear()
	dust_gap = 0.0
	water_impact_count = 0

func _clear_waves() -> void:
	for i in wave_h.size():
		wave_h[i] = 0.0
		wave_v[i] = 0.0
	wave_kicks.clear()
	wave_energy = 0.0

# Push the water at x: `impulse` is a speed in px/s (positive lifts it, negative presses it down), `width` the half width in px.
func disturb(x: float, impulse: float, width: float) -> void:
	if wave_v.is_empty():
		return
	var centre := (x - WAVE_X0) / WAVE_DX
	var reach := int(ceil(width * 2.2 / WAVE_DX))
	for i in range(maxi(1, int(centre) - reach), mini(WAVE_N - 1, int(centre) + reach + 1)):
		var d := (float(i) - centre) * WAVE_DX / width
		wave_v[i] += impulse * exp(-d * d)

func disturb_later(x: float, impulse: float, width: float, delay: float) -> void:
	wave_kicks.append({"x": x, "impulse": impulse, "width": width, "delay": delay})

# The surface height at x in px (positive = above the still level), the swell only.
func wave_at(x: float) -> float:
	if wave_h.is_empty():
		return 0.0
	var f := clampf((x - WAVE_X0) / WAVE_DX, 0.0, WAVE_N - 1.001)
	var i := int(f)
	return lerpf(wave_h[i], wave_h[i + 1], f - float(i))

func wave_slope_between(x0: float, x1: float) -> float:
	if absf(x1 - x0) < 1.0:
		return 0.0
	return (wave_at(x1) - wave_at(x0)) / (x1 - x0)

func _update_waves(delta: float) -> void:
	if wave_h.is_empty():
		return
	for k in range(wave_kicks.size() - 1, -1, -1):
		wave_kicks[k].delay = float(wave_kicks[k].delay) - delta
		if float(wave_kicks[k].delay) <= 0.0:
			disturb(float(wave_kicks[k].x), float(wave_kicks[k].impulse), float(wave_kicks[k].width))
			wave_kicks.remove_at(k)
	var steps := clampi(int(ceil(delta * 120.0)), 1, 5)
	var dt := minf(delta, 0.05) / float(steps)
	var c2 := WAVE_SPEED * WAVE_SPEED / (WAVE_DX * WAVE_DX)
	var energy := 0.0
	for step in steps:
		for i in range(1, WAVE_N - 1):
			var accel := c2 * (wave_h[i - 1] + wave_h[i + 1] - 2.0 * wave_h[i]) - wave_damp[i] * wave_v[i]
			wave_v[i] += accel * dt
		for i in range(1, WAVE_N - 1):
			# (the water level also settles by itself: without this a displaced volume would only spread out, never go away)
			wave_h[i] = clampf((wave_h[i] + wave_v[i] * dt) * (1.0 - WAVE_LEAK * dt), -WAVE_MAX, WAVE_MAX)
	for i in WAVE_N:
		energy += absf(wave_h[i])
	wave_energy = energy
	wave_texture.update(Image.create_from_data(WAVE_N, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))

# The raft on the water, every frame: the bow pushes a swell ahead, the stern leaves a trough that follows, the hull sinking
# (`press`, px/s downwards) or tipping (`tip`, rad/s) shoves the water under it outwards.
func raft_waves(centre_x: float, half_width: float, vx: float, press: float, tip: float, delta: float) -> void:
	var speed := absf(vx)
	if speed > 3.0:
		var dir := signf(vx)
		disturb(centre_x + dir * half_width * 0.95, WAKE_BOW * speed * delta, 13.0)
		disturb(centre_x - dir * half_width * 0.95, -WAKE_BOW * 0.6 * speed * delta, 15.0)
	if absf(press) > 2.0:
		disturb(centre_x, -press * HULL_PRESS * delta, half_width * 0.6)
	if absf(tip) > 0.02:
		disturb(centre_x + half_width * 0.8, tip * HULL_TIP * delta, 14.0)
		disturb(centre_x - half_width * 0.8, -tip * HULL_TIP * delta, 14.0)

# The boy wading: a little slap at his feet with every stride.
func wade_waves(x: float, vx: float, delta: float) -> void:
	disturb(x, -absf(vx) * WADE_PUSH * delta, 8.0)

# Where the surface really is at x (the still level plus the swell): ripples, foam and the raft's waterline sit on it.
func water_line(x: float) -> float:
	return level.WATER_Y - wave_at(x)

func _soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.62, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

# Dust kicked up where the dragged raft's bottom scrapes the ground: puffs that rise and thin out,
# and a few flecks of grit. `moved` is how far the raft travelled this frame (signed).
func emit_drag_dust(contacts: Array, moved: float) -> void:
	dust_gap += absf(moved)
	var direction := signf(moved)
	while dust_gap >= 4.0:
		dust_gap -= 4.0
		for contact in contacts:
			var at: Vector2 = contact
			# The leading end shoves a heap of earth ahead of it; the trailing end drops what it dragged.
			var leading: bool = signf(at.x - level.crate.position.x - level.CRATE_SIZE.x * 0.5) == direction
			var count := 1 if leading else 2
			for k in range(count):
				ground_dust.append({
					"pos": at + Vector2(spray_rng.randf_range(-9.0, 9.0), spray_rng.randf_range(-3.0, 0.0)),
					"vel": Vector2(-direction * spray_rng.randf_range(8.0, 46.0) + (direction * 14.0 if leading else 0.0), -spray_rng.randf_range(14.0, 50.0)),
					"age": 0.0, "life": spray_rng.randf_range(0.7, 1.35), "size": spray_rng.randf_range(13.0, 28.0), "grit": false,
				})
			if spray_rng.randf() < 0.45:
				ground_dust.append({
					"pos": at + Vector2(spray_rng.randf_range(-6.0, 6.0), -2.0),
					"vel": Vector2(-direction * spray_rng.randf_range(20.0, 90.0), -spray_rng.randf_range(55.0, 130.0)),
					"age": 0.0, "life": spray_rng.randf_range(0.35, 0.65), "size": spray_rng.randf_range(0.9, 1.9), "grit": true,
				})
	while ground_dust.size() > 140:
		ground_dust.pop_front()

# The wind of a fan stroke is not drawn as marks. What shows it is what it moves: the grass of the bank leans away from
# the stroke in a wave that runs ahead and eases back, a few dead leaves are picked up and tumble along, the water
# crinkles where the gust passes over it, and a very faint shove of mist travels in front.
const GUST_SPEED := 380.0
const GUST_DRAG := 1.6
const GUST_LIFE := 1.6
var gust_age := -1.0  # < 0: no gust
var gust_origin := Vector2.ZERO
var gust_dir := 1.0
var gust_leaves: Array[Dictionary] = []
var gust_ripples: Array[Dictionary] = []
var gust_ripple_gap := 0.0

func emit_gust(origin: Vector2, direction: float) -> void:
	gust_age = 0.0
	gust_origin = origin
	gust_dir = direction
	gust_ripple_gap = 0.0
	for i in 8:
		var ahead := spray_rng.randf_range(10.0, 190.0)
		gust_leaves.append({
			"pos": Vector2(origin.x + direction * ahead, origin.y + spray_rng.randf_range(10.0, 40.0)),
			"vel": Vector2(direction * spray_rng.randf_range(110.0, 230.0), -spray_rng.randf_range(40.0, 150.0)),
			"delay": ahead / GUST_SPEED * 0.8, "age": 0.0, "life": spray_rng.randf_range(1.0, 1.7),
			"angle": spray_rng.randf() * TAU, "spin": spray_rng.randf_range(-7.0, 7.0), "flip": spray_rng.randf() * TAU,
			"flip_speed": spray_rng.randf_range(4.0, 9.0), "size": spray_rng.randf_range(4.0, 7.5),
		})

func _gust_reach() -> float:
	return GUST_SPEED / GUST_DRAG * (1.0 - exp(-GUST_DRAG * maxf(gust_age, 0.0)))

# How far the grass at this world x leans (px at the tip of a tall blade, signed).
func gust_lean(world_x: float) -> float:
	if gust_age < 0.0:
		return 0.0
	var t := gust_age / GUST_LIFE
	if t >= 1.0:
		return 0.0
	var ahead := (world_x - gust_origin.x) * gust_dir
	if ahead < -20.0:
		return 0.0
	var reach := _gust_reach()
	var shape := exp(-pow((ahead - reach) / 80.0, 2.0)) if ahead > reach else exp(-(reach - ahead) / 170.0)
	var amplitude := 26.0 * (1.0 - t) * smoothstep(-20.0, 30.0, ahead)
	# after the front has gone by, the blades spring back and forth once or twice
	var passed := maxf(reach - ahead, 0.0)
	var wobble := sin(passed * 0.045 - gust_age * 13.0) * 0.28 * smoothstep(0.0, 40.0, passed)
	return gust_dir * amplitude * shape * (1.0 + wobble)

func _update_gust(delta: float) -> void:
	if gust_age >= 0.0:
		gust_age += delta
		if gust_age >= GUST_LIFE:
			gust_age = -1.0
		else:
			# the water crinkles under the front while it is over the river
			var front_x := gust_origin.x + gust_dir * _gust_reach()
			gust_ripple_gap -= delta
			if gust_ripple_gap <= 0.0 and front_x > 1156.0 and front_x < 2060.0 and gust_age < 1.0:
				gust_ripple_gap = 0.07
				gust_ripples.append({"x": front_x + spray_rng.randf_range(-20.0, 20.0), "age": 0.0, "size": spray_rng.randf_range(0.8, 1.3)})
	for k in range(gust_ripples.size() - 1, -1, -1):
		gust_ripples[k].age = float(gust_ripples[k].age) + delta
		if float(gust_ripples[k].age) > 1.2:
			gust_ripples.remove_at(k)
	for k in range(gust_leaves.size() - 1, -1, -1):
		var leaf: Dictionary = gust_leaves[k]
		if float(leaf.delay) > 0.0:
			leaf.delay = float(leaf.delay) - delta
			continue
		leaf.age = float(leaf.age) + delta
		var v: Vector2 = leaf.vel
		v.x *= exp(-1.3 * delta)
		# a leaf in a gust rides it up, then flutters down
		v.y += (260.0 * delta) * (1.0 if float(leaf.age) > 0.35 else 0.12)
		v.y += sin(float(leaf.age) * 9.0 + float(leaf.flip)) * 120.0 * delta
		leaf.vel = v
		leaf.pos = Vector2(leaf.pos) + v * delta
		leaf.angle = float(leaf.angle) + float(leaf.spin) * delta
		leaf.flip = float(leaf.flip) + float(leaf.flip_speed) * delta
		if float(leaf.age) >= float(leaf.life) or Vector2(leaf.pos).y > level.ground_y(Vector2(leaf.pos).x) - 1.0 and float(leaf.age) > 0.5:
			gust_leaves.remove_at(k)

func _draw_gust() -> void:
	# a very faint shove of mist in front of the stroke
	if gust_age >= 0.0:
		var reach := _gust_reach()
		var t := gust_age / GUST_LIFE
		var centre := Vector2(gust_origin.x + gust_dir * (reach + 20.0), gust_origin.y - 10.0)
		var size := Vector2(70.0 + reach * 0.25, 70.0 + reach * 0.2)
		dust_layer.draw_texture_rect(dust_texture, Rect2(centre - size * 0.5, size), false, Color(0.5, 0.51, 0.49, smoothstep(0.0, 0.1, t) * (1.0 - t) * 0.09))
	for leaf in gust_leaves:
		if float(leaf.delay) > 0.0:
			continue
		var t: float = float(leaf.age) / float(leaf.life)
		var length: float = float(leaf.size)
		var flat := 0.2 + 0.8 * absf(cos(float(leaf.flip)))
		var width := length * 0.42 * flat
		var c := cos(float(leaf.angle))
		var s := sin(float(leaf.angle))
		var shape := [Vector2(-length, 0.0), Vector2(-length * 0.35, -width), Vector2(length * 0.55, -width * 0.8), Vector2(length, 0.0), Vector2(length * 0.4, width * 0.9), Vector2(-length * 0.5, width * 0.7)]
		var points := PackedVector2Array()
		for point in shape:
			var p: Vector2 = point
			points.append(Vector2(leaf.pos) + Vector2(p.x * c - p.y * s, p.x * s + p.y * c))
		dust_layer.draw_colored_polygon(points, Color(0.06, 0.065, 0.06, minf(1.0, (1.0 - t) * 3.0) * 0.85))

func _update_ground_dust(delta: float) -> void:
	_update_gust(delta)
	for k in range(ground_dust.size() - 1, -1, -1):
		var d: Dictionary = ground_dust[k]
		d.age = float(d.age) + delta
		var v: Vector2 = d.vel
		if bool(d.grit):
			v.y += 420.0 * delta
		else:
			v = v.move_toward(Vector2(v.x * 0.3, -9.0), 120.0 * delta)
		d.vel = v
		d.pos = Vector2(d.pos) + v * delta
		if float(d.age) >= float(d.life):
			ground_dust.remove_at(k)

func _draw_ground_dust() -> void:
	_draw_gust()
	for d in ground_dust:
		var t: float = float(d.age) / float(d.life)
		if bool(d.grit):
			dust_layer.draw_circle(d.pos, float(d.size), Color(0.03, 0.03, 0.03, (1.0 - t) * 0.9), true, -1.0, true)
		else:
			var size: float = float(d.size) * (1.0 + t * 1.6)
			var alpha := minf(1.0, t * 8.0) * (1.0 - t) * 0.5
			dust_layer.draw_texture_rect(dust_texture, Rect2(Vector2(d.pos) - Vector2(size * 1.3, size) * 0.5, Vector2(size * 1.3, size)), false, Color(0.47, 0.47, 0.45, alpha))

func emit_water_impact(x: float, speed: float, spread: float, rings: bool = true) -> void:
	var strength := clampf(0.42 + speed / 380.0, 0.42, 1.0)
	water_impacts.append({"x": x, "age": 0.0, "strength": strength, "spread": clampf(spread, 8.0, 52.0), "rings": rings})
	# the water is pressed down where it was hit, springs back as a short column a moment later, and the swell runs out both ways
	var width := clampf(spread * 0.55 + 5.0, 8.0, 30.0)
	var push := 30.0 + 66.0 * strength
	disturb(x, -push, width)
	disturb_later(x, push * 0.62, width * 0.7, 0.17)
	disturb_later(x, -push * 0.28, width * 0.9, 0.42)
	water_impact_count += 1
	if water_impacts.size() > 8:
		water_impacts.pop_front()

func emit_struggle_splash(x: float, side: float) -> void:
	var drops: Array[Dictionary] = []
	# Sample once per stroke, so each drop follows a stable ballistic path.
	for i in spray_rng.randi_range(15, 23):
		var direction := side if spray_rng.randf() < 0.78 else -side
		drops.append({
			"offset": Vector2(direction * spray_rng.randf_range(9.0, 23.0), -1.0),
			"velocity": Vector2(direction * spray_rng.randf_range(22.0, 105.0), -spray_rng.randf_range(80.0, 215.0)),
			"delay": spray_rng.randf_range(0.0, 0.055),
			"radius": spray_rng.randf_range(0.55, 1.6),
			"shade": spray_rng.randf_range(0.48, 0.79),
		})
	water_impacts.append({"age": 0.0, "x": x, "drops": drops})
	# every stroke of the drowning boy slaps the water and sets it rocking
	disturb(x + side * 14.0, -46.0, 11.0)
	disturb_later(x + side * 14.0, 30.0, 9.0, 0.12)
	if water_impacts.size() > 8:
		water_impacts.pop_front()

const BLUR_SHADER := """shader_type canvas_item;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float sigma = 4.0;
void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * direction;
	vec4 sum = vec4(0.0);
	float total = 0.0;
	for (int i = -8; i <= 8; i++) {
		float d = float(i) * sigma * 0.4;
		float w = exp(-0.5 * (d * d) / (sigma * sigma));
		sum += texture(TEXTURE, UV + step_uv * d) * w;
		total += w;
	}
	COLOR = sum / total;
}"""

func _blur_material(direction: Vector2, sigma: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("direction", direction)
	material_value.set_shader_parameter("sigma", sigma)
	return material_value

func _transparent_view() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	return viewport

# Two separable gaussian passes. The old single 9-tap blur laid nine shifted copies of each edge
# over each other, which read as stepped bands and ghost lines instead of a soft, clean edge.
func _blur_layer(parent: Node, radius: float) -> SubViewport:
	var viewport := _transparent_view()
	var horizontal := _transparent_view()
	var first := Sprite2D.new()
	first.centered = false
	first.texture = viewport.get_texture()
	first.material = _blur_material(Vector2(1.0, 0.0), radius * 0.5)
	horizontal.add_child(first)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = horizontal.get_texture()
	sprite.material = _blur_material(Vector2(0.0, 1.0), radius * 0.5)
	parent.add_child(sprite)
	viewport.set_meta(&"output_sprite", sprite)
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
	# Act one's planes never switch off: the backdrop must flow into act two without a seam.
	var first_act_world_animated := camera_x < 2180.0
	water_volume.visible = camera_x < 2750.0
	background.position.x = -90.0 - camera_x * 0.10
	cone.position = Vector2(370.0 - camera_x * 0.22, -155)
	cone_act_two.position = Vector2(370.0 + (3900.0 - camera_x) * 0.22, -155)
	cone_act_two.modulate.a = smoothstep(2000.0, 3000.0, camera_x)
	cone_act_two.visible = cone_act_two.modulate.a > 0.01
	(cone.material as ShaderMaterial).set_shader_parameter("clock", clock)
	(cone_act_two.material as ShaderMaterial).set_shader_parameter("clock", clock)
	for plane in [atmosphere, lens]:
		(plane.material as ShaderMaterial).set_shader_parameter("clock", clock)
		(plane.material as ShaderMaterial).set_shader_parameter("scroll", camera_x)
	fan_pickup.visible = level.fan_revealed and not level.fan_owned
	fan_pickup.position = level.fan_rest_position()
	fan_pickup.scale = Vector2(level.fan_ground_facing,1.0)*level.FAN_SCALE
	fan_pickup.rotation = level.fan_ground_facing*1.35 + (level.crate_tilt if level.fan_on_raft else 0.0)
	if ActorStyleHostRef.style_override == PoseRef.STYLE_HOOD and not level.fan_on_tree:
		# Lying on the ground the blade is seen from the side, almost edge-on: a thin leaf resting on the surface, not
		# the whole face-on blade stuck on the ground (which covered the soil like a sticker).
		fan_pickup.rotation = level.fan_ground_facing*1.50 + (level.crate_tilt if level.fan_on_raft else 0.0)
		fan_pickup.scale = Vector2(level.fan_ground_facing*0.17,1.0)*level.FAN_SCALE
	if level.fan_on_tree:
		fan_pickup.scale = Vector2.ONE*level.FAN_SCALE
		fan_pickup.rotation = -0.75
	crate_art.position = level.crate.position + level.CRATE_SIZE * 0.5
	crate_art.rotation = level.crate_tilt
	raft_front.transform = crate_art.transform
	(water_volume.material as ShaderMaterial).set_shader_parameter("clock", clock)
	_update_waves(delta)
	for i in range(water_impacts.size() - 1, -1, -1):
		water_impacts[i].age += delta
		if water_impacts[i].age > 2.4:
			water_impacts.remove_at(i)
	_update_ground_dust(delta)
	dust_layer.queue_redraw()
	mid.queue_redraw()
	foreground.queue_redraw()
	if first_act_world_animated:
		for plane in [terrain, props, crate_art, raft_front, bank_grass, surface]:
			plane.queue_redraw()

func _draw_mid() -> void:
	# These sparse trees move independently of the distant bitmap and playable bank.
	for spec in [Vector3(110, 95, 0.27), Vector3(1180, 74, 0.24), Vector3(1710, 56, 0.25), Vector3(1960, 108, 0.29), Vector3(2230, 120, 0.32), Vector3(2640, 70, 0.26)]:
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
	_draw_bank_mass(-120.0,1350.0)
	_draw_bank_mass(1880.0,2800.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4721
	for i in range(255):
		var x := rng.randf_range(220.0, 2540.0)
		if x > 1250.0 and x < 1980.0:
			continue
		var y := _bank_edge_y(x)
		var height := rng.randf_range(3.0, 14.0)
		var lean := rng.randf_range(-7.0, 9.0) + sin(clock * 0.8 + i) * 1.0
		terrain.draw_colored_polygon(PackedVector2Array([
			Vector2(x-0.7,y+3),Vector2(x+lean,y-height),Vector2(x+0.8,y+3)
		]), INK)
		if i % 5 == 0:
			terrain.draw_circle(Vector2(x,y+2),rng.randf_range(2.0,5.0),INK,true,-1,true)

func _bank_edge_y(x: float) -> float:
	var ground: float = level.ground_y(x)
	var underwater := smoothstep(level.WATER_Y + 8.0, level.WATER_Y + 100.0, ground)
	var rounded: float = (level.ground_y(x-18.0) + ground*2.0 + level.ground_y(x+18.0)) * 0.25
	var earth := bank_noise.get_noise_1d(x) * 9.0 + bank_noise.get_noise_1d(x*3.7) * 2.0
	# Keep exposed contact contours close to the unchanged physics surface.
	return lerpf(ground, rounded, underwater) - 2.0 + earth * lerpf(0.65,2.0,underwater)

func _draw_bank_mass(start: float, end: float) -> void:
	var edge := PackedVector2Array()
	for x in range(int(start),int(end),4):
		edge.append(Vector2(x,_bank_edge_y(x)))
	edge.append(Vector2(end,_bank_edge_y(end)))
	var mass := edge.duplicate()
	mass.append(Vector2(end,1000))
	mass.append(Vector2(start,1000))
	terrain.draw_colored_polygon(mass,INK)
	terrain.draw_polyline(edge,INK,1.8,true)

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
	_beam(props,Vector2(379,550),Vector2(367,418),10,2)
	# The walkable edge shares the collider's height; weathering stays underneath.
	var rack: Rect2 = level.RACK_RECT
	var plank := PackedVector2Array([rack.position, Vector2(rack.end.x, rack.position.y)])
	for i in range(6,-1,-1):
		plank.append(Vector2(lerpf(rack.position.x,rack.end.x,float(i)/6.0), rack.end.y+sin(i*1.8+1.0)*0.85))
	props.draw_colored_polygon(plank,INK)
	_beam(props,Vector2(563,419),Vector2(558,550),8,8)
	_beam(props,Vector2(373,466),Vector2(420,421),6,3)
	if level.completed:
		props.draw_circle(Vector2(2460,517),3.0,Color(0.76,0.76,0.76),true,-1,true)

func _draw_crate() -> void:
	if ActorStyleHostRef.style_override == PoseRef.STYLE_HOOD:
		_draw_boat_back()
		return
	crate_art.draw_set_transform(-level.CRATE_SIZE * 0.5)
	# The interior deck is the collision top. The rear gunwale stays behind the actor.
	crate_art.draw_colored_polygon(PackedVector2Array([
		Vector2(0,0), Vector2(144,0), Vector2(148,12), Vector2(141,28),
		Vector2(118,32), Vector2(84,29), Vector2(57,33), Vector2(19,30),
		Vector2(-5,24), Vector2(-3,9)
	]), INK)
	_beam(crate_art,Vector2(6,-13),Vector2(137,-16),7,4)
	for x in [9.0, 59.0, 134.0]:
		_beam(crate_art,Vector2(x,5),Vector2(x-2,-19),5, x)
	# Short end grips bridge the pull pose's reach without moving the actor root.
	_beam(crate_art,Vector2(128,17),Vector2(157,13),7,6)
	_beam(crate_art,Vector2(155,19),Vector2(157,7),5,2)
	_beam(crate_art,Vector2(14,17),Vector2(-12,14),6,3)

func _draw_raft_front() -> void:
	if ActorStyleHostRef.style_override == PoseRef.STYLE_HOOD:
		_draw_boat_front()
		return
	raft_front.draw_set_transform(-level.CRATE_SIZE * 0.5)
	# One continuous low front board hides soles, not a second collision wall.
	raft_front.draw_colored_polygon(PackedVector2Array([
		Vector2(-3,-8), Vector2(12,-12), Vector2(30,-10), Vector2(45,-13),
		Vector2(61,-10), Vector2(82,-12), Vector2(105,-9), Vector2(125,-12),
		Vector2(146,-8), Vector2(148,17), Vector2(129,26), Vector2(96,24),
		Vector2(72,28), Vector2(39,25), Vector2(9,27), Vector2(-4,20)
	]), INK)
	_beam(raft_front,Vector2(16,-14),Vector2(17,28),4,7)
	_beam(raft_front,Vector2(123,-13),Vector2(125,27),5,3)

# The boat the hooded boy handles: a long skiff with a stem and a stern post that rise to chest height, where his hands
# go when he pushes (flush with the ends); pulling, he takes up the rope tied to the post (drawn by the controller).
# The deck line (y = 0) is the collision top.
func _draw_boat_back() -> void:
	crate_art.draw_set_transform(-level.CRATE_SIZE * 0.5)
	# far side of the hull, rising to the stem and the stern post
	crate_art.draw_colored_polygon(PackedVector2Array([
		Vector2(-3,-24), Vector2(3,-12), Vector2(6,1), Vector2(30,3), Vector2(72,5), Vector2(114,3), Vector2(138,1),
		Vector2(141,-12), Vector2(147,-24), Vector2(149,-8), Vector2(147,12), Vector2(131,27), Vector2(100,33),
		Vector2(72,34), Vector2(44,33), Vector2(13,27), Vector2(-3,12), Vector2(-5,-8)
	]), INK)
	_beam(crate_art,Vector2(3,8),Vector2(-2,-25),6,11)
	_beam(crate_art,Vector2(141,8),Vector2(146,-25),6,12)
	# a rib and a thwart inside, and the rings the ropes are tied to
	_beam(crate_art,Vector2(44,3),Vector2(42,-9),5,3)
	_beam(crate_art,Vector2(100,3),Vector2(102,-9),5,4)
	_beam(crate_art,Vector2(20,-5),Vector2(124,-6),4,5)
	crate_art.draw_circle(Vector2(-2,-13),3.4,INK,true,-1.0,true)
	crate_art.draw_circle(Vector2(146,-13),3.4,INK,true,-1.0,true)

func _draw_boat_front() -> void:
	raft_front.draw_set_transform(-level.CRATE_SIZE * 0.5)
	# the near side of the hull: low, so it hides his soles but not his legs
	raft_front.draw_colored_polygon(PackedVector2Array([
		Vector2(-5,-6), Vector2(8,-3), Vector2(36,-1), Vector2(72,0), Vector2(108,-1), Vector2(136,-3), Vector2(149,-6),
		Vector2(150,10), Vector2(133,27), Vector2(101,34), Vector2(72,35), Vector2(43,34), Vector2(11,27), Vector2(-6,10)
	]), INK)

func _draw_bank_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8117
	# Dense ankle-height tufts follow world-space ground, including both shore slopes.
	for span in [Vector2(12,250), Vector2(1050,1260), Vector2(1968,2145)]:
		var opening: bool = span.x < 250.0
		var roots := PackedVector2Array()
		for sample in range(int(span.x), int(span.y) + 1, 4):
			var taper := smoothstep(0.0,25.0,minf(sample-span.x,span.y-sample))
			var root_height := (16.0 if opening else 7.0) * taper
			roots.append(Vector2(sample, _bank_edge_y(sample) - root_height - bank_noise.get_noise_1d(sample*1.8)*5.0*taper))
		for sample in range(int(span.y), int(span.x) - 1, -4):
			roots.append(Vector2(sample, level.ground_y(sample) + 10.0))
		bank_grass.draw_colored_polygon(roots, INK)
		var x: float = span.x
		while x < span.y:
			var y := _bank_edge_y(x)
			var cluster := 0.5 + bank_noise.get_noise_1d(x*2.3)*0.5
			var height := rng.randf_range(28,40) if opening else lerpf(12.0,27.0,cluster) + rng.randf_range(-3,3)
			height *= lerpf(0.15,1.0,smoothstep(0.0,25.0,minf(x-span.x,span.y-x)))
			var lean := rng.randf_range(-10,13) + sin(clock * 0.65 + x * 0.11) * 1.2 + gust_lean(x) * clampf(height / 30.0, 0.3, 1.2)
			for offset in [-2.0, 2.0]:
				bank_grass.draw_colored_polygon(PackedVector2Array([
					Vector2(x+offset-2,y+5),Vector2(x+lean+offset*2,y-height+absf(offset)),Vector2(x+offset+2,y+5)
				]), INK)
			x += rng.randf_range(3,6)

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
			surface.draw_line(Vector2(x-9.0,water_line(x-9.0)),Vector2(x+11.0,water_line(x+11.0)),Color(0.74,0.74,0.74,0.20),1.2,true)
		for i in range(3):
			var phase := fposmod(clock*0.65+i/3.0,1.0)
			surface.draw_set_transform(Vector2(center.x,579.0),0.0,Vector2(1.0,0.13))
			surface.draw_arc(Vector2.ZERO,level.CRATE_SIZE.x*0.5+phase*52.0,0,TAU,40,Color(0.74,0.74,0.74,(1.0-phase)*0.14),1.7,true)
			surface.draw_set_transform(Vector2.ZERO)
	_draw_swell_lines()
	for impact in water_impacts:
		_draw_water_impact(impact)
	for ripple in gust_ripples:
		# a short crinkle of the surface: two flat arcs opening and fading
		var age: float = float(ripple.age)
		var spread: float = (6.0 + age * 46.0) * float(ripple.size)
		var alpha := (1.0 - age / 1.2) * 0.34
		surface.draw_set_transform(Vector2(float(ripple.x), level.WATER_Y + 2.0), 0.0, Vector2(1.0, 0.12))
		surface.draw_arc(Vector2.ZERO, spread, 0.0, TAU, 40, Color(0.74, 0.74, 0.74, alpha), 1.5, true)
		surface.draw_arc(Vector2.ZERO, spread * 0.55, 0.0, TAU, 28, Color(0.74, 0.74, 0.74, alpha * 0.7), 1.2, true)
		surface.draw_set_transform(Vector2.ZERO)

# The swell on the surface: a bright crest line that rides the water (brighter where it moves most) and two fainter lines under it
# that follow it more gently, so the whole surface reads as rocking, not only the spray.
func _draw_swell_lines() -> void:
	if wave_energy < 0.6:
		return
	var from_x := maxf(WAVE_X0 + 8.0, camera_x - 20.0)
	var to_x := minf(WAVE_X0 + (WAVE_N - 2) * WAVE_DX, camera_x + 1300.0)
	if to_x <= from_x:
		return
	var x := from_x
	var base_y: float = level.WATER_Y
	while x < to_x:
		var nx := x + WAVE_DX * 2.0
		var h0 := wave_at(x)
		var h1 := wave_at(nx)
		var activity := clampf(maxf(absf(h0), absf(h1)) * 0.11 + absf(h1 - h0) * 0.16, 0.0, 1.0)
		if activity > 0.03:
			surface.draw_line(Vector2(x, base_y - h0 + 1.5), Vector2(nx, base_y - h1 + 1.5), Color(0.06, 0.06, 0.06, activity * 0.55), 2.6, true)
			surface.draw_line(Vector2(x, base_y - h0), Vector2(nx, base_y - h1), Color(0.86, 0.86, 0.86, activity * 0.75), 1.5, true)
			for k in 2:
				var depth := 7.0 + k * 9.0
				var echo0 := base_y + depth - h0 * (0.55 - 0.2 * k)
				var echo1 := base_y + depth - h1 * (0.55 - 0.2 * k)
				surface.draw_line(Vector2(x, echo0), Vector2(nx, echo1), Color(0.78, 0.78, 0.78, activity * (0.30 - 0.1 * k)), 1.1, true)
		x = nx

func _draw_water_impact(impact: Dictionary) -> void:
	if impact.has("drops"):
		_draw_struggle_splash(impact)
		return
	var t: float = impact.age
	var strength: float = impact.strength
	var origin := Vector2(impact.x, water_line(float(impact.x)))
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
	if not impact.rings:
		return
	# rings run out and fade slowly (the harder the hit the farther and the longer)
	var life := 1.3 + strength * 1.0
	for i in 4:
		var age := t - i * 0.16
		if age < 0.0 or age > life:
			continue
		var fade := 1.0 - age / life
		surface.draw_set_transform(origin + Vector2(0,2),0,Vector2(1,0.14))
		surface.draw_arc(Vector2.ZERO,impact.spread+age*(62.0+strength*34.0),0,TAU,56,Color(0.70,0.70,0.70,fade*fade*(0.34-i*0.05)),1.5,true)
		surface.draw_set_transform(Vector2.ZERO)

func _draw_struggle_splash(impact: Dictionary) -> void:
	var origin := Vector2(impact.x, water_line(float(impact.x)))
	for drop in impact.drops:
		var t: float = impact.age - drop.delay
		if t < 0.0:
			continue
		var velocity: Vector2 = drop.velocity
		var offset: Vector2 = drop.offset
		var point := origin + offset + velocity * t + Vector2(0.0, 300.0*t*t)
		if point.y >= level.WATER_Y:
			continue
		var alpha := minf(t / 0.025, 1.0) * 0.75
		var tail := (velocity + Vector2(0.0, 600.0*t)) * 0.014
		var shade: float = drop.shade
		# Fine streaks shorten into beads at the apex, then fall back into the water.
		surface.draw_line(point+Vector2(0,0.6), point-tail+Vector2(0,0.6), Color(0.13,0.13,0.13,alpha*0.4), drop.radius*2.0+0.6, true)
		surface.draw_line(point, point-tail, Color(shade,shade,shade,alpha), drop.radius*1.5, true)
		surface.draw_circle(point, drop.radius, Color(shade,shade,shade,alpha), true, -1.0, true)

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
	var marsh_rng := RandomNumberGenerator.new()
	marsh_rng.seed = 91
	for i in range(80):
		var wx := marsh_rng.randf_range(3100.0,6500.0)
		var sx := wx-camera_x*1.14
		var height := marsh_rng.randf_range(20.0,85.0)
		var lean := marsh_rng.randf_range(-38.0,38.0)+sin(clock*0.35+i)*2.0
		var width := marsh_rng.randf_range(2.0,4.0)
		if sx < -60.0 or sx > 1340.0:
			continue
		foreground.draw_colored_polygon(PackedVector2Array([Vector2(sx-width,744),Vector2(sx+lean,744-height),Vector2(sx+width,744)]),Color(0.012,0.014,0.014,0.85))
	for i in range(12):
		var age := fposmod(clock*0.019+i*0.117,1.0)
		var mote := Vector2(fposmod(i*137.0-camera_x*0.40+age*30.0,1280.0),580-age*420.0)
		foreground.draw_circle(mote,0.7,Color(0.88,0.88,0.88,sin(age*PI)*0.13),true,-1,true)
