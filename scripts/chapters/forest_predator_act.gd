extends RefCounted

const Motion=preload("res://scripts/chapters/forest_predator_motion.gd")
const Layout=preload("res://scripts/chapters/forest_predator_layout.gd")
const PICKUP_TIME:=0.87
const THROW_TIME:=0.34
const RELEASE_AT:=0.15
const WINDUP:=Motion.WINDUP_TIME
const FEED_TIME:=Motion.FEED_TIME
const SNAP_TIME:=Motion.SNAP_TIME
const EXIT_RETRY_X:=Layout.PLANT_X+160.0
const GRAVITY:=980.0
const TRIGGER_RANGE:=150.0
const BITE_RANGE:=125.0
const PICKUP_RANGE:=72.0

enum Flower { ALERT, WINDUP, MISS, BAIT_SNAP, EATING, RECOVER, CAPTURE }
enum Bait { HANGING, PICKING, HELD, THROWING, FLYING, GROUND, IN_MOUTH, GONE }
var scene
var enabled:=true
var flower:=Flower.ALERT
var bait:=Bait.HANGING
var time:=0.0
var action_time:=0.0
var throw_animation:=0.0
var bait_position:=Vector2.ZERO # grasp point at the tied feet
var bait_velocity:=Vector2.ZERO
var bait_angle:=0.0
var pickup_from:=Vector2.ZERO
var captured_from:=Vector2.ZERO
var attack_side:=-1.0
var retry_armed:=false
var solved:=false
var rope_attached:=true
var bite_count:=0
var feed_count:=0
var dust:Array[Dictionary]=[]
var fluid:Array[Dictionary]=[]
var snap_splashed:=false

func _init(owner):scene=owner
func ground(x:float)->float:return scene.ground_top(x)
func object_floor(x:float)->float:return ground(x)
func base()->Vector2:return Vector2(Layout.PLANT_X,ground(Layout.PLANT_X)+Layout.BASE_DEPTH)
func hanging_angle()->float:
	var t:float=scene.level.clock
	return sin(t*0.87)*0.035+sin(t*0.43)*0.009
func hanging_point()->Vector2:
	return Vector2(Layout.TREE_X,ground(Layout.TREE_X)+Layout.TREE_EMBED)+(Layout.BRANCH_TIP-Layout.TREE_ROOT)*Layout.TREE_SCALE+Vector2(0,Layout.ROPE_LENGTH).rotated(hanging_angle())
func reset(full:=false)->void:
	if full:
		retry_armed=false
		solved=false
	flower=Flower.ALERT
	attack_side=-1.0
	bait=Bait.GONE if solved else Bait.HANGING
	bait_position=hanging_point()
	bait_velocity=Vector2.ZERO
	bait_angle=0
	time=0
	action_time=0
	throw_animation=0
	rope_attached=not solved
	dust.clear()
	fluid.clear()
	snap_splashed=false
func near()->bool:
	var player:Vector2=scene.level.player.position
	var in_forest:bool=player.x< -300 and player.x>scene.WORLD_LEFT and player.y< -3900
	var at_encounter:bool=player.x>Layout.TREE_X-350 and player.x<Layout.PLANT_X+350
	var at_bait:bool=bait==Bait.GROUND and absf(player.x+13-bait_position.x)<PICKUP_RANGE
	return enabled and in_forest and (at_encounter or owns_bait() or bait==Bait.FLYING or at_bait)
func feet()->Vector2:return scene.level.player.position+Vector2(13,54)
func hand()->Vector2:return scene.level.actor.fan_hand_position()
func owns_bait()->bool:return bait in [Bait.PICKING,Bait.HELD,Bait.THROWING]
func locks_move()->bool:return bait in [Bait.PICKING,Bait.THROWING] or throw_animation>0 or flower==Flower.CAPTURE
func captured()->bool:return flower==Flower.CAPTURE
func retry_position()->Vector2:
	var x:float=EXIT_RETRY_X if solved else Layout.RETRY_X
	return Vector2(x-13,ground(x)-56)
func animation_time()->float:
	# Ambient breathing never depends on encounter proximity or state timer resets.
	return scene.level.clock if flower==Flower.ALERT else time
func mouth()->Vector2:
	var point:=Motion.source_mouth(flower,animation_time())-Vector2(480,880)
	point*=0.4*Layout.VIDEO_DISPLAY_SCALE
	point.x*=-attack_side
	return base()+point
func pose_info()->Dictionary:
	if not enabled:return {"action":&"none","progress":0.0}
	if captured():return {"action":&"uncontrolled_fall","progress":clampf(time,0,1)}
	if bait==Bait.PICKING:return {"action":&"pickup","progress":clampf(action_time/PICKUP_TIME,0,1)}
	if throw_animation>0:return {"action":&"throw_release","progress":1.0-throw_animation/THROW_TIME}
	return {"action":&"none","progress":0.0}
func can_take()->bool:
	return near() and bait in [Bait.HANGING,Bait.GROUND] and scene.level.player.is_on_floor() and absf(feet().x-bait_position.x)<PICKUP_RANGE and absf(feet().y-(bait_position.y+15 if bait==Bait.GROUND else ground(bait_position.x)))<30
func interact()->bool:
	if not near() or scene.intro_time<scene.LIE_TIME+scene.GET_UP_TIME or captured():return false
	if owns_bait():
		if bait==Bait.HELD and Input.is_action_just_pressed("interact"):
			bait=Bait.THROWING
			throw_animation=THROW_TIME
			action_time=0
		return true
	if can_take() and Input.is_action_just_pressed("interact"):
		bait=Bait.PICKING
		action_time=0
		pickup_from=bait_position
		scene.level.facing=signf(bait_position.x-feet().x) if absf(bait_position.x-feet().x)>1 else scene.level.facing
		_sound("cloth")
		return true
	return false
func _sound(key:String)->void:
	if scene.sounds.has(key):scene.sounds[key].play()
func _puff(at:Vector2)->void:
	for i in 7:
		dust.append({"p":at,"v":Vector2(sin(float(i)*2.4)*26,-15-float(i)*5),"age":0.0,"life":0.6+float(i)*0.05})
func _launch()->void:
	bait=Bait.FLYING
	bait_position=hand()
	var target:=mouth()+Vector2(0,-25) # aim the body below the grasp point through the opening
	var d:Vector2=target-bait_position
	if d.x*scene.level.facing>0 and absf(d.x)<390:
		var flight:=clampf(absf(d.x)/320.0,0.40,0.85)
		bait_velocity=d/flight-Vector2(0,GRAVITY*flight*0.5)
	else:bait_velocity=Vector2(scene.level.facing*260,-270)
	_sound("whoosh")
func _feed()->void:
	flower=Flower.BAIT_SNAP
	time=0
	bait=Bait.IN_MOUTH
	feed_count+=1
	snap_splashed=false
	_sound("impact")
func _bait_tick(delta:float)->void:
	if bait==Bait.HANGING:
		bait_position=hanging_point()
	elif bait==Bait.PICKING:
		action_time+=delta
		if action_time>=PICKUP_TIME*0.48:
			rope_attached=false
			bait_position=pickup_from.lerp(hand(),smoothstep(0.48,0.98,action_time/PICKUP_TIME))
		if action_time>=PICKUP_TIME:bait=Bait.HELD
	elif bait==Bait.HELD:bait_position=hand()
	elif bait==Bait.THROWING:
		action_time+=delta
		bait_position=hand()
		if action_time>=RELEASE_AT:_launch()
	elif bait==Bait.FLYING:
		var before:=bait_position
		bait_velocity.y+=GRAVITY*delta
		bait_position+=bait_velocity*delta
		bait_angle+=delta*3.0*signf(bait_velocity.x)
		# Swept body centre prevents a fast throw skipping the mouth in one step.
		var centre:=bait_position+Vector2(0,25)
		var closest:=Geometry2D.get_closest_point_to_segment(mouth(),before+Vector2(0,25),centre)
		if flower in [Flower.ALERT,Flower.WINDUP,Flower.MISS,Flower.RECOVER] and closest.distance_to(mouth())<35:
			_feed()
		else:
			var ray:=PhysicsRayQueryParameters2D.create(before+Vector2(0,25),centre,1)
			var hit:Dictionary=scene.level.get_world_2d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and bait_velocity.y>0:
				bait=Bait.GROUND
				bait_position=Vector2(hit.position)-Vector2(0,15)
				bait_angle=PI*0.5
				_puff(bait_position)
		if bait==Bait.FLYING and bait_position.y+25>=object_floor(bait_position.x):
			if scene.in_pit(bait_position.x):
				if bait_position.y>scene.GROUND_Y+300:bait=Bait.GONE
			else:
				bait=Bait.GROUND
				bait_position.y=object_floor(bait_position.x)-15
				bait_angle=PI*0.5
				_puff(bait_position)
	elif bait==Bait.GROUND and flower in [Flower.ALERT,Flower.WINDUP] and absf(bait_position.x-Layout.PLANT_X)<135:
		_feed()
func _spray_juice()->void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=feed_count*7919+bite_count*2713+17
	var side:float=attack_side if captured() else -1.0
	var source:=mouth()+Vector2(side*31,7)
	for i in 16:
		var speed:float=rng.randf_range(55,155)*(1.25 if captured() else 1.0)
		var v:=Vector2(side*speed,rng.randf_range(-95,30))
		fluid.append({"p":source,"previous":source,"v":v,"age":0.0,"life":rng.randf_range(0.65,1.25),"size":rng.randf_range(0.7,1.6),"landed":false})
	# A few heavier beads leave the lower lip later than the initial jet.
	for i in 4:
		var at:=mouth()+Vector2(-30+float(i)*11,23)
		fluid.append({"p":at,"previous":at,"v":Vector2(-6,14+float(i)*5),"age":-float(i)*0.08,"life":1.0,"size":1.3,"landed":false})
func _fluid_tick(delta:float)->void:
	for i in range(fluid.size()-1,-1,-1):
		var drop:Dictionary=fluid[i]
		drop.age+=delta
		if drop.age<0:continue
		drop.previous=drop.p
		if not drop.landed:
			drop.v.y+=510.0*delta
			drop.p+=drop.v*delta
			if drop.p.y>=object_floor(drop.p.x) and not scene.in_pit(drop.p.x):
				drop.p.y=object_floor(drop.p.x)+1
				drop.landed=true
				drop.age=0.0
				drop.life=0.65
		if drop.age>drop.life:fluid.remove_at(i)

func tick(delta:float)->void:
	if not enabled:return
	_fluid_tick(delta)
	for i in range(dust.size()-1,-1,-1):
		dust[i].age+=delta
		dust[i].p+=dust[i].v*delta
		if dust[i].age>dust[i].life:dust.remove_at(i)
	if not near() and not captured() and flower not in [Flower.BAIT_SNAP,Flower.EATING,Flower.RECOVER]:return
	if scene.level.curtain_phase!=0:return
	if scene.intro_time<scene.LIE_TIME+scene.GET_UP_TIME:return
	if feet().x>=Layout.TREE_X+10:retry_armed=true
	time+=delta
	throw_animation=maxf(0,throw_animation-delta)
	_bait_tick(delta)
	if flower in [Flower.BAIT_SNAP,Flower.EATING] and feet().x>Layout.PLANT_X+95 and scene.level.player.is_on_floor():solved=true
	match flower:
		Flower.ALERT:
			if absf(feet().x-Layout.PLANT_X)<TRIGGER_RANGE and feet().y>ground(Layout.PLANT_X)-200 and feet().y<ground(Layout.PLANT_X)+45:
				flower=Flower.WINDUP
				time=0
				attack_side=signf(feet().x-Layout.PLANT_X)
		Flower.WINDUP:
			if time>=WINDUP:
				if absf(feet().x-Layout.PLANT_X)<BITE_RANGE and absf(feet().y-ground(Layout.PLANT_X))<200:
					flower=Flower.CAPTURE
					time=0
					captured_from=feet()
					bite_count+=1
					snap_splashed=false
					scene.level.player.velocity=Vector2.ZERO
					_sound("impact")
				else:
					flower=Flower.MISS
					time=0
		Flower.MISS:
			if time>81.0/60.0:
				flower=Flower.ALERT
				time=0
		Flower.BAIT_SNAP:
			if time>=SNAP_TIME:
				flower=Flower.EATING
				time=0
		Flower.EATING:
			if time>FEED_TIME:
				flower=Flower.RECOVER
				time=0
		Flower.RECOVER:
			if time>Motion.RECOVER_TIME:
				flower=Flower.ALERT
				time=0
		Flower.CAPTURE:
			if time>1.4:scene.level._fail_restore()
	if flower in [Flower.BAIT_SNAP,Flower.CAPTURE] and time>(WINDUP+3.0/24.0 if flower==Flower.BAIT_SNAP else 3.0/24.0) and not snap_splashed:
		snap_splashed=true
		_spray_juice()
	if flower==Flower.EATING and time>0.6:bait=Bait.GONE
func apply_actor(actor:Node2D)->void:
	if not captured():return
	actor.position=captured_from.lerp(mouth()+Vector2(0,30),smoothstep(0.0,0.20,time))
	actor.rotation=-attack_side*0.25*smoothstep(0.0,0.20,time)
	actor.modulate.a=1.0-smoothstep(0.10,0.28,time)
	if time>3.0/24.0:actor.eye_light.hide()
func swallow_age()->float:
	if flower==Flower.BAIT_SNAP:return time-(WINDUP+3.0/24.0)
	if flower==Flower.EATING:return SNAP_TIME-(WINDUP+3.0/24.0)+time
	if flower==Flower.CAPTURE:return time-3.0/24.0
	return -1.0
