extends SceneTree

# The hooded boy as an actor style in the real level: every packaged clip loads, the zones are within budget,
# the override swaps the knight without touching the controller, and idle / run / jump pick the right clips.

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const Manifest = preload("res://scripts/actors/hood_actor_manifest.gd")
const HoodFrameActor = preload("res://scripts/actors/hood_frame_actor.gd")
const MAIN_SCENE = preload("res://scenes/main.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL ", message)

func _run() -> void:
	# 1. the library: every clip of every group has its frames and a crop rectangle per frame
	for group in Manifest.GROUPS:
		for clip in Manifest.GROUPS[group]:
			var data: Dictionary = Manifest.CLIPS[clip]
			_assert(data["rects"].size() == int(data["frames"]), "%s has a crop rect per frame" % clip)
			_assert(ResourceLoader.exists(Manifest.frame_path(clip, 0)), "%s first frame exists" % clip)
			_assert(ResourceLoader.exists(Manifest.frame_path(clip, int(data["frames"]) - 1)), "%s last frame exists" % clip)
	# 2. zone budgets (cropped RGBA8 size; the textures are VRAM compressed, about 4x smaller)
	var actor = HoodFrameActor.new()
	root.add_child(actor)
	await _frames(1)
	actor.load_zone("level1")
	var pixels := 0
	for clip in actor.textures:
		for texture in actor.textures[clip]:
			pixels += texture.get_width() * texture.get_height()
	print("level1 zone: %d clips, %.0f MB as RGBA8" % [actor.textures.size(), pixels * 4.0 / 1e6])
	_assert(pixels * 4.0 / 1e6 < 200.0, "level1 zone is within 200 MB as RGBA8 (about 50 MB compressed)")
	actor.unload_group("small")
	_assert(not actor.has_clip(&"small_run_l1") and actor.has_clip(&"tired_run"), "a group can be unloaded on its own")
	actor.queue_free()
	await _frames(1)
	# 3. the real level with the override: the controller is not touched, the host shows the hooded boy
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	var main = MAIN_SCENE.instantiate()
	main.debug_start_level = 1  # the project may be set to start in another act for play-testing
	root.add_child(main)
	await _frames(3)
	var controller = main.active_controller
	_assert(controller != null, "level controller started")
	_assert(controller.presentation_state()["style_id"] == ActorPoseState.STYLE_CROOKED_TOWER, "the controller still asks for the knight")
	var host = main.art_actor
	_assert(host.hood_actor.visible and not host.crooked_tower_actor.visible, "the host shows the hooded boy instead")
	var hood = host.hood_actor
	await _frames(12)
	var home: Vector2 = controller.player_position  # where the level puts him: standing on the ground
	# idle
	controller.player_position = home
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await create_timer(0.1).timeout
	_assert(hood.current_clip == &"idle_left", "standing still plays the idle clip (%s)" % hood.current_clip)
	var idle_frames := {}
	for i in 30:
		await create_timer(0.02).timeout
		idle_frames[hood.current_frame_index] = true
	_assert(idle_frames.size() == 1, "and stands perfectly still, no twitching (%d different frames)" % idle_frames.size())
	# run: the run clip, 1.0x at the run speed
	var steps_before: int = HoodFrameActor.footstep_serial
	controller.player_position = home + Vector2(-60.0, 0.0)  # room to run before the bats on the cliff come
	await create_timer(0.1).timeout
	Input.action_press("move_right")
	await create_timer(0.15).timeout
	_assert(hood.current_clip == &"tired_start", "setting off plays the start (%s)" % hood.current_clip)
	await create_timer(0.9).timeout
	var steps: int = HoodFrameActor.footstep_serial - steps_before
	_assert(steps >= 1 and steps <= 5, "a second of running gives a few foot-downs for the audio (%d)" % steps)
	_assert(hood.current_clip == &"tired_run", "then the tired run loop (%s)" % hood.current_clip)
	_assert(absf(hood.anim_speed - 1.0) < 0.15, "the run loop plays at 1.0x at his run speed, so his feet do not slide (%.3f)" % hood.anim_speed)
	Input.action_release("move_right")
	await create_timer(0.15).timeout
	# jump: takeoff, then the rise / apex / fall by vertical speed
	controller.player_position = home
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await create_timer(0.1).timeout
	Input.action_press("jump")
	await create_timer(0.1).timeout
	_assert(hood.current_clip == &"clumsy_stand_takeoff", "the jump starts with the takeoff clip (%s)" % hood.current_clip)
	await create_timer(0.12).timeout  # real time: a headless frame is far shorter than a refresh
	Input.action_release("jump")
	_assert(String(hood.current_clip) in ["clumsy_stand_rise", "clumsy_stand_apex"], "then rises (%s)" % hood.current_clip)
	controller.player_position = home - Vector2(0.0, 150.0)
	controller.player_velocity.y = 220.0
	main.game_context.on_ground = false
	await create_timer(0.1).timeout
	_assert(hood.current_clip == &"clumsy_stand_fall", "and falls (%s)" % hood.current_clip)
	controller.player_position = home
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	await create_timer(0.1).timeout
	_assert(hood.current_clip == &"clumsy_stand_land", "lands (%s)" % hood.current_clip)
	# a failure in the shaft fades out first and resets under the dark
	controller.shaft_failure_kind = "fall"
	controller.shaft_failure_time = 0.5
	controller.call("_update_shaft_failure", 0.016)
	_assert(controller.curtain_phase == 1 and controller.shaft_failure_kind == "fall", "a failure waits for the fade-out before the reset")
	controller.curtain_time = 0.3
	controller.call("_sync_iris")
	_assert(controller.iris != null and controller.iris.rect.visible, "the fade is an iris on a layer of its own, over everything")
	controller.call("_update_curtain", 0.6)
	_assert(controller.curtain_phase == 2 and controller.shaft_failure_kind == "", "and resets under the dark")
	controller.call("_update_curtain", 0.9)
	_assert(controller.curtain_phase == 0, "then fades back in")
	_assert(ActorStyleHost._running_a_script(), "scripts keep the previous actor by default; the game starts with the hooded boy")
	_assert(String(controller.call("_room_intro_text")) == "", "no text hint over the cliff")
	# the shaft entry: small dust, and he stands up facing right
	controller.shaft_dust.clear()
	controller.call("_spawn_shaft_impact_dust", Vector2(500.0, 600.0), 1.0)
	_assert(controller.shaft_dust.size() <= 12, "the landing throws up only a few puffs for him (%d)" % controller.shaft_dust.size())
	controller.shaft_dust.clear()
	controller.call("_enter_shaft")
	controller.shaft_entry_phase = controller.ShaftEntryPhase.GET_UP
	controller.call("_set_actor_action", ActorPoseState.ACTION_GET_UP, 2.375)
	controller.call("_advance_actor_action", 3.0)
	_assert(controller.player_facing > 0.0, "after getting up he faces right (%s)" % controller.player_facing)
	var entry_pose = ActorPoseState.new()
	entry_pose.facing = -1.0
	entry_pose.clip_flip_h = true
	entry_pose.feet = home
	entry_pose.grounded = true
	hood.sync_pose(1.0 / 60.0, entry_pose)
	_assert(hood.body.scale.x < 0.0, "the entry clips are drawn facing right (the body is mirrored)")
	# 4. landing from a running jump: no running on the spot; actions of the controller drive the clips
	var test_actor = HoodFrameActor.new()
	root.add_child(test_actor)
	await _frames(1)
	test_actor.load_zone("level1")
	var p = ActorPoseState.new()
	p.feet = home
	p.style_id = ActorPoseState.STYLE_HOOD
	p.grounded = false
	p.velocity = Vector2(285.0, -300.0)
	test_actor.sync_pose(1.0 / 60.0, p)
	p.grounded = true
	p.velocity = Vector2.ZERO  # lands and stands still
	test_actor.sync_pose(1.0 / 60.0, p)
	var seen_land := false
	for i in 120:
		test_actor.sync_pose(1.0 / 60.0, p)
		seen_land = seen_land or test_actor.current_clip == &"clumsy_run_land"
	_assert(not seen_land, "landing from a run without a key held plays the standing landing, not the running stumble")
	_assert(test_actor.current_clip == &"idle_left", "and stands in the idle (%s)" % test_actor.current_clip)
	# lands while the run key is still down: runs on straight away
	p.grounded = false
	p.velocity = Vector2(285.0, 200.0)
	test_actor.sync_pose(1.0 / 60.0, p)
	p.grounded = true
	for i in 100:
		test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"tired_run", "landing with the run key held keeps running at once (%s)" % test_actor.current_clip)
	# the bat event: knock-down -> downed (hit on the ground, lying) -> get up
	p.velocity = Vector2.ZERO
	var expected := {
		ActorPoseState.ACTION_KNOCKDOWN: &"fall_air",
		ActorPoseState.ACTION_GET_UP: &"get_up",
		ActorPoseState.ACTION_FALL_IMPACT: &"fall_impact",
		ActorPoseState.ACTION_FALL_DOWNED: &"downed",
		ActorPoseState.ACTION_UNCONTROLLED_FALL: &"fall_loop",
		ActorPoseState.ACTION_HIT: &"flinch",
	}
	for action in expected:
		p.action = action
		p.action_progress = 0.5
		test_actor.sync_pose(1.0 / 60.0, p)
		_assert(test_actor.current_clip == expected[action], "action %s plays %s (%s)" % [action, expected[action], test_actor.current_clip])
	p.action = ActorPoseState.ACTION_KNOCKDOWN
	p.action_progress = 0.59
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_frame_index <= 42, "the stagger of the knock-down stays on the ground-bound frames (%d)" % test_actor.current_frame_index)
	p.action_progress = 0.7
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"fall_impact", "then he goes straight down (%s)" % test_actor.current_clip)
	p.action = ActorPoseState.ACTION_DOWNED
	p.action_progress = 0.2
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"downed", "and lies still (%s)" % test_actor.current_clip)
	p.action = ActorPoseState.ACTION_GET_UP
	p.action_progress = 0.0
	test_actor.sync_pose(1.0 / 60.0, p)
	var first_index: int = test_actor.current_frame_index
	p.action_progress = 1.0
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_frame_index > first_index + 20, "get-up follows the action clock (%d -> %d)" % [first_index, test_actor.current_frame_index])
	p.action = ActorPoseState.ACTION_NONE
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"idle_left", "and returns to normal control (%s)" % test_actor.current_clip)
	# a stone: picked up (lies on the ground until the grasp frame, then in the hand), carried, thrown
	p.small_item_kind = &"stone"
	p.small_item_radius = 14.0
	p.small_item_origin = home + Vector2(30.0, -14.0)
	p.held = 0
	p.action = ActorPoseState.ACTION_PICKUP
	p.action_progress = 0.2
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"small_pickup", "picking up plays the pick-up clip (%s)" % test_actor.current_clip)
	_assert(test_actor.item_node.visible and test_actor.item_node.position.distance_to(test_actor.body.to_local(p.small_item_origin)) < 0.5, "the stone still lies where it was before the grasp")
	p.action_progress = 0.95
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.item_node.visible and test_actor.item_node.position.distance_to(test_actor.body.to_local(p.small_item_origin)) > 1.0, "after the grasp the stone has left the ground and is in his hand")
	p.action = ActorPoseState.ACTION_NONE
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"small_pickup" and test_actor.current_frame_index >= 50, "he straightens up from the crouch before anything else (%s %d)" % [test_actor.current_clip, test_actor.current_frame_index])
	for i in 60:
		test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"small_hold" and test_actor.item_node.visible, "then stands holding the stone (%s)" % test_actor.current_clip)
	p.velocity = Vector2(285.0, 0.0)
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"small_run_l1" and test_actor.item_node.visible, "runs with it (%s)" % test_actor.current_clip)
	p.velocity = Vector2.ZERO
	p.action = ActorPoseState.ACTION_THROW_CHARGE
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"small_throw_charge" and test_actor.item_node.visible, "winds up (%s)" % test_actor.current_clip)
	p.action = ActorPoseState.ACTION_THROW_RELEASE
	p.action_progress = 0.2
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"small_throw_release" and test_actor.item_node.visible, "the stone is still in the hand early in the swing")
	p.held = -1
	p.action_progress = 0.8
	test_actor.sync_pose(1.0 / 60.0, p)
	_assert(not test_actor.item_node.visible, "the stone has left the hand later in the swing")
	p.action = ActorPoseState.ACTION_NONE
	test_actor.sync_pose(1.0 / 60.0, p)
	for i in 400:
		test_actor.sync_pose(1.0 / 60.0, p)
	_assert(test_actor.current_clip == &"idle_left", "after the throw he recovers and stands (%s)" % test_actor.current_clip)
	p.small_item_kind = &""
	test_actor.queue_free()
	await _frames(1)
	# the feel: no clip ever holds the controls up
	var feel_actor = HoodFrameActor.new()
	root.add_child(feel_actor)
	await _frames(1)
	feel_actor.load_zone("level1")
	var q = ActorPoseState.new()
	q.feet = home
	q.style_id = ActorPoseState.STYLE_HOOD
	q.grounded = true
	q.facing = 1.0
	q.velocity = Vector2(200.0, 0.0)
	for i in 5:
		feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(feel_actor.current_clip == &"tired_start", "setting off at once plays the start (%s)" % feel_actor.current_clip)
	# a jump in the middle of the start: the air clip is there on the very next frame
	q.grounded = false
	q.velocity = Vector2(200.0, -450.0)
	feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(String(feel_actor.current_clip).begins_with("clumsy_run_"), "a jump in the middle of the start does not wait for it (%s)" % feel_actor.current_clip)
	q.grounded = true
	q.velocity = Vector2(200.0, 0.0)
	for i in 230:
		feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(feel_actor.current_clip == &"tired_run", "running (%s)" % feel_actor.current_clip)
	# turning round while running: the very next frame is mirrored, the run goes on, no clip change
	var frame_before: int = feel_actor.current_frame_index
	q.facing = -1.0
	q.velocity = Vector2(-200.0, 0.0)
	feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(feel_actor.current_clip == &"tired_run" and feel_actor.body.scale.x > 0.0, "turning round while running mirrors him at once and the run goes on (%s)" % feel_actor.current_clip)
	_assert(mini(absi(feel_actor.current_frame_index - frame_before), 74 - absi(feel_actor.current_frame_index - frame_before)) <= 3, "without restarting the run (frame %d -> %d)" % [frame_before, feel_actor.current_frame_index])
	# stopping is just stopping: the idle on the next frames; a key straight after is a run again at once
	q.velocity = Vector2.ZERO
	for i in 20:
		feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(feel_actor.current_clip == &"run_stop", "letting go after a run plays the run-to-stand clip (%s)" % feel_actor.current_clip)
	for i in 80:
		feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(feel_actor.current_clip == &"idle_left", "and it ends in the idle (%s)" % feel_actor.current_clip)
	q.velocity = Vector2(-200.0, 0.0)
	for i in 70:
		feel_actor.sync_pose(1.0 / 60.0, q)
	q.velocity = Vector2.ZERO
	feel_actor.sync_pose(1.0 / 60.0, q)
	q.velocity = Vector2(-200.0, 0.0)
	feel_actor.sync_pose(1.0 / 60.0, q)
	feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(feel_actor.current_clip in [&"tired_start", &"tired_run"], "a key right after is a run again at once (%s)" % feel_actor.current_clip)
	# and a jump in the middle of the start
	q.velocity = Vector2.ZERO
	for i in 20:
		feel_actor.sync_pose(1.0 / 60.0, q)
	q.grounded = false
	q.velocity = Vector2(0.0, -450.0)
	feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(String(feel_actor.current_clip).begins_with("clumsy_stand_"), "a jump straight after stopping does not wait (%s)" % feel_actor.current_clip)
	# a tap on the key does not stagger
	q.grounded = true
	q.velocity = Vector2.ZERO
	for i in 90:
		feel_actor.sync_pose(1.0 / 60.0, q)
	q.velocity = Vector2(200.0, 0.0)
	for i in 6:
		feel_actor.sync_pose(1.0 / 60.0, q)
	q.velocity = Vector2.ZERO
	for i in 12:
		feel_actor.sync_pose(1.0 / 60.0, q)
	_assert(feel_actor.current_clip == &"idle_left", "a quick tap on the key does not stagger (%s)" % feel_actor.current_clip)
	# a short run (1.5 s), and a run with a jump in it, simply stop; only a run of 3 s or more ends bent over
	var short_actor = HoodFrameActor.new()
	root.add_child(short_actor)
	await _frames(1)
	short_actor.load_zone("level1")
	short_actor.load_group("climb")
	var r = ActorPoseState.new()
	r.feet = home
	r.style_id = ActorPoseState.STYLE_HOOD
	r.grounded = true
	r.facing = 1.0
	r.velocity = Vector2(150.0, 0.0)
	for i in 90:
		short_actor.sync_pose(1.0 / 60.0, r)
	r.velocity = Vector2.ZERO
	var saw_stagger := false
	for i in 40:
		short_actor.sync_pose(1.0 / 60.0, r)
		saw_stagger = saw_stagger or short_actor.current_clip not in [&"idle_left", &"tired_run", &"run_stop"]
	_assert(not saw_stagger and short_actor.current_clip in [&"idle_left", &"run_stop"], "after a run he stops (%s)" % short_actor.current_clip)
	for i in 60:
		short_actor.sync_pose(1.0 / 60.0, r)
	_assert(short_actor.current_clip == &"idle_left", "and stands (%s)" % short_actor.current_clip)
	r.velocity = Vector2(150.0, 0.0)
	for i in 60:
		short_actor.sync_pose(1.0 / 60.0, r)
	r.grounded = false
	r.velocity = Vector2(228.0, -440.0)
	for i in 20:
		short_actor.sync_pose(1.0 / 60.0, r)
	r.grounded = true
	r.velocity = Vector2.ZERO  # lands with the key already up
	var wrong := false
	for i in 90:
		short_actor.sync_pose(1.0 / 60.0, r)
		wrong = wrong or short_actor.current_clip in [&"clumsy_run_land", &"tired_run", &"tired_start"]
	_assert(not wrong and short_actor.current_clip == &"idle_left", "a running jump, then the key up: he does not run on or stagger (%s)" % short_actor.current_clip)
	# the key comes up just after the landing: the running landing turns into the standing one, no running legs
	r.velocity = Vector2(150.0, 0.0)
	for i in 40:
		short_actor.sync_pose(1.0 / 60.0, r)
	r.grounded = false
	r.velocity = Vector2(228.0, -440.0)
	for i in 20:
		short_actor.sync_pose(1.0 / 60.0, r)
	r.grounded = true
	r.velocity = Vector2(228.0, 0.0)
	short_actor.sync_pose(1.0 / 60.0, r)
	r.velocity = Vector2.ZERO
	wrong = false
	for i in 90:
		short_actor.sync_pose(1.0 / 60.0, r)
		wrong = wrong or short_actor.current_clip in [&"tired_run", &"tired_start"]
	_assert(not wrong and short_actor.current_clip == &"idle_left", "stopping right after a running landing is a stop (%s)" % short_actor.current_clip)
	# the end of a climb: the clip itself ends on the idle picture
	var climb_pose = ActorPoseState.new()
	climb_pose.feet = home
	climb_pose.style_id = ActorPoseState.STYLE_HOOD
	climb_pose.facing = 1.0
	climb_pose.action = ActorPoseState.ACTION_CLIMB
	for i in 20:
		climb_pose.action_progress = float(i) / 20.0
		short_actor.sync_pose(1.0 / 60.0, climb_pose)
	_assert(short_actor.current_clip == &"climb", "the climb plays (%s)" % short_actor.current_clip)
	climb_pose.action = ActorPoseState.ACTION_NONE
	climb_pose.grounded = true
	for i in 3:
		short_actor.sync_pose(1.0 / 60.0, climb_pose)
	_assert(short_actor.current_clip == &"idle_left", "the climb ends on the idle picture and the idle takes over (%s)" % short_actor.current_clip)
	short_actor.queue_free()
	feel_actor.queue_free()
	await _frames(1)
	# the toggle goes back to the knight
	var key := InputEventKey.new()
	key.keycode = KEY_F9
	key.pressed = true
	host._unhandled_key_input(key)
	await create_timer(0.1).timeout
	_assert(not host.style_toast.visible, "F9 switches without any message on the screen")
	_assert(host.crooked_tower_actor.visible and not host.hood_actor.visible, "F9 switches back to the knight (hood %s, knight %s)" % [host.hood_actor.visible, host.crooked_tower_actor.visible])
	ActorStyleHost.style_override = &""
	if failures.is_empty():
		print("hood actor smoke OK")
	else:
		print("hood actor smoke FAILED: ", failures.size())
	quit(0 if failures.is_empty() else 1)
