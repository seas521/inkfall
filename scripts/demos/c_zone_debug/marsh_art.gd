extends Node2D

# Second act of the C zone. It continues act one's picture instead of replacing it:
# the same pale fog backdrop, blurred mid and foreground layers and near-black ink
# silhouettes. Detail lives in the outer contour (grass, roots, splinters, chipped
# overhangs), never in interior texture, and everything gameplay touches is ink.

const SCREEN := Vector2(1280.0, 720.0)
const INK := Color("050606")
const CliffArt = preload("res://scripts/demos/c_zone_debug/cliff_art.gd")
const InkFlame = preload("res://scripts/effects/ink_flame.gd")
const GRASS_SHADER := """shader_type canvas_item;
// source_color: the ink must be converted like any other colour, or an HDR 2D (linear) viewport
// shows a hand-written 0.02 as mid grey instead of near black.
uniform vec4 ink : source_color = vec4(0.02, 0.022, 0.022, 1.0);
void vertex() {
	float k = COLOR.r;
	VERTEX.x += (sin(TIME * 1.25 + VERTEX.x * 0.07) * 1.5 + sin(TIME * 0.55 + VERTEX.x * 0.013) * 1.1) * k * k;
}
void fragment() {
	COLOR = vec4(ink.rgb, 1.0);
}"""

# Everything made of ink is drawn as clean shapes into a screen-sized stage and then run through
# this pass, which only softens the edge by about a pixel and a half. It does not warp the
# contour or add a halo: act one's silhouettes are single, calm curves and so are these.
const INK_SHADER := """shader_type canvas_item;
uniform float soften = 2.4;
uniform vec4 ink : source_color = vec4(0.02, 0.021, 0.021, 1.0);
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float core = texture(TEXTURE, UV).a * 0.14;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7853982 + 0.3;
		vec2 d = vec2(cos(a), sin(a));
		core += texture(TEXTURE, UV + d * soften * 0.55 * px).a * 0.07;
		core += texture(TEXTURE, UV + d * soften * 1.25 * px).a * 0.035;
	}
	COLOR = vec4(ink.rgb, smoothstep(0.05, 0.95, core));
}"""

var level: Node2D
var clock := 0.0
var camera_x := 0.0
var noise := FastNoiseLite.new()
var mist_texture: GradientTexture2D
var void_back: Node2D
var bog_canvas: Node2D
var bog_sprites: Array[Sprite2D] = []
var bog_views: Array[SubViewport] = []
var land: Node2D
var grass: Node2D
var dyn: Node2D
var fog: Node2D
var gas_back: Node2D
var effects: Node2D
var flame_sprites: Array[Node2D] = []
var rock_shapes: Dictionary = {}
var cap_undersides: Dictionary = {}
var cap_frags: Dictionary = {}
var prev_cap_loose: Array[bool] = [false, false]
var prev_cap_phase: Array[int] = [0, 0]
var cap_grit_clock := 0.0
var dust: Array[Dictionary] = []
var chips: Array[Dictionary] = []
var dust_rng := RandomNumberGenerator.new()
var prev_rock_modes: Array[int] = []
var prev_limb_broken := false
var rock_trail_clock := 0.0
var feet_dust_clock := 0.0
var warn_dust_clock := 0.0
var back_stage: Dictionary
var front_stage: Dictionary

func _ready() -> void:
	noise.seed = 9041
	noise.frequency = 0.021
	noise.fractal_octaves = 3
	mist_texture = _build_mist_texture()
	back_stage = _ink_stage(1, 2.4)
	front_stage = _ink_stage(7, 1.5)
	void_back = _layer(self, -3, _draw_void)
	_build_bog()
	fog = _layer(self, -3, _draw_fog_puffs)
	# The gas body lives behind the ink stage: a cliff edge cuts the plume off, so the gas seems to
	# rise out along the edge instead of being smeared over the step.
	gas_back = _layer(self, -2, _draw_gas_back)
	land = _layer(back_stage.root, 0, _draw_land_static)
	dyn = _layer(back_stage.root, 3, _draw_dynamic)
	effects = _layer(self, 6, _draw_effects)
	grass = _layer(front_stage.root, 0, _draw_grass)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = GRASS_SHADER
	material.shader = shader
	material.set_shader_parameter("ink", Color(0.012, 0.013, 0.013))
	grass.material = material
	_build_flames()

const BLUR_SHADER := """shader_type canvas_item;
// A gaussian blur of the bog. The viewport texture holds premultiplied colour, so the blur averages
// colour and alpha together, and the edge of a dark shape fades out without a darker rim.
uniform vec2 radius = vec2(4.0, 6.0);
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 sum = vec4(0.0);
	float weights = 0.0;
	for (int i = -3; i <= 3; i++) {
		for (int j = -3; j <= 3; j++) {
			vec2 o = vec2(float(i), float(j)) / 3.0;
			float w = exp(-dot(o, o) * 2.2);
			sum += texture(TEXTURE, UV + o * radius * px) * w;
			weights += w;
		}
	}
	sum /= weights;
	COLOR = vec4(sum.rgb / max(sum.a, 0.0001), sum.a);
}"""

# The bog of each pit is drawn once into its own viewport and shown through a gaussian blur, so it
# reads as an out-of-focus mass in the mist rather than a hard-edged band.
func _build_bog() -> void:
	var shader := Shader.new()
	shader.code = BLUR_SHADER
	for pit_range in level.MARSH_PITS:
		var pit: Vector2 = pit_range
		var origin := Vector2(pit.x - 130.0, 470.0)
		var view := SubViewport.new()
		view.size = Vector2i(int(pit.y - pit.x + 260.0), 340)
		view.transparent_bg = true
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(view)
		var canvas := Node2D.new()
		canvas.position = -origin
		canvas.draw.connect(_draw_bog_pit.bind(canvas, pit))
		view.add_child(canvas)
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.position = origin
		sprite.z_index = -3
		sprite.texture = view.get_texture()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var material := ShaderMaterial.new()
		material.shader = shader
		sprite.material = material
		add_child(sprite)
		bog_views.append(view)
		bog_sprites.append(sprite)

func _draw_bog_pit(canvas: Node2D, pit: Vector2) -> void:
	bog_canvas = canvas
	_draw_bog(pit)
	for i in range(level.MARSH_GAS_RECTS.size()):
		var cx: float = level.MARSH_GAS_RECTS[i].get_center().x
		if cx > pit.x - 60.0 and cx < pit.y + 60.0:
			_draw_crater(i)

func _layer(parent: Node, z: int, drawer: Callable) -> Node2D:
	var node := Node2D.new()
	node.z_index = z
	node.draw.connect(drawer)
	parent.add_child(node)
	return node

# A screen-sized viewport that always shows the current camera window of the world.
func _ink_stage(z: int, soften: float) -> Dictionary:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	var root := Node2D.new()
	view.add_child(root)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.z_index = z
	sprite.texture = view.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader := Shader.new()
	shader.code = INK_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("ink", Color(0.012, 0.013, 0.013))
	material.set_shader_parameter("soften", soften)
	sprite.material = material
	add_child(sprite)
	return {"view": view, "root": root, "sprite": sprite, "material": material}

func sync(delta: float, new_camera_x: float, active: bool) -> void:
	visible = active
	var live := active and new_camera_x > 1400.0
	for stage in [back_stage, front_stage]:
		(stage.view as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
		(stage.sprite as Sprite2D).visible = live
	if not active:
		return
	# Each bog is drawn once, but its viewport only settles after a number of frames, so the ones near
	# the camera simply keep rendering.
	for k in range(bog_views.size()):
		var pit: Vector2 = level.MARSH_PITS[k]
		var near := new_camera_x > pit.x - SCREEN.x - 300.0 and new_camera_x < pit.y + 300.0
		bog_views[k].render_target_update_mode = SubViewport.UPDATE_ALWAYS if near else SubViewport.UPDATE_DISABLED
	clock += delta
	camera_x = new_camera_x
	for stage in [back_stage, front_stage]:
		var shake: Vector2 = level.camera.offset
		var camera_y: float = level.camera_y
		(stage.root as Node2D).position = Vector2(-camera_x - shake.x, -shake.y - camera_y)
		(stage.sprite as Sprite2D).position = Vector2(camera_x + shake.x, shake.y + camera_y)
	_sync_flames()
	_update_effects(delta)
	dyn.queue_redraw()
	fog.queue_redraw()
	gas_back.queue_redraw()
	effects.queue_redraw()

func _visible_x(x: float, pad: float = 180.0) -> bool:
	return x > camera_x - pad and x < camera_x + SCREEN.x + pad

func _build_mist_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.24, 0.52, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.68),
		Color(1.0, 1.0, 1.0, 0.31),
		Color(1.0, 1.0, 1.0, 0.08),
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

func _soft(canvas: Node2D, center: Vector2, size: Vector2, color: Color) -> void:
	canvas.draw_texture_rect(mist_texture, Rect2(center - size * 0.5, size), false, color)

# ---------------------------------------------------------------- shared shapes

func _profile_y(profile: PackedVector2Array, x: float) -> float:
	if x <= profile[0].x:
		return profile[0].y
	for i in range(profile.size() - 1):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if x <= b.x:
			return lerpf(a.y, b.y, clampf((x - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0))
	return profile[profile.size() - 1].y

# The silhouette rides a hair above the collider so feet sink into grass, never hover.
func _visual_y(profile: PackedVector2Array, x: float) -> float:
	return _profile_y(profile, x) - 1.6 + noise.get_noise_1d(x) * 2.0 + noise.get_noise_1d(x * 3.9) * 0.8

func _limb(canvas: Node2D, points: Array, widths: Array) -> void:
	var spine: Array[Vector2] = []
	var thickness: Array[float] = []
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var d: Vector2 = points[i + 1]
		var previous: Vector2 = points[maxi(0, i - 1)]
		var following: Vector2 = points[mini(points.size() - 1, i + 2)]
		var b: Vector2 = a + (d - previous) / 6.0
		var c: Vector2 = d - (following - a) / 6.0
		for sample in range(14):
			var t := float(sample) / 14.0
			spine.append(a.bezier_interpolate(b, c, d, t))
			thickness.append(lerpf(float(widths[i]), float(widths[i + 1]), t))
	spine.append(points[points.size() - 1])
	thickness.append(float(widths[widths.size() - 1]))
	var outline := PackedVector2Array()
	for side in [1.0, -1.0]:
		for step in range(spine.size()):
			var i: int = step if side > 0.0 else spine.size() - 1 - step
			var direction: Vector2 = spine[mini(i + 1, spine.size() - 1)] - spine[maxi(0, i - 1)]
			var normal := Vector2(-direction.y, direction.x).normalized()
			outline.append(spine[i] + normal * thickness[i] * float(side))
	canvas.draw_colored_polygon(outline, INK)

func _beam(canvas: Node2D, a: Vector2, b: Vector2, width: float, seed_value: float) -> void:
	var normal := (b - a).normalized().orthogonal() * width * 0.5
	var points := PackedVector2Array()
	for i in range(7):
		var t := float(i) / 6.0
		points.append(a.lerp(b, t) + normal * 0.94)
	for i in range(6, -1, -1):
		var t := float(i) / 6.0
		points.append(a.lerp(b, t) - normal * 0.94)
	canvas.draw_colored_polygon(points, INK)

func _twig_fan(canvas: Node2D, root: Vector2, height: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for n in range(rng.randi_range(3, 5)):
		var lean := rng.randf_range(-0.9, 0.9)
		var length := height * rng.randf_range(0.55, 1.0)
		var mid := root + Vector2(lean * length * 0.35 + rng.randf_range(-6.0, 6.0), -length * 0.55)
		var tip := root + Vector2(lean * length * 0.8, -length)
		_limb(canvas, [root + Vector2(rng.randf_range(-3.0, 3.0), 3.0), mid, tip], [2.6, 1.5, 0.3])
		if length > 40.0:
			var knot := mid.lerp(tip, 0.35)
			_limb(canvas, [knot, knot + Vector2(sign(lean + 0.01) * 14.0, -14.0), knot + Vector2(sign(lean + 0.01) * 24.0, -34.0)], [1.4, 0.9, 0.2])

# ------------------------------------------------------------ pit interiors

func _draw_void() -> void:
	# Gas pockets are fog-filled hollows: pale at the lip, sinking to black. The bands
	# below also hide the backdrop's horizon so no water line shows through a pocket.
	# The mist never gets brighter than the backdrop behind it: it only darkens downward,
	# so a pocket reads as depth, not as a pale floor.
	var stops := [
		Vector3(430.0, 0.0, 0.36), Vector3(500.0, 0.46, 0.27), Vector3(560.0, 0.80, 0.17),
		Vector3(625.0, 1.0, 0.08), Vector3(700.0, 1.0, 0.03), Vector3(800.0, 1.0, 0.015),
	]
	for pit in level.MARSH_PITS:
		# Wide enough to sit under the tapered cliff faces, so no backdrop slit shows beside them.
		var x0: float = pit.x - 90.0
		var x1: float = pit.y + 90.0
		for i in range(stops.size() - 1):
			var upper: Vector3 = stops[i]
			var lower: Vector3 = stops[i + 1]
			var c0 := Color(upper.z, upper.z, upper.z, upper.y)
			var c1 := Color(lower.z, lower.z, lower.z, lower.y)
			void_back.draw_polygon(
				PackedVector2Array([Vector2(x0, upper.x), Vector2(x1, upper.x), Vector2(x1, lower.x), Vector2(x0, lower.x)]),
				PackedColorArray([c0, c0, c1, c1])
			)
func _vent_params(i: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6120 + i * 37
	var rect: Rect2 = level.MARSH_GAS_RECTS[i]
	return {
		"cx": rect.get_center().x, "mouth": level.MARSH_VENT_BASE_Y + rng.randf_range(-6.0, 8.0),
		"half": rng.randf_range(95.0, 135.0), "skew": rng.randf_range(-0.35, 0.35),
		"shift": rng.randf_range(0.0, 400.0), "lean": rng.randf_range(-0.3, 0.3), "seed": 6120 + i * 37,
	}

# An irregular rounded shape: never an ellipse.
func _blob(center: Vector2, rx: float, ry: float, rng: RandomNumberGenerator, count: int = 18, wobble: float = 0.14) -> PackedVector2Array:
	var points := PackedVector2Array()
	var phase := rng.randf_range(0.0, TAU)
	for n in range(count):
		var a := TAU * float(n) / float(count)
		var k := 1.0 + wobble * sin(3.0 * a + phase) + wobble * 0.6 * sin(5.0 * a + phase * 1.7) + rng.randf_range(-wobble * 0.3, wobble * 0.3)
		points.append(center + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return points

const BOG_Y := 586.0

func _bog_y(x: float) -> float:
	return BOG_Y + noise.get_noise_1d(x * 0.7 + 400.0) * 15.0 + noise.get_noise_1d(x * 2.3) * 5.0 + noise.get_noise_1d(x * 6.0) * 1.5

# The mud surface: the bog's own rolling line plus the swollen craters round the vents.
func _bog_surface(x: float) -> float:
	var y := _bog_y(x)
	for i in range(level.MARSH_GAS_RECTS.size()):
		var v := _vent_params(i)
		var reach: float = float(v.half) * 1.3
		var u := absf(x - float(v.cx)) / reach
		if u >= 1.0:
			continue
		var h := _bog_y(float(v.cx)) - (float(v.mouth) - 14.0)
		var dip := 0.4 * exp(-pow(u / 0.26, 2.0))
		y -= h * pow(1.0 - u * u, 1.5) * (1.0 - dip) + noise.get_noise_1d(x * 2.2 + float(v.shift)) * 3.0 * (1.0 - u)
	return y

func _hash(a: float, b: float = 0.0) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

func _draw_bog(pit: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5100 + int(pit.x)
	var x0 := pit.x - 90.0
	var x1 := pit.y + 90.0
	# The mud: a glossy skin that darkens quickly into black, with a haze fading in above its edge so
	# there is no ruled horizon.
	var x := x0
	while x < x1:
		var xn := minf(x + 4.0, x1)
		var ya := _bog_surface(x)
		var yb := _bog_surface(xn)
		_mud_column(x, xn, ya, yb)
		var haze := Color(0.12, 0.12, 0.115, 0.0)
		var haze_on := Color(0.12, 0.12, 0.115, 0.4)
		bog_poly(PackedVector2Array([Vector2(x, ya - 28.0), Vector2(xn, yb - 28.0), Vector2(xn, yb), Vector2(x, ya)]), PackedColorArray([haze, haze, haze_on, haze_on]))
		x = xn
	# Scum, humps of mud and a sunken log break the surface line.
	var n := int((x1 - x0) / 62.0)
	for k in range(n):
		var sx := rng.randf_range(x0 + 20.0, x1 - 20.0)
		var sy := _bog_y(sx)
		var w := rng.randf_range(18.0, 52.0)
		var h := rng.randf_range(4.0, 11.0)
		_soft(bog_canvas, Vector2(sx, sy + 2.0), Vector2(w * 1.2, h * 1.5), Color(0.02, 0.02, 0.02, 0.85))
	# Dead stalks and snapped stumps standing in the bog.
	for k in range(maxi(2, n / 3)):
		var cx0 := rng.randf_range(x0 + 30.0, x1 - 30.0)
		var stump := rng.randf() < 0.3
		if stump:
			var sy := _bog_surface(cx0) + 3.0
			var sh := rng.randf_range(20.0, 44.0)
			var sl := rng.randf_range(-0.35, 0.35)
			_limb(bog_canvas, [Vector2(cx0, sy), Vector2(cx0 + sl * 10.0, sy - sh * 0.5), Vector2(cx0 + sl * 18.0, sy - sh)], [8.0, 6.0, 4.6])
			continue
		for blade in range(rng.randi_range(2, 4)):
			var rx := cx0 + float(blade) * rng.randf_range(5.0, 11.0)
			var ry := _bog_surface(rx) + 3.0
			var height := rng.randf_range(26.0, 86.0)
			var lean := rng.randf_range(-0.4, 0.4)
			_limb(bog_canvas, [Vector2(rx, ry), Vector2(rx + lean * height * 0.4, ry - height * 0.55), Vector2(rx + lean * height, ry - height)], [3.4, 2.4, 0.6])
	# The wet gloss of the mud: faint, long, soft glints just under the surface.
	for k in range(n):
		var gx := rng.randf_range(x0 + 20.0, x1 - 20.0)
		var gy := _bog_y(gx) + rng.randf_range(5.0, 16.0)
		_soft(bog_canvas, Vector2(gx, gy), Vector2(rng.randf_range(16.0, 44.0), 1.8), Color(0.5, 0.5, 0.47, rng.randf_range(0.06, 0.14)))
	# Mist lies on the surface and softens its edge.
	for k in range(int((x1 - x0) / 90.0) + 1):
		var mx := x0 + float(k) * 90.0 + rng.randf_range(0.0, 60.0)
		_soft(bog_canvas, Vector2(mx, _bog_y(mx) - 6.0), Vector2(rng.randf_range(80.0, 150.0), rng.randf_range(12.0, 22.0)), Color(0.3, 0.3, 0.29, rng.randf_range(0.10, 0.18)))

func _mud_column(x: float, xn: float, ya: float, yb: float) -> void:
	var skin := Color(0.075, 0.075, 0.07, 1.0)
	var deep := Color(0.025, 0.025, 0.025, 1.0)
	bog_canvas.draw_polygon(PackedVector2Array([Vector2(x, ya), Vector2(xn, yb), Vector2(xn, yb + 28.0), Vector2(x, ya + 28.0)]), PackedColorArray([skin, skin, deep, deep]))
	bog_canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, ya + 27.0), Vector2(xn, yb + 27.0), Vector2(xn, 840.0), Vector2(x, 840.0)]), deep)

func bog_poly(points: PackedVector2Array, colors: PackedColorArray) -> void:
	bog_canvas.draw_polygon(points, colors)

# A low crater of gas-saturated slurry: the mud has swollen and lipped over a soft pool. It has no
# straight edge anywhere. The bubbles that break in it are drawn live (see _draw_gas_back).
func _draw_crater(i: int) -> void:
	var v := _vent_params(i)
	var cx: float = v.cx
	var mouth: float = v.mouth
	var reach: float = float(v.half) * 0.78
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v.seed)
	# Two heavy lips of mud on the crater's rim, one slumped lower.
	for side: float in [-1.0, 1.0]:
		var lx: float = cx + side * (reach * 0.62 + rng.randf_range(-4.0, 6.0))
		var ly := _bog_surface(lx) + 1.0
		bog_canvas.draw_colored_polygon(_blob(Vector2(lx, ly), rng.randf_range(13.0, 20.0), rng.randf_range(5.0, 8.0), rng, 14, 0.2), Color(0.02, 0.02, 0.02, 1.0))
	# The pool in the crater: slurry slightly paler than the mud, with a wet glint on its far lip.
	var pool_rx := reach * 0.42
	bog_canvas.draw_colored_polygon(_blob(Vector2(cx, mouth + 5.0), pool_rx, 4.2, rng, 18, 0.1), Color(0.13, 0.13, 0.12, 1.0))
	bog_canvas.draw_colored_polygon(_blob(Vector2(cx - 2.0, mouth + 6.0), pool_rx * 0.78, 2.8, rng, 16, 0.12), Color(0.05, 0.05, 0.05, 1.0))
	bog_canvas.draw_colored_polygon(_blob(Vector2(cx - pool_rx * 0.1, mouth + 2.0), pool_rx * 0.7, 0.9, rng, 10, 0.2), Color(0.5, 0.5, 0.47, 0.22))
	# Slow gloss runs down the flanks where slurry has overflowed.
	for n in range(5):
		var gx := cx + rng.randf_range(-reach, reach)
		var gy := mouth + rng.randf_range(10.0, 26.0)
		bog_canvas.draw_colored_polygon(_blob(Vector2(gx, gy), rng.randf_range(8.0, 18.0), 0.9, rng, 8, 0.2), Color(0.5, 0.5, 0.47, rng.randf_range(0.07, 0.16)))

# ---------------------------------------------------------- static ink layer

func _draw_land_static() -> void:
	for i in range(level.MARSH_LANDS.size()):
		_draw_land_piece(level.MARSH_LANDS[i], i)
	_draw_branches()
	_draw_slab()
	_draw_fire_deck()
	_draw_spires()
	_draw_set_dressing()
	CliffArt.draw_static(self)

const SHOULDER := 11.0

# How far a face sits inside the land's end at a given depth: the collider's taper, a rounded
# shoulder where the top turns over, and a soft bulge of earth just under the lip. Low-frequency
# noise (never per-step jitter) keeps the face an uneven, weathered slope rather than a ruled line.
func _face_offset(index: int, side: float, depth: float) -> float:
	var shoulder := SHOULDER - sqrt(maxf(SHOULDER * SHOULDER - pow(SHOULDER - minf(depth, SHOULDER), 2.0), 0.0))
	var bulge := 7.0 * smoothstep(4.0, 30.0, depth) * (1.0 - smoothstep(30.0, 100.0, depth))
	var weather := noise.get_noise_1d(depth * 0.9 + float(index) * 173.0 + side * 61.0) * (1.5 + depth * 0.03)
	return _inset_at(depth) + shoulder - bulge + weather * smoothstep(8.0, 40.0, depth)

func _draw_land_piece(profile: PackedVector2Array, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + index * 37
	var start: float = profile[0].x
	var end: float = profile[profile.size() - 1].x
	var left_top := _visual_y(profile, start)
	var right_top := _visual_y(profile, end)
	var has_left_face: bool = true
	var has_right_face: bool = index < level.MARSH_LANDS.size() - 1
	var left_face: Array[Vector2] = []
	var right_face: Array[Vector2] = []
	var depth := 0.0
	while depth <= 470.0:
		if has_left_face:
			# The first piece is the ledge at the end of act one's bank. Its face gets the same rounded
			# shoulder and leaning rock as every other cliff, but stays within a few pixels of the wall
			# so the player never walks into it.
			var inset := _face_offset(index, -1.0, depth)
			if index == 0:
				inset = minf(inset, 17.0)
			var lx := start + inset
			left_face.append(Vector2(lx, _visual_y(profile, clampf(lx, start, end)) + depth))
		else:
			left_face.append(Vector2(start, left_top + depth))
		if has_right_face:
			var rx := end - _face_offset(index, 1.0, depth)
			right_face.append(Vector2(rx, _visual_y(profile, clampf(rx, start, end)) + depth))
		else:
			right_face.append(Vector2(end, right_top + depth))
		depth += 10.0 if depth < 120.0 else 24.0
	var outline := PackedVector2Array()
	outline.append(Vector2(start - 12.0, 960.0))
	for k in range(left_face.size() - 1, -1, -1):
		outline.append(left_face[k])
	var edge := PackedVector2Array()
	var x: float = left_face[0].x
	var x_end: float = right_face[0].x
	while x < x_end:
		edge.append(Vector2(x, _visual_y(profile, x)))
		x += 4.0
	edge.append(Vector2(x_end, _visual_y(profile, x_end)))
	outline.append_array(edge)
	for k in range(right_face.size()):
		outline.append(right_face[k])
	outline.append(Vector2(end + 12.0, 960.0))
	land.draw_colored_polygon(outline, INK)
	land.draw_polyline(edge, INK, 2.2, true)
	# A few half-buried stones and tussocks lift the top contour here and there.
	var bx := start + 24.0
	while true:
		bx += rng.randf_range(90.0, 210.0)
		if bx >= end - 30.0:
			break
		var w := rng.randf_range(7.0, 18.0)
		var h := rng.randf_range(3.0, 6.0)
		var by := _visual_y(profile, bx) + 3.0
		var stone := PackedVector2Array()
		for q in range(13):
			var angle := PI + PI * float(q) / 12.0
			stone.append(Vector2(bx + cos(angle) * w, by + sin(angle) * h * (1.0 + sin(float(q) * 1.9 + bx) * 0.12)))
		stone.append(Vector2(bx + w, by + 5.0))
		stone.append(Vector2(bx - w, by + 5.0))
		land.draw_colored_polygon(stone, INK)
	# Thin dry roots trail from the faces that border a gas pocket.
	var faces: Array = []
	if has_left_face:
		faces.append({"x": start, "top": left_top, "dir": -1.0, "side": -1.0})
	if has_right_face:
		faces.append({"x": end, "top": right_top, "dir": 1.0, "side": 1.0})
	for face in faces:
		for n in range(2):
			var dir: float = face.dir
			var y0: float = float(face.top) + rng.randf_range(18.0, 110.0)
			var fx: float = float(face.x) - dir * _face_offset(index, float(face.side), y0 - float(face.top)) + dir * 2.0
			_limb(land, [
				Vector2(fx, y0),
				Vector2(fx + dir * rng.randf_range(4.0, 12.0), y0 + rng.randf_range(20.0, 34.0)),
				Vector2(fx + dir * rng.randf_range(-3.0, 9.0), y0 + rng.randf_range(48.0, 70.0)),
				Vector2(fx + dir * rng.randf_range(0.0, 10.0), y0 + rng.randf_range(78.0, 112.0)),
			], [rng.randf_range(2.2, 3.4), 1.6, 0.9, 0.2])

func _inset_at(depth: float) -> float:
	var depths: Array[float] = level.LAND_FACE_DEPTH
	var insets: Array[float] = level.LAND_FACE_INSET
	for k in range(depths.size() - 1):
		if depth <= depths[k + 1]:
			return lerpf(insets[k], insets[k + 1], clampf((depth - depths[k]) / (depths[k + 1] - depths[k]), 0.0, 1.0))
	return insets[insets.size() - 1]

func _draw_branches() -> void:
	# One dead tree stands on the shoulder of the first ledge and leans out over the gas pit. Its
	# roots grip the lip of the cliff; the landing branch and the long swing limb both grow from
	# its trunk, so nothing hangs in the air.
	_limb(land, [Vector2(3304, 480), Vector2(3318, 432), Vector2(3346, 380), Vector2(3386, 322), Vector2(3424, 264), Vector2(3440, 212), Vector2(3436, 162)],
		[28.0, 24.0, 20.0, 17.0, 14.5, 12.5, 11.0])
	# Broken crown above the limb root.
	_limb(land, [Vector2(3436, 168), Vector2(3430, 118), Vector2(3442, 70), Vector2(3436, 30)], [10.5, 8.0, 4.5, 1.2])
	# Roots over the ledge top and down the pit face.
	_limb(land, [Vector2(3318, 440), Vector2(3290, 434), Vector2(3262, 436), Vector2(3238, 441)], [7.0, 5.0, 3.0, 0.8])
	_limb(land, [Vector2(3322, 446), Vector2(3342, 466), Vector2(3344, 504), Vector2(3334, 548)], [8.0, 6.0, 3.6, 0.8])
	_limb(land, [Vector2(3312, 452), Vector2(3322, 486), Vector2(3318, 528), Vector2(3326, 566)], [6.0, 4.0, 2.4, 0.6])
	# Landing branch: a limb that leaves the trunk and runs out level. Its top edge is the
	# collider's top (y = 250) from x = 3296 to 3414, so the centre line always sits one
	# half-width below that; it swells into a collar where it meets the trunk, thickens at a
	# knot, drooping and thinning toward a split tip. Nothing pokes out the far side of the trunk.
	_limb(land, [
		Vector2(3250, 254.0), Vector2(3290, 256.5), Vector2(3316, 258.0), Vector2(3345, 259.2),
		Vector2(3372, 258.6), Vector2(3396, 261.0), Vector2(3418, 266.0),
	], [1.1, 5.5, 8.0, 9.2, 8.6, 11.0, 16.0])
	# Split tip and a short broken stub, rather than a tall thin twig.
	_limb(land, [Vector2(3286, 256.0), Vector2(3274, 246.0), Vector2(3266, 234.0)], [2.8, 1.6, 0.3])
	_limb(land, [Vector2(3358, 251.0), Vector2(3355, 238.0), Vector2(3360, 226.0)], [4.6, 3.6, 2.6])
	land.draw_circle(Vector2(3360.0, 225.0), 2.8, INK, true, -1.0, true)
	# One drooping twig under the limb.
	_limb(land, [Vector2(3304, 262.0), Vector2(3300, 280.0), Vector2(3306, 300.0)], [3.0, 1.8, 0.3])
	# Long limb that carries the swing: a stout bough that thins and curls up at the tip.
	_limb(land, [
		Vector2(3436, 164), Vector2(3476, 128), Vector2(3530, 108), Vector2(3590, 98), Vector2(3680, 100),
		Vector2(3780, 98), Vector2(3880, 102), Vector2(3960, 94), Vector2(4030, 80), Vector2(4090, 62), Vector2(4132, 42),
	], [11.0, 10.5, 10.0, 9.5, 9.0, 8.4, 7.6, 6.5, 5.0, 3.0, 1.0])
	# The hill has a tree of its own: a dead trunk rooted in the slope below the crown, leaning over
	# it, with one bent bough reaching across. A falling boulder breaks that bough (see
	# _draw_limb_outer), so the thing that gives way belongs to a tree that visibly holds it.
	_limb(land, [Vector2(4380, 470), Vector2(4372, 420), Vector2(4364, 372), Vector2(4350, 318), Vector2(4338, 262), Vector2(4338, 208), Vector2(4352, 160), Vector2(4372, 112), Vector2(4372, 70)],
		[24.0, 21.0, 18.0, 15.5, 13.5, 12.0, 10.5, 9.0, 5.0])
	_limb(land, [Vector2(4374, 122), Vector2(4388, 96), Vector2(4384, 68), Vector2(4398, 44)], [6.0, 4.2, 2.8, 0.6])
	# Bough that reaches over the crown; the part past x = 4252 is drawn in the dynamic layer.
	_limb(land, [Vector2(4348, 182), Vector2(4322, 142), Vector2(4292, 113), Vector2(4262, 100.5), Vector2(4252, 98.5)], [10.0, 8.8, 7.4, 6.2, 5.8])
	# Roots that clamp the slope.
	_limb(land, [Vector2(4376, 400), Vector2(4408, 410), Vector2(4440, 428), Vector2(4466, 450)], [9.0, 6.0, 3.4, 0.8])
	_limb(land, [Vector2(4366, 404), Vector2(4338, 408), Vector2(4306, 392), Vector2(4284, 380)], [8.0, 5.4, 3.0, 0.7])
	# A few real side limbs that fork once, instead of short thorns.
	_limb(land, [Vector2(3504, 114), Vector2(3520, 86), Vector2(3532, 62), Vector2(3550, 38)], [5.0, 3.6, 2.4, 0.5])
	_limb(land, [Vector2(3520, 86), Vector2(3502, 68), Vector2(3498, 46)], [2.4, 1.5, 0.4])
	_limb(land, [Vector2(3780, 100), Vector2(3792, 74), Vector2(3788, 48), Vector2(3802, 22)], [5.0, 3.2, 2.2, 0.5])
	# A knot where the rope bites the limb.
	land.draw_circle(level.SWING_ANCHOR + Vector2(0.0, 6.0), 6.0, INK, true, -1.0, true)

func _draw_slab() -> void:
	var deck: Rect2 = level.SLAB_DECK
	var y := deck.position.y
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var outline := PackedVector2Array([
		Vector2(deck.position.x - 4.0, y + 5.0), Vector2(deck.position.x + 4.0, y + 0.5),
		Vector2(deck.position.x + 38.0, y - 0.6), Vector2(deck.position.x + 70.0, y + 0.2),
		Vector2(deck.end.x - 10.0, y - 0.5), Vector2(deck.end.x + 5.0, y + 7.0),
	])
	# Ragged, lopsided belly: chunks broke off unevenly, so no mirrored wedge.
	var count := 9
	for q in range(count):
		var u := 1.0 - float(q + 1) / float(count + 1)
		var skew := pow(u, 0.7)
		var depth := (10.0 + 66.0 * sin(PI * pow(u, 0.8))) * rng.randf_range(0.65, 1.15)
		if q % 2 == 1:
			depth *= rng.randf_range(0.55, 0.85)
		outline.append(Vector2(lerpf(deck.position.x, deck.end.x, skew) + rng.randf_range(-4.0, 4.0), y + depth))
	land.draw_colored_polygon(outline, INK)
	for chip in [Vector3(deck.end.x + 14.0, y + 48.0, 5.0), Vector3(deck.position.x - 16.0, y + 54.0, 4.0), Vector3(deck.position.x + 78.0, y + 92.0, 3.5)]:
		land.draw_colored_polygon(PackedVector2Array([Vector2(chip.x - chip.z, chip.y), Vector2(chip.x, chip.y - chip.z * 1.2), Vector2(chip.x + chip.z * 1.1, chip.y + chip.z * 0.2), Vector2(chip.x - chip.z * 0.3, chip.y + chip.z)]), INK)
	for root in range(3):
		var rx := deck.position.x + 24.0 + float(root) * 38.0 + rng.randf_range(-8.0, 8.0)
		var ry := y + 20.0 + rng.randf_range(0.0, 20.0)
		_limb(land, [Vector2(rx, ry), Vector2(rx + rng.randf_range(-6.0, 6.0), ry + 22.0), Vector2(rx + rng.randf_range(-8.0, 8.0), ry + rng.randf_range(46.0, 70.0))], [3.0, 1.8, 0.3])
	_beam(land, Vector2(deck.end.x - 30.0, y + 2.0), Vector2(deck.end.x - 16.0, y - 36.0), 4.6, 2.0)
	_beam(land, Vector2(deck.end.x - 21.0, y - 18.0), Vector2(deck.end.x - 4.0, y - 30.0), 3.0, 7.0)
	_beam(land, Vector2(deck.position.x + 22.0, y + 2.0), Vector2(deck.position.x + 12.0, y - 22.0), 3.6, 4.0)

func _draw_fire_deck() -> void:
	var deck: Rect2 = level.FIRE_DECK
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var x := deck.position.x - 2.0
	while x < deck.end.x + 2.0:
		var w := rng.randf_range(15.0, 22.0)
		var x1 := minf(x + w, deck.end.x + 2.0)
		land.draw_colored_polygon(PackedVector2Array([
			Vector2(x, deck.position.y), Vector2(x1 - 1.4, deck.position.y),
			Vector2(x1 - 1.4, deck.position.y + rng.randf_range(10.0, 14.0)), Vector2(x + 1.0, deck.position.y + rng.randf_range(9.0, 14.0)),
		]), INK)
		x = x1
	# Scaffold legs sink into the gas and fade with it.
	for post in [Vector3(deck.position.x + 8.0, 706.0, 7.0), Vector3(deck.get_center().x, 720.0, 8.0), Vector3(deck.end.x - 8.0, 700.0, 6.0)]:
		_beam(land, Vector2(post.x, deck.position.y + 8.0), Vector2(post.x + (post.y - 700.0) * 0.1, post.y), post.z, post.x)
	_beam(land, Vector2(deck.position.x + 8.0, deck.position.y + 18.0), Vector2(deck.get_center().x, 520.0), 4.4, 3.0)
	_beam(land, Vector2(deck.end.x - 8.0, deck.position.y + 18.0), Vector2(deck.get_center().x, 506.0), 4.0, 8.0)
	_beam(land, Vector2(deck.position.x - 6.0, deck.position.y + 15.0), Vector2(deck.end.x + 6.0, deck.position.y + 13.0), 4.6, 1.0)
	# The iron bowl under the flame slot and a few bent prongs around it.
	land.draw_colored_polygon(PackedVector2Array([
		Vector2(deck.get_center().x - 18.0, deck.position.y + 8.0), Vector2(deck.get_center().x + 18.0, deck.position.y + 8.0),
		Vector2(deck.get_center().x + 11.0, deck.position.y + 26.0), Vector2(deck.get_center().x - 10.0, deck.position.y + 25.0),
	]), INK)
	for prong in [-17.0, 15.0]:
		_limb(land, [Vector2(deck.get_center().x + prong, deck.position.y + 6.0), Vector2(deck.get_center().x + prong * 1.22, deck.position.y - 2.0), Vector2(deck.get_center().x + prong * 1.1, deck.position.y - 9.0)], [2.0, 1.4, 0.4])

# Each crumbling pillar is a weathered stone spire: a wedge of rock under the slab, a pinched
# neck, then a body that thickens unevenly toward the dark, with a boulder jammed against one side,
# a ledge, and roots hanging from the slab. No two are alike.
func _draw_spires() -> void:
	for index in range(level.FRAGILE_CAPS.size()):
		_draw_spire(level.FRAGILE_CAPS[index], index)

func _draw_spire(rect: Rect2, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6100 + index * 131
	var cx := rect.get_center().x
	var half_cap := rect.size.x * 0.5
	var top := rect.end.y - 5.0
	var ledge_depth := rng.randf_range(120.0, 190.0)
	var lean_phase := rng.randf_range(0.0, TAU)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var y := top
	while y < 800.0:
		var depth := y - top
		var wedge := 0.56 - 0.24 * smoothstep(0.0, 56.0, depth)
		var body := 0.46 * smoothstep(60.0, 380.0, depth)
		var ledge := 0.12 * smoothstep(ledge_depth - 14.0, ledge_depth, depth) * (1.0 - smoothstep(ledge_depth + 8.0, ledge_depth + 26.0, depth))
		var centre := cx + sin(depth * 0.011 + lean_phase) * 6.0
		var wl := half_cap * (wedge + body + ledge) + noise.get_noise_1d(y * 0.45 + float(index) * 57.0) * 4.5 + rng.randf_range(-1.2, 1.2)
		var wr := half_cap * (wedge + body + ledge * 0.4) + noise.get_noise_1d(y * 0.45 + float(index) * 57.0 + 300.0) * 4.5 + rng.randf_range(-1.2, 1.2)
		left.append(Vector2(centre - wl, y))
		right.append(Vector2(centre + wr, y))
		y += 12.0 + rng.randf_range(-2.0, 3.0)
	var outline := PackedVector2Array()
	outline.append_array(left)
	for k in range(right.size() - 1, -1, -1):
		outline.append(right[k])
	land.draw_colored_polygon(outline, INK)
	# A boulder wedged against the side, and a shard that has slid off a ledge.
	var side := 1.0 if index % 2 == 0 else -1.0
	var jam_y := top + rng.randf_range(80.0, 120.0)
	var jam_at := Vector2(cx + side * (half_cap * 0.56 + 6.0), jam_y)
	land.draw_colored_polygon(_xform(_rock_shape(40 + index, 19.0), jam_at, rng.randf_range(-0.5, 0.5)), INK)
	var second_at := Vector2(cx - side * (half_cap * 0.66 + 4.0), top + rng.randf_range(190.0, 250.0))
	land.draw_colored_polygon(_xform(_rock_shape(50 + index, 24.0), second_at, rng.randf_range(-0.5, 0.5)), INK)
	land.draw_colored_polygon(_xform(_rock_shape(60 + index, 10.0), jam_at + Vector2(-side * 10.0, 46.0), rng.randf_range(-1.0, 1.0)), INK)
	# Roots and moss strands hanging from the slab's underside.
	for n in range(3):
		var rx := rect.position.x + rect.size.x * (0.15 + 0.35 * float(n)) + rng.randf_range(-5.0, 5.0)
		_limb(land, [Vector2(rx, rect.end.y - 2.0), Vector2(rx + rng.randf_range(-5.0, 5.0), rect.end.y + 16.0), Vector2(rx + rng.randf_range(-7.0, 7.0), rect.end.y + rng.randf_range(34.0, 62.0))], [2.4, 1.5, 0.3])

func _xform(points: PackedVector2Array, at: Vector2, angle: float) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point.rotated(angle) + at)
	return moved

func _draw_set_dressing() -> void:
	# Thin dead shrubs and stakes. They are narrow enough never to hide the player.
	for spec in [
		Vector3(3900.0, 0.0, 44.0), Vector3(4130.0, 0.0, 36.0), Vector3(4970.0, 1.0, 52.0),
		Vector3(4868.0, 1.0, 34.0), Vector3(5858.0, 2.0, 66.0), Vector3(6072.0, 2.0, 54.0),
		Vector3(5802.0, 2.0, 38.0), Vector3(2842.0, 3.0, 40.0),
	]:
		var profile: PackedVector2Array
		match int(spec.y):
			0: profile = level.MARSH_LANDS[1]
			1: profile = level.MARSH_LANDS[2]
			2: profile = level.MARSH_LANDS[3]
			_: profile = level.MARSH_LANDS[0]
		_twig_fan(land, Vector2(spec.x, _visual_y(profile, spec.x) + 2.0), spec.z, int(spec.x))
	for stake in [Vector3(3748.0, 0.0, 46.0), Vector3(3762.0, 0.0, 30.0), Vector3(5046.0, 1.0, 42.0), Vector3(5065.0, 1.0, 26.0), Vector3(5792.0, 2.0, 34.0)]:
		var profile: PackedVector2Array = level.MARSH_LANDS[int(stake.y) + 1] if stake.y < 2.0 else level.MARSH_LANDS[3]
		var base := Vector2(stake.x, _visual_y(profile, stake.x) + 3.0)
		_beam(land, base, base + Vector2(sin(stake.x) * 6.0, -stake.z), 4.4, stake.x)

# --------------------------------------------------------------------- grass

func _draw_grass() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	# The raft bank under the ledge continues act one's tufts.
	var bank_x := 2548.0
	while bank_x < 2776.0:
		var y: float = level.art._bank_edge_y(bank_x)
		_blade(rng, bank_x, y, rng.randf_range(5.0, 15.0), 0.9)
		bank_x += rng.randf_range(3.0, 6.0)
	for i in range(level.MARSH_LANDS.size()):
		var profile: PackedVector2Array = level.MARSH_LANDS[i]
		var start: float = profile[0].x
		var end: float = profile[profile.size() - 1].x
		var x := start + 2.0
		# Like act one: long calm stretches of bare earth with a few hair-thin stalks, and only
		# here and there a tuft that gathers a handful of blades.
		while x < end:
			var edge := smoothstep(0.0, 26.0, minf(x - start, end - x))
			var cluster := 0.5 + noise.get_noise_1d(x * 1.1 + float(i) * 91.0) * 0.5
			if cluster > 0.66:
				var blades := rng.randi_range(3, 5)
				for b in range(blades):
					var bx := x + float(b) * rng.randf_range(2.5, 4.5)
					if bx < end - 4.0:
						_blade(rng, bx, _visual_y(profile, bx), lerpf(9.0, 22.0, cluster) * lerpf(0.5, 1.0, edge) * rng.randf_range(0.7, 1.0), 0.8)
				x += rng.randf_range(14.0, 24.0)
			else:
				_blade(rng, x, _visual_y(profile, x), rng.randf_range(3.0, 9.0) * lerpf(0.4, 1.0, edge), 0.45)
				x += rng.randf_range(9.0, 17.0)
		_draw_slope_grass(profile, i, rng)
		# Tall dry reeds, sparse and thin.
		var reeds := int((end - start) / 170.0)
		for n in range(reeds):
			var rx := rng.randf_range(start + 12.0, end - 12.0)
			_blade(rng, rx, _visual_y(profile, rx), rng.randf_range(26.0, 44.0), 0.45)
		# Strands that droop over each cliff lip.
		for lip in [start, end]:
			if (lip == start and i == 0) or (lip == end and i == level.MARSH_LANDS.size() - 1):
				continue
			var lip_dir: float = -1.0 if lip == start else 1.0
			for n in range(3):
				var gx: float = lip - lip_dir * rng.randf_range(9.0, 24.0)
				var gy := _visual_y(profile, clampf(gx, start, end))
				grass.draw_polygon(
					PackedVector2Array([Vector2(gx - 1.6, gy + 2.0), Vector2(gx + lip_dir * rng.randf_range(4.0, 11.0), gy + rng.randf_range(10.0, 24.0)), Vector2(gx + 1.6, gy + 2.0)]),
					PackedColorArray([Color(0, 0, 0, 1), Color(1, 0, 0, 1), Color(0, 0, 0, 1)])
				)
	var slab: Rect2 = level.SLAB_DECK
	for n in range(5):
		var sx := rng.randf_range(slab.position.x + 8.0, slab.end.x - 8.0)
		_blade(rng, sx, slab.position.y - 0.6, rng.randf_range(4.0, 10.0), 0.8)
	CliffArt.draw_grass(self)

# On a slope the body's box cannot follow the ground, so one foot hangs in the air. Like act one's
# hillside, every steep stretch gets a thick front band of grass that covers the feet.
func _slope_weight(profile: PackedVector2Array, x: float) -> float:
	var rise := absf(_profile_y(profile, x + 24.0) - _profile_y(profile, x - 24.0)) / 48.0
	return smoothstep(0.06, 0.18, rise)

# Runs of grass along the slopes. Short flat stretches between two slopes (the crown of a hill)
# are bridged, so the grass never stops dead in the middle of a hill.
func _draw_slope_grass(profile: PackedVector2Array, index: int, rng: RandomNumberGenerator) -> void:
	var start: float = profile[0].x + (10.0 if index > 0 else 0.0)
	var end: float = profile[profile.size() - 1].x - (10.0 if index < level.MARSH_LANDS.size() - 1 else 0.0)
	var runs: Array[Vector2] = []
	var x := start
	while x <= end:
		if _slope_weight(profile, x) > 0.04:
			if runs.size() > 0 and x - runs[runs.size() - 1].y < 180.0:
				runs[runs.size() - 1].y = x
			else:
				runs.append(Vector2(x, x))
		x += 4.0
	for run in runs:
		_slope_grass_run(profile, run.x - 4.0, run.y + 4.0, rng)

func _slope_grass_run(profile: PackedVector2Array, x0: float, x1: float, rng: RandomNumberGenerator) -> void:
	if x1 - x0 < 24.0:
		return
	# A dark band of roots along the slope hides the feet; it thins out where the ground flattens.
	var roots := PackedVector2Array()
	var x := x0
	while x <= x1:
		var w := _run_weight(profile, x, x0, x1)
		roots.append(Vector2(x, _visual_y(profile, x) - 1.4 - 11.0 * w - noise.get_noise_1d(x * 1.8) * 3.0 * w))
		x += 4.0
	x = x1
	while x >= x0:
		roots.append(Vector2(x, _visual_y(profile, x) + 10.0))
		x -= 4.0
	if roots.size() >= 3 and Geometry2D.triangulate_polygon(roots).size() > 0:
		grass.draw_colored_polygon(roots, Color(0, 0, 0, 1))
	x = x0
	while x < x1:
		var w := _run_weight(profile, x, x0, x1)
		var height := rng.randf_range(15.0, 30.0) * (0.25 + 0.75 * w)
		var lean := rng.randf_range(-9.0, 11.0)
		var y := _visual_y(profile, x)
		for offset in [-2.0, 2.0]:
			grass.draw_polygon(
				PackedVector2Array([Vector2(x + offset - 2.0, y + 5.0), Vector2(x + lean + offset * 2.0, y - height + absf(offset)), Vector2(x + offset + 2.0, y + 5.0)]),
				PackedColorArray([Color(0, 0, 0, 1), Color(1, 0, 0, 1), Color(0, 0, 0, 1)])
			)
		x += rng.randf_range(3.0, 6.0)

func _run_weight(profile: PackedVector2Array, x: float, x0: float, x1: float) -> float:
	var floor_w := 0.45 * smoothstep(0.0, 40.0, minf(x - x0, x1 - x))
	return maxf(_slope_weight(profile, x), floor_w)

func _blade(rng: RandomNumberGenerator, x: float, y: float, height: float, width_scale: float) -> void:
	var lean := rng.randf_range(-7.0, 9.0)
	grass.draw_polygon(
		PackedVector2Array([
			Vector2(x - 2.0 * width_scale, y + 4.0),
			Vector2(x + lean, y - height),
			Vector2(x + 2.0 * width_scale, y + 4.0),
		]),
		PackedColorArray([Color(0, 0, 0, 1), Color(1, 0, 0, 1), Color(0, 0, 0, 1)])
	)

# ------------------------------------------------------------- dynamic layer

func _draw_dynamic() -> void:
	_draw_swing()
	_draw_puzzle_box()
	_draw_fragile_caps()
	_draw_hang_deck()
	_draw_limb_outer()
	_draw_chips()
	_draw_rocks_ink()
	CliffArt.draw_dynamic(self)

# The preserved broken crate: an open wooden frame, hollow inside. Only the loaded top lip,
# the two uprights (the right one snapped), the sill and the diagonal brace exist.
func _draw_puzzle_box() -> void:
	if level.puzzle_box == null or not _visible_x(level.puzzle_box.position.x):
		return
	var o: Vector2 = level.puzzle_box.position
	_beam(dyn, o + Vector2(-3.0, 91.0), o + Vector2(107.0, 91.0), 11.0, 4.0)
	_beam(dyn, o + Vector2(7.0, 90.0), o + Vector2(5.0, 1.0), 10.0, 6.0)
	_beam(dyn, o + Vector2(93.0, 91.0), o + Vector2(98.0, 5.0), 12.0, 2.0)
	# The load-bearing top matches the collider; the damage is a chipped lower edge.
	dyn.draw_colored_polygon(PackedVector2Array([
		o + Vector2(0.0, 0.0), o + Vector2(102.0, 0.0), o + Vector2(105.0, 5.0), o + Vector2(98.0, 7.0),
		o + Vector2(102.0, 11.0), o + Vector2(82.0, 9.0), o + Vector2(67.0, 12.0), o + Vector2(41.0, 10.0),
		o + Vector2(18.0, 12.0), o + Vector2(-2.0, 8.0),
	]), INK)
	_beam(dyn, o + Vector2(8.0, 12.0), o + Vector2(93.0, 82.0), 12.0, 4.0)
	_beam(dyn, o + Vector2(9.0, 68.0), o + Vector2(42.0, 69.0), 8.0, 6.0)
	_beam(dyn, o + Vector2(58.0, 46.0), o + Vector2(94.0, 43.0), 8.0, 8.0)
	_beam(dyn, o + Vector2(23.0, 90.0), o + Vector2(24.0, 49.0), 7.0, 3.0)

func _draw_swing() -> void:
	if level.swing_body == null or not _visible_x(level.SWING_ANCHOR.x, 300.0):
		return
	var seat_rect := Rect2(level.swing_body.position, level.SWING_SIZE)
	var anchor: Vector2 = level.SWING_ANCHOR
	dyn.draw_line(anchor + Vector2(-16.0, 4.0), seat_rect.position + Vector2(8.0, 1.0), INK, 3.0, true)
	dyn.draw_line(anchor + Vector2(16.0, 4.0), seat_rect.position + Vector2(seat_rect.size.x - 8.0, 1.0), INK, 3.0, true)
	var seat := PackedVector2Array([
		seat_rect.position + Vector2(-3.0, 1.0),
		Vector2(seat_rect.end.x + 4.0, seat_rect.position.y),
		Vector2(seat_rect.end.x - 4.0, seat_rect.end.y + 4.0),
		Vector2(seat_rect.position.x + seat_rect.size.x * 0.58, seat_rect.end.y + 7.0),
		Vector2(seat_rect.position.x + 5.0, seat_rect.end.y + 3.0),
	])
	dyn.draw_colored_polygon(seat, INK)
	for knot in [8.0, seat_rect.size.x - 8.0]:
		dyn.draw_circle(seat_rect.position + Vector2(knot, -1.0), 3.2, INK, true, -1.0, true)

# ---- crumbling slabs ---------------------------------------------------------
# The slab on top of each spire. Its top is the collider's top; its underside is chipped and
# stepped, different for every slab, and it cleaves along ragged seams into chunks.
func _cap_underside(index: int) -> PackedVector2Array:
	if cap_undersides.has(index):
		return cap_undersides[index]
	var rect: Rect2 = level.FRAGILE_CAPS[index]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7300 + index * 211
	var points := PackedVector2Array()
	var x := rect.position.x - 6.0
	var end := rect.end.x + 6.0
	while x <= end:
		var u := clampf((x - rect.position.x) / rect.size.x, 0.0, 1.0)
		var belly := 0.55 + 0.6 * sin(PI * u)
		var depth := rect.size.y * belly * rng.randf_range(0.7, 1.12)
		if rng.randf() < 0.22:
			depth *= rng.randf_range(0.5, 0.75)
		points.append(Vector2(x, rect.position.y + depth + 3.0))
		x += rng.randf_range(6.0, 11.0)
	cap_undersides[index] = points
	return points

func _underside_y(points: PackedVector2Array, x: float) -> float:
	if x <= points[0].x:
		return points[0].y
	for i in range(points.size() - 1):
		if x <= points[i + 1].x:
			var a := points[i]
			var b := points[i + 1]
			return lerpf(a.y, b.y, clampf((x - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0))
	return points[points.size() - 1].y

# A slab piece between x0 and x1. The seams are zig-zagged so chunks fit like broken rock.
func _cap_piece(index: int, x0: float, x1: float, seam_l: float, seam_r: float) -> PackedVector2Array:
	var rect: Rect2 = level.FRAGILE_CAPS[index]
	var under := _cap_underside(index)
	var top_l := rect.position.y + (3.0 if x0 < rect.position.x else 0.0)
	var top_r := rect.position.y + (3.0 if x1 > rect.end.x else 0.0)
	var points := PackedVector2Array()
	points.append(Vector2(x0, top_l))
	points.append(Vector2(x1, top_r))
	var bottom_r := _underside_y(under, x1)
	var bottom_l := _underside_y(under, x0)
	points.append(Vector2(x1 + seam_r * 2.0, lerpf(top_r, bottom_r, 0.35)))
	points.append(Vector2(x1 - seam_r, lerpf(top_r, bottom_r, 0.7)))
	points.append(Vector2(x1, bottom_r))
	var x := x1 - 6.0
	while x > x0 + 4.0:
		points.append(Vector2(x, _underside_y(under, x)))
		x -= 8.0
	points.append(Vector2(x0, bottom_l))
	points.append(Vector2(x0 + seam_l, lerpf(top_l, bottom_l, 0.7)))
	points.append(Vector2(x0 - seam_l * 2.0, lerpf(top_l, bottom_l, 0.35)))
	return points

func _cap_seams(index: int) -> Array[float]:
	var rect: Rect2 = level.FRAGILE_CAPS[index]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8100 + index * 97
	var seams: Array[float] = [rect.position.x - 5.0]
	for k in range(1, 4):
		seams.append(rect.position.x + rect.size.x * float(k) / 4.0 + rng.randf_range(-7.0, 7.0))
	seams.append(rect.end.x + 5.0)
	return seams

func _draw_fragile_caps() -> void:
	for index in range(level.FRAGILE_CAPS.size()):
		_draw_fragile_cap(index)

func _draw_fragile_cap(index: int) -> void:
	var rect: Rect2 = level.FRAGILE_CAPS[index]
	if not _visible_x(rect.position.x):
		return
	var state: Dictionary = level.fragile_state(index)
	var phase: int = state.phase
	var t: float = state.time
	var break_time: float = state["break"]
	var seams := _cap_seams(index)
	var left: float = seams[0]
	var right: float = seams[seams.size() - 1]
	var loose_from := break_time * 0.55
	if phase == 0 or (phase == 1 and t < loose_from):
		var alpha := clampf(t / 0.7, 0.0, 1.0) if phase == 0 else 1.0
		var shake := smoothstep(0.0, loose_from, t) if phase == 1 else 0.0
		dyn.draw_set_transform(Vector2(sin(clock * 70.0 + float(index)) * 1.6 * shake, 0.0))
		dyn.draw_colored_polygon(_cap_piece(index, left, right, 0.0, 0.0), Color(INK.r, INK.g, INK.b, alpha))
		dyn.draw_set_transform(Vector2.ZERO)
		if alpha < 1.0:
			_draw_stump(index, 1.0 - alpha)
		return
	var elapsed: float = t if phase == 1 else break_time + t
	for frag in _cap_fragments(index):
		var fall: float = elapsed - loose_from - float(frag.delay)
		var center: Vector2 = frag.center
		var offset := Vector2.ZERO
		var angle := 0.0
		if fall > 0.0:
			var vel: Vector2 = frag.vel
			offset = Vector2(vel.x * fall, vel.y * fall + 0.5 * 1500.0 * fall * fall)
			angle = float(frag.spin) * fall
			if center.y + offset.y > 760.0:
				continue
		else:
			# Hanging by a thread: a faint shiver and a slight sag toward the side that gives first.
			var wob := smoothstep(-0.1, 0.0, fall)
			offset = Vector2(sin(clock * 70.0 + center.x) * 1.4, wob * 2.0)
			angle = float(frag.spin) * 0.02 * wob
		dyn.draw_set_transform(center + offset, angle)
		dyn.draw_colored_polygon(frag.local, INK)
	dyn.draw_set_transform(Vector2.ZERO)
	_draw_stump(index, 1.0)

# A broken crown on the spire once its slab has gone: jagged teeth instead of a flat cut.
func _draw_stump(index: int, alpha: float) -> void:
	var rect: Rect2 = level.FRAGILE_CAPS[index]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + index * 53
	var rng0 := RandomNumberGenerator.new()
	rng0.seed = 6100 + index * 131
	rng0.randf_range(120.0, 190.0)
	var lean_phase := rng0.randf_range(0.0, TAU)
	var top := rect.end.y - 5.0
	var cx := rect.get_center().x + sin(lean_phase) * 6.0
	var half := rect.size.x * 0.5 * 0.56 + noise.get_noise_1d(top * 0.45 + float(index) * 57.0) * 4.5
	var points := PackedVector2Array()
	points.append(Vector2(cx - half - 1.0, top + 6.0))
	var x := cx - half
	var tooth := 0
	while x < cx + half - 3.0:
		var width := rng.randf_range(5.0, 9.0)
		var height := rng.randf_range(4.0, 17.0) if tooth % 3 != 1 else rng.randf_range(1.0, 5.0)
		points.append(Vector2(x, top + 1.0))
		points.append(Vector2(x + width * rng.randf_range(0.25, 0.6), top - height))
		x += width
		tooth += 1
	points.append(Vector2(cx + half, top + 1.0))
	points.append(Vector2(cx + half + 1.0, top + 6.0))
	dyn.draw_colored_polygon(points, Color(INK.r, INK.g, INK.b, alpha))

# ---- slab fragments -----------------------------------------------------------
# Jagged edge between two lattice points, with a couple of wandering mid-points.
func _ragged(a: Vector2, b: Vector2, rng: RandomNumberGenerator, amount: float) -> PackedVector2Array:
	var normal := (b - a).orthogonal().normalized()
	var pts := PackedVector2Array()
	pts.append(a)
	for t in [0.28, 0.52, 0.76]:
		pts.append(a.lerp(b, t) + normal * rng.randf_range(-amount, amount) + (b - a).normalized() * rng.randf_range(-amount, amount) * 0.45)
	pts.append(b)
	return pts

func _reversed(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(points.size() - 1, -1, -1):
		out.append(points[k])
	return out

# The slab cut into irregular shards along crack lines that are shared between neighbours, so the
# pieces fit back together exactly until they come loose.
func _cap_fragments(index: int) -> Array:
	if cap_frags.has(index):
		return cap_frags[index]
	var frags: Array = []
	for jitter in [1.0, 0.7, 0.45, 0.2, 0.0]:
		frags = _build_fragments(index, jitter)
		if not frags.is_empty():
			break
	cap_frags[index] = frags
	return frags

func _build_fragments(index: int, jitter: float) -> Array:
	var rect: Rect2 = level.FRAGILE_CAPS[index]
	var under := _cap_underside(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8800 + index * 71
	var seams := _cap_seams(index)
	var cols := seams.size() - 1
	var top_y := rect.position.y + 3.0
	var xs := PackedFloat32Array()
	for k in range(seams.size()):
		xs.append(seams[k])
	# Lattice: row 0 on the top, row 1 in the middle (jittered), row 2 on the underside.
	var lattice: Array = []
	for k in range(xs.size()):
		var mid_shift := 0.0 if k == 0 or k == xs.size() - 1 else rng.randf_range(-9.0, 9.0) * jitter
		var bottom := _underside_y(under, xs[k])
		lattice.append([
			Vector2(xs[k], top_y),
			Vector2(xs[k] + mid_shift, lerpf(top_y, bottom, rng.randf_range(0.38, 0.62))),
			Vector2(xs[k], bottom),
		])
	# Shared edges.
	var vertical: Dictionary = {}
	var horizontal: Dictionary = {}
	for k in range(xs.size()):
		for r in range(2):
			var edge_amount := 0.0 if k == 0 or k == xs.size() - 1 else 4.5 * jitter
			vertical[Vector2i(k, r)] = _ragged(lattice[k][r], lattice[k][r + 1], rng, edge_amount)
	for k in range(cols):
		horizontal[Vector2i(k, 1)] = _ragged(lattice[k][1], lattice[k + 1][1], rng, 4.0 * jitter)
	var frags: Array = []
	for k in range(cols):
		for r in range(2):
			var poly := PackedVector2Array()
			# Top edge.
			if r == 0:
				poly.append(lattice[k][0])
				poly.append(lattice[k + 1][0])
			else:
				poly.append_array(horizontal[Vector2i(k, 1)])
			# Right edge going down.
			poly.append_array(vertical[Vector2i(k + 1, r)])
			# Bottom edge going back left.
			if r == 0:
				poly.append_array(_reversed(horizontal[Vector2i(k, 1)]))
			else:
				poly.append(lattice[k + 1][2])
				var x: float = xs[k + 1] - 6.0
				while x > xs[k] + 4.0:
					poly.append(Vector2(x, _underside_y(under, x)))
					x -= 8.0
				poly.append(lattice[k][2])
			# Left edge going up.
			poly.append_array(_reversed(vertical[Vector2i(k, r)]))
			# Drop consecutive duplicates so the triangulator is happy.
			var clean := PackedVector2Array()
			for point in poly:
				if clean.is_empty() or clean[clean.size() - 1].distance_to(point) > 0.4:
					clean.append(point)
			if clean.size() > 2 and clean[0].distance_to(clean[clean.size() - 1]) < 0.4:
				clean.remove_at(clean.size() - 1)
			if Geometry2D.triangulate_polygon(clean).is_empty():
				return []
			var sum := Vector2.ZERO
			for point in clean:
				sum += point
			var center := sum / float(clean.size())
			var local := PackedVector2Array()
			for point in clean:
				local.append(point - center)
			var spread := (center.x - rect.get_center().x) / (rect.size.x * 0.5)
			frags.append({
				"local": local, "center": center,
				"vel": Vector2(spread * rng.randf_range(20.0, 60.0) + rng.randf_range(-14.0, 14.0), -rng.randf_range(0.0, 70.0) if r == 1 else -rng.randf_range(0.0, 20.0)),
				"spin": rng.randf_range(-3.2, 3.2) + spread * 0.9,
				# The lower shards let go first, the top ones a beat later.
				"delay": (0.0 if r == 1 else 0.07) + rng.randf_range(0.0, 0.1),
			})
	return frags

# ---- the rope-hung deck -------------------------------------------------------
# Drawn in the dynamic layer: it swings and tilts with the player's weight, so the ropes follow its
# corners to anchors far above.
func _draw_hang_deck() -> void:
	var deck: Rect2 = level.HANG_DECK
	if not _visible_x(deck.get_center().x, 260.0):
		return
	var state: Dictionary = level.hang_state()
	var center: Vector2 = state.center
	var tilt: float = state.tilt
	var half := deck.size * 0.5
	var anchor_x := deck.get_center().x
	# Ropes: from each end of the deck up to a pair of anchors above the frame.
	for end in [-1.0, 1.0]:
		var near := center + Vector2(end * (half.x - 5.0), -half.y + 3.0).rotated(tilt)
		var far := center + Vector2(end * (half.x - 12.0), 5.0).rotated(tilt)
		var top := Vector2(anchor_x + end * 22.0, level.HANG_ANCHOR_Y)
		dyn.draw_line(near, top, INK, 2.4, true)
		dyn.draw_line(far, top + Vector2(end * 3.0, 0.0), INK, 1.8, true)
	dyn.draw_set_transform(center, tilt)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var x := -half.x - 3.0
	while x < half.x + 2.0:
		var w := rng.randf_range(14.0, 24.0)
		var x1 := minf(x + w, half.x + 3.0)
		var thickness := rng.randf_range(10.0, 15.0)
		dyn.draw_colored_polygon(PackedVector2Array([
			Vector2(x, -half.y), Vector2(x1 - 1.5, -half.y),
			Vector2(x1 - 1.5 + rng.randf_range(-1.0, 1.0), -half.y + thickness),
			Vector2(x + 1.0, -half.y + thickness + rng.randf_range(-2.0, 2.0)),
		]), INK)
		x = x1
	_beam(dyn, Vector2(-half.x - 8.0, half.y + 7.0), Vector2(half.x + 9.0, half.y + 4.0), 5.0, 3.0)
	_beam(dyn, Vector2(-half.x + 6.0, half.y + 14.0), Vector2(half.x - 7.0, half.y + 13.0), 4.0, 5.0)
	for tail in [Vector2(-18.0, 20.0), Vector2(11.0, 26.0)]:
		_limb(dyn, [Vector2(-half.x + 20.0 + tail.x, half.y + 11.0), Vector2(-half.x + 22.0 + tail.x, half.y + 11.0 + tail.y), Vector2(-half.x + 20.0 + tail.x, half.y + 21.0 + tail.y)], [1.8, 1.2, 0.3])
	dyn.draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- fog layer

func _draw_fog_puffs() -> void:
	for pit in level.MARSH_PITS:
		var left: float = pit.x
		var right: float = pit.y
		if right < camera_x - 200.0 or left > camera_x + SCREEN.x + 200.0:
			continue
		var width := right - left
		var count := int(width / 62.0) + 3
		for k in range(count):
			var x := left + fposmod(float(k) * 97.3 + clock * (4.0 + float(k % 3) * 2.5), width)
			var y := 526.0 + fposmod(float(k) * 37.0, 74.0) + sin(clock * 0.4 + float(k)) * 5.0
			var edge := smoothstep(0.0, 70.0, minf(x - left, right - x))
			_soft(fog, Vector2(x, y), Vector2(240.0 + float(k % 4) * 60.0, 70.0 + float(k % 3) * 20.0), Color(0.30, 0.30, 0.30, 0.12 * edge))
		# A low bank of fog lying on the bog, so the mud, stalks and their bases are seen through it.
		for k in range(int(width / 110.0) + 2):
			var bx := left - 60.0 + fposmod(float(k) * 151.7 + clock * (2.0 + float(k % 3) * 1.5), width + 120.0)
			var by := 566.0 + float(k % 3) * 14.0 + sin(clock * 0.25 + float(k) * 1.7) * 4.0
			_soft(fog, Vector2(bx, by), Vector2(300.0 + float(k % 3) * 70.0, 46.0 + float(k % 2) * 14.0), Color(0.16, 0.16, 0.155, 0.14))

# ------------------------------------------------------------ effects layer

func _draw_effects() -> void:
	_draw_fire()
	_draw_crumble_dust()
	CliffArt.draw_effects(self)

# One blister on the bog: it swells as a glossy dome until about four fifths of its life, bursts,
# and leaves an expanding ring that fades.
func _bog_bubble(canvas: Node2D, at: Vector2, radius: float, age: float, strength: float) -> void:
	if age < 0.78:
		var grow := smoothstep(0.0, 0.78, age)
		var r := radius * (0.25 + 0.75 * grow)
		# Out of focus: a soft dark body, a faint pale glint and a wide, faint ring.
		_soft(canvas, at + Vector2(0.0, -r * 0.3), Vector2(r * 3.0, r * 2.2), Color(0.04, 0.04, 0.04, 0.7))
		_soft(canvas, at + Vector2(-r * 0.25, -r * 0.7), Vector2(r * 1.0, r * 0.55), Color(0.5, 0.5, 0.47, 0.2 * strength))
		canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.24))
		canvas.draw_arc(Vector2.ZERO, r * 1.2, 0.0, TAU, 20, Color(0.45, 0.45, 0.42, 0.1 * strength), 3.0, true)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		var t := (age - 0.78) / 0.22
		canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.24))
		canvas.draw_arc(Vector2.ZERO, radius * (1.1 + 1.9 * t), 0.0, TAU, 24, Color(0.45, 0.45, 0.42, 0.16 * strength * (1.0 - t)), 3.2, true)
		canvas.draw_set_transform(Vector2.ZERO)
		for side in [-1.0, 1.0]:
			canvas.draw_circle(at + Vector2(side * radius * 0.5 * t, -radius * (0.9 * t - 0.8 * t * t)), 1.5 * (1.0 - t) + 0.4, Color(0.05, 0.05, 0.05, 0.9 * (1.0 - t)), true, -1.0, true)

# Mist drifting over the bubbles and crater, so nothing at the bog's surface is sharp.
func _draw_bog_veil() -> void:
	for pit_range in level.MARSH_PITS:
		var pit: Vector2 = pit_range
		if not _visible_x((pit.x + pit.y) * 0.5, (pit.y - pit.x) * 0.5 + 200.0):
			continue
		var width: float = pit.y - pit.x
		for k in range(int(width / 90.0) + 2):
			var x: float = pit.x - 40.0 + fposmod(float(k) * 83.7 + clock * (3.0 + float(k % 3) * 2.0), width + 80.0)
			var y: float = 572.0 + float(k % 4) * 9.0 + sin(clock * 0.3 + float(k)) * 4.0
			_soft(gas_back, Vector2(x, y), Vector2(170.0 + float(k % 3) * 60.0, 24.0 + float(k % 2) * 10.0), Color(0.15, 0.15, 0.145, 0.12))

func _draw_gas_back() -> void:
	# Dust and grit hang behind the ground and its grass, so a trail of it never lights the earth
	# or shows where the grass sits.
	_draw_dust()
	# Idle bog: the occasional slow bubble anywhere in every pit.
	for pit_range in level.MARSH_PITS:
		var pit: Vector2 = pit_range
		if not _visible_x((pit.x + pit.y) * 0.5, (pit.y - pit.x) * 0.5 + 200.0):
			continue
		var count := int((pit.y - pit.x) / 70.0)
		for k in range(count):
			var phase: float = clock * 0.16 + float(k) * 0.381 + pit.x * 0.0137
			var cycle: float = floorf(phase)
			var age: float = phase - cycle
			var bx: float = pit.x + (pit.y - pit.x) * _hash(cycle + float(k) * 3.7, pit.x * 0.01)
			if not _visible_x(bx, 60.0):
				continue
			_bog_bubble(gas_back, Vector2(bx, _bog_y(bx) + 4.0), 3.0 + _hash(cycle, float(k)) * 5.0, age, 0.5)
	for i in range(level.MARSH_GAS_RECTS.size()):
		var rect: Rect2 = level.MARSH_GAS_RECTS[i]
		var cx := rect.get_center().x
		if not _visible_x(cx, 260.0):
			continue
		var strength: float = level.marsh_gas_strength(i)
		var v := _vent_params(i)
		var mouth := Vector2(cx + float(v.lean) * 0.0, float(v.mouth))
		# Telegraph: the sludge bubbles and the mouth leaks a thin wisp long before it erupts, and
		# both quicken as the eruption nears.
		var activity := 0.3 + 0.7 * clampf(strength * 2.2, 0.0, 1.0)
		# Blisters swell in the slurry, burst and leave a ring. Before an eruption they come faster
		# and bigger, so the crater warns you.
		var reach: float = float(v.half) * 0.78
		for k in range(5):
			var rate := 0.3 + 0.55 * activity
			var phase: float = clock * rate + float(k) / 5.0 + float(i) * 0.37
			var cycle: float = floorf(phase)
			var age: float = phase - cycle
			var bx: float = cx + (_hash(cycle, float(k) + float(i) * 7.0) - 0.5) * reach * 0.8
			var radius := (4.0 + 9.0 * activity + _hash(cycle + 3.0, float(k)) * 5.0)
			_bog_bubble(gas_back, Vector2(bx, mouth.y + 5.0), radius, age, 0.7)
		# Background vapour: it hangs low over the crater, far behind the pillars and platforms, well
		# under their feet, and only breathes with the old cycle. It does no harm.
		var breath := 0.3 + 0.7 * strength
		var height := 30.0 + 44.0 * breath
		for k in range(10):
			var age := fposmod(clock * 0.2 + float(k) / 10.0 + float(i) * 0.31, 1.0)
			var x := cx + sin(age * 4.0 + float(k) * 1.9 + clock * 0.5) * (10.0 + age * 26.0)
			var y := mouth.y - 4.0 - age * height
			var radius := (30.0 + age * 40.0) * (0.7 + 0.3 * breath)
			var shade := 0.2 + age * 0.06
			_soft(gas_back, Vector2(x, y), Vector2(radius * 1.8, radius * 1.1), Color(shade, shade, shade, sin(age * PI) * 0.42 * breath))
	_draw_bog_veil()

# The flame is the particle fire (scripts/effects/ink_flame.gd): a wide base on the deck, ragged
# tips licking above the hazard, torn-off licks, sparks and a flickering glow. Its width is the
# hazard plus a margin and its height about 1.7 times the hazard, so what burns is what hurts.
func _build_flames() -> void:
	for i in range(level.MARSH_FIRE_RECTS.size()):
		var rect: Rect2 = level.MARSH_FIRE_RECTS[i]
		var flame := InkFlame.new() as Node2D
		flame.width = rect.size.x + 26.0
		flame.height = rect.size.y * 1.7
		flame.seed_value = i + 7
		flame.z_index = 2
		flame.position = Vector2(rect.get_center().x, rect.end.y + 2.0)
		flame.strength = 0.0
		flame.visible = false
		add_child(flame)
		flame_sprites.append(flame)

func _sync_flames() -> void:
	for i in range(flame_sprites.size()):
		var rect: Rect2 = level.MARSH_FIRE_RECTS[i]
		var flame: Node2D = flame_sprites[i]
		flame.visible = _visible_x(rect.get_center().x, 160.0)
		flame.set("strength", level.marsh_fire_strength(i))

func _draw_fire() -> void:
	for i in range(level.MARSH_FIRE_RECTS.size()):
		var rect: Rect2 = level.MARSH_FIRE_RECTS[i]
		if not _visible_x(rect.get_center().x):
			continue
		var strength: float = level.marsh_fire_strength(i)
		var base := Vector2(rect.get_center().x, rect.end.y)
		if strength < 0.05:
			# Banked coals between bursts.
			var ember := 0.4 + sin(clock * 5.0 + float(i)) * 0.14
			_soft(effects, base + Vector2(0.0, -3.0), Vector2(30.0, 12.0), Color(1.0, 0.40, 0.08, ember))
			effects.draw_circle(base + Vector2(-5.0, -2.0), 1.4, Color(1.0, 0.62, 0.2, ember + 0.2), true, -1.0, true)
			effects.draw_circle(base + Vector2(4.0, -3.0), 1.2, Color(1.0, 0.55, 0.15, ember + 0.2), true, -1.0, true)
			continue

# ---------------------------------------------------------------- the breakable limb
func _shift(points: Array, by: Vector2) -> Array:
	var shifted: Array = []
	for point in points:
		shifted.append(Vector2(point) - by)
	return shifted

# Outer half of the long limb. While intact it hangs exactly where the static half ends; once a
# boulder hits it, it snaps at the pivot, swings down, tears away and falls into the gas.
func _draw_limb_outer() -> void:
	var pivot := Vector2(level.LIMB_BREAK_X, level.LIMB_BREAK_Y)
	if not _visible_x(pivot.x, 420.0):
		return
	var state: Dictionary = level.limb_break_state()
	var spine := [Vector2(4258, 99.5), Vector2(4228, 94.0), Vector2(4196, 94.0), Vector2(4166, 103.0), Vector2(4146, 120.0)]
	var widths := [5.9, 5.0, 4.0, 2.6, 0.9]
	var droop := [Vector2(4214, 96.0), Vector2(4208, 120.0), Vector2(4214, 146.0)]
	var fork := [Vector2(4190, 94.5), Vector2(4176, 72.0), Vector2(4182, 50.0)]
	if not state.broken:
		_limb(dyn, spine, widths)
		_limb(dyn, droop, [4.0, 2.5, 0.4])
		_limb(dyn, fork, [3.0, 2.0, 0.4])
		return
	var t: float = state.time
	var swing := -(1.05 * smoothstep(0.0, 0.5, t) + maxf(0.0, t - 0.5) * 1.7)
	var fall := maxf(0.0, t - 0.42)
	var offset := Vector2(-fall * 46.0, 0.5 * 1500.0 * fall * fall)
	var alpha := 1.0 - smoothstep(470.0, 660.0, pivot.y + offset.y + 120.0)
	if alpha > 0.02:
		dyn.draw_set_transform(pivot + offset, swing)
		_limb(dyn, _shift(spine, pivot), widths)
		_limb(dyn, _shift(droop, pivot), [4.0, 2.5, 0.4])
		_limb(dyn, _shift(fork, pivot), [3.0, 2.0, 0.4])
		dyn.draw_set_transform(Vector2.ZERO)
	# The torn end left on the stump: long splinters along the grain and two hanging strips of bark.
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	for k in range(9):
		var y0 := pivot.y - 8.0 + float(k) * 1.9
		var reach := rng.randf_range(9.0, 27.0) * (1.0 if k % 2 == 0 else 0.5)
		dyn.draw_colored_polygon(PackedVector2Array([
			Vector2(pivot.x + 4.0, y0 - 1.8), Vector2(pivot.x - reach, y0 + rng.randf_range(-3.5, 4.5)), Vector2(pivot.x + 4.0, y0 + 2.2),
		]), INK)
	for strip in [Vector2(2.0, 20.0), Vector2(8.0, 13.0)]:
		dyn.draw_colored_polygon(PackedVector2Array([
			Vector2(pivot.x + 4.0 - strip.x, pivot.y + 5.0), Vector2(pivot.x - strip.x - 9.0, pivot.y + 5.0), Vector2(pivot.x - strip.x - 5.0, pivot.y + 5.0 + strip.y), Vector2(pivot.x - strip.x + 1.0, pivot.y + 3.0 + strip.y * 0.7),
		]), INK)

func _draw_chips() -> void:
	for chip in chips:
		if not _visible_x(chip.pos.x, 60.0):
			continue
		var size: float = chip.size
		dyn.draw_set_transform(chip.pos, chip.angle)
		dyn.draw_colored_polygon(PackedVector2Array([
			Vector2(-size, -size * 0.35), Vector2(size * 0.2, -size * 0.55), Vector2(size, size * 0.1), Vector2(-size * 0.3, size * 0.5),
		]), Color(INK.r, INK.g, INK.b, clampf(chip.life * 2.0, 0.0, 1.0)))
	dyn.draw_set_transform(Vector2.ZERO)

# A split boulder: seven to nine hard-cornered fracture faces of very different reach, a chipped
# notch, and only the lightest corner cutting, so the faces stay straight and the outline reads as
# broken rock, not a pebble.
func _rock_shape(seed_value: int, radius: float) -> PackedVector2Array:
	var key := seed_value * 1000 + int(radius)
	if rock_shapes.has(key):
		return rock_shapes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 311 + seed_value * 7919
	var count := rng.randi_range(7, 9)
	var notch := rng.randi_range(0, count - 1)
	var phase := rng.randf() * TAU
	var base: Array[Vector2] = []
	for q in range(count):
		var angle := phase + TAU * float(q) / float(count) + rng.randf_range(-0.2, 0.2)
		var reach := radius * rng.randf_range(0.72, 1.14)
		if q % 3 == 0:
			reach *= rng.randf_range(0.82, 0.95)
		base.append(Vector2(cos(angle) * reach, sin(angle) * reach * 0.94))
	var points := PackedVector2Array()
	for q in range(count):
		var a: Vector2 = base[q]
		var b: Vector2 = base[(q + 1) % count]
		points.append(a.lerp(b, 0.1))
		if q == notch:
			points.append(a.lerp(b, 0.5) * 0.84)
		points.append(a.lerp(b, 0.9))
	rock_shapes[key] = points
	return points

# The stone itself and its chips are ink, so they live on the brushed-ink stage.
func _draw_rocks_ink() -> void:
	for i in range(level.marsh_rocks.size()):
		var state: Dictionary = level.marsh_rock_state(i)
		if state.mode == level.ROCK_WAIT or state.mode == level.ROCK_WARN:
			continue
		var center: Vector2 = state.position
		if not _visible_x(center.x, 80.0) or center.y < -90.0:
			continue
		dyn.draw_set_transform(center, state.angle)
		dyn.draw_colored_polygon(_rock_shape(state.seed, state.radius), Color(INK.r, INK.g, INK.b, state.alpha))
		dyn.draw_set_transform(Vector2.ZERO)

# -------------------------------------------------------------- dust, grit and debris
func _puff(at: Vector2, velocity: Vector2, size: float, life: float, alpha: float) -> void:
	if dust.size() > 220:
		return
	dust.append({"pos": at, "vel": velocity, "age": 0.0, "life": life, "size": size, "alpha": alpha})

func _chip(at: Vector2, velocity: Vector2, size: float, life: float) -> void:
	if chips.size() > 90:
		return
	chips.append({"pos": at, "vel": velocity, "angle": dust_rng.randf() * TAU, "spin": dust_rng.randf_range(-9.0, 9.0), "size": size, "life": life})

func _burst(at: Vector2, count: int, spread: float, lift: float, size: float, alpha: float) -> void:
	for n in range(count):
		var side := dust_rng.randf_range(-1.0, 1.0)
		_puff(at + Vector2(side * spread * 0.4, dust_rng.randf_range(-4.0, 3.0)),
			Vector2(side * spread * dust_rng.randf_range(0.5, 1.4), -lift * dust_rng.randf_range(0.25, 1.0)),
			size * dust_rng.randf_range(0.7, 1.3), dust_rng.randf_range(0.7, 1.35), alpha)

func _update_effects(delta: float) -> void:
	# Particles first.
	for k in range(dust.size() - 1, -1, -1):
		var d: Dictionary = dust[k]
		d.age = float(d.age) + delta
		d.vel = Vector2(d.vel) * (1.0 - delta * 1.8) + Vector2(0.0, -6.0) * delta
		d.pos = Vector2(d.pos) + Vector2(d.vel) * delta
		if float(d.age) >= float(d.life):
			dust.remove_at(k)
	for k in range(chips.size() - 1, -1, -1):
		var c: Dictionary = chips[k]
		c.vel = Vector2(c.vel) + Vector2(0.0, 1500.0) * delta
		c.pos = Vector2(c.pos) + Vector2(c.vel) * delta
		c.angle = float(c.angle) + float(c.spin) * delta
		c.life = float(c.life) - delta
		if float(c.life) <= 0.0 or Vector2(c.pos).y > 700.0:
			chips.remove_at(k)
	var count: int = level.marsh_rocks.size()
	if prev_rock_modes.size() != count:
		prev_rock_modes.clear()
		for i in range(count):
			prev_rock_modes.append(level.ROCK_WAIT)
	# Boulders: grit before the fall, a burst at landing, a low dust train while rolling.
	var warning := false
	rock_trail_clock += delta
	for i in range(count):
		var state: Dictionary = level.marsh_rock_state(i)
		var mode: int = state.mode
		var radius: float = state.radius
		var at: Vector2 = state.position
		if mode == level.ROCK_WARN:
			warning = true
			warn_dust_clock += delta
			if warn_dust_clock > 0.035:
				warn_dust_clock = 0.0
				var gx: float = at.x + dust_rng.randf_range(-radius, radius)
				_puff(Vector2(gx, dust_rng.randf_range(2.0, 24.0)), Vector2(dust_rng.randf_range(-8.0, 8.0), dust_rng.randf_range(50.0, 120.0)), dust_rng.randf_range(10.0, 20.0), 0.7, 0.28)
				_chip(Vector2(gx, 0.0), Vector2(dust_rng.randf_range(-20.0, 20.0), dust_rng.randf_range(60.0, 180.0)), dust_rng.randf_range(1.6, 3.0), 1.2)
		if mode == level.ROCK_ROLL and prev_rock_modes[i] == level.ROCK_FALL:
			var ground := Vector2(at.x, level.marsh_rock_surface_y(at.x))
			_burst(ground, 22, 150.0, 70.0, 34.0, 0.46)
			for n in range(9):
				_chip(ground + Vector2(dust_rng.randf_range(-18.0, 18.0), -4.0), Vector2(dust_rng.randf_range(-170.0, 170.0), -dust_rng.randf_range(160.0, 380.0)), dust_rng.randf_range(2.0, 4.6), dust_rng.randf_range(0.5, 0.9))
		if mode == level.ROCK_DROP and prev_rock_modes[i] == level.ROCK_ROLL:
			_burst(at + Vector2(0.0, radius), 10, 90.0, 40.0, 26.0, 0.36)
		if mode == level.ROCK_ROLL and rock_trail_clock > 0.045:
			var speed: float = absf(state.vx)
			var heading := signf(state.vx)
			var ground_y: float = level.marsh_rock_surface_y(at.x)
			_puff(Vector2(at.x - heading * radius * 0.5, ground_y - 2.0), Vector2(-heading * dust_rng.randf_range(10.0, 36.0), -dust_rng.randf_range(8.0, 30.0)), dust_rng.randf_range(16.0, 30.0) * (0.6 + speed / 300.0), dust_rng.randf_range(0.8, 1.4), 0.34 * clampf(speed / 120.0, 0.45, 1.0))
		prev_rock_modes[i] = mode
	# Before the trap springs: far-off grit that thickens and creeps nearer the further the player climbs.
	var rumble: float = level.rock_rumble
	if rumble > 0.02 and not level.rock_sequence:
		warn_dust_clock += delta
		if warn_dust_clock > lerpf(0.16, 0.05, rumble):
			warn_dust_clock = 0.0
			var reach: float = lerpf(0.96, 0.55, rumble)
			var rx: float = camera_x + SCREEN.x * (reach + dust_rng.randf_range(-0.12, 0.05))
			_puff(Vector2(rx, dust_rng.randf_range(0.0, 30.0)), Vector2(dust_rng.randf_range(-6.0, 6.0), dust_rng.randf_range(40.0, 100.0)), dust_rng.randf_range(8.0, 16.0) * (0.6 + rumble * 0.6), 0.9, 0.12 + 0.14 * rumble)
	# While the player is frozen the whole ceiling of the scene sheds grit.
	if float(level.rock_lock_time) > 0.0 and not level.limb_broken:
		warn_dust_clock += delta
		if warn_dust_clock > 0.03:
			warn_dust_clock = 0.0
			var gx: float = camera_x + dust_rng.randf_range(0.0, SCREEN.x)
			_puff(Vector2(gx, dust_rng.randf_range(0.0, 20.0)), Vector2(dust_rng.randf_range(-8.0, 8.0), dust_rng.randf_range(60.0, 140.0)), dust_rng.randf_range(10.0, 22.0), 0.8, 0.26)
			_chip(Vector2(gx, 0.0), Vector2(dust_rng.randf_range(-20.0, 20.0), dust_rng.randf_range(70.0, 200.0)), dust_rng.randf_range(1.6, 3.4), 1.3)
	if rock_trail_clock > 0.045:
		rock_trail_clock = 0.0
	# Crumbling slabs: grit trickles from the cracks, then the whole top cleaves in a cloud.
	cap_grit_clock += delta
	for index in range(level.FRAGILE_CAPS.size()):
		var cap: Rect2 = level.FRAGILE_CAPS[index]
		var cap_state: Dictionary = level.fragile_state(index)
		var cap_phase: int = cap_state.phase
		var cap_t: float = cap_state.time
		var cap_break: float = cap_state["break"]
		var loose: bool = cap_phase == 2 or (cap_phase == 1 and cap_t >= cap_break * 0.55)
		if cap_phase == 1 and not loose and cap_grit_clock > 0.045:
			var gx := cap.position.x + dust_rng.randf() * cap.size.x
			var gy := _underside_y(_cap_underside(index), gx)
			_chip(Vector2(gx, gy), Vector2(dust_rng.randf_range(-14.0, 14.0), dust_rng.randf_range(20.0, 90.0)), dust_rng.randf_range(1.4, 3.2), 1.0)
			if dust_rng.randf() < 0.45:
				_puff(Vector2(gx, gy + 2.0), Vector2(dust_rng.randf_range(-6.0, 6.0), dust_rng.randf_range(10.0, 40.0)), dust_rng.randf_range(7.0, 13.0), 0.7, 0.2)
		if loose and not prev_cap_loose[index]:
			var mid := Vector2(cap.get_center().x, cap.end.y)
			_burst(mid, 20, cap.size.x * 1.4, 36.0, 26.0, 0.42)
			for n in range(14):
				var px := cap.position.x + dust_rng.randf() * cap.size.x
				_chip(Vector2(px, cap.position.y + dust_rng.randf_range(2.0, cap.size.y)), Vector2(dust_rng.randf_range(-130.0, 130.0), -dust_rng.randf_range(20.0, 190.0)), dust_rng.randf_range(2.4, 6.0), dust_rng.randf_range(0.7, 1.3))
			# Dust that slides down the shaft as the weight leaves it.
			for n in range(7):
				_puff(Vector2(cap.get_center().x + dust_rng.randf_range(-16.0, 16.0), cap.end.y + dust_rng.randf_range(0.0, 30.0)), Vector2(dust_rng.randf_range(-22.0, 22.0), dust_rng.randf_range(30.0, 90.0)), dust_rng.randf_range(16.0, 28.0), dust_rng.randf_range(1.0, 1.8), 0.32)
		prev_cap_loose[index] = loose
	if cap_grit_clock > 0.045:
		cap_grit_clock = 0.0
	CliffArt.react(self, delta)
	# The limb tearing apart.
	var broken: bool = level.limb_broken
	if broken and not prev_limb_broken:
		var pivot := Vector2(level.LIMB_BREAK_X, level.LIMB_BREAK_Y)
		_burst(pivot, 18, 170.0, 60.0, 30.0, 0.42)
		for n in range(16):
			_chip(pivot + Vector2(dust_rng.randf_range(-10.0, 18.0), dust_rng.randf_range(-6.0, 6.0)), Vector2(dust_rng.randf_range(-190.0, 260.0), -dust_rng.randf_range(40.0, 300.0)), dust_rng.randf_range(2.4, 6.5), dust_rng.randf_range(0.8, 1.5))
	prev_limb_broken = broken
	# The player's heels dig in while a boulder leans on them.
	var shove: Dictionary = level.rock_shove_info()
	feet_dust_clock += delta
	var resist: float = float(shove.get("resist", 0.0))
	if shove.active and feet_dust_clock > lerpf(0.04, 0.02, resist):
		feet_dust_clock = 0.0
		var back: float = -float(shove.dir)
		var feet: Vector2 = shove.feet
		var heavy := 1.0 + clampf(float(shove.speed) / 86.0, 0.0, 1.0) * 0.7 + resist * 0.9
		for n in range(2 + int(round(resist * 4.0))):
			_puff(feet + Vector2(dust_rng.randf_range(-9.0, 9.0), -2.0), Vector2(back * dust_rng.randf_range(30.0, 80.0) * heavy, -dust_rng.randf_range(8.0, 34.0) - resist * 24.0), dust_rng.randf_range(10.0, 20.0) * heavy, dust_rng.randf_range(0.55, 1.0) + resist * 0.35, 0.24 + resist * 0.14)
		if resist > 0.3:
			# grit thrown up by the heels
			for n in range(2):
				_chip(feet + Vector2(dust_rng.randf_range(-8.0, 8.0), -2.0), Vector2(back * dust_rng.randf_range(40.0, 150.0), -dust_rng.randf_range(30.0, 130.0)), dust_rng.randf_range(1.6, 3.8), dust_rng.randf_range(0.4, 0.8))

func _draw_dust() -> void:
	for d in dust:
		var k: float = float(d.age) / float(d.life)
		if not _visible_x(Vector2(d.pos).x, 80.0):
			continue
		var grow := 1.0 + k * 1.1
		var size: float = d.size
		_soft(gas_back, d.pos, Vector2(size * 1.5 * grow, size * grow), Color(0.50, 0.49, 0.46, float(d.alpha) * (1.0 - k) * minf(1.0, k * 8.0 + 0.35)))

func _draw_crumble_dust() -> void:
	for index in range(level.FRAGILE_CAPS.size()):
		_draw_crumble_dust_for(index)

func _draw_crumble_dust_for(index: int) -> void:
	var rect: Rect2 = level.FRAGILE_CAPS[index]
	if not _visible_x(rect.position.x):
		return
	var state: Dictionary = level.fragile_state(index)
	if state.phase != 1:
		return
	var break_time: float = state["break"]
	var t: float = state.time
	if t < 0.05 or t > break_time * 0.6:
		return
	# Hairline cracks open along the very seams the slab will split on.
	var grow := smoothstep(0.05, break_time * 0.5, t)
	var shake := smoothstep(0.0, break_time * 0.55, t)
	effects.draw_set_transform(Vector2(sin(clock * 70.0 + float(index)) * 1.6 * shake, 0.0))
	var seams := _cap_seams(index)
	var top := rect.position.y + 3.0
	for k in range(1, seams.size() - 1):
		var x: float = seams[k]
		var reach := (10.0 + 12.0 * float(k % 2)) * grow
		var pts := PackedVector2Array()
		var steps := 4
		for n in range(steps + 1):
			var f := float(n) / float(steps)
			pts.append(Vector2(x + sin(float(n) * 2.3 + float(k) * 1.7 + float(index)) * 3.0, top + f * reach))
		effects.draw_polyline(pts, Color(0.36, 0.36, 0.35, 0.75 * grow), 1.0, true)
	effects.draw_set_transform(Vector2.ZERO)

