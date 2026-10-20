extends SceneTree

# Look-development capture of the gas vents' pool: frozen frames at chosen clocks.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")

var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(int(OS.get_environment("WINW") if OS.get_environment("WINW") != "" else "1280"), int(OS.get_environment("WINH") if OS.get_environment("WINH") != "" else "720")))
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_marsh_act()
	await _frames(10)
	await _frames(20)
	for k in range(level.marsh_art.bog_views.size()):
		level.marsh_art.bog_views[k].get_texture().get_image().save_png("/tmp/bogview%d.png" % k)
	if OS.get_environment("FILM") == "1":
		load("res://scripts/effects/film_look.gd").attach(level)
		await _frames(5)
	var shots := [
		["vent-a-quiet", 5517.0, 0.4, Vector2(5390.0, 376.0)],
		["vent-b-warn", 5517.0, 1.7, Vector2(5390.0, 376.0)],
		["vent-c-erupt", 5517.0, 2.2, Vector2(5390.0, 376.0)],
		["vent-d-wide", 5600.0, 0.9, Vector2(5390.0, 376.0)],
		["gas-layer-a", 5540.0, 0.8, Vector2(5400.0, 430.0)],
		["gas-layer-b", 5640.0, 0.9, Vector2(5400.0, 430.0)],
		["ledge-a", 2790.0, 0.4, Vector2(2650.0, 500.0)],
		["slope-a-hill-down", 4440.0, 0.4, Vector2(4440.0, 380.0)],
		["slope-b-hill-up", 4000.0, 0.4, Vector2(4000.0, 380.0)],
		["slope-c-bank", 5900.0, 0.4, Vector2(5890.0, 340.0)],
		["bog-pit-three", 6280.0, 0.4, Vector2(6100.0, 340.0)],
		["bog-pit-one", 3530.0, 0.4, Vector2(3300.0, 376.0)],
	]
	for shot in shots:
		level.player.position = shot[3]
		level.player.velocity = Vector2.ZERO
		level.clock = shot[2]
		await _frames(30)
		level.clock = shot[2]
		level.set_physics_process(false)
		level.camera_x = float(shot[1]) - 640.0
		level.camera.position = Vector2(float(shot[1]), 360.0)
		level._present(0.0)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-marsh")
		root.get_texture().get_image().save_png("res://artifacts/c-zone-marsh/%s%s.png" % [("film-" if OS.get_environment("FILM") == "1" else ""), shot[0]])
		level.set_physics_process(true)
	quit(0)

func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame
