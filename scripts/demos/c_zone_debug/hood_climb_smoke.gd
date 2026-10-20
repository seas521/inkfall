extends SceneTree

# The hooded boy's jump and climb (headless): a jump is about his own height; a jump that brings his hands to a ledge's edge
# (the pushable box, a thin deck, a wall) takes hold of it and he climbs; moving away lets go; low steps are just stepped on.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const Route = preload("res://scripts/demos/c_zone_debug/tree_fan_route.gd")
var level
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

# until the climb that has started is over and he stands
func _finish_climb() -> void:
	for i in 400:
		await physics_frame
		if level.climb_time < 0.0 and level.player.is_on_floor():
			break
	await _frames(5)

func _release_all() -> void:
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)

func _feet() -> Vector2:
	return level.player.position + Vector2(13.0, 54.0)

func _block(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.size * 0.5
	body.add_child(shape)
	body.position = rect.position
	level.add_child(body)
	return body

# run at a ledge and jump when `gap` px are left to its face
func _run_and_jump(face_x: float, gap: float) -> void:
	Input.action_press("move_right")
	for i in 240:
		await physics_frame
		if level.player.position.x + 26.0 >= face_x - gap:
			break
	Input.action_press("jump")
	await _frames(25)
	Input.action_release("jump")

func _run() -> void:
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_cliff_act()
	await _frames(40)
	var floor_y: float = level.cliff._ground_y(6560.0)
	_check(level.actor == level.hood_actor and level.actor.has_clip(&"climb"), "he is the hooded boy and has the climb clip")

	# the jump: about his own height; the run: slow
	level.player.position = Vector2(6500.0, floor_y - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	var start_y := _feet().y
	Input.action_press("jump")
	var apex := 0.0
	for i in 90:
		await physics_frame
		apex = maxf(apex, start_y - _feet().y)
	Input.action_release("jump")
	await _frames(40)
	print("jump apex %.1f px" % apex)
	_check(apex > 45.0 and apex <= 68.0, "a held jump rises about his own height (%.1f px, 76 px tall on screen)" % apex)
	var x0: float = level.player.position.x
	Input.action_press("move_right")
	await _frames(60)
	var speed: float = (level.player.position.x - x0) / 1.0
	Input.action_release("move_right")
	_check(speed > 120.0 and speed < 175.0, "he runs slowly (%.0f px/s)" % speed)
	await _frames(30)

	# a wall 90 px high: far more than a jump
	var wall := _block(Rect2(6700.0, floor_y - 90.0, 90.0, 90.0))
	level.player.position = Vector2(6560.0, floor_y - 54.0)
	level.player.velocity = Vector2.ZERO
	level.facing = 1.0
	await _frames(20)
	await _run_and_jump(6700.0, 70.0)
	var grabbed := false
	for i in 80:
		await physics_frame
		if level.climb_time >= 0.0:
			grabbed = true
			break
	Input.action_release("move_right")
	_check(grabbed, "a jump at a 90 px wall takes hold of its edge")
	_check(level.climb_corner.distance_to(Vector2(6700.0 + level.CLIMB_INSET, floor_y - 90.0)) < 3.0, "at its corner (%s)" % level.climb_corner)
	await _frames(20)
	_check(level.climb_total > 1.2 and level.climb_total < 2.2, "the climb takes %.1f s" % level.climb_total)
	_check(level.actor.current_clip == &"climb" and level.pose.action == ActorPoseState.ACTION_CLIMB, "the climb clip plays (%s)" % level.actor.current_clip)
	# the picture must not drop when the idle takes over (the climb used to end a few pixels above where the idle draws him)
	var ys: Array = []
	var end_offset := 0.0
	for i in 600:
		await physics_frame
		ys.append(float(level.actor.global_position.y))
		if level.climb_time >= 0.0:
			end_offset = float(level.actor.support_offset)
		if level.climb_time < 0.0 and level.player.is_on_floor():
			break
	for i in 15:
		await physics_frame
		ys.append(float(level.actor.global_position.y))
	var idle_offset: float = float(level.actor.support_offset)
	var worst_step := 0.0
	for i in range(maxi(1, ys.size() - 40), ys.size()):
		worst_step = maxf(worst_step, absf(float(ys[i]) - float(ys[i - 1])))
	print("climb sink at the end %.2f, idle %.2f, biggest step in the last 40 frames %.2f px" % [end_offset, idle_offset, worst_step])
	_check(absf(end_offset - idle_offset) < 1.0, "the climb ends sunk onto the ledge exactly as the idle stands on it (%.2f vs %.2f px)" % [end_offset, idle_offset])
	_check(worst_step < 1.5, "no drop when the idle takes over (biggest step %.2f px)" % worst_step)
	_check(level.climb_time < 0.0, "the climb ends")
	var top_feet := _feet()
	_check(absf(top_feet.y - (floor_y - 90.0)) < 2.0 and top_feet.x > 6700.0 and top_feet.x < 6740.0, "he stands on top of it (%s)" % top_feet)
	await _frames(30)
	_check(level.player.is_on_floor() and absf(_feet().y - (floor_y - 90.0)) < 2.5, "and the floor holds him there")
	_check(level.actor.current_clip in [&"climb", &"idle_left"], "the climb ends in the idle (%s)" % level.actor.current_clip)
	await _frames(20)
	_check(level.actor.current_clip == &"idle_left", "after the climb he stands in the idle (%s)" % level.actor.current_clip)
	wall.queue_free()
	await _frames(5)

	# letting go
	var wall2 := _block(Rect2(6700.0, floor_y - 90.0, 90.0, 90.0))
	level.player.position = Vector2(6560.0, floor_y - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	await _run_and_jump(6700.0, 70.0)
	for i in 80:
		await physics_frame
		if level.climb_time >= 0.0:
			break
	Input.action_release("move_right")
	await _frames(10)
	Input.action_press("move_left")
	await _frames(6)
	Input.action_release("move_left")
	_check(level.climb_time < 0.0 and not level.player.is_on_floor(), "moving away from the ledge lets go")
	await _frames(90)
	_check(level.player.is_on_floor() and _feet().y > floor_y - 4.0, "and he drops to the ground")
	wall2.queue_free()
	await _frames(5)

	# a low step is stepped on, not climbed
	var step := _block(Rect2(6700.0, floor_y - 22.0, 300.0, 22.0))
	level.player.position = Vector2(6560.0, floor_y - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	await _run_and_jump(6700.0, 20.0)
	var climbed_low := false
	for i in 25:
		await physics_frame
		climbed_low = climbed_low or level.climb_time >= 0.0
	Input.action_release("move_right")
	for i in 40:
		await physics_frame
		climbed_low = climbed_low or level.climb_time >= 0.0
	print("step: feet %s climbed %s" % [_feet(), climbed_low])
	_check(absf(_feet().y - (floor_y - 22.0)) < 2.5 and not climbed_low, "a 22 px step is jumped on to, not climbed")
	step.queue_free()
	await _frames(5)

	# a thin deck 100 px up with the player's jump from below
	var deck := _block(Rect2(6700.0, floor_y - 100.0, 110.0, 14.0))
	level.player.position = Vector2(6580.0, floor_y - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	await _run_and_jump(6700.0, 36.0)
	grabbed = false
	for i in 80:
		await physics_frame
		if level.climb_time >= 0.0:
			grabbed = true
			break
	Input.action_release("move_right")
	_check(grabbed, "a thin deck 100 px up can be climbed onto too")
	await _finish_climb()
	_check(level.player.is_on_floor() and absf(_feet().y - (floor_y - 100.0)) < 2.5 and _feet().x > 6700.0, "and he ends on it (%s)" % _feet())
	deck.queue_free()
	await _frames(5)

	# the box of act two: 94 px, climbed from the ledge
	level.debug_enter_marsh_act()
	await _frames(30)
	var ledge_y: float = level.SECOND_ACT_LEDGE.position.y
	level.player.position = Vector2(2870.0, ledge_y - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	await _run_and_jump(2950.0, 36.0)
	grabbed = false
	for i in 80:
		await physics_frame
		if level.climb_time >= 0.0:
			grabbed = true
			break
	Input.action_release("move_right")
	_check(grabbed, "from the ledge he can climb onto the 94 px box")
	await _finish_climb()
	_check(level.player.is_on_floor() and absf(_feet().y - (ledge_y - 94.0)) < 3.0, "and stands on it (%s, wanted y %.0f)" % [_feet(), ledge_y - 94.0])
	# the box, pushed under the root platform (86 px above it)
	level.puzzle_box.position = Vector2(3150.0, ledge_y - 94.0)
	level.puzzle_box.velocity = Vector2.ZERO
	level.player.position = Vector2(3215.0, ledge_y - 94.0 - 54.0)
	level.player.velocity = Vector2.ZERO
	await _frames(20)
	await _run_and_jump(3296.0, 30.0)
	grabbed = false
	for i in 80:
		await physics_frame
		if level.climb_time >= 0.0:
			grabbed = true
			break
	Input.action_release("move_right")
	_check(grabbed, "from the box he can climb onto the root platform above it")
	await _finish_climb()
	_check(level.player.is_on_floor() and absf(_feet().y - level.ROOT_PLATFORM.position.y) < 3.0, "and stands on it (%s, wanted y %.0f)" % [_feet(), level.ROOT_PLATFORM.position.y])

	# act one: the rack cannot be climbed from the bank, only from the raft
	level.reset_all()
	await Route.frames(level, 100)
	level.crate.position.x = 750.0
	level.player.position = Vector2(475.0, 496.0)
	level.player.velocity = Vector2.ZERO
	await Route.frames(level, 30)
	Input.action_press("jump")
	var from_bank := false
	for i in 70:
		await physics_frame
		from_bank = from_bank or level.climb_time >= 0.0
	Input.action_release("jump")
	_check(not from_bank, "jumping up from the bank does not take hold of the rack")
	# from the raft up through the drying rack to the leaf on the tree
	level.reset_all()
	await Route.frames(level, 100)
	level.player.position = Vector2(470.0, 496.0)
	level.player.velocity = Vector2.ZERO
	await Route.frames(level, 40)
	_check(level.is_riding(), "he stands on the raft")
	level.facing = 1.0
	Input.action_press("jump")
	var took_hold := false
	for i in 60:
		await physics_frame
		took_hold = took_hold or level.climb_time >= 0.0
	Input.action_release("jump")
	_check(took_hold, "jumping up under the rack takes hold of it")
	await _finish_climb()
	_check(level.player.is_on_floor() and absf(_feet().y - level.RACK_RECT.position.y) < 2.5, "he stands on the rack (%s)" % _feet())
	level.player.position.x = 470.0
	level.facing = 1.0
	await Route.frames(level, 20)
	_check(not level.can_pick_up_fan(), "standing on the rack he cannot reach the leaf")
	Input.action_press("jump")
	var reached := await Route.until(level, func(): return level.can_pick_up_fan(), 60)
	Input.action_release("jump")
	_check(reached, "a jump from the rack reaches the leaf")

	# act two: the gaps with his shorter jump (the fire deck and the rope-hung deck)
	level.debug_enter_marsh_act()
	await _frames(30)
	# the boulders have already fallen and are gone (this is about the pit)
	level.rock_sequence = true
	level.limb_broken = true
	for rock in level.marsh_rocks:
		rock["mode"] = level.ROCK_DROP
		rock["pos"] = Vector2(4300.0, 900.0)
	level.player.position = Vector2(4470.0, level.marsh_rock_surface_y(4488.0) - 56.0)
	level.player.velocity = Vector2.ZERO
	await _frames(30)
	await _run_and_jump(4620.0, 103.0)
	var landed_on_deck := false
	var fire_hold := false
	for i in 120:
		await physics_frame
		fire_hold = fire_hold or level.climb_time >= 0.0
		if i == 30:
			Input.action_release("move_right")
		if level.player.is_on_floor() and absf(_feet().y - level.FIRE_DECK.position.y) < 3.0 and _feet().x > 4617.0 and _feet().x < 4705.0:
			landed_on_deck = true
			break
	Input.action_release("move_right")
	print("fire deck: grabbed %s, feet %s" % [fire_hold, _feet()])
	_check(landed_on_deck, "from the pit's edge one jump reaches the fire deck (%s)" % _feet())
	level.debug_enter_marsh_act()
	await _frames(30)
	level.player.position = Vector2(5062.0, level.marsh_rock_surface_y(5075.0) - 56.0)
	level.player.velocity = Vector2.ZERO
	await _frames(30)
	await _run_and_jump(5180.0, 100.0)
	grabbed = false
	for i in 90:
		await physics_frame
		if level.climb_time >= 0.0:
			grabbed = true
			break
	Input.action_release("move_right")
	await _finish_climb()
	print("hang deck: grabbed %s feet %s" % [grabbed, _feet()])
	_check(level.player.is_on_floor() and absf(_feet().y - level.HANG_DECK.position.y) < 14.0 and _feet().x > 5150.0 and _feet().x < 5272.0, "from the last foot of land he gets onto the rope-hung deck (%s)" % _feet())

	_release_all()
	print("climb smoke: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
