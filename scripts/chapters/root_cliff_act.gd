extends Node2D

# Continuous world geometry from bridge to C. Only recovery/DEBUG moves the actor.
const Art=preload("res://scripts/chapters/root_cliff_art.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const X:=[-2220,-1940,-1710,-1480,-1250,-1020,-790,-560,-790,-1020,-1250,-1480,-1710,-1940,-1710,-1480,-1250,-1020,-790,-560,-790,-1020,-1250,-1480,-1710,-1480,-1250,-1020,-790,-560,-790,-1020,-1250,-1480,-1250,-1020,-790,-560,-790,-560,-310]
const SAVES:=[0,10,20,30,38]
const FRAGILE:=[4,5,13,17,18,25,26,33,35]
const VENTS:=[8,16,24,32,37]
var level
var art:Node2D
var active:=false
var in_c_zone:=false
var enabled:=true
var platforms:Array[StaticBody2D]=[]
var floor_body:StaticBody2D
var age:Dictionary={}
var clock:=0.0
var failure_time:=0.0
var checkpoint_index:=0
var last_landing:=0
var fall_y:=-3715.0
var was_grounded:=true
var deaths:=0
var warning_sound:AudioStreamPlayer
var fissure_sound:AudioStreamPlayer

static func landing(i:int)->Vector2:return Vector2(X[i],-3715+i*100)
static func width(i:int)->float:
	if i==0:return 260.0
	return 210.0 if i in SAVES else (132.0 if i in FRAGILE else 160.0)

func _ready()->void:
	for i in X.size():
		var body:=StaticBody2D.new()
		body.position=landing(i)
		body.collision_layer=1
		var shape:=CollisionShape2D.new()
		var rect:=RectangleShape2D.new()
		rect.size=Vector2(width(i),18)
		shape.shape=rect
		shape.position.y=9
		shape.one_way_collision=true
		body.add_child(shape)
		add_child(body)
		platforms.append(body)
	floor_body=platforms[0]
	warning_sound=AudioStreamPlayer.new()
	warning_sound.stream=preload("res://assets/audio/level01/tree_creak_03.mp3")
	warning_sound.volume_db=-24
	add_child(warning_sound)
	fissure_sound=AudioStreamPlayer.new()
	fissure_sound.stream=preload("res://assets/audio/level01/cliff_wind.mp3")
	fissure_sound.volume_db=-60
	add_child(fissure_sound)
	art=Art.new()
	art.route=self
	add_child(art)

func reset()->void:
	active=false
	in_c_zone=false
	checkpoint_index=0
	last_landing=0
	failure_time=0
	clock=0
	age.clear()
	set_enabled(true)

func set_enabled(value:bool)->void:
	enabled=value
	for body in platforms:body.collision_layer=1 if value else 0
	if not value:
		active=false
		fissure_sound.stop()
	if art!=null:art.sync(0)

func feet()->Vector2:return level.player.position+Vector2(13,54)
func camera_target_y()->float:
	var look_down:=smoothstep(-3715.0,-3350.0,feet().y)*180.0
	return lerpf(minf(0,level.player.position.y-500+look_down),0,smoothstep(0,300,feet().y))

func enter(place:=false)->void:
	active=true
	in_c_zone=false
	level.log_bridge.active=false
	level.rope_ladder.stop()
	level.actor.finish_rope_ladder()
	level.scene1.cut=level.scene1.Cut.DONE
	level.scene1.intro_time=99
	level.intro_time=0
	level.climb_time=-1
	fall_y=feet().y
	was_grounded=level.player.is_on_floor()
	if place:restore_checkpoint()

func restore_checkpoint()->void:
	failure_time=0
	age.clear()
	for body in platforms:body.collision_layer=1 if enabled else 0
	level.player.position=landing(checkpoint_index)-Vector2(13,55)
	level.player.velocity=Vector2.ZERO
	level.jump_buffer=0
	level.jump_windup_left=0
	level.coyote=0
	level.player.collision_mask=11
	fall_y=feet().y
	last_landing=checkpoint_index
	was_grounded=true
	level.camera_x=level.player.position.x-525
	level.camera_y=camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)

func vent_phase(i:int)->float:return fposmod(clock+float(i)*0.73,4.8)
func vent_active(i:int)->bool:return vent_phase(i)>=1.1 and vent_phase(i)<2.35
func vent_position(i:int)->Vector2:return landing(i)+Vector2(-width(i)*0.5+26,0)
func fail()->void:
	if failure_time>0:return
	failure_time=0.001
	deaths+=1
	level.player.velocity=Vector2.ZERO

func tick(delta:float)->bool:
	if not enabled:return false
	clock+=delta
	if in_c_zone:
		fissure_sound.stop()
		level.log_bridge.art.sync(delta,Vector2(level.camera_x,level.camera_y),true)
		art.sync(delta)
		return false
	if not active:
		art.sync(delta)
		if level.log_bridge.reached_bank and feet().x>-2350 and feet().y<-3500:enter()
		else:return false
	if failure_time>0:
		failure_time+=delta
		if failure_time>=1.0:restore_checkpoint()
		present(delta)
		return true
	level.scene1.tick_low_stance(delta)
	var direction:float=Input.get_axis("move_left","move_right")
	if absf(direction)>0.1:level.facing=signf(direction)
	level._update_player(delta,direction,0)
	var loudness:=0.0
	for i in VENTS:
		var distance:float=feet().distance_to(vent_position(i))
		var phase:float=vent_phase(i)
		var pressure:float=0.3+phase*0.5 if phase<1.1 else (1.0 if phase<2.35 else 0.0)
		loudness=maxf(loudness,pressure*(1.0-smoothstep(80.0,450.0,distance)))
	if loudness>0.01:
		if not fissure_sound.playing:fissure_sound.play()
		fissure_sound.volume_db=lerpf(-42.0,-21.0,loudness)
	else:fissure_sound.stop()
	var p:=feet()
	var grounded:bool=level.player.is_on_floor()
	if grounded:
		if not was_grounded and p.y-fall_y>level.LETHAL_FALL:fail()
		fall_y=p.y
		for i in platforms.size():
			if absf(p.y-landing(i).y)<8 and absf(p.x-landing(i).x)<width(i)*0.5+12:
				last_landing=i
				if i in SAVES:checkpoint_index=maxi(checkpoint_index,i)
				if i in FRAGILE and not age.has(i):
					age[i]=0.001
					warning_sound.play()
	else:fall_y=minf(fall_y,p.y)
	was_grounded=grounded
	for i in age:
		age[i]+=delta
		if age[i]>=0.95:platforms[i].collision_layer=0
	for i in VENTS:
		var vent:=vent_position(i)
		if vent_active(i) and Rect2(vent-Vector2(21,100),Vector2(42,104)).intersects(Rect2(level.player.position,Vector2(26,54))):fail()
	if p.y>landing(mini(last_landing+2,X.size()-1)).y+190:fail()
	if grounded and p.x>-210 and p.y>290:
		active=false
		in_c_zone=true
		level.checkpoint=0
		# Forest saves park the boat at C's far bank; restore puzzle props only.
		level.crate.position=level.CRATE_START
		level.crate.velocity=Vector2.ZERO
		level.beached=false
		level.landed=false
		level.floating=false
		level.fan_owned=false
		level.fan_on_tree=true
		level.fan_revealed=true
		level.fan_left_behind=false
		level.air_top_y=level.player.position.y
		return false
	present(delta)
	return true

func present(delta:float)->void:
	level._update_camera(delta)
	level.camera.offset=Vector2.ZERO
	var pose:=Pose.new()
	var action:StringName=Pose.ACTION_NONE
	var progress:=0.0
	if failure_time>0:
		action=Pose.ACTION_FALL_IMPACT
		progress=clampf(failure_time/0.6,0,1)
	elif level.scene1.low_stance.active():
		var low:Dictionary=level.scene1.low_stance.pose_info()
		action=low.action
		progress=low.progress
	pose.apply({"feet":feet(),"velocity":level.player.velocity,"grounded":level.player.is_on_floor(),"facing":level.facing,"action":action,"action_progress":progress,"visual_scale":Pose.HOOD_VISUAL_SCALE,"fog_blur":level.ACTOR_EDGE_SOFTNESS,"jump_windup":1-level.jump_windup_left/Pose.HOOD_JUMP_WINDUP if level.jump_windup_left>0 else -1.0})
	level.actor.sync_pose(delta,pose)
	level.actor.modulate.a=1
	level.actor.rotation=0
	level.actor.apply_surface_contact(delta,level.player,pose.grounded)
	level.art.sync(delta,level.camera_x,true)
	level.log_bridge.art.sync(delta,Vector2(level.camera_x,level.camera_y),true)
	art.sync(delta)
	if level.iris!=null:level.iris.call("set_state",smoothstep(0.6,0.95,failure_time),Vector2(540,500))
