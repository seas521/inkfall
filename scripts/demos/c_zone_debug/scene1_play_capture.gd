extends SceneTree

# Windowed: he runs right through the back half of scene 1 and every few frames a screenshot is taken; the mean change between two
# consecutive shots is printed, so a jump in the backdrop shows up as a spike. S1_FROM / S1_TO: the route offsets (px).
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

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
	var start_offset := float(OS.get_environment("S1_FROM")) if OS.has_environment("S1_FROM") else 4300.0
	var end_offset := float(OS.get_environment("S1_TO")) if OS.has_environment("S1_TO") else 6600.0
	var x: float = Scene1.START_X + start_offset
	level.player.position = Vector2(x - 13.0, Scene1.ground_top(x) - 56.0)
	level.player.velocity = Vector2.ZERO
	for i in 40:
		await physics_frame
	DirAccess.make_dir_recursive_absolute("res://artifacts/scene1/play")
	var previous: Image = null
	var index := 0
	Input.action_press("move_right")
	var guard := 0
	while level.player.position.x + 13.0 < Scene1.START_X + end_offset and guard < 400:
		guard += 1
		for i in 8:
			await physics_frame
		# a crude autopilot: jump whenever the run is held up
		if absf(level.player.velocity.x) < 40.0 and level.player.is_on_floor():
			Input.action_press("jump")
			await physics_frame
			await physics_frame
			Input.action_release("jump")
		await process_frame
		var shot: Image = root.get_texture().get_image()
		var small: Image = shot.duplicate()
		small.resize(320, 180, Image.INTERPOLATE_BILINEAR)
		var diff := 0.0
		if previous != null:
			var a := previous.get_data()
			var b := small.get_data()
			var total := 0
			var count := 0
			for k in range(0, a.size(), 4):
				total += absi(int(a[k]) - int(b[k]))
				count += 1
			diff = float(total) / float(count)
		print("frame %03d off %.0f cam %.0f camy %.0f diff %.2f" % [index, level.player.position.x + 13.0 - Scene1.START_X, level.camera_x, level.camera_y, diff])
		if index % 4 == 0:
			shot.save_png("res://artifacts/scene1/play/f%03d.png" % index)
		previous = small
		index += 1
	Input.action_release("move_right")
	quit(0)
