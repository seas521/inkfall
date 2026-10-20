extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_capture_jump")

func _capture_jump() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(3)
	var controller = main.active_controller
	controller.player_position = Vector2(135.0, 506.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _frames(2)
	Input.action_press("jump")
	await _frames(18)
	Input.action_release("jump")
	await _frames(62)
	quit()

func _frames(count: int) -> void:
	for _frame_index in range(count):
		await physics_frame
