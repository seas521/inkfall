extends SceneTree
var level
var route
var trial
var escape
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(8);level.enter_root_cliff_test();route=level.bridge_to_c
 route.checkpoint_step=3;route.restore_checkpoint();trial=route.mine_trial;escape=trial.escape
 level.player.position=Vector2(trial.GRIP_X-13,trial.ground(trial.GRIP_X)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(trial.GRIP_X)
 await frames(15);Input.action_press("interact")
 for i in 260:
  await frames(1)
  if trial.launched and trial.operation=="":break
 Input.action_release("interact")
 for i in 600:
  await frames(1)
  if escape.crushed:break
 assert(escape.crushed)
 var seen_air:=false
 var seen_impact:=false
 var seen_down:=false
 var frames_air:=0
 var frames_impact:=0
 var previous_air:=-1
 for i in 160:
  await frames(1)
  if escape.hit_age<0 and route.failure_time==0:break
  var clip:String=String(level.actor.current_clip)
  if escape.hit_age<.8:
   assert(clip=="fall_air")
   assert(level.actor.current_frame_index>=42 and level.actor.current_frame_index>=previous_air)
   previous_air=level.actor.current_frame_index;frames_air+=1;seen_air=true
  elif escape.hit_age>.85 and escape.hit_age<1.47:
   assert(clip=="fall_impact");frames_impact+=1;seen_impact=true
  if escape.hit_age>1.50 and escape.hit_age<1.67:
   assert(clip=="downed" and route.failure_close<0);seen_down=true
  if route.failure_time==0 and not trial.broken:break
 assert(seen_air and seen_impact and seen_down)
 assert(frames_air>=40 and frames_impact>=32)
 assert(route.failure_time==0 and not trial.broken and escape.hit_age<0)
 print("ROCK HIT PASS: one continuous fall, ",frames_air," airborne frames + ",frames_impact," settling frames, body holds before iris and retry")
 quit()
