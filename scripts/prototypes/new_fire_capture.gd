extends SceneTree

# Frames of the new flame in the game: the surface campfire, the shaft ledges and the C zone fire deck.
const MAIN_SCENE = preload("res://scenes/main.tscn")
const Level01Controller = preload("res://scripts/levels/level_01_controller.gd")
const RIVER = preload("res://scenes/debug/c_zone_river.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _snap(name: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/new_fire")
	root.get_texture().get_image().save_png("res://artifacts/new_fire/%s.png" % name)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var which := OS.get_environment("WHICH")
	if which == "surface":
		var main = MAIN_SCENE.instantiate()
		root.add_child(main)
		await _frames(40)
		var controller = main.active_controller
		controller.player_position = Vector2(930.0, controller.player_position.y)
		for k in range(3):
			await _frames(15)
			_snap("surface-%d" % k)
	elif which == "shaft":
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
		for k in range(4):
			await _frames(22)
			controller.player_position = Vector2(714.0, 781.0)
			_snap("shaft-%d" % k)
	else:
		var level = RIVER.instantiate()
		root.add_child(level)
		await _frames(10)
		level.debug_enter_marsh_act()
		await _frames(20)
		level.player.position = Vector2(4560.0, 380.0)
		level.camera.position = Vector2(4646.0, 360.0)
		for k in range(4):
			await _frames(14)
			level.player.position = Vector2(4540.0, 380.0)
			_snap("marsh-%d" % k)
	quit(0)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
