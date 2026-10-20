extends SceneTree

const Scene = preload("res://scenes/debug/c_zone_river.tscn")
const Swing = preload("res://scripts/demos/c_zone_debug/fan_swing_manifest.gd")
var level
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = Scene.instantiate()
	root.add_child(level)
	level.intro_time = 0.0
	level.player.position = Vector2(800,496)
	level.crate.position = Vector2(2200,518)
	level.fan_owned = true
	for i in 60: await _step()
	var seen := {}
	Input.action_press("blade_toggle")
	await _step()
	Input.action_release("blade_toggle")
	for i in int(ceil(Swing.DURATION * 60.0)) + 4:
		if level.actor.current_clip == Swing.CLIP:
			seen[level.actor.current_frame_index] = true
		await _step()
	var main_stroke := true
	for i in range(38-12,45-12):
		main_stroke = main_stroke and seen.has(i)
	_check(main_stroke and seen.has(0) and seen.has(Swing.COUNT-1),"E preserves every main-stroke frame and both endpoints")
	_check(Swing.COUNT == 89,"all consecutive source frames 12..100 remain loaded")
	_check(level.actor.current_clip == &"carry","swing returns to carry")
	level.set_physics_process(false)
	var feet: Vector2 = level.player.position
	for facing in [-1.0,1.0]:
		level.facing = facing
		for i in Swing.COUNT:
			level.fan_swing = Swing.DURATION * (1.0 - Swing.frame_progress(i))
			level._present(0.0)
			_check(level.actor.current_frame_index == i and level.actor.current_clip == Swing.CLIP,"frame %d facing %s" % [i,facing])
			_check(level.fan.position.distance_to(level.actor.fan_hand_position()) < 0.01,"fan grip follows frame")
			_check(absf(level.fan.rotation-facing*Swing.angle(i)) < 0.001,"fan angle mirrors with frame")
			_check(level.actor.animated.position == -Swing.ROOT and level.actor.animated.scale == Vector2.ONE and level.player.position == feet,"fixed actor root and physics")
			_check(not level.actor.small_item.visible and level.fan.z_index < level.actor.z_index,"no stone; fist covers stem")
	level.set_physics_process(true)
	level.fan_cooldown = 0.0
	level.swing_fan()
	Input.action_press("move_right")
	for i in 5: await _step()
	_check(level.actor.current_clip == &"carry_run","moving during swing retains walking legs")
	Input.action_press("jump")
	for i in 4: await _step()
	_check(level.actor.current_clip in [&"carry_takeoff",&"carry_rise",&"carry_apex",&"carry_fall"],"jump interrupts stationary swing without freezing legs")
	Input.action_release("jump")
	Input.action_release("move_right")
	for i in 80: await _step()
	_check(level.actor.current_clip == &"carry","landing recovers carry")
	level.reset_all()
	level.intro_time = 0.0
	level.crate.position = Vector2(1490,level._unloaded_float_y())
	level.floating = true
	level.player.position = Vector2(1549,400)
	level.fan_owned = true
	for i in 120: await _step()
	level.swing_fan()
	for i in 27: await _step()
	_check(level.actor.current_clip == Swing.CLIP and level.wind_impulses > 0,"riding raft plays swing and preserves wind impulse")
	if "--capture" in OS.get_cmdline_user_args():
		level.camera.position = level.player.position + Vector2(55,-12)
		level.camera.zoom = Vector2.ONE * 2.0
		level.camera.force_update_scroll()
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-fan/swing-in-game")
		root.get_texture().get_image().save_png("res://artifacts/c-zone-fan/swing-in-game/raft-swing-8496.png")
	Input.action_press("interact")
	for i in 30: await _step()
	Input.action_release("interact")
	_check(not level.fan_owned and level.fan_swing == 0.0,"put-down clears swing")
	print("fan_swing_smoke: %s" % ("PASS" if failures == 0 else "FAIL"))
	level.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _step() -> void:
	await physics_frame
	await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
