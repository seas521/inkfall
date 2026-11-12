extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var main=load("res://scenes/main.tscn").instantiate()
	main.debug_start_level=5
	root.add_child(main)
	for i in 240:await physics_frame
	var level=main.river
	if level==null:
		push_error("Chapter entry did not mount")
		quit(1)
		return
	Input.action_press("move_right")
	for i in 150:
		await physics_frame
		if i in [0,60,120]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/forest-opening-v5/live-check/live-%03d.png"%i)
			print("LIVE ",i," player=",level.player.position," camera=",Vector2(level.camera_x,level.camera_y)," zoom=",level.camera.zoom," film_count=",get_nodes_in_group("film_look").size())
	Input.action_release("move_right")
	level.process_mode=Node.PROCESS_MODE_DISABLED
	for entry in [["with-near",true,true],["without-near",false,true],["without-foreground",false,false]]:
		level.art.near_blur_sprite.visible=entry[1]
		level.art.fore_blur_sprite.visible=entry[2]
		for frame in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/forest-opening-v5/foreground-ab/"+entry[0]+".png")
	quit()
