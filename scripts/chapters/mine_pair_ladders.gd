extends Node2D
# The two fixed ladders in the pair-cart chamber. World movement and pose
# selection are separate; no runtime scale fitting or collision from art.
const Master=preload("res://scripts/actors/back_ladder_manifest.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const DISPLAY:=.42*Pose.HOOD_VISUAL_SCALE
const FOOT_OFFSET:=Vector2(13,54)
const CYCLE_TRAVEL:=40.0
enum Mode {NONE, ENTER, CLIMB, EXIT}
var room
var mode:=Mode.NONE
var ladder_index:=-1
var ladder_x:=0.0
var top_y:=0.0
var bottom_y:=0.0
var from_top:=false
var going_up:=true
var phase:=0.0
var source_frame:=0.0
var segment_time:=0.0
var segment_duration:=0.0
var frame_from:=0.0
var frame_to:=0.0
var segment_from:=Vector2.ZERO
var physical_feet:=Vector2.ZERO
var saved_mask:=43
var facing:=-1.0
var cooldown:=0.0
var landing_settle:=0.0
var completed_up:=[0,0]
var completed_down:=[0,0]
func active()->bool:return mode!=Mode.NONE
func definitions()->Array:
 return [{"x":room.ORIGIN.x+220,"top":room.UPPER_Y,"bottom":room.MID_Y},
  {"x":room.ORIGIN.x+275,"top":room.MID_Y,"bottom":room.lower_floor_y(room.ORIGIN.x+275)}]
func _segment(next:Mode,first:float,last:float)->void:
 mode=next;source_frame=first;frame_from=first;frame_to=last
 # Keep the authored contact poses, but remove the cinematic wait at
 # each end. Traversal remains controlled independently of clip FPS.
 segment_time=0;segment_duration=.50 if next==Mode.ENTER else .55
 segment_from=physical_feet
func begin(index:int,descending:bool)->void:
 var level=room.gap.level
 var definition:Dictionary=definitions()[index]
 ladder_index=index;ladder_x=definition.x;top_y=definition.top;bottom_y=definition.bottom
 from_top=descending;going_up=not descending;phase=0
 physical_feet=room.gap.route.feet();facing=level.facing
 saved_mask=level.player.collision_mask;level.player.collision_mask=0
 level.player.velocity=Vector2.ZERO;level.jump_buffer=0;level.jump_windup_left=0
 level.climb_time=-1;level.scene1.low_stance.consume_ladder_down()
 level.actor.load_group("back_ladder");level.actor.begin_rope_ladder()
 _segment(Mode.ENTER,240 if descending else 0,156 if descending else 54)
func cancel()->void:
 if not active():return
 var level=room.gap.level
 level.player.collision_mask=saved_mask
 mode=Mode.NONE;cooldown=.25
 landing_settle=0
 level.actor.finish_rope_ladder()
func _place()->void:
 room.gap.level.player.position=physical_feet-FOOT_OFFSET
 room.gap.level.player.velocity=Vector2.ZERO
 # Clear the capsule's old grounded/platform contact while it is carried
 # by the ladder; death and jump code must see a genuinely airborne body.
 room.gap.level.player.move_and_slide()
 room.gap.route.fall_origin=physical_feet.y
func _finish()->void:
 var level=room.gap.level
 level.scene1.low_stance.consume_ladder_down()
 physical_feet=Vector2(ladder_x,top_y if going_up else bottom_y)
 _place();cancel()
 landing_settle=.20
 level.facing=facing;level.player.velocity=Vector2(0,60)
 level.player.move_and_slide()
 room.gap.route.fall_origin=room.gap.route.feet().y
 if going_up:completed_up[ladder_index]+=1
 else:completed_down[ladder_index]+=1
func tick(delta:float)->bool:
 cooldown=maxf(0,cooldown-delta)
 landing_settle=maxf(0,landing_settle-delta)
 var level=room.gap.level
 if not room.enabled or room.gap.route.failure_time>0:
  cancel();return false
 if not active():
  if cooldown>0 or not level.player.is_on_floor() or level.climb_time>=0:return false
  if room.gap.rock_state in [1,2,3] or room.gap.trial.operation!="":return false
  var input:=Input.get_axis("climb_up","climb_down")
  if absf(input)<.5:return false
  var feet:Vector2=room.gap.route.feet()
  var candidates:=definitions()
  for i in candidates.size():
   var d:Dictionary=candidates[i]
   if absf(feet.x-float(d.x))>25:continue
   if input<0 and absf(feet.y-float(d.bottom))<15:begin(i,false);return true
   if input>0 and absf(feet.y-float(d.top))<15:begin(i,true);return true
  return false
 if Input.is_action_just_pressed("jump"):
  var direction:=Input.get_axis("move_left","move_right")
  if absf(direction)<.1:direction=facing
  # Restore collision at the current ladder axis before taking off.
  # Teleporting 23px sideways could start the capsule behind the rock
  # boundary, where one-way support below became an invisible foothold.
  cancel()
  level.player.velocity=Vector2(direction*130,-150)
  level.jump_buffer=0;level.jump_windup_left=0
  level.player.move_and_slide()
  return true
 if mode==Mode.ENTER or mode==Mode.EXIT:
  segment_time=minf(segment_duration,segment_time+delta)
  var t:=segment_time/maxf(.01,segment_duration)
  source_frame=lerpf(frame_from,frame_to,t)
  # Finish lining up while still turning on the platform. Descending
  # cannot drift diagonally across the rail after the feet leave it.
  physical_feet.x=lerpf(segment_from.x,ladder_x,smoothstep(0,.3,t))
  if mode==Mode.ENTER:
   if from_top:physical_feet.y=lerpf(top_y,top_y+40,smoothstep(0,1,(198-source_frame)/42.0))
   else:physical_feet.y=lerpf(bottom_y,bottom_y-12,smoothstep(36,54,source_frame))
  elif going_up:physical_feet.y=lerpf(segment_from.y,top_y,smoothstep(156,198,source_frame))
  else:physical_feet.y=lerpf(segment_from.y,bottom_y,smoothstep(0,1,(54-source_frame)/18.0))
  _place()
  if segment_time>=segment_duration:
   if mode==Mode.EXIT:_finish()
   else:
    mode=Mode.CLIMB
    phase=float(Master.DATA.get("loop_entry_top" if from_top else "loop_entry_mount",0))/26.0
  return true
 var direction:=Input.get_axis("climb_up","climb_down")
 physical_feet.x=ladder_x
 if absf(direction)>.5:
  going_up=direction<0
  var travel:=direction*(70.0 if going_up else 82.0)*delta
  physical_feet.y=clampf(physical_feet.y+travel,top_y+40,bottom_y-12)
  phase=fposmod(phase-travel/CYCLE_TRAVEL,1.0)
  if going_up and physical_feet.y<=top_y+40.01:_segment(Mode.EXIT,156,240)
  elif not going_up and physical_feet.y>=bottom_y-12.01:_segment(Mode.EXIT,54,0)
 _place();return true
func apply_pose(pose)->void:
 if not active():return
 var offset:=Vector2.ZERO
 if mode==Mode.CLIMB:
  var index:=clampi(floori(phase*26),0,25)
  var master_index:=97+index
  var track:Dictionary=Master.DATA.tracks[master_index]
  # The loop was registered on its torso. Never centre the body on the
  # alternating lowest foot: that shifts the entire boy left/right.
  offset=Vector2(0,(float(track.feet[1])-float(track.torso[1]))*float(track.applied_scale)-95)
  pose.action=&"back_ladder_up";pose.action_progress=(float(index)+.00001)/25.0
 else:
  var index:=clampi(roundi(source_frame),0,240)
  var track:Dictionary=Master.DATA.tracks[index]
  var root:=Vector2(Master.DATA.source_root[0],Master.DATA.source_root[1])
  offset=(Vector2(track.torso[0],track.feet[1])-root)*float(track.applied_scale)
  pose.action=&"back_ladder";pose.action_progress=(float(index)+.00001)/240.0
 pose.feet=physical_feet-Vector2(-facing*offset.x,offset.y)*DISPLAY
 if mode==Mode.EXIT and going_up and source_frame>=221:
  # The video ends on its own standing drawing. Join to gameplay's actual
  # idle before releasing ownership, with the same root and sole anchor.
  pose.action=&"mine_ladder_settle"
  pose.action_progress=clampf((source_frame-221)/19.0,0,1)
  pose.feet=physical_feet
 # Match the established grounded actor's optical sole contact throughout
 # turn-in and step-off, not only after switching back to the idle clip.
 pose.feet.y+=4.0*support_weight()
 pose.facing=facing;pose.grounded=false;pose.velocity=Vector2.ZERO
 pose.jump_windup=-1;pose.held=-1;pose.small_item_kind=&""
func support_weight()->float:
 if mode==Mode.ENTER:
  return 1.0-smoothstep(0,1,(198-source_frame)/42.0) if from_top else 1.0-smoothstep(36,54,source_frame)
 if mode==Mode.EXIT:
  return smoothstep(156,198,source_frame) if going_up else smoothstep(0,1,(54-source_frame)/18.0)
 return 0.0
func contact_delta(delta:float)->float:return 0.0 if landing_settle>0 else delta
func post_present()->void:
 var actor=room.gap.level.actor
 if not active():
  var feet:Vector2=room.gap.route.feet()
  # Per-frame flat-ground clamping fights the tread/ramp contact solver
  # and creates 8–10px sprite jumps, even with a grounded capsule.
  if room.on_stair(feet):return
  if room.enabled and actor.pose.grounded and feet.x>=room.ORIGIN.x and feet.x<room.ORIGIN.x+1672:
   var sole:=sole_world_y()
   var target:=grounded_sole_y(feet)
   if is_finite(sole) and target>sole and target-sole<8:actor.position.y+=target-sole
  return
 actor.body_offset=Vector2.ZERO;actor.body.position=Vector2.ZERO
 actor.body.rotation=0;actor.rotation=0;actor.ghost.hide()
 var weight:=support_weight()
 if weight>0:
  # Use precomputed opaque soles of the rendered frame, including its
  # crop/scale rounding, so the last climbing frame meets the same ink
  # surface as the following standing frame.
  var sole:=sole_world_y()
  var target:=grounded_sole_y(physical_feet) if weight>.999 else physical_feet.y+4.0*weight
  if is_finite(sole):actor.position.y+=(target-sole)*weight
func grounded_sole_y(at:Vector2)->float:return maxf(at.y+4.0,room.visible_floor_y(at)+.6)
func sole_world_y()->float:
 var actor=room.gap.level.actor
 var result:float=-INF
 for point:Vector2 in actor._sole_points_of_frame():result=maxf(result,actor.sprite.to_global(point).y)
 return result
func rendered_axis()->Vector2:
 var actor=room.gap.level.actor
 if actor.current_clip==&"mine_ladder_settle":return actor.body.to_global(Vector2.ZERO)
 if actor.current_clip==&"back_ladder_up":return actor.body.to_global(Vector2(0,-95))
 var track:Dictionary=Master.DATA.tracks[clampi(actor.current_frame_index,0,240)]
 var root:=Vector2(Master.DATA.source_root[0],Master.DATA.source_root[1])
 return actor.body.to_global((Vector2(track.torso[0],track.torso[1])-root)*float(track.applied_scale))
