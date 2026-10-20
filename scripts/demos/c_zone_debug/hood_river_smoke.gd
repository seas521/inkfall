extends SceneTree

# The hooded boy in the C zone (headless): movement, gripping the raft, the water death, a boulder pushing him back,
# the marsh hits. Run: godot --headless --path . --script res://scripts/demos/c_zone_debug/hood_river_smoke.gd
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _until(condition: Callable, budget: int) -> void:
	for i in range(budget):
		await physics_frame
		if condition.call():
			return

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
	await _frames(100)
	_check(level.actor == level.hood_actor and level.hood_actor.visible and not level.legacy_actor.visible, "the C zone shows the hooded boy")
	_check(level.player.is_on_floor() and level.actor.current_clip in [&"idle_left"], "standing on the bank, after the walk in: idle or catching his breath (%s)" % level.actor.current_clip)
	Input.action_press("move_right")
	await _frames(30)
	_check(level.actor.current_clip in [&"tired_start", &"tired_run"], "running (%s)" % level.actor.current_clip)
	Input.action_release("move_right")
	await _frames(10)
	# grip the raft from its right side
	Input.action_press("move_left")
	await _until(func(): return level.player.position.x < level.crate.position.x + level.CRATE_SIZE.x + 28.0, 200)
	Input.action_release("move_left")
	await _frames(10)
	Input.action_press("interact")
	await _frames(40)
	_check(not level.dragging and level.grip_pending, "F beside the raft does not grip yet: it waits for the direction")
	_check(not (String(level.actor.current_clip).begins_with("grip_") or level.actor.current_clip == &"small_pickup"), "and he does nothing with his arms meanwhile (%s)" % level.actor.current_clip)
	Input.action_press("move_left")
	await _frames(6)
	Input.action_release("move_left")
	await _frames(60)
	_check(level.dragging, "the key towards the raft grips it (a push)")
	_check(level.actor.current_clip == &"grip_hold" or level.actor.current_clip == &"grip_engage", "gripping: engage / hold (%s)" % level.actor.current_clip)
	var hood = level.actor
	var scale_value: float = hood.DISPLAY_SCALE * 0.90
	# the hand rests on the raft's side: hand point = centre + facing * reach
	var data: Dictionary = hood.Manifest.CLIPS[String(hood.current_clip)]
	var hand_x: float = float(hood.pose.facing) * (hood.body_offset.x / float(hood.pose.facing) + scale_value * hood._hand_distance(data))
	var wanted_hand: float = float(hood.pose.facing) * (hood.contact_reach + hood.contact_sink)
	_check(absf(hand_x - wanted_hand) < 0.6, "the hands rest on the raft's side (%.1f px, wanted %.1f)" % [hand_x, wanted_hand])
	Input.action_press("move_left")
	await _frames(40)
	_check(level.actor.current_clip in [&"push", &"grip_to_pull", &"pull"], "pushing / pulling plays its own clips (%s)" % level.actor.current_clip)
	var frame_a: int = level.actor.current_frame_index
	await _frames(20)
	_check(level.actor.current_frame_index != frame_a, "the clip follows the distance travelled")
	Input.action_release("move_left")
	await _frames(30)
	_check(level.actor.current_clip in [&"grip_hold", &"push", &"pull", &"grip_to_pull"], "stopping keeps the last pose (%s)" % level.actor.current_clip)
	# pulling the boat: he takes up the rope and stands back from the hull
	var before_pull_x: float = level.player.position.x
	var boat_x: float = level.crate.position.x
	Input.action_press("move_right")
	await _frames(12)
	_check(level.rope_stage == 1 and level.actor.current_clip == &"grip_release", "moving away first lets go of the hull (%s)" % level.actor.current_clip)
	await _frames(30)
	_check(level.actor.current_clip == &"small_pickup" and level.rope_hold < 0.2, "then he crouches to the rope lying at the post's foot, not yet in his hand (%s, rope %.2f)" % [level.actor.current_clip, level.rope_hold])
	_check(absf(level.crate.position.x - boat_x) < 1.0, "the boat does not move while he is taking the rope up")
	await _frames(35)
	_check(level.rope_stage == 2 and level.rope_hold > 0.9, "stood up with the rope in his hand (stage %d, rope %.2f)" % [level.rope_stage, level.rope_hold])
	await _frames(60)
	_check(level.rope_mode and level.rope_extra > 20.0, "and steps back from the hull to pull (%.1f px)" % level.rope_extra)
	_check(level.actor.current_clip == &"pull" and level.actor.rope_blend() > 0.9, "pulling plays the pull loop with the rope held (%s %.2f)" % [level.actor.current_clip, level.actor.rope_blend()])
	_check(level.crate.position.x != boat_x, "and the boat follows")
	var offset_before: float = level.actor.grip_offset_x
	await _frames(1)
	_check(absf(level.actor.grip_offset_x - offset_before) < 5.0, "the hand alignment never jumps (%.1f -> %.1f)" % [offset_before, level.actor.grip_offset_x])
	Input.action_release("move_right")
	await _frames(20)
	Input.action_press("move_left")
	await _frames(60)
	_check(not level.rope_mode and level.actor.rope_blend() < 0.2, "pushing again puts the hands back on the hull (blend %.2f)" % level.actor.rope_blend())
	Input.action_release("move_left")
	await _frames(10)
	Input.action_release("interact")
	await _frames(20)
	_check(not level.dragging, "F lets go")
	await _frames(40)
	# F, then the key AWAY from the raft: a pull, which goes straight to the rope with no arms raised first
	level.player.position.x = level.crate.position.x + level.CRATE_SIZE.x + 28.0
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	Input.action_press("interact")
	await _frames(20)
	_check(level.grip_pending and not level.dragging, "F again: waiting")
	Input.action_press("move_right")
	var saw_raise := false
	var saw_rope := false
	for i in 40:
		await physics_frame
		saw_raise = saw_raise or level.actor.current_clip in [&"grip_engage", &"grip_release", &"grip_hold", &"push"]
		saw_rope = saw_rope or level.rope_stage == 1
	Input.action_release("move_right")
	Input.action_release("interact")
	await _frames(20)
	_check(saw_rope and not saw_raise, "the key away from the raft goes straight to the rope, his arms never go up first (rope %s, raised %s)" % [saw_rope, saw_raise])
	await _frames(40)
	# the fan: carried, picked up, swung
	level.fan_owned = true
	level.fan_revealed = true
	await _frames(40)
	_check(level.actor.current_clip == &"small_hold", "carrying the fan: he stands in the carry pose (%s)" % level.actor.current_clip)
	_check(level.fan.global_position.distance_to(level.actor.fan_hand_position()) < 1.0, "the fan node sits in his hand")
	_check(level.fan.rotation * level.facing < -0.8 and level.fan.leaf_node.z_index < 0 and level.fan.z_index > level.actor.z_index and level.fan.fist, "carried, the stalk crosses him, open where his fist is, and the blade rests back behind his head (%.2f rad)" % level.fan.rotation)
	Input.action_press("move_right")
	await _frames(25)
	_check(level.actor.current_clip == &"small_run_l1", "and runs with it (%s)" % level.actor.current_clip)
	var run_gap := 0.0  # how far the handle is from his hand while he runs and jumps with the fan
	for i in 20:
		await physics_frame
		var hand = level.actor.hand_local()
		if hand != null:
			run_gap = maxf(run_gap, level.fan.global_position.distance_to(level.actor.body.to_global(hand)))
	_check(run_gap < 1.5, "running, the handle stays in his hand (%.2f px apart)" % run_gap)
	Input.action_press("jump")
	var jump_gap := 0.0
	for i in 50:
		await physics_frame
		var hand = level.actor.hand_local()
		if hand != null:
			jump_gap = maxf(jump_gap, level.fan.global_position.distance_to(level.actor.body.to_global(hand)))
	Input.action_release("jump")
	_check(jump_gap < 1.5, "jumping, the fan does not come away from him (%.2f px apart)" % jump_gap)
	Input.action_release("move_right")
	await _frames(20)
	level.fan_cooldown = 0.0
	level.swing_fan()
	await _frames(30)
	_check(level.actor.current_clip == &"fan_swing_2", "the swing plays the swing clip (%s)" % level.actor.current_clip)
	_check(level.fan_swing_total > 1.5, "the swing takes the whole clip (%.2f s)" % level.fan_swing_total)
	for i in 50:
		await physics_frame
	_check(level.art.gust_age >= 0.0 and level.art.gust_leaves.size() > 0, "the power stroke sends out a gust that lifts leaves (%d)" % level.art.gust_leaves.size())
	var ahead_x: float = level.art.gust_origin.x + level.art.gust_dir * 60.0
	_check(absf(level.art.gust_lean(ahead_x)) > 3.0 and signf(level.art.gust_lean(ahead_x)) == level.art.gust_dir, "the grass ahead of the stroke leans away from it (%.1f px)" % level.art.gust_lean(ahead_x))
	_check(absf(level.art.gust_lean(level.art.gust_origin.x - level.art.gust_dir * 200.0)) < 0.5, "and the grass behind it does not")
	var flex := 0.0
	var gap_while_settling := false  # the stalk is only opened for his fist when the hand is really known
	var early_turn := 0.0  # how far the blade has gone back towards the shoulder while the hand is still settling
	var end_gap := 0.0  # how far the handle is from his hand (the carry pose) at the end of the swing
	var lowest := 0.0  # how far down the blade points after the lift (0: up, 3.14: straight down)
	for i in 110:
		await physics_frame
		flex = maxf(flex, absf(level.actor.fan_bend))
		if level.actor.current_clip == &"fan_swing_2" and level.actor.current_frame_index > 78 and level.fan.fist:
			gap_while_settling = true
		if level.actor.current_clip == &"fan_swing_2" and level.actor.current_frame_index >= 80 and level.actor.current_frame_index <= 88:
			early_turn = maxf(early_turn, absf(level.fan.rotation))
		if level.actor.current_clip == &"fan_swing_2" and level.actor.current_frame_index >= 94:
			var hold: Array = level.actor.Manifest.CLIPS["small_hold"]["hold_points"][0]
			end_gap = maxf(end_gap, level.fan.global_position.distance_to(level.actor.body.to_global(Vector2(hold[0], hold[1]))))
		if level.actor.current_clip == &"fan_swing_2" and level.actor.current_frame_index > 80:
			lowest = maxf(lowest, absf(level.fan.rotation))
	_check(not gap_while_settling, "no gap in the handle (no floating hand) while the arm settles after the swing")
	_check(early_turn < 0.6, "the blade stays up in the hand after the swing, it does not go to the shoulder first (%.2f rad)" % early_turn)
	_check(end_gap < 14.0, "at the end of the swing the handle is in his hand, not hanging in the air (%.1f px)" % end_gap)
	_check(flex > 4.0, "the blade flexes as it is swung (up to %.1f px)" % flex)
	_check(lowest < 1.9, "after the swing the blade never points at the floor (%.2f rad)" % lowest)
	_check(level.fan_swing == 0.0 and level.fan_wind_delay < 0.0, "the swing ends and the wind check has run")
	level.fan_owned = false
	await _frames(10)
	level.fan_on_tree = false
	level.fan_ground_position = level.player.position + Vector2(30.0, 50.0)
	level.fan_owned = true
	level.pickup_total = 1.0
	level.pickup_time = 1.0
	await _frames(1)
	_check(level.fan.global_position.distance_to(level.fan_rest_position()) < 8.0, "the blade starts the pick-up where it lay (%.1f px off)" % level.fan.global_position.distance_to(level.fan_rest_position()))
	await _frames(18)
	_check(level.actor.current_clip == &"fan_pickup" and level.actor.current_frame_index > 5, "picking the fan up plays the pick-up clip (%s %d)" % [level.actor.current_clip, level.actor.current_frame_index])
	_check(absf(level.fan.scale.x) < 0.65 * 0.4, "lying on the ground as it is picked up the blade is edge-on, not the whole face (%.2f)" % level.fan.scale.x)
	await _frames(70)
	_check(level.actor.current_clip == &"fan_pickup" and level.actor.current_frame_index >= 60, "and straightens up after he is let go (%s %d)" % [level.actor.current_clip, level.actor.current_frame_index])
	level.fan_owned = false
	level.fan_on_tree = false
	level.fan_ground_position = level.player.position + Vector2(40.0, 50.0)
	await _frames(10)
	_check(absf(level.art.fan_pickup.scale.x) < 0.2 and level.art.fan_pickup.visible, "lying on the ground the blade is seen edge-on, not as a sticker (%.2f)" % level.art.fan_pickup.scale.x)
	# picking the fan up from the blade's side: he walks round to the handle first, the fan does not turn on the ground
	level.fan_revealed = true
	level.fan_owned = false
	level.fan_on_tree = false
	level.fan_ground_facing = 1.0
	level.fan_ground_position = level.player.position + Vector2(13.0 - 30.0, 50.0)
	await _frames(20)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	_check(level.fan_walk_target != INF and not level.fan_owned, "from the blade's side he first walks to the handle (target %.0f)" % level.fan_walk_target)
	await _frames(60)
	_check(level.fan_owned and level.facing == 1.0 and absf(level.player.position.x + 13.0 - (level.fan_ground_position.x - level.FAN_HANDLE_REACH)) < 8.0, "then bends to it facing the way the blade points (facing %.0f)" % level.facing)
	await _frames(100)
	level.fan_owned = false
	await _frames(10)
	# the boat: it rides higher and does not sink under him; a wind blowing away from the bank frees a beached boat
	_check(is_equal_approx(level._unloaded_float_y(), level.WATER_Y - 18.0 - level.HOOD_FLOAT_RAISE) and level._load_sink_target() < 6.0, "the boat rides higher and sinks less under him (load %.0f px)" % level._load_sink_target())
	level.fan_owned = false
	level.floating = true
	level.crate.position = Vector2(1500.0, level.CRATE_START.y)
	level.crate.velocity = Vector2.ZERO
	level.player.position = level.crate.position + Vector2(66.0, -58.0)
	level.player.velocity = Vector2.ZERO
	await _frames(60)
	_check(level.is_riding() and level.ride_drop > 6.0, "riding the boat he is drawn lower, his feet behind the hull (%.1f px)" % level.ride_drop)
	level.player.position += Vector2(0.0, -80.0)
	level.player.velocity = Vector2(0.0, -300.0)
	await _frames(12)
	_check(level.ride_drop < 9.0 and not level.is_riding(), "and he comes up again when he leaves it (%.1f px)" % level.ride_drop)
	level.fan_owned = true
	level.floating = false
	level.beached = true
	level.crate.position = Vector2(1850.0, level.CRATE_START.y)
	level.player.position = level.crate.position + Vector2(60.0, -60.0)
	level.facing = -1.0
	_check(level._fan_wind_applies(), "wind blowing back towards the water counts for a boat run up on the far bank")
	level.facing = 1.0
	_check(not level._fan_wind_applies(), "but wind blowing onto the bank does not")
	level.beached = false
	level.fan_owned = false
	# the marsh: frozen in fright, hit by fire, boulder
	level.rock_lock_time = 1.0
	await _frames(6)
	_check(level.actor.current_clip == &"scared_brake", "frozen in fright shows the scared pose (%s)" % level.actor.current_clip)
	level.rock_lock_time = 0.0
	await _frames(4)
	level.marsh_hit_kind = "rock"
	level.marsh_hit_time = 0.001
	await _frames(10)
	_check(level.actor.current_clip == &"fall_air", "a rock hit: the stagger (%s)" % level.actor.current_clip)
	await _frames(45)
	_check(level.actor.current_clip in [&"fall_impact", &"downed"], "then he goes down (%s)" % level.actor.current_clip)
	level.marsh_hit_time = 0.0
	level.marsh_hit_kind = ""
	await _frames(10)
	level.marsh_hit_kind = "pit"
	level.marsh_hit_time = 0.001
	await _frames(10)
	_check(level.actor.current_clip == &"fall_loop", "thrown into the pit: the fall loop (%s)" % level.actor.current_clip)
	level.marsh_hit_time = 0.0
	level.marsh_hit_kind = ""
	await _frames(10)
	# the water death
	level.death_time = 0.001
	await _frames(15)
	_check(level.actor.current_clip == &"water_plunge", "drowning starts with the plunge (%s)" % level.actor.current_clip)
	level.death_time = 1.2
	await _frames(3)
	_check(level.actor.current_clip == &"water_tread", "then thrashing at the surface (%s)" % level.actor.current_clip)
	level.death_time = 2.4
	await _frames(3)
	_check(level.actor.current_clip == &"water_drown", "then sinking (%s)" % level.actor.current_clip)
	# a failure fades out, resets under the dark, and fades in
	level.death_time = 2.8
	await _frames(4)
	_check(level.curtain_phase == 1 and level.death_time > 0.0, "after the drowning the screen fades out before the reset")
	await _frames(15)
	_check(level.iris != null and level.iris.rect.visible, "the fade is an iris on a layer of its own")
	await _frames(45)
	_check(level.curtain_phase == 2 and level.death_time == 0.0, "the checkpoint is restored under the dark")
	await _frames(70)
	_check(level.curtain_phase == 0 and level._curtain_alpha() == 0.0, "and the screen fades back in")
	# F9 goes back to the previous character
	ActorStyleHost.style_override = &""
	level.death_time = 0.0
	await _frames(4)
	_check(level.actor == level.legacy_actor and not level.hood_actor.visible, "switching the style gives back the previous character")
	print("hood river smoke ", "OK" if failures == 0 else "FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
