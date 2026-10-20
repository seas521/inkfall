extends SceneTree

# Stones in the hand, the throw preview, and a stone at rest, on the bank before the broken bridge.
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
	level.debug_enter_cliff_act()
	await _frames(20)
	var cliff = level.cliff
	var stone_x: float = cliff.stones[0].body.position.x
	level.player.position.x = stone_x - 22.0
	level.facing = 1.0
	await _frames(6)
	await _snap("t0-rest")
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(30)
	await _snap("t1-carry")
	Input.action_press("interact")
	await _frames(40)
	await _snap("t2-aim-short")
	await _frames(40)
	await _snap("t3-aim-long")
	Input.action_release("interact")
	quit(0)

func _snap(label: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-cliff")
	root.get_texture().get_image().save_png("res://artifacts/c-zone-cliff/%s.png" % label)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
