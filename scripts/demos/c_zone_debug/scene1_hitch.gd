extends SceneTree

# Windowed frame-time log of scene 1 from the moment it loads: loading, lying, getting up, the first steps. Every frame that takes
# more than 20 ms is printed with what was going on (the actor's clip, how far the lying / get-up is).
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var t_load := Time.get_ticks_usec()
	level = SCENE.instantiate()
	root.add_child(level)
	print("HITCH instantiate+add_child %.0f ms" % ((Time.get_ticks_usec() - t_load) / 1000.0))
	for i in 30:
		await process_frame
	var t_enter := Time.get_ticks_usec()
	level.debug_enter_scene1()
	print("HITCH debug_enter_scene1 %.0f ms" % ((Time.get_ticks_usec() - t_enter) / 1000.0))
	# time every draw callback in the level (GDScript drawing is main-thread work that runs every frame a node asks for a redraw)
	var draw_cost := {}
	var draw_calls := {}
	_wrap_draws(level, draw_cost, draw_calls)
	var last := Time.get_ticks_usec()
	var worst := 0.0
	var count := 0
	var slow := 0
	var pressed := false
	var start := last
	for i in 900:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		last = now
		var t := (now - start) / 1.0e6
		count += 1
		worst = maxf(worst, dt)
		if t > 3.6 and not pressed:
			pressed = true
			Input.action_press("move_right")
		if dt > 20.0:
			slow += 1
		if dt > 20.0 or i % 15 == 0:
			var actor = level.hood_actor
			print("HITCH frame %d t=%.2fs dt=%.1f ms physics %.1f ms process %.1f ms draws %d nodes %d objects %d intro=%.2f clip=%s frame=%d x=%.0f" % [i, t, dt, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)), level.scene1.intro_time, actor.current_clip, actor.current_frame_index, level.player.position.x])
		if t > 11.0:
			break
	Input.action_release("move_right")
	var rows: Array = []
	for key in draw_cost:
		rows.append([key, float(draw_cost[key]) / 1000.0, int(draw_calls[key])])
	rows.sort_custom(func(a, b): return a[1] > b[1])
	for row in rows.slice(0, 14):
		print("DRAW %-48s total %7.1f ms over %d calls = %.2f ms each" % [row[0], row[1], row[2], row[1] / maxf(float(row[2]), 1.0)])
	print("HITCH done: %d frames, %d over 20 ms, worst %.1f ms" % [count, slow, worst])
	quit()

func _wrap_draws(node: Node, cost: Dictionary, calls: Dictionary) -> void:
	if node is CanvasItem:
		for connection in node.get_signal_connection_list("draw"):
			var original: Callable = connection["callable"]
			node.draw.disconnect(original)
			var key := "%s %s" % [node.get_path().get_name(node.get_path().get_name_count() - 1), original.get_method()]
			cost[key] = 0
			calls[key] = 0
			node.draw.connect(func():
				var t := Time.get_ticks_usec()
				original.call()
				cost[key] += Time.get_ticks_usec() - t
				calls[key] += 1)
	for child in node.get_children():
		_wrap_draws(child, cost, calls)
