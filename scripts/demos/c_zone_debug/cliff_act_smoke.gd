extends SceneTree

# Act three, played with real inputs: pick a stone up, tap to put it down, throw it through the
# bridge rope, cross, carry a stone to the cage, cut the catch rope and ride the lift to the top.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Cliff = preload("res://scripts/demos/c_zone_debug/cliff_act.gd")
var level
var cliff
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_cliff_act()
	cliff = level.cliff
	await _frames(20)
	_check(level.checkpoint == 4 and level.player.position.x < 6000.0 and level.player.is_on_floor(), "act three starts on the bank before the broken bridge")
	_check(cliff.bridge_state == Cliff.Bridge.RAISED and not level.completed, "the bridge is raised and the act is not complete")

	# --- walking into the gap is a fall, and the bank is the save point.
	level.player.position = Vector2(6180.0, 520.0)
	level.player.velocity = Vector2.ZERO
	await _frames(12)
	_check(level.marsh_hit_kind == "pit", "stepping into the gap is a fall into the gas")
	await _frames(190)
	_check(level.marsh_hit_time == 0.0 and absf(level.player.position.x + 13.0 - level.CHECKPOINT_BANK_X) < 3.0 and level.player.is_on_floor(), "the fall returns to the bank, not to the hill")

	# --- pick a stone up; a tap puts it back; a hold throws.
	var stone_x: float = cliff.stones[0].body.position.x
	level.player.position.x = stone_x - 22.0
	level.facing = 1.0
	await _frames(6)
	await _press("interact", 2)
	await _frames(26)
	_check(cliff.carrying == 0 and int(cliff.stones[0].state) == Cliff.Stone.HELD, "F picks up the stone next to the player")
	var held_pose: Dictionary = cliff.pose_info()
	_check(held_pose.equipment == &"throwable" and held_pose.hand_stone, "the carried stone is shown in the hand")
	await _press("interact", 4)
	await _frames(30)
	_check(cliff.carrying == -1 and int(cliff.stones[0].state) == Cliff.Stone.REST, "a short tap puts the stone down again")
	_check(absf(cliff.stones[0].body.position.x - (level.player.position.x + 13.0 + 26.0)) < 14.0, "it is set down just in front")
	level.player.position.x = cliff.stones[0].body.position.x - 22.0
	await _frames(4)
	await _press("interact", 2)
	await _frames(26)
	_check(cliff.carrying == 0, "the stone can be picked up again")

	# --- Q cancels an aim: the stone stays in the hand, and holding F on does not start a new one.
	Input.action_press("interact")
	await _frames(14)
	_check(cliff.charging and cliff.hold > 0.1, "holding F starts aiming")
	await _press("throw_cancel", 2)
	await _frames(4)
	_check(not cliff.charging and cliff.carrying == 0 and int(cliff.stones[0].state) == Cliff.Stone.HELD, "Q cancels the aim and keeps the stone")
	await _frames(20)
	_check(not cliff.charging and cliff.release_time <= 0.0, "F still held does not start a new aim straight away")
	Input.action_release("interact")
	await _frames(10)
	_check(cliff.carrying == 0 and int(cliff.stones[0].state) == Cliff.Stone.HELD and cliff.hold == 0.0, "nothing was thrown or put down by the cancel")

	# --- a weak throw into the gap is lost and the stone comes back.
	Input.action_press("interact")
	await _frames(3)
	cliff.hold = 0.4
	cliff.aim = -0.35
	Input.action_release("interact")
	await _frames(120)
	_check(cliff.bridge_state == Cliff.Bridge.RAISED, "a weak throw leaves the bridge up")
	_check(int(cliff.stones[0].state) == Cliff.Stone.REST and cliff.stones[0].body.position.distance_to(cliff.stones[0].home) < 40.0, "a stone that falls into the gas returns to its pile")

	# --- the real throw: aim the preview at the rope, then let go.
	level.player.position.x = cliff.stones[0].body.position.x - 22.0
	level.facing = 1.0
	await _frames(6)
	await _press("interact", 2)
	await _frames(26)
	Input.action_press("interact")
	await _frames(3)
	var found := _solve(1.0)
	_check(found, "a throw that cuts the bridge rope exists from the bank (the preview shows it)")
	Input.action_release("interact")
	for _step in range(240):
		await physics_frame
		if cliff.bridge_state != Cliff.Bridge.RAISED:
			break
	_check(cliff.bridge_state == Cliff.Bridge.FALLING or cliff.bridge_state == Cliff.Bridge.DOWN, "the stone cuts the rope and the bridge starts to fall")
	await _frames(150)
	_check(cliff.bridge_state == Cliff.Bridge.DOWN, "the bridge comes to rest across the gap")
	_check(not cliff.bridge_shape.disabled and absf(cliff.bridge_angle) < 0.01, "a fallen bridge is solid")

	# --- the bridge dips under the player's weight, then settles.
	level.player.position = Vector2(cliff.BRIDGE_HINGE.x + cliff.BRIDGE_LENGTH * 0.5 - 13.0, 330.0)
	level.player.velocity = Vector2.ZERO
	await _frames(70)
	_check(level.player.is_on_floor() and cliff.bridge_sag > 4.0, "standing mid-bridge bows it down")
	var mid_sag: float = cliff.bridge_sag
	level.player.position = Vector2(cliff.BRIDGE_HINGE.x + 28.0, 330.0)
	level.player.velocity = Vector2.ZERO
	await _frames(70)
	_check(cliff.bridge_sag < mid_sag * 0.6, "standing near the end barely bows it")
	level.player.position.x = 6100.0
	await _frames(150)
	_check(absf(cliff.bridge_sag) < 0.6, "an empty bridge settles flat again")

	# --- cross on foot; the deck bobs under the footsteps and the player stays on it.
	Input.action_press("move_right")
	var sag_min := 99.0
	var sag_max := -99.0
	var off_floor := 0
	for _step in range(700):
		await physics_frame
		if level.player.position.x > 6180.0 and level.player.position.x < 6390.0:
			sag_min = minf(sag_min, cliff.bridge_sag)
			sag_max = maxf(sag_max, cliff.bridge_sag)
			if not level.player.is_on_floor():
				off_floor += 1
		if level.player.position.x > 6500.0 and level.player.is_on_floor():
			break
	Input.action_release("move_right")
	_check(level.player.position.x > 6500.0 and level.marsh_hit_time == 0.0, "the player walks across the fallen bridge")
	_check(sag_max - sag_min > 1.5, "the bridge bobs while someone runs across it")
	_check(off_floor < 12, "the deck carries the runner without dropping them")
	_check(level.checkpoint == 4, "dropping the bridge does not add another save point")

	# --- dying again keeps the bridge down.
	level.player.position = Vector2(6300.0, 700.0)
	await _frames(12)
	await _frames(190)
	_check(cliff.bridge_state == Cliff.Bridge.DOWN and level.player.position.x < 6000.0, "a respawn keeps the bridge down")
	Input.action_press("move_right")
	for _step in range(800):
		await physics_frame
		if level.player.position.x > 6540.0 and level.player.is_on_floor():
			break
	Input.action_release("move_right")

	# --- the cage hangs far overhead, held up by a stack of three stones on the ground.
	_check(cliff.stack_left == 3 and cliff.lift_state == Cliff.Lift.PINNED, "the cage hangs pinned by a pyramid of three stones")
	_check(absf(cliff.cage_top() - Cliff.DOCK_Y) < 1.0 and cliff.cage_top() < -250.0, "it hangs far overhead, above the top of the first screen")
	_check(cliff.top_stack_index() == 4 and cliff.stack_liftable(4) and not cliff.stack_liftable(2) and not cliff.stack_liftable(3), "only the top stone of the pyramid can be lifted first")
	_check(cliff.stack_pos(2).y < cliff.stack_pos(0).y - 15.0 and absf(cliff.stack_pos(0).y - cliff.stack_pos(1).y) < 0.1, "the stones are stacked one on top of two")
	level.player.position = Vector2(Cliff.STACK_X - 36.0, 330.0)
	level.player.velocity = Vector2.ZERO
	await _frames(40)
	_check(not cliff.lever_usable(), "the lever is of no use while the cage is up")

	# --- take them off one by one: the cage sinks a third of the way each time.
	var expected := [Cliff.LIFT_STAGE[2], Cliff.LIFT_STAGE[1], 0.0]
	for round in range(3):
		var top_index: int = cliff.top_stack_index()
		level.player.position = Vector2(Cliff.STACK_X - 36.0, 330.0)
		level.player.velocity = Vector2.ZERO
		level.facing = 1.0
		await _frames(30)
		await _press("interact", 2)
		await _frames(2)
		_check(cliff.stack_left == 2 - round, "lifting stack stone %d takes it off the pin" % (round + 1))
		await _frames(40)
		_check(cliff.carrying >= 2 and (round > 0 or cliff.carrying == top_index), "the stone in the hand came off the stack, the top one first")
		await _frames(150)
		_check(absf(cliff.lift_s - float(expected[round])) < 6.0, "the cage has sunk to a third-step height after stone %d" % (round + 1))
		# Carry it off and set it down well away from the pin.
		level.player.position.x = 6760.0 - float(round) * 38.0
		level.player.velocity = Vector2.ZERO
		await _frames(20)
		await _press("interact", 4)
		await _frames(40)
		_check(cliff.carrying == -1, "the stone is set down away from the stack")
	await _frames(120)
	_check(cliff.lift_state == Cliff.Lift.LANDED and cliff.lift_s < 1.0, "with the last stone gone the cage settles on the ground")

	# --- in the cage the lever pumps it up; stop and it sinks.
	_check(not cliff.lever_usable(), "the lever needs someone standing in the cage")
	level.player.position = Vector2(Cliff.LIFT_X + Cliff.LIFT_W - 30.0, 330.0)
	level.player.velocity = Vector2.ZERO
	level.facing = 1.0
	await _frames(40)
	_check(cliff.on_cage() and cliff.lever_usable(), "standing by the lever post in the cage can use it")
	await _press("interact", 2)
	await _frames(6)
	_check(cliff.lever_time > 0.0 and cliff.lift_target >= Cliff.LIFT_PUMP - 0.5, "a pull of the lever hoists the target one notch")
	await _frames(40)
	var risen: float = Cliff.LIFT_REST_Y - cliff.cage_top()
	_check(risen > 30.0, "the cage rises with the swing")
	await _frames(140)
	_check(cliff.lift_target < Cliff.LIFT_PUMP - 15.0, "stop pumping and the cage sinks back")
	for pump in range(24):
		await _press("interact", 2)
		await _frames(30)
		if cliff.lift_state == Cliff.Lift.ARRIVED:
			break
	await _frames(40)
	_check(cliff.lift_state == Cliff.Lift.ARRIVED and absf(cliff.cage_top() - (Cliff.LIFT_REST_Y - Cliff.LIFT_TRAVEL)) < 1.5, "enough swings dock the cage at the upper station")

	# --- no jump: the docked cage sits level with a slope; walk up it into the next scene.
	_check(level.camera.position.y < 0.0, "the camera has climbed with the cage")
	level.facing = 1.0
	Input.action_press("move_right")
	var climbed := false
	for _step in range(900):
		await physics_frame
		if level.player.position.x + 13.0 > Cliff.CLIFF_X + 150.0 and level.player.is_on_floor() and level.player.position.y + 54.0 < Cliff.DOCK_Y - 40.0:
			climbed = true
		if level.completed:
			break
	Input.action_release("move_right")
	_check(climbed, "the player walks off the cage and up the slope")
	_check(level.completed and cliff.fade >= 1.0, "reaching the top of the slope fades out and completes the act")

	print("cliff_act_smoke: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	level.queue_free()
	await _frames(3)
	quit(0 if failures == 0 else 1)

func _solve(face: float) -> bool:
	level.facing = face
	for hold in [0.7, 0.8, 0.9, 1.0, 0.6, 0.5, 0.4, 0.3]:
		for step in range(0, 61):
			var aim := -1.38 + float(step) * 0.02
			cliff.hold = hold
			cliff.aim = aim
			var path: Dictionary = cliff.preview_path()
			if path.rope:
				return true
	return false

func _count_solutions(face: float) -> int:
	level.facing = face
	var count := 0
	for hold in [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]:
		for step in range(0, 46):
			var aim := -1.2 + float(step) * 0.02
			cliff.hold = hold
			cliff.aim = aim
			if cliff.preview_path().rope:
				count += 1
	cliff.hold = 0.0
	cliff.aim = Cliff.AIM_START
	return count

func _press(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
		print("FAIL: ", description)
