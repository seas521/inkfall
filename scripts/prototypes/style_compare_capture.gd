extends SceneTree

# One frame from each of the first level's looks, to compare their drawing styles side by side.
const MAIN_SCENE = preload("res://scenes/main.tscn")
const Level01Controller = preload("res://scripts/levels/level_01_controller.gd")
const RIVER = preload("res://scenes/debug/c_zone_river.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _snap(name: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/style")
	root.get_texture().get_image().save_png("res://artifacts/style/%s.png" % name)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var which := OS.get_environment("WHICH")
	if which == "river":
		var level = RIVER.instantiate()
		root.add_child(level)
		for _i in range(120):
			await process_frame
		_snap("c-river")
		level.player.position = Vector2(1060.0, 480.0)
		for _i in range(100):
			await process_frame
		_snap("c-river-bank")
	elif which == "cavern":
		var main = MAIN_SCENE.instantiate()
		root.add_child(main)
		for _i in range(5):
			await process_frame
		var controller = main.active_controller
		controller._enter_cavern()
		for _i in range(120):
			await process_frame
		_snap("b-cavern")
	elif which == "jump":
		var main = MAIN_SCENE.instantiate()
		root.add_child(main)
		for _i in range(60):
			await process_frame
		var controller = main.active_controller
		Input.action_press("jump")
		for k in range(60):
			await physics_frame
			await process_frame
			if k % 6 == 3 and k < 40:
				_snap("a-jump-%02d" % k)
				print(k, " camera_y=", controller.surface_camera_y, " y=", controller.player_position.y)
		Input.action_release("jump")
	else:
		var main = MAIN_SCENE.instantiate()
		root.add_child(main)
		for _i in range(40):
			await process_frame
		var controller = main.active_controller
		controller.player_position = Vector2(300.0, controller.player_position.y)
		for _i in range(40):
			await process_frame
		_snap("a-surface-left")
		controller.player_position = Vector2(930.0, controller.player_position.y)
		for _i in range(40):
			await process_frame
		_snap("a-surface-right")
	quit(0)
