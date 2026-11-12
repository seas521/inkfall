extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
func _initialize():call_deferred("run")
func frames(n:int):
	for i in n:await physics_frame;await process_frame
func shot(name:String):
	RenderingServer.force_draw()
	var im:=root.get_texture().get_image();im.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	im.save_png("res://artifacts/under-log/"+name+".png")
func run():
	root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_size(Vector2i(1280,720))
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8);level.debug_enter_scene1();level.scene1.predator.enabled=false
	level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
	var L=S.Crevice;var x:float=L.LEFT-120
	level.player.position=Vector2(x-13,S.ground_top(x)-54);level.player.velocity=Vector2.ZERO
	var sp=level.scene1.spider
	sp.enabled=false;sp.retry_armed=true;sp.state=sp.State.CHASE
	sp.position=Vector2(L.LEFT-500,S.ground_top(L.LEFT-500));sp.last_motion_x=x
	level.camera_x=L.LEFT-390;level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	DisplayServer.window_set_title("Inkfall · 倒木树下藏身")
	DirAccess.make_dir_recursive_absolute("res://artifacts/under-log")
	await frames(12);shot("01-approach")
	if OS.get_cmdline_user_args().has("--play"):return
	Input.action_press("climb_down");await frames(65)
	Input.action_press("move_right")
	for i in 250:
		await frames(1)
		if level.player.position.x+13>L.LEFT+110:break
	sp.enabled=true;sp.log_hunt=true;sp.heard_x=level.player.position.x+13
	sp.position=Vector2(L.LEFT-85,sp.log_surface(L.LEFT-85));sp.last_motion_x=sp.heard_x
	sp._begin(sp.State.SEARCH)
	shot("02-search")
	await frames(60);shot("03-striking")
	Input.action_release("move_right");Input.action_release("climb_down")
	await frames(120);shot("04-still")
	await frames(140);shot("05-retreat")
	print("UNDER LOG CAPTURE x=",level.player.position.x+13-L.LEFT," state=",sp.state)
	quit()
