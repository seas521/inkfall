extends Node2D

const VOLUME: Shader = preload("res://assets/shaders/inkfall_volume.gdshader")
const WATER: Shader = preload("res://assets/shaders/inkfall_water.gdshader")
const ROCK: Texture2D = preload("res://assets/art/level01/rock-platform.png")
const EXPOSURE: Shader = preload("res://assets/shaders/inkfall_exposure.gdshader")
var pool: Dictionary = {}
var white: GradientTexture2D
var exposure: Sprite2D
var waterfall_mist: GPUParticles2D

func _ready() -> void:
	white = GradientTexture2D.new()
	white.width = 2
	white.height = 2
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE,Color.WHITE])
	white.gradient = gradient
	exposure = Sprite2D.new()
	exposure.centered = false
	exposure.texture = white
	exposure.scale = Vector2(640,360)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = EXPOSURE
	exposure.material = mat
	add_child(exposure)
	exposure.hide()
	_create_waterfall_mist()

func _create_waterfall_mist() -> void:
	var mist_gradient := Gradient.new()
	mist_gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.68, 1.0])
	mist_gradient.colors = PackedColorArray([
		Color(0.86, 0.86, 0.84, 0.44),
		Color(0.66, 0.66, 0.64, 0.25),
		Color(0.42, 0.42, 0.40, 0.08),
		Color(0.18, 0.18, 0.17, 0.0),
	])
	var mist_texture := GradientTexture2D.new()
	mist_texture.width = 96
	mist_texture.height = 64
	mist_texture.gradient = mist_gradient
	mist_texture.fill = GradientTexture2D.FILL_RADIAL
	mist_texture.fill_from = Vector2(0.5, 0.5)
	mist_texture.fill_to = Vector2(1.0, 0.5)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(68.0, 3.0, 1.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 72.0
	process.initial_velocity_min = 16.0
	process.initial_velocity_max = 46.0
	process.gravity = Vector3(0.0, 16.0, 0.0)
	process.scale_min = 0.07
	process.scale_max = 0.22
	process.color = Color(0.72, 0.72, 0.70, 0.36)
	waterfall_mist = GPUParticles2D.new()
	waterfall_mist.amount = 74
	waterfall_mist.lifetime = 1.55
	waterfall_mist.randomness = 0.78
	waterfall_mist.visibility_rect = Rect2(-180.0, -120.0, 360.0, 240.0)
	waterfall_mist.texture = mist_texture
	waterfall_mist.process_material = process
	waterfall_mist.z_index = 4
	waterfall_mist.emitting = true
	waterfall_mist.hide()
	add_child(waterfall_mist)

func begin_frame() -> void:
	exposure.hide()
	waterfall_mist.hide()
	for node in pool.values():
		(node as Sprite2D).hide()

func light_shaft(sources: PackedVector4Array, depth: float) -> void:
	exposure.show()
	var mat: ShaderMaterial = exposure.material as ShaderMaterial
	var count: int = mini(8,sources.size())
	sources.resize(8)
	mat.set_shader_parameter("sources",sources)
	mat.set_shader_parameter("source_count",count)
	mat.set_shader_parameter("depth",depth)

func present(key: String, rect: Rect2, kind: String, time: float, strength: float = 1.0, seed: float = 0.0, world_x: float = 0.0, active_flow: bool = true, monochrome: bool = false) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not rect.intersects(Rect2(-80,-80,1440,880)) or strength <= 0.015:
		return
	var sprite: Sprite2D = pool.get(key) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.texture = white
		var shader_material: ShaderMaterial = ShaderMaterial.new()
		shader_material.shader = WATER if kind == "river" or kind == "waterfall" else VOLUME
		sprite.material = shader_material
		add_child(sprite)
		pool[key] = sprite
	sprite.show()
	sprite.position = rect.position
	sprite.scale = rect.size / 2.0
	var mat: ShaderMaterial = sprite.material as ShaderMaterial
	mat.set_shader_parameter("clock",time)
	if kind == "river" or kind == "waterfall":
		mat.set_shader_parameter("river",kind == "river")
		mat.set_shader_parameter("extent",rect.size)
		mat.set_shader_parameter("origin_x",world_x)
		mat.set_shader_parameter("rock_texture",ROCK)
		mat.set_shader_parameter("waterfall_active",active_flow)
		mat.set_shader_parameter("monochrome",monochrome)
		if kind == "waterfall":
			waterfall_mist.position = Vector2(rect.get_center().x, minf(608.0, rect.end.y - 5.0))
			waterfall_mist.show()
	else:
		mat.set_shader_parameter("smoke",kind == "gas")
		mat.set_shader_parameter("intensity",strength)
		mat.set_shader_parameter("seed",seed)
		mat.set_shader_parameter("monochrome",monochrome)
