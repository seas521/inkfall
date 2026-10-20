extends SceneTree

# The hooded boy pushing the boat into the water (it slides in by itself): no flicker between clips, and the contact
# alignment never jumps. Run: godot --headless --path . --script res://scripts/demos/c_zone_debug/hood_slide_smoke.gd
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		print("FAIL: ", description)

func _run() -> void:
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 60:
		await physics_frame
	for direction in [1.0, -1.0]:
		await _push_down_bank(direction)
	print("hood slide smoke ", "OK" if failures == 0 else "FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)

func _push_down_bank(direction: float) -> void:
	level.reset_all()
	level.intro_time = 0.0
	level.crate.position = Vector2(990, level.CRATE_START.y) if direction > 0.0 else Vector2(2120, level.CRATE_START.y)
	level.player.position = Vector2(945, 496) if direction > 0.0 else Vector2(2120 + level.CRATE_SIZE.x + 13, 496)
	for i in 30:
		await physics_frame
	var input: StringName = &"move_right" if direction > 0.0 else &"move_left"
	Input.action_press("interact")
	Input.action_press(input)
	var launched := false
	var last_clip: StringName = &""
	var changes_after_launch := 0
	var max_jump := 0.0
	var last_offset: float = level.actor.grip_offset_x
	var trace := []
	for i in 300:
		await physics_frame
		launched = launched or level.launching
		var clip: StringName = level.actor.current_clip
		if clip != last_clip:
			if launched:
				changes_after_launch += 1
			trace.append("%d:%s" % [i, clip])
			last_clip = clip
		max_jump = maxf(max_jump, absf(level.actor.grip_offset_x - last_offset))
		last_offset = level.actor.grip_offset_x
	print("trace bank %s: %s" % [direction, " ".join(trace)])
	_check(launched, "pushing reaches the slide on bank %s" % direction)
	_check(changes_after_launch <= 8, "no flicker between clips once it slides on bank %s (%d changes)" % [direction, changes_after_launch])
	_check(max_jump <= 4.6, "the contact alignment never jumps on bank %s (largest step %.2f px)" % [direction, max_jump])
	Input.action_release(input)
	Input.action_release("interact")
	for i in 20:
		await physics_frame
