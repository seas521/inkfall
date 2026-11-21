extends Node2D
# Two visible masses, two elastic buffers, one ballistic exit. No speed gates:
# hammer energy -> 1D cart impulse -> uphill work -> flight under gravity.
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const Contacts=preload("res://scripts/chapters/mine_contact_solver.gd")
const Pendulum=preload("res://scripts/chapters/mine_pendulum_dynamics.gd")
const ValleyExit=preload("res://scripts/chapters/mine_valley_exit.gd")
const SLIDER_TRAVEL:=42.0
const SLIDER_HANDLE_X:=38.0
const SLIDER_STANCE_X:=SLIDER_HANDLE_X+23.0
const Art=preload("res://scripts/chapters/mine_relay_art.gd")
const STAGE_X:=808.0
const THIRD_X:=1350.0
const CART_MASS:=220.0
const DONOR_CHASSIS_MASS:=300.0
const LOAD_MASS:=80.0
const HAMMER_MASS:=8000.0
const GRAVITY:=980.0
const LENGTH:=470.0
const MAX_ANGLE:=1.28
const PARK_ANGLE:=.60
const PIVOT:=Vector2(740,-3417)
const LEVER:=Vector2(1080,-2938)
const RAMP_START:=1630.0
const RAMP_END:=1890.0
const RAMP_HEIGHT:=110.0
const EXIT_X:=2310.0
const EXIT_END:=3630.0
const CART_STOP_X:=2670.0
const EXIT_Y:=-2928.0
const RESTITUTION:=.72
const CART_GAP:=73.0
const BUMPER_HALF:=36.5
const RECEIVER_CENTER:=1140.0
const HAMMER_RADIUS:=39.0
const HEAD_CENTER:=Vector2(0,3)
const HEAD_HALF:=Vector2(32,31)
enum State {READY,WINDING,COUNTDOWN,SWINGING,ROLLING,FLIGHT,LANDED,FAILED}
var room
var art:Node2D
var exit_scene:Node2D
var cart_detached:=false
var state:=State.READY
var angle:=0.0
var angular_speed:=0.0
var charge:=0.0
var countdown:=0.0
var lever_age:=0.0
var lever_contact:=false
var charge_owner:=false
var hammer_struck:=false
var collision_done:=false
var velocities:=[0.0,0.0]
# Manual placement parks the car; only external impacts start free rolling.
var impact_driven:=[false,false]
# Only the upturned launch bend returns a manually released cart. The
# puzzle room floor and arranged staging positions remain parked.
var ramp_return:=[false,false]
var distances:=[0.0,0.0]
var positions:=[Vector2.ZERO,Vector2.ZERO]
var pitches:=[0.0,0.0]
var suspension:=[0.0,0.0]
var suspension_v:=[0.0,0.0]
var airborne:=false
var flight_velocity:=Vector2.ZERO
var flight_rotation:=0.0
var rider:=-1
var ride_age:=0.0
var seat_blend:=Vector2.ZERO
var dismount_lock:=0.0
var air_active:=false
var air_momentum:=0.0
var impact_grace:=0.0
var incoming_speed:=0.0
var checkpoint_active:=false
var checkpoint_load:=false
var checkpoint_stone:=Vector2.ZERO
var checkpoint_location:=0
var completed:=false
var terminal_age:=0.0
var failures:=0
var attempts:=0
var last_collision:Dictionary={}
var landing_speed:=0.0
var exit_dwell:=0.0
var hand_gap:=0.0
var handle_y:=LEVER.y-8.0
var transition_age:=-1.0
var handoff_done:=false
var transition_layer:CanvasLayer
var transition_shade:ColorRect
var restoring:=false
var rolling_back:=false
var previous_feet:=Vector2.ZERO
var cart_landed:=false
var arrival_checkpoint:=false
var exit_cart_falling:=false
var cart_lost:=[false,false]
var donor_airborne:=false
var donor_velocity:=Vector2.ZERO
var checkpoint_bays:=[STAGE_X,THIRD_X]
var checkpoint_restraint_cleared:=false
var impact_shift:=[0.0,0.0]
var contact_age:=-1.0
var contact_duration:=.065
var contact_out:=[0.0,0.0]
var contact_cooldown:=0.0
var contact_quality:=1.0
var strike_spacing:=[0.0,0.0]
var collision_serial:=0
var collision_shake:=0.0
var warning_strength:=0.0
var wind_start_angle:=0.0
var hammer_age:=0.0
var hammer_settling:=false
var last_hammer_contact:Dictionary={}
var rail_bodies:Array[StaticBody2D]=[]
var slider_position:=0.0
var slider_velocity:=0.0
var slider_distance:=0.0
var slider_lamp:=0.0
var iron_restitution:=Vector2(.45,.40)
var contact_solver:=Contacts.new()
var contact_sides:=[1.0,-1.0]
var rail_joint:=[0,0]
var traction_pitch:=[0.0,0.0]
var control_side:=-1.0
var lever_stroke:=0.0
var motor_engagement:=0.0
var brake_amount:=1.0
var pendulum_live:=false
var clutch_release:=0.0
var haul_blocked:=false
var wrecked:=false
var wreck_age:=0.0
var wreck_strain:=0.0
var wreck_spin:=0.0
var wreck_impact_speed:=0.0
var wreck_camera_anchor:=Vector2.ZERO
var release_camera_time:=0.0
var release_camera_weight:=0.0
var release_camera_settling:=false
var wind_start_slider:=0.0
var haul_started_parked:=false
var valley_visited:=false
var hammer_body:StaticBody2D
func setup(owner_room)->void:
 room=owner_room
 exit_scene=ValleyExit.new();exit_scene.relay=self;add_child(exit_scene)
 art=Art.new();art.relay=self;add_child(art)
 _build_track()
 hammer_body=StaticBody2D.new();hammer_body.name="solid_impact_head"
 hammer_body.collision_layer=33;hammer_body.collision_mask=0
 var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new()
 box.size=HEAD_HALF*2;shape.shape=box;hammer_body.add_child(shape);add_child(hammer_body)
 reset(false)
func reset(clear_checkpoint:bool=true)->void:
 if exit_scene!=null and exit_scene.detached:exit_scene.restore_to_mine()
 if cart_detached:
  room.carts[1].reparent(room);room.carts[1].position=Vector2.ZERO
  room.cart_bodies[1].reparent(room);cart_detached=false
 _release_passenger()
 state=State.READY;angle=PARK_ANGLE;angular_speed=0;charge=0;countdown=0;lever_age=0
 strike_spacing=[0.0,0.0]
 release_camera_time=0.0
 release_camera_weight=0.0;wind_start_slider=0.0;haul_started_parked=false
 release_camera_settling=false
 charge_owner=false;lever_contact=false;hammer_struck=false;collision_done=false
 impact_driven=[false,false];ramp_return=[false,false]
 velocities=[0.0,0.0];distances=[0.0,0.0];pitches=[0.0,0.0];suspension=[0.0,0.0];suspension_v=[0.0,0.0]
 airborne=false;air_active=false;flight_velocity=Vector2.ZERO;flight_rotation=0
 dismount_lock=0;impact_grace=0;completed=false;terminal_age=0;exit_dwell=0;transition_age=-1
 last_collision={};last_hammer_contact={};landing_speed=0;hand_gap=0
 rolling_back=false
 cart_landed=false;exit_cart_falling=false;cart_lost=[false,false];donor_airborne=false;donor_velocity=Vector2.ZERO
 impact_shift=[0.0,0.0];contact_age=-1;contact_cooldown=0;collision_shake=0;warning_strength=0;hammer_age=0;hammer_settling=false
 handoff_done=false
 wrecked=false;wreck_age=0;wreck_strain=0;wreck_spin=0;wreck_impact_speed=0
 if art!=null:art.wreck_parts.clear();art.reset_slider_feedback()
 slider_position=0;slider_velocity=0;slider_distance=0;slider_lamp=0;contact_solver.clear();contact_sides=[1.0,-1.0];rail_joint=[0,0];traction_pitch=[0.0,0.0]
 control_side=-1;lever_stroke=0;motor_engagement=0;brake_amount=1;clutch_release=0;pendulum_live=false
 if clear_checkpoint:checkpoint_active=false;valley_visited=false;arrival_checkpoint=false
 for i in 2:
  positions[i]=Vector2(room.bays[i],track_y(room.bays[i]));pitches[i]=track_angle(room.bays[i])
  if i<room.carts.size():
   room.carts[i].set_wreck(0)
   room.carts[i].sync_cart(positions[i],pitches[i],0,0,0,1,room.enabled)
 previous_feet=room.gap.route.feet()
 _sync_hammer_body()
func _build_track()->void:
 # Recessed, rooted floor ends before the cantilever. Only the rail has
 # support over the void; walking to the exit cannot replace a cart launch.
 # Meet the preceding walking plane at exactly the same elevation.
 # A 2px raised edge here tilted the capsule's contact normal and briefly
 # ungrounded it during a pull, which correctly cancelled the grip.
 var top:=PackedVector2Array([Vector2(1007,room.TRACK_Y),Vector2(1630,room.TRACK_Y),Vector2(1725,room.TRACK_Y-12),Vector2(1750,room.TRACK_Y+32),Vector2(1722,room.TRACK_Y+620),Vector2(1007,room.TRACK_Y+620)])
 rail_bodies.append(room.gap.route._surface(top,false))
 # The takeoff rail is cart-only: the capsule cannot stroll up a steel
 # cantilever across open air. Cart axles sample this same analytic curve.
func set_enabled(value:bool)->void:
 visible=value
 if exit_scene!=null:exit_scene.set_enabled(value)
 for body in rail_bodies:body.collision_layer=1 if value else 0
 if hammer_body!=null:hammer_body.collision_layer=33 if value else 0
 if not value:_release_passenger();charge_owner=false
func track_y(x:float)->float:
 if x<room.STAIR_END:
  var u:float=clampf((room.STAIR_END-x)/(room.STAIR_END-room.STAIR_START),0,1)
  var f:float=u*u/(.18) if u<.1 else (1-(1-u)*(1-u)/.18 if u>.9 else (u-.05)/.9)
  return room.TRACK_Y-(room.TRACK_Y-room.MID_Y)*f
 var t:=clampf((x-RAMP_START)/(RAMP_END-RAMP_START),0,1)
 return room.TRACK_Y-RAMP_HEIGHT*t*t
func track_angle(x:float)->float:
 if x<room.STAIR_END and x>room.STAIR_START:
  var u:float=clampf((room.STAIR_END-x)/(room.STAIR_END-room.STAIR_START),0,1)
  var derivative:float=u/.09 if u<.1 else ((1-u)/.09 if u>.9 else 1/.9)
  return atan((room.TRACK_Y-room.MID_Y)/(room.STAIR_END-room.STAIR_START)*derivative)
 var t:=clampf((x-RAMP_START)/(RAMP_END-RAMP_START),0,1)
 return -atan(2*RAMP_HEIGHT*t/(RAMP_END-RAMP_START))
func cart_at(index:int)->Vector2:
 return positions[index]
func cart_mass(index:int)->float:
 # The relay is now arranged by spacing, not by extra cargo. Its striking
 # car has a fixed tuned assembly mass; cargo does not unlock more power.
 return DONOR_CHASSIS_MASS if index==0 else CART_MASS+(LOAD_MASS if rider==index else 0.0)
func stone_loaded()->bool:
 return room.hoist!=null and room.hoist.location==room.hoist.Location.CART
func can_load(at:Vector2)->bool:
 return can_manipulate(0) and absf(velocities[0])<12 and absf(at.x-room.bays[0])<100 and absf(at.y-positions[0].y)<18
func stone_seat()->Vector2:
 # Sit behind the near wall, with a clear upper portion above the rim.
 return positions[0]+Vector2(7,-42).rotated(pitches[0])
func staged()->bool:return absf(room.bays[0]-STAGE_X)<65
func contact_gap()->float:return CART_GAP
func on_launch_bend(index:int)->bool:
 return not cart_lost[index] and not (airborne if index==1 else donor_airborne) and not (index==1 and cart_landed) and room.bays[index]>RAMP_START+.5 and room.bays[index]<RAMP_END
func exit_cart_supported(x:float)->bool:
 # Once the centre passes the lip, the remaining axle cannot balance the
 # chassis indefinitely. The right wheel may still contact the bank while
 # it tips; that unilateral support is resolved in the falling update.
 return x>=EXIT_X+4.
func release_exit_cart()->void:
 if not cart_landed or exit_cart_supported(room.bays[1]):return
 var speed:float=velocities[1]
 room.release_cart()
 cart_landed=false;airborne=true;exit_cart_falling=true;impact_driven[1]=true
 state=State.FLIGHT;flight_rotation=pitches[1]
 flight_velocity=Vector2(speed,35.)
 dismount_lock=.28
func restore_arrival()->Vector2:
 room.release_cart();_release_passenger();charge_owner=false
 if exit_scene.detached:exit_scene.restore_to_mine()
 if cart_detached:
  room.carts[1].reparent(room);room.carts[1].position=Vector2.ZERO
  room.cart_bodies[1].reparent(room);cart_detached=false
 handoff_done=false;room.gap.route.in_c_zone=false;room.gap.route.active=true
 cart_landed=true;airborne=false;exit_cart_falling=false;cart_lost[1]=false;completed=true
 wrecked=false;wreck_age=0.;wreck_strain=0.;rolling_back=false
 air_active=false;impact_driven[1]=false;ramp_return[1]=false
 velocities[1]=0.;pitches[1]=0.;suspension[1]=0.;suspension_v[1]=0.
 state=State.LANDED;dismount_lock=.28
 room.bays[1]=CART_STOP_X;positions[1]=Vector2(CART_STOP_X,EXIT_Y)
 room.cart_bodies[1].position=positions[1];room.cart_bodies[1].rotation=0.
 room.cart_bodies[1].collision_layer=33
 room.carts[1].set_wreck(0.);art.wreck_parts.clear()
 room.set_enabled(true)
 var home_x:=CART_STOP_X+112.
 return Vector2(home_x,exit_scene.ground_y(home_x))
func can_manipulate(index:int)->bool:
 return not cart_lost[index] and not (airborne if index==1 else donor_airborne) and absf(velocities[index])<145
func relay_runup_quality()->float:
 # Capture the actual spacing when a hammer stroke drives a car toward
 # its partner. Close-packed buffers cannot deliver a full relay stroke.
 return smoothstep(130.0,220.0,maxf(strike_spacing[0],strike_spacing[1]))
func _save_attempt()->void:
 checkpoint_active=true;checkpoint_load=stone_loaded()
 room.gap.route.checkpoint_step=room.gap.route.MOUTH_STEP
 checkpoint_stone=room.hoist.stone_origin;checkpoint_location=room.hoist.location
 checkpoint_bays=room.bays.duplicate()
 checkpoint_restraint_cleared=room.restraint_cleared
func restore_attempt()->Vector2:
 failures+=1;restoring=true
 var loaded:=checkpoint_load
 var saved_stone:=checkpoint_stone
 var saved_location:=checkpoint_location
 # A death restarts the relay layout, not the last player-arranged or
 # post-impact positions. Keep the already completed restraint unlock.
 room.release_cart();room.bays=[STAGE_X,THIRD_X];room.carts_joined=false
 room.restraint_cleared=checkpoint_restraint_cleared or room.restraint_cleared
 reset(false)
 var hoist=room.hoist
 hoist.task=hoist.Task.NONE;hoist.attached=false;hoist.hand_offset=Vector2.ZERO
 hoist.location=hoist.Location.CART if loaded else saved_location
 hoist.stone_origin=stone_seat() if loaded else saved_stone
 hoist.stone.position=hoist.stone_origin;hoist.stone.rotation=0;hoist.stone.visible=true
 hoist._register_weight()
 for i in 2:
  room.cart_bodies[i].position=positions[i];room.cart_bodies[i].rotation=pitches[i]
  room.cart_bodies[i].collision_layer=33
 if room.restraint_cleared:
  room.pressure.rise=room.scenery.mechanisms.CLAMP_TRAVEL;room.pressure.released=true;room.pressure._present()
 room.gap.level.scene1.low_stance.reset()
 restoring=false
 return Vector2(LEVER.x-28,room.TRACK_Y)
func _release_passenger()->void:
 rider=-1;ride_age=0
 if room!=null and room.gap!=null and room.gap.level!=null:
  var level=room.gap.level
  level.player.collision_mask=11 if room.gap.route.in_c_zone else 43
  for body in room.cart_bodies:level.player.remove_collision_exception_with(body)
func debug_prepare(with_ballast:bool)->void:
 room.release_cart();room.ladders.cancel();room.bays=[STAGE_X,THIRD_X];room.carts_joined=true
 reset()
 var hoist=room.hoist
 hoist.task=hoist.Task.NONE;hoist.attached=false
 hoist.location=hoist.Location.CART if with_ballast else hoist.Location.GROUND
 hoist.stone_origin=stone_seat() if with_ballast else Vector2(room.pressure.plate_rest.x,room.MID_Y+3)
 hoist.stone.position=hoist.stone_origin;hoist.stone.rotation=0;hoist.stone.visible=true;hoist._register_weight()
 _save_attempt()
 var level=room.gap.level
 level.player.position=Vector2(LEVER.x-28,room.TRACK_Y)-Vector2(13,54)
 level.player.velocity=Vector2.ZERO;level.jump_buffer=0;level.jump_windup_left=0;level.climb_time=-1
 level.scene1.low_stance.reset();room.gap.route.fall_origin=room.TRACK_Y
 level.camera_x=160;level.camera_y=-3525;level.camera.position=Vector2(800,-3165)
func _board(index:int)->void:
 var level=room.gap.level
 var old_mass:=cart_mass(index)
 # A late boarding passenger contributes their real horizontal momentum.
 if absf(velocities[index])>1:
  velocities[index]=(old_mass*velocities[index]+LOAD_MASS*level.player.velocity.x)/(old_mass+LOAD_MASS)
 rider=index;ride_age=0;air_active=false
 seat_blend=room.gap.route.feet()-positions[index]
 level.scene1.low_stance.reset();level.jump_buffer=0;level.jump_windup_left=0
 level.player.collision_mask=0;level.player.velocity=Vector2.ZERO
 level.player.move_and_slide() # clear the old roof/ground contact while seated
 for body in room.cart_bodies:level.player.add_collision_exception_with(body)
func _try_board()->bool:
 if rider>=0 or dismount_lock>0 or room.hoist.owns_motion() or room.cart_gripped:return false
 var level=room.gap.level
 if level.climb_time>=0 or level.jump_windup_left>0 or level.player.velocity.y< -1:return false
 var p:Vector2=room.gap.route.feet()
 for i in 2:
  if i==1 and airborne:continue
  var local:Vector2=(p-positions[i]).rotated(-pitches[i])
  if absf(local.x)<39 and absf(local.y+47)<9 and level.player.is_on_floor():
   _board(i);return true
 return false
func can_dismount(index:int)->bool:
 # The takeoff bend and unsupported flight form one seated launch.
 # A fresh jump here used the cached rail speed and injected another
 # full upward impulse, letting an underpowered car bypass the gap.
 if index==1 and cart_landed:return true
 if (airborne if index==1 else donor_airborne):return false
 return not (room.bays[index]>=RAMP_START and velocities[index]>10.0)
func tick_control(delta:float)->bool:
 var level=room.gap.level
 if not room.enabled or room.gap.route.failure_time>0 or completed:
  charge_owner=false;return false
 if room.ladders.active() or room.hoist.owns_motion():return false
 if not checkpoint_active and room.gap.route.feet().x>940:_save_attempt()
 if _try_board():return true
 if rider>=0:
  var supported_dismount:=can_dismount(rider)
  if not supported_dismount:
   # Do not bank a forbidden midair press for an automatic jump on landing.
   level.jump_buffer=0;level.jump_windup_left=0;level.coyote=0
  if Input.is_action_just_pressed("jump") and supported_dismount:
   var source:=rider
   var launch_speed:float=incoming_speed if source==0 and impact_grace>0 else velocities[source]
   var motion:=Vector2(launch_speed,0).rotated(pitches[source])
   _release_passenger();dismount_lock=.28;air_active=true
   # Preserve momentum at the last loaded axle, including the short
   # compression/rebound interval during which the buffers are in contact.
   air_momentum=motion.x
   level._launch_jump(Pose.HOOD_JUMP_SCALE)
   level.player.velocity.x=motion.x+Input.get_axis("move_left","move_right")*228
   level.player.velocity.y+=minf(0,motion.y)
   level.player.move_and_slide()
   return true
  ride_age+=delta
  var seat:Vector2=positions[rider]+Vector2(0,-47).rotated(pitches[rider])
  level.player.position=seat-Vector2(13,54);level.player.velocity=Vector2.ZERO
  room.gap.route.fall_origin=seat.y
  return true
 if charge_owner:
  if not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump"):
   _release_hammer()
   return false
  lever_age+=delta;level.facing=-control_side
  var before:Vector2=room.gap.route.feet()
  var requested:=slider_position
  if lever_contact:
   var input:=Input.get_axis("move_left","move_right")
   var heading:float=signf(input) if absf(input)>.1 else control_side
   slider_velocity=move_toward(slider_velocity,heading*38,delta*130)
   requested=clampf(slider_position+slider_velocity*delta,-SLIDER_TRAVEL,SLIDER_TRAVEL)
  var desired_dx:float=requested-slider_position
  var foot_target:float=LEVER.x+requested+control_side*SLIDER_STANCE_X
  level.player.velocity=Vector2(clampf((foot_target-before.x)/maxf(delta,.001),-75,75),40)
  level.player.move_and_slide()
  if lever_contact:
   var moved:float=room.gap.route.feet().x-before.x
   var actual:float=clampf(moved,minf(0,desired_dx),maxf(0,desired_dx))
   slider_position+=actual;slider_distance+=absf(actual)
   if absf(desired_dx)<.001:slider_velocity=0
  lever_stroke=minf(1,lever_age/.32)
  return true
 var p:Vector2=room.gap.route.feet()
 var side:float=signf(p.x-(LEVER.x+slider_position))
 if Input.is_action_just_pressed("interact") and not room.cart_gripped and room.cart_grip_candidate(p)<0 and absf(Input.get_axis("move_left","move_right"))<.1 and level.player.is_on_floor() and absf(p.x-(LEVER.x+slider_position))>20 and absf(p.x-(LEVER.x+slider_position+side*SLIDER_STANCE_X))<40 and absf(p.y-room.TRACK_Y)<15:
  strike_spacing=[0.0,0.0]
  release_camera_time=0.0
  release_camera_weight=0.0
  release_camera_settling=false
  _save_attempt();attempts+=1;charge_owner=true;lever_age=0;lever_contact=false;state=State.WINDING
  control_side=side;lever_stroke=0;motor_engagement=0;clutch_release=0;slider_distance=0
  level.actor.grip_distance=0
  charge=clampf(angle*control_side/MAX_ANGLE,0,1);wind_start_angle=angle
  wind_start_slider=slider_position;haul_started_parked=not pendulum_live and absf(angular_speed)<.005
  # Capture the existing pendulum, never zero its speed when re-gripped.
  level.actor.reset_grip_animation();level.scene1.low_stance.reset()
  return true
 if air_active:
  var input:=Input.get_axis("move_left","move_right")
  air_momentum*=exp(-.018*delta)
  level._update_player(delta,input,0,air_momentum+input*228,750)
  # Catch only an actual descending roof crossing, never attract the
  # capsule from the side or undo an intentional dismount.
  if dismount_lock<=0 and level.player.velocity.y>=0:
   var feet:Vector2=room.gap.route.feet()
   for i in 2:
    if i==1 and airborne:continue
    var roof:float=positions[i].y-47
    if absf(feet.x-positions[i].x)<39 and previous_feet.y<=roof+8 and feet.y>=roof-5 and feet.y<roof+32:
     _board(i);return true
  if level.player.is_on_floor():
   if _try_board():return true
   air_active=false
  room.gap.route.fall_origin=room.gap.route.feet().y
  return true
 return false
func lever_hand()->Vector2:
 return Vector2(LEVER.x+slider_position+control_side*SLIDER_HANDLE_X,handle_y)
func crash_camera_owns()->bool:
 if wrecked:return wreck_age<.35
 if rider!=1 or not airborne or flight_velocity.x<=1:return false
 var travel_time:float=maxf(0,(EXIT_X-24-positions[1].x)/flight_velocity.x)
 var wall_y:float=positions[1].y+flight_velocity.y*travel_time+.5*GRAVITY*travel_time*travel_time
 return wall_y>EXIT_Y+14
func camera_owns()->bool:
 return room.enabled and (crash_camera_owns() or ((charge_owner or state==State.COUNTDOWN) and absf(room.gap.route.feet().x-LEVER.x)<400) or release_camera_owns())
func release_camera_owns()->bool:
 return (release_camera_weight>0 or release_camera_settling) and not charge_owner and not room.ladders.active() and room.gap.route.failure_time<=0
func present_camera(delta:float)->void:
 var level=room.gap.level
 if crash_camera_owns():
  # Frame the actual failed trajectory. A death at the old high camera's
  # bottom edge was hidden under the film vignette before it could read.
  var focus:Vector2=wreck_camera_anchor if wrecked else positions[1]
  var follow:=1-exp(-delta*8)
  level.camera_x=lerpf(level.camera_x,focus.x-620,follow)
  level.camera_y=lerpf(level.camera_y,focus.y-410,follow)
  level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
  if wrecked:room.gap.route.failure_center=(focus-Vector2(level.camera_x,level.camera_y)).clamp(Vector2(160,120),Vector2(1120,600))
  return
 if release_camera_owns():
  # Retain the shot after letting go. Frame the real head, left car and
  # player together so the strike does not disappear under the vignette.
  var player:Vector2=room.gap.route.feet()
  var head:Vector2=PIVOT+Vector2(sin(angle),cos(angle))*LENGTH
  var left:float=minf(minf(head.x-56,positions[0].x-60),player.x-40)
  var right:float=maxf(maxf(head.x+56,positions[0].x+60),player.x+50)
  var target_x:=clampf((left+right)*.5-640,player.x-1120,player.x-160)
  var target_y:=clampf((minf(head.y-35,player.y-60)+maxf(head.y+35,player.y))*.5-360,room.TRACK_Y-610,room.TRACK_Y-510)
  var normal_target:=Vector2(player.x-538,level._camera_target_y())
  var target:=normal_target.lerp(Vector2(target_x,target_y),release_camera_weight)
  var follow:=1-exp(-delta*3.6)
  var current:=Vector2(level.camera_x,level.camera_y)
  var max_speed:float=maxf(300.0,absf(velocities[rider])+120.0) if rider>=0 else 300.0
  var next:=current.move_toward(current.lerp(target,follow),delta*max_speed)
  level.camera_x=next.x;level.camera_y=next.y
  level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
  return
 var weight:=1-exp(-delta*3.2)
 level.camera_x=lerpf(level.camera_x,160.0,weight)
 level.camera_y=lerpf(level.camera_y,-3525.0,weight)
 level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
func _release_hammer()->void:
 # Let go of the haul clutch immediately. Angle and angular momentum
 # remain continuous; gravity starts the next half-swing without a pause.
 charge_owner=false;lever_contact=false;motor_engagement=0
 clutch_release=.7 if pendulum_live else 0.0
 release_camera_time=2.6 if pendulum_live else 0.0
 release_camera_weight=1.0 if pendulum_live else 0.0
 release_camera_settling=pendulum_live
 if pendulum_live:
  state=State.SWINGING
  hammer_age=0
 else:state=State.READY
 room.mechanical_impulse(LEVER,-.012)
func warning_offset()->Vector2:
 var time:float=room.gap.route.clock
 return Vector2(sin(time*TAU*9.5),sin(time*TAU*7.3+.7)*.55)*warning_strength*1.6
func contact_camera_offset()->Vector2:
 var time:float=room.gap.route.clock
 return Vector2(sin(time*57),cos(time*69))*(collision_shake*9)
func tick_world(delta:float)->void:
 if room==null or not room.enabled:return
 if not valley_visited and room.gap.route.feet().x>850:
  room.gap.route.prepare_c_zone_preview()
 release_camera_time=maxf(0,release_camera_time-delta)
 if rider>=0 or absf(room.gap.route.feet().x-LEVER.x)>=450:release_camera_time=0.0
 if release_camera_time<=0:release_camera_weight=move_toward(release_camera_weight,0,delta/(.55 if rider>=0 else 1.6))
 if release_camera_weight<=0 and release_camera_settling:
  var level=room.gap.level
  var normal_target:=Vector2(room.gap.route.feet().x-538,level._camera_target_y())
  if Vector2(level.camera_x,level.camera_y).distance_to(normal_target)<40:release_camera_settling=false
 if room.gap.route.failure_time>0:release_camera_time=0.0;release_camera_weight=0.0;release_camera_settling=false
 _sync_hammer_body()
 if room.gap.route.failure_time>0:
  if wrecked and not cart_lost[1]:_tick_wreck(delta)
  elif airborne:
   flight_velocity.y+=GRAVITY*delta;positions[1]+=flight_velocity*delta
   pitches[1]+=delta*.9;distances[1]+=flight_velocity.x*delta
  if donor_airborne:
   donor_velocity.y+=GRAVITY*delta;positions[0]+=donor_velocity*delta;pitches[0]+=delta
  for body in room.cart_bodies:body.collision_layer=0
  art.tick(delta)
  return
 dismount_lock=maxf(0,dismount_lock-delta);impact_grace=maxf(0,impact_grace-delta)
 previous_feet=room.gap.route.feet()
 collision_shake=move_toward(collision_shake,0,delta*1.5)
 var step_left:=minf(delta,.10)
 while step_left>.000001:
  var h:=minf(step_left,1.0/120.0);step_left-=h
  _integrate(h)
  if room.gap.route.failure_time>0:
   art.tick(delta)
   return
 _sync_hammer_body()
 for i in 2:
  if not cart_lost[i] and not (airborne if i==1 else donor_airborne):
   positions[i]=Vector2(room.bays[i],EXIT_Y if i==1 and cart_landed else track_y(room.bays[i]));pitches[i]=0.0 if i==1 and cart_landed else track_angle(room.bays[i])
  var rail_supported:bool=not cart_lost[i] and not (airborne if i==1 else donor_airborne)
  var joint:int=floori((room.bays[i]+23)/88.0)
  if rail_supported and joint!=rail_joint[i] and absf(velocities[i])>45:
   suspension_v[i]+=clampf(absf(velocities[i])*.008,1,7)*(1.0 if joint%2==0 else -.65)
   traction_pitch[i]+=sin(float(joint)*2.4)*.012
  rail_joint[i]=joint
  traction_pitch[i]*=exp(-delta*9)
  suspension_v[i]+=(-suspension[i]*72-suspension_v[i]*7.2)*delta
  suspension[i]+=suspension_v[i]*delta
  room.cart_bodies[i].position=positions[i]
  room.cart_bodies[i].rotation=pitches[i]
  room.cart_bodies[i].collision_layer=0 if rider==i or cart_lost[i] or (airborne if i==1 else donor_airborne) else 33
 if rider>=0:
  room.gap.level.player.position=positions[rider]+Vector2(0,-47).rotated(pitches[rider])-Vector2(13,54)
 var p:Vector2=room.gap.route.feet()
 if p.x>1750 and p.y>room.TRACK_Y+330 and not completed:room.gap.route.fail()
 if state in [State.LANDED,State.FAILED]:terminal_age+=delta
 # Losing an unattended car does not arbitrarily kill a safe player.
 # The crank offers a local retry; genuine passenger falls still fail.
 if cart_landed and not arrival_checkpoint:
  var grounded_here:bool=room.gap.level.player.is_on_floor() and p.x>=EXIT_X+24. and absf(p.y-exit_scene.ground_y(p.x))<18.
  if rider==1 or grounded_here:arrival_checkpoint=true
 if cart_landed and p.x>EXIT_X+260 and rider<0 and room.gap.level.player.is_on_floor():
  completed=true
 if completed and p.x>=ValleyExit.JOIN_X and not handoff_done:_begin_handoff()
 if art!=null:art.tick(delta)
func _sync_hammer_body()->void:
 if hammer_body==null:return
 hammer_body.position=PIVOT+Vector2(sin(angle),cos(angle))*LENGTH+HEAD_CENTER.rotated(-angle)
 hammer_body.rotation=-angle
func _head_overlaps_cart(index:int,at_x:float,at_angle:float=NAN)->bool:
 var hammer:=_hinge_contact_body()
 hammer.q=angle if is_nan(at_angle) else at_angle
 var cart:=_rail_contact_body(index,at_x)
 return not Contacts.manifold(Contacts.shape(hammer),Contacts.shape(cart),0.0).is_empty()
func limit_manual_cart(index:int,from_x:float,to_x:float)->float:
 if is_equal_approx(from_x,to_x):return from_x
 var body:=_rail_contact_body(index,from_x)
 var obstacles:Array=[{"body":_hinge_contact_body()}]
 for other in 2:
  if other!=index and _cart_on_rail(other):obstacles.append({"body":_rail_contact_body(other),"self_shape":"buffer","other_shape":"buffer"})
 var axis_x:float=Vector2(body.axis).x
 var accepted:=Contacts.limit_translation(body,obstacles,(to_x-from_x)/maxf(.25,axis_x))
 return from_x+accepted*axis_x
func _head_overlaps_player(at_angle:float)->bool:
 var collider:=room.gap.level.player.get_child(0) as CollisionShape2D
 if collider==null or not collider.shape is CapsuleShape2D:return false
 var capsule:=collider.shape as CapsuleShape2D
 var radius:float=capsule.radius*collider.global_scale.x
 var half_axis:float=maxf(0,capsule.height*.5-capsule.radius)
 var bob:=PIVOT+Vector2(sin(at_angle),cos(at_angle))*LENGTH+HEAD_CENTER.rotated(-at_angle)
 var a:Vector2=(collider.to_global(Vector2(0,-half_axis))-bob).rotated(at_angle)
 var b:Vector2=(collider.to_global(Vector2(0,half_axis))-bob).rotated(at_angle)
 var bounds:=Rect2(-HEAD_HALF,HEAD_HALF*2)
 if bounds.has_point(a) or bounds.has_point(b):return true
 var corners:=[-HEAD_HALF,Vector2(HEAD_HALF.x,-HEAD_HALF.y),HEAD_HALF,Vector2(-HEAD_HALF.x,HEAD_HALF.y)]
 for i in 4:
  var closest:=Geometry2D.get_closest_points_between_segments(a,b,corners[i],corners[(i+1)%4])
  if closest[0].distance_squared_to(closest[1])<=radius*radius:return true
 return false
func _check_hammer_player(from_angle:float,to_angle:float)->bool:
 if room.gap.route.failure_time>0 or absf(angular_speed)*LENGTH<45:return false
 var steps:=maxi(1,ceili(absf(to_angle-from_angle)*LENGTH/4.0))
 for i in range(steps+1):
  if _head_overlaps_player(lerpf(from_angle,to_angle,float(i)/steps)):
   var at:Vector2=room.gap.route.feet()-Vector2(0,26)
   room.release_cart();_release_passenger();charge_owner=false;air_active=false
   room.mechanical_impulse(at,.12);collision_shake=.18
   room.gap.route.fail()
   return true
 return false
func _cart_on_rail(index:int)->bool:
 return not cart_lost[index] and not (airborne if index==1 else donor_airborne)
func _hinge_contact_body()->Dictionary:
 var parked_brake:=charge_owner and haul_started_parked and motor_engagement<.999
 var fixed:bool=parked_brake or (not pendulum_live and not charge_owner and absf(angle)>.0012)
 return {"motion":&"hinge","origin":PIVOT,"length":LENGTH,"offset":HEAD_CENTER,"half":HEAD_HALF,"q":angle,"speed":0.0 if parked_brake else angular_speed,"inv":0.0 if fixed else 1.0/(HAMMER_MASS*pow(LENGTH+HEAD_CENTER.y,2)),"fixed":fixed}
func _haul_target_angle()->float:
 var end:float=SLIDER_TRAVEL if slider_position>=wind_start_slider else -SLIDER_TRAVEL
 var span:float=end-wind_start_slider
 var progress:float=clampf((slider_position-wind_start_slider)/span,0,1) if absf(span)>.001 else 1.0
 return lerpf(wind_start_angle,MAX_ANGLE*signf(end),progress)
func _rail_contact_body(index:int,at_x:float=INF)->Dictionary:
 var x:float=room.bays[index] if is_inf(at_x) else at_x
 var landed:bool=index==1 and cart_landed
 var pitch:float=0.0 if landed else track_angle(x)
 var fixed:bool=not _cart_on_rail(index) or (index==0 and room.restraint_locked()) or (room.cart_gripped and room.cart_grip_index==index)
 return {"motion":&"rail","origin":Vector2(x,EXIT_Y if landed else track_y(x)),"axis":Vector2.RIGHT.rotated(pitch),"rotation":pitch,"offset":Vector2(0,-25),"half":Vector2(31,22),"buffer_offset":Vector2(0,-23),"buffer_half":Vector2(BUMPER_HALF,6),"q":0.0,"speed":0.0 if fixed else velocities[index],"inv":0.0 if fixed else 1.0/cart_mass(index),"fixed":fixed,"mass":cart_mass(index)}
func _contact_feedback(event:Dictionary,bodies:Array)->void:
 var normal:Vector2=event.normal
 var impulse:float=event.impulse
 var strength:=0.0
 for entry in [[int(event.a),-1.0],[int(event.b),1.0]]:
  var body_id:int=entry[0]
  if body_id==0:continue
  var index:=body_id-1
  var force:Vector2=normal*impulse*float(entry[1])
  var dv:float=force.length()/cart_mass(index)
  strength=maxf(strength,clampf(dv*.08,0,90))
  suspension_v[index]+=clampf(force.y/cart_mass(index)*.10+dv*.025,-38,38)
  traction_pitch[index]+=clampf(-force.x/cart_mass(index)*.000065,-.06,.06)
  contact_sides[index]=-signf(force.dot(bodies[body_id].axis))
  if absf(velocities[index])>.1:impact_driven[index]=true
 if strength<.25:return
 collision_shake=maxf(collision_shake,clampf(strength*.003,.01,.22))
 room.mechanical_impulse(event.point,clampf(strength*.002,0,.20))
 art.impact(event.point,strength)
 if event.a==0 or event.b==0:
  var index:int=(event.b if event.a==0 else event.a)-1
  var before_omega:float=event.before_a if event.a==0 else event.before_b
  var hammer:Dictionary=bodies[0]
  var hammer_v:Vector2=Contacts.jacobian(hammer,event.point)*before_omega
  hammer_struck=true
  if release_camera_time>0:release_camera_time=minf(release_camera_time,.65)
  var toward_other:float=signf(room.bays[1-index]-room.bays[index])
  var cart_force:Vector2=normal*impulse*(1.0 if event.b==index+1 else -1.0)
  if cart_force.x*toward_other>0:
   strike_spacing=[0.0,0.0];strike_spacing[index]=absf(room.bays[1]-room.bays[0])
  if not charge_owner:state=State.ROLLING
  last_hammer_contact={"cart":index,"x":room.bays[index],"angle":angle,"incoming":hammer_v.x,"outgoing":velocities[index],"point":event.point,"normal":normal,"impulse":impulse,"kind":"roof" if absf(normal.y)>absf(normal.x) else "side","contact_duration":0.0}
 else:
  collision_done=true;collision_serial+=1;impact_grace=.42
  incoming_speed=event.before_a if event.a==1 else event.before_b
  contact_quality=event.pair.quality
  contact_age=0;contact_cooldown=contact_duration
  contact_out=velocities.duplicate()
  var da:float=event.ja*float(bodies[event.a].inv)*impulse
  var db:float=event.jb*float(bodies[event.b].inv)*impulse
  last_collision={"m1":cart_mass(0),"m2":cart_mass(1),"u1":event.before_a,"u2":event.before_b,"v1":event.after_a,"v2":event.after_b,"momentum_error":absf(cart_mass(0)*da+cart_mass(1)*db),"charge":charge,"point":event.point,"normal":normal,"impulse":impulse,"quality":contact_quality,"gap":room.bays[1]-room.bays[0]}
func _advance_contacts(h:float)->void:
 var bodies:Array=[_hinge_contact_body(),_rail_contact_body(0),_rail_contact_body(1)]
 var pairs:Array=[]
 for index in 2:
  if _cart_on_rail(index):pairs.append({"a":0,"b":index+1,"material":&"iron","restitution_low":iron_restitution.x,"restitution_high":iron_restitution.y})
 if _cart_on_rail(0) and _cart_on_rail(1):
  var quality:=relay_runup_quality()
  pairs.append({"a":1,"b":2,"shape_a":"buffer","shape_b":"buffer","material":&"buffer","quality":quality,"restitution":lerpf(.28,RESTITUTION,quality)})
 var previous_angle:=angle
 var events:Array=contact_solver.step(bodies,pairs,h)
 angle=bodies[0].q;angular_speed=bodies[0].speed
 if not bodies[0].fixed and absf(angular_speed)>.0008:pendulum_live=true
 for index in 2:
  if not _cart_on_rail(index):continue
  var old:float=room.bays[index]
  room.bays[index]+=float(bodies[index+1].q)*Vector2(bodies[index+1].axis).x
  distances[index]+=float(room.bays[index])-old
  velocities[index]=bodies[index+1].speed
  if absf(velocities[index])>.1:impact_driven[index]=true
 if _check_hammer_player(previous_angle,angle):return
 haul_blocked=charge_owner and not contact_solver.last_contacts.is_empty() and absf(angular_speed)<.03
 for event in events:_contact_feedback(event,bodies)
func _integrate(h:float)->void:
 release_exit_cart()
 contact_cooldown=maxf(0,contact_cooldown-h)
 warning_strength=0.0;haul_blocked=false
 if state==State.COUNTDOWN:
  # Old checkpoint/debug states release directly under the new control.
  pendulum_live=true;state=State.SWINGING
 if charge_owner and lever_contact:pendulum_live=true
 if state==State.SWINGING:pendulum_live=true
 clutch_release=maxf(0,clutch_release-h)
 var band_target:float=1.0 if charge_owner or not pendulum_live else clutch_release/.7
 brake_amount=move_toward(brake_amount,band_target,h*6)
 if not charge_owner:
  slider_velocity+=(-48*slider_position-12*slider_velocity)*h
  slider_position=clampf(slider_position+slider_velocity*h,-SLIDER_TRAVEL,SLIDER_TRAVEL)
  if absf(slider_position)<.02 and absf(slider_velocity)<.05:slider_position=0;slider_velocity=0
  lever_stroke=move_toward(lever_stroke,0,h*3.5)
 slider_lamp=move_toward(slider_lamp,1.0 if absf(slider_position)>SLIDER_TRAVEL-.65 else 0.0,h*7)
 motor_engagement=move_toward(motor_engagement,1.0 if charge_owner and lever_contact else 0.0,h*3.5)
 if pendulum_live and not (charge_owner and haul_started_parked and motor_engagement<.999):
  hammer_age+=h
  var target:float=_haul_target_angle() if charge_owner and lever_contact else NAN
  var integrated:Vector2=Pendulum.step(Vector2(angle,angular_speed),h,LENGTH+HEAD_CENTER.y,GRAVITY,target,motor_engagement,2.5*clutch_release/.7)
  angular_speed=integrated.y
  charge=clampf(angle*control_side/MAX_ANGLE,0,1) if charge_owner else charge
  if not charge_owner and absf(angle)<.0012 and absf(angular_speed)<.0008:
   angle=0;angular_speed=0;pendulum_live=false
   if state==State.SWINGING:state=State.READY
 if contact_age>=0:
  contact_age+=h
  var compression:=sin(clampf(contact_age/contact_duration,0,1)*PI)*2.7
  impact_shift=[compression,compression]
  if contact_age>=contact_duration:impact_shift=[0.0,0.0];contact_age=-1
 # External forces first. The shared solver then advances and resolves all
 # contacts together; visual compression never owns positions or speeds.
 for i in 2:
  if not _cart_on_rail(i) or (room.cart_gripped and room.cart_grip_index==i):continue
  if i==0 and room.restraint_locked():velocities[i]=0;continue
  if not impact_driven[i]:
   if on_launch_bend(i):impact_driven[i]=true;ramp_return[i]=true
   else:velocities[i]=0;continue
  var old:float=room.bays[i]
  var pitch:float=0.0 if i==1 and cart_landed else track_angle(old)
  velocities[i]+=GRAVITY*sin(pitch)*h
  var resistance:float=120.0 if old<740 else (220.0 if i==1 and cart_landed else (100.0 if absf(velocities[i])<300 else 24.0))
  if ramp_return[i] and on_launch_bend(i):resistance=minf(18.0,absf(GRAVITY*sin(pitch))*.20)
  velocities[i]=move_toward(velocities[i],0,resistance*h)
  if ramp_return[i] and not on_launch_bend(i) and absf(velocities[i])<.1:ramp_return[i]=false;impact_driven[i]=false
 _advance_contacts(h)
 if room.gap.route.failure_time>0:return
 for i in 2:
  if _cart_on_rail(i) and room.bays[i]<room.STAIR_START+20:
   room.bays[i]=room.STAIR_START+20;velocities[i]=0
 if not donor_airborne and not cart_lost[0] and room.bays[0]>=RAMP_END:
  donor_airborne=true;positions[0]=Vector2(RAMP_END,track_y(RAMP_END));donor_velocity=Vector2(velocities[0],0).rotated(track_angle(RAMP_END))
 if donor_airborne:
  donor_velocity.y+=GRAVITY*h;positions[0]+=donor_velocity*h
  room.bays[0]=positions[0].x;pitches[0]+=h*.6
  if positions[0].y>room.TRACK_Y+650:cart_lost[0]=true;donor_airborne=false
 if not cart_landed and not airborne and not cart_lost[1] and room.bays[1]>=RAMP_END:
  airborne=true;state=State.FLIGHT;room.bays[1]=RAMP_END
  positions[1]=Vector2(RAMP_END,track_y(RAMP_END));flight_rotation=track_angle(RAMP_END)
  flight_velocity=Vector2(velocities[1],0).rotated(flight_rotation)
  art.impact(positions[1]+Vector2(-18,0),14)
 if not airborne and not cart_landed and not cart_lost[1] and room.bays[1]>RAMP_START and velocities[1]<=0 and collision_done:
  rolling_back=true
  if state not in [State.WINDING,State.COUNTDOWN,State.SWINGING]:state=State.FAILED
 if airborne and wrecked:
  _tick_wreck(h)
 elif airborne:
  var before:Vector2=positions[1]
  flight_velocity.y+=GRAVITY*h;positions[1]+=flight_velocity*h
  room.bays[1]=positions[1].x;distances[1]+=flight_velocity.x*h
  if exit_cart_falling:
   # Roll tail-first over the lip. The remaining right axle supports the
   # car until it clears the bank instead of falling through solid earth.
   flight_rotation=maxf(-PI,flight_rotation-h*.9)
   var support:=Vector2(24,0).rotated(flight_rotation)
   if positions[1].x+support.x>=EXIT_X and positions[1].y+support.y>EXIT_Y:
    positions[1].y=EXIT_Y-support.y;flight_velocity.y=0.
  else:flight_rotation=move_toward(flight_rotation,atan2(flight_velocity.y,flight_velocity.x),h*.8)
  pitches[1]=flight_rotation
  var wall_x:float=exit_scene.face_x(positions[1].y-18)
  if before.x<wall_x-24 and positions[1].x>=wall_x-24 and positions[1].y>EXIT_Y+14:
   _crash_into_bank(wall_x)
   return
  if before.y<=EXIT_Y and positions[1].y>=EXIT_Y and flight_velocity.y>0 and positions[1].x>=EXIT_X+20:
   airborne=false;exit_cart_falling=false;cart_landed=true;state=State.LANDED;positions[1].y=EXIT_Y;pitches[1]=0
   landing_speed=flight_velocity.length();suspension_v[1]=minf(120,flight_velocity.y*.22);velocities[1]=flight_velocity.x*.70;terminal_age=0
   room.mechanical_impulse(positions[1],.16);art.impact(positions[1],70)
  elif positions[1].y>room.TRACK_Y+650:
   cart_lost[1]=true;state=State.FAILED;terminal_age=0;airborne=false;velocities[1]=0
   if rider==1:room.gap.route.fail()
 if cart_landed and room.bays[1]>CART_STOP_X and velocities[1]>0:
  room.bays[1]=CART_STOP_X;velocities[1]*= -.12;suspension_v[1]-=35;art.impact(Vector2(room.bays[1],EXIT_Y),24)
func _crash_into_bank(wall_x:float=EXIT_X)->void:
 if wrecked:return
 wrecked=true;wreck_age=0;wreck_strain=0
 wreck_impact_speed=flight_velocity.length()
 var incoming:=flight_velocity
 positions[1].x=wall_x-32;room.bays[1]=positions[1].x
 wreck_camera_anchor=positions[1]
 flight_velocity=Vector2(-clampf(absf(incoming.x)*.20,85,180),maxf(100,incoming.y*.32))
 wreck_spin=clampf(absf(incoming.x)*.004,2.0,3.4)
 state=State.FAILED;collision_shake=.48
 suspension[1]=4;suspension_v[1]=75
 var contact:=Vector2(wall_x-2,maxf(EXIT_Y+5,positions[1].y-18))
 art.bank_crash(contact,incoming)
 room.mechanical_impulse(contact,.22)
 if rider==1:
  _release_passenger();air_active=false
  var level=room.gap.level
  level.player.velocity=Vector2(-clampf(absf(incoming.x)*.16,80,150),maxf(100,incoming.y*.28))
  level.jump_buffer=0;level.jump_windup_left=0;level.coyote=0
  room.gap.route.fail()
  # A stale seated floor contact must never play a grounded impact in air.
  room.gap.route.failure_airborne=true;level.player.collision_mask=0
func _tick_wreck(delta:float)->void:
 wreck_age+=delta
 wreck_strain=smoothstep(0,.14,wreck_age)
 collision_shake=move_toward(collision_shake,0,delta*1.7)
 flight_velocity.y+=GRAVITY*delta
 flight_velocity.x*=exp(-delta*.45)
 positions[1]+=flight_velocity*delta;room.bays[1]=positions[1].x
 wreck_spin=move_toward(wreck_spin,1.4,delta*.7)
 pitches[1]+=wreck_spin*delta
 distances[1]+=maxf(100,wreck_impact_speed)*exp(-wreck_age*.8)*delta
 suspension[1]=4*exp(-wreck_age*9)*cos(wreck_age*31)
 if positions[1].y>room.TRACK_Y+650:
  cart_lost[1]=true;airborne=false
func apply_pose(pose)->void:
 if charge_owner:
  pose.action_progress=minf(1,lever_age/.32);pose.facing=-control_side;pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
  pose.action=&"grip_engage" if lever_age<.32 else (&"grip_hold" if absf(slider_velocity)<.5 else (&"pull" if slider_velocity*control_side>0 else &"push"))
  var actor=room.gap.level.actor
  actor.rope_allowed=false;actor.rope_hold=0;actor.grip_distance=slider_distance
  actor.contact_reach=22.5;actor.contact_sink=1
 elif rider>=0:
  pose.action=&"mine_cart_ride";pose.action_progress=minf(1,ride_age/.25)
  var seat:=Vector2(-8,-37).rotated(pitches[rider])+Vector2(0,suspension[rider])
  pose.feet=positions[rider]+seat_blend.lerp(seat,smoothstep(0,.25,ride_age))
  pose.velocity=Vector2.ZERO;pose.facing=1;pose.grounded=true;pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
func slider_palm_world()->Vector2:
 var actor=room.gap.level.actor
 var hand:Vector2=actor.body.to_local(actor.grip_hand_world())
 var tracks:Dictionary=preload("res://scripts/chapters/mine_slider_palm_tracks.gd").HEIGHTS
 var rows:Array=tracks.get(String(actor.current_clip),[])
 if not rows.is_empty():hand.y=float(rows[clampi(actor.current_frame_index,0,rows.size()-1)])
 return actor.body.to_global(hand)
func post_present()->void:
 if charge_owner:
  var actor=room.gap.level.actor
  # Keep the filmed feet grounded. The crank's rocker grip follows the
  # native hand height; translating the whole torso to a fixed grip used
  # to lift the shoes by up to fifteen pixels during a loaded stroke.
  actor.body.position.y+=room.TRACK_Y+4-room.ladders.sole_world_y()
  var hand:Vector2=slider_palm_world()
  handle_y=clampf(hand.y,room.TRACK_Y-43.5,room.TRACK_Y-17)
  var grip:=lever_hand()
  var strength:=smoothstep(0,.32,lever_age)
  actor.body.position.x+=(grip.x-hand.x)*strength
  hand_gap=slider_palm_world().distance_to(grip)
  if strength>.99:lever_contact=true
 if rider>=0:room.gap.level.actor.rotation=pitches[rider]+clampf(-suspension_v[rider]*.002,-.12,.12)
func valley_preview_active()->bool:
 return room!=null and room.enabled and not room.gap.route.in_c_zone and room.gap.level.camera_x>800
func _begin_handoff()->void:
 if handoff_done:return
 arrival_checkpoint=true
 var level=room.gap.level
 var foot:Vector2=room.gap.route.feet()-ValleyExit.C_OFFSET
 var velocity:Vector2=level.player.velocity
 var camera_at:=Vector2(level.camera_x,level.camera_y)-ValleyExit.C_OFFSET
 exit_scene.detach_to_c()
 room.carts[1].reparent(level);room.carts[1].position=-ValleyExit.C_OFFSET
 room.cart_bodies[1].reparent(level);room.cart_bodies[1].position-=ValleyExit.C_OFFSET
 cart_detached=true;handoff_done=true
 _release_passenger()
 if not valley_visited:
  room.gap.route._reach_c_zone();valley_visited=true
 else:
  room.gap.route.active=false;room.gap.route.in_c_zone=true
  room.gap.route.ride_t=-1;level.log_bridge.active=false
  level.player.collision_mask=11;room.gap.route.art.sync(0)
 level.player.position=foot-Vector2(13,54);level.player.velocity=velocity
 level.camera_x=camera_at.x;level.camera_y=camera_at.y
 level.camera.position=camera_at+Vector2(640,360)
 level.air_top_y=level.player.position.y
 level.art.position=Vector2.ZERO
 level.art.sync(0,level.camera_x,true)
func try_return_from_valley()->bool:
 if not handoff_done or not exit_scene.detached:return false
 var level=room.gap.level
 var foot:Vector2=room.gap.route.feet()
 # Hysteresis before the legacy x < -300 forest boundary. The return is
 # the same physical bank, not a new spawn or a reset of C's progress.
 if foot.x>=ValleyExit.JOIN_X-ValleyExit.C_OFFSET.x-80:return false
 var mine_foot:Vector2=foot+ValleyExit.C_OFFSET
 if absf(mine_foot.y-exit_scene.ground_y(mine_foot.x))>240:return false
 if level.death_time>0 or level.marsh_hit_time>0:return false
 var velocity:Vector2=level.player.velocity
 var camera_at:=Vector2(level.camera_x,level.camera_y)+ValleyExit.C_OFFSET
 exit_scene.restore_to_mine()
 room.carts[1].reparent(room);room.carts[1].position=Vector2.ZERO
 room.cart_bodies[1].reparent(room);room.cart_bodies[1].position=positions[1]
 cart_detached=false;handoff_done=false
 room.gap.route.in_c_zone=false;room.gap.route.active=true
 level.player.position=mine_foot-Vector2(13,54);level.player.velocity=velocity
 level.player.collision_mask=43;level.air_top_y=level.player.position.y
 room.gap.route.fall_origin=mine_foot.y
 level.camera_x=camera_at.x;level.camera_y=camera_at.y
 level.camera.position=camera_at+Vector2(640,360)
 room.gap.route.art.sync(0)
 level.art.sync(0,level.camera_x,true)
 return true
