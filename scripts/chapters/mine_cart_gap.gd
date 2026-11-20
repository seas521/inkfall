extends Node2D
# Physical continuation of the mine: remove the chock, roll the cart back up
# its grade, jump from the derailed car and catch the suspended service deck.
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const Art=preload("res://scripts/chapters/mine_cart_gap_art.gd")
const RAIL_END:=-952.0
const ActorClips=preload("res://scripts/actors/hood_actor_manifest.gd")
const PICKUP_TIME:=float(ActorClips.CLIPS["hug_pickup"]["frames"])/60.0
const PICKUP_GRASP:=float(ActorClips.CLIPS["hug_pickup"]["grasp_frame"])/60.0
const THROW_RECOVER:=float(ActorClips.CLIPS["hug_recover"]["frames"])/60.0
const THROW_WINDUP:=float(ActorClips.CLIPS["hug_throw_charge"]["frames"])/60.0
const THROW_RELEASE:=float(ActorClips.CLIPS["hug_throw_release"]["frames"])/60.0
const THROW_DETACH:=THROW_WINDUP+float(ActorClips.CLIPS["hug_throw_release"]["detach_frame"])/60.0
const DECK_ANCHOR:=Vector2(-728,-3400)
const DECK_LENGTH:=331.0
const DECK_SIZE:=Vector2(90,14)
const BANK_X:=-600.0
const BANK_Y:=-3050.0
var trial
var escape
var route
var level
var art
var rail_body:StaticBody2D
var deck:AnimatableBody2D
var bank:StaticBody2D
var phase:=0.0
var omega:=0.0
var tilt:=0.0
var tilt_speed:=0.0
var deck_velocity:=Vector2.ZERO
var deck_before:=Transform2D.IDENTITY
var deck_loaded:=false
var climbing_deck:=false
var corner_local:=Vector2.ZERO
var end_local:=Vector2.ZERO
var platform_reached:=false
var bank_reached:=false
var catches:=0
var coast:=false
var boarding_window:=0.0
var launched:=false
var flight_age:=0.0
var fall_pitch:=0.0
var rail_chips:Array[Dictionary]=[]
var jump_from_cart:=false
var jump_from_deck:=false
var air_momentum:=0.0
var cart_jump_control:=228.0
var air_active:=false
var source_car:=false
var source_deck:=false
var rock_state:=0 # 0 chock, 1 pickup, 2 held, 3 throw, 4 removed, 5 grounded, 6 flying
var rock_age:=0.0
var rock_air:=false
var rock_released:=false
var rock_attached:=false
var rock_grip_offset:=Vector2.ZERO
var rock_approach_x:=0.0
var rock_approach_age:=0.0
var rock_track_velocity:=Vector2.ZERO
var rock_velocity:=Vector2.ZERO
var rock_angle:=0.0
var rock_visible:=true
var rock_cleared:=false
var rock_origin:=Vector2.ZERO
var rock_position:=Vector2.ZERO
var rock_facing:=1.0
var deck_dwell:=0.0
var bank_polygon:=PackedVector2Array()

func _ready()->void:
 escape=trial.escape;route=trial.route;level=route.level
 level.actor.load_group("hug");level.actor.load_group("small");level.actor.load_group("climb")
 rail_body=StaticBody2D.new();rail_body.collision_layer=1;rail_body.collision_mask=0
 var rail_shape:=CollisionShape2D.new();var rail_rect:=RectangleShape2D.new()
 rail_rect.size=Vector2(RAIL_END-escape.EDGE_X+4,8);rail_shape.shape=rail_rect
 rail_shape.position=Vector2((RAIL_END+escape.EDGE_X)*.5,rail_y(RAIL_END)+3)
 rail_body.add_child(rail_shape);add_child(rail_body)
 deck=AnimatableBody2D.new();deck.sync_to_physics=false;deck.collision_layer=1;deck.collision_mask=0
 deck.set_meta("cliff_handhold",true);deck.set_meta("cliff_handhold_step",4)
 var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=DECK_SIZE
 shape.shape=rect;shape.one_way_collision=true;deck.add_child(shape);add_child(deck)
 bank_polygon=PackedVector2Array([Vector2(BANK_X,BANK_Y),Vector2(BANK_X+60,BANK_Y-3),Vector2(150,BANK_Y-2),Vector2(950,BANK_Y+13),Vector2(950,-2300),Vector2(BANK_X-45,-2300),Vector2(BANK_X-18,-2710),Vector2(BANK_X-42,-2810),Vector2(BANK_X-20,-2890),Vector2(BANK_X-29,-2972),Vector2(BANK_X-6,-3025)])
 bank=route._surface(bank_polygon,false)
 bank.set_meta("cliff_handhold",true);bank.set_meta("cliff_handhold_step",5)
 art=Art.new();art.gap=self;add_child(art)
 reset()

func reset()->void:
 if art!=null and art.pair_room!=null and art.pair_room.ladders!=null:art.pair_room.ladders.cancel()
 if art!=null and art.pair_room!=null:art.pair_room.reset_puzzle()
 level.player.remove_collision_exception_with(escape.chock_body)
 phase=-.10;omega=0;tilt=0;tilt_speed=0
 flight_age=0;fall_pitch=0;rail_chips.clear()
 coast=false;boarding_window=0;launched=false;platform_reached=false;bank_reached=false;catches=0
 air_active=false;air_momentum=0;jump_from_cart=false;jump_from_deck=false;climbing_deck=false
 deck_loaded=false;deck_dwell=0;rock_state=0;rock_age=0
 rock_origin=escape.chock_body.position;rock_position=rock_origin
 rock_air=false;rock_released=false;rock_attached=false;rock_grip_offset=Vector2.ZERO;rock_visible=true;rock_cleared=false;rock_velocity=Vector2.ZERO;rock_angle=0
 place_deck();deck_before=deck.transform
 if art!=null:art.queue_redraw()

func enabled()->bool:return not route.shaft_preview
func rail_y(_x:float)->float:return route.mine_floor_base_y(escape.EDGE_X)
func deck_center()->Vector2:return DECK_ANCHOR+Vector2(sin(phase),cos(phase))*DECK_LENGTH
func place_deck()->void:deck.transform=Transform2D(tilt,deck_center())
func standing_on_deck()->bool:
 var p:=deck.to_local(route.feet())
 return level.player.is_on_floor() and absf(p.x)<DECK_SIZE.x*.5+7 and absf(p.y+DECK_SIZE.y*.5)<10

func tick_world(delta:float)->void:
 var active:bool=route.enabled and not route.in_c_zone and enabled()
 visible=active
 rail_body.collision_layer=1 if active else 0;deck.collision_layer=1 if active else 0
 bank.collision_layer=0 # multi-level room owns the landing and open shaft
 if not active:return
 boarding_window=maxf(0,boarding_window-delta)
 if route.feet().x>-1510:level.player.platform_floor_layers=0
 var was_loaded:=standing_on_deck()
 var local_feet:=deck.to_local(route.feet())
 var previous:=deck.transform
 var load:float=clampf(local_feet.x/(DECK_SIZE.x*.5),-1,1) if was_loaded else 0.0
 var forcing:=sin(route.clock*1.53)*.065+sin(route.clock*.83)*.018
 omega+=(-(850.0/DECK_LENGTH)*sin(phase)-.30*omega+forcing+load*.05)*delta
 # The service deck cannot swing through the facing rock bank.
 var limit:=asin(clampf((BANK_X-DECK_SIZE.x*.5-50-DECK_ANCHOR.x)/DECK_LENGTH,0,.25))
 phase=clampf(phase+omega*delta,-.20,limit)
 if phase>=limit and omega>0:omega*= -.15
 tilt_speed+=((load*.16-tilt)*43.0-tilt_speed*6.8)*delta
 tilt=clampf(tilt+tilt_speed*delta,-.20,.20)
 place_deck();deck_velocity=(deck.position-previous.origin)/maxf(delta,.001)
 if was_loaded and level.climb_time<0:
  level.player.position+=deck.to_global(local_feet)-previous*local_feet
 if was_loaded and not deck_loaded:
  omega+=clampf(level.player.velocity.x,-300,300)*.0004;tilt_speed+=load*.65
 deck_loaded=was_loaded
 if was_loaded and level.climb_time<0:
  deck_dwell+=delta
  if deck_dwell>.12:platform_reached=true
 else:deck_dwell=0
 if level.climb_time>=0 and climbing_deck:
  level.climb_corner=deck.to_global(corner_local)
  level.climb_end_feet=deck.to_global(end_local)
 if level.player.is_on_floor() and route.feet().x>BANK_X+18 and absf(route.feet().y-BANK_Y)<18:
  bank_reached=true;air_active=false
 if rock_air:
  var previous_rock:=rock_position
  rock_velocity.y+=980*delta;rock_position+=rock_velocity*delta;rock_angle+=2.7*delta
  # The thrown load hits the actual car instead of travelling through its
  # black body and coming to rest invisibly inside it.
  var query:=PhysicsRayQueryParameters2D.create(previous_rock,rock_position,32)
  query.hit_from_inside=true
  var hit:Dictionary=level.player.get_world_2d().direct_space_state.intersect_ray(query)
  if not hit.is_empty():
   var normal:Vector2=hit.normal
   if normal.length_squared()<.5:normal=Vector2.RIGHT if rock_velocity.x<0 else Vector2.LEFT
   rock_position=Vector2(hit.position)+normal*16
   rock_velocity=rock_velocity.bounce(normal)*.3
   if normal.y< -.7 and absf(rock_velocity.y)<70:
    rock_air=false;rock_state=5 if rock_state!=3 else 3;rock_angle=0
  if rock_position.x>escape.EDGE_X+14:
   rock_cleared=true
   if rock_state==6:rock_state=4
  if rock_position.x<escape.EDGE_X-12 and rock_position.y>=trial.ground(rock_position.x)-9 and rock_velocity.y>0:
   rock_position.y=trial.ground(rock_position.x)-9;rock_air=false;rock_velocity=Vector2.ZERO
   if rock_state!=3:rock_state=5
  if rock_position.y>rail_y(RAIL_END)+650:rock_air=false;rock_visible=false
 for chip in rail_chips:
  chip.age+=delta;chip.v.y+=980*delta;chip.p+=chip.v*delta;chip.angle+=chip.spin*delta
 rail_chips=rail_chips.filter(func(chip):return chip.age<2.2)
 art.tick(delta)

func cart_position()->Vector2:
 if escape.falling:return Vector2(trial.cart_x,escape.air_y)
 return Vector2(trial.cart_x,rail_y(trial.cart_x) if trial.cart_x>escape.EDGE_X else trial.ground(trial.cart_x))

func cart_flight(delta:float)->void:
 if not escape.saved:return
 if not coast and not launched and trial.cart_x<=RAIL_END+21:return
 if not launched and trial.cart_x>RAIL_END+21:
  launched=true;coast=true;flight_age=0;escape.falling=true;escape.air_y=rail_y(RAIL_END);escape.air_vy=0
  if trial.operation=="recover":trial.operation=""
  for i in 7:
   escape._emit_spark(true)
   escape.sparks[-1].p=Vector2(RAIL_END,rail_y(RAIL_END)-2)+Vector2(float(i%3),0)
  for i in 11:
   rail_chips.append({"p":Vector2(RAIL_END-10+float(i)*1.5,rail_y(RAIL_END)+5),"v":Vector2(20+sin(i*3.2)*42,-8-absf(sin(i*2.8))*39),"age":0.0,"angle":sin(i*7),"spin":sin(i*2)*4,"length":2.0+float(i%3)*2})
 if launched:
  flight_age+=delta
  escape.air_vy+=980*delta;escape.air_y+=escape.air_vy*delta
  # No explosion: front axle loses support first, then gravity pitches the tub.
  fall_pitch=minf(2.6,.11+flight_age*.50+flight_age*flight_age*.28)
  if flight_age>3.5 and (platform_reached or bank_reached):coast=false;trial.cart_speed=0

func try_rock()->bool:
 if not enabled() or not escape.saved or launched:return false
 var p:Vector2=route.feet()
 var pickup_position:Vector2=escape.chock_body.position if rock_state==0 else rock_position
 if rock_state in [0,5] and level.player.is_on_floor() and absf(p.x-pickup_position.x)<53 and absf(p.y-trial.ground(p.x))<16:
  rock_age=0;rock_origin=pickup_position;rock_angle=0;rock_visible=true;rock_attached=false;rock_grip_offset=Vector2.ZERO;rock_approach_age=0
  rock_facing=signf(rock_origin.x-p.x) if absf(rock_origin.x-p.x)>2 else level.facing
  var contact_data:Dictionary=level.HoodManifest.CLIPS["hug_pickup"]
  var contact:Array=contact_data.hold_points[int(contact_data.grasp_frame)]
  var spacing:float=absf(float(contact[0]))*level.actor.DISPLAY_SCALE*Pose.HOOD_VISUAL_SCALE
  rock_approach_x=rock_origin.x-rock_facing*spacing
  level.player.add_collision_exception_with(escape.chock_body)
  rock_state=8 if absf(rock_approach_x-p.x)>3 else 1
  return true
 if rock_state==2 and level.player.is_on_floor():
  rock_state=3;rock_age=0;rock_facing=level.facing;rock_released=false
  return true
 return rock_state in [1,3]

func tick_rock(delta:float)->bool:
 if rock_state not in [1,2,3,8]:return false
 var player=level.player
 if rock_state==8:
  # Walk into reach while the stone stays on the floor. No root teleport.
  rock_approach_age+=delta;level.facing=rock_facing
  var dx:float=rock_approach_x-route.feet().x
  player.velocity=Vector2(clampf(dx/maxf(delta,.001),-48,48),160)
  player.move_and_slide()
  if absf(dx)<1.0:rock_state=1;rock_age=0
  elif rock_approach_age>.95:
   rock_state=0;rock_age=0;player.remove_collision_exception_with(escape.chock_body)
  route.fall_origin=route.feet().y
  return true
 if rock_state==2:
  if Input.is_action_just_pressed("interact"):try_rock()
  var direction:float=Input.get_axis("move_left","move_right")
  if absf(direction)>.1:level.facing=signf(direction)
  var carry_speed:float=Pose.HEAVY_CARRY_SPEED
  player.velocity.x=move_toward(player.velocity.x,direction*carry_speed,delta*180)
  player.velocity.y=minf(500,player.velocity.y+1500*delta);player.move_and_slide()
 else:
  rock_age+=delta;level.facing=rock_facing
  player.velocity.x=0;player.velocity.y=160;player.move_and_slide()
  if rock_state==1:
   if rock_age>PICKUP_GRASP+.18 and not rock_attached:
    rock_state=0;rock_age=0;player.remove_collision_exception_with(escape.chock_body)
   elif rock_age>=PICKUP_TIME and rock_attached:rock_state=2;rock_age=0
  elif rock_state==3:
   if rock_age>=THROW_DETACH and not rock_released:
    rock_released=true;rock_air=true
    rock_velocity=Vector2(rock_facing*clampf(absf(rock_track_velocity.x),145,280),clampf(rock_track_velocity.y,-220,-65));rock_angle=0
   if rock_age>=THROW_WINDUP+THROW_RELEASE+THROW_RECOVER:rock_state=6 if rock_air else (4 if not rock_visible else 5);rock_age=0
 route.fall_origin=route.feet().y
 if route.feet().y>rail_y(RAIL_END)+150:route.fail()
 return true

func apply_rock_pose(pose)->bool:
 if rock_state not in [1,2,3]:return false
 pose.held=0 if rock_attached else -1;pose.equipment=Pose.EQUIPMENT_THROWABLE;pose.small_item_kind=&"mine_heavy"
 pose.heavy_item_offset=rock_grip_offset
 if rock_state==1:
  pose.action=Pose.ACTION_PICKUP
  pose.action_progress=clampf(rock_age/PICKUP_TIME,0,1)
 elif rock_state==3:
  if rock_age<THROW_WINDUP:
   pose.action=Pose.ACTION_THROW_CHARGE;pose.action_progress=rock_age/THROW_WINDUP
  elif rock_age<THROW_WINDUP+THROW_RELEASE:
   pose.action=Pose.ACTION_THROW_RELEASE;pose.action_progress=clampf((rock_age-THROW_WINDUP)/THROW_RELEASE,0,1)
   if rock_age>=THROW_DETACH:pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
  else:
   pose.held=-1;pose.equipment=Pose.EQUIPMENT_NONE
   pose.action=&"heavy_recover";pose.action_progress=clampf((rock_age-THROW_WINDUP-THROW_RELEASE)/THROW_RECOVER,0,1)
 else:pose.action=Pose.ACTION_NONE
 return true

func sync_rock_visual(delta:float=0.0)->void:
 var attached_before:=rock_attached
 var old_position:=rock_position
 if rock_state==8 or rock_state==1 and not rock_attached:rock_position=rock_origin
 var hand=level.actor.hand_local()
 if rock_state==1 and rock_age>=PICKUP_GRASP and not rock_attached and hand!=null:
  var palm:Vector2=level.actor.body.to_global(hand)
  var contact:Vector2=rock_origin-palm
  # The palms must physically enter the stone's lower/side grip region.
  # Preserve their offset: snapping the rock CENTRE to a palm is telekinesis.
  if absf(contact.x)<27 and absf(contact.y)<24:
   rock_grip_offset=level.actor.body.to_local(rock_origin)-hand
   rock_attached=true
   escape.chock_present=false;escape.chock_body.collision_layer=0
   level.player.remove_collision_exception_with(escape.chock_body)
 if attached_before and rock_attached and rock_state in [1,2] and delta>0:
  # Preserve first contact, then draw the load fully into the filmed embrace.
  # Keeping the ground-contact offset forever leaves a lit slit at the chest.
  rock_grip_offset=rock_grip_offset.move_toward(Vector2.ZERO,delta*55)
 if rock_attached and (rock_state in [1,2] or rock_state==3 and not rock_released) and hand!=null:
  rock_position=level.actor.body.to_global(hand+rock_grip_offset)
 if rock_state==3 and not rock_released and delta>0:
  rock_track_velocity=rock_track_velocity.lerp((rock_position-old_position)/delta,.45)
 art.dynamic.queue_redraw()

func grip_allowed()->bool:return rock_cleared or rock_state==0 and not escape.chock_present
func released_cart()->void:
 if not grip_allowed():return
 coast=not escape.chock_present
 boarding_window=1.6

func prepare_move()->void:
 source_car=escape.is_riding()
 source_deck=standing_on_deck()
 if level.player.is_on_floor() and not source_car:air_active=false

func target_velocity(direction:float,delta:float)->float:
 if not air_active:return INF
 air_momentum*=exp(-.065*delta)
 return air_momentum+direction*(228 if jump_from_deck else cart_jump_control)

func after_move(direction:float)->void:
 if (source_car or source_deck) and level.player.velocity.y< -100 and not level.player.is_on_floor():
  air_active=true
  jump_from_cart=source_car;jump_from_deck=source_deck
  # Parked dismount and deliberate rail launch are separate modes.
  # The launch keeps its tuned momentum even while accelerating slowly.
  var rail_launch:bool=coast and absf(trial.cart_speed)>100 and direction*trial.cart_speed>0 and trial.cart_x>escape.EDGE_X-90
  cart_jump_control=90.0 if rail_launch else 228.0
  air_momentum=trial.cart_speed*.88 if source_car else deck_velocity.x*.85
  level.player.velocity.x=air_momentum+direction*(228 if source_deck else cart_jump_control)
 if level.climb_time<0 and not level.player.is_on_floor() and route.feet().x>escape.EDGE_X-20:
  level.climb_prev_velocity=level.player.velocity
  if level._try_begin_climb(direction):
   if deck.to_local(level.climb_corner).length()<DECK_SIZE.x:
    climbing_deck=true;corner_local=deck.to_local(level.climb_corner);end_local=deck.to_local(level.climb_end_feet)
    catches+=1;omega+=.14;air_active=false
   else:climbing_deck=false

func climb_finished()->void:
 if climbing_deck:
  platform_reached=true;climbing_deck=false
 level.player.collision_mask=43

func restore()->Vector2:
 if art!=null and art.pair_room!=null:art.pair_room.reset_puzzle()
 level.player.remove_collision_exception_with(escape.chock_body)
 # Recreate only this short attempt. The escaped mine stays collapsed.
 air_active=false;climbing_deck=false;coast=false;boarding_window=0;launched=false
 flight_age=0;fall_pitch=0;rail_chips.clear()
 escape.falling=false;escape.air_y=0;escape.air_vy=0;escape.riding=false;escape.ride_age=0;escape.dismount_pending=false;escape.cart_shoving=false;escape.shove_support_grace=0
 trial.cart_x=trial.PARK_X;trial.cart_speed=0;trial.operation=""
 escape.braking=false;escape.stop_age=-1
 if rock_state!=0:
  rock_state=4;rock_cleared=true;rock_air=false;rock_visible=false
 escape.chock_present=rock_state==0
 escape.chock_body.collision_layer=1 if escape.chock_present else 0
 escape._set_chock_x(trial.PARK_X+escape.CHOCK_OFFSET)
 if bank_reached:return Vector2(BANK_X+65,BANK_Y)
 if platform_reached:
  phase=.06;omega=0;tilt=0;tilt_speed=0;place_deck()
  return deck.to_global(Vector2(0,-DECK_SIZE.y*.5))
 return Vector2(trial.PARK_X-76,trial.ground(trial.PARK_X-76))
