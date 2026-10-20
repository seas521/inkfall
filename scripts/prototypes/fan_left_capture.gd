extends SceneTree

# The leaf left lying at the second act's ledge.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var level = SCENE.instantiate()
	root.add_child(level)
	for _i in range(60):
		await process_frame
	level.fan_owned = true
	level.fan_revealed = true
	level.fan_on_tree = false
	level.checkpoint_fan = true
	level.player.position = Vector2(level.SECOND_ACT_LEDGE.position.x + 6.0, level.SECOND_ACT_LEDGE.position.y - level.PLAYER_SIZE.y - 1.0)
	for k in range(4):
		for _i in range(22):
			await physics_frame
			await process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://artifacts/fan_left")
		root.get_texture().get_image().save_png("res://artifacts/fan_left/f%d.png" % k)
	quit(0)
