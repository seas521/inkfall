extends Node2D

const SCREEN := Vector2(1280.0, 720.0)

var clock := 0.0
var camera_x := 0.0
var overlay: Node2D
var soft_texture: GradientTexture2D


func _ready() -> void:
	z_index = 40
	z_as_relative = false
	soft_texture = _make_soft_texture()
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	hide()


func _make_soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.67, 0.86, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.88),
		Color(0.0, 0.0, 0.0, 0.56),
		Color(0.0, 0.0, 0.0, 0.19),
		Color(0.0, 0.0, 0.0, 0.045),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func sync(delta: float, new_camera_x: float, active: bool) -> void:
	visible = active
	if not active:
		return
	clock += delta
	camera_x = new_camera_x
	overlay.queue_redraw()


func _draw_soft(center: Vector2, size: Vector2, tint: Color = Color.WHITE) -> void:
	overlay.draw_texture_rect(soft_texture, Rect2(center - size * 0.5, size), false, tint)


func _expanded(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var result := PackedVector2Array()
	for point in points:
		result.append(center + (point - center) * (1.0 + amount))
	return result


func _draw_blurred_mass(points: PackedVector2Array, opacity: float = 0.96) -> void:
	# Wide translucent expansions simulate the soft optical bleed visible in the
	# reference without putting a sharp gray outline on the silhouette.
	for blur_index in range(10, 0, -1):
		var ratio := float(blur_index) / 10.0
		overlay.draw_colored_polygon(
			_expanded(points, ratio * 0.075),
			Color(0.0, 0.0, 0.0, (1.0 - ratio * 0.45) * 0.035)
		)
	overlay.draw_colored_polygon(points, Color(0.001, 0.002, 0.002, opacity))


func _draw_overlay() -> void:
	if not visible:
		return
	var drift := sin(camera_x * 0.0021) * 12.0

	var lower_left := PackedVector2Array([
		Vector2(-80.0, 720.0),
		Vector2(-80.0, 632.0),
		Vector2(8.0 + drift, 610.0),
		Vector2(95.0 + drift, 638.0),
		Vector2(154.0 + drift, 690.0),
		Vector2(210.0 + drift, 720.0),
	])
	var lower_right := PackedVector2Array([
		Vector2(1070.0 + drift, 720.0),
		Vector2(1132.0 + drift, 674.0),
		Vector2(1194.0 + drift, 626.0),
		Vector2(1285.0, 604.0),
		Vector2(1360.0, 632.0),
		Vector2(1360.0, 720.0),
	])
	_draw_blurred_mass(lower_left)
	_draw_blurred_mass(lower_right)

	# Broad edge haze makes the frame feel photographed through a wet, dirty lens.
	_draw_soft(Vector2(-55.0, 365.0), Vector2(360.0, 790.0))
	_draw_soft(Vector2(1335.0, 370.0), Vector2(390.0, 800.0))
	_draw_soft(Vector2(640.0, -105.0), Vector2(1190.0, 290.0), Color(1.0, 1.0, 1.0, 0.82))
	_draw_soft(Vector2(640.0, 770.0), Vector2(1040.0, 190.0), Color(1.0, 1.0, 1.0, 0.36))

	# Restrained moving grain. It is intentionally uneven and never used as
	# decorative white dust.
	var frame_seed := int(clock * 12.0)
	for grain_index in range(96):
		var x := fposmod(float(grain_index * 83 + frame_seed * 29), SCREEN.x)
		var y := fposmod(float(grain_index * 149 + frame_seed * 47), SCREEN.y)
		var value := 0.72 if (grain_index + frame_seed) % 5 == 0 else 0.0
		overlay.draw_circle(Vector2(x, y), 0.48, Color(value, value, value, 0.010), true, -1.0, false)
