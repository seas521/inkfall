extends SceneTree

# Frames of the character dropping into a pit.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_marsh_act()
	await _frames(20)
	level.player.position = Vector2(3520.0, 380.0)
	level.player.velocity = Vector2(20.0, 0.0)
	level.camera.position = Vector2(3520.0, 360.0)
	for k in range(8):
		await _frames(5)
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-marsh")
		root.get_texture().get_image().save_png("res://artifacts/c-zone-marsh/fall-%d.png" % k)
		print("t", k, " hit=", level.marsh_hit_time, " pos=", level.player.position)
	quit(0)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
