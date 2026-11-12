extends SceneTree

# Windowed capture of the forest's first room: frozen frames at a few places along it.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Forest = preload("res://scripts/demos/c_zone_debug/forest_act.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String, cam_x: float, player_x: float) -> void:
	level.player.position = Vector2(player_x - 13.0, Forest.FLOOR_Y - 56.0)
	level.player.velocity = Vector2.ZERO
	for i in 3:
		await physics_frame
	level.set_physics_process(false)
	level.camera_x = cam_x - 640.0
	level.camera_y = level._camera_target_y()
	level.camera.position = Vector2(cam_x, 360.0 + level.camera_y)
	level._present(0.0)
	for i in 4:
		await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest-art")
	root.get_texture().get_image().save_png("res://artifacts/forest-art/%s.png" % name)
	level.set_physics_process(true)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	level.debug_enter_forest_act()
	for i in 30:
		await physics_frame
	var x0: float = Forest.ROOM_X
	await _shot("a_arrival", Forest.START_X + 420.0, Forest.START_X + 120.0)
	await _shot("b_entry", x0 + 300.0, x0 + 90.0)
	await _shot("c_log", x0 + 880.0, x0 + 760.0)
	await _shot("d_shelf_beam", x0 + 1300.0, x0 + 1080.0)
	await _shot("e_beam_gate", x0 + 1850.0, x0 + 1700.0)
	await _shot("f_gate", x0 + 2300.0, x0 + 2100.0)
	quit(0)
