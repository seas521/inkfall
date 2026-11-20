extends Node2D
# A rail stop released by a mechanical lever. No inventory dependency.
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const MINER=preload("res://assets/art/descent/mine-cart-v1/miner-skeleton-side.png")
const DUST_TEXTURE=preload("res://assets/art/descent/mine-cart-escape-v1/mineral-dust.png")
const TOOLS=preload("res://assets/art/descent/mine-cart-v1/tools.png")
const STONES=[preload("res://assets/art/descent/mine-v12/stone-0.png"),preload("res://assets/art/descent/mine-v12/stone-1.png"),preload("res://assets/art/descent/mine-v12/stone-2.png"),preload("res://assets/art/descent/mine-v12/stone-3.png")]
const BRAKE_X:=-2740.0
const WALL_X:=-2460.0
const PARK_X:=-1110.0
const LEGACY_PARK_X:=-2070.0
const GRIP_X:=BRAKE_X-24
var route
var escape
var gap
var broken:=false
var launched:=false
var cart_x:=-2705.0
var cart_speed:=0.0
var operation:=""
var operation_time:=0.0
var boarding_jump_queued:=false
var brake_progress:=0.0
var shake:=0.0
var elapsed:=0.0
var impact_age:=-1.0
var masonry:Node2D
var cart_body:AnimatableBody2D
var wall:StaticBody2D
var miner:Sprite2D
var rear_tools:Sprite2D
var pieces:Array[Dictionary]=[]
var dust:Array[Dictionary]=[]
var dust_layer:Node2D
var dust_serial:=0
var initialized:=false
var wall_height:=240.0
var handle_position:=Vector2.ZERO
var hand_contact:=false
const REACH_TIME:=0.40
const PULL_END:=1.75
const RELEASE_END:=2.10

func _ready()->void:
	z_index=4
	route.level.actor.load_group("grip")
	rear_tools=Sprite2D.new();rear_tools.name="RearMiningTools"
	rear_tools.texture=TOOLS;rear_tools.scale=Vector2.ONE*0.19
	rear_tools.centered=false;rear_tools.z_index=-4
	# Anchor the visible feet, not the transparent image rectangle.
	var used:=TOOLS.get_image().get_used_rect()
	rear_tools.position=Vector2(-2950-float(used.position.x+used.size.x/2)*0.19,ground(-2950)-float(used.end.y)*0.19+2)
	rear_tools.modulate=Color(0.45,0.45,0.45)
	add_child(rear_tools)
	miner=Sprite2D.new();miner.name="MinerRemains";miner.texture=MINER;miner.centered=false
	var silhouette_bounds:=MINER.get_image().get_used_rect()
	miner.region_enabled=true;miner.region_rect=Rect2(silhouette_bounds)
	var miner_scale:=58.0/float(silhouette_bounds.size.y)
	miner.scale=Vector2.ONE*miner_scale
	miner.position=Vector2(-2920,ground(-2920)-58+2)
	miner.rotation=atan2(ground(-2820)-ground(-2920),100.0)
	miner.z_index=-2
	miner.material=ShaderMaterial.new();miner.material.shader=preload("res://assets/shaders/mine_miner_silhouette.gdshader")
	add_child(miner)
	masonry=Node2D.new();masonry.material=ShaderMaterial.new()
	masonry.material.shader=preload("res://assets/shaders/mine_masonry_ink.gdshader")
	add_child(masonry);masonry.draw.connect(_draw_masonry)
	wall=StaticBody2D.new();wall.collision_layer=1;wall.collision_mask=0
	var shape:=CollisionShape2D.new()
	wall_height=ground(WALL_X)-route.art.chamber.ceiling_y(WALL_X)+12.0
	var box:=RectangleShape2D.new();box.size=Vector2(40,wall_height);shape.shape=box
	shape.position=Vector2(WALL_X,ground(WALL_X)-wall_height*0.5);wall.add_child(shape);add_child(wall)
	cart_body=AnimatableBody2D.new();cart_body.sync_to_physics=false
	cart_body.collision_layer=1;cart_body.collision_mask=0
	var cart_shape:=CollisionShape2D.new()
	var cart_box:=RectangleShape2D.new();cart_box.size=Vector2(62,44)
	cart_shape.shape=cart_box;cart_shape.position=Vector2(0,-25)
	cart_body.add_child(cart_shape);add_child(cart_body)
	dust_layer=Node2D.new();dust_layer.z_index=2
	dust_layer.material=ShaderMaterial.new()
	dust_layer.material.shader=preload("res://assets/shaders/mine_impact_dust.gdshader")
	add_child(dust_layer);dust_layer.draw.connect(_draw_dust)
	escape=preload("res://scripts/chapters/mine_cart_escape.gd").new()
	escape.trial=self;add_child(escape)
	gap=preload("res://scripts/chapters/mine_cart_gap.gd").new()
	gap.trial=self;add_child(gap)
	reset()

func ground(x:float)->float:return route.mine_floor_y(x)

func cart_position()->Vector2:
	if escape!=null and not route.shaft_preview:return escape.cart_position()
	return route.shaft.cart_at() if route.shaft!=null and cart_x>-2180 else Vector2(cart_x,ground(cart_x))

func restore_attempt()->Variant:
	return escape.restore_attempt() if escape!=null else null

func reset()->void:
	route.art.chamber.set_collapse(-1)
	broken=false;launched=false;cart_x=route.MINE_CART_X;cart_speed=0
	operation="";operation_time=0;boarding_jump_queued=false;brake_progress=0;shake=0;impact_age=-1
	hand_contact=false;handle_position=Vector2(BRAKE_X-1.5,ground(BRAKE_X)-34)
	wall.collision_layer=1;pieces.clear();dust.clear();dust_serial=0
	for row in int(ceil(wall_height/25.0)):
		for col in 2:
			if row==2 and col==0:continue
			pieces.append({"p":Vector2(WALL_X-11+col*23+(2 if row%2 else -2),ground(WALL_X)-13-row*25),"v":Vector2.ZERO,"angle":0.03*sin(row*7+col),"spin":0.0,"delay":0.0,"landed":false,"row":row,"id":(row+col)%4})
	if escape!=null:escape.reset()
	if gap!=null:gap.reset()
	initialized=true;sync_visual(0)

func cancel_operation()->void:
	boarding_jump_queued=false
	operation="";operation_time=0
	if not launched:brake_progress=0

func near_lever()->bool:
	return absf(route.feet().x-BRAKE_X)<43 and route.feet().x<route.MINE_CART_X-15 and absf(route.feet().y-ground(BRAKE_X))<25

func interact()->void:
	if gap!=null and gap.try_rock():return
	if escape!=null and escape.try_recover():return
	if operation!="" or launched or not route.level.player.is_on_floor() or not near_lever():return
	operation="align";operation_time=0;hand_contact=false
	route.level.facing=1

func tick(delta:float)->bool:
	elapsed+=delta;shake=maxf(0,shake-delta)
	# Decide who owns motion before integrating the car. Catching F after a
	# free-roll update used to integrate free and gripped travel in one tick.
	if Input.is_action_just_pressed("interact"):interact()
	if impact_age>=0:impact_age+=delta
	var was_riding:bool=escape.is_riding()
	var previous:Vector2=cart_position()
	var legacy:bool=route.shaft_preview
	var rolling:bool=(launched and cart_x<LEGACY_PARK_X and route.shaft.jammed) if legacy else escape.wants_roll()
	if rolling:
		var old:=cart_x
		if legacy:
			var desired:float=minf(320,sqrt(maxf(0,2*180*(LEGACY_PARK_X-cart_x))))
			cart_speed=move_toward(cart_speed,desired,(90.0 if cart_speed<desired else 200.0)*delta)
		elif escape.braking:
			escape.advance_braking(delta)
		else:
			# Gravity along the actual track, with rolling resistance. No distant
			# artificial slowdown: the wheel chock supplies the stopping impulse.
			var grade:float=(route.mine_floor_base_y(cart_x+10)-route.mine_floor_base_y(cart_x-10))/20.0
			var acceleration:float=maxf(54,980*sin(atan(grade))*.82-14)
			if escape.saved:
				cart_speed=escape.free_roll_speed(cart_speed,cart_x,delta) if not escape.falling else cart_speed*exp(-.025*delta)
			else:cart_speed=clampf(cart_speed+acceleration*delta,0,330)
		if legacy or not escape.braking and not escape.stopped_once:cart_x+=cart_speed*delta
		elif not legacy and not escape.chock_present:cart_x+=cart_speed*delta
		if not broken and old<WALL_X-48 and cart_x>=WALL_X-48:break_wall()
		if legacy:
			cart_x=minf(LEGACY_PARK_X,cart_x)
			if LEGACY_PARK_X-cart_x<0.5:cart_x=LEGACY_PARK_X;cart_speed=0
		elif escape.chock_present and not escape.braking and not escape.stopped_once and cart_x>=PARK_X-escape.BRAKE_RUN:escape.start_braking()
	if escape.saved and cart_x<maxf(escape.rubble_front,-1470)+31:
		cart_x=maxf(escape.rubble_front,-1470)+31;cart_speed=maxf(0,cart_speed)
	if escape.update_motion(delta,was_riding,previous):return true

	_tick_debris(delta)
	if escape.tick_knockdown(delta):return true
	if gap!=null and gap.tick_rock(delta):return true
	if gap!=null and gap.rock_state in [1,3]:return true
	if operation=="recover":return escape.tick_recovery(delta)
	if escape.tick_cart_shove(delta):return true
	if operation=="":
		if not launched:brake_progress=move_toward(brake_progress,0,delta*2)
		return false
	if not Input.is_action_pressed("interact") and not launched:
		operation="";operation_time=0;hand_contact=false;return false
	route.level.facing=1
	route.level.player.velocity.y+=1200*delta
	if operation=="align":
		var dx:float=GRIP_X-route.feet().x
		route.level.player.velocity.x=clampf(dx/maxf(delta,0.001),-95,95)
		route.level.player.move_and_slide()
		if absf(dx)<2:
			operation="brake";operation_time=0
		return true
	if operation_time<REACH_TIME or hand_contact or launched:
		operation_time+=delta
	# Take up the load first, then commit body weight to the stroke.
	var effort:=clampf((operation_time-REACH_TIME)/(PULL_END-REACH_TIME-0.18),0.0,1.0)
	brake_progress=smoothstep(0.0,1.0,pow(effort,1.6))
	# Face the handle while shifting weight backwards with its arc.
	var target_x:float=GRIP_X-18.0*brake_progress
	route.level.player.velocity.x=clampf((target_x-route.feet().x)/maxf(delta,0.001),-65,65)
	route.level.player.move_and_slide()
	if operation_time>=PULL_END-.15 and Input.is_action_just_pressed("jump"):
		boarding_jump_queued=true
	if operation_time>=PULL_END and hand_contact:
		brake_progress=1;launched=true
	if operation_time>=RELEASE_END:
		operation="";operation_time=0;hand_contact=false
		if boarding_jump_queued:route.level.jump_buffer=.13
		boarding_jump_queued=false
	return true

func break_wall()->void:
	if broken:return
	broken=true;wall.collision_layer=0;cart_speed*=0.74;shake=0.45;impact_age=0
	for i in pieces.size():
		pieces[i].delay=maxf(0,float(pieces[i].row)-2.0)*0.045
		var upper:float=clampf(float(pieces[i].row)/maxf(1,wall_height/25.0-1),0,1)
		pieces[i].v=Vector2(lerpf(170,18,upper)+sin(i*3.2)*16,-(1.0-upper)*(30+absf(sin(i*5))*80))
		pieces[i].spin=sin(i*9)*5
	for i in 5:
		var height:float=12+float(i)*29+sin(i*3.4)*13
		_emit_dust(Vector2(WALL_X+sin(i*2.1)*15,ground(WALL_X)-height),Vector2(38+i*17,-20-i*3),Vector2(140+i*9,105+i*8),3.0+float(i)*.13,float(i)*.045)
	for i in 48:
		dust.append({"p":Vector2(WALL_X,ground(WALL_X)-8-float(i%7)*9),"v":Vector2(-90+float(i)*6,-35-absf(sin(i*7))*150),"age":-float(i%4)*0.012,"life":1.1,"kind":1,"seed":float(i)/48,"size":Vector2(0.7+float(i%3)*0.35,1)})

func _emit_dust(at:Vector2,velocity:Vector2,size:Vector2,life:float,delay:float)->void:
	dust_serial+=1
	dust.append({"p":at,"v":velocity,"age":-delay,"life":life,"kind":0,"size":size,"seed":fmod(dust_serial*0.618034,1.0)})

func apply_pose(pose)->void:
	if escape.cart_shoving:
		escape.apply_cart_shove_pose(pose);return
	if gap!=null and gap.apply_rock_pose(pose):return
	if operation=="recover":
		escape.apply_recovery_pose(pose);return
	if operation!="brake":
		if escape!=null:escape.apply_escape_pose(pose)
		return
	pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
	if operation_time<REACH_TIME:
		pose.action=&"grip_engage"
		pose.action_progress=operation_time/REACH_TIME
	elif launched:
		pose.action=&"grip_release"
		pose.action_progress=clampf((operation_time-PULL_END)/(RELEASE_END-PULL_END),0,1)
	else:
		pose.action=&"lever"
		pose.action_progress=brake_progress
	pose.effort=brake_progress

func sync_visual(_delta:float)->void:
	if not initialized:return
	if gap!=null:gap.sync_rock_visual(_delta)
	visible=route.enabled and not route.in_c_zone
	if escape!=null:escape.sync_enabled(visible)
	if operation=="brake" and not launched and operation_time>=REACH_TIME:
		var hand:Vector2=to_local(route.level.actor.grip_hand_world())
		# Close the small reach gap before loading the linkage. Once held,
		# the existing tracked grip drives the stick, not an unrelated timer.
		if not hand_contact:
			handle_position=handle_position.move_toward(hand,90.0*_delta)
			hand_contact=handle_position.distance_to(hand)<1.5
		else:
			handle_position=hand
	elif not launched:
		handle_position=handle_position.move_toward(Vector2(BRAKE_X-1.5,ground(BRAKE_X)-34),90.0*_delta)
	wall.collision_layer=1 if visible and not broken else 0
	cart_body.collision_layer=(1 if route.shaft_preview else 32) if visible else 0
	cart_body.position=cart_position()
	cart_body.rotation=gap.fall_pitch if gap!=null and escape.falling and gap.flight_age>.35 else 0.0
	masonry.material.set_shader_parameter("lamp_position",route.art.chamber.lamp.light_position())
	masonry.material.set_shader_parameter("lamp_angle",route.art.chamber.lamp.light_angle())
	dust_layer.material.set_shader_parameter("lamp_position",route.art.chamber.lamp.light_position())
	dust_layer.material.set_shader_parameter("lamp_angle",route.art.chamber.lamp.light_angle())
	masonry.material.set_shader_parameter("lamp_strength",route.art.chamber.lamp.energy)
	dust_layer.material.set_shader_parameter("lamp_strength",route.art.chamber.lamp.energy)
	dust_layer.queue_redraw();masonry.queue_redraw();queue_redraw()

func lever_handle()->Vector2:
	return handle_position

func _draw()->void:
	if not initialized:return
	var base:=Vector2(BRAKE_X,ground(BRAKE_X)-3)
	var handle:=lever_handle()
	# A fixed iron base and axle, with a rod to the visible folding rail stop.
	draw_colored_polygon(PackedVector2Array([base+Vector2(-11,4),base+Vector2(-7,-6),base+Vector2(7,-6),base+Vector2(10,4)]),Color(0.035,0.035,0.035))
	draw_line(base,handle,Color(0.10,0.10,0.10),3.5,true)
	draw_circle(base,3,Color(0.13,0.13,0.13))
	draw_line(handle+Vector2(-5,0),handle+Vector2(5,0),Color(0.12,0.12,0.12),4,true)
	var stop:=Vector2(route.MINE_CART_X+27,ground(route.MINE_CART_X+27))
	draw_line(base+Vector2(3,-2),stop+Vector2(0,2),Color(0.055,0.055,0.055),1.5,true)
	var top:=stop+Vector2(lerpf(0,14,brake_progress),lerpf(-13,2,brake_progress))
	draw_line(stop+Vector2(0,3),top,Color(0.085,0.085,0.085),4.0,true)
	draw_line(top+Vector2(-5,0),top+Vector2(5,0),Color(0.10,0.10,0.10),3,true)
	for d in dust:
		if d.kind!=1 or d.age<0:continue
		var shade:float=0.10+route.art.chamber.light_at(d.p.x)*0.2
		draw_line(d.p,d.p-d.v.normalized()*d.size.x*2,Color(shade,shade,shade,(1.0-d.age/d.life)*0.65),d.size.x,true)

func _draw_dust()->void:
	for d in dust:
		if d.kind!=0 or d.age<0:continue
		var t:float=clampf(d.age/d.life,0,1)
		var size:Vector2=d.size*Vector2(1+t*0.65,1+t*0.42)
		var rect:=Rect2(d.p-size*Vector2(0.5,0.85),size)
		var points:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		dust_layer.draw_polygon(points,PackedColorArray([Color(t,d.seed,0,1)]),PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),DUST_TEXTURE)

func _draw_masonry()->void:
	if not initialized:return
	for i in pieces.size():
		var p:Dictionary=pieces[i]
		masonry.draw_set_transform(p.p,p.angle)
		masonry.draw_texture_rect(STONES[p.id],Rect2(-16,-17,32,34),false)
		if i%3==0:
			masonry.draw_polyline(PackedVector2Array([Vector2(-3,-13),Vector2(-1,-5),Vector2(-5,1),Vector2(-3,9)]),Color.BLACK,0.8,true)
	masonry.draw_set_transform(Vector2.ZERO)

func _tick_debris(delta:float)->void:
	if broken:
		for piece in pieces:
			if piece.delay>0:piece.delay=maxf(0,piece.delay-delta);continue
			piece.v.y+=680*delta;piece.p+=piece.v*delta;piece.angle+=piece.spin*delta
			var pile:float=(8+absf(sin(float(piece.id)*7+piece.angle))*11)*exp(-pow((piece.p.x-WALL_X-85)/135.0,2.0))
			var floor_y:=ground(piece.p.x)-5-pile
			if piece.p.y>floor_y:
				if not piece.landed:
					piece.landed=true
					_emit_dust(Vector2(piece.p.x,floor_y-3),Vector2(piece.v.x*0.25,-7),Vector2(75,55),2.3,0.0)
				piece.p.y=floor_y;piece.v.y=-absf(piece.v.y)*0.18
				piece.v.x*=exp(-7*delta);piece.spin*=exp(-8*delta)
	for d in dust:
		d.age+=delta
		if d.age<0:continue
		d.p+=d.v*delta
		if d.kind==1:
			d.v.y+=460*delta
			if d.p.y>ground(d.p.x)-2:d.age=d.life
		else:
			d.v*=exp(-1.15*delta)
			d.v.y+=2.8*delta
	dust=dust.filter(func(d):return d.age<d.life)

func tick_failure_visual(delta:float)->void:
	# Passenger death must not freeze the vehicle that just hit the wall.
	if gap!=null and gap.art!=null and gap.art.pair_room!=null:
		var pair=gap.art.pair_room
		if pair.enabled and pair.relay.wrecked:pair.tick(delta)
	elapsed+=delta;shake=maxf(0,shake-delta)
	if impact_age>=0:impact_age+=delta
	if escape.enabled() and broken:
		escape._update_collapse(delta)
		escape.tick_knockdown(delta)
	_tick_debris(delta)
	sync_visual(delta)
