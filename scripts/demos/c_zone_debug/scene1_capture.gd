extends SceneTree

# Windowed capture of scene 1: frozen frames along it.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

# `offset`: along the route (px from where he lies); the camera is centred 200 px ahead of him
func _shot(name: String, offset: float, intro: float, lead := 200.0) -> void:
	var px: float = Scene1.START_X + offset
	var gy: float = Scene1.ground_top(px)
	level.player.position = Vector2(px - 13.0, gy - 56.0)
	level.player.velocity = Vector2.ZERO
	level.scene1.intro_time = intro
	for i in 3:
		await physics_frame
	level.set_physics_process(false)
	level.camera_x = px + lead - 640.0
	level.camera_y = level._camera_target_y()
	level.camera.position = Vector2(px + lead, 360.0 + level.camera_y)
	level._present(0.0)
	for i in 4:
		await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/scene1")
	var shot: Image = root.get_texture().get_image()
	shot.save_png("res://artifacts/scene1/%s.png" % name)
	var zoom := shot.get_region(Rect2i(250, 470, 700, 190))
	zoom.resize(1400, 380, Image.INTERPOLATE_LANCZOS)
	zoom.save_png("res://artifacts/scene1/%s_zoom.png" % name)
	level.set_physics_process(true)

# Whatever is happening now (he keeps walking): the camera follows him
func _snap(name: String) -> void:
	level.set_physics_process(false)
	var px: float = level.player.position.x + 13.0
	level.camera_x = px + 200.0 - 640.0
	level.camera_y = level._camera_target_y()
	level.camera.position = Vector2(px + 200.0, 360.0 + level.camera_y)
	level._present(0.0)
	for i in 4:
		await process_frame
	RenderingServer.force_draw()
	var shot: Image = root.get_texture().get_image()
	shot.save_png("res://artifacts/scene1/%s.png" % name)
	var zoom := shot.get_region(Rect2i(250, 470, 700, 190))
	zoom.resize(1400, 380, Image.INTERPOLATE_LANCZOS)
	zoom.save_png("res://artifacts/scene1/%s_zoom.png" % name)
	level.set_physics_process(true)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	level.debug_enter_scene1()
	for i in 30:
		await physics_frame
	await _shot("a_lying", 0.0, 0.3)
	# wading through the first pond
	var px: float = Scene1.START_X + 2560.0 - 60.0
	level.player.position = Vector2(px - 13.0, Scene1.ground_top(px) - 56.0)
	level.scene1.intro_time = 9.0
	Input.action_press("move_right")
	for i in 150:
		await physics_frame
		if i == 70:
			await _snap("w_enter")
		if i == 110:
			await _snap("w_mid")
	Input.action_release("move_right")
	await _shot("b_pit_spikes", 1000.0, 9.0)
	await _shot("c_log", 1400.0, 9.0)
	await _shot("d_thorns", 2150.0, 9.0)
	await _shot("e_pond", 2560.0, 9.0)
	await _shot("f_island_pit", 3030.0, 9.0)
	await _shot("g_boulder", 3450.0, 9.0)
	await _shot("h_pond_stones", 4700.0, 9.0)
	await _shot("i_log_big", 5650.0, 9.0)
	await _shot("j_edge_1", 4700.0, 9.0)
	await _shot("j_edge_2", 5000.0, 9.0)
	await _shot("j_edge_3", 5300.0, 9.0)
	await _shot("j_edge_4", 5600.0, 9.0)
	await _shot("j_edge_5", 5900.0, 9.0)
	await _shot("k_open_end", 6800.0, 9.0, 300.0)
	quit(0)
