extends SceneTree
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func frames(count:int) -> void:
	for i in count: await physics_frame

func check(ok:bool, message:String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func run() -> void:
	var level = load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
	root.add_child(level)
	await frames(6)
	level.enter_root_cliff_test()
	await frames(4)
	var route = level.bridge_to_c
	check(route.active and route.enabled, "mine route must start at the ladder bank")
	check(level.log_bridge.mine_geometry, "old bridge collision must be disabled")
	check(route.platforms.size() == route.STEPS.size(), "all stone landings must exist")
	route.checkpoint_step = 4
	route.restore_checkpoint()
	await frames(4)
	check(level.player.is_on_floor(), "mine mouth must be a grounded checkpoint")
	level.player.position = Vector2(route.STOP_X-13,route.STEPS[4].y-55)
	await frames(4)
	print("STOP_STATE ",level.player.is_on_floor()," ",route.checkpoint_step," ",level.player.position," active=",route.active)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check(route.stop_set, "rail stop must be set before the rock is released")
	level.player.position = Vector2(route.ROCK_X-13,route.STEPS[4].y-55)
	await frames(4)
	print("ROCK_STATE ",level.player.is_on_floor()," ",route.checkpoint_step," ",level.player.position," active=",route.active)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check(route.rock_progress >= 0, "loose rock should start moving")
	await frames(88)
	check(route.brake_open, "weighted bucket must lift the brake")
	level.player.position = Vector2(route.FIRST_RAIL.x-13,route.STEPS[4].y-55)
	await frames(4)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	check(route.ride_t >= 0, "boy must board the cart after the brake opens")
	Input.action_press("climb_down")
	route.ride_t = 0.985
	await frames(18)
	Input.action_release("climb_down")
	check(route.in_c_zone, "ride must reach C in continuous coordinates")
	check(absf(level.player.position.y + 54.0 - level.ground_y(-180)) < 12.0, "cart exit must meet C's original ground")
	quit(0 if failures==0 else 1)
