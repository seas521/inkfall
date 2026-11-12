extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
func _initialize():call_deferred("run")
func frames(n:int):
	for i in n:await process_frame
func run():
	root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var args := OS.get_cmdline_user_args()
	var large := "--large" in args or "--4k" in args
	var capture_size := Vector2i(3840,2160) if "--4k" in args else (Vector2i(2560,1440) if large else Vector2i(1280,720))
	DisplayServer.window_set_size(capture_size)
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8);level.debug_enter_scene1();level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
	level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
	level.set_physics_process(false)
	var review_dir := "res://artifacts/forest-depth-review-4k" if "--4k" in args else ("res://artifacts/forest-depth-review-large" if large else "res://artifacts/forest-depth-review")
	if "--rainforest" in args:
		review_dir = "res://artifacts/forest-primeval-v2/review"
	if "--cinema" in args:
		review_dir = "res://artifacts/forest-lens-v3/review"
	if "--lens-v4" in args:
		review_dir = "res://artifacts/forest-lens-v4/review"
	if "--opening-v5" in args:
		review_dir = "res://artifacts/forest-opening-v5/review"
	if "--route-v1" in args:
		review_dir = "res://artifacts/forest-route-v1/after"
	DirAccess.make_dir_recursive_absolute(review_dir)
	if "--opening-v6" in args:
		review_dir = "res://artifacts/forest-opening-v6/review"
	var stops=[Vector2(S.START_X+180,0),Vector2(S.START_X+1050,1),Vector2(S.START_X+2050,2),Vector2(S.START_X+2800,3),Vector2(S.Crevice.LEFT+160,4),Vector2(S.Crevice.EXIT_SAFE,5),Vector2(S.CLIFF_X-220,6)]
	if "--route-v1" in args:
		stops.insert(4,Vector2(-6650,7))
	if "--4k" in args:
		stops = [stops[2]]
	for stop:Vector2 in stops:
		var x:=stop.x
		level.player.position=Vector2(x-13,S.ground_top(x)-54);level.player.velocity=Vector2.ZERO
		level.camera_x=x-520;level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		for pool in level.scene1.pools:
			pool.visible=absf(pool.x_start-x)<2400.0
			if pool.visible:pool.update(0.016,Vector2(x,S.ground_top(x)),Vector2.ZERO,S.ground_top(x))
		level._present(0)
		await frames(6);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(review_dir + "/forest-%02d.png"%int(stop.y))
		print("REVIEW ",stop.y," camera=",level.camera_x)
	if "--opening-motion" in args:
		for i in 241:
			var x:float=S.START_X+180.0+float(i)*0.8
			level.player.position=Vector2(x-13,S.ground_top(x)-54)
			level.camera_x=x-520
			level.camera_y=level._camera_target_y()
			level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
			level._present(1.0/60.0)
			await process_frame
			if i%120==0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(review_dir+"/motion-%03d.png"%i)
		print("OPENING MOTION: 240 frames, 192 world units, 4 seconds of presentation")
	quit()
