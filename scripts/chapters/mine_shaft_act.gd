extends Node2D
# The working mechanism is spatial: a two-level maintenance loop, a loaded
# weighbridge, a load-bearing lock pin, and a clutch/points linkage.
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const UPPER:=-3170.0
const LOWER:=-2940.0
const TRAY_X:=-1640.0
const CAGE_X:=-1040.0
const LADDER_X:=-1470.0
const PIN_X:=-1240.0
const POINTS_X:=-1210.0
const PROBE_X:=-1820.0
const HATCH:=Vector2(-2010,-1900)
const EXIT_Y:=-540.0
var route
var art:Node2D
var bodies:Array[PhysicsBody2D]=[]
var hatch:StaticBody2D
var gate:StaticBody2D
var cage:AnimatableBody2D
var jam_body:AnimatableBody2D
var fragile_body:StaticBody2D
var cage_y:=UPPER-78.0
var tray_depth:=0.0
var jammed:=true
var inspected:=false
var jam_progress:=0.0
var pin_locked:=false
var routed:=false
var descending:=false
var arrived:=false
var descent_time:=0.0
var cart_on_cage:=false
var holding_cart:=false
var grip_side:=1.0
var grip_age:=0.0
var grip_distance:=0.0
var operation:=""
var operation_age:=0.0
var operation_progress:=0.0
var refusal:=0.0
var clock:=0.0
var ladder:=false
var ladder_frame:=100.0
var checkpoint:=0
var fall_y:=UPPER
var checkpoint_cart:=-2070.0
var fragile_age:=-1.0
var touched_exit:=false
var brake_feedback:=0.0
var hazard_hits:=0

func _ready()->void:
	_build_collision()
	art=preload("res://scripts/chapters/mine_shaft_art.gd").new()
	art.shaft=self
	add_child(art)
	reset()

func _platform(a:Vector2,b:Vector2,depth:float=28.0)->StaticBody2D:
	var body:StaticBody2D=route._surface(PackedVector2Array([a,b,b+Vector2(0,depth),a+Vector2(0,depth)]),true)
	bodies.append(body)
	return body

func _box(at:Vector2,size:Vector2,moving:bool=false)->PhysicsBody2D:
	var body:PhysicsBody2D=AnimatableBody2D.new() if moving else StaticBody2D.new()
	if moving:body.sync_to_physics=false
	body.position=at;body.collision_layer=1;body.collision_mask=0
	var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=size;shape.shape=rect
	body.add_child(shape);add_child(body);bodies.append(body)
	return body

func _build_collision()->void:
	_platform(Vector2(-2180,UPPER),Vector2(HATCH.x,UPPER))
	hatch=_platform(Vector2(HATCH.x,UPPER),Vector2(HATCH.y,UPPER),12)
	_platform(Vector2(HATCH.y,UPPER),Vector2(-1130,UPPER))
	# The ramp is physically below the hatch, with room to stand throughout.
	_platform(Vector2(-1990,UPPER+8),Vector2(-1760,LOWER))
	_platform(Vector2(-1760,LOWER),Vector2(-1120,LOWER))
	gate=_box(Vector2(-1370,LOWER-54),Vector2(15,108))
	jam_body=_box(Vector2(-1650,LOWER-22),Vector2(48,44),true)
	cage=_box(Vector2(CAGE_X,UPPER),Vector2(170,16),true)
	# Continuous mine shaft to the lower forest elevation; collision is limited
	# to its actual cheeks, never a hidden block in the playable opening.
	_box(Vector2(-1165,-1810),Vector2(20,2210))
	_box(Vector2(-925,-1880),Vector2(20,2350))
	_platform(Vector2(-970,EXIT_Y),Vector2(-820,EXIT_Y+48))
	fragile_body=_platform(Vector2(-760,EXIT_Y+115),Vector2(-680,EXIT_Y+115),12)
	_platform(Vector2(-590,-335),Vector2(-440,-327))
	_platform(Vector2(-740,-245),Vector2(-620,-237))
	_platform(Vector2(-510,-155),Vector2(-380,-147))
	_platform(Vector2(-660,-65),Vector2(-550,-57))
	_platform(Vector2(-450,25),Vector2(-320,33))
	_platform(Vector2(-600,115),Vector2(-470,123))
	_platform(Vector2(-410,205),Vector2(-280,213))
	_platform(Vector2(-220,300),Vector2(-180,310),90)

func reset()->void:
	jammed=true;inspected=false;jam_progress=0;pin_locked=false;routed=false
	descending=false;arrived=false;descent_time=0;cart_on_cage=false
	cage_y=UPPER-78;tray_depth=0;holding_cart=false;ladder=false
	operation="";operation_age=0;operation_progress=0;refusal=0
	checkpoint=0;fall_y=UPPER;fragile_age=-1;touched_exit=false;hazard_hits=0
	checkpoint_cart=-2070
	_sync_bodies()

func cancel_operation()->void:
	holding_cart=false;operation="";operation_age=0;ladder=false

func set_enabled(value:bool)->void:
	for body in bodies:body.collision_layer=1 if value else 0
	visible=value
	if value:_sync_bodies()

func owns_player()->bool:
	return route.feet().x>-2150 or ladder or holding_cart or descending or arrived

func cart_at()->Vector2:
	if cart_on_cage:return Vector2(CAGE_X,cage_y)
	var x:float=route.mine_trial.cart_x
	if x<-2180:return Vector2(x,route.mine_floor_y(x))
	return Vector2(x,UPPER+(tray_depth if absf(x-TRAY_X)<52 else 0.0))

func _sync_bodies()->void:
	if not route.enabled or not route.shaft_preview:return
	hatch.collision_layer=0 if inspected and jammed else 1
	gate.collision_layer=0 if tray_depth>18 or pin_locked or routed else 1
	jam_body.collision_layer=1 if jammed else 0
	jam_body.position=Vector2(-1650+jam_progress*95,LOWER-22+jam_progress*5)
	cage.position=Vector2(CAGE_X,cage_y+8)
	fragile_body.collision_layer=0 if fragile_age>0.75 else 1

func _near(x:float,y:float,radius:float=37)->bool:
	return absf(route.feet().x-x)<radius and absf(route.feet().y-y)<30

func _start(kind:String)->void:
	operation=kind;operation_age=0;operation_progress=0

func _interact()->void:
	if descending or operation!="" or ladder:return
	if holding_cart:holding_cart=false;return
	if _near(PROBE_X,UPPER):_start("probe");return
	if jammed and _near(-1693,LOWER,45):_start("jam");return
	if _near(PIN_X,LOWER):
		if pin_locked:
			if absf(route.mine_trial.cart_x-TRAY_X)<52:pin_locked=false
			else:refusal=0.7
		elif tray_depth>20:_start("pin")
		else:refusal=0.7
		return
	if _near(POINTS_X,UPPER):
		if pin_locked and not cart_on_cage and absf(route.mine_trial.cart_x-TRAY_X)>72:_start("points")
		else:refusal=0.7
		return
	if _near(CAGE_X,cage_y,68) and routed and cart_on_cage:
		_start("release");return
	if not jammed and route.mine_trial.broken and route.mine_trial.cart_speed<0.1:
		var c:=cart_at()
		if absf(route.feet().x-c.x)<95 and absf(route.feet().y-c.y)<60 and not cart_on_cage:
			grip_side=signf(c.x-route.feet().x)
			if grip_side==0:grip_side=1
			level().facing=grip_side;holding_cart=true;grip_age=0;grip_distance=0

func level():return route.level

func tick(delta:float)->bool:
	clock+=delta;refusal=maxf(0,refusal-delta)
	var loaded:bool=absf(route.mine_trial.cart_x-TRAY_X)<52
	var tray_target:float=26.0 if (loaded and not jammed) or pin_locked else 0.0
	tray_depth=move_toward(tray_depth,tray_target,28*delta)
	var old_y:=cage_y
	if not descending and not arrived:
		var target:float=UPPER if routed else UPPER-78-tray_depth*3.2
		cage_y=move_toward(cage_y,target,52*delta)
	elif descending:
		_tick_descent(delta)
	_sync_bodies()
	if not owns_player():return false
	if route.failure_time>0:return false
	if descending or arrived:
		if absf(route.feet().x-CAGE_X)<100 and absf(route.feet().y-old_y)<28:
			level().player.position.y+=cage_y-old_y
			fall_y=cage_y;route.fall_origin=cage_y
	if Input.is_action_just_pressed("interact"):_interact()
	if operation!="":return _tick_operation(delta)
	if _tick_ladder(delta):return true
	if holding_cart:return _tick_cart(delta)
	if level().climb_time>=0:
		level()._update_climb(delta);fall_y=route.feet().y;return true
	level().scene1.tick_low_stance(delta)
	var direction:float=Input.get_axis("move_left","move_right")
	if absf(direction)>0.1:level().facing=signf(direction)
	level()._update_player(delta,direction,0)
	var p:Vector2=route.feet()
	if level().player.is_on_floor():
		if p.y-fall_y>level().LETHAL_FALL:route.fail();return true
		fall_y=p.y
	else:
		fall_y=minf(fall_y,p.y)
		if p.y-fall_y>level().LETHAL_FALL:route.fail();return true
	route.fall_origin=fall_y;route.was_grounded=level().player.is_on_floor()
	if p.y>LOWER+120 and not descending and not arrived:route.fail()
	if arrived:
		if _near(-720,EXIT_Y+115,45) and level().player.is_on_floor() and fragile_age<0:fragile_age=0
		if fragile_age>=0:fragile_age+=delta
		if p.x>-960 and p.y>EXIT_Y-30:checkpoint=3
		if p.x>-210 and p.y>290:
			route._reach_c_zone_at(p)
			return true
	return true

func _tick_operation(delta:float)->bool:
	if not Input.is_action_pressed("interact") and operation_age<0.34:
		operation="";return true
	operation_age+=delta
	var duration:float=1.4 if operation=="jam" else 0.95
	operation_progress=smoothstep(0.25,duration,operation_age)
	level().player.velocity=Vector2(0,200)
	if operation=="jam":
		level().facing=1
		jam_progress=operation_progress
		var target:float=-1693+jam_progress*95
		level().player.velocity.x=clampf((target-route.feet().x)/maxf(delta,0.001),0,90)
	level().player.move_and_slide()
	if operation_age<duration:return true
	match operation:
		"probe":inspected=true
		"jam":jammed=false;jam_progress=1;checkpoint=1
		"pin":pin_locked=true
		"points":routed=not routed
		"release":
			if cart_on_cage and routed:
				descending=true;descent_time=0;checkpoint=2;checkpoint_cart=CAGE_X
	operation="";operation_age=0
	return true

func _tick_cart(delta:float)->bool:
	var direction:float=Input.get_axis("move_left","move_right")
	grip_age+=delta
	if not Input.is_action_pressed("interact"):
		holding_cart=false;return true
	level().facing=grip_side
	var c:=cart_at()
	var target:float=c.x-grip_side*54
	var speed:float=direction*52.0 if grip_age>0.35 else 0.0
	var min_x:float=-2105.0
	var max_x:float=CAGE_X if routed and absf(cage_y-UPPER)<2 else -1170.0
	var x:float=clampf(route.mine_trial.cart_x+speed*delta,min_x,max_x)
	if grip_age<=0.35:
		level().player.velocity.x=clampf((target-route.feet().x)/maxf(delta,0.001),-85,85)
	else:
		grip_distance+=absf(x-route.mine_trial.cart_x)
		route.mine_trial.cart_x=x
		level().player.velocity.x=(x-c.x)/maxf(delta,0.001)
	level().player.velocity.y=300
	level().player.move_and_slide()
	fall_y=route.feet().y;route.fall_origin=fall_y
	if routed and x>CAGE_X-12 and absf(cage_y-UPPER)<2:
		cart_on_cage=true;route.mine_trial.cart_x=CAGE_X;holding_cart=false
	return true

func _tick_ladder(delta:float)->bool:
	var vertical:float=Input.get_axis("climb_up","climb_down")
	var p:Vector2=route.feet()
	if not ladder:
		if absf(p.x-LADDER_X)>26 or p.y<UPPER-8 or p.y>LOWER+8 or absf(vertical)<0.1:return false
		if vertical<0 and p.y<=UPPER+3:return false
		if vertical>0 and p.y>=LOWER-3:return false
		ladder=true;level().actor.begin_rope_ladder()
	level().player.velocity=Vector2.ZERO
	var y:=clampf(p.y+vertical*85*delta,UPPER,LOWER)
	level().player.position=Vector2(LADDER_X-13,y-54)
	ladder_frame=96+fmod(clock*absf(vertical)*48,72)
	fall_y=y;route.fall_origin=y
	if y<=UPPER or y>=LOWER:
		ladder=false;level().actor.finish_rope_ladder()
		# Move above the one-way landing before restoring gravity.
		if y<=UPPER:level().player.position.y-=2
	return true

func _tick_descent(delta:float)->void:
	descent_time+=delta
	var speed:float=lerpf(52,132,smoothstep(0,7,descent_time))
	for beam in [-2480.0,-1580.0]:
		var crossing:bool=cage_y<beam+80 and cage_y+speed*delta>=beam+80
		if crossing and not level().scene1.low_stance.active():
			hazard_hits+=1;route.fail();return
	cage_y=minf(EXIT_Y, cage_y+speed*delta)
	if cage_y>=EXIT_Y:
		descending=false;arrived=true;brake_feedback=0.6

func apply_pose(pose)->void:
	if ladder:
		pose.action=&"rope_ladder";pose.action_progress=ladder_frame/240.0
		pose.grounded=false;pose.visual_scale=Pose.HOOD_VISUAL_SCALE
	elif holding_cart:
		pose.action=&"grip_engage" if grip_age<0.35 else (&"pull" if Input.get_axis("move_left","move_right")*grip_side<0 else &"push")
		if grip_age>=0.35 and absf(Input.get_axis("move_left","move_right"))<0.1:pose.action=&"grip_hold"
		pose.action_progress=minf(1,grip_age/0.35)
		level().actor.grip_distance=grip_distance
	elif operation!="":
		pose.action=&"grip_engage" if operation_age<0.25 else (&"push" if operation=="jam" else &"lever")
		pose.action_progress=operation_age/0.25 if operation_age<0.25 else operation_progress
		pose.effort=operation_progress

func respawn()->bool:
	if checkpoint==0:return false
	cancel_operation();fall_y=UPPER
	if checkpoint==1:
		# Preserve the solved mechanical state; a ladder on the safe side is
		# always accessible even with the weighbridge locked.
		level().player.position=Vector2(-1780-13,UPPER-55)
		fall_y=UPPER
	elif checkpoint==2:
		descending=false;arrived=false;cage_y=UPPER;routed=true;pin_locked=true
		cart_on_cage=true;route.mine_trial.cart_x=CAGE_X;descent_time=0
		level().player.position=Vector2(CAGE_X-13,UPPER-55)
		# The cage lever starts a fresh controlled attempt.
		fall_y=UPPER
		fragile_age=-1
	else:
		descending=false;arrived=true;cage_y=EXIT_Y
		level().player.position=Vector2(-890-13,-515-55)
		fall_y=-515;fragile_age=-1
	level().player.velocity=Vector2.ZERO
	route.fall_origin=fall_y;_sync_bodies()
	return true
