extends Node2D

const SCREEN := Vector2(1280.0, 720.0)
const ENTRY_PLATE: Texture2D = preload("res://assets/art/level01/c-zone-limbo-entry-far.jpg")
const MIDDLE_PLATE: Texture2D = preload("res://assets/art/level01/c-zone-limbo-middle-far.jpg")
const EXIT_PLATE: Texture2D = preload("res://assets/art/level01/c-zone-limbo-exit-far.jpg")
const ENTRY_GAMEPLAY: Texture2D = preload("res://assets/art/level01/c-zone-limbo-entry-gameplay.jpg")
const ENTRY_LEDGES: Texture2D = preload("res://assets/art/level01/c-zone-limbo-entry-ledges.jpg")
const MIDDLE_GAMEPLAY: Texture2D = preload("res://assets/art/level01/c-zone-limbo-middle-gameplay.jpg")
const EXIT_GAMEPLAY: Texture2D = preload("res://assets/art/level01/c-zone-limbo-exit-gameplay.jpg")
const WATER_SCENE_SOURCE: Texture2D = preload("res://assets/art/level01/c-zone-limbo-waterfall-source.jpg")
const WATERFALL_SOURCE: Texture2D = preload("res://assets/art/level01/c-zone-limbo-waterfall-crop.png")
const LIGHT_SHADER: Shader = preload("res://assets/shaders/cinematic_light_cone.gdshader")

var clock := 0.0
var camera_x := 0.0
var flow_active := true
var plates: Array[Sprite2D] = []
var gameplay_plates: Array[Sprite2D] = []
var gameplay_world_x := PackedFloat32Array([0.0, 0.0, 0.0, 1030.0, 2060.0])
var gameplay_offset_y := PackedFloat32Array([55.0, 0.0, 0.0, 0.0, 0.0])
var base_plane: Node2D
var atmosphere: Node2D
var river_base: Sprite2D
var waterfall_base: Sprite2D
var waterfall_light: Sprite2D
var lift_light: Sprite2D
var soft_texture: GradientTexture2D


func _ready() -> void:
	soft_texture = _make_soft_texture()
	base_plane = Node2D.new()
	base_plane.z_index = 0
	base_plane.draw.connect(_draw_base)
	add_child(base_plane)
	_make_plate(ENTRY_PLATE)
	_make_plate(MIDDLE_PLATE)
	_make_plate(EXIT_PLATE)
	river_base = _make_river_base()
	waterfall_base = _make_waterfall_base()
	_make_gameplay_plate(ENTRY_GAMEPLAY, 0.0, 1.0, 0.0, 0.43)
	_make_gameplay_plate(ENTRY_LEDGES, 0.0, 0.49, 0.0, 1.0)
	_make_gameplay_plate(ENTRY_LEDGES, 0.61, 1.0, 0.0, 1.0)
	_make_gameplay_plate(MIDDLE_GAMEPLAY, 0.0, 1.0, 0.0, 1.0)
	_make_gameplay_plate(EXIT_GAMEPLAY, 0.0, 1.0, 0.0, 1.0)
	waterfall_light = _make_light(Vector2(716.0, 128.0), Vector2(420.0, 520.0), 0.22, 4.7)
	lift_light = _make_light(Vector2(3190.0, 125.0), Vector2(260.0, 360.0), 0.075, 9.2)
	atmosphere = Node2D.new()
	atmosphere.z_index = 0
	atmosphere.draw.connect(_draw_atmosphere)
	add_child(atmosphere)
	hide()


func _draw_base() -> void:
	base_plane.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("0a0b0c"))


func _make_plate(texture_value: Texture2D) -> void:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture_value
	sprite.scale = SCREEN / texture_value.get_size() * 1.07
	sprite.position = Vector2(-45.0, -18.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = 0
	sprite.material = _make_plate_material()
	add_child(sprite)
	plates.append(sprite)


func _make_gameplay_plate(
	texture_value: Texture2D,
	mask_left: float,
	mask_right: float,
	mask_top: float,
	mask_bottom: float
) -> void:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture_value
	sprite.scale = SCREEN / texture_value.get_size()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = 0
	var material_value := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float mask_left = 0.0;
uniform float mask_right = 1.0;
uniform float mask_top = 0.0;
uniform float mask_bottom = 1.0;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float magenta_excess = min(source.r, source.b) - source.g;
	float key = smoothstep(0.22, 0.62, magenta_excess) * smoothstep(0.42, 0.82, max(source.r, source.b));
	float left_mask = smoothstep(mask_left, min(mask_left + 0.045, 1.0), UV.x);
	float right_mask = 1.0 - smoothstep(max(0.0, mask_right - 0.045), mask_right, UV.x);
	float top_mask = smoothstep(mask_top, min(mask_top + 0.035, 1.0), UV.y);
	float bottom_mask = 1.0 - smoothstep(max(0.0, mask_bottom - 0.035), mask_bottom, UV.y);
	float alpha = (1.0 - key) * left_mask * right_mask * top_mask * bottom_mask;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float value = 0.0025 + luminance * 0.004;
	COLOR = vec4(vec3(value), alpha) * COLOR;
}"""
	material_value.shader = shader
	material_value.set_shader_parameter("mask_left", mask_left)
	material_value.set_shader_parameter("mask_right", mask_right)
	material_value.set_shader_parameter("mask_top", mask_top)
	material_value.set_shader_parameter("mask_bottom", mask_bottom)
	sprite.material = material_value
	add_child(sprite)
	gameplay_plates.append(sprite)


func _make_river_base() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = WATER_SCENE_SOURCE
	sprite.position = Vector2(76.0, 0.0)
	sprite.scale = SCREEN / WATER_SCENE_SOURCE.get_size()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = 0
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float water_mask = smoothstep(0.74, 0.84, UV.y);
	float alpha = water_mask * smoothstep(0.012, 0.30, value) * (0.10 + value * 0.30);
	float gray = 0.018 + value * 0.16;
	COLOR = vec4(vec3(gray), alpha) * COLOR;
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	sprite.material = material_value
	add_child(sprite)
	return sprite


func _make_waterfall_base() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = WATERFALL_SOURCE
	sprite.position = Vector2(600.0, 255.0)
	sprite.scale = Vector2(160.0 / 364.0, 385.0 / 560.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = 0
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float value = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float alpha = smoothstep(0.012, 0.24, value) * (0.20 + value * 0.46);
	float gray = clamp(0.16 + value * 0.50, 0.0, 0.72);
	COLOR = vec4(vec3(gray), alpha) * COLOR;
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	sprite.material = material_value
	add_child(sprite)
	return sprite


func _make_plate_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 1.65;
	vec4 source = texture(TEXTURE, UV) * 0.44;
	source += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.14;
	source += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.14;
	source += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.14;
	source += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.14;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float value = clamp(pow(luminance, 0.92) * 1.55, 0.0, 0.86);
	COLOR = vec4(vec3(value), source.a) * COLOR;
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	return material_value


func _make_light(world_position: Vector2, size: Vector2, intensity: float, seed: float) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var white := GradientTexture2D.new()
	white.width = 2
	white.height = 2
	white.gradient = gradient
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = white
	sprite.position = world_position
	sprite.scale = size * 0.5
	sprite.z_index = 0
	var material_value := ShaderMaterial.new()
	material_value.shader = LIGHT_SHADER
	material_value.set_shader_parameter("intensity", intensity)
	material_value.set_shader_parameter("seed", seed)
	material_value.set_shader_parameter("light_tint", Vector3(0.70, 0.70, 0.68))
	sprite.material = material_value
	add_child(sprite)
	return sprite


func _make_soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.26, 0.58, 0.84, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.70),
		Color(1.0, 1.0, 1.0, 0.39),
		Color(1.0, 1.0, 1.0, 0.13),
		Color(1.0, 1.0, 1.0, 0.028),
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


func sync(delta: float, new_camera_x: float, active: bool, water_blocked: bool) -> void:
	visible = active
	if not active:
		return
	clock += delta
	camera_x = new_camera_x
	flow_active = not water_blocked
	var first_blend := smoothstep(390.0, 900.0, camera_x)
	var second_blend := smoothstep(1450.0, 1980.0, camera_x)
	plates[0].modulate.a = 1.0 - first_blend
	plates[1].modulate.a = first_blend * (1.0 - second_blend)
	plates[2].modulate.a = second_blend
	for index in range(plates.size()):
		var drift := -45.0 - camera_x * (0.010 + float(index) * 0.002)
		var vertical_offset := 14.0 if index == 0 else (54.0 if index == 1 else 22.0)
		plates[index].position = Vector2(drift, vertical_offset)
	for index in range(gameplay_plates.size()):
		gameplay_plates[index].position = Vector2(gameplay_world_x[index] - camera_x, gameplay_offset_y[index])
	river_base.position.x = 76.0 - camera_x
	waterfall_base.visible = flow_active
	waterfall_base.position.x = 600.0 - camera_x
	waterfall_light.position.x = 716.0 - camera_x
	lift_light.position.x = 3190.0 - camera_x
	var waterfall_material := waterfall_light.material as ShaderMaterial
	waterfall_material.set_shader_parameter("clock", clock)
	waterfall_material.set_shader_parameter("intensity", 0.21 if flow_active else 0.045)
	var lift_material := lift_light.material as ShaderMaterial
	lift_material.set_shader_parameter("clock", clock)
	lift_material.set_shader_parameter("intensity", 0.07 + sin(clock * 0.71) * 0.006)
	atmosphere.queue_redraw()


func _draw_soft(center: Vector2, size: Vector2, tint: Color) -> void:
	atmosphere.draw_texture_rect(soft_texture, Rect2(center - size * 0.5, size), false, tint)


func _draw_atmosphere() -> void:
	if not visible:
		return
	var entry_x := 180.0 - camera_x
	if entry_x > -320.0 and entry_x < SCREEN.x + 320.0:
		_draw_soft(Vector2(entry_x, 420.0), Vector2(540.0, 450.0), Color(0.70, 0.70, 0.68, 0.42))
	var entry_bank_x := 350.0 - camera_x
	if entry_bank_x > -420.0 and entry_bank_x < SCREEN.x + 420.0:
		_draw_soft(Vector2(entry_bank_x, 505.0), Vector2(760.0, 270.0), Color(0.66, 0.66, 0.64, 0.16))
	var middle_x := 1740.0 - camera_x
	if middle_x > -520.0 and middle_x < SCREEN.x + 520.0:
		_draw_soft(Vector2(middle_x, 405.0), Vector2(940.0, 420.0), Color(0.62, 0.62, 0.60, 0.13))
	var lift_x := 3190.0 - camera_x
	if lift_x > -360.0 and lift_x < SCREEN.x + 360.0:
		_draw_soft(Vector2(lift_x, 370.0), Vector2(470.0, 450.0), Color(0.66, 0.66, 0.64, 0.15))
	var late_route_x := 2690.0 - camera_x
	if late_route_x > -480.0 and late_route_x < SCREEN.x + 480.0:
		_draw_soft(Vector2(late_route_x, 390.0), Vector2(760.0, 410.0), Color(0.61, 0.61, 0.59, 0.13))
	_draw_soft(Vector2(640.0, 610.0), Vector2(1540.0, 190.0), Color(0.50, 0.50, 0.48, 0.13))
	for fog_index in range(5):
		var depth := float(fog_index % 3) / 2.0
		var x := fposmod(float(fog_index) * 357.0 - camera_x * (0.23 + depth * 0.12) + clock * (0.7 + depth), 1910.0) - 315.0
		var y := 420.0 + float(fog_index % 3) * 79.0 + sin(clock * 0.09 + fog_index * 1.8) * 12.0
		_draw_soft(
			Vector2(x, y),
			Vector2(690.0 + depth * 130.0, 118.0 + depth * 28.0),
			Color(0.66, 0.66, 0.64, 0.030 + depth * 0.012)
		)
	for mote_index in range(14):
		var age := fposmod(clock * (0.020 + float(mote_index % 4) * 0.004) + float(mote_index) * 0.191, 1.0)
		var x := fposmod(float(mote_index) * 191.0 - camera_x * 0.43 + age * 27.0, 1460.0) - 90.0
		var y := 610.0 - age * 470.0 + sin(age * TAU + mote_index) * 6.0
		var alpha := sin(age * PI) * (0.012 + float(mote_index % 3) * 0.006)
		atmosphere.draw_circle(Vector2(x, y), 0.65, Color(0.76, 0.76, 0.74, alpha), true, -1.0, true)
