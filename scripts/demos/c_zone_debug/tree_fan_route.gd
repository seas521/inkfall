extends RefCounted

# Input-only route shared by the tree-specific and full-river regressions.
static func climb(level) -> bool:
	Input.action_press("move_left")
	if not await until(level,func(): return level.player.position.x<587.0,180): return false
	Input.action_press("jump")
	if not await until(level,func(): return level.player.position.x<479.0,90): return false
	Input.action_release("move_left")
	await frames(level,34)
	Input.action_release("jump")
	if not await until(level,func(): return level.is_riding(),120): return false
	await frames(level,4)
	Input.action_press("jump")
	await frames(level,42)
	Input.action_release("jump")
	if not await until(level,func(): return level.player.is_on_floor() and absf(level.player.position.y+54.0-level.RACK_RECT.position.y)<2.0,90): return false
	Input.action_press("move_right")
	await frames(level,4)
	Input.action_release("move_right")
	await frames(level,8)
	return true

static func collect(level) -> bool:
	Input.action_press("jump")
	if not await until(level,func(): return level.can_pick_up_fan(),70): return false
	Input.action_press("interact")
	await frames(level,2)
	Input.action_release("interact")
	await frames(level,28)
	Input.action_release("jump")
	return level.fan_owned and not level.fan_on_tree

static func frames(level, count: int) -> void:
	for i in count: await level.get_tree().physics_frame

static func until(level, condition: Callable, limit: int) -> bool:
	for i in limit:
		if condition.call(): return true
		await level.get_tree().physics_frame
	return condition.call()
