extends Node2D

const PredatorLayout=preload("res://scripts/chapters/forest_predator_layout.gd")
const PredatorAct=preload("res://scripts/chapters/forest_predator_act.gd")
var predator
const SpiderAct=preload("res://scripts/chapters/forest_spider_act.gd")
var spider
const Crevice=preload("res://scripts/chapters/rock_crevice_layout.gd")
const LowStance=preload("res://scripts/actors/low_stance_act.gd")
var low_stance
var low_tick_frame:=-1

# Scene 1 of chapter 1 (docs/chapters/scenes/scene-01-chase.md): the cliff edge at the edge of the forest. West of the C zone in the
# world; the ground here is at GROUND_Y, thousands of px above the C zone's bank. He lies on the ground, gets up, and runs east
# through a long stretch of natural ground (mounds, boulders, small pits, shallow ponds, a fallen trunk) to the cliff edge and goes
# over. The hunter and the chase are not made yet (he just runs).
#
# This file: the ground, the obstacles, the start (lying, getting up). The drawing is in scene1_ink.gd (marsh_art's ink stage), from
# the same data. Coordinates are world coordinates (y up is negative).

const START_X := -9500.0  # where he lies
const GROUND_Y := -4300.0  # the ground's surface
const WORLD_LEFT := -10800.0  # the ground and the forest go on well past the point he can run to (the world edge at -9200)
const CLIFF_X := -3500.0  # the cliff edge: the ground ends here
const PLAYER_SIZE := Vector2(26.0, 54.0)
const LIGHT_X := START_X + 2850.0  # the clearing with the shaft of light (the middle of the pond)

# The shots, in order along the route (x is the offset from START_X):
#   0 - 500     he wakes: the darkest, tightest picture, a faint glow behind him
#   500 - 2400  out through the forest: big out-of-focus trunks go past; a fallen tree (climb) and a pit (jump)
#   2400 - 3300 the clearing: a shaft of light and a shallow pond (he wades)
#   3300 - 4800 the way up: a bramble (jump), then the ground rises to a boulder (climb) and on to the cliff; the trees thin out and
#               the far valley opens up
# The natural ground along the route:
#   mound   smooth hill:   x = centre, w = half width, h = height
#   pond    shallow water: x = start, w = width, d = depth (he wades: slower; the water is water_pool.gd)
#   pit     a gap with spikes at the bottom: x = start, w = width (island = a small rock in the middle to step on); falling in is death
#   spikes  curved brambles on the ground: x = start, w = width; touching trips him, jumping clears them
#   boulder a rock:        x = centre, top / bottom = widths of the flat spot on top and of the foot, h = height above the ground
#   rock    a rock at an absolute height (stepping stones in ponds): x = centre, w, top = height above GROUND_Y (negative = below)
#   log     a fallen tree he can jump onto: x = start, len, h
const BRAMBLE_OFFSET:=3320.0
const FEATURES := [
	{"t": "log", "x": 1000.0, "len": 380.0, "h": 38.0},
	{"t": "pit", "x": 1880.0, "w": 96.0},
	{"t": "pond", "x": 2680.0, "w": 340.0, "d": 22.0},
	{"t": "spikes", "x": BRAMBLE_OFFSET, "w": 84.0},
	{"t":"crevice","x":3820.0,"w":1480.0},
	# the ground is never a ruler line: the long rise to the cliff, and a few low swells between the obstacles
	# (these come last: the tests count the others by kind)
	{"t": "mound", "x": 6000.0, "w": 2700.0, "h": 190.0},
	{"t": "mound", "x": 380.0, "w": 300.0, "h": 30.0},
	{"t": "mound", "x": 1520.0, "w": 240.0, "h": 34.0},
	{"t": "mound", "x": 2260.0, "w": 210.0, "h": 26.0},
	{"t": "mound", "x": 3210.0, "w": 190.0, "h": 28.0},
]

const LOG_TAPER := 0.84  # (only the old drawn log in scene1_ink.gd uses it)
# the top line of the fallen trunk in forest_fallen_log.jpg (1280 x 720): x, y of the top of the trunk proper (the stubs are left out); the trunk
# proper runs from x 270 to 1230 and is about 112 px thick at the root end
const LOG_PROFILE := [Vector2(272, 372), Vector2(330, 373), Vector2(400, 375), Vector2(460, 376), Vector2(520, 378), Vector2(600, 384), Vector2(700, 390), Vector2(800, 393), Vector2(900, 396), Vector2(1000, 394), Vector2(1100, 392), Vector2(1170, 388), Vector2(1228, 394)]
const PIT_SPIKES_DEPTH := 70.0  # how far down the spikes are at the bottom of a pit
static var broken_from := 1.0e9  # after the hand has come down the ground ends here instead of at CLIFF_X
static func edge_x() -> float:
	return minf(CLIFF_X, broken_from)
const WaterPool = preload("res://scripts/demos/c_zone_debug/water_pool.gd")
const Hunter = preload("res://scripts/demos/c_zone_debug/hunter_act.gd")
# The hunter's chase (hunter_act.gd, hunter_art.gd: the foot, the arm, the line, the lantern, the hand that breaks the edge) is switched
# off for now: with this false none of it is made, drawn or run, and the route is quiet again. (docs/art/seedance-hunter-prompts.md)
const HUNTER_ON := false
# the checkpoints (his feet's x): the start, after the pond (the hunter's first foot), after the thorns (the arm), after the boulder
const CP_X := [START_X, START_X+3040.0, START_X+3578.0, Crevice.EXIT_SAFE+12.0]
const LIE_TIME := 1.4  # lying still
const GET_UP_TIME := 1.9  # the get-up clip

# The cliff (computer-controlled): from AUTO_X on the boy is out of breath and walks on by himself, slower and slower; at PANT_X
# (a little short of the edge) he staggers to a halt and bends over, hands on his knees; after a few breaths the flock comes up out
# of the chasm (the bat event of level 1: scripts/art/surface_bat_flock.gd, the same timings), strikes him down, and when he has
# got up again the controls are his.
enum Cut { NONE, WALK, STOP, PANT, FLOCK, KNOCK, DOWNED, GETUP, DONE, SLAM_OMEN, SLAM }
const AUTO_X := CLIFF_X - 560.0  # (his feet) where the walk takes over
const PANT_X := CLIFF_X - 170.0  # where he stops
const GRAVE_X := CLIFF_X-92.0

static func grave_position()->Vector2:
	return Vector2(GRAVE_X,ground_top(GRAVE_X))
const WALK_SPEED_FROM := 118.0
const WALK_SPEED_TO := 48.0
const STOP_TIME := 0.45  # tired_stop from its 8th frame to its last (27 frames at 60 fps)
const PANT_TIME := 3.3  # the bent-over breathing before the flock comes
const BREATH_TIME := 1.0  # one loop of tired_idle
const FLOCK_IMPACT_TIME := 0.82  # (SURFACE_BAT_IMPACT_TIME in level 1)
const FLOCK_VISUAL_TIME := 2.35  # (SURFACE_BAT_VISUAL_DURATION)
const KNOCK_TIME := 1.417
const DOWNED_TIME := 1.25
const GETUP_TIME := 2.375
# after he has got up the controls are his again for FREE_TIME; then the hunter's hand comes for him: a shadow follows him (OMEN_TIME,
# it stops following in the last LOCK_TIME), then the hand comes down and the edge breaks away from SLAM_BACK px behind where he stood
const FREE_TIME := 2.6
const SLAM_OMEN_TIME := 1.7
const SLAM_LOCK_TIME := 0.5
const SLAM_FALL_TIME := 0.3  # the hand is seen coming down for this long
const SLAM_BACK := 150.0

var level: Node2D
var clock := 0.0
var intro_time := 0.0
var body: StaticBody2D
var pools: Array = []
var previous_feet_y := 0.0
var cut: int = Cut.NONE
var cut_time := 0.0  # in the current phase
var flock_time := 0.0  # since the flock came up (it carries on through the knock-down)
var flock_on := false
var breath_time := 0.0
var walk_feet_x := 0.0
var sounds := {}  # name -> AudioStreamPlayer
var cp := 0  # the checkpoint he comes back to
var slam_x := 0.0  # where the hand comes down
var slam_time := 0.0  # since it did
var edge_polygon: CollisionPolygon2D
var hunter: Node2D
var rain_level := 0.0
var previous_cut: int = Cut.NONE
var previous_flock := -1.0
const TRIP_FALL_TIME:=0.542
const TRIP_DOWN_TIME:=0.30
const TRIP_GET_UP_TIME:=1.90
const TRIP_DURATION:=TRIP_FALL_TIME+TRIP_DOWN_TIME+TRIP_GET_UP_TIME
var trip_time:=-1.0
var trip_contact:=false
var trip_count:=0

# 0 in the forest, 1 out on the open ground at the cliff: the rain, the blown leaves and the dust (the weather of level 1's cliff) come in as the trees thin out
static func weather(camera_x: float) -> float:
	return smoothstep(-4900.0, -4300.0, camera_x) * (1.0 - smoothstep(-2600.0, -2400.0, camera_x))

static func spawn_position() -> Vector2:
	return Vector2(START_X - PLAYER_SIZE.x * 0.5, GROUND_Y - PLAYER_SIZE.y - 2.0)

# Where he comes back to: the start (lying), or one of the checkpoints on the way (on his feet)
func respawn_position() -> Vector2:
	if spider!=null and spider.retry_armed and not spider.cleared:return spider.retry_position()
	if cp <= 0:
		return predator.retry_position() if predator!=null and predator.retry_armed else spawn_position()
	var x: float = CP_X[cp]
	return Vector2(x - PLAYER_SIZE.x * 0.5, ground_top(x) - PLAYER_SIZE.y - 2.0)

static func fx(feature: Dictionary) -> float:
	return START_X + float(feature["x"])

# The ground's surface at x: level, plus the mounds, minus the ponds.
# The ground's height is asked for thousands of times a frame (the drawing, the grass, the mist: every one walks along the contour), and
# each answer used to go through every feature of the route; the contour does not change, so it is sampled once (every 2 px) and read back.
const TOP_STEP := 2.0
const TOP_FROM := -11000.0
const TOP_TO := -3300.0
static var _top_samples := PackedFloat32Array()
static var _pit_ranges: Array = []

static func _build_caches() -> void:
	var n := int((TOP_TO - TOP_FROM) / TOP_STEP) + 2
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		samples[i] = _ground_top_raw(TOP_FROM + float(i) * TOP_STEP)
	_top_samples = samples
	var pits: Array = []
	for f: Dictionary in FEATURES:
		if String(f["t"]) == "pit":
			pits.append(Vector2(fx(f), fx(f) + float(f["w"])))
	_pit_ranges = pits

static func ground_top(x: float) -> float:
	if _top_samples.is_empty():
		_build_caches()
	if x <= TOP_FROM or x >= TOP_TO:
		return _ground_top_raw(x)
	var position := (x - TOP_FROM) / TOP_STEP
	var index := int(position)
	return lerpf(_top_samples[index], _top_samples[index + 1], position - float(index))

static func _ground_top_raw(x: float) -> float:
	var y := GROUND_Y
	for f: Dictionary in FEATURES:
		var t := String(f["t"])
		if t == "mound":
			var w := float(f["w"])
			var dx := absf(x - fx(f))
			if dx < w:
				var k := 1.0 - dx / w
				y -= float(f["h"]) * (0.5 - 0.5 * cos(PI * k))
		elif t == "pond":
			var x0 := fx(f)
			var w2 := float(f["w"])
			var edge := minf(60.0, w2 * 0.3)
			var inside := smoothstep(x0, x0 + edge, x) * (1.0 - smoothstep(x0 + w2 - edge, x0 + w2, x))
			y += float(f["d"]) * inside
	# The player climbs the bank after the old spike pit. The plant stays
	# rooted at the original forest floor ahead, never hidden below it.
	var rise:=smoothstep(PredatorLayout.RISE_START,PredatorLayout.RISE_TOP,x)
	var fall:=1.0-smoothstep(PredatorLayout.BANK_EDGE,PredatorLayout.BANK_BOTTOM,x)
	y-=PredatorLayout.BANK_HEIGHT*rise*fall
	var exit_rise:=smoothstep(PredatorLayout.EXIT_RISE,PredatorLayout.EXIT_TOP,x)
	var exit_fall:=1.0-smoothstep(PredatorLayout.EXIT_TOP,PredatorLayout.EXIT_BOTTOM,x)
	y-=PredatorLayout.EXIT_HEIGHT*exit_rise*exit_fall
	y=Crevice.floor_for(x,y)
	return y

static func in_pit(x: float) -> bool:
	if _pit_ranges.is_empty() and _top_samples.is_empty():
		_build_caches()
	for range_value: Vector2 in _pit_ranges:
		if x > range_value.x and x < range_value.y:
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
	pieces.append(Vector2(from, edge_x()))
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

# A boulder's outline (also its collision): the silhouette of the boulder image (assets/art/c_zone_debug/forest/forest_boulder_block.jpg,
# measured on its 1024 x 576 view: a sheer left face, a flat top, a leaning right side; the top-left corner is kept sharp: the climb clip
# takes hold of the corner, so the corner is where the boy hangs, and a rounded one would leave him inside the rock), so the rock he sees is the rock he climbs.
# x = centre, y up from the ground. The same numbers place the sprite (river_art.gd).
const BOULDER_VIEW := [Vector2(318, 440), Vector2(318, 300), Vector2(318, 200), Vector2(318, 124), Vector2(326, 112), Vector2(346, 108), Vector2(400, 108), Vector2(500, 112), Vector2(600, 123), Vector2(645, 135), Vector2(665, 155), Vector2(700, 225), Vector2(725, 320), Vector2(735, 385), Vector2(725, 420), Vector2(700, 440), Vector2(640, 452), Vector2(400, 457), Vector2(340, 448)]
const BOULDER_CENTRE_X := 526.0  # the rock's centre in the view
const BOULDER_BOTTOM_Y := 457.0  # its foot
const BOULDER_TOP_Y := 108.0  # its top
const BOULDER_SINK := 5.0  # the foot sinks into the ground

# (sx, sy): view pixels -> world pixels
static func boulder_scale(f: Dictionary) -> Vector2:
	return Vector2(float(f["bottom"]) * 0.95 / 417.0, float(f["h"]) / (BOULDER_BOTTOM_Y - BOULDER_TOP_Y))

static func boulder_points(f: Dictionary) -> PackedVector2Array:
	var cx := fx(f)
	var g := ground_top(cx)
	var k := boulder_scale(f)
	var points := PackedVector2Array()
	for v: Vector2 in BOULDER_VIEW:
		points.append(Vector2(cx + (v.x - BOULDER_CENTRE_X) * k.x, g + BOULDER_SINK - (BOULDER_BOTTOM_Y - v.y) * k.y))
	return points

func _ready() -> void:
	predator=PredatorAct.new(self)
	predator.reset(true)
	spider=SpiderAct.new(self)
	spider.reset(true)
	low_stance=LowStance.new(level)
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for piece: Vector2 in ground_pieces():
		var shape := CollisionPolygon2D.new()
		shape.polygon = _piece_points(piece)
		body.add_child(shape)
		edge_polygon = shape  # (the last one is the one that ends at the cliff)
	for f: Dictionary in FEATURES:
		var t := String(f["t"])
		if t=="crevice":
			var ceiling_shape:=CollisionPolygon2D.new()
			ceiling_shape.polygon=Crevice.polygon(Callable(self,"ground_top"))
			body.add_child(ceiling_shape)
		elif t == "boulder":
			var poly := CollisionPolygon2D.new()
			poly.polygon = boulder_points(f)
			body.add_child(poly)
		elif t == "log":
			# a tapering trunk: thick at the root end, 16% lower at the broken end
			var poly2 := CollisionPolygon2D.new()
			var lx := fx(f)
			var lh := float(f["h"])
			# the collision follows the trunk's own top line in the image (LOG_PROFILE), so that his feet stand on what he sees; a rounded
			# start: a jump that is a little early still slides up onto it instead of catching on a corner
			var pts := PackedVector2Array([Vector2(lx - 4.0, GROUND_Y + 6.0), Vector2(lx - 4.0, GROUND_Y - lh * 0.6)])
			for v: Vector2 in LOG_PROFILE:
				pts.append(Vector2(lx + (v.x - 270.0) / 960.0 * float(f["len"]), GROUND_Y - lh + (v.y - 375.0) * float(f["len"]) / 960.0))
			pts.append(Vector2(lx + float(f["len"]), GROUND_Y + 6.0))
			poly2.polygon = pts
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
	_make_sounds()
	if HUNTER_ON:
		hunter = Hunter.new()
		add_child(hunter)
		hunter.setup(level, self)
	# the ponds: real water in each dip
	for f: Dictionary in FEATURES:
		if String(f["t"]) == "pond":
			var pool = WaterPool.new()
			pool.setup(level, fx(f), fx(f) + float(f["w"]), GROUND_Y, Callable(self, "_bed"), float(f["d"]))
			add_child(pool)
			pools.append(pool)

static func _piece_points(piece: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2(piece.x, GROUND_Y + 700.0))
	var x := piece.x
	while x < piece.y:
		points.append(Vector2(x, ground_top(x)))
		x += 8.0
	points.append(Vector2(piece.y, ground_top(piece.y)))
	points.append(Vector2(piece.y, GROUND_Y + 700.0))
	return points

# The edge breaks away: the ground (and its picture) ends at `x` now
func break_edge(x: float) -> void:
	broken_from = x
	var pieces := ground_pieces()
	edge_polygon.set_deferred("polygon", _piece_points(pieces[pieces.size() - 1]))
	_redraw_land()

func _redraw_land() -> void:
	var stage = level.get("marsh_art")
	if stage != null and stage.get("land") != null:
		(stage.land as Node2D).queue_redraw()

func _bed(x: float) -> float:
	return ground_top(x)

func reset() -> void:
	if low_stance!=null:low_stance.reset()
	trip_time=-1.0
	trip_contact=false
	if predator!=null:predator.reset()
	if spider!=null:spider.reset()
	intro_time = 0.0 if cp <= 0 and not ((predator!=null and predator.retry_armed) or (spider!=null and spider.retry_armed)) else 99.0
	cut = Cut.NONE
	cut_time = 0.0
	flock_time = 0.0
	flock_on = false
	breath_time = 0.0
	for pool in pools:
		pool.inside = false
	slam_time = 0.0
	if broken_from < 1.0e8:
		broken_from = 1.0e9
		var pieces := ground_pieces()
		edge_polygon.polygon = _piece_points(pieces[pieces.size() - 1])
		_redraw_land()
	if hunter != null:
		hunter.reset(cp, float(CP_X[cp]) if cp > 0 else START_X)

# Falling onto pit spikes is lethal. Surface brambles only trip the player.
func hazard_hit() -> bool:
	if level.player.position.x > -300.0 or level.player.position.x < WORLD_LEFT:
		return false
	var feet := Vector2(level.player.position.x + PLAYER_SIZE.x * 0.5, level.player.position.y + PLAYER_SIZE.y)
	for f: Dictionary in FEATURES:
		var t := String(f["t"])
		if t == "pit":
			if feet.x > fx(f) + 6.0 and feet.x < fx(f) + float(f["w"]) - 6.0 and feet.y > GROUND_Y + PIT_SPIKES_DEPTH - 24.0:
				return true
	return false

func tripping()->bool:
	return trip_time>=0.0

func _tick_trip(delta:float,feet:Vector2)->void:
	if tripping():
		var before:=trip_time
		trip_time+=delta
		if before<TRIP_FALL_TIME+TRIP_DOWN_TIME and trip_time>=TRIP_FALL_TIME+TRIP_DOWN_TIME:
			(sounds["cloth"] as AudioStreamPlayer).play()
		if trip_time>=TRIP_DURATION:trip_time=-1.0
		return
	var touching:=false
	var nearby:=false
	for f:Dictionary in FEATURES:
		if String(f["t"])!="spikes":continue
		var left:=fx(f)
		var right:=left+float(f["w"])
		nearby=nearby or (feet.x>left-18 and feet.x<right+18)
		touching=touching or (feet.x>left+4 and feet.x<right-4 and feet.y>ground_top(feet.x)-28)
	if not nearby:trip_contact=false
	if not touching or trip_contact or not level.player.is_on_floor():return
	if intro_time<LIE_TIME+GET_UP_TIME or cut not in [Cut.NONE,Cut.DONE]:return
	if level.curtain_phase!=0 or level.marsh_hit_time>0 or level.death_time>0:return
	trip_contact=true
	trip_time=0
	trip_count+=1
	level.player.velocity=Vector2.ZERO
	level.jump_buffer=0
	level.jump_windup_left=0
	(sounds["impact"] as AudioStreamPlayer).play()

func tick_low_stance(delta:float)->void:
	var frame_id:=Engine.get_physics_frames()
	if low_tick_frame==frame_id:return
	low_tick_frame=frame_id
	var feet:=Vector2(level.player.position.x+PLAYER_SIZE.x*.5,level.player.position.y+PLAYER_SIZE.y)
	var ladder_mouth:bool=absf(feet.x-(CLIFF_X-26))<100 and absf(feet.y-ground_top(CLIFF_X))<65
	var route_locked:bool=level.marsh_hit_time>0 or level.death_time>0 or level.climb_time>=0
	if level.log_bridge!=null:route_locked=route_locked or level.log_bridge.failure_time>0 or level.log_bridge.gripping
	var low_allowed:bool=intro_time>=LIE_TIME+GET_UP_TIME and cut in [Cut.NONE,Cut.DONE] and not route_locked
	# Beneath the timber, releasing S retains the pose until there is room to
	# stand. Everywhere else this remains a normal hold-S crouch.
	var under_wood:bool=Crevice.in_low_zone(feet.x) and feet.y>Crevice.roof_top(feet.x,Callable())+25
	var low_wanted:bool=(low_stance.active() and under_wood) or (Input.is_action_pressed("climb_down") and not ladder_mouth)
	low_stance.tick(delta,low_wanted,low_allowed and level.player.is_on_floor(),Crevice.at_mouth(feet.x))

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
	tick_low_stance(delta)
	if near:
		_tick_trip(delta,feet)
		predator.tick(delta)
		spider.tick(delta)
		_tick_cut(delta, feet.x)
		if hunter != null:
			hunter.tick(delta, feet, level.player.is_on_floor())
		# a checkpoint is taken when he stands on it (not while the hunter has him)
		if cp < CP_X.size() - 1 and cut == Cut.NONE and feet.x >= CP_X[cp + 1] and level.player.is_on_floor() and level.marsh_hit_time <= 0.0:
			cp += 1
	_tick_sounds(delta, near)

func _make_sounds() -> void:
	# the same sounds level 1's bats and rain use (scripts/audio/level01_surface_audio.gd)
	for entry in [["rain", "ambience_rain", -80.0, true, &"Ambience"], ["wings", "bat_wings", -4.5, false, &"Event"], ["colony", "bat_colony", -8.0, false, &"Event"],
			["whoosh", "bat_whoosh", -4.0, false, &"Event"], ["impact", "body_impact", -3.5, false, &"Event"], ["cloth", "get_up_cloth", -8.5, false, &"Character"]]:
		var stream: AudioStream = (load("res://assets/audio/level01/%s.mp3" % entry[1]) as AudioStream).duplicate()
		if entry[3] and stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.volume_db = entry[2]
		player.bus = entry[4] if AudioServer.get_bus_index(entry[4]) >= 0 else &"Master"
		add_child(player)
		sounds[entry[0]] = player
		if entry[3]:
			player.play()

# Rain on the open ground; the flock's wings, the strike, the cloth of getting up.
func _tick_sounds(delta: float, near: bool) -> void:
	var camera_x: float = level.camera_x
	var target := lerpf(-80.0, -19.0, weather(camera_x)) if near else -80.0
	if near:target-=Crevice.enclosure(level.player.position.x+13)*9.0
	var rain: AudioStreamPlayer = sounds["rain"]
	rain.volume_db = move_toward(rain.volume_db, target, delta * 30.0)
	if flock_on and previous_flock < 0.0:
		(sounds["wings"] as AudioStreamPlayer).play()
		(sounds["colony"] as AudioStreamPlayer).play()
	if flock_on and previous_flock < 0.28 and flock_time >= 0.28:
		(sounds["whoosh"] as AudioStreamPlayer).play()
	if cut == Cut.KNOCK and previous_cut != Cut.KNOCK:
		(sounds["impact"] as AudioStreamPlayer).play()
	if cut == Cut.GETUP and previous_cut != Cut.GETUP:
		(sounds["cloth"] as AudioStreamPlayer).play()
	previous_cut = cut
	previous_flock = flock_time if flock_on else -1.0

func _tick_cut(delta: float, feet_x: float) -> void:
	if flock_on:
		flock_time += delta
	if cut == Cut.PANT or cut == Cut.FLOCK:
		breath_time += delta
	match cut:
		Cut.NONE:
			# (only once he is on his feet and on the ground: not in the middle of a jump over something)
			if intro_time >= LIE_TIME + GET_UP_TIME and not low_stance.active() and feet_x >= AUTO_X and feet_x < PANT_X and level.player.is_on_floor():
				cut = Cut.WALK
				cut_time = 0.0
				walk_feet_x = feet_x
		Cut.WALK:
			cut_time += delta
			if feet_x >= PANT_X:
				cut = Cut.STOP
				cut_time = 0.0
		Cut.STOP:
			cut_time += delta
			if cut_time >= STOP_TIME:
				cut = Cut.PANT
				cut_time = 0.0
				breath_time = 0.0
		Cut.PANT:
			cut_time += delta
			if cut_time >= PANT_TIME:
				cut = Cut.FLOCK
				cut_time = 0.0
				flock_on = true
				flock_time = 0.0
		Cut.FLOCK:
			cut_time += delta
			if cut_time >= FLOCK_IMPACT_TIME:
				cut = Cut.KNOCK
				cut_time = 0.0
		Cut.KNOCK:
			cut_time += delta
			if cut_time >= KNOCK_TIME:
				cut = Cut.DOWNED
				cut_time = 0.0
		Cut.DOWNED:
			cut_time += delta
			if cut_time >= DOWNED_TIME:
				cut = Cut.GETUP
				cut_time = 0.0
		Cut.GETUP:
			cut_time += delta
			if cut_time >= GETUP_TIME:
				cut = Cut.DONE
				cut_time = 0.0
		Cut.DONE:
			cut_time += delta
			if HUNTER_ON and cut_time >= FREE_TIME:
				cut = Cut.SLAM_OMEN
				cut_time = 0.0
				slam_x = feet_x
		Cut.SLAM_OMEN:
			cut_time += delta
			# the shadow follows him (the hand always finds him), and stops following just before it comes down
			if cut_time < SLAM_OMEN_TIME - SLAM_LOCK_TIME:
				slam_x = lerpf(slam_x, feet_x, 1.0 - exp(-delta * 5.0))
			else:
				slam_x = lerpf(slam_x, feet_x, 1.0 - exp(-delta * 1.2))
			if cut_time >= SLAM_OMEN_TIME:
				cut = Cut.SLAM
				cut_time = 0.0
				slam_time = 0.0
				_do_slam(feet_x)
		Cut.SLAM:
			cut_time += delta
			slam_time += delta
	if flock_on and flock_time > FLOCK_VISUAL_TIME + 0.2:
		flock_on = false

func _do_slam(feet_x: float) -> void:
	var edge_x_now := minf(slam_x, feet_x) - SLAM_BACK
	break_edge(edge_x_now)
	hunter.impact_time = 0.0
	hunter.hand_impact()
	if level.marsh_hit_time <= 0.0:
		level._start_marsh_hit("pit", Vector2(feet_x, GROUND_Y))
		level.player.velocity = Vector2(0.0, 60.0)

# The hand's shadow and how far down it is (for the art): shadow 0..1, down 0..1, lift 0..1 (gone)
func slam_info() -> Dictionary:
	if cut == Cut.SLAM_OMEN:
		var shadow := smoothstep(0.0, SLAM_OMEN_TIME * 0.8, cut_time)
		var down := clampf((cut_time - (SLAM_OMEN_TIME - SLAM_FALL_TIME)) / SLAM_FALL_TIME, 0.0, 1.0)
		return {"x": slam_x, "shadow": shadow, "down": down * down, "lift": 0.0}
	if cut == Cut.SLAM:
		return {"x": slam_x, "shadow": 1.0 - smoothstep(0.3, 1.0, slam_time), "down": 1.0, "lift": smoothstep(1.0, 1.9, slam_time)}
	return {"x": slam_x, "shadow": 0.0, "down": 0.0, "lift": 1.0}

# The computer walks him (the controller turns the stick to the right and takes the speed from here).
func auto_walking() -> bool:
	return cut == Cut.WALK

# His speed on the way: the stride shortens as he runs out of breath.
func auto_speed(feet_x: float) -> float:
	var u := clampf((feet_x - walk_feet_x) / maxf(PANT_X - walk_feet_x, 1.0), 0.0, 1.0)
	return lerpf(WALK_SPEED_FROM, WALK_SPEED_TO, smoothstep(0.0, 1.0, u))

# No jumping while the cliff is in control (or while he walks and bends over).
func locks_jump() -> bool:
	if low_stance!=null and low_stance.active():return true
	if tripping():return true
	if predator!=null and predator.enabled and predator.locks_move():return true
	return cut != Cut.NONE and cut != Cut.DONE and cut != Cut.SLAM_OMEN

# The flock is up (its clock, for the art and the sound); -1 when it is not.
func flock_clock() -> float:
	return flock_time if flock_on else -1.0

# 0..1: the wind of the flock (the grass, the dust, the rain lean over).
func gust() -> float:
	if not flock_on:
		return 0.0
	return clampf(smoothstep(0.12, 0.42, flock_time) * (1.0 - smoothstep(0.92, 1.72, flock_time)), 0.0, 1.0)

# Camera shake: a tremor as they come up, a jolt as they strike (level 1's).
func shake() -> float:
	if not flock_on:
		return maxf(hunter.shake() if hunter != null else 0.0, slam_tremor())
	var emergence := smoothstep(0.06, 0.20, flock_time) * (1.0 - smoothstep(0.66, FLOCK_IMPACT_TIME, flock_time))
	var age := maxf(0.0, flock_time - FLOCK_IMPACT_TIME)
	var impact := exp(-7.5 * age) * (1.0 - smoothstep(0.0, 0.56, age)) if flock_time >= FLOCK_IMPACT_TIME else 0.0
	return maxf(0.75 * emergence + 2.85 * impact, hunter.shake() if hunter != null else 0.0)

# the hand's tremor while the shadow grows
func slam_tremor() -> float:
	return 0.6 * smoothstep(0.2, SLAM_OMEN_TIME, cut_time) if cut == Cut.SLAM_OMEN else 0.0

func locks_move() -> bool:
	if low_stance!=null and low_stance.locks_translation():return true
	if tripping():return true
	if predator!=null and predator.enabled and predator.locks_move():return true
	if level.player.position.x >= -300.0:
		return false
	if cut >= Cut.STOP and cut <= Cut.GETUP:
		return true
	return intro_time < LIE_TIME + GET_UP_TIME

# What he does while lying and getting up: {action, progress}
func pose_info() -> Dictionary:
	if tripping():
		if trip_time<TRIP_FALL_TIME:return {"action":&"fall_impact","progress":trip_time/TRIP_FALL_TIME}
		if trip_time<TRIP_FALL_TIME+TRIP_DOWN_TIME:return {"action":&"downed","progress":(trip_time-TRIP_FALL_TIME)/TRIP_DOWN_TIME}
		return {"action":&"get_up","progress":clampf((trip_time-TRIP_FALL_TIME-TRIP_DOWN_TIME)/TRIP_GET_UP_TIME,0,1)}
	if predator!=null and predator.enabled and predator.pose_info().action!=&"none":return predator.pose_info()
	if low_stance!=null and low_stance.active():return low_stance.pose_info()
	if level != null and level.player.position.x < -300.0:
		match cut:
			Cut.STOP:
				return {"action": &"tired_stop", "progress": clampf(cut_time / STOP_TIME, 0.0, 1.0)}
			Cut.PANT, Cut.FLOCK:
				return {"action": &"pant", "progress": fposmod(breath_time / BREATH_TIME, 1.0)}
			Cut.KNOCK:
				return {"action": &"knockdown", "progress": clampf(cut_time / KNOCK_TIME, 0.0, 1.0)}
			Cut.DOWNED:
				return {"action": &"downed", "progress": clampf(cut_time / DOWNED_TIME, 0.0, 1.0)}
			Cut.GETUP:
				return {"action": &"get_up", "progress": clampf(cut_time / GETUP_TIME, 0.0, 1.0)}
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
	return level.player.position.x < -300.0 and level.player.position.y > GROUND_Y + 700.0 and level.marsh_hit_time <= 0.0
