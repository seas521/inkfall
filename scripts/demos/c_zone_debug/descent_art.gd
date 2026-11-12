extends Node2D

# Static art review: individually authored matte sets, not repeated geometry.
# Each set separates a defocused far plane, material mid plane and dark near
# extraction. Air, volumetric light and the actual Seedance actor stay independent.
const Layout = preload("res://scripts/demos/c_zone_debug/descent_layout.gd")
const LIGHT = preload("res://assets/shaders/cinematic_light_cone.gdshader")
const MATTE = preload("res://assets/shaders/descent_matte.gdshader")
const PLATES := [
	preload("res://assets/art/descent/01-broken-walkway-v2.png"),
	preload("res://assets/art/descent/02-wet-recess-v2.png"),
	preload("res://assets/art/descent/03-hoist-station-v2.png"),
	preload("res://assets/art/descent/04-scree-chute-v2.png"),
	preload("res://assets/art/descent/05-bat-cavern-v2.png"),
]
const MASKS := [
	preload("res://assets/art/descent/01-foreground-mask.png"),
	preload("res://assets/art/descent/02-foreground-mask.png"),
	preload("res://assets/art/descent/03-foreground-mask.png"),
	preload("res://assets/art/descent/04-foreground-mask.png"),
	preload("res://assets/art/descent/05-foreground-mask.png"),
]

var level
var clock := 0.0
var camera := Vector2.ZERO
var weight := 0.0
var back_layer: CanvasLayer
var near_layer: CanvasLayer
var sets: Array[CanvasGroup] = []
var planes: Array[Array] = []
var mist: Node2D
var dust: Node2D
var cones: Array[ColorRect] = []
var soft: GradientTexture2D
var mouth: Node2D
var contour_noise := FastNoiseLite.new()

func _ready() -> void:
	back_layer = CanvasLayer.new()
	back_layer.layer = -7
	add_child(back_layer)
	for i in range(PLATES.size()):
		var set_root := CanvasGroup.new()
		set_root.clear_margin = 24.0
		set_root.fit_margin = 24.0
		back_layer.add_child(set_root)
		sets.append(set_root)
		var set_planes: Array = []
		for depth in range(3):
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture = PLATES[i]
			sprite.scale = Vector2(1280,720)/PLATES[i].get_size()
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var material_value := ShaderMaterial.new()
			material_value.shader = MATTE
			material_value.set_shader_parameter("plate_texture",PLATES[i])
			material_value.set_shader_parameter("silhouette_mask",MASKS[i])
			material_value.set_shader_parameter("plane",depth)
			material_value.set_shader_parameter("scene_id",i)
			sprite.material = material_value
			set_root.add_child(sprite)
			set_planes.append(sprite)
		planes.append(set_planes)
	for i in range(5):
		var cone := ColorRect.new()
		cone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cone.position = Vector2(320,-160) if i != 4 else Vector2(800,-80)
		cone.size = Vector2(960,880)
		var material_value := ShaderMaterial.new()
		material_value.shader = LIGHT
		material_value.set_shader_parameter("seed",float(i)*1.93)
		material_value.set_shader_parameter("intensity",0.07)
		material_value.set_shader_parameter("light_tint",Vector3(0.68,0.68,0.68))
		cone.material = material_value
		back_layer.add_child(cone)
		cones.append(cone)
	soft = GradientTexture2D.new()
	soft.width = 128
	soft.height = 128
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5,0.5)
	soft.fill_to = Vector2(1,0.5)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.28,0.65,1])
	gradient.colors = PackedColorArray([Color(1,1,1,0.65),Color(1,1,1,0.3),Color(1,1,1,0.04),Color(1,1,1,0)])
	soft.gradient = gradient
	mist = Node2D.new()
	mist.draw.connect(_draw_mist)
	back_layer.add_child(mist)
	near_layer = CanvasLayer.new()
	near_layer.layer = 16
	add_child(near_layer)
	dust = Node2D.new()
	dust.draw.connect(_draw_dust)
	near_layer.add_child(dust)
	contour_noise.seed = 15421
	contour_noise.frequency = 0.031
	mouth = Node2D.new()
	mouth.z_index = 2
	mouth.draw.connect(_draw_mouth_ground)
	add_child(mouth)
	set_active(false)

func set_active(value: bool) -> void:
	visible = value
	back_layer.visible = value
	near_layer.visible = value

func _route_position(origin: Vector2) -> float:
	var best := INF
	var result := 0.0
	for i in range(Layout.SHOTS.size()-1):
		var a: Vector2 = Layout.SHOTS[i].camera
		var b: Vector2 = Layout.SHOTS[i+1].camera
		var u := clampf((origin-a).dot(b-a)/(b-a).length_squared(),0,1)
		var distance := origin.distance_squared_to(a.lerp(b,u))
		if distance < best:
			best = distance
			result = float(i)+u
	return result

func sync(delta: float, origin: Vector2, active: bool) -> void:
	camera = origin
	clock += delta
	# At C's bank the new matte contributes exactly zero. The original C renderer
	# stays alive throughout, including its real terrain and existing backdrop.
	var reviewing: bool = level != null and level.descent != null and level.descent.enabled
	var entry := smoothstep(0,2.5,float(level.descent.entry_time)) if reviewing else 0.0
	weight = entry*(1.0-smoothstep(-1280,-120,origin.x))
	mouth.visible = reviewing and origin.x > -1750 and origin.x < 50
	mouth.modulate.a = smoothstep(-1750,-1150,origin.x) if mouth.visible else 0.0
	set_active(active and weight > 0.0001 and origin.x > -5000 and origin.y < 900)
	if level != null and level.marsh_art != null:
		level.marsh_art.modulate.a = 1.0-weight
	if not visible:
		return
	var route := _route_position(origin)
	var first := mini(int(route),PLATES.size()-1)
	var u := smoothstep(0,1,route-float(first)) if first < PLATES.size()-1 else 0.0
	for i in range(sets.size()):
		var strength := 1.0 if i == first else (u if i == first+1 else 0.0)
		sets[i].visible = strength > 0.0001
		sets[i].modulate.a = strength*weight
		cones[i].visible = i == first
		cones[i].modulate.a = weight
		(cones[i].material as ShaderMaterial).set_shader_parameter("clock",clock)
		if not sets[i].visible:
			continue
		var drift := origin-Vector2(Layout.SHOTS[i].camera)
		for depth in range(3):
			var material_value: ShaderMaterial = planes[i][depth].material
			material_value.set_shader_parameter("pan",drift*Vector2(0.000018,0.000014)*[0.25,0.65,1.10][depth])
			material_value.set_shader_parameter("clock",clock)
	mist.queue_redraw()
	dust.queue_redraw()

func _draw_mist() -> void:
	for i in range(6):
		var y := 410.0+sin(float(i)*1.91+clock*0.025)*140
		var x := 600.0+sin(clock*(0.025+float(i%2)*0.01)+float(i)*2.3)*230
		mist.draw_texture_rect(soft,Rect2(x-620,y-80,1240,160),false,Color(0.66,0.66,0.66,0.025*weight))
	var wet := smoothstep(-4350,-3700,camera.y)*(1-smoothstep(-3200,-2650,camera.y))*weight
	for i in range(42):
		var at := Vector2(fposmod(i*83.71+clock*8,1320)-20,fposmod(i*123.17+clock*195,780)-30)
		mist.draw_line(at,at+Vector2(2,16+float(i%4)*5),Color(0.65,0.65,0.65,0.035*wet),0.7,true)

func _draw_dust() -> void:
	for i in range(24):
		var depth := float(i%3+1)
		var age := fposmod(clock*(0.013+depth*0.004)+float(i)*0.173,1)
		var at := Vector2(fposmod(float(i)*183.73-camera.x*0.04+sin(age*3+float(i))*23,1320)-20,760-age*840)
		dust.draw_circle(at,0.35+depth*0.22,Color(0.72,0.72,0.72,sin(age*PI)*0.06*weight),true,-1,true)

func _draw_mouth_ground() -> void:
	# A small, continuous contact contour joins C's existing bank, rather than
	# exposing its vertical start edge during the photographic art transition.
	var points := PackedVector2Array([Vector2(-1150,1000)])
	for x in range(-1150,-119,8):
		var t := clampf(float(x+1150)/1030.0,0,1)
		var y := lerpf(454,320,smoothstep(0,1,t))+contour_noise.get_noise_1d(x)*1.5*(1-t)
		points.append(Vector2(x,y))
	points.append(Vector2(-120,320))
	points.append(Vector2(-112,323))
	points.append(Vector2(-112,1000))
	mouth.draw_colored_polygon(points,Color("050606"))
