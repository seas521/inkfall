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
		land.draw_colored_polygon(points, INK)
	# the pits: ragged lips and a hole that goes down into the dark
	for f: Dictionary in Scene1.FEATURES:
		if String(f["t"]) != "pit":
			continue
		var x0 := Scene1.fx(f)
		var x1 := x0 + float(f["w"])
		land.draw_colored_polygon(PackedVector2Array([Vector2(x0 - 5.0, Scene1.GROUND_Y + 30.0), Vector2(x1 + 5.0, Scene1.GROUND_Y + 30.0), Vector2(x1 + 5.0, Scene1.GROUND_Y + 520.0), Vector2(x0 - 5.0, Scene1.GROUND_Y + 520.0)]), INK)
		for edge in [x0, x1]:
			var dir: float = -1.0 if edge == x0 else 1.0
			land.draw_colored_polygon(PackedVector2Array([Vector2(edge, Scene1.GROUND_Y - 1.0), Vector2(edge - dir * 12.0, Scene1.GROUND_Y + 16.0), Vector2(edge + dir * 6.0, Scene1.GROUND_Y + 44.0), Vector2(edge + dir * 3.0, Scene1.GROUND_Y + 8.0)]), INK)
		if bool(f.get("island", false)):
			var cx := x0 + float(f["w"]) * 0.5
			land.draw_colored_polygon(PackedVector2Array([Vector2(cx - 26.0, Scene1.GROUND_Y + 60.0), Vector2(cx - 22.0, Scene1.GROUND_Y + 8.0), Vector2(cx - 10.0, Scene1.GROUND_Y - 2.0), Vector2(cx + 12.0, Scene1.GROUND_Y - 1.0), Vector2(cx + 24.0, Scene1.GROUND_Y + 10.0), Vector2(cx + 28.0, Scene1.GROUND_Y + 60.0)]), INK)

# Trees: a dense forest where he wakes up, thinning out towards the cliff; none on top of a feature.
static func _forest(art) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 612
	var x: float = Scene1.WORLD_LEFT + 60.0
	while x < Scene1.CLIFF_X - 200.0:
		var density: float = 1.0 - smoothstep(Scene1.START_X, Scene1.CLIFF_X - 1200.0, x)  # 1 at the start, 0 near the cliff
		var base := Vector2(x, _top(art, x) + 3.0)
		var big := x < Scene1.START_X + 400.0 or rng.randf() < 0.30 + density * 0.4
		if big:
			var height := rng.randf_range(520.0, 900.0)
			var half := rng.randf_range(24.0, 46.0)
			var lean := rng.randf_range(-24.0, 24.0)
			ForestInk._trunk(art, base, height, [half, half * 0.74, half * 0.52, half * 0.3], lean)
			ForestInk._branch(art, [base + Vector2(lean * 0.6, -height * 0.55), base + Vector2(lean * 0.6 + 70.0, -height * 0.62), base + Vector2(lean * 0.6 + 150.0, -height * 0.7)], [half * 0.22, half * 0.14, 2.0], 3, int(x))
			ForestInk._branch(art, [base + Vector2(lean * 0.9, -height * 0.8), base + Vector2(lean * 0.9 - 60.0, -height * 0.86), base + Vector2(lean * 0.9 - 130.0, -height * 0.92)], [half * 0.2, half * 0.12, 1.8], 3, int(x) + 7)
		else:
			var h2 := rng.randf_range(280.0, 460.0)
			var lean2 := rng.randf_range(-14.0, 14.0)
			ForestInk._trunk(art, base, h2, [13.0, 9.5, 6.5, 3.5], lean2)
			ForestInk._branch(art, [base + Vector2(lean2 * 0.5, -h2 * 0.5), base + Vector2(lean2 * 0.5 + 36.0, -h2 * 0.62), base + Vector2(lean2 * 0.5 + 76.0, -h2 * 0.78)], [4.4, 2.6, 0.5], 3, int(x))
		x += rng.randf_range(150.0, 330.0) + (1.0 - density) * 380.0

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
	land.draw_colored_polygon(_rough(art, base, 2.0, float(f["seed"])), INK)
	# a smaller stone at the foot, on one side
	var cx := Scene1.fx(f)
	var g := Scene1.ground_top(cx)
	var bottom := float(f["bottom"]) * 0.5
	var side := 1.0 if int(f["seed"]) % 2 == 0 else -1.0
	land.draw_colored_polygon(art._blob(Vector2(cx - side * (bottom + 22.0), g - 7.0), 17.0, 11.0, RandomNumberGenerator.new(), 12, 0.15), INK)

static func _features(art) -> void:
	var land: Node2D = art.land
	for f: Dictionary in Scene1.FEATURES:
		var t := String(f["t"])
		if t == "boulder":
			_boulder_art(art, f)
		elif t == "trunk":
			var x0 := Scene1.fx(f)
			var len := float(f["len"])
			var h := float(f["h"])
			var g := Scene1.GROUND_Y
			art._limb(land, [Vector2(x0 - 6.0, g - h * 0.5), Vector2(x0 + len * 0.5, g - h * 0.5 - 4.0), Vector2(x0 + len + 6.0, g - h * 0.5 + 2.0)], [h * 0.5, h * 0.52, h * 0.48])
			# broken limbs and a root-plate at one end
			art._limb(land, [Vector2(x0 + len * 0.3, g - h + 6.0), Vector2(x0 + len * 0.26, g - h - 26.0), Vector2(x0 + len * 0.18, g - h - 52.0)], [7.0, 4.0, 0.9])
			art._limb(land, [Vector2(x0 + len * 0.72, g - h + 6.0), Vector2(x0 + len * 0.78, g - h - 22.0), Vector2(x0 + len * 0.9, g - h - 40.0)], [6.0, 3.4, 0.8])
			for i in range(4):
				art._limb(land, [Vector2(x0 - 4.0, g - h * 0.5 + float(i - 1) * 16.0), Vector2(x0 - 30.0 - float(i) * 6.0, g - h * 0.5 + float(i - 1) * 28.0 - 10.0), Vector2(x0 - 52.0 - float(i) * 8.0, g - h * 0.5 + float(i - 1) * 34.0 - 30.0)], [6.0, 3.0, 0.6])
		elif t == "rock":
			var cx := Scene1.fx(f)
			var w := float(f["w"]) * 0.5
			var top_y := Scene1.GROUND_Y - float(f["top"])
			var rock_base := PackedVector2Array([Vector2(cx - w - 6.0, Scene1.GROUND_Y + 60.0), Vector2(cx - w, top_y + 12.0), Vector2(cx - w * 0.5, top_y - 2.0), Vector2(cx + w * 0.5, top_y - 1.0), Vector2(cx + w, top_y + 12.0), Vector2(cx + w + 6.0, Scene1.GROUND_Y + 60.0)])
			land.draw_colored_polygon(_rough(art, _round(rock_base, 2), 2.0, float(f["seed"])), INK)
	# small stones strewn about
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var x: float = Scene1.START_X - 200.0
	while x < Scene1.CLIFF_X - 100.0:
		if not Scene1.in_pit(x) and rng.randf() < 0.5:
			var s := rng.randf_range(6.0, 15.0)
			land.draw_colored_polygon(art._blob(Vector2(x, _top(art, x) - s * 0.4), s, s * 0.6, rng, 10, 0.14), INK)
		x += rng.randf_range(90.0, 220.0)

# The cliff edge: the ground ends in a ragged, undercut lip.
static func _cliff_edge(art) -> void:
	var land: Node2D = art.land
	var g := Scene1.ground_top(Scene1.CLIFF_X)
	var x0 := Scene1.CLIFF_X
	var lip := PackedVector2Array([Vector2(x0 - 40.0, g - 2.0), Vector2(x0 + 6.0, g - 1.0), Vector2(x0 + 22.0, g + 10.0), Vector2(x0 + 4.0, g + 30.0), Vector2(x0 + 26.0, g + 60.0), Vector2(x0 - 8.0, g + 96.0), Vector2(x0 + 14.0, g + 140.0), Vector2(x0 - 24.0, g + 190.0), Vector2(x0 - 40.0, g + 260.0)])
	land.draw_colored_polygon(lip, INK)
	for i in range(5):
		var rx := x0 - 150.0 + float(i) * 34.0
		art._limb(land, [Vector2(rx, g + 2.0), Vector2(rx + 6.0, g + 40.0 + float(i % 3) * 14.0), Vector2(rx - 4.0, g + 80.0 + float(i % 2) * 40.0)], [3.0, 2.0, 0.4])

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
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var x: float = Scene1.WORLD_LEFT
	while x < Scene1.CLIFF_X:
		var drift := sin(art.clock * 0.16 + x * 0.011) * 28.0
		var y: float = Scene1.GROUND_Y - rng.randf_range(10.0, 70.0)
		art._soft(fog, Vector2(x + drift, y), Vector2(rng.randf_range(320.0, 600.0), rng.randf_range(90.0, 180.0)), Color(0.30, 0.30, 0.30, rng.randf_range(0.10, 0.18)))
		x += rng.randf_range(170.0, 300.0)

# The shallow ponds: a pale sheet of sky in each dip, with a few ripples (drawn above the ink).
static func draw_effects(art) -> void:
	var fx: Node2D = art.effects
	for f: Dictionary in Scene1.FEATURES:
		if String(f["t"]) != "pond":
			continue
		var x0 := Scene1.fx(f)
		var w := float(f["w"])
		var d := float(f["d"])
		var y := Scene1.GROUND_Y + d - 3.0
		var edge := minf(60.0, w * 0.3)
		fx.draw_line(Vector2(x0 + edge * 0.7, y), Vector2(x0 + w - edge * 0.7, y), Color(0.60, 0.60, 0.58, 0.55), 2.0, true)
		for k in range(5):
			var rx: float = x0 + w * (0.12 + 0.19 * float(k)) + sin(art.clock * 0.7 + float(k) * 1.7) * 6.0
			fx.draw_line(Vector2(rx - 18.0, y + 3.0), Vector2(rx + 18.0, y + 3.0), Color(0.55, 0.55, 0.53, 0.28), 1.2, true)
