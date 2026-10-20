extends SceneTree

var main
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.debug_start_level = 1
	root.add_child(main)
	await _frames(5)
	var level = main.active_controller
	level._enter_shaft()
	level.shaft_entry_phase = level.ShaftEntryPhase.DONE
	level.entry_fall_lock = 0.0
	level.elapsed = 0.0
	level.player_position = Vector2(530,2296)
	level.player_velocity = Vector2.ZERO
	level.camera_axis = 2050.0
	await _frames(3)
	_check(level.shaft_exit_armed, "last jump shelf arms the exit")
	Input.action_press("move_right")
	for i in 100:
		await _frames(1)
		if main.river_transition != null:
			break
	Input.action_release("move_right")
	_check(main.river_transition != null, "leaving the last shelf starts the cinematic")
	if main.river_transition == null:
		quit(1)
		return
	Input.action_press("jump")
	Input.action_press("interact")
	Input.action_press("blade_toggle")
	await _frames(25)
	_check(main.river == null and level.room == level.Room.SHAFT, "outgoing shot remains in the shaft before blackout")
	await _shot("01-shaft-out")
	await _frames(24)
	_check(main.river != null and not level.visible, "new C replaces the old cavern under cover")
	_check(main.river_transition.veil.color.a > 0.99, "scene swap is fully covered")
	await _shot("02-covered")
	await _frames(34)
	_check(main.river.cinematic_entry and not main.river.fan_owned and not main.river.dragging, "entrance locks gameplay interactions")
	await _shot("03-bank-in")
	await _frames(70)
	Input.action_release("jump")
	Input.action_release("interact")
	Input.action_release("blade_toggle")
	_check(main.river_transition == null and not main.river.cinematic_entry, "cinematic finishes and releases control")
	_check(main.river.camera.zoom.is_equal_approx(Vector2.ONE) and main.river.camera.offset.is_zero_approx(), "camera returns to normal framing")
	_check(main.river.player.is_on_floor() and main.river.death_time == 0.0, "entrance settles safely on the left bank")
	await _shot("04-bank-play")
	var x: float = main.river.player.position.x
	Input.action_press("move_right")
	await _frames(12)
	Input.action_release("move_right")
	_check(main.river.player.position.x > x+10.0, "movement works after the transition")
	main._show_debug_selector()
	await _frames(3)
	_check(main.river == null and root.canvas_transform.is_equal_approx(Transform2D.IDENTITY), "menu exit clears the river camera")
	main.debug_selection = 4
	main._start_debug_level()
	await _frames(4)
	_check(
		main.river != null
			and main.river_transition == null
			and main.river.player.position.x >= 2780.0,
		"dedicated act-two entry starts at the marsh high ledge"
	)
	main._show_debug_selector()
	main.debug_selection = 1
	main._start_debug_level()
	await _frames(3)
	_check(main.active_controller == main.level_controllers[1] and main.river == null, "other levels still open normally")
	main.queue_free()
	await _frames(3)
	print("level01_river_entry_smoke: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _shot(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args():
		return
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-entry")
	var frame := root.get_texture().get_image()
	if label == "04-bank-play":
		var pixel: Vector2 = main.river.art.get_global_transform_with_canvas()*Vector2(800,650)
		pixel *= Vector2(frame.get_size()) / root.get_visible_rect().size
		_check(frame.get_pixel(int(pixel.x),int(pixel.y)).r < 0.08, "host background does not cover C terrain")
	frame.save_png("res://artifacts/c-zone-entry/%s.png" % label)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _check(ok: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",message])
	if not ok:
		failures += 1
