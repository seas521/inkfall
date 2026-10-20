extends SceneTree

# Contact sheets of the wizard rig. WHICH = idle | walk | run | scared | fall | jump | skid
# Output: artifacts/wizard-rig/<WHICH>.png
const SCENE := "res://scenes/prototypes/wizard_rig_lab.tscn"
const CELL := Vector2i(280, 250)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var which := OS.get_environment("WHICH")
	var lab: Node2D = (load(SCENE) as PackedScene).instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_process_unhandled_key_input(false)
	await process_frame
	var input := {"dir": 0.0, "run": false}
	var times: Array = []
	var warm := 0.0
	match which:
		"walk":
			input = {"dir": 1.0, "run": false}
			warm = 0.9
			for i in range(10): times.append(0.06 * i)
		"run":
			input = {"dir": 1.0, "run": true}
			warm = 1.0
			for i in range(10): times.append(0.045 * i)
		"idle":
			for i in range(6): times.append(0.5 * i)
		"scared":
			lab.start_scared()
			times = [0.0, 0.06, 0.12, 0.2, 0.32, 0.5, 0.8, 1.2, 1.7, 2.1]
		"fall":
			lab.start_fall()
			times = [0.08, 0.2, 0.3, 0.43, 0.52, 0.62, 0.78, 1.0, 1.4, 2.0, 2.6, 3.1, 3.6, 4.0, 4.4, 4.8]
		"jump":
			warm = 0.2
			input = {"dir": 1.0, "run": false}
			for i in range(10): times.append(0.07 * i)
		"skid":
			input = {"dir": 1.0, "run": true}
			warm = 1.2
			for i in range(8): times.append(0.07 * i)
	lab.tick(0.0, input)
	var dt := 1.0 / 60.0
	var t := 0.0
	var step_index := 0
	while t < warm:
		lab.tick(dt, input)
		t += dt
	if which == "jump":
		lab.jump()
	if which == "skid":
		input = {"dir": 0.0, "run": false}
	var cols := 5
	var rows := int(ceil(float(times.size()) / float(cols)))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	var elapsed := 0.0
	for index in range(times.size()):
		while elapsed < float(times[index]) - 0.0001:
			lab.tick(dt, input)
			elapsed += dt
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		if index == 0:
			print("img ", img.get_size(), " pos ", lab.pos_x, " rigpos ", lab.rig.position, " px ", img.get_pixel(int(lab.pos_x), 500))
		var cx := int(lab.pos_x)
		var rect := Rect2i(cx - CELL.x / 2, int(lab.GROUND_Y) - 215, CELL.x, CELL.y)
		rect.position.x = clampi(rect.position.x, 0, img.get_width() - CELL.x)
		sheet.blit_rect(img, rect, Vector2i((index % cols) * CELL.x, (index / cols) * CELL.y))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/wizard-rig"))
	sheet.save_png(ProjectSettings.globalize_path("res://artifacts/wizard-rig/%s.png" % which))
	print("saved ", which)
	quit()
