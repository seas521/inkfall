extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_capture_throw")

func _capture_throw() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(3)
	var controller = main.active_controller
	controller.player_position = Vector2(335.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	Input.action_press("interact")
	await _frames(1)
	Input.action_release("interact")
	await _frames(24)
	Input.action_press("interact")
	await _frames(45)
	Input.action_release("interact")
	await _frames(36)
	quit()

func _frames(count: int) -> void:
	for _frame_index in range(count):
		await physics_frame
