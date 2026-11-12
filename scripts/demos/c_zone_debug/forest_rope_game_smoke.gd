extends SceneTree

# The rope in the game (headless, the hooded boy): the hillside above the lift, the practice rope: jump to it, grab, climb, swing,
# let go and land.
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

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_forest_act()
	await _frames(40)
	var forest = level.forest
	var ground: float = forest.ground_y(level.player.position.x + 13.0)
	_check(level.player.is_on_floor() and absf(level.player.position.y + 54.0 - ground) < 3.0, "he stands on the hillside above the lift (feet %.1f, ground %.1f)" % [level.player.position.y + 54.0, ground])
	_check(not forest.rope_attached(), "not holding anything yet")
	# stand under the rope: it is out of reach (his hands are below its end)
	level.player.position = Vector2(forest.VINE_PIVOT.x - 13.0, forest.FLOOR_Y - 56.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	forest.try_grab(level.player)
	_check(not forest.rope_attached(), "standing he cannot reach the rope")
	# jump at it
	Input.action_press("jump")
	await _frames(30)
	Input.action_release("jump")
	var grabbed := false
	for i in 90:
		await physics_frame
		if forest.rope_attached():
			grabbed = true
			break
	_check(grabbed, "a jump at the rope takes hold of it")
	var start_hold: float = forest.ropes[0].hold
	# climb up
	Input.action_press("aim_up")
	await _frames(40)
	Input.action_release("aim_up")
	_check(forest.ropes[0].hold < start_hold - 30.0, "up climbs (hands %.0f -> %.0f px under the branch)" % [start_hold, forest.ropes[0].hold])
	# swing by pumping with the swing
	var peak := 0.0
	for i in 60 * 5:
		var push := signf(forest.ropes[0].omega) if absf(forest.ropes[0].omega) > 0.05 else 1.0
		if push > 0.0:
			Input.action_release("move_left")
			Input.action_press("move_right")
		else:
			Input.action_release("move_right")
			Input.action_press("move_left")
		await physics_frame
		peak = maxf(peak, absf(forest.ropes[0].angle))
	Input.action_release("move_left")
	Input.action_release("move_right")
	print("swing peak %.2f rad" % peak)
	_check(peak > 0.45, "the arrows swing him (peak %.2f rad)" % peak)
	var hang: Dictionary = forest.hang_info()
	_check(not hang.is_empty(), "the actor is hung along the rope")
	# let go on the way out
	while forest.ropes[0].omega < 0.8 or forest.ropes[0].angle < 0.1:
		await physics_frame
		var push2 := signf(forest.ropes[0].omega)
		if push2 > 0.0:
			Input.action_press("move_right")
		else:
			Input.action_release("move_right")
	Input.action_release("move_right")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_check(not forest.rope_attached() and level.player.velocity.x > 60.0, "jump lets go and he flies on (vx %.0f)" % level.player.velocity.x)
	var landed := false
	for i in 200:
		await physics_frame
		if level.player.is_on_floor():
			landed = true
			break
	_check(landed, "and lands on the ground again")
	var ground2: float = forest.ground_y(level.player.position.x + 13.0)
	_check(absf(level.player.position.y + 54.0 - ground2) < 4.0, "on the ground, not through it (feet %.1f, ground %.1f)" % [level.player.position.y + 54.0, ground2])
	print("forest rope game smoke OK" if failures == 0 else "forest rope game smoke: %d FAILED" % failures)
	quit()
