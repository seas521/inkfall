extends RefCounted

# Ink drawing for scene 1 (see scene1_act.gd): the forest, the natural ground (mounds, boulders, pits, ponds, a fallen trunk) and the
# cliff edge, in the marsh art's ink stage so that it looks like the rest of the zone. World coordinates (y up is negative).

const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const ForestInk = preload("res://scripts/demos/c_zone_debug/forest_ink.gd")
const INK := Color("050606")

static func _top(art, x: float) -> float:
	return Scene1.ground_top(x) - 1.4 + float(art.noise.get_noise_1d(x * 1.1 + 5000.0)) * 2.0 + float(art.noise.get_noise_1d(x * 4.0)) * 0.7

static func draw_static(art) -> void:
	_ground(art)
	_forest(art)
	_features(art)
	_cliff_edge(art)

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
	for f: Dictionary in Scene1.FEATURES:
		if String(f["t"]) == "pit":
			_pit_art(art, f)

# Trees: a dense forest where he wakes up, thinning out towards the cliff; none on top of a feature.
static func _forest(art) -> void:
	var land: Node2D = art.land
	var rng := RandomNumberGenerator.new()
	rng.seed = 612
	var x: float = Scene1.WORLD_LEFT + 60.0
	# the forest goes on to the west without end and stops at the open ground before the cliff: he comes out of the trees
	while x < Scene1.START_X + 5900.0:
		var density: float = 1.0 - smoothstep(Scene1.START_X + 4000.0, Scene1.START_X + 5800.0, x)  # 1 at the start, 0 near the open ground
		if _near_obstacle(x):
			x += 90.0  # no tree stands where an obstacle is (it would swallow its outline)
			continue
		var base := Vector2(x, _top(art, x) + 3.0)
		var big := x < Scene1.START_X + 400.0 or rng.randf() < 0.30 + density * 0.4
		if big:
			var height := rng.randf_range(520.0, 900.0)
			var half := rng.randf_range(24.0, 46.0)
			var lean := rng.randf_range(-24.0, 24.0)
			ForestInk._trunk(art, base, height, [half, half * 0.74, half * 0.52, half * 0.3], lean)
			_roots(art, base, half, rng)
			# broken limb stubs low on the trunk, and a burl
			for k in range(rng.randi_range(1, 3)):
				var side: float = 1.0 if rng.randf() < 0.5 else -1.0
				var at_h: float = rng.randf_range(0.12, 0.46) * height
				var stub_from := base + Vector2(lean * (at_h / height) * 0.5 + side * half * 0.5, -at_h)
				_limb(land, [stub_from, stub_from + Vector2(side * rng.randf_range(14.0, 26.0), -rng.randf_range(2.0, 8.0)), stub_from + Vector2(side * rng.randf_range(30.0, 52.0), rng.randf_range(-12.0, 4.0))], [half * 0.2, half * 0.14, 1.0])
			var burl_h: float = rng.randf_range(0.2, 0.5) * height
			_poly(land, art._blob(base + Vector2(lean * (burl_h / height) * 0.5 + (half * 0.62 if rng.randf() < 0.5 else -half * 0.62), -burl_h), half * 0.4, half * 0.55, rng, 10, 0.2), INK)
			ForestInk._branch(art, [base + Vector2(lean * 0.6, -height * 0.55), base + Vector2(lean * 0.6 + 70.0, -height * 0.62), base + Vector2(lean * 0.6 + 150.0, -height * 0.7)], [half * 0.22, half * 0.14, 2.0], 3, int(x))
			ForestInk._branch(art, [base + Vector2(lean * 0.9, -height * 0.8), base + Vector2(lean * 0.9 - 60.0, -height * 0.86), base + Vector2(lean * 0.9 - 130.0, -height * 0.92)], [half * 0.2, half * 0.12, 1.8], 3, int(x) + 7)
		else:
			var h2 := rng.randf_range(280.0, 460.0)
			var lean2 := rng.randf_range(-14.0, 14.0)
			ForestInk._trunk(art, base, h2, [13.0, 9.5, 6.5, 3.5], lean2)
			_roots(art, base, 13.0, rng)
			ForestInk._branch(art, [base + Vector2(lean2 * 0.5, -h2 * 0.5), base + Vector2(lean2 * 0.5 + 36.0, -h2 * 0.62), base + Vector2(lean2 * 0.5 + 76.0, -h2 * 0.78)], [4.4, 2.6, 0.5], 3, int(x))
		x += rng.randf_range(150.0, 330.0) + (1.0 - density) * 260.0

# a tuft of grass drawn into the ground layer (a thin curved blade)
static func _tuft(art, rng: RandomNumberGenerator, x: float, y: float, height: float) -> void:
	var lean := rng.randf_range(-0.5, 0.5) * height
	_limb(art.land, [Vector2(x, y + 1.0), Vector2(x + lean * 0.3, y - height * 0.55), Vector2(x + lean, y - height)], [1.3, 0.9, 0.15])

# draw_colored_polygon, skipping (and reporting) outlines that cannot be triangulated
static func _poly(canvas: Node2D, points: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(points).is_empty():
		return
	canvas.draw_colored_polygon(points, color)

# A tapering limb through the points (same as the marsh art's), skipping outlines that fold over themselves
static func _limb(canvas: Node2D, points: Array, widths: Array) -> void:
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
	if Geometry2D.triangulate_polygon(outline).is_empty():
		return
	canvas.draw_colored_polygon(outline, INK)

static func _near_obstacle(x: float, margin := 90.0) -> bool:
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
			"rock":
				from -= float(f["w"])
				to += float(f["w"])
			_:
				continue
		if x > from - margin and x < to + margin:
			return true
	return false

static func _round(points: PackedVector2Array, times: int) -> PackedVector2Array:
	return Scene1.round_corners(points, times)

static func _rough(art, points: PackedVector2Array, amount: float, seed_value: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p + Vector2(float(art.noise.get_noise_1d(p.x * 0.9 + seed_value * 31.0)) * amount, float(art.noise.get_noise_1d(p.y * 0.9 + seed_value * 17.0 + 400.0)) * amount))
	return out

static func _boulder_art(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var base: PackedVector2Array = Scene1.boulder_points(f)  # already rounded (it is also the collision)
	_poly(land, _rough(art, base, 3.6, float(f["seed"])), INK)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f["seed"]) * 29 + 7
	var cx := Scene1.fx(f)
	var g := Scene1.ground_top(cx)
	var bottom := float(f["bottom"]) * 0.5
	var top := float(f["top"]) * 0.5
	var h := float(f["h"])
	var side := 1.0 if int(f["seed"]) % 2 == 0 else -1.0
	# a smaller stone and a chip of rock at the foot
	_poly(land, art._blob(Vector2(cx - side * (bottom + 20.0), g - 8.0), 18.0, 11.0, rng, 11, 0.24), INK)
	_poly(land, art._blob(Vector2(cx + side * (bottom + 14.0), g - 4.0), 9.0, 6.0, rng, 9, 0.24), INK)
	# a root draped over the top, and grass in the crack
	_limb(land, [Vector2(cx - top * 0.5, g - h + 3.0), Vector2(cx - top * 1.4, g - h * 0.7), Vector2(cx - bottom * 0.95, g - h * 0.25), Vector2(cx - bottom * 1.25, g + 2.0)], [3.4, 2.6, 2.0, 0.6])
	for k in range(6):
		_tuft(art, rng, cx - top + rng.randf_range(0.0, top * 2.0), g - h + 1.0, rng.randf_range(8.0, 18.0))

# ------------------------------------------------------------------ the spiked pit
# A hole in the ground: ragged walls, a lip that overhangs and has roots hanging from it, rubble at the bottom and sharpened stakes (some
# leaning, some broken) with a few bones. There is no fill: the backdrop shows through the hole, so the stakes stand against it.
static func _pit_art(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var x0 := Scene1.fx(f)
	var x1 := x0 + float(f["w"])
	var width := float(f["w"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0) * 3 + 11
	var floor_y := Scene1.GROUND_Y + Scene1.PIT_SPIKES_DEPTH + 60.0
	# the walls
	for side in [-1.0, 1.0]:
		var edge: float = x0 if side < 0.0 else x1
		var inward: float = -side  # towards the middle of the pit
		var wall := PackedVector2Array()
		wall.append(Vector2(edge - inward * 20.0, Scene1.GROUND_Y - 2.0))
		wall.append(Vector2(edge + inward * rng.randf_range(10.0, 17.0), Scene1.GROUND_Y + 3.0))  # the lip overhangs
		var y := Scene1.GROUND_Y + 12.0
		while y < floor_y:
			wall.append(Vector2(edge + inward * rng.randf_range(1.0, 13.0), y))
			y += rng.randf_range(9.0, 18.0)
		wall.append(Vector2(edge + inward * 8.0, floor_y + 6.0))
		wall.append(Vector2(edge - inward * 20.0, floor_y + 6.0))
		_poly(land, wall, INK)
		# roots hanging from the lip
		for k in range(rng.randi_range(2, 3)):
			var rx: float = edge + inward * rng.randf_range(2.0, 12.0)
			var drop := rng.randf_range(24.0, 58.0)
			_limb(land, [Vector2(rx, Scene1.GROUND_Y + 4.0), Vector2(rx + inward * rng.randf_range(2.0, 9.0), Scene1.GROUND_Y + drop * 0.5), Vector2(rx + inward * rng.randf_range(-4.0, 10.0), Scene1.GROUND_Y + drop)], [3.0, 1.9, 0.3])
		# clods about to fall
		for k in range(2):
			var cx: float = edge + inward * rng.randf_range(-4.0, 2.0)
			_poly(land, art._blob(Vector2(cx, Scene1.GROUND_Y - 3.0), rng.randf_range(4.0, 8.0), rng.randf_range(3.0, 5.0), rng, 8, 0.25), INK)
	# the floor: rubble
	var rubble := PackedVector2Array([Vector2(x0 - 10.0, floor_y + 600.0), Vector2(x0 - 4.0, floor_y)])
	var rx2 := x0
	while rx2 < x1:
		rubble.append(Vector2(rx2, floor_y - rng.randf_range(0.0, 11.0)))
		rx2 += rng.randf_range(8.0, 16.0)
	rubble.append(Vector2(x1 + 4.0, floor_y))
	rubble.append(Vector2(x1 + 10.0, floor_y + 600.0))
	_poly(land, rubble, INK)
	# the stakes: sharpened, leaning, a few broken off
	var count := int(width / 12.0)
	for k in range(count):
		var sx: float = x0 + (float(k) + 0.5) * width / float(count) + rng.randf_range(-3.0, 3.0)
		var tall := rng.randf_range(142.0, 172.0)
		var lean := rng.randf_range(-16.0, 16.0)
		var base := Vector2(sx, floor_y)
		var tip := base + Vector2(lean, -tall)
		var bend := rng.randf_range(-5.0, 5.0)
		if rng.randf() < 0.18:
			_limb(land, [base, base + Vector2(lean * 0.4 + bend, -tall * 0.35), base + Vector2(lean * 0.7, -tall * 0.5)], [5.5, 4.6, 3.8])  # snapped
			_poly(land, PackedVector2Array([base + Vector2(lean * 0.7 - 4.0, -tall * 0.5), base + Vector2(lean * 0.7 - 1.0, -tall * 0.5 - 8.0), base + Vector2(lean * 0.7 + 3.0, -tall * 0.5 - 3.0), base + Vector2(lean * 0.7 + 4.0, -tall * 0.5)]), INK)
		else:
			_limb(land, [base, base + Vector2(lean * 0.45 + bend, -tall * 0.5), tip], [5.2, 3.8, 0.25])
	# bones among them
	if width > 100.0:
		var bx: float = x0 + width * rng.randf_range(0.3, 0.7)
		for rib in range(3):
			_limb(land, [Vector2(bx + float(rib) * 7.0, floor_y - 2.0), Vector2(bx + float(rib) * 7.0 + 5.0, floor_y - 14.0 - float(rib)), Vector2(bx + float(rib) * 7.0 + 14.0, floor_y - 16.0)], [1.6, 1.3, 0.5])
		_poly(land, art._blob(Vector2(bx - 14.0, floor_y - 6.0), 7.0, 6.0, rng, 10, 0.12), INK)
	if bool(f.get("island", false)):
		var cx2 := x0 + width * 0.5
		var stone := PackedVector2Array([Vector2(cx2 - 28.0, floor_y + 20.0), Vector2(cx2 - 25.0, Scene1.GROUND_Y + 36.0), Vector2(cx2 - 21.0, Scene1.GROUND_Y + 10.0), Vector2(cx2 - 13.0, Scene1.GROUND_Y + 2.0), Vector2(cx2 - 2.0, Scene1.GROUND_Y - 3.0), Vector2(cx2 + 11.0, Scene1.GROUND_Y - 1.0), Vector2(cx2 + 20.0, Scene1.GROUND_Y + 6.0), Vector2(cx2 + 23.0, Scene1.GROUND_Y + 30.0), Vector2(cx2 + 30.0, floor_y + 20.0)])
		_poly(land, _rough(art, stone, 3.0, x0), INK)
		for blade in range(5):
			_tuft(art, rng, cx2 - 12.0 + float(blade) * 6.0, Scene1.GROUND_Y - 1.0, rng.randf_range(8.0, 16.0))

# ------------------------------------------------------------------ a bramble: curved canes with thorns
static func _bramble(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var x0 := Scene1.fx(f)
	var x1 := x0 + float(f["w"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0) + 3
	var count := int(float(f["w"]) / 11.0)
	for k in range(count):
		var cx: float = x0 + (float(k) + 0.5) * float(f["w"]) / float(count) + rng.randf_range(-4.0, 4.0)
		var g: float = Scene1.ground_top(cx)
		var tall := rng.randf_range(26.0, 52.0)
		var drift := rng.randf_range(12.0, 30.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p0 := Vector2(cx, g + 3.0)
		var p1 := Vector2(cx + drift * 0.25, g - tall * 0.55)
		var p2 := Vector2(cx + drift * 0.8, g - tall)
		var p3 := Vector2(cx + drift * 1.25, g - tall * 0.78)  # the cane arches over
		_limb(land, [p0, p1, p2, p3], [2.6, 2.0, 1.4, 0.3])
		# thorns along the cane, both sides, pointing outwards and up
		var samples := [Vector2(0.3, 1.0), Vector2(0.5, -1.0), Vector2(0.7, 1.0), Vector2(0.88, -1.0)]
		for s: Vector2 in samples:
			var pos: Vector2 = p0.bezier_interpolate(p1, p2, p3, s.x)
			var ahead: Vector2 = p0.bezier_interpolate(p1, p2, p3, minf(1.0, s.x + 0.05))
			var dir := (ahead - pos).normalized()
			var normal := Vector2(-dir.y, dir.x) * s.y
			var length := rng.randf_range(7.0, 12.0)
			_poly(land, PackedVector2Array([pos - dir * 2.0 + normal * 1.2, pos + (normal + dir * 0.4).normalized() * length, pos + dir * 3.0 + normal * 1.2]), INK)
	# a thick dead tangle underneath
	for k in range(4):
		var bx: float = x0 + rng.randf_range(0.0, float(f["w"]))
		_limb(land, [Vector2(bx - 20.0, Scene1.ground_top(bx) + 2.0), Vector2(bx - 4.0, Scene1.ground_top(bx) - 12.0 - rng.randf_range(0.0, 8.0)), Vector2(bx + 22.0, Scene1.ground_top(bx) - 4.0)], [1.8, 2.2, 1.0])

# ------------------------------------------------------------------ the roots at the foot of a tree
static func _roots(art, base: Vector2, half: float, rng: RandomNumberGenerator) -> void:
	var land: Node2D = art.land
	for side in [-1.0, 1.0]:
		var reach := half * rng.randf_range(2.4, 4.2)
		var arch := rng.randf_range(10.0, 20.0)
		_limb(land, [base + Vector2(side * half * 0.4, -8.0), base + Vector2(side * half * 1.3, -arch), base + Vector2(side * reach * 0.7, -arch * 0.45), base + Vector2(side * reach, 4.0)], [half * 0.5, half * 0.32, half * 0.17, 0.8])
		if rng.randf() < 0.6:
			_limb(land, [base + Vector2(side * half * 0.8, -4.0), base + Vector2(side * half * 1.8, -3.0), base + Vector2(side * half * 2.6, 5.0)], [half * 0.22, half * 0.14, 0.6])

# ------------------------------------------------------------------ a fallen tree: root plate at one end, a splintered break at the other
static func _log_art(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var x0 := Scene1.fx(f)
	var len := float(f["len"])
	var h := float(f["h"])
	var g := Scene1.GROUND_Y
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0) + 5
	var body := PackedVector2Array()
	body.append(Vector2(x0 - 30.0, g + 4.0))
	body.append(Vector2(x0 - 22.0, g - h * 0.5))
	body.append(Vector2(x0 - 4.0, g - h * 0.9))
	var steps := int(len / 10.0)
	for i in range(steps + 1):
		var u := float(i) / float(steps)
		var notch := 0.0
		if i % 4 == 2:
			notch = rng.randf_range(1.5, 3.5)  # bark nicks
		body.append(Vector2(x0 + u * len, g - h * lerpf(1.0, Scene1.LOG_TAPER, u) + float(art.noise.get_noise_1d(x0 * 0.7 + u * 30.0)) * 1.6 + notch * 0.6))
	var end_h := h * Scene1.LOG_TAPER
	body.append(Vector2(x0 + len + 3.0, g - end_h - 9.0))  # the splintered end
	body.append(Vector2(x0 + len + 8.0, g - end_h + 10.0))
	body.append(Vector2(x0 + len + 14.0, g - end_h * 0.5))
	body.append(Vector2(x0 + len + 5.0, g - end_h * 0.2))
	body.append(Vector2(x0 + len + 8.0, g + 4.0))
	_poly(land, body, INK)
	# the root plate: a lump of earth with the roots torn out of it, fanned in the air
	var plate: PackedVector2Array = art._blob(Vector2(x0 - 16.0, g - h * 0.62), h * 0.55, h * 0.72, rng, 16, 0.2)
	_poly(land, plate, INK)
	for k in range(9):
		var ang := lerpf(-2.7, -0.2, float(k) / 8.0) + rng.randf_range(-0.12, 0.12)
		var root_from := Vector2(x0 - 16.0, g - h * 0.62) + Vector2(cos(ang), sin(ang)) * h * 0.5
		var length := rng.randf_range(24.0, 48.0)
		var mid := root_from + Vector2(cos(ang + rng.randf_range(-0.4, 0.4)), sin(ang)) * length * 0.55
		var tip := root_from + Vector2(cos(ang + rng.randf_range(-0.7, 0.7)), sin(ang)) * length
		_limb(land, [root_from, mid, tip], [3.4, 2.0, 0.3])
		if rng.randf() < 0.6:
			var knot := root_from.lerp(mid, 0.7)
			_limb(land, [knot, knot + Vector2(rng.randf_range(-12.0, 12.0), -rng.randf_range(8.0, 16.0)), knot + Vector2(rng.randf_range(-20.0, 20.0), -rng.randf_range(18.0, 30.0))], [1.4, 0.9, 0.2])
	# broken branches standing from the top
	for k in range(2):
		var bx: float = x0 + len * (0.28 + 0.4 * float(k)) + rng.randf_range(-12.0, 12.0)
		var bh := rng.randf_range(24.0, 48.0)
		var lean := rng.randf_range(-12.0, 12.0)
		var top_here := g - h * lerpf(1.0, Scene1.LOG_TAPER, (bx - x0) / len)
		_limb(land, [Vector2(bx, top_here + 6.0), Vector2(bx + lean * 0.4, top_here - bh * 0.5), Vector2(bx + lean, top_here - bh)], [5.0, 3.0, 0.8])
		_limb(land, [Vector2(bx + lean * 0.4, top_here - bh * 0.5), Vector2(bx + lean * 0.4 + 14.0, top_here - bh * 0.7), Vector2(bx + lean * 0.4 + 26.0, top_here - bh * 0.95)], [2.0, 1.2, 0.2])
	# moss / grass on the top
	for k in range(7):
		var mx: float = x0 + rng.randf_range(10.0, len - 8.0)
		_tuft(art, rng, mx, g - h * lerpf(1.0, Scene1.LOG_TAPER, (mx - x0) / len) + 1.0, rng.randf_range(6.0, 14.0))

# ------------------------------------------------------------------ a stepping stone: a low, lumpy slab
static func _slab_art(art, f: Dictionary) -> void:
	var land: Node2D = art.land
	var cx := Scene1.fx(f)
	var w := float(f["w"]) * 0.5
	var top_y := Scene1.GROUND_Y - float(f["top"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f["seed"]) * 13 + 2
	var tilt := rng.randf_range(-5.0, 5.0)
	var base_y := Scene1.GROUND_Y + 70.0
	var slab := PackedVector2Array([
		Vector2(cx - w * 1.6, base_y),
		Vector2(cx - w * 1.35, top_y + 26.0),
		Vector2(cx - w * 1.05, top_y + 9.0 + tilt),
		Vector2(cx - w * 0.7, top_y + 2.0 + tilt * 0.6),
		Vector2(cx - w * 0.25, top_y - 1.0),
		Vector2(cx + w * 0.2, top_y + 1.0 - tilt * 0.3),
		Vector2(cx + w * 0.62, top_y - 2.5),
		Vector2(cx + w * 0.95, top_y + 6.0 - tilt),
		Vector2(cx + w * 1.2, top_y + 17.0),
		Vector2(cx + w * 1.5, top_y + 34.0),
		Vector2(cx + w * 1.65, base_y)])
	_poly(land, _rough(art, slab, 2.4, float(f["seed"])), INK)
	for k in range(3):
		_tuft(art, rng, cx - w * 0.6 + rng.randf_range(0.0, w * 1.2), top_y + 1.0, rng.randf_range(5.0, 11.0))

# ------------------------------------------------------------------ the rest
static func _features(art) -> void:
	var land: Node2D = art.land
	for f: Dictionary in Scene1.FEATURES:
		var t := String(f["t"])
		if t == "boulder":
			_boulder_art(art, f)
		elif t == "spikes":
			_bramble(art, f)
		elif t == "log":
			_log_art(art, f)
		elif t == "rock":
			_slab_art(art, f)
	_scatter(art)

# Small things lying about: stones, fallen sticks, roots across the ground, ferns, toadstools. Never on an obstacle, in a pit or in water.
static func _scatter(art) -> void:
	var land: Node2D = art.land
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x: float = Scene1.START_X - 260.0
	while x < Scene1.CLIFF_X - 80.0:
		x += rng.randf_range(60.0, 150.0)
		if _near_obstacle(x, 20.0) or Scene1.in_pit(x):
			continue
		var g: float = _top(art, x)
		var pick := rng.randf()
		if pick < 0.28:
			# a few stones
			for k in range(rng.randi_range(2, 4)):
				var s := rng.randf_range(4.0, 13.0)
				var sx := x + rng.randf_range(-16.0, 16.0)
				_poly(land, art._blob(Vector2(sx, _top(art, sx) - s * 0.3), s, s * 0.6, rng, 9, 0.22), INK)
		elif pick < 0.5:
			# a fallen stick with a twig
			var len := rng.randf_range(34.0, 86.0)
			var tilt := rng.randf_range(-0.22, 0.22)
			var a := Vector2(x, g - 1.0)
			var b := a + Vector2(len, tilt * len)
			_limb(land, [a, a.lerp(b, 0.5) + Vector2(0.0, -3.0), b], [2.4, 2.0, 0.6])
			var knot := a.lerp(b, rng.randf_range(0.3, 0.7))
			_limb(land, [knot, knot + Vector2(10.0, -10.0), knot + Vector2(20.0, -22.0)], [1.3, 0.9, 0.2])
		elif pick < 0.68:
			# a root arching over the ground
			var reach := rng.randf_range(40.0, 90.0)
			_limb(land, [Vector2(x, g + 3.0), Vector2(x + reach * 0.3, g - 11.0), Vector2(x + reach * 0.7, g - 9.0), Vector2(x + reach, g + 3.0)], [5.0, 3.6, 3.0, 0.8])
		elif pick < 0.86:
			# ferns: a fan of curved fronds
			for k in range(rng.randi_range(5, 8)):
				var ang := rng.randf_range(-1.1, 1.1)
				var fl := rng.randf_range(16.0, 34.0)
				var root := Vector2(x + rng.randf_range(-4.0, 4.0), g + 1.0)
				_limb(land, [root, root + Vector2(sin(ang) * fl * 0.5, -fl * 0.7), root + Vector2(sin(ang) * fl * 1.1, -fl * 0.85 + fl * absf(ang) * 0.45)], [1.7, 1.1, 0.2])
		else:
			# toadstools
			for k in range(rng.randi_range(2, 4)):
				var mx := x + rng.randf_range(-14.0, 14.0)
				var mh := rng.randf_range(7.0, 15.0)
				var my: float = _top(art, mx)
				_limb(land, [Vector2(mx, my + 1.0), Vector2(mx + rng.randf_range(-1.5, 1.5), my - mh * 0.5), Vector2(mx + rng.randf_range(-2.0, 2.0), my - mh)], [1.6, 1.3, 1.1])
				var cap: PackedVector2Array = art._blob(Vector2(mx, my - mh), mh * 0.55, mh * 0.3, rng, 10, 0.1)
				_poly(land, cap, INK)

# ------------------------------------------------------------------ rim light on the tops of the obstacles (pale thin lines in the effects layer)
static func _rim(fx: Node2D, points: PackedVector2Array, closed: bool) -> void:
	var n := points.size()
	var count := n if closed else n - 1
	for i in range(count):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % n]
		var run := absf(b.x - a.x)
		if run < 0.5:
			continue
		var slope := absf(b.y - a.y) / run
		if closed and (a.y + b.y) * 0.5 > Scene1.GROUND_Y - 10.0:
			continue
		var weight := clampf(1.0 - slope * 0.8, 0.0, 1.0)
		if closed and b.x < a.x:
			continue  # only the edges that face up (the outline runs left to right along the top in these shapes)
		if weight > 0.05:
			fx.draw_line(a + Vector2(0.0, 1.0), b + Vector2(0.0, 1.0), Color(0.74, 0.74, 0.72, 0.42 * weight), 1.5, true)

static func draw_effects(art) -> void:
	var fx: Node2D = art.effects
	for f: Dictionary in Scene1.FEATURES:
		var kind := String(f["t"])
		if kind == "boulder":
			var outline: PackedVector2Array = Scene1.boulder_points(f)
			# the polygon's top: take the points above the middle of the rock, in order of x
			var upper := PackedVector2Array()
			var mid_y := Scene1.GROUND_Y - float(f["h"]) * 0.55
			for p: Vector2 in outline:
				if p.y < mid_y:
					upper.append(p)
			var sorted: Array = Array(upper)
			sorted.sort_custom(func(u: Vector2, v: Vector2): return u.x < v.x)
			_rim(fx, PackedVector2Array(sorted), false)
		elif kind == "log":
			var x0 := Scene1.fx(f)
			var h := float(f["h"])
			var top := PackedVector2Array()
			for i in range(0, 9):
				var u := float(i) / 8.0
				top.append(Vector2(x0 + u * float(f["len"]), Scene1.GROUND_Y - h * lerpf(1.0, Scene1.LOG_TAPER, u)))
			_rim(fx, top, false)
		elif kind == "rock":
			var cx := Scene1.fx(f)
			var w := float(f["w"]) * 0.5
			var top_y := Scene1.GROUND_Y - float(f["top"])
			_rim(fx, PackedVector2Array([Vector2(cx - w * 0.9, top_y + 5.0), Vector2(cx - w * 0.5, top_y + 1.0), Vector2(cx - w * 0.1, top_y - 1.0), Vector2(cx + w * 0.4, top_y), Vector2(cx + w * 0.85, top_y + 4.0)]), false)

# The cliff edge: the ground ends in a ragged, undercut lip.
static func _cliff_edge(art) -> void:
	var land: Node2D = art.land
	var g := Scene1.ground_top(Scene1.CLIFF_X)
	var x0 := Scene1.CLIFF_X
	var lip := PackedVector2Array([Vector2(x0 - 40.0, g - 2.0), Vector2(x0 + 6.0, g - 1.0), Vector2(x0 + 22.0, g + 10.0), Vector2(x0 + 4.0, g + 30.0), Vector2(x0 + 26.0, g + 60.0), Vector2(x0 - 8.0, g + 96.0), Vector2(x0 + 14.0, g + 140.0), Vector2(x0 - 24.0, g + 190.0), Vector2(x0 - 40.0, g + 260.0)])
	_poly(land, lip, INK)
	for i in range(5):
		var rx := x0 - 150.0 + float(i) * 34.0
		_limb(land, [Vector2(rx, g + 2.0), Vector2(rx + 6.0, g + 40.0 + float(i % 3) * 14.0), Vector2(rx - 4.0, g + 80.0 + float(i % 2) * 40.0)], [3.0, 2.0, 0.4])

static func draw_grass(art) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4412
	for piece: Vector2 in Scene1.ground_pieces():
		var x: float = piece.x + 4.0
		while x < piece.y - 4.0:
			var cluster: float = 0.5 + float(art.noise.get_noise_1d(x * 1.1 + 900.0)) * 0.5
			var y := _top(art, x)
			if cluster > 0.66:
				for b in range(rng.randi_range(3, 5)):
					art._blade(rng, x + float(b) * rng.randf_range(2.5, 4.5), _top(art, x + float(b) * 3.0), lerpf(9.0, 22.0, cluster) * rng.randf_range(0.7, 1.0), 0.8)
				x += rng.randf_range(16.0, 28.0)
			else:
				art._blade(rng, x, y, rng.randf_range(3.0, 9.0), 0.45)
				x += rng.randf_range(10.0, 19.0)
	for i in range(14):
		var fx := Scene1.START_X - 70.0 + float(i) * 11.0 + rng.randf_range(-3.0, 3.0)
		art._blade(rng, fx, _top(art, fx), rng.randf_range(18.0, 36.0), 1.0)
	# reeds at the ponds
	for f: Dictionary in Scene1.FEATURES:
		if String(f["t"]) == "pond":
			var x0 := Scene1.fx(f)
			for i in range(12):
				var rx := x0 + rng.randf_range(-10.0, float(f["w"]) + 10.0)
				art._blade(rng, rx, _top(art, rx), rng.randf_range(24.0, 50.0), 0.5)

static func draw_fog(art) -> void:
	var fog: Node2D = art.fog
	# Mist lying on the ground along the whole route: pale just above the ground line and fading upwards, so the obstacles stand against
	# something light (and the stakes in a pit show above its lip). It thins out where the backdrop opens up.
	var strip := 300.0
	var sx: float = Scene1.WORLD_LEFT
	while sx < Scene1.CLIFF_X:
		var fade_a: float = 1.0 - smoothstep(Scene1.START_X + 4800.0, Scene1.START_X + 6100.0, sx)
		var fade_b: float = 1.0 - smoothstep(Scene1.START_X + 4800.0, Scene1.START_X + 6100.0, sx + strip)
		var low_a := Color(0.74, 0.74, 0.72, 0.62 * fade_a)
		var low_b := Color(0.74, 0.74, 0.72, 0.62 * fade_b)
		var high_a := Color(0.74, 0.74, 0.72, 0.0)
		fog.draw_polygon(PackedVector2Array([Vector2(sx, Scene1.GROUND_Y - 150.0), Vector2(sx + strip, Scene1.GROUND_Y - 150.0), Vector2(sx + strip, Scene1.GROUND_Y + 2.0), Vector2(sx, Scene1.GROUND_Y + 2.0)]), PackedColorArray([high_a, high_a, low_b, low_a]))
		sx += strip
	# ... and it fills the pits down to a little below their lips, fading as it sinks
	for f: Dictionary in Scene1.FEATURES:
		if String(f["t"]) == "pit":
			var px0 := Scene1.fx(f)
			var px1 := px0 + float(f["w"])
			var top_c := Color(0.74, 0.74, 0.72, 0.62)
			var bottom_c := Color(0.5, 0.5, 0.5, 0.0)
			fog.draw_polygon(PackedVector2Array([Vector2(px0, Scene1.GROUND_Y + 2.0), Vector2(px1, Scene1.GROUND_Y + 2.0), Vector2(px1, Scene1.GROUND_Y + 110.0), Vector2(px0, Scene1.GROUND_Y + 110.0)]), PackedColorArray([top_c, top_c, bottom_c, bottom_c]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var x: float = Scene1.WORLD_LEFT
	while x < Scene1.CLIFF_X:
		var drift := sin(art.clock * 0.16 + x * 0.011) * 28.0
		var y: float = Scene1.GROUND_Y - rng.randf_range(10.0, 70.0)
		art._soft(fog, Vector2(x + drift, y), Vector2(rng.randf_range(320.0, 600.0), rng.randf_range(90.0, 180.0)), Color(0.30, 0.30, 0.30, rng.randf_range(0.10, 0.18)))
		x += rng.randf_range(170.0, 300.0)
