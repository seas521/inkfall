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
	controller.shaft_entry_phase = Level01Controller.ShaftEntryPhase.DONE
	controller.entry_fall_lock = 0.0
	controller.room_intro_time = 0.0
	controller.elapsed = 0.0
	controller.player_position = Vector2(714.0, 781.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true

	Input.action_press("move_left")
	Input.action_press("jump")
	await _frames(10)
	Input.action_release("jump")
	await _frames(35)
	Input.action_release("move_left")

	var landed_on_next := false
	for _frame_index in range(90):
		await physics_frame
		var feet_y: float = float(controller.player_position.y) + 54.0
		if main.game_context.on_ground and absf(feet_y - 1030.0) <= 6.0:
			landed_on_next = true
			break
	_assert(landed_on_next, "intentional jump reaches the next lower shelf")
	_assert(controller.shaft_failure_kind == "", "intentional jump does not trigger uncontrolled fall")
	_assert(controller.room == Level01Controller.Room.SHAFT, "jump remains inside the shaft")
	print("level01_shaft_jump_smoke: PASS")
	quit()

func _frames(count: int) -> void:
	for _frame_index in range(count):
		await physics_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("level01_shaft_jump_smoke: " + message)
	quit(1)
