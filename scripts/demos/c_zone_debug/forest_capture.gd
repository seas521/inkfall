extends SceneTree

# Windowed capture of the forest act's graybox: the boy standing, on the practice rope and swinging.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest")
	root.get_texture().get_image().save_png("res://artifacts/forest/%s.png" % name)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	level.debug_enter_forest_act()
	for i in 60:
		await physics_frame
	await _shot("a_stand")
	var forest = level.forest
	level.player.position = Vector2(forest.PRACTICE_PIVOT.x - 13.0, forest.FLOOR_Y - 56.0)
	await _frames(20)
	Input.action_press("jump")
	await _frames(6)
	Input.action_release("jump")
	for i in 90:
		await physics_frame
		if forest.rope_attached():
			break
	await _frames(2)
	await _shot("b_grab")
	var n := 0
	for i in 60 * 3:
		var push := signf(forest.ropes[0].omega) if absf(forest.ropes[0].omega) > 0.05 else 1.0
		if push > 0.0:
			Input.action_release("move_left")
			Input.action_press("move_right")
		else:
			Input.action_release("move_right")
			Input.action_press("move_left")
		await physics_frame
		if i == 100:
			await _shot("c_swing_1")
		if i == 150:
			await _shot("d_swing_2")
	Input.action_release("move_left")
	Input.action_release("move_right")
	quit(0)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
