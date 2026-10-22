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
	root.get_texture().get_image().save_png("res://artifacts/scene1/%s.png" % name)
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
	await _shot("b_getting_up", 0.0, 2.4)
	await _shot("c_mound_pit", 900.0, 9.0)
	await _shot("d_boulder", 1300.0, 9.0)
	await _shot("e_pond", 2350.0, 9.0)
	await _shot("f_boulders", 2650.0, 9.0)
	await _shot("g_island_pit", 3150.0, 9.0)
	await _shot("h_pond_stones", 4150.0, 9.0)
	await _shot("i_trunk", 4500.0, 9.0)
	await _shot("j_boulder_field", 6100.0, 9.0)
	await _shot("k_cliff", 6800.0, 9.0, 300.0)
	quit(0)
