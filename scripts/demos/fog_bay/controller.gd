extends Node2D
# Independent bay: no inherited level layout, invisible rack, old checkpoints or renderer.
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const Actor=preload("res://scripts/demos/c_zone_debug/hood_river_actor.gd")
const Fan=preload("res://scripts/demos/c_zone_debug/fan_art.gd")
const PLAYER_SIZE=Vector2(26,54)
const CRATE_SIZE=Vector2(144,32)
const FAN_SCALE=.65
const WATER_Y=575.
const BOAT_HULL_PROFILE=[Vector2(-5,-6),Vector2(8,-3),Vector2(36,-1),Vector2(72,0),Vector2(108,-1),Vector2(136,-3),Vector2(149,-6),Vector2(150,10),Vector2(133,27),Vector2(101,34),Vector2(72,35),Vector2(43,34),Vector2(11,27),Vector2(-6,10)]
# Low left launch shoal, open water, high right cliff with two actual rock footholds.
var LEFT_PROFILE=PackedVector2Array([Vector2(-1600,524),Vector2(-400,524),Vector2(-120,534),Vector2(170,543),Vector2(390,550),Vector2(550,557),Vector2(630,570),Vector2(680,583),Vector2(735,612),Vector2(810,662),Vector2(920,780),Vector2(1050,950),Vector2(-1600,1500)])
var RIGHT_PROFILE=PackedVector2Array([Vector2(2200,950),Vector2(2290,790),Vector2(2350,670),Vector2(2390,605),Vector2(2405,575),Vector2(2410,528),Vector2(2420,514),Vector2(2450,514),Vector2(2460,449),Vector2(2500,438),Vector2(2680,424),Vector2(2880,430),Vector2(3100,425),Vector2(3800,430),Vector2(3800,1500)])
var player:CharacterBody2D
var crate:CharacterBody2D
var crate_shape:CollisionShape2D
var actor:Node2D
var fan:Node2D
var art:Node2D
var camera:Camera2D
var pose=Pose.new()
var clock:=0.
var camera_x:=0.
var camera_y:=0.
var facing:=1.
var crate_tilt:=0.
var floating:=true
var fan_owned:=false
var fan_revealed:=true
var fan_on_tree:=true
var fan_on_raft:=false
var fan_ground_facing:=1.
var fan_ground_position:=Vector2(518,438)
var fan_local:=Vector2.ZERO
var dragging:=false
var grip_distance:=0.
var grip_side:=-1.
var grip_age:=0.
var fan_swing:=0.
var wind_pending:=false
var fan_pickup_time:=0.
var death_time:=0.
var checkpoint:=0
var checkpoint_fan:=false
var completed:=false
var heave_velocity:=0.
var pitch_velocity:=0.
var hydro_live:=false
var was_loaded:=false
var immersion_load:=0.
var buoyancy_force:=0.
var buoyancy_moment:=0.
var hud:Label
var jump_grace:=0.
var departure_x:=700.

func _ready()->void:
 get_window().title="Inkfall · 雾湾 / 独立水域 Demo"
 RenderingServer.set_default_clear_color(Color("777777"))
 preload("res://scripts/effects/film_look.gd").attach(self)
 for profile in [LEFT_PROFILE,RIGHT_PROFILE]:
  var body:=StaticBody2D.new();body.collision_layer=1
  var shape:=CollisionPolygon2D.new();shape.polygon=profile;body.add_child(shape);add_child(body)
 player=_body(PLAYER_SIZE,4,3);player.floor_snap_length=12.;player.floor_max_angle=deg_to_rad(48.)
 player.platform_floor_layers=0
 crate=_body(CRATE_SIZE,2,1);crate_shape=crate.get_child(0);crate.floor_snap_length=12.
 camera=Camera2D.new();camera.position=Vector2(530,350);add_child(camera)
 art=preload("res://scripts/demos/fog_bay/art.gd").new();art.level=self;add_child(art)
 actor=Actor.new();actor.z_index=5;add_child(actor)
 fan=Fan.new();fan.z_index=6;add_child(fan)
 var ui:=CanvasLayer.new();ui.layer=30;add_child(ui)
 hud=Label.new();hud.position=Vector2(30,28);hud.add_theme_font_size_override("font_size",16);hud.modulate=Color(.7,.7,.7,.75);ui.add_child(hud)
 restore_checkpoint()

func _body(size:Vector2,layer:int,mask:int)->CharacterBody2D:
 var b:=CharacterBody2D.new();b.collision_layer=layer;b.collision_mask=mask;b.safe_margin=.08
 var s:=CollisionShape2D.new();var r:=RectangleShape2D.new();r.size=size;s.shape=r;s.position=size*.5;b.add_child(s);add_child(b);return b

func ground_y(x:float)->float:
 var result:=1500.
 for profile in [LEFT_PROFILE,RIGHT_PROFILE]:
  for i in range(profile.size()-2):
   var a:Vector2=profile[i];var b:Vector2=profile[i+1]
   if x>=minf(a.x,b.x) and x<=maxf(a.x,b.x) and absf(a.x-b.x)>.01:
    result=minf(result,lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))

 return result

func fan_rest_position()->Vector2:
 return crate.position+fan_local.rotated(crate_tilt) if fan_on_raft else fan_ground_position
func crate_top_at(x:float)->float:
 return crate.position.y+(x-crate.position.x-72.)*tan(crate_tilt)
func is_riding()->bool:
 var feet:=player.position+Vector2(13,54)
 return absf(feet.x-crate.position.x-72.)<73. and absf(feet.y-crate_top_at(feet.x))<13. and player.velocity.y>=-2.
func _shore_limit(angle:float)->float:
 var limit:=1500.
 for x in [-66.,-36.,0.,36.,66.]:
  var bottom:=Vector2(x,18.-9.*pow(x/72.,2.)).rotated(angle)
  limit=minf(limit,ground_y(crate.position.x+72.+bottom.x)-16.-bottom.y)
 return limit
func can_pick_up_fan()->bool:
 if fan_owned or death_time>0:return false
 var hand:=player.position+Vector2(13+facing*14,10)
 return hand.distance_to(fan_rest_position())<35. if fan_on_tree else (player.position+Vector2(13,54)).distance_to(fan_rest_position())<62.
func can_grab()->bool:
 var dx:=absf(player.position.x+13.-crate.position.x-72.)
 return player.is_on_floor() and not is_riding() and dx>70. and dx<120. and absf(player.position.y+36.-crate.position.y)<38.
func _drop_fan()->void:
 fan_owned=false;fan_on_tree=false;fan_on_raft=is_riding()
 fan_ground_position=player.position+Vector2(13+facing*18.,50)
 if fan_on_raft:fan_local=(fan_ground_position-crate.position).rotated(-crate_tilt)
 fan_ground_facing=facing
func swing_fan()->bool:
 if not fan_owned or fan_swing>0. or dragging:return false
 fan_swing=1.63;wind_pending=true;return true

func _physics_process(dt:float)->void:
 clock+=dt
 if Input.is_physical_key_pressed(KEY_R):restore_checkpoint()
 if death_time>0.:
  death_time+=dt
  if death_time>2.7:restore_checkpoint()
  _present(dt);return
 var direction:=Input.get_axis("move_left","move_right")
 var riding:=is_riding()
 var relative:Vector2=(player.position+Vector2(13,54)-crate.position-Vector2(72,16)).rotated(-crate_tilt)
 if Input.is_action_just_pressed("interact"):
  if can_grab() and direction!=0.:
   if fan_owned:_drop_fan()
   dragging=true;grip_side=signf(player.position.x+13.-crate.position.x-72.);grip_age=0.;facing=-grip_side
  elif can_pick_up_fan():
   fan_owned=true;checkpoint_fan=true;fan_on_tree=false;fan_on_raft=false;fan_pickup_time=.48
  elif fan_owned:_drop_fan()
  elif can_grab():
   dragging=true;grip_side=signf(player.position.x+13.-crate.position.x-72.);grip_age=0.;facing=-grip_side
 if not Input.is_action_pressed("interact"):dragging=false
 if Input.is_action_pressed("blade_toggle"):swing_fan()
 if fan_swing>0.:
  var previous:=fan_swing;fan_swing=maxf(0.,fan_swing-dt)
  if previous> .93 and fan_swing<=.93 and wind_pending:
   wind_pending=false;art.emit_gust(player.position+Vector2(13,24),facing)
   if (player.position+Vector2(13,54)).distance_to(crate.position+Vector2(72,0))<245.:
    crate.velocity.x+=facing*135.;crate.velocity.x=clampf(crate.velocity.x,-190.,190.)
    pitch_velocity-=facing*.045
 fan_pickup_time=maxf(0.,fan_pickup_time-dt)
 var old:Vector2=crate.position
 _update_boat(dt,direction,riding)
 if riding:
  player.position=crate.position+Vector2(72,16)+relative.rotated(crate_tilt)-Vector2(13,54)
  player.velocity.y=maxf(0.,heave_velocity)
 var moved:float=crate.position.x-old.x
 if dragging:
  grip_age+=dt;grip_distance+=absf(moved)
  facing=-grip_side
  player.velocity.x=moved/dt+clampf((crate.position.x+72.+grip_side*94.-13.-player.position.x)*12.,-80.,80.)
 else:
  if direction!=0. and fan_swing<=0.:facing=direction
  var speed:float=direction*135. if fan_swing<=0. and fan_pickup_time<=0. else 0.
  player.velocity.x=move_toward(player.velocity.x,speed,600.*dt)
 player.velocity.y=minf(850.,player.velocity.y+1250.*dt)
 jump_grace=maxf(0.,jump_grace-dt)
 if player.is_on_floor() or riding:jump_grace=.10
 if Input.is_action_just_pressed("jump") and jump_grace>0.:
  player.velocity.y=-420.;jump_grace=0.;dragging=false
 player.move_and_slide()
 if floating:art.raft_waves(crate.position.x+72.,70.,crate.velocity.x,heave_velocity,pitch_velocity,dt)
 if not riding and is_riding():art.emit_water_impact(player.position.x+13.,180.,25.)
 if player.position.y>603. and not is_riding() and ground_y(player.position.x+13.)>660.:
  death_time=.001;dragging=false;art.emit_water_impact(player.position.x+13.,220.,25.)
 if player.position.x>2495. and player.is_on_floor():checkpoint=1
 if player.position.x>2980. and player.position.y<450.:completed=true
 _update_camera(dt);_present(dt)

func _update_boat(dt:float,direction:float,riding:bool)->void:
 var support:=_shore_limit(crate_tilt)
 floating=support>551. and crate.position.x>654. and crate.position.x<2420.
 if dragging and grip_age>.25:
  crate.velocity.x=move_toward(crate.velocity.x,direction*75.,380.*dt)
 elif floating:
  var drag:=absf(crate.velocity.x)*.22+crate.velocity.x*crate.velocity.x*.0024
  crate.velocity.x=move_toward(crate.velocity.x,0.,drag*dt)
 else:crate.velocity.x=move_toward(crate.velocity.x,0.,190.*dt)
 if floating:
  _hydrostatics(dt,riding)
  # Move horizontally through collision; vertical hydrostatic displacement was integrated separately.
  var vy:float=crate.velocity.y;crate.velocity.y=0.;crate.move_and_slide();crate.velocity.y=vy
 else:
  hydro_live=false;was_loaded=false;pitch_velocity=0.;heave_velocity=0.
  crate.velocity.y+=1250.*dt
  crate_tilt=lerpf(crate_tilt,atan2(ground_y(crate.position.x+133.)-ground_y(crate.position.x+11.),122.),1.-exp(-dt*5.))
  crate_tilt=clampf(crate_tilt,-.20,.20);crate_shape.rotation=crate_tilt
  crate.move_and_slide()
 if crate.position.x<650.:crate.position.x=650.;crate.velocity.x=maxf(0.,crate.velocity.x)
 if crate.position.x>2796.:crate.position.x=2796.;crate.velocity.x=minf(0.,crate.velocity.x)
 if dragging and not can_grab() and absf(player.position.y+36.-crate.position.y)>55.:dragging=false

func _hydrostatics(delta:float,riding:bool)->void:
 hydro_live=true
 var passenger_mass:=28. if riding else 0.
 var mass:=95.+passenger_mass
 var gravity:=480.
 var inertia:=mass*144.*144./12.
 var passenger_x:=clampf(player.position.x+13.-crate.position.x-72.,-65.,65.)
 if riding and not was_loaded:
  heave_velocity+=clampf(player.velocity.y,0.,320.)*passenger_mass/mass*.32
  pitch_velocity+=clampf(player.velocity.y,0.,320.)*passenger_mass*passenger_x/inertia*.18
 was_loaded=riding
 var steps:=maxi(1,int(ceil(delta*120.)));var dt:=minf(delta,.05)/steps
 for step in steps:
  var force:=mass*gravity;var torque:=passenger_mass*gravity*passenger_x
  var submerged_sum:=0.;var lift_sum:=0.
  for i in 9:
   var lx:float=-64.+16.*i;var bottom:float=19.-10.*pow(absf(lx)/72.,2.)
   var local:=Vector2(lx,bottom).rotated(crate_tilt)
   var at:=crate.position+Vector2(72,16)+local
   var depth:=clampf(at.y-art.water_line(at.x),0.,35.)
   var lift:=depth*660.;force-=lift;torque-=lift*local.x
   submerged_sum+=depth;lift_sum+=lift
  immersion_load=submerged_sum;buoyancy_force=lift_sum;buoyancy_moment=torque
  heave_velocity+=(force/mass-heave_velocity*4.6)*dt
  pitch_velocity+=(torque/inertia-pitch_velocity*3.8)*dt
  crate.position.y+=heave_velocity*dt
  crate_tilt=clampf(crate_tilt+pitch_velocity*dt,-.19,.19)
  if absf(crate_tilt)>=.189:pitch_velocity*=.75
  var support:=_shore_limit(crate_tilt)
  if crate.position.y>support:crate.position.y=support;heave_velocity=minf(heave_velocity,0.);pitch_velocity*=.8
 crate_shape.rotation=crate_tilt;crate.velocity.y=heave_velocity

func _update_camera(dt:float)->void:
 var openness:=smoothstep(600.,1200.,player.position.x)*(1.-smoothstep(2220.,2760.,player.position.x))
 var zoom_target:=lerpf(.96,.74,openness)
 camera.zoom=camera.zoom.lerp(Vector2.ONE*zoom_target,1.-exp(-dt*1.1))
 var centre:=Vector2(clampf(player.position.x+170.,560.,2950.),lerpf(365.,370.,openness))
 camera.position=camera.position.lerp(centre,1.-exp(-dt*2.3))
 camera_x=camera.position.x-640.;camera_y=camera.position.y-360.

func _present(dt:float)->void:
 var action:StringName=Pose.ACTION_NONE;var progress:=0.
 if death_time>0.:action=&"water_drown";progress=clampf(death_time/2.7,0.,1.)
 elif fan_pickup_time>0.:action=Pose.ACTION_PICKUP;progress=1.-fan_pickup_time/.48
 elif fan_swing>0.:action=Pose.ACTION_THROW_RELEASE;progress=1.-fan_swing/1.63
 elif dragging:
  if grip_age<.25:action=&"grip_engage";progress=grip_age/.25
  elif absf(crate.velocity.x)<1.:action=&"grip_hold"
  else:action=&"pull" if crate.velocity.x*facing<0. else &"push"
 pose.apply({"feet":player.position+Vector2(13,54),"velocity":player.velocity,"grounded":player.is_on_floor() or is_riding(),"facing":facing,"action":action,"action_progress":progress,"equipment":Pose.EQUIPMENT_THROWABLE if fan_owned else Pose.EQUIPMENT_NONE,"small_item_kind":&"fan" if fan_owned else &"","monochrome":false,"visual_scale":Pose.HOOD_VISUAL_SCALE,"fog_blur":1.1})
 actor.grip_distance=grip_distance;actor.contact_reach=17.;actor.contact_sink=2.;actor.rope_allowed=false;actor.fan_ground_target=fan_rest_position()
 actor.sync_pose(dt,pose)
 if is_riding():actor.position.y+=8.
 if death_time>0.:actor.position.y+=smoothstep(.9,2.7,death_time)*65.;actor.modulate.a=1.-smoothstep(1.9,2.7,death_time)
 else:actor.modulate.a=1.
 fan.visible=fan_owned and not dragging and death_time<=0.
 if fan.visible:actor.drive_fan(fan,FAN_SCALE);fan.queue_redraw()
 art.sync(dt,camera_x,true)
 hud.text="A / D 移动   空格 跳跃   F 拾取 / 推拉   E 挥扇   R 重来" if clock<9. else ("雾湾出口 · 可由此衔接谷底森林" if completed else "")
 hud.modulate.a=.75 if completed else (1.-smoothstep(6.,9.,clock))*.75

func restore_checkpoint()->void:
 for key in ["move_left","move_right","interact","jump","blade_toggle"]:Input.action_release(key)
 player.position=Vector2(330,490) if checkpoint==0 else Vector2(2660,370)
 crate.position=Vector2(780,550) if checkpoint==0 else Vector2(2230,550)
 player.velocity=Vector2.ZERO;crate.velocity=Vector2.ZERO;crate_tilt=0.;crate_shape.rotation=0.
 heave_velocity=0.;pitch_velocity=0.;death_time=0.;fan_swing=0.;fan_pickup_time=0.;dragging=false;was_loaded=false
 fan_owned=checkpoint_fan;fan_on_tree=not fan_owned;fan_on_raft=false;fan_ground_position=Vector2(518,438)
 actor.reset_grip_animation()
 camera.position=Vector2(560,365) if checkpoint==0 else Vector2(2780,365)
 camera.zoom=Vector2.ONE*.96;completed=false
