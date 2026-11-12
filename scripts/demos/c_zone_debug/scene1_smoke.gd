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
	level.scene1.cut = Scene1.Cut.NONE  # (running past the cliff line in an earlier test started the cliff sequence)
	level.scene1.flock_on = false

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
	level.scene1.spider.enabled=false # independently exercised by forest_spider_smoke.gd
	level.scene1.predator.enabled=false # encounter is exercised by forest_predator_smoke.gd
	if level.scene1.hunter != null:
		level.scene1.hunter.enabled = false  # (the route tests run without him: hunter_smoke.gd has the hunter)
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
	var mound := _feature("mound", 1)  # (the first mound is the long rise to the cliff)
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
	# the first pit (78 wide, spikes at the bottom): a running jump clears it
	var pit := _feature("pit", 0)
	_put(float(pit["x"]) - 150.0)
	await _frames(20)
	await _run_and_jump(Scene1.fx(pit), 24.0)
	await _frames(60)
	Input.action_release("move_right")
	_check(level.player.position.x > Scene1.fx(pit) + float(pit["w"]) and level.player.is_on_floor(), "a running jump clears the small pit (x %.0f)" % level.player.position.x)
	# ... and walking in is death: he starts again
	level.scene1.intro_time = 99.0
	_put(float(pit["x"]) - 30.0)
	await _frames(10)
	Input.action_press("move_right")
	var hit := false
	var restarted := false
	for i in 700:
		await physics_frame
		if level.marsh_hit_time > 0.0:
			hit = true
		if level.player.position.x < Scene1.START_X + 300.0:
			restarted = true
			break
	Input.action_release("move_right")
	_check(hit and restarted, "falling onto the spikes in the pit is death and he starts again (hit %s, restarted %s)" % [hit, restarted])
	level.scene1.intro_time = 99.0
	await _frames(60)
	# surface brambles: jumping clears them; contact trips him without a restart
	var spikes := _feature("spikes", 0)
	_put(float(spikes["x"]) - 150.0)
	await _frames(20)
	await _run_and_jump(Scene1.fx(spikes), 26.0)
	await _frames(60)
	Input.action_release("move_right")
	_check(level.player.position.x > Scene1.fx(spikes) + float(spikes["w"]) and level.marsh_hit_time <= 0.0, "a jump clears the thorns (x %.0f)" % level.player.position.x)
	_put(float(spikes["x"]) - 60.0)
	await _frames(10)
	var trips_before:int=level.scene1.trip_count
	var seen_trip:Dictionary={}
	var locked_trip:=true
	var no_death:=true
	var trip_x:=0.0
	Input.action_press("move_right")
	for i in 300:
		await physics_frame
		no_death=no_death and level.marsh_hit_time<=0 and level.curtain_phase==0
		if level.scene1.tripping():
			if trip_x==0:trip_x=_feet().x
			seen_trip[level.scene1.pose_info().action]=true
			locked_trip=locked_trip and level.scene1.locks_move() and level.scene1.locks_jump() and absf(_feet().x-trip_x)<2
		elif level.scene1.trip_count>trips_before:break
	Input.action_release("move_right")
	_check(no_death and seen_trip.has(&"fall_impact") and seen_trip.has(&"downed") and seen_trip.has(&"get_up"), "bramble contact falls, pauses and gets up without death or a checkpoint restart")
	_check(locked_trip and not level.scene1.tripping() and not level.scene1.locks_move(), "falling and getting up briefly lock controls then restore movement in place")
	await _frames(90)
	_check(level.scene1.trip_count==trips_before+1 and not level.scene1.tripping(), "standing in the bramble after getting up does not cause a repeated fall")
	Input.action_press("move_right")
	await _frames(80)
	Input.action_release("move_right")
	_check(_feet().x>Scene1.fx(spikes)+float(spikes["w"])+18 and level.scene1.trip_count==trips_before+1, "he can continue through and out of the bramble after recovering")
	Input.action_press("move_left")
	for i in 160:
		await physics_frame
		if level.scene1.tripping():break
	Input.action_release("move_left")
	_check(level.scene1.trip_count==trips_before+2 and level.scene1.tripping(), "returning after leaving the bramble can trip him again")
	await _frames(180)
	# The former boulder is now a short, reusable low-stance passage.
	level.scene1.intro_time=99.0
	_put(3860)
	await _frames(20)
	Input.action_press("move_right")
	var saw_low:=false
	for i in 2400:
		await physics_frame
		saw_low=saw_low or level.scene1.low_stance.active()
		if _feet().x>Scene1.Crevice.EXIT_SAFE+15:break
	Input.action_release("move_right")
	await _frames(50)
	_check(saw_low and _feet().x>Scene1.Crevice.EXIT_SAFE+15 and not level.scene1.low_stance.active(), "the short rock passage bends, traverses, and stands up without a climb (x %.1f, low %s)" % [_feet().x-Scene1.START_X,level.scene1.low_stance.active()])
	# a shallow pond: slower, and the water reacts
	var pond := _feature("pond", 0)
	_put(float(pond["x"]) - 120.0)
	await _frames(40)
	Input.action_press("move_right")
	var slow_speed := 9999.0
	var max_wave := 0.0
	for i in 200:
		await physics_frame
		for h in level.scene1.pools[0].wave_h:
			max_wave = maxf(max_wave, absf(h))
		if level.player.position.x + 13.0 > Scene1.fx(pond) + 80.0 and level.player.position.x + 13.0 < Scene1.fx(pond) + float(pond["w"]) - 80.0:
			slow_speed = minf(slow_speed, absf(level.player.velocity.x))
	Input.action_release("move_right")
	_check(slow_speed < 100.0, "wading a pond is slower than running (%.0f px/s)" % slow_speed)
	_check(max_wave > 0.5, "stepping into the pond sets up waves (%.2f)" % max_wave)
	# the fallen logs
	var log_feature := _feature("log", 0)
	_put(float(log_feature["x"]) - 220.0)
	await _frames(20)
	await _run_and_jump(Scene1.fx(log_feature), 40.0)
	await _finish_climb()
	await _frames(200)
	Input.action_release("move_right")
	_check(level.player.position.x > Scene1.fx(log_feature) + float(log_feature["len"]) and level.player.is_on_floor(), "the low fallen tree can be climbed over (x %.0f)" % level.player.position.x)
	# nothing to the west but forest: he runs left as far as the world lets him and just stops (no cliff, no fall)
	level.player.position.x = Scene1.WORLD_LEFT + 700.0
	level.player.position.y = Scene1.ground_top(level.player.position.x) - 56.0
	await _frames(10)
	Input.action_press("move_left")
	await _frames(300)
	Input.action_release("move_left")
	_check(level.player.is_on_floor() and level.player.position.x >= Scene1.WORLD_LEFT and level.marsh_hit_time <= 0.0, "running west he is stopped by the forest, not by a cliff (x %.0f)" % level.player.position.x)
	# the cliff, computer-controlled: past AUTO_X he walks on by himself (slower and slower, keys and jumps ignored), stops short of the
	# edge bent over, the flock comes, strikes him down, he gets up, and then the controls are his
	level.scene1.intro_time = 99.0
	level.scene1.reset()
	level.scene1.intro_time = 99.0
	level.player.position = Vector2(Scene1.AUTO_X - 80.0 - 13.0, Scene1.ground_top(Scene1.AUTO_X - 80.0) - 56.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	Input.action_press("move_right")
	for i in 200:
		await physics_frame
		if level.scene1.cut == Scene1.Cut.WALK:
			break
	Input.action_release("move_right")
	_check(level.scene1.cut == Scene1.Cut.WALK, "past the line the computer takes over (x %.0f)" % (level.player.position.x + 13.0))
	var fast_speed := 0.0
	var slow_walk := 9999.0
	var seen := {}
	var jumped_y := 1.0e9
	var flock_seen := false
	var control_back := false
	Input.action_press("move_left")  # the keys do nothing now
	Input.action_press("jump")
	for i in 2400:
		await physics_frame
		var sc = level.scene1
		seen[sc.pose_info().action] = true
		if sc.cut == Scene1.Cut.WALK:
			fast_speed = maxf(fast_speed, absf(level.player.velocity.x))
			slow_walk = minf(slow_walk, absf(level.player.velocity.x))
			jumped_y = minf(jumped_y, level.player.position.y)
		if sc.flock_clock() >= 0.0:
			flock_seen = true
		if sc.cut == Scene1.Cut.GETUP:
			Input.action_release("move_left")
			Input.action_release("jump")
		if sc.cut == Scene1.Cut.DONE:
			control_back = true
			break
	Input.action_release("move_left")
	Input.action_release("jump")
	_check(fast_speed < 140.0 and slow_walk < 70.0, "the walk slows down (%.0f -> %.0f px/s)" % [fast_speed, slow_walk])
	_check(jumped_y > Scene1.ground_top(Scene1.PANT_X) - 70.0, "he does not jump while the computer walks him")
	_check(seen.has(&"tired_stop") and seen.has(&"pant") and seen.has(&"knockdown") and seen.has(&"downed") and seen.has(&"get_up"), "he staggers to a stop, pants, is struck down, lies, gets up (%s)" % [seen.keys()])
	_check(flock_seen, "the flock comes")
	_check(control_back and level.player.position.x + 13.0 > Scene1.PANT_X - 20.0 and level.player.position.x + 13.0 < Scene1.CLIFF_X, "the walk ended short of the edge (x %.0f)" % (level.player.position.x + 13.0))
	_check(not level.scene1.locks_move() and not level.scene1.locks_jump(), "the controls are his again")
	if Scene1.HUNTER_ON:
		# the hand: he stands where he got up; its shadow comes, the hand comes down and the edge breaks away under him
		var broke := false
		for i in 900:
			await physics_frame
			if Scene1.broken_from < Scene1.CLIFF_X - 10.0 and level.marsh_hit_time > 0.0:
				broke = true
				break
		_check(broke, "the hand breaks the edge away under him (edge now at %.0f)" % Scene1.edge_x())
		_check(level.scene1.cut == Scene1.Cut.SLAM, "the cliff sequence ends in the slam")
		for i in 600:
			await physics_frame
			if level.curtain_phase == 2:
				break
		await _frames(20)
		_check(Scene1.broken_from > 1.0e8 and level.player.position.x + 13.0 < Scene1.CLIFF_X - 300.0 and level.marsh_hit_time <= 0.0, "he falls, and starts again at a checkpoint with the edge whole (x %.0f)" % (level.player.position.x + 13.0))
	# Running off the cliff continues into the playable log bridge.
	level.scene1.cp = 3
	_put(Scene1.CLIFF_X-Scene1.START_X-100.0)
	await _frames(20)
	Input.action_press("move_right")
	var entered_descent := false
	for i in 900:
		await physics_frame
		if level.log_bridge.active and not level.descent.enabled:
			entered_descent = true
			break
	Input.action_release("move_right")
	_check(entered_descent and level.curtain_phase == 0, "running off the cliff enters the playable log bridge without a death curtain")
	print("scene 1 smoke OK" if failures == 0 else "scene 1 smoke: %d FAILED" % failures)
	quit(0 if failures == 0 else 1)
