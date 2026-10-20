extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
const Level01Controller = preload("res://scripts/levels/level_01_controller.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(5)
	var controller = main.active_controller
	controller._enter_shaft()
	controller.entry_fall_lock = 0.0
	controller.shaft_entry_phase = Level01Controller.ShaftEntryPhase.DONE
	controller.room_intro_time = 0.0
	_assert(
		controller._shaft_collision_platforms().size() > Level01Controller.SHAFT_PLATFORMS.size(),
		"wall-side rock tongues include stepped collision"
	)
	controller.elapsed = 0.0
	controller.player_position = Vector2(555.0, 976.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _walk("move_left", 58)
	_assert(controller.player_position.x <= 412.0, "left rock tongue reaches the cliff bound")
	_assert(main.game_context.on_ground, "left rock tongue remains standable to the wall")

	controller.elapsed = 0.0
	controller.player_position = Vector2(714.0, 781.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _walk("move_right", 58)
	_assert(controller.player_position.x >= 842.0, "right rock tongue reaches the cliff bound")
	_assert(main.game_context.on_ground, "right rock tongue remains standable to the wall")

	controller.elapsed = 0.0
	controller.player_position = Vector2(551.0, 2296.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _frames(3)
	_assert(controller.shaft_exit_armed, "standing on the last shelf arms the exit fall")
	_assert(controller.room == Level01Controller.Room.SHAFT, "last shelf remains in the shaft")
	await _walk("move_right", 90)
	_assert(controller.river_exit_pending and (main.river_transition != null or main.river != null), "jumping below the last shelf transitions to the replacement C")
	print("level01_shaft_support_smoke: PASS")
	quit()

func _walk(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(2)

func _frames(count: int) -> void:
	for _frame_index in range(count):
		await physics_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("level01_shaft_support_smoke: " + message)
	quit(1)
