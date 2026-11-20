extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
var level
var route
var failures:=0
func _initialize():call_deferred("run")
func frames(n:int):
	for i in n:await physics_frame
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures+=1
func place(i:int,edge:=0.0):
	route.active=true
	route.in_c_zone=false
	route.failure_time=0
	route.clock=3.3-float(i+1)*0.73
	route.age.clear()
	for body in route.platforms:body.collision_layer=1
	level.player.position=route.landing(i)+Vector2(edge-13,-55)
	level.player.velocity=Vector2.ZERO
	route.fall_y=route.feet().y
	route.last_landing=i
	route.was_grounded=true
	level.jump_buffer=0
	level.jump_windup_left=0
	await frames(5)
func run():
	level=SCENE.instantiate()
	root.add_child(level)
	await frames(3)
	route=level.bridge_to_c
	level.log_bridge.reached_bank=true
	level.log_bridge.state=level.log_bridge.State.BRIDGED
	level.log_bridge.angle=level.log_bridge.END_ANGLE
	level.log_bridge.log_body.transform=Transform2D(level.log_bridge.angle,level.log_bridge.PIVOT)
	level.log_bridge.left_bank_reached=true
	# Earned bank enters physically without replacing actor or camera.
	var actor_id:int=level.actor.get_instance_id()
	var before:=Vector2(-2335,-3770)
	level.player.position=before
	route.active=false
	route.tick(1.0/60.0)
	check(route.active and level.player.position.distance_to(before)<3.0,"bridge enters descent without coordinate swap")
	check(level.actor.get_instance_id()==actor_id,"descent retains the same actor")
	route.enter(true)
	if OS.get_cmdline_user_args().has("--capture"):
		preload("res://scripts/effects/film_look.gd").attach(level)
		root.content_scale_size=Vector2i(1280,720)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		DisplayServer.window_set_size(Vector2i(1280,720))
		DirAccess.make_dir_recursive_absolute("res://artifacts/post-bridge/root-cliff-review")
		for i in [0,5,12,20,28,36,40]:
			await place(i)
			level.camera_x=level.player.position.x-525
			level.camera_y=route.camera_target_y()
			level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
			await frames(4)
			await process_frame
			RenderingServer.force_draw()
			var capture:=root.get_texture().get_image()
			capture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
			capture.save_png("res://artifacts/post-bridge/root-cliff-review/%02d.png"%i)
		await place(8,30)
		route.clock=0.5-8*0.73
		level.camera_x=level.player.position.x-525
		level.camera_y=route.camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		for frame in 150:
			await physics_frame
			if frame in [12,55,130]:
				await process_frame
				RenderingServer.force_draw()
				var motion:=root.get_texture().get_image()
				motion.resize(1280,720,Image.INTERPOLATE_LANCZOS)
				motion.save_png("res://artifacts/post-bridge/root-cliff-review/vent-%03d.png"%frame)
		quit()
		return
	# A missed landing is lethal rather than a free shortcut to the valley.
	await place(0)
	var old_deaths:int=route.deaths
	level.player.position=route.landing(10)-Vector2(13,400)
	route.fall_y=route.feet().y
	route.was_grounded=false
	for f in 75:
		await physics_frame
		if route.deaths>old_deaths:break
	check(route.deaths>old_deaths,"large skipped descent is lethal")
	# Geometry and landing safety use real player input; wait for safe vent phase.
	for i in range(route.X.size()-1):
		var direction:float=signf(route.landing(i+1).x-route.landing(i).x)
		await place(i,direction*(route.width(i)*0.5-18))
		route.clock=3.3-float(37 if i==38 else i+1)*0.73
		var deaths:int=route.deaths
		Input.action_press("move_right" if direction>0 else "move_left")
		Input.action_press("jump")
		for f in 90:
			await physics_frame
			if direction*(route.feet().x-route.landing(i+1).x)>-18:
				Input.action_release("move_left")
				Input.action_release("move_right")
			if f>15 and level.player.is_on_floor():break
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("jump")
		check(route.deaths==deaths and absf(route.feet().y-route.landing(i+1).y)<8,"jump %d -> %d feet=%s"%[i,i+1,str(route.feet())])
	await place(4)
	await frames(65)
	check(route.platforms[4].collision_layer==0,"loaded rotten root breaks")
	route.checkpoint_index=20
	route.restore_checkpoint()
	check(route.platforms[4].collision_layer==1 and absf(route.feet().y-route.landing(20).y)<3,"recovery restores roots at earned checkpoint")
	await place(8,-route.width(8)*0.5+26)
	route.clock=1.2-8*0.73
	await frames(2)
	check(route.failure_time>0,"active fissure hurts only inside its plume")
	await place(40,60)
	Input.action_press("move_right")
	await frames(90)
	Input.action_release("move_right")
	check(route.in_c_zone and level.checkpoint==0,"physical final landing enters C")
	check(level.crate.position.distance_to(level.CRATE_START)<10,"C boat restored at near bank")
	level.reset_all()
	level.enter_station_test()
	check(not route.enabled and level.post_bridge.active,"standalone station kept separate")
	print("ROOT CLIFF REVIEW failures=",failures)
	quit(1 if failures else 0)
