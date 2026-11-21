extends Node2D
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const Ladder=preload("res://scripts/actors/rope_ladder_manifest.gd")
const TRACK_SCALE=.6*.42*Pose.HOOD_VISUAL_SCALE*.5
const RUNG_PITCH=90.*TRACK_SCALE
const ANCHOR=Vector2(1290,369)
const LENGTH=122.
const LINKS=32
var nodes:=PackedVector2Array()
var previous:=PackedVector2Array()
var level
var held:=false
var grip_y:=510.
var phase:=0.
var frame:=159.
var upward:=true
var source_origin:=Vector2.ZERO
var last_movement:=0.
var cooldown:=0.
var sway:=0.
var sway_v:=0.
var time:=0.
var exit_time:=-1.
var exit_from:=Vector2.ZERO
var catching:=false
var catch_feet:=Vector2.ZERO
var catch_boat:=Vector2.ZERO
var catch_hand:=Vector2.ZERO
var twist:=0.
var twist_v:=0.
var mounting:=false
var transition_origin:=Vector2.ZERO
var transition_target:=Vector2.ZERO
func _ready()->void:
 for i in LINKS+1:
  var t:float=i/float(LINKS)
  nodes.append(ANCHOR+Vector2(-sin(t*PI)*4.,t*LENGTH))
 previous=nodes.duplicate()
 level.actor.load_group("rope_ladder");level.actor.load_group("climb")
func point(y:float)->Vector2:
 var u:float=clampf((y-ANCHOR.y)/LENGTH,0.,1.)*LINKS
 var i:int=mini(int(u),LINKS-1)
 return nodes[i].lerp(nodes[i+1],u-i) if not nodes.is_empty() else Vector2(ANCHOR.x,y)
func step_rope(dt:float)->void:
 dt=minf(dt,1./30.)
 for i in range(1,nodes.size()):
  var position:Vector2=nodes[i]
  var velocity:Vector2=(position-previous[i])*.978
  previous[i]=position
  nodes[i]+=velocity+Vector2(sin(time*.8+i*.19)*15.,470.)*dt*dt
 var grip_index:int=clampi(int(round((grip_y-ANCHOR.y)/LENGTH*LINKS)),1,LINKS)
 for iteration in 14:
  nodes[0]=ANCHOR
  if held:
   var target:Vector2=ANCHOR+Vector2(sway*(grip_index/float(LINKS)),grip_index*LENGTH/LINKS)
   nodes[grip_index]=target
  for i in LINKS:
   var delta:Vector2=nodes[i+1]-nodes[i]
   var error:Vector2=delta*(1.-(LENGTH/LINKS)/maxf(delta.length(),.001))
   var left_fixed:bool=i==0 or (held and i==grip_index)
   var right_fixed:bool=held and i+1==grip_index
   if left_fixed:nodes[i+1]-=error if not right_fixed else Vector2.ZERO
   elif right_fixed:nodes[i]+=error
   else:nodes[i]+=error*.5;nodes[i+1]-=error*.5
 nodes[0]=ANCHOR
func begin_from_boat()->bool:
 var feet:Vector2=level.player.position+Vector2(6.5,27)
 var target:=point(ANCHOR.y+LENGTH-12.)+Vector2(-5.,0.)
 # A vertical catch is available only directly below the ladder. No auto-walk
 # or diagonal leap can cover the gap from farther back along the boat.
 if held or cooldown>0. or not level.is_riding() or absf(feet.x-(target.x+2.))>6.:return false
 held=true;catching=true;frame=128.;catch_feet=feet;catch_boat=level.crate.position
 catch_hand=target;grip_y=target.y;last_movement=0.;upward=true
 source_origin=feet-track("feet")
 level.player.velocity=Vector2.ZERO;level.player.collision_mask=0
 level.dragging=false;level.fan_swing=0.;level.fan.visible=false
 return true
func update_catch(dt:float)->void:
 frame=minf(159.,frame+24.*dt)
 if frame<=140.:
  # Feet remain planted on the boat throughout the recorded crouch.
  catch_feet+=level.crate.position-catch_boat;catch_boat=level.crate.position
  source_origin=catch_feet-track("feet")
 elif frame<147.:
  var current:float=frame
  frame=140.;var from_head:Vector2=catch_feet-track("feet")+track("eye")
  frame=147.;var to_head:Vector2=catch_hand-track("hand")+track("eye")
  frame=current
  var t:float=(frame-140.)/7.
  var head:Vector2=from_head.lerp(to_head,t)+Vector2(0,-20.*t*(1.-t))
  source_origin=head-track("eye")
  source_origin.x=catch_feet.x-track("feet").x
 else:
  source_origin=catch_hand-track("hand")
  source_origin.x=catch_feet.x-track("feet").x
  sway_v-=dt*22.;twist_v+=dt*.7
 level.player.position=source_origin+track("feet")-Vector2(6.5,27)
 level.player.velocity=Vector2.ZERO
 if frame>=159.:
  catching=false;sway_v-=5.;twist_v+=.25
  # Pin the caught hand at its actual contact rather than shifting the body.
  catch_hand=source_origin+track("hand")
func tick(dt:float)->bool:
 time+=dt;cooldown=maxf(0.,cooldown-dt)
 var old_sway:=sway
 var stepping:bool=held and not catching and not mounting and exit_time<0. and (Input.is_action_pressed("climb_up") or Input.is_action_pressed("climb_down"))
 var drive:float=sin(frame*TAU/26.)*80. if stepping else 0.
 sway_v+=(-sway*15.-sway_v*3.+drive)*dt;sway=clampf(sway+sway_v*dt,-7.,7.)
 twist_v+=(-twist*18.-twist_v*3.2+(sin(frame*TAU/26.)*2.5 if stepping else 0.))*dt
 twist=clampf(twist+twist_v*dt,-.22,.22)
 if held and not catching:source_origin.x+=(sway-old_sway)*clampf((grip_y-ANCHOR.y)/LENGTH,0.,1.)
 step_rope(dt)
 queue_redraw()
 if catching:
  update_catch(dt)
  return true
 if mounting:
  frame=minf(42.,frame+dt*24.)
  source_origin=transition_origin.lerp(transition_target,smoothstep(10.,42.,frame))
  follow_source()
  grip_y=(source_origin+track("hand")).y
  if frame>=42.:mounting=false;upward=false;last_movement=0.
  return true
 if exit_time>=0.:
  exit_time+=dt;frame=minf(234.,frame+dt*24.)
  source_origin=transition_origin.lerp(transition_target,smoothstep(194.,234.,frame))
  follow_source()
  if frame>=234.:
   exit_time=-1.;held=false;cooldown=.5;level.player.collision_mask=3;level.completed=true;level.checkpoint=1
   var feet:Vector2=level.player.position+Vector2(6.5,27)
   level.player.position.y=level.ground_y(feet.x)-27.
   level.facing=1.;level.actor.finish_rope_ladder()
  return true
 if not held and cooldown<=0. and level.player.is_on_floor() and Input.is_action_pressed("climb_down"):
  var feet:Vector2=level.player.position+Vector2(6.5,27)
  if absf(feet.x-1338.)<22. and absf(feet.y-level.ground_y(feet.x))<5.:
   held=true;mounting=true;frame=10.;upward=false
   level.player.collision_mask=0;level.player.velocity=Vector2.ZERO
   level.actor.begin_rope_ladder();level.fan_swing=0.;level.dragging=false
   transition_origin=feet-track("feet");source_origin=transition_origin
   frame=42.;transition_target=Vector2(ANCHOR.x-5.,ANCHOR.y+100.*TRACK_SCALE)-track("hand");frame=10.
   return true
 var hand:Vector2=level.player.position+Vector2(6.5,3.)
 if not held:
  if cooldown<=0. and not level.player.is_on_floor() and not level.is_riding() and absf(hand.x-(point(hand.y).x-3.))<6. and absf(level.player.velocity.x)<12. and hand.y>ANCHOR.y+8. and hand.y<ANCHOR.y+LENGTH:
   held=true;grip_y=hand.y;frame=159.;upward=true;phase=0.;last_movement=0.
   var rung:float=ANCHOR.y+100.*TRACK_SCALE+roundf((hand.y-ANCHOR.y-100.*TRACK_SCALE)/RUNG_PITCH)*RUNG_PITCH
   source_origin=point(minf(rung,ANCHOR.y+LENGTH-4.))+Vector2(-5.,0.)-track("hand")
   sway_v+=clampf(level.player.velocity.x*.15,-15.,15.)
   level.player.velocity=Vector2.ZERO;level.player.collision_mask=0;level.dragging=false
   level.fan_swing=0.;level.fan.visible=false
  else:return false
 if Input.is_action_just_pressed("jump"):
  held=false;cooldown=.4;level.player.collision_mask=3
  level.player.velocity=Vector2(Input.get_axis("move_left","move_right")*130.,-230.)
  level.actor.rotation=0.;return false
 var movement:=Input.get_action_strength("climb_down")-Input.get_action_strength("climb_up")
 if movement!=0.:
  if upward!=(movement<0.):
   var fixed_hand:Vector2=source_origin+track("hand")
   if movement<0. and frame>=42. and frame<=67.:frame=Ladder.DATA.up_from_down[clampi(int(frame)-42,0,25)]
   elif movement>0. and frame>=159. and frame<=183.:frame=Ladder.DATA.down_from_up[clampi(int(frame)-159,0,24)]
   else:frame=159. if movement<0. else 42.
   source_origin=fixed_hand-track("hand")
  upward=movement<0.
  # Original cliff ladder: 24fps, one recorded cycle advances exactly two rungs.
  var start:float=159. if upward else 42.
  var end:float=184. if upward else 68.
  frame+=dt*24.
  if frame>=end:
   source_origin.y+=(-1. if upward else 1.)*RUNG_PITCH*2.
   frame=start+fposmod(frame-start,end-start)
 last_movement=movement
 grip_y=(source_origin+track("hand")).y
 if grip_y<=ANCHOR.y+9. and movement<0.:
  var eye:Vector2=source_origin+track("eye")
  frame=194.;source_origin=eye-track("eye")
  transition_origin=source_origin
  frame=234.;transition_target=Vector2(1338,level.ground_y(1338.))-track("feet");frame=194.
  exit_time=0.;return true
 if grip_y>ANCHOR.y+LENGTH-3.:
  source_origin.y-=grip_y-(ANCHOR.y+LENGTH-3.);grip_y=ANCHOR.y+LENGTH-3.
 # As on the original cliff ladder, the recorded hand/torso motion plays
 # around a fixed segment origin. Never cancel it by pinning every hand frame.
 level.player.position=source_origin+track("feet")-Vector2(6.5,27)
 level.player.velocity=Vector2.ZERO
 return true
func follow_source()->void:
 level.player.position=source_origin+track("feet")-Vector2(6.5,27)
 level.player.velocity=Vector2.ZERO
func track(key:String)->Vector2:
 var data:Array=Ladder.DATA.tracks[clampi(int(frame),0,240)][key]
 var value:Vector2=(Vector2(data[0],data[1])-Vector2(384,365))*TRACK_SCALE
 value.x=-value.x
 return value
func present(dt:float)->void:
 var pose=Pose.new()
 pose.apply({"feet":source_origin,"action":&"rope_ladder","action_progress":frame/240.,"grounded":false,"facing":1.,"visual_scale":Pose.HOOD_VISUAL_SCALE*.5,"monochrome":true,"fog_blur":.7})
 level.actor.sync_pose(dt,pose)
 level.actor.body_offset=Vector2.ZERO;level.actor.body.position=Vector2.ZERO;level.actor.rotation=0.;level.actor.ghost.hide()
 level.fan.visible=false
func reset()->void:
 held=false;catching=false;mounting=false;exit_time=-1.;cooldown=.4;sway=0.;sway_v=0.;twist=0.;twist_v=0.
 level.player.collision_mask=3;level.actor.rotation=0.
func _draw()->void:
 if nodes.size()<2:return
 # Weathered anchor: lower end buried behind the sloping earth, exposed head
 # projects above it. Both ladder rails are separately lashed around the post.
 draw_colored_polygon(PackedVector2Array([
  Vector2(1317,348),Vector2(1311,327),Vector2(1312,323),
  Vector2(1315,325),Vector2(1318,322),Vector2(1322,324),
  Vector2(1324,344)
 ]),Color(.025,.025,.025))
 draw_line(Vector2(1318,326),Vector2(1321,343),Color(.065,.065,.065),.7,true)
 draw_line(Vector2(1315,324),Vector2(1318,330),Color(.005,.005,.005),1.,true)
 for k in 4:
  draw_polyline(PackedVector2Array([Vector2(1313+k*.5,333+k*2.),Vector2(1318+k*.4,335+k*2.),Vector2(1323+k*.25,332+k*2.)]),Color(.12,.12,.12),1.1,true)
 for side in [-1.,1.]:
  # Lash to post, then follow the rock rather than forming a suspended arch.
  var wrap:=PackedVector2Array([Vector2(1319+side*2.,337+side*2.),Vector2(1315+side*3.,349),Vector2(1302+side*5.,355),Vector2(1294+side*5.,361),ANCHOR+Vector2(side*5.,0)])
  draw_polyline(wrap,Color(.035,.035,.035),1.8,true)
  for i in LINKS:
   var a:Vector2=nodes[i]+Vector2(side*(5.*cos(twist)+.4*sin(i*.45)),0)
   var b:Vector2=nodes[i+1]+Vector2(side*(5.*cos(twist)+.4*sin((i+1)*.45)),0)
   var width:float=1.8+.25*sin(i*.61)+.16*sin(i*1.73)
   draw_line(a,b,Color(.04,.04,.04),width,true)
   if i%3==0:draw_line(a+Vector2(-.4,0),b+Vector2(.3,0),Color(.12,.12,.12),.5,true)
 # Worn wooden rungs: slight uneven ends and tilt, while foot spacing stays consistent.
 var y:float=ANCHOR.y+100.*TRACK_SCALE
 var index:=0
 while y<ANCHOR.y+LENGTH-3.:
  var p:=point(y)
  var slope:float=sin(index*2.7)*.7+sin(twist)*5.
  var a:=p+Vector2(-7.1,slope);var b:=p+Vector2(7.4,-slope)
  var outline:=PackedVector2Array([a+Vector2(-.6,-1.),a.lerp(b,.3)+Vector2(0,-1.2),b+Vector2(.3,-.8),b+Vector2(-.6,1.2),a+Vector2(.4,1.5)])
  draw_colored_polygon(outline,Color(.035,.035,.035))
  draw_line(a+Vector2(1.,-.6),b-Vector2(1.,.6),Color(.095,.095,.095),.5,true)
  for side in [-1.,1.]:draw_circle(p+Vector2(side*5.,-side*slope*.65),1.4,Color(.045,.045,.045),true,-1,true)
  y+=RUNG_PITCH;index+=1
 for spec in [Vector3(28.,-1.,2.),Vector3(76.,1.,2.5),Vector3(116.,-1.,2.)]:
  var p:=point(ANCHOR.y+spec.x)+Vector2(spec.y*5.,0.)
  draw_polyline(PackedVector2Array([p,p+Vector2(spec.y*spec.z,1.),p+Vector2(spec.y*(spec.z+.3),3.)]),Color(.09,.09,.09),.55,true)
