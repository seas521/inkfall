extends Node2D

# Scene 1 of chapter 1 (docs/chapters/scenes/scene-01-chase.md): the cliff edge at the edge of the forest. West of the C zone in the
# world; the ground here is at GROUND_Y, thousands of px above the C zone's bank. He lies on the ground, gets up, and runs east
# through a long stretch of natural ground (mounds, boulders, small pits, shallow ponds, a fallen trunk) to the cliff edge and goes
# over. The hunter and the chase are not made yet (he just runs).
#
# This file: the ground, the obstacles, the start (lying, getting up). The drawing is in scene1_ink.gd (marsh_art's ink stage), from
# the same data. Coordinates are world coordinates (y up is negative).

const START_X := -7300.0  # where he lies
const GROUND_Y := -4300.0  # the ground's surface
const WORLD_LEFT := -9700.0  # the ground and the forest go on well past the point he can run to (the world edge at -8500)
const CLIFF_X := -3500.0  # the cliff edge: the ground ends here
const PLAYER_SIZE := Vector2(26.0, 54.0)

# The natural ground along the route. x is the offset from START_X.
#   mound   smooth hill:   x = centre, w = half width, h = height
#   pond    shallow water: x = start, w = width, d = depth (he wades: slower; the water is water_pool.gd)
#   pit     a gap with spikes at the bottom: x = start, w = width (island = a small rock in the middle to step on); falling in is death
#   spikes  thorns / stakes on the ground: x = start, w = width; touching them is death, he jumps them
#   boulder a rock:        x = centre, top / bottom = widths of the flat spot on top and of the foot, h = height above the ground
#   rock    a rock at an absolute height (stepping stones in ponds): x = centre, w, top = height above GROUND_Y (negative = below)
#   log     a fallen tree he can jump onto: x = start, len, h
const FEATURES := [
	{"t": "pit", "x": 700.0, "w": 100.0},
	{"t": "log", "x": 1250.0, "len": 210.0, "h": 60.0},
	{"t": "spikes", "x": 1800.0, "w": 96.0},
	{"t": "pond", "x": 2250.0, "w": 320.0, "d": 40.0},
	{"t": "boulder", "x": 2900.0, "top": 70.0, "bottom": 150.0, "h": 96.0, "seed": 3},
	{"t": "pit", "x": 3350.0, "w": 128.0, "island": true},
]

const LOG_TAPER := 0.84  # height of a fallen tree's thin end compared with its root end
const PIT_SPIKES_DEPTH := 70.0  # how far down the spikes are at the bottom of a pit
const WaterPool = preload("res://scripts/demos/c_zone_debug/water_pool.gd")
const LIE_TIME := 1.4  # lying still
const GET_UP_TIME := 1.9  # the get-up clip

var level: Node2D
var clock := 0.0
var intro_time := 0.0
var body: StaticBody2D
var pools: Array = []
var previous_feet_y := 0.0

static func spawn_position() -> Vector2:
	return Vector2(START_X - PLAYER_SIZE.x * 0.5, ground_top(START_X) - PLAYER_SIZE.y - 2.0)

static func fx(feature: Dictionary) -> float:
	return START_X + float(feature["x"])

# How far the open ground rises and falls at x (px, up is negative): a slow swell of a few pixels, with smaller ripples on it. It is
# flat at the start and wherever there is an obstacle (those are placed on the level ground GROUND_Y).
static func swell(x: float) -> float:
	var s := sin(x * 0.0071 + 0.8) * 7.0 + sin(x * 0.0173 + 2.1) * 3.6 + sin(x * 0.041 + 0.3) * 1.3
	return s * flat_mask(x)

static func flat_mask(x: float) -> float:
	var mask := smoothstep(START_X - 40.0, START_X + 360.0, x)  # level where he lies
	for f: Dictionary in FEATURES:
		var from := fx(f)
		var to := from
		match String(f["t"]):
			"boulder":
				from -= float(f["bottom"]) * 0.7
				to += float(f["bottom"]) * 0.7
			"log":
				to += float(f["len"])
			"spikes", "pit", "pond":
				to += float(f["w"])
		var near := smoothstep(from - 150.0, from - 20.0, x) * (1.0 - smoothstep(to + 20.0, to + 150.0, x))
		mask *= 1.0 - near
	return mask

# The ground's surface at x: gently rolling, minus the ponds.
static func ground_top(x: float) -> float:
	var y := GROUND_Y + swell(x)
	for f: Dictionary in FEATURES:
		var t := String(f["t"])
		if t == "pond":
			var x0 := fx(f)
			var w2 := float(f["w"])
			var u := clampf((x - x0) / w2, 0.0, 1.0)
			y += float(f["d"]) * pow(sin(PI * u), 1.4)  # a shallow bowl: the banks slope gently into the water
	return y

static func in_pit(x: float) -> bool:
	for f: Dictionary in FEATURES:
		if String(f["t"]) == "pit":
			var x0 := fx(f)
			if x > x0 and x < x0 + float(f["w"]):
				return true
	return false

# The solid ground comes in pieces: the pits are the gaps between them.
static func ground_pieces() -> Array:
	var cuts: Array = []
	for f: Dictionary in FEATURES:
		if String(f["t"]) == "pit":
			cuts.append(Vector2(fx(f), fx(f) + float(f["w"])))
	cuts.sort_custom(func(a, b): return a.x < b.x)
	var pieces: Array = []
	var from := WORLD_LEFT
	for cut: Vector2 in cuts:
		pieces.append(Vector2(from, cut.x))
		from = cut.y
	pieces.append(Vector2(from, CLIFF_X))
	return pieces

# Corner-cutting: every corner is replaced by two points a quarter of the way along each edge, so a trapezoid turns into a rounded rock.
static func round_corners(points: PackedVector2Array, times: int) -> PackedVector2Array:
	var current := points
	for _i in range(times):
		var next := PackedVector2Array()
		var n := current.size()
		for i in range(n):
			var a: Vector2 = current[i]
			var b: Vector2 = current[(i + 1) % n]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		current = next
	return current

# A boulder's outline (also its collision): a rounded rock with a flat spot on top, one of three shapes (a hump, a leaning slab,
# a shouldered rock). x = centre, y up from the ground.
static func boulder_points(f: Dictionary) -> PackedVector2Array:
	var cx := fx(f)
	var top := float(f["top"]) * 0.5
	var bottom := float(f["bottom"]) * 0.5
	var h := float(f["h"])
	var g := ground_top(cx)
	var raw: PackedVector2Array
	match int(f["seed"]) % 3:
		0:  # a hump: gentle on the left, steep on the right
			raw = PackedVector2Array([Vector2(cx - bottom * 1.15, g + 8.0), Vector2(cx - bottom * 0.7, g - h * 0.30), Vector2(cx - top * 1.5, g - h * 0.78), Vector2(cx - top * 0.6, g - h), Vector2(cx + top * 0.8, g - h), Vector2(cx + bottom * 0.62, g - h * 0.6), Vector2(cx + bottom * 0.78, g - h * 0.1), Vector2(cx + bottom * 0.84, g + 8.0)])
		1:  # a leaning slab: the top overhangs on the left
			raw = PackedVector2Array([Vector2(cx - bottom * 0.7, g + 8.0), Vector2(cx - bottom * 0.78, g - h * 0.4), Vector2(cx - top * 1.7, g - h * 0.9), Vector2(cx - top * 1.1, g - h), Vector2(cx + top * 0.9, g - h), Vector2(cx + bottom * 0.7, g - h * 0.45), Vector2(cx + bottom * 1.05, g + 8.0)])
		_:  # a shouldered rock: a step on one side
			raw = PackedVector2Array([Vector2(cx - bottom, g + 8.0), Vector2(cx - bottom * 0.9, g - h * 0.4), Vector2(cx - top * 1.2, g - h * 0.55), Vector2(cx - top * 0.5, g - h), Vector2(cx + top * 0.9, g - h), Vector2(cx + bottom * 0.7, g - h * 0.7), Vector2(cx + bottom * 0.95, g - h * 0.1), Vector2(cx + bottom * 1.0, g + 8.0)])
	return round_corners(raw, 2)

func _ready() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for piece: Vector2 in ground_pieces():
		var shape := CollisionPolygon2D.new()
		var points := PackedVector2Array()
		points.append(Vector2(piece.x, GROUND_Y + 700.0))
		var x := piece.x
		while x < piece.y:
			points.append(Vector2(x, ground_top(x)))
			x += 8.0
		points.append(Vector2(piece.y, ground_top(piece.y)))
		points.append(Vector2(piece.y, GROUND_Y + 700.0))
		shape.polygon = points
		body.add_child(shape)
	for f: Dictionary in FEATURES:
		var t := String(f["t"])
		if t == "boulder":
			var poly := CollisionPolygon2D.new()
			poly.polygon = boulder_points(f)
			body.add_child(poly)
		elif t == "log":
			# a tapering trunk: thick at the root end, 16% lower at the broken end
			var poly2 := CollisionPolygon2D.new()
			var lx := fx(f)
			poly2.polygon = PackedVector2Array([Vector2(lx, GROUND_Y + 6.0), Vector2(lx, GROUND_Y - float(f["h"])), Vector2(lx + float(f["len"]), GROUND_Y - float(f["h"]) * LOG_TAPER), Vector2(lx + float(f["len"]), GROUND_Y + 6.0)])
			body.add_child(poly2)
		elif t == "rock":
			var shape3 := CollisionShape2D.new()
			var rect3 := RectangleShape2D.new()
			rect3.size = Vector2(float(f["w"]), 160.0)
			shape3.shape = rect3
			shape3.position = Vector2(fx(f), GROUND_Y - float(f["top"]) + 80.0)
			body.add_child(shape3)
		elif t == "pit" and bool(f.get("island", false)):
			var shape4 := CollisionShape2D.new()
			var rect4 := RectangleShape2D.new()
			rect4.size = Vector2(46.0, 300.0)
			shape4.shape = rect4
			shape4.position = Vector2(fx(f) + float(f["w"]) * 0.5, GROUND_Y + 150.0)
			body.add_child(shape4)
	add_child(body)
	# the ponds: real water in each dip
	for f: Dictionary in FEATURES:
		if String(f["t"]) == "pond":
			var pool = WaterPool.new()
			pool.setup(level, fx(f), fx(f) + float(f["w"]), GROUND_Y, Callable(self, "_bed"), float(f["d"]))
			add_child(pool)
			pools.append(pool)

func _bed(x: float) -> float:
	return ground_top(x)

func reset() -> void:
	intro_time = 0.0
	for pool in pools:
		pool.inside = false

# Touching thorns, or falling to the spikes at the bottom of a pit: death.
func hazard_hit() -> bool:
	if level.player.position.x > -300.0 or level.player.position.x < WORLD_LEFT:
		return false
	var feet := Vector2(level.player.position.x + PLAYER_SIZE.x * 0.5, level.player.position.y + PLAYER_SIZE.y)
	for f: Dictionary in FEATURES:
		var t := String(f["t"])
		if t == "spikes":
			if feet.x > fx(f) + 4.0 and feet.x < fx(f) + float(f["w"]) - 4.0 and feet.y > GROUND_Y - 16.0:
				return true
		elif t == "pit":
			if feet.x > fx(f) + 6.0 and feet.x < fx(f) + float(f["w"]) - 6.0 and feet.y > GROUND_Y + PIT_SPIKES_DEPTH - 24.0:
				return true
	return false

func tick(delta: float) -> void:
	clock += delta
	var near: bool = level.player.position.x < -300.0
	if near:
		intro_time += delta
	var feet := Vector2(level.player.position.x + PLAYER_SIZE.x * 0.5, level.player.position.y + PLAYER_SIZE.y)
	for pool in pools:
		pool.visible = near and absf(pool.x_start - feet.x) < 2400.0
		if pool.visible:
			pool.update(delta, feet, level.player.velocity, previous_feet_y)
	previous_feet_y = feet.y

func locks_move() -> bool:
	return level.player.position.x < -300.0 and intro_time < LIE_TIME + GET_UP_TIME

# What he does while lying and getting up: {action, progress}
func pose_info() -> Dictionary:
	if level == null or level.player.position.x >= -300.0 or intro_time >= LIE_TIME + GET_UP_TIME:
		return {"action": &"none", "progress": 0.0}
	if intro_time < LIE_TIME:
		return {"action": &"downed", "progress": clampf(intro_time / LIE_TIME, 0.0, 1.0)}
	return {"action": &"get_up", "progress": clampf((intro_time - LIE_TIME) / GET_UP_TIME, 0.0, 1.0)}

# Standing in a shallow pond (he wades: slower).
func in_pond() -> bool:
	var x: float = level.player.position.x + PLAYER_SIZE.x * 0.5
	if x > CLIFF_X or x < WORLD_LEFT or level.player.position.x > -300.0:
		return false
	for f: Dictionary in FEATURES:
		if String(f["t"]) == "pond":
			var x0 := fx(f)
			if x > x0 + 12.0 and x < x0 + float(f["w"]) - 12.0 and level.player.position.y + PLAYER_SIZE.y > GROUND_Y + float(f["d"]) * 0.35:
				return true
	return false

# Gone over the edge or into a pit: for now (scenes 2 to 6 are not made) he starts again.
func fell_off() -> bool:
	return level.player.position.x < -300.0 and level.player.position.y > GROUND_Y + 700.0
