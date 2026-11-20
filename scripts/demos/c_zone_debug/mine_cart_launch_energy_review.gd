extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(8)
 level.enter_mine_cart_gap_test()
 var route=level.bridge_to_c;var trial=route.mine_trial;var gap=trial.gap;var escape=trial.escape
 var results:Array=[]
 for start:float in [-1150,-1190,-1200,-1210,-1230,-1270,-1335]:
  gap.restore();gap.rock_state=4;gap.rock_cleared=true;gap.rock_visible=false;escape.remove_stop_rock()
  trial.cart_x=start;trial.cart_speed=0;trial.operation="";gap.coast=true;trial.sync_visual(0)
  # An empty-car run isolates energy from a person resisting its motion.
  level.player.position=Vector2(100-13,gap.art.pair_room.floor_y(100)-55);level.player.velocity=Vector2.ZERO;route.fall_origin=route.feet().y
  for i in 1600:
   await frames(1)
   if gap.launched:break
   if i>30 and absf(trial.cart_speed)<.05:break
  var row={"start":start,"drop":trial.ground(trial.PARK_X)-escape.track_height(start),"end":trial.cart_x,"speed":trial.cart_speed,"launched":gap.launched}
  results.append(row);print("ENERGY ",JSON.stringify(row))
  if start>=-1230:assert(not gap.launched and trial.cart_x<gap.RAIL_END,"insufficient height must stop before the broken rail")
  if start<=-1335:assert(gap.launched and trial.cart_speed>100,"enough height must supply real launch momentum")
  if start==-1230:
   var x:float=trial.cart_x-54
   level.player.position=Vector2(x-13,trial.ground(x)-55);level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(x)
   await frames(20)
   Input.action_press("interact");await frames(25)
   assert(trial.operation=="recover","an undercharged stopped car must remain grabbable")
   Input.action_press("move_left");await frames(240);Input.action_release("move_left");await frames(20)
   assert(trial.cart_x<escape.EDGE_X-60,"the stopped car must be recoverable to solid ground")
   Input.action_release("interact");print("UNDERCHARGED CAR RECOVERY PASS")
 print("LAUNCH ENERGY RESULTS ",JSON.stringify(results))
 quit()
