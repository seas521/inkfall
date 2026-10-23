extends Node2D

# A shallow pond with the same water as the river (the refracting, reflecting, glinting surface), a swell that runs when something
# disturbs it (damped, it fades by itself), splashes and rings when he steps in, and wake ripples while he wades. Pure ground-level water:
# the dip in the ground is drawn by the ink stage; this node draws the water in it.
#
# setup(x0, x1, surface_y, bed_fn): the pond spans x0..x1; its surface is at surface_y; bed_fn(x) is the ground's height under it.

const WAVE_DX := 4.0
const WAVE_SPEED := 150.0
const WAVE_DAMP := 2.4
const WAVE_LEAK := 1.6
const WAVE_MAX := 9.0

const SHADER_CODE := """shader_type canvas_item;
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D waves : repeat_disable, filter_linear;
uniform sampler2D bed_height : repeat_disable, filter_linear;
uniform float x0 = 0.0;
uniform float span = 100.0;
uniform float cells = 25.0;
uniform float water_y = 0.0;
uniform float clock = 0.0;
varying vec2 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec2 wave_uv = vec2(((world_position.x - x0) / 4.0 + 0.5) / cells, 0.5);
	float swell = texture(waves, wave_uv).r;
	float swell_slope = (texture(waves, wave_uv + vec2(1.0 / cells, 0.0)).r - texture(waves, wave_uv - vec2(1.0 / cells, 0.0)).r) / 8.0;
	float wave = sin(world_position.x * 0.05 + clock * 1.5) * 0.45 - swell;
	float depth = world_position.y - water_y - wave;
	if (depth < 0.0) { discard; }
	float bed = texture(bed_height, vec2((world_position.x - x0) / span, 0.5)).r;
	float clearance = bed - world_position.y;
	if (clearance <= 0.0) { discard; }
	float edge_aa = smoothstep(0.0, 9.0, clearance);  // the water thins out into the bank, no hard edge
	float distortion = sin(world_position.y * 0.18 + clock * 2.1) * 0.35 + sin(world_position.x * 0.09 - clock * 1.3) * 0.15;
	distortion *= smoothstep(0.0, 3.0, clearance);
	vec2 bend = vec2(distortion + swell_slope * 30.0 * exp(-depth / 12.0), swell_slope * 7.0 * exp(-depth / 8.0));
	vec2 refract_uv = SCREEN_UV + bend * SCREEN_PIXEL_SIZE * smoothstep(0.0, 6.0, depth);
	vec3 submerged = texture(scene_color, refract_uv).rgb;
	float bed_depth = max(bed - water_y, 3.0);
	float frac = clamp(depth / bed_depth, 0.0, 1.0);
	float tone = mix(0.42, 0.10, frac);
	vec3 water = mix(vec3(tone), submerged * 0.80, mix(0.88, 0.62, smoothstep(0.0, 14.0, depth)));
	float world_pixel = SCREEN_PIXEL_SIZE.y / max(fwidth(world_position.y), 0.001);
	vec2 reflected_uv = vec2(refract_uv.x, SCREEN_UV.y - (depth * 2.0 + wave) * world_pixel);
	vec3 reflected = texture(scene_color, clamp(reflected_uv, vec2(0.0), vec2(1.0))).rgb;
	water = mix(water, reflected, 0.16 * exp(-depth / 10.0));
	water *= mix(1.0, 0.5, frac);
	float band = (1.0 - smoothstep(0.0, 2.4, depth)) * (0.14 + 0.05 * sin(world_position.x * 0.021 + clock * 0.6));
	band *= 1.0 + abs(swell_slope) * 7.0 + abs(swell) * 0.2;
	water = mix(water, vec3(0.66), clamp(band, 0.0, 0.7));
	water += vec3(0.24) * clamp(abs(swell_slope) * 2.4, 0.0, 0.45) * (1.0 - smoothstep(0.0, 8.0, depth));
	COLOR = vec4(water, edge_aa);
}"""

var level: Node2D
var x_start := 0.0
var x_end := 0.0
var surface_y := 0.0
var cells := 0
var wave_h := PackedFloat32Array()
var wave_v := PackedFloat32Array()
var wave_damp := PackedFloat32Array()
var wave_kicks: Array[Dictionary] = []
var wave_texture: ImageTexture
var material_value: ShaderMaterial
var polygon: Polygon2D
var splash_layer: Node2D
var impacts: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var inside := false
var wade_clock := 0.0
var clock := 0.0

func setup(new_level: Node2D, x0: float, x1: float, y: float, bed_fn: Callable, depth: float) -> void:
	level = new_level
	x_start = x0
	x_end = x1
	surface_y = y
	rng.seed = int(x0)
	cells = int((x1 - x0) / WAVE_DX) + 3
	wave_h.resize(cells)
	wave_v.resize(cells)
	wave_damp.resize(cells)
	for i in cells:
		var x := x0 + float(i) * WAVE_DX
		var shore := minf(x - x0, x1 - x)
		wave_damp[i] = WAVE_DAMP + 4.0 * (1.0 - smoothstep(0.0, 36.0, shore))
	var beds := Image.create(cells, 1, false, Image.FORMAT_RF)
	for i in cells:
		beds.set_pixel(i, 0, Color(float(bed_fn.call(x0 + float(i) * WAVE_DX)), 0.0, 0.0, 1.0))
	wave_texture = ImageTexture.create_from_image(Image.create_from_data(cells, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))
	var shader := Shader.new()
	shader.code = SHADER_CODE
	material_value = ShaderMaterial.new()
	material_value.shader = shader
	material_value.set_shader_parameter("waves", wave_texture)
	material_value.set_shader_parameter("bed_height", ImageTexture.create_from_image(beds))
	material_value.set_shader_parameter("x0", x0)
	material_value.set_shader_parameter("span", float(cells) * WAVE_DX)
	material_value.set_shader_parameter("cells", float(cells))
	material_value.set_shader_parameter("water_y", y)
	polygon = Polygon2D.new()
	polygon.z_index = 8
	polygon.polygon = PackedVector2Array([Vector2(x0 - 8.0, y - 14.0), Vector2(x1 + 8.0, y - 14.0), Vector2(x1 + 8.0, y + depth + 40.0), Vector2(x0 - 8.0, y + depth + 40.0)])
	polygon.material = material_value
	add_child(polygon)
	splash_layer = Node2D.new()
	splash_layer.z_index = 9
	splash_layer.draw.connect(_draw_splashes)
	add_child(splash_layer)

func disturb(x: float, impulse: float, width: float) -> void:
	var centre := (x - x_start) / WAVE_DX
	var reach := int(ceil(width * 2.2 / WAVE_DX))
	for i in range(maxi(1, int(centre) - reach), mini(cells - 1, int(centre) + reach + 1)):
		var d := (float(i) - centre) * WAVE_DX / width
		wave_v[i] += impulse * exp(-d * d)

func disturb_later(x: float, impulse: float, width: float, delay: float) -> void:
	wave_kicks.append({"x": x, "impulse": impulse, "width": width, "delay": delay})

# Something goes into the water at x with `speed` (px/s, downwards): the same hit as in the river, at the pond's scale.
func splash(x: float, speed: float, size: float) -> void:
	var strength := clampf(0.35 + speed / 520.0, 0.35, 1.0)
	impacts.append({"x": x, "age": 0.0, "strength": strength, "spread": clampf(size, 8.0, 34.0)})
	var width := clampf(size * 0.55 + 4.0, 7.0, 20.0)
	var push := 12.0 + 38.0 * strength
	disturb(x, -push, width)
	disturb_later(x, push * 0.6, width * 0.7, 0.14)
	disturb_later(x, -push * 0.25, width * 0.9, 0.36)
	if impacts.size() > 6:
		impacts.pop_front()

func _step_waves(delta: float) -> void:
	for k in range(wave_kicks.size() - 1, -1, -1):
		wave_kicks[k].delay = float(wave_kicks[k].delay) - delta
		if float(wave_kicks[k].delay) <= 0.0:
			disturb(float(wave_kicks[k].x), float(wave_kicks[k].impulse), float(wave_kicks[k].width))
			wave_kicks.remove_at(k)
	var steps := clampi(int(ceil(delta * 120.0)), 1, 5)
	var dt := minf(delta, 0.05) / float(steps)
	var c2 := WAVE_SPEED * WAVE_SPEED / (WAVE_DX * WAVE_DX)
	for step in steps:
		for i in range(1, cells - 1):
			wave_v[i] += (c2 * (wave_h[i - 1] + wave_h[i + 1] - 2.0 * wave_h[i]) - wave_damp[i] * wave_v[i]) * dt
		for i in range(1, cells - 1):
			wave_h[i] = clampf((wave_h[i] + wave_v[i] * dt) * (1.0 - WAVE_LEAK * dt), -WAVE_MAX, WAVE_MAX)
	wave_texture.update(Image.create_from_data(cells, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))

# Called every frame with the boy's feet and velocity.
func update(delta: float, feet: Vector2, velocity: Vector2, previous_feet_y: float) -> void:
	clock += delta
	material_value.set_shader_parameter("clock", clock)
	var in_range := feet.x > x_start + 6.0 and feet.x < x_end - 6.0
	var wet := in_range and feet.y > surface_y + 3.0
	if wet and not inside:
		splash(feet.x, maxf(0.0, (feet.y - previous_feet_y) / maxf(delta, 0.001)), 14.0)
	elif not wet and inside and in_range:
		splash(feet.x, 90.0, 9.0)  # stepping out
	inside = wet
	if wet and absf(velocity.x) > 20.0:
		wade_clock += delta
		if wade_clock > 0.16:
			wade_clock = 0.0
			disturb(feet.x - signf(velocity.x) * 14.0, -absf(velocity.x) * 0.09, 8.0)
			impacts.append({"x": feet.x - signf(velocity.x) * 10.0, "age": 0.0, "strength": 0.3, "spread": 7.0, "ring_only": true})
			if impacts.size() > 6:
				impacts.pop_front()
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i].age += delta
		if impacts[i].age > 2.0:
			impacts.remove_at(i)
	_step_waves(delta)
	splash_layer.queue_redraw()

func _wave_at(x: float) -> float:
	var f := clampf((x - x_start) / WAVE_DX, 0.0, float(cells) - 1.001)
	var i := int(f)
	return lerpf(wave_h[i], wave_h[i + 1], f - float(i))

func _draw_splashes() -> void:
	var line_color := Color(0.66, 0.66, 0.64)
	# the surface itself: a bright line that rides the swell, and a dark one under it
	var prev := Vector2.ZERO
	var first := true
	var x := x_start + 4.0
	while x < x_end - 4.0:
		var y := surface_y - _wave_at(x)
		var p := Vector2(x, y)
		if not first:
			var activity := clampf(absf(_wave_at(x)) * 0.14 + absf(_wave_at(x) - _wave_at(x - 8.0)) * 0.2, 0.0, 1.0)
			splash_layer.draw_line(prev, p, Color(line_color, 0.30 + activity * 0.5), 1.4, true)
		prev = p
		first = false
		x += 8.0
	for impact in impacts:
		var t: float = impact.age
		var strength: float = impact.strength
		var origin := Vector2(float(impact.x), surface_y - _wave_at(float(impact.x)))
		if not bool(impact.get("ring_only", false)):
			if t < 0.28:
				var height := sin(t / 0.28 * PI) * 15.0 * strength
				for side in [-1.0, 1.0]:
					var base := origin + Vector2(side * float(impact.spread) * 0.8, 0.0)
					splash_layer.draw_colored_polygon(PackedVector2Array([base + Vector2(-5, 1), base + Vector2(side * 5.0, -height), base + Vector2(side * 10.0, -height * 0.6), base + Vector2(side * 14.0, 1)]), Color(0.65, 0.65, 0.63, (1.0 - t / 0.28) * 0.5))
			for i in 16:
				var side2 := -1.0 if i % 2 == 0 else 1.0
				var vx := side2 * (14.0 + fposmod(float(i) * 17.7, 46.0)) * strength
				var vy := -(46.0 + fposmod(float(i) * 29.3, 70.0)) * strength
				var point := origin + Vector2(side2 * float(impact.spread) * 0.35 + vx * t, vy * t + 170.0 * t * t)
				if point.y > surface_y + 1.0 or t > 0.8:
					continue
				var alpha := (1.0 - t / 0.8) * 0.7
				var tail := Vector2(vx, vy + 340.0 * t).normalized() * (1.2 + strength * 1.8)
				splash_layer.draw_line(point + Vector2(0, 0.6), point - tail + Vector2(0, 0.6), Color(0.16, 0.16, 0.16, alpha * 0.5), 2.0, true)
				splash_layer.draw_line(point, point - tail, Color(0.82, 0.82, 0.8, alpha), 1.2, true)
		# rings that run out and fade
		var life := 1.0 + strength * 0.9
		for k in 3:
			var age := t - float(k) * 0.15
			if age < 0.0 or age > life:
				continue
			var fade := 1.0 - age / life
			splash_layer.draw_set_transform(origin + Vector2(0, 1.5), 0.0, Vector2(1.0, 0.16))
			splash_layer.draw_arc(Vector2.ZERO, float(impact.spread) * 0.5 + age * (46.0 + strength * 26.0), 0.0, TAU, 40, Color(0.72, 0.72, 0.70, fade * fade * (0.40 - float(k) * 0.08)), 1.4, true)
			splash_layer.draw_set_transform(Vector2.ZERO)
