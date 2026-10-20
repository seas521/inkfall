extends Node2D

const Palette = preload("res://scripts/shared/inkfall_palette.gd")
const CinematicDepthArt = preload("res://scripts/art/cinematic_depth_art.gd")
const CinematicLightArt = preload("res://scripts/art/cinematic_light_art.gd")
const CinematicForegroundArt = preload("res://scripts/art/cinematic_foreground_art.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")

const SCREEN := Palette.SCREEN
const PLAYER_SIZE := Palette.PLAYER_SIZE

const PLATFORMS: Array[Rect2] = [
	Rect2(-60.0, 560.0, 760.0, 180.0),
	Rect2(770.0, 522.0, 345.0, 218.0),
	Rect2(1190.0, 575.0, 455.0, 165.0),
	Rect2(1725.0, 505.0, 385.0, 235.0),
	Rect2(2185.0, 550.0, 500.0, 190.0),
	Rect2(2760.0, 480.0, 520.0, 260.0),
	Rect2(470.0, 430.0, 132.0, 18.0),
	Rect2(1370.0, 445.0, 120.0, 18.0),
	Rect2(2350.0, 410.0, 140.0, 18.0),
]

const LAMP_RIGS: Array[Vector3] = [
	Vector3(190.0, 116.0, 560.0),
	Vector3(990.0, 92.0, 522.0),
	Vector3(1910.0, 104.0, 505.0),
	Vector3(2935.0, 74.0, 480.0),
]

const SHIELD_STATION := Vector2(930.0, 522.0)
const BLADE_STATION := Vector2(1885.0, 505.0)
const CRATE_SIZE := Vector2(76.0, 66.0)
const CRATE_SPAWN := Vector2(2960.0, 414.0)
const CRATE_LIMITS := Vector2(2785.0, 3185.0)
const SMALL_ITEM_SPECS := [
	{"kind": &"orb", "radius": 8.0, "x": 180.0},
	{"kind": &"stone", "radius": 13.0, "x": 235.0},
	{"kind": &"wood", "radius": 14.0, "x": 290.0},
	{"kind": &"scrap", "radius": 13.0, "x": 345.0},
	{"kind": &"bottle", "radius": 13.0, "x": 400.0},
	{"kind": &"key", "radius": 13.0, "x": 455.0},
]

var game_context
var host
var ui_font: Font
var depth_art: Node2D
var light_art: Node2D
var foreground_art: Node2D
var elapsed := 0.0
var safe_position := Vector2(135.0, 506.0)
var room := 9
var actor_equipment: StringName = ActorPoseState.EQUIPMENT_NONE
var actor_action: StringName = ActorPoseState.ACTION_NONE
var actor_action_elapsed := 0.0
var actor_action_duration := 0.0
var action_hold_time := 0.0
var aim_angle := -0.72
var push_distance := 0.0
var shield_input_active := false
var shield_impact_time := 0.0
var shield_bolt_cooldown := 1.25
var shield_bolt_active := false
var shield_bolt_position := Vector2.ZERO
var small_items: Array[Dictionary] = []
var held_small_item_index := -1
var active_small_item_index := -1
var throwable_kind: StringName = &"orb"
var throwable_radius := 8.0
var crate_position := CRATE_SPAWN
var damage_test_index := 0
var damage_restore_equipment: StringName = ActorPoseState.EQUIPMENT_NONE
var blade_sheathe_target: StringName = ActorPoseState.EQUIPMENT_NONE
var blade_owned := false

var player_position: Vector2:
	get: return game_context.player_position
	set(value): game_context.player_position = value
var player_velocity: Vector2:
	get: return game_context.player_velocity
	set(value): game_context.player_velocity = value
var camera_axis: float:
	get: return game_context.camera_axis
	set(value): game_context.camera_axis = value

func _ready() -> void:
	depth_art = CinematicDepthArt.new()
	depth_art.show_behind_parent = true
	add_child(depth_art)
	light_art = CinematicLightArt.new()
	light_art.show_behind_parent = true
	add_child(light_art)
	foreground_art = CinematicForegroundArt.new()
	add_child(foreground_art)
	hide()

func enter(context, font: Font, game_host) -> void:
	game_context = context
	ui_font = font
	host = game_host
	show()
	reset()

func leave() -> void:
	hide()
	depth_art.hide()
	light_art.hide()
	foreground_art.hide()

func reset() -> void:
	player_position = Vector2(135.0, 506.0)
	player_velocity = Vector2.ZERO
	game_context.on_ground = false
	game_context.regular_jump_active = false
	camera_axis = 0.0
	safe_position = player_position
	elapsed = 0.0
	actor_equipment = ActorPoseState.EQUIPMENT_NONE
	actor_action = ActorPoseState.ACTION_NONE
	actor_action_elapsed = 0.0
	actor_action_duration = 0.0
	action_hold_time = 0.0
	aim_angle = -0.72
	push_distance = 0.0
	shield_input_active = false
	shield_impact_time = 0.0
	shield_bolt_cooldown = 1.25
	shield_bolt_active = false
	small_items.clear()
	for spec in SMALL_ITEM_SPECS:
		var radius := float(spec["radius"])
		var spawn := Vector2(float(spec["x"]), _floor_y_at(float(spec["x"])) - radius)
		small_items.append({
			"kind": StringName(spec["kind"]),
			"radius": radius,
			"spawn": spawn,
			"position": spawn,
			"velocity": Vector2.ZERO,
			"state": &"waiting",
			"draw_delay": 0.0,
		})
	held_small_item_index = -1
	active_small_item_index = -1
	throwable_kind = &"orb"
	throwable_radius = 8.0
	crate_position = CRATE_SPAWN
	damage_test_index = 0
	damage_restore_equipment = ActorPoseState.EQUIPMENT_NONE
	blade_sheathe_target = ActorPoseState.EQUIPMENT_NONE
	blade_owned = false
	depth_art.show()
	light_art.show()
	foreground_art.show()
	queue_redraw()

func restart_current() -> void:
	player_position = safe_position
	player_velocity = Vector2.ZERO
	game_context.on_ground = false
	game_context.regular_jump_active = false
	if _is_damage_action(actor_action):
		actor_equipment = damage_restore_equipment
		_set_actor_action(ActorPoseState.ACTION_NONE)
	camera_axis = clampf(player_position.x - 390.0, 0.0, 1980.0)
	queue_redraw()

func physics_tick(delta: float) -> void:
	elapsed += delta
	_advance_actor_action(delta)
	var action_movement_locked := _actor_action_locks_movement()
	if action_movement_locked:
		player_velocity.x = 0.0
	host.update_shared_player(
		game_context,
		delta,
		PLATFORMS,
		Vector2(-20.0, 3300.0),
		not action_movement_locked
	)
	_update_motion_lab(delta)
	if _actor_action_locks_movement():
		player_velocity.x = 0.0
	_update_small_items(delta)
	_update_shield_bolt(delta)
	var target_camera := clampf(player_position.x - 390.0 + player_velocity.x * 0.06, 0.0, 1980.0)
	camera_axis = lerpf(camera_axis, target_camera, 1.0 - exp(-5.8 * delta))
	if game_context.on_ground and absf(player_velocity.y) < 1.0:
		safe_position = player_position
	if player_position.y > 790.0:
		restart_current()
	depth_art.sync(delta, camera_axis, true)
	light_art.sync(delta, camera_axis, true)
	foreground_art.sync(delta, camera_axis, true)
	queue_redraw()

func sync_environment(_env_fx: Node2D) -> void:
	pass

func presentation_state() -> Dictionary:
	var actor_screen_x := _world_to_screen(player_position + PLAYER_SIZE * 0.5).x
	return {
		"style_id": ActorPoseState.STYLE_CROOKED_TOWER,
		"feet": _world_to_screen(player_position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y)),
		"velocity": player_velocity,
		"grounded": game_context.on_ground,
		"facing": game_context.player_facing,
		"held": -1,
		"aiming": false,
		"room": room,
		"failure_time": 0.0,
		"failure_duration": 0.8,
		"equipment": actor_equipment,
		"action": actor_action,
		"action_progress": _actor_action_progress(),
		"aim_angle": aim_angle,
		"effort": _actor_effort(),
		"impact": clampf(shield_impact_time / 0.18, 0.0, 1.0),
		"light_exposure": _lamp_exposure_at(actor_screen_x),
		"small_item_kind": throwable_kind,
		"small_item_radius": throwable_radius,
		"camera_axis": camera_axis,
		"cavern_foreground": false,
	}

func _set_actor_action(next_action: StringName, duration: float = 0.0) -> void:
	actor_action = next_action
	actor_action_elapsed = 0.0
	actor_action_duration = duration

func _shield_stance_locks_movement() -> bool:
	if (
		actor_equipment != ActorPoseState.EQUIPMENT_SHIELD
		and actor_equipment != ActorPoseState.EQUIPMENT_SHIELD_BLADE
	):
		return false
	return (
		shield_input_active
		or actor_action == ActorPoseState.ACTION_SHIELD_RAISE
		or actor_action == ActorPoseState.ACTION_SHIELD_GUARD
		or actor_action == ActorPoseState.ACTION_SHIELD_LOWER
		or actor_action == ActorPoseState.ACTION_SHIELD_PARRY
		or actor_action == ActorPoseState.ACTION_SHIELD_BLOCK
	)

func _actor_action_locks_movement() -> bool:
	return (
		_shield_stance_locks_movement()
		or _is_damage_action(actor_action)
		or actor_action == ActorPoseState.ACTION_BLADE_EQUIP
		or actor_action == ActorPoseState.ACTION_BLADE_SWING
		or actor_action == ActorPoseState.ACTION_BLADE_SHEATHE
	)

func _is_damage_action(action: StringName) -> bool:
	return (
		action == ActorPoseState.ACTION_HIT
		or action == ActorPoseState.ACTION_KNOCKDOWN
		or action == ActorPoseState.ACTION_DOWNED
		or action == ActorPoseState.ACTION_GET_UP
		or action == ActorPoseState.ACTION_UNCONTROLLED_FALL
		or action == ActorPoseState.ACTION_FALL_IMPACT
		or action == ActorPoseState.ACTION_FALL_DOWNED
	)

func _advance_actor_action(delta: float) -> void:
	shield_impact_time = maxf(0.0, shield_impact_time - delta)
	if actor_action_duration <= 0.0:
		return
	actor_action_elapsed += delta
	if actor_action_elapsed < actor_action_duration:
		return
	var finished_action := actor_action
	actor_action_elapsed = actor_action_duration
	actor_action_duration = 0.0
	if finished_action == ActorPoseState.ACTION_PUSH_ENGAGE and Input.is_action_pressed("interact"):
		actor_action = ActorPoseState.ACTION_PUSH
	elif finished_action == ActorPoseState.ACTION_SHIELD_BLOCK and shield_input_active and Input.is_action_pressed("shield"):
		actor_action = ActorPoseState.ACTION_SHIELD_GUARD
	elif finished_action == ActorPoseState.ACTION_KNOCKDOWN:
		_set_actor_action(ActorPoseState.ACTION_DOWNED, 1.25)
	elif finished_action == ActorPoseState.ACTION_DOWNED:
		_set_actor_action(ActorPoseState.ACTION_GET_UP, 2.375)
	elif finished_action == ActorPoseState.ACTION_UNCONTROLLED_FALL:
		_set_actor_action(ActorPoseState.ACTION_FALL_IMPACT, 0.542)
	elif finished_action == ActorPoseState.ACTION_FALL_IMPACT:
		_set_actor_action(ActorPoseState.ACTION_FALL_DOWNED)
	elif (
		finished_action == ActorPoseState.ACTION_BLADE_SHEATHE
		or finished_action == ActorPoseState.ACTION_BLADE_SHEATHE_RUN
	):
		actor_equipment = blade_sheathe_target
		actor_action = ActorPoseState.ACTION_NONE
	elif finished_action == ActorPoseState.ACTION_BLADE_SHEATHE_GUARD:
		actor_equipment = ActorPoseState.EQUIPMENT_SHIELD
		actor_action = (
			ActorPoseState.ACTION_SHIELD_GUARD
			if Input.is_action_pressed("shield")
			else ActorPoseState.ACTION_NONE
		)
	elif finished_action == ActorPoseState.ACTION_HIT or finished_action == ActorPoseState.ACTION_GET_UP:
		actor_equipment = damage_restore_equipment
		actor_action = ActorPoseState.ACTION_NONE
	else:
		actor_action = ActorPoseState.ACTION_NONE

func _actor_action_progress() -> float:
	if actor_action_duration > 0.0:
		return clampf(actor_action_elapsed / actor_action_duration, 0.0, 1.0)
	if actor_action == ActorPoseState.ACTION_THROW_CHARGE:
		return clampf(action_hold_time / 0.9, 0.0, 1.0)
	if actor_action == ActorPoseState.ACTION_PUSH:
		return fposmod(push_distance / 34.0, 1.0)
	if actor_action == ActorPoseState.ACTION_SHIELD_GUARD:
		return fposmod(elapsed * 0.36, 1.0)
	return 0.0

func _actor_effort() -> float:
	if actor_action == ActorPoseState.ACTION_THROW_CHARGE:
		return clampf(action_hold_time / 0.9, 0.0, 1.0)
	if actor_action == ActorPoseState.ACTION_PUSH or actor_action == ActorPoseState.ACTION_PUSH_ENGAGE:
		return clampf(0.48 + action_hold_time * 0.55, 0.0, 1.0)
	if actor_action == ActorPoseState.ACTION_SHIELD_GUARD:
		return 0.62
	return 0.0

func _update_motion_lab(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if Input.is_action_just_pressed("damage_test") and _start_damage_test():
		return
	if _try_blade_toggle():
		return
	if _try_push_crate(delta, direction):
		return
	if actor_action == ActorPoseState.ACTION_PUSH or actor_action == ActorPoseState.ACTION_PUSH_ENGAGE:
		action_hold_time = 0.0
		_set_actor_action(ActorPoseState.ACTION_PUSH_RELEASE, 0.18)
	_resolve_crate_overlap()

	if Input.is_action_just_pressed("interact") and _try_equipment_station():
		return
	if actor_equipment == ActorPoseState.EQUIPMENT_THROWABLE:
		_update_throw_action(delta)
	elif actor_equipment == ActorPoseState.EQUIPMENT_SHIELD:
		_update_shield_action(delta)
	elif actor_equipment == ActorPoseState.EQUIPMENT_BLADE:
		_update_blade_action()
	elif actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE:
		_update_shield_action(delta)
		_update_blade_action()
	elif Input.is_action_just_pressed("interact"):
		var nearest_item := _nearest_small_item_index(48.0)
		if nearest_item >= 0:
			var item: Dictionary = small_items[nearest_item]
			held_small_item_index = nearest_item
			active_small_item_index = nearest_item
			throwable_kind = StringName(item["kind"])
			throwable_radius = float(item["radius"])
			item["state"] = &"held"
			small_items[nearest_item] = item
			actor_equipment = ActorPoseState.EQUIPMENT_THROWABLE
			_set_actor_action(ActorPoseState.ACTION_PICKUP, 0.30)

func _try_blade_toggle() -> bool:
	if not Input.is_action_just_pressed("blade_toggle"):
		return false
	if not blade_owned:
		return true
	var moving := absf(player_velocity.x) > 25.0
	if actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE:
		if (
			actor_action != ActorPoseState.ACTION_NONE
			and actor_action != ActorPoseState.ACTION_SHIELD_RAISE
			and actor_action != ActorPoseState.ACTION_SHIELD_GUARD
		):
			return true
		blade_sheathe_target = ActorPoseState.EQUIPMENT_SHIELD
		if (
			shield_input_active
			or Input.is_action_pressed("shield")
			or actor_action == ActorPoseState.ACTION_SHIELD_RAISE
			or actor_action == ActorPoseState.ACTION_SHIELD_GUARD
		):
			shield_input_active = true
			action_hold_time = maxf(action_hold_time, 0.20)
			_set_actor_action(ActorPoseState.ACTION_BLADE_SHEATHE_GUARD, 0.583)
		elif moving:
			_set_actor_action(ActorPoseState.ACTION_BLADE_SHEATHE_RUN, 1.667)
		else:
			_set_actor_action(ActorPoseState.ACTION_BLADE_SHEATHE, 0.625)
		return true
	if actor_equipment == ActorPoseState.EQUIPMENT_SHIELD:
		if actor_action != ActorPoseState.ACTION_NONE or shield_input_active:
			return true
		actor_equipment = ActorPoseState.EQUIPMENT_SHIELD_BLADE
		_set_actor_action(
			ActorPoseState.ACTION_BLADE_DRAW_RUN if moving else ActorPoseState.ACTION_BLADE_EQUIP,
			0.458 if moving else 0.625
		)
		return true
	return true

func _start_damage_test() -> bool:
	if actor_action != ActorPoseState.ACTION_NONE:
		return false
	_drop_carried_throwable()
	damage_restore_equipment = actor_equipment
	actor_equipment = ActorPoseState.EQUIPMENT_NONE
	shield_input_active = false
	shield_bolt_active = false
	player_velocity = Vector2.ZERO
	game_context.regular_jump_active = false
	var player_center_x := player_position.x + PLAYER_SIZE.x * 0.5
	player_position.y = _floor_y_at(player_center_x) - PLAYER_SIZE.y
	game_context.on_ground = true
	match damage_test_index:
		0:
			_set_actor_action(ActorPoseState.ACTION_HIT, 0.583)
		1:
			_set_actor_action(ActorPoseState.ACTION_KNOCKDOWN, 1.417)
		_:
			_set_actor_action(ActorPoseState.ACTION_UNCONTROLLED_FALL, 1.708)
	damage_test_index = (damage_test_index + 1) % 3
	return true

func _try_equipment_station() -> bool:
	if (
		_player_near(SHIELD_STATION, 58.0)
		and actor_equipment != ActorPoseState.EQUIPMENT_SHIELD
		and actor_equipment != ActorPoseState.EQUIPMENT_SHIELD_BLADE
	):
		_drop_carried_throwable()
		actor_equipment = ActorPoseState.EQUIPMENT_SHIELD
		shield_input_active = false
		shield_bolt_cooldown = 0.9
		_set_actor_action(ActorPoseState.ACTION_SHIELD_EQUIP, 0.36)
		return true
	if _player_near(BLADE_STATION, 58.0):
		if (
			actor_equipment == ActorPoseState.EQUIPMENT_BLADE
			or actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE
		):
			if actor_action == ActorPoseState.ACTION_NONE:
				blade_sheathe_target = (
					ActorPoseState.EQUIPMENT_SHIELD
					if actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE
					else ActorPoseState.EQUIPMENT_NONE
				)
				_set_actor_action(ActorPoseState.ACTION_BLADE_SHEATHE, 0.625)
			return true
		if actor_equipment != ActorPoseState.EQUIPMENT_SHIELD:
			return true
		_drop_carried_throwable()
		actor_equipment = ActorPoseState.EQUIPMENT_SHIELD_BLADE
		blade_owned = true
		shield_input_active = false
		shield_bolt_active = false
		_set_actor_action(ActorPoseState.ACTION_BLADE_EQUIP, 0.625)
		return true
	return false

func _drop_carried_throwable() -> void:
	if actor_equipment != ActorPoseState.EQUIPMENT_THROWABLE or held_small_item_index < 0:
		return
	var item: Dictionary = small_items[held_small_item_index]
	var drop_x: float = player_position.x + PLAYER_SIZE.x * 0.5 + game_context.player_facing * 22.0
	item["position"] = Vector2(drop_x, _floor_y_at(drop_x) - float(item["radius"]))
	item["velocity"] = Vector2.ZERO
	item["state"] = &"waiting"
	item["draw_delay"] = 0.0
	small_items[held_small_item_index] = item
	held_small_item_index = -1

func _update_throw_action(delta: float) -> void:
	aim_angle = clampf(
		aim_angle + Input.get_axis("aim_up", "aim_down") * 1.45 * delta,
		-1.34,
		-0.12
	)
	if Input.is_action_just_pressed("interact") and actor_action_duration <= 0.0:
		action_hold_time = 0.0
		_set_actor_action(ActorPoseState.ACTION_THROW_CHARGE)
	if actor_action != ActorPoseState.ACTION_THROW_CHARGE:
		return
	if Input.is_action_pressed("interact"):
		action_hold_time = minf(1.0, action_hold_time + delta)
		return
	var throw_ratio := clampf((action_hold_time - 0.16) / 0.84, 0.0, 1.0)
	if held_small_item_index < 0:
		actor_equipment = ActorPoseState.EQUIPMENT_NONE
		_set_actor_action(ActorPoseState.ACTION_NONE)
		return
	var item: Dictionary = small_items[held_small_item_index]
	var item_radius := float(item["radius"])
	if action_hold_time < 0.16:
		var drop_x: float = player_position.x + PLAYER_SIZE.x * 0.5 + game_context.player_facing * 24.0
		item["position"] = Vector2(drop_x, _floor_y_at(drop_x) - item_radius)
		item["velocity"] = Vector2.ZERO
		item["state"] = &"waiting"
		item["draw_delay"] = 0.28
		small_items[held_small_item_index] = item
		held_small_item_index = -1
		actor_equipment = ActorPoseState.EQUIPMENT_NONE
		_set_actor_action(ActorPoseState.ACTION_PUT_DOWN, 0.28)
		return
	var direction := Vector2(game_context.player_facing * cos(aim_angle), sin(aim_angle)).normalized()
	item["position"] = player_position + Vector2(PLAYER_SIZE.x * 0.5 + game_context.player_facing * 20.0, 20.0)
	item["velocity"] = direction * lerpf(310.0, 620.0, throw_ratio)
	item["state"] = &"thrown"
	item["draw_delay"] = 0.15
	small_items[held_small_item_index] = item
	held_small_item_index = -1
	actor_equipment = ActorPoseState.EQUIPMENT_NONE
	_set_actor_action(ActorPoseState.ACTION_THROW_RELEASE, 0.34)

func _update_shield_action(delta: float) -> void:
	if actor_action_duration > 0.0 and actor_action != ActorPoseState.ACTION_SHIELD_RAISE:
		return
	if Input.is_action_just_pressed("shield"):
		shield_input_active = true
		action_hold_time = 0.0
		_set_actor_action(ActorPoseState.ACTION_SHIELD_RAISE, 0.22)
	if not shield_input_active:
		return
	if Input.is_action_pressed("shield"):
		action_hold_time += delta
		if (
			action_hold_time >= 0.20
			and actor_action != ActorPoseState.ACTION_SHIELD_GUARD
			and actor_action != ActorPoseState.ACTION_SHIELD_BLOCK
		):
			_set_actor_action(ActorPoseState.ACTION_SHIELD_GUARD)
		return
	if action_hold_time < 0.20:
		_set_actor_action(
			ActorPoseState.ACTION_SHIELD_PARRY,
			0.75 if actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE else 1.15
		)
	else:
		_set_actor_action(ActorPoseState.ACTION_SHIELD_LOWER, 0.18)
	shield_input_active = false
	action_hold_time = 0.0

func _update_blade_action() -> void:
	if Input.is_action_just_pressed("interact") and actor_action_duration <= 0.0:
		_set_actor_action(ActorPoseState.ACTION_BLADE_SWING, 0.708)

func _try_push_crate(delta: float, direction: float) -> bool:
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	var crate_rect := Rect2(crate_position, CRATE_SIZE)
	var vertical_overlap := player_rect.end.y > crate_rect.position.y + 5.0 and player_rect.position.y < crate_rect.end.y - 5.0
	var touching_left := absf(player_rect.end.x - crate_rect.position.x) <= 17.0 and direction > 0.1
	var touching_right := absf(player_rect.position.x - crate_rect.end.x) <= 17.0 and direction < -0.1
	if not Input.is_action_pressed("interact") or not vertical_overlap or not (touching_left or touching_right):
		return false
	if actor_action != ActorPoseState.ACTION_PUSH and actor_action != ActorPoseState.ACTION_PUSH_ENGAGE:
		_drop_carried_throwable()
		actor_equipment = ActorPoseState.EQUIPMENT_NONE
		shield_input_active = false
		action_hold_time = 0.0
		_set_actor_action(ActorPoseState.ACTION_PUSH_ENGAGE, 0.16)
	action_hold_time = minf(1.0, action_hold_time + delta)
	var push_speed := lerpf(42.0, 88.0, clampf(action_hold_time / 0.72, 0.0, 1.0))
	var previous_x := crate_position.x
	crate_position.x = clampf(crate_position.x + signf(direction) * push_speed * delta, CRATE_LIMITS.x, CRATE_LIMITS.y)
	var moved := crate_position.x - previous_x
	push_distance += absf(moved)
	if direction > 0.0:
		player_position.x = crate_position.x - PLAYER_SIZE.x
	else:
		player_position.x = crate_position.x + CRATE_SIZE.x
	player_velocity.x = signf(direction) * push_speed
	return true

func _resolve_crate_overlap() -> void:
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	var crate_rect := Rect2(crate_position, CRATE_SIZE)
	if not player_rect.intersects(crate_rect):
		return
	if player_rect.get_center().x <= crate_rect.get_center().x:
		player_position.x = crate_rect.position.x - PLAYER_SIZE.x
	else:
		player_position.x = crate_rect.end.x
	player_velocity.x = 0.0

func _player_near(world_point: Vector2, radius: float) -> bool:
	var player_center := player_position + PLAYER_SIZE * 0.5
	return player_center.distance_to(world_point) <= radius

func _nearest_small_item_index(radius: float) -> int:
	var player_center := player_position + PLAYER_SIZE * 0.5
	var nearest_index := -1
	var nearest_distance := radius
	for index in range(small_items.size()):
		var item: Dictionary = small_items[index]
		if item["state"] != &"waiting" or float(item["draw_delay"]) > 0.0:
			continue
		var distance := player_center.distance_to(Vector2(item["position"]))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index

func _floor_y_at(world_x: float) -> float:
	var nearest_y := 720.0
	for platform in PLATFORMS:
		if world_x >= platform.position.x and world_x <= platform.end.x:
			nearest_y = minf(nearest_y, platform.position.y)
	return nearest_y

func _update_small_items(delta: float) -> void:
	for index in range(small_items.size()):
		var item: Dictionary = small_items[index]
		item["draw_delay"] = maxf(0.0, float(item["draw_delay"]) - delta)
		if item["state"] != &"thrown":
			small_items[index] = item
			continue
		var position := Vector2(item["position"])
		var velocity := Vector2(item["velocity"])
		var radius := float(item["radius"])
		var previous_bottom := position.y + radius
		velocity.y += 980.0 * delta
		position += velocity * delta
		if velocity.y >= 0.0:
			for platform in PLATFORMS:
				var next_bottom := position.y + radius
				if (
					position.x >= platform.position.x
					and position.x <= platform.end.x
					and previous_bottom <= platform.position.y + 4.0
					and next_bottom >= platform.position.y
				):
					position.y = platform.position.y - radius
					velocity = Vector2.ZERO
					item["state"] = &"waiting"
					item["draw_delay"] = 0.0
					break
		if position.y > 790.0 or position.x < -120.0 or position.x > 3400.0:
			position = Vector2(item["spawn"])
			velocity = Vector2.ZERO
			item["state"] = &"waiting"
			item["draw_delay"] = 0.0
		item["position"] = position
		item["velocity"] = velocity
		small_items[index] = item

func _update_shield_bolt(delta: float) -> void:
	if (
		actor_equipment != ActorPoseState.EQUIPMENT_SHIELD
		and actor_equipment != ActorPoseState.EQUIPMENT_SHIELD_BLADE
	):
		shield_bolt_active = false
		shield_bolt_cooldown = 1.0
		return
	shield_bolt_cooldown = maxf(0.0, shield_bolt_cooldown - delta)
	var player_center := player_position + PLAYER_SIZE * 0.5
	if not shield_bolt_active and shield_bolt_cooldown <= 0.0:
		shield_bolt_position = player_center + Vector2(game_context.player_facing * 205.0, -5.0)
		shield_bolt_active = true
	if not shield_bolt_active:
		return
	var travel_direction := signf(player_center.x - shield_bolt_position.x)
	shield_bolt_position.x += travel_direction * 205.0 * delta
	if shield_bolt_position.distance_to(player_center + Vector2(game_context.player_facing * 18.0, -4.0)) <= 27.0:
		shield_bolt_active = false
		shield_bolt_cooldown = 1.35
	elif absf(shield_bolt_position.x - player_center.x) > 260.0:
		shield_bolt_active = false
		shield_bolt_cooldown = 0.8

func _world_to_screen(world_position: Vector2) -> Vector2:
	return world_position - Vector2(camera_axis, 0.0)

func _world_rect_to_screen(world_rect: Rect2) -> Rect2:
	return Rect2(_world_to_screen(world_rect.position), world_rect.size)

func _draw() -> void:
	if game_context == null:
		return
	var actor_center := _world_to_screen(player_position + PLAYER_SIZE * 0.5)
	host.draw_soft_cloud(self, actor_center, Vector2(160.0, 190.0), Color(0.88, 0.91, 0.90, 0.035))
	_draw_interaction_lighting()
	_draw_gameplay_plane()
	_draw_motion_lab_props()
	if game_context.on_ground:
		var feet := _world_to_screen(player_position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y + 2.0))
		var spill_strength := 0.065 + clampf(absf(player_velocity.x) / 285.0, 0.0, 1.0) * 0.018
		host.draw_soft_cloud(self, feet, Vector2(126.0, 21.0), Color(0.74, 0.77, 0.75, spill_strength))
	host.draw_actor_shadow(self, PLATFORMS, player_position, camera_axis)
	_draw_ui()

func _draw_interaction_lighting() -> void:
	for lamp_index in range(LAMP_RIGS.size()):
		var rig: Vector3 = LAMP_RIGS[lamp_index]
		var lamp_x := rig.x - camera_axis
		if lamp_x < -180.0 or lamp_x > SCREEN.x + 180.0:
			continue
		var lamp_y := rig.y
		var pulse := 0.92 + sin(elapsed * (0.62 + float(lamp_index) * 0.07) + lamp_index * 1.9) * 0.055
		draw_line(Vector2(lamp_x, -8.0), Vector2(lamp_x, lamp_y - 8.0), Color(0.0, 0.0, 0.0, 0.88), 3.0, true)
		var shade := PackedVector2Array([
			Vector2(lamp_x - 22.0, lamp_y + 4.0),
			Vector2(lamp_x - 11.0, lamp_y - 8.0),
			Vector2(lamp_x + 11.0, lamp_y - 8.0),
			Vector2(lamp_x + 22.0, lamp_y + 4.0),
		])
		draw_colored_polygon(shade, Color("030405"))
		draw_line(Vector2(lamp_x - 22.0, lamp_y + 4.0), Vector2(lamp_x + 22.0, lamp_y + 4.0), Color(0.42, 0.44, 0.42, 0.22), 1.5, true)
		draw_circle(Vector2(lamp_x, lamp_y + 8.0), 3.0, Color(0.86, 0.88, 0.84, 0.72 * pulse), true, -1.0, true)

func _lamp_exposure_at(screen_x: float) -> float:
	var exposure := 0.0
	for rig in LAMP_RIGS:
		var lamp_screen_x := rig.x - camera_axis
		exposure = maxf(exposure, exp(-pow((screen_x - lamp_screen_x) / 165.0, 2.0)))
	return exposure

func _nearest_lamp_screen_x(screen_x: float) -> float:
	var nearest_x := SCREEN.x * 0.5
	var nearest_distance := INF
	for rig in LAMP_RIGS:
		var lamp_screen_x := rig.x - camera_axis
		var distance := absf(screen_x - lamp_screen_x)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_x = lamp_screen_x
	return nearest_x

func _draw_gameplay_plane() -> void:
	_draw_silhouette_gameplay_plane()

func _draw_silhouette_gameplay_plane() -> void:
	for platform_index in range(PLATFORMS.size()):
		var rect := _world_rect_to_screen(PLATFORMS[platform_index])
		if rect.end.x < -50.0 or rect.position.x > SCREEN.x + 50.0:
			continue
		var suspended := rect.size.y <= 26.0
		if suspended:
			_draw_suspended_supports(rect, platform_index)

		var top_points := PackedVector2Array()
		var samples := maxi(4, int(rect.size.x / (54.0 if suspended else 72.0)))
		for sample_index in range(samples + 1):
			var ratio := float(sample_index) / float(samples)
			var x := lerpf(rect.position.x, rect.end.x, ratio)
			var amplitude := 0.75 if suspended else 3.3
			var uneven := sin(float(sample_index) * 2.37 + float(platform_index) * 1.71) * amplitude
			uneven += sin(float(sample_index) * 5.1 + platform_index) * amplitude * 0.24
			top_points.append(Vector2(x, rect.position.y + uneven))

		var body := PackedVector2Array(top_points)
		var bottom_y := minf(SCREEN.y + 90.0, rect.end.y)
		if suspended:
			body.append(Vector2(rect.end.x - 5.0, bottom_y - 2.0))
			body.append(Vector2(rect.position.x + rect.size.x * 0.66, bottom_y - 5.0))
			body.append(Vector2(rect.position.x + rect.size.x * 0.34, bottom_y - 2.0))
			body.append(Vector2(rect.position.x + 5.0, bottom_y - 4.0))
		else:
			var chunks := maxi(4, int(rect.size.x / 95.0))
			for chunk_index in range(chunks, -1, -1):
				var ratio := float(chunk_index) / float(chunks)
				var depth_variation := fposmod(float(chunk_index) * 17.0 + float(platform_index) * 11.0, 17.0)
				body.append(Vector2(lerpf(rect.position.x, rect.end.x, ratio), bottom_y - depth_variation))

		host.draw_soft_cloud(
			self,
			Vector2(rect.get_center().x + 4.0, rect.position.y + 18.0),
			Vector2(rect.size.x * 1.04, minf(74.0, rect.size.y + 28.0)),
			Color(0.0, 0.0, 0.0, 0.56)
		)
		_draw_feathered_black_shape(body, 4.2 if suspended else 3.2)

		var exposure := _lamp_exposure_at(rect.get_center().x)
		if suspended:
			var cap_radius := minf(6.0, rect.size.y * 0.34)
			draw_circle(Vector2(rect.position.x + 5.0, rect.position.y + 5.0), cap_radius, Color("010202"), true, -1.0, true)
			draw_circle(Vector2(rect.end.x - 5.0, rect.position.y + 5.0), cap_radius, Color("010202"), true, -1.0, true)
		elif exposure > 0.18:
			var reflected_center := Vector2(_nearest_lamp_screen_x(rect.get_center().x), rect.position.y + 7.0)
			host.draw_soft_cloud(self, reflected_center, Vector2(138.0, 20.0), Color(0.68, 0.70, 0.68, 0.026 * exposure))

func _draw_feathered_black_shape(points: PackedVector2Array, radius: float) -> void:
	for ring_index in range(4, 0, -1):
		var ring_radius := radius * float(ring_index) / 4.0
		var alpha := 0.016 + float(4 - ring_index) * 0.008
		for sample_index in range(10):
			var angle := float(sample_index) * TAU / 10.0
			var offset := Vector2(cos(angle), sin(angle)) * ring_radius
			var shifted := PackedVector2Array()
			for point in points:
				shifted.append(point + offset)
			draw_colored_polygon(shifted, Color(0.0, 0.0, 0.0, alpha))
	draw_colored_polygon(points, Color("010202"))

func _draw_suspended_supports(rect: Rect2, platform_index: int) -> void:
	var center_x := rect.get_center().x
	var anchor_y := 92.0 + float(platform_index % 3) * 48.0
	var left_anchor := Vector2(center_x - rect.size.x * 0.24, anchor_y)
	var right_anchor := Vector2(center_x + rect.size.x * 0.22, anchor_y + float(platform_index % 2) * 26.0)
	var left_mount := Vector2(rect.position.x + rect.size.x * 0.20, rect.position.y + 2.0)
	var right_mount := Vector2(rect.position.x + rect.size.x * 0.80, rect.position.y + 2.0)
	_draw_soft_black_line(left_anchor, left_mount, 2.4)
	_draw_soft_black_line(right_anchor, right_mount, 2.4)
	draw_line(left_anchor - Vector2(16.0, 0.0), right_anchor + Vector2(16.0, 0.0), Color("020303"), 8.0, true)
	var brace_y := rect.end.y + 24.0
	_draw_soft_black_line(Vector2(rect.position.x + 12.0, rect.end.y - 2.0), Vector2(center_x, brace_y), 4.0)
	_draw_soft_black_line(Vector2(rect.end.x - 12.0, rect.end.y - 2.0), Vector2(center_x, brace_y), 4.0)

func _draw_soft_black_line(from: Vector2, to: Vector2, width: float) -> void:
	draw_line(from, to, Color(0.0, 0.0, 0.0, 0.10), width + 7.0, true)
	draw_line(from, to, Color(0.0, 0.0, 0.0, 0.24), width + 3.0, true)
	draw_line(from, to, Color("010202"), width, true)

func _draw_motion_lab_props() -> void:
	for item in small_items:
		if item["state"] in [&"waiting", &"thrown"] and float(item["draw_delay"]) <= 0.0:
			_draw_lab_throwable(
				_world_to_screen(Vector2(item["position"])),
				StringName(item["kind"]),
				float(item["radius"])
			)
	_draw_shield_station()
	_draw_blade_station()
	_draw_lab_crate()
	if shield_bolt_active:
		_draw_shield_bolt(_world_to_screen(shield_bolt_position))
	var prompt := _motion_lab_prompt()
	if prompt != "":
		var prompt_position := _world_to_screen(player_position + Vector2(PLAYER_SIZE.x * 0.5, -18.0))
		var text_size := ui_font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)
		var panel := Rect2(prompt_position + Vector2(-text_size.x * 0.5 - 10.0, -22.0), text_size + Vector2(20.0, 28.0))
		draw_rect(panel, Color(0.0, 0.0, 0.0, 0.62))
		draw_string(ui_font, panel.position + Vector2(10.0, 19.0), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.96, 0.68, 0.31, 0.88))

func _draw_lab_throwable(center: Vector2, kind: StringName = &"orb", radius: float = 8.0) -> void:
	if center.x < -30.0 or center.x > SCREEN.x + 30.0:
		return
	match kind:
		&"stone":
			var points := PackedVector2Array([
				center + Vector2(-radius, radius * 0.24),
				center + Vector2(-radius * 0.54, -radius * 0.84),
				center + Vector2(radius * 0.44, -radius),
				center + Vector2(radius, -radius * 0.08),
				center + Vector2(radius * 0.56, radius * 0.82),
				center + Vector2(-radius * 0.48, radius),
			])
			draw_colored_polygon(points, Color("07090a"))
			draw_polyline(points, Color(0.34, 0.36, 0.33, 0.34), maxf(1.4, radius * 0.13), true)
			draw_line(
				center + Vector2(-radius * 0.42, -radius * 0.24),
				center + Vector2(radius * 0.34, -radius * 0.44),
				Color(0.36, 0.38, 0.35, 0.42),
				maxf(1.0, radius * 0.10),
				true
			)
			draw_circle(
				center + Vector2(radius * 0.34, -radius * 0.42),
				maxf(1.2, radius * 0.14),
				Color(0.94, 0.45, 0.11, 0.82),
				true,
				-1.0,
				true
			)
		&"wood":
			var start := center + Vector2(-radius, radius * 0.42)
			var finish := center + Vector2(radius, -radius * 0.42)
			var bundle_offset := Vector2(0.0, radius * 0.34)
			draw_line(start - bundle_offset, finish - bundle_offset, Color("060809"), maxf(5.0, radius * 0.48), true)
			draw_line(start, finish, Color("060809"), maxf(6.0, radius * 0.52), true)
			draw_line(start + bundle_offset, finish + bundle_offset, Color("060809"), maxf(5.0, radius * 0.48), true)
			draw_line(start, finish, Color(0.32, 0.31, 0.27, 0.52), maxf(1.5, radius * 0.14), true)
			draw_line(
				center + Vector2(radius * 0.22, -radius * 0.08),
				center + Vector2(radius * 0.58, -radius * 0.62),
				Color("07090a"),
				maxf(2.4, radius * 0.22),
				true
			)
			draw_circle(
				center + Vector2(-radius * 0.20, radius * 0.08),
				maxf(1.2, radius * 0.13),
				Color(0.91, 0.42, 0.10, 0.78),
				true,
				-1.0,
				true
			)
		&"scrap":
			var points := PackedVector2Array([
				center + Vector2(-radius * 0.92, -radius * 0.48),
				center + Vector2(-radius * 0.28, -radius * 0.72),
				center + Vector2(radius * 0.90, -radius * 0.38),
				center + Vector2(radius * 0.72, radius * 0.62),
				center + Vector2(-radius * 0.54, radius * 0.56),
			])
			draw_colored_polygon(points, Color("060809"))
			draw_polyline(points, Color(0.33, 0.36, 0.34, 0.36), maxf(1.4, radius * 0.13), true)
			draw_line(
				center + Vector2(-radius * 0.45, -radius * 0.30),
				center + Vector2(radius * 0.48, radius * 0.30),
				Color(0.34, 0.38, 0.36, 0.48),
				maxf(1.5, radius * 0.14),
				true
			)
			draw_circle(
				center + Vector2(radius * 0.42, radius * 0.20),
				maxf(1.2, radius * 0.13),
				Color(0.93, 0.44, 0.11, 0.82),
				true,
				-1.0,
				true
			)
		&"bottle":
			var body := PackedVector2Array([
				center + Vector2(-radius * 0.70, -radius * 0.28),
				center + Vector2(-radius * 0.40, -radius * 0.58),
				center + Vector2(radius * 0.40, -radius * 0.58),
				center + Vector2(radius * 0.70, -radius * 0.28),
				center + Vector2(radius * 0.62, radius * 0.82),
				center + Vector2(-radius * 0.62, radius * 0.82),
			])
			draw_colored_polygon(body, Color("060809"))
			draw_polyline(body, Color(0.34, 0.37, 0.34, 0.34), maxf(1.3, radius * 0.12), true)
			draw_rect(
				Rect2(
					center + Vector2(-radius * 0.22, -radius * 0.88),
					Vector2(radius * 0.44, radius * 0.56)
				),
				Color("050708")
			)
			draw_circle(
				center + Vector2(radius * 0.15, radius * 0.26),
				maxf(1.2, radius * 0.14),
				Color(0.94, 0.45, 0.11, 0.80),
				true,
				-1.0,
				true
			)
		&"key":
			var line_width := maxf(4.2, radius * 0.40)
			var color := Color("060809")
			var bow_center := center + Vector2(-radius * 0.48, 0.0)
			var bow := PackedVector2Array([
				bow_center + Vector2(-radius * 0.78, -radius * 0.20),
				bow_center + Vector2(-radius * 0.42, -radius * 0.68),
				bow_center + Vector2(radius * 0.34, -radius * 0.72),
				bow_center + Vector2(radius * 0.70, -radius * 0.10),
				bow_center + Vector2(radius * 0.38, radius * 0.66),
				bow_center + Vector2(-radius * 0.54, radius * 0.62),
			])
			draw_colored_polygon(bow, color)
			var inset := PackedVector2Array([
				bow_center + Vector2(-radius * 0.28, -radius * 0.12),
				bow_center + Vector2(0.0, -radius * 0.30),
				bow_center + Vector2(radius * 0.26, -radius * 0.04),
				bow_center + Vector2(radius * 0.06, radius * 0.28),
				bow_center + Vector2(-radius * 0.26, radius * 0.18),
			])
			draw_colored_polygon(inset, Color(0.26, 0.28, 0.26, 0.54))
			draw_line(center + Vector2(-radius * 0.08, 0.0), center + Vector2(radius * 0.86, 0.0), color, line_width, true)
			draw_line(center + Vector2(radius * 0.42, 0.0), center + Vector2(radius * 0.42, radius * 0.38), color, line_width, true)
			draw_line(center + Vector2(radius * 0.72, 0.0), center + Vector2(radius * 0.72, radius * 0.28), color, line_width, true)
			draw_circle(
				center + Vector2(-radius * 0.56, -radius * 0.12),
				maxf(1.1, radius * 0.12),
				Color(0.94, 0.45, 0.11, 0.82),
				true,
				-1.0,
				true
			)
		_:
			draw_circle(center, radius + 1.5, Color(0.0, 0.0, 0.0, 0.18), true, -1.0, true)
			draw_circle(center, radius, Color("080b0c"), true, -1.0, true)
			draw_circle(center + Vector2(radius * 0.18, -radius * 0.16), radius * 0.45, Color(0.88, 0.34, 0.08, 0.12), true, -1.0, true)
			draw_circle(center + Vector2(radius * 0.18, -radius * 0.16), radius * 0.21, Color(0.94, 0.45, 0.11, 0.88), true, -1.0, true)
			draw_arc(center, radius * 0.66, -1.15, 1.40, 14, Color(0.82, 0.46, 0.18, 0.62), maxf(1.2, radius * 0.15), true)

func _draw_shield_station() -> void:
	var base := _world_to_screen(SHIELD_STATION)
	if base.x < -80.0 or base.x > SCREEN.x + 80.0:
		return
	draw_line(base + Vector2(-22.0, 0.0), base + Vector2(-10.0, -48.0), Color("050708"), 7.0, true)
	draw_line(base + Vector2(22.0, 0.0), base + Vector2(10.0, -48.0), Color("050708"), 7.0, true)
	if (
		actor_equipment != ActorPoseState.EQUIPMENT_SHIELD
		and actor_equipment != ActorPoseState.EQUIPMENT_SHIELD_BLADE
	):
		var shield_center := base + Vector2(0.0, -34.0)
		var shield := PackedVector2Array([
			shield_center + Vector2(-15.0, -17.0),
			shield_center + Vector2(14.0, -17.0),
			shield_center + Vector2(18.0, 0.0),
			shield_center + Vector2(1.0, 23.0),
			shield_center + Vector2(-16.0, 8.0),
		])
		draw_colored_polygon(shield, Color("07090a"))
		var shield_plane := PackedVector2Array([
			shield_center + Vector2(0.0, -14.0),
			shield_center + Vector2(11.0, -11.0),
			shield_center + Vector2(13.0, 0.0),
			shield_center + Vector2(2.0, 17.0),
			shield_center + Vector2(-2.0, 4.0),
		])
		draw_colored_polygon(shield_plane, Color(0.24, 0.26, 0.25, 0.42))
		draw_circle(shield_center, 3.2, Color(0.80, 0.45, 0.18, 0.72), true, -1.0, true)

func _draw_blade_station() -> void:
	var base := _world_to_screen(BLADE_STATION)
	if base.x < -90.0 or base.x > SCREEN.x + 90.0:
		return
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-28.0, 0.0),
		base + Vector2(28.0, 0.0),
		base + Vector2(18.0, -12.0),
		base + Vector2(-18.0, -12.0),
	]), Color("050708"))
	if (
		actor_equipment != ActorPoseState.EQUIPMENT_BLADE
		and actor_equipment != ActorPoseState.EQUIPMENT_SHIELD_BLADE
	):
		draw_set_transform(base + Vector2(0.0, -26.0), -0.58, Vector2.ONE)
		draw_line(Vector2(-7.0, 0.0), Vector2(5.0, 0.0), Color(0.73, 0.40, 0.16, 0.78), 4.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(3.0, -2.5),
			Vector2(40.0, -1.3),
			Vector2(47.0, 0.0),
			Vector2(39.0, 2.0),
			Vector2(3.0, 2.5),
		]), Color(0.20, 0.22, 0.21, 0.72))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_lab_crate() -> void:
	var rect := _world_rect_to_screen(Rect2(crate_position, CRATE_SIZE))
	if rect.end.x < -50.0 or rect.position.x > SCREEN.x + 50.0:
		return
	host.draw_soft_cloud(self, rect.get_center() + Vector2(4.0, 10.0), rect.size + Vector2(30.0, 24.0), Color(0.0, 0.0, 0.0, 0.48))
	var body := PackedVector2Array([
		rect.position + Vector2(2.0, 4.0),
		Vector2(rect.end.x - 4.0, rect.position.y),
		rect.end - Vector2(1.0, 2.0),
		Vector2(rect.position.x, rect.end.y - 5.0),
	])
	draw_colored_polygon(body, Color("050708"))
	var lit_face := PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.48, 7.0),
		Vector2(rect.end.x - 7.0, rect.position.y + 4.0),
		rect.end - Vector2(6.0, 8.0),
		rect.position + Vector2(rect.size.x * 0.56, rect.size.y - 7.0),
	])
	draw_colored_polygon(lit_face, Color(0.19, 0.20, 0.19, 0.31))
	draw_circle(rect.get_center() + Vector2(8.0, -1.0), 3.0, Color(0.76, 0.42, 0.17, 0.48), true, -1.0, true)

func _draw_shield_bolt(center: Vector2) -> void:
	draw_circle(center, 13.0, Color(0.80, 0.48, 0.20, 0.035), true, -1.0, true)
	draw_circle(center, 6.5, Color(0.87, 0.56, 0.25, 0.12), true, -1.0, true)
	draw_circle(center, 2.2, Color(0.96, 0.72, 0.39, 0.78), true, -1.0, true)

func _motion_lab_prompt() -> String:
	if _player_near(SHIELD_STATION, 58.0):
		if (
			actor_equipment == ActorPoseState.EQUIPMENT_SHIELD
			or actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE
		):
			return "已装备盾牌"
		return "F 装备盾牌"
	if _player_near(BLADE_STATION, 58.0):
		if (
			actor_equipment == ActorPoseState.EQUIPMENT_BLADE
			or actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE
		):
			return "F 收剑"
		if actor_equipment == ActorPoseState.EQUIPMENT_SHIELD:
			return "E 拔剑" if blade_owned else "F 拾取单手剑"
		return "需要先取得盾牌"
	var player_rect := Rect2(player_position, PLAYER_SIZE).grow(20.0)
	if player_rect.intersects(Rect2(crate_position, CRATE_SIZE)):
		return "按住 F ＋ A / D 推动重箱"
	if actor_equipment == ActorPoseState.EQUIPMENT_THROWABLE:
		return "按住 F 蓄力　↑ ↓ 瞄准　松开投掷"
	if actor_equipment == ActorPoseState.EQUIPMENT_SHIELD:
		return (
			"E 拔剑　短按 R 盾反　长按 R 举盾"
			if blade_owned
			else "短按 R 盾反　长按 R 举盾"
		)
	if actor_equipment == ActorPoseState.EQUIPMENT_BLADE:
		return "F 前刺　持剑跳跃待补"
	if actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE:
		return "F 前刺　E 收剑　R 盾牌"
	var nearby_item := _nearest_small_item_index(48.0)
	if nearby_item >= 0:
		return "F 拾取%s" % _small_item_display_name(StringName(small_items[nearby_item]["kind"]))
	return ""

func _small_item_display_name(kind: StringName) -> String:
	match kind:
		&"orb":
			return "墨光球"
		&"stone":
			return "黑石"
		&"wood":
			return "焦木"
		&"scrap":
			return "废铁"
		&"bottle":
			return "小瓶"
		&"key":
			return "钥匙"
	return "小物品"

func _draw_ui() -> void:
	draw_rect(Rect2(18.0, 16.0, 390.0, 60.0), Color(0.0, 0.0, 0.0, 0.44))
	draw_string(ui_font, Vector2(30.0, 42.0), "原创场景 · 沉钟雾谷", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(0.90, 0.91, 0.89))
	draw_string(ui_font, Vector2(30.0, 66.0), "歪塔巨盔骑士 · Seedance 奔跑帧 Demo", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.91, 0.61, 0.28, 0.78))
	draw_rect(Rect2(18.0, 672.0, SCREEN.x - 36.0, 34.0), Color(0.0, 0.0, 0.0, 0.42))
	draw_string(ui_font, Vector2(30.0, 696.0), "A / D 移动　Space 跳跃　F 互动 / 攻击　E 拔剑 / 收剑　R 盾牌　H 受击　T 重置", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.85, 0.86, 0.84, 0.72))
