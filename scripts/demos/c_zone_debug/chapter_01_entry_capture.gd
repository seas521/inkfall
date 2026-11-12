extends SceneTree

const MAIN=preload("res://scenes/main.tscn")
var main
func _initialize():call_deferred("_run")
func _frames(n:int):
	for i in n:
		await physics_frame
		await process_frame
func _capture(label:String):
	RenderingServer.force_draw()
	var shot:=root.get_texture().get_image()
	shot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	shot.save_png("res://artifacts/rope-ladder/chapter-entry/"+label+".png")
func _run():
	DirAccess.make_dir_recursive_absolute("res://artifacts/rope-ladder/chapter-entry")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main=MAIN.instantiate()
	root.add_child(main)
	await _frames(6)
	_capture("01-forest-start")
	main._show_debug_selector()
	main.debug_selection=main.CLIFF_ENTRY_DEBUG_INDEX
	main.queue_redraw()
	await _frames(3)
	_capture("02-debug-cliff-entry")
	main._start_debug_level()
	await _frames(6)
	_capture("03-cliff-start")
	DisplayServer.window_set_title("Inkfall · 悬崖衔接测试 · Esc 返回完整场景列表")
	print("CHAPTER ENTRY REVIEW COMPLETE; PLAY READY: cliff entry; Esc returns to DEBUG; complete chapter starts at forest get-up")
	if not OS.get_cmdline_user_args().has("--play"):quit(0)
