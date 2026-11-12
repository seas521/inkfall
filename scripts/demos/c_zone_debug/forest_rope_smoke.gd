extends SceneTree

# The rope pendulum on its own (headless): grab, swing by pumping, climb, let go.
const Rope = preload("res://scripts/demos/c_zone_debug/forest_rope.gd")
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
	var rope = Rope.new()
	rope.setup(Vector2(0.0, 0.0), 210.0)
	_check(rope.grab_distance(Vector2(0.0, 120.0)) > 100.0, "hands on the rope's line take hold")
	_check(rope.grab_distance(Vector2(60.0, 120.0)) < 0.0, "hands 60 px off the line do not")
	_check(rope.grab_distance(Vector2(0.0, 10.0)) < 0.0, "above the highest hold: no")
	# jump into it at 120 px/s from the left
	_check(rope.grab(Vector2(0.0, 120.0), Vector2(120.0, 0.0)) and rope.attached, "he grabs it in the air")
	_check(rope.omega > 0.2, "and the rope takes his speed across it (omega %.2f)" % rope.omega)
	# hanging still: it settles (damped)
	for i in 600:
		rope.step(1.0 / 60.0, 0.0, 0.0)
	_check(absf(rope.angle) < 0.2, "left alone it settles (%.2f rad after 10 s)" % rope.angle)
	# pumping with the swing: the amplitude grows
	var peak := 0.0
	for i in 60 * 14:
		var push := signf(rope.omega) if absf(rope.omega) > 0.05 else 1.0
		rope.step(1.0 / 60.0, push, 0.0)
		peak = maxf(peak, absf(rope.angle))
	_check(peak > 0.9 and peak <= Rope.MAX_ANGLE + 0.001, "pumping with the swing gets a big swing (peak %.2f rad)" % peak)
	# how long to get a swing of 0.6 rad from rest (a good swing over a boulder needs about that)
	rope.setup(Vector2.ZERO, 210.0)
	rope.grab(Vector2(0.0, 120.0), Vector2.ZERO)
	var t := 0.0
	while absf(rope.angle) < 0.6 and t < 20.0:
		var push2 := signf(rope.omega) if absf(rope.omega) > 0.05 else 1.0
		rope.step(1.0 / 60.0, push2, 0.0)
		t += 1.0 / 60.0
	print("time to 0.6 rad from rest: %.1f s" % t)
	_check(t > 1.0 and t < 4.0, "a 0.6 rad swing takes %.1f s of pumping (not instant, not a chore)" % t)
	# climbing
	rope.setup(Vector2.ZERO, 210.0)
	rope.grab(Vector2(0.0, 150.0), Vector2.ZERO)
	for i in 60:
		rope.step(1.0 / 60.0, 0.0, 1.0)
	_check(absf(rope.hold - 80.0) < 4.0, "climbing up for 1 s moves the hands about 70 px (%.0f)" % (150.0 - rope.hold))
	for i in 600:
		rope.step(1.0 / 60.0, 0.0, 1.0)
	_check(is_equal_approx(rope.hold, Rope.MIN_HOLD), "he stops at the top")
	for i in 600:
		rope.step(1.0 / 60.0, 0.0, -1.0)
	_check(is_equal_approx(rope.hold, 210.0), "and at the bottom")
	# let go at the bottom of a swing: horizontal speed
	rope.setup(Vector2.ZERO, 210.0)
	rope.grab(Vector2(0.0, 120.0), Vector2.ZERO)
	rope.angle = 0.0
	rope.omega = 1.5
	var v: Vector2 = rope.release()
	_check(v.x > 200.0 and absf(v.y) < 5.0 and not rope.attached, "let go at the bottom of the swing he flies sideways (%.0f, %.0f)" % [v.x, v.y])
	_check(not rope.grab(Vector2(0.0, 120.0), Vector2.ZERO), "he cannot catch it again at once")
	print("forest rope smoke OK" if failures == 0 else "forest rope smoke: %d FAILED" % failures)
	quit()
