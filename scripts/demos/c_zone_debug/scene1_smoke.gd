extends SceneTree

# Scene 1 (headless): he lies, gets up, runs; mounds, pits, boulders, ponds and the trunk can be crossed.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
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

func _feet() -> Vector2:
	return level.player.position + Vector2(13.0, 54.0)

func _put(offset: float) -> void:
	var x: float = Scene1.START_X + offset
	level.player.position = Vector2(x - 13.0, Scene1.ground_top(x) - 56.0)
	level.player.velocity = Vector2.ZERO

# run right and jump when `gap` px are left to the obstacle's edge, hold right all the time
func _run_and_jump(edge_x: float, gap: float) -> void:
	Input.action_press("move_right")
	for i in 400:
		await physics_frame
		if level.player.position.x + 26.0 >= edge_x - gap:
			break
	Input.action_press("jump")
	await _frames(28)
	Input.action_release("jump")

# until the climb that has started is over (or nothing started within a second)
func _finish_climb() -> void:
	for i in 60:
		await physics_frame
		if level.climb_time >= 0.0:
			break
	for i in 400:
		await physics_frame
		if level.climb_time < 0.0:
			break

func _feature(kind: String, nth := 0) -> Dictionary:
	var n := 0
	for f: Dictionary in Scene1.FEATURES:
		if String(f["t"]) == kind:
			if n == nth:
				return f
			n += 1
	return {}

func _run() -> void:
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_scene1()
	await _frames(20)
	_check(level.player.is_on_floor() and absf(_feet().y - Scene1.GROUND_Y) < 3.0, "he lies on the ground (feet %.1f, ground %.1f)" % [_feet().y, Scene1.GROUND_Y])
	var x0: float = level.player.position.x
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check(absf(level.player.position.x - x0) < 1.0, "while he lies he cannot be moved")
	await _frames(240)
	_check(not level.scene1.locks_move(), "after the get-up the controls are his")
	# a mound: he runs over it and stays on the ground
	var mound := _feature("mound", 0)
	_put(float(mound["x"]) - 330.0)
	await _frames(20)
	Input.action_press("move_right")
	var on_top := false
	for i in 240:
		await physics_frame
		if absf(level.player.position.x + 13.0 - Scene1.fx(mound)) < 20.0 and level.player.is_on_floor():
			on_top = absf(_feet().y - Scene1.ground_top(Scene1.fx(mound))) < 4.0
	Input.action_release("move_right")
	_check(on_top, "he runs up over the mound and stands on its top")
	# the first pit
	var pit := _feature("pit", 0)
	_put(float(pit["x"]) - 150.0)
	await _frames(20)
	await _run_and_jump(Scene1.fx(pit), 24.0)
	await _frames(60)
	Input.action_release("move_right")
	_check(level.player.position.x > Scene1.fx(pit) + float(pit["w"]) and level.player.is_on_floor(), "a running jump clears the small pit (x %.0f)" % level.player.position.x)
	# the small pit is not deadly: he grabs the far lip as he falls and climbs out (it costs time)
	_put(float(pit["x"]) - 40.0)
	await _frames(10)
	Input.action_press("move_right")
	await _frames(400)
	Input.action_release("move_right")
	_check(level.player.is_on_floor() and level.player.position.x > Scene1.fx(pit) + float(pit["w"]) and absf(_feet().y - Scene1.GROUND_Y) < 8.0, "falling into the small pit he climbs out on the far side (x %.0f)" % level.player.position.x)
	# a wide pit is: he falls and starts again
	var wide := _feature("pit", 2)
	_put(float(wide["x"]) - 40.0)
	await _frames(10)
	Input.action_press("move_right")
	var restarted := false
	for i in 500:
		await physics_frame
		if level.player.position.x < Scene1.START_X + 300.0:
			restarted = true
			break
	Input.action_release("move_right")
	_check(restarted, "falling into the wide pit puts him back at the start")
	# the first boulder: climb on and over it
	level.scene1.intro_time = 99.0
	var boulder := _feature("boulder", 0)
	var edge_x := Scene1.fx(boulder) - float(boulder["bottom"]) * 0.5
	_put(float(boulder["x"]) - 230.0)
	await _frames(20)
	await _run_and_jump(edge_x, 40.0)
	await _finish_climb()
	await _frames(150)
	Input.action_release("move_right")
	_check(level.player.position.x > Scene1.fx(boulder) + float(boulder["bottom"]) * 0.5, "the first boulder can be climbed over (x %.0f)" % level.player.position.x)
	# a shallow pond: slower
	var pond := _feature("pond", 0)
	_put(float(pond["x"]) - 120.0)
	await _frames(40)
	Input.action_press("move_right")
	var slow_speed := 9999.0
	for i in 200:
		await physics_frame
		if level.player.position.x + 13.0 > Scene1.fx(pond) + 80.0 and level.player.position.x + 13.0 < Scene1.fx(pond) + float(pond["w"]) - 80.0:
			slow_speed = minf(slow_speed, absf(level.player.velocity.x))
	Input.action_release("move_right")
	_check(slow_speed < 100.0, "wading a pond is slower than running (%.0f px/s)" % slow_speed)
	# the fallen trunk
	var trunk := _feature("trunk", 0)
	_put(float(trunk["x"]) - 220.0)
	await _frames(20)
	await _run_and_jump(Scene1.fx(trunk), 40.0)
	await _finish_climb()
	await _frames(200)
	Input.action_release("move_right")
	_check(level.player.position.x > Scene1.fx(trunk) + float(trunk["len"]) and level.player.is_on_floor(), "the fallen trunk can be climbed over (x %.0f)" % level.player.position.x)
	print("scene 1 smoke OK" if failures == 0 else "scene 1 smoke: %d FAILED" % failures)
	quit()
