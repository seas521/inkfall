extends "res://scripts/demos/c_zone_debug/mine_cart_interaction_matrix_review.gd"
func travel_to(x:float,direction:float,limit:int=1300)->bool:
 var key:String="move_left" if direction<0 else "move_right"
 Input.action_press(key)
 for i in limit:
  await frames(1)
  if (trial.cart_x-x)*direction>=0:break
 Input.action_release(key);await frames(35)
 return absf(trial.cart_x-x)<8
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(8)
 level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;gap=trial.gap;escape=trial.escape
 await setup(trial.PARK_X)
 level.player.position=Vector2(trial.cart_x+54-13,trial.ground(trial.cart_x+54)-55);await frames(20)
 Input.action_press("interact");await frames(25)
 for cycle in 2:
  check(trial.operation=="recover","chain starts with a real grip")
  check(await travel_to(-1425,-1),"push across the crest to its left side")
  check(await travel_to(-1335,1),"pull back onto the right slope")
  Input.action_release("interact")
  var reached:=false
  for i in 1000:
   await frames(1)
   if trial.cart_x> -1065:reached=true;break
  check(reached,"released car must reach cliff-side catch zone")
  var x:float=trial.cart_x;var speed:float=trial.cart_speed;var old_x:float=x
  var tick:int=Engine.get_physics_frames();var largest:=0.;var active:=false
  Input.action_press("interact")
  for i in 45:
   await frames(1)
   var dt:float=float(maxi(1,Engine.get_physics_frames()-tick))/60
   largest=maxf(largest,absf(trial.cart_x-old_x)/dt)
   old_x=trial.cart_x;tick=Engine.get_physics_frames()
   if trial.operation=="recover":active=true
   check(trial.cart_speed>=-.1 and absf(trial.cart_speed)<=speed+15,"F-only brake cannot inject reverse velocity")
  check(active and absf(trial.cart_speed)<.1,"F-only catch brakes to rest")
  check(largest<=speed+20,"cliff-side regrab has no position jump")
  print("CHAIN CYCLE ",cycle," catch ",x," speed ",speed," stop ",trial.cart_x," max travel speed ",largest)
 # Jump while still holding F must let go, with no automatic regrab.
 Input.action_press("jump");Input.action_press("move_right")
 var rose:=false
 for i in 18:
  await frames(1)
  if level.player.velocity.y< -100:rose=true
  if i>2:check(trial.operation!="recover","jump cancels grip even with F held")
 check(rose,"jump can interrupt an active grip")
 keys_up()
 # Holding F is not a magic support beyond the last physical rail contact.
 await setup(-980)
 level.player.position=Vector2(trial.cart_x-54-13,trial.ground(trial.cart_x-54)-55);await frames(20)
 print("EDGE GRIP SETUP ",route.feet()," grounded ",level.player.is_on_floor()," allowed ",gap.grip_allowed()," mask ",level.player.collision_mask)
 Input.action_press("interact");await frames(25);print("EDGE GRIP STATE ",trial.operation);Input.action_press("move_right")
 for i in 200:
  await frames(1)
  if escape.falling:break
 print("EDGE PUSH TRACE ",trial.cart_x," v ",trial.cart_speed," op ",trial.operation," fall ",escape.falling," launched ",gap.launched," feet ",route.feet())
 check(escape.falling and trial.operation!="recover","pushing past the rail edge releases grip and the cart falls")
 keys_up()
 print("CART INTERACTION CHAIN ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
