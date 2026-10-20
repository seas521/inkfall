extends Node2D

const SCREEN := Vector2(1280.0, 720.0)
const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/art/level01/cinematic_shaft/background-v1.png")
const RAIN_SHADER: Shader = preload("res://assets/shaders/level01_shaft_rain.gdshader")

var clock := 0.0
var camera_y := 0.0
var background: Sprite2D
var atmosphere: Node2D
var rain_sprite: Sprite2D
var soft_texture: GradientTexture2D

func _ready() -> void:
	soft_texture = _make_soft_texture()
	background = _make_background()
	atmosphere = Node2D.new()
	atmosphere.draw.connect(_draw_atmosphere)
	add_child(atmosphere)
	rain_sprite = _make_rain_sprite()
	hide()

func _make_background() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = BACKGROUND_TEXTURE
	sprite.scale = SCREEN / sprite.texture.get_size()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float value = clamp(pow(luminance, 1.04) * 0.86, 0.0, 0.78);
	float vignette = 1.0 - smoothstep(0.30, 0.72, length((UV - vec2(0.5)) * vec2(0.74, 1.0)));
	value *= mix(0.82, 1.0, vignette);
	COLOR = vec4(vec3(value), source.a) * COLOR;
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	sprite.material = material_value
	add_child(sprite)
	return sprite

func _make_soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.60, 0.84, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.72),
		Color(1.0, 1.0, 1.0, 0.40),
		Color(1.0, 1.0, 1.0, 0.13),
		Color(1.0, 1.0, 1.0, 0.030),
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

func _make_rain_sprite() -> Sprite2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var white := GradientTexture2D.new()
	white.width = 2
	white.height = 2
	white.gradient = gradient
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = white
	sprite.scale = SCREEN * 0.5
	var material_value := ShaderMaterial.new()
	material_value.shader = RAIN_SHADER
	material_value.set_shader_parameter("intensity", 0.20)
	material_value.set_shader_parameter("seed", 5.7)
	sprite.material = material_value
	add_child(sprite)
	return sprite

func sync(delta: float, new_camera_y: float, active: bool) -> void:
	visible = active
	if not active:
		return
	clock += delta
	camera_y = new_camera_y
	var rain_material := rain_sprite.material as ShaderMaterial
	rain_material.set_shader_parameter("clock", clock)
	rain_material.set_shader_parameter("depth", camera_y)
	atmosphere.queue_redraw()

func _draw_soft(center: Vector2, size: Vector2, tint: Color) -> void:
	atmosphere.draw_texture_rect(soft_texture, Rect2(center - size * 0.5, size), false, tint)

func _draw_atmosphere() -> void:
	for fog_index in range(7):
		var depth_ratio := float(fog_index % 3) / 2.0
		var x := fposmod(float(fog_index) * 287.0 - camera_y * (0.04 + depth_ratio * 0.11) + clock * (0.7 + depth_ratio), 1880.0) - 300.0
		var y := 285.0 + float(fog_index % 3) * 126.0 + sin(clock * 0.09 + fog_index * 1.7) * 16.0
		_draw_soft(
			Vector2(x, y),
			Vector2(650.0 + depth_ratio * 180.0, 135.0 + depth_ratio * 42.0),
			Color(0.72, 0.72, 0.72, 0.014 + depth_ratio * 0.010)
		)
	for mote_index in range(34):
		var age := fposmod(clock * (0.018 + float(mote_index % 4) * 0.004) + float(mote_index) * 0.177, 1.0)
		var x := 430.0 + fposmod(float(mote_index) * 93.0 + sin(age * TAU + mote_index) * 9.0, 420.0)
		var y := 690.0 - age * 650.0
		atmosphere.draw_circle(Vector2(x, y), 0.55, Color(0.78, 0.78, 0.78, sin(age * PI) * 0.025), true, -1.0, true)
