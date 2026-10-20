extends Node2D

const SCREEN := Vector2(1280.0, 720.0)
const FOREGROUND_VOLUME: Texture2D = preload("res://assets/art/cinematic-bell-foreground-blur-magenta.png")

var clock := 0.0
var camera_x := 0.0
var sprites: Array[Sprite2D] = []
var overlay: Node2D
var soft_texture: GradientTexture2D

func _ready() -> void:
	z_index = 45
	z_as_relative = false
	soft_texture = _make_soft_texture()
	var foreground_material := _make_foreground_material()
	for index in range(4):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = FOREGROUND_VOLUME
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.material = foreground_material
		sprites.append(sprite)
		add_child(sprite)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	hide()

func _make_soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.67, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.78),
		Color(1.0, 1.0, 1.0, 0.36),
		Color(1.0, 1.0, 1.0, 0.09),
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

func _make_foreground_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float magenta_excess = min(source.r, source.b) - source.g;
	float keyed = step(0.012, magenta_excess) * step(0.15, max(source.r, source.b));
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float near_black = luminance * 0.08;
	COLOR = vec4(vec3(near_black), source.a * (1.0 - keyed) * 0.88);
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	return material_value

func sync(delta: float, new_camera_x: float, active: bool) -> void:
	visible = active
	if not active:
		return
	clock += delta
	camera_x = new_camera_x
	var scroll := camera_x * 1.12
	var first_tile := int(floor(scroll / SCREEN.x))
	for index in range(sprites.size()):
		var tile := first_tile + index - 1
		var sprite := sprites[index]
		sprite.position = Vector2(float(tile) * SCREEN.x - scroll, 0.0)
		sprite.flip_h = abs(tile) % 2 == 1
	overlay.queue_redraw()

func _draw_soft(center: Vector2, size: Vector2, tint: Color) -> void:
	overlay.draw_texture_rect(soft_texture, Rect2(center - size * 0.5, size), false, tint)

func _foreground_x(world_x: float) -> float:
	return world_x - camera_x * 1.14

func _draw_overlay() -> void:
	if not visible:
		return
	_draw_foreground_haze()
	_draw_lens_vignette()
	_draw_film_grain()

func _draw_foreground_haze() -> void:
	for haze_index in range(4):
		var x := fposmod(float(haze_index) * 370.0 - camera_x * 0.82 + clock * (7.0 + float(haze_index) * 1.4), 1840.0) - 280.0
		var y := 560.0 + float(haze_index % 2) * 58.0 + sin(clock * 0.16 + haze_index * 1.9) * 12.0
		_draw_soft(Vector2(x, y), Vector2(610.0, 118.0), Color(0.58, 0.61, 0.60, 0.015 + float(haze_index % 2) * 0.006))

func _draw_near_structures() -> void:
	for beam_index in range(5):
		var world_x := 180.0 + float(beam_index) * 880.0
		var x := _foreground_x(world_x)
		if x < -260.0 or x > SCREEN.x + 260.0:
			continue
		var start := Vector2(x - 70.0, -50.0)
		var finish := Vector2(x + 95.0, 770.0)
		for blur_index in range(4, 0, -1):
			var width := 38.0 + float(blur_index) * 17.0
			var alpha := 0.022 + float(4 - blur_index) * 0.014
			overlay.draw_line(start, finish, Color(0.0, 0.0, 0.0, alpha), width, true)
		overlay.draw_line(start, finish, Color(0.006, 0.008, 0.009, 0.82), 31.0, true)
		overlay.draw_line(start + Vector2(8.0, 0.0), finish + Vector2(8.0, 0.0), Color(0.58, 0.60, 0.59, 0.07), 2.0, true)

	for chain_index in range(6):
		var world_x := 510.0 + float(chain_index) * 620.0
		var x := _foreground_x(world_x)
		if x < -60.0 or x > SCREEN.x + 60.0:
			continue
		var length := 130.0 + float(chain_index % 3) * 62.0
		for link_index in range(int(length / 18.0)):
			var y := float(link_index) * 18.0 - 8.0
			var sway := sin(clock * 0.28 + float(chain_index) + y * 0.015) * 4.0
			overlay.draw_arc(Vector2(x + sway, y), 7.0, 0.0, TAU, 12, Color(0.01, 0.013, 0.014, 0.72), 4.0, true)

	for grass_index in range(18):
		var x := fposmod(float(grass_index) * 91.0 - camera_x * 1.18, SCREEN.x + 180.0) - 90.0
		var height := 22.0 + float(grass_index % 5) * 13.0
		var lean := sin(clock * 0.38 + grass_index * 1.4) * 5.0
		overlay.draw_line(Vector2(x, SCREEN.y + 4.0), Vector2(x + lean, SCREEN.y - height), Color(0.005, 0.007, 0.008, 0.72), 8.0, true)

func _draw_lens_vignette() -> void:
	_draw_soft(Vector2(-35.0, -20.0), Vector2(460.0, 390.0), Color(0.0, 0.0, 0.0, 0.72))
	_draw_soft(Vector2(SCREEN.x + 35.0, -20.0), Vector2(460.0, 390.0), Color(0.0, 0.0, 0.0, 0.72))
	_draw_soft(Vector2(-25.0, SCREEN.y + 10.0), Vector2(500.0, 320.0), Color(0.0, 0.0, 0.0, 0.64))
	_draw_soft(Vector2(SCREEN.x + 25.0, SCREEN.y + 10.0), Vector2(500.0, 320.0), Color(0.0, 0.0, 0.0, 0.64))
	for edge_band in range(6):
		var alpha := lerpf(0.11, 0.0, float(edge_band) / 5.0)
		overlay.draw_rect(Rect2(0.0, float(edge_band) * 6.0, SCREEN.x, 7.0), Color(0.0, 0.0, 0.0, alpha))

func _draw_film_grain() -> void:
	var frame_seed := int(clock * 18.0)
	for grain_index in range(145):
		var x := fposmod(float(grain_index * 73 + frame_seed * 37), SCREEN.x)
		var y := fposmod(float(grain_index * 131 + frame_seed * 61), SCREEN.y)
		var value := 0.35 if (grain_index + frame_seed) % 3 == 0 else 0.0
		var alpha := 0.012 + float(grain_index % 4) * 0.004
		overlay.draw_circle(Vector2(x, y), 0.45, Color(value, value, value, alpha), true, -1.0, false)
