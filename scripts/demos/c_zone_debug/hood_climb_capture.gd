extends SceneTree

# Windowed capture of the climb onto the pushable box (a window opens for a moment): zoomed screenshots of the box top while he
# climbs, to look at the contact by eye. Output: res://artifacts/climb-capture/NN.png
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _shoot(label: String, zoom: float) -> void:
	var box: Vector2 = level.puzzle_box.position
	level.camera.position = Vector2(box.x + 60.0, box.y - 10.0)
	level.camera.zoom = Vector2.ONE * zoom
	level.camera.offset = Vector2.ZERO
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts/climb-capture")
	image.save_png("res://artifacts/climb-capture/%s.png" % label)

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_marsh_act()
	await _frames(30)
	var ledge_y: float = level.SECOND_ACT_LEDGE.position.y
	level.player.position = Vector2(2870.0, ledge_y - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	Input.action_press("move_right")
	for i in 240:
		await physics_frame
		if level.player.position.x + 26.0 >= 2950.0 - 36.0:
			break
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")
	var started := false
	var shot := 0
	for i in 400:
		await physics_frame
		if level.climb_time >= 0.0:
			started = true
			Input.action_release("move_right")
			if i % 3 == 0:
				level.set_physics_process(false)
				await _shoot("%02d_p%03d" % [shot, int(level.climb_time / level.climb_total * 100.0)], 4.0)
				level.set_physics_process(true)
				shot += 1
		elif started:
			break
	await _frames(20)
	level.set_physics_process(false)
	await _shoot("%02d_idle" % shot, 4.0)
	quit()
