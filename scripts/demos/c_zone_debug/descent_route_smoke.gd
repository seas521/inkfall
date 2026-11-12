extends SceneTree
const SCENE=preload("res://scenes/chapters/chapter_01_route.tscn")
var level
var route
var failures:=0
func _initialize():call_deferred("_run")
func _frames(n:int):
	for i in n:await physics_frame
func _check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func _put(at:Vector2):
	route.failure_time=0
	route.interaction=""
	level.player.position=at-Vector2(13,54)
	level.player.velocity=Vector2.ZERO
	route.fall_y=at.y
	route.was_grounded=true
	await _frames(10)
func _jump(direction:float,max_frames:=80):
	Input.action_press("move_right" if direction>0 else "move_left")
	Input.action_press("jump")
	for i in max_frames:
		await physics_frame
		if i>15 and level.player.is_on_floor():break
	Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_release("move_left")
	await _frames(3)
func _run():
	level=SCENE.instantiate()
	root.add_child(level)
	await _frames(4)
	route=level.post_bridge
	route.enter(0,true)
	await _frames(10)
	_check(level.player.is_on_floor() and route.stage==0,"station begins on a real shared-world bank")
	_check(level.log_bridge.exit_open and level.log_bridge.exit_shoulder.collision_layer==0,"accepted bridge opens naturally into the new station")
	_check(level.camera.zoom==Vector2.ONE and level.actor.pose.visual_scale==0.90,"new rooms preserve actor and camera scale")
	Input.action_press("interact")
	await _frames(20)
	Input.action_press("move_right")
	for i in 250:
		await physics_frame
		if route.upper_travel>=200:break
	Input.action_release("move_right")
	Input.action_release("interact")
	await _frames(5)
	_check(route.upper_travel>=198 and route.upper_travel<210,"F and movement physically position the trolley")
	var held:Vector2=route.suspended.position
	await _frames(20)
	_check(route.suspended.position.distance_to(held)<0.01,"ratcheted trolley holds the board after the player leaves")
	# Each fixture starts at a specific obstacle; all traversal uses real
	# Space input, the common body and the authored platform colliders.
	await _put(route.O+Vector2(418,0))
	await _jump(1)
	_check(route._on(route.suspended,140),"a real jump reaches the positioned suspended board")
	await _put(route.suspended.position+Vector2(124,0))
	await _jump(1)
	_check(route.feet().x>route.O.x+720 and level.player.is_on_floor(),"second jump reaches the upper landing")
	await _put(route.seesaw.position+Vector2(-110,0).rotated(route.seesaw_angle))
	await _frames(130)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	_check(route.seesaw_locked and route.seesaw_angle< -0.23,"standing on the left loads the see-saw and F engages its bearing pawl")
	await _put(route.seesaw.position+Vector2(135,0).rotated(route.seesaw_angle))
	await _jump(1)
	_check(route.feet().x>route.O.x+1230 and level.player.is_on_floor(),"locked loaded geometry makes the upper exit jump possible")
	# A fresh lower route has no upper mechanism solved.
	level.reset_all()
	route.enter(0,true)
	await _put(route.O+Vector2(812,280))
	Input.action_press("interact")
	await _frames(20)
	Input.action_press("move_right")
	for i in 230:
		await physics_frame
		if route.basket_y<=281:break
	Input.action_release("move_right")
	Input.action_release("interact")
	await _frames(4)
	_check(route.basket_y<=281 and route.upper_travel==0 and not route.seesaw_locked,"counterweight brings basket to boarding height without doing the upper route")
	await _put(route.basket.position+Vector2(120,0))
	Input.action_press("interact")
	await _frames(185)
	Input.action_release("interact")
	await _frames(4)
	_check(absf(route.basket_y-420)<0.1 and route.bar_travel==0,"dead-man brake descends, then the actual obstruction stops the basket")
	_check(absf(route.feet().y-(route.O.y+420))<8,"the platform physically carries its passenger")
	await _put(route.O+Vector2(1142,420))
	Input.action_press("interact")
	await _frames(20)
	Input.action_press("move_left")
	for i in 100:
		await physics_frame
		if route.bar_travel>=56:break
	Input.action_release("move_left")
	Input.action_release("interact")
	_check(route.bar_travel>=56,"pulling the bearing obstruction clears the guide at the side landing")
	await _put(route.basket.position+Vector2(110,0))
	Input.action_press("interact")
	await _frames(180)
	Input.action_release("interact")
	_check(absf(route.basket_y-565)<0.1,"cleared basket continues to the common lower exit")
	await _put(route.basket.position+Vector2(154,0))
	await _jump(1)
	_check(route.feet().x>route.O.x+1700 and level.player.is_on_floor(),"lower route independently jumps onto the common exit")
	route.enter(1,true)
	await _put(route.Layout.DESCENT[6]+Vector2(50,0))
	var camera_target:float=level._camera_target_y()
	_check(camera_target< -2500,"vertical follow also works east of the old debug coordinate boundary")
	Input.action_press("interact")
	await _frames(20)
	Input.action_press("move_right")
	await _frames(85)
	Input.action_release("move_right")
	Input.action_release("interact")
	_check(route.deflector>0.95,"the player rotates the physical rock deflector through F and movement")
	for i in 900:
		await physics_frame
		if route.collected>=2 and route.harvest_height>199:break
	_check(route.collected==2 and route.harvest_height>199,"real falling rocks enter the counterweight basket and lower the route in two stages")
	var solved:float=route.harvest_height
	route.restore_checkpoint()
	await _frames(6)
	_check(route.collected==2 and route.harvest_height>=solved-0.01,"nearby retry preserves the solved rock mechanism")
	_check(route.Layout.FRAGILE.size()>=4 and route.Layout.SWAYING.size()>=3,"later jump runs mix crumbling and moving supports")
	# Continuous C entrance: no scene replacement, no camera snap or zoom.
	var actor_id:int=level.actor.get_instance_id()
	await _put(Vector2(36,387))
	await _frames(6)
	_check(route.in_c_zone and not route.active and level.actor.get_instance_id()==actor_id,"cave exit hands the same actor into the original C zone")
	print("descent route smoke OK" if failures==0 else "descent route smoke: %d FAILED"%failures)
	quit(0 if failures==0 else 1)
