extends RefCounted

# Ink drawing for act four, the forest's first room. Like cliff_art.gd these helpers draw into the second act's layers (the stage
# that gives every silhouette its soft edge), so the room belongs to the same picture as the marsh and the cliff.
# `art` is the marsh art node. Room coordinates: x to the right from the entry, y up from the ground (see forest_act.gd).

const Forest = preload("res://scripts/demos/c_zone_debug/forest_act.gd")
const INK := Color("050606")

static func W(x: float, y: float) -> Vector2:
	return Forest.world(x, y)

# ------------------------------------------------------------------ static ink

static func draw_static(art) -> void:
	_draw_ground(art)
	_draw_back_trees(art)
	_draw_room_trees(art)
	_draw_logs_and_shelf(art)
	_draw_walk(art)
	_draw_machine_frame(art)
	_draw_dressing(art)

static func _ground_top(art, x: float) -> float:
	return Forest.FLOOR_Y - 1.4 + art.noise.get_noise_1d(x * 1.1 + 3000.0) * 2.2 + art.noise.get_noise_1d(x * 4.0) * 0.8

# The ground runs on from the cliff's slope, level, into the fog.
static func _draw_ground(art) -> void:
	var land: Node2D = art.land
	var points := PackedVector2Array()
	var x0 := Forest.START_X - 80.0
	points.append(Vector2(x0, 400.0))
	var x := x0
	while x <= Forest.WORLD_END:
		points.append(Vector2(x, _ground_top(art, x)))
		x += 8.0
	points.append(Vector2(Forest.WORLD_END, 400.0))
	land.draw_colored_polygon(points, INK)
	# the stone hidden at the entry: only a low round hump among the roots, easy to take for part of the ground
	var hump := PackedVector2Array()
	for i in range(13):
		var a := PI * float(i) / 12.0
		hump.append(W(92.0 - cos(a) * 17.0, 3.0 + sin(a) * 11.0))
	land.draw_colored_polygon(hump, INK)

# A tapering trunk with a flared foot. `lean` leans the top.
static func _trunk(art, base: Vector2, height: float, half_widths: Array, lean: float) -> void:
	var land: Node2D = art.land
	var mid := base + Vector2(lean * 0.35 + art.noise.get_noise_1d(base.x * 0.7) * 8.0, -height * 0.5)
	var top := base + Vector2(lean, -height)
	art._limb(land, [base + Vector2(0.0, 6.0), base + Vector2(lean * 0.05, -height * 0.18), mid, top], half_widths)
	# the foot spreads into two or three roots
	for side in [-1.0, 1.0]:
		art._limb(land, [base + Vector2(side * float(half_widths[0]) * 0.5, -10.0), base + Vector2(side * float(half_widths[0]) * 1.5, 2.0), base + Vector2(side * float(half_widths[0]) * 2.6, 6.0)], [float(half_widths[0]) * 0.55, float(half_widths[0]) * 0.28, 1.5])

static func _branch(art, points: Array, widths: Array, twigs: int, seed_value: int) -> void:
	var land: Node2D = art.land
	art._limb(land, points, widths)
	var tip: Vector2 = points[points.size() - 1]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for n in range(twigs):
		var root: Vector2 = tip.lerp(points[maxi(0, points.size() - 2)], rng.randf_range(0.0, 0.8))
		var dir := Vector2(sign(tip.x - float(points[0].x) + 0.01), 0.0)
		art._limb(land, [root, root + Vector2(dir.x * rng.randf_range(14.0, 30.0), rng.randf_range(-24.0, -8.0)), root + Vector2(dir.x * rng.randf_range(30.0, 60.0), rng.randf_range(-44.0, -14.0))], [1.8, 1.1, 0.2])

# Dead trees further back: slender, bare, a few of them leaning.
static func _draw_back_trees(art) -> void:
	var land: Node2D = art.land
	var specs := [
		Vector3(7560.0, 360.0, 14.0), Vector3(7650.0, 250.0, -22.0),
		Vector3(W(2330.0, 0.0).x, 380.0, 18.0), Vector3(W(2480.0, 0.0).x, 260.0, -16.0), Vector3(W(2650.0, 0.0).x, 420.0, 10.0),
		Vector3(W(2820.0, 0.0).x, 300.0, -12.0),
	]
	for spec: Vector3 in specs:
		var base := Vector2(spec.x, _ground_top(art, spec.x) + 2.0)
		_trunk(art, base, spec.y, [11.0, 8.0, 5.5, 3.0], spec.z)
		var top := base + Vector2(spec.z, -spec.y)
		_branch(art, [base + Vector2(spec.z * 0.5, -spec.y * 0.55), base + Vector2(spec.z * 0.5 + 34.0, -spec.y * 0.66), base + Vector2(spec.z * 0.5 + 70.0, -spec.y * 0.8)], [4.0, 2.4, 0.4], 3, int(spec.x))
		_branch(art, [top + Vector2(0.0, 70.0), top + Vector2(-30.0, 52.0), top + Vector2(-58.0, 40.0)], [3.4, 2.0, 0.4], 2, int(spec.x) + 5)

# The trees of the room itself: the big one by the entry (it carries the hunter's marks), the one the vine hangs from, and the one
# the stone bag hangs from.
static func _draw_room_trees(art) -> void:
	# T1: the big tree
	var t1 := W(505.0, 0.0) + Vector2(0.0, 2.0)
	_trunk(art, t1, 440.0, [34.0, 25.0, 18.0, 12.0], 8.0)
	_branch(art, [t1 + Vector2(4.0, -300.0), t1 + Vector2(60.0, -338.0), t1 + Vector2(140.0, -352.0)], [10.0, 6.0, 1.5], 4, 101)
	_branch(art, [t1 + Vector2(2.0, -350.0), t1 + Vector2(-48.0, -384.0), t1 + Vector2(-110.0, -396.0)], [8.0, 5.0, 1.2], 3, 102)
	_branch(art, [t1 + Vector2(8.0, -438.0), t1 + Vector2(30.0, -480.0), t1 + Vector2(20.0, -530.0)], [7.0, 4.0, 0.6], 3, 103)
	# T2: the vine tree; its branch reaches out to where the vine hangs
	var t2 := W(1018.0, 0.0) + Vector2(0.0, 2.0)
	_trunk(art, t2, 410.0, [28.0, 21.0, 15.0, 10.0], -4.0)
	_branch(art, [t2 + Vector2(-6.0, -372.0), t2 + Vector2(-52.0, -386.0), W(930.0, 346.0) - Vector2(0.0, 6.0)], [8.0, 5.5, 3.0], 2, 201)
	_branch(art, [t2 + Vector2(-2.0, -300.0), t2 + Vector2(46.0, -332.0), t2 + Vector2(110.0, -340.0)], [7.0, 4.0, 1.0], 3, 202)
	_branch(art, [t2 + Vector2(-5.0, -408.0), t2 + Vector2(10.0, -456.0), t2 + Vector2(-8.0, -500.0)], [6.0, 3.5, 0.5], 3, 203)
	# T3: the bag tree, in front of the gate
	var t3 := W(2062.0, 0.0) + Vector2(0.0, 2.0)
	_trunk(art, t3, 340.0, [24.0, 18.0, 13.0, 9.0], 6.0)
	_branch(art, [t3 + Vector2(-4.0, -300.0), t3 + Vector2(-52.0, -312.0), W(1960.0, 266.0)], [7.0, 4.5, 2.5], 2, 301)
	_branch(art, [t3 + Vector2(4.0, -330.0), t3 + Vector2(40.0, -372.0), t3 + Vector2(32.0, -420.0)], [6.0, 3.5, 0.5], 3, 302)

# A lump of rock: strata of different hardness, so the faces step and undercut instead of standing like a cut block.
static func _rock(art, x0: float, x1: float, top: float, seed_value: int) -> void:
	var land: Node2D = art.land
	var outline := PackedVector2Array()
	outline.append(W(x0 - 30.0, -6.0))
	var ledges := [Vector3(top * 0.30, 0.14, 16.0), Vector3(top * 0.58, 0.12, 11.0), Vector3(top * 0.84, 0.10, 8.0)]
	# up the left face
	var y := 0.0
	while y < top:
		var off: float = float(art.noise.get_noise_1d(y * 0.9 + float(seed_value))) * 7.0
		var bulge := 0.0
		for ledge: Vector3 in ledges:
			var d: float = y - ledge.x
			if d > -top * ledge.y and d <= 0.0:
				bulge += ledge.z * (1.0 + d / (top * ledge.y))
			elif d > 0.0 and d < 10.0:
				bulge -= 5.0 * (1.0 - d / 10.0)
		outline.append(W(x0 - 18.0 + off - bulge * 0.8 + (1.0 - y / top) * -10.0, y))
		y += 8.0
	# the top, a little domed and rough
	var x := x0 - 10.0
	while x < x1 + 10.0:
		var dome: float = sin(PI * clampf((x - x0 + 10.0) / (x1 - x0 + 20.0), 0.0, 1.0)) * 6.0
		outline.append(W(x, top - 4.0 + dome + float(art.noise.get_noise_1d(x * 2.0 + float(seed_value))) * 3.0))
		x += 8.0
	# down the right face
	y = top
	while y > 0.0:
		var off2: float = float(art.noise.get_noise_1d(y * 0.9 + float(seed_value) + 500.0)) * 7.0
		var bulge2 := 0.0
		for ledge: Vector3 in ledges:
			var d2: float = y - ledge.x * 1.06
			if d2 > -top * ledge.y and d2 <= 0.0:
				bulge2 += ledge.z * (1.0 + d2 / (top * ledge.y))
			elif d2 > 0.0 and d2 < 10.0:
				bulge2 -= 5.0 * (1.0 - d2 / 10.0)
		outline.append(W(x1 + 18.0 + off2 + bulge2 * 0.8 + (1.0 - y / top) * 10.0, y))
		y -= 8.0
	outline.append(W(x1 + 32.0, -6.0))
	land.draw_colored_polygon(outline, INK)

static func _draw_logs_and_shelf(art) -> void:
	var land: Node2D = art.land
	# the stump: a short thick trunk with a broken, uneven top
	var stump := PackedVector2Array([W(606.0, -2.0), W(612.0, 28.0), W(610.0, 50.0), W(626.0, 53.0), W(640.0, 49.0), W(654.0, 54.0), W(668.0, 50.0), W(666.0, 26.0), W(674.0, -2.0)])
	land.draw_colored_polygon(stump, INK)
	# the fallen log
	art._limb(land, [W(692.0, 56.0), W(780.0, 62.0), W(886.0, 58.0)], [58.0, 60.0, 56.0])
	land.draw_colored_polygon(PackedVector2Array([W(884.0, 2.0), W(900.0, 30.0), W(900.0, 90.0), W(884.0, 118.0)]), INK)
	art._limb(land, [W(730.0, 112.0), W(722.0, 138.0), W(708.0, 160.0)], [6.0, 3.8, 1.0])
	art._limb(land, [W(826.0, 116.0), W(836.0, 140.0), W(854.0, 150.0)], [5.0, 3.0, 0.8])
	# the high shelf: a lump of rock
	_rock(art, 1100.0, 1240.0, 210.0, 55)
	# small stones at its foot
	for stone in [Vector3(1080.0, 0.0, 14.0), Vector3(1258.0, 0.0, 10.0), Vector3(1040.0, 0.0, 8.0)]:
		land.draw_colored_polygon(art._blob(W(stone.x, stone.z * 0.5), stone.z, stone.z * 0.6, RandomNumberGenerator.new(), 12, 0.12), INK)

# The branch walk over the beam: three thick boughs with a gap between them, held by hanging roots.
static func _draw_walk(art) -> void:
	var land: Node2D = art.land
	for seg in [Vector2(1250.0, 1450.0), Vector2(1500.0, 1700.0), Vector2(1750.0, 1962.0)]:
		art._limb(land, [W(seg.x - 8.0, 262.0), W((seg.x + seg.y) * 0.5, 268.0), W(seg.y + 8.0, 262.0)], [6.0, 8.0, 5.0])
		# short dead twigs on top
		art._twig_fan(land, W(seg.x + 40.0, 272.0), 26.0, int(seg.x))
		art._twig_fan(land, W(seg.y - 50.0, 272.0), 20.0, int(seg.y))
	# the shelf's end, where the walk begins
	art._limb(land, [W(1226.0, 214.0), W(1240.0, 244.0), W(1256.0, 262.0)], [5.0, 4.0, 3.0])
	# hanging roots under the walk
	for x in [1330.0, 1590.0, 1850.0]:
		art._limb(land, [W(x, 258.0), W(x + 6.0, 222.0), W(x - 3.0, 196.0)], [2.2, 1.4, 0.3])
	# and the vines it hangs from, going up out of the picture
	for x in [1290.0, 1420.0, 1540.0, 1670.0, 1790.0, 1930.0]:
		art._limb(land, [W(x, 266.0), W(x + 8.0, 330.0), W(x - 5.0, 420.0), W(x + 4.0, 560.0)], [1.8, 1.4, 1.2, 1.0])

# The static parts of the hunter's machine: the rail on the ground and the frame of the gate.
static func _draw_machine_frame(art) -> void:
	var land: Node2D = art.land
	# the rail the fulcrum slides on, with three notches
	land.draw_colored_polygon(PackedVector2Array([W(1550.0, -2.0), W(1550.0, 5.0), W(1890.0, 5.0), W(1890.0, -2.0)]), INK)
	for x in [1610.0, 1710.0, 1810.0]:
		land.draw_colored_polygon(PackedVector2Array([W(x - 7.0, 4.0), W(x - 4.0, 13.0), W(x + 4.0, 13.0), W(x + 7.0, 4.0)]), INK)
	# the gate frame: two posts, a lintel, a pulley wheel
	var gx := 2200.0
	for dx in [-64.0, 64.0]:
		land.draw_colored_polygon(PackedVector2Array([W(gx + dx - 8.0, -3.0), W(gx + dx - 7.0, 252.0), W(gx + dx + 7.0, 252.0), W(gx + dx + 8.0, -3.0)]), INK)
	# the pulley wheel on the lintel
	land.draw_circle(W(gx, 270.0), 13.0, INK)
	land.draw_colored_polygon(PackedVector2Array([W(gx - 74.0, 240.0), W(gx - 74.0, 256.0), W(gx + 74.0, 256.0), W(gx + 74.0, 240.0)]), INK)
	# a palisade of stakes leading away on both sides
	for i in range(8):
		for side in [-1.0, 1.0]:
			var sx: float = gx + float(side) * (80.0 + float(i) * 16.0)
			var h: float = 160.0 + float(art.noise.get_noise_1d(sx * 3.0)) * 36.0 - float(i) * 6.0
			land.draw_colored_polygon(PackedVector2Array([W(sx - 5.0, -3.0), W(sx - 5.0, h), W(sx, h + 14.0), W(sx + 5.0, h), W(sx + 5.0, -3.0)]), INK)

static func _draw_dressing(art) -> void:
	var land: Node2D = art.land
	# thin dead shrubs and stakes (narrow enough never to hide the player)
	for spec in [Vector2(210.0, 40.0), Vector2(330.0, 52.0), Vector2(430.0, 34.0), Vector2(960.0, 44.0), Vector2(1380.0, 38.0), Vector2(1500.0, 46.0), Vector2(1920.0, 36.0), Vector2(2420.0, 50.0), Vector2(2540.0, 34.0)]:
		art._twig_fan(land, W(spec.x, -2.0), spec.y, int(spec.x))
	# the hunter's stakes, where he marked the way
	for x in [250.0, 1010.0, 1440.0]:
		art._beam(land, W(x, -3.0), W(x + sin(x) * 6.0, 48.0), 4.6, x)

# ------------------------------------------------------------------ the foreground tufts

static func draw_grass(art) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5531
	var x := Forest.START_X + 10.0
	while x < Forest.WORLD_END:
		var cluster: float = 0.5 + art.noise.get_noise_1d(x * 1.1 + 600.0) * 0.5
		var y := _ground_top(art, x)
		if cluster > 0.68:
			var blades := rng.randi_range(3, 5)
			for b in range(blades):
				art._blade(rng, x + float(b) * rng.randf_range(2.5, 4.5), y, lerpf(9.0, 22.0, cluster) * rng.randf_range(0.7, 1.0), 0.8)
			x += rng.randf_range(16.0, 28.0)
		else:
			art._blade(rng, x, y, rng.randf_range(3.0, 9.0), 0.45)
			x += rng.randf_range(10.0, 19.0)
	# ferns over the hidden stone at the entry: a thick tuft that hides all but its crown
	for i in range(16):
		var fx := W(70.0, 0.0).x + float(i) * 3.0 + rng.randf_range(-2.0, 2.0)
		art._blade(rng, fx, _ground_top(art, fx), rng.randf_range(20.0, 40.0), 1.0)
	# tall dry reeds
	for n in range(30):
		var rx: float = rng.randf_range(Forest.START_X + 80.0, Forest.WORLD_END - 40.0)
		art._blade(rng, rx, _ground_top(art, rx), rng.randf_range(26.0, 46.0), 0.45)

# ------------------------------------------------------------------ the parts that can move (drawn every frame)

static func draw_dynamic(art) -> void:
	var dyn: Node2D = art.dyn
	# the balance beam: the pan end up, the gate end down, the fulcrum under it at the first notch
	var pan_end := W(1260.0, 140.0)
	var gate_end := W(1960.0, 20.0)
	var normal := (gate_end - pan_end).normalized().orthogonal() * 8.5
	dyn.draw_colored_polygon(PackedVector2Array([pan_end + normal, gate_end + normal, gate_end - normal, pan_end - normal]), INK)
	# the fulcrum block
	dyn.draw_colored_polygon(PackedVector2Array([W(1584.0, 4.0), W(1604.0, 72.0), W(1616.0, 72.0), W(1636.0, 4.0)]), INK)
	# the wedge that holds it
	dyn.draw_colored_polygon(PackedVector2Array([W(1566.0, 3.0), W(1568.0, 30.0), W(1592.0, 3.0)]), INK)
	# the pan: a shallow tray with a lip at each end, hung from the beam end
	dyn.draw_colored_polygon(PackedVector2Array([W(1196.0, 132.0), W(1198.0, 144.0), W(1324.0, 144.0), W(1326.0, 132.0)]), INK)
	dyn.draw_colored_polygon(PackedVector2Array([W(1196.0, 144.0), W(1196.0, 164.0), W(1206.0, 164.0), W(1208.0, 144.0)]), INK)
	dyn.draw_colored_polygon(PackedVector2Array([W(1314.0, 144.0), W(1314.0, 164.0), W(1324.0, 164.0), W(1326.0, 144.0)]), INK)
	# the arm from the beam's gate end to the portcullis, and the portcullis itself (down)
	var gx := 2200.0
	art._beam(dyn, gate_end, W(gx - 14.0, 22.0), 11.0, 3.0)
	for i in range(8):
		var bx := gx - 52.0 + float(i) * 14.8
		dyn.draw_colored_polygon(PackedVector2Array([W(bx - 3.0, -2.0), W(bx - 3.0, 226.0), W(bx + 3.0, 226.0), W(bx + 3.0, -2.0)]), INK)
		dyn.draw_colored_polygon(PackedVector2Array([W(bx - 3.0, 4.0), W(bx, -6.0), W(bx + 3.0, 4.0)]), INK)
	for cy in [64.0, 150.0, 224.0]:
		dyn.draw_colored_polygon(PackedVector2Array([W(gx - 56.0, cy - 4.0), W(gx - 56.0, cy + 4.0), W(gx + 56.0, cy + 4.0), W(gx + 56.0, cy - 4.0)]), INK)
	# the stone bag on its cord
	var bag := W(1960.0, 176.0)
	dyn.draw_line(W(1960.0, 266.0), bag + Vector2(0.0, -22.0), INK, 3.0, true)
	dyn.draw_colored_polygon(art._blob(bag, 24.0, 28.0, RandomNumberGenerator.new(), 16, 0.12), INK)

# ------------------------------------------------------------------ pale marks and the lantern glow (drawn above the actor)

static func draw_effects(art) -> void:
	var fx: Node2D = art.effects
	# the hunter's blazes: strips of bark cut away, pale on the trunk of the big tree
	for h in [60.0, 150.0, 240.0, 330.0]:
		var p := W(506.0, h)
		fx.draw_rect(Rect2(p + Vector2(-4.0, -14.0), Vector2(8.0, 28.0)), Color(0.62, 0.62, 0.60, 0.9))
	# the same mark on the stump and on the log's cut end
	fx.draw_rect(Rect2(W(641.0, 48.0) + Vector2(-4.0, -10.0), Vector2(8.0, 20.0)), Color(0.62, 0.62, 0.60, 0.9))
	# the hidden stone: only a faint rim of light on its crown
	var crown := W(92.0, 14.0)
	fx.draw_arc(crown, 14.0, PI * 1.12, PI * 1.88, 12, Color(0.55, 0.55, 0.53, 0.28), 1.6, true)
	# the hunter's lantern behind the gate: a small warm light in the fog (the only colour)
	var lantern := W(2330.0, 150.0)
	var flicker := 0.85 + 0.15 * sin(art.clock * 5.3) * sin(art.clock * 2.1)
	art._soft(fx, lantern, Vector2(260.0, 200.0), Color(0.95, 0.58, 0.18, 0.10 * flicker))
	art._soft(fx, lantern, Vector2(90.0, 90.0), Color(1.0, 0.70, 0.30, 0.26 * flicker))
	fx.draw_circle(lantern, 4.0, Color(1.0, 0.82, 0.5, 0.9 * flicker))

# ------------------------------------------------------------------ mist that drifts along the ground (behind the ink)

static func draw_fog(art) -> void:
	var fog: Node2D = art.fog
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var x := Forest.START_X
	while x < Forest.WORLD_END:
		var drift := sin(art.clock * 0.18 + x * 0.013) * 26.0
		var y := Forest.FLOOR_Y - rng.randf_range(10.0, 60.0)
		art._soft(fog, Vector2(x + drift, y), Vector2(rng.randf_range(300.0, 560.0), rng.randf_range(90.0, 170.0)), Color(0.30, 0.30, 0.30, rng.randf_range(0.09, 0.16)))
		x += rng.randf_range(180.0, 320.0)
