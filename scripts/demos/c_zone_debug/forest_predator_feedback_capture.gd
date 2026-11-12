extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
var p
func _initialize():call_deferred("_run")
func frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func snap(label:String):
	level.set_physics_process(false)
	await process_frame
	RenderingServer.force_draw()
	var shot:=root.get_texture().get_image()
	shot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	shot.save_png("res://artifacts/forest-predator/"+label+".png")
	print("PREDATOR FEEDBACK ",label," state=",p.flower," bait=",p.bait," timer=",p.time)
	level.set_physics_process(true)
func put(offset:float):
	var x:float=S.START_X+offset
	level.player.position=Vector2(x-13,S.ground_top(x)-56)
	level.player.velocity=Vector2.ZERO
	level.scene1.intro_time=99
	level.camera_x=x-525
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
func _run():
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest-predator")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate();root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await frames(6)
	p=level.scene1.predator
	if level.scene1.hunter!=null:level.scene1.hunter.enabled=false
	put(2290);await frames(8)
	Input.action_press("interact");await frames(2);Input.action_release("interact")
	await frames(58);await snap("04-held-carcass")
	Input.action_press("move_left");await frames(14);Input.action_release("move_left")
	await snap("04b-held-turn-left")
	Input.action_press("move_right");await frames(14);Input.action_release("move_right")
	await snap("04c-held-turn-right")
	level.facing=1
	Input.action_press("interact");await frames(2);Input.action_release("interact")
	await frames(16);await snap("05-ballistic-bait")
	for i in 100:
		await frames(1)
		if p.flower==p.Flower.BAIT_SNAP:break
	await frames(14);await snap("06-jaws-swallowing")
	await frames(11);await snap("06b-wet-bite")
	await frames(45);await snap("07-feeding-window")
	level.debug_enter_scene1();put(2330);await frames(2)
	Input.action_press("move_right")
	for i in 100:
		await frames(1)
		if p.captured():break
	Input.action_release("move_right")
	await frames(12);await snap("08-player-captured")
	await frames(20);await snap("09-player-swallowed")
	await frames(100);await snap("10-nearby-retry")
	quit()
