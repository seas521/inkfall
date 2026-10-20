extends Node2D

# A flame built the way good 2D games build one, not as a few fixed tongues:
#  - body: many short-lived soft blobs that start wide at the base, rise at different speeds and
#    heights, drift with a shared gust, and shrink while their colour cools white -> orange -> red.
#    The outline is the union of these, so it is never the same twice and its tips are ragged.
#  - licks: small teardrops that break away from the upper body and fly off on their own.
#  - sparks: tiny points that twinkle as they climb and cool.
#  - soot: a few dark puffs above the tips (normal blend) so the fire does not end in a clean cut.
#  - light: a flickering warm glow around the base, strong enough that the fire is seen mostly
#    through what it lights. `light` is the current flicker (about 0.6 .. 1.0) for outside use.
# The node's origin is the centre of the base; the flame rises towards -y.

var width := 60.0
var height := 90.0
var strength := 1.0
var monochrome := false
var seed_value := 1
var light := 1.0
var glow_scale := 1.0

var clock := 0.0
var _rng := RandomNumberGenerator.new()
var _body: Array[Dictionary] = []
var _licks: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _smoke: Array[Dictionary] = []
var _acc_body := 0.0
var _acc_lick := 0.0
var _acc_spark := 0.0
var _acc_smoke := 0.0
var _blob: Texture2D
var _glow: Texture2D
var _smoke_node: Node2D

func _ready() -> void:
	_rng.seed = seed_value * 7919 + 13
	clock = _rng.randf() * 40.0
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_blob = _radial([0.0, 0.25, 0.55, 0.8, 1.0], [1.0, 0.85, 0.42, 0.10, 0.0])
	_glow = _radial([0.0, 0.3, 0.6, 0.85, 1.0], [1.0, 0.55, 0.20, 0.04, 0.0])
	_smoke_node = Node2D.new()
	add_child(_smoke_node)
	_smoke_node.draw.connect(_draw_smoke)

static func _radial(offsets: Array, alphas: Array) -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	var colors := PackedColorArray()
	for alpha in alphas:
		colors.append(Color(1.0, 1.0, 1.0, float(alpha)))
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func _wind() -> float:
	return 0.55 * sin(clock * 1.1 + float(seed_value)) + 0.35 * sin(clock * 2.7 + 1.7) + 0.22 * sin(clock * 6.3)

# Heat colour for age a (0 = just born, 1 = gone).
func _heat(a: float) -> Color:
	var c: Color
	if a < 0.28:
		c = Color(1.0, 0.93, 0.62).lerp(Color(1.0, 0.62, 0.16), a / 0.28)
	elif a < 0.65:
		c = Color(1.0, 0.62, 0.16).lerp(Color(0.86, 0.24, 0.05), (a - 0.28) / 0.37)
	else:
		c = Color(0.86, 0.24, 0.05).lerp(Color(0.30, 0.05, 0.01), (a - 0.65) / 0.35)
	if monochrome:
		var v := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		c = Color(v, v, v)
	return c

func _tint(c: Color) -> Color:
	if monochrome:
		var v := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		return Color(v, v, v, c.a)
	return c

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	delta = minf(delta, 0.05)
	clock += delta
	var s := clampf(strength, 0.0, 1.0)
	var span := clampf(width / 60.0, 0.7, 3.0)
	var wind := _wind()
	light = 0.80 + 0.12 * sin(clock * 8.7 + 1.0) + 0.07 * sin(clock * 21.3) + 0.05 * sin(clock * 3.1 + 2.0)
	if s > 0.03:
		_acc_body += delta * 95.0 * s * minf(span, 2.0)
		while _acc_body >= 1.0:
			_acc_body -= 1.0
			if _body.size() < 220:
				_spawn_body(s)
		_acc_lick += delta * 2.4 * s * span
		while _acc_lick >= 1.0:
			_acc_lick -= 1.0
			_spawn_lick(s)
		_acc_spark += delta * 9.0 * s * span
		while _acc_spark >= 1.0:
			_acc_spark -= 1.0
			_spawn_spark(s)
		_acc_smoke += delta * 1.5 * s * span
		while _acc_smoke >= 1.0:
			_acc_smoke -= 1.0
			_spawn_smoke(s)
	_step(_body, delta, wind, 0)
	_step(_licks, delta, wind, 1)
	_step(_sparks, delta, wind, 2)
	_step(_smoke, delta, wind, 3)
	queue_redraw()
	if _smoke_node != null:
		_smoke_node.queue_redraw()

func _spawn_body(s: float) -> void:
	var x0 := clampf(_rng.randfn(0.0, width * 0.26), -width * 0.5, width * 0.5)
	var centre := 1.0 - absf(x0) / maxf(width, 1.0) * 0.8
	var base := clampf(minf(width * 0.34, height * 0.50), 10.0, 34.0)
	_body.append({
		"x0": x0, "reach": height * s * _rng.randf_range(0.55, 1.3) * centre, "age": 0.0,
		"life": _rng.randf_range(0.5, 0.95), "size": base * _rng.randf_range(0.6, 1.1),
		"ph": _rng.randf() * TAU, "pos": Vector2(x0, 0.0), "rot": 0.0,
	})

func _spawn_lick(s: float) -> void:
	var base := clampf(minf(width * 0.34, height * 0.50), 10.0, 34.0)
	_licks.append({
		"pos": Vector2(_rng.randf_range(-0.2, 0.2) * width, -height * s * _rng.randf_range(0.30, 0.55)),
		"vel": Vector2(_rng.randf_range(-14.0, 14.0), -height * _rng.randf_range(0.9, 1.7)),
		"age": 0.0, "life": _rng.randf_range(0.5, 0.95), "size": base * _rng.randf_range(0.7, 1.2),
		"ph": _rng.randf() * TAU, "rot": 0.0,
	})

func _spawn_spark(s: float) -> void:
	_sparks.append({
		"pos": Vector2(_rng.randf_range(-0.3, 0.3) * width, -height * s * _rng.randf_range(0.2, 0.6)),
		"vel": Vector2(_rng.randf_range(-14.0, 14.0), -_rng.randf_range(45.0, 125.0) * height / 90.0),
		"age": 0.0, "life": _rng.randf_range(0.9, 1.9), "size": _rng.randf_range(0.9, 1.7),
		"ph": _rng.randf() * TAU,
	})

func _spawn_smoke(s: float) -> void:
	_smoke.append({
		"pos": Vector2(_rng.randf_range(-0.15, 0.15) * width, -height * s * 0.9),
		"vel": Vector2(0.0, -_rng.randf_range(20.0, 36.0)),
		"age": 0.0, "life": _rng.randf_range(1.8, 2.8), "size": _rng.randf_range(10.0, 17.0),
		"ph": _rng.randf() * TAU,
	})

func _step(items: Array[Dictionary], delta: float, wind: float, kind: int) -> void:
	var k := items.size() - 1
	while k >= 0:
		var p: Dictionary = items[k]
		p.age = float(p.age) + delta
		var a: float = float(p.age) / float(p.life)
		if a >= 1.0:
			items.remove_at(k)
			k -= 1
			continue
		var ph: float = p.ph
		match kind:
			0:
				var x0: float = p.x0
				var reach: float = p.reach
				var pos := Vector2(
					x0 * (1.0 - 0.78 * a) + sin(clock * 6.0 + ph + a * 3.0) * width * 0.09 * a + wind * height * 0.16 * pow(a, 1.8),
					-reach * pow(a, 0.85)
				)
				var d: Vector2 = pos - Vector2(p.pos)
				if d.length() > 0.01:
					p.rot = clampf(atan2(d.x, -d.y), -0.9, 0.9)
				p.pos = pos
			1:
				var v: Vector2 = p.vel
				v.x += (wind * 60.0 + sin(clock * 9.0 + ph) * 55.0) * delta
				v.y *= 1.0 - 0.55 * delta
				p.vel = v
				p.pos = Vector2(p.pos) + v * delta
				p.rot = clampf(atan2(v.x, -v.y), -0.9, 0.9)
			2:
				var v2: Vector2 = p.vel
				v2.x += (wind * 34.0 + sin(clock * 5.0 + ph) * 40.0) * delta
				v2.y *= 1.0 - 0.25 * delta
				p.vel = v2
				p.pos = Vector2(p.pos) + v2 * delta
			3:
				var v3: Vector2 = p.vel
				v3.x += wind * 14.0 * delta
				p.vel = v3
				p.pos = Vector2(p.pos) + v3 * delta
		k -= 1

func _draw() -> void:
	var s := clampf(strength, 0.0, 1.0)
	if s > 0.02:
		var l := light * s
		_blob_at(Vector2(0.0, -height * 0.38), Vector2(width * 4.2 + 90.0, height * 3.0 + 60.0) * glow_scale, 0.0, _tint(Color(1.0, 0.42, 0.09, 0.24 * l)), _glow)
		_blob_at(Vector2(0.0, -height * 0.30), Vector2(width * 1.9 + 24.0, height * 1.45) * glow_scale, 0.0, _tint(Color(1.0, 0.58, 0.18, 0.24 * l)), _glow)
		_blob_at(Vector2(0.0, -3.0), Vector2(width * 2.8 + 44.0, 17.0) * Vector2(glow_scale, 1.0), 0.0, _tint(Color(1.0, 0.55, 0.16, 0.24 * l)), _glow)
	for p in _body:
		var a: float = float(p.age) / float(p.life)
		var sz: float = float(p.size) * pow(1.0 - a, 0.9)
		var alpha := clampf(a * 10.0, 0.0, 1.0) * pow(1.0 - a, 0.7) * 0.27
		var c := _heat(a)
		c.a = alpha
		_blob_at(p.pos, Vector2(sz, sz * (1.6 + 0.9 * a)), p.rot, c, _blob)
	for p in _licks:
		var a2: float = float(p.age) / float(p.life)
		var sz2: float = float(p.size) * (1.0 - a2)
		var c2 := _heat(0.12 + a2 * 0.7)
		c2.a = clampf(a2 * 8.0, 0.0, 1.0) * pow(1.0 - a2, 0.5) * 0.60
		_blob_at(p.pos, Vector2(sz2 * 0.50, sz2 * 1.7), p.rot, c2, _blob)
	for p in _sparks:
		var a3: float = float(p.age) / float(p.life)
		var c3 := _heat(0.05 + a3 * 0.6)
		c3.a = pow(1.0 - a3, 0.7) * (0.55 + 0.45 * sin(clock * 35.0 + float(p.ph)))
		var r: float = p.size
		_blob_at(p.pos, Vector2(r * 4.0, r * 4.0), 0.0, Color(c3.r, c3.g, c3.b, c3.a * 0.45), _glow)
		draw_circle(p.pos, r * 0.6, c3, true, -1.0, true)

func _blob_at(pos: Vector2, size: Vector2, rot: float, color: Color, texture: Texture2D) -> void:
	draw_set_transform(pos, rot, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_smoke() -> void:
	for p in _smoke:
		var a: float = float(p.age) / float(p.life)
		var sz: float = float(p.size) * (1.0 + a * 1.8)
		var pos: Vector2 = p.pos + Vector2(sin(clock * 1.7 + float(p.ph)) * 5.0 * a, 0.0)
		_smoke_node.draw_texture_rect(_glow, Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(0.03, 0.025, 0.025, sin(a * PI) * 0.22))
