extends SceneTree

# The hooded boy in act three (headless): pick a stone up, carry it, aim, throw. The cliff act keeps its own rules; only the
# timings follow his clips.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Cliff = preload("res://scripts/demos/c_zone_debug/cliff_act.gd")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level
var cliff
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

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
	await _frames(10)
	level.debug_enter_cliff_act()
	cliff = level.cliff
	await _frames(30)
	_check(level.actor == level.hood_actor, "act three shows the hooded boy")
	var stone_x: float = cliff.stones[0].body.position.x
	level.player.position.x = stone_x - 22.0
	level.facing = 1.0
	await _frames(6)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(20)
	_check(cliff.pickup_total > 0.8 and int(cliff.stones[0].state) == Cliff.Stone.PICKUP, "picking up takes the length of the crouch (%.2f s)" % cliff.pickup_total)
	_check(level.actor.current_clip == &"small_pickup", "he crouches (%s)" % level.actor.current_clip)
	await _frames(60)
	_check(cliff.carrying == 0 and int(cliff.stones[0].state) == Cliff.Stone.HELD, "then holds the stone")
	var hand: Vector2 = level.actor.fan_hand_position()
	_check(cliff.stones[0].body.position.distance_to(hand) < 2.0, "the stone follows his hand")
	_check(absf(level.stone_nodes[0].scale.x - level.HOOD_STONE_SCALE) < 0.01 and absf(level.stone_nodes[1].scale.x - level.HOOD_STONE_SCALE) < 0.01, "a stone in his hand and one on the ground are the same size (%.2f, %.2f)" % [level.stone_nodes[0].scale.x, level.stone_nodes[1].scale.x])
	await _frames(60)
	_check(level.actor.current_clip == &"small_hold", "standing with it (%s)" % level.actor.current_clip)
	Input.action_press("interact")
	await _frames(25)
	_check(cliff.charging and level.actor.current_clip == &"small_throw_charge", "aiming plays the wind-up (%s)" % level.actor.current_clip)
	_check(level.actor.item_node.visible and not level.stone_nodes[0].visible, "the actor carries the stone while aiming")
	cliff.hold = 0.5
	Input.action_release("interact")
	await _frames(4)
	_check(cliff.release_time > 0.0 and level.actor.current_clip == &"small_throw_release", "letting go plays the swing (%s)" % level.actor.current_clip)
	_check(level.actor.item_node.visible, "the stone is still in his hand early in the swing")
	await _frames(20)
	_check(int(cliff.stones[0].state) == Cliff.Stone.FLY or int(cliff.stones[0].state) == Cliff.Stone.REST, "and has left it at the release frame")
	_check(not level.actor.item_node.visible, "the actor's stone is gone")
	await _frames(30)
	_check(absf(level.stone_nodes[0].scale.x - level.HOOD_STONE_SCALE) < 0.01, "and it keeps that size once thrown (%.2f)" % level.stone_nodes[0].scale.x)
	await _frames(60)
	_check(level.actor.current_clip in [&"small_throw_release", &"small_throw_recover", &"idle_left"], "he recovers (%s)" % level.actor.current_clip)
	# the pile of three stones: drawn smaller they must still touch
	var pile_gap := 0.0
	for k in [2, 3]:
		if int(cliff.stones[k + 0].state) == Cliff.Stone.STACKED and int(cliff.stones[4].state) == Cliff.Stone.STACKED:
			pile_gap = maxf(pile_gap, level.stone_nodes[4].position.distance_to(level.stone_nodes[k].position))
	print("pile top-to-bottom distance ", pile_gap)
	_check(pile_gap == 0.0 or pile_gap < 21.5, "the top stone of the pile rests on the two below it (%.1f px apart)" % pile_gap)
	# the lever: the stick goes through his hands
	level.player.position.x = cliff.lever_stand_x() - 13.0
	cliff.lever_dir = 1.0
	cliff.lever_s = 1.0
	for i in 30:
		cliff.lever_grace = 1.0
		await physics_frame
	var frame_pushed: int = level.actor.current_frame_index
	_check(level.actor.current_clip == &"grip_to_pull" and cliff.lever_hand_driven, "working the lever plays the push-to-pull stroke (%s)" % level.actor.current_clip)
	_check(cliff.lever_hand_world.distance_to(level.actor.grip_hand_world()) < 0.5, "the stick is drawn through the point his hand is at (%.2f px)" % cliff.lever_hand_world.distance_to(level.actor.grip_hand_world()))
	cliff.lever_dir = -1.0
	for i in 40:
		cliff.lever_grace = 1.0
		await physics_frame
	_check(level.actor.current_frame_index > frame_pushed + 25, "pulling the stick in, his arms come in with it (frame %d -> %d)" % [frame_pushed, level.actor.current_frame_index])
	var hand_gap: float = absf(cliff.lever_hand_world.x - level.player.position.x)
	# a drop from a height kills; so does the cage coming down on him
	level.set_physics_process(true)
	level.restore_checkpoint()
	await _frames(20)
	var ground_x := 6000.0
	level.player.position = Vector2(ground_x, cliff._ground_y(ground_x + 13.0) - 54.0 - 320.0)
	level.player.velocity = Vector2.ZERO
	for i in 120:
		await physics_frame
		if level.marsh_hit_time > 0.0:
			break
	_check(level.marsh_hit_kind == "fall", "a drop of 300 px kills (%s)" % level.marsh_hit_kind)
	level.restore_checkpoint()
	await _frames(30)
	level.player.position = Vector2(ground_x, cliff._ground_y(ground_x + 13.0) - 54.0 - 60.0)
	level.player.velocity = Vector2.ZERO
	await _frames(90)
	_check(level.marsh_hit_time == 0.0, "a small drop does not")
	level.restore_checkpoint()
	await _frames(30)
	level.set_physics_process(false)
	cliff.lift_s = 300.0
	level.last_lift_s = 310.0
	level.player.position = Vector2(Cliff.LIFT_X + 30.0, cliff.cage_top() + 14.0 - 54.0 + 6.0)
	level.player.velocity = Vector2.ZERO
	level._check_fall_and_crush()
	_check(level.marsh_hit_kind == "crush", "a cage coming down on someone standing under it crushes him (%s)" % level.marsh_hit_kind)
	level.set_physics_process(true)
	level.restore_checkpoint()
	await _frames(10)
	print("hood cliff smoke ", "OK" if failures == 0 else "FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)
