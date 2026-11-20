extends Node2D
# Approved layered art with load-operated restraint and contact-fitted carts.
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const Cart=preload("res://scripts/chapters/mine_cart_visual.gd")
const Pendant=preload("res://scripts/chapters/mine_pair_lamp_2d.gd")
const Scenery=preload("res://scripts/chapters/mine_pair_static_art.gd")
const Ladders=preload("res://scripts/chapters/mine_pair_ladders.gd")
const Pressure=preload("res://scripts/chapters/mine_pair_pressure.gd")
const Hoist=preload("res://scripts/chapters/mine_pair_hoist.gd")
const StairDescent=preload("res://scripts/chapters/mine_stair_descent.gd")
const Relay=preload("res://scripts/chapters/mine_cart_relay.gd")
const ORIGIN:=Vector2(-665,-3563)
const MID_Y:=-3050.0
const LOWER_Y:=-2674.0
const UPPER_Y:=-3247.0
const TRACK_Y:=-2913.0
const STAIR_START:=315.0
const STAIR_END:=435.0
var gap
var lamp:Node2D
var far_lamp:Node2D
var lamps:Array[Node2D]=[]
var carts:Array[Node2D]=[]
var bodies:Array[PhysicsBody2D]=[]
var bays:=[523.0,Relay.THIRD_X]
var scenery:Node2D
var ladders:Node2D
var pressure:RefCounted
var hoist:RefCounted
var stairs:RefCounted
var relay:Node2D
var cart_bodies:Array[StaticBody2D]=[]
var restraint_cleared:=false
var cart_gripped:=false
var cart_grip_distance:=0.0
var cart_motion_speed:=0.0
var cart_grip_index:=0
var cart_grip_side:=1.0
var cart_grip_age:=0.0
var cart_speed:=0.0
var cart_distance:=0.0
var carts_joined:=false
var enabled:=true
var terrain_image:Image
var surface_image:Image
var terrain_bits:BitMap
var stair_floor_override:=false
var saved_floor_angle:=0.0
func floor_y(x:float)->float:
 if x<STAIR_START:return MID_Y
 if x<STAIR_END:return lerpf(MID_Y,TRACK_Y,(x-STAIR_START)/(STAIR_END-STAIR_START))
 return TRACK_Y
func on_stair(at:Vector2)->bool:
 return enabled and at.x>STAIR_START-24 and at.x<STAIR_END+24 and absf(at.y-floor_y(at.x))<24
func stair_speed_cap(at:Vector2)->float:
 if not on_stair(at):return INF
 return StairDescent.UP_SPEED if Input.get_axis("move_left","move_right")<0 else StairDescent.DOWN_SPEED
func lower_floor_y(x:float)->float:
 if terrain_image==null:return LOWER_Y
 var px:=clampi(roundi(x-ORIGIN.x),280,910)
 for y in range(940,799,-1):
  if terrain_bits!=null and not terrain_bits.get_bit(px,y):return ORIGIN.y+float(y+1)
 return LOWER_Y
func visible_floor_y(at:Vector2)->float:
 if surface_image==null:return at.y
 var x:=clampi(roundi(at.x-ORIGIN.x),0,surface_image.get_width()-1)
 var first:=clampi(floori(at.y-ORIGIN.y),0,surface_image.get_height()-1)
 for y in range(first,mini(first+13,surface_image.get_height())):
  if surface_image.get_pixel(x,y).get_luminance()<.17:return ORIGIN.y+y
 return at.y
func _ready()->void:
 terrain_image=Scenery.FRONT.get_image()
 surface_image=Scenery.SOURCE.get_image()
 scenery=Scenery.new();scenery.room=self;add_child(scenery)
 _terrain_collision()
 scenery.mechanisms.fit_to_floor()
 # Walking planes share the artwork's native registration. Ramps bridge
 # shallow individual treads without a hidden vertical collision snag.
 _solid([Vector2(-410,MID_Y),Vector2(STAIR_START,MID_Y),Vector2(STAIR_START,MID_Y+15),Vector2(-410,MID_Y+15)],true)
 _solid([Vector2(-549,UPPER_Y),Vector2(-231,UPPER_Y),Vector2(-231,UPPER_Y+14),Vector2(-549,UPPER_Y+14)],true)
 _solid([Vector2(STAIR_START,MID_Y),Vector2(STAIR_END,TRACK_Y),Vector2(1007,TRACK_Y),Vector2(1007,TRACK_Y+13),Vector2(STAIR_END-4,TRACK_Y+13),Vector2(STAIR_START-3,MID_Y+15)])
 # First four preserve the prior auxiliary-light API. Remaining fixtures
 # live at actual rear depths, not all on the player's plane.
 for i in 6:
  var fixture:=Pendant.new();fixture.lamp_index=i
  fixture.position=ORIGIN+Vector2(Pendant.BULBS[i].x,Pendant.ANCHOR_Y[i])
  fixture.z_as_relative=false;fixture.z_index=3 if i<4 else 1
  add_child(fixture);lamps.append(fixture)
 lamp=lamps[1];far_lamp=lamps[3]
 for x:float in bays:
  var cart:=Cart.new();add_child(cart);carts.append(cart)
  cart.front.z_as_relative=false;cart.back.z_as_relative=false
  var body:=StaticBody2D.new();body.collision_layer=33;body.collision_mask=0
  var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(62,44)
  shape.shape=rectangle;shape.position=Vector2(0,-25);body.position=Vector2(x,TRACK_Y);body.add_child(shape);add_child(body);bodies.append(body);cart_bodies.append(body)
  body.set_meta("cart_preview",true)
 scenery.mechanisms.fit_restraint_to_cart(carts[0],Vector2(bays[0],TRACK_Y))
 ladders=Ladders.new();ladders.room=self;add_child(ladders)
 pressure=Pressure.new();pressure.setup(self)
 hoist=Hoist.new();hoist.setup(self)
 stairs=StairDescent.new();stairs.room=self
 relay=Relay.new();add_child(relay);relay.setup(self)
 gap.level.actor.load_group("mine_stairs")
 tick(0)
func _terrain_collision()->void:
 # Art contains signs, ladders, posts and beams as well as geology. Never
 # turn their dark pixels into walking-plane collisions. Only banks below
 # their walking surface and the lower terrain can contribute solid rock.
 var envelope:=BitMap.new();envelope.create_from_image_alpha(terrain_image,.40)
 envelope.grow_mask(20,Rect2i(Vector2i.ZERO,terrain_image.get_size()))
 var original:=Scenery.SOURCE.get_image()
 var bitmap:=BitMap.new();bitmap.create(terrain_image.get_size())
 for y in terrain_image.get_height():
  for x in terrain_image.get_width():
   if envelope.get_bit(x,y) and original.get_pixel(x,y).get_luminance()<.15:bitmap.set_bit(x,y,true)
 var geology:=BitMap.new();geology.create(terrain_image.get_size())
 for y in terrain_image.get_height():
  for x in terrain_image.get_width():
   if not bitmap.get_bit(x,y):continue
   var world:=ORIGIN+Vector2(x,y)
   var bank:=world.x< -410.0 or world.x>=STAIR_END
   var lower_decoration:=x>=240 and x<850 and y>=800 and y<880
   if ((bank and world.y>=floor_y(world.x)) or y>=800) and not lower_decoration:
    geology.set_bit(x,y,true)
 terrain_bits=geology
 # The lower walking edge needs a continuous support plane. Simplifying
 # ink pixels into rock polygons creates tiny re-entrant vertices that
 # can pin the capsule after a slow pickup/throw, despite a flat normal.
 # Keep the source bitmap for visual/ladder registration; recess only the
 # collision seam, and cover it with a gently sampled one-way surface.
 var collision:BitMap=geology.duplicate()
 for x in range(250,927):
  var top:=roundi(lower_floor_y(ORIGIN.x+x)-ORIGIN.y)
  for y in range(maxi(800,top-10),mini(941,top+10)):collision.set_bit(x,y,false)
 for polygon:PackedVector2Array in collision.opaque_to_polygons(Rect2i(Vector2i.ZERO,terrain_image.get_size()),3.0):
  var area:=0.0
  for i in polygon.size():area+=polygon[i].cross(polygon[(i+1)%polygon.size()])
  if absf(area)<700:continue
  var world:=PackedVector2Array()
  for point in polygon:world.append(ORIGIN+point)
  _solid(world,false,true)
 var lower_top:=PackedVector2Array()
 for px in range(250,927,12):
  var at_x:float=ORIGIN.x+px
  var at_y:float=(lower_floor_y(at_x-6)+lower_floor_y(at_x)+lower_floor_y(at_x+6))/3.0
  lower_top.append(Vector2(at_x,at_y))
 var lower_shape:=lower_top.duplicate()
 for i in range(lower_top.size()-1,-1,-1):lower_shape.append(lower_top[i]+Vector2(0,12))
 _solid(lower_shape,true)
func _solid(points:PackedVector2Array,one_way:bool=false,segments:bool=false)->void:
 var body:=StaticBody2D.new();body.collision_layer=1;body.collision_mask=0
 var shape:=CollisionPolygon2D.new();shape.build_mode=CollisionPolygon2D.BUILD_SEGMENTS if segments else CollisionPolygon2D.BUILD_SOLIDS
 shape.polygon=points;shape.one_way_collision=one_way
 body.add_child(shape);add_child(body);bodies.append(body)
func set_enabled(value:bool)->void:
 enabled=value;visible=value
 if not value and ladders!=null:ladders.cancel()
 if not value:release_cart()
 if not value and stairs!=null:stairs.reset()
 if relay!=null:relay.set_enabled(value)
 if not value and stair_floor_override:
  gap.level.player.floor_max_angle=saved_floor_angle;stair_floor_override=false
 for body in bodies:
  if relay!=null and relay.cart_detached and body==cart_bodies[1]:continue
  body.collision_layer=(33 if body.has_meta("cart_preview") else 1) if value else 0
func tick(_delta:float)->void:
 if scenery==null:return
 if bays[0]>611:restraint_cleared=true
 if relay!=null:relay.tick_world(_delta)
 if relay!=null and relay.handoff_done:return
 if hoist!=null:hoist.tick_world(_delta)
 if pressure!=null:pressure.tick(_delta)
 var feet:Vector2=gap.route.feet()
 var on_stair:=enabled and feet.x>STAIR_START-30 and feet.x<STAIR_END+30 and absf(feet.y-floor_y(feet.x))<80
 if on_stair and not stair_floor_override:
  saved_floor_angle=gap.level.player.floor_max_angle
  gap.level.player.floor_max_angle=maxf(saved_floor_angle,deg_to_rad(55))
  stair_floor_override=true
 elif not on_stair and stair_floor_override:
  gap.level.player.floor_max_angle=saved_floor_angle;stair_floor_override=false
 scenery.sync()
 var view:=Rect2(Vector2(gap.level.camera_x,gap.level.camera_y)-Vector2(180,160),Vector2(1640,1040))
 for i in carts.size():
  var at:Vector2=relay.cart_at(i) if relay!=null else Vector2(bays[i],TRACK_Y)
  var pitch:float=relay.pitches[i] if relay!=null else 0.0
  var heave:float=relay.suspension[i] if relay!=null else 0.0
  var distance:float=(cart_distance if i==0 else 0.0)+(relay.distances[i] if relay!=null else 0.0)
  carts[i].set_wreck(relay.wreck_strain if i==1 and relay.wrecked else 0.0)
  carts[i].sync_cart(at,pitch,heave,heave*.008+relay.traction_pitch[i],distance,1,enabled and not relay.cart_lost[i] and view.grow(180).has_point(at),INF,not (relay.airborne if i==1 else relay.donor_airborne) and not (i==1 and relay.wrecked))
func restraint_locked()->bool:
 return not restraint_cleared and absf(bays[0]-523.0)<60.0 and not pressure.released
func release_cart()->void:
 if cart_gripped and not cart_bodies.is_empty():
  gap.level.player.remove_collision_exception_with(cart_bodies[cart_grip_index])
  if relay!=null:
   var index:=cart_grip_index
   var return_downhill:bool=enabled and gap.route.failure_time<=0 and relay.on_launch_bend(index)
   relay.ramp_return[index]=return_downhill
   relay.impact_driven[index]=return_downhill
   # Keep the actual along-rail speed at release. Gravity first arrests
   # an uphill push, then rolls the cart back without a motor or snap.
   relay.velocities[index]=relay.velocities[index]/maxf(.5,cos(relay.track_angle(bays[index]))) if return_downhill else 0.0
 cart_gripped=false;cart_speed=0;cart_motion_speed=0
func reset_puzzle()->void:
 restraint_cleared=false
 release_cart();bays=[523.0,Relay.THIRD_X];cart_distance=0;carts_joined=false
 if pressure!=null:pressure.reset()
 if hoist!=null:hoist.reset()
 if stairs!=null:stairs.reset()
 if relay!=null:relay.reset()
 for i in cart_bodies.size():cart_bodies[i].position=Vector2(bays[i],TRACK_Y)
func mechanical_impulse(at:Vector2,strength:float)->void:
 for fixture in lamps:
  var falloff:float=exp(-fixture.global_position.distance_to(at)/440.0)
  fixture.add_impulse(strength*falloff)
 if relay!=null and relay.art!=null:relay.art.lamp_omega+=strength*.45
func cart_grip_candidate(at:Vector2)->int:
 # Share the exact reachable-car test with the slider so input priority
 # does not depend on which controller is ticked first.
 var nearest:=INF;var selected:=-1
 for i in 2:
  if not relay.can_manipulate(i):continue
  var cart:Vector2=relay.cart_at(i)
  var dx:float=absf(at.x-cart.x)
  if absf(at.y-cart.y)>20 or dx<=28 or dx>=90:continue
  if dx<nearest:nearest=dx;selected=i
 return selected
func tick_cart_control(delta:float)->bool:
 var level=gap.level
 if not enabled or gap.route.failure_time>0 or ladders.active() or level.climb_time>=0 or relay.rider>=0 or relay.charge_owner:
  release_cart();return false
 if cart_gripped and (not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump") or not level.player.is_on_floor()):
  release_cart();return false
 if not cart_gripped:
  if not Input.is_action_just_pressed("interact") or not level.player.is_on_floor():return false
  var p:Vector2=gap.route.feet()
  var selected:=cart_grip_candidate(p)
  if selected<0:return false
  cart_grip_index=selected;cart_gripped=true;cart_grip_side=signf(p.x-bays[selected]);cart_grip_age=0
  cart_speed=relay.velocities[selected]
  relay.impact_driven[selected]=false;relay.ramp_return[selected]=false
  cart_grip_distance=0;cart_motion_speed=0;level.actor.grip_distance=0
  level.actor.reset_grip_animation();level.player.add_collision_exception_with(cart_bodies[selected])
 var index:=cart_grip_index
 cart_grip_age+=delta;level.facing=-cart_grip_side
 var input:=Input.get_axis("move_left","move_right") if cart_grip_age>.32 else 0.0
 var locked:bool=index==0 and restraint_locked()
 var grade:float=relay.track_angle(bays[index]) if not (index==1 and relay.cart_landed) else 0.0
 var desired:float=0 if locked else input*50.0/(1+maxf(0,-sin(grade)*input)*2.0)
 var uphill_limit:=INF
 if relay.on_launch_bend(index) and input>0:
  var uphill_load:float=maxf(0,-sin(grade))
  var capacity:float=.40*relay.CART_MASS/relay.cart_mass(index)
  # A finite force limit follows from the actual rail grade and mass.
  # Reach it in finite time; do not creep toward an asymptotic speed.
  var limiting_grade:=asin(clampf(capacity,0.01,.8))
  uphill_limit=relay.RAMP_START+tan(limiting_grade)*(relay.RAMP_END-relay.RAMP_START)*(relay.RAMP_END-relay.RAMP_START)/(2.0*relay.RAMP_HEIGHT)
  desired*=sqrt(maxf(0,1.0-pow(uphill_load/capacity,4.0)))
  if bays[index]>=uphill_limit-.05:desired=0.0
 var braking:=is_zero_approx(desired) or desired*cart_speed<0
 cart_speed=move_toward(cart_speed,desired,delta*(420.0 if braking else 100.0))
 var old:float=bays[index]
 var requested:float=old+cart_speed*cos(grade)*delta
 if is_finite(uphill_limit):requested=minf(requested,maxf(old,uphill_limit))
 requested=relay.limit_manual_cart(index,old,requested)
 var gap_width:float=relay.contact_gap()
 requested=maxf(STAIR_START+20,requested)
 if locked:requested=old;cart_speed=0
 if is_equal_approx(requested,old):cart_speed=0
 var before:Vector2=gap.route.feet()
 var correction:=clampf((old+cart_grip_side*54-before.x)*8,-45,45)
 var velocity:float=(requested-old)/maxf(delta,.001)+correction
 level.player.velocity=Vector2(velocity,18)
 if level.player.is_on_floor():
  var support:Vector2=level.player.get_floor_normal()
  if support.y<-.5:
   # Push along the actual bank instead of projecting a constant downward
   # impulse into it, which consumed the last few px/s of uphill effort.
   level.player.velocity.y=velocity*(-support.x/support.y)+1.0
 level.player.move_and_slide()
 var actual:float=gap.route.feet().x-before.x-correction*delta
 bays[index]+=clampf(actual,minf(0,requested-old),maxf(0,requested-old))
 var dx:float=bays[index]-old
 cart_grip_distance+=absf(dx);cart_motion_speed=dx/maxf(delta,.001)
 if index==0:cart_distance+=dx
 else:relay.distances[index]+=dx
 relay.velocities[index]=dx/maxf(delta,.001)
 relay.positions[index]=Vector2(bays[index],relay.EXIT_Y if index==1 and relay.cart_landed else relay.track_y(bays[index]))
 cart_bodies[index].position=relay.positions[index]
 carts_joined=absf(absf(bays[1]-bays[0])-gap_width)<.5
 gap.route.fall_origin=gap.route.feet().y
 return true
func apply_cart_pose(pose)->void:
 if not cart_gripped:return
 var level=gap.level
 level.actor.rope_allowed=false;level.actor.rope_hold=0
 level.actor.contact_reach=22.5;level.actor.contact_sink=1
 pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE;pose.action_progress=minf(1,cart_grip_age/.32)
 pose.action=&"grip_engage" if cart_grip_age<.32 else (&"grip_hold" if absf(cart_motion_speed)<.1 else (&"push" if cart_motion_speed*cart_grip_side<0 else &"pull"))
 level.actor.grip_distance=cart_grip_distance
func fit_cart_hands()->void:
 if not cart_gripped or gap.route.failure_time>0:return
 var index:=cart_grip_index
 var actor=gap.level.actor
 var hand:Vector2=actor.grip_hand_world()
 var contact:Vector2=carts[index].grip_surface(relay.cart_at(index),Vector3(relay.pitches[index],0,0),hand.y,cart_grip_side)
 actor.body.position.x+=(contact.x-hand.x)*smoothstep(0,.32,cart_grip_age)
func _unhandled_key_input(event:InputEvent)->void:
 if not enabled or gap.level.debug_return_index!=16 or not gap.route.active:return
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.physical_keycode in [KEY_5,KEY_6]:
  relay.debug_prepare(event.physical_keycode==KEY_5)
  gap.level.get_viewport().set_input_as_handled();return
 var station:int=[KEY_1,KEY_2,KEY_3,KEY_4].find(event.physical_keycode)
 if station<0:return
 ladders.cancel()
 release_cart()
 var points:=[Vector2(70,MID_Y),Vector2(-380,UPPER_Y),Vector2(0,lower_floor_y(0)),Vector2(740,TRACK_Y)]
 gap.level.player.position=points[station]-Vector2(13,55)
 gap.level.player.velocity=Vector2.ZERO;gap.route.fall_origin=points[station].y
 gap.level.climb_time=-1;gap.level.jump_buffer=0;gap.level.jump_windup_left=0
 gap.level.get_viewport().set_input_as_handled()
