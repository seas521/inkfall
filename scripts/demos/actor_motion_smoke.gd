extends SceneTree

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const MAIN_SCENE = preload("res://scenes/main.tscn")
const PLAYER_CENTER_OFFSET := 13.0

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(3)
	var controller = main.active_controller
	if controller == null:
		_fail("cinematic controller did not start")
		_finish()
		return

	_assert(controller.presentation_state()["style_id"] == ActorPoseState.STYLE_CROOKED_TOWER, "Seedance crooked-tower style is active")
	main.art_actor.present(0.016, {
		"style_id": ActorPoseState.STYLE_LEGACY,
		"feet": Vector2(120.0, 560.0),
		"velocity": Vector2.ZERO,
		"grounded": true,
		"facing": 1.0,
	})
	_assert(main.art_actor.legacy_actor.visible and not main.art_actor.crooked_tower_actor.visible, "legacy actor remains selectable")
	main.art_actor.present(0.016, controller.presentation_state())
	await _test_jump(main, controller)
	await _test_run(main, controller)
	await _test_throw(main, controller)
	await _test_shield(main, controller)
	await _test_damage(main, controller)
	await _test_blade(main, controller)
	await _test_push(main, controller)
	_finish()

func _test_jump(main, controller) -> void:
	controller.player_position = Vector2(135.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	Input.action_press("jump")
	await _frames(2)
	_assert(controller.player_velocity.y < 0.0, "jump enters rising state")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"takeoff", "Seedance takeoff clip is active")
	await _frames(16)
	Input.action_release("jump")
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"rise" or main.art_actor.crooked_tower_actor.current_clip == &"apex",
		"Seedance airborne clip follows vertical velocity"
	)
	controller.player_position = Vector2(135.0, 350.0)
	controller.player_velocity.y = 220.0
	main.game_context.on_ground = false
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"fall", "Seedance fall clip is active")
	controller.player_position = Vector2(135.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _frames(2)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"land"
		and main.art_actor.crooked_tower_actor.current_frame_index in [0, 1],
		"normal landing starts the upright stance-opening frames"
	)
	await _frames(12)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"idle", "landing settles into the wide-stance idle")
	controller.reset()
	await _frames(2)

func _test_run(main, controller) -> void:
	controller.player_position = Vector2(135.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	Input.action_press("move_right")
	await _frames(24)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"run", "distance-driven Seedance run clip is active")
	var distance_before_camera_follow: float = main.art_actor.crooked_tower_actor.travel_distance
	await _frames(90)
	_assert(
		main.art_actor.crooked_tower_actor.travel_distance > distance_before_camera_follow + 80.0,
		"run cycle keeps advancing after camera follow stabilizes"
	)
	Input.action_release("move_right")
	await _frames(8)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"idle",
		"run returns to approved idle frame"
	)

func _test_throw(main, controller) -> void:
	_assert(controller.small_items.size() == 6, "original scene exposes six small items")
	var expected_kinds := [&"orb", &"stone", &"wood", &"scrap", &"bottle", &"key"]
	for index in range(expected_kinds.size()):
		_assert(
			controller.small_items[index]["kind"] == expected_kinds[index],
			"%s is placed in the original scene" % expected_kinds[index]
		)
	controller.player_position = Vector2(167.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _tap("interact")
	_assert(controller.held_small_item_index == 0, "nearest ground item is selected independently")
	_assert(controller.actor_equipment == ActorPoseState.EQUIPMENT_THROWABLE, "throwable pickup equips object")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"pickup", "Seedance pickup clip is active")
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item is attached during pickup")
	await _frames(20)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"carry", "Seedance held-object clip is active")
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item is attached during carry idle")
	Input.action_press("move_right")
	await _frames(24)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"carry_run", "held-object run clip is active")
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item is attached during carry run")
	Input.action_release("move_right")
	await _frames(3)
	Input.action_press("jump")
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"carry_takeoff", "held-object takeoff clip is active")
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item is attached during takeoff")
	await _frames(16)
	Input.action_release("jump")
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"carry_rise" or main.art_actor.crooked_tower_actor.current_clip == &"carry_apex",
		"held-object airborne clip follows vertical velocity"
	)
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item is attached while airborne")
	controller.player_position.y = 350.0
	controller.player_velocity.y = 220.0
	main.game_context.on_ground = false
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"carry_fall", "held-object fall clip is active")
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item is attached during fall")
	controller.player_position.y = 506.0
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"carry_land", "held-object landing clip is active")
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item is attached during landing")
	await _frames(20)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"carry", "held-object landing returns to carry idle")
	Input.action_press("interact")
	await _frames(18)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"throw_charge", "Seedance throw charge clip is active")
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item is attached during throw charge")
	Input.action_release("interact")
	await _frames(2)
	var thrown_item: Dictionary = controller.small_items[controller.active_small_item_index]
	_assert(thrown_item["state"] == &"thrown", "held object enters thrown physics")
	_assert(controller.actor_action == ActorPoseState.ACTION_THROW_RELEASE, "throw release pose is emitted")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"throw_release", "Seedance throw release clip is active")
	_assert(main.art_actor.crooked_tower_actor.small_item.visible, "small item remains attached in early release frames")
	_assert(float(thrown_item["draw_delay"]) > 0.0, "world projectile waits for actor release frame")
	await _frames(8)
	_assert(
		main.art_actor.crooked_tower_actor.current_frame_index >= 4,
		"throw release advances beyond the handoff frame"
	)
	_assert(not main.art_actor.crooked_tower_actor.small_item.visible, "small item leaves the hand at release frame 4")
	controller.reset()
	controller.player_position = Vector2(167.0, 506.0)
	main.game_context.on_ground = true
	await _tap("interact")
	await _frames(20)
	await _tap("interact")
	_assert(controller.actor_action == ActorPoseState.ACTION_PUT_DOWN, "short press emits put-down action")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"put_down", "reversed pickup frames animate put-down")
	var placed_item: Dictionary = controller.small_items[controller.active_small_item_index]
	_assert(float(placed_item["draw_delay"]) > 0.0, "world object stays hidden during put-down frames")
	await _frames(18)
	placed_item = controller.small_items[controller.active_small_item_index]
	_assert(float(placed_item["draw_delay"]) <= 0.0, "world object appears after put-down completes")
	await _test_each_small_item_pickup(main, controller)

func _test_each_small_item_pickup(main, controller) -> void:
	for index in range(controller.small_items.size()):
		controller.reset()
		var ground_item: Dictionary = controller.small_items[index]
		var kind: StringName = ground_item["kind"]
		controller.player_position = Vector2(Vector2(ground_item["position"]).x - PLAYER_CENTER_OFFSET, 506.0)
		controller.player_velocity = Vector2.ZERO
		main.game_context.on_ground = true
		await _tap("interact")
		_assert(controller.held_small_item_index == index, "%s can be picked up from the ground" % kind)
		_assert(controller.throwable_kind == kind, "%s keeps its identity while held" % kind)
		_assert(main.art_actor.crooked_tower_actor.current_clip == &"pickup", "%s uses the pickup animation" % kind)
		await _frames(20)
		await _frames(1)
		var item = main.art_actor.crooked_tower_actor.small_item
		_assert(item.visible, "%s reuses the approved carry animation" % kind)
		_assert(item.item_kind == kind, "%s selects its runtime prop art" % kind)
		_assert(
			is_equal_approx(item.item_radius, float(ground_item["radius"]) / 0.42),
			"%s preserves its configured gameplay size" % kind
		)
		_assert(
			item.z_index == (-1 if kind == &"orb" else 1),
			"%s uses the intended hand overlap layer" % kind
		)
		if kind != &"orb":
			_assert(
				float(ground_item["radius"]) >= 13.0 and item.item_radius * 0.42 >= 13.0,
				"%s fully covers the baked orb footprint" % kind
			)
		await _tap("interact")
		_assert(controller.actor_action == ActorPoseState.ACTION_PUT_DOWN, "%s can be placed back on the ground" % kind)
		await _frames(18)
	controller.reset()

func _test_shield(main, controller) -> void:
	controller.player_position = Vector2(900.0, 468.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _tap("interact")
	_assert(controller.actor_equipment == ActorPoseState.EQUIPMENT_SHIELD, "shield station equips shield")
	controller.shield_bolt_active = false
	controller.shield_bolt_cooldown = 99.0
	await _frames(24)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"shield_ready", "shield ready frame is active")
	Input.action_press("move_right")
	await _frames(18)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"shield_walk", "shield walk clip is active")
	var shield_walk_distance: float = main.art_actor.crooked_tower_actor.travel_distance
	await _frames(18)
	_assert(
		main.art_actor.crooked_tower_actor.travel_distance > shield_walk_distance + 30.0,
		"shield walk advances the complete footstep cycle"
	)
	Input.action_release("move_right")
	await _frames(3)
	Input.action_press("jump")
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"shield_takeoff", "shield takeoff clip is active")
	await _frames(24)
	Input.action_release("jump")
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"shield_rise" or main.art_actor.crooked_tower_actor.current_clip == &"shield_apex",
		"shield airborne clip follows vertical velocity"
	)
	controller.player_position.y = 350.0
	controller.player_velocity.y = 220.0
	main.game_context.on_ground = false
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"shield_fall", "shield fall clip is active")
	controller.player_position.y = 468.0
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"shield_land", "shield landing clip is active")
	await _frames(18)
	await _tap("shield")
	_assert(controller.actor_action == ActorPoseState.ACTION_SHIELD_PARRY, "short press emits shield parry")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"shield_parry", "shield parry clip is active")
	_assert(controller.actor_action_duration >= 1.14, "shield parry preserves the full source motion")
	await _frames(74)
	controller.player_position = Vector2(900.0, 468.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	Input.action_press("shield")
	await _frames(10)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"shield_raise",
		"held shield input stays in raise without falling back to ready"
	)
	await _frames(6)
	_assert(controller.actor_action == ActorPoseState.ACTION_SHIELD_GUARD, "long press emits shield guard")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"shield_guard", "shield guard clip is active")
	var guarded_x: float = controller.player_position.x
	Input.action_press("move_right")
	await _frames(18)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"shield_guard",
		"held guard remains in the stable defensive pose"
	)
	_assert(
		absf(controller.player_position.x - guarded_x) < 0.5,
		"held guard locks horizontal movement"
	)
	Input.action_release("move_right")
	await _frames(2)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"shield_guard",
		"held guard stays stable after movement input"
	)
	controller.shield_impact_time = 0.0
	controller.shield_bolt_active = true
	controller.shield_bolt_position = controller.player_position + Vector2(
		13.0 + controller.game_context.player_facing * 18.0,
		23.0
	)
	controller._update_shield_bolt(0.0)
	_assert(not controller.shield_bolt_active, "shield removes the incoming light orb")
	_assert(
		controller.actor_action == ActorPoseState.ACTION_SHIELD_GUARD,
		"light orb does not interrupt the player guard pose"
	)
	_assert(controller.shield_impact_time <= 0.0, "light orb adds no player impact effect")
	Input.action_release("shield")
	await _frames(2)
	_assert(controller.actor_action == ActorPoseState.ACTION_SHIELD_LOWER, "guard release lowers shield")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"shield_lower", "reversed raise frames lower shield consistently")

func _test_damage(main, controller) -> void:
	controller.reset()
	controller.player_position = Vector2(135.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _tap("damage_test")
	_assert(controller.actor_action == ActorPoseState.ACTION_HIT, "damage test starts light-hit action")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"hit", "full-frame light-hit clip is active")
	await _frames(38)
	_assert(controller.actor_action == ActorPoseState.ACTION_NONE, "light hit recovers to locomotion")

	await _tap("damage_test")
	_assert(controller.actor_action == ActorPoseState.ACTION_KNOCKDOWN, "damage test starts heavy knockdown")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"knockdown", "full-frame knockdown clip is active")
	await _frames(88)
	_assert(controller.actor_action == ActorPoseState.ACTION_DOWNED, "knockdown reaches downed loop")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"downed", "downed loop is active")
	await _frames(78)
	_assert(controller.actor_action == ActorPoseState.ACTION_GET_UP, "downed loop transitions to get-up")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"get_up", "full-frame get-up clip is active")
	await _frames(146)
	_assert(controller.actor_action == ActorPoseState.ACTION_NONE, "get-up returns to locomotion")

	await _tap("damage_test")
	_assert(
		controller.actor_action == ActorPoseState.ACTION_UNCONTROLLED_FALL,
		"damage test starts uncontrolled fall"
	)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"uncontrolled_fall",
		"full-frame uncontrolled-fall clip is active"
	)
	await _frames(105)
	_assert(controller.actor_action == ActorPoseState.ACTION_FALL_IMPACT, "fall reaches ground impact")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"fall_impact", "fall-impact clip is active")
	await _frames(35)
	_assert(controller.actor_action == ActorPoseState.ACTION_FALL_DOWNED, "fall ends in persistent downed state")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"fall_downed", "fall-downed loop is active")
	controller.restart_current()
	await _frames(2)
	_assert(controller.actor_action == ActorPoseState.ACTION_NONE, "restart exits the persistent fall-downed state")

func _test_blade(main, controller) -> void:
	controller.actor_equipment = ActorPoseState.EQUIPMENT_SHIELD
	controller.blade_owned = false
	controller.player_position = Vector2(1855.0, 451.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _tap("interact")
	_assert(
		controller.actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE,
		"blade pickup upgrades shield equipment to shield-and-sword"
	)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_equip", "full-frame sword equip clip is active")
	await _frames(40)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_ready", "sword ready loop is active")

	controller.player_position = Vector2(100.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	Input.action_press("move_right")
	await _frames(12)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_run", "full-frame sword run clip is active")
	await _tap("blade_toggle")
	_assert(
		controller.actor_action == ActorPoseState.ACTION_BLADE_SHEATHE_RUN,
		"running sword toggle starts full-frame sheathing"
	)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"blade_sheathe_run",
		"running sheathe clip is active"
	)
	await _frames(102)
	_assert(controller.actor_equipment == ActorPoseState.EQUIPMENT_SHIELD, "running sheathe returns to shield-only")
	Input.action_release("move_right")

	controller.player_position = Vector2(500.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	Input.action_press("move_left")
	await _frames(12)
	await _tap("blade_toggle")
	_assert(
		controller.actor_action == ActorPoseState.ACTION_BLADE_DRAW_RUN,
		"running sword toggle starts full-frame drawing"
	)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_draw_run", "running draw clip is active")
	await _frames(30)
	_assert(
		controller.actor_equipment == ActorPoseState.EQUIPMENT_SHIELD_BLADE,
		"running draw restores shield-and-sword equipment"
	)
	Input.action_release("move_left")
	await _frames(8)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_ready", "sword run returns to ready")

	controller.player_position = Vector2(900.0, 468.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	Input.action_press("jump")
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"combo_takeoff", "shield-and-sword takeoff is active")
	await _frames(18)
	Input.action_release("jump")
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"combo_rise"
		or main.art_actor.crooked_tower_actor.current_clip == &"combo_apex",
		"shield-and-sword airborne phase follows jump velocity"
	)
	controller.player_position.y = 350.0
	controller.player_velocity.y = 220.0
	main.game_context.on_ground = false
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"combo_fall", "shield-and-sword fall is active")
	controller.player_position.y = 468.0
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _frames(2)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"combo_land", "shield-and-sword landing is active")
	await _frames(24)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_ready", "combo landing returns to sword ready")

	await _tap("shield")
	_assert(controller.actor_action == ActorPoseState.ACTION_SHIELD_PARRY, "combo shield input emits parry")
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"combo_shield_parry",
		"full-frame shield-and-sword parry is active"
	)
	await _frames(48)
	Input.action_press("shield")
	await _frames(1)
	await _tap("blade_toggle")
	_assert(
		controller.actor_action == ActorPoseState.ACTION_BLADE_SHEATHE_GUARD,
		"guarded sword toggle starts full-frame sheathing"
	)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"blade_sheathe_guard",
		"guarded sheathe clip is active"
	)
	await _frames(36)
	_assert(controller.actor_equipment == ActorPoseState.EQUIPMENT_SHIELD, "guarded sheathe keeps shield equipped")
	Input.action_release("shield")
	await _frames(24)

	await _tap("blade_toggle")
	_assert(controller.actor_action == ActorPoseState.ACTION_BLADE_EQUIP, "idle sword toggle draws the owned sword")
	await _frames(40)
	controller.player_position = Vector2(1980.0, 451.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _tap("interact")
	_assert(controller.actor_action == ActorPoseState.ACTION_BLADE_SWING, "blade input emits swing")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_swing", "full-frame sword thrust clip is active")
	await _frames(45)
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_ready", "sword thrust returns to ready")
	controller.player_position = Vector2(1855.0, 451.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _tap("interact")
	_assert(controller.actor_action == ActorPoseState.ACTION_BLADE_SHEATHE, "blade station starts sheathing")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"blade_sheathe", "full-frame sheathe clip is active")
	await _frames(62)
	_assert(controller.actor_equipment == ActorPoseState.EQUIPMENT_SHIELD, "sheathing keeps the acquired shield")

func _test_push(main, controller) -> void:
	controller.actor_equipment = ActorPoseState.EQUIPMENT_NONE
	controller.player_position = Vector2(controller.crate_position.x - 26.0, 426.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	var initial_x: float = controller.crate_position.x
	Input.action_press("interact")
	Input.action_press("move_right")
	await _frames(18)
	_assert(controller.actor_action == ActorPoseState.ACTION_PUSH, "crate contact enters sustained push")
	_assert(controller.crate_position.x > initial_x, "crate moves from player effort")
	_assert(main.art_actor.crooked_tower_actor.current_clip == &"run", "missing push art safely keeps locomotion visible")
	Input.action_release("move_right")
	Input.action_release("interact")
	await _frames(2)
	_assert(controller.actor_action == ActorPoseState.ACTION_PUSH_RELEASE, "lost crate contact emits push release")

func _tap(action_name: StringName) -> void:
	Input.action_press(action_name)
	await _frames(1)
	Input.action_release(action_name)
	await _frames(1)

func _frames(count: int) -> void:
	for _frame_index in range(count):
		await physics_frame

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_fail(label)

func _fail(label: String) -> void:
	failures.append(label)
	push_error("FAIL: " + label)

func _finish() -> void:
	Input.action_release("jump")
	Input.action_release("interact")
	Input.action_release("shield")
	Input.action_release("blade_toggle")
	Input.action_release("damage_test")
	Input.action_release("move_left")
	Input.action_release("move_right")
	if failures.is_empty():
		print("Actor motion smoke test passed.")
		quit(0)
	else:
		quit(1)
