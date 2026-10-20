extends SceneTree

# Frames of a fatal fall in the first level's shaft.
const MAIN_SCENE = preload("res://scenes/main.tscn")
const Level01Controller = preload("res://scripts/levels/level_01_controller.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(5)
	var controller = main.active_controller
	controller._enter_shaft()
	controller.shaft_entry_phase = Level01Controller.ShaftEntryPhase.DONE
	controller.entry_fall_lock = 0.0
	controller.room_intro_time = 0.0
	controller.player_position = Vector2(714.0, 781.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await _frames(10)
	controller.entry_fall_lock = 2.2
	controller.shaft_entry_phase = Level01Controller.ShaftEntryPhase.FALLING
	controller.player_position = Vector2(560.0, 300.0)
	controller.player_velocity = Vector2(0.0, 200.0)
	for k in range(4):
		await _frames(5)
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://artifacts/level01")
		root.get_texture().get_image().save_png("res://artifacts/level01/shaft-fall-%d.png" % k)
	quit(0)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
