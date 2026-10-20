extends SceneTree

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const MAIN_SCENE = preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(4)
	var controller = main.active_controller
	if controller == null:
		_fail("level 1-01 did not start")
		_finish()
		return

	controller.player_position = Vector2(360.0, 371.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _frames(2)
	_assert(controller.surface_bat_triggered, "cliff approach triggers the bat flock")
	_assert(controller.surface_bat_flock.visible, "bat flock art becomes visible")
	_assert(
		float(controller.presentation_state()["fog_blur"]) > 0.0,
		"surface actor receives the cinematic fog blur"
	)

	await _frames(16)
	_assert(
		controller.call("_surface_bat_gust_strength") > 0.0,
		"bat approach bends the cliff grass"
	)
	await _frames(39)
	_assert(controller.surface_bat_impact_started, "bat flock starts the impact")
	_assert(
		controller.actor_action == ActorPoseState.ACTION_KNOCKDOWN,
		"impact starts the approved knockdown clip"
	)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"knockdown",
		"Seedance knockdown frames are playing"
	)

	await _frames(90)
	_assert(
		controller.actor_action == ActorPoseState.ACTION_DOWNED,
		"knockdown transitions to the downed hold"
	)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"downed",
		"Seedance downed loop is playing"
	)

	await _frames(80)
	_assert(
		controller.actor_action == ActorPoseState.ACTION_GET_UP,
		"downed hold transitions to automatic get-up"
	)
	_assert(
		main.art_actor.crooked_tower_actor.current_clip == &"get_up",
		"Seedance get-up frames are playing"
	)

	await _frames(150)
	_assert(
		controller.actor_action == ActorPoseState.ACTION_NONE,
		"get-up restores locomotion"
	)
	_assert(controller.surface_bat_recovery_complete, "bat encounter completes once")
	_assert(
		not controller.call("_surface_bat_sequence_locks_movement"),
		"movement unlocks after recovery"
	)
	_assert(
		controller.call("_surface_bat_gust_strength") <= 0.001,
		"cliff grass settles after the flock passes"
	)
	_finish()


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
	if failures.is_empty():
		print("Level 1-01 bat event smoke test passed.")
		quit(0)
	else:
		quit(1)
