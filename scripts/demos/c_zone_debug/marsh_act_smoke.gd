extends SceneTree

const SCENE = preload("res://scenes/debug/c_zone_river.tscn")

var level
var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	if capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(20)
	_check(level.WORLD_WIDTH > 6000.0, "second act extends the same continuous world")
	_check(level.puzzle_box != null and level.swing_body != null, "box and swing are mounted in the river scene")
	_check(level.marsh_art != null, "marsh art is mounted in the same scene")
	_check(level.art.background.visible and level.art.mid_view.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "act-one backdrop and blur layers stay alive")

	# --- raft flush against the ledge: one step, no gap.
	level.checkpoint = 2
	level.restore_checkpoint()
	level.crate.position = Vector2(level.RAFT_FLUSH_X, level.CRATE_START.y)
	level.player.position = Vector2(level.RAFT_FLUSH_X + 60.0, level.CRATE_START.y - level.PLAYER_SIZE.y - 2.0)
	level.player.velocity = Vector2.ZERO
	level.intro_time = 0.0
	await _frames(30)
	_check(is_equal_approx(level.crate.position.x + level.CRATE_SIZE.x, level.SECOND_ACT_LEDGE.position.x), "raft ends flush against the ledge face")
	_check(level.is_riding(), "player stands on the flush raft")
	await _shot("01-raft-ledge", 2900.0)
	Input.action_press("jump")
	Input.action_press("move_right")
	await _frames(26)
	Input.action_release("move_right")
	Input.action_release("jump")
	await _frames(25)
	_check(level.player.position.x > 2800.0 and level.player.is_on_floor(), "player steps from the raft onto the high ledge")

	# --- box.
	level.player.position = Vector2(2915.0, level.SECOND_ACT_LEDGE.position.y - level.PLAYER_SIZE.y)
	level.player.velocity = Vector2.ZERO
	level.puzzle_box.position = level.PUZZLE_BOX_START
	await _frames(8)
	_check(level.can_grab_puzzle_box(), "preserved broken box has a reachable land grip")
	Input.action_press("interact")
	Input.action_press("move_right")
	await _frames(145)
	Input.action_release("move_right")
	Input.action_release("interact")
	await _frames(8)
	_check(level.puzzle_box.position.x > 3090.0, "box can be pushed toward the launch branch")
	_check(not level.fan_owned, "second act retires the first-act fan before box traversal")
	await _shot("02-box-route", 3150.0)

	level.puzzle_box.position = Vector2(3150.0, level.SECOND_ACT_LEDGE.position.y - level.PUZZLE_BOX_SIZE.y)
	level.puzzle_box.velocity = Vector2.ZERO
	level.player.position = level.puzzle_box.position + Vector2(37.0, -level.PLAYER_SIZE.y)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	_check(level.player.is_on_floor(), "box top is a real launch surface")
	Input.action_press("jump")
	Input.action_press("move_right")
	await _frames(22)
	Input.action_release("move_right")
	Input.action_release("jump")
	await _frames(25)
	_check(level.player.is_on_floor() and level.player.position.y + level.PLAYER_SIZE.y < 255.0, "box jump lands on the landing branch")
	await _shot("03-swing-launch", 3480.0)

	var swing_min: float = 99999.0
	var swing_max: float = -99999.0
	for _step in range(200):
		await physics_frame
		swing_min = minf(swing_min, level.swing_body.position.x)
		swing_max = maxf(swing_max, level.swing_body.position.x)
	_check(swing_max - swing_min > 150.0, "swing follows a readable pendulum arc")
	level.player.position = level.swing_body.position + Vector2(level.SWING_SIZE.x * 0.5 - level.PLAYER_SIZE.x * 0.5, -level.PLAYER_SIZE.y - 1.0)
	level.player.velocity = Vector2.ZERO
	await _frames(12)
	var rider_offset: float = level.player.position.x - level.swing_body.position.x
	await _frames(24)
	_check(absf((level.player.position.x - level.swing_body.position.x) - rider_offset) < 18.0, "moving swing carries a standing player")
	await _shot("04-swing", 3620.0)

	# --- land after the swing: checkpoint and falling stones.
	level.player.position = Vector2(3790.0, 350.0)
	level.player.velocity = Vector2.ZERO
	level.checkpoint = 2
	await _frames(14)
	level._update_marsh_checkpoint()
	_check(level.checkpoint == 2, "landing on the hill is not a save point")
	# --- the hill: nothing falls until the player lands on it, then a stone drops out of the sky,
	# breaks the limb and rolls down the slope instead of vanishing.
	level._reset_marsh_rocks()
	level.player.position = Vector2(3790.0, 380.0)
	level.player.velocity = Vector2.ZERO
	await _frames(30)
	_check(not level.rock_sequence and level.rock_lock_time == 0.0, "landing on the hill is safe: the trap waits")
	level.player.position = Vector2(level.ROCK_RUMBLE_FROM + 90.0, 250.0)
	level.player.velocity = Vector2.ZERO
	await _frames(3)
	level._reset_marsh_rocks()
	await _frames(2)
	_check(not level.rock_sequence, "nothing starts while the player is still in the air")
	await _frames(40)
	_check(level.rock_rumble > 0.05 and not level.rock_sequence, "a faint rumble builds as the player climbs")
	level.player.position = Vector2(level.ROCK_TRIGGER_X + 6.0, 330.0)
	level.player.velocity = Vector2.ZERO
	await _frames(40)
	_check(level.rock_sequence and level.rock_lock_time > 0.0, "reaching the trigger point freezes the player and starts the stones")
	level.player.position = Vector2(4850.0, 380.0)
	level.player.velocity = Vector2.ZERO
	var saw_warn := false
	var saw_fall := false
	var saw_roll := false
	var shot_taken := false
	var roll_frames := 0
	var roll_start_x := 0.0
	var roll_end_x := 0.0
	var visible_while_rolling := true
	var dropped := false
	for _step in range(640):
		await physics_frame
		level.player.position = Vector2(4850.0, 380.0)
		level.player.velocity = Vector2.ZERO
		var first: Dictionary = level.marsh_rock_state(0)
		saw_warn = saw_warn or first.mode == level.ROCK_WARN
		saw_fall = saw_fall or first.mode == level.ROCK_FALL
		if first.mode == level.ROCK_ROLL:
			if not saw_roll:
				roll_start_x = first.position.x
			saw_roll = true
			roll_frames += 1
			roll_end_x = first.position.x
			visible_while_rolling = visible_while_rolling and first.visible and first.alpha > 0.9
			if roll_frames == 40 and not shot_taken:
				shot_taken = true
				await _shot("05-stones-land", 4180.0)
		if first.mode == level.ROCK_DROP:
			dropped = true
	_check(saw_warn, "a short tremor and grit warn of the stone")
	_check(saw_fall and level.limb_broken, "the falling stone breaks the limb")
	_check(saw_roll and roll_frames > 40 and visible_while_rolling, "the landed stone keeps rolling instead of vanishing")
	_check(roll_end_x < roll_start_x - 60.0, "the first stone rolls down the left slope")
	_check(dropped, "a rolling stone tumbles off the edge into the gas")
	level.restore_checkpoint()
	_check(not level.limb_broken and not level.rock_sequence, "a reset restores the limb and re-arms the trap")

	# A stone in free fall still crushes.
	level.checkpoint = 2
	level.restore_checkpoint()
	level._reset_marsh_rocks()
	level.rock_sequence = true
	level.marsh_rocks[0]["mode"] = level.ROCK_FALL
	level.marsh_rocks[0]["pos"] = Vector2(4244.0, 300.0)
	level.player.position = Vector2(4244.0, 300.0) - level.PLAYER_SIZE * 0.5
	level.player.velocity = Vector2.ZERO
	level.marsh_hit_time = 0.0
	level._check_marsh_hazards()
	_check(level.marsh_hit_kind == "rock", "a falling stone crushes the player")
	await _frames(75)
	_check(level.marsh_hit_time == 0.0 and level.player.position.x < 2400.0 or level.marsh_save > 0, "a stone hit before the save point restarts inside the act")
	# Dying on the hill puts the player back at its foot, not across the river, with the trap re-armed.
	level.marsh_save = 2
	level.limb_broken = true
	level.rock_sequence = true
	level.restore_checkpoint()
	_check(absf(level.player.position.x + level.PLAYER_SIZE.x * 0.5 - level.MARSH_HILL_SAVE_X) < 2.0, "dying on the hill respawns at the foot of the hill")
	_check(not level.limb_broken and not level.rock_sequence, "the first stone is armed to fall again")
	_check(level.fan_revealed and level.fan_on_tree and not level.fan_owned, "the leaf is back on its tree, not with the player")
	await _frames(30)
	_check(level.player.is_on_floor(), "the respawn stands on the hill")
	level.player.position = Vector2(level.ROCK_TRIGGER_X + 4.0, level.marsh_rock_surface_y(level.ROCK_TRIGGER_X + 17.0) - level.PLAYER_SIZE.y - 1.0)
	await _frames(20)
	_check(level.rock_sequence, "walking up again springs the first stone")
	level.marsh_save = 1
	level.restore_checkpoint()
	_check(absf(level.player.position.x + level.PLAYER_SIZE.x * 0.5 - level.MARSH_LEDGE_SAVE_X) < 2.0, "before the hill, a death respawns at the ledge")

	# A rolling stone leans on the player and walks them slowly; a jump then escapes it.
	level._reset_marsh_rocks()
	level.rock_sequence = true
	level.limb_broken = true
	level.limb_time = 3.0
	var ground_x := 3860.0
	level.player.position = Vector2(ground_x, level.marsh_rock_surface_y(ground_x + 13.0) - level.PLAYER_SIZE.y)
	level.player.velocity = Vector2.ZERO
	level.marsh_rocks[0]["mode"] = level.ROCK_ROLL
	level.marsh_rocks[0]["pos"] = Vector2(3900.0, level._rock_ground_center(3900.0, 27.0))
	level.marsh_rocks[0]["vx"] = -150.0
	level.marsh_rocks[0]["impact_time"] = 5.0
	var start_player_x: float = level.player.position.x
	await _frames(14)
	_check(level.rock_shove_index == 0 and level.marsh_hit_time == 0.0, "a rolling stone shoves instead of killing outright")
	_check(absf(float(level.marsh_rocks[0]["vx"])) <= level.ROCK_SHOVE_SPEED + 1.0, "the stone only grinds forward at a slow pace")
	await _frames(20)
	_check(level.player.position.x < start_player_x - 8.0, "the player is walked toward the edge")
	var free_cap: float = level.rock_push_cap
	_check(level.rock_resist < 0.01 and absf(free_cap - level.ROCK_SHOVE_SPEED) < 0.5, "not bracing: the stone's pace is the normal one (%.0f)" % free_cap)
	# bracing against it (the key towards the stone): it grinds forward more slowly, and there is more dust, but it still comes on
	Input.action_press("move_right")
	var before_brace_x: float = level.player.position.x
	await _frames(14)
	_check(level.rock_resist > 0.95 and level.rock_push_cap < free_cap * 0.6, "holding the key against the stone braces him: it slows to %.0f px/s" % level.rock_push_cap)
	_check(absf(float(level.marsh_rocks[0]["vx"])) < free_cap * 0.6 and absf(float(level.marsh_rocks[0]["vx"])) > 10.0, "the stone itself slows, but still moves (%.0f)" % float(level.marsh_rocks[0]["vx"]))
	_check(float(level.rock_shove_info()["resist"]) > 0.95, "the art is told how hard he braces (more dust)")
	var braced_travel: float = before_brace_x - level.player.position.x
	await _frames(30)
	_check(level.player.position.x < before_brace_x - braced_travel, "he is still walked back toward the edge, only more slowly")
	Input.action_release("move_right")
	await _frames(14)
	_check(level.rock_resist < 0.05, "letting go of the key: the stone is back to its normal pace")
	await _shot("05b-shove", 3880.0)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	await _frames(6)
	_check(level.rock_immune > 0.0 and level.rock_shove_index == -1 and not level.player.is_on_floor(), "jumping while shoved slips clear of the stone")
	await _frames(70)
	level.restore_checkpoint()

	# --- gas is scenery, fire still hurts.
	level.checkpoint = 3
	level.clock = 2.2
	var gas_active: float = level.marsh_gas_strength(0)
	_check(gas_active > 0.5, "gas cycle still breathes through an active phase")
	level.player.position = level.MARSH_GAS_RECTS[0].get_center() - level.PLAYER_SIZE * 0.5
	level.player.velocity = Vector2.ZERO
	await _shot("06-fire-gas", 4710.0)
	level._check_marsh_hazards()
	_check(level.marsh_hit_time == 0.0, "standing in the gas does no harm")
	level.restore_checkpoint()
	level.clock = 2.1
	_check(level.marsh_fire_strength(0) > 0.5, "fire deck has an authored active window")
	level.player.position = Vector2(level.MARSH_FIRE_RECTS[0].get_center().x - 13.0, level.FIRE_DECK.position.y - level.PLAYER_SIZE.y - 2.0)
	level.player.velocity = Vector2.ZERO
	level._check_marsh_hazards()
	_check(level.marsh_hit_kind == "fire", "flame hits a player standing in the slot")
	await _frames(130)

	# --- walking off the edge drops into the gas pocket.
	# Landing on the fire deck is the act's only save point: dodging the stones and jumping on.
	level.checkpoint = 2
	level.restore_checkpoint()
	var fire_deck: Rect2 = level.FIRE_DECK
	level.player.position = Vector2(fire_deck.end.x - 30.0, fire_deck.position.y - level.PLAYER_SIZE.y - 2.0)
	level.player.velocity = Vector2.ZERO
	await _frames(12)
	_check(level.checkpoint == 3, "landing on the step after the stones records the save point")
	level.restore_checkpoint()
	_check(absf(level.player.position.x + 13.0 - level.MARSH_SAVE_X) < 2.0 and level.rock_sequence and level.limb_broken, "the save point is past the stones and the trap stays spent")
	await _frames(60)
	_check(level.marsh_hit_time == 0.0 and level.player.is_on_floor() and level.rock_lock_time <= 0.0, "the respawn stands safely with no stones falling")
	level.player.position = Vector2(4650.0, 520.0)
	level.player.velocity = Vector2.ZERO
	await _frames(10)
	_check(level.marsh_hit_kind == "pit", "dropping below the lip starts the gas fall")
	await _shot("07-gas-fall", 4690.0)
	await _frames(120)
	_check(level.marsh_hit_time == 0.0 and absf(level.player.position.x + 13.0 - level.MARSH_SAVE_X) < 30.0, "gas fall returns to the save point")

	# --- crumbling spires: stepping on the first one starts it falling apart, and its collapse
	# shakes the next one loose.
	var first_cap: Rect2 = level.FRAGILE_CAPS[0]
	level.player.position = Vector2(first_cap.get_center().x - 13.0, first_cap.position.y - level.PLAYER_SIZE.y - 2.0)
	level.player.velocity = Vector2.ZERO
	await _frames(8)
	_check(level.fragile_state(0).phase == 1, "stepping on the first spire starts the crumble")
	_check(level.fragile_state(1).phase == 0, "the second spire is still solid before the first falls")
	await _frames(24)
	await _shot("08-crumble", 5640.0)
	await _frames(26)
	_check(level.fragile_state(0).phase == 2, "the first slab collapses after a short grace period")
	_check(level.fragile_state(1).phase >= 1, "its collapse shakes the next spire loose")
	_check(level.marsh_hit_kind == "pit" or level.player.position.y > first_cap.position.y, "a player still standing on the slab falls with it")
	await _frames(100)
	level.player.position = Vector2(4830.0, 380.0)
	level.player.velocity = Vector2.ZERO
	await _frames(260)
	_check(level.fragile_state(0).phase == 0 and level.fragile_state(1).phase == 0, "the spires grow back once the player is clear")

	# --- the rope-hung deck swings and tips toward the loaded side.
	var deck: Rect2 = level.HANG_DECK
	level._reset_hang_deck()
	level.player.position = Vector2(level.hang_center().x - 30.0 - 13.0, deck.position.y - level.PLAYER_SIZE.y - 3.0)
	level.player.velocity = Vector2.ZERO
	await _frames(30)
	var left_tilt: float = level.hang_tilt
	_check(level.hang_player_on and absf(left_tilt) > 0.05, "standing off-centre tips the hung deck")
	level._reset_hang_deck()
	level.player.position = Vector2(level.hang_center().x + 30.0 - 13.0, level.hang_center().y - 20.0 - level.PLAYER_SIZE.y)
	level.player.velocity = Vector2.ZERO
	await _frames(30)
	_check(level.hang_tilt * left_tilt < 0.0, "standing at the other end tips it the other way")
	level.player.position = Vector2(4830.0, 380.0)
	level.player.velocity = Vector2.ZERO
	await _frames(200)
	_check(absf(level.hang_tilt) < 0.05, "an empty deck levels out again")
	var sway_min: float = 99.0
	var sway_max: float = -99.0
	for _step in range(240):
		await physics_frame
		sway_min = minf(sway_min, level.hang_sway)
		sway_max = maxf(sway_max, level.hang_sway)
	_check(sway_max - sway_min > 0.02, "the hung deck keeps a slow sway")

	# --- nothing further along saves: dying on the spires keeps the earlier save point.
	var slab: Rect2 = level.SLAB_DECK
	level.player.position = Vector2(slab.get_center().x - 13.0, slab.position.y - level.PLAYER_SIZE.y - 2.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	_check(level.checkpoint == 3, "standing further along does not move the save point")

	level.player.position = Vector2(5970.0, level.MARSH_LANDS[3][2].y - level.PLAYER_SIZE.y)
	level.player.velocity = Vector2.ZERO
	await _frames(15)
	_check(not level.completed and level.checkpoint == 4, "the far bank is the start of act three, not the end of the level")
	await _shot("09-act-three-bank", 5730.0)
	if capture:
		await _frames(120)
		print("marsh_render_fps: %d" % Engine.get_frames_per_second())

	print("marsh_act_smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	level.queue_free()
	await _frames(3)
	quit(0 if failures == 0 else 1)

func _shot(label: String, center_x: float) -> void:
	if not capture:
		return
	level.set_physics_process(false)
	level.camera_x = center_x - 640.0
	level.camera.position = Vector2(center_x, 360.0)
	level._present(0.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-marsh")
	root.get_texture().get_image().save_png("res://artifacts/c-zone-marsh/%s.png" % label)
	level.set_physics_process(true)

func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
		await process_frame

func _check(ok: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures += 1
