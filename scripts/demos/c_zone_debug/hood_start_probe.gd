extends SceneTree

# Standing start: ground speed against the start clip's frame (headless). Prints speed and clip frame every 4 physics frames.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	var level = SCENE.instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
	level.debug_enter_cliff_act()
	for i in 60:
		await physics_frame
	var x0: float = level.player.position.x
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
		if i % 4 == 0:
			var a = level.actor
			print("t=%.2f v=%.0f x=%.1f clip=%s frame=%d" % [i / 60.0, level.player.velocity.x, level.player.position.x - x0, a.current_clip, a.current_frame_index])
	Input.action_release("move_right")
	quit()
