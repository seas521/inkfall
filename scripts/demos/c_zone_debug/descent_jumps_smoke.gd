extends "res://scripts/demos/c_zone_debug/descent_route_smoke.gd"

func _run():
	level=SCENE.instantiate()
	root.add_child(level)
	await _frames(4)
	route=level.post_bridge
	route.enter(1,true)
	route.collected=2
	route.harvest_height=200
	await _put(route.Layout.DESCENT[14]+Vector2(78,0))
	await _jump(1)
	_check(level.player.is_on_floor() and route.feet().y<route.Layout.DESCENT[14].y-40,"the optional overlook is reachable by a real jump")
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	_check(route.discovered,"optional route records its environmental discovery without locking main progression")
	for i in range(route.Layout.DESCENT.size()-1):
		route.active=true
		route.in_c_zone=false
		route.stage=1
		route.failure_time=0
		route.clock=1
		route.rock_clock=-100
		route.rocks.clear()
		route.fragile_age.clear()
		route._sync_mechanisms(0)
		var from:Node2D=route.ledges[i]
		var to:Node2D=route.ledges[i+1]
		var direction:float=signf(route.Layout.DESCENT[i+1].x-route.Layout.DESCENT[i].x)
		var start:Vector2=from.position+Vector2(route.Layout.ledge_width(i)-17 if direction>0 else 17,0)
		if i==0:start=Vector2(145,route.Layout.DESCENT[0].y)
		await _put(start)
		var deaths:int=route.deaths
		var move:String="move_right" if direction>0 else "move_left"
		Input.action_press(move)
		Input.action_press("jump")
		for frame in 85:
			await physics_frame
			var target_x:float=to.position.x+route.Layout.ledge_width(i+1)*0.5
			# Short gaps and the wide puzzle landing need an air brake, just
			# as a player would use; holding a direction blindly overshoots.
			if direction*(route.feet().x-target_x)> -18:Input.action_release(move)
			if frame>15 and level.player.is_on_floor():break
		Input.action_release(move)
		Input.action_release("jump")
		await _frames(3)
		var expected:Rect2=Rect2(to.position-Vector2(16,10),Vector2(route.Layout.ledge_width(i+1)+32,24))
		var landed:bool=level.player.is_on_floor() and expected.has_point(route.feet())
		if i==route.Layout.DESCENT.size()-2:
			Input.action_press("move_right")
			for frame in 60:
				await physics_frame
				if route.in_c_zone:break
			Input.action_release("move_right")
			landed=route.in_c_zone
		_check(landed and route.deaths==deaths,"real jump %02d → %02d lands safely (feet %s, target %s)"%[i,i+1,str(route.feet()),str(to.position)])
	print("descent jumps smoke OK" if failures==0 else "descent jumps smoke: %d FAILED"%failures)
	quit(0 if failures==0 else 1)
