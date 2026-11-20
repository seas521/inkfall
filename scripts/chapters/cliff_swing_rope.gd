extends Node2D

const Frames=preload("res://scripts/actors/rope_swing_manifest.gd")
const UpFrames=preload("res://scripts/actors/rope_climb_up_manifest.gd")
const ClimbFrames=preload("res://scripts/actors/rope_climb_manifest.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const DISPLAY:=0.42*Pose.HOOD_VISUAL_SCALE
# The up-take was filmed with a larger body than the down-take. Normalize
# its full silhouette and hand-to-feet tracking together, never the camera.
const UP_BODY_SCALE:=0.82
const LENGTH:=340.0
const MIN_GRIP:=110.0
const CLIMB_SPEED:=62.0
var grip:=MIN_GRIP
var climb_pose:=true
var climb_phase:=0.0
var climbing_up:=false
const FIBER_COUNT:=40
const GRAVITY:=850.0
var fibers:=PackedVector2Array()
var fiber_previous:=PackedVector2Array()
const GRAB_RADIUS:=34.0
var grab_intent:=0.0
enum State { FREE, REACH, CATCH, HANG, RELEASE }
var route
var state:=State.FREE
var angle:=0.0
var omega:=0.0
var frame:=61.0
var phase:=0.0
var age:=0.0
var cooldown:=0.0
var catch_origin:=Vector2.ZERO
var shown_hand:=Vector2.ZERO
var release_rotation:=0.0
var reach_velocity:=Vector2.ZERO
var catches:=0
var releases:=0
var hand_error:=0.0
var fiber_motion:=0.0
var fiber_velocity:=0.0
const LINKS:=20
var rope_points:=PackedVector2Array()
var rope_previous:=PackedVector2Array()
var tail_points:=PackedVector2Array()
var tail_previous:=PackedVector2Array()
var last_rope_tip:=Vector2.ZERO
var previous_body:=Vector2.ZERO
var body_history:=false
var contact_impulses:=0

# Fixed material nodes: climbing moves the grip constraint, never stretches the rope
# or creates/deletes a tail. A reduced pendulum drives the loaded hand; the free
# strand retains Verlet inertia. After release only the top knot remains pinned.
func _sample_fiber(distance:float)->Vector2:
	if fibers.is_empty():return anchor()+Vector2(0,distance)
	var u:=clampf(distance/(LENGTH+28.0)*FIBER_COUNT,0,FIBER_COUNT)
	var i:=mini(int(u),FIBER_COUNT-1)
	return fibers[i].lerp(fibers[i+1],u-i)

func _pin_grip(target:Vector2)->void:
	var u:=grip/(LENGTH+28.0)*FIBER_COUNT
	var i:=mini(int(u),FIBER_COUNT-1)
	var t:=u-i
	var error:=target-fibers[i].lerp(fibers[i+1],t)
	var denominator:float=(1.0-t)*(1.0-t)+t*t
	fibers[i]+=error*(1.0-t)/denominator
	fibers[i+1]+=error*t/denominator

func _touch_free_rope(delta:float)->void:
	var center:Vector2=route.feet()+Vector2(0,-30)
	if not body_history:
		previous_body=center
		body_history=true
	var displacement:=center-previous_body
	if displacement.length()<90 and displacement.length()>0.2:
		for i in range(1,fibers.size()):
			var closest:=Geometry2D.get_closest_point_to_segment(fibers[i],previous_body,center)
			if absf(fibers[i].x-closest.x)<15 and absf(fibers[i].y-closest.y)<32:
				var impulse:=displacement.limit_length(6.0)*0.4
				fiber_previous[i]-=impulse
				contact_impulses+=1
	previous_body=center

func _step_fibers(delta:float)->void:
	var a:=anchor()
	if fibers.is_empty():
		for i in FIBER_COUNT+1:fibers.append(a+Vector2(0,(LENGTH+28.0)*i/FIBER_COUNT))
		fiber_previous=fibers.duplicate()
	var loaded:=state==State.CATCH or state==State.HANG
	if not loaded:_touch_free_rope(delta)
	else:body_history=false
	var substeps:=maxi(1,ceili(delta/(1.0/120.0)))
	var dt:=delta/substeps
	var segment:float=(LENGTH+28.0)/FIBER_COUNT
	for substep in substeps:
		for i in range(1,FIBER_COUNT+1):
			var old:=fibers[i]
			var wind:=5.0*sin(route.clock*0.82+i*0.09)+2.0*sin(route.clock*1.37)
			fibers[i]+=(fibers[i]-fiber_previous[i])*exp(-1.2*dt)+Vector2(wind,GRAVITY)*dt*dt
			fiber_previous[i]=old
		for iteration in 48:
			fibers[0]=a
			for j in FIBER_COUNT:
				var diff:=fibers[j+1]-fibers[j]
				var correction:=diff*(1.0-segment/maxf(diff.length(),0.0001))
				if j==0:fibers[j+1]-=correction
				else:
					fibers[j]+=correction*0.5
					fibers[j+1]-=correction*0.5
			if loaded:_pin_grip(shown_hand if state==State.CATCH else hand())
		fibers[0]=a
		if loaded:
			var target:=shown_hand if state==State.CATCH else hand()
			for i in range(1,int(grip/segment)):
				var equilibrium:=a.lerp(target,i*segment/grip)
				var correction:Vector2=(equilibrium-fibers[i])*(1.0-exp(-24.0*dt))
				fibers[i]+=correction
				fiber_previous[i]+=correction
	rope_points.clear()
	tail_points.clear()
	for i in LINKS+1:rope_points.append(_sample_fiber(grip*i/LINKS))
	for i in 9:tail_points.append(_sample_fiber(grip+(LENGTH+28.0-grip)*i/8.0))
	last_rope_tip=fibers[-1]

func _smooth_rope(raw:PackedVector2Array)->PackedVector2Array:
	var result:=PackedVector2Array()
	for i in range(raw.size()-1):
		for j in 3:
			result.append(raw[i].cubic_interpolate(raw[i+1],raw[maxi(0,i-1)],raw[mini(raw.size()-1,i+2)],float(j)/3))
	result.append(raw[-1])
	return result

func anchor()->Vector2:
	# Knot sits on the upper-left bough of the FIRST rooted tree, not in midair.
	return route.trees[0].global_position+(Vector2(302,180)-route.trees[0].pivot)*route.trees[0].size_factor

func hand()->Vector2:
	if state==State.FREE or state==State.REACH or state==State.RELEASE:return _sample_fiber(grip)
	return anchor()+Vector2(sin(angle),cos(angle))*grip*0.998

func _nearest_grip(hands:Vector2)->Vector2:
	# Search the visible strand, not the single previous/minimum grip point.
	var best:=Vector2(INF,MIN_GRIP)
	var a:=_sample_fiber(MIN_GRIP)
	for i in 24:
		var d0:=lerpf(MIN_GRIP,LENGTH,float(i)/24.0)
		var d1:=lerpf(MIN_GRIP,LENGTH,float(i+1)/24.0)
		var b:=_sample_fiber(d1)
		var segment:=b-a
		var t:=clampf((hands-a).dot(segment)/maxf(segment.length_squared(),0.001),0,1)
		var point:=a.lerp(b,t)
		var distance:=hands.distance_to(point)
		if distance<best.x:best=Vector2(distance,lerpf(d0,d1,t))
		a=b
	return best

func tail_link()->float:return (LENGTH+28.0-grip)/8.0

func track(key:String,at:float)->Vector2:
	var data:Dictionary=(UpFrames.DATA if climbing_up else ClimbFrames.DATA) if climb_pose else Frames.DATA
	var end:int=int(data.frames)-1
	var a:int=clampi(int(at),0,end)
	var b:int=mini(a+1,end)
	var p:Array=data.tracks[a][key]
	var q:Array=data.tracks[b][key]
	return Vector2(p[0],p[1]).lerp(Vector2(q[0],q[1]),at-a)*DISPLAY*(UP_BODY_SCALE if climb_pose and climbing_up else 1.0)

func source_angle(at:float)->float:
	if climb_pose:return 0.0
	var a:int=clampi(int(at),0,240)
	return lerpf(float(Frames.DATA.tracks[a].angle),float(Frames.DATA.tracks[mini(a+1,240)].angle),at-a)

func presenting()->bool:return state!=State.FREE

func reset()->void:
	state=State.FREE
	grip=MIN_GRIP
	climb_pose=true
	climb_phase=0
	climbing_up=false
	body_history=false
	fibers.clear()
	fiber_previous.clear()
	rope_points.clear()
	rope_previous.clear()
	tail_points.clear()
	tail_previous.clear()
	angle=0
	omega=0
	age=0
	cooldown=0.25
	grab_intent=0.0
	if route!=null:
		route.level.actor.rotation=0
		route.level.player.collision_mask=route.PLAYER_COLLISION_MASK
	queue_redraw()

func tick(delta:float)->bool:
	cooldown=maxf(0,cooldown-delta)
	grab_intent=maxf(0,grab_intent-delta)
	if Input.is_action_just_pressed("jump"):grab_intent=0.45
	var level=route.level
	var direction:float=Input.get_axis("move_left","move_right")
	var fiber_target:float=clampf(-omega*1.8,-4.5,4.5)
	fiber_velocity+=((fiber_target-fiber_motion)*30.0-fiber_velocity*6.0)*delta
	fiber_motion+=fiber_velocity*delta
	queue_redraw()
	if state==State.FREE:
		grip=move_toward(grip,MIN_GRIP,delta*90.0)
		var wind:=0.12*sin(route.clock*0.82)+0.045*sin(route.clock*1.37+0.8)
		omega+=(-850.0/grip*sin(angle)-omega*3.2+wind)*delta
		angle+=omega*delta
		var hands:Vector2=route.feet()+Vector2(-7,-61)
		var nearest:=_nearest_grip(hands)
		if cooldown<=0 and not level.player.is_on_floor() and (grab_intent>0 or Input.is_action_pressed("jump")) and nearest.x<GRAB_RADIUS+12.0:
			grip=nearest.y
			state=State.REACH
			climbing_up=false
			climb_pose=true
			frame=18
			age=0
			# Preserve the existing rope angle: catching must not teleport the endpoint.
			omega=clampf(level.player.velocity.dot(Vector2(cos(angle),-sin(angle)))/grip*0.12,-0.25,0.25)
			catch_origin=route.feet()-track("feet_local",floorf(frame)).rotated(source_angle(floorf(frame))-angle)
			shown_hand=catch_origin
			reach_velocity=level.player.velocity
			level.player.collision_mask=route.PLAYER_COLLISION_MASK
			level.climb_time=-1
			level.jump_buffer=0
			level.jump_windup_left=0
			level.scene1.low_stance.reset()
			level.actor.load_group("rope_swing")
			level.actor.begin_rope_ladder()

		_step_fibers(delta)
		queue_redraw()
		return false if state==State.FREE else true
	age+=delta
	if state==State.REACH:
		frame=minf(23,18+age*24)
		level.player.velocity.y+=1500*delta
		level.player.move_and_slide()
		var reach_hand:Vector2=route.feet()+Vector2(-7,-61)
		if reach_hand.distance_to(hand())<GRAB_RADIUS+22.0:
			var contact:=hand()-anchor()
			angle=atan2(contact.x,contact.y)
			state=State.CATCH
			age=0
			frame=24
			catch_origin=route.feet()-track("feet_local",24).rotated(-angle)
			shown_hand=catch_origin
			reach_velocity=level.player.velocity.limit_length(130)
			level.player.collision_mask=0
			catches+=1
		elif age>0.30 or level.player.is_on_floor():
			state=State.FREE
			cooldown=0.25
		_step_fibers(delta)
		return presenting()
	if state==State.RELEASE:
		var wind:=0.12*sin(route.clock*0.82)+0.045*sin(route.clock*1.37+0.8)
		omega+=(-850.0/grip*sin(angle)-omega*3.2+wind)*delta
		angle+=omega*delta
		frame=minf(216,frame+delta*24)
		level.player.velocity.y=minf(850,level.player.velocity.y+1500*delta)
		level.player.move_and_slide()
		route.fall_origin=minf(route.fall_origin,route.feet().y)
		if level.player.is_on_floor() or frame>=216:
			state=State.FREE
			cooldown=0.65
			level.actor.rotation=0
			# Let the normal controller own landing and fall damage, including this contact.
			if level.player.is_on_floor() and route.feet().y-route.fall_origin>level.LETHAL_FALL:route.fail()
			route.was_grounded=false
		_step_fibers(delta)
		return state!=State.FREE
	var climb_input:=float(Input.is_action_pressed("climb_down"))-float(Input.is_action_pressed("climb_up"))
	if state==State.HANG:
		# A loaded rope conserves angular momentum as the grip radius changes.
		var previous_grip:=grip
		grip=clampf(grip+climb_input*CLIMB_SPEED*delta,MIN_GRIP,LENGTH)
		omega*=pow(previous_grip/grip,2.0)
		if absf(climb_input)>0.1:
			var wants_up:=climb_input<0
			if not climb_pose or wants_up!=climbing_up:climb_phase=0.0
			climb_pose=true
			climbing_up=wants_up
			climb_phase+=absf(grip-previous_grip)/CLIMB_SPEED
			frame=(14.0+fmod(climb_phase*24.0,71.0)) if climbing_up else (42.0+fmod(climb_phase*24.0,52.0))
		elif absf(direction)>0.1 and climb_pose:
			climb_pose=false
			frame=73
	var previous_angle:=angle
	var limit_force:float=-signf(angle)*maxf(0,absf(angle)-0.48)*50.0
	omega+=(-850.0/grip*sin(angle)-omega*1.1+(direction*3.2 if state==State.HANG and absf(climb_input)<0.1 else 0.0)+limit_force)*delta
	angle+=omega*delta
	if state==State.CATCH:
		frame=minf(42,frame+delta*24)
		if frame>=42:
			state=State.HANG
			age=0
	elif not climb_pose:
		var target_frame:float=lerpf(94.0,157.0,clampf(-angle/0.48,0,1))
		if absf(omega)<0.12 and absf(direction)<0.1:target_frame=73.0
		frame=move_toward(frame,target_frame,delta*24.0)
	var rotation_value:=source_angle(floorf(frame))-angle
	shown_hand=hand()
	if state==State.CATCH:
		var t:=clampf(age/0.25,0,1)
		shown_hand=catch_origin*(2*t*t*t-3*t*t+1)+reach_velocity*0.25*(t*t*t-2*t*t+t)+hand()*(-2*t*t*t+3*t*t)
	var feet:Vector2=shown_hand+track("feet_local",floorf(frame)).rotated(rotation_value)
	if state==State.HANG and absf(climb_input)<0.1 and absf(omega)>0.1:
		level.player.collision_mask=route.PLAYER_COLLISION_MASK
		var blocked:bool=level.player.test_move(level.player.global_transform,feet-Vector2(13,54)-level.player.position)
		level.player.collision_mask=0
		if blocked:
			angle=previous_angle
			omega*=-0.12
			shown_hand=hand()
			feet=shown_hand+track("feet_local",floorf(frame)).rotated(source_angle(floorf(frame))-angle)
	level.player.position=feet-Vector2(13,54)
	level.player.velocity=Vector2.ZERO
	route.fall_origin=feet.y
	if state==State.HANG and age>0.12 and Input.is_action_just_pressed("jump"):
		state=State.RELEASE
		climb_pose=false
		age=0
		frame=201
		release_rotation=source_angle(floorf(frame))-angle
		var radial:=feet-anchor()
		level.player.velocity=Vector2(radial.y,-radial.x)*omega
		level.player.velocity.x=clampf(level.player.velocity.x,-310,310)
		level.player.velocity.y=clampf(level.player.velocity.y,-220,300)
		level.player.collision_mask=route.PLAYER_COLLISION_MASK
		releases+=1
	_step_fibers(delta)
	queue_redraw()
	return true

func present(delta:float)->void:
	var level=route.level
	var rotation_value:=source_angle(floorf(frame))-angle
	var root:=shown_hand
	if state==State.REACH:
		rotation_value=0
		root=route.feet()-track("feet_local",floorf(frame))
	if state==State.RELEASE:
		rotation_value=lerpf(release_rotation,0,smoothstep(0,0.5,age))
		root=route.feet()-track("feet_local",floorf(frame)).rotated(rotation_value)
	var pose:=Pose.new()
	pose.apply({"feet":root,"grounded":false,"velocity":Vector2.ZERO,"facing":-1,"action":(&"rope_climb_up" if climbing_up else &"rope_climb") if climb_pose else &"rope_swing","action_progress":frame/(120.0 if climb_pose else 240.0),"visual_scale":Pose.HOOD_VISUAL_SCALE*(UP_BODY_SCALE if climb_pose and climbing_up else 1.0),"fog_blur":level.ACTOR_EDGE_SOFTNESS})
	level.actor.sync_pose(delta,pose)
	level.actor.body_offset=Vector2.ZERO
	level.actor.body.position=Vector2.ZERO
	level.actor.rotation=rotation_value
	level.actor.ghost.hide()
	level.actor.modulate.a=1
	hand_error=root.distance_to(hand()) if state==State.HANG else 0

func _draw()->void:
	if route==null:return
	var a:=anchor()
	var b:=hand()
	var axis:Vector2=(b-a).normalized()
	var normal:=Vector2(axis.y,-axis.x)
	var loaded:=state==State.CATCH or state==State.HANG
	var visual_rope:=rope_points.duplicate()
	if not visual_rope.is_empty():
		visual_rope[0]=a
		visual_rope[-1]=shown_hand if state==State.CATCH else b
	var points:=_smooth_rope(visual_rope) if not visual_rope.is_empty() else PackedVector2Array([a,b])
	for i in range(points.size()-1):
		var t:=float(i)/float(points.size()-1)
		var width:=lerpf(3.0,2.25,t)+sin(t*53.0)*0.12
		draw_line(points[i],points[i+1],Color(0.009,0.009,0.009),width,true)
	# Tiny broken highlights imply twisted fibers without a bright central stripe.
	for i in range(3,points.size()-1,5):
		var side:=normal*(0.65 if i%8==3 else -0.45)
		draw_line(points[i]+side,points[i+1]+side*0.2,Color(0.038,0.038,0.038),0.55,true)
	# Short overlapping wraps seated around the actual bough, not a metal ring.
	for i in 3:
		var at:=a+Vector2(i*1.6-1.6,i*1.5)
		var wrap:=PackedVector2Array([at+Vector2(-4,-4),at+Vector2(-5,0),at+Vector2(-1,4),at+Vector2(4,2),at+Vector2(5,-2)])
		draw_polyline(wrap,Color(0.009,0.009,0.009),1.7,true)
	# Rope continues BELOW the hands. The unweighted tail lags and curls freely.
	var tail:=_smooth_rope(tail_points) if not tail_points.is_empty() else PackedVector2Array([b,b+Vector2(0,24)])
	for i in range(tail.size()-1):
		draw_line(tail[i],tail[i+1],Color(0.009,0.009,0.009),lerpf(2.25,1.1,float(i)/maxf(1,tail.size()-1)),true)
	for i in 3:
		var tip:Vector2=tail[-1]+normal*(i-1)*0.7
		draw_polyline(PackedVector2Array([tip,tip+axis*3+normal*(i-1)*1.5,tip+axis*(6-i)+normal*(i-1)*2.4]),Color(0.016,0.016,0.016),0.65,true)
