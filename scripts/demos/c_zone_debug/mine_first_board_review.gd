extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 for delay:float in [-.10,.02,.22,.38]:
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(8)
  level.enter_root_cliff_test()
  var route=level.bridge_to_c
  route.checkpoint_step=3;route.restore_checkpoint()
  var trial=route.mine_trial
  level.player.position=Vector2(trial.GRIP_X-13,trial.ground(trial.GRIP_X)-55);level.player.velocity=Vector2.ZERO
  route.fall_origin=route.feet().y;await frames(15)
  Input.action_press("interact")
  for i in 240:
   await frames(1)
   if trial.operation=="brake" and trial.operation_time>=trial.PULL_END+delay or trial.launched and trial.escape.launch_age>=maxf(0,delay):break
  Input.action_press("jump");Input.action_press("move_right")
  var boarded:=false
  for i in 120:
   await frames(1)
   if trial.escape.is_riding():boarded=true;break
  Input.action_release("jump");Input.action_release("move_right");Input.action_release("interact")
  print("FIRST BOARD delay ",delay," boarded ",boarded," feet ",route.feet()," car ",trial.cart_position())
  assert(boarded,"first attempt jump during unlock/release must not be discarded")
  level.queue_free();await frames(2)
 print("FIRST BOARD PASS")
 quit()
