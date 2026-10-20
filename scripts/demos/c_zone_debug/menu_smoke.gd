extends SceneTree

var failures := 0
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	if capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
	var configured_scene = load("res://scenes/main.tscn").instantiate()
	var configured_start: int = configured_scene.debug_start_level
	configured_scene.free()
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(40)
	if configured_start == 5:
		_check(current_scene.river != null and not current_scene.river.fan_owned, "configured startup opens the fan-free second act")
	elif configured_start == 6:
		_check(current_scene.river != null and current_scene.river.checkpoint == 4, "configured startup opens the third act on its bank")
	else:
		_check(current_scene.debug_selector_open, "project opens the reduced DEBUG selector")
	if not current_scene.debug_selector_open:
		await _press("ui_cancel")
	for i in range(8):
		await _press("ui_down")
	_check(current_scene.debug_selector_open and current_scene.debug_selection == 5, "DEBUG keyboard navigation stops at the sixth entry")
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/c-zone-river/00-debug-menu.png")
	await _press("interact")
	await _frames(20)
	_check(current_scene.river != null and current_scene.river.hosted_in_level and current_scene.river.player.position.x > 5800.0 and current_scene.river.checkpoint == 4, "third-act entry mounts the continuous scene on the bank before the broken bridge")
	await _press("ui_cancel")
	_check(current_scene.debug_selector_open and current_scene.debug_selection == 5, "Escape returns to the third-act DEBUG entry")
	await _press("ui_up")
	for cycle in range(2):
		await _press("ui_accept" if cycle == 0 else "interact")
		await _frames(20)
		_check(current_scene.river != null and current_scene.river.hosted_in_level, "second-act entry mounts the continuous C-zone scene")
		_check(current_scene.river.player.position.x >= 2780.0 and not current_scene.river.fan_owned, "second-act entry starts after the raft without the retired fan")
		await _press("ui_cancel")
		_check(current_scene.debug_selector_open and current_scene.debug_selection == 4, "Escape returns to the second-act DEBUG entry")
	await _press("ui_up")
	await _press("ui_accept")
	_check(not current_scene.debug_selector_open and current_scene.active_controller == current_scene.level_controllers[3], "cinematic demo remains available")
	await _press("ui_cancel")
	await _press("ui_up")
	await _press("ui_up")
	await _press("ui_accept")
	_check(current_scene.active_controller == current_scene.level_controllers[1], "level 02 still opens after menu reduction")
	current_scene.queue_free()
	await _frames(3)
	var direct_start = load("res://scenes/main.tscn").instantiate()
	direct_start.debug_start_level = 5
	root.add_child(direct_start)
	current_scene = direct_start
	await _frames(20)
	_check(current_scene.river != null and current_scene.river.player.position.x >= 2780.0, "inspector DEBUG startup launches act two directly")
	current_scene.queue_free()
	await _frames(3)
	print("c_zone_menu_smoke: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _press(action: StringName) -> void:
	Input.action_press(action)
	await _frames(3)
	Input.action_release(action)
	await _frames(5)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
