extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(8)
 for direction:float in [-1,1]:
  if direction>0:level.bridge_to_c.mine_trial.reset()
  level.enter_mine_cart_gap_test()
  var route=level.bridge_to_c;var trial=route.mine_trial;var gap=trial.gap
  var x:float=trial.escape.chock_body.position.x+45
  level.player.position=Vector2(x-13,trial.ground(x)-55);level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(x)
  await frames(20)
  Input.action_press("interact");await frames(2);Input.action_release("interact")
  for i in 175:
   await frames(1)
   if gap.rock_state==2:break
  assert(gap.rock_state==2)
  await frames(20);level.facing=direction
  Input.action_press("interact");await frames(2);Input.action_release("interact")
  await frames(230)
  print("THROW ",direction," state ",gap.rock_state," visible ",gap.rock_visible," pos ",gap.rock_position," cart ",trial.cart_position())
  if direction<0:
   assert(gap.rock_state==5 and gap.rock_visible,"throw toward car must stay grounded and visible")
   assert(gap.rock_position.distance_to(trial.cart_position()+Vector2(0,-25))>30,"stone cannot vanish inside the cart")
   level.player.position=Vector2(gap.rock_position.x+40-13,trial.ground(gap.rock_position.x+40)-55)
   level.player.velocity=Vector2.ZERO;await frames(15)
   assert(gap.try_rock(),"landed stone remains collectible")
 print("ROCK THROW PASS")
 quit()
