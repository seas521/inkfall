extends "res://scripts/demos/c_zone_debug/rope_ladder_capture.gd"

var captures:=0
func _capture(label:String):
	RenderingServer.force_draw()
	var shot:=root.get_texture().get_image()
	shot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	shot.save_png("res://artifacts/rope-ladder/catch-review/%03d.png"%captures)
	if not label.is_empty():
		shot.save_png("res://artifacts/rope-ladder/catch-review/"+label+".png")
	print("CATCH REVIEW ",captures," source=",level.rope_ladder.frame," feet=",level.rope_ladder.feet())
	captures+=1
func _run():
	DirAccess.make_dir_recursive_absolute("res://artifacts/rope-ladder/catch-review")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	Film.attach(level)
	await _frames(8)
	level.debug_enter_log_bridge()
	var ladder=level.rope_ladder
	for offset in [22.0,68.0]:
		ladder.stop()
		level.set_physics_process(true)
		level.actor.finish_rope_ladder()
		level.player.position=Vector2(ladder.anchor().x+offset-13,level.log_bridge.LEFT.position.y-54)
		level.player.velocity=Vector2.ZERO
		level.log_bridge.fall_in_air=false
		await _frames(24)
		level.camera_x=level.player.position.x-525
		level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		if OS.get_cmdline_user_args().has("--play"):
			DisplayServer.window_set_title("Inkfall · 台阶跳回绳梯 · 接梯修复预览")
			print("PLAY READY: Space jumps from the bank to catch the ladder; W/S climbs; Space dismounts")
			return
		# Advance fixed physics steps ourselves. PNG readback must not speed
		# up the recorded animation by accumulating extra live physics ticks.
		level.set_physics_process(false)
		for i in 5:
			for j in 3:level.log_bridge._present(1.0/60.0)
			await process_frame
			_capture("bank-%.0f"%offset if i==4 else "")
		ladder.catch_from_bank()
		for i in 31:
			for j in 3:ladder.tick(1.0/60.0)
			await process_frame
			_capture("crouch-%.0f"%offset if i==6 else ("catch-%.0f"%offset if i==16 else ""))
		_capture("held-%.0f"%offset)
	print("CATCH REVIEW COMPLETE ",captures)
	quit(0)
