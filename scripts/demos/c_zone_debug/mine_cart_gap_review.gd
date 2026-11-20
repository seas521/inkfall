extends SceneTree
var level
var route
var trial
var gap
func snap(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-gap-v1/"+label+".png")
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;gap=trial.gap
 await frames(30)
 # The shared wall must be behind BOTH original rails and solid earth.
 # Merely putting it behind the rails leaves an apparent suspended incline.
 assert(trial.z_index+gap.art.wall.z_index<route.art.chase_chamber.earth.z_index)
 print("GAP READY ",route.feet()," stone ",trial.escape.chock_body.position)
 await snap("01-parked")
 Input.action_press("move_right");Input.action_press("jump")
 for i in 90:
  await frames(1)
  if route.feet().x>trial.PARK_X+54:break
  # Boarding and dismount are separate presses, including a boarding hold.
  if trial.escape.riding and trial.escape.ride_age>.4 and level.jump_windup_left<=0:
   Input.action_release("jump");await frames(2);Input.action_press("jump")
 Input.action_release("jump")
 # Continue off the large chock onto the supported rail, then turn to lift it.
 for i in 40:
  await frames(1)
  if route.feet().x> -1020:break
 Input.action_release("move_right");await frames(25)
 # The extra dismount jump may coast farther than simply walking off the rim.
 if route.feet().x>trial.escape.chock_body.position.x+60:
  Input.action_press("move_left")
  for i in 100:
   await frames(1)
   if route.feet().x<trial.escape.chock_body.position.x+53:break
  Input.action_release("move_left");await frames(20)
 print("ROCK APPROACH ",route.feet()," failure ",route.failure_time)
 Input.action_press("interact");await frames(2);Input.action_release("interact")
 for i in 175:
  await frames(1)
  if gap.rock_state==2:break
 await frames(5)
 print("PICKUP ",gap.rock_state," pose ",level.actor.current_clip," rock ",gap.rock_position)
 await snap("02-carrying-rock")
 assert(gap.rock_state==2 and level.actor.current_clip in [&"hug_hold",&"hug_pickup"])
 Input.action_press("move_right");await frames(12);Input.action_release("move_right");await frames(5)
 Input.action_press("interact");await frames(2);Input.action_release("interact");await frames(70)
 await snap("02b-stone-thrown")
 await frames(105)
 print("THROWN ",gap.rock_state," feet ",route.feet()," rock ",gap.rock_position)
 assert(gap.rock_cleared and gap.rock_released and not trial.escape.chock_present and trial.cart_speed==0)
 await snap("02b-stone-thrown")
 # Pull uphill from the front first, then move to the rear for the launch.
 Input.action_press("move_left")
 for i in 80:
  await frames(1)
  if route.feet().x<trial.cart_x+64:break
 Input.action_release("move_left");await frames(8)
 Input.action_press("interact");await frames(25)
 print("FRONT GRIP ",trial.operation," side ",trial.escape.grip_side," feet ",route.feet())
 assert(trial.operation=="recover" and trial.escape.grip_side==1)
 Input.action_press("move_left");await frames(105);Input.action_release("move_left")
 print("FRONT PUSH ",trial.cart_x," action ",level.actor.current_clip)
 assert(trial.cart_x<trial.PARK_X-25)
 Input.action_release("interact");await frames(1)
 # Release on a grade starts rolling: retain grip while crossing for this
 # validation by restoring the same stopped bay, then test the rear pull.
 trial.cart_x=trial.PARK_X;trial.cart_speed=0;gap.coast=false
 Input.action_press("move_left");Input.action_press("jump")
 for i in 100:
  await frames(1)
  if route.feet().x<trial.cart_x-65:break
  if trial.escape.riding and trial.escape.ride_age>.4 and level.jump_windup_left<=0:
   Input.action_release("jump");await frames(2);Input.action_press("jump")
 Input.action_release("move_left");Input.action_release("jump");await frames(30)
 if route.feet().x<trial.cart_x-78:
  Input.action_press("move_right")
  for i in 100:
   await frames(1)
   if route.feet().x>trial.cart_x-64:break
  Input.action_release("move_right");await frames(20)
 Input.action_press("interact");await frames(25)
 print("REAR GRIP ",trial.operation," feet ",route.feet())
 assert(trial.operation=="recover" and trial.escape.grip_side==-1)
 Input.action_press("move_left")
 for i in 1000:
  await frames(1)
  if trial.cart_x< -1372:break
 Input.action_release("move_left")
 print("CHARGED ",trial.cart_x," feet ",route.feet()," failure ",route.failure_time)
 await snap("03-charged")
 assert(trial.cart_x< -1370)
 Input.action_release("interact");Input.action_press("move_right");Input.action_press("jump")
 var boarded:=false
 for i in 95:
  await frames(1)
  if trial.escape.is_riding():boarded=true;break
 Input.action_release("move_right");Input.action_release("jump")
 print("REBOARD ",boarded," feet ",route.feet()," cart ",trial.cart_position()," v ",trial.cart_speed)
 assert(boarded)
 var jumped:=false
 for i in 360:
  await frames(1)
  if trial.cart_x>gap.RAIL_END+24 and not jumped:
   Input.action_press("move_right");Input.action_press("jump");jumped=true
   print("LAUNCH JUMP ",route.feet()," deck ",gap.deck.position," velocity ",trial.cart_speed)
  if jumped and i%5==0:print("FLIGHT ",route.feet()," v ",level.player.velocity," deck ",gap.deck.position," climb ",level.climb_time)
  if jumped and gap.flight_age>.24 and gap.flight_age<.27:await snap("04-derailed-cart")
  if gap.catches>0:break
 Input.action_release("jump");Input.action_release("move_right")
 print("CATCH ",gap.catches," feet ",route.feet()," failure ",route.failure_time)
 await snap("05-hands-catch")
 assert(gap.catches>0)
 await frames(180)
 print("DECK ",gap.platform_reached," feet ",route.feet()," deck ",gap.deck.position)
 await snap("06-on-platform")
 assert(gap.platform_reached)
 # Move to the outer plank before choosing the jump timing.
 Input.action_press("move_right")
 for i in 100:
  await frames(1)
  if gap.deck.to_local(route.feet()).x>33:break
 Input.action_release("move_right");await frames(2)
 for i in 250:
  await frames(1)
  if gap.deck.position.x>gap.DECK_ANCHOR.x+21 and gap.deck_velocity.x>0:break
 print("BANK TAKEOFF ",route.feet()," local ",gap.deck.to_local(route.feet())," deck_v ",gap.deck_velocity)
 Input.action_press("move_right");Input.action_press("jump")
 for i in 120:
  await frames(1)
  if gap.bank_reached:break
  if i%15==0:print("BANK FLIGHT ",route.feet()," v ",level.player.velocity," climb ",level.climb_time)
 Input.action_release("move_right");Input.action_release("jump")
 await frames(150)
 print("BANK REACHED ",gap.bank_reached," feet ",route.feet()," failure ",route.failure_time)
 await snap("07-opposite-bank")
 assert(gap.bank_reached and route.failure_time==0)
 # The continuation remains underground; both next carts are full-size
 # physical props, and the player can jump over the first to explore the bay.
 Input.action_press("move_right")
 for i in 180:
  await frames(1)
  if route.feet().x> -312:break
 Input.action_press("jump");await frames(64)
 Input.action_release("jump");Input.action_release("move_right");await frames(20)
 print("PAIR ROOM ",route.feet()," carts ",gap.art.pair_room.carts.size())
 await snap("08-two-cart-foundation")
 assert(gap.art.pair_room.carts.size()==2 and route.feet().x> -210 and route.failure_time==0)
 # Falling during the cart phase must locally restore the vehicle; carrying
 # progress persists and later bank/deck checkpoints do not replay collapse.
 # Later death preserves both the mine escape and the newly earned bank.
 route.fail();route.restore_checkpoint();await frames(15)
 assert(route.feet().x>gap.BANK_X and trial.broken and trial.escape.saved)
 gap.bank_reached=false
 route.restore_checkpoint();await frames(25)
 assert(gap.standing_on_deck() and gap.platform_reached)
 gap.platform_reached=false
 route.restore_checkpoint();await frames(15)
 assert(absf(trial.cart_x-trial.PARK_X)<1 and gap.rock_state==4 and not trial.escape.chock_present)
 assert(not gap.coast and not trial.escape.falling and route.failure_time==0)
 print("MINE CART GAP PASS")
 quit()
