extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var output_dir := "res://artifacts/forest-root-v11/live-check"
	DirAccess.make_dir_recursive_absolute(output_dir)
	var main=load("res://scenes/main.tscn").instantiate()
	main.debug_start_level=5
	root.add_child(main)
	for i in 240:await physics_frame
	var level=main.river
	if level==null:
		push_error("Chapter entry did not mount")
		quit(1)
		return
	if "--left-boundary" in OS.get_cmdline_user_args():
		Input.action_press("move_left")
		for i in 420:await physics_frame
		Input.action_release("move_left")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_dir+"/left-edge.png")
		print("LEFT EDGE player=",level.player.position.x," camera=",level.camera_x," expected=",level.WORLD_MIN_X)
		if absf(level.camera_x-level.WORLD_MIN_X)>0.1 or absf(level.player.position.x-(level.WORLD_MIN_X+20.0))>0.1:
			push_error("Opening left boundary mismatch")
			quit(1)
			return
		quit()
		return
	Input.action_press("move_right")
	for i in 150:
		await physics_frame
		if i in [0,60,120]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output_dir+"/live-%03d.png"%i)
			print("LIVE ",i," player=",level.player.position," camera=",Vector2(level.camera_x,level.camera_y)," zoom=",level.camera.zoom," film_count=",get_nodes_in_group("film_look").size())
	Input.action_release("move_right")
	quit()
