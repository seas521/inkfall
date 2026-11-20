extends RefCounted
# Register real support-foot plants to the individual approved wooden treads.
# Physics/input remains live; the sprite uses native step poses and foot locks.
const Source=preload("res://scripts/actors/mine_stair_manifest.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
const DOWN_SPEED:=44.0
const UP_SPEED:=42.0
# Top platform, each visible tread, lower platform (source-art pixels).
const TREADS=[Vector2(975,513),Vector2(986.5,528),Vector2(998.5,543),Vector2(1009.5,556),Vector2(1018.5,567),Vector2(1035,581),Vector2(1045,595),Vector2(1058,610),Vector2(1070,627),Vector2(1086,642),Vector2(1098,652)]
var room
var active:=false
var going_down:=true
var frame:=0
var offset:=0.0
var horizontal_offset:=0.0
var part:="enter"
var segment:=-1
var target_contact:=Vector2.ZERO
var contact_error:=0.0
var land_event:=false
var resting:=false
func reset()->void:
 active=false;resting=false;frame=0;offset=0;horizontal_offset=0;going_down=true;segment=-1;part="enter"
func source_info()->Dictionary:return Source.DATA if going_down else Source.UP
func _tread(index:int)->Vector2:
 var at:int=index if going_down else TREADS.size()-1-index
 return room.ORIGIN+TREADS[clampi(at,0,TREADS.size()-1)]
func _flat_sink(index:int)->float:
 var at:=_tread(index)
 var support:float=room.MID_Y if at.y<room.TRACK_Y-50 else room.TRACK_Y
 return support+4-at.y
func apply_pose(pose)->void:
 var feet:Vector2=room.gap.route.feet()
 var start:float=room.STAIR_START-8
 var finish:float=room.STAIR_END+12
 var heading:float=Input.get_axis("move_left","move_right")
 var down:bool=going_down if active and absf(heading)<.1 and absf(pose.velocity.x)<1 else pose.facing>0
 var allowed:bool=room.enabled and room.gap.route.failure_time<=0 and pose.grounded and pose.action==Pose.ACTION_NONE and pose.small_item_kind==&"" and pose.jump_windup<0 and not room.ladders.active() and not room.cart_gripped
 allowed=allowed and feet.x>=start and feet.x<=finish and absf(feet.y-room.floor_y(feet.x))<18
 if not allowed:
  active=false;resting=false;segment=-1;return
 if (not active or resting) and absf(pose.velocity.x)<1:
  if feet.x<room.STAIR_START or feet.x>room.STAIR_END:return
  # A vertical jump can land without any walking input. Register the
  # canonical standing pose to a real tread instead of the hidden ramp.
  going_down=down;active=true;resting=true;part="enter";frame=0;segment=-1;land_event=false
  var nearest:=0
  for i in TREADS.size():
   if absf(_tread(i).x-feet.x)<absf(_tread(nearest).x-feet.x):nearest=i
  target_contact=Vector2(feet.x,_tread(nearest).y+1.5)
  pose.action=StringName(source_info().parts.enter.clip);pose.action_progress=0.0
  pose.velocity=Vector2.ZERO
  return
 resting=false
 var previous_part:=part;var previous_segment:=segment
 var same_direction:bool=active and down==going_down
 going_down=down;active=true;land_event=false
 var entering:bool=feet.x<room.STAIR_START if going_down else feet.x>room.STAIR_END
 var exiting:bool=feet.x>room.STAIR_END if going_down else feet.x<room.STAIR_START
 var data:Dictionary=source_info()
 if entering:
  part="enter";segment=-1
  var t:float=clampf((feet.x-start)/(room.STAIR_START-start),0,1) if going_down else clampf((finish-feet.x)/(finish-room.STAIR_END),0,1)
  frame=clampi(roundi(t*float(data.parts.enter.frames-1)),0,int(data.parts.enter.frames)-1)
  var ease:=smoothstep(0,1,t)
  var flat_x:float=start if going_down else finish
  target_contact=Vector2(lerpf(flat_x,_tread(0).x,ease),_tread(0).y+lerpf(_flat_sink(0),1.5,ease))
 elif exiting:
  part="exit";segment=TREADS.size()-1
  var t:float=clampf((feet.x-room.STAIR_END)/(finish-room.STAIR_END),0,1) if going_down else clampf((room.STAIR_START-feet.x)/(room.STAIR_START-start),0,1)
  frame=clampi(roundi(t*float(data.parts.exit.frames-1)),0,int(data.parts.exit.frames)-1)
  var ease:=smoothstep(0,1,t)
  var flat_x:float=finish if going_down else start
  target_contact=Vector2(lerpf(_tread(segment).x,flat_x,ease),_tread(segment).y+lerpf(1.5,_flat_sink(segment),ease))
  land_event=same_direction and previous_part=="step"
 else:
  part="step"
  var along:float=clampf((feet.x-room.STAIR_START)/(room.STAIR_END-room.STAIR_START),0,1)
  if not going_down:along=1-along
  var full_distance:float=absf(_tread(TREADS.size()-1).x-_tread(0).x)
  segment=TREADS.size()-2
  var a:=0.0;var b:=1.0
  for i in TREADS.size()-1:
   var first:float=absf(_tread(i).x-_tread(0).x)/full_distance
   var last:float=absf(_tread(i+1).x-_tread(0).x)/full_distance
   if along<=last:
    segment=i;a=first;b=last;break
  var phase:=clampf(inverse_lerp(a,b,along),0,1)
  # Reserve the end of each interval for its actual new-foot landing.
  # Otherwise floor() skipped that pose and jumped straight to the next
  # cycle, compressing two weight transfers into a single rendered frame.
  frame=clampi(roundi(minf(phase/.9,1.0)*float(data.parts.step.frames-1)),0,int(data.parts.step.frames)-1)
  var anchor:=segment
  if same_direction and previous_part=="step" and previous_segment!=segment:
   # Start the next support cycle in phase. Forcing the preceding last
   # pose here inserted a last/first-frame snap at every single tread.
   land_event=true
  if frame==int(data.parts.step.frames)-1:anchor=mini(segment+1,TREADS.size()-1)
  target_contact=_tread(anchor)+Vector2(0,1.5)
 var info:Dictionary=data.parts[part]
 pose.action=StringName(info.clip)
 pose.action_progress=(float(frame)+.00001)/float(info.frames-1)
 pose.velocity=Vector2.ZERO
func post_present(_delta:float)->void:
 if not active:return
 var actor=room.gap.level.actor
 var data:Dictionary=source_info().parts[part]
 if String(actor.current_clip)!=String(data.clip):return
 var point:Array=data.contacts[actor.current_frame_index]
 var local:=Vector2(point[0],point[1])
 var contact:Vector2=actor.body.to_global(local)
 var correction:Vector2=target_contact-contact
 actor.position+=correction
 offset=correction.y;horizontal_offset=correction.x
 contact_error=actor.body.to_global(local).distance_to(target_contact)
 actor.support_offset=offset;actor.support_valid=true
 actor.ghost.hide()
 if land_event:actor.footstep_serial+=1
