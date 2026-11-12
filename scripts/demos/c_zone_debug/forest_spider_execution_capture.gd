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
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest-spider/execution")
	level=SCENE.instantiate()
	root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8)
	level.debug_enter_scene1()
	level.scene1.predator.enabled=false
	level.scene1.intro_time=99
	var airborne:=OS.get_cmdline_user_args().has("--air")
	var x:=S.START_X+(3650 if airborne else 3240)
	level.player.position=Vector2(x-13,S.ground_top(x)-56)
	level.player.velocity=Vector2.ZERO
	level.camera_x=level.player.position.x-525
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	await frames(30)
	if airborne:
		Input.action_press("jump");await frames(14);Input.action_release("jump")
	var spider=level.scene1.spider
	spider.position=Vector2(x-(165 if airborne else 98),S.ground_top(x-(165 if airborne else 98)))
	spider.state=spider.State.CHASE
	spider.time=0
	spider.motion_clock=0.4
	await frames(2)
	var output:="res://artifacts/forest-spider/execution/"+("air/" if airborne else "")
	DirAccess.make_dir_recursive_absolute(output)
	if OS.get_cmdline_user_args().has("--motion"):
		DirAccess.make_dir_recursive_absolute(output+"motion")
		for i in (60 if airborne else 48):
			await frames(2)
			RenderingServer.force_draw()
			var picture:=root.get_texture().get_image()
			picture.resize(960,540,Image.INTERPOLATE_LANCZOS)
			picture.save_png(output+"motion/f_%03d.png"%i)
		print("EXECUTION MOTION CAPTURED")
		quit()
		return
	var fixtures:=[["01-fallen",0.32],["02-leg-raised",0.68],["03-impale",0.84],["04-blood-burst",0.98],["05-withdraw",1.38]]
	if airborne:fixtures=[["01-hook",0.24],["02-lift",0.58],["03-leg-raised",0.94],["04-impale",1.06],["05-blood",1.27],["06-hold",1.65]]
	for fixture in fixtures:
		for i in 100:
			if spider.time>=fixture[1]:break
			await frames(1)
		RenderingServer.force_draw()
		var picture:=root.get_texture().get_image()
		picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
		picture.save_png(output+fixture[0]+".png")
		print("EXECUTION ",fixture[0]," t=",spider.time," blood=",spider.blood.size()," tip error=",level.art.spider_art.view.execution_error)
	await frames(120)
	quit()
