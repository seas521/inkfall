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
	level.player.position=Vector2(x-13,S.ground_top(x)-54)
	level.player.velocity=Vector2.ZERO
	level.scene1.intro_time=99
	level.scene1.cut=S.Cut.NONE
	level.camera_x=level.player.position.x-525
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
func _run():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute("res://artifacts/rock-crevice")
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8)
	level.debug_enter_scene1()
	level.scene1.predator.enabled=false
	if OS.get_cmdline_user_args().has("--play"):
		place(3700)
		level.scene1.spider.last_player_x=level.player.position.x+13
		DisplayServer.window_set_title("Inkfall · 短岩缝 · 弯腰通行")
		return
	if OS.get_cmdline_user_args().has("--motion"):
		place(3760)
		level.scene1.spider.enabled=false
		DirAccess.make_dir_recursive_absolute("res://artifacts/rock-crevice/motion")
		var directory:=DirAccess.open("res://artifacts/rock-crevice/motion")
		for old:String in directory.get_files():
			if old.begins_with("f_") and old.ends_with(".png"):directory.remove(old)
		Input.action_press("move_right")
		for i in 620:
			await frames(3)
			RenderingServer.force_draw()
			var picture:=root.get_texture().get_image()
			picture.resize(960,540,Image.INTERPOLATE_LANCZOS)
			picture.save_png("res://artifacts/rock-crevice/motion/f_%03d.png"%i)
			if level.player.position.x+13>S.Crevice.EXIT_SAFE+100 and not level.scene1.low_stance.active():break
		Input.action_release("move_right")
		print("CREVICE MOTION x=",level.player.position.x+13-S.START_X)
		quit();return
	level.set_physics_process(false)
	var low=level.scene1.low_stance
	for item in [["00-entrance",3828,false],["01-approach",3910,true],["02-low-passage",4470,true],["03-exit",5330,false],["04-cliff",5570,false]]:
		place(item[1])
		low.mode=low.Mode.LOW if item[2] else low.Mode.UP
		low.time=0.25
		low.distance=28
		level.player.velocity=Vector2(60,0) if item[2] else Vector2.ZERO
		for i in 32:
			level._present(1.0/60.0)
			await process_frame
		RenderingServer.force_draw()
		var picture:=root.get_texture().get_image()
		picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
		picture.save_png("res://artifacts/rock-crevice/"+item[0]+".png")
		print("CREVICE CAPTURE ",item[0])
	quit()
