extends SceneTree

# The pin's three-stone pyramid at the foot of the cliff lift (act three).  TAG names the output.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var level = SCENE.instantiate()
	root.add_child(level)
	for _i in range(10):
		await process_frame
	level.debug_enter_cliff_act()
	for _i in range(20):
		await process_frame
	level.player.position = Vector2(6840.0, 380.0)
	for _i in range(60):
		await physics_frame
		await process_frame
	level.camera.position = Vector2(6900.0, 360.0)
	level.camera_x = 6260.0
	for _i in range(40):
		await physics_frame
		await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/stack")
	root.get_texture().get_image().save_png("res://artifacts/stack/%s.png" % OS.get_environment("TAG"))
	var img := root.get_texture().get_image()
	var sx: int = int(level.cliff.STACK_X - level.camera_x)
	print("LEVELS ground(%d,430)=%.3f stone(%d,372)=%.3f player-body(%d,%d)=%.3f far-cliff(1000,300)=%.3f" % [sx, img.get_pixel(sx, 430).r, sx, img.get_pixel(sx, 372).r, int(level.player.position.x - level.camera_x + 13.0), int(level.player.position.y + 30.0), img.get_pixel(int(level.player.position.x - level.camera_x + 13.0), int(level.player.position.y + 30.0)).r, img.get_pixel(1000, 300).r])
	print("STACK ground=", level.cliff._ground_y(level.cliff.STACK_X), " pos0=", level.cliff.stack_pos(0), " pos1=", level.cliff.stack_pos(1), " pos2=", level.cliff.stack_pos(2))
	quit(0)
