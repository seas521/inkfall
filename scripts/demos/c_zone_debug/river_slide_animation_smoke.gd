extends SceneTree

const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(60)
	await _push_down_bank(1.0)
	await _push_down_bank(-1.0)
	await _release_interruption()
	_animation_hysteresis()
	print("river_slide_animation_smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	level.queue_free()
	await _frames(2)
	quit(0 if failures == 0 else 1)

func _push_down_bank(direction: float) -> void:
	level.reset_all()
	level.intro_time = 0.0
	level.crate.position = Vector2(990, level.CRATE_START.y) if direction > 0.0 else Vector2(2120, level.CRATE_START.y)
	level.player.position = Vector2(945, 496) if direction > 0.0 else Vector2(2120 + level.CRATE_SIZE.x + 13, 496)
	await _frames(30)
	var input: StringName = &"move_right" if direction > 0.0 else &"move_left"
	Input.action_press("interact")
	Input.action_press(input)
	var launched := false
	var left_grip := false
	var resumed_grip := false
	var last_clip: StringName = &""
	var locomotion_changes := 0
	for i in 260:
		await physics_frame
		launched = launched or level.launching
		var clip: StringName = level.actor.current_clip
		if clip != last_clip:
			if "--trace" in OS.get_cmdline_user_args():
				print("bank=%s tick=%d clip=%s vx=%.2f dragging=%s launch=%s release=%.3f" % [direction, i, clip, level.player.velocity.x, level.dragging, level.launching, level.release_time])
			if launched and last_clip in [&"idle", &"run"] and clip in [&"idle", &"run"]:
				locomotion_changes += 1
			last_clip = clip
		if launched:
			var grip: bool = level.actor.Grip.CLIPS.has(clip)
			resumed_grip = resumed_grip or (left_grip and grip)
			left_grip = left_grip or not grip
	_check(launched, "pushing reaches the slide on bank %s" % direction)
	_check(not resumed_grip, "released slide cannot re-enter a grip animation on bank %s" % direction)
	_check(locomotion_changes <= 4, "slide collision stalls do not flicker between run and idle on bank %s (%d changes)" % [direction, locomotion_changes])
	Input.action_release(input)
	Input.action_release("interact")
	await _frames(20)

func _release_interruption() -> void:
	level.reset_all()
	await _frames(60)
	level.set_physics_process(false)
	level.player.velocity = Vector2.ZERO
	level.release_time = level.RELEASE_TIME
	level._present(1.0 / 60.0)
	_check(level.actor.current_clip == &"grip_release", "stationary release still plays its recovery animation")
	level.player.velocity.x = 40.0
	level._present(1.0 / 60.0)
	level.player.velocity.x = 0.0
	level._present(1.0 / 60.0)
	_check(level.release_time == 0.0 and level.actor.current_clip != &"grip_release", "movement permanently cancels release even if collision immediately stops the player")
	level.actor.locomotion_hold_time = 0.1
	level.restore_checkpoint()
	_check(level.actor.locomotion_hold_time == 0.0, "checkpoint reset clears animation hysteresis")
	level.set_physics_process(true)
	await _frames(60)

func _animation_hysteresis() -> void:
	var actor = level.actor
	var test_pose = level.Pose.new()
	test_pose.apply({"feet": Vector2(500, 550), "grounded": true})
	actor.landing_time = 0.0
	actor.previous_grounded = true
	var stable := true
	for i in 60:
		test_pose.velocity.x = 31.67 if i % 2 == 0 else 0.0
		actor.sync_pose(1.0 / 60.0, test_pose)
		stable = stable and actor.current_clip == &"run"
	_check(stable, "alternating collision velocities keep one locomotion clip")
	var phase: int = actor.current_frame_index
	test_pose.velocity = Vector2.ZERO
	for i in 3:
		actor.sync_pose(1.0 / 60.0, test_pose)
	_check(actor.current_clip == &"run" and actor.current_frame_index == phase, "brief stall holds actual feet phase without walking in place")
	for i in 10:
		actor.sync_pose(1.0 / 60.0, test_pose)
	_check(actor.current_clip == &"idle", "sustained stop returns to idle within the short hysteresis window")
	test_pose.velocity.x = 80.0
	actor.sync_pose(1.0 / 60.0, test_pose)
	test_pose.action = &"grip_engage"
	actor.sync_pose(1.0 / 60.0, test_pose)
	_check(actor.current_clip == &"grip_engage" and actor.locomotion_hold_time == 0.0, "grabbing interrupts locomotion immediately")
	test_pose.action = level.Pose.ACTION_NONE
	test_pose.velocity.x = 80.0
	actor.sync_pose(1.0 / 60.0, test_pose)
	test_pose.grounded = false
	test_pose.velocity.y = -300.0
	actor.sync_pose(1.0 / 60.0, test_pose)
	_check(actor.current_clip == &"takeoff" and actor.locomotion_hold_time == 0.0, "jump interrupts locomotion immediately")

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, description: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures += 1
