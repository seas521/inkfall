extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 for distance:float in [59,75,95,115]:
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(8)
  level.enter_root_cliff_test();var route=level.bridge_to_c
  route.checkpoint_step=3;route.restore_checkpoint();var trial=route.mine_trial
  var x:float=trial.cart_x-distance
  level.player.position=Vector2(x-13,trial.ground(x)-55);level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(x);await frames(20)
  var max_height:=0.0;var boarded:=false
  Input.action_press("move_right");Input.action_press("jump")
  for i in 100:
   await frames(1)
   max_height=maxf(max_height,trial.cart_position().y-route.feet().y)
   if trial.escape.is_riding():boarded=true;break
  Input.action_release("move_right");Input.action_release("jump")
  print("LOCKED BOARD distance ",distance," success ",boarded," peak ",max_height," feet ",route.feet()-trial.cart_position()," mask ",level.player.collision_mask)
  assert(boarded,"locked cart must be boardable from the lever and nearby approach distances")
  level.queue_free();await frames(2)
 print("LOCKED BOARD PASS")
 quit()
