extends RefCounted
# One real load: floor -> arms -> basket -> arms -> pressure pedal.
# F is a single action; the geared hoist completes its selected trip.
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const Clips=preload("res://scripts/actors/hood_actor_manifest.gd")
const PICKUP_TIME:=float(Clips.CLIPS.hug_pickup.frames)/60.0
const GRASP_TIME:=float(Clips.CLIPS.hug_pickup.grasp_frame)/60.0
const BASKET_REACH:=.30
const BASKET_LIFT:=.38
const BASKET_PICKUP_TIME:=BASKET_REACH+BASKET_LIFT
const BASKET_CONTACT_FRAME:=46.0
const BASKET_LIFT_FRAME:=65.0
const THROW_VELOCITY:=Vector2(85,-230)
const PUT_TIME:=.92
const LEVER_TIME:=.78
const STONE_SCALE:=.62
# The source has a transparent fringe below the rock. Its visible opaque
# sole is -1px from the atlas pivot, NOT the 6px PNG rectangle bottom.
const STONE_BOTTOM:=-1.0*STONE_SCALE
const STONE_CENTER:=33.0*STONE_SCALE
const ROCK_HAND_OFFSET:=Vector2(0,STONE_CENTER)
const THROW_WINDUP:=float(Clips.CLIPS.hug_throw_charge.frames)/60.0
const THROW_RELEASE:=float(Clips.CLIPS.hug_throw_release.frames)/60.0
const THROW_DETACH:=THROW_WINDUP+float(Clips.CLIPS.hug_throw_release.detach_frame)/60.0
const THROW_TOTAL:=THROW_WINDUP+THROW_RELEASE+float(Clips.CLIPS.hug_recover.frames)/60.0
enum Task {NONE, APPROACH, PICKUP, CARRY, PUTDOWN, LEVER, THROW}
enum Location {GROUND, ARMS, BASKET, AIR, CART}
var room
var task:=Task.NONE
var location:=Location.GROUND
var after_approach:=Task.NONE
var age:=0.0
var facing:=1.0
var approach_x:=0.0
var stone:Node2D
var stone_home:=Vector2.ZERO
var stone_origin:=Vector2.ZERO
var hand_offset:=Vector2.ZERO
var attached:=false
var place_in_basket:=false
var place_in_cart:=false
var inside_cart:=false
var place_origin:=Vector2.ZERO
var rise:=0.0
var speed:=0.0
var target_top:=false
var trip_started:=false
var lever_raising:=true
var selector_stroke:=0.0
var sway:=0.0
var sway_speed:=0.0
var previous_speed:=0.0
var was_loaded:=false
var load_blend:=0.0
var load_pulse:=0.0
var completed_trips:=0
var stone_velocity:=Vector2.ZERO
var inside_basket:=false
var bounced:=false
var load_offset_x:=0.0
var basket_bob:=0.0
var basket_bob_velocity:=0.0
var load_tilt:=0.0
var load_tilt_velocity:=0.0
var throws:=0
var basket_pickup:=false
var extracting:=false
func setup(owner_room)->void:
 room=owner_room;stone=room.scenery.mechanisms.ballast
 stone_home=stone.position
 stone_home.y=room.lower_floor_y(stone_home.x)-STONE_BOTTOM+2.0
 stone.scale=Vector2.ONE*STONE_SCALE
 room.scenery.mechanisms.configure_selector()
 reset()
func owns_motion()->bool:return task!=Task.NONE
func loaded()->bool:return location==Location.BASKET
func plate_locked()->bool:
 return location==Location.GROUND and room.pressure.footprint_contains(stone_origin+Vector2(0,STONE_BOTTOM),16)
func moving()->bool:
 var travel:float=room.scenery.mechanisms.basket_travel
 return absf(speed)>.15 or absf(rise-(travel if target_top else 0.0))>.2
func docked()->bool:
 var travel:float=room.scenery.mechanisms.basket_travel
 return not moving() and (rise<.2 or rise>travel-.2)
func reset()->void:
 task=Task.NONE;location=Location.GROUND;attached=false;age=0
 rise=0;speed=0;previous_speed=0;target_top=false;trip_started=false
 basket_bob=0;basket_bob_velocity=0;load_tilt=0;load_tilt_velocity=0
 selector_stroke=0;sway=0;sway_speed=0;completed_trips=0
 was_loaded=false;load_blend=0;load_pulse=0
 stone_origin=stone_home;stone.position=stone_origin;stone.rotation=0;stone.visible=true
 hand_offset=Vector2.ZERO;basket_pickup=false;extracting=false;_basket_occlusion(true)
 stone_velocity=Vector2.ZERO;inside_basket=false;inside_cart=false;place_in_cart=false;bounced=false;load_offset_x=0;throws=0
 room.scenery.mechanisms.set_selector(0)
 _present_basket();_register_weight()
 room.scenery.mechanisms.basket_rope.reset_motion()
func _floor(at:Vector2)->float:
 if at.y>room.TRACK_Y+90:return room.lower_floor_y(at.x)
 if at.y<room.MID_Y-100:return room.UPPER_Y
 return room.floor_y(at.x)
func _basket_floor()->float:
 return room.MID_Y if rise>room.scenery.mechanisms.basket_travel*.5 else room.lower_floor_y(room.scenery.mechanisms.basket.position.x)
func _contact_floor(at:Vector2)->float:
 var level=room.gap.level
 var nominal:=_floor(at)
 var query:=PhysicsRayQueryParameters2D.create(Vector2(at.x,nominal-24),Vector2(at.x,nominal+40),1,[level.player.get_rid()])
 var hit:Dictionary=level.player.get_world_2d().direct_space_state.intersect_ray(query)
 var surface:float=float(hit.position.y) if not hit.is_empty() and Vector2(hit.normal).y<-.65 else nominal
 return maxf(surface,room.visible_floor_y(Vector2(at.x,surface)))
func _basket_occlusion(inside:bool)->void:
 # Keep the rock behind the actor even when it clears the near lip.
 # Only the basket wall changes depth, after the rock is above it.
 stone.z_index=4
 room.scenery.mechanisms.basket_front.z_index=6 if inside else 3
func _basket_stone_origin()->Vector2:
 return room.scenery.mechanisms.basket.to_global(Vector2(load_offset_x,room.scenery.mechanisms.BASKET_SEAT_Y-STONE_BOTTOM))
func _spacing()->float:
 return absf(float(Clips.CLIPS.hug_pickup.hold_points[Clips.CLIPS.hug_pickup.grasp_frame][0]))*.42*Pose.HOOD_VISUAL_SCALE
func _move_player(delta:float)->void:
 var player=room.gap.level.player
 var start:Vector2=player.position
 var velocity:Vector2=player.velocity
 var grounded:bool=player.is_on_floor()
 player.move_and_slide()
 var travel:float=absf(velocity.x*delta)
 if not grounded or travel<.02 or absf(player.position.x-start.x)>travel*.4:return
 # Slow heavy steps need the same tiny terrain tolerance as normal
 # locomotion. A 2–5px rock lip must not become an invisible carry wall.
 for height:float in [2.,4.,6.]:
  var raised:Transform2D=player.global_transform
  raised.origin=start-Vector2(0,height)
  if player.test_move(player.global_transform,raised.origin-player.position):continue
  if player.test_move(raised,Vector2(velocity.x*delta,0)):continue
  player.global_transform=raised;player.velocity=velocity
  player.move_and_slide();player.apply_floor_snap();return
func _approach(next:Task,at_x:float)->void:
 task=Task.APPROACH;after_approach=next;approach_x=at_x;age=0
 room.gap.level.scene1.low_stance.reset()
func _try_interact()->bool:
 var level=room.gap.level
 if not Input.is_action_just_pressed("interact") or not level.player.is_on_floor():return false
 # Ballast is committed once inside the tub. Never start an unreachable
 # pickup approach through the cart body or steal its stationary F press.
 var p:Vector2=room.gap.route.feet()
 if task==Task.CARRY:
  # The throw is the same action everywhere: no destination mark, automatic
  # walk, turn-to-target, or velocity calculated from the plate/basket seat.
  place_in_cart=room.relay!=null and room.relay.can_load(p)
  place_in_basket=not place_in_cart and docked() and absf(p.x-room.scenery.mechanisms.basket.position.x)<85 and absf(p.y-_basket_floor())<12
  facing=level.facing
  task=Task.THROW;age=0
  level.scene1.low_stance.reset()
  return true
 if task!=Task.NONE:return false
 var selector:Vector2=room.scenery.mechanisms.selector_grip()
 if absf(p.y-room.UPPER_Y)<12 and absf(p.x-selector.x)<78:
  facing=1;lever_raising=not target_top
  _approach(Task.LEVER,selector.x-23);return true
 var floor_at:float=_basket_floor() if location==Location.BASKET else stone_origin.y+STONE_BOTTOM
 if location in [Location.ARMS,Location.AIR,Location.CART] or (location==Location.BASKET and not docked()):return false
 # The pressure plate is the load's final destination. Check the actual
 # supported footprint before starting an approach, even before the
 # restraint has finished rising; F must never recover this stone.
 if plate_locked():return false
 if absf(p.x-stone_origin.x)<82 and absf(p.y-floor_at)<15:
  facing=signf(stone_origin.x-p.x) if absf(stone_origin.x-p.x)>2 else level.facing
  _approach(Task.PICKUP,stone_origin.x-facing*_spacing());return true
 return false
func tick_control(delta:float)->bool:
 var level=room.gap.level
 if not room.enabled or room.gap.route.failure_time>0 or room.ladders.active() or room.cart_gripped:return false
 _try_interact()
 if task==Task.NONE:return false
 level.jump_buffer=0;level.jump_windup_left=0
 var player=level.player
 if task==Task.APPROACH:
  age+=delta;level.facing=facing
  var dx:float=approach_x-room.gap.route.feet().x
  var pace:float=Pose.HEAVY_CARRY_SPEED if attached else 60.0
  player.velocity=Vector2(clampf(dx/maxf(delta,.001),-pace,pace),80)
  _move_player(delta)
  if absf(dx)<.8:
   task=after_approach;age=0;player.velocity.x=0
   if task==Task.PICKUP:
    hand_offset=Vector2.ZERO;basket_pickup=location==Location.BASKET;extracting=basket_pickup
   if task==Task.LEVER:trip_started=false;level.actor.reset_grip_animation()
  elif age>5:task=Task.CARRY if attached else Task.NONE
 elif task==Task.CARRY:
  var input:=Input.get_axis("move_left","move_right")
  if absf(input)>.1:level.facing=signf(input)
  player.velocity.x=move_toward(player.velocity.x,input*Pose.HEAVY_CARRY_SPEED,180*delta)
  player.velocity.y=minf(550,player.velocity.y+1200*delta);_move_player(delta)
 else:
  age+=delta;level.facing=facing
  var vx:=0.0
  if task==Task.LEVER:
   var t:=smoothstep(.18,.82,age/LEVER_TIME)
   selector_stroke=t if lever_raising else 1.0-t
   room.scenery.mechanisms.set_selector(selector_stroke)
   var foot_x:float=room.scenery.mechanisms.selector_grip().x-23
   vx=clampf((foot_x-room.gap.route.feet().x)/maxf(delta,.001),-65,65)
  player.velocity=Vector2(vx,80);player.move_and_slide()
  if task==Task.PICKUP and age>=(BASKET_PICKUP_TIME if basket_pickup else PICKUP_TIME):
   task=Task.CARRY if attached else Task.NONE;age=0
  elif task==Task.PUTDOWN and age>=PUT_TIME:
   if attached:_place_stone()
   task=Task.NONE;age=0;level.actor.finish_rope_ladder()
  elif task==Task.LEVER and age>=LEVER_TIME:
   task=Task.NONE;age=0;level.actor.finish_rope_ladder()
  elif task==Task.THROW and age>=THROW_TOTAL:
   task=Task.NONE;age=0;level.actor.finish_rope_ladder()
 room.gap.route.fall_origin=room.gap.route.feet().y
 if room.gap.route.feet().y>room.LOWER_Y+400:room.gap.route.fail()
 return true
func apply_pose(pose)->void:
 if task in [Task.PICKUP,Task.CARRY,Task.PUTDOWN,Task.THROW] or (task==Task.APPROACH and attached):
  pose.small_item_kind=&"heavy";pose.held=0 if attached else -1
  pose.equipment=Pose.EQUIPMENT_THROWABLE
  pose.action=Pose.ACTION_NONE;pose.jump_windup=-1
  if task==Task.PICKUP:
   pose.action=Pose.ACTION_PICKUP
   if basket_pickup:
    # Reach down to the supported load, then reverse the same tracked
    # hands to lift it over the rim. No floor-level scoop through the wall.
    var t:=smoothstep(0.,1.,age/BASKET_REACH) if age<BASKET_REACH else 1.-smoothstep(0.,1.,(age-BASKET_REACH)/BASKET_LIFT)
    pose.action_progress=lerpf(BASKET_LIFT_FRAME,BASKET_CONTACT_FRAME,t)/float(Clips.CLIPS.hug_pickup.frames-1)
   else:pose.action_progress=clampf(age/PICKUP_TIME,0,1)
  elif task==Task.PUTDOWN:
   pose.action=&"mine_heavy_putdown";pose.action_progress=clampf(age/PUT_TIME,0,1)
  elif task==Task.THROW:
   if age<THROW_WINDUP:
    pose.action=Pose.ACTION_THROW_CHARGE;pose.action_progress=age/THROW_WINDUP
   elif age<THROW_WINDUP+THROW_RELEASE:
    pose.action=Pose.ACTION_THROW_RELEASE;pose.action_progress=(age-THROW_WINDUP)/THROW_RELEASE
   else:
    pose.action=&"heavy_recover";pose.action_progress=(age-THROW_WINDUP-THROW_RELEASE)/(THROW_TOTAL-THROW_WINDUP-THROW_RELEASE)
 elif task==Task.LEVER:
  pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
  pose.action=&"lever";pose.action_progress=selector_stroke
  room.gap.level.actor.rope_allowed=false
func post_present(delta:float)->void:
 if not room.enabled or room.gap.route.failure_time>0:return
 var actor=room.gap.level.actor
 var hand=actor.hand_local()
 var grasp_at:float=BASKET_REACH if basket_pickup else GRASP_TIME
 if task==Task.PICKUP and age>=grasp_at and not attached and hand!=null:
  var palm:Vector2=actor.body.to_global(hand)
  var center:Vector2=stone_origin-Vector2(0,STONE_CENTER)
  if absf(palm.x-center.x)<(12 if basket_pickup else 29) and absf(palm.y-center.y)<(24 if basket_pickup else 27):
   hand_offset=stone_origin-(palm+ROCK_HAND_OFFSET)
   attached=true;location=Location.ARMS
 if attached and hand!=null:
  # Keep the exact contact offset through the lift; relaxing it while
  # still inside would suck the stone down through the basket floor.
  if task!=Task.PUTDOWN and not (basket_pickup and task==Task.PICKUP):hand_offset=hand_offset.move_toward(Vector2.ZERO,delta*55)
  var carried:Vector2=actor.body.to_global(hand)+ROCK_HAND_OFFSET+hand_offset
  if task==Task.PUTDOWN and carried.y>=place_origin.y and age>.08:
   _place_stone()
  else:
   stone_origin=carried;stone.position=stone_origin;stone.rotation=0
   if extracting and stone_origin.y+STONE_BOTTOM<room.scenery.mechanisms.basket.position.y+room.scenery.mechanisms.BASKET_RIM_Y+2:
    extracting=false;inside_basket=false;_basket_occlusion(false)
 if task==Task.THROW and attached and age>=THROW_DETACH:
  attached=false;location=Location.AIR;_basket_occlusion(true);extracting=false;inside_basket=false;inside_cart=false;bounced=false;throws+=1
  stone_velocity=Vector2(facing*THROW_VELOCITY.x,THROW_VELOCITY.y)
 if task==Task.LEVER:
  var palm:Vector2=actor.grip_hand_world()
  var grip:Vector2=room.scenery.mechanisms.selector_grip()
  var contact:=Vector2(grip.x,clampf(palm.y,grip.y-8,grip.y+8))
  actor.body.position.x+=contact.x-palm.x
  # Begin only after the reaching hand actually holds the selector.
  if not trip_started and age>LEVER_TIME*.42 and absf(palm.y-contact.y)<.5:
   target_top=lever_raising;trip_started=true
   room.mechanical_impulse(grip,.018)
 _register_weight()
func _place_stone()->void:
 attached=false;hand_offset=Vector2.ZERO;_basket_occlusion(true);extracting=false
 location=Location.BASKET if place_in_basket else Location.GROUND
 stone_origin=_basket_stone_origin() if place_in_basket else place_origin
 stone.position=stone_origin;stone.rotation=room.scenery.mechanisms.basket.rotation if place_in_basket else 0.0
 if place_in_basket:sway_speed+=.018*float(room.gap.level.facing)
 _stone_impact(stone_origin)
 room.mechanical_impulse(stone_origin,-.016)
 _register_weight()
func _register_weight()->void:
 room.pressure.set_ballast("hoist_stone",stone_origin+Vector2(0,STONE_BOTTOM),location==Location.GROUND and not attached)
func tick_world(delta:float)->void:
 if not room.enabled or room.gap.route.failure_time>0:return
 var now_loaded:=loaded()
 if now_loaded!=was_loaded:
  # A changing load releases / takes up tension, then settles naturally.
  if not now_loaded:
   sway_speed+=load_tilt*.12
   basket_bob_velocity-=12.
  load_pulse=1.0 if now_loaded else -1.0
  room.mechanical_impulse(room.scenery.mechanisms.basket.position,-.018 if now_loaded else .009)
  was_loaded=now_loaded
 load_blend=move_toward(load_blend,1.0 if now_loaded else 0.0,delta*3.2)
 load_pulse*=exp(-delta*4.5)
 var travel:float=room.scenery.mechanisms.basket_travel
 var target:float=travel if target_top else 0.0
 var remaining:float=target-rise
 var acceleration:float=36.0 if loaded() else 95.0
 var maximum:float=58.0 if loaded() else 104.0
 var desired:float=signf(remaining)*minf(maximum,sqrt(2*acceleration*absf(remaining)))
 previous_speed=speed
 speed=move_toward(speed,desired,acceleration*delta)
 var next:=rise+speed*delta
 if (target-rise)*(target-next)<=0 or absf(remaining)<.05:
  if absf(speed)>1:
   completed_trips+=1;sway_speed+=.020 if loaded() else .033
   room.mechanical_impulse(room.scenery.mechanisms.basket.position,-.024 if loaded() else -.010)
   room.pressure._emit_dust(room.scenery.mechanisms.basket.position+Vector2(0,26),4 if loaded() else 2)
  rise=target;speed=0
 else:rise=clampf(next,0,travel)
 var left:=delta
 var length:float=maxf(100,room.scenery.mechanisms.basket_rest.y-rise-room.scenery.mechanisms.CROWN.y-128)
 while left>0:
  var step:=minf(left,1.0/120.0);left-=step
  var effort:float=lerpf(.35,1.0,load_blend)
  var drive:float=sin(rise/18.0)*absf(speed)*.00035*effort
  # A dock parks the hoist, but the cradle hangs clear of the ground.
  # Keep gravity and damping active rather than pinning the load flat.
  var stiffness:float=maxf(980.0/length,3.0 if docked() else 0.0)
  var damping:float=1.35 if docked() else lerpf(1.7,1.05,load_blend)
  basket_bob_velocity+=(-65.*basket_bob-5.8*basket_bob_velocity)*step
  basket_bob+=basket_bob_velocity*step
  # An off-centre load rolls the basket underneath its suspension eye;
  # it does not leave a permanently diagonal suspension rope.
  var target_tilt:float=atan(load_offset_x*.65/84.)*load_blend
  load_tilt_velocity+=((target_tilt-load_tilt)*24.-4.*load_tilt_velocity)*step
  load_tilt+=load_tilt_velocity*step
  sway_speed+=(-stiffness*sin(sway)-damping*sway_speed+drive)*step
  sway=clampf(sway+sway_speed*step,-.065,.065)
 _present_basket()
 room.scenery.mechanisms.basket_rope.tick_motion(delta,loaded(),speed)
 if location==Location.AIR:_tick_stone_flight(delta)
 if location==Location.CART:
  stone_origin=room.relay.stone_seat();stone.position=stone_origin;stone.rotation=room.relay.pitches[0]
 if plate_locked():
  # A load rides the button face through its full stroke; it must not
  # remain suspended at the pedal's original, unpressed height.
  stone_origin.y=room.MID_Y+room.pressure.depression-STONE_BOTTOM+1.0
  stone.position=stone_origin
 _register_weight()
func _stone_impact(at:Vector2)->void:
 var floor_at:float=_contact_floor(at)
 var contact:=Vector2(at.x,minf(at.y+STONE_BOTTOM,floor_at)-2)
 if location==Location.AIR and inside_basket:
  contact.y=minf(contact.y,room.scenery.mechanisms.basket.position.y-12)
 room.pressure._emit_dust(contact,7)
 var motes:Array=room.pressure.motes
 for i in range(maxi(0,motes.size()-7),motes.size()):
  motes[i].v.y*=1.5;motes[i].size*=1.3;motes[i].life*=1.2
  motes[i].opacity=2.1;motes[i].tone=.34
func _tick_stone_flight(delta:float)->void:
 var old:=stone_origin
 stone_velocity.y+=980*delta;stone_origin+=stone_velocity*delta
 if place_in_cart:
  var car:Vector2=room.relay.cart_at(0)
  if not inside_cart and stone_velocity.y>0 and old.y<car.y-52 and stone_origin.y>=car.y-52 and absf(stone_origin.x-car.x)<32:
   inside_cart=true;stone_velocity.x*=.18
  if inside_cart and stone_velocity.y>0 and stone_origin.y>=room.relay.stone_seat().y:
   stone_origin=room.relay.stone_seat();stone_velocity=Vector2.ZERO;location=Location.CART
   _stone_impact(stone_origin);room.mechanical_impulse(car,-.04)
  elif not inside_cart and stone_velocity.y>0 and stone_origin.y+STONE_BOTTOM>=_contact_floor(stone_origin):
   stone_origin.y=_contact_floor(stone_origin)-STONE_BOTTOM+2;location=Location.GROUND;stone_velocity=Vector2.ZERO;_stone_impact(stone_origin)
  stone.position=stone_origin;stone.rotation=0
  return
 var basket=room.scenery.mechanisms.basket
 var rim:float=basket.position.y+room.scenery.mechanisms.BASKET_RIM_Y
 if not inside_basket and stone_velocity.y>0 and old.y+STONE_BOTTOM<rim and stone_origin.y+STONE_BOTTOM>=rim:
  if absf(stone_origin.x-basket.position.x)<28:
   inside_basket=true
 # Resolve actual basket-wall contact while airborne. Do not clamp the
 # landing to a preferred seat; the retained x is the load's real location.
 if inside_basket:
  var local:Vector2=basket.to_local(stone_origin)
  if absf(local.x)>20.:
   var side:float=signf(local.x)
   local.x=side*20.;stone_origin=basket.to_global(local)
   if stone_velocity.x*side>0:stone_velocity.x*= -.28
 var landing:Vector2=basket.to_local(stone_origin)
 if inside_basket and stone_velocity.y>0 and landing.y>=room.scenery.mechanisms.BASKET_SEAT_Y-STONE_BOTTOM:
  var impact_speed:float=stone_velocity.y
  load_offset_x=landing.x
  landing.y=room.scenery.mechanisms.BASKET_SEAT_Y-STONE_BOTTOM
  stone_origin=basket.to_global(landing)
  if not bounced:
   bounced=true
   # Vertical momentum compresses the rope; eccentric impact also rolls
   # the cradle. Both impulses depend on the actual contact, then decay.
   basket_bob_velocity+=clampf(impact_speed*.20,30.,70.)
   load_tilt_velocity+=clampf(impact_speed*load_offset_x*.000045,-.24,.24)
   sway_speed+=clampf(stone_velocity.x*.0035,-.15,.15)
   stone_velocity=Vector2(stone_velocity.x*.35,-minf(40,impact_speed*.12))
   _stone_impact(stone_origin);room.mechanical_impulse(stone_origin,-.04)
  else:
   location=Location.BASKET;stone_velocity=Vector2.ZERO
 elif not inside_basket and stone_velocity.y>0 and stone_origin.y+STONE_BOTTOM>=_contact_floor(stone_origin):
  stone_origin.y=_contact_floor(stone_origin)-STONE_BOTTOM+2
  location=Location.GROUND;stone_velocity=Vector2.ZERO;_stone_impact(stone_origin)
 stone.position=stone_origin
 stone.rotation=sin(age*4)*.08 if location==Location.AIR else 0.0
 if location==Location.AIR:
  var center:=Vector2(0,-STONE_CENTER)
  stone.position=stone_origin+center-center.rotated(stone.rotation)
func _present_basket()->void:
 var art=room.scenery.mechanisms
 art.set_basket_rise(rise)
 var length:float=maxf(100,art.basket_rest.y-rise-art.CROWN.y-128)
 art.basket.position+=Vector2(sin(sway)*length,(cos(sway)-1)*length)
 # The cradle now hangs above both landings, including while docked.
 var suspended:=.55+.45*sin(PI*clampf(rise/maxf(1,art.basket_travel),0,1))
 art.basket.position.y+=suspended*(load_blend*2.2+load_pulse*1.5)
 art.basket.position.y+=basket_bob
 art.basket.rotation=-sway+load_tilt
 # Rotate around the suspension eye, not the basket's floor. The eye
 # stays attached while a right-heavy basket hangs lower on its right.
 var eye:=Vector2(0,-84)
 art.basket.position+=eye-eye.rotated(art.basket.rotation)
 art.sync_basket_front()
 art._sync_ropes()
 if location==Location.BASKET:
  stone_origin=_basket_stone_origin();stone.position=stone_origin;stone.rotation=art.basket.rotation
