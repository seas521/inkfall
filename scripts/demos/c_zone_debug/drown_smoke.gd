extends SceneTree

const Scene = preload("res://scenes/debug/c_zone_river.tscn")
var level
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	level = Scene.instantiate()
	root.add_child(level)
	level.intro_time = 0.0
	level.checkpoint = 1
	level.checkpoint_fan = true
	level.fan_owned = true
	level.crate.position = Vector2(2200,518)
	level.player.position = Vector2(1510,584)
	await _frames(40)
	_check(level.death_time > 0.0 and level.actor.current_clip == &"water_drown","deep water uses the supplied struggle frames")
	_check(not level.fan.visible and not level.actor.small_item.visible,"drowning hides held equipment")
	var sprays: Array = level.art.water_impacts.filter(func(event): return event.has("drops"))
	_check(not sprays.is_empty(), "struggling emits dedicated spray instead of repeated ripple rings")
	if not sprays.is_empty():
		var drops: Array = sprays[0].drops
		_check(drops.size() >= 15 and drops[0].velocity != drops[1].velocity, "spray has varied ballistic droplets")
	var x: float = level.player.position.x
	var y: float = level.actor.position.y
	Input.action_press("move_right")
	Input.action_press("jump")
	Input.action_press("blade_toggle")
	if "--capture" in OS.get_cmdline_user_args():
		level.camera.position = level.player.position+Vector2(30,-60)
		level.camera.zoom = Vector2.ONE*2.0
		level.camera.force_update_scroll()
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-drown")
		root.get_texture().get_image().save_png("res://artifacts/c-zone-drown/struggle.png")
	await _frames(94)
	_check(level.death_time > 0.0 and level.actor.position.y > y+20.0,"struggle progresses into sinking")
	_check(absf(level.player.position.x-x)<0.01,"drowning cannot walk or jump out of the animation")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("blade_toggle")
	await _frames(50)
	_check(level.death_time == 0.0 and level.player.position.x<1200.0 and level.fan_owned,"checkpoint restores the player and acquired fan")
	_check(level.actor.current_clip != &"water_drown" and level.actor.modulate.a > 0.99,"normal visuals recover after drowning")
	print("drown_smoke: %s" % ("PASS" if failures==0 else "FAIL"))
	level.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
