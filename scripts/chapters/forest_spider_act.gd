extends RefCounted
const Crevice=preload("res://scripts/chapters/rock_crevice_layout.gd")
# Pond ambush, then a bounded chase to the far side of the existing boulder.
enum State { DORMANT, DESCEND, LAND, CHASE, STOP, RETREAT, ASCEND, GONE, CAUGHT, SEARCH, FRENZY }
const TRIGGER_OFFSET:=2850.0
const DROP_OFFSET:=2750.0
const RETRY_OFFSET:=2720.0
const ESCAPE_OFFSET:=Crevice.EXIT_SAFE-Crevice.START
const STOP_OFFSET:=Crevice.BODY_STOP-Crevice.START
const DESCEND_TIME:=3.2
const LAND_TIME:=0.35
const WALK_SPEED:=150.0
const RETREAT_SPEED:=135.0
const CATCH_FRONT:=230.0
const STAB_IMPACT:=0.80
var scene
var enabled:=true
var state:=State.DORMANT
var time:=0.0
var walk_time:=0.0
var motion_clock:=0.0
var barrier_time:=0.0
var execution_target:=Vector2.ZERO
var victim_grounded:=false
var execution_airborne:=false
var victim_hooked:=false
var hook_point:=Vector2.ZERO
var hook_start:=Vector2.ZERO
var aerial_hold:=Vector2.ZERO
var victim_fall_time:=0.0
var stabbed:=false
var blood:Array[Dictionary]=[]
var blood_jets:Array[Dictionary]=[]
var stab_count:=0
var position:=Vector2.ZERO # fixed ground/root anchor of the authored clip
var drop_from:=Vector2.ZERO
var facing:=1.0
var retry_armed:=false
var cleared:=false
var caught_count:=0
var ambush_count:=0
var last_player_x:=-1.0e9
const QUIET_TIME:=3.5
const FRENZY_AFTER:=1.6
const MOUTH_ATTACK_DELAY:=1.90
var log_hunt:=false
var log_attack_delay:=0.0
var quiet_time:=0.0
var noise_time:=0.0
var heard_x:=0.0
var log_strike_count:=0
var log_strike_x:=0.0
var log_strike_age:=-1.0
var log_strike_fired:=false
var log_tip_contact:=false
var last_motion_x:=-1.0e9
func _init(owner):scene=owner
func x_at(offset:float)->float:return scene.START_X+offset
func feet()->Vector2:return scene.level.player.position+Vector2(13,54)
func reset(full:=false)->void:
	if full:
		retry_armed=false
		cleared=false
	state=State.GONE if cleared else State.DORMANT
	time=0
	walk_time=0
	motion_clock=0
	barrier_time=0
	stabbed=false
	victim_grounded=false
	execution_airborne=false
	victim_hooked=false
	victim_fall_time=0
	blood.clear()
	blood_jets.clear()
	facing=1
	position=Vector2(x_at(DROP_OFFSET),scene.ground_top(x_at(DROP_OFFSET)))
	last_player_x=scene.level.player.position.x+13
	last_motion_x=last_player_x
	log_hunt=false;log_attack_delay=0;quiet_time=0;noise_time=0;heard_x=last_player_x
	log_strike_age=-1;log_strike_count=0;log_strike_fired=false;log_tip_contact=false
func retry_position()->Vector2:
	var x:=x_at(RETRY_OFFSET)
	return Vector2(x-13,scene.ground_top(x)-56)
func is_visible()->bool:
	return enabled and state not in [State.DORMANT,State.GONE]
func walking()->bool:
	return state in [State.RETREAT,State.SEARCH,State.FRENZY] or (state==State.CHASE and position.x<x_at(STOP_OFFSET)-0.5)
func rage()->float:
	if state==State.FRENZY:return 1.0
	if state==State.SEARCH:return clampf(noise_time/FRENZY_AFTER,0.1,0.75)
	if state==State.STOP:return (1.0-smoothstep(1.30,2.1,time))
	return smoothstep(0.0,0.45,barrier_time) if state==State.CHASE else 0.0
func silk_visible()->bool:return state in [State.DESCEND,State.LAND,State.ASCEND]
func silk_top()->Vector2:return Vector2(x_at(DROP_OFFSET)-65,scene.GROUND_Y-780)
func silk_end()->Vector2:return position+Vector2(-65,-85)
func _begin(next:int)->void:
	state=next
	time=0
func _ambush()->void:
	retry_armed=true
	ambush_count+=1
	var x:=x_at(DROP_OFFSET)
	drop_from=Vector2(x,scene.ground_top(x)-610)
	position=drop_from
	_begin(State.DESCEND)
func _supported()->bool:
	var query:=PhysicsRayQueryParameters2D.create(feet()-Vector2(0,5),feet()+Vector2(0,7),1)
	return not scene.level.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func _land_victim()->void:
	victim_grounded=true
	victim_fall_time=0
	time=0
	execution_target=feet()+Vector2(scene.level.facing*3,-11)
	scene.level.marsh_hit_time=0.001
	scene.level.player.velocity=Vector2.ZERO
func impact_time()->float:return 1.02 if execution_airborne else STAB_IMPACT
func supported_execution()->bool:return victim_grounded or (execution_airborne and victim_hooked)
func carrier_tip(from:Vector2)->Vector2:
	if not victim_hooked:return from.lerp(hook_point,smoothstep(0.0,0.20,time))
	return execution_target+reaction_shift()
func settle_victim(delta:float)->void:
	var level=scene.level
	if execution_airborne:
		if not victim_hooked and time<0.20:
			level.player.velocity.y=minf(800,level.player.velocity.y+1250*delta)
			level.player.velocity.x=move_toward(level.player.velocity.x,0,450*delta)
			level.player.move_and_slide()
			hook_point=feet()-Vector2(0,28)
			if level.player.is_on_floor() and _supported():
				execution_airborne=false
				_land_victim()
			return
		if not victim_hooked:
			victim_hooked=true
			hook_start=hook_point
			level.player.collision_mask=0
		execution_target=hook_start.lerp(aerial_hold,smoothstep(0.20,0.52,time))
		level.player.position=execution_target+Vector2(0,11)-Vector2(13,54)
		level.player.velocity=Vector2.ZERO
		if time>2.10:level._fail_restore()
		return
	victim_fall_time+=delta
	level.player.velocity.x=move_toward(level.player.velocity.x,0,500*delta)
	level.player.velocity.y=minf(850,level.player.velocity.y+1500*delta)
	level.player.move_and_slide()
	if level.player.is_on_floor() and _supported():_land_victim()
	elif victim_fall_time>2.0 or feet().y>scene.GROUND_Y+600:level._fail_restore()
func _catch()->void:
	var level=scene.level
	if level.climb_time>=0:level._end_climb(false)
	var velocity:Vector2=level.player.velocity
	victim_grounded=_supported()
	execution_airborne=not victim_grounded
	victim_hooked=false
	hook_point=feet()-Vector2(0,28)
	aerial_hold=position+Vector2(facing*125,-115)
	victim_fall_time=0
	caught_count+=1
	execution_target=feet()+Vector2(level.facing*3,-11)
	stabbed=false
	_begin(State.CAUGHT)
	level._start_marsh_hit("fall",level.player.position+Vector2(13,27))
	if not victim_grounded:
		level.player.velocity=Vector2(velocity.x*0.25,maxf(40,velocity.y))
func reaction_shift()->Vector2:
	var age:=time-impact_time()
	if state!=State.CAUGHT or not supported_execution() or age<0:return Vector2.ZERO
	var pulse:=sin(clampf(age/0.18,0,1)*PI)*exp(-age*5.0)
	return Vector2(-facing*4.5*sin(age*32.0)*exp(-age*10.0),-9.0*pulse)
func reaction_angle()->float:
	var age:=time-impact_time()
	if state!=State.CAUGHT or not supported_execution() or age<0:return 0.0
	return -facing*0.14*sin(age*30.0)*exp(-age*9.0)
func apply_actor(actor:Node2D)->void:
	if state!=State.CAUGHT or not supported_execution():return
	var theta:=reaction_angle()+(facing*0.22 if execution_airborne else 0.0)
	actor.position=execution_target+(actor.position-execution_target).rotated(theta)+reaction_shift()
	actor.rotation=theta
func execution_tip(from:Vector2)->Vector2:
	var impact:=impact_time()
	var raised:=execution_target+Vector2(-facing*20,-105 if execution_airborne else -150)
	if time<impact-0.10:return from.lerp(raised,smoothstep(impact-0.52,impact-0.10,time))
	if time<impact:return raised.lerp(execution_target,pow(clampf((time-impact+0.10)/0.10,0,1),2.2))
	if time<impact+0.32:return execution_target+reaction_shift()+Vector2(0,body_impact()*5.0)
	return execution_target.lerp(raised+Vector2(-facing*18,-10),smoothstep(impact+0.32,impact+0.56,time))
func body_impact()->float:
	var impact:=impact_time()
	if state!=State.CAUGHT or not supported_execution() or time<impact-0.025:return 0.0
	var press:=smoothstep(impact-0.025,impact+0.025,time)
	var settle:=0.66+0.34*exp(-maxf(0,time-impact)*16.0)
	return press*settle*(1.0-smoothstep(impact+0.32,impact+0.62,time))
func _sheltered(player:Vector2)->bool:
	# Position alone is ambiguous at the broken mouth: an upright actor beside
	# it is exposed, while an actor who deliberately bent and moved beneath it
	# is protected by the same visible timber.
	return scene.low_stance.active() and Crevice.sheltered(player.x,player.y)
func _can_attack(player:Vector2)->bool:
	# The solid roof protects the low passage; exposed mouths are dangerous.
	if _sheltered(player):return false
	if log_hunt:
		if log_attack_delay>0:return false
		if absf(player.x-position.x)>260 or absf(player.y-scene.ground_top(player.x))>130:return false
		# At either open mouth the actor is visibly exposed. A ray toward him can
		# graze the timber's support branch, but that must not turn the ground in
		# front of the shelter into an invisible safe zone.
		if not scene.low_stance.active() or player.x<=Crevice.SHELTER_LEFT or player.x>=Crevice.SHELTER_RIGHT:return true
		var log_ray:=PhysicsRayQueryParameters2D.create(position+Vector2(facing*55,-80),player-Vector2(0,25),1)
		return scene.level.get_world_2d().direct_space_state.intersect_ray(log_ray).is_empty()
	if absf(player.x-position.x)>CATCH_FRONT or player.y<position.y-175 or player.y>position.y+45:return false
	var origin:=position+Vector2(facing*95,-125)
	var target:=player-Vector2(0,26)
	var query:=PhysicsRayQueryParameters2D.create(origin,target,1)
	return scene.level.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
func _stab()->void:
	stabbed=true
	stab_count+=1
	var rng:=RandomNumberGenerator.new()
	rng.seed=7297+caught_count*101
	var directions:=[Vector2(-175,-255),Vector2(-85,-335),Vector2(-25,-295),Vector2(65,-330),Vector2(155,-245),Vector2(105,-175)]
	for i in [0,1,3,4]:
		blood_jets.append({"v":directions[i],"width":rng.randf_range(3.8,5.5),"emit":rng.randf_range(0.10,0.16),"delay":rng.randf_range(0,0.025),"phase":rng.randf()*TAU})
	for i in 42:
		var delay:float=0.0 if i<28 else rng.randf_range(0.02,0.14)
		var velocity:Vector2=Vector2(directions[i%6]).rotated(rng.randf_range(-0.17,0.17))*rng.randf_range(0.62,1.15)
		blood.append({"p":execution_target,"v":velocity,"age":-delay,"life":rng.randf_range(0.75,1.25),"size":rng.randf_range(1.1,3.0),"landed":false})
	scene.level.camera_shake=maxf(scene.level.camera_shake,1.15)
	(scene.sounds["impact"] as AudioStreamPlayer).play()
func _tick_blood(delta:float)->void:
	for i in range(blood.size()-1,-1,-1):
		var drop:Dictionary=blood[i]
		drop.age+=delta
		if drop.age<0:continue
		if not drop.landed:
			drop.v.y+=680.0*delta
			drop.p+=drop.v*delta
			var floor:float=scene.ground_top(drop.p.x)
			if drop.p.y>=floor:
				drop.p.y=floor
				drop.landed=true
				drop.age=0.0
				drop.life=0.65
		if drop.age>drop.life:blood.remove_at(i)

func log_surface(x:float)->float:
	var ground:float=scene.ground_top(x)
	var w:=smoothstep(Crevice.LEFT-150,Crevice.LEFT+15,x)*(1.-smoothstep(Crevice.EXIT_MOUTH+10,Crevice.EXIT_MOUTH+120,x))
	return lerpf(ground,Crevice.roof_top(x,Callable()),w)
func log_attacking()->bool:return log_hunt and log_strike_age>=0 and log_strike_age<.85
func log_target()->Vector2:return Vector2(log_strike_x,Crevice.roof_top(log_strike_x,Callable())+9)
func log_tip(from:Vector2)->Vector2:
	var target:=log_target()
	var raised:=target+Vector2(-facing*22,-100)
	if log_strike_age<.32:return from.lerp(raised,smoothstep(0,.32,log_strike_age))
	if log_strike_age<.46:return raised.lerp(target,pow(clampf((log_strike_age-.32)/.14,0,1),2.0))
	if log_strike_age<.59:return target
	return target.lerp(raised,smoothstep(.59,.85,log_strike_age))
func report_log_tip(actual:Vector2)->void:
	# Rendering solves the authored leg against its real reach. Only that solved
	# tip can confirm contact; the gameplay clock alone must not shake the timber.
	if log_strike_age>=.42 and actual.distance_to(log_target())<=7.0:log_tip_contact=true
func _search_log(delta:float,player:Vector2,moving:bool)->void:
	var sheltered:=_sheltered(player)
	log_attack_delay=maxf(0.0,log_attack_delay-delta)
	if moving:
		heard_x=player.x;quiet_time=0;noise_time+=delta
	else:
		quiet_time=quiet_time+delta if sheltered else 0.0
		noise_time=maxf(0,noise_time-delta*.6)
	if quiet_time>=QUIET_TIME:
		log_strike_age=-1
		_begin(State.RETREAT)
		return
	var next:int=State.FRENZY if noise_time>=FRENZY_AFTER else State.SEARCH
	if state!=next:_begin(next)
	var patrol:float=0 if moving else sin(motion_clock*1.7)*95
	var target_x:float=clampf(heard_x+patrol,Crevice.LEFT-75,Crevice.EXIT_MOUTH+90)
	var speed:float=215 if state==State.FRENZY else 160
	var dx:=target_x-position.x
	if absf(dx)>12:facing=signf(dx)
	position.x=move_toward(position.x,target_x,speed*delta)
	position.y=move_toward(position.y,log_surface(position.x),200*delta)
	walk_time+=delta
	if state==State.FRENZY and log_strike_age<0:
		log_strike_age=0;log_strike_fired=false;log_tip_contact=false
		log_strike_x=clampf(heard_x,Crevice.LEFT+30,Crevice.EXIT_MOUTH-30)
	if log_strike_age>=0:
		log_strike_age+=delta
		if log_strike_age>=.46 and log_tip_contact and not log_strike_fired:
			log_strike_fired=true;log_strike_count+=1
			scene.level.camera_shake=maxf(scene.level.camera_shake,.65)
			(scene.sounds["impact"] as AudioStreamPlayer).play()
		if log_strike_age>=.85:log_strike_age=-1;log_tip_contact=false
	if not sheltered and _can_attack(player):_catch()

func tick(delta:float)->void:
	if not enabled:return
	_tick_blood(delta)
	var player:=feet()
	var in_forest:bool=player.x>scene.WORLD_LEFT and player.x<scene.CLIFF_X+100 and player.y< -3900
	if not in_forest:return
	var level=scene.level
	if state==State.CAUGHT:
		if not victim_grounded and not execution_airborne:return
		time+=delta
		motion_clock+=delta
		if time>=impact_time() and not stabbed and supported_execution():_stab()
		return
	if level.curtain_phase!=0 or level.marsh_hit_time>0 or level.death_time>0:return
	if scene.intro_time<scene.LIE_TIME+scene.GET_UP_TIME:return
	time+=delta
	motion_clock+=delta
	var crossed:bool=last_player_x<x_at(TRIGGER_OFFSET) and player.x>=x_at(TRIGGER_OFFSET)
	last_player_x=player.x
	var moved:=absf(player.x-last_motion_x)>.04
	last_motion_x=player.x
	if state==State.DORMANT:
		# Starting a later DEBUG/checkpoint entry must not create a fresh ambush.
		if crossed and player.x<x_at(TRIGGER_OFFSET+120):_ambush()
		return
	# The body stops short of the timber, but its long-leg hunt must begin as
	# soon as the player reaches the mouth. Waiting until the player was already
	# sheltered left a dead strip where the spider stood still and could not
	# reach an exposed player.
	var reached_log_mouth:=player.x>=Crevice.DUCK_LEFT and player.x<=Crevice.DUCK_RIGHT
	if state==State.CHASE and reached_log_mouth:
		log_hunt=true;log_attack_delay=MOUTH_ATTACK_DELAY;heard_x=player.x;quiet_time=0;noise_time=0
		_begin(State.SEARCH)
	if state in [State.SEARCH,State.FRENZY]:
		_search_log(delta,player,moved)
		return
	match state:
		State.DESCEND:
			var target:=Vector2(x_at(DROP_OFFSET),scene.ground_top(x_at(DROP_OFFSET)))
			position=drop_from.lerp(target,smoothstep(0.0,1.0,time/DESCEND_TIME))
			if time>=DESCEND_TIME:
				_begin(State.LAND)
				level.camera_shake=maxf(level.camera_shake,0.55)
				level.art.emit_drag_dust([position+Vector2(-70,0),position+Vector2(70,0)],12.0)
				(scene.sounds["impact"] as AudioStreamPlayer).play()
		State.LAND:
			if time>=LAND_TIME:_begin(State.CHASE)
		State.CHASE:
			facing=1.0 if player.x>=position.x else -1.0
			var stop_x:=x_at(STOP_OFFSET)
			var burst:float=10.0*pow(maxf(0,sin(motion_clock*7.0)),4)
			position.x=move_toward(position.x,minf(player.x,stop_x),(WALK_SPEED+burst)*delta)
			position.y=scene.ground_top(position.x)
			walk_time+=delta
			barrier_time=barrier_time+delta if position.x>=stop_x-1 else 0.0
			# The long legs halt at the boulder's near face. The far bank is safe.
			if _can_attack(player):
				_catch()
		State.STOP:
			if time>=2.1:
				_begin(State.RETREAT) # keep facing the player while backing away
		State.RETREAT:
			if log_hunt and not cleared and moved and absf(player.x-position.x)<450:
				heard_x=player.x;quiet_time=0;noise_time=0
				_begin(State.SEARCH)
				return
			position.x=move_toward(position.x,x_at(DROP_OFFSET),RETREAT_SPEED*delta)
			position.y=move_toward(position.y,log_surface(position.x) if log_hunt else scene.ground_top(position.x),200*delta)
			if log_hunt and position.x<Crevice.LEFT-280:
				cleared=true;log_hunt=false
			walk_time+=delta*RETREAT_SPEED/WALK_SPEED
			if absf(position.x-x_at(DROP_OFFSET))<1:
				drop_from=position
				_begin(State.ASCEND)
		State.ASCEND:
			position=drop_from+Vector2(0,-650*smoothstep(0,1,time/2.2))
			if time>=2.2:_begin(State.GONE)
