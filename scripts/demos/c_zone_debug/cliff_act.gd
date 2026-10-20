extends Node2D

const ActorStyleHostRef = preload("res://scripts/actors/actor_style_host.gd")

# Third act of the C zone: the broken drawbridge and the cliff lift.
#
# Stones lie about. F picks one up; a tap puts it down again, and holding F aims (arrow keys or
# W/S tilt the throw) and lets go to throw it, with exactly the speeds, gravity and trajectory
# preview of the first chapter. Two puzzles decide the act:
#   1. the drawbridge is held upright by a rope from a gallows on the far bank; a stone through
#      that rope drops the bridge across the gas pit;
#   2. on the far side a cage hangs from a pulley far overhead. The rope's other end is pinned to
#      the ground under a pyramid of three stones, so the cage cannot come down. Carry the stones
#      off one by one (the top one first) and the cage drops, in steps. Once it is down, step in
#      and pump the lever beside the post: each swing hoists the cage a little way and it sinks
#      back if you stop. It docks at the top, far above the first screen, level with a slope that
#      climbs away: walk up it and the way on opens.

const Pose = preload("res://scripts/actors/actor_pose_state.gd")
const Palette = preload("res://scripts/shared/inkfall_palette.gd")

signal finished_act

# ---- geometry (world space) -----------------------------------------------------------------
const PIT := Vector2(6150.0, 6410.0)
const BRIDGE_HINGE := Vector2(6148.0, 394.0)
const BRIDGE_LENGTH := 262.0
const BRIDGE_RAISED := 1.22
const BRIDGE_THICK := 16.0
const BRIDGE_ANCHOR := Vector2(6404.0, 56.0)
const LIFT_X := 6972.0
const LIFT_W := 100.0
const LIFT_REST_Y := 390.0
# Ground to the upper station: a long way up, far past the top of the first screen.
const LIFT_TRAVEL := 700.0
# How high the cage hangs while the pin still holds n stones (index n): the first stone to go
# drops it into view, the last brings it to the ground.
const LIFT_STAGE: Array[float] = [0.0, 150.0, 330.0, 700.0]
const LIFT_HEIGHT := 108.0
const LIFT_PUMP := 120.0
const LIFT_PUMP_COOLDOWN := 0.5
const LIFT_PUMP_TIME := 0.42
# The cliff face the lift runs along, and the slope that begins level with the docked cage.
const CLIFF_X := 7072.0
const DOCK_Y := LIFT_REST_Y - LIFT_TRAVEL
const RAMP_RUN := 368.0
const RAMP_RISE := 190.0
const EXIT_X := 7412.0
# The pin: a slab on the ground with a pyramid of three stones on it.
const STACK_X := 6905.0
const SLAB_H := 8.0
const WORLD_END := 7520.0

# A bridge that takes weight: it dips under whoever stands on it (most in the middle), bobs with
# every footstep and kicks harder when someone lands on it.
const BRIDGE_SAG := 8.0
const BRIDGE_SAG_MAX := 14.0
const BRIDGE_SPRING := 150.0
const BRIDGE_DAMP := 6.0
const BRIDGE_STEP := 62.0
const BRIDGE_STEP_KICK := 24.0
const STONE_RADIUS := 10.0
const STONE_REACH := 60.0
const STONE_VISUAL_RADIUS := 12.0
const ROPE_HIT := 13.0
const HANDOFF_TIME := 0.31
const RELEASE_TIME := 0.34
const LAUNCH_DELAY := 0.10
# The hooded boy's clips (small_pickup 0 -> 52, put down 65 -> 30, throw swing 8 -> 28):
const HOOD_PICKUP_TIME := 0.87
const HOOD_PUT_TIME := 0.60
const HOOD_LAUNCH_DELAY := 0.15  # the swing's release frame
const AIM_MIN := -1.42
const AIM_MAX := -0.05
const AIM_START := -0.82

enum Bridge { RAISED, FALLING, DOWN }
enum Lift { PINNED, LOWERING, LANDED, RISING, ARRIVED }
enum Stone { REST, FLY, PICKUP, HELD, PUTDOWN, THROWN_PENDING, STACKED }

var level: Node2D
var clock := 0.0
var stones: Array[Dictionary] = []
var carrying := -1
var charging := false
var hold := 0.0
var aim := AIM_START
var pickup_time := 0.0
var pickup_total := HANDOFF_TIME  # the hooded boy's crouch is longer: the totals follow the actor style
var put_total := HANDOFF_TIME
var put_time := 0.0
var release_time := 0.0
var release_delay := 0.0
var pending_velocity := Vector2.ZERO
var active_index := -1
var hand_world := Vector2.ZERO

var bridge_state := Bridge.RAISED
var bridge_angle := BRIDGE_RAISED
var bridge_omega := 0.0
var bridge_time := 0.0
var bridge_body: AnimatableBody2D
var bridge_sag := 0.0
var bridge_sag_speed := 0.0
var bridge_u := 0.5
var bridge_on := false
var bridge_step_phase := 0.0
var bridge_step_count := 0
var prev_air_vy := 0.0
var bridge_shape: CollisionShape2D
var rope_swing := 0.0
var rope_swing_speed := 0.0

var stack_left := 3
var lift_state := Lift.PINNED
var lift_s := LIFT_TRAVEL
var lift_target := 0.0
var lift_speed := 0.0
var since_pump := 9.0
var below_wait := 0.0
var lever_time := 0.0
var lever_cool := 0.0
var lever_dir := 1.0
var lever_s := 1.0
var lever_grace := 0.0
# The hooded boy's hands close on the stick: the controller gives the stick the point his hand is at, and the stick is
# drawn through it (instead of the hands being drawn near a stick that moves on its own).
var lever_hand_driven := false
var lever_hand_world := Vector2.ZERO
var lift_body: AnimatableBody2D
var fade := 0.0
var finished := false

var events: Array[Dictionary] = []

func _ready() -> void:
	bridge_body = AnimatableBody2D.new()
	bridge_body.collision_layer = 1
	bridge_body.collision_mask = 0
	bridge_body.sync_to_physics = true
	bridge_shape = CollisionShape2D.new()
	var plank := RectangleShape2D.new()
	plank.size = Vector2(PIT.y - BRIDGE_HINGE.x + 2.0, BRIDGE_THICK)
	bridge_shape.shape = plank
	bridge_shape.position = Vector2(BRIDGE_HINGE.x - 1.0 + plank.size.x * 0.5, BRIDGE_HINGE.y - 2.0 + BRIDGE_THICK * 0.5)
	bridge_body.add_child(bridge_shape)
	add_child(bridge_body)
	lift_body = AnimatableBody2D.new()
	lift_body.collision_layer = 1
	lift_body.collision_mask = 0
	lift_body.sync_to_physics = true
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(LIFT_W, 14.0)
	floor_shape.shape = floor_rect
	lift_body.add_child(floor_shape)
	add_child(lift_body)
	# A solid cliff face; at the top it turns into a slope that climbs away.
	var cliff := StaticBody2D.new()
	cliff.collision_layer = 1
	cliff.collision_mask = 0
	var cliff_shape := CollisionPolygon2D.new()
	var outline := PackedVector2Array([Vector2(CLIFF_X, 900.0)])
	var sample := CLIFF_X
	while sample < CLIFF_X + RAMP_RUN:
		outline.append(Vector2(sample, ramp_y(sample)))
		sample += 16.0
	outline.append(Vector2(CLIFF_X + RAMP_RUN, DOCK_Y - RAMP_RISE))
	outline.append(Vector2(WORLD_END + 200.0, DOCK_Y - RAMP_RISE))
	outline.append(Vector2(WORLD_END + 200.0, 900.0))
	cliff_shape.polygon = outline
	cliff.add_child(cliff_shape)
	add_child(cliff)
	_build_stones()
	reset(false)

# The slope's contour: it eases off the dock, climbs, and eases out again to level ground, so it is a
# hillside and not a ruled line. Collision and drawing share it.
static func ramp_y(x: float) -> float:
	var t := clampf((x - CLIFF_X) / RAMP_RUN, 0.0, 1.0)
	return DOCK_Y - RAMP_RISE * (0.55 * t + 0.45 * smoothstep(0.0, 1.0, t))

func _stone_homes() -> Array[Vector2]:
	var homes: Array[Vector2] = []
	for x in [6004.0, 6034.0, 6650.0, 6680.0, 6710.0]:
		homes.append(Vector2(x, _ground_y(x) - STONE_RADIUS - 1.0))
	return homes

# Where stack stone i sits on the slab: two side by side below, one on top between them.
func stack_pos(i: int) -> Vector2:
	var slab_top := _ground_y(STACK_X) - SLAB_H
	var base := slab_top - 11.0
	match i:
		0: return Vector2(STACK_X - 12.5, base)
		1: return Vector2(STACK_X + 12.5, base)
		_: return Vector2(STACK_X + 0.5, base - 21.5)

# The stone that may be lifted next: the top one while it is there, then either of the two below.
func top_stack_index() -> int:
	if int(stones[4]["state"]) == Stone.STACKED:
		return 4
	return -1

func stack_liftable(index: int) -> bool:
	if int(stones[index]["state"]) != Stone.STACKED:
		return false
	return index == 4 or int(stones[4]["state"]) != Stone.STACKED

func _ground_y(x: float) -> float:
	for profile in level.MARSH_LANDS:
		var p: PackedVector2Array = profile
		if x >= p[0].x and x <= p[p.size() - 1].x:
			for i in range(p.size() - 1):
				if x <= p[i + 1].x:
					return lerpf(p[i].y, p[i + 1].y, clampf((x - p[i].x) / maxf(p[i + 1].x - p[i].x, 0.001), 0.0, 1.0))
	return 400.0

func _build_stones() -> void:
	var homes := _stone_homes()
	for index in range(homes.size()):
		var body := CharacterBody2D.new()
		body.collision_layer = 16
		body.collision_mask = 1
		body.safe_margin = 0.08
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = STONE_RADIUS
		shape.shape = circle
		body.add_child(shape)
		add_child(body)
		stones.append({
			"body": body, "home": homes[index], "state": Stone.REST, "vel": Vector2.ZERO,
			"angle": float(index) * 1.3, "spin": 0.0, "seed": 90 + index * 7, "flash": 0.0, "alpha": 1.0,
		})

# ---- reset -----------------------------------------------------------------------------------
# keep_bridge: a respawn at the bank must not undo a bridge the player already dropped.
func reset(keep_bridge: bool) -> void:
	carrying = -1
	charging = false
	hold = 0.0
	aim = AIM_START
	pickup_time = 0.0
	put_time = 0.0
	release_time = 0.0
	release_delay = 0.0
	active_index = -1
	fade = 0.0
	finished = false
	events.clear()
	if not (keep_bridge and bridge_state == Bridge.DOWN):
		bridge_state = Bridge.RAISED
		bridge_angle = BRIDGE_RAISED
		bridge_omega = 0.0
	rope_swing = 0.0
	rope_swing_speed = 0.0
	bridge_sag = 0.0
	bridge_sag_speed = 0.0
	bridge_on = false
	bridge_step_phase = 0.0
	if bridge_body != null:
		bridge_body.transform = Transform2D.IDENTITY
	if bridge_shape != null:
		bridge_shape.set_deferred("disabled", bridge_state != Bridge.DOWN)
	stack_left = 3
	lift_state = Lift.PINNED
	lift_s = LIFT_TRAVEL
	lift_target = 0.0
	lift_speed = 0.0
	since_pump = 9.0
	below_wait = 0.0
	lever_time = 0.0
	lever_cool = 0.0
	lever_dir = 1.0
	lever_s = 1.0
	lever_grace = 0.0
	_place_lift()
	for index in range(stones.size()):
		var stone: Dictionary = stones[index]
		stone["vel"] = Vector2.ZERO
		stone["flash"] = 0.0
		stone["alpha"] = 1.0
		var body: CharacterBody2D = stone["body"]
		body.collision_mask = 1
		if index >= 2:
			stone["state"] = Stone.STACKED
			stone["angle"] = (float(index - 2) - 1.0) * 0.14
			body.collision_mask = 0
			body.position = stack_pos(index - 2)
		else:
			stone["state"] = Stone.REST
			body.position = stone["home"]

# ---- lookups used by the controller and the art -------------------------------------------------
func bridge_tip() -> Vector2:
	return BRIDGE_HINGE + Vector2(cos(bridge_angle), -sin(bridge_angle)) * BRIDGE_LENGTH

func cage_top() -> float:
	return LIFT_REST_Y - lift_s

# The lever is a floor lever by the right post, the kind you crouch to and rock back and forth. The
# player is drawn to the stand spot while pumping, so the grip frames' low, forward hands close on
# the stick; the stick is drawn through those hands.
func lever_pivot() -> Vector2:
	return Vector2(LIFT_X + LIFT_W - 14.0, cage_top() - 4.0)

func lever_stand_x() -> float:
	return LIFT_X + LIFT_W - 14.0 - 46.0

# Where the hands are at stroke s (+1 pushed away, -1 pulled in): about 16 up and 31 ahead of the feet.
func lever_hand() -> Vector2:
	return Vector2(lever_stand_x() + 31.0 + 14.0 * lever_s, cage_top() - 16.0)

# Standing in the cage by the lever, with the cage down on the ground or on its way up.
func lever_usable() -> bool:
	if stack_left > 0 or lift_state == Lift.ARRIVED:
		return false
	var feet_x: float = level.player.position.x + 13.0
	return on_cage() and absf(feet_x - lever_stand_x()) < 48.0

func on_cage() -> bool:
	var player: CharacterBody2D = level.player
	var feet: Vector2 = player.position + Vector2(13.0, 54.0)
	return absf(feet.y - cage_top()) < 9.0 and feet.x > LIFT_X + 6.0 and feet.x < LIFT_X + LIFT_W - 6.0 and player.is_on_floor()

func _hood() -> bool:
	return ActorStyleHostRef.style_override == Pose.STYLE_HOOD

func release_origin() -> Vector2:
	return level.player.position + Vector2(13.0 + float(level.facing) * 16.0, 16.0)

func throw_speed() -> float:
	var ratio := clampf((hold - Palette.THROW_HOLD_THRESHOLD) / 0.82, 0.0, 1.0)
	return lerpf(Palette.THROW_MIN_SPEED, Palette.THROW_MAX_SPEED, ratio)

func throw_velocity() -> Vector2:
	return Vector2(float(level.facing) * cos(aim), sin(aim)).normalized() * throw_speed()

func locks_move() -> bool:
	return charging or pickup_time > 0.0 or put_time > 0.0 or release_time > 0.0 or lever_time > 0.0

func stone_state(index: int) -> Dictionary:
	var stone: Dictionary = stones[index]
	var body: CharacterBody2D = stone["body"]
	return {
		"state": int(stone["state"]), "position": body.position, "angle": float(stone["angle"]),
		"seed": int(stone["seed"]), "flash": float(stone["flash"]), "alpha": float(stone["alpha"]),
	}

# What the player pose should look like this frame. kind &"fan" borrows the single-hand carry
# frames (the held stone is then drawn at the hand by the controller); throwing uses the original
# two-handed frames, which bring their own stone.
func pose_info() -> Dictionary:
	var info := {"action": Pose.ACTION_NONE, "progress": 0.0, "kind": &"", "equipment": Pose.EQUIPMENT_NONE, "aim": aim, "effort": 0.0, "hand_stone": false}
	if charging:
		info.action = Pose.ACTION_THROW_CHARGE
		info.progress = clampf(hold, 0.0, 1.0)
		info.kind = &"ink_stone"
		info.equipment = Pose.EQUIPMENT_THROWABLE
		info.effort = clampf(hold, 0.0, 1.0)
	elif release_time > 0.0:
		info.action = Pose.ACTION_THROW_RELEASE
		info.progress = 1.0 - release_time / RELEASE_TIME
		info.kind = &"ink_stone"
		info.equipment = Pose.EQUIPMENT_THROWABLE
	elif pickup_time > 0.0:
		info.action = Pose.ACTION_PICKUP
		info.progress = 1.0 - pickup_time / pickup_total
		info.kind = &"fan"
		info.equipment = Pose.EQUIPMENT_THROWABLE
		info.hand_stone = true
	elif put_time > 0.0:
		info.action = Pose.ACTION_PUT_DOWN
		info.progress = 1.0 - put_time / put_total
		info.kind = &"fan"
		info.equipment = Pose.EQUIPMENT_THROWABLE
		info.hand_stone = true
	elif lever_grace > 0.0:
		# Leaning in and out with the stick: the reach frames of the grip clip, between upright and crouched.
		if _hood():
			# his own stroke: 0 = pushed away (arms out), 1 = pulled in (the transition clip between the two stances)
			info.action = &"lever"
			info.progress = (1.0 - lever_s) * 0.5
		else:
			info.action = &"grip_engage"
			info.progress = lerpf(0.52, 1.0, (lever_s + 1.0) * 0.5)
	elif carrying >= 0:
		info.kind = &"fan"
		info.equipment = Pose.EQUIPMENT_THROWABLE
		info.hand_stone = true
	return info

# ---- input ---------------------------------------------------------------------------------------
# Returns true when F (or an aim key) was used up here, so the older interactions stay out of it.
func interact(direction: float, delta: float) -> bool:
	if finished or pickup_time > 0.0 or put_time > 0.0 or release_time > 0.0:
		return pickup_time > 0.0 or put_time > 0.0 or release_time > 0.0
	if charging:
		# Q cancels the throw: the stone stays in the hand and F must be pressed again to re-aim.
		if Input.is_action_just_pressed("throw_cancel"):
			charging = false
			hold = 0.0
			aim = AIM_START
			return true
		# Letting go throws exactly what the preview showed on the previous frame.
		if not Input.is_action_pressed("interact"):
			_release()
			return true
		# Up/Down arrows or W/S tilt the throw.
		var tilt := Input.get_axis("aim_up", "aim_down")
		if Input.is_physical_key_pressed(KEY_W):
			tilt -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			tilt += 1.0
		aim = clampf(aim + clampf(tilt, -1.0, 1.0) * 1.55 * delta, AIM_MIN, AIM_MAX)
		hold = minf(1.0, hold + delta)
		if direction != 0.0:
			level.facing = signf(direction)
		return true
	if carrying >= 0:
		if Input.is_action_just_pressed("interact") and level.player.is_on_floor():
			charging = true
			hold = 0.0
			return true
		return false
	if Input.is_action_just_pressed("interact") and level.player.is_on_floor():
		var index := _nearest_rest_stone()
		if index < 0 and lever_usable() and lever_cool <= 0.0:
			_pump()
			return true
		if index >= 0:
			var stone: Dictionary = stones[index]
			var body: CharacterBody2D = stone["body"]
			if int(stone["state"]) == Stone.STACKED:
				# Lifting a stone off the pin lets the rope slip: the cage sinks a third of the way.
				stack_left -= 1
				events.append({"kind": "stack_pull", "pos": body.position, "left": stack_left})
				level.camera_shake = maxf(level.camera_shake, 0.9)
			stone["state"] = Stone.PICKUP
			stone["from"] = body.position
			body.collision_mask = 0
			active_index = index
			pickup_total = HOOD_PICKUP_TIME if _hood() else HANDOFF_TIME
			pickup_time = pickup_total
			var toward := signf(body.position.x - (level.player.position.x + 13.0))
			if toward != 0.0:
				level.facing = toward
			return true
	return false

func _nearest_rest_stone() -> int:
	var center: Vector2 = level.player.position + Vector2(13.0, 40.0)
	var best := -1
	var best_distance := STONE_REACH
	for index in range(stones.size()):
		var stone: Dictionary = stones[index]
		var state: int = stone["state"]
		# On the pin only the top of the pyramid can be lifted, and then the two below.
		if state != Stone.REST and not stack_liftable(index):
			continue
		var distance := center.distance_to((stone["body"] as CharacterBody2D).position)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best

func _pump() -> void:
	lever_time = LIFT_PUMP_TIME
	lever_grace = LIFT_PUMP_TIME + 0.4
	lever_cool = LIFT_PUMP_COOLDOWN
	lever_dir = -lever_dir
	since_pump = 0.0
	lift_target = minf(LIFT_TRAVEL, lift_target + LIFT_PUMP)
	level.facing = 1.0
	events.append({"kind": "lever_pump", "pos": lever_pivot() + Vector2(0.0, 8.0)})
func _release() -> void:
	charging = false
	var stone: Dictionary = stones[carrying]
	if hold < Palette.THROW_HOLD_THRESHOLD:
		# Only a tap: put it down at the feet.
		stone["state"] = Stone.PUTDOWN
		(stone["body"] as CharacterBody2D).collision_mask = 0
		stone["to"] = level.player.position + Vector2(13.0 + float(level.facing) * 26.0, 54.0 - STONE_RADIUS - 2.0)
		active_index = carrying
		put_total = HOOD_PUT_TIME if _hood() else HANDOFF_TIME
		put_time = put_total
	else:
		stone["state"] = Stone.THROWN_PENDING
		active_index = carrying
		pending_velocity = throw_velocity()
		release_time = RELEASE_TIME
		release_delay = HOOD_LAUNCH_DELAY if _hood() else LAUNCH_DELAY
	carrying = -1
	hold = 0.0

# ---- per-frame update ----------------------------------------------------------------------------
func tick(delta: float) -> void:
	clock += delta
	_update_bridge(delta)
	_update_lift(delta)
	_update_handoffs(delta)
	for index in range(stones.size()):
		_update_stone(index, delta)
	_update_rope_swing(delta)

func _update_handoffs(delta: float) -> void:
	var player: CharacterBody2D = level.player
	if pickup_time > 0.0:
		pickup_time = maxf(0.0, pickup_time - delta)
		if pickup_time == 0.0 and active_index >= 0:
			stones[active_index]["state"] = Stone.HELD
			carrying = active_index
			active_index = -1
	if put_time > 0.0:
		put_time = maxf(0.0, put_time - delta)
		if put_time == 0.0 and active_index >= 0:
			var stone: Dictionary = stones[active_index]
			var body: CharacterBody2D = stone["body"]
			body.position = stone["to"]
			body.collision_mask = 1
			stone["vel"] = Vector2.ZERO
			stone["state"] = Stone.FLY
			active_index = -1
	if release_time > 0.0:
		release_time = maxf(0.0, release_time - delta)
		if release_delay > 0.0:
			release_delay = maxf(0.0, release_delay - delta)
			if release_delay == 0.0 and active_index >= 0:
				var stone: Dictionary = stones[active_index]
				var body: CharacterBody2D = stone["body"]
				body.position = release_origin()
				body.collision_mask = 1
				stone["vel"] = pending_velocity
				stone["spin"] = float(level.facing) * 9.0
				stone["state"] = Stone.FLY
				active_index = -1

func _update_stone(index: int, delta: float) -> void:
	var stone: Dictionary = stones[index]
	var body: CharacterBody2D = stone["body"]
	stone["flash"] = maxf(0.0, float(stone["flash"]) - delta * 2.0)
	var state: int = stone["state"]
	if state == Stone.STACKED:
		body.position = stack_pos(index - 2)
		return
	if state == Stone.HELD:
		body.position = hand_world if hand_world != Vector2.ZERO else release_origin()
		return
	var hand := hand_world if hand_world != Vector2.ZERO else release_origin()
	if state == Stone.PICKUP:
		var p := 1.0 - pickup_time / pickup_total
		body.position = Vector2(stone["from"]).lerp(hand, smoothstep(0.0, 0.75 if _hood() else 0.65, p))
		return
	if state == Stone.PUTDOWN:
		var p := 1.0 - put_time / put_total
		body.position = hand.lerp(Vector2(stone["to"]), smoothstep(0.1, 0.77, p) if _hood() else smoothstep(0.15, 1.0, p))
		return
	if state == Stone.THROWN_PENDING:
		body.position = hand
		return
	if state == Stone.REST:
		# Still held up by something? A cage or bridge may have moved away.
		if not body.test_move(body.global_transform, Vector2(0.0, 2.0)):
			stone["state"] = Stone.FLY
			stone["vel"] = Vector2.ZERO
		return
	var vel: Vector2 = stone["vel"]
	var from := body.position
	vel.y += Palette.GRAVITY * delta
	var collision := body.move_and_collide(vel * delta)
	_check_ropes(index, from, body.position, vel)
	if collision != null:
		var normal := collision.get_normal()
		vel = vel.bounce(normal) * 0.30
		vel -= (vel - normal * vel.dot(normal)) * 0.10
		stone["spin"] = float(stone["spin"]) * 0.6
		if vel.length() > 120.0:
			events.append({"kind": "stone_hit", "pos": collision.get_position(), "power": vel.length()})
		if vel.length() < 55.0 and normal.y < -0.45:
			vel = Vector2.ZERO
			stone["state"] = Stone.REST
			stone["spin"] = 0.0
	stone["angle"] = float(stone["angle"]) + float(stone["spin"]) * delta
	stone["vel"] = vel
	if body.position.y > 760.0 or body.position.x < 0.0 or body.position.x > WORLD_END + 60.0:
		events.append({"kind": "stone_lost", "pos": Vector2(clampf(body.position.x, 0.0, WORLD_END), minf(body.position.y, 620.0))})
		body.position = stone["home"]
		stone["state"] = Stone.REST
		stone["vel"] = Vector2.ZERO
		stone["flash"] = 1.0

# ---- ropes ---------------------------------------------------------------------------------------
func _segment_distance(p1: Vector2, p2: Vector2, q1: Vector2, q2: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(p1, p2, q1, q2) != null:
		return 0.0
	var best := 1.0e9
	best = minf(best, p1.distance_to(Geometry2D.get_closest_point_to_segment(p1, q1, q2)))
	best = minf(best, p2.distance_to(Geometry2D.get_closest_point_to_segment(p2, q1, q2)))
	best = minf(best, q1.distance_to(Geometry2D.get_closest_point_to_segment(q1, p1, p2)))
	best = minf(best, q2.distance_to(Geometry2D.get_closest_point_to_segment(q2, p1, p2)))
	return best

func _check_ropes(index: int, from: Vector2, to: Vector2, vel: Vector2) -> void:
	if vel.length() < 30.0:
		return
	if bridge_state == Bridge.RAISED and _segment_distance(from, to, bridge_tip(), BRIDGE_ANCHOR) <= ROPE_HIT:
		var hit := Geometry2D.get_closest_point_to_segment(to, bridge_tip(), BRIDGE_ANCHOR)
		events.append({"kind": "rope_snap", "pos": hit})
		bridge_state = Bridge.FALLING
		bridge_omega = 0.05
		bridge_time = 0.0
		rope_swing_speed = 2.2
		level.camera_shake = maxf(level.camera_shake, 1.0)
		return

func _update_rope_swing(delta: float) -> void:
	rope_swing_speed += (-rope_swing * 38.0 - rope_swing_speed * 1.6) * delta
	rope_swing = clampf(rope_swing + rope_swing_speed * delta, -1.0, 1.0)

# ---- bridge --------------------------------------------------------------------------------------
func _update_bridge(delta: float) -> void:
	if bridge_state == Bridge.DOWN:
		_update_bridge_sway(delta)
		return
	if bridge_state != Bridge.FALLING:
		return
	bridge_time += delta
	bridge_omega += (3.0 * Palette.GRAVITY / (2.0 * BRIDGE_LENGTH)) * cos(bridge_angle) * delta * 0.55
	bridge_angle -= bridge_omega * delta
	if bridge_angle <= 0.0:
		bridge_angle = 0.0
		var speed := bridge_omega
		events.append({"kind": "bridge_thud", "pos": Vector2(BRIDGE_HINGE.x + BRIDGE_LENGTH, BRIDGE_HINGE.y), "power": speed})
		level.camera_shake = maxf(level.camera_shake, clampf(speed * 0.9, 1.6, 3.4))
		if speed > 0.9:
			bridge_omega = -speed * 0.2
		else:
			bridge_omega = 0.0
			bridge_state = Bridge.DOWN
			bridge_shape.set_deferred("disabled", false)

func bridge_dip_at(x: float) -> float:
	return bridge_sag * sin(PI * clampf((x - BRIDGE_HINGE.x) / BRIDGE_LENGTH, 0.0, 1.0))

func _update_bridge_sway(delta: float) -> void:
	var player: CharacterBody2D = level.player
	var feet: Vector2 = player.position + Vector2(13.0, 54.0)
	var u := clampf((feet.x - BRIDGE_HINGE.x) / BRIDGE_LENGTH, 0.0, 1.0)
	var deck_y := BRIDGE_HINGE.y - 2.0 + bridge_sag * sin(PI * bridge_u)
	var on: bool = player.is_on_floor() and feet.x > BRIDGE_HINGE.x + 4.0 and feet.x < BRIDGE_HINGE.x + BRIDGE_LENGTH - 4.0 and absf(feet.y - deck_y) < 10.0
	var target := 0.0
	if on:
		bridge_u = u
		var shape := sin(PI * u)
		target = BRIDGE_SAG * shape
		if not bridge_on:
			# Landing: the harder the fall, the harder the kick.
			bridge_sag_speed += (clampf(prev_air_vy, 0.0, 700.0) * 0.05 + 8.0) * shape
			events.append({"kind": "bridge_creak", "pos": Vector2(feet.x, deck_y + 14.0), "power": 1.0})
		var speed := absf(player.velocity.x)
		if speed > 60.0:
			bridge_step_phase += speed * delta / BRIDGE_STEP
			if bridge_step_phase >= 1.0:
				bridge_step_phase -= 1.0
				bridge_step_count += 1
				bridge_sag_speed += BRIDGE_STEP_KICK * shape
				if bridge_step_count % 3 == 0:
					events.append({"kind": "bridge_creak", "pos": Vector2(feet.x, deck_y + 14.0), "power": 0.5})
		else:
			bridge_step_phase = 0.0
	else:
		bridge_step_phase = 0.0
	bridge_on = on
	if not player.is_on_floor():
		prev_air_vy = player.velocity.y
	bridge_sag_speed += ((target - bridge_sag) * BRIDGE_SPRING - BRIDGE_DAMP * bridge_sag_speed) * delta
	bridge_sag = clampf(bridge_sag + bridge_sag_speed * delta, -3.0, BRIDGE_SAG_MAX)
	bridge_body.transform = Transform2D(0.0, Vector2(0.0, bridge_sag * sin(PI * bridge_u)))

# ---- lift ----------------------------------------------------------------------------------------
func _place_lift() -> void:
	if lift_body != null:
		lift_body.transform = Transform2D(0.0, Vector2(LIFT_X + LIFT_W * 0.5, cage_top() + 7.0))

func _update_lift(delta: float) -> void:
	lever_cool = maxf(0.0, lever_cool - delta)
	lever_time = maxf(0.0, lever_time - delta)
	since_pump += delta
	lever_grace = maxf(0.0, lever_grace - delta)
	lever_s = lerpf(lever_s, lever_dir, 1.0 - exp(-11.0 * delta))
	if lever_grace > 0.0 and on_cage():
		# Step up to the stick and hold still while working it.
		var p: CharacterBody2D = level.player
		p.position.x = move_toward(p.position.x, lever_stand_x() - 13.0, 240.0 * delta)
		p.velocity.x = 0.0
	var player: CharacterBody2D = level.player
	var aboard := on_cage()
	var previous_state: int = lift_state
	# Where the cage wants to be. While stones lie on the pin, it can only come down a third at a time.
	var goal := 0.0
	if stack_left > 0:
		goal = LIFT_STAGE[stack_left]
	else:
		var docked: bool = lift_s >= LIFT_TRAVEL - 1.0 and lift_target >= LIFT_TRAVEL - 0.5
		if docked:
			# Docked at the top. If the player went down to the ground instead, it lowers again.
			var below: bool = player.position.y + 54.0 > 330.0 and player.position.x < CLIFF_X + 10.0
			below_wait = below_wait + delta if below else 0.0
			if below_wait > 1.5:
				lift_target = LIFT_TRAVEL - 1.0
		elif lift_target > 0.0 and since_pump > 0.8:
			# Let go of the lever and the weight of the cage drags it back down.
			lift_target = maxf(0.0, lift_target - (70.0 if aboard else 160.0) * delta)
		goal = lift_target
		if lift_s >= LIFT_TRAVEL - 1.0 and below_wait > 1.5:
			lift_target = maxf(0.0, lift_target - 160.0 * delta)
	var difference := goal - lift_s
	var limit := (300.0 if difference < 0.0 else 190.0) * delta
	var step := clampf(difference * (1.0 - exp(-3.6 * delta)), -limit, limit)
	if absf(difference) < 0.35:
		step = difference
	lift_s = clampf(lift_s + step, 0.0, LIFT_TRAVEL)
	lift_speed = step / maxf(delta, 0.0001)
	# State follows from the stack and the pumped height.
	if stack_left == 3:
		lift_state = Lift.PINNED
	elif stack_left > 0:
		lift_state = Lift.LOWERING
	elif lift_target <= 0.0:
		lift_state = Lift.LANDED if lift_s <= 0.5 else Lift.LOWERING
	elif lift_s >= LIFT_TRAVEL - 1.0 and lift_target >= LIFT_TRAVEL - 0.5:
		lift_state = Lift.ARRIVED
	else:
		lift_state = Lift.RISING
	if lift_state == Lift.LANDED and previous_state == Lift.LOWERING:
		events.append({"kind": "lift_thud", "pos": Vector2(LIFT_X + LIFT_W * 0.5, LIFT_REST_Y), "power": 1.0})
		level.camera_shake = maxf(level.camera_shake, 2.4)
	if lift_state == Lift.ARRIVED and previous_state != Lift.ARRIVED:
		events.append({"kind": "lift_thud", "pos": Vector2(LIFT_X + LIFT_W * 0.5, DOCK_Y), "power": 0.5})
		level.camera_shake = maxf(level.camera_shake, 1.2)
	_place_lift()
	# Climbing the slope to its crest hands over to the next scene.
	if lift_state == Lift.ARRIVED and not finished:
		var exiting: bool = player.is_on_floor() and player.position.x + 13.0 > EXIT_X
		fade = minf(1.0, fade + delta / 1.4) if exiting else maxf(0.0, fade - delta / 0.8)
		if fade >= 1.0:
			finished = true
			level.completed = true
			finished_act.emit()

func lift_shiver() -> float:
	# The cage hangs on its rope: a slow sway while pinned, a tremble when it moves.
	if absf(lift_speed) > 10.0:
		return sin(clock * 33.0) * 0.8
	return sin(clock * 2.1) * 0.9 if lift_state == Lift.PINNED or lift_state == Lift.LOWERING else 0.0

func take_events() -> Array[Dictionary]:
	var taken: Array[Dictionary] = events.duplicate()
	events.clear()
	return taken

# Predicted path for the aiming preview: same integrator and constants as the real throw, stopping
# at terrain. Returns {"points": PackedVector2Array, "rope": bool}.
func preview_path() -> Dictionary:
	var points := PackedVector2Array()
	var vel := throw_velocity()
	var pos := release_origin()
	var space := get_world_2d().direct_space_state
	var cuts_rope := false
	for step in range(1, 140):
		var previous := pos
		vel.y += Palette.GRAVITY / 60.0
		pos += vel / 60.0
		var query := PhysicsRayQueryParameters2D.create(previous, pos, 1)
		var hit := space.intersect_ray(query)
		if bridge_state == Bridge.RAISED and _segment_distance(previous, pos, bridge_tip(), BRIDGE_ANCHOR) <= ROPE_HIT:
			cuts_rope = true
		if not hit.is_empty():
			points.append(hit.position)
			break
		points.append(pos)
		if pos.y > 700.0 or cuts_rope:
			break
	return {"points": points, "rope": cuts_rope}
