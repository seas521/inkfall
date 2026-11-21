extends Node2D
# Local escape beat. The bearing pier fails behind the cart; a real wheel
# chock, not a permanent x limit, stops it before the rail break.
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const EDGE_X:=-1014.0
const RECOVERY_LEFT:=-1420.0
const SAFE_X:=-2340.0
const COLLAPSE_LEFT:=-3090.0
const CRUSH_TIME:=1.12
const CART_LAYER:=32
const BRAKE_RUN:=88.0
const CHOCK_OFFSET:=56.0
const HIT_FALL_TIME:=.82
const HIT_SETTLE_TIME:=.68
const HIT_TOTAL:=HIT_FALL_TIME+HIT_SETTLE_TIME
const MAX_SPARKS:=72
const ROOF=preload("res://assets/art/descent/mine-cart-escape-v1/roof-fragments.png")
const Pendant=preload("res://scripts/chapters/mine_pendant.gd")
const Chock=preload("res://scripts/chapters/mine_cart_chock_art.gd")
var trial
var route
var started:=false
var saved:=false
var crushed:=false
var riding:=false
var ride_age:=0.0
var dismount_pending:=false
var seat_start:=Vector2.ZERO
var stop_impulse:=0.0
var braking:=false
var brake_age:=-1.0
var brake_duration:=.55
var brake_start:=0.0
var brake_speed:=0.0
var skid_loss:=0.0
var sparks:Array[Dictionary]=[]
var spark_carry:=0.0
var spark_serial:=0
var spark_draw:Node2D
var peak_sparks:=0
var stumble_age:=-1.0
var hit_age:=-1.0
var stumble_facing:=1.0
var crush_cause:StringName=&""
var chase_lamp:Node2D
var timber_supports:Array[Node2D]=[]
var floor_polygon:CollisionPolygon2D
var floor_home:=PackedVector2Array()
var floor_pads:Array[Dictionary]=[]
var floor_pad_updates:=0
var rubble_front:=-100000.0
var tools_home:=Vector2.ZERO
var launch_age:=0.0
var chock_present:=true
var stopped_once:=false
var stop_age:=-1.0
var falling:=false
var air_y:=0.0
var air_vy:=0.0
var grip_side:=-1.0
var grip_motion:=0.0
var pull_age:=0.0
var pull_distance:=0.0
var cart_shoving:=false
var shove_support_grace:=0.0
var shove_direction:=1.0
var shove_jump_lock:=0.0
var roof:Array[Dictionary]=[]
var collapse_draw:Node2D
var end_fill:StaticBody2D
var rubble_body:StaticBody2D
var chock_body:StaticBody2D
var reset_count:=0
var end_lamp:Node2D
var tool_parts:Array[Dictionary]=[]
var miner_home:=Vector2.ZERO
var miner_rotation_home:=0.0
var miner_pivot:=Vector2.ZERO

func _ready()->void:
	route=trial.route
	end_lamp=Pendant.new();end_lamp.z_index=2
	end_lamp.position=Vector2(trial.PARK_X-8,trial.ground(trial.PARK_X-8)-165)-Pendant.BULB_OFFSET
	add_child(end_lamp)
	chase_lamp=Pendant.new();chase_lamp.z_index=2
	chase_lamp.position=Vector2(-2160,trial.ground(-2160)-165)-Pendant.BULB_OFFSET
	add_child(chase_lamp)
	# Hang from the authored rock roof, with one continuous swinging cable.
	# Preserve the bulb's resting height and its existing light pool.
	for fixture in [chase_lamp,end_lamp]:
		var bulb_y:float=fixture.position.y+Pendant.BULB_OFFSET.y
		fixture.position.y=route.art.chase_chamber.ceiling_y(fixture.position.x)-14.0
		fixture.fit_suspension(bulb_y-fixture.position.y)
	floor_polygon=route.platforms[-1].get_child(0)
	# The mine is solid ground, not a one-way branch. Rebuilding a one-way
	# polygon during subsidence can let a stationary capsule pass through it.
	floor_polygon.one_way_collision=false
	floor_polygon.disabled=true
	# Prebuilt solid pads follow the ground by transform. Reassigning the
	# large polygon decomposed it into new convex shapes every physics tick.
	var pad_edges:Array[float]=[]
	for i in 49:pad_edges.append(lerpf(-3205,route.MINE_PREVIEW_END,float(i)/48))
	for x in range(-1620,-1100,8):pad_edges.append(float(x))
	pad_edges.sort()
	for i in pad_edges.size()-1:
		var a:float=pad_edges[i]
		var b:float=pad_edges[i+1]
		if b-a<.01:continue
		var pad:=CollisionShape2D.new();var rect:=RectangleShape2D.new()
		rect.size=Vector2(b-a+1.0 if a>=-1620 and b<=-1100 else (b-a)*1.045+4,420);pad.shape=rect
		floor_polygon.get_parent().add_child(pad)
		floor_pads.append({"node":pad,"a":a,"b":b,"last":Vector2.INF})
	floor_home=PackedVector2Array()
	for i in 129:
		var x:float=lerpf(-3205,route.MINE_PREVIEW_END,i/128.0)
		var y:float=lerpf(-3268,-3271,clampf((x+3205)/40,0,1)) if x< -3165 else route.mine_floor_base_y(x)
		floor_home.append(Vector2(x,y))
	floor_home.append(Vector2(EDGE_X,-2500));floor_home.append(Vector2(-3205,-2500))
	_build_tool_layers()
	for data in [[-2630.0,-.10],[-2110.0,1.55]]:
		var support:=preload("res://scripts/chapters/mine_breakable_support.gd").new()
		add_child(support);support.build(trial,data[0],data[1]);timber_supports.append(support)
	collapse_draw=Node2D.new();collapse_draw.z_index=5
	add_child(collapse_draw);collapse_draw.draw.connect(_draw_collapse)
	collapse_draw.material=ShaderMaterial.new()
	collapse_draw.material.shader=preload("res://assets/shaders/mine_roof_silhouette.gdshader")
	end_fill=route._surface(PackedVector2Array([Vector2(route.MINE_PREVIEW_END,trial.ground(route.MINE_PREVIEW_END)),Vector2(EDGE_X,trial.ground(EDGE_X)),Vector2(EDGE_X,-2500),Vector2(route.MINE_PREVIEW_END,-2500)]),true)
	rubble_body=StaticBody2D.new();rubble_body.collision_layer=0
	var rubble_shape:=CollisionShape2D.new();var rubble_box:=RectangleShape2D.new()
	rubble_box.size=Vector2(SAFE_X-COLLAPSE_LEFT,210)
	rubble_shape.shape=rubble_box
	rubble_shape.position=Vector2((SAFE_X+COLLAPSE_LEFT)*.5,trial.ground(SAFE_X)-90)
	rubble_body.add_child(rubble_shape);add_child(rubble_body)
	chock_body=StaticBody2D.new();chock_body.collision_layer=1
	# A bevel joins the wheel contact to the rock top. A square collider
	# leaves a sub-capsule-width crack that reports only side contacts.
	var shape:=CollisionPolygon2D.new()
	shape.polygon=PackedVector2Array([Vector2(-25,13.5),Vector2(-25,0),Vector2(-10,-13.5),Vector2(10,-13.5),Vector2(15,-7),Vector2(15,13.5)])
	chock_body.position=Vector2(trial.PARK_X-BRAKE_RUN+CHOCK_OFFSET,trial.ground(trial.PARK_X-BRAKE_RUN+CHOCK_OFFSET)-14)
	chock_body.add_child(shape);add_child(chock_body)
	spark_draw=Node2D.new();spark_draw.z_index=7
	var spark_ink:=ShaderMaterial.new();spark_ink.shader=preload("res://assets/shaders/mine_friction_spark.gdshader")
	spark_draw.material=spark_ink;add_child(spark_draw);spark_draw.draw.connect(_draw_sparks)
	reset()

func enabled()->bool:return not route.shaft_preview

func reset()->void:
	started=false;saved=false;crushed=false;riding=false;ride_age=0;dismount_pending=false;launch_age=0;seat_start=Vector2.ZERO;stop_impulse=0
	route.art.chamber.set_collapse(-1)
	route.art.chase_chamber.set_collapse(-1)
	chase_lamp.restore_fixture()
	stumble_age=-1;hit_age=-1;stumble_facing=1;crush_cause=&""
	_sync_floor_pads(true)
	rubble_front=-100000
	braking=false;brake_age=-1;skid_loss=0;sparks.clear();spark_carry=0;spark_serial=0;peak_sparks=0
	if spark_draw!=null:spark_draw.queue_redraw()
	chock_present=true;stopped_once=false;stop_age=-1;falling=false;air_y=0;air_vy=0
	pull_age=0;pull_distance=0;cart_shoving=false;shove_support_grace=0;roof.clear()
	for i in 8:
		var x:float=lerpf(-2900,SAFE_X-43,float(i)/7)
		var at:=Vector2(x,route.art.chamber.ceiling_y(x)-14+sin(i*2.3)*17)
		var size:float=[155.0,95.0,140.0,90.0,150.0,105.0,135.0,88.0][i]
		roof.append({"home":at,"p":at,"size":size,"delay":0.40+float(i)*.035,"age":0.0,"vy":0.0,"angle":sin(i*3.4)*.35,"spin":(-1.0 if i%2==0 else 1.0)*(0.6+float(i%3)*.45),"landed":false,"id":i})
	for i in 4:
		var x:float=[-2140.0,-1930.0,-1720.0,-1550.0][i]
		var at:=Vector2(x,route.art.chase_chamber.ceiling_y(x)-12)
		roof.append({"home":at,"p":at,"size":105.0+float(i%2)*24,"delay":1.6+(x+2340)/310.0,"age":0.0,"vy":0.0,"angle":-.2,"spin":-.7 if i%2 else .9,"landed":false,"id":i+8})
	_restore_corner()
	for support in timber_supports:support.reset()

	rubble_body.collision_layer=0
	chock_body.collision_layer=1
	_set_chock_x(trial.PARK_X-BRAKE_RUN+CHOCK_OFFSET)
	queue_redraw();collapse_draw.queue_redraw()

func restore_attempt()->Variant:
	if not enabled():return null
	if saved:
		crushed=false;stumble_age=-1;hit_age=-1;crush_cause=&"";trial.operation="";trial.cart_speed=0
		if trial.gap!=null:return trial.gap.restore()
		if falling or trial.cart_x>trial.PARK_X:
			falling=false;trial.cart_x=trial.PARK_X;chock_present=true;chock_body.collision_layer=1
		var x:float=clampf(trial.cart_x-75,RECOVERY_LEFT+45,trial.PARK_X-60)
		return Vector2(x,trial.ground(x))
	if started:
		reset_count+=1
		trial.reset()
		started=true
		return Vector2(trial.GRIP_X-12,trial.ground(trial.GRIP_X-12))
	return null

func is_riding()->bool:
	if not enabled() or route.failure_time>0 or trial.operation=="recover" or cart_shoving:return false
	var at:=cart_position()
	var feet:Vector2=route.feet()
	if not route.level.player.is_on_floor() or absf(feet.x-at.x)>=44 or absf(feet.y-(at.y-47))>=7 or route.level.player.velocity.y< -1:return false
	if riding:return true
	# Accept the rounded capsule landing on either rim, but only when the
	# actual cart roof supports it. A side touch/nearby rock is not boarding.
	for i in route.level.player.get_slide_collision_count():
		var hit=route.level.player.get_slide_collision(i)
		if hit.get_collider()==trial.cart_body and hit.get_normal().dot(Vector2.UP)>.7:return true
	return false

func cart_position()->Vector2:
	if trial.gap!=null and saved:return trial.gap.cart_position()
	return Vector2(trial.cart_x,air_y if falling else trial.ground(trial.cart_x))

func wants_roll()->bool:
	if saved and trial.gap!=null:return trial.gap.coast and trial.operation!="recover"
	return trial.launched and launch_age>0.52 and trial.operation!="recover" and (not stopped_once or not chock_present)

func update_motion(delta:float,was_riding:bool,previous:Vector2)->bool:
	if not enabled():
		visible=false;end_fill.collision_layer=0;chock_body.collision_layer=0;rubble_body.collision_layer=0
		return false
	sync_enabled(route.enabled and not route.in_c_zone)
	end_lamp.update_swing(delta)
	chase_lamp.update_swing(delta)
	_update_lighting()
	end_fill.collision_layer=1 if visible else 0
	chock_body.collision_layer=1 if visible and chock_present else 0
	if trial.launched:started=true;launch_age+=delta
	if stop_age>=0:stop_age+=delta
	_tick_sparks(delta)
	if saved and trial.gap!=null:
		trial.gap.cart_flight(delta)
	elif falling:
		air_vy+=1000*delta;air_y+=air_vy*delta
	elif trial.cart_x>EDGE_X+34:
		falling=true;air_y=trial.ground(EDGE_X);air_vy=0
	var at:=cart_position()
	# Support/transport and sitting are separate states. Once a passenger
	# asks to jump, a brief roof contact must never centre or reseat them.
	if was_riding and (Input.is_action_just_pressed("jump") or route.level.jump_windup_left>0):dismount_pending=true
	if dismount_pending:
		var clear_side:bool=absf(route.feet().x-at.x)>56
		var landed_elsewhere:bool=route.level.player.is_on_floor() and absf(route.feet().y-(at.y-47))>16
		if clear_side or landed_elsewhere:dismount_pending=false
	if was_riding:
		route.level.player.position+=at-previous
		# Bring the physical passenger toward the same seat as the drawing.
		# Otherwise jumping out would expose the old off-centre capsule root.
		if not dismount_pending and not Input.is_action_just_pressed("jump") and route.level.jump_windup_left<=0 and (ride_age<.34 or absf(Input.get_axis("move_left","move_right"))<.1):
			route.level.player.position.x=move_toward(route.level.player.position.x,at.x-22,140*delta)
		route.fall_origin=route.feet().y
	trial.cart_body.position=at
	if was_riding and not riding:seat_start=route.feet()-at
	riding=was_riding
	ride_age=ride_age+delta if was_riding else 0.0
	if trial.broken:
		_update_collapse(delta)
		var p:Vector2=route.feet()
		# Sweep real falling fragments against the exposed actor. Completed
		# collapse also covers its rubble top; standing above it is not immunity.
		var stone_hit:=hits_falling_stone()
		var roof_hit:bool=roof_hazard_at(p.x) and p.y<trial.ground(p.x)+100
		if (stone_hit or roof_hit) and route.failure_time<=0:
			begin_crush(&"falling_stone" if stone_hit else &"collapsed_roof")
			return true
		if stopped_once and not saved and route.failure_time<=0 and route.level.player.is_on_floor() and route.feet().x>trial.PARK_X-150 and route.feet().x<EDGE_X+5 and absf(route.feet().y-trial.ground(route.feet().x))<110:
			saved=true
	queue_redraw();collapse_draw.queue_redraw()
	return false

func start_braking()->void:
	if braking or stopped_once:return
	braking=true;brake_age=0;brake_start=trial.cart_x;brake_speed=trial.cart_speed
	brake_duration=2.0*maxf(1,trial.PARK_X-brake_start)/maxf(1,brake_speed)
	stop_impulse=clampf(brake_speed/300.0,.3,1.1)
	trial.shake=maxf(trial.shake,.17)
	for i in 12:_emit_spark(true)

func advance_braking(delta:float)->void:
	brake_age=minf(brake_duration,brake_age+delta)
	var t:=brake_age
	var a:float=brake_speed/brake_duration
	trial.cart_x=brake_start+brake_speed*t-.5*a*t*t
	trial.cart_speed=maxf(0,brake_speed-a*t)
	var travel:float=trial.cart_x-brake_start
	skid_loss=maxf(0,travel-12)
	_set_chock_x(trial.cart_x+CHOCK_OFFSET)
	if brake_age>=brake_duration:hit_chock()

func _set_chock_x(x:float)->void:
	chock_body.position=Vector2(x,trial.ground(x)-14)

func front_wheel_distance()->float:
	return trial.cart_x-route.MINE_CART_X-skid_loss

func brake_load()->float:
	if not braking:return 0.0
	var t:=brake_age/maxf(.001,brake_duration)
	return smoothstep(0,.16,t)*(1.0-smoothstep(.75,1,t))*stop_impulse

func passenger_lean()->float:
	return brake_load()*.09+(sin(stop_age*17)*exp(-stop_age*5)*.035 if stop_age>=0 else 0.0)

func spark_contact()->Vector2:
	return Vector2(trial.cart_x+21,trial.ground(trial.cart_x+21)-2)

func _emit_spark(burst:bool=false)->void:
	if sparks.size()>=MAX_SPARKS:return
	spark_serial+=1
	var a:=fmod(spark_serial*.61803399,1.0)
	var b:=fmod(spark_serial*.41421356+.27,1.0)
	var hot:=a>.76 or burst and a>.4
	var power:float=clampf(trial.cart_speed/270.0,.22,1.1)
	var velocity:=Vector2(-68-b*150,-38-a*144)*sqrt(power)
	if hot:velocity*=1.18
	var size:float=1.15 if hot else .65+b*.38
	sparks.append({"p":spark_contact()+Vector2(b*2,-a),"v":velocity,"age":0.0,"life":.27+b*.22,"size":size,"hot":hot,"bounced":false})
	peak_sparks=maxi(peak_sparks,sparks.size())

func _tick_sparks(delta:float)->void:
	var active:bool=not sparks.is_empty()
	if braking and trial.cart_speed>18:
		var pulse:=.80+.20*sin(brake_age*73.0)+.12*sin(brake_age*131.0)
		spark_carry+=delta*155*pulse*clampf(trial.cart_speed/200,.25,1.0)
		while spark_carry>=1:
			spark_carry-=1;_emit_spark()
	for spark in sparks:
		spark.age+=delta;spark.v.y+=620*delta;spark.p+=spark.v*delta
		var floor_y:float=trial.ground(spark.p.x)-1.0
		if spark.p.y>=floor_y and spark.v.y>0:
			spark.p.y=floor_y
			if not spark.bounced:
				spark.v.y=-spark.v.y*.25;spark.v.x*=.55;spark.bounced=true;spark.age+=.045
			else:spark.age=spark.life
	sparks=sparks.filter(func(spark):return spark.age<spark.life)
	if active or not sparks.is_empty() or braking:spark_draw.queue_redraw()

func _spark_quad(a:Vector2,b:Vector2,width:float,energy:float,kind:float=0)->void:
	var normal:Vector2=(b-a).normalized().orthogonal()*width*.5
	var points:=PackedVector2Array([a-normal,b-normal,b+normal,a+normal])
	spark_draw.draw_polygon(points,PackedColorArray([Color(energy,0,kind,1)]),PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]))

func _draw_sparks()->void:
	if not visible:return
	var flash:float=0.0
	if braking:
		flash=clampf(trial.cart_speed/260.0,0,1.1)*(.78+.22*sin(brake_age*83))
	elif stop_age>=0 and stop_age<.08:flash=(1.0-stop_age/.08)*.25
	if flash>0:
		var point:=spark_contact()
		_spark_quad(point-Vector2(9,0),point+Vector2(9,0),12.0,flash,1)
	for spark in sparks:
		var t:float=clampf(spark.age/spark.life,0,1)
		var fade:float=(1.0-smoothstep(.20,1.0,t))*smoothstep(0,.025,spark.age)
		var length:float=clampf(spark.v.length()*.055,3.0,15.0)*spark.size
		var point:Vector2=spark.p
		var tail:Vector2=point-spark.v.normalized()*length
		_spark_quad(tail,point,(4.5 if spark.hot else 3.2)*spark.size,fade*(1.2 if spark.hot else .82))

func hit_chock()->void:
	for i in 4:_emit_spark()
	braking=false
	trial.cart_x=trial.PARK_X;trial.cart_speed=0
	stopped_once=true;stop_age=0
	_set_chock_x(trial.PARK_X+CHOCK_OFFSET)
	trial.shake=maxf(trial.shake,0.11)
	trial._emit_dust(Vector2(trial.PARK_X+35,trial.ground(trial.PARK_X)-5),Vector2(11,-5),Vector2(48,35),1.3,0)

# Future room may remove this object. No invisible park clamp remains then.
func remove_stop_rock()->void:
	chock_present=false;braking=false;chock_body.collision_layer=0

func try_recover()->bool:
	if not enabled() or not saved or falling or trial.operation!="":return false
	if trial.gap!=null and not trial.gap.grip_allowed():return false
	var p:Vector2=route.feet()
	if absf(p.x-trial.cart_x)>28 and absf(p.x-trial.cart_x)<90 and absf(p.y-trial.ground(p.x))<18 and route.level.player.is_on_floor():
		grip_side=signf(p.x-trial.cart_x);grip_motion=0
		trial.operation="recover";pull_age=0;pull_distance=0;cart_shoving=false;shove_support_grace=0
		if trial.gap!=null:trial.gap.coast=false
		route.level.facing=-grip_side;route.level.actor.reset_grip_animation()
		return true
	return false

func track_height(x:float)->float:
	return (trial.ground(x-21)+trial.ground(x+21))*.5

func track_grade(x:float)->float:
	return (track_height(x+4)-track_height(x-4))/8.0

func free_roll_speed(speed:float,x:float,delta:float)->float:
	var grade:=track_grade(x)
	# Gravity projected onto horizontal travel, reduced by wheel inertia.
	var gravity:float=980*.62*grade/(1+grade*grade)
	# The long, level run is worn track: its bearing/joint losses consume
	# momentum. A short uphill shove cannot coast all the way to the break.
	var resistance:=32.0
	if absf(speed)<.5 and absf(gravity)<=resistance:return 0.0
	var next:float=speed+gravity*delta
	# Rolling resistance opposes either direction and never propels the car.
	return clampf(move_toward(next,0,resistance*delta),-330,330)

func tick_recovery(delta:float)->bool:
	if falling or Input.is_action_just_pressed("jump"):
		trial.operation="";cart_shoving=false;shove_jump_lock=.25
		if trial.gap!=null:trial.gap.released_cart()
		if not falling:route.level.jump_buffer=.13
		return false
	if not Input.is_action_pressed("interact"):
		trial.operation=""
		if trial.gap!=null:trial.gap.released_cart()
		return false
	pull_age+=delta;route.level.facing=-grip_side
	var player=route.level.player
	grip_motion=Input.get_axis("move_left","move_right") if pull_age>=.32 else 0.0
	var desired:float=grip_motion*clampf(50+grip_motion*track_grade(trial.cart_x)*45,32,66)
	var braking:bool=is_zero_approx(desired) or desired*trial.cart_speed<0
	trial.cart_speed=move_toward(trial.cart_speed,desired,delta*(420 if braking else 100))
	var lower:float=maxf(rubble_front,-1470.0)+31.0 if trial.gap!=null else RECOVERY_LEFT+105
	var old_cart:float=trial.cart_x
	# A grab never relocates a car back inside an obsolete interaction limit.
	# Only the real rubble blocks travel; the rail edge can still be overrun.
	var requested:float=old_cart+trial.cart_speed*delta
	var next:float=minf(old_cart,lower) if requested<lower else requested
	if is_equal_approx(next,old_cart):trial.cart_speed=0
	var motion:float=next-old_cart
	var before:Vector2=route.feet()
	var correction:float=clampf((old_cart+grip_side*54-before.x)*10,-65,65)
	var vx:float=motion/maxf(delta,.001)+correction
	var floor_y:float=trial.ground(before.x+vx*delta)
	player.position.y+=minf(0,floor_y-before.y-2)
	player.velocity=Vector2(vx,(floor_y-trial.ground(before.x))/maxf(delta,.001)+18)
	player.apply_floor_snap();player.move_and_slide()
	var actual:float=route.feet().x-before.x-correction*delta
	trial.cart_x+=clampf(actual,minf(0,motion),maxf(0,motion))
	if absf(trial.cart_x-old_cart-motion)>.1:trial.cart_speed=(trial.cart_x-old_cart)/maxf(delta,.001)
	pull_distance+=absf(trial.cart_x-old_cart)
	route.fall_origin=route.feet().y
	return true

func tick_cart_shove(delta:float)->bool:
	var was_shoving:=cart_shoving
	cart_shoving=false
	shove_jump_lock=maxf(0,shove_jump_lock-delta)
	var player=route.level.player
	var p:Vector2=route.feet()
	var heading:float=signf(trial.cart_speed)
	var separation:float=(p.x-trial.cart_x)*heading
	if not saved or not trial.gap.coast or falling or trial.operation!="" or absf(trial.cart_speed)<2:
		shove_support_grace=0;return false
	if Input.is_action_just_pressed("jump") or route.level.jump_windup_left>0:
		shove_support_grace=0;shove_jump_lock=.25;return false
	if shove_jump_lock>0:return false
	if player.is_on_floor():shove_support_grace=.08
	else:shove_support_grace=maxf(0,shove_support_grace-delta)
	# Enter at actual contact, leave only after genuine separation. Floor
	# seams get a short grace; it never suspends someone beyond the ground.
	var supported:bool=player.is_on_floor() or was_shoving and shove_support_grace>0 and p.x<EDGE_X-2 and absf(p.y-trial.ground(p.x))<5
	if not supported or separation<(33 if was_shoving else 36) or separation>(72 if was_shoving else 55) or absf(p.y-trial.ground(p.x))>9:return false
	cart_shoving=true;shove_direction=heading
	route.level.actor.load_group("shove")
	var resistance:float=1.0 if Input.get_axis("move_left","move_right")*heading<0 else .45
	trial.cart_speed=heading*move_toward(absf(trial.cart_speed),minf(absf(trial.cart_speed),80),delta*90*resistance)
	var target:float=trial.cart_x+heading*45
	var vx:float=trial.cart_speed+clampf((target-p.x)*8,-60,60)
	# A constant downward speed projects into excess downhill travel during
	# move_and_slide, repeatedly breaking contact. Follow the surface tangent.
	var step_x:float=vx*delta
	var slope_vy:float=(trial.ground(p.x+step_x)-trial.ground(p.x))/maxf(delta,.001)
	player.velocity=Vector2(vx,slope_vy+18)
	player.apply_floor_snap()
	player.move_and_slide()
	if not player.is_on_floor() and route.feet().x>EDGE_X-2:
		cart_shoving=false;shove_support_grace=0
	route.fall_origin=route.feet().y
	return true

func apply_cart_shove_pose(pose)->void:
	if not cart_shoving:return
	pose.shoved=true;pose.facing=-shove_direction;pose.action=&"push"
	pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE

func _finish_recovery_frame()->bool:
	route.fall_origin=route.feet().y
	return true

func apply_recovery_pose(pose)->void:
	# Do not inherit a boat rope or a crate's contact offset from C-zone.
	route.level.actor.rope_allowed=false;route.level.actor.rope_hold=0
	route.level.actor.contact_reach=22.5;route.level.actor.contact_sink=1
	pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
	pose.action=&"grip_engage" if pull_age<.32 else (&"grip_hold" if absf(grip_motion)<.1 else (&"push" if grip_motion*grip_side<0 else &"pull"))
	pose.action_progress=minf(1,pull_age/.32)
	route.level.actor.grip_distance=pull_distance

func fit_recovery_hands()->void:
	if trial.operation!="recover" or falling:return
	var actor=route.level.actor
	var hand:Vector2=actor.grip_hand_world()
	var contact:Vector2=route.art.cart_visual.grip_surface(cart_position(),visual_motion(),hand.y,grip_side)
	# The approach clip reaches naturally; once loaded, keep the recorded
	# palm on the iron each frame. Move the intact drawing, never cut limbs.
	var weight:=smoothstep(0,.32,pull_age)
	actor.body.position.x+=(contact.x-hand.x)*weight

func _update_collapse(delta:float)->void:
	var p:Vector2=route.feet()
	var old_floor:float=trial.ground(p.x)
	var follows_ground:bool=absf(p.y-old_floor)<6 and route.level.player.velocity.y>=0
	route.art.chamber.set_collapse(trial.impact_age)
	route.art.chase_chamber.set_collapse(trial.impact_age)
	if trial.impact_age>1.65:chase_lamp.set_failure(trial.impact_age-1.65,trial.ground(-2160))
	_update_lighting()
	if follows_ground and p.x>COLLAPSE_LEFT and p.x<SAFE_X:
		route.level.player.position.y+=trial.ground(p.x)-old_floor
	_sync_floor_pads()
	trial.shake=maxf(trial.shake,.19*exp(-trial.impact_age*1.4))
	for chunk in roof:
		chunk.moving_this_step=false
		if trial.impact_age<chunk.delay:continue
		chunk.age+=delta
		if not chunk.landed:
			chunk.previous=chunk.p;chunk.moving_this_step=true
			chunk.vy+=980*delta;chunk.p.y+=chunk.vy*delta
			chunk.angle+=chunk.spin*delta
			var floor_y:float=trial.ground(chunk.home.x)-24
			if chunk.p.y>=floor_y:
				chunk.p.y=floor_y;chunk.landed=true
				trial.shake=maxf(trial.shake,.16)
				trial._emit_dust(chunk.p+Vector2(20,10),Vector2(18,-9),Vector2(150,105),3.5,0)
			elif chunk.age<delta*1.5:
				trial._emit_dust(chunk.p+Vector2(0,20),Vector2(8,15),Vector2(100,80),2.5,0)
	_update_corner()
	for support in timber_supports:support.tick(delta)
	var front_x:float=minf(-1470,SAFE_X+maxf(0,trial.impact_age-2.42)*310)
	if absf(front_x-rubble_front)>.25:
		var box:RectangleShape2D=rubble_body.get_child(0).shape
		box.size=Vector2(front_x-COLLAPSE_LEFT,210)
		rubble_body.get_child(0).position=Vector2((COLLAPSE_LEFT+front_x)*.5,trial.ground(front_x)-90)
		rubble_front=front_x
	queue_redraw();collapse_draw.queue_redraw()
	rubble_body.collision_layer=1 if trial.impact_age>CRUSH_TIME+0.08 else 0

func _pad_y(x:float)->float:
	if x< -3165:return lerpf(-3268,-3271,clampf((x+3205)/40,0,1))
	return trial.ground(x)

func _sync_floor_pads(force:bool=false)->void:
	for part in floor_pads:
		var heights:=Vector2(_pad_y(part.a),_pad_y(part.b))
		if not force and heights.distance_squared_to(part.last)<.0025:continue
		var angle:float=atan2(heights.y-heights.x,part.b-part.a)
		part.node.position=Vector2((part.a+part.b)*.5,(heights.x+heights.y)*.5)+Vector2(-sin(angle),cos(angle))*210
		part.node.rotation=angle
		part.last=heights;floor_pad_updates+=1

func _draw_collapse()->void:
	if not visible or not trial.broken:return
	for chunk in roof:
		if trial.impact_age<chunk.delay:continue
		collapse_draw.draw_set_transform(chunk.p,chunk.angle)
		# Authored irregular stone silhouettes, not a row of rectangles.
		var cell:=ROOF.get_size()/Vector2(4,2)
		var uv:=Rect2(Vector2(int(chunk.id)%4,floori(float(int(chunk.id)%8)/4.0))*cell,cell)
		collapse_draw.draw_texture_rect_region(ROOF,Rect2(-Vector2.ONE*chunk.size*.5,Vector2.ONE*chunk.size),uv)

	collapse_draw.draw_set_transform(Vector2.ZERO)

func _draw()->void:
	if not visible:return
	var floor_y:float=trial.ground(EDGE_X)
	var edge:=preload("res://scripts/chapters/mine_gap_rock_shape.gd").left_edge(floor_y)
	var face:=PackedVector2Array([Vector2(EDGE_X-260,floor_y)])
	face.append_array(edge);face.append(Vector2(EDGE_X-260,edge[-1].y))

	draw_colored_polygon(face,Color(.003,.003,.003))
	# Draw the physical stop in contact with the front wheel.
	if chock_present:Chock.draw_stone(self,chock_body.position)
	# A bent rail end and missing sleepers make the break readable without UI.
	var end:=Vector2(EDGE_X,trial.ground(EDGE_X))
	draw_polyline(PackedVector2Array([end+Vector2(-45,-2),end+Vector2(4,-2),end+Vector2(18,3),end+Vector2(24,14)]),Color(.035,.035,.035),1.8,true)

func sync_enabled(value:bool)->void:
	visible=value and enabled()
	end_fill.collision_layer=1 if visible else 0
	chock_body.collision_layer=1 if visible and chock_present else 0
	rubble_body.collision_layer=1 if visible and trial.impact_age>CRUSH_TIME+.08 else 0
	if not visible:route.art.chamber.ink.set_shader_parameter("end_lamp",Vector2(1000000,1000000))

func _update_lighting()->void:
	var ink:ShaderMaterial=route.art.chamber.ink
	ink.set_shader_parameter("end_lamp",chase_lamp.light_position())
	ink.set_shader_parameter("end_tilt",chase_lamp.light_angle())
	ink.set_shader_parameter("end_strength",chase_lamp.energy)
	var extension:ShaderMaterial=route.art.chase_chamber.ink
	extension.set_shader_parameter("stopping_bay",true)
	extension.set_shader_parameter("rock_end_x",EDGE_X)
	extension.set_shader_parameter("aux_lamp",chase_lamp.light_position())
	extension.set_shader_parameter("aux_angle",chase_lamp.light_angle())
	extension.set_shader_parameter("aux_strength",chase_lamp.energy)
	extension.set_shader_parameter("end_lamp",end_lamp.light_position())
	extension.set_shader_parameter("end_tilt",end_lamp.light_angle())

func end_illumination(x:float)->float:
	var light:=0.0
	for fixture in [chase_lamp,end_lamp]:
		var d:Vector2=Vector2(x,trial.ground(x))-fixture.light_position()
		var a:float=fixture.light_angle()
		d=Vector2(cos(a)*d.x+sin(a)*d.y,-sin(a)*d.x+cos(a)*d.y)
		var value:=0.0
		if fixture==end_lamp:
			var below:=smoothstep(-14,24,d.y)
			var beam:=below*exp(-pow(absf(d.x)/(32+maxf(d.y,0)*.90),2))*exp(-maxf(d.y,0)/420.0)
			var spread:Vector2=(d-Vector2(0,105))/Vector2(245,205)
			value=beam+.20*exp(-spread.length_squared())*smoothstep(-38,26,d.y)
		else:value=exp(-pow(absf(d.x)/(18+maxf(d.y,0)*.7),2.2))*exp(-maxf(d.y,0)/310.0)
		light=maxf(light,value*fixture.energy)
	return light

func roof_hazard_at(x:float)->bool:
	if x>COLLAPSE_LEFT and x<SAFE_X:return trial.impact_age>=CRUSH_TIME
	var room=route.art.chase_chamber
	return room.collapse_weight(x)>.5 and room.local_collapse_age(x)>1.12

func hits_falling_stone()->bool:
	var p:Vector2=route.feet()
	var upper:=p-Vector2(0,65)
	var lower:=p-Vector2(0,12)
	if is_riding():
		upper=cart_position()+Vector2(0,-86)
		lower=cart_position()+Vector2(0,-71)
	for support in timber_supports:
		if support.strikes(upper,lower):return true
	for chunk in roof:
		if not chunk.get("moving_this_step",false):continue
		var closest:=Geometry2D.get_closest_points_between_segments(chunk.previous,chunk.p,upper,lower)
		if closest[0].distance_to(closest[1])<chunk.size*.30+9.0:return true
	return false

func begin_crush(cause:StringName)->void:
	crushed=true;crush_cause=cause;hit_age=0
	if stumble_age<0:
		stumble_age=0;stumble_facing=route.level.facing
	route.fail();route.failure_airborne=false
	# A rock can hit someone in mid-jump: let that body land on the real floor.
	route.level.player.collision_mask=43
	route.level.player.velocity=Vector2(-25,80) if not route.level.player.is_on_floor() else Vector2.ZERO

func tick_knockdown(delta:float)->bool:
	if not enabled():return false
	if stumble_age<0:
		if not trial.broken or trial.impact_age<.12 or riding or is_riding() or route.failure_time>0:return false
		var p:Vector2=route.feet()
		var shock_zone:bool=p.x>COLLAPSE_LEFT and p.x<SAFE_X
		if not shock_zone:return false
		if not route.level.player.is_on_floor() or absf(p.y-trial.ground(p.x))>9:return false
		stumble_age=0;stumble_facing=route.level.facing
		route.level.jump_buffer=0;route.level.jump_windup_left=0
		route.level.player.velocity=Vector2(-78,160)
	stumble_age+=delta
	if crushed:hit_age+=delta
	if not crushed or not route.level.player.is_on_floor():
		var body=route.level.player
		body.velocity.x=-(35 if crushed else 50)*exp(-(hit_age if crushed else stumble_age)*3.5)
		body.velocity.y=minf(400,body.velocity.y+1000*delta)
		body.move_and_slide()
		route.fall_origin=route.feet().y
	return true

func crush_animation_complete()->bool:
	return hit_age>=HIT_TOTAL+.18

func apply_escape_pose(pose)->void:
	if stumble_age>=0:
		pose.action=&"mine_rock_hit" if crushed else &"mine_collapse_stagger"
		pose.action_progress=clampf(hit_age/HIT_TOTAL if crushed else stumble_age/.6,0,1)
		pose.facing=stumble_facing;pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
		return
	apply_ride_pose(pose)

func _build_tool_layers()->void:
	for name in ["rack","boards","pick","hoe","bucket","coil"]:
		var texture:Texture2D=load("res://assets/art/descent/mine-cart-escape-v1/props/"+name+".png")
		if texture==null:continue
		var bounds:=texture.get_image().get_used_rect()
		var anchor:=Vector2(bounds.position.x+bounds.size.x*.5,bounds.end.y)
		var pivot:=Node2D.new();pivot.position=anchor
		var sprite:=Sprite2D.new();sprite.texture=texture;sprite.centered=false;sprite.position=-anchor
		pivot.add_child(sprite);trial.rear_tools.add_child(pivot)
		tool_parts.append({"name":name,"node":pivot,"home":anchor})
	if tool_parts.size()==6:trial.rear_tools.self_modulate=Color(1,1,1,0)
	tools_home=trial.rear_tools.position
	miner_home=trial.miner.position;miner_rotation_home=trial.miner.rotation
	miner_pivot=trial.miner.region_rect.size*Vector2(.28,.93)*trial.miner.scale

func _restore_corner()->void:
	trial.rear_tools.position=tools_home
	for part in tool_parts:
		part.node.position=part.home;part.node.rotation=0
	trial.miner.position=miner_home;trial.miner.rotation=miner_rotation_home

func _update_corner()->void:
	trial.rear_tools.position=tools_home+Vector2(0,route.art.chamber.floor_shift(tools_home.x))
	var t:float=maxf(0,trial.impact_age-.20)
	for i in tool_parts.size():
		var part:Dictionary=tool_parts[i]
		var f:=smoothstep(.08+i*.025,.85+i*.025,t)
		var angle:float={"rack":1.15,"boards":-.92,"pick":-1.46,"hoe":1.40,"bucket":.46,"coil":.08}[part.name]
		part.node.rotation=angle*f+sin(t*31+i)*.018*exp(-t*5)
		part.node.position=part.home+Vector2((i-2)*8*f,4*f)
	var settle:=smoothstep(.07,.70,t)
	var a:=miner_rotation_home+.13*settle+sin(t*28)*.022*exp(-t*5)
	var hip:=miner_home+miner_pivot.rotated(miner_rotation_home)
	trial.miner.rotation=a
	trial.miner.position=hip-miner_pivot.rotated(a)+Vector2(1.5*settle,2.4*settle+route.art.chamber.floor_shift(miner_home.x))

# x: chassis pitch, y: heave in pixels, z: tub rocking about its own pivot.
func visual_motion()->Vector3:
	var grade:float=(route.mine_floor_base_y(trial.cart_x+10)-route.mine_floor_base_y(trial.cart_x-10))/20.0
	var pitch:=atan(grade)
	var heave:=0.0
	var tub:=0.0
	if trial.launched:
		var t:=maxf(0,launch_age-.52)
		var start_load:=sin(t*18)*exp(-t*4)*smoothstep(0,.06,t)
		pitch+=start_load*.055;heave-=absf(start_load)*1.3;tub+=start_load*.080
		var travel:float=trial.cart_x-route.MINE_CART_X
		var speed:float=clampf(trial.cart_speed/300,0,1)
		pitch+=sin(travel*.21)*.008*speed
		heave+=(sin(travel*.34)*.45+sin(travel*.91)*.22)*speed
	if trial.impact_age>=0:
		var t:float=trial.impact_age
		var strike:=sin(t*23)*exp(-t*4.8)
		pitch+=strike*.065;heave-=absf(strike)*2.7;tub+=strike*.10
	if braking:
		var load:=brake_load()
		pitch+=load*.045;heave+=load*1.0;tub+=load*.105
		var contact:=sin(brake_age*32)*exp(-brake_age*10)*stop_impulse
		pitch+=contact*.025;tub+=contact*.035
	if stop_age>=0:
		var strike:=sin(stop_age*17)*exp(-stop_age*5.5)*stop_impulse
		pitch+=strike*.067;heave-=absf(strike)*1.7;tub+=strike*.08
	if trial.gap!=null and saved:
		if falling:
			pitch=trial.gap.fall_pitch;heave=0;tub=sin(trial.gap.flight_age*9)*.07*exp(-trial.gap.flight_age*2)
		elif trial.cart_x>trial.gap.RAIL_END-21:
			pitch+=smoothstep(trial.gap.RAIL_END-21,trial.gap.RAIL_END+21,trial.cart_x)*.11
	return Vector3(pitch,heave,tub)

func apply_ride_pose(pose)->void:
	if dismount_pending:return
	# The player owns takeoff as soon as jump gathering starts.
	if route.level.jump_windup_left>0 or route.level.jump_buffer>0:return
	if not riding or not is_riding() or route.level.player.velocity.y< -1:return
	var blend:=smoothstep(0,.34,ride_age)
	var motion:=visual_motion()
	var seat:=Vector2(-9+brake_load()*4,-37+brake_load()).rotated(motion.x)+Vector2(0,motion.y)
	pose.feet=cart_position()+seat_start.lerp(seat,blend)
	pose.facing=1
	pose.action=&"mine_cart_ride"
	pose.action_progress=minf(1,ride_age/.34)
	pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
