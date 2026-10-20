extends SceneTree

# Live capture of act three: the broken bridge, the throw preview, the stone stack, the lift and the ledge.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Cliff = preload("res://scripts/demos/c_zone_debug/cliff_act.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = SCENE.instantiate()
	root.add_child(level)
	await _frames(10)
	level.debug_enter_cliff_act()
	await _frames(20)
	var cliff = level.cliff
	await _snap("01-bank")
	cliff.bridge_state = Cliff.Bridge.DOWN
	level.player.position = Vector2(6560.0, 330.0)
	level.player.velocity = Vector2.ZERO
	await _frames(40)
	await _snap("02-far-bank")
	level.player.position = Vector2(6830.0, 330.0)
	level.player.velocity = Vector2.ZERO
	level.facing = 1.0
	await _frames(40)
	await _snap("03-stack")
	# Take the stones off the pin one by one, with the real input.
	for round in range(3):
		level.player.position = Vector2(Cliff.STACK_X - 40.0, level.player.position.y)
		level.facing = 1.0
		await _frames(8)
		Input.action_press("interact")
		await _frames(2)
		Input.action_release("interact")
		await _frames(30)
		await _snap("04-pulled-%d" % (round + 1))
		# Put it down away from the stack with a tap.
		level.player.position.x = 6760.0 - float(round) * 40.0
		await _frames(10)
		Input.action_press("interact")
		await _frames(4)
		Input.action_release("interact")
		await _frames(50)
	await _frames(100)
	await _snap("05-landed")
	# Aboard, pumping the lever.
	level.player.position = Vector2(Cliff.LIFT_X + Cliff.LIFT_W - 30.0, 340.0)
	level.player.velocity = Vector2.ZERO
	level.facing = 1.0
	await _frames(30)
	var shots := 0
	for pump in range(24):
		Input.action_press("interact")
		await _frames(2)
		Input.action_release("interact")
		await _frames(10)
		if pump == 0:
			await _snap("06a-lever-pull")
		await _frames(8)
		if pump == 1:
			await _snap("06b-lever-push")
		await _frames(14)
		if pump == 3:
			await _snap("07-pumping-high")
		if cliff.lift_state == Cliff.Lift.ARRIVED:
			break
	await _frames(60)
	await _snap("08-docked")
	Input.action_press("move_right")
	await _frames(60)
	await _snap("09-ramp")
	await _frames(30)
	await _snap("09b-ramp")
	await _frames(90)
	await _snap("10-ramp-top")
	Input.action_release("move_right")
	quit(0)

func _snap(label: String) -> void:
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-cliff")
	root.get_texture().get_image().save_png("res://artifacts/c-zone-cliff/%s.png" % label)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
