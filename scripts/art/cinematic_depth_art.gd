extends Node2D

const SCREEN := Vector2(1280.0, 720.0)
const FAR_VOLUME: Texture2D = preload("res://assets/art/cinematic-bell-far-volume.png")
const MID_VOLUME: Texture2D = preload("res://assets/art/cinematic-bell-mid-volume-magenta.png")

var clock := 0.0
var camera_x := 0.0
var far_sprites: Array[Sprite2D] = []
var mid_sprites: Array[Sprite2D] = []
var far_layer: Node2D
var ink_fog: Node2D
var mid_layer: Node2D
var atmosphere: Node2D
var soft_texture: GradientTexture2D

func _ready() -> void:
	soft_texture = _make_soft_texture()
	var far_container := Node2D.new()
	add_child(far_container)
	_build_plate_layer(far_container, FAR_VOLUME, far_sprites, _make_far_plate_material())
	far_layer = Node2D.new()
	far_layer.draw.connect(_draw_far_layer)
	add_child(far_layer)
	ink_fog = Node2D.new()
	ink_fog.draw.connect(_draw_ink_fog)
	add_child(ink_fog)
	var mid_container := Node2D.new()
	add_child(mid_container)
	_build_plate_layer(mid_container, MID_VOLUME, mid_sprites, _make_mid_plate_material())
	mid_layer = Node2D.new()
	mid_layer.draw.connect(_draw_mid_layer)
	add_child(mid_layer)
	atmosphere = Node2D.new()
	atmosphere.draw.connect(_draw_atmosphere)
	add_child(atmosphere)

func _make_soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.50, 0.76, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.46),
		Color(1.0, 1.0, 1.0, 0.19),
		Color(1.0, 1.0, 1.0, 0.055),
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

func _build_plate_layer(container: Node2D, texture: Texture2D, target: Array[Sprite2D], material_value: ShaderMaterial) -> void:
	for index in range(4):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.material = material_value
		target.append(sprite)
		container.add_child(sprite)

func _make_far_plate_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float veiled = pow(clamp(luminance, 0.0, 1.0), 1.18) * 0.82;
	COLOR = vec4(vec3(veiled) * vec3(0.88, 0.91, 0.90), source.a);
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	return material_value

func _make_mid_plate_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float magenta_excess = min(source.r, source.b) - source.g;
	float keyed = step(0.012, magenta_excess) * step(0.15, max(source.r, source.b));
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float volume = smoothstep(0.015, 0.72, luminance) * 0.48;
	COLOR = vec4(vec3(volume) * vec3(0.70, 0.72, 0.71), source.a * (1.0 - keyed) * 0.66);
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
	_sync_plate_layer(far_sprites, 0.055)
	_sync_plate_layer(mid_sprites, 0.27)
	far_layer.queue_redraw()
	ink_fog.queue_redraw()
	mid_layer.queue_redraw()
	atmosphere.queue_redraw()

func _sync_plate_layer(sprites: Array[Sprite2D], ratio: float) -> void:
	var scroll := camera_x * ratio
	var first_tile := int(floor(scroll / SCREEN.x))
	for index in range(sprites.size()):
		var tile := first_tile + index - 1
		var sprite := sprites[index]
		sprite.position = Vector2(float(tile) * SCREEN.x - scroll, 0.0)
		sprite.flip_h = abs(tile) % 2 == 1

func _layer_x(world_x: float, ratio: float) -> float:
	return world_x - camera_x * ratio

func _draw_soft(canvas: Node2D, center: Vector2, size: Vector2, tint: Color) -> void:
	canvas.draw_texture_rect(soft_texture, Rect2(center - size * 0.5, size), false, tint)

func _draw_ink_fog() -> void:
	# A moving black veil sits on top of the lit backdrop, revealing only pockets
	# of exposure. This is the main source of the dense projector-like image.
	ink_fog.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.0, 0.0, 0.0, 0.12))
	for fog_index in range(13):
		var world_x := 70.0 + float(fog_index) * 290.0
		var x := _layer_x(world_x, 0.17) + sin(clock * (0.10 + float(fog_index % 3) * 0.018) + fog_index) * 46.0
		if x < -370.0 or x > SCREEN.x + 370.0:
			continue
		var y := 110.0 + float(fog_index % 5) * 112.0 + sin(clock * 0.14 + fog_index * 2.1) * 25.0
		var width := 430.0 + float(fog_index % 4) * 85.0
		var height := 190.0 + float(fog_index % 3) * 74.0
		var density := 0.16 + float(fog_index % 3) * 0.045
		_draw_soft(ink_fog, Vector2(x, y), Vector2(width, height), Color(0.0, 0.0, 0.0, density))
	for band_index in range(7):
		var y := 75.0 + float(band_index) * 91.0
		var offset := sin(clock * 0.08 + band_index * 1.4) * 34.0
		ink_fog.draw_line(Vector2(-90.0 + offset, y), Vector2(SCREEN.x + 90.0 + offset, y + 28.0), Color(0.0, 0.0, 0.0, 0.045), 52.0, true)

func _draw_far_layer() -> void:
	far_layer.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.0, 0.0, 0.0, 0.14))
	_draw_soft(far_layer, Vector2(650.0 - camera_x * 0.025, 322.0), Vector2(650.0, 470.0), Color(0.72, 0.75, 0.74, 0.055))
	return
	# Backdrop exposure: a focused fog window surrounded by dense black.
	for band in range(48):
		var y := float(band) * 15.0
		var vertical := exp(-pow((y - 335.0) / 255.0, 2.0))
		var tone := 0.075 + vertical * 0.34
		far_layer.draw_rect(Rect2(0.0, y, SCREEN.x, 16.0), Color(tone * 0.78, tone * 0.82, tone * 0.84, 1.0))
	_draw_soft(far_layer, Vector2(650.0 - camera_x * 0.025, 322.0), Vector2(970.0, 610.0), Color(0.88, 0.91, 0.91, 0.22))
	_draw_soft(far_layer, Vector2(960.0 - camera_x * 0.045, 306.0), Vector2(350.0, 480.0), Color(0.96, 0.96, 0.92, 0.12))

	# Distant foundry stacks: low contrast, large shapes, almost no detail.
	for stack_index in range(10):
		var world_x := 120.0 + float(stack_index) * 365.0
		var x := _layer_x(world_x, 0.08)
		if x < -180.0 or x > SCREEN.x + 180.0:
			continue
		var width := 74.0 + float(stack_index % 3) * 36.0
		var height := 250.0 + float(stack_index % 4) * 54.0
		var rect := Rect2(x - width * 0.5, 474.0 - height, width, height)
		far_layer.draw_rect(rect, Color(0.08, 0.09, 0.095, 0.27))
		far_layer.draw_line(Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), Color(0.66, 0.68, 0.67, 0.10), 4.0, true)
		for seam_index in range(3):
			var seam_y := rect.position.y + height * (0.22 + float(seam_index) * 0.23)
			far_layer.draw_line(Vector2(rect.position.x, seam_y), Vector2(rect.end.x, seam_y + 2.0), Color(0.55, 0.57, 0.56, 0.055), 2.0, true)

	# Huge bell shells are read by contour only, like distant stage scenery.
	for bell_index in range(4):
		var world_x := 460.0 + float(bell_index) * 820.0
		var center := Vector2(_layer_x(world_x, 0.12), 306.0 + float(bell_index % 2) * 54.0)
		if center.x < -260.0 or center.x > SCREEN.x + 260.0:
			continue
		var radius := 112.0 + float(bell_index % 3) * 24.0
		far_layer.draw_arc(center, radius, PI * 0.92, TAU - PI * 0.08, 36, Color(0.10, 0.11, 0.115, 0.34), 38.0, true)
		far_layer.draw_arc(center, radius + 2.0, PI * 0.94, TAU - PI * 0.06, 36, Color(0.80, 0.81, 0.79, 0.085), 3.0, true)
		far_layer.draw_line(center + Vector2(-radius * 0.72, radius * 0.42), center + Vector2(radius * 0.72, radius * 0.42), Color(0.09, 0.10, 0.105, 0.30), 22.0, true)

func _draw_mid_layer() -> void:
	# The authored midground plate carries the volumetric forms. Keep procedural
	# additions off this plane so silhouettes do not become flat line art again.
	return
	# Structural silhouettes move independently from both gameplay and backdrop.
	for frame_index in range(7):
		var world_x := 260.0 + float(frame_index) * 520.0
		var x := _layer_x(world_x, 0.34)
		if x < -260.0 or x > SCREEN.x + 260.0:
			continue
		var lean := -32.0 + float(frame_index % 3) * 24.0
		var top := Vector2(x + lean, 118.0 + float(frame_index % 2) * 46.0)
		var bottom := Vector2(x, 548.0)
		mid_layer.draw_line(top, bottom, Color(0.035, 0.039, 0.041, 0.68), 29.0, true)
		mid_layer.draw_line(top + Vector2(6.0, 0.0), bottom + Vector2(6.0, 0.0), Color(0.52, 0.54, 0.53, 0.10), 3.0, true)
		var arm_end := top + Vector2(185.0 if frame_index % 2 == 0 else -165.0, 38.0)
		mid_layer.draw_line(top, arm_end, Color(0.03, 0.034, 0.036, 0.74), 22.0, true)
		mid_layer.draw_line(top + Vector2(0.0, -5.0), arm_end + Vector2(0.0, -5.0), Color(0.61, 0.62, 0.60, 0.09), 2.0, true)
		var rope_x := arm_end.x - 18.0
		mid_layer.draw_line(Vector2(rope_x, arm_end.y), Vector2(rope_x, arm_end.y + 172.0), Color(0.025, 0.028, 0.03, 0.62), 3.0, true)
		var counterweight := Rect2(rope_x - 10.0, arm_end.y + 164.0, 20.0, 44.0)
		mid_layer.draw_rect(counterweight, Color(0.025, 0.029, 0.031, 0.70))

	for bridge_index in range(3):
		var start_world := 690.0 + float(bridge_index) * 1080.0
		var start := Vector2(_layer_x(start_world, 0.40), 405.0 - float(bridge_index % 2) * 82.0)
		var finish := start + Vector2(360.0, 54.0)
		mid_layer.draw_line(start, finish, Color(0.025, 0.029, 0.031, 0.74), 20.0, true)
		mid_layer.draw_line(start + Vector2(0.0, -7.0), finish + Vector2(0.0, -7.0), Color(0.74, 0.74, 0.70, 0.10), 2.0, true)
		for slat_index in range(8):
			var ratio := float(slat_index) / 7.0
			var point := start.lerp(finish, ratio)
			mid_layer.draw_line(point + Vector2(-4.0, -12.0), point + Vector2(5.0, 12.0), Color(0.02, 0.024, 0.026, 0.72), 4.0, true)

func _draw_atmosphere() -> void:
	# Projector-like light breathes subtly instead of behaving like a game lamp.
	for shaft_index in range(3):
		var x := 360.0 + float(shaft_index) * 310.0 - camera_x * (0.08 + float(shaft_index) * 0.025)
		var pulse := 0.78 + sin(clock * (0.31 + float(shaft_index) * 0.04) + shaft_index * 1.7) * 0.16
		_draw_soft(atmosphere, Vector2(x + 46.0, 292.0), Vector2(180.0, 680.0), Color(0.86, 0.89, 0.88, 0.036 * pulse))

	for fog_index in range(9):
		var x := fposmod(float(fog_index) * 214.0 - camera_x * 0.21 + clock * (2.8 + float(fog_index % 3)), 1700.0) - 210.0
		var y := 330.0 + float(fog_index % 4) * 74.0 + sin(clock * 0.19 + fog_index) * 11.0
		_draw_soft(atmosphere, Vector2(x, y), Vector2(520.0, 126.0), Color(0.75, 0.78, 0.77, 0.034 + float(fog_index % 2) * 0.012))

	for dust_index in range(64):
		var depth_ratio := float(dust_index % 3) / 2.0
		var age := fposmod(clock * (0.040 + float(dust_index % 5) * 0.006) + float(dust_index) * 0.163, 1.0)
		var parallax := lerpf(0.06, 0.68, depth_ratio)
		var base_x := fposmod(float(dust_index) * 109.37 - camera_x * parallax, SCREEN.x + 160.0) - 80.0
		var swirl := sin(age * TAU * (1.0 + float(dust_index % 2)) + dust_index * 2.17) * lerpf(9.0, 34.0, depth_ratio)
		var x := base_x + swirl
		var y := 638.0 - age * 590.0 + sin(age * TAU + dust_index * 1.31) * (7.0 + depth_ratio * 12.0)
		var envelope := sin(age * PI)
		var flicker := 0.58 + pow(sin(clock * 1.7 + dust_index * 2.3), 2.0) * 0.42
		var alpha := envelope * flicker * lerpf(0.11, 0.34, depth_ratio)
		var radius := lerpf(0.42, 1.25, depth_ratio) + float(dust_index % 2) * 0.18
		var point := Vector2(x, y)
		atmosphere.draw_circle(point, radius, Color(0.92, 0.92, 0.87, alpha), true, -1.0, true)
		if depth_ratio > 0.75:
			atmosphere.draw_line(point + Vector2(0.0, 2.0), point + Vector2(-swirl * 0.035, 6.5), Color(0.86, 0.87, 0.84, alpha * 0.32), 0.8, true)
		if dust_index % 11 == 0:
			_draw_soft(atmosphere, point, Vector2(13.0, 13.0) * (0.7 + depth_ratio * 0.6), Color(0.92, 0.92, 0.87, alpha * 0.07))
