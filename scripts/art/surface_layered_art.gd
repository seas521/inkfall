extends Node2D

const SCREEN := Vector2(1280.0, 720.0)
const PLATE_SCALE := 1280.0 / 1672.0
const FOREGROUND_TOP := -64.0
# The generated far plate is already misty: the old fog overlays, made to lift silhouettes off a dark
# plate, would wash it out, so they are kept at a fraction.
const FOG_WASH := 0.34
const FOREGROUND_STRETCH := 0.64
const FOREGROUND_RICH_TOP := -98.0

const FAR_VALLEY: Texture2D = preload("res://assets/art/level01/cinematic_surface/far-vista-v3.jpg")
const MID_RUINS: Texture2D = preload("res://assets/art/level01/cinematic_surface/mid-forest-ruins-v2-magenta.png")
const GAMEPLAY_PLATE: Texture2D = preload("res://assets/art/level01/cinematic_surface/gameplay-cliffs-house-v2-magenta.png")
const YARD_TREE: Texture2D = preload("res://assets/art/level01/cinematic_surface/yard-tree-black.png")
const InkFlame = preload("res://scripts/effects/ink_flame.gd")
const FOREGROUND_LEFT_TREE: Texture2D = preload("res://assets/art/level01/cinematic_surface/foreground-left-tree.png")
const CAMPFIRE: Texture2D = preload("res://assets/art/level01/cinematic_surface/campfire-v3-transparent.png")
const FOREGROUND_RIGHT: Texture2D = preload("res://assets/art/level01/cinematic_surface/foreground-right-black.png")
const MOONLIGHT_SHADER: Shader = preload("res://assets/shaders/level01_moonlight.gdshader")
const FIRELIGHT_SHADER: Shader = preload("res://assets/shaders/level01_firelight.gdshader")

var clock := 0.0
var player_x := 170.0
var right_shift_x := 0.0
var fire_intensity := 0.86
var bat_gust := 0.0

var far_sprite: Sprite2D
var mid_sprite: Sprite2D
var gameplay_sprite: Sprite2D
var tree_sprite: Sprite2D
var cliff_grass: Node2D
var fire_sprite: Sprite2D
var foreground_left_tree: Sprite2D
var foreground_right: Sprite2D
var far_fog: Node2D
var mid_fog: Node2D
var fire_air: Node2D
var foreground_air: Node2D
var moon_light: Sprite2D
var valley_light: Sprite2D
var fire_light: Sprite2D
var soft_texture: GradientTexture2D
var tree_material: ShaderMaterial
var fire_material: ShaderMaterial
var fire_flame: Node2D


func _ready() -> void:
	soft_texture = _make_soft_texture()

	far_sprite = _make_sprite(FAR_VALLEY, 0)
	far_fog = _make_draw_layer(_draw_far_fog, 1)
	mid_sprite = _make_sprite(MID_RUINS, 2)
	# The old ruined-cliff plate doubles up with the vista's own rock layers, so it is not shown.
	mid_sprite.visible = false
	mid_fog = _make_draw_layer(_draw_mid_fog, 3)
	moon_light = _make_light_sprite(MOONLIGHT_SHADER, Vector2(-70.0, 34.0), Vector2(690.0, 570.0), 0.26, 0.7)
	valley_light = _make_light_sprite(MOONLIGHT_SHADER, Vector2(250.0, 118.0), Vector2(800.0, 520.0), 0.12, 2.3)
	fire_light = _make_light_sprite(FIRELIGHT_SHADER, Vector2(920.0, 274.0), Vector2(200.0, 140.0), 0.34)
	gameplay_sprite = _make_sprite(GAMEPLAY_PLATE, 5)
	tree_sprite = _make_sprite(YARD_TREE, 6)
	cliff_grass = _make_draw_layer(_draw_cliff_grass, 7)
	fire_air = _make_draw_layer(_draw_fire_air, 4)
	fire_sprite = _make_sprite(CAMPFIRE, 8)
	# The painted logs and stones stay; the painted flame is cut away and replaced by a living one.
	fire_flame = InkFlame.new() as Node2D
	fire_flame.width = 36.0
	fire_flame.height = 66.0
	fire_flame.seed_value = 11
	fire_flame.glow_scale = 0.38
	fire_flame.z_index = 9
	add_child(fire_flame)
	foreground_right = _make_sprite(FOREGROUND_RIGHT, 12)
	# The left foreground is a big gnarled dead tree with hanging vines and a thicket of ferns and grass:
	# a separate picture with a transparent background, black in the colour channels (only its alpha
	# carries the shape), so it is the same pure black as the cliffs in any renderer. It stands just behind
	# the character.
	foreground_left_tree = _make_sprite(FOREGROUND_LEFT_TREE, 9)
	foreground_air = _make_draw_layer(_draw_foreground_air, 13)

	_configure_layout()
	_configure_materials()


func _make_sprite(texture_value: Texture2D, z_value: int, relative_z: bool = true) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture_value
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = z_value
	sprite.z_as_relative = relative_z
	add_child(sprite)
	return sprite


func _make_draw_layer(callback: Callable, z_value: int, relative_z: bool = true) -> Node2D:
	var layer := Node2D.new()
	layer.z_index = z_value
	layer.z_as_relative = relative_z
	layer.draw.connect(callback)
	add_child(layer)
	return layer


func _make_light_sprite(
	shader_value: Shader,
	position_value: Vector2,
	size_value: Vector2,
	intensity: float,
	seed: float = 0.0
) -> Sprite2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var white_texture := GradientTexture2D.new()
	white_texture.width = 2
	white_texture.height = 2
	white_texture.gradient = gradient

	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = white_texture
	sprite.position = position_value
	sprite.scale = size_value * 0.5
	sprite.z_index = 4
	var material_value := ShaderMaterial.new()
	material_value.shader = shader_value
	material_value.set_shader_parameter("intensity", intensity)
	if shader_value == MOONLIGHT_SHADER:
		material_value.set_shader_parameter("seed", seed)
	sprite.material = material_value
	add_child(sprite)
	return sprite


func _make_soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.60, 0.84, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.76),
		Color(1.0, 1.0, 1.0, 0.44),
		Color(1.0, 1.0, 1.0, 0.16),
		Color(1.0, 1.0, 1.0, 0.04),
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


func _configure_layout() -> void:
	# The vista plate is 1280 x 720; a little oversize so the camera's small parallax never shows an edge.
	far_sprite.position = Vector2(-32.0, -19.0)
	far_sprite.scale = Vector2.ONE * 1.05

	mid_sprite.position = Vector2(-14.0, -8.0)
	mid_sprite.scale = Vector2.ONE * 0.79

	# The authored ledges align with the unchanged collision tops at y=425/375.
	gameplay_sprite.position = Vector2(0.0, 65.0)
	gameplay_sprite.scale = Vector2.ONE * PLATE_SCALE

	var tree_scale := 0.245
	var tree_root_in_source := Vector2(1015.0, 826.0)
	tree_sprite.scale = Vector2.ONE * tree_scale
	tree_sprite.position = Vector2(1232.0, 378.0) - tree_root_in_source * tree_scale

	var fire_scale := 0.18
	var fire_base_in_source := Vector2(838.0, 714.0)
	fire_sprite.scale = Vector2.ONE * fire_scale
	fire_sprite.position = Vector2(1017.0, 378.0) - fire_base_in_source * fire_scale

	var foreground_scale := 0.52
	# The frame's branches are cut by the picture's own top edge, so that edge must never come into
	# view: the sprite starts well above the screen (the camera can lift it by about 40 px) and is a
	# little taller than it is wide, which keeps its bottom where it was, hidden in the black cliffs.
	foreground_right.position = Vector2(1280.0 - 540.0 * foreground_scale + 48.0, FOREGROUND_TOP)
	foreground_right.scale = Vector2(foreground_scale, FOREGROUND_STRETCH)
	foreground_left_tree.position = Vector2(-10.0, FOREGROUND_RICH_TOP)
	foreground_left_tree.scale = Vector2(0.68, 0.80)


func _configure_materials() -> void:
	far_sprite.material = _make_far_material()
	far_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	mid_sprite.material = _make_haze_silhouette_material(2.6, 0.20, 0.58, 0.92)
	gameplay_sprite.material = _make_keyed_material(1.0, 1.0, 0.006, 0.30)

	tree_material = _make_tree_material()
	tree_sprite.material = tree_material
	fire_material = _make_fire_material()
	fire_sprite.material = fire_material


func _make_far_material() -> ShaderMaterial:
	# The far vista is a generated plate (a deep misty gorge under a moon at the upper left). It only
	# needs a gentle grade to sit with the C zone: a hint of soft focus, blacks lifted a little so the
	# rock layers stay readable, and a touch of haze at the bottom.
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	// The plate is slid down and right so the moon sits clear of the screen corner (where the film's
	// vignette would sink it) and of the caption; the sprite mirrors past its edge, so nothing shows.
	vec2 uv = UV - vec2(0.03, 0.11);
	vec2 px = TEXTURE_PIXEL_SIZE * 0.9;
	vec3 c = texture(TEXTURE, uv).rgb * 0.46;
	c += texture(TEXTURE, uv + vec2(px.x, 0.0)).rgb * 0.135;
	c += texture(TEXTURE, uv - vec2(px.x, 0.0)).rgb * 0.135;
	c += texture(TEXTURE, uv + vec2(0.0, px.y)).rgb * 0.135;
	c += texture(TEXTURE, uv - vec2(0.0, px.y)).rgb * 0.135;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float value = 0.07 + lum * 0.93;
	// The moon is near a corner, where the film's vignette would sink it: lift the very bright part.
	value += smoothstep(0.88, 0.99, lum) * 0.16;
	value = mix(value, 0.62, smoothstep(0.80, 1.0, UV.y) * 0.35);
	COLOR = vec4(vec3(clamp(value, 0.0, 0.97)), 1.0);
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	return material_value


func _make_keyed_material(exposure: float, alpha_value: float, black_floor: float, white_ceiling: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float exposure = 1.0;
uniform float layer_alpha = 1.0;
uniform float black_floor = 0.0;
uniform float white_ceiling = 1.0;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float magenta_excess = min(source.r, source.b) - source.g;
	float keyed = smoothstep(0.006, 0.075, magenta_excess);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float shaped = pow(clamp(luminance, 0.0, 1.0), 0.94);
	float value = mix(black_floor, white_ceiling, shaped) * exposure;
	COLOR = vec4(vec3(value), source.a * (1.0 - keyed) * layer_alpha) * COLOR;
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("exposure", exposure)
	material_value.set_shader_parameter("layer_alpha", alpha_value)
	material_value.set_shader_parameter("black_floor", black_floor)
	material_value.set_shader_parameter("white_ceiling", white_ceiling)
	return material_value


# The ruined cliffs seen through haze: a soft blur and a grey range, not black, so they read as
# misty silhouettes like the trees of the C zone and sit clearly behind the black gameplay cliffs.
func _make_haze_silhouette_material(spread: float, low: float, high: float, alpha_value: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float spread = 2.5;
uniform float low = 0.2;
uniform float high = 0.6;
uniform float layer_alpha = 1.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * spread;
	float lum_sum = 0.0;
	float alpha_sum = 0.0;
	float weights = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			vec2 o = vec2(float(i), float(j));
			float w = exp(-dot(o, o) * 0.30);
			vec4 c = texture(TEXTURE, UV + o * px);
			float magenta_excess = min(c.r, c.b) - c.g;
			float a = c.a * (1.0 - smoothstep(0.006, 0.075, magenta_excess));
			lum_sum += dot(c.rgb, vec3(0.299, 0.587, 0.114)) * a * w;
			alpha_sum += a * w;
			weights += w;
		}
	}
	float a_out = alpha_sum / weights;
	float lum = lum_sum / max(alpha_sum, 0.0001);
	float value = mix(low, high, clamp(pow(lum, 0.8), 0.0, 1.0));
	COLOR = vec4(vec3(value), a_out * layer_alpha);
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("spread", spread)
	material_value.set_shader_parameter("low", low)
	material_value.set_shader_parameter("high", high)
	material_value.set_shader_parameter("layer_alpha", alpha_value)
	return material_value


func _make_tree_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float clock = 0.0;
void fragment() {
	float upper = 1.0 - smoothstep(0.16, 0.86, UV.y);
	float crown = upper * upper;
	vec2 sample_uv = UV;
	sample_uv.x -= (
		sin(clock * 0.68 + UV.y * 4.0) * 0.018
		+ sin(clock * 1.27 + UV.y * 9.0 + 1.8) * 0.006
		+ sin(clock * 2.05 - UV.y * 15.0 + 0.4) * 0.0025
	) * crown;
	// The picture is already a black silhouette with a transparent background.
	vec4 source = texture(TEXTURE, sample_uv);
	COLOR = vec4(0.0, 0.0, 0.0, source.a);
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	return material_value


func _make_fire_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float clock = 0.0;
uniform float intensity = 0.86;
void fragment() {
	float flame_region = 1.0 - smoothstep(0.54, 0.70, UV.y);
	float center_mask = 1.0 - smoothstep(0.09, 0.22, abs(UV.x - 0.5));
	float free_flame = flame_region * center_mask;
	vec2 sample_uv = UV;
	float height_pulse = (
		sin(clock * 2.35 + 0.5) * 0.050
		+ sin(clock * 5.20 + 2.1) * 0.018
	);
	sample_uv.y += height_pulse * max(0.0, 0.70 - UV.y) * free_flame;
	sample_uv.x -= (
		sin(clock * 1.85 + UV.y * 14.0) * 0.022
		+ sin(clock * 3.90 - UV.y * 29.0 + 0.7) * 0.008
		+ sin(clock * 7.10 + UV.y * 47.0) * 0.003
	) * free_flame;
	sample_uv.y += (
		sin(clock * 2.70 + UV.x * 19.0) * 0.006
		+ sin(clock * 6.10 - UV.x * 31.0) * 0.0025
	) * free_flame;
	sample_uv = clamp(sample_uv, vec2(0.0), vec2(1.0));
	vec4 source = texture(TEXTURE, sample_uv);
	vec2 soft_px = TEXTURE_PIXEL_SIZE * 3.0;
	vec4 softened = source * 0.52;
	softened += texture(TEXTURE, sample_uv + vec2(soft_px.x, 0.0)) * 0.12;
	softened += texture(TEXTURE, sample_uv - vec2(soft_px.x, 0.0)) * 0.12;
	softened += texture(TEXTURE, sample_uv + vec2(0.0, soft_px.y)) * 0.12;
	softened += texture(TEXTURE, sample_uv - vec2(0.0, soft_px.y)) * 0.12;
	source = mix(source, softened, free_flame * 0.68);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float local_flicker = (
		0.90
		+ sin(clock * 4.30 + UV.y * 23.0) * 0.065
		+ sin(clock * 8.10 - UV.x * 17.0) * 0.025
	);
	float flame_lift = free_flame * (0.08 + intensity * 0.055);
	float value = clamp(
		pow(luminance, 0.92) * (0.62 + intensity * 0.27) * mix(1.0, local_flicker, free_flame)
		+ flame_lift,
		0.0,
		0.98
	);
	float alpha_flicker = mix(1.0, 0.89 + local_flicker * 0.11, free_flame * 0.72);
	float logs_only = smoothstep(0.585, 0.640, UV.y);
	COLOR = vec4(vec3(value), source.a * alpha_flicker * logs_only) * COLOR;
}"""
	var material_value := ShaderMaterial.new()
	material_value.shader = shader
	return material_value


func sync(
	delta: float,
	player_world_x: float,
	camera_y: float,
	active: bool,
	bat_gust_strength: float = 0.0
) -> void:
	visible = active
	if not active:
		return

	clock += delta
	player_x = player_world_x
	bat_gust = clampf(bat_gust_strength, 0.0, 1.0)

	fire_intensity = lerpf(
		fire_intensity,
		0.84 + sin(clock * 1.07) * 0.070 + sin(clock * 3.13 + 0.7) * 0.032,
		1.0 - exp(-5.0 * delta)
	)
	tree_material.set_shader_parameter("clock", clock)
	fire_material.set_shader_parameter("clock", clock)
	fire_material.set_shader_parameter("intensity", fire_intensity)
	(far_sprite.material as ShaderMaterial).set_shader_parameter("clock", clock)
	(moon_light.material as ShaderMaterial).set_shader_parameter("clock", clock)
	(valley_light.material as ShaderMaterial).set_shader_parameter("clock", clock)
	(fire_light.material as ShaderMaterial).set_shader_parameter("clock", clock)
	(fire_light.material as ShaderMaterial).set_shader_parameter("intensity", 0.31 + fire_intensity * 0.05)

	far_sprite.position = Vector2(-32.0, -19.0 - camera_y * 0.06)
	far_fog.position = Vector2(0.0, -camera_y * 0.10)
	mid_sprite.position = Vector2(-14.0, -8.0 - camera_y * 0.28)
	mid_fog.position = Vector2(0.0, -camera_y * 0.46)
	moon_light.position = Vector2(-70.0, 34.0 - camera_y * 0.16)
	valley_light.position = Vector2(250.0, 118.0 - camera_y * 0.32)
	fire_light.position = Vector2(920.0, 274.0 - camera_y)

	gameplay_sprite.position = Vector2(0.0, 65.0 - camera_y)
	tree_sprite.position.y = 378.0 - 826.0 * 0.245 - camera_y
	fire_sprite.position.y = 378.0 - 714.0 * 0.18 - camera_y
	fire_flame.position = Vector2(1017.0, 361.0 - camera_y)
	fire_air.position = Vector2(0.0, -camera_y)
	cliff_grass.position = Vector2(0.0, -camera_y)

	foreground_right.position.y = FOREGROUND_TOP - camera_y * 1.04
	foreground_left_tree.position.y = FOREGROUND_RICH_TOP - camera_y * 1.0
	foreground_air.position = Vector2(0.0, -camera_y * 1.12)

	far_fog.queue_redraw()
	mid_fog.queue_redraw()
	fire_air.queue_redraw()
	cliff_grass.queue_redraw()
	foreground_air.queue_redraw()


func _draw_soft(canvas: Node2D, center: Vector2, size: Vector2, tint: Color) -> void:
	canvas.draw_texture_rect(soft_texture, Rect2(center - size * 0.5, size), false, tint)


func _draw_far_fog() -> void:
	# Broad moon haze separates the player and yard silhouettes without
	# introducing a directional spotlight.
	_draw_soft(far_fog, Vector2(225.0, 355.0), Vector2(540.0, 340.0), Color(0.78, 0.78, 0.78, (0.24) * FOG_WASH))
	_draw_soft(far_fog, Vector2(690.0, 330.0), Vector2(820.0, 390.0), Color(0.60, 0.60, 0.60, (0.18) * FOG_WASH))
	_draw_soft(far_fog, Vector2(1120.0, 300.0), Vector2(500.0, 350.0), Color(0.70, 0.70, 0.70, (0.20) * FOG_WASH))
	for fog_index in range(7):
		var depth := float(fog_index % 3) / 2.0
		var x := fposmod(float(fog_index) * 276.0 + clock * (1.0 + depth * 1.2), 1830.0) - 310.0
		var y := 318.0 + float(fog_index % 4) * 88.0 + sin(clock * 0.12 + fog_index * 1.6) * 13.0
		_draw_soft(far_fog, Vector2(x, y), Vector2(620.0, 142.0), Color(0.70, 0.70, 0.70, (0.055 + depth * 0.018) * FOG_WASH))


func _draw_mid_fog() -> void:
	# This is the gameplay readability band: broad air exposure, not a cone or
	# character halo. It keeps the black actor readable across both ledges.
	_draw_soft(mid_fog, Vector2(250.0, 330.0), Vector2(650.0, 370.0), Color(0.78, 0.78, 0.78, (0.46) * FOG_WASH))
	_draw_soft(mid_fog, Vector2(675.0, 340.0), Vector2(820.0, 410.0), Color(0.68, 0.68, 0.68, (0.34) * FOG_WASH))
	_draw_soft(mid_fog, Vector2(1090.0, 300.0), Vector2(580.0, 365.0), Color(0.74, 0.74, 0.74, (0.38) * FOG_WASH))

	for fog_index in range(6):
		var x := fposmod(float(fog_index) * 340.0 - clock * (2.0 + float(fog_index % 2)), 1940.0) - 330.0
		var y := 405.0 + float(fog_index % 3) * 76.0
		_draw_soft(mid_fog, Vector2(x, y), Vector2(650.0, 150.0), Color(0.72, 0.72, 0.72, (0.085) * FOG_WASH))

	for veil_index in range(4):
		var center := Vector2(
			500.0 + float(veil_index) * 105.0 + sin(clock * 0.10 + veil_index) * 22.0,
			505.0 + float(veil_index) * 44.0
		)
		_draw_soft(mid_fog, center, Vector2(430.0, 230.0), Color(0.0, 0.0, 0.0, 0.025))


func _draw_fire_air() -> void:
	var origin := Vector2(1017.0, 375.0)
	var pulse := fire_intensity
	_draw_soft(fire_air, origin + Vector2(0.0, -30.0), Vector2(96.0, 72.0), Color(0.72, 0.72, 0.72, 0.030 * pulse))
	_draw_soft(fire_air, origin + Vector2(0.0, -17.0), Vector2(60.0, 50.0), Color(0.86, 0.86, 0.86, 0.045 * pulse))


func _draw_cliff_grass() -> void:
	# The painted ledge crest sits below the collision line; bury the roots
	# inside the dark soil so swaying blades never appear detached.
	var root_y := 431.0
	for blade_index in range(15):
		var depth := float(blade_index % 4) / 3.0
		var base := Vector2(443.0 + float(blade_index) * 2.55, root_y)
		var height := 19.0 + float((blade_index * 7) % 19)
		var ambient := sin(
			clock * (0.72 + depth * 0.18) + float(blade_index) * 0.61
		) * (1.4 + depth * 1.3)
		var gust_flutter := 0.78 + sin(
			clock * 10.5 + float(blade_index) * 0.87
		) * 0.22
		var gust_lean := bat_gust * (12.0 + depth * 9.0) * gust_flutter
		var lean := ambient - gust_lean
		var width := 1.2 + depth * 1.25
		var midpoint := base + Vector2(lean * 0.38, -height * 0.48)
		var tip := base + Vector2(lean, -height)
		var blade := PackedVector2Array([
			base + Vector2(-width, 3.0),
			base + Vector2(width, 3.0),
			midpoint + Vector2(width * 0.45, 0.0),
			tip,
			midpoint + Vector2(-width * 0.45, 0.0),
		])
		cliff_grass.draw_colored_polygon(blade, Color(0.0, 0.0, 0.0, 1.0))


func _draw_foreground_air() -> void:
	# A broad lens veil softens the near silhouettes without creating a
	# readable spotlight. Edge fog partially eats nearby silhouettes.
	_draw_soft(foreground_air, Vector2(-65.0, 365.0), Vector2(650.0, 790.0), Color(0.66, 0.66, 0.65, 0.042))
	_draw_soft(foreground_air, Vector2(1345.0, 375.0), Vector2(670.0, 800.0), Color(0.64, 0.64, 0.63, 0.044))
	_draw_soft(foreground_air, Vector2(640.0, -55.0), Vector2(1320.0, 290.0), Color(0.62, 0.62, 0.61, 0.024))
	_draw_soft(foreground_air, Vector2(640.0, 365.0), Vector2(1460.0, 790.0), Color(0.68, 0.68, 0.68, 0.035))
	_draw_soft(foreground_air, Vector2(185.0, 380.0), Vector2(560.0, 610.0), Color(0.54, 0.54, 0.54, 0.026))
	_draw_soft(foreground_air, Vector2(1110.0, 390.0), Vector2(590.0, 620.0), Color(0.56, 0.56, 0.56, 0.028))
	_draw_soft(foreground_air, Vector2(640.0, 700.0), Vector2(1120.0, 220.0), Color(0.48, 0.48, 0.48, 0.020))

	for dust_index in range(68):
		var depth := float(dust_index % 4) / 3.0
		var age := fposmod(clock * (0.024 + float(dust_index % 5) * 0.004) + float(dust_index) * 0.171, 1.0)
		var x := fposmod(float(dust_index) * 119.0 + age * (10.0 + depth * 31.0), 1390.0) - 55.0
		var y := 650.0 - age * 575.0 + sin(age * TAU + dust_index) * (4.0 + depth * 8.0)
		var alpha := sin(age * PI) * (0.010 + depth * 0.030)
		var radius := 0.55 + depth * 1.25
		foreground_air.draw_circle(Vector2(x, y), radius, Color(0.78, 0.78, 0.78, alpha), true, -1.0, true)

	var frame_seed := int(clock * 15.0)
	for grain_index in range(118):
		var x := fposmod(float(grain_index * 79 + frame_seed * 31), SCREEN.x)
		var y := fposmod(float(grain_index * 137 + frame_seed * 53), SCREEN.y)
		var value := 0.30 if (grain_index + frame_seed) % 4 == 0 else 0.0
		foreground_air.draw_circle(Vector2(x, y), 0.45, Color(value, value, value, 0.007), true, -1.0, false)
