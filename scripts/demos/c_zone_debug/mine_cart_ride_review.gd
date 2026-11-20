extends SceneTree
var level
var route
var trial
var escape
var maximum_speed:=0.0
var start_pitch:=0.0
var impact_pitch:=0.0
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func snap(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-ride-v2/"+name+".png")
func run()->void:
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_root_cliff_test()
 route=level.bridge_to_c;route.checkpoint_step=3;route.restore_checkpoint()
 trial=route.mine_trial;escape=trial.escape
 level.player.position=Vector2(trial.GRIP_X-13,trial.ground(trial.GRIP_X)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(trial.GRIP_X)
 await frames(15);await snap("00-parked")
 Input.action_press("interact")
 for i in 260:
  await frames(1)
  if trial.launched and trial.operation=="":break
 Input.action_release("interact")
 Input.action_press("move_right");Input.action_press("jump")
 var boarded:=false
 for i in 100:
  await frames(1)
  var grade:float=atan((route.mine_floor_base_y(trial.cart_x+10)-route.mine_floor_base_y(trial.cart_x-10))/20.0)
  start_pitch=maxf(start_pitch,absf(escape.visual_motion().x-grade))
  if escape.is_riding():boarded=true;break
 Input.action_release("move_right");Input.action_release("jump")
 assert(boarded)
 var seated:=false
 var struck:=false
 var after_strike:=false
 for i in 650:
  await frames(1)
  maximum_speed=maxf(maximum_speed,trial.cart_speed)
  var base:float=atan((route.mine_floor_base_y(trial.cart_x+10)-route.mine_floor_base_y(trial.cart_x-10))/20.0)
  if not trial.broken:start_pitch=maxf(start_pitch,absf(escape.visual_motion().x-base))
  if escape.ride_age>.45 and not seated:
   seated=true;await snap("01-seated")
   assert(level.actor.pose.action==&"mine_cart_ride")
   assert(absf(level.actor.position.x-trial.cart_x)<22)
   assert(absf(route.feet().x-trial.cart_x)<15)
   var visual=route.art.cart_visual
   assert(visual.back.z_index<level.actor.z_index and visual.front.z_index>level.actor.z_index)
   assert(visual.ROLL_RADIUS>13)
  if trial.broken:
   impact_pitch=maxf(impact_pitch,absf(escape.visual_motion().x-base))
   if not struck and trial.impact_age>.07:
    struck=true;await snap("02-impact")
   if not after_strike and trial.impact_age>.40:
    after_strike=true;await snap("03-fast-run")
  if escape.stopped_once:break
 assert(seated and struck and after_strike and escape.saved and route.failure_time==0)
 assert(maximum_speed>280)
 print("ROCK TRACE ",start_pitch," ",impact_pitch," SPEED ",maximum_speed)
 assert(start_pitch>.015 and impact_pitch>.025)
 var visual=route.art.cart_visual
 var expected:float=(trial.cart_x-route.MINE_CART_X)/visual.ROLL_RADIUS
 for wheel in visual.axles:
  var wheel_expected:float=escape.front_wheel_distance()/visual.ROLL_RADIUS if wheel.get_meta("front_axle",false) else expected
  assert(absf(angle_difference(wheel.rotation.x,wheel_expected))<.0001)
 await snap("04-stop")
 print("CART RIDE PASS: passenger between walls, large spoked wheels, distance-based rotation; peak speed=",maximum_speed," start rocking=",start_pitch," impact rocking=",impact_pitch)
 quit()
