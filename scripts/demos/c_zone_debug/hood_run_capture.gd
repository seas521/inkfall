extends SceneTree

# Windowed capture of the hooded boy running on the flat far bank of the C zone (a window opens for a moment): a screenshot every
# 2 physics frames while he runs at the game's own speed, to look at the real posture and cadence by eye.
# Output: res://artifacts/run-capture/NN.png
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
	var p: Vector2 = level.player.position + Vector2(13.0, 20.0)
	level.camera.position = p
	level.camera.zoom = Vector2.ONE * 3.0
	level.camera.offset = Vector2.ZERO
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://artifacts/run-capture")
	image.save_png("res://artifacts/run-capture/%s.png" % label)

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_cliff_act()
	await _frames(40)
	var x: float = level.player.position.x
	Input.action_press("move_right")
	var shot := 0
	for i in 100:
		await physics_frame
		if i >= 30 and i % 2 == 0 and shot < 30:
			level.set_physics_process(false)
			await _shoot("%02d_%s" % [shot, level.actor.current_clip])
			level.set_physics_process(true)
			shot += 1
	Input.action_release("move_right")
	print("ran %.0f px in 100 frames (speed %.0f px/s)" % [level.player.position.x - x, (level.player.position.x - x) / (100.0 / 60.0)])
	quit()
