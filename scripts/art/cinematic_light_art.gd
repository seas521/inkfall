extends Node2D

const LIGHT_CONE: Shader = preload("res://assets/shaders/cinematic_light_cone.gdshader")

const LAMP_RIGS: Array[Vector3] = [
	Vector3(190.0, 116.0, 560.0),
	Vector3(990.0, 92.0, 522.0),
	Vector3(1910.0, 104.0, 505.0),
	Vector3(2935.0, 74.0, 480.0),
]

var clock := 0.0
var camera_x := 0.0
var cones: Array[Sprite2D] = []

func _ready() -> void:
	var white := GradientTexture2D.new()
	white.width = 2
	white.height = 2
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	white.gradient = gradient
	for cone_index in range(LAMP_RIGS.size()):
		var cone := Sprite2D.new()
		cone.centered = false
		cone.texture = white
		var material_value := ShaderMaterial.new()
		material_value.shader = LIGHT_CONE
		material_value.set_shader_parameter("seed", float(cone_index) * 1.73)
		material_value.set_shader_parameter("intensity", 0.27 + float(cone_index % 2) * 0.035)
		cone.material = material_value
		cones.append(cone)
		add_child(cone)
	hide()

func sync(delta: float, new_camera_x: float, active: bool) -> void:
	visible = active
	if not active:
		return
	clock += delta
	camera_x = new_camera_x
	for cone_index in range(cones.size()):
		var rig: Vector3 = LAMP_RIGS[cone_index]
		var cone := cones[cone_index]
		var lamp_x := rig.x - camera_x
		var lamp_y := rig.y + 5.0
		var height := rig.z - lamp_y
		var width := 290.0
		cone.position = Vector2(lamp_x - width * 0.5, lamp_y)
		cone.scale = Vector2(width * 0.5, height * 0.5)
		cone.visible = lamp_x > -width and lamp_x < 1280.0 + width
		(cone.material as ShaderMaterial).set_shader_parameter("clock", clock)
