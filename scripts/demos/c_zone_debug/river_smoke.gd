extends SceneTree

const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const TreeRoute = preload("res://scripts/demos/c_zone_debug/tree_fan_route.gd")
var level
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	if capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(100)
	_check(level.player.is_on_floor(), "spawn settles on the wide bank")
	await _shot("01-bank")
	_check(await TreeRoute.climb(level),"raft and rack provide the route to the tree")
	_check(await TreeRoute.collect(level),"airborne F collects the tree leaf")
	Input.action_press("move_right")
	await _until(func(): return level.player.position.x>615.0,150)
	Input.action_release("move_right")
	await _frames(65)
	Input.action_press("interact")
	await _frames(30)
	Input.action_release("interact")
	_check(not level.fan_owned and not level.fan_on_tree,"collected leaf can be set down before moving the raft")
	Input.action_press("move_left")
	await _until(func(): return level.player.position.x < level.crate.position.x + level.CRATE_SIZE.x + 28.0, 140)
	Input.action_release("move_left")
	await _frames(10)
	Input.action_press("interact")
	await _frames(45)
	_check(level.dragging and level.actor.current_clip == &"grip_hold", "F engages the nearby crate side and holds without running")
	Input.action_press("move_right")
	await _frames(35)
	_check(level.dragging and level.facing < 0.0 and level.player.velocity.x > 0.0, "front-side pull faces the crate while walking backward")
	_check(level.actor.current_clip == &"pull", "pull selects its own full-frame animation")
	_check(absf(level.player.position.x - level.grip_target_x()) < 3.0, "physical grip spacing stays stable beside the crate")
	await _shot("02a-crate-pull")
	Input.action_release("move_right")
	await _frames(24)
	var held_distance: float = level.grip_distance
	var held_frame: int = level.actor.current_frame_index
	await _frames(20)
	_check(level.dragging and level.actor.current_clip == &"grip_hold", "stopping movement keeps contact with the crate")
	_check(is_equal_approx(level.grip_distance, held_distance) and level.actor.current_frame_index == held_frame, "stationary grip does not slide through a walk cycle")
	Input.action_press("move_left")
	await _frames(25)
	_check(level.actor.current_clip == &"push" and level.facing < 0.0, "moving toward the crate from its right side selects push")
	await _shot("02b-crate-push")
	Input.action_release("move_left")
	Input.action_press("move_right")
	await _until(func(): return level.crate.position.x > 700.0, 250)
	Input.action_release("interact")
	Input.action_release("move_right")
	await _frames(8)
	_check(not level.dragging, "releasing F lets go of the crate")
	_check(level.crate.position.x > 680.0, "rightward pulling exits the open broken frame")
	_check(level.fan_revealed and not level.fan_on_tree, "moving the raft preserves the previously dropped leaf")
	await _shot("02-crate-pulled")
	# Jump over the crate to collect the revealed tool behind it.
	Input.action_press("move_left")
	Input.action_press("jump")
	await _frames(37)
	Input.action_release("jump")
	await _until(func(): return level.player.position.x < level.fan_rest_position().x+2.0, 130)
	Input.action_release("move_left")
	await _frames(32)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(24)
	_check(level.fan_owned, "fan pickup works after returning around the box")
	# Push the same box down the bank and release it in the water.
	Input.action_press("move_right")
	await _until(func(): return level.player.position.x > level.crate.position.x-52.0, 160)
	Input.action_release("move_right")
	await _frames(5)
	Input.action_press("interact")
	Input.action_press("move_right")
	await _until(func(): return level.floating and not level.launching, 600)
	Input.action_release("interact")
	Input.action_release("move_right")
	await _frames(50)
	_check(level.floating, "box gains buoyancy at the bank")
	_check(level.checkpoint == 1, "river recovery checkpoint recorded")
	var rest_x: float = level.crate.position.x
	await _frames(120)
	_check(absf(level.crate.position.x-rest_x)<2.0, "floating box stays still without wind")
	_check(absf(level.crate_tilt) < deg_to_rad(6.0), "raft settles nearly level after water entry")
	_check(absf(level.crate_shape.rotation-level.crate_tilt)<0.001, "collision follows the drawn crate angle")
	var bottom: Vector2 = level.crate.position + level.CRATE_SIZE*0.5 + (level.CRATE_SIZE*0.5).rotated(level.crate_tilt)
	_check(bottom.y > level.WATER_Y+10.0, "lower crate corner is submerged")
	await _shot("03-floating")
	await _retrieve_fan()
	# A normal held jump must reach the floating box from the shallow bank.
	Input.action_press("jump")
	Input.action_press("move_right")
	await _until(func(): return level.player.position.x > level.crate.position.x+30.0, 45)
	Input.action_release("move_right")
	await _frames(40)
	Input.action_release("jump")
	await _frames(12)
	_check(level.is_riding(), "player can board the floating box using normal jump input")
	_check(level.load_sink > 6.0, "rider weight sinks the floating box")
	var before_swing: int = level.wind_impulses
	Input.action_press("blade_toggle")
	await _frames(2)
	_check(level.wind_impulses == before_swing+1, "keyboard fan action remains available without a HUD button")
	await _until(func(): return level.crate.position.x > 1540.0, 350)
	await _shot("03b-riding-in-water")
	await _until(func(): return level.beached, 400)
	Input.action_release("blade_toggle")
	await _frames(90)
	_check(level.beached and not level.floating and level.crate.position.x + level.CRATE_SIZE.x > 1950.0, "the raft bow grounds on the opposite shallows")
	_check(level.wind_impulses > 2, "crossing is driven by repeated wind impulses")
	var shore_x: float = level.crate.position.x
	var shore_impulses: int = level.wind_impulses
	Input.action_press("blade_toggle")
	await _frames(140)
	Input.action_release("blade_toggle")
	_check(absf(level.crate.position.x - shore_x) < 2.0 and level.wind_impulses == shore_impulses, "continued fan strokes cannot move a grounded crate")
	await _shot("04-arrival")
	Input.action_press("move_right")
	Input.action_press("jump")
	await _frames(38)
	Input.action_release("jump")
	Input.action_release("move_right")
	await _frames(40)
	Input.action_press("move_left")
	await _until(func(): return level.player.position.x < level.crate.position.x+level.CRATE_SIZE.x+23.0, 100)
	Input.action_release("move_left")
	await _frames(8)
	Input.action_press("interact")
	Input.action_press("move_right")
	await _until(func(): return level.crate.position.x > 1950.0, 260)
	_check(level.dragging and level.crate_tilt < deg_to_rad(-10.0), "pulling out of the river follows the right-bank slope instead of staying upright")
	await _shot("04b-uphill-pull")
	await _until(func(): return level.crate.position.x > 2260.0, 520)
	Input.action_release("interact")
	Input.action_release("move_right")
	await _frames(10)
	_check(level.landed and level.checkpoint == 2, "the same box remains draggable after beaching")
	_check(absf(level.crate_tilt)<0.01, "beaching settles the crate upright again")
	await _shot("05-beached-box")
	await _round_trip()
	# Recovery must retain the tool and reset an abandoned mid-river crate.
	level.checkpoint = 1
	level.checkpoint_fan = true
	level.player.position = Vector2(1560,680)
	await _frames(180)
	_check(level.player.position.x < 1200.0 and level.crate.position.x < 1250.0, "drowning recovers both player and raft")
	_check(level.fan_owned, "drowning preserves the acquired fan")
	level.reset_all()
	await _frames(60)
	_check(not level.fan_owned and level.checkpoint == 0 and level.crate.position.x < 450.0, "full restart resets the entire first act")
	await _grip_edges()
	await _animation_assets()
	await _launch_edges()
	await _right_launch_edges()
	print("c_zone_river_smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	level.queue_free()
	await _frames(2)
	quit(0 if failures == 0 else 1)

func _grip_edges() -> void:
	level.crate.position = Vector2(750,level.CRATE_START.y)
	level.player.position = Vector2(705,496)
	await _frames(20)
	Input.action_press("interact")
	Input.action_press("move_left")
	await _frames(80)
	_check(level.dragging and level.facing > 0.0 and level.actor.current_clip == &"pull" and level.crate.position.x < 700.0, "moving away from the crate on its left side selects backward pull")
	Input.action_release("move_left")
	Input.action_press("move_right")
	await _frames(25)
	_check(level.dragging and level.facing > 0.0 and level.actor.current_clip == &"push", "moving toward the crate from its left side selects push")
	Input.action_press("jump")
	await _frames(3)
	_check(not level.dragging and level.player.velocity.y < 0.0 and level.actor.current_clip not in [&"pull", &"push"], "jump releases the crate immediately and uses jump animation")
	Input.action_release("jump")
	Input.action_release("interact")
	Input.action_release("move_left")
	Input.action_release("move_right")
	level.restore_checkpoint()
	level.crate.position = Vector2(750,level.CRATE_START.y)
	level.player.position = Vector2(750 + level.CRATE_SIZE.x + 18.5,496)
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(30,200)
	shape.shape = rectangle
	wall.position = Vector2(970,450)
	wall.add_child(shape)
	level.add_child(wall)
	await _frames(20)
	Input.action_press("interact")
	Input.action_press("move_right")
	await _frames(145)
	var blocked_x: float = level.crate.position.x
	var blocked_distance: float = level.grip_distance
	await _frames(30)
	_check(level.dragging and level.actor.current_clip == &"grip_hold" and absf(level.crate.position.x-blocked_x) < 0.1, "a blocked puller stops the box without running in place")
	_check(absf(level.grip_distance-blocked_distance) < 0.1 and absf(level.player.position.x-level.grip_target_x()) < 3.0, "blocked grip keeps both spacing and animation phase stable")
	Input.action_release("interact")
	Input.action_release("move_right")
	wall.queue_free()
	await _frames(20)
	level.player.position = Vector2(300,496)
	await _frames(15)
	Input.action_press("interact")
	await _frames(3)
	_check(not level.dragging, "F cannot grab a distant crate")
	Input.action_release("interact")
	level.reset_all()
	await _frames(60)
	_check(not level.dragging and level.grip_time == 0.0 and level.release_time == 0.0 and level.grip_distance == 0.0, "reset clears all grip transition and phase state")
	_check(level.actor.movement_clip == &"" and level.actor.held_clip == &"grip_hold", "reset clears cached Seedance effort poses")

func _animation_assets() -> void:
	var grip = preload("res://scripts/demos/c_zone_debug/seedance_grip_manifest.gd")
	var valid := true
	for clip: StringName in grip.CLIPS:
		for i in int(grip.CLIPS[clip].frames):
			var texture := load(grip.frame_path(clip, i)) as Texture2D
			valid = valid and texture != null
			if texture != null:
				valid = valid and Vector2i(texture.get_size()) == grip.CANVAS
	_check(valid, "all C-only Seedance frames load on the fixed 384x320 canvas")
	var test_pose = level.Pose.new()
	test_pose.apply({"feet": Vector2(500, 550), "grounded": true, "facing": 1.0, "visual_scale": 0.9})
	for action: StringName in [&"grip_engage", &"push", &"pull", &"grip_hold", &"grip_release"]:
		test_pose.action = action
		test_pose.action_progress = 0.5
		level.actor.sync_pose(1.0 / 60.0, test_pose)
		_check(level.actor.position == test_pose.feet and level.actor.animated.position == -grip.ROOT and level.actor.animated.scale == Vector2.ONE, "%s preserves feet anchor and source scale" % action)
	test_pose.action = &"pull"
	level.actor.grip_distance = 300.0
	level.actor.sync_pose(1.0 / 60.0, test_pose)
	var frozen_animation: StringName = level.actor.animated.animation
	var frozen_frame: int = level.actor.animated.frame
	test_pose.action = &"grip_hold"
	level.actor.sync_pose(1.0 / 60.0, test_pose)
	_check(level.actor.animated.animation == frozen_animation and level.actor.animated.frame == frozen_frame, "stop preserves the exact moving texture, not a replacement hold pose")
	level.reset_all()
	await _frames(60)

func _round_trip() -> void:
	var original_box = level.crate
	Input.action_press("interact")
	Input.action_press("move_left")
	await _until(func(): return level.launching, 260)
	_check(level.launching and level.launch_direction < 0.0, "the same crate can re-enter water from the right bank after arrival")
	await _until(func(): return level.crate.position.x < 2020.0, 260)
	_check(level.crate_tilt < deg_to_rad(-10.0), "right-bank launch mirrors the forward tilt on the left bank")
	await _shot("09-return-descent")
	await _until(func(): return level.floating and not level.launching, 400)
	Input.action_release("interact")
	Input.action_release("move_left")
	await _frames(50)
	_check(level.floating and not level.beached and level.landed, "arrival progress does not disable buoyancy on the return trip")
	await _retrieve_fan()
	Input.action_press("jump")
	Input.action_press("move_left")
	await _until(func(): return level.player.position.x < level.crate.position.x + 45.0, 60)
	Input.action_release("move_left")
	await _frames(45)
	Input.action_release("jump")
	_check(level.is_riding(), "player can board the return raft from the right shallows")
	Input.action_press("blade_toggle")
	await _until(func(): return level.beached, 650)
	Input.action_release("blade_toggle")
	await _frames(90)
	_check(level.beached and not level.floating and level.crate.position.x < 1320.0, "fan strokes can take the original crate back to the left bank")
	await _shot("10-left-return")
	var rest_x: float = level.crate.position.x
	Input.action_press("blade_toggle")
	await _frames(100)
	Input.action_release("blade_toggle")
	_check(absf(level.crate.position.x - rest_x) < 2.0, "left-bank grounding also blocks wind propulsion")
	Input.action_press("jump")
	Input.action_press("move_left")
	await _frames(38)
	Input.action_release("jump")
	Input.action_release("move_left")
	await _frames(40)
	Input.action_press("move_right")
	await _until(func(): return level.player.position.x > level.crate.position.x - 50.0, 140)
	Input.action_release("move_right")
	await _frames(8)
	Input.action_press("interact")
	Input.action_press("move_left")
	await _until(func(): return level.crate.position.x < 950.0, 500)
	Input.action_release("interact")
	Input.action_release("move_left")
	await _frames(40)
	_check(level.crate == original_box and level.crate.position.x < 1000.0 and absf(level.crate_tilt) < 0.01, "the same box can be dragged up the left slope and stands upright only on flat ground")
	_check(level.checkpoint == 1 and level.checkpoint_fan and level.fan_revealed, "returning preserves the discovered fan after placing it down for uphill dragging")
	Input.action_press("interact")
	Input.action_press("move_right")
	await _until(func(): return level.launching, 220)
	_check(level.launching and level.launch_direction > 0.0, "a second outward launch remains possible after a complete round trip")
	Input.action_release("interact")
	Input.action_release("move_right")

func _retrieve_fan() -> void:
	if level.fan_owned:
		return
	var approach_x: float = level.player.position.x
	_check(level.art.fan_pickup.visible,"automatic put-down leaves the fan in the world")
	for i in 300:
		var gap: float = level.fan_rest_position().x-level.player.position.x-13.0
		if absf(gap)<28.0 and level.player.is_on_floor():
			break
		Input.action_press("move_right" if gap>0 else "move_left")
		Input.action_release("move_left" if gap>0 else "move_right")
		await physics_frame
	Input.action_release("move_left")
	Input.action_release("move_right")
	await _frames(8)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(24)
	_check(level.fan_owned,"player retrieves the placed fan before boarding")
	for i in 300:
		var gap: float = approach_x-level.player.position.x
		if absf(gap)<5.0:
			break
		Input.action_press("move_right" if gap>0 else "move_left")
		Input.action_release("move_left" if gap>0 else "move_right")
		await physics_frame
	Input.action_release("move_left")
	Input.action_release("move_right")
	await _frames(8)

func _until(condition: Callable, budget: int) -> void:
	for i in range(budget):
		await physics_frame
		if condition.call():
			return

func _launch_edges() -> void:
	level.reset_all()
	level.intro_time = 0.0
	level.crate.position = Vector2(990,level.CRATE_START.y)
	level.player.position = Vector2(990 + level.CRATE_SIZE.x + 5.5, level.ground_y(990 + level.CRATE_SIZE.x + 18.5) - 54.0)
	await _frames(25)
	Input.action_press("interact")
	Input.action_press("move_right")
	await _until(func(): return level.launching, 140)
	_check(level.launching and not level.dragging and level.entry_brake, "front pulling releases automatically at the launch slope")
	var safe_x: float = level.player.position.x
	var release_facing: float = level.facing
	await _frames(40)
	_check(level.facing == release_facing,"left-bank automatic release preserves pulling facing while braking")
	_check(absf(level.player.position.x - safe_x) < 2.0, "automatic release brakes the puller instead of accelerating into deep water")
	Input.action_release("interact")
	Input.action_release("move_right")
	await _frames(180)
	_check(level.death_time == 0.0 and level.player.position.y + 54.0 < 630.0 and absf(level.player.position.x - safe_x) < 2.0, "waiting in front of the sliding crate does not shove or drown the player")
	await _shot("06-safe-launch-wait")
	Input.action_press("jump")
	Input.action_press("move_left")
	await _until(func(): return level.player.position.x < level.crate.position.x + 65.0, 40)
	Input.action_release("move_left")
	await _frames(45)
	Input.action_release("jump")
	_check(level.is_riding(), "the front-side puller can jump back onto the crate after waiting")
	var slope_seen := false
	var entry_seen := false
	for i in range(600):
		await physics_frame
		if not slope_seen and level.crate.position.x > 1120.0 and not level.floating:
			slope_seen = true
			_check(level.crate_tilt > deg_to_rad(10.0) and level.crate.position.y > level.CRATE_START.y + 5.0, "bank descent tilts and lowers the crate before buoyancy")
			_check(absf(level._shore_limit(level.crate_tilt) - level.crate.position.y) < 4.0 or level.crate.velocity.y > 40.0, "descending crate has ground support or downward fall speed, not midair translation")
			await _shot("06b-slope-descent")
		if not entry_seen and level.floating:
			entry_seen = true
			_check(level._lowest_crate_y() - level.WATER_Y > level.CRATE_SIZE.y * 0.3, "buoyancy starts with a substantial part of the crate actually immersed")
		if level.floating and not level.launching:
			break
	_check(slope_seen and entry_seen, "launch includes a supported slope phase before its water phase")
	_check(level.floating and not level.launching and level.is_riding(), "the crate gently slides into water carrying its rider")
	var moored_x: float = level.crate.position.x
	await _frames(100)
	_check(absf(level.crate.position.x - moored_x) < 1.0, "launch finishes at a stationary boarding position without wind")
	await _shot("07-loaded-launch")
	var loaded_y: float = level.crate.position.y
	level.player.position = Vector2(1100,496)
	level.player.velocity = Vector2.ZERO
	await _frames(180)
	_check(level.load_sink < 1.0 and level.crate.position.y < loaded_y - 5.0, "leaving the crate lets it rise back toward its unloaded waterline")
	var landing_x: float = level.crate.position.x + level.CRATE_SIZE.x * 0.82
	level.player.position = Vector2(landing_x - 13.0, level.crate_top_at(landing_x) - 144.0)
	level.player.velocity = Vector2.ZERO
	await _until(func(): return level.is_riding(), 80)
	_check(level.is_riding() and level.sink_speed > 10.0, "landing adds a downward buoyancy impulse")
	await _frames(20)
	_check(level.load_rock > 0.01 and level.load_sink > 5.0, "off-center landing rocks and submerges the same physical crate")
	_check(absf(level.crate_shape.rotation - level.crate_tilt) < 0.001 and level.is_riding(), "rider follows the rocking collision surface without falling through")
	await _shot("08-landing-weight")
	level.reset_all()
	await _frames(60)
	_check(not level.launching and not level.beached and not level.entry_brake and absf(level.load_sink) < 0.1, "reset clears launch, grounding and buoyancy load")

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _right_launch_edges() -> void:
	level.checkpoint = 2
	level.checkpoint_fan = true
	level.restore_checkpoint()
	level.crate.position = Vector2(2120,level.CRATE_START.y)
	level.player.position = Vector2(2084.5, level.ground_y(2097.5) - 54.0)
	await _frames(30)
	Input.action_press("interact")
	Input.action_press("move_left")
	await _until(func(): return level.launching, 160)
	_check(level.launching and level.entry_brake and level.launch_direction < 0.0, "front pulling from the right bank uses the mirrored release and brake")
	var waiting_x: float = level.player.position.x
	var release_facing: float = level.facing
	await _frames(80)
	_check(level.facing == release_facing,"right-bank automatic release preserves pulling facing while braking")
	Input.action_release("interact")
	Input.action_release("move_left")
	await _frames(120)
	_check(level.death_time == 0.0 and absf(level.player.position.x - waiting_x) < 2.0, "the right-bank crate also yields to a waiting player")
	await _shot("11-right-bank-wait")
	Input.action_press("jump")
	Input.action_press("move_right")
	await _until(func(): return level.player.position.x > level.crate.position.x + 30.0, 50)
	Input.action_release("move_right")
	await _frames(45)
	Input.action_release("jump")
	_check(level.is_riding(), "front-side puller can board after waiting on the right bank too")
	await _until(func(): return level.floating and not level.launching, 600)
	await _frames(120)
	_check(level.floating and level.is_riding() and absf(level.crate_tilt) < deg_to_rad(6.0), "right-bank raft settles nearly level while carrying its rider")
	await _shot("12-right-bank-floating")
	level.reset_all()
	await _frames(60)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
		print("STATE player=", level.player.position, " crate=", level.crate.position, " float=", level.floating, " riding=", level.is_riding(), " drag=", level.dragging, " tilt=", rad_to_deg(level.crate_tilt), " speed=", level.crate.velocity)
	else:
		print("PASS: ", description)

func _shot(label: String) -> void:
	if not capture:
		return
	level.set_physics_process(false)
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-river")
	root.get_texture().get_image().save_png("res://artifacts/c-zone-river/%s.png" % label)
	level.set_physics_process(true)
