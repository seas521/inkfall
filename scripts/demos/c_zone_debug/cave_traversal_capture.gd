extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
func _initialize():call_deferred("_run")
func frames(n:int):
	for i in n:await physics_frame;await process_frame
func shot(name:String):
	RenderingServer.force_draw()
	var picture:=root.get_texture().get_image();picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	picture.save_png("res://artifacts/rock-crevice/"+name+".png")
func _run():
	root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_size(Vector2i(1280,720))
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8);level.debug_enter_scene1()
	level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
	level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
	var x:float=S.Crevice.LEFT-42
	level.player.position=Vector2(x-13,S.ground_top(x)-54);level.player.velocity=Vector2.ZERO
	level.camera_x=level.player.position.x-480;level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	await frames(15);shot("aligned-01-standing-approach")
	Input.action_press("move_right")
	var middle:=false
	var entering:=false
	var bending:=false
	var emerging:=false
	var rising:=false
	for i in 1700:
		await frames(1)
		var low=level.scene1.low_stance
		if not bending and low.mode==low.Mode.ENTER and low.time>low.ENTER_TIME*.45:
			bending=true;shot("aligned-02-bending-in-mouth")
		if not emerging and level.player.position.x+13>S.Crevice.EXIT_MOUTH-20:
			emerging=true;shot("aligned-05-emerging")
		if not rising and level.player.position.x+13>S.Crevice.EXIT_MOUTH and low.mode==low.Mode.EXIT and low.time>low.EXIT_TIME*.45:
			rising=true;shot("aligned-06-rising-in-mouth")
		if not entering and level.player.position.x+13>S.Crevice.LEFT+45:
			entering=true;shot("aligned-03-entering")
		if not middle and level.player.position.x+13>S.Crevice.MIDDLE:
			middle=true;shot("aligned-04-interior")
		if level.player.position.x+13>S.Crevice.DUCK_RIGHT+180 and not level.scene1.low_stance.active():break
	Input.action_release("move_right");shot("aligned-07-outside")
	print("CAVE MOTION OK x=",level.player.position.x+13-S.START_X)
	quit()
