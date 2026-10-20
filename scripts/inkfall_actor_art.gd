extends Sprite2D

const ATLAS: Texture2D = preload("res://assets/art/level01/witch-starlight-key-v1.png")
const REGIONS: Array[Rect2] = [
	Rect2(35,20,240,385), Rect2(344,20,262,385), Rect2(644,20,274,385), Rect2(948,20,265,385),
	Rect2(35,425,242,325), Rect2(340,445,274,351), Rect2(640,542,280,254), Rect2(968,468,245,328),
	Rect2(32,850,295,342), Rect2(354,837,251,344), Rect2(624,875,267,260), Rect2(919,947,295,210),
]
const ROOTS: Array[Vector2] = [
	Vector2(162,388), Vector2(487,388), Vector2(800,388), Vector2(1111,388),
	Vector2(161,739), Vector2(503,783), Vector2(797,783), Vector2(1091,783),
	Vector2(179,1020), Vector2(480,1010), Vector2(760,1005), Vector2(1068,1050),
]
var previous_ground: bool = false
var previous_held: int = -1
var previous_room: int = -1
var action_time: float = 0.0
var stride: float = 0.0
var clock_time: float = 0.0
var idle_wait_time: float = 0.0
var idle_action_time: float = 0.0
var aura: Sprite2D
var mist_aura: Sprite2D
var stars: Node2D
var idle_soul_mote: Sprite2D
var pose_material: ShaderMaterial

func _ready() -> void:
	centered = false
	region_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture = ATLAS
	var shader: Shader = Shader.new()
	shader.code = """shader_type canvas_item;
uniform float impact = 0.0;
uniform float opacity = 1.0;
uniform float idle_motion = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

vec4 key_sample(vec4 source) {
	float green = max(0.0, source.g - max(source.r, source.b));
	source.a *= 1.0 - smoothstep(0.10, 0.38, green);
	source.g = min(source.g, max(source.r, source.b) + 0.025);
	return source;
}

void fragment() {
	vec2 sample_uv = UV;
	float upper_freedom = 1.0 - smoothstep(0.08, 0.235, UV.y);
	sample_uv.x += sin(TIME * 2.15 + UV.y * 30.0) * 0.005 * upper_freedom * idle_motion;
	vec2 blur_px = TEXTURE_PIXEL_SIZE * 3.5;
	vec4 center = key_sample(texture(TEXTURE, sample_uv));
	vec4 left = key_sample(texture(TEXTURE, sample_uv - vec2(blur_px.x, 0.0)));
	vec4 right = key_sample(texture(TEXTURE, sample_uv + vec2(blur_px.x, 0.0)));
	vec4 up = key_sample(texture(TEXTURE, sample_uv - vec2(0.0, blur_px.y)));
	vec4 down = key_sample(texture(TEXTURE, sample_uv + vec2(0.0, blur_px.y)));
	float soft_alpha = center.a * 0.48 + (left.a + right.a + up.a + down.a) * 0.13;
	vec3 soft_rgb = (
		center.rgb * center.a * 0.48
		+ left.rgb * left.a * 0.13
		+ right.rgb * right.a * 0.13
		+ up.rgb * up.a * 0.13
		+ down.rgb * down.a * 0.13
	) / max(soft_alpha, 0.001);
	vec4 c = vec4(soft_rgb, soft_alpha);

	float luminance = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float fabric_mask = smoothstep(0.025, 0.10, luminance) * (1.0 - smoothstep(0.32, 0.56, luminance));
	float spirit_current = 0.5 + 0.5 * sin(UV.y * 29.0 - TIME * 1.35 + UV.x * 8.0);
	float fire_influence = smoothstep(0.60, 0.92, SCREEN_UV.x);

	vec3 pale_body = vec3(luminance) * vec3(0.91, 0.93, 0.96);
	c.rgb = mix(c.rgb, pale_body, 0.68);
	vec3 moon_fabric = mix(
		vec3(0.20, 0.22, 0.25),
		vec3(0.78, 0.80, 0.82),
		0.25 + spirit_current * 0.38
	);
	vec3 eclipse_plum = mix(
		vec3(0.18, 0.055, 0.14),
		vec3(0.62, 0.25, 0.44),
		0.22 + spirit_current * 0.48
	);
	moon_fabric = mix(
		moon_fabric,
		eclipse_plum,
		0.74 + fire_influence * 0.10
	);
	c.rgb = mix(c.rgb, moon_fabric, fabric_mask * 0.88);
	vec2 refract_offset = vec2(
		sin(UV.y * 24.0 + TIME * 0.54),
		cos(UV.x * 19.0 - TIME * 0.43)
	) * SCREEN_PIXEL_SIZE * 1.4 * fabric_mask;
	vec3 scene_behind = textureLod(screen_texture, SCREEN_UV + refract_offset, 1.6).rgb;
	c.rgb = mix(c.rgb, scene_behind * 0.88 + vec3(0.045), fabric_mask * 0.34);
	float inner_edge = max(0.0, center.a - min(min(left.a, right.a), min(up.a, down.a)));
	vec3 edge_light = mix(vec3(0.88, 0.76, 0.70), vec3(1.0, 0.78, 0.43), fire_influence);
	c.rgb += edge_light * inner_edge * 0.34;
	float veil = 0.5 + 0.5 * sin(UV.y * 18.0 - TIME * 0.72 + UV.x * 13.0);
	c.rgb = mix(c.rgb, vec3(0.74, 0.77, 0.82), veil * 0.055);
	c.rgb = mix(c.rgb, vec3(1.0, 0.76, 0.38), impact);

	float fabric_transparency = mix(1.0, 0.48, fabric_mask);
	float spectral_breathe = 0.96 + sin(TIME * 1.25 + UV.y * 8.0) * 0.025;
	c.a *= opacity * fabric_transparency * spectral_breathe;
	COLOR = c;
}"""
	pose_material = ShaderMaterial.new()
	pose_material.shader = shader
	material = pose_material
	aura = Sprite2D.new()
	aura.show_behind_parent = true
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	ramp.colors = PackedColorArray([Color(0.92,0.94,0.98,0.28), Color(0.78,0.81,0.86,0.14), Color(0.56,0.60,0.67,0.035), Color(0,0,0,0)])
	var glow: GradientTexture2D = GradientTexture2D.new()
	glow.width = 128
	glow.height = 128
	glow.gradient = ramp
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5,0.5)
	glow.fill_to = Vector2(1,0.5)
	aura.texture = glow
	aura.visible = true
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var aura_shader := Shader.new()
	aura_shader.code = """shader_type canvas_item;
render_mode blend_add;
void fragment() {
	vec2 uv = UV;
	float freedom = 1.0 - smoothstep(0.62, 0.98, UV.y);
	uv.x += sin(UV.y * 11.0 + TIME * 0.62) * 0.018 * freedom;
	uv.y += sin(UV.x * 9.0 - TIME * 0.48) * 0.010;
	vec4 glow_sample = texture(TEXTURE, uv);
	float uneven = 0.68 + sin(UV.y * 17.0 + UV.x * 13.0 + TIME * 0.74) * 0.20;
	glow_sample.a *= uneven;
	COLOR = glow_sample * COLOR;
}"""
	var aura_material := ShaderMaterial.new()
	aura_material.shader = aura_shader
	aura.material = aura_material
	add_child(aura)
	mist_aura = Sprite2D.new()
	mist_aura.show_behind_parent = true
	mist_aura.texture = glow
	mist_aura.z_index = -2
	mist_aura.visible = false
	add_child(mist_aura)
	stars = Node2D.new()
	stars.material = additive
	stars.draw.connect(_draw_stars)
	add_child(stars)
	idle_soul_mote = Sprite2D.new()
	idle_soul_mote.texture = glow
	idle_soul_mote.material = additive
	idle_soul_mote.scale = Vector2.ONE * 0.18
	idle_soul_mote.visible = false
	idle_soul_mote.z_index = 2
	add_child(idle_soul_mote)

func _draw_stars() -> void:
	for i in range(7):
		var phase: float = fposmod(clock_time * (0.26 + i * 0.019) + i * 0.173, 1.0)
		var shine: float = pow(sin(phase * PI), 5.0)
		var point: Vector2 = Vector2(sin(i * 8.37) * 27.0 + sin(clock_time + i) * 2.0, 20.0 - phase * 59.0)
		var size: float = 0.7 + shine * 1.7
		var color: Color = Color(0.76,0.85,1.0,shine * 0.8)
		stars.draw_line(point - Vector2(size,0), point + Vector2(size,0), color, 0.8, true)
		stars.draw_line(point - Vector2(0,size*1.5), point + Vector2(0,size*1.5), color, 0.8, true)

func sync_pose(delta: float, feet: Vector2, velocity: Vector2, grounded: bool, facing: float, held: int, aiming: bool, current_room: int, active: bool, failure_time: float = 0.0, failure_duration: float = 0.82) -> void:
	visible = active
	if not active:
		previous_room = -1
		return
	clock_time += delta
	if previous_room != current_room:
		action_time = 0.0
		idle_wait_time = 0.0
		idle_action_time = 0.0
		previous_ground = grounded
		previous_held = held
		previous_room = current_room
	action_time = maxf(0.0, action_time - delta)
	var frame: int = 0
	var fade: float = 0.86
	var dying: bool = failure_time > 0.0
	var can_idle: bool = grounded and absf(velocity.x) <= 25.0 and held < 0 and not aiming and not dying and action_time <= 0.0
	if can_idle:
		if idle_action_time > 0.0:
			idle_action_time = maxf(0.0, idle_action_time - delta)
		else:
			idle_wait_time += delta
			if idle_wait_time >= 4.0:
				idle_action_time = 1.65
				idle_wait_time = 0.0
	else:
		idle_wait_time = 0.0
		idle_action_time = 0.0
	if dying:
		# Failure has priority over holding, throwing, landing and normal falling.
		var progress: float = clampf(failure_time / maxf(0.01, failure_duration), 0.0, 1.0)
		frame = 8 + (0 if progress < 0.16 else (1 if progress < 0.38 else (2 if progress < 0.68 else 3)))
		fade = 0.86 * (1.0 - smoothstep(0.78, 1.0, progress))
		action_time = 0.0
		pose_material.set_shader_parameter("impact", (1.0 - smoothstep(0.0,0.11,failure_time)) * 0.9)
	else:
		pose_material.set_shader_parameter("impact", 0.0)
		if grounded and not previous_ground:
			action_time = 0.12
		if held < 0 and previous_held >= 0:
			action_time = 0.10
		stride += absf(velocity.x) * delta / 27.0
		if held >= 0:
			frame = 7
		elif action_time > 0.0 and grounded:
			frame = 6
		elif not grounded:
			frame = 4 if velocity.y < -40.0 else 5
		elif absf(velocity.x) > 25.0:
			frame = 1 + int(stride) % 3
	previous_ground = grounded
	previous_held = held
	pose_material.set_shader_parameter("opacity", fade)
	region_rect = REGIONS[frame]
	var factor: float = 67.0 / 354.0
	scale = Vector2(factor * facing, factor)
	var anchor: Vector2 = feet + (Vector2(0,-30) if dying else Vector2.ZERO)
	position = anchor + (REGIONS[frame].position - ROOTS[frame]) * scale
	rotation = -0.05 * facing if aiming and not dying else 0.0
	aura.position = (feet + Vector2(0,-31) - position) / scale
	aura.scale = Vector2(92.0/128.0,112.0/128.0) / scale
	mist_aura.position = aura.position + Vector2(sin(clock_time * 0.46) * 3.0, cos(clock_time * 0.38) * 2.0) / scale
	mist_aura.scale = Vector2(146.0/128.0,164.0/128.0) / scale
	var idle_action_progress: float = 1.0 - idle_action_time / 1.65
	var mote_envelope: float = smoothstep(0.10, 0.32, idle_action_progress) * (1.0 - smoothstep(0.66, 0.92, idle_action_progress))
	pose_material.set_shader_parameter("idle_motion", mote_envelope)
	var idle_aura: float = mote_envelope * 0.045 if idle_action_time > 0.0 else 0.0
	aura.modulate.a = minf(1.0, fade * (0.94 + sin(clock_time * 1.35) * 0.08 + idle_aura)) * 0.34
	mist_aura.modulate = Color(0.88, 0.86, 0.80, fade * (0.15 + sin(clock_time * 0.72) * 0.025))
	idle_soul_mote.visible = frame == 0 and idle_action_time > 0.0 and mote_envelope > 0.01
	idle_soul_mote.position = Vector2(190.0, 205.0) + Vector2(cos(clock_time * 2.4) * 3.0, sin(clock_time * 2.8) * 4.0)
	idle_soul_mote.modulate = Color(0.62, 0.80, 1.0, mote_envelope * fade * 0.58)
	stars.position = aura.position
	stars.scale = Vector2.ONE / scale
	stars.modulate.a = fade
	stars.queue_redraw()
