extends Node2D

const MOONWELL_SHADER: Shader = preload("res://assets/shaders/level01_shaft_moonwell.gdshader")

var clock := 0.0
var cone: Sprite2D

func _ready() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var white := GradientTexture2D.new()
	white.width = 2
	white.height = 2
	white.gradient = gradient

	cone = Sprite2D.new()
	cone.centered = false
	cone.texture = white
	cone.position = Vector2(280.0, -18.0)
	cone.scale = Vector2(360.0, 378.0)
	cone.z_index = 0
	var material_value := ShaderMaterial.new()
	material_value.shader = MOONWELL_SHADER
	material_value.set_shader_parameter("intensity", 0.21)
	cone.material = material_value
	add_child(cone)
	hide()

func sync(delta: float, camera_y: float, active: bool) -> void:
	visible = active
	if not active:
		return
	clock += delta
	var material_value := cone.material as ShaderMaterial
	material_value.set_shader_parameter("clock", clock)
	material_value.set_shader_parameter("depth", camera_y)
	material_value.set_shader_parameter(
		"intensity",
		0.208 + sin(clock * 0.29) * 0.008 + sin(clock * 0.71 + 1.4) * 0.004
	)
