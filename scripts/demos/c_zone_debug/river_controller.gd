extends Node2D

const Art = preload("res://scripts/demos/c_zone_debug/river_art.gd")
const Actor = preload("res://scripts/demos/c_zone_debug/river_actor.gd")
const HoodActor = preload("res://scripts/demos/c_zone_debug/hood_river_actor.gd")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ScreenIris = preload("res://scripts/shared/screen_iris.gd")
const Pose = preload("res://scripts/actors/actor_pose_state.gd")
const Fan = preload("res://scripts/demos/c_zone_debug/fan_art.gd")
const Swing = preload("res://scripts/demos/c_zone_debug/fan_swing_manifest.gd")
const Drown = preload("res://scripts/demos/c_zone_debug/drown_manifest.gd")
const MarshArt = preload("res://scripts/demos/c_zone_debug/marsh_art.gd")
const SmallItem = preload("res://scripts/actors/small_item_renderer.gd")
const CliffAct = preload("res://scripts/demos/c_zone_debug/cliff_act.gd")
const CliffArt = preload("res://scripts/demos/c_zone_debug/cliff_art.gd")
const HoodManifest = preload("res://scripts/actors/hood_actor_manifest.gd")

const WORLD_WIDTH := 7520.0
const PLAYER_SIZE := Vector2(26, 54)
const ACTOR_VISUAL_SCALE := 0.90
const CRATE_SIZE := Vector2(144, 32)
const CRATE_START := Vector2(422, 518)
const FAN_SPOT := Vector2(495, 292)
const RACK_RECT := Rect2(363, 414, 209, 10)
const WATER_Y := 575.0
const GRIP_REACH := 22.5
const CRATE_CONTACT_INSET := 5.0
const GRIP_TIME := 16.0 / 24.0
const RELEASE_TIME := 14.0 / 24.0
const FAN_HANDOFF_TIME := 8.0 / 26.0
# The hooded boy's fan clips are longer: he is locked for the first part of the pick-up / put-down (the rest of the clip
# plays on when he is let go), and the swing takes the full clip with the wind coming at the power stroke.
const HOOD_FAN_LOCK_TIME := 1.0
# The boat (hooded boy): pushing, his hands are on the hull; pulling, he takes up the rope tied to the near end and stands
# back from the boat by ROPE_EXTRA so there is rope between his hands and the hull.
const ROPE_EXTRA := 34.0
# Pulling starts with taking the rope up: he lets go of the hull, crouches to the rope's end at the foot of the post,
# stands up with it in his hand and only then pulls (the boat does not move until he has it).
const ROPE_PICK_TIME := 1.10
const ROPE_LET_GO_TIME := 0.40  # the first part of the pick-up: the hands leaving the hull (skipped when the pull was meant from the start)
# A 24 px stone looks like a boulder next to the small hooded boy: for him every stone (lying, in the hand, flying) is
# drawn at this share of its size, so it is the same stone all the way.
const HOOD_STONE_SCALE := 0.8
const ROPE_INK := Color("050606")
const HOOD_FAN_SWING_TIME := 98.0 / 60.0
const HOOD_FAN_WIND_DELAY := 0.70
const FAN_SCALE := 0.65
const SLIDE_STOP_X := 1240.0
const RETURN_SLIDE_STOP_X := 1830.0
const PUZZLE_BOX_SIZE := Vector2(102.0, 94.0)
const PUZZLE_BOX_START := Vector2(2950.0, 336.0)
const PUZZLE_BOX_BOUNDS := Vector2(2855.0, 3180.0)
const PUZZLE_BOX_GRIP_REACH := 25.0
# The raft ends pressed flush against the ledge face: no gap, one step up.
const RAFT_FLUSH_X := 2636.0
const SECOND_ACT_LEDGE := Rect2(2780.0, 430.0, 552.0, 320.0)
const ROOT_PLATFORM := Rect2(3296.0, 250.0, 118.0, 14.0)
const FIRE_DECK := Rect2(4620.0, 432.0, 80.0, 14.0)
const HANG_DECK := Rect2(5180.0, 392.0, 90.0, 14.0)
const SLAB_DECK := Rect2(5360.0, 470.0, 130.0, 16.0)
# Two crumbling spires in a row. Each starts to give way the moment it is stepped on, and when one
# collapses it shakes the next loose, so the player has to keep moving.
const FRAGILE_CAPS: Array[Rect2] = [
	Rect2(5545.0, 450.0, 66.0, 24.0),
	Rect2(5666.0, 428.0, 66.0, 24.0),
]
const FRAGILE_BREAK_TIMES: Array[float] = [0.62, 0.5]
const FRAGILE_RESPAWN_TIME := 3.2
# The rope-hung deck swings from a point above the screen and tips toward whichever side is loaded.
const HANG_ANCHOR_Y := -60.0
const HANG_TILT_MAX := 0.26
const SWING_ANCHOR := Vector2(3590.0, 92.0)
const SWING_SIZE := Vector2(84.0, 16.0)
const SWING_ROPE_LENGTH := 190.0
const SWING_PERIOD := 3.05
const SWING_MAX_ANGLE := 0.5585
const MARSH_EXIT_X := 5930.0
const MARSH_SAVE_X := 4452.0
# Respawn points inside the second act, so that a death there never sends the player back across the
# river (where the leaf is gone and the raft has to be hauled to the ledge again): the start of the
# ledge, and the foot of the hill where the stones fall. Dying on the hill puts the player back at its
# foot with the first stone still to come.
const ACTOR_EDGE_SOFTNESS := 1.3
const STONE_SEAT_DEPTH := 4.5
const MARSH_LEDGE_SAVE_X := 2840.0
const MARSH_HILL_SAVE_X := 3800.0
const MARSH_FALL_Y := 585.0
# Separate gas pockets. Solid land lies between them, so the hazard never reads as one pool.
const MARSH_PITS: Array[Vector2] = [
	Vector2(3332.0, 3730.0), Vector2(4520.0, 4780.0), Vector2(5090.0, 5780.0),
	# Act three: the gap the drawbridge spans.
	Vector2(6150.0, 6410.0),
]
const CHECKPOINT_BANK_X := 5900.0
const MARSH_VENT_BASE_Y := 560.0
# Cliff faces lean inward with depth, so every island of land reads as a rock outcrop.
const LAND_FACE_DEPTH: Array[float] = [0.0, 16.0, 40.0, 76.0, 126.0, 200.0, 310.0, 470.0]
const LAND_FACE_INSET: Array[float] = [0.0, 0.0, 3.0, 9.0, 22.0, 40.0, 64.0, 92.0]
const MARSH_GAS_RECTS: Array[Rect2] = [
	Rect2(4722.0, 330.0, 36.0, 300.0),
	Rect2(5297.0, 300.0, 36.0, 320.0),
	Rect2(5499.0, 310.0, 36.0, 310.0),
	Rect2(5738.0, 320.0, 36.0, 300.0),
]
const MARSH_FIRE_RECTS: Array[Rect2] = [
	Rect2(4646.0, 388.0, 28.0, 44.0),
]
# Boulders fall out of the sky: the first one smashes through the long limb above the hill,
# the rest follow in quick succession, land on the crown and roll down either side.
const MARSH_ROCK_SPECS: Array[Dictionary] = [
	{"x": 4244.0, "radius": 35.0, "delay": 0.0, "dir": -1.0, "repeat": 1.9},
	{"x": 4296.0, "radius": 31.0, "delay": 1.9, "dir": 1.0, "repeat": 2.1},
	{"x": 4226.0, "radius": 38.0, "delay": 3.5, "dir": -1.0, "repeat": 2.3},
]
const ROCK_START_Y := -150.0
const ROCK_RUMBLE_FROM := 3880.0
const ROCK_TRIGGER_X := 4060.0
const LIMB_BREAK_X := 4252.0
const LIMB_BREAK_Y := 98.0
enum { ROCK_WAIT, ROCK_WARN, ROCK_FALL, ROCK_ROLL, ROCK_DROP }
const ROCK_WARN_TIME := 0.3
const ROCK_MAX_SPEED := 215.0
const ROCK_SHOVE_SPEED := 86.0
const ROCK_RESIST_SPEED := 34.0  # holding the key against the stone: it grinds forward this slowly instead (still forward)
const ROCK_RESIST_RAMP := 0.15  # s to dig in

@export var return_to_debug_menu := false
var hosted_in_level := false
var cinematic_entry := false
var LEFT_PROFILE := PackedVector2Array([
	Vector2(-120, 320), Vector2(5, 365), Vector2(225, 550),
	Vector2(1090, 550), Vector2(1180, 584), Vector2(1270, 630),
	Vector2(1350, 850), Vector2(-120, 850)
])
var RIGHT_PROFILE := PackedVector2Array([
	Vector2(1880, 850), Vector2(1950, 625), Vector2(2110, 550),
	Vector2(2800, 550), Vector2(2800, 850)
])
# Top contours of every solid piece of land in the second act. Collision and art share them.
var MARSH_LANDS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(2780, 430), Vector2(3300, 430), Vector2(3332, 446)]),
	# The hill: a long, gentle approach to walk up, then a steeper crown the boulders roll off.
	PackedVector2Array([
		Vector2(3730, 436), Vector2(3790, 434), Vector2(3850, 431), Vector2(3910, 426),
		Vector2(3970, 420), Vector2(4030, 412), Vector2(4090, 400), Vector2(4150, 384),
		Vector2(4200, 370), Vector2(4240, 364), Vector2(4290, 364), Vector2(4340, 374),
		Vector2(4390, 394), Vector2(4440, 418), Vector2(4490, 440), Vector2(4520, 452),
	]),
	PackedVector2Array([
		Vector2(4780, 454), Vector2(4820, 446), Vector2(4870, 438), Vector2(4920, 442),
		Vector2(4970, 452), Vector2(5020, 450), Vector2(5060, 454), Vector2(5090, 466),
	]),
	PackedVector2Array([
		Vector2(5780, 414), Vector2(5830, 406), Vector2(5890, 396), Vector2(5960, 398),
		Vector2(6030, 404), Vector2(6110, 398), Vector2(6150, 394),
	]),
	# Act three, far bank: stones, the gallows tree and the foot of the cliff with its lift.
	PackedVector2Array([
		Vector2(6410, 392), Vector2(6470, 390), Vector2(6560, 394), Vector2(6650, 398),
		Vector2(6740, 396), Vector2(6830, 392), Vector2(6910, 391), Vector2(7000, 390), Vector2(7100, 390),
	]),
]

var player: CharacterBody2D
var crate: CharacterBody2D
var crate_shape: CollisionShape2D
var crate_tilt := 0.0
var float_time := 0.0
var launching := false
var launch_direction := 1.0
var float_direction := 1.0
var entry_brake := false
var beached := false
var load_sink := 0.0
var sink_speed := 0.0
var load_rock := 0.0
var marsh_rocks: Array[Dictionary] = []
var rock_sequence := false
var rock_rumble := 0.0
var rock_first_delay := 0.5
var limb_broken := false
var limb_time := 0.0
var camera_shake := 0.0
var rock_landings := 0
var rock_lock_time := 0.0
var camera_look := 0.0
var rock_shove_index := -1
var rock_immune := 0.0
var rock_push_vx := 0.0
var rock_push_cap := ROCK_SHOVE_SPEED
var rock_resist := 0.0  # 0..1: how hard he is bracing against the stone
var rock_speed := 0.0
var actor: Node2D
var legacy_actor: Node2D
var hood_actor: Node2D
var fan: Node2D
var art: Node2D
var marsh_art: Node2D
var cliff: Node2D
var stone_nodes: Array[Node2D] = []
var stone_scales: Array[float] = []
var fade_rect: ColorRect
var camera: Camera2D
var puzzle_box: CharacterBody2D
var swing_body: AnimatableBody2D
var pose = Pose.new()
var clock := 0.0
var camera_x := 0.0
var camera_y := 0.0
var facing := 1.0
var fan_owned := false
var fan_revealed := false
var fan_on_tree := true
var airborne_pickup := false
var fan_handoff_rotation := 1.35
var floating := false
var dragging := false
var puzzle_box_dragging := false
var grip_time := 0.0
var release_time := 0.0
var grip_distance := 0.0
var crate_motion := 0.0
var puzzle_box_motion := 0.0
var landed := false # Progress only; returning to the river must still allow buoyancy.
var completed := false
var paused := false
var intro_time := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var jump_windup_left := 0.0  # the hooded boy gathers for a jump on the ground for HOOD_JUMP_WINDUP before he leaves it
var fan_cooldown := 0.0
# The hooded boy's failures fade to black after his fall / drowning / knock-down has played, and the checkpoint fades in
# (the previous actor cuts straight to the checkpoint).
const CURTAIN_CLOSE := 0.55
const CURTAIN_OPEN := 0.80
var curtain_phase := 0  # 0 none, 1 closing, 2 opening
var curtain_time := 0.0
var iris: CanvasLayer
var rope_stage := 0  # 0 hands on the hull, 1 taking the rope up, 2 rope in his hands
var rope_pick_time := 0.0
var rope_direct := false  # F then the key away from the boat: no hands on the hull first, straight to the rope
var rope_hold := 0.0  # 0..1: how much of the rope is lifted off the ground into his hand
var rope_mode := false  # pulling (moving away from the boat) with the rope in his hands
var rope_extra := 0.0  # px he stands back from the hull while he holds the rope
var grip_is_crate := false  # the object he grips is the boat (the rope belongs to it), not the broken box
var rope_side := 0.0  # which end of the boat the rope he holds is tied to
var rope_art: Node2D
var fan_warmup := 6
var fan_swing := 0.0
var fan_swing_total := Swing.DURATION
var fan_wind_delay := -1.0
var pickup_total := FAN_HANDOFF_TIME
var put_down_total := FAN_HANDOFF_TIME
var pickup_time := 0.0
var put_down_time := 0.0
var pending_grab := false
# The hooded boy takes hold of the boat only when he knows which way: F beside it does nothing yet, the next direction key decides
# (towards the boat: push; away from it: pull, which starts with the rope). Raising his arms for a push and then bending to the
# rope for a pull contradicted itself.
var grip_pending := false
var fan_ground_position := FAN_SPOT
var fan_on_raft := false
# Set once the leaf has been left at the second act's ledge: it stays lying there, cannot be taken
# again, and the next death puts it back on its tree.
var fan_left_behind := false
var marsh_save := 0
var fan_raft_local := Vector2.ZERO
var fan_ground_facing := 1.0
var fan_handoff_origin := Vector2.ZERO
var death_time := 0.0
var marsh_hit_time := 0.0
var marsh_hit_kind := ""
var fragile: Array[Dictionary] = []
var hang_body: AnimatableBody2D
var hang_sway := 0.0
var hang_sway_speed := 0.0
var hang_tilt := 0.0
var hang_tilt_speed := 0.0
var hang_player_on := false
var checkpoint := 0
var debug_return_index := 4
var checkpoint_fan := false
var wind_impulses := 0
var crate_wet := false
var player_wet := false
var debug_visible := false
var debug_label: Label
var pause_panel: Control
var sound: AudioStreamPlayer

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("979797"))
	_create_ground(LEFT_PROFILE)
	_create_ground(RIGHT_PROFILE)
	_reset_marsh_rocks()
	for land_index in range(MARSH_LANDS.size()):
		_create_land(MARSH_LANDS[land_index], land_index == 0)
	for deck in [ROOT_PLATFORM, FIRE_DECK, SLAB_DECK]:
		_create_static_rect(deck)
	_create_hang_deck()
	_create_fragile_platforms()
	_create_rack_platform()
	crate = _body(CRATE_SIZE, 2, 1)
	crate_shape = crate.get_child(0)
	crate.floor_snap_length = 16.0
	puzzle_box = _body(PUZZLE_BOX_SIZE, 2, 1)
	puzzle_box.floor_snap_length = 12.0
	player = _body(PLAYER_SIZE, 4, 11)
	var player_shape := CapsuleShape2D.new()
	player_shape.radius = PLAYER_SIZE.x * 0.5
	player_shape.height = PLAYER_SIZE.y
	(player.get_child(0) as CollisionShape2D).shape = player_shape
	player.floor_snap_length = 12.0
	player.floor_max_angle = deg_to_rad(48.0)
	player.platform_floor_layers = 1
	_create_swing()
	cliff = CliffAct.new()
	cliff.level = self
	cliff.finished_act.connect(_act_finished)
	add_child(cliff)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	art = Art.new()
	art.level = self
	add_child(art)
	marsh_art = MarshArt.new()
	marsh_art.level = self
	add_child(marsh_art)
	legacy_actor = Actor.new()
	legacy_actor.z_index = 5
	add_child(legacy_actor)
	hood_actor = HoodActor.new()
	hood_actor.z_index = 5
	add_child(hood_actor)
	hood_actor.hide()
	actor = legacy_actor
	rope_art = Node2D.new()
	rope_art.z_index = 4
	rope_art.draw.connect(_draw_ropes)
	add_child(rope_art)
	fan = Fan.new()
	fan.z_index = 6
	add_child(fan)
	# Stones are drawn with the very renderer the hand-held item uses, so a stone on the ground, in
	# the air and in the hand is the same stone.
	for _index in range(cliff.stones.size()):
		var stone_node: Node2D = SmallItem.new()
		stone_node.call("configure", &"ink_stone", CliffAct.STONE_VISUAL_RADIUS)
		add_child(stone_node)
		stone_nodes.append(stone_node)
		stone_scales.append(1.0)
	_create_ui()
	sound = AudioStreamPlayer.new()
	var ambience = load("res://assets/audio/level01/ambience_wind.mp3").duplicate()
	ambience.loop = true
	sound.stream = ambience
	sound.volume_db = -29.0
	add_child(sound)
	sound.play()
	reset_all()

func _body(size: Vector2, layer: int, mask: int) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = layer
	body.collision_mask = mask
	body.safe_margin = 0.08
	body.platform_floor_layers = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.position = size * 0.5
	body.add_child(shape)
	add_child(body)
	return body

func _create_ground(points: PackedVector2Array) -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	ground.add_child(shape)
	add_child(ground)

func _create_land(profile: PackedVector2Array, vertical_left: bool) -> void:
	var points := profile.duplicate()
	var first: Vector2 = profile[0]
	var last: Vector2 = profile[profile.size() - 1]
	# Depth 0 coincides with the contour's own end points, so it is skipped on both sides.
	for k in range(1, LAND_FACE_DEPTH.size()):
		points.append(Vector2(last.x - LAND_FACE_INSET[k], last.y + LAND_FACE_DEPTH[k]))
	for k in range(LAND_FACE_DEPTH.size() - 1, 0, -1):
		var inset := 0.0 if vertical_left else LAND_FACE_INSET[k]
		points.append(Vector2(first.x + inset, first.y + LAND_FACE_DEPTH[k]))
	_create_ground(points)

func _create_fragile_platforms() -> void:
	fragile.clear()
	for index in range(FRAGILE_CAPS.size()):
		var rect: Rect2 = FRAGILE_CAPS[index]
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		shape.position = rect.get_center()
		body.add_child(shape)
		add_child(body)
		fragile.append({"rect": rect, "body": body, "shape": shape, "phase": 0, "time": 10.0, "break": FRAGILE_BREAK_TIMES[index]})

func _create_hang_deck() -> void:
	hang_body = AnimatableBody2D.new()
	hang_body.collision_layer = 1
	hang_body.collision_mask = 0
	hang_body.sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = HANG_DECK.size
	shape.shape = rectangle
	hang_body.add_child(shape)
	add_child(hang_body)
	_reset_hang_deck()

func _create_static_rect(rect: Rect2) -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.get_center()
	ground.add_child(shape)
	add_child(ground)

func _create_swing() -> void:
	swing_body = AnimatableBody2D.new()
	swing_body.collision_layer = 1
	swing_body.collision_mask = 0
	swing_body.sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = SWING_SIZE
	shape.shape = rectangle
	shape.position = SWING_SIZE * 0.5
	swing_body.add_child(shape)
	add_child(swing_body)
	_update_swing()

func _create_rack_platform() -> void:
	var rack := StaticBody2D.new()
	rack.collision_layer = 8
	rack.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = RACK_RECT.size
	shape.shape = rectangle
	shape.position = RACK_RECT.get_center()
	shape.one_way_collision = true
	shape.one_way_collision_margin = 3.0
	rack.add_child(shape)
	add_child(rack)

func reset_all() -> void:
	checkpoint = 0
	checkpoint_fan = false
	fan_left_behind = false
	marsh_save = 0
	fan_owned = false
	fan_revealed = true
	landed = false
	completed = false
	wind_impulses = 0
	clock = 0.0
	restore_checkpoint()
	player.position = Vector2(CRATE_START.x + CRATE_SIZE.x + 42.0, 445)
	intro_time = 0.38

func debug_enter_marsh_act() -> void:
	checkpoint = 2
	checkpoint_fan = false
	fan_left_behind = true
	marsh_save = 1
	restore_checkpoint()
	player.position = Vector2(2870.0, SECOND_ACT_LEDGE.position.y - PLAYER_SIZE.y)
	player.velocity = Vector2.ZERO
	crate.position = Vector2(RAFT_FLUSH_X, CRATE_START.y)
	crate.velocity = Vector2.ZERO
	puzzle_box.position = PUZZLE_BOX_START
	puzzle_box.velocity = Vector2.ZERO
	fan_owned = false
	fan_on_tree = false
	fan_revealed = false
	landed = true
	beached = true
	floating = false
	intro_time = 0.0
	camera_x = clampf(player.position.x - 525.0, 0.0, WORLD_WIDTH - 1280.0)
	camera.position = Vector2(camera_x + 640.0, 360.0)
	_present(0.0)

func restore_checkpoint() -> void:
	camera_y = 0.0
	if camera != null:
		camera.position.y = 360.0
	player.position = Vector2(590, 496)
	crate.position = CRATE_START
	if checkpoint == 1:
		player.position = Vector2(1050, 496)
		crate.position = Vector2(1100, CRATE_START.y)
	elif checkpoint == 2 and marsh_save == 2:
		# The foot of the hill: walk up and the first stone comes down again.
		player.position = Vector2(MARSH_HILL_SAVE_X - PLAYER_SIZE.x * 0.5, marsh_rock_surface_y(MARSH_HILL_SAVE_X) - PLAYER_SIZE.y - 2.0)
		crate.position = Vector2(RAFT_FLUSH_X, CRATE_START.y)
	elif checkpoint == 2 and marsh_save == 1:
		player.position = Vector2(MARSH_LEDGE_SAVE_X - PLAYER_SIZE.x * 0.5, SECOND_ACT_LEDGE.position.y - PLAYER_SIZE.y - 2.0)
		crate.position = Vector2(RAFT_FLUSH_X, CRATE_START.y)
	elif checkpoint == 2:
		player.position = Vector2(2140 + CRATE_SIZE.x + 25.0, 496)
		crate.position = Vector2(2140, CRATE_START.y)
	elif checkpoint >= 4:
		# Act three begins on the bank in front of the broken bridge.
		player.position = Vector2(CHECKPOINT_BANK_X - PLAYER_SIZE.x * 0.5, cliff._ground_y(CHECKPOINT_BANK_X) - PLAYER_SIZE.y - 2.0)
		crate.position = Vector2(RAFT_FLUSH_X, CRATE_START.y)
	elif checkpoint >= 3:
		# The mid-act save: the foot of the hill, once the falling stones are behind the player.
		player.position = Vector2(MARSH_SAVE_X - PLAYER_SIZE.x * 0.5, marsh_rock_surface_y(MARSH_SAVE_X) - PLAYER_SIZE.y - 2.0)
		crate.position = Vector2(RAFT_FLUSH_X, CRATE_START.y)
	puzzle_box.position = (
		Vector2(3150.0, SECOND_ACT_LEDGE.position.y - PUZZLE_BOX_SIZE.y)
		if checkpoint >= 3 or marsh_save == 2
		else PUZZLE_BOX_START
	)
	puzzle_box.velocity = Vector2.ZERO
	player.collision_mask = 11
	climb_time = -1.0
	climb_cooldown = 0.0
	_reset_fragile()
	_reset_hang_deck()
	_reset_marsh_rocks()
	if checkpoint >= 3:
		_clear_marsh_rocks()
	cliff.reset(checkpoint >= 4)
	rock_first_delay = 0.6
	fan_owned = checkpoint_fan
	fan_revealed = true
	fan_on_tree = not checkpoint_fan
	# A leaf left lying at the second act's ledge goes back to its tree when the player dies.
	fan_left_behind = false
	airborne_pickup = false
	fan_handoff_rotation = 1.35
	fan_ground_position = FAN_SPOT
	fan_on_raft = false
	fan_raft_local = Vector2.ZERO
	fan_ground_facing = 1.0
	put_down_time = 0.0
	pending_grab = false
	grip_pending = false
	player.velocity = Vector2.ZERO
	crate.velocity = Vector2.ZERO
	crate_tilt = 0.0
	crate_shape.rotation = 0.0
	float_time = 0.0
	launching = false
	launch_direction = -1.0 if checkpoint >= 2 else 1.0
	float_direction = launch_direction
	entry_brake = false
	beached = checkpoint >= 2
	landed = checkpoint >= 2
	completed = false
	load_sink = 0.0
	sink_speed = 0.0
	load_rock = 0.0
	rock_speed = 0.0
	floating = false
	dragging = false
	puzzle_box_dragging = false
	grip_time = 0.0
	release_time = 0.0
	grip_distance = 0.0
	crate_motion = 0.0
	puzzle_box_motion = 0.0
	actor.reset_grip_animation()
	actor.locomotion_hold_time = 0.0
	actor.support_offset = 0.0
	crate_wet = false
	player_wet = false
	art.reset_water_impacts()
	intro_time = 0.0
	death_time = 0.0
	marsh_hit_time = 0.0
	marsh_hit_kind = ""
	fan_cooldown = 0.0
	fan_swing = 0.0
	fan_wind_delay = -1.0
	pickup_time = 0.0
	coyote = 0.0
	jump_buffer = 0.0
	jump_windup_left = 0.0
	facing = 1.0
	camera_x = clampf(player.position.x - 540.0, 0.0, WORLD_WIDTH - 1280.0)
	camera.position.x = camera_x + 640.0
	_present(0.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if cinematic_entry:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			if event.shift_pressed:
				reset_all()
			else:
				restore_checkpoint()
		KEY_F1:
			debug_visible = not debug_visible
			debug_label.visible = debug_visible
		KEY_ESCAPE:
			if hosted_in_level:
				return
			if return_to_debug_menu:
				_return_to_debug()
			else:
				_set_paused(not paused)

func _return_to_debug() -> void:
	get_tree().set_meta(&"inkfall_debug_return", debug_return_index)
	var error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		get_tree().remove_meta(&"inkfall_debug_return")
		push_error("Unable to return to DEBUG: %s" % error)

func _physics_process(delta: float) -> void:
	if paused:
		return
	_update_curtain(delta)
	clock += delta
	_update_swing()
	_update_hang_deck(delta)
	cliff.tick(delta)
	_update_marsh_rocks(delta)
	grip_time = maxf(0.0, grip_time - delta)
	release_time = maxf(0.0, release_time - delta)
	fan_cooldown = maxf(0.0, fan_cooldown - delta)
	fan_swing = maxf(0.0, fan_swing - delta)
	if fan_wind_delay >= 0.0:
		fan_wind_delay -= delta
		if fan_wind_delay < 0.0:
			art.call("emit_gust", player.position + Vector2(13.0 + facing * 34.0, 14.0), facing)
			if _fan_wind_applies():
				_apply_fan_wind()
	pickup_time = maxf(0.0, pickup_time - delta)
	if pickup_time == 0.0:
		airborne_pickup = false
	if death_time > 0.0:
		death_time += delta
		if death_time > Drown.DURATION:
			_fail_restore()
		elif death_time < Drown.STRUGGLE:
			var stroke := int(death_time / Drown.STRUGGLE * Drown.PADDLE.size())
			var previous_stroke := int((death_time-delta) / Drown.STRUGGLE * Drown.PADDLE.size())
			if stroke != previous_stroke and stroke % 2 == 1 and player.position.x < SECOND_ACT_LEDGE.position.x:
				art.emit_struggle_splash(player.position.x+13.0, -1.0 if stroke % 4 == 1 else 1.0)
		_present(delta)
		return
	if marsh_hit_time > 0.0:
		_update_marsh_hit(delta)
		_update_camera(delta)
		_present(delta)
		return
	climb_cooldown = maxf(0.0, climb_cooldown - delta)
	if climb_time >= 0.0:
		_update_climb(delta)
		_update_camera(delta)
		_present(delta)
		return
	if put_down_time > 0.0:
		put_down_time = maxf(0.0,put_down_time-delta)
		if put_down_time == 0.0:
			_finish_put_down()
	var direction := 0.0 if cinematic_entry or rock_lock_time > 0.0 else Input.get_axis("move_left", "move_right")
	direction = _update_fan_walk(delta, direction)
	if direction * launch_direction <= 0.0 or Input.is_action_just_pressed("jump"):
		entry_brake = false
	if intro_time > 0.0:
		intro_time = maxf(0.0, intro_time - delta)
		direction = 1.0
		player.velocity.x = 260.0
	if not cinematic_entry:
		_update_interaction(direction)
	if player.position.x >= SECOND_ACT_LEDGE.position.x:
		_retire_fan_for_second_act()
	if (pickup_time > 0.0 and not airborne_pickup) or put_down_time > 0.0 or cliff.locks_move():
		direction = 0.0
		player.velocity.x = 0.0
	var previous_crate := crate.position
	var previous_puzzle_box := puzzle_box.position
	var previous_lowest := _lowest_crate_y()
	var previous_feet_y := player.position.y + PLAYER_SIZE.y
	var riding := is_riding()
	var rider_local := (player.position + Vector2(13,54) - crate.position - CRATE_SIZE * 0.5).rotated(-crate_tilt)
	_update_crate(delta, direction, riding)
	_update_puzzle_box(delta, direction)
	if riding:
		# Carry the contact point through translation and rotation on either bank.
		player.position = crate.position + CRATE_SIZE * 0.5 + rider_local.rotated(crate_tilt) - Vector2(13,54)
	_update_rock_shove(delta, direction)
	var impact_speed := player.velocity.y
	climb_prev_velocity = player.velocity
	_update_player(delta, direction, (crate.position.x - previous_crate.x) / delta)
	if player.is_on_floor() or is_riding():
		climb_floor_y = player.position.y + PLAYER_SIZE.y
		climb_floor_on_raft = is_riding()
	_try_begin_climb(direction)
	_update_water_contact(delta, previous_lowest, previous_feet_y)
	if floating:
		art.raft_waves(crate.position.x + CRATE_SIZE.x * 0.5, CRATE_SIZE.x * 0.5, crate.velocity.x, sink_speed, rock_speed, delta)
	elif player.is_on_floor() and player.position.y + PLAYER_SIZE.y > WATER_Y + 8.0 and absf(player.velocity.x) > 20.0 and player.position.x + 13.0 > 1156.0 and player.position.x + 13.0 < 2060.0:
		art.wade_waves(player.position.x + 13.0, player.velocity.x, delta)
	if floating and is_riding() and not riding:
		sink_speed += clampf(impact_speed * 0.09, 14.0, 48.0)
		var impact_offset := clampf((player.position.x + 13.0 - crate.position.x - CRATE_SIZE.x * 0.5) / (CRATE_SIZE.x * 0.5), -1.0, 1.0)
		rock_speed += impact_offset * 0.65
		art.emit_water_impact(player.position.x + 13.0, impact_speed * 0.45, 26.0)
	crate_motion = crate.position.x - previous_crate.x
	if not floating and absf(crate_motion) > 0.12 and crate.is_on_floor():
		# The raft's two bottom corners scrape the ground and kick up dust.
		var bottom_left := crate.position + CRATE_SIZE * 0.5 + Vector2(-CRATE_SIZE.x * 0.5 + 8.0, CRATE_SIZE.y * 0.5).rotated(crate_tilt)
		var bottom_right := crate.position + CRATE_SIZE * 0.5 + Vector2(CRATE_SIZE.x * 0.5 - 8.0, CRATE_SIZE.y * 0.5).rotated(crate_tilt)
		art.emit_drag_dust([bottom_left, bottom_right], crate_motion)
	puzzle_box_motion = puzzle_box.position.x - previous_puzzle_box.x
	if dragging:
		grip_distance += absf(crate_motion)
	elif puzzle_box_dragging:
		grip_distance += absf(puzzle_box_motion)
	if floating and checkpoint == 0:
		checkpoint = 1
		checkpoint_fan = checkpoint_fan or fan_owned
	var feet_y := player.position.y + PLAYER_SIZE.y
	var submerged := feet_y > WATER_Y + 48.0 and ground_y(player.position.x+13.0) > 659.0 and not player.is_on_floor() and not is_riding()
	var in_marsh := player.position.x >= SECOND_ACT_LEDGE.position.x - 20.0
	if in_marsh:
		if feet_y > MARSH_FALL_Y and marsh_hit_time <= 0.0:
			_start_marsh_hit("pit", player.position + PLAYER_SIZE * 0.5)
	elif feet_y > 659.0 or submerged:
		death_time = 0.001
		dragging = false
		puzzle_box_dragging = false
		entry_brake = false
		fan_swing = 0.0
		fan_wind_delay = -1.0
		release_time = 0.0
		pickup_time = 0.0
		put_down_time = 0.0
		pending_grab = false
		grip_pending = false
		player.velocity = Vector2.ZERO
	if crate.position.x > 2115.0 and player.position.x > 2100.0 and player.is_on_floor():
		checkpoint = maxi(checkpoint, 2)
		checkpoint_fan = checkpoint_fan or fan_owned
		landed = true
	elif crate.position.x < 1000.0 and player.position.x < 1090.0 and player.is_on_floor() and checkpoint > 0:
		checkpoint = 1
		checkpoint_fan = checkpoint_fan or fan_owned
	_update_marsh_checkpoint()
	_update_fragile(delta)
	_check_fall_and_crush()
	_check_marsh_hazards()
	_update_camera(delta)
	_present(delta)

func _update_camera(delta: float) -> void:
	var target_camera := clampf(player.position.x - 525.0, 0.0, WORLD_WIDTH - 1280.0)
	camera_x = lerpf(camera_x, target_camera, 1.0 - exp(-delta * 3.8))
	camera.position.x = camera_x + 640.0
	# Up the cliff the camera climbs with the player; everywhere else it holds level.
	var target_y := minf(0.0, player.position.y - 300.0) if player.position.x > 6850.0 else 0.0
	camera_y = lerpf(camera_y, target_y, 1.0 - exp(-delta * 4.0))
	camera.position.y = 360.0 + camera_y
	camera_look = move_toward(camera_look, -18.0 if rock_lock_time > 0.0 else 0.0, delta * 60.0)
	camera.offset = Vector2(sin(clock * 41.0), cos(clock * 53.0) * 0.6) * camera_shake + Vector2(0.0, camera_look)

func is_riding() -> bool:
	var feet := player.position + Vector2(13, 54)
	var center := crate.position + CRATE_SIZE * 0.5
	var top_center_x := center.x + sin(crate_tilt) * CRATE_SIZE.y * 0.5
	var half_width := cos(crate_tilt) * CRATE_SIZE.x * 0.5
	return absf(feet.y - crate_top_at(feet.x)) < 12.0 and absf(feet.x - top_center_x) < half_width + 3.0 and player.velocity.y >= -2.0

func crate_top_at(world_x: float) -> float:
	var center := crate.position + CRATE_SIZE * 0.5
	return center.y + (world_x - center.x) * tan(crate_tilt) - CRATE_SIZE.y * 0.5 / cos(crate_tilt)

func can_grab() -> bool:
	var p := player.position + PLAYER_SIZE * 0.5
	var c := crate.position + CRATE_SIZE * 0.5
	var side := signf(p.x - c.x)
	var contact := crate_side_contact(side)
	var side_gap := (p.x - contact.x) * side
	return side != 0.0 and side_gap >= 4.0 and side_gap < GRIP_REACH + 24.0 + rope_extra and absf(player.position.y + 36.0 - contact.y) < 48.0 and not is_riding() and player.is_on_floor() and not launching and (not floating or can_pull_floating())

# A raft that has just slid into the water is still beside the bank it left. From there it can be
# pulled back to the shore, so pushing it in without the leaf is never a dead end. Once it has drifted
# out into the river (a wind stroke, or anything past a short way from the shore) it can't be.
func can_pull_floating() -> bool:
	if not floating or beached:
		return false
	var near_left := crate.position.x < SLIDE_STOP_X + 60.0
	var near_right := crate.position.x > RETURN_SLIDE_STOP_X - 60.0
	return (near_left or near_right) and (dragging or absf(crate.velocity.x) < 30.0)

func crate_side_contact(side: float) -> Vector2:
	return crate.position + CRATE_SIZE * 0.5 + Vector2(side * (CRATE_SIZE.x * 0.5 - CRATE_CONTACT_INSET), CRATE_SIZE.y * 0.5 - 18.0).rotated(crate_tilt)

func _release_grip() -> void:
	if dragging:
		release_time = RELEASE_TIME
	dragging = false
	grip_time = 0.0

func grip_target_x() -> float:
	return crate_side_contact(-facing).x - facing * (GRIP_REACH + rope_extra) - PLAYER_SIZE.x * 0.5

func can_grab_puzzle_box() -> bool:
	if puzzle_box == null or not player.is_on_floor() or player.position.x < SECOND_ACT_LEDGE.position.x - 40.0:
		return false
	var player_center := player.position + PLAYER_SIZE * 0.5
	var box_center := puzzle_box.position + PUZZLE_BOX_SIZE * 0.5
	var side := signf(player_center.x - box_center.x)
	if is_zero_approx(side):
		return false
	var contact_x := box_center.x + side * PUZZLE_BOX_SIZE.x * 0.5
	var side_gap := (player_center.x - contact_x) * side
	return (
		side_gap >= 2.0
		and side_gap < PUZZLE_BOX_GRIP_REACH + 23.0
		and absf(player.position.y + 36.0 - (puzzle_box.position.y + 49.0)) < 48.0
	)

func _begin_puzzle_box_grip() -> void:
	grip_is_crate = false
	puzzle_box_dragging = true
	dragging = false
	grip_time = GRIP_TIME
	release_time = 0.0
	grip_distance = 0.0
	facing = signf(puzzle_box.position.x + PUZZLE_BOX_SIZE.x * 0.5 - player.position.x - PLAYER_SIZE.x * 0.5)

func _release_puzzle_box_grip() -> void:
	if puzzle_box_dragging:
		release_time = RELEASE_TIME
	puzzle_box_dragging = false
	grip_time = 0.0

func puzzle_box_grip_target_x() -> float:
	var contact_x := puzzle_box.position.x + PUZZLE_BOX_SIZE.x * 0.5 - facing * PUZZLE_BOX_SIZE.x * 0.5
	return contact_x - facing * PUZZLE_BOX_GRIP_REACH - PLAYER_SIZE.x * 0.5

func fan_rest_position() -> Vector2:
	if fan_on_tree:
		return FAN_SPOT
	if fan_on_raft:
		return crate.position + CRATE_SIZE * 0.5 + fan_raft_local.rotated(crate_tilt)
	return fan_ground_position

# The hooded boy picks the fan up by its handle with the blade pointing away from him, the way the clip was filmed. So he
# first walks to the handle end, whichever side of the fan he came from, and then bends down (the fan never has to turn
# round on the ground).
const FAN_HANDLE_REACH := 11.5  # px from his centre to where the hand meets the handle
const FAN_WALK_TIMEOUT := 1.2
var fan_walk_target := INF
var refloat_keeps_speed := false
var fan_walk_time := 0.0

func _fan_pickup_stand_x() -> float:
	return fan_rest_position().x - fan_ground_facing * FAN_HANDLE_REACH

func _fan_pickup_needs_walk() -> bool:
	return ActorStyleHost.style_override == Pose.STYLE_HOOD and not fan_on_tree and (player.is_on_floor() or is_riding()) and absf(player.position.x + 13.0 - _fan_pickup_stand_x()) > 10.0

func _update_fan_walk(delta: float, direction: float) -> float:
	if fan_walk_target == INF:
		return direction
	fan_walk_time += delta
	var remaining := fan_walk_target - (player.position.x + 13.0)
	var cancelled := Input.is_action_just_pressed("jump") or death_time > 0.0 or marsh_hit_time > 0.0 or not can_pick_up_fan() and absf(remaining) > 90.0
	if cancelled or fan_walk_time > FAN_WALK_TIMEOUT:
		fan_walk_target = INF
		return direction
	if absf(remaining) <= 4.0:
		fan_walk_target = INF
		if can_pick_up_fan():
			_begin_fan_pickup(fan_ground_facing)
		return 0.0
	return signf(remaining)

func _begin_fan_pickup(face_override: float) -> void:
	fan_handoff_origin = fan_rest_position()
	fan_handoff_rotation = art.fan_pickup.rotation
	airborne_pickup = fan_on_tree
	fan_on_tree = false
	var toward := signf(fan_handoff_origin.x-player.position.x-13.0)
	if face_override != 0.0:
		facing = face_override
	elif toward != 0.0:
		facing = toward
	fan_owned = true
	checkpoint_fan = true
	pickup_total = _fan_lock_time()
	pickup_time = pickup_total
	release_time = 0.0

func can_pick_up_fan() -> bool:
	if not fan_revealed or fan_owned or fan_left_behind or put_down_time > 0.0 or death_time > 0.0 or paused:
		return false
	if fan_on_tree:
		# his hand is up over his head when he reaches (the hooded boy jumps no higher than himself)
		var reaching_hand := player.position+Vector2(13.0+facing*14.0,10.0 if ActorStyleHost.style_override == Pose.STYLE_HOOD else 28.0)
		return not player.is_on_floor() and not is_riding() and reaching_hand.distance_to(FAN_SPOT)<30.0
	return (player.is_on_floor() or is_riding()) and (player.position+Vector2(13,54)).distance_to(fan_rest_position()) < 65.0

func _begin_grab() -> void:
	grip_is_crate = true
	dragging = true
	grip_time = GRIP_TIME
	release_time = 0.0
	grip_distance = 0.0
	facing = signf(crate.position.x + CRATE_SIZE.x*0.5-player.position.x-13.0)

# F beside the boat. The hooded boy waits for the direction; everyone else grips at once.
func _request_grab() -> void:
	if ActorStyleHost.style_override != Pose.STYLE_HOOD:
		_begin_grab()
		return
	var direction := Input.get_axis("move_left", "move_right")
	grip_pending = true
	if direction != 0.0:
		_decide_grab(direction)

func _decide_grab(direction: float) -> void:
	grip_pending = false
	var boat_side := signf(crate.position.x + CRATE_SIZE.x * 0.5 - player.position.x - PLAYER_SIZE.x * 0.5)
	_begin_grab()
	if direction * boat_side < 0.0:
		# pulling: no arms raised first, straight to the rope
		grip_time = 0.0
		rope_direct = true

func _begin_put_down(grab_after: bool) -> bool:
	if not player.is_on_floor() and not is_riding():
		return false
	var feet := player.position + Vector2(13,54)
	fan_on_raft = is_riding()
	if fan_on_raft:
		fan_raft_local = (feet-crate.position-CRATE_SIZE*0.5).rotated(-crate_tilt)
		fan_raft_local.x = clampf(fan_raft_local.x+facing*10.0,-CRATE_SIZE.x*0.5+22.0,CRATE_SIZE.x*0.5-22.0)
		fan_raft_local.y = -CRATE_SIZE.y*0.5-4.0
	else:
		# Prefer the hand side, but never place the tool inside the hull or in deep water.
		var found := false
		for distance in ([FAN_HANDLE_REACH,-18.0,-38.0,38.0,-60.0,60.0] if ActorStyleHost.style_override == Pose.STYLE_HOOD else [18.0,-18.0,-38.0,38.0,-60.0,60.0]):
			var x: float = clampf(feet.x+facing*distance,25.0,WORLD_WIDTH-25.0)
			var y := ground_y(x)
			if absf(feet.y-RACK_RECT.position.y)<4.0 and x>RACK_RECT.position.x+12.0 and x<RACK_RECT.end.x-12.0:
				y = RACK_RECT.position.y
			if absf(feet.y-SECOND_ACT_LEDGE.position.y)<6.0 and x>SECOND_ACT_LEDGE.position.x+12.0 and x<SECOND_ACT_LEDGE.end.x-12.0:
				y = SECOND_ACT_LEDGE.position.y
			if y > WATER_Y+16.0 or absf(y-feet.y)>32.0:
				continue
			var local := (Vector2(x,y-4.0)-crate.position-CRATE_SIZE*0.5).rotated(-crate_tilt)
			if absf(local.x)<CRATE_SIZE.x*0.5+12.0 and absf(local.y)<CRATE_SIZE.y*0.5+12.0:
				continue
			fan_ground_position = Vector2(x,y-4.0)
			found = true
			break
		if not found:
			return false
	fan_ground_facing = facing
	fan_on_tree = false
	fan_handoff_origin = fan.position
	put_down_total = _fan_lock_time()
	put_down_time = put_down_total
	pending_grab = grab_after
	fan_swing = 0.0
	fan_wind_delay = -1.0
	pickup_time = 0.0
	_release_grip()
	release_time = 0.0
	return true

func _finish_put_down() -> void:
	fan_owned = false
	fan_revealed = true
	var should_grab := pending_grab and Input.is_action_pressed("interact") and not Input.is_action_pressed("jump") and can_grab()
	pending_grab = false
	grip_pending = false
	if should_grab:
		_request_grab()

func _update_interaction(direction: float) -> void:
	if intro_time > 0.0:
		return
	if pickup_time > 0.0 or put_down_time > 0.0:
		if not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump"):
			pending_grab = false
			grip_pending = false
		return
	if player.position.x > 5700.0 or cliff.carrying >= 0:
		if cliff.interact(direction, get_physics_process_delta_time()):
			if direction != 0.0 and not cliff.charging:
				facing = signf(direction)
			return
	if puzzle_box_dragging:
		if not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump") or not can_grab_puzzle_box():
			_release_puzzle_box_grip()
		else:
			facing = signf(puzzle_box.position.x + PUZZLE_BOX_SIZE.x * 0.5 - player.position.x - PLAYER_SIZE.x * 0.5)
		return
	if Input.is_action_just_pressed("interact"):
		if can_grab_puzzle_box():
			_begin_puzzle_box_grip()
			return
		elif can_pick_up_fan() and not (can_grab() and direction != 0.0):
			if _fan_pickup_needs_walk():
				fan_walk_target = _fan_pickup_stand_x()
				fan_walk_time = 0.0
				return
			_begin_fan_pickup(0.0)
			return
		elif can_grab():
			if fan_owned:
				facing = signf(crate.position.x+CRATE_SIZE.x*0.5-player.position.x-13.0)
				_begin_put_down(true)
				return
			_request_grab()
			if grip_pending:
				return
		elif fan_owned:
			_begin_put_down(false)
			return
	if grip_pending:
		if not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump") or not can_grab() or fan_owned:
			grip_pending = false
		elif direction != 0.0:
			_decide_grab(direction)
	if not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump"):
		_release_grip()
		_release_puzzle_box_grip()
	if dragging:
		if not can_grab():
			_release_grip()
		else:
			facing = signf(crate.position.x + CRATE_SIZE.x * 0.5 - player.position.x - 13.0)
	elif direction != 0.0 and not entry_brake:
		facing = signf(direction)
	if Input.is_action_pressed("blade_toggle") and fan_owned and fan_cooldown <= 0.0 and not dragging and not puzzle_box_dragging:
		swing_fan()

func swing_fan() -> bool:
	if not fan_owned or fan_cooldown > 0.0 or paused or dragging or puzzle_box_dragging or death_time > 0.0 or pickup_time > 0.0 or put_down_time > 0.0:
		return false
	var hood := ActorStyleHost.style_override == Pose.STYLE_HOOD
	if not hood:
		art.call("emit_gust", player.position + Vector2(13.0 + facing * 34.0, 14.0), facing)
	fan_swing_total = HOOD_FAN_SWING_TIME if hood else Swing.DURATION
	fan_swing = fan_swing_total
	fan_cooldown = fan_swing_total + 0.08
	if hood:
		fan_wind_delay = HOOD_FAN_WIND_DELAY
		return _fan_wind_applies()
	if _fan_wind_applies():
		_apply_fan_wind()
		return true
	return false

func _fan_lock_time() -> float:
	return HOOD_FAN_LOCK_TIME if ActorStyleHost.style_override == Pose.STYLE_HOOD else FAN_HANDOFF_TIME

func _fan_wind_applies() -> bool:
	var offset := crate.position + CRATE_SIZE * 0.5 - (player.position + PLAYER_SIZE * 0.5)
	var near := offset.length() < 240.0 and (offset.x * facing > -25.0 or is_riding())
	if beached and ActorStyleHost.style_override == Pose.STYLE_HOOD:
		# a boat that has run up on the bank is blown back out into the water, if the wind blows away from the bank
		return not launching and near and facing * bank_downhill_direction() > 0.0
	return floating and not launching and not beached and _shore_limit(crate_tilt) > _unloaded_float_y() - 6.0 and near

func _apply_fan_wind() -> void:
	if beached:
		beached = false
		refloat_keeps_speed = true
		crate.velocity.y = 0.0
	crate.velocity.x = facing * 205.0
	wind_impulses += 1

func ground_y(x: float) -> float:
	if x <= 225.0:
		return 365.0 + (x - 5.0) * 185.0 / 220.0
	if x <= 1090.0:
		return 550.0
	if x <= 1180.0:
		return lerpf(550.0, 584.0, (x - 1090.0) / 90.0)
	if x <= 1270.0:
		return lerpf(584.0, 630.0, (x - 1180.0) / 90.0)
	if x < 1350.0:
		return lerpf(630.0, 850.0, (x - 1270.0) / 80.0)
	if x < 1880.0:
		return 850.0
	if x < 1950.0:
		return lerpf(850.0, 625.0, (x - 1880.0) / 70.0)
	if x < 2110.0:
		return lerpf(625.0, 550.0, (x - 1950.0) / 160.0)
	return 550.0

# The hooded boy's boat is a hull with a waterline, not a raft: it rides higher, and does not sink under him (the raft
# sank 11 px, which on a deeper hull looks like a wreck).
const HOOD_FLOAT_RAISE := 3.0
# Riding, the hooded boy is drawn this much lower: his feet go down behind the hull's near side, so he stands IN the boat
# (the collision still stands him on the deck line).
const HOOD_RIDE_DROP := 9.0
var ride_drop := 0.0
const HOOD_LOAD_SINK := 5.0

func _float_raise() -> float:
	return HOOD_FLOAT_RAISE if ActorStyleHost.style_override == Pose.STYLE_HOOD else 0.0

func _load_sink_target() -> float:
	return HOOD_LOAD_SINK if ActorStyleHost.style_override == Pose.STYLE_HOOD else 11.0

func _unloaded_float_y() -> float:
	return WATER_Y - 18.0 - _float_raise()

func _shore_limit(angle: float, ahead_x := 0.0) -> float:
	var limit := 850.0
	var half := CRATE_SIZE * 0.5
	var extent := half + Vector2.ONE
	for corner in [Vector2(-extent.x,-extent.y), Vector2(extent.x,-extent.y), extent, Vector2(-extent.x,extent.y)]:
		var rotated: Vector2 = corner.rotated(angle)
		limit = minf(limit, ground_y(crate.position.x + ahead_x + half.x + rotated.x) - half.y - rotated.y - 0.5)
	return limit

func _lowest_crate_y() -> float:
	var half := CRATE_SIZE * 0.5
	return crate.position.y + half.y + absf(sin(crate_tilt)) * half.x + absf(cos(crate_tilt)) * half.y

func crate_waterline_span() -> Vector2:
	var half := CRATE_SIZE * 0.5
	var corners := PackedVector2Array()
	for point in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		corners.append(crate.position + half + point.rotated(crate_tilt))
	var crossings: Array[float] = []
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		if (a.y <= WATER_Y and b.y > WATER_Y) or (b.y <= WATER_Y and a.y > WATER_Y):
			crossings.append(lerpf(a.x, b.x, (WATER_Y - a.y) / (b.y - a.y)))
	if crossings.size() < 2:
		return Vector2(crate.position.x + half.x, crate.position.x + half.x)
	crossings.sort()
	return Vector2(crossings.front(), crossings.back())

func _update_water_contact(delta: float, previous_lowest: float, previous_feet_y: float) -> void:
	var lowest := _lowest_crate_y()
	var in_river := crate.position.x + CRATE_SIZE.x > 1156.0 and crate.position.x < 2060.0
	if not crate_wet and in_river and lowest > WATER_Y + 0.5:
		crate_wet = true
		var span := crate_waterline_span()
		art.emit_water_impact((span.x + span.y) * 0.5, maxf(0.0, (lowest - previous_lowest) / delta), maxf(10.0, (span.y - span.x) * 0.5))
	elif not in_river or lowest < WATER_Y - 6.0:
		crate_wet = false
	var feet := player.position + Vector2(13, 54)
	var player_in_river := feet.x > 1156.0 and feet.x < 2060.0
	if not player_wet and player_in_river and feet.y > WATER_Y + 2.0 and not is_riding():
		player_wet = true
		art.emit_water_impact(feet.x, maxf(0.0, (feet.y - previous_feet_y) / delta), 16.0, true)
	elif not player_in_river or feet.y < WATER_Y - 6.0:
		player_wet = false

func bank_slope_angle() -> float:
	# Submerged ends have buoyant support; the river bed cannot tip a shallow raft upright.
	var support_depth := WATER_Y + CRATE_SIZE.y
	var left := minf(ground_y(crate.position.x + 5.0), support_depth)
	var right := minf(ground_y(crate.position.x + CRATE_SIZE.x - 5.0), support_depth)
	return clampf(atan2(right - left, CRATE_SIZE.x - 10.0), -deg_to_rad(35.0), deg_to_rad(35.0))

func bank_downhill_direction() -> float:
	return 1.0 if crate.position.x + CRATE_SIZE.x * 0.5 < 1600.0 else -1.0

func _update_crate(delta: float, direction: float, riding: bool) -> void:
	var slope := bank_slope_angle()
	var downhill := bank_downhill_direction()
	var entering_slope := dragging and grip_time <= 0.0 and direction * downhill > 0.0 and absf(slope) > deg_to_rad(5.0)
	if not floating and not launching and entering_slope:
		launching = true
		beached = false
		launch_direction = downhill
		float_direction = downhill
		entry_brake = facing * downhill < 0.0
		_release_grip()
		crate.velocity.x = 0.0
		if entry_brake:
			player.velocity.x = 0.0
	var was_floating := floating
	# A wet bow is not enough: the wide raft must clear the bank before leveling.
	var water_contact := _lowest_crate_y() >= WATER_Y and _shore_limit(0.0) >= _unloaded_float_y() + 12.0
	var water_support := crate.position.x + CRATE_SIZE.x * 0.5 > 1156.0 and crate.position.x < 2065.0 and (was_floating or water_contact)
	if was_floating and not launching and crate.velocity.x * downhill < -0.5 and _shore_limit(crate_tilt, crate.velocity.x * delta) <= _unloaded_float_y() + load_sink + 2.0:
		beached = true
		crate.velocity.x = 0.0
	floating = water_support and not beached
	crate.floor_snap_length = 0.0 if floating else 16.0
	float_time = float_time + delta if floating else 0.0
	var sink_target := _load_sink_target() if floating and riding else 0.0
	sink_speed += ((sink_target - load_sink) * 35.0 - sink_speed * 6.0) * delta
	load_sink = clampf(load_sink + sink_speed * delta, -2.0, 20.0)
	var weight_offset := clampf((player.position.x + 13.0 - crate.position.x - CRATE_SIZE.x * 0.5) / (CRATE_SIZE.x * 0.5), -1.0, 1.0)
	var rock_target := weight_offset * deg_to_rad(4.0) if floating and riding else 0.0
	rock_speed += ((rock_target - load_rock) * 30.0 - rock_speed * 4.5) * delta
	load_rock = clampf(load_rock + rock_speed * delta, -0.12, 0.12)
	var angle_target := slope
	if floating:
		angle_target = float_direction * deg_to_rad(9.0) * exp(-float_time * 2.0) + sin(float_time * 1.5) * deg_to_rad(0.6) + load_rock
		var swell_tilt: float = -atan(art.wave_slope_between(crate.position.x + 10.0, crate.position.x + CRATE_SIZE.x - 10.0))
		angle_target += clampf(swell_tilt * 0.9, -deg_to_rad(5.0), deg_to_rad(5.0))
	var previous_support := _shore_limit(crate_tilt)
	crate_tilt = lerpf(crate_tilt, angle_target, 1.0 - exp(-delta * 5.0))
	crate_shape.rotation = crate_tilt
	if not floating and crate.is_on_floor():
		# Rotate about the supporting bank contact; unsupported motion remains gravity-driven.
		crate.position.y += _shore_limit(crate_tilt) - previous_support
	if floating:
		if not was_floating and not launching:
			if refloat_keeps_speed:
				refloat_keeps_speed = false  # blown back off the bank: the stroke's push carries on
			else:
				crate.velocity.x = 0.0
		var pulling_back := dragging and can_pull_floating()
		if not pulling_back:
			_release_grip()
		var shore_limit := minf(_shore_limit(crate_tilt), _shore_limit(crate_tilt, crate.velocity.x * delta))
		# the swell lifts and tips the raft a little (the water under it, not just the load, decides how it sits)
		var raft_wave: float = art.wave_at(crate.position.x + CRATE_SIZE.x * 0.5)
		var target_y := minf(_unloaded_float_y() + load_sink + sin(clock * 1.8) * 1.3 - raft_wave * 0.75, shore_limit)
		crate.position.y = minf(crate.position.y, shore_limit)
		crate.position.y = move_toward(crate.position.y, target_y, delta * 110.0)
		crate.velocity.y = 0.0
		if not launching:
			var pull_target := 0.0
			# Only towards the shore: a floating raft can be hauled in, not shoved out.
			if pulling_back and _grip_settled() and direction * downhill < 0.0:
				pull_target = direction * _boat_speed()
			crate.velocity.x = move_toward(crate.velocity.x, pull_target, delta * (580.0 if pull_target != 0.0 else 72.0))
	else:
		# Keep the rotating bottom on the signed bank slope, not an upright land pose.
		crate.position.y = minf(crate.position.y, _shore_limit(crate_tilt))
		crate.velocity.y = minf(900.0, crate.velocity.y + 1500.0 * delta)
		var drag_target := direction * _boat_speed() if dragging and _grip_settled() else 0.0
		if not launching:
			crate.velocity.x = move_toward(crate.velocity.x, drag_target, delta * 580.0)
		if dragging and crate.velocity.x * facing < 0.0:
			# A blocked puller must not drag the crate through their own collision body.
			var contact := player.move_and_collide(Vector2(crate.velocity.x * delta, 0), true)
			if contact != null and contact.get_normal().dot(Vector2.UP) < cos(player.floor_max_angle):
				crate.velocity.x = contact.get_travel().x / delta
	if launching:
		var stop_x := SLIDE_STOP_X if launch_direction > 0.0 else RETURN_SLIDE_STOP_X
		if (crate.position.x - stop_x) * launch_direction >= -0.1 or (floating and absf(crate.velocity.x) < 0.5):
			launching = false
			crate.velocity.x = 0.0
		elif floating:
			crate.velocity.x = move_toward(crate.velocity.x, 0.0, delta * 28.0)
		else:
			var downhill_force := 330.0 * sin(crate_tilt) * cos(crate_tilt)
			crate.velocity.x = clampf(crate.velocity.x + downhill_force * delta, -52.0, 52.0)
	# During launch the crate yields to the player, instead of pushing them underwater.
	crate.collision_mask = 5 if launching and not riding else 1
	crate.move_and_slide()
	crate.position.x = clampf(crate.position.x, 260.0, WORLD_WIDTH - CRATE_SIZE.x - 38.0)
	if crate.position.y > 780.0:
		restore_checkpoint()

func _update_puzzle_box(delta: float, direction: float) -> void:
	var target_speed := direction * _box_speed() if puzzle_box_dragging and grip_time <= 0.0 else 0.0
	puzzle_box.velocity.x = move_toward(puzzle_box.velocity.x, target_speed, delta * 720.0)
	puzzle_box.velocity.y = 0.0
	puzzle_box.move_and_slide()
	puzzle_box.position.x = clampf(puzzle_box.position.x, PUZZLE_BOX_BOUNDS.x, PUZZLE_BOX_BOUNDS.y)
	puzzle_box.position.y = SECOND_ACT_LEDGE.position.y - PUZZLE_BOX_SIZE.y

func _update_swing() -> void:
	if swing_body == null:
		return
	var phase := clock * TAU / SWING_PERIOD - PI * 0.5
	var angle := sin(phase) * SWING_MAX_ANGLE
	var center := SWING_ANCHOR + Vector2(sin(angle), cos(angle)) * SWING_ROPE_LENGTH
	swing_body.position = center - SWING_SIZE * 0.5

func marsh_gas_strength(index: int) -> float:
	var phases := [0.0, 0.78, 1.55, 0.35]
	var cycle := fposmod(clock + float(phases[index]), 3.05)
	if cycle < 1.42:
		return 0.0
	if cycle < 1.86:
		return smoothstep(1.42, 1.86, cycle) * 0.46
	if cycle < 2.64:
		return 0.82 + sin(clock * 8.0 + float(index)) * 0.18
	return 1.0 - smoothstep(2.64, 3.05, cycle)

func marsh_fire_strength(index: int) -> float:
	var cycle := fposmod(clock + float(index) * 1.12, 3.15)
	if cycle < 1.35:
		return 0.0
	if cycle < 1.78:
		return smoothstep(1.35, 1.78, cycle) * 0.45
	if cycle < 2.52:
		return 0.88 + sin(clock * 10.0 + float(index) * 0.7) * 0.12
	return 1.0 - smoothstep(2.52, 3.15, cycle)

func _reset_marsh_rocks() -> void:
	marsh_rocks.clear()
	for index in range(MARSH_ROCK_SPECS.size()):
		var spec: Dictionary = MARSH_ROCK_SPECS[index]
		marsh_rocks.append({
			"mode": ROCK_WAIT, "t": float(spec["delay"]), "pos": Vector2(float(spec["x"]), ROCK_START_Y),
			"vx": 0.0, "vy": 0.0, "angle": 0.0, "dir": float(spec["dir"]), "alpha": 1.0, "shake": 0.0,
			"impact_time": 99.0, "seed": index * 13 + 5, "radius": float(spec["radius"]),
		})
	rock_shove_index = -1
	rock_immune = 0.0
	rock_push_vx = 0.0
	rock_push_cap = ROCK_SHOVE_SPEED
	rock_sequence = false
	rock_rumble = 0.0
	limb_broken = false
	limb_time = 0.0
	camera_shake = 0.0
	rock_landings = 0
	rock_lock_time = 0.0
	camera_look = 0.0
	if camera != null:
		camera.offset = Vector2.ZERO

# The trap has already been sprung and survived: the limb is down and no more stones fall.
func _clear_marsh_rocks() -> void:
	rock_sequence = true
	limb_broken = true
	limb_time = 99.0
	for rock in marsh_rocks:
		rock["mode"] = ROCK_WAIT
		rock["t"] = 1.0e9
		rock["alpha"] = 0.0

# Height of the hill's top contour (the collider) at x, extended flat past either end.
func marsh_rock_surface_y(x: float) -> float:
	var profile: PackedVector2Array = MARSH_LANDS[1]
	if x <= profile[0].x:
		return profile[0].y
	for i in range(profile.size() - 1):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if x <= b.x:
			return lerpf(a.y, b.y, clampf((x - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0))
	return profile[profile.size() - 1].y

func _rock_slope(x: float) -> float:
	return (marsh_rock_surface_y(x + 12.0) - marsh_rock_surface_y(x - 12.0)) / 24.0

# Where the centre of a boulder of this radius sits when it rests on the hill at x.
func _rock_ground_center(x: float, radius: float) -> float:
	var slope := _rock_slope(x)
	return marsh_rock_surface_y(x) - radius * sqrt(1.0 + slope * slope) + 3.0

func _update_marsh_rocks(delta: float) -> void:
	rock_immune = maxf(0.0, rock_immune - delta)
	camera_shake = maxf(0.0, camera_shake - delta * 24.0)
	if limb_broken:
		limb_time += delta
		rock_lock_time = minf(rock_lock_time, 0.12)
	if rock_lock_time > 0.0:
		rock_lock_time = maxf(0.0, rock_lock_time - delta)
		if not limb_broken:
			camera_shake = maxf(camera_shake, 0.7 + 1.3 * (1.0 - rock_lock_time / 1.7))
	# The trap is sprung by walking up the hill: a faint rumble from far off swells as the player
	# climbs, and at the trigger point they freeze while the first stone comes down.
	if not rock_sequence:
		rock_rumble = 0.0
		if player.position.x > ROCK_RUMBLE_FROM - 40.0 and player.position.x < 4560.0 and player.is_on_floor() and marsh_hit_time <= 0.0 and death_time <= 0.0:
			rock_rumble = clampf((player.position.x - ROCK_RUMBLE_FROM) / (ROCK_TRIGGER_X - ROCK_RUMBLE_FROM), 0.0, 1.0)
			camera_shake = maxf(camera_shake, 0.25 + 0.7 * rock_rumble if rock_rumble > 0.0 else 0.0)
			if player.position.x >= ROCK_TRIGGER_X:
				rock_sequence = true
				# The ground shudders and the player freezes, looking up, until the limb gives way.
				rock_lock_time = 1.7
				for index in range(marsh_rocks.size()):
					marsh_rocks[index]["t"] = rock_first_delay + float(MARSH_ROCK_SPECS[index]["delay"])
		if not rock_sequence:
			return
	var profile: PackedVector2Array = MARSH_LANDS[1]
	var land_start: float = profile[0].x
	var land_end: float = profile[profile.size() - 1].x
	for index in range(marsh_rocks.size()):
		var rock: Dictionary = marsh_rocks[index]
		var spec: Dictionary = MARSH_ROCK_SPECS[index]
		var radius: float = rock["radius"]
		var rpos: Vector2 = rock["pos"]
		rock["impact_time"] = float(rock["impact_time"]) + delta
		match int(rock["mode"]):
			ROCK_WAIT:
				rock["t"] = float(rock["t"]) - delta
				rock["alpha"] = 0.0
				if float(rock["t"]) <= 0.0:
					rock["mode"] = ROCK_WARN
					rock["t"] = ROCK_WARN_TIME
					rock["seed"] = int(rock["seed"]) + 1
					rock["angle"] = 0.0
					rock["vx"] = 0.0
					rock["vy"] = 0.0
					rpos = Vector2(float(spec["x"]), ROCK_START_Y)
			ROCK_WARN:
				# A tremor and a trickle of grit from above: barely time to look up.
				rock["t"] = float(rock["t"]) - delta
				rock["shake"] = 1.0 - float(rock["t"]) / ROCK_WARN_TIME
				rock["alpha"] = 1.0
				if float(rock["t"]) <= 0.0:
					rock["mode"] = ROCK_FALL
					rock["shake"] = 0.0
					rock["vy"] = 420.0
			ROCK_FALL:
				rock["vy"] = minf(float(rock["vy"]) + 1900.0 * delta, 1100.0)
				rpos.y += float(rock["vy"]) * delta
				if not limb_broken and absf(rpos.x - LIMB_BREAK_X) < 70.0 and rpos.y + radius >= LIMB_BREAK_Y - 6.0 and rpos.y - radius < LIMB_BREAK_Y + 16.0:
					# The stone goes through the limb and takes its outer half with it.
					limb_broken = true
					limb_time = 0.0
					camera_shake = maxf(camera_shake, 4.0)
					rock["vy"] = float(rock["vy"]) * 0.8
				var ground := _rock_ground_center(rpos.x, radius)
				if rpos.y >= ground:
					rpos.y = ground
					rock["mode"] = ROCK_ROLL
					rock["impact_time"] = 0.0
					rock["vx"] = float(rock["dir"]) * 84.0
					rock["vy"] = 0.0
					var near := clampf(1.0 - absf(rpos.x - player.position.x) / 420.0, 0.0, 1.0)
					camera_shake = maxf(camera_shake, (2.6 if rock_landings == 0 else 1.3) * near)
					rock_landings += 1
			ROCK_ROLL:
				var vx: float = rock["vx"]
				vx += clampf(_rock_slope(rpos.x), -0.9, 0.9) * 900.0 * delta
				vx -= vx * 0.08 * delta
				var travel := signf(vx) if not is_zero_approx(vx) else float(rock["dir"])
				if absf(vx) < 46.0:
					vx = travel * 46.0
				vx = clampf(vx, -ROCK_MAX_SPEED, ROCK_MAX_SPEED)
				if rock_shove_index == index:
					# The player is in the way: the stone only grinds forward at the player's pace.
					vx = signf(vx) * minf(absf(vx), rock_push_cap)
				rock["vx"] = vx
				rpos.x += vx * delta
				rpos.y = _rock_ground_center(rpos.x, radius)
				rock["angle"] = float(rock["angle"]) + vx / radius * delta
				if rpos.x < land_start - 6.0 or rpos.x > land_end + 6.0:
					rock["mode"] = ROCK_DROP
					rock["vy"] = 60.0
			ROCK_DROP:
				rock["vy"] = minf(float(rock["vy"]) + 1500.0 * delta, 900.0)
				rpos.x += float(rock["vx"]) * 0.8 * delta
				rpos.y += float(rock["vy"]) * delta
				rock["angle"] = float(rock["angle"]) + float(rock["vx"]) / radius * delta * 1.4
				rock["alpha"] = 1.0 - smoothstep(500.0, 640.0, rpos.y)
				if rpos.y > 680.0:
					rock["mode"] = ROCK_WAIT
					rock["t"] = float(spec["repeat"])
					rock["alpha"] = 0.0
					rock["impact_time"] = 99.0
		rock["pos"] = rpos

# Art-facing view of one boulder. "hazard" is the crushing window (falling, or the instant it lands);
# a rolling boulder shoves instead (see _update_rock_shove).
func marsh_rock_state(index: int) -> Dictionary:
	var rock: Dictionary = marsh_rocks[index]
	var mode := int(rock["mode"])
	var impact_time := float(rock["impact_time"])
	return {
		"visible": mode != ROCK_WAIT, "hazard": mode == ROCK_FALL or (mode == ROCK_ROLL and impact_time < 0.12),
		"impact": impact_time < 0.4, "alpha": float(rock["alpha"]), "shake": float(rock["shake"]),
		"impact_time": impact_time, "position": Vector2(rock["pos"]), "radius": float(rock["radius"]),
		"index": index, "mode": mode, "angle": float(rock["angle"]), "vx": float(rock["vx"]),
		"rolling": mode == ROCK_ROLL, "seed": int(rock["seed"]),
	}

func rock_shove_info() -> Dictionary:
	var info := {"active": false, "dir": 0.0, "feet": player.position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y), "speed": 0.0}
	if rock_shove_index < 0:
		return info
	var rock: Dictionary = marsh_rocks[rock_shove_index]
	info["active"] = true
	info["dir"] = signf(float(rock["vx"]))
	info["speed"] = absf(float(rock["vx"]))
	info["resist"] = rock_resist
	return info

func limb_break_state() -> Dictionary:
	return {"broken": limb_broken, "time": limb_time}

func _end_rock_shove() -> void:
	rock_shove_index = -1
	rock_resist = 0.0
	rock_push_cap = ROCK_SHOVE_SPEED

# A rolling boulder does not knock the player down: it runs into them, loses most of its speed and
# walks them back toward the edge. Nothing needs pressing; a jump is the way out, and the boulder
# then rolls on beneath for a moment.
func _update_rock_shove(delta: float, direction: float) -> void:
	rock_push_vx = 0.0
	var found := -1
	if player.position.x > 3700.0 and player.position.x < 4560.0 and player.is_on_floor() and rock_immune <= 0.0 and marsh_hit_time <= 0.0 and death_time <= 0.0:
		var player_rect := Rect2(player.position, PLAYER_SIZE)
		var player_cx := player.position.x + PLAYER_SIZE.x * 0.5
		for index in range(marsh_rocks.size()):
			var rock: Dictionary = marsh_rocks[index]
			if int(rock["mode"]) != ROCK_ROLL:
				continue
			var center: Vector2 = rock["pos"]
			var radius: float = rock["radius"]
			var heading := signf(float(rock["vx"]))
			if heading * (player_cx - center.x) < -radius * 0.4:
				continue
			var nearest := Vector2(clampf(center.x, player_rect.position.x, player_rect.end.x), clampf(center.y, player_rect.position.y, player_rect.end.y))
			if nearest.distance_to(center) < radius - 1.0 and player_rect.end.y > center.y - radius * 0.55:
				found = index
				break
	if found < 0:
		if rock_shove_index >= 0:
			_end_rock_shove()
		return
	var shoved: Dictionary = marsh_rocks[found]
	var travel := signf(float(shoved["vx"]))
	if rock_shove_index != found:
		rock_shove_index = found
		dragging = false
		puzzle_box_dragging = false
		pending_grab = false
		grip_pending = false
	facing = -travel
	# Holding the key against the stone braces him: his heels dig in (more dust, see marsh_art) and the stone grinds forward more
	# slowly. It does not stop it: he is still walked back to the edge, only later.
	var bracing := direction != 0.0 and direction * travel < 0.0
	rock_resist = move_toward(rock_resist, 1.0 if bracing else 0.0, delta / ROCK_RESIST_RAMP)
	rock_push_cap = lerpf(ROCK_SHOVE_SPEED, ROCK_RESIST_SPEED, rock_resist)
	rock_push_vx = travel * minf(absf(float(shoved["vx"])), rock_push_cap)
	# The boulder leans on the player at hip height, never inside them.
	var center_x: float = Vector2(shoved["pos"]).x
	var desired := center_x + travel * (float(shoved["radius"]) * 0.72 + PLAYER_SIZE.x * 0.5)
	var player_cx_now := player.position.x + PLAYER_SIZE.x * 0.5
	if travel * (player_cx_now - desired) < 0.0:
		player.position.x += desired - player_cx_now
	grip_distance += absf(rock_push_vx) * delta

# Act three: a drop from the lift, high or half way up, kills; and a cage coming down on someone standing under it crushes
# them (it used to press them into the ground, where they stood stuck).
const LETHAL_FALL := 170.0
var air_top_y := 0.0
var in_air := false
var last_lift_s := -1.0

func _check_fall_and_crush() -> void:
	if marsh_hit_time > 0.0 or death_time > 0.0 or player.position.x < 5700.0:
		in_air = false
		if cliff != null:
			last_lift_s = cliff.lift_s
		return
	var grounded: bool = player.is_on_floor() or cliff.on_cage()
	if not grounded:
		if not in_air:
			in_air = true
			air_top_y = player.position.y
		air_top_y = minf(air_top_y, player.position.y)
	elif in_air:
		in_air = false
		if player.position.y - air_top_y > LETHAL_FALL:
			_start_marsh_hit("fall", player.position)
			return
	var descending: bool = last_lift_s >= 0.0 and cliff.lift_s < last_lift_s - 0.2
	last_lift_s = cliff.lift_s
	if descending and not cliff.on_cage():
		var cage := Rect2(CliffAct.LIFT_X, cliff.cage_top(), CliffAct.LIFT_W, 14.0)
		var body_rect := Rect2(player.position + Vector2(3.0, 2.0), PLAYER_SIZE - Vector2(6.0, 4.0))
		if cage.intersects(body_rect):
			_start_marsh_hit("crush", player.position)

func _check_marsh_hazards() -> void:
	if marsh_hit_time > 0.0 or death_time > 0.0:
		return
	var player_rect := Rect2(player.position, PLAYER_SIZE)
	# The gas in the pits is scenery only: it is drawn low and far behind, and does no harm.
	for fire_index in range(MARSH_FIRE_RECTS.size()):
		var source := MARSH_FIRE_RECTS[fire_index]
		var strength := marsh_fire_strength(fire_index)
		var height := source.size.y * strength
		var active_rect := Rect2(Vector2(source.position.x, source.end.y - height), Vector2(source.size.x, height))
		if strength > 0.52 and player_rect.intersects(active_rect):
			_start_marsh_hit("fire", active_rect.get_center())
			return
	for rock_index in range(MARSH_ROCK_SPECS.size()):
		var state := marsh_rock_state(rock_index)
		if not bool(state["hazard"]):
			continue
		var radius := float(state["radius"])
		var rock_rect := Rect2(Vector2(state["position"]) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
		if player_rect.intersects(rock_rect):
			_start_marsh_hit("rock", Vector2(state["position"]))
			return

func _start_marsh_hit(kind: String, source: Vector2) -> void:
	marsh_hit_kind = kind
	marsh_hit_time = 0.001
	puzzle_box_dragging = false
	dragging = false
	fan_swing = 0.0
	fan_wind_delay = -1.0
	release_time = 0.0
	if kind == "pit":
		# Walked or dropped off an edge: the fall already has its momentum.
		return
	if kind == "fall" or kind == "crush":
		player.velocity = Vector2.ZERO
		camera_shake = maxf(camera_shake, 1.4)
		art.call("emit_drag_dust", [player.position + Vector2(13.0, 54.0)], 16.0)
		return
	var player_center := player.position + PLAYER_SIZE * 0.5
	var recoil := signf(player_center.x - source.x)
	if is_zero_approx(recoil):
		recoil = -facing
	if kind == "rock":
		player.velocity = Vector2(recoil * 36.0, 0.0)
		return
	# Gas and flame throw the player clear of the platform, down into the pocket.
	player.collision_mask = 0
	player.velocity = Vector2(recoil * 190.0, -215.0)

func _update_marsh_hit(delta: float) -> void:
	marsh_hit_time += delta
	var feet_y := player.position.y + PLAYER_SIZE.y
	if marsh_hit_kind == "fall" or marsh_hit_kind == "crush":
		# Too far to fall, or flattened under the cage: he lies where it happened, then the fade and the checkpoint
		player.velocity = Vector2.ZERO
		if marsh_hit_time > 1.7:
			_fail_restore()
		return
	if marsh_hit_kind == "rock":
		player.velocity.x = move_toward(player.velocity.x, 0.0, 900.0 * delta)
		player.velocity.y = minf(850.0, player.velocity.y + 1500.0 * delta)
		player.move_and_slide()
		if marsh_hit_time > 1.05:
			_fail_restore()
		return
	player.velocity.x = move_toward(player.velocity.x, 0.0, 155.0 * delta)
	player.velocity.y = minf(900.0, player.velocity.y + 1500.0 * delta)
	if feet_y > MARSH_FALL_Y - 40.0:
		# Thick gas swallows the fall instead of letting the body drop out of frame.
		player.velocity.y = minf(player.velocity.y, 250.0)
	player.move_and_slide()
	if player.position.y + PLAYER_SIZE.y > 664.0 or marsh_hit_time > 2.2:
		_fail_restore()

func marsh_actor_alpha() -> float:
	if marsh_hit_time <= 0.0:
		return 1.0
	if marsh_hit_kind == "rock":
		return 1.0 - smoothstep(0.62, 1.0, marsh_hit_time)
	if marsh_hit_kind == "fall" or marsh_hit_kind == "crush":
		return 1.0 - smoothstep(1.25, 1.7, marsh_hit_time)
	return 1.0 - smoothstep(MARSH_FALL_Y - 25.0, MARSH_FALL_Y + 60.0, player.position.y + PLAYER_SIZE.y)

func _reset_fragile() -> void:
	for platform in fragile:
		platform["phase"] = 0
		platform["time"] = 10.0
		(platform["shape"] as CollisionShape2D).set_deferred("disabled", false)

func fragile_state(index: int) -> Dictionary:
	var platform: Dictionary = fragile[index]
	return {"phase": int(platform["phase"]), "time": float(platform["time"]), "rect": platform["rect"], "break": float(platform["break"])}

func _update_fragile(delta: float) -> void:
	if fragile.is_empty():
		return
	var feet := player.position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y + 2.0)
	for index in range(fragile.size()):
		var platform: Dictionary = fragile[index]
		var rect: Rect2 = platform["rect"]
		var shape: CollisionShape2D = platform["shape"]
		platform["time"] = float(platform["time"]) + delta
		match int(platform["phase"]):
			0:
				var trigger := Rect2(rect.position + Vector2(-4.0, -8.0), Vector2(rect.size.x + 8.0, 14.0))
				if player.is_on_floor() and trigger.has_point(feet):
					platform["phase"] = 1
					platform["time"] = 0.0
			1:
				if float(platform["time"]) >= float(platform["break"]):
					platform["phase"] = 2
					platform["time"] = 0.0
					shape.set_deferred("disabled", true)
					camera_shake = maxf(camera_shake, 1.2)
					# The rubble shakes the next spire loose: it is already part of the way to falling.
					if index + 1 < fragile.size() and int(fragile[index + 1]["phase"]) == 0:
						fragile[index + 1]["phase"] = 1
						fragile[index + 1]["time"] = float(fragile[index + 1]["break"]) * 0.45
			2:
				var keep_clear := rect.grow(60.0)
				if float(platform["time"]) >= FRAGILE_RESPAWN_TIME and not keep_clear.intersects(Rect2(player.position, PLAYER_SIZE)):
					platform["phase"] = 0
					platform["time"] = 0.0
					shape.set_deferred("disabled", false)

# ---- the rope-hung deck
func _reset_hang_deck() -> void:
	hang_sway = 0.0
	hang_sway_speed = 0.0
	hang_tilt = 0.0
	hang_tilt_speed = 0.0
	hang_player_on = false
	if hang_body != null:
		_place_hang_deck()

func hang_center() -> Vector2:
	var anchor := Vector2(HANG_DECK.get_center().x, HANG_ANCHOR_Y)
	var length := HANG_DECK.get_center().y - HANG_ANCHOR_Y
	return anchor + Vector2(sin(hang_sway), cos(hang_sway)) * length

func _place_hang_deck() -> void:
	# One assignment: a synced body snaps back to its last valid transform after each separate change.
	hang_body.transform = Transform2D(hang_tilt, hang_center())

func hang_state() -> Dictionary:
	return {"center": hang_center(), "tilt": hang_tilt, "sway": hang_sway, "loaded": hang_player_on}

# The deck swings like a pendulum, creaks a little on its own, kicks when someone lands on it, and
# tips toward whichever end carries the weight, so where you stand decides how steep it gets and
# which way you slide.
func _update_hang_deck(delta: float) -> void:
	if hang_body == null:
		return
	var center := hang_center()
	var feet := player.position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y)
	var local := (feet - center).rotated(-hang_tilt)
	var half := HANG_DECK.size * 0.5
	var on := player.is_on_floor() and absf(local.x) <= half.x + 4.0 and local.y > -half.y - 8.0 and local.y < half.y + 6.0 and marsh_hit_time <= 0.0
	var offset := clampf(local.x / half.x, -1.0, 1.0)
	if on and not hang_player_on:
		# Landing: a push along the player's heading and a dip on the side they came down on.
		hang_sway_speed += clampf(player.velocity.x, -300.0, 300.0) * 0.0005 + offset * 0.05
		hang_tilt_speed += offset * 0.9 + signf(player.velocity.x) * 0.15
	hang_player_on = on
	var length := HANG_DECK.get_center().y - HANG_ANCHOR_Y
	var forcing := sin(clock * 1.7) * 0.05 + sin(clock * 2.9 + 1.0) * 0.025
	var accel := -(1500.0 / length) * sin(hang_sway) - 0.5 * hang_sway_speed + forcing
	hang_sway_speed += accel * delta
	hang_sway = clampf(hang_sway + hang_sway_speed * delta, -0.24, 0.24)
	var target := offset * HANG_TILT_MAX if on else 0.0
	hang_tilt_speed += ((target - hang_tilt) * 62.0 - hang_tilt_speed * 7.0) * delta
	hang_tilt = clampf(hang_tilt + hang_tilt_speed * delta, -HANG_TILT_MAX * 1.35, HANG_TILT_MAX * 1.35)
	_place_hang_deck()

func _update_marsh_checkpoint() -> void:
	if checkpoint >= 4 or not player.is_on_floor():
		return
	var feet_x := player.position.x + PLAYER_SIZE.x * 0.5
	# Inside the second act, before the mid-act save: remember how far in the player has got.
	if checkpoint == 2:
		var feet_y := player.position.y + PLAYER_SIZE.y
		if marsh_save < 2 and feet_x > MARSH_HILL_SAVE_X and feet_x < ROCK_RUMBLE_FROM + 60.0 and absf(feet_y - marsh_rock_surface_y(feet_x)) < 8.0:
			marsh_save = 2
		elif marsh_save < 1 and feet_x > MARSH_LEDGE_SAVE_X and feet_x < SECOND_ACT_LEDGE.position.x + 520.0 and absf(feet_y - SECOND_ACT_LEDGE.position.y) < 8.0:
			marsh_save = 1
	# Act three starts on the last bank: from here a fall into the gap does not cost the whole act.
	if checkpoint >= 3:
		if feet_x > CHECKPOINT_BANK_X and feet_x < MARSH_PITS[3].x - 24.0:
			checkpoint = 4
			checkpoint_fan = false
		return
	# Saved once the player has dodged the stones and jumped on to the next step (the fire deck).
	if feet_x > FIRE_DECK.position.x and feet_x < FIRE_DECK.end.x and player.position.y + PLAYER_SIZE.y < FIRE_DECK.position.y + 6.0:
		checkpoint = 3
		checkpoint_fan = false

# Reaching the second act's ledge ends the leaf's use. It is not made to vanish: a leaf in the hand
# is set down where the player stands (the normal put-down), one already lying somewhere stays
# there. After that it cannot be picked up again, and the next death puts it back on its tree.
func _retire_fan_for_second_act() -> void:
	if fan_left_behind or (not fan_owned and not checkpoint_fan):
		return
	if fan_owned:
		if put_down_time > 0.0 or pickup_time > 0.0:
			return
		if not _begin_put_down(false):
			return
	checkpoint_fan = false
	fan_left_behind = true

func _update_player(delta: float, direction: float, crate_speed: float) -> void:
	var grounded := player.is_on_floor() or is_riding()
	coyote = 0.11 if grounded else maxf(0.0, coyote - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if not cinematic_entry and Input.is_action_just_pressed("jump") and intro_time <= 0.0 and pickup_time <= 0.0 and put_down_time <= 0.0:
		jump_buffer = 0.13
	var speed := 285.0
	var jump_scale := 1.0
	if ActorStyleHost.style_override == Pose.STYLE_HOOD:
		speed *= Pose.HOOD_RUN_SPEED_SCALE if grounded else Pose.HOOD_AIR_SPEED_SCALE
		jump_scale = Pose.HOOD_JUMP_SCALE
	var in_shallows := player.position.y + 54.0 > WATER_Y + 10.0
	if in_shallows:
		speed = 160.0
	var target := direction * speed
	_update_rope_mode(delta, direction)
	if entry_brake:
		target = 0.0
	if hang_player_on and rock_shove_index < 0:
		target += sin(hang_tilt) * 90.0
	if rock_shove_index >= 0:
		target = rock_push_vx
	elif dragging:
		target = crate_speed + clampf((grip_target_x() - player.position.x) * 16.0, -110.0, 110.0)
	elif puzzle_box_dragging:
		var box_speed := puzzle_box_motion / maxf(delta, 0.0001)
		target = box_speed + clampf((puzzle_box_grip_target_x() - player.position.x) * 16.0, -105.0, 105.0)
	if intro_time <= 0.0:
		var accel := 1900.0
		if ActorStyleHost.style_override == Pose.STYLE_HOOD and grounded and direction != 0.0 and rock_shove_index < 0 and not dragging and not puzzle_box_dragging and not hang_player_on and not in_shallows \
				and player.velocity.x * direction > -1.0 and absf(target) > absf(player.velocity.x):
			accel = Pose.HOOD_START_ACCEL  # the first step shows before he is at speed (no sliding on the spot)
		player.velocity.x = move_toward(player.velocity.x, target, delta * accel)
	player.velocity.y = minf(850.0, player.velocity.y + 1500.0 * delta)
	if rock_lock_time > 0.0 or cliff.locks_move():
		jump_buffer = 0.0
	var hood_gathers := ActorStyleHost.style_override == Pose.STYLE_HOOD and grounded
	if jump_buffer > 0.0 and coyote > 0.0 and jump_windup_left <= 0.0:
		if hood_gathers:
			# the jump gathers first (the video's crouch), the launch comes when it has run out; the controls stay live
			jump_windup_left = Pose.HOOD_JUMP_WINDUP
			jump_buffer = 0.0
		else:
			_launch_jump(jump_scale)
	elif jump_windup_left > 0.0:
		jump_windup_left -= delta
		if coyote <= 0.0 or rock_lock_time > 0.0 or cliff.locks_move():
			jump_windup_left = 0.0  # he left the ground (or was frozen) while gathering: no jump
		elif jump_windup_left <= 0.0:
			jump_windup_left = 0.0
			_launch_jump(jump_scale)
	# letting go early cuts the jump; for the hooded boy (whose jump gathers first) to a short hop that is still a jump (about 40 px)
	var jump_cut := -210.0 * jump_scale
	if ActorStyleHost.style_override == Pose.STYLE_HOOD:
		jump_cut = -595.0 * jump_scale * Pose.HOOD_JUMP_CUT
	if not Input.is_action_pressed("jump") and player.velocity.y < jump_cut:
		player.velocity.y = jump_cut
	player.move_and_slide()
	player.position.x = clampf(player.position.x, 20.0, WORLD_WIDTH - 55.0)

# --- climbing ------------------------------------------------------------------------------------------
# The hooded boy jumps about his own height (Pose.HOOD_JUMP_SCALE); anything higher he climbs: a jump that brings his hands
# to the top edge of a ledge (a wall, a box, a thin deck) takes hold of it, and the `climb` clip hangs, pulls up, crawls and
# stands. The clip's root is the ledge corner, so the whole movement is in the frames; the body just follows the same path
# (the camera and the rest of the game keep a body that is where he is). Moving away from the ledge early lets go.
var climb_total := 2.5  # the clip's length (set from its manifest when the climb starts)
var climb_snap := 0.38  # the clip's lead-in: from where he was to the hanging pose
const CLIMB_LET_GO_TIME := 0.5  # moving away from the ledge within this long after the lead-in lets go
const CLIMB_WINDOW := 45.0  # the drying rack (a beam over his head): its top may be this far above or below the top of his head
# Edges: the hands have to be at the corner. The lead-in only moves him by the rest (at most about 35 px) from where he is.
const CLIMB_REACH_ABOVE := 12.0  # px the ledge's top may be above the top of his head
const CLIMB_REACH_BELOW := 30.0  # ... or below it
const CLIMB_MAX_DISTANCE := 36.0  # px from his centre to the edge
const CLIMB_MIN_HEIGHT := 30.0  # lower than this above his feet and he just steps / lands on it
const CLIMB_JUMP_REACH := 40.0  # a ledge no higher than this above the floor he jumped from is landed on
const CLIMB_INSET := 8.0  # the corner is taken this far inside the edge, so that he ends standing a little further in
const CLIMB_MASK := 11  # ground, the box (not the stones); the boat and moving platforms are refused below
var climb_time := -1.0
var climb_corner := Vector2.ZERO
var climb_side := 1.0
var climb_from_feet := Vector2.ZERO
var climb_end_feet := Vector2.ZERO
var climb_cooldown := 0.0
var climb_bridge_left := 0.0  # the bridge frames (air pose -> the reach) still to show
var climb_bridge_total := 0.0
var climb_bridge_start := 0
var climb_prev_velocity := Vector2.ZERO  # his velocity as the frame began: what he carries into the grab
var climb_v0 := Vector2.ZERO
var climb_lead_start := 0  # the frame of the reach he starts from (see _try_begin_climb)
var climb_start_t := 0.0
var climb_land_grace := 0.0  # the body has not found the floor yet on the first frames after the climb: still standing
var climb_floor_on_raft := false
var climb_floor_y := 0.0  # the feet of the last floor he stood on: a ledge a jump reaches is not climbed

func _climb_scale() -> float:
	return HoodActor.DISPLAY_SCALE * ACTOR_VISUAL_SCALE

# a point of the clip (canvas px from its root, the clip faces left) -> where it is in the world around the corner
func _climb_point(clip_point: Array) -> Vector2:
	var k := _climb_scale()
	return climb_corner + Vector2(climb_side * -float(clip_point[0]) * k, float(clip_point[1]) * k)

# Where the clip's feet are in the world at this moment of the lead-in (the lead-in is rooted at the corner)
func _climb_clip_feet(frame: float) -> Vector2:
	var data: Dictionary = HoodManifest.CLIPS["climb"]
	var lead_feet: Array = data.get("lead_feet", [])
	if lead_feet.is_empty():
		return _climb_point(data["start_feet"])
	var clamped := clampf(frame, 0.0, float(lead_feet.size() - 1))
	var low := int(floor(clamped))
	var high := mini(low + 1, lead_feet.size() - 1)
	var mix := clamped - float(low)
	var a: Array = lead_feet[low]
	var b: Array = lead_feet[high]
	return _climb_point([lerpf(float(a[0]), float(b[0]), mix), lerpf(float(a[1]), float(b[1]), mix)])

# His feet while he takes hold: they carry on with the speed he came with and settle into the hanging place (a Hermite curve with
# the incoming velocity at the start and none at the end; an ease that starts from rest was a dead stop in mid-air), then the
# climb carries him up to where he stands.
func _climb_feet() -> Vector2:
	var data: Dictionary = HoodManifest.CLIPS["climb"]
	var hang := _climb_clip_feet(float(data.get("lead_frames", 0)))
	var duration := maxf(climb_bridge_total + climb_snap - climb_start_t, 0.08)
	if climb_time < climb_snap:
		# the clock of the take-hold: the bridge first (the climb clock waits), then the rest of the reach
		var elapsed := (climb_bridge_total - climb_bridge_left) + (climb_time - climb_start_t)
		var s := clampf(elapsed / duration, 0.0, 1.0)
		var h00 := 2.0 * s * s * s - 3.0 * s * s + 1.0
		var h10 := s * s * s - 2.0 * s * s + s
		var h01 := -2.0 * s * s * s + 3.0 * s * s
		return climb_from_feet * h00 + climb_v0 * duration * h10 + hang * h01
	var rest := maxf(climb_total - climb_snap, 0.1)
	return hang.lerp(climb_end_feet, smoothstep(0.0, 1.0, (climb_time - climb_snap) / rest))

func _climb_root() -> Vector2:
	var data: Dictionary = HoodManifest.CLIPS["climb"]
	var frame := climb_time / climb_total * float(int(data["frames"]) - 1)
	if climb_bridge_left > 0.0:
		return _climb_feet()  # the bridge frames are rooted at the feet like every clip
	if climb_time >= climb_snap:
		return climb_corner
	# the displayed feet follow _climb_feet(); the clip's own feet movement is taken out, so the root is where the corner has to be
	return climb_corner + (_climb_feet() - _climb_clip_feet(frame))

func _climb_blocked(direction: float) -> bool:
	if ActorStyleHost.style_override != Pose.STYLE_HOOD or hood_actor == null or not hood_actor.has_clip(&"climb"):
		return true
	if climb_time >= 0.0 or climb_cooldown > 0.0 or intro_time > 0.0 or cinematic_entry:
		return true
	if player.is_on_floor() or is_riding() or death_time > 0.0 or marsh_hit_time > 0.0:
		return true
	# his hands are busy
	if dragging or puzzle_box_dragging or fan_owned or cliff.carrying >= 0 or rock_shove_index >= 0 or rock_lock_time > 0.0:
		return true
	if pickup_time > 0.0 or put_down_time > 0.0 or fan_swing > 0.0 or release_time > 0.0 or cliff.locks_move():
		return true
	return false

func _climb_ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, CLIMB_MASK, [player.get_rid(), crate.get_rid()])
	return player.get_world_2d().direct_space_state.intersect_ray(query)

# Is there a ledge in front of his hands? Fills the corner (and returns true) if he can take hold of one.
func _find_ledge(side: float, pressing: bool) -> bool:
	var head_y := player.position.y
	var feet_y := head_y + PLAYER_SIZE.y
	var centre_x := player.position.x + PLAYER_SIZE.x * 0.5
	var found := Vector2.ZERO
	var collider: Object = null
	if _find_rack_climb(side):
		return true
	if not pressing:
		return false  # an edge is only taken while he leans towards it
	var step := 6.0
	var offset := 10.0
	while offset <= CLIMB_MAX_DISTANCE:
		var x := centre_x + side * offset
		var hit := _climb_ray(Vector2(x, head_y - CLIMB_REACH_ABOVE - 6.0), Vector2(x, head_y + CLIMB_REACH_BELOW))
		var good := not hit.is_empty() and Vector2(hit.normal).y < -0.9
		if good:
			if offset <= 10.0:
				return false  # the surface is already under his hands: not an edge (he is above it, or it is a slope)
			# edge between the last ray and this one: bisect
			var lo := offset - step
			var hi := offset
			for _i in 3:
				var mid := (lo + hi) * 0.5
				var test := _climb_ray(Vector2(centre_x + side * mid, head_y - CLIMB_REACH_ABOVE - 6.0), Vector2(centre_x + side * mid, head_y + CLIMB_REACH_BELOW))
				if not test.is_empty() and Vector2(test.normal).y < -0.9:
					hi = mid
				else:
					lo = mid
			found = Vector2(centre_x + side * hi, float(hit.position.y))
			collider = hit.collider
			break
		offset += step
	if collider == null:
		return false
	if found.y > feet_y - CLIMB_MIN_HEIGHT:
		return false
	# a ledge only a little above the floor he left is landed on (unless he has dropped well below it since)
	if found.y > climb_floor_y - CLIMB_JUMP_REACH and feet_y < climb_floor_y + 40.0:
		return false
	# the rope-hung deck is the one moving platform he can take hold of (unloaded it hangs still); the swing, the bridge
	# and the lift move too much, the raft is not land
	if (collider is AnimatableBody2D and collider != hang_body) or (collider is CharacterBody2D and collider != puzzle_box):
		return false
	# the face under the edge must really be a wall (a slope is walked): the edge is a corner, nothing solid just inside it
	var below := _climb_ray(Vector2(found.x - side * 5.0, found.y + 6.0), Vector2(found.x - side * 5.0, found.y + 30.0))
	if not below.is_empty():
		return false
	# room to stand on top of it
	var end_x := found.x + side * (CLIMB_INSET - float(HoodManifest.CLIPS["climb"]["end_feet"][0]) * _climb_scale())
	var shape := RectangleShape2D.new()
	shape.size = Vector2(PLAYER_SIZE.x - 2.0, PLAYER_SIZE.y - 6.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = CLIMB_MASK
	query.exclude = [player.get_rid(), crate.get_rid()]
	query.transform = Transform2D(0.0, Vector2(end_x, found.y - PLAYER_SIZE.y * 0.5 - 4.0))
	if not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	climb_corner = found + Vector2(side * CLIMB_INSET, 0.0)
	return true

# The drying rack above the raft is a one-way beam: he cannot hook an edge of it from the raft (it lies over him), so he takes
# hold of the beam itself as his head comes level with it.
func _find_rack_climb(side: float) -> bool:
	var centre_x := player.position.x + PLAYER_SIZE.x * 0.5
	var head_y := player.position.y
	var feet_y := head_y + PLAYER_SIZE.y
	if not climb_floor_on_raft or centre_x < RACK_RECT.position.x + 14.0 or centre_x > RACK_RECT.end.x - 14.0:
		return false  # only from a jump off the raft (not from the bank, not from below the rack in the water)
	if feet_y < RACK_RECT.position.y + 30.0 or head_y > RACK_RECT.position.y + CLIMB_WINDOW or head_y < RACK_RECT.position.y - 40.0:
		return false
	var corner_x := centre_x + side * (6.0 + CLIMB_INSET)
	var end_x := corner_x + side * (-float(HoodManifest.CLIPS["climb"]["end_feet"][0]) * _climb_scale())
	if end_x < RACK_RECT.position.x + 8.0 or end_x > RACK_RECT.end.x - 8.0:
		return false
	climb_corner = Vector2(corner_x, RACK_RECT.position.y)
	return true

func _try_begin_climb(direction: float) -> bool:
	if _climb_blocked(direction):
		return false
	if player.velocity.y < -240.0 or player.velocity.y > 460.0:
		return false  # hands find a ledge near the top of a jump, or falling past it; not on the way up at full speed
	var side := signf(direction) if direction != 0.0 else facing
	if not _find_ledge(side, direction != 0.0):
		return false
	climb_side = side
	facing = side
	climb_from_feet = player.position + Vector2(13.0, 54.0)
	climb_end_feet = _climb_point(HoodManifest.CLIPS["climb"]["end_feet"])
	var clip_data: Dictionary = HoodManifest.CLIPS["climb"]
	climb_total = float(clip_data["frames"]) / float(clip_data["fps"])
	climb_snap = float(clip_data["lead_frames"]) / float(clip_data["fps"])
	# The reach starts from the frame that looks most like the air pose he is in (a table of the build: the jump clips and the climb
	# come from different videos); the picture then carries on from that frame instead of cutting to the first one.
	climb_lead_start = 0
	climb_bridge_left = 0.0
	climb_bridge_total = 0.0
	var from_air: Dictionary = clip_data.get("from_air", {})
	var air_clip := String(hood_actor.current_clip)
	if from_air.has(air_clip):
		var air_table: Array = from_air[air_clip]
		climb_lead_start = int(air_table[clampi(hood_actor.current_frame_index, 0, air_table.size() - 1)])
	# the bridge: in-between frames from the air frame he is in to the reach frame the climb carries on from (grab_bridge, a table of
	# the build); without it (another clip, or no bridge clip) the climb starts straight from the matching frame
	var bridge_data: Dictionary = HoodManifest.CLIPS.get("grab_bridge", {})
	if bridge_data.has("bridge_start") and Dictionary(bridge_data["bridge_start"]).has(air_clip):
		var starts: Array = bridge_data["bridge_start"][air_clip]
		var leads: Array = bridge_data["bridge_lead"][air_clip]
		var at := clampi(hood_actor.current_frame_index, 0, starts.size() - 1)
		climb_bridge_start = int(starts[at])
		climb_lead_start = int(leads[at])
		climb_bridge_total = float(int(bridge_data["bridge_frames"])) / float(bridge_data["fps"])
		climb_bridge_left = climb_bridge_total
	climb_start_t = float(climb_lead_start) / float(int(clip_data["frames"]) - 1) * climb_total
	climb_time = climb_start_t
	climb_v0 = climb_prev_velocity.limit_length(260.0)
	player.velocity = Vector2.ZERO
	player.collision_mask = 0
	jump_buffer = 0.0
	jump_windup_left = 0.0
	coyote = 0.0
	return true

func _end_climb(landed: bool) -> void:
	climb_time = -1.0
	climb_bridge_left = 0.0
	climb_cooldown = 0.45
	climb_land_grace = 0.15 if landed else 0.0
	player.collision_mask = 11
	player.velocity = Vector2.ZERO if landed else Vector2(-climb_side * 40.0, 60.0)
	if landed:
		# on whatever is really under his feet there now (the rope-hung deck may have swayed a little)
		var end_feet := climb_end_feet
		var hit := _climb_ray(end_feet + Vector2(0.0, -26.0), end_feet + Vector2(0.0, 26.0))
		if not hit.is_empty() and absf(float(hit.position.y) - end_feet.y) < 24.0:
			end_feet.y = float(hit.position.y)
		player.position = end_feet - Vector2(13.0, 54.0)

func _update_climb(delta: float) -> void:
	if climb_bridge_left > 0.0:
		climb_bridge_left = maxf(0.0, climb_bridge_left - delta)
	else:
		climb_time += delta
	var direction := Input.get_axis("move_left", "move_right")
	if climb_bridge_left <= 0.0 and climb_time < climb_snap + CLIMB_LET_GO_TIME and direction * climb_side < -0.5:
		_end_climb(false)
		return
	if climb_time >= climb_total:
		_end_climb(true)
		return
	player.position = _climb_feet() - Vector2(13.0, 54.0)
	player.velocity = Vector2.ZERO

func _launch_jump(jump_scale: float) -> void:
	if rock_shove_index >= 0:
		# Slipping out of the shove: the boulder rolls on beneath for a moment.
		rock_immune = 1.0
		_end_rock_shove()
	player.velocity.y = -595.0 * jump_scale
	jump_buffer = 0.0
	coyote = 0.0
	dragging = false
	puzzle_box_dragging = false

func _present(delta: float) -> void:
	# Collision can alternate vx between zero and walking speed. A cancelled
	# release must not resume when the player touches the sliding crate again.
	if release_time > 0.0 and (not player.is_on_floor() or absf(player.velocity.x) >= 30.0 or pickup_time > 0.0 or fan_swing > 0.0):
		release_time = 0.0
	_select_actor()
	var action: StringName = Pose.ACTION_NONE
	var progress := 0.0
	var cliff_pose: Dictionary = cliff.pose_info()
	if death_time > 0.0:
		action = Drown.CLIP
		progress = clampf(death_time / Drown.DURATION,0.0,1.0)
	elif marsh_hit_time > 0.0:
		if marsh_hit_kind == "fall":
			action = Pose.ACTION_FALL_IMPACT if marsh_hit_time < 0.542 else Pose.ACTION_DOWNED
			progress = clampf(marsh_hit_time / 0.542, 0.0, 1.0) if marsh_hit_time < 0.542 else clampf((marsh_hit_time - 0.542) / 1.0, 0.0, 1.0)
		elif marsh_hit_kind == "crush":
			action = Pose.ACTION_DOWNED
			progress = clampf(marsh_hit_time / 1.25, 0.0, 1.0)
		elif marsh_hit_kind == "rock":
			action = Pose.ACTION_KNOCKDOWN
			progress = clampf(marsh_hit_time / 1.05, 0.0, 1.0)
		elif marsh_hit_kind == "pit" or marsh_hit_time >= 0.28:
			action = Pose.ACTION_UNCONTROLLED_FALL
			progress = clampf(marsh_hit_time / 1.3, 0.0, 1.0)
		else:
			action = Pose.ACTION_HIT
			progress = clampf(marsh_hit_time / 0.28, 0.0, 1.0)
	elif rock_lock_time > 0.0:
		# Frozen in fright: the first frames of the knockdown clip, where the eye flares wide, held
		# with a small tremor (the same look as when the crow strikes on the cliff).
		action = Pose.ACTION_KNOCKDOWN
		progress = 0.11 + 0.05 * (0.5 + 0.5 * sin(clock * 17.0))
	elif rock_shove_index >= 0:
		action = &"push"
	elif cliff_pose.action != Pose.ACTION_NONE:
		action = cliff_pose.action
		progress = cliff_pose.progress
	elif pickup_time > 0.0 and not airborne_pickup:
		action = Pose.ACTION_PICKUP
		progress = 1.0 - pickup_time / pickup_total
	elif put_down_time > 0.0:
		action = Pose.ACTION_PUT_DOWN
		progress = 1.0 - put_down_time / put_down_total
	elif fan_swing > 0.0:
		action = Pose.ACTION_THROW_RELEASE
		progress = 1.0 - fan_swing / fan_swing_total
	elif dragging and rope_stage == 1:
		action = &"rope_pickup"
		progress = 1.0 - rope_pick_time / ROPE_PICK_TIME
	elif dragging:
		if grip_time > 0.0:
			action = &"grip_engage"
			progress = 1.0 - grip_time / GRIP_TIME
		elif absf(crate_motion) < 0.05:
			action = &"grip_hold"
		else:
			action = &"pull" if crate_motion * facing < 0.0 else &"push"
	elif puzzle_box_dragging:
		if grip_time > 0.0:
			action = &"grip_engage"
			progress = 1.0 - grip_time / GRIP_TIME
		elif absf(puzzle_box_motion) < 0.05:
			action = &"grip_hold"
		else:
			action = &"pull" if puzzle_box_motion * facing < 0.0 else &"push"
	elif release_time > 0.0:
		action = &"grip_release"
		progress = 1.0 - release_time / RELEASE_TIME
	var pose_feet := player.position + Vector2(13, 54)
	if climb_time >= 0.0:
		# the clip's own root is the ledge corner: it is what is placed (see _climb_root)
		action = Pose.ACTION_CLIMB
		progress = clampf(climb_time / climb_total, 0.0, 1.0)
		pose_feet = _climb_root()
	pose.apply({
		"feet": pose_feet,
		"velocity": Vector2.ZERO if climb_time >= 0.0 else player.velocity, "grounded": climb_time < 0.0 and (player.is_on_floor() or is_riding()) and marsh_hit_time <= 0.0,
		"facing": facing, "action": action, "action_progress": progress,
		"equipment": Pose.EQUIPMENT_THROWABLE if (fan_owned or cliff_pose.equipment == Pose.EQUIPMENT_THROWABLE) else Pose.EQUIPMENT_NONE,
		"small_item_kind": &"fan" if fan_owned else (_cliff_item_kind(cliff_pose)),
		"small_item_radius": CliffAct.STONE_VISUAL_RADIUS * HOOD_STONE_SCALE if ActorStyleHost.style_override == Pose.STYLE_HOOD else 11.0,
		"aim_angle": cliff_pose.aim, "effort": cliff_pose.effort, "aiming": cliff.charging,
		"monochrome": false, "visual_scale": ACTOR_VISUAL_SCALE,
		"shoved": rock_shove_index >= 0, "alarm": rock_lock_time > 0.0,
		"jump_windup": (1.0 - jump_windup_left / Pose.HOOD_JUMP_WINDUP) if jump_windup_left > 0.0 else -1.0,
		"grab_frame": (climb_bridge_start + mini(int((1.0 - climb_bridge_left / climb_bridge_total) * float(int(HoodManifest.CLIPS["grab_bridge"]["bridge_frames"]))), int(HoodManifest.CLIPS["grab_bridge"]["bridge_frames"]) - 1)) if (climb_time >= 0.0 and climb_bridge_left > 0.0 and climb_bridge_total > 0.0) else -1,
		# The ink stage softens every edge of the land by a pixel or two; the actor gets the same, so the
		# character does not look cut out and pasted onto it.
		"fog_blur": ACTOR_EDGE_SOFTNESS,
	})
	actor.grip_distance = grip_distance
	# hands on the boat's stem (the outermost 3 px of the post, 5 px inside the physical edge) or on the box's upright
	var on_boat := dragging or (not puzzle_box_dragging and grip_is_crate)
	actor.set("contact_reach", (GRIP_REACH - CRATE_CONTACT_INSET - 3.0) if on_boat else PUZZLE_BOX_GRIP_REACH)
	actor.set("contact_sink", 2.0 if on_boat else 4.0)
	actor.set("rope_allowed", grip_is_crate)
	actor.set("rope_hold", rope_hold)
	actor.set("squash", lerpf(1.0, 0.2, smoothstep(0.0, 0.12, marsh_hit_time)) if (marsh_hit_kind == "crush" and marsh_hit_time > 0.0) else 1.0)
	actor.set("fan_ground_target", fan_rest_position())
	actor.sync_pose(delta, pose)
	if death_time > 0.0:
		var sink := smoothstep(Drown.STRUGGLE,Drown.DURATION,death_time)
		var surface_y := WATER_Y + 26.0 + sin(death_time*8.0)*2.0*(1.0-sink)
		actor.position.y = lerpf(pose.feet.y,surface_y,smoothstep(0.0,0.36,death_time)) + sink*76.0
		actor.modulate.a = 1.0 - smoothstep(0.78,1.0,sink)
	else:
		climb_land_grace = maxf(0.0, climb_land_grace - delta)
		actor.apply_surface_contact(delta, player, pose.grounded or climb_land_grace > 0.0)
		actor.modulate.a = marsh_actor_alpha()
		var drop_target := HOOD_RIDE_DROP if (actor == hood_actor and is_riding() and pose.grounded) else 0.0
		ride_drop = move_toward(ride_drop, drop_target, 70.0 * delta)
		actor.position.y += ride_drop
	fan.visible = fan_owned and death_time <= 0.0 and marsh_hit_time <= 0.0 and not dragging and not puzzle_box_dragging
	fan.set_swing_pose(progress if fan_swing > 0.0 else 0.0)
	if actor.has_method("drive_fan"):
		# the hooded boy places the fan from his own clips (rod while picking up / swinging / putting down, else his hand)
		actor.call("drive_fan", fan, FAN_SCALE)
	else:
		fan.position = actor.fan_hand_position()
		fan.scale = Vector2(facing,1.0)*FAN_SCALE
		fan.rotation = facing * actor.fan_swing_angle() if fan_swing > 0.0 else facing * 0.9
		fan.z_index = actor.z_index - 1 if actor.current_clip == &"fan_swing" else actor.z_index + 1
		if pickup_time > 0.0:
			var pickup_progress := 1.0-pickup_time/pickup_total
			var transfer := smoothstep(0.0,0.65,pickup_progress)
			fan.position = fan_handoff_origin.lerp(fan.position,transfer)
			fan.rotation = lerp_angle(fan_handoff_rotation,facing*0.9,transfer)
		elif put_down_time > 0.0:
			var transfer := smoothstep(0.0,1.0,progress)
			fan.position = fan_handoff_origin.lerp(fan.position,smoothstep(0.0,0.25,progress)).lerp(fan_rest_position(),transfer)
			fan.rotation = lerp_angle(facing*0.9,fan_ground_facing*1.35,transfer)
	fan.queue_redraw()
	# The first time the fan is drawn the renderer has to build what draws it, which stalls a frame or two: it is drawn once,
	# invisibly, at the start, so that the first real pick-up is as smooth as the rest.
	if fan_warmup > 0:
		fan_warmup -= 1
		fan.visible = true
		fan.modulate.a = 0.01
		fan.global_position = camera.position
		fan.scale = Vector2.ONE * FAN_SCALE
	else:
		fan.modulate.a = 1.0
	rope_art.visible = actor == hood_actor
	if rope_art.visible:
		rope_art.queue_redraw()
	cliff.hand_world = actor.fan_hand_position()
	cliff.lever_hand_driven = actor == hood_actor and cliff_pose.action == &"lever"
	if cliff.lever_hand_driven:
		cliff.lever_hand_world = actor.call("grip_hand_world")
	_sync_stone_nodes()
	if fade_rect != null:
		fade_rect.color.a = cliff.fade
	if iris == null:
		iris = ScreenIris.new()
		add_child(iris)
	var camera_origin := camera.position - Vector2(640.0, 360.0)
	iris.call("set_state", _curtain_alpha(), player.position + PLAYER_SIZE * 0.5 - camera_origin)
	art.sync(delta, camera_x, true)
	marsh_art.sync(delta, camera_x, true)
	if debug_visible:
		debug_label.text = "C / CONTINUOUS   |   %s\nPLAYER %.0f, %.0f   RAFT %.0f, %.0f   BOX %.0f\nFAN %s   HIT %s   CHECKPOINT %d" % ["COMPLETE" if completed else "PLAY", player.position.x, player.position.y, crate.position.x, crate.position.y, puzzle_box.position.x, fan_owned, marsh_hit_kind, checkpoint]

# A boat or a box is heavy: for the hooded boy, whose push and pull clips are a laboured step, the object moves
# (and he with it) at a labouring pace instead of the walking pace the previous actor's art was timed for.
const HOOD_BOAT_SPEED := 80.0
const HOOD_BOX_SPEED := 70.0

func _boat_speed() -> float:
	return HOOD_BOAT_SPEED if ActorStyleHost.style_override == Pose.STYLE_HOOD else 126.0

func _box_speed() -> float:
	return HOOD_BOX_SPEED if ActorStyleHost.style_override == Pose.STYLE_HOOD else 108.0

func _grip_settled() -> bool:
	return grip_time <= 0.0 and rope_stage != 1

func _update_rope_mode(delta: float, direction: float) -> void:
	var hood := ActorStyleHost.style_override == Pose.STYLE_HOOD
	var active := hood and dragging and grip_is_crate
	if not active:
		rope_stage = 0
		rope_direct = false
		rope_pick_time = 0.0
		rope_mode = false
		rope_extra = 0.0
		rope_hold = move_toward(rope_hold, 0.0, 2.0 * delta)
		return
	rope_side = -facing
	match rope_stage:
		0:
			# moving away from the boat with his hands on it: he takes the rope up first
			if grip_time <= 0.0 and direction != 0.0 and direction * facing < 0.0:
				rope_stage = 1
				rope_pick_time = ROPE_PICK_TIME - (ROPE_LET_GO_TIME if rope_direct else 0.0)
				rope_direct = false
		1:
			rope_pick_time = maxf(0.0, rope_pick_time - delta)
			if rope_pick_time <= 0.0:
				rope_stage = 2
		2:
			# moving back towards it: the rope is dropped and his hands go back to the hull
			if direction != 0.0 and direction * facing > 0.0:
				rope_stage = 0
	rope_mode = rope_stage == 2
	rope_extra = move_toward(rope_extra, ROPE_EXTRA if rope_mode else 0.0, delta * 110.0)
	match rope_stage:
		1:
			var done := 1.0 - rope_pick_time / ROPE_PICK_TIME
			rope_hold = smoothstep(0.77, 1.0, done)
		2:
			rope_hold = 1.0
		_:
			rope_hold = move_toward(rope_hold, 0.0, 2.0 * delta)

# One rope is tied to each end of the boat. Hanging, it falls from the post and lies on the ground; as he takes it up it
# lifts to his hand (rope_blend of the clip), and pulling it is straight.
func _draw_ropes() -> void:
	var centre := crate.position + CRATE_SIZE * 0.5
	var held_blend := 0.0
	var hand := Vector2.ZERO
	if actor == hood_actor:
		held_blend = rope_hold
		hand = actor.call("grip_hand_world")
	for s: float in [-1.0, 1.0]:
		var attach := centre + Vector2(s * (CRATE_SIZE.x * 0.5 + 2.0), -CRATE_SIZE.y * 0.5 - 13.0).rotated(crate_tilt)
		var rest_x := attach.x
		var rest := Vector2(rest_x, minf(ground_y(rest_x), centre.y + CRATE_SIZE.y * 0.5 + 6.0) - 3.0)
		var blend := held_blend if is_equal_approx(s, rope_side) else 0.0
		var free := rest.lerp(hand, blend)
		var slack_control := Vector2(attach.x + s * 5.0, rest.y - 2.0)
		var taut_control := attach.lerp(free, 0.5) + Vector2(0.0, 5.0)
		var control := slack_control.lerp(taut_control, blend)
		var points := PackedVector2Array()
		for i in range(15):
			var t := float(i) / 14.0
			points.append(attach.lerp(control, t).lerp(control.lerp(free, t), t))
		rope_art.draw_polyline(points, ROPE_INK, 2.8, true)
		rope_art.draw_circle(free, 2.6, ROPE_INK)

# The actor is chosen by ActorStyleHost.style_override (the hooded boy; there is no key that switches it).
# The previous actor shows a carried stone with the fan's one-hand art, so the cliff act calls it "fan". The hooded boy
# draws the stone himself only while aiming and throwing; carried, picked up and put down, the cliff's own stone node
# follows his hand.
func _cliff_item_kind(cliff_pose: Dictionary) -> StringName:
	if ActorStyleHost.style_override != Pose.STYLE_HOOD:
		return cliff_pose.kind
	if cliff_pose.action in [Pose.ACTION_THROW_CHARGE, Pose.ACTION_THROW_RELEASE]:
		return &"ink_stone"
	return &""

func _fail_restore() -> void:
	if ActorStyleHost.style_override != Pose.STYLE_HOOD:
		restore_checkpoint()
		return
	if curtain_phase == 0:
		curtain_phase = 1
		curtain_time = 0.0

func _update_curtain(delta: float) -> void:
	if curtain_phase == 1:
		curtain_time += delta
		if curtain_time >= CURTAIN_CLOSE:
			curtain_phase = 2
			curtain_time = 0.0
			restore_checkpoint()
	elif curtain_phase == 2:
		curtain_time += delta
		if curtain_time >= CURTAIN_OPEN:
			curtain_phase = 0

func _curtain_alpha() -> float:
	if curtain_phase == 1:
		return smoothstep(0.0, CURTAIN_CLOSE, curtain_time)
	if curtain_phase == 2:
		return 1.0 - smoothstep(0.0, CURTAIN_OPEN, curtain_time)
	return 0.0

func _select_actor() -> void:
	var wanted: Node2D = hood_actor if ActorStyleHost.style_override == Pose.STYLE_HOOD else legacy_actor
	if wanted == actor:
		return
	actor.hide()
	actor = wanted
	actor.show()
	actor.call("reset_grip_animation")
	art.crate_art.queue_redraw()  # the raft has end posts for the hooded boy

func _sync_stone_nodes() -> void:
	for index in range(stone_nodes.size()):
		var info: Dictionary = cliff.stone_state(index)
		var node := stone_nodes[index]
		var state: int = info.state
		var in_hand: bool = state == CliffAct.Stone.HELD or state == CliffAct.Stone.PICKUP or state == CliffAct.Stone.PUTDOWN
		# While aiming or throwing, the actor's own two-handed frames carry the stone.
		var hidden: bool = state == CliffAct.Stone.THROWN_PENDING or (state == CliffAct.Stone.HELD and cliff.charging)
		node.visible = not hidden and death_time <= 0.0 and not (in_hand and marsh_hit_time > 0.0)
		node.position = info.position
		if ActorStyleHost.style_override == Pose.STYLE_HOOD and state == CliffAct.Stone.STACKED:
			# drawn smaller, the three stones of the pile would stand apart: pull them in about the slab so they touch
			var anchor: Vector2 = cliff.stack_pos(0) + Vector2(CliffAct.STONE_RADIUS * 1.25, 11.0)
			node.position = anchor + (Vector2(info.position) - anchor) * HOOD_STONE_SCALE
		node.rotation = 0.0 if in_hand else float(info.angle)
		# The stone's belly is a little shallower than its collision circle and the ground's soft edge
		# eats another pixel or two, so a stone at rest would look as if it hovered. Seat it in the ground.
		if state == CliffAct.Stone.REST or state == CliffAct.Stone.STACKED:
			node.position.y += STONE_SEAT_DEPTH
			# The top stone rests on the two below it, which have just sunk: follow them down.
			if state == CliffAct.Stone.STACKED and index == 4:
				node.position.y += STONE_SEAT_DEPTH * 0.7
		# A stone at rest is half sunk in the ground: behind the ink, so the ground's edge covers its foot.
		node.z_index = 7 if in_hand else (0 if (state == CliffAct.Stone.REST or state == CliffAct.Stone.STACKED) else 4)
		node.modulate.a = float(info.alpha)
		stone_scales[index] = HOOD_STONE_SCALE if ActorStyleHost.style_override == Pose.STYLE_HOOD else 1.0
		node.scale = Vector2.ONE * stone_scales[index]

# The lift has reached the cliff top and the screen has gone dark: hand over to the next scene.
func _act_finished() -> void:
	completed = true
	if return_to_debug_menu and not hosted_in_level:
		_return_to_debug()

func debug_enter_cliff_act() -> void:
	debug_return_index = 5
	checkpoint = 4
	checkpoint_fan = false
	restore_checkpoint()
	player.velocity = Vector2.ZERO
	fan_owned = false
	fan_on_tree = false
	fan_revealed = false
	landed = true
	beached = true
	floating = false
	intro_time = 0.0
	camera_x = clampf(player.position.x - 525.0, 0.0, WORLD_WIDTH - 1280.0)
	camera.position = Vector2(camera_x + 640.0, 360.0)
	_present(0.0)

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade_rect)
	debug_label = Label.new()
	debug_label.position = Vector2(24, 20)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	debug_label.hide()
	layer.add_child(debug_label)
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(pause_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(shade)
	var column := VBoxContainer.new()
	column.position = Vector2(520, 250)
	column.size = Vector2(240, 200)
	column.add_theme_constant_override("separation", 18)
	pause_panel.add_child(column)
	for title in ["继续", "回到岸边", "重置第一幕"]:
		var button := Button.new()
		button.text = title
		button.custom_minimum_size = Vector2(240, 44)
		column.add_child(button)
		button.pressed.connect(func():
			if title == "回到岸边": restore_checkpoint()
			if title == "重置第一幕": reset_all()
			_set_paused(false)
		)
	pause_panel.hide()

func _set_paused(value: bool) -> void:
	paused = value
	pause_panel.visible = value
	if value:
		pause_panel.get_child(1).get_child(0).grab_focus()
