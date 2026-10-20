extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
const CAPTURE_DIR := "/tmp/inkfall-parry-game-frames-v2"

func _initialize() -> void:
	call_deferred("_capture_shield_parry")

func _capture_shield_parry() -> void:
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(3)
	var controller = main.active_controller
	controller.player_position = Vector2(900.0, 468.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _tap("interact")
	await _frames(32)
	Input.action_press("shield")
	await _frames(4)
	await _save_frame(0)
	Input.action_release("shield")
	for frame_index in range(1, 38):
		await _frames(2)
		await _save_frame(frame_index)
	quit()

func _tap(action_name: StringName) -> void:
	Input.action_press(action_name)
	await _frames(1)
	Input.action_release(action_name)
	await _frames(1)

func _frames(count: int) -> void:
	for _frame_index in range(count):
		await physics_frame

func _save_frame(frame_index: int) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/frame_%02d.png" % [CAPTURE_DIR, frame_index])
