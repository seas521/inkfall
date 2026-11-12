extends SceneTree

# Native moving-camera regression: compare identical terrain before/after and
# measure grass command generation separately from the rest of the scene.
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
var level
var calls:Dictionary={"tufts":0,"band":0}
var cost:Dictionary={"tufts":0,"band":0}
func _initialize():call_deferred("_run")
func _wrap(node:Node2D,key:String):
	for connection in node.get_signal_connection_list("draw"):
		var original:Callable=connection.callable
		node.draw.disconnect(original)
		node.draw.connect(func():
			var start:=Time.get_ticks_usec()
			original.call()
			cost[key]+=Time.get_ticks_usec()-start
			calls[key]+=1)
func _run():
	if OS.get_cmdline_user_args().has("--play"):
		await _play()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	await process_frame
	level.debug_enter_scene1()
	level.set_physics_process(false)
	level.scene1.intro_time=99.0
	_wrap(level.art.grass_art,"tufts")
	_wrap(level.art.grass_band,"band")
	var tag:="after" if OS.get_cmdline_user_args().has("--after") else "before"
	DirAccess.make_dir_recursive_absolute("res://artifacts/forest-grass")
	for i in 181:
		level.camera_x=-8900.0+float(i)*12.0
		level.camera_y=-4855.0
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		level.player.position=Vector2(level.camera_x+520,level.scene1.ground_top(level.camera_x+533)-54)
		level._present(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if i in [0,90,180]:
			var shot:=root.get_texture().get_image()
			shot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
			shot.save_png("res://artifacts/forest-grass/%s-%03d.png"%[tag,i])
	print("GRASS PROFILE ",tag," calls=",calls," generation_usec=",cost)
	if tag=="after":
		assert(calls.tufts==0 and calls.band==0,"camera motion must not regenerate grass")
		for x in [-6500.0,-5600.0,-4900.0,-4100.0,-8500.0]:
			level.camera_x=x
			level.camera.position.x=x+640
			level._present(0.0)
			await process_frame
			await RenderingServer.frame_post_draw
		assert(calls.tufts==0 and calls.band==0,"new regions and backtracking must reuse prepared geometry")
		var original_edge:float=level.art._grass_cached_edge
		# A broken cliff changes valid ground and must invalidate both caches.
		level.scene1.break_edge(level.scene1.CLIFF_X-120)
		level._present(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(level.art._grass_cached_edge<original_edge)
		assert(calls.tufts==1 and calls.band==1,"cliff changes must rebuild grass")
		print("GRASS CACHE REGRESSION OK: camera scroll cached; broken edge rebuilt")
	quit(0)

func _play():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 6:await process_frame
	main._show_debug_selector()
	main.debug_selection=main.SCENE1_DEBUG_INDEX
	main._start_debug_level()
	for i in 6:await process_frame
	DisplayServer.window_set_title("Inkfall · 森林草皮缓存修复 · Esc 返回 DEBUG")
	print("FOREST GRASS PLAY READY")
