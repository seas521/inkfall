extends Node2D

const Layout=preload("res://scripts/chapters/descent_route_layout.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const Art=preload("res://scripts/chapters/descent_route_art.gd")
const O:=Layout.ORIGIN
var level
var art
var active:=false
var in_c_zone:=false
var stage:=0
var clock:=0.0
var checkpoint:=Vector2(-2180,-3715)
var checkpoint_stage:=0
var visited_upper:=false
var visited_lower:=false
var discovered:=false
var upper_travel:=0.0
var weight_travel:=0.0
var basket_y:=520.0
var basket_speed:=0.0
var bar_travel:=0.0
var seesaw_angle:=0.25
var seesaw_locked:=false
var upper_complete:=false
var lower_complete:=false
var interaction:=""
var grip_elapsed:=0.0
var grip_facing:=1.0
var grip_distance:=0.0
var pull_motion:=0.0
var scrape_distance:=0.0
var failure_time:=0.0
var deaths:=0
var fall_y:=0.0
var was_grounded:=true
var bodies:Array=[]
var station:Array=[]
var ledges:Array=[]
var fragile_age:Dictionary={}
var trolley:AnimatableBody2D
var weight:AnimatableBody2D
var suspended:AnimatableBody2D
var seesaw:AnimatableBody2D
var basket:AnimatableBody2D
var bar:AnimatableBody2D
var blocker:StaticBody2D
var deflector:=0.0
var collected:=0
var harvest_height:=0.0
var rock_clock:=0.0
var rocks:Array[Dictionary]=[]
var dust:Array[Dictionary]=[]
var sounds:Dictionary={}
var _hand:=Vector2.ZERO

func _ready()->void:
	for rect in Layout.STATION:station.append(_platform(O+rect.position,rect.size))
	trolley=_platform(O+Vector2(130,-48),Vector2(56,48))
	weight=_platform(O+Vector2(840,232),Vector2(56,48))
	suspended=_platform(O+Vector2(700,0),Vector2(140,24),true)
	seesaw=_platform(O+Vector2(1040,20),Vector2(300,20),true,Vector2(-150,0))
	basket=_platform(O+Vector2(705,520),Vector2(170,22),true)
	bar=_platform(O+Vector2(1170,389),Vector2(65,16))
	for i in Layout.DESCENT.size():
		var w:float=Layout.ledge_width(i)
		ledges.append(_platform(Layout.DESCENT[i]-Vector2(w*0.5,0),Vector2(w,28),true))
	# A separate overlook is a genuine optional detour, not a mandatory key.
	_platform(Layout.DESCENT[14]+Vector2(130,-55),Vector2(160,65),true)
	art=Art.new()
	art.route=self
	add_child(art)
	for item in [["creak","tree_creak_01.mp3",-25.0],["click","tree_creak_03.mp3",-22.0],["impact","body_impact.mp3",-20.0]]:
		var sound:=AudioStreamPlayer.new()
		sound.stream=load("res://assets/audio/level01/"+item[1])
		sound.volume_db=item[2]
		add_child(sound)
		sounds[item[0]]=sound
	_sync_mechanisms(0)
	set_collisions(false)

func _platform(at:Vector2,size:Vector2,one_way:=false,offset:=Vector2.ZERO)->AnimatableBody2D:
	var body:=AnimatableBody2D.new()
	body.position=at
	body.collision_layer=1
	body.collision_mask=0
	body.sync_to_physics=true
	var shape:=CollisionShape2D.new()
	var rectangle:=RectangleShape2D.new()
	rectangle.size=size
	shape.shape=rectangle
	shape.position=offset+size*0.5
	shape.one_way_collision=one_way
	body.add_child(shape)
	add_child(body)
	bodies.append(body)
	return body

func set_collisions(enabled:bool)->void:
	for body in bodies:body.collision_layer=1 if enabled else 0

func reset()->void:
	active=false
	in_c_zone=false
	stage=0
	checkpoint=O+Vector2(120,0)
	checkpoint_stage=0
	visited_upper=false
	visited_lower=false
	discovered=false
	upper_travel=0
	weight_travel=0
	basket_y=520
	basket_speed=0
	bar_travel=0
	seesaw_angle=0.25
	seesaw_locked=false
	upper_complete=false
	lower_complete=false
	interaction=""
	failure_time=0
	deflector=0
	collected=0
	harvest_height=0
	rock_clock=-1.2
	rocks.clear()
	dust.clear()
	fragile_age.clear()
	_sync_mechanisms(0)
	set_collisions(false)
	if art!=null:art.sync(0,false)

func feet()->Vector2:return level.player.position+Vector2(13,54)
func basket_position()->Vector2:
	return O+Vector2(1080+(basket_y-280.0)/285.0*470.0,basket_y)
func _on(body:Node2D,width:float,height:=0.0)->bool:
	var p:Vector2=body.to_local(feet())
	return level.player.is_on_floor() and p.x>=-8 and p.x<=width+8 and absf(p.y-height)<8

func enter(which:=0,place:=false)->void:
	active=true
	in_c_zone=false
	stage=which
	level.rope_ladder.stop()
	level.log_bridge.active=false
	level.scene1.cut=level.scene1.Cut.DONE
	level.scene1.intro_time=99
	level.intro_time=0
	level.climb_time=-1
	level.fan_owned=false
	level.fan.hide()
	level.actor.finish_rope_ladder()
	set_collisions(true)
	if place:
		checkpoint=O+Vector2(100,0) if which==0 else Layout.DESCENT[0]
		checkpoint_stage=which
		_respawn()
		level.camera_x=level.player.position.x-525
		level.camera_y=level._camera_target_y()
		level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	fall_y=feet().y
	was_grounded=true

func _respawn()->void:
	stage=checkpoint_stage
	level.player.position=checkpoint-Vector2(13,55)
	level.player.velocity=Vector2.ZERO
	level.player.collision_mask=11
	level.jump_buffer=0
	level.jump_windup_left=0
	level.coyote=0
	level.facing=1
	level.actor.finish_rope_ladder()
	interaction=""
	grip_elapsed=0
	fall_y=checkpoint.y
	was_grounded=true
	rocks.clear()
	rock_clock=-1.2
	fragile_age.clear()
	_sync_mechanisms(0)

func restore_checkpoint()->void:
	failure_time=0
	_respawn()
	# Only debug/restart and a closed death iris relocate the camera.
	level.camera_x=level.player.position.x-525
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)

func _fail()->void:
	if failure_time>0:return
	failure_time=0.001
	deaths+=1
	interaction=""
	level.player.velocity=Vector2.ZERO
	burst(feet(),12)
	sounds.impact.play()

func burst(at:Vector2,count:=8)->void:
	for i in count:
		dust.append({"p":at,"v":Vector2(sin(i*2.399)*45,-15-absf(cos(i*1.71))*35),"age":0.0,"life":0.8+float(i%4)*0.15})

func _choose_interaction()->String:
	var p:Vector2=feet()
	if stage==1:
		if p.distance_to(Layout.DESCENT[6]+Vector2(50,-20))<85:return "deflector"
		if p.distance_to((Layout.DESCENT[14]+Vector2(210,-55)))<75:return "memory"
		return ""
	if p.distance_to(O+Vector2(158+upper_travel,0))<70:return "trolley"
	if p.distance_to(O+Vector2(868+weight_travel,280))<70:return "weight"
	if p.distance_to(O+Vector2(1200-bar_travel,420))<70 and bar_travel<56:return "bar"
	if _on(basket,170):return "basket"
	if absf(p.x-(O.x+930))<65 and absf(p.y-(O.y+50))<55:return "ratchet"
	return ""

func _tick_interaction(delta:float,direction:float)->bool:
	if Input.is_action_just_pressed("interact"):
		interaction=_choose_interaction()
		grip_facing=1.0
		if interaction=="trolley":grip_facing=1.0 if feet().x<trolley.position.x+28 else -1.0
		elif interaction=="weight":grip_facing=1.0 if feet().x<weight.position.x+28 else -1.0
		elif interaction=="basket":grip_facing=-1.0
		grip_elapsed=0
		grip_distance=0
		if interaction=="ratchet":
			if seesaw_angle< -0.23:
				seesaw_locked=true
				sounds.click.play()
				burst(O+Vector2(930,30),5)
			interaction=""
		elif interaction=="memory":
			discovered=true
			sounds.creak.play()
			interaction=""
	if not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump"):
		interaction=""
		return false
	if interaction.is_empty():return false
	grip_elapsed+=delta
	pull_motion=0
	if interaction=="basket":
		if not _on(basket,170):
			interaction=""
			return false
		var stop:float=565.0 if bar_travel>=56 else 420.0
		var before:float=basket_y
		basket_speed=move_toward(basket_speed,65.0,delta*90)
		basket_y=minf(stop,basket_y+basket_speed*delta)
		if before<stop and basket_y>=stop:
			basket_speed=0
			sounds.click.play()
			burst(basket_position(),7)
		weight_travel=(520-basket_y)/1.4
		_hand=basket_position()+Vector2(-24,-37)
	elif interaction=="deflector":
		deflector=clampf(deflector+direction*delta*0.8,0,1)
		_hand=Layout.DESCENT[6]+Vector2(55,-38)
		pull_motion=absf(direction)*delta*30
	elif grip_elapsed>0.28:
		var travel:float=direction*55*delta
		if interaction=="trolley":
			var before:float=upper_travel
			upper_travel=clampf(upper_travel+travel,0,280)
			pull_motion=absf(upper_travel-before)
			level.player.velocity.x=(upper_travel-before)/delta
			_hand=O+Vector2(130+upper_travel,-30)
		elif interaction=="weight":
			var before:float=weight_travel
			weight_travel=clampf(weight_travel+travel,0,172)
			basket_y=clampf(520-weight_travel*1.4,280,520)
			pull_motion=absf(weight_travel-before)
			level.player.velocity.x=(weight_travel-before)/delta
			_hand=O+Vector2(840+weight_travel,250)
		elif interaction=="bar":
			var before:float=bar_travel
			bar_travel=clampf(bar_travel-maxf(0,-direction)*-55*delta,0,56)
			pull_motion=absf(bar_travel-before)
			level.player.velocity.x=-(bar_travel-before)/delta
			_hand=O+Vector2(1200-bar_travel,390)
			if before<56 and bar_travel>=56:
				sounds.click.play()
				burst(O+Vector2(1170,400),9)
				interaction=""
	else:
		level.player.velocity.x=0
	grip_distance+=pull_motion
	if pull_motion>0 and not sounds.creak.playing:sounds.creak.play()
	if pull_motion>0:
		scrape_distance+=pull_motion
		if scrape_distance>=5:
			scrape_distance=fmod(scrape_distance,5)
			burst(_hand+Vector2(12,28),2)
	return true

func _sync_mechanisms(delta:float)->void:
	trolley.position=O+Vector2(130+upper_travel,-48)
	weight.position=O+Vector2(840+weight_travel,232)
	suspended.position=O+Vector2(710-upper_travel,0)
	if not seesaw_locked:
		var p:Vector2=seesaw.to_local(feet())
		var target:=0.25
		if absf(p.x)<170 and absf(p.y)<10 and level.player.is_on_floor():target=clampf(p.x/130.0*0.35,-0.35,0.35)
		seesaw_angle=move_toward(seesaw_angle,target,delta*0.40)
	seesaw.rotation=seesaw_angle
	basket.position=basket_position()-Vector2(85,0)
	bar.position=O+Vector2(1170-bar_travel,389)
	for i in ledges.size():
		var at:Vector2=Layout.DESCENT[i]-Vector2(Layout.ledge_width(i)*0.5,0)
		if i==7:at.y-=200.0-harvest_height
		if i in Layout.SWAYING:at.x+=sin(clock*1.25+float(i))*22
		if fragile_age.has(i):
			var age:float=fragile_age[i]
			at.y+=pow(maxf(0,age-0.65),2)*600
			ledges[i].rotation=minf(0.5,maxf(0,age-0.55)*0.45)
		else:ledges[i].rotation=0
		ledges[i].position=at
		ledges[i].collision_layer=1 if active and float(fragile_age.get(i,0))<1.05 else 0

func _tick_descent(delta:float)->void:
	harvest_height=move_toward(harvest_height,float(collected)*100,delta*45)
	var p:Vector2=feet()
	for i in Layout.FRAGILE:
		if _on(ledges[i],Layout.ledge_width(i)) and not fragile_age.has(i):
			fragile_age[i]=0.001
			sounds.creak.play()
	for i in fragile_age.keys():fragile_age[i]=float(fragile_age[i])+delta
	for i in Layout.SAVES:
		if _on(ledges[i],Layout.ledge_width(i)) and Layout.DESCENT[i].y>checkpoint.y+30:
			checkpoint=Layout.DESCENT[i]
			checkpoint_stage=1
	if p.distance_to(Layout.DESCENT[6])<600:
		rock_clock+=delta
		if rock_clock>=4.0:
			rock_clock=0
			rocks.append({"p":Layout.DESCENT[6]+Vector2(-150,-280),"v":Vector2(80,30),"routed":false,"age":0.0})
	for i in range(rocks.size()-1,-1,-1):
		var rock:Dictionary=rocks[i]
		var previous:Vector2=rock.p
		rock.age+=delta
		rock.v.y+=650*delta
		rock.p+=rock.v*delta
		var pivot:Vector2=Layout.DESCENT[6]+Vector2(-65,-30)
		if not rock.routed and rock.p.y>=pivot.y and previous.y<pivot.y:
			rock.routed=true
			rock.p=pivot
			rock.v=Vector2(lerpf(115,-150,deflector),-20)
			burst(pivot,4)
		var catcher:Vector2=Layout.DESCENT[7]+Vector2(0,100)
		if rock.routed and rock.p.y>=catcher.y and previous.y<catcher.y and absf(rock.p.x-catcher.x)<65:
			collected=mini(2,collected+1)
			burst(catcher,12)
			sounds.impact.play()
			rocks.remove_at(i)
			continue
		if rock.p.distance_to(level.player.position+Vector2(13,25))<25:_fail()
		if rock.age>5:rocks.remove_at(i)
	# Later chutes have readable dust warnings, with actual collision stones.
	var phase:float=fmod(clock,4.2)
	if phase<delta:
		for index in [10,18,26]:
			var chute:Vector2=Layout.DESCENT[index]
			if absf(p.y-chute.y)<350:
				rocks.append({"p":chute+Vector2(95,-260),"v":Vector2(-35,30),"routed":true,"age":0.0})

func tick(delta:float)->bool:
	clock+=delta
	if in_c_zone:return false
	if not active:
		if level.log_bridge.reached_bank and feet().x> -2460 and feet().y< -3500:
			enter(0)
		else:
			art.sync(delta,false)
			return false
	if failure_time>0:
		failure_time+=delta
		if failure_time>=0.9:
			_respawn()
			failure_time=0
			level.camera_x=level.player.position.x-525
			level.camera_y=level._camera_target_y()
			level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
		_present(delta)
		return true
	var direction:float=Input.get_axis("move_left","move_right")
	if absf(direction)>0.1:level.facing=signf(direction)
	var manipulating:bool=_tick_interaction(delta,direction)
	_sync_mechanisms(delta)
	if manipulating:
		level.facing=grip_facing
		if interaction in ["basket","deflector"] or grip_elapsed<=0.28:level.player.velocity.x=0
		level.player.velocity.y=minf(850,level.player.velocity.y+1500*delta)
		level.player.move_and_slide()
	else:level._update_player(delta,direction,0)
	var p:Vector2=feet()
	var grounded:bool=level.player.is_on_floor()
	if grounded and not was_grounded and p.y-fall_y>level.LETHAL_FALL:_fail()
	if grounded:fall_y=p.y
	else:fall_y=minf(fall_y,p.y)
	was_grounded=grounded
	if stage==0:
		if p.y>O.y+110:visited_lower=true
		if p.x>O.x+500 and p.y<O.y+80:visited_upper=true
		if p.y>O.y+850:_fail()
		if grounded and p.x>O.x+1450 and absf(p.y-(O.y+565))<10:
			upper_complete=upper_complete or visited_upper
			lower_complete=lower_complete or visited_lower
			checkpoint=O+Vector2(1800,565)
			checkpoint_stage=0
		if grounded and p.x>O.x+2200 and absf(p.y-(O.y+565))<10:
			stage=1
			checkpoint=Layout.DESCENT[0]
			checkpoint_stage=1
			rock_clock=-1.2
	else:
		_tick_descent(delta)
		if not grounded and p.y-fall_y>350:_fail()
		if p.y>720:_fail()
		if grounded and p.x> -110 and p.y>200:
			in_c_zone=true
			active=false
			level.checkpoint=0
			level.scene1.cut=level.scene1.Cut.DONE
			level.scene1.intro_time=99
			level.intro_time=0
			art.sync(delta,false)
			return false
	for i in range(dust.size()-1,-1,-1):
		dust[i].age+=delta
		dust[i].p+=dust[i].v*delta
		dust[i].v*=exp(-delta*2)
		if dust[i].age>dust[i].life:dust.remove_at(i)
	_present(delta)
	return true

func _present(delta:float)->void:
	level._update_camera(delta)
	level.camera.offset=Vector2.ZERO
	var pose:=Pose.new()
	var action:StringName=Pose.ACTION_NONE
	var progress:=0.0
	if failure_time>0:
		action=Pose.ACTION_FALL_IMPACT
		progress=failure_time/0.65
	elif not interaction.is_empty():
		action=&"grip_engage" if grip_elapsed<0.28 else (&"pull" if Input.get_axis("move_left","move_right")*level.facing<0 else &"push")
		if pull_motion<0.001 and grip_elapsed>=0.28:action=&"grip_hold"
		progress=clampf(grip_elapsed/0.28,0,1)
	elif level.scene1.low_stance.active():
		var low_pose:Dictionary=level.scene1.low_stance.pose_info()
		action=low_pose.action
		progress=float(low_pose.progress)
	pose.apply({"feet":feet(),"velocity":level.player.velocity,"grounded":level.player.is_on_floor(),"facing":level.facing,"action":action,"action_progress":progress,"fog_blur":level.ACTOR_EDGE_SOFTNESS,"visual_scale":Pose.HOOD_VISUAL_SCALE,"jump_windup":(1-level.jump_windup_left/Pose.HOOD_JUMP_WINDUP) if level.jump_windup_left>0 else -1.0})
	level.actor.grip_distance=grip_distance
	level.actor.rope_allowed=false
	level.actor.squash=1
	level.actor.sync_pose(delta,pose)
	level.actor.rotation=0
	level.actor.modulate.a=1.0-smoothstep(0.52,0.83,failure_time) if failure_time>0 else 1.0
	level.actor.apply_surface_contact(delta,level.player,pose.grounded)
	level.art.sync(delta,level.camera_x,true)
	level.log_bridge.art.sync(delta,Vector2(level.camera_x,level.camera_y),feet().y< -3450)
	art.sync(delta,true)
	if level.iris!=null:level.iris.call("set_state",smoothstep(0.5,0.84,failure_time),Vector2(540,500))
