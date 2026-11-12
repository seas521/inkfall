extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
func _initialize():call_deferred("_run")
func frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func place(offset:float):
	var x:=S.START_X+offset
	level.scene1.intro_time=99
	level.scene1.cut=S.Cut.NONE
	level.player.position=Vector2(x-13,S.ground_top(x)-54)
	level.player.velocity=Vector2.ZERO
	level.camera_x=level.player.position.x-525
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
func _run():
	if not OS.get_cmdline_user_args().has("--play"):DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest-spider")
	if OS.get_cmdline_user_args().has("--play"):
		var main=load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await frames(6)
		main._show_debug_selector()
		main.debug_selection=main.SCENE1_DEBUG_INDEX
		main._start_debug_level()
		level=main.river
		place(2740)
		level.scene1.spider.last_player_x=level.player.position.x+13
		await frames(8)
		DisplayServer.window_set_title("Inkfall · 水潭蛛丝伏击 · 森林追逐")
		print("SPIDER PLAY READY")
		return
	level=SCENE.instantiate()
	root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8)
	level.set_physics_process(false)
	var spider=level.scene1.spider
	for fixture in [["01-silk-descent",2850,2630,spider.State.DESCEND,-260],["02-walk-chase",3260,3020,spider.State.CHASE,0],["03-rock-safety",4260,3880,spider.State.STOP,0]]:
		place(fixture[1])
		spider.state=fixture[3]
		spider.time=0.8
		spider.walk_time=0.3
		spider.motion_clock=0.3
		spider.position=Vector2(S.START_X+fixture[2],S.ground_top(S.START_X+fixture[2])+fixture[4])
		for i in 32:
			spider.motion_clock+=1.0/60.0
			level._present(1.0/60.0)
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/forest-spider/"+fixture[0]+".png")
		print("SPIDER CAPTURE ",fixture[0])
	quit()
