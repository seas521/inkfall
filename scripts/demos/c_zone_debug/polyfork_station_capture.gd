extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
var level
func _initialize():call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _snap(label:String):
	await _frames(3)
	RenderingServer.force_draw()
	var shot:=root.get_texture().get_image()
	shot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	shot.save_png("res://artifacts/polyfork-station/reduced/"+label+".png")
	print("POST BRIDGE CAPTURE ",label," feet=",level.post_bridge.feet())
func _run():
	DirAccess.make_dir_recursive_absolute("res://artifacts/polyfork-station/reduced")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	preload("res://scripts/effects/film_look.gd").attach(level)
	await _frames(6)
	if OS.get_cmdline_user_args().has("--scree"):level.enter_scree_test()
	else:level.enter_station_test()
	await _frames(8)
	await _snap("01-station-fork")
	if OS.get_cmdline_user_args().has("--play"):
		DisplayServer.window_set_title("Inkfall · 双路吊运站与落石栈道 · 玩法预览")
		print("PLAY READY: A/D move; Space jump; hold F + A/D to move mechanisms; F locks loaded seesaw; hold F on basket to descend; Esc DEBUG")
		return
	var route=level.post_bridge
	for item in [["02-upper",route.O+Vector2(770,0)],["03-basket",route.O+Vector2(920,280)],["04-merge",route.O+Vector2(1800,565)],["05-rock-puzzle",route.Layout.DESCENT[6]],["06-jump-run",route.Layout.DESCENT[14]],["07-cave-exit",route.Layout.DESCENT[-1]]]:
		route.enter(0 if item[1].y< -3100 else 1,false)
		level.player.position=item[1]-Vector2(13,54)
		level.player.velocity=Vector2.ZERO
		level.camera_x=level.player.position.x-525
		level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		await _snap(item[0])
	print("POST BRIDGE CAPTURE COMPLETE")
	quit(0)
