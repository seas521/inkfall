extends SceneTree

# Look-development capture: frozen frames of act two with chosen hazard clocks.
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
	await _frames(10)
	var shots := [
		["look-a-gas-ledge", 4750.0, 2.2, Vector2(4830.0, 392.0)],
		["look-b-gas-final", 5480.0, 2.2, Vector2(5220.0, 336.0)],
		["look-c-gas-warn", 5480.0, 1.7, Vector2(5390.0, 414.0)],
		["look-d-swing-box", 3200.0, 0.4, Vector2(3150.0, 376.0)],
		["look-e-stones", 4200.0, 2.75, Vector2(4040.0, 350.0)],
		["look-f-exit", 5890.0, 0.0, Vector2(5890.0, 340.0)],
		["look-g-seam-a", 2150.0, 0.0, Vector2(2300.0, 440.0)],
		["look-h-seam-b", 2650.0, 0.0, Vector2(2700.0, 440.0)],
		["look-l-tree", 3420.0, 0.4, Vector2(3250.0, 376.0)],
		["look-i-fire-full", 4660.0, 2.1, Vector2(4470.0, 360.0)],
		["look-j-fire-rising", 4660.0, 1.65, Vector2(4470.0, 360.0)],
		["look-k-fire-fading", 4660.0, 2.75, Vector2(4470.0, 360.0)],
	]
	for shot in shots:
		level.player.position = shot[3]
		level.player.velocity = Vector2.ZERO
		level.clock = shot[2]
		await _frames(2)
		level.clock = shot[2]
		level.set_physics_process(false)
		level.camera_x = float(shot[1]) - 640.0
		level.camera.position = Vector2(float(shot[1]), 360.0)
		level._present(0.0)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-marsh")
		root.get_texture().get_image().save_png("res://artifacts/c-zone-marsh/%s.png" % shot[0])
		level.set_physics_process(true)
	quit(0)

func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame
