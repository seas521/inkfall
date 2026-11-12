extends SceneTree

# The hunter of scene 1 (headless): the foot can be crossed or waited out, the arm has to be jumped, the line catches a boy who stops,
# and being taken puts him back at the last checkpoint.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const Hunter = preload("res://scripts/demos/c_zone_debug/hunter_act.gd")
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

func _feet_x() -> float:
	return level.player.position.x + 13.0

# a clean start at checkpoint `index` (his feet at `x`, standing, the hunter as the checkpoint leaves him)
func _start_at(index: int, x: float) -> void:
	level.scene1.cp = index
	level.scene1.reset()
	level.marsh_hit_time = 0.0
	level.marsh_hit_kind = ""
	level.curtain_phase = 0
	level.scene1.intro_time = 99.0
	level.player.position = Vector2(x - 13.0, Scene1.ground_top(x) - 56.0)
	level.player.velocity = Vector2.ZERO
	level.scene1.hunter.reset(index, x)
	level.scene1.hunter.enabled = true

func _release() -> void:
	Input.action_release("move_right")
	Input.action_release("jump")

func _run() -> void:
	if not Scene1.HUNTER_ON:
		print("hunter smoke OK (the hunter is switched off: Scene1.HUNTER_ON)")
		quit()
		return
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_scene1()
	await _frames(30)
	var hunter = level.scene1.hunter

	# 1. the foot: running without stopping gets him across before it lands
	_start_at(1, Scene1.CP_X[1])
	await _frames(20)
	Input.action_press("move_right")
	var crossed := false
	for i in 500:
		await physics_frame
		if _feet_x() > Hunter.FOOT_X1 + 40.0:
			crossed = true
			break
	_release()
	_check(crossed and level.marsh_hit_time <= 0.0, "running on gets him across the foot's shadow in time (x %.0f, foot phase %d)" % [_feet_x(), hunter.foot_phase])
	await _frames(240)
	_check(hunter.foot_phase == Hunter.Part.GONE, "the foot lifts away again (phase %d)" % hunter.foot_phase)

	# 2. the foot: standing clear of the shadow is safe; the foot is a wall until it lifts
	_start_at(1, Hunter.FOOT_TRIGGER + 6.0)
	await _frames(20)
	var wall_up := false
	for i in 600:
		await physics_frame
		if hunter.foot_phase == Hunter.Part.REST and not hunter.wall_shape.disabled:
			wall_up = true
		if hunter.foot_phase == Hunter.Part.GONE:
			break
	_check(wall_up and level.marsh_hit_time <= 0.0, "standing clear he is not hurt and the foot stands as a wall (hit %.2f)" % level.marsh_hit_time)
	_check(hunter.wall_shape.disabled, "the wall goes when the foot lifts")

	# 3. the foot: standing under it is death
	_start_at(1, (Hunter.FOOT_X0 + Hunter.FOOT_X1) * 0.5)
	hunter.reset(1, _feet_x())
	await _frames(20)
	var crushed := false
	for i in 400:
		await physics_frame
		if level.marsh_hit_time > 0.0:
			crushed = true
			break
	_check(crushed and level.marsh_hit_kind == "crush", "under the foot he is crushed (%s)" % level.marsh_hit_kind)
	# ... and taken, he comes back at the checkpoint, on his feet
	for i in 400:
		await physics_frame
		if level.curtain_phase == 2:
			break
	await _frames(20)
	_check(absf(_feet_x() - Scene1.CP_X[level.scene1.cp]) < 30.0 and level.scene1.intro_time >= 99.0 and level.marsh_hit_time <= 0.0, "taken, he is back on his feet at the checkpoint (x %.0f, cp %d)" % [_feet_x(), level.scene1.cp])

	# 4. the arm: not jumping is death, jumping at the right moment is not
	_start_at(2, Scene1.CP_X[2])
	await _frames(20)
	Input.action_press("move_right")
	var hit := false
	for i in 600:
		await physics_frame
		if level.marsh_hit_time > 0.0:
			hit = true
			break
	_release()
	_check(hit and level.marsh_hit_kind == "rock", "the arm's band takes him if he runs on (x %.0f)" % _feet_x())
	for i in 400:
		await physics_frame
		if level.curtain_phase == 2:
			break
	await _frames(20)
	_start_at(2, Scene1.CP_X[2])
	await _frames(20)
	Input.action_press("move_right")
	var jumped_until := -1
	var survived := false
	for i in 700:
		await physics_frame
		var band = hunter.arm_x()
		if band != null and jumped_until < 0 and _feet_x() - float(band) < 300.0 and _feet_x() - float(band) > 0.0:
			Input.action_press("jump")
			jumped_until = i + 24
		if jumped_until >= 0 and i >= jumped_until:
			Input.action_release("jump")
		if level.marsh_hit_time > 0.0:
			break
		if hunter.arm_phase == Hunter.Part.GONE:
			survived = true
			break
	_release()
	_check(survived and level.marsh_hit_time <= 0.0, "jumping the band he is not hurt (x %.0f, arm phase %d, hit %.2f)" % [_feet_x(), hunter.arm_phase, level.marsh_hit_time])

	# 5. the line catches a boy who stops
	_start_at(2, Scene1.CP_X[2])
	await _frames(20)
	var caught := false
	for i in 900:
		await physics_frame
		if level.marsh_hit_time > 0.0:
			caught = true
			break
	_check(caught, "standing still the line catches him (gap %.0f)" % hunter.gap)

	# the hunter is quiet before the pond
	_start_at(0, Scene1.START_X + 1200.0)
	await _frames(300)
	_check(not hunter.started and hunter.pressure < 0.1 and level.marsh_hit_time <= 0.0, "far from the cliff there is no chase yet (pressure %.2f)" % hunter.pressure)

	print("hunter smoke OK" if failures == 0 else "hunter smoke: %d FAILED" % failures)
	quit()
