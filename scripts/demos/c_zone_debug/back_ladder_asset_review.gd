extends SceneTree
# Render the imported master through the actual game actor and film pass.
# This is an animation/contact preview, not automatic traversal gameplay.
const Frames=preload("res://scripts/actors/back_ladder_manifest.gd")
const Pose=preload("res://scripts/actors/actor_pose_state.gd")
var output:="res://artifacts/back-ladder-3155-review/game"
var failed:=false
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if not ok:failed=true;push_error(label)
func frames(n:int)->void:
 for i in n:await physics_frame
func capture(label:String)->void:
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var raw=FileAccess.open(output+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE)
 meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func pose_at(level:Node,index:int)->void:
 var data:Dictionary=Frames.DATA
 var track:Dictionary=data.tracks[index]
 var source_root:=Vector2(data.source_root[0],data.source_root[1])
 var native_feet:=Vector2(track.feet[0],track.feet[1])
 var display:float=.42*Pose.HOOD_VISUAL_SCALE
 var feet:=Vector2(-445,-3050)
 if index>=54 and index<156:feet.y=lerpf(-3050,-3207,float(index-54)/102.0)
 elif index>=156:feet.y=lerpf(-3207,-3247,clampf(float(index-156)/42.0,0,1))
 var p:=Pose.new()
 p.apply({"feet":feet-(native_feet-source_root)*float(track.applied_scale)*display,
  "velocity":Vector2.ZERO,"grounded":false,"facing":-1.0,
  "action":&"back_ladder","action_progress":(float(index)+.00001)/float(data.frames-1),
  "visual_scale":Pose.HOOD_VISUAL_SCALE,"fog_blur":level.ACTOR_EDGE_SOFTNESS})
 level.actor.sync_pose(1.0/60.0,p)
 level.actor.body_offset=Vector2.ZERO;level.actor.body.position=Vector2.ZERO
 level.actor.ghost.hide();level.actor.body.rotation=0
 check(level.actor.current_clip==&"back_ladder","new action must select its own master")
 check(level.actor.current_frame_index==index,"native source frame must not skip or play at container 60fps")
 check(level.actor.body.scale.is_equal_approx(Vector2.ONE*display),"actor runtime scale must stay fixed")
 if index>=36 and index<=198:check(not level.actor.eye_light.visible,"back-view phase must not show an eye through the hood")
func run()->void:
 DirAccess.make_dir_recursive_absolute(output)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90)
 var level=main.river
 level.process_mode=Node.PROCESS_MODE_DISABLED
 level.camera.position=Vector2(-260,-3200);level.camera.zoom=Vector2.ONE
 level.camera.offset=Vector2.ZERO;level.camera.force_update_scroll()
 level.actor.load_group("back_ladder");level.actor.begin_rope_ladder()
 var old_rope:Dictionary=level.actor.Manifest.CLIPS["rope_ladder"]
 check(old_rope.frames==241 and old_rope.fps==24,"existing side-view rope ladder stays intact")
 var data:Dictionary=Frames.DATA
 var first_heights:Array=[];var last_heights:Array=[]
 for track in data.tracks:
  if track.source_time<=.4:first_heights.append(float(track.height)*float(track.applied_scale))
  if track.source_time>=9.2:last_heights.append(float(track.height)*float(track.applied_scale))
 var first:=0.0;var last:=0.0
 for h in first_heights:first+=float(h)/first_heights.size()
 for h in last_heights:last+=float(h)/last_heights.size()
 check(absf(first-last)<2,"matching start/end standing heights must agree within two sprite pixels")
 for index in data.frames:pose_at(level,index)
 for pair in [[0,"00-side"],[30,"01-turn"],[70,"02-climb"],[126,"03-climb"],[180,"04-step-off"],[233,"05-side"]]:
  pose_at(level,pair[0]);await process_frame;await capture(pair[1])
 var loop_data:Dictionary=level.actor.Manifest.CLIPS["back_ladder_up"]
 for i in int(loop_data.frames):
  var p:=Pose.new()
  p.apply({"feet":Vector2(-445,-3130),"grounded":false,"facing":-1.0,
   "action":&"back_ladder_up","action_progress":(float(i)+.00001)/float(loop_data.frames-1),
   "visual_scale":Pose.HOOD_VISUAL_SCALE,"fog_blur":level.ACTOR_EDGE_SOFTNESS})
  level.actor.sync_pose(1.0/60.0,p);level.actor.ghost.hide()
  check(level.actor.current_clip==&"back_ladder_up" and level.actor.current_frame_index==i,"loop pose frame must be addressable without skips")
  check(not level.actor.eye_light.visible,"climb loop must not expose an eye")
  check(level.actor.body.scale.is_equal_approx(Vector2.ONE*.42*Pose.HOOD_VISUAL_SCALE),"loop must retain the same actor scale")
 await process_frame;await capture("06-loop")
 var report={"frames":data.frames,"fps":data.fps,"first_height":first,"last_height":last,
  "runtime_scale":level.actor.body.scale.x,"old_rope_unchanged":true,"gameplay_traversal_enabled":false,"passed":not failed}
 var f=FileAccess.open(output+"/review.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
 print("BACK LADDER ASSET REVIEW ","FAIL" if failed else "PASS"," ",report)
 quit(1 if failed else 0)
