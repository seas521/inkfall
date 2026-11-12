extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
func _initialize():call_deferred("_run")
func frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _run():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8)
	level.debug_enter_scene1()
	level.scene1.predator.enabled=false
	level.scene1.spider.enabled=false
	level.scene1.intro_time=99
	level.scene1.cut=S.Cut.NONE
	if OS.get_cmdline_user_args().has("--play"):
		var pond_preview:=OS.get_cmdline_user_args().has("--pond")
		var x:float=S.START_X+(3035 if pond_preview else 1740)
		level.player.position=Vector2(x-13,S.ground_top(x)-54)
		level.player.velocity=Vector2.ZERO
		level.camera_x=level.player.position.x-430
		level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		level.scene1.predator.enabled=not pond_preview
		DisplayServer.window_set_title("Inkfall · 草皮贴合修复 · 尖刺坑与食人花坡面")
		print("GRASS SURFACE PLAY READY")
		return
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest-grass/surface-fix")
	for fixture in [["01-pit-lip",1740],["02-plant-bank",2445],["03-pond-bank",2600],["04-steep-bank",2090],["05-pond-far-bank",3020]]:
		var x:float=S.START_X+float(fixture[1])
		level.player.position=Vector2(x-13,S.ground_top(x)-54)
		level.player.velocity=Vector2.ZERO
		level.camera_x=level.player.position.x-430
		level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		level.set_physics_process(false)
		for i in 12:
			level._present(1.0/60.0)
			await process_frame
		RenderingServer.force_draw()
		var shot:=root.get_texture().get_image()
		shot.save_png("res://artifacts/forest-grass/surface-fix/"+fixture[0]+".png")
		print("GRASS SURFACE CAPTURE ",fixture[0])
	quit()
