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
 await frames(8);level.enter_root_cliff_test()
 route=level.bridge_to_c;route.checkpoint_step=3;route.restore_checkpoint()
 trial=route.mine_trial;escape=trial.escape
 level.player.position=Vector2(trial.GRIP_X-13,trial.ground(trial.GRIP_X)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(trial.GRIP_X)
 await frames(15)
 Input.action_press("interact")
 for i in 260:
  await frames(1)
  if trial.launched and trial.operation=="":break
 Input.action_release("interact")
 Input.action_press("move_right");Input.action_press("jump")
 for i in 100:
  await frames(1)
  if escape.is_riding():break
 Input.action_release("move_right");Input.action_release("jump")
 assert(escape.is_riding())
 for i in 500:
  await frames(1)
  if trial.cart_x>-2110:break
 assert(route.failure_time==0)
 Input.action_press("jump");Input.action_press("move_right")
 await frames(22);Input.action_release("jump")
 var exposed:=false
 for i in 500:
  await frames(1)
  if not escape.is_riding():exposed=true
  if route.failure_time>0:break
 Input.action_release("move_right")
 print("MIDRIDE EXIT exposed=",exposed," cause=",escape.crush_cause," p=",route.feet()," age=",trial.impact_age)
 assert(exposed and escape.crushed and route.failure_time>0)
 assert(escape.crush_cause in [&"falling_stone",&"collapsed_roof"])
 for i in 220:
  await frames(1)
  if route.failure_time==0 and not trial.broken:break
 assert(route.failure_time==0 and not trial.broken and escape.stumble_age<0)
 # Exercise a fast rock between frames, including the old high-rubble loophole.
 await frames(30)
 var p:Vector2=route.feet()
 var original_roof=escape.roof.duplicate(true)
 escape.roof.clear()
 escape.roof.append({"previous":p-Vector2(70,40),"p":p+Vector2(70,-10),"size":70.0,"moving_this_step":true})
 assert(escape.hits_falling_stone())
 escape.roof[0].p=p+Vector2(90,-60);escape.roof[0].previous=p+Vector2(70,-100)
 assert(not escape.hits_falling_stone())
 escape.roof.assign(original_roof)
 trial.impact_age=10;trial.broken=true
 escape._update_collapse(0)
 var high:=Vector2(-1900,trial.ground(-1900)-240)
 assert(escape.roof_hazard_at(high.x) and high.y<trial.ground(high.x)+100)
 print("MIDRIDE HAZARDS PASS: real jump-out death, automatic retry, fast swept rock hit, near miss and no immunity atop rubble")
 quit()
