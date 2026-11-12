extends "res://scripts/demos/c_zone_debug/rope_ladder_capture.gd"

func _run():
	var suffix:String="before" if OS.get_cmdline_user_args().has("--before") else "after"
	DirAccess.make_dir_recursive_absolute("res://artifacts/rope-ladder/exit-review/"+suffix)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	level=SCENE.instantiate()
	root.add_child(level)
	Film.attach(level)
	await _frames(8)
	level.debug_enter_rope_ladder()
	level.log_bridge.enter(false)
	level.set_physics_process(false)
	var ladder=level.rope_ladder
	ladder.source_origin=ladder.anchor()
	ladder._begin(ladder.Mode.EXIT,230)
	ladder._follow_source()
	ladder._present(1.0/60.0)
	var sheet:=Image.create(160*8,180*4,false,Image.FORMAT_RGBA8)
	sheet.fill(Color(0.25,0.25,0.25))
	for index in 32:
		level._physics_process(1.0/60.0)
		await process_frame
		RenderingServer.force_draw()
		var shot:=root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(1280,720,Image.INTERPOLATE_LANCZOS)
		shot.save_png("res://artifacts/rope-ladder/exit-review/"+suffix+"/%03d.png"%index)
		var eye:Vector2=level.actor.eye_light.get_global_transform_with_canvas().origin
		var region:=Rect2i(Vector2i(eye)-Vector2i(70,45),Vector2i(160,180))
		sheet.blit_rect(shot,region,Vector2i(index%8*160,index/8*180))
		print("EXIT REVIEW ",index," clip=",level.actor.current_clip," frame=",level.actor.current_frame_index," ghost=",level.actor.ghost.visible," alpha=",level.actor.ghost.modulate.a," scale=",level.actor.body.scale)
	sheet.save_png("res://artifacts/rope-ladder/exit-review/"+suffix+"-sheet.png")
	print("EXIT REVIEW COMPLETE ",suffix)
	quit(0)
