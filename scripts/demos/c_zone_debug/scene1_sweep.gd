extends SceneTree

# Windowed: the camera is swept along the route in small steps (as if he ran at full speed) and the mean change between two consecutive
# frames is printed. A pop in the backdrop (something appearing or vanishing) shows as a spike against its neighbours.
# S1_FROM / S1_TO / S1_STEP: route offsets in px.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _env(name: String, fallback: float) -> float:
	return float(OS.get_environment(name)) if OS.has_environment(name) else fallback

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
	level.scene1.intro_time = 99.0
	var from := _env("S1_FROM", 3600.0)
	var to := _env("S1_TO", 6400.0)
	var step := _env("S1_STEP", 22.0)
	var previous: Image = null
	var offset := from
	var index := 0
	var rows: Array = []
	while offset <= to:
		var px: float = Scene1.START_X + offset
		var gy: float = Scene1.ground_top(px)
		level.player.position = Vector2(px - 13.0, gy - 56.0)
		level.player.velocity = Vector2.ZERO
		level.set_physics_process(false)
		level.camera_x = px + 100.0 - 640.0
		level.camera_y = level._camera_target_y()
		level.camera.position = Vector2(px + 100.0, 360.0 + level.camera_y)
		level._present(1.0 / 60.0)
		await process_frame
		await process_frame
		var shot: Image = root.get_texture().get_image()
		var small: Image = shot.duplicate()
		small.resize(256, 144, Image.INTERPOLATE_BILINEAR)
		small.convert(Image.FORMAT_L8)
		var diff := 0.0
		if previous != null:
			var a := previous.get_data()
			var b := small.get_data()
			var total := 0
			for k in range(a.size()):
				total += absi(int(a[k]) - int(b[k]))
			diff = float(total) / float(a.size())
		rows.append([offset, diff])
		if index % 6 == 0:
			DirAccess.make_dir_recursive_absolute("res://artifacts/scene1/sweep")
			shot.save_png("res://artifacts/scene1/sweep/%s%04d.png" % [OS.get_environment("S1_TAG"), int(offset)])
		previous = small
		offset += step
		index += 1
	for r in rows:
		print("SWEEP %.0f %.2f" % [r[0], r[1]])
	quit(0)
