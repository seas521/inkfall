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
const WAVE_MAX := 8.0

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
	float edge_aa = smoothstep(0.0, max(fwidth(world_position.y), 0.5), clearance);
	float distortion = sin(world_position.y * 0.18 + clock * 2.1) * 0.35 + sin(world_position.x * 0.09 - clock * 1.3) * 0.15;
	distortion *= smoothstep(0.0, 3.0, clearance);
	vec2 bend = vec2(distortion + swell_slope * 30.0 * exp(-depth / 12.0), swell_slope * 7.0 * exp(-depth / 8.0));
	vec2 refract_uv = SCREEN_UV + bend * SCREEN_PIXEL_SIZE * smoothstep(0.0, 6.0, depth);
	vec3 submerged = texture(scene_color, refract_uv).rgb;
	// Absorb by optical depth instead of mixing a pale opaque fog tint.
	// Refracted legs and bank remain visible, while the basin separates from air.
	float transmission=exp(-max(depth,0.0)*0.028);
	vec3 water=submerged*mix(0.98,transmission,smoothstep(0.0,5.0,depth));
	water=mix(water,vec3(0.025),0.035*(1.0-transmission));
	float world_pixel = SCREEN_PIXEL_SIZE.y / max(fwidth(world_position.y), 0.001);
	vec2 reflected_uv = vec2(refract_uv.x, SCREEN_UV.y - (depth * 2.0 + wave) * world_pixel);
	vec3 reflected = texture(scene_color, clamp(reflected_uv, vec2(0.0), vec2(1.0))).rgb;
	water = mix(water, reflected, 0.30 * exp(-depth / 6.0));
	float band = (1.0 - smoothstep(0.0, 2.4, depth)) * (0.07 + 0.035 * sin(world_position.x * 0.021 + clock * 0.6));
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
var bed_function: Callable
var bed_ys := PackedFloat32Array()  # the ground's height under each wave cell
var wet_cells := PackedByteArray()  # per wave cell: is there water (the bed is under the surface)? (looked up, not computed, while drawing)
var energy := 0.0  # how much the water still moves: a calm pond is neither simulated nor redrawn
var was_active := true
var splash_layer: Node2D
var impacts: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var inside := false
var wade_clock := 0.0
var clock := 0.0

func setup(new_level: Node2D, x0: float, x1: float, y: float, bed_fn: Callable, depth: float) -> void:
	level = new_level
	bed_function = bed_fn
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
	wet_cells.resize(cells)
	bed_ys.resize(cells)
	for i in cells:
		var bed_y := float(bed_fn.call(x0 + float(i) * WAVE_DX))
		beds.set_pixel(i, 0, Color(bed_y, 0.0, 0.0, 1.0))
		wet_cells[i] = 1 if bed_y > y + 1.5 else 0
		bed_ys[i] = bed_y
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
	var peak := 0.0
	for step in steps:
		for i in range(1, cells - 1):
			wave_v[i] += (c2 * (wave_h[i - 1] + wave_h[i + 1] - 2.0 * wave_h[i]) - wave_damp[i] * wave_v[i]) * dt
		for i in range(1, cells - 1):
			wave_h[i] = clampf((wave_h[i] + wave_v[i] * dt) * (1.0 - WAVE_LEAK * dt), -WAVE_MAX, WAVE_MAX)
			peak = maxf(peak, absf(wave_h[i]) + absf(wave_v[i]) * 0.02)
	energy = peak
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
		# the water moves with him: every frame a trough at his legs and a low bow wave ahead of them, so a wake runs along with him
		var dir := signf(velocity.x)
		var speed := absf(velocity.x)
		disturb(feet.x - dir * 6.0, -speed * 0.034, 13.0)
		disturb(feet.x + dir * 22.0, speed * 0.018, 15.0)
		wade_clock += delta
		if wade_clock > 0.09:
			wade_clock = 0.0
			impacts.append({"x": feet.x - dir * 8.0, "age": 0.0, "strength": 0.7, "spread": 12.0, "ring_only": true})
			if impacts.size() > 6:
				impacts.pop_front()
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i].age += delta
		if impacts[i].age > 2.0:
			impacts.remove_at(i)
	var active := not impacts.is_empty() or not wave_kicks.is_empty() or energy > 0.02
	if active:
		_step_waves(delta)
		splash_layer.queue_redraw()
	elif was_active:
		# it has just come to rest: the last picture (flat water) is drawn once and kept
		for i in cells:
			wave_h[i] = 0.0
			wave_v[i] = 0.0
		wave_texture.update(Image.create_from_data(cells, 1, false, Image.FORMAT_RF, wave_h.to_byte_array()))
		splash_layer.queue_redraw()
	was_active = active

func _wave_at(x: float) -> float:
	var f := clampf((x - x_start) / WAVE_DX, 0.0, float(cells) - 1.001)
	var i := int(f)
	return lerpf(wave_h[i], wave_h[i + 1], f - float(i))

# is there water at x (the ground under the surface is lower than the surface)?
func _bed_at(x: float) -> float:
	return bed_ys[clampi(int(roundf((x - x_start) / WAVE_DX)), 0, cells - 1)]

func _wet(x: float) -> bool:
	if x <= x_start + 1.0 or x >= x_end - 1.0:
		return false
	return wet_cells[clampi(int(roundf((x - x_start) / WAVE_DX)), 0, cells - 1)] == 1

func _draw_splashes() -> void:
	var line_color := Color(0.66, 0.66, 0.64)
	# the surface itself: a bright line that rides the swell (a few segments, each with its own brightness; only over water)
	var prev := Vector2.ZERO
	var first := true
	var x := x_start + 4.0
	while x < x_end - 4.0:
		var wave_here := _wave_at(x)
		var p := Vector2(x, surface_y - wave_here)
		if not first and _wet(x) and _wet(x - 8.0):
			var activity := clampf(absf(wave_here) * 0.14 + absf(wave_here - _wave_at(x - 8.0)) * 0.2, 0.0, 1.0)
			splash_layer.draw_line(prev, p, Color(line_color, 0.13 + activity * 0.48), 1.4)
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
			if t < 0.8:
				for i in 8:
					var side2 := -1.0 if i % 2 == 0 else 1.0
					var vx := side2 * (14.0 + fposmod(float(i) * 17.7, 46.0)) * strength
					var vy := -(46.0 + fposmod(float(i) * 29.3, 70.0)) * strength
					var point := origin + Vector2(side2 * float(impact.spread) * 0.35 + vx * t, vy * t + 170.0 * t * t)
					if point.y > surface_y + 1.0:
						continue
					var alpha := (1.0 - t / 0.8) * 0.7
					var tail := Vector2(vx, vy + 340.0 * t).normalized() * (1.2 + strength * 1.8)
					splash_layer.draw_line(point, point - tail, Color(0.82, 0.82, 0.8, alpha), 1.4)
		# rings that run out and fade: a flat ellipse on the surface, only the parts over water are drawn (a polyline per run)
		var life := 1.0 + strength * 0.9
		for k in 3:
			var age := t - float(k) * 0.15
			if age < 0.0 or age > life:
				continue
			var fade := 1.0 - age / life
			var radius: float = float(impact.spread) * 0.5 + age * (46.0 + strength * 26.0)
			var ring_alpha: float = fade * (0.62 - float(k) * 0.12)
			# only the part of the ring that lies in the water: the lower half of the ellipse (under the surface), above the bed: nothing is
			# ever drawn in the air or over the ground
			var run := PackedVector2Array()
			for step in range(25):
				var angle := float(step) / 24.0 * PI
				var rp := origin + Vector2(cos(angle) * radius, 1.5 + sin(angle) * minf(radius * 0.30, 14.0))
				if _wet(rp.x) and rp.y < _bed_at(rp.x) - 1.5:
					run.append(rp)
				elif run.size() > 1:
					_ring_run(run, ring_alpha)
					run = PackedVector2Array()
				else:
					run = PackedVector2Array()
			if run.size() > 1:
				_ring_run(run, ring_alpha)

func _ring_run(run: PackedVector2Array, alpha: float) -> void:
	# fades towards the banks: the colour of each point
	var colors := PackedColorArray()
	for point in run:
		var edge_fade := clampf(minf(point.x - x_start, x_end - point.x) / 30.0, 0.0, 1.0)
		colors.append(Color(0.72, 0.72, 0.70, alpha * edge_fade))
	splash_layer.draw_polyline_colors(run, colors, 1.4)
