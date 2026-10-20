extends SceneTree

# Frames of the raft being dragged along the bank, with its dust.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(100)
	Input.action_press("move_left")
	for _i in range(140):
		await _frames(1)
		if level.player.position.x < level.crate.position.x + level.CRATE_SIZE.x + 28.0:
			break
	Input.action_release("move_left")
	await _frames(10)
	Input.action_press("interact")
	await _frames(45)
	Input.action_press("move_right")
	DirAccess.make_dir_recursive_absolute("res://artifacts/drag_dust")
	for k in range(5):
		await _frames(20)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/drag_dust/f%d.png" % k)
		print(k, " dust=", level.art.ground_dust.size(), " crate=", level.crate.position.x, " dragging=", level.dragging)
	Input.action_release("interact")
	Input.action_release("move_right")
	quit(0)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
