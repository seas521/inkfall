extends SceneTree

# Prints the value of the first level's silhouettes (tree, grass, cliffs, yard tree, right foreground)
# in the running renderer, and saves a frame.  They should all read as the same near-zero black.
const MAIN_SCENE = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _px(x: int, y: int) -> String:
	var c: Color = root.get_texture().get_image().get_pixel(x, y)
	return "%.3f" % c.r

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	for _i in range(40):
		await process_frame
	RenderingServer.force_draw()
	print("BLACK left trunk(60,520)=", _px(60, 520), " left tree lower(110,420)=", _px(110, 420), " left cliff(300,620)=", _px(300, 620), " right cliff(900,620)=", _px(900, 620), " yard tree trunk(1195,330)=", _px(1195, 330), " right foreground(1250,60)=", _px(1250, 60))
	DirAccess.make_dir_recursive_absolute("res://artifacts/style")
	root.get_texture().get_image().save_png("res://artifacts/style/%s.png" % OS.get_environment("TAG"))
	quit(0)
