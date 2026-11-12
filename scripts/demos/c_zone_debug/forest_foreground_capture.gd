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
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest-foreground")
	for fixture in [["01-wake",250],["02-log",950],["03-pit",1740],["04-plant",2445],["05-pond",2900],["06-approach",3500]]:
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
		shot.save_png("res://artifacts/forest-foreground/"+fixture[0]+".png")
		print("FOREGROUND CAPTURE ",fixture[0])
	# Capture an actual camera position where a near trunk crosses the left
	# side, so the replacement is verified visibly rather than only offscreen.
	for scan in range(20):
		var cam:float=-10000+scan*180
		level.camera_x=cam
		level.player.position=Vector2(cam+430,S.ground_top(cam+443)-54)
		level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(cam+640,level.camera_y+360)
		level._present(0.0)
		await process_frame
		var has_tree:=false
		for tree in level.art.plates_near.sprites:
			if tree.visible:
				var stem:float=tree.position.x+tree.texture.get_width()*.5*tree.scale.x
				if stem>70 and stem<260:has_tree=true
		if has_tree:
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://artifacts/forest-foreground/07-left-trunk.png")
			print("FOREGROUND LEFT TRUNK camera=",cam)
			break
	quit()
