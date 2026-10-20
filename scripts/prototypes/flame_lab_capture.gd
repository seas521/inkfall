extends SceneTree

# Frames of the flame lab: scripts/prototypes/flame_lab_capture.gd
const SCENE = preload("res://scenes/prototypes/flame_lab.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var lab = SCENE.instantiate()
	root.add_child(lab)
	DirAccess.make_dir_recursive_absolute("res://artifacts/flame_lab")
	for shot in range(8):
		for _i in range(18 if shot > 0 else 80):
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/flame_lab/f%02d.png" % shot)
	quit(0)
