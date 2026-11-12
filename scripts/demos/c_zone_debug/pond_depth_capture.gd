extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
func _initialize():call_deferred("_run")
func frames(n:int):
	for i in n:await physics_frame;await process_frame
func shot(name:String):
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://artifacts/forest-grass/"+name+".png")
func _run():
	root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_size(Vector2i(1280,720))
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8);level.debug_enter_scene1()
	level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
	level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
	var x:float=S.START_X+2800
	level.player.position=Vector2(x-13,S.ground_top(x)-54);level.player.velocity=Vector2.ZERO
	level.camera_x=level.player.position.x-520;level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	await frames(25);shot("pond-still")
	Input.action_press("move_right");await frames(70);Input.action_release("move_right")
	shot("pond-wading")
	print("POND visible=",level.scene1.pools[0].visible," wet=",level.scene1.pools[0].inside," energy=",level.scene1.pools[0].energy)
	quit()
