extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func snap(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-contact-v2/"+label+".png")
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_mine_cart_gap_test()
 var route=level.bridge_to_c;var trial=route.mine_trial;var gap=trial.gap;var escape=trial.escape
 gap.rock_state=4;gap.rock_cleared=true;gap.rock_visible=false;escape.remove_stop_rock()
 level.player.position=Vector2(trial.cart_x+54-13,trial.ground(trial.cart_x+54)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=route.feet().y;await frames(15)
 Input.action_press("interact");await frames(25);Input.action_press("move_left")
 for i in 1100:
  await frames(1)
  assert(trial.operation=="recover" and not escape.is_riding(),"held push must never become automatic boarding")
  assert(absf(route.feet().x-trial.cart_x-54)<.15,"cart cannot move independently of its pusher")
  if i%60==0:print("PUSH ",i," cart ",trial.cart_x," grip ",trial.operation," offset ",route.feet().x-trial.cart_x," ride ",escape.is_riding()," feet ",route.feet().y," floor ",trial.ground(route.feet().x))
 assert(absf(trial.cart_x-(maxf(escape.rubble_front,-1470.0)+31))<1,"cart stops at actual collapse rubble, not the old slope limit")
 Input.action_release("move_left");await frames(45)
 # Return to the RIGHT of the crest before the passive downhill test.
 Input.action_press("move_right")
 for i in 400:
  await frames(1)
  if trial.cart_x> -1335:break
 Input.action_release("move_right");await frames(45)
 var held_x:float=trial.cart_x
 await frames(45)
 assert(absf(trial.cart_x-held_x)<.02 and trial.operation=="recover","holding grip brakes the cart")
 await snap("01-rubble-stop")
 print("HELD ",trial.cart_x," op ",trial.operation)
 Input.action_release("interact");await frames(1)
 assert(trial.cart_speed<5,"release must start from rest, without a launch impulse")
 await frames(11)
 print("RELEASE12 ",trial.cart_x," speed ",trial.cart_speed)
 var early_speed:float=trial.cart_speed
 await frames(18);print("RELEASE30 ",trial.cart_x," speed ",trial.cart_speed)
 assert(trial.cart_x>held_x and trial.cart_speed>early_speed and trial.operation=="","released cart must accelerate downhill")
 var transitions:=0
 var last_shoving:=false
 var shoved_frames:=0
 var fell:=false
 for i in 1000:
  await frames(1)
  if escape.cart_shoving!=last_shoving:
   transitions+=1
   print("SHOVE TRANSITION ",i," active ",escape.cart_shoving," offset ",route.feet().x-trial.cart_x," grounded ",level.player.is_on_floor()," velocity ",level.player.velocity," clip ",level.actor.current_clip)
   last_shoving=escape.cart_shoving
  if escape.cart_shoving:
   shoved_frames+=1
   if shoved_frames==30:await snap("02-bracing")
   assert(level.actor.pose.shoved and level.actor.current_clip in [&"shoved_in",&"shoved"],"cart contact must show bracing, not standing")
  if not level.player.is_on_floor() and route.feet().x>escape.EDGE_X:
   fell=true;break
 assert(transitions<=2,"continuous contact cannot restart bracing at floor seams")
 assert(shoved_frames>10,"rolling cart must push the exposed player with a bracing animation")
 assert(fell,"bracing must not leave the player standing over the mine gap")
 # Bracing is interruptible by a real jump, without the stand-up tail.
 gap.restore()
 level.player.position=Vector2(trial.cart_x+45-13,trial.ground(trial.cart_x+45)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(trial.cart_x+45)
 await frames(15);trial.cart_speed=35;gap.coast=true
 for i in 60:
  await frames(1)
  if escape.cart_shoving:break
 assert(escape.cart_shoving,"second contact must enter bracing")
 Input.action_press("jump");Input.action_press("move_right")
 var jumped:=false
 for i in 22:
  await frames(1)
  if level.player.velocity.y< -100:jumped=true
  # SceneTree.physics_frame is emitted before the controller tick; allow
  # the input to reach that tick before checking the visible exit state.
  if i>1:assert(not escape.cart_shoving and level.actor.current_clip!=&"shoved_out","jump must interrupt bracing without a recovery twitch")
 Input.action_release("jump");Input.action_release("move_right")
 assert(jumped,"the player must be able to jump away from the pushing cart")
 print("SHOVE JUMP EXIT PASS")
 print("SHOVE TRANSITIONS ",transitions)
 print("PUSH HOLD PASS shove_frames ",shoved_frames)
 quit()
