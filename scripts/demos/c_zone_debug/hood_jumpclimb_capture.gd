extends SceneTree

# Windowed capture (a window opens for a moment): run at the pushable box, jump, take hold, climb. A screenshot every 2 physics
# frame (not paused: a paused tick would swallow the jump press) from the jump key on. Output: res://artifacts/jumpclimb-capture/NN_<clip>.png
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _shoot(label: String) -> void:
	var box: Vector2 = level.puzzle_box.position
	level.camera.position = Vector2(box.x - 20.0, box.y + 30.0)
	level.camera.zoom = Vector2.ONE * 2.6
	level.camera.offset = Vector2.ZERO
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts/jumpclimb-capture")
	image.save_png("res://artifacts/jumpclimb-capture/%s.png" % label)

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_marsh_act()
	await _frames(30)
	var ledge_y: float = level.SECOND_ACT_LEDGE.position.y
	level.player.position = Vector2(2790.0, ledge_y - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	Input.action_press("move_right")
	for i in 400:
		await physics_frame
		if level.player.position.x + 26.0 >= 2950.0 - 55.0:
			break
	Input.action_press("jump")
	var shot := 0
	for i in 150:
		await physics_frame
		if i == 14:
			Input.action_release("jump")
		if level.climb_time >= 0.0:
			Input.action_release("move_right")
		if shot < 60:
			await _shoot("%02d_%s_%d" % [shot, level.actor.current_clip, level.actor.current_frame_index])
			shot += 1
	quit()
