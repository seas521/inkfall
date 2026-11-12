extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const Scene1=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
func _initialize():call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _run():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest-predator")
	if OS.get_cmdline_user_args().has("--play"):
		var main=load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await _frames(6)
		main._show_debug_selector()
		main.debug_selection=main.SCENE1_DEBUG_INDEX
		main._start_debug_level()
		level=main.river
		var trip_preview:=OS.get_cmdline_user_args().has("--trip")
		_place(3420 if trip_preview else 2290)
		await _frames(8)
		DisplayServer.window_set_title("Inkfall · 林间荆棘 · 摔倒与起身" if trip_preview else "Inkfall · 尖刺洞后食人花 · 交互试玩")
		print("PREDATOR PLAY READY; F take / throw; Space jump; R retry")
		return
	level=SCENE.instantiate()
	root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await _frames(6)
	level.set_physics_process(false)
	for item in [["01-log-approach",1840.0],["02-bait-and-mouth",2290.0],["03-exit",2630.0]]:
		_place(item[1])
		for i in 8:
			level._present(1.0/60.0)
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/forest-predator/"+item[0]+".png")
		print("PREDATOR CAPTURE ",item[0])
	if OS.get_cmdline_user_args().has("--idle"):
		for item in [["idle-open",0.0],["idle-close",2.1]]:
			level.clock=item[1]
			_place(2290)
			for i in 8:
				level._present(0)
				await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://artifacts/forest-predator/"+item[0]+".png")
	quit()
func _place(offset:float):
	var x:float=Scene1.START_X+offset
	level.scene1.intro_time=99.0
	level.player.position=Vector2(x-13,Scene1.ground_top(x)-54)
	level.player.velocity=Vector2.ZERO
	level.camera_x=level.player.position.x-525
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	level._present(0.0)
