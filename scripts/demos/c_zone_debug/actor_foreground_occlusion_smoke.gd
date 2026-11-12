extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
var failures:=0
func _initialize():call_deferred("_run")
func frames(n:int):
	for i in n:await physics_frame;await process_frame
func check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func orange_pixels()->int:
	RenderingServer.force_draw()
	var frame:=root.get_texture().get_image()
	frame.resize(640,360,Image.INTERPOLATE_LANCZOS)
	var count:=0
	for y in 360:
		for x in 640:
			var c:=frame.get_pixel(x,y)
			if c.r>.18 and c.r>c.g*1.6 and c.g>c.b*1.6:count+=1
	return count
func _run():
	root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_size(Vector2i(1280,720))
	level=SCENE.instantiate();root.add_child(level)
	await frames(8);level.debug_enter_scene1()
	level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
	level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
	var x:float=S.START_X+420
	level.player.position=Vector2(x-13,S.ground_top(x)-54);level.player.velocity=Vector2.ZERO
	level.camera_x=level.player.position.x-500;level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	await frames(10);level.set_physics_process(false)
	var wall:=ColorRect.new();wall.color=Color(.003,.003,.003);wall.z_index=6
	wall.position=level.player.position+Vector2(-90,-70);wall.size=Vector2(200,185)
	level.add_child(wall)
	for stance in ["idle","low"]:
		wall.hide()
		level.scene1.low_stance.mode=level.scene1.low_stance.Mode.UP if stance=="idle" else level.scene1.low_stance.Mode.LOW
		for i in 18:level._present(1.0/60.0);await process_frame
		var before:=orange_pixels()
		wall.show();await process_frame;await process_frame
		var after:=orange_pixels()
		check(before>0,stance+" has one visible eye before foreground coverage")
		check(after==0,stance+" eye is completely occluded with its body, never above the rock")
		print("ORANGE ",stance," before=",before," after=",after)
	print("actor foreground occlusion smoke OK" if failures==0 else "actor foreground occlusion smoke FAILED")
	quit(0 if failures==0 else 1)
