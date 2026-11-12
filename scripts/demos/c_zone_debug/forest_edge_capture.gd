extends SceneTree
const SCENE=preload("res://scenes/debug/c_zone_river.tscn")
const Film=preload("res://scripts/effects/film_look.gd")
var level
func _initialize(): call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _run():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	Film.attach(level)
	await _frames(8)
	level.debug_enter_rope_ladder()
	level.scene1.cut=level.scene1.Cut.DONE
	level.scene1.intro_time=99
	DirAccess.make_dir_recursive_absolute("res://artifacts/rope-ladder/forest-edge")
	var index:=0
	for x in [-5200.0,-4900.0,-4600.0,-4300.0,-4050.0,-3540.0]:
		index+=1
		level.player.position=Vector2(x-13,level.scene1.ground_top(x)-54)
		level.player.velocity=Vector2.ZERO
		level.camera_x=x-525.0
		level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		await _frames(15)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://artifacts/rope-ladder/forest-edge/%02d.png"%index)
		print("EDGE CAPTURE ",index," camera=",Vector2(level.camera_x,level.camera_y)," forest=",level.art.forest_back.visible," valley=",level.log_bridge.art.back.visible)
	print("COMPLETE forest edge")
	quit(0)
