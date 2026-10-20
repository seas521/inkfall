extends SceneTree

# A raft pushed into the water without the leaf can still be hauled back to the shore, and the leaf
# is left lying at the second act's ledge instead of vanishing (a death then puts it back on its tree).
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(100)
	# Without ever touching the leaf: put the raft at the top of the bank and push it in.
	level.crate.position = Vector2(1000.0, level.CRATE_START.y)
	level.crate.velocity = Vector2.ZERO
	level.player.position = Vector2(1000.0 - 52.0 - 26.0, 480.0)
	await _frames(40)
	Input.action_press("move_right")
	await _until(func(): return level.player.position.x > level.crate.position.x - 56.0, 120)
	Input.action_release("move_right")
	await _frames(5)
	Input.action_press("interact")
	Input.action_press("move_right")
	await _until(func(): return level.floating and not level.launching, 700)
	Input.action_release("interact")
	Input.action_release("move_right")
	await _frames(70)
	_check(level.floating and not level.beached, "the raft floats at the water's edge")
	_check(not level.fan_owned, "the leaf was never taken")
	var rest_x: float = level.crate.position.x
	# Walk to the raft's shore side and haul it back.
	Input.action_press("move_right")
	await _until(func(): return level.can_grab(), 160)
	Input.action_release("move_right")
	await _frames(4)
	_check(level.can_grab(), "the floating raft can be gripped from the bank")
	Input.action_press("interact")
	await _frames(25)
	_check(level.dragging, "gripping a floating raft near the bank holds it")
	Input.action_press("move_left")
	await _until(func(): return level.crate.position.x < rest_x - 40.0, 260)
	_check(level.crate.position.x < rest_x - 40.0, "hauling pulls the raft towards the shore")
	await _until(func(): return level.beached and not level.floating, 400)
	_check(level.beached and not level.floating, "the raft comes back up onto the bank")
	_check(level.dragging, "the grip holds through the change from water to ground")
	await _frames(60)
	Input.action_release("interact")
	Input.action_release("move_left")
	await _frames(10)
	_check(level.crate.position.x < rest_x - 80.0, "the raft ends further up the bank than where it floated")
	# It cannot be shoved out while floating: pushing away from the shore does nothing to a floating raft.
	# The leaf: carried over the ledge it is set down and stays; a death clears it.
	level.fan_owned = true
	level.fan_revealed = true
	level.fan_on_tree = false
	level.checkpoint_fan = true
	level.player.position = Vector2(level.SECOND_ACT_LEDGE.position.x + 6.0, level.SECOND_ACT_LEDGE.position.y - level.PLAYER_SIZE.y - 1.0)
	level.player.velocity = Vector2.ZERO
	await _until(func(): return level.fan_left_behind and not level.fan_owned and level.put_down_time <= 0.0, 120)
	_check(level.fan_left_behind and not level.fan_owned, "the leaf is set down on the ledge")
	_check(level.fan_revealed and not level.fan_on_tree, "it stays lying there in plain sight")
	_check(not level.can_pick_up_fan(), "it cannot be taken again")
	level.restore_checkpoint()
	await _frames(5)
	_check(level.fan_revealed and level.fan_on_tree and not level.fan_owned and not level.fan_left_behind, "dying puts the leaf back on its tree")
	print("river_pullback_smoke: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)
	else:
		print("PASS: ", label)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func _until(test: Callable, limit: int) -> void:
	for _i in range(limit):
		if test.call():
			return
		await physics_frame
		await process_frame
