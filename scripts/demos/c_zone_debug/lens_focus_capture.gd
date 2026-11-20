extends SceneTree

const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
const DIR="res://artifacts/forest-lens-v5/review"

func _initialize()->void:call_deferred("run")

func frames(count:int)->void:
	for i in count:await physics_frame

func snap(name:String)->void:
	await frames(5)
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	image.save_png(DIR+"/"+name+".png")
	print("CAPTURE ",name," player=",level.player.position," camera=",Vector2(level.camera_x,level.camera_y))

func run()->void:
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_size(Vector2i(1280,720))
	DirAccess.make_dir_recursive_absolute(DIR)
	level=SCENE.instantiate()
	root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(8)
	level.debug_enter_scene1()
	level.scene1.predator.enabled=false
	level.scene1.spider.enabled=false
	level.scene1.intro_time=99.0
	level.scene1.cut=S.Cut.NONE
	level.set_physics_process(false)
	for stop in [Vector2(S.START_X+1050,1),Vector2(S.START_X+2800,3),Vector2(S.CLIFF_X-220,6)]:
		var x:float=stop.x
		level.player.position=Vector2(x-13,S.ground_top(x)-54)
		level.player.velocity=Vector2.ZERO
		level.camera_x=x-525
		level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		level._present(0)
		await snap("forest-%02d"%int(stop.y))
	level.set_physics_process(true)
	level.debug_enter_rope_ladder(false)
	await frames(20)
	await snap("ladder-top")
	Input.action_press("climb_down")
	await frames(140)
	await snap("ladder-middle")
	Input.action_release("climb_down")
	level.debug_enter_marsh_act()
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	level._present(0)
	await snap("c-zone")
	quit()
