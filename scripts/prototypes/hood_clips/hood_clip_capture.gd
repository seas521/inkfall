extends SceneTree

# Plays a scripted run (right, reverse, left, stop) in real time and saves a contact sheet.
const SCENE := "res://scenes/prototypes/hood_clip_lab.tscn"
const CELL := Vector2i(260, 230)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var lab: Node2D = (load(SCENE) as PackedScene).instantiate()
	root.add_child(lab)
	for i in range(10):
		await process_frame
	# time, direction
	var script := [[0.0, 0.0], [0.5, 1.0], [2.5, 0.0]]
	var samples: Array = []
	var t := 0.0
	var step := 0.2
	var end := 7.6
	var next := 0.0
	var braked := false
	var started := Time.get_ticks_msec()
	while true:
		t = float(Time.get_ticks_msec() - started) / 1000.0
		if t > end:
			break
		var dir := 0.0
		for entry in script:
			if t >= float(entry[0]):
				dir = float(entry[1])
		lab.forced_dir = dir
		if t >= 2.0 and not braked and lab.state == "run":
			braked = true
			lab._enter("scared")
		if t >= next:
			next += step
			await process_frame
			RenderingServer.force_draw()
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			samples.append([t, lab.state, lab.facing, int(lab.pos_x) * 1, img.get_region(Rect2i(clampi(int(lab.pos_x) - CELL.x / 2, 0, 1280 - CELL.x), 560 - 200, CELL.x, CELL.y))])
		await process_frame
	var cols := 10
	var rows := int(ceil(float(samples.size()) / float(cols)))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for i in range(samples.size()):
		sheet.blit_rect(samples[i][4], Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, (i / cols) * CELL.y))
		print("t=%.2f %s facing=%d x=%d" % [samples[i][0], samples[i][1], int(samples[i][2]), samples[i][3]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/hood-lab"))
	sheet.save_png(ProjectSettings.globalize_path("res://artifacts/hood-lab/run_turn_stop.png"))
	quit()
