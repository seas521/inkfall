extends SceneTree
var level
var route
var room
var control
var failed:=false
var report:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func release()->void:
 for action in ["climb_up","climb_down","move_left","move_right","jump"]:Input.action_release(action)
func warp(at:Vector2)->void:
 release();control.cancel()
 level.player.position=at-Vector2(13,55);level.player.velocity=Vector2.ZERO
 route.fall_origin=at.y;level.jump_buffer=0;level.jump_windup_left=0;level.climb_time=-1
 await frames(20)
func wait_for_loop()->void:
 for i in 240:
  await frames(1)
  if control.mode==control.Mode.CLIMB:return
 check(false,"entry must reach a controllable climb pose")
func traverse(index:int,down:bool,exercise_hold:bool=false)->void:
 var d:Dictionary=control.definitions()[index]
 await warp(Vector2(d.x,d.top if down else d.bottom))
 check(level.player.is_on_floor(),"ladder approach must be supported by real floor")
 Input.action_press("climb_down" if down else "climb_up")
 await frames(2)
 check(control.active() and control.ladder_index==index,"directional input must engage the selected ladder")
 await wait_for_loop()
 check(level.player.collision_mask==0,"only active ladder traversal temporarily releases floor collision")
 if exercise_hold:
  await frames(55);release();await frames(2)
  var held:Vector2=route.feet();var phase:float=control.phase
  await frames(30)
  check(route.feet().distance_to(held)<.01 and control.phase==phase,"release must hold position and animation phase without breathing")
  Input.action_press("climb_down" if not down else "climb_up");await frames(18);release()
  check((route.feet().y-held.y)*(1 if not down else -1)>1,"mid-ladder direction reversal must move correctly")
  Input.action_press("climb_down" if down else "climb_up")
 var max_scale_error:=0.0
 var max_axis_error:=0.0
 for i in 1300:
  await frames(1)
  if control.active():
   max_scale_error=maxf(max_scale_error,absf(absf(level.actor.body.scale.x)-.378))
   max_axis_error=maxf(max_axis_error,absf(control.rendered_axis().x-control.physical_feet.x))
   check(level.actor.z_index==5,"up and down must use the same front side of the ladder")
   if control.support_weight()>.999:
    check(absf(control.sole_world_y()-control.grounded_sole_y(control.physical_feet))<.05,"supported turn/step-off sole must meet the visible surface")
   if control.mode==control.Mode.CLIMB:check(not level.actor.eye_light.visible,"back-facing climb cannot expose an eye")
  if not control.active():break
 release();await frames(20)
 check(not control.active(),"traversal must finish")
 check(absf(route.feet().y-float(d.bottom if down else d.top))<8,"exit must stand on the destination floor: "+str(route.feet()))
 check(level.player.is_on_floor() and level.player.collision_mask==43,"normal grounded control and collision must return")
 print("LADDER SOLE CONTACT ",{"sole":control.sole_world_y(),"feet":route.feet().y,"offset":level.actor.support_offset,"valid":level.actor.support_valid,"clip":level.actor.current_clip,"actor":level.actor.position,"grounded":level.actor.pose.grounded})
 check(control.sole_world_y()>=control.grounded_sole_y(route.feet())-.05,"idle after step-off must keep its soles on the ink surface")
 check(max_scale_error<.0001,"climbing must not resize the actor")
 check(max_axis_error<.05,"torso must not shift with alternating foot anchors: "+str(max_axis_error))
 check(route.failure_time==0,"supported ladder traversal must not cause fall death")
 Input.action_press("move_right");await frames(25);Input.action_release("move_right")
 check(route.feet().x>float(d.x)+8,"player must walk away freely after step-off")
 report.append({"ladder":index,"down":down,"completed":not control.active(),"feet":str(route.feet()),"max_scale_error":max_scale_error,"max_axis_error":max_axis_error})
 print("LADDER TRAVERSE ",report[-1])
func run()->void:
 root.size=Vector2i(1280,720)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders
 await traverse(0,false,true)
 if OS.get_environment("INKFALL_LADDER_CONTACT_PROBE")=="1":quit(1 if failed else 0);return
 await traverse(0,true)
 await traverse(1,true,true)
 await traverse(1,false)
 # Jumping and death must both release ownership and restore valid state.
 var d:Dictionary=control.definitions()[0]
 await warp(Vector2(d.x,d.bottom));Input.action_press("climb_up");await wait_for_loop()
 Input.action_press("jump");await frames(2);release()
 check(not control.active() and level.player.collision_mask==43,"jump off must release ladder ownership and collision")
 check(level.player.velocity.y<0,"jump off must enter real airborne motion")
 await warp(Vector2(d.x,d.bottom));Input.action_press("climb_up");await wait_for_loop();release()
 route.fail();check(not control.active(),"death must cancel ladder ownership")
 check(route.failure_airborne,"death while climbing must remain an airborne fall")
 route.restore_checkpoint();await frames(25)
 check(not control.active() and level.player.collision_mask==43 and route.failure_time==0,"respawn must restore valid player state")
 await warp(Vector2(70,room.MID_Y));Input.action_press("climb_down");await frames(20);release()
 check(not control.active(),"S away from a ladder must remain available to crouching")
 var dir:="res://artifacts/mine-pair-ladders-live"
 DirAccess.make_dir_recursive_absolute(dir)
 var file=FileAccess.open(dir+"/review.json",FileAccess.WRITE);file.store_string(JSON.stringify({"passed":not failed,"traversals":report},"  "))
 print("MINE PAIR LADDERS ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
