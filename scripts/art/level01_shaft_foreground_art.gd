extends Node2D

const SCREEN := Vector2(1280.0, 720.0)

var clock := 0.0
var camera_y := 0.0
var overlay: Node2D
var soft_texture: GradientTexture2D

func _ready() -> void:
	z_index = 45
	z_as_relative = false
	soft_texture = _make_soft_texture()
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	hide()

func _make_soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.68, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.30),
		Color(1.0, 1.0, 1.0, 0.065),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func sync(delta: float, new_camera_y: float, active: bool) -> void:
	visible = active
	if not active:
		return
	clock += delta
	camera_y = new_camera_y
	overlay.queue_redraw()

func _draw_soft(center: Vector2, size: Vector2, tint: Color) -> void:
	overlay.draw_texture_rect(soft_texture, Rect2(center - size * 0.5, size), false, tint)

func _draw_overlay() -> void:
	if not visible:
		return
	_draw_soft(Vector2(-110.0, 350.0), Vector2(440.0, 820.0), Color(0.0, 0.0, 0.0, 0.28))
	_draw_soft(Vector2(SCREEN.x + 110.0, 365.0), Vector2(440.0, 820.0), Color(0.0, 0.0, 0.0, 0.28))
	_draw_soft(Vector2(640.0, -90.0), Vector2(980.0, 220.0), Color(0.0, 0.0, 0.0, 0.12))
	_draw_soft(Vector2(640.0, 775.0), Vector2(980.0, 170.0), Color(0.0, 0.0, 0.0, 0.10))
	for haze_index in range(4):
		var x := fposmod(float(haze_index) * 410.0 - camera_y * 0.08 + clock * (2.7 + haze_index), 1760.0) - 240.0
		var y := 560.0 + float(haze_index % 2) * 66.0
		_draw_soft(Vector2(x, y), Vector2(620.0, 105.0), Color(0.64, 0.64, 0.64, 0.009))
	var frame_seed := int(clock * 15.0)
	for grain_index in range(112):
		var x := fposmod(float(grain_index * 79 + frame_seed * 31), SCREEN.x)
		var y := fposmod(float(grain_index * 137 + frame_seed * 53), SCREEN.y)
		var value := 0.28 if (grain_index + frame_seed) % 4 == 0 else 0.0
		overlay.draw_circle(Vector2(x, y), 0.45, Color(value, value, value, 0.007), true, -1.0, false)
