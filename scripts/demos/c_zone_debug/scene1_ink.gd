extends RefCounted

# Ink drawing for scene 1 (see scene1_act.gd): a few trees, flat ground and six obstacles, each with one clear meaning:
#   a pit with stakes and a bramble are DANGER (jump over them); a fallen tree and a boulder are SOLID (climb them: their tops carry a thin
#   rim of light); a pond is only slow. Nothing else lies about. World coordinates (y up is negative).

const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const ForestInk = preload("res://scripts/demos/c_zone_debug/forest_ink.gd")
const INK := Color("050606")

static func _top(art, x: float) -> float:
	# the earth's edge is rough (clods, ruts) and never lower than the walkable line, so his feet never float over it
	var rough: float = absf(float(art.noise.get_noise_1d(x * 2.6))) * 3.2 + absf(float(art.noise.get_noise_1d(x * 9.0 + 70.0))) * 1.4
	return Scene1.ground_top(x) - 0.5 - rough

# draw_colored_polygon, skipping outlines that cannot be triangulated
static func _poly(canvas: Node2D, points: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(points).is_empty():
		return
	canvas.draw_colored_polygon(points, color)

# The outline of a tapering limb through the points (same as the marsh art's)
static func _limb_outline(points: Array, widths: Array) -> PackedVector2Array:
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
			var u := float(sample) / 14.0
			spine.append(a.bezier_interpolate(b, c, d, u))
			thickness.append(lerpf(float(widths[i]), float(widths[i + 1]), u))
	spine.append(points[points.size() - 1])
	thickness.append(float(widths[widths.size() - 1]))
	var outline := PackedVector2Array()
	for side in [1.0, -1.0]:
		for step in range(spine.size()):
			var i: int = step if side > 0.0 else spine.size() - 1 - step
			var direction: Vector2 = spine[mini(i + 1, spine.size() - 1)] - spine[maxi(0, i - 1)]
			var normal := Vector2(-direction.y, direction.x).normalized()
			outline.append(spine[i] + normal * thickness[i] * float(side))
	return outline

static func _limb(canvas: Node2D, points: Array, widths: Array) -> void:
	_poly(canvas, _limb_outline(points, widths), INK)

# Roughens a closed outline: it is resampled every `step` px and every sample is pushed in or out by noise (bark, chipped stone, torn
# roots). The silhouette itself carries the texture, since everything in the foreground is plain black.
static func _ragged(art, points: PackedVector2Array, step: float, amp: float, seed_value: float) -> PackedVector2Array:
	var area := 0.0
	for i in range(points.size()):
		var a0: Vector2 = points[i]
		var b0: Vector2 = points[(i + 1) % points.size()]
		area += a0.x * b0.y - b0.x * a0.y
	var flip := 1.0 if area > 0.0 else -1.0
	var out := PackedVector2Array()
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var d := b - a
		var length := d.length()
		if length < 0.01:
			continue
		var normal := Vector2(d.y, -d.x).normalized() * flip
		var n := maxi(1, int(length / step))
		for s in range(n):
			var p := a + d * (float(s) / float(n))
			var wobble: float = float(art.noise.get_noise_2d(p.x + seed_value * 13.0, p.y)) * amp + float(art.noise.get_noise_2d(p.x * 3.1 + seed_value, p.y * 3.1 + 50.0)) * amp * 0.55
			out.append(p + normal * wobble)
	return out

static func _round(points: PackedVector2Array, times: int) -> PackedVector2Array:
	return Scene1.round_corners(points, times)

static func _rough(art, points: PackedVector2Array, amount: float, seed_value: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p + Vector2(float(art.noise.get_noise_1d(p.x * 0.9 + seed_value * 31.0)) * amount, float(art.noise.get_noise_1d(p.y * 0.9 + seed_value * 17.0 + 400.0)) * amount))
	return out

# Is x close to an obstacle? (no tree stands there: it would swallow the obstacle's outline)
static func _near_obstacle(x: float, margin: float) -> bool:
	if x > Scene1.START_X - 170.0 - margin * 0.3 and x < Scene1.START_X + 420.0:
		return true  # where he lies and gets up: nothing black stands behind him
	for f: Dictionary in Scene1.FEATURES:
		var kind := String(f["t"])
		var from := Scene1.fx(f)
		var to := from
		match kind:
			"boulder":
				from -= float(f["bottom"]) * 0.7
				to += float(f["bottom"]) * 0.7
			"log":
				from -= 60.0
				to += float(f["len"]) + 30.0
			"spikes", "pit", "pond":
				to += float(f["w"])
			_:
				continue
		if x > from - margin and x < to + margin:
			return true
	return false

static func draw_static(art) -> void:
	_ground(art)
	_forest(art)
	for f: Dictionary in Scene1.FEATURES:
		match String(f["t"]):
			"boulder":
				_boulder_art(art, f)
			"spikes":
				_bramble(art, f)
			"log":
				_log_art(art, f)
			"pit":
				_pit_art(art, f)
	_cliff_edge(art)

# ------------------------------------------------------------------ the ground: one level slab (the pits are gaps in it)
static func _ground(art) -> void:
	var land: Node2D = art.land
	for piece: Vector2 in Scene1.ground_pieces():
		var points := PackedVector2Array()
		points.append(Vector2(piece.x, Scene1.GROUND_Y + 500.0))
		var x: float = piece.x
		while x < piece.y:
			points.append(Vector2(x, _top(art, x)))
			x += 8.0
		points.append(Vector2(piece.y, _top(art, piece.y)))
		points.append(Vector2(piece.y, Scene1.GROUND_Y + 500.0))
		_poly(land, points, INK)

# ------------------------------------------------------------------ trees: dead trunks, each one different, with a rough bark outline
# A branch with a few twigs: a list of outlines.
static func _branch_polys(art, from: Vector2, dir: float, length: float, thick: float, rng: RandomNumberGenerator, twigs: int, rough: float) -> Array:
	var out: Array = []
	var p1 := from + Vector2(dir * length * 0.5, -length * rng.randf_range(0.0, 0.2))
	var p2 := from + Vector2(dir * length, -length * rng.randf_range(0.1, 0.42))
	out.append(_ragged(art, _limb_outline([from, p1, p2], [thick, thick * 0.55, 0.8]), 5.0, rough, rng.randf() * 90.0))
	for k in range(twigs):
		var at := rng.randf_range(0.4, 0.95)
		var root := from.bezier_interpolate(p1, p1, p2, at)
		var up := rng.randf_range(0.5, 1.0)
		var tip := root + Vector2(dir * rng.randf_range(14.0, length * 0.4), -length * 0.28 * up)
		out.append(_limb_outline([root, root.lerp(tip, 0.5) + Vector2(0.0, -6.0), tip], [thick * 0.32, thick * 0.2, 0.4]))
	return out

# Every shape of one tree as outlines (trunk, branches). kind picks the species of dead tree. `scale` shrinks everything for far layers.
static func _tree_polys(art, base: Vector2, height: float, half: float, lean: float, kind: int, rng: RandomNumberGenerator, rough: float) -> Array:
	var polys: Array = []
	var broken := kind == 2
	var trunk_height := height
	if broken:
		trunk_height = height * rng.randf_range(0.34, 0.5)
	elif kind == 3:
		trunk_height = height * 0.78
	elif kind == 5:
		trunk_height = height * 0.84
	elif kind == 4:
		trunk_height = height * 0.7
	var steps := maxi(8, int(trunk_height / 18.0))
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var center_at: Array[float] = []
	var knot_phase := rng.randf_range(0.0, 6.0)
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		var cx := base.x + lean * u * u * 1.2 + float(art.noise.get_noise_1d(base.x * 0.3 + u * 6.0)) * 12.0 * u
		var y := base.y - trunk_height * u
		var taper := 0.62 if not broken else 0.22
		var w := half * (1.0 - taper * u) + half * 1.15 * exp(-u * 15.0)  # the foot flares out into the roots
		w += half * 0.3 * maxf(0.0, sin(u * 21.0 + knot_phase)) * maxf(0.0, sin(u * 7.3 + knot_phase * 2.0))  # knots and burls
		center_at.append(cx)
		left.append(Vector2(cx - w, y))
		right.append(Vector2(cx + w, y))
	var outline := PackedVector2Array()
	outline.append_array(left)
	var top_c: Vector2 = (left[left.size() - 1] + right[right.size() - 1]) * 0.5
	var top_w: float = (right[right.size() - 1].x - left[left.size() - 1].x) * 0.5
	if broken:
		# a splintered top
		outline.append(top_c + Vector2(-top_w * 0.7, -rng.randf_range(16.0, 40.0)))
		outline.append(top_c + Vector2(-top_w * 0.25, -rng.randf_range(2.0, 12.0)))
		outline.append(top_c + Vector2(top_w * 0.1, -rng.randf_range(30.0, 62.0)))
		outline.append(top_c + Vector2(top_w * 0.55, -rng.randf_range(4.0, 16.0)))
		outline.append(top_c + Vector2(top_w * 0.85, -rng.randf_range(14.0, 30.0)))
	for i in range(right.size() - 1, -1, -1):
		outline.append(right[i])
	polys.append(_ragged(art, outline, 6.0, rough, base.x * 0.07))
	# roots: a few bare toes spreading over the ground
	for s in [-1.0, 1.0]:
		if rng.randf() < 0.8:
			var reach := half * rng.randf_range(2.2, 3.6)
			polys.append(_limb_outline([base + Vector2(s * half * 0.5, -10.0), base + Vector2(s * half * 1.4, -rng.randf_range(4.0, 12.0)), base + Vector2(s * reach, 5.0)], [half * 0.5, half * 0.3, 1.0]))
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var at := func(u: float) -> Vector2:
		var idx := clampi(int(u * float(steps)), 0, steps)
		return Vector2(center_at[idx], base.y - trunk_height * float(idx) / float(steps))
	match kind:
		0:
			polys.append_array(_branch_polys(art, at.call(rng.randf_range(0.5, 0.8)), side, rng.randf_range(100.0, 200.0), half * 0.4, rng, 3, rough * 0.5))
		1:
			polys.append_array(_branch_polys(art, at.call(rng.randf_range(0.36, 0.5)), side, rng.randf_range(80.0, 160.0), half * 0.4, rng, 2, rough * 0.5))
			polys.append_array(_branch_polys(art, at.call(rng.randf_range(0.68, 0.86)), -side, rng.randf_range(70.0, 140.0), half * 0.34, rng, 3, rough * 0.5))
		2:
			polys.append_array(_branch_polys(art, at.call(rng.randf_range(0.5, 0.8)), side, rng.randf_range(40.0, 80.0), half * 0.35, rng, 1, rough * 0.5))
		3:
			var fork: Vector2 = at.call(1.0)
			for s in [-1.0, 1.0]:
				var tip := fork + Vector2(s * rng.randf_range(50.0, 110.0), -height * rng.randf_range(0.16, 0.26))
				polys.append(_ragged(art, _limb_outline([fork, fork + Vector2(s * 24.0, -height * 0.08), tip], [half * 0.4, half * 0.24, 1.2]), 5.0, rough * 0.6, rng.randf() * 90.0))
				polys.append_array(_branch_polys(art, fork.lerp(tip, 0.6), s, rng.randf_range(40.0, 90.0), half * 0.16, rng, 1, rough * 0.4))
		4:
			polys.append_array(_branch_polys(art, at.call(rng.randf_range(0.5, 0.75)), side, rng.randf_range(30.0, 60.0), half * 0.3, rng, 1, rough * 0.4))
		5:
			var crown: Vector2 = at.call(1.0)
			for k in range(rng.randi_range(3, 5)):
				var ang := lerpf(-1.25, 1.25, float(k) / 4.0) + rng.randf_range(-0.2, 0.2)
				var tip2 := crown + Vector2(sin(ang) * rng.randf_range(60.0, 130.0), -cos(ang) * rng.randf_range(70.0, 150.0))
				polys.append(_ragged(art, _limb_outline([crown, crown.lerp(tip2, 0.55) + Vector2(rng.randf_range(-12.0, 12.0), 0.0), tip2], [half * 0.3, half * 0.17, 0.8]), 5.0, rough * 0.5, rng.randf() * 90.0))
		6:
			polys.append_array(_branch_polys(art, at.call(rng.randf_range(0.25, 0.4)), side, rng.randf_range(90.0, 150.0), half * 0.4, rng, 2, rough * 0.5))
			var stub: Vector2 = at.call(0.74)
			polys.append(_limb_outline([stub, stub + Vector2(-side * 14.0, -10.0), stub + Vector2(-side * 28.0, -22.0)], [half * 0.24, half * 0.16, 1.0]))
		_:
			pass
	return polys

static func _tree(art, base: Vector2, rng: RandomNumberGenerator) -> void:
	var land: Node2D = art.land
	var kind := rng.randi_range(0, 7)
	var half := rng.randf_range(13.0, 32.0)
	if kind == 4:
		half = rng.randf_range(7.0, 11.0)
	var height := rng.randf_range(480.0, 900.0)
	for poly: PackedVector2Array in _tree_polys(art, base, height, half, rng.randf_range(-30.0, 30.0) * (1.8 if kind == 4 else 1.0), kind, rng, 2.6):
		_poly(land, poly, INK)

static func _forest(art) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 612
	var x: float = Scene1.WORLD_LEFT + 60.0
	# the forest goes on to the west without end and ends at the open ground before the cliff: he comes out of the trees
	while x < Scene1.START_X + 3200.0:
		var density: float = 1.0 - smoothstep(Scene1.START_X + 1500.0, Scene1.START_X + 3000.0, x)
		x += rng.randf_range(120.0, 320.0) + (1.0 - density) * 260.0
		if _near_obstacle(x, 190.0):
			continue
		_tree(art, Vector2(x, _top(art, x) + 3.0), rng)

# ------------------------------------------------------------------ DANGER: a pit with stakes
# A hole with plain walls; the stakes stand in it, sharpened and leaning, and their tips come up to the lip, against the mist.
static func _pit_art(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var x0 := Scene1.fx(f)
	var x1 := x0 + float(f["w"])
	var width := float(f["w"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0) * 3 + 11
	var floor_y := Scene1.GROUND_Y + Scene1.PIT_SPIKES_DEPTH + 60.0
	for side in [-1.0, 1.0]:
		var edge: float = x0 if side < 0.0 else x1
		var inward: float = -side
		var wall := PackedVector2Array([
			Vector2(edge - inward * 20.0, Scene1.GROUND_Y - 2.0),
			Vector2(edge + inward * 7.0, Scene1.GROUND_Y + 2.0),  # the lip leans over a little
			Vector2(edge + inward * 3.0, Scene1.GROUND_Y + 40.0),
			Vector2(edge + inward * 8.0, Scene1.GROUND_Y + 85.0),
			Vector2(edge + inward * 4.0, floor_y),
			Vector2(edge - inward * 20.0, floor_y + 6.0)])
		_poly(land, _ragged(art, wall, 6.0, 3.2, x0), INK)
	_poly(land, PackedVector2Array([Vector2(x0 - 10.0, floor_y + 600.0), Vector2(x0 - 4.0, floor_y), Vector2(x1 + 4.0, floor_y), Vector2(x1 + 10.0, floor_y + 600.0)]), INK)
	var count := int(width / 13.0)
	for k in range(count):
		var sx: float = x0 + (float(k) + 0.5) * width / float(count)
		var tall := rng.randf_range(142.0, 168.0)
		var lean := rng.randf_range(-14.0, 14.0)
		var base := Vector2(sx, floor_y)
		_poly(land, _ragged(art, _limb_outline([base, base + Vector2(lean * 0.45, -tall * 0.5), base + Vector2(lean, -tall)], [5.2, 3.8, 0.25]), 5.0, 0.9, sx), INK)
	if bool(f.get("island", false)):
		# a rock to land on in the middle of the wide pit: a plain worn pillar
		var cx := x0 + width * 0.5
		var pillar := PackedVector2Array([Vector2(cx - 26.0, floor_y + 20.0), Vector2(cx - 22.0, Scene1.GROUND_Y + 10.0), Vector2(cx - 12.0, Scene1.GROUND_Y + 1.0), Vector2(cx + 12.0, Scene1.GROUND_Y + 1.0), Vector2(cx + 21.0, Scene1.GROUND_Y + 10.0), Vector2(cx + 26.0, floor_y + 20.0)])
		_poly(land, _rough(art, _round(pillar, 1), 1.5, x0), INK)

# ------------------------------------------------------------------ DANGER: a thorn thicket
# A low dark mass whose whole outline is spikes (nothing else in the scene has a jagged outline), with a few long barbed canes over it.
static func _bramble(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var x0 := Scene1.fx(f)
	var w := float(f["w"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0) + 3
	var g := Scene1.GROUND_Y
	var outline := PackedVector2Array([Vector2(x0 - 6.0, g + 4.0)])
	var steps := int(w / 7.0)
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		var body := sin(PI * u)
		var base_y := g - 8.0 - 36.0 * pow(body, 0.6)
		outline.append(Vector2(x0 + u * w, base_y))
		# a spike between every two points, pointing outwards (up and to the side)
		var spike_u := u + 0.5 / float(steps)
		var tall := rng.randf_range(14.0, 26.0) * (0.5 + 0.5 * body)
		var lean := rng.randf_range(-9.0, 9.0) + (u - 0.5) * 16.0
		outline.append(Vector2(x0 + spike_u * w + lean * 0.3, base_y - tall))
	outline.append(Vector2(x0 + w + 6.0, g + 4.0))
	_poly(land, outline, INK)
	for k in range(5):
		var cx: float = x0 + w * (0.12 + 0.19 * float(k))
		var tall := rng.randf_range(50.0, 74.0)
		var drift := rng.randf_range(12.0, 26.0) * (1.0 if k % 2 == 0 else -1.0)
		var p0 := Vector2(cx, g - 14.0)
		var p1 := Vector2(cx + drift * 0.2, g - tall * 0.55)
		var p2 := Vector2(cx + drift * 0.8, g - tall)
		var p3 := Vector2(cx + drift * 1.3, g - tall * 0.8)
		_limb(land, [p0, p1, p2, p3], [2.4, 1.8, 1.2, 0.3])

# ------------------------------------------------------------------ SOLID: a fallen tree (climb it)
static func _log_art(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var x0 := Scene1.fx(f)
	var len := float(f["len"])
	var h := float(f["h"])
	var g := Scene1.GROUND_Y
	var end_h := h * Scene1.LOG_TAPER
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0) + 5
	var body := PackedVector2Array()
	body.append(Vector2(x0 - 22.0, g + 4.0))
	body.append(Vector2(x0 - 16.0, g - h * 0.5))
	body.append(Vector2(x0 - 4.0, g - h * 0.92))
	# the top: bark ridges (small rounded bumps) and a couple of knots
	var steps := int(len / 9.0)
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		var ridge := absf(sin(u * len / 7.0 + rng.randf_range(-0.4, 0.4))) * 2.2
		var knot := 0.0
		if i == int(steps * 0.3) or i == int(steps * 0.74):
			knot = 4.5
		body.append(Vector2(x0 + u * len, g - h * lerpf(1.0, Scene1.LOG_TAPER, u) - ridge * 0.4 - knot * (1.0 if i % 2 == 0 else 0.4)))
	# the broken end: long splinters
	body.append(Vector2(x0 + len + 2.0, g - end_h - 14.0))
	body.append(Vector2(x0 + len + 5.0, g - end_h + 4.0))
	body.append(Vector2(x0 + len + 12.0, g - end_h * 0.8))
	body.append(Vector2(x0 + len + 6.0, g - end_h * 0.55))
	body.append(Vector2(x0 + len + 13.0, g - end_h * 0.3))
	body.append(Vector2(x0 + len + 7.0, g + 4.0))
	_poly(land, _ragged(art, body, 5.0, 1.9, x0 * 0.01), INK)
	# the torn-up roots at the root end
	for k in range(5):
		var ang := lerpf(-3.6, -2.6, float(k) / 4.0)
		var from := Vector2(x0 - 2.0, g - h * 0.5) + Vector2(cos(ang), sin(ang)) * 6.0
		var mid := from + Vector2(cos(ang), sin(ang) * 0.7) * rng.randf_range(18.0, 30.0)
		var tip := from + Vector2(cos(ang + rng.randf_range(-0.3, 0.3)), sin(ang) * 0.5 + 0.2) * rng.randf_range(40.0, 62.0)
		_poly(land, _ragged(art, _limb_outline([from, mid, tip], [4.6, 2.6, 0.4]), 4.0, 1.0, float(k)), INK)
		var knot_at := from.lerp(mid, 0.8)
		_limb(land, [knot_at, knot_at + Vector2(-10.0, 9.0 * (1.0 if k % 2 == 0 else -1.0)), knot_at + Vector2(-20.0, 16.0 * (1.0 if k % 2 == 0 else -0.6))], [1.8, 1.1, 0.3])
	# two broken branches standing from the top, one long
	for k in range(2):
		var bx := x0 + len * (0.2 + 0.5 * float(k)) + rng.randf_range(-8.0, 8.0)
		var top_here := g - h * lerpf(1.0, Scene1.LOG_TAPER, (bx - x0) / len)
		var bh := rng.randf_range(26.0, 50.0)
		_poly(land, _ragged(art, _limb_outline([Vector2(bx, top_here + 6.0), Vector2(bx + 3.0, top_here - bh * 0.5), Vector2(bx + rng.randf_range(-6.0, 10.0), top_here - bh)], [5.0, 3.4, 0.8]), 4.0, 1.0, bx), INK)

# ------------------------------------------------------------------ SOLID: a boulder (climb it)
static func _boulder_art(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var base: PackedVector2Array = Scene1.boulder_points(f)  # rounded (it is also the collision)
	var seed_value := float(f["seed"])
	# a chipped, weathered outline: coarse bumps and fine grit
	_poly(land, _ragged(art, base, 6.0, 4.2, seed_value), INK)
	# a few angular shards stuck on the upper contour and heaped at the foot: broken-off pieces
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value) * 29 + 7
	var cx := Scene1.fx(f)
	var g := Scene1.ground_top(cx)
	var bottom := float(f["bottom"]) * 0.5
	for k in range(4):
		var side := -1.0 if k % 2 == 0 else 1.0
		var sx := cx + side * (bottom * rng.randf_range(0.8, 1.25))
		var sh := rng.randf_range(10.0, 22.0)
		_poly(land, _ragged(art, PackedVector2Array([Vector2(sx - side * 20.0, g + 3.0), Vector2(sx - side * 8.0, g - sh), Vector2(sx + side * 2.0, g - sh * 0.55), Vector2(sx + side * 14.0, g - sh * 0.2), Vector2(sx + side * 22.0, g + 3.0)]), 4.0, 1.6, seed_value + float(k)), INK)

# ------------------------------------------------------------------ the edge of the cliff
static func _cliff_edge(art) -> void:
	var land: Node2D = art.land
	var g := Scene1.ground_top(Scene1.CLIFF_X)
	var x0 := Scene1.CLIFF_X
	var lip := PackedVector2Array([Vector2(x0 - 40.0, g - 2.0), Vector2(x0 + 6.0, g - 1.0), Vector2(x0 + 22.0, g + 10.0), Vector2(x0 + 4.0, g + 30.0), Vector2(x0 + 26.0, g + 60.0), Vector2(x0 - 8.0, g + 96.0), Vector2(x0 + 14.0, g + 140.0), Vector2(x0 - 24.0, g + 190.0), Vector2(x0 - 40.0, g + 260.0)])
	_poly(land, lip, INK)

# ------------------------------------------------------------------ grass: in patches, none where nothing grows; reeds round the ponds
static func draw_grass(art) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4412
	var x: float = Scene1.START_X - 200.0
	while x < Scene1.CLIFF_X - 60.0:
		var patch: float = float(art.noise.get_noise_1d(x * 0.9 + 300.0))  # -1 .. 1, slowly changing: where the grass grows
		if patch > 0.12 and not _near_obstacle(x, 24.0):
			# a clump: a few blades of different heights leaning different ways, close together
			var blades := rng.randi_range(2, 6)
			for b in range(blades):
				var bx := x + rng.randf_range(-7.0, 7.0)
				art._blade(rng, bx, _top(art, bx), rng.randf_range(6.0, 12.0 + 20.0 * patch), rng.randf_range(0.45, 0.9))
			x += rng.randf_range(14.0, 70.0)
		else:
			x += rng.randf_range(18.0, 60.0)
	for f: Dictionary in Scene1.FEATURES:
		if String(f["t"]) == "pond":
			var x0 := Scene1.fx(f)
			for side in [0.0, 1.0]:
				for i in range(rng.randi_range(3, 6)):
					var rx := x0 + (-6.0 - rng.randf_range(0.0, 34.0) if side < 0.5 else float(f["w"]) + 6.0 + rng.randf_range(0.0, 34.0))
					art._blade(rng, rx, _top(art, rx), rng.randf_range(22.0, 48.0), 0.5)

# ------------------------------------------------------------------ mist: pale along the ground behind everything, so the silhouettes stand out
# Trees at two depths behind the lane, in the mist and passing slower than the camera: the forest around him. Same builder as the lane
# trees (every one different, rough bark, branches), grey instead of black. Finite (the last comes in from the right edge as the
# backdrop opens), and they fade out with it.
const DEPTH_LAYERS := [[0.58, 0.30, 150.0, 22.0, 40.0], [0.80, 0.15, 210.0, 16.0, 32.0]]
const CAMERA_RANGE := Vector2(-8500.0, -4700.0)  # the camera positions that scene 1 uses

# Each depth layer is its own node, drawn once and only moved afterwards (the bark outlines are expensive).
static func _update_depth(art) -> void:
	if not art.has_meta("scene1_depth"):
		var nodes: Array = []
		for layer_index in range(DEPTH_LAYERS.size()):
			var node := Node2D.new()
			node.z_index = -4
			node.draw.connect(_draw_depth_layer.bind(node, art, layer_index))
			art.add_child(node)
			nodes.append(node)
		art.set_meta("scene1_depth", nodes)
	var cam: float = art.camera_x
	var fade: float = 1.0 - smoothstep(-6000.0, -4800.0, cam)
	var nodes2: Array = art.get_meta("scene1_depth")
	for layer_index in range(nodes2.size()):
		var node2: Node2D = nodes2[layer_index]
		var k: float = DEPTH_LAYERS[layer_index][0]
		node2.visible = fade > 0.01 and cam < -4700.0
		node2.position = Vector2(cam * (1.0 - k), 0.0)
		node2.modulate = Color(1.0, 1.0, 1.0, 0.9 * fade)

static func _draw_depth_layer(node: Node2D, art, layer_index: int) -> void:
	var layer: Array = DEPTH_LAYERS[layer_index]
	var k: float = layer[0]
	var grey: float = layer[1]
	var spacing: float = layer[2]
	var color := Color(grey, grey, grey, 1.0)
	var first := int(floor((CAMERA_RANGE.x * k - 300.0) / spacing)) - 1
	var last := int(ceil((CAMERA_RANGE.y * k + 1600.0) / spacing)) + 1
	for i in range(first, last + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 131 + int(k * 100.0)
		var xi := float(i) * spacing + rng.randf_range(-spacing * 0.35, spacing * 0.35)
		if xi > 1400.0 - 6000.0 * k or rng.randf() < 0.15:
			continue
		var kind := rng.randi_range(0, 7)
		var half: float = rng.randf_range(float(layer[3]), float(layer[4]))
		if kind == 4:
			half *= 0.4
		for poly: PackedVector2Array in _tree_polys(art, Vector2(xi, Scene1.GROUND_Y + 8.0), rng.randf_range(420.0, 1000.0), half, rng.randf_range(-40.0, 40.0), kind, rng, 3.0):
			if not Geometry2D.triangulate_polygon(poly).is_empty():
				node.draw_colored_polygon(poly, color)

static func draw_fog(art) -> void:
	var fog: Node2D = art.fog
	_update_depth(art)
	var strip := 300.0
	var sx: float = Scene1.WORLD_LEFT
	while sx < Scene1.CLIFF_X:
		var fade_a: float = 1.0 - smoothstep(Scene1.START_X + 2400.0, Scene1.START_X + 3300.0, sx)
		var fade_b: float = 1.0 - smoothstep(Scene1.START_X + 2400.0, Scene1.START_X + 3300.0, sx + strip)
		var low_a := Color(0.74, 0.74, 0.72, 0.62 * fade_a)
		var low_b := Color(0.74, 0.74, 0.72, 0.62 * fade_b)
		var high := Color(0.74, 0.74, 0.72, 0.0)
		fog.draw_polygon(PackedVector2Array([Vector2(sx, Scene1.GROUND_Y - 160.0), Vector2(sx + strip, Scene1.GROUND_Y - 160.0), Vector2(sx + strip, Scene1.GROUND_Y + 2.0), Vector2(sx, Scene1.GROUND_Y + 2.0)]), PackedColorArray([high, high, low_b, low_a]))
		sx += strip
	# the mist reaches down into each pit, fading as it sinks
	for f: Dictionary in Scene1.FEATURES:
		if String(f["t"]) == "pit":
			var px0 := Scene1.fx(f)
			var px1 := px0 + float(f["w"])
			var top_c := Color(0.74, 0.74, 0.72, 0.62)
			var bottom_c := Color(0.5, 0.5, 0.5, 0.0)
			fog.draw_polygon(PackedVector2Array([Vector2(px0, Scene1.GROUND_Y + 2.0), Vector2(px1, Scene1.GROUND_Y + 2.0), Vector2(px1, Scene1.GROUND_Y + 110.0), Vector2(px0, Scene1.GROUND_Y + 110.0)]), PackedColorArray([top_c, top_c, bottom_c, bottom_c]))

# ------------------------------------------------------------------ in front: nothing. The foreground is pure black; its texture is its outline.
static func draw_effects(_art) -> void:
	pass
