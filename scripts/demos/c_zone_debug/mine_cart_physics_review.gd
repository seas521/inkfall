extends SceneTree
var level
var route
var trial
var gap
var escape
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func setup(x:float)->void:
 gap.restore();gap.rock_state=4;gap.rock_cleared=true;gap.rock_visible=false;escape.remove_stop_rock()
 trial.cart_x=x;trial.cart_speed=0;trial.operation="";gap.coast=false
 trial.sync_visual(0)
 level.player.position=Vector2(x+54-13,trial.ground(x+54)-55);level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(x+54)
 await frames(20)
func grip()->void:
 Input.action_press("interact");await frames(25)
 assert(trial.operation=="recover")
func release_keys()->void:
 Input.action_release("move_left");Input.action_release("move_right");Input.action_release("interact")
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(8)
 level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;gap=trial.gap;escape=trial.escape
 var speeds:Dictionary={}
 for test:Dictionary in [{"name":"uphill","x":-1290.,"axis":-1.},{"name":"flat","x":-1125.,"axis":-1.},{"name":"downhill","x":-1290.,"axis":1.}]:
  await setup(test.x);await grip()
  var key:String="move_left" if test.axis<0 else "move_right"
  Input.action_press(key);await frames(60)
  speeds[test.name]=absf(trial.cart_speed)
  assert(trial.operation=="recover" and not escape.cart_shoving,"F must remain active grip")
  print("DRIVE ",test.name," speed ",trial.cart_speed," offset ",route.feet().x-trial.cart_x)
  release_keys();await frames(1)
 assert(speeds.uphill<speeds.flat and speeds.flat<speeds.downhill,"manual speed must reflect slope load")
 for test:Dictionary in [{"name":"left of crest","x":-1428.,"sign":-1.},{"name":"right of crest","x":-1335.,"sign":1.},{"name":"crest","x":-1405.,"sign":0.},{"name":"flat","x":-1120.,"sign":0.}]:
  await setup(test.x);await grip();Input.action_release("interact");await frames(15)
  print("ROLL ",test.name," dx ",trial.cart_x-test.x," speed ",trial.cart_speed," grade ",escape.track_grade(test.x))
  if test.sign==0:assert(absf(trial.cart_speed)<.5,"flat/crest cannot receive an invented rolling impulse")
  else:assert((trial.cart_x-test.x)*test.sign>0 and trial.cart_speed*test.sign>0,"released car must roll down its actual side of the crest")
 # F catches a car which is already pushing the player; it can then reverse.
 await setup(-1300)
 level.player.position.x=trial.cart_x+45-13;trial.cart_speed=45;gap.coast=true
 for i in 30:
  await frames(1)
  if escape.cart_shoving:break
 assert(escape.cart_shoving,"no F means passive resistance")
 Input.action_press("interact");Input.action_press("move_left");await frames(60)
 assert(trial.operation=="recover" and not escape.cart_shoving and trial.cart_speed<0,"F must brake, grip, then drive in reverse")
 print("F BRAKE AND REVERSE PASS speed ",trial.cart_speed)
 release_keys()
 print("MINE CART PHYSICS PASS ",JSON.stringify(speeds))
 quit()
