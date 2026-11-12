extends SceneTree
const MAIN=preload("res://scenes/main.tscn")
var main
func _initialize():call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _snap(label:String):
	RenderingServer.force_draw()
	var shot:=root.get_texture().get_image()
	shot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	shot.save_png("res://artifacts/polyfork-station/reduced/"+label+".png")
func _run():
	DirAccess.make_dir_recursive_absolute("res://artifacts/polyfork-station")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main=MAIN.instantiate()
	root.add_child(main)
	await _frames(6)
	main._show_debug_selector()
	main.debug_selection=main.SCREE_DEBUG_INDEX
	main.queue_redraw()
	await _frames(4)
	_snap("00-debug-new-entries")
	main.debug_selection=main.STATION_DEBUG_INDEX
	main._start_debug_level()
	await _frames(12)
	_snap("08-playable-station")
	DisplayServer.window_set_title("Inkfall · 双路吊运站 · Polyfork 素材试用（Esc 返回 DEBUG）")
	print("POST BRIDGE ENTRY REVIEW COMPLETE; PLAY READY: station entry 9, scree entry 10; F+A/D mechanisms, Space jump, F on basket hold to descend, Esc DEBUG")
	if not OS.get_cmdline_user_args().has("--play"):quit(0)
