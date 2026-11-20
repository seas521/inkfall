extends SceneTree
var level
var route
var trial
var escape
var errors:=0
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,label:String)->void:
 print(label,": ",ok)
 if not ok:errors+=1;quit(1)
func snap(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-escape-v3/"+name+".png")
func lever()->void:
 Input.action_press("interact")
 for i in 260:
  await frames(1)
  if trial.launched and trial.operation=="":break
 Input.action_release("interact")
func run()->void:
 root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_root_cliff_test()
 route=level.bridge_to_c;route.checkpoint_step=3;route.restore_checkpoint()
 trial=route.mine_trial;escape=trial.escape
 level.player.position=Vector2(trial.GRIP_X-13,trial.ground(trial.GRIP_X)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(trial.GRIP_X)
 await frames(15);await snap("00-black-cart")
 if DisplayServer.get_name()!="headless":
  var at:Vector2=route.art.cart_sprite.get_global_transform_with_canvas()*Vector2(0,-24)
  var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
  var shade:=img.get_pixelv(Vector2i(at))
  print("CART BODY PIXEL ",shade)
  check(maxf(shade.r,maxf(shade.g,shade.b))<.025,"cart body stays black in actual film render")
 await lever()
 var stumbled:=false
 var grounded_fall:=false
 for i in 650:
  await frames(1)
  if escape.stumble_age>.2 and not stumbled:
   stumbled=true
   check(level.actor.pose.action==&"mine_collapse_stagger","shock triggers stagger before crushing")
   await snap("01-stumble")
  if escape.stumble_age>.65 and not grounded_fall:
   grounded_fall=true;await snap("02-falling-over")
  if route.failure_time>0:break
 check(stumbled and grounded_fall and escape.crushed,"missed cart falls over then gets crushed")
 check(escape.hit_age>=0 and level.actor.pose.action==&"mine_rock_hit","death begins one continuous unhurried fall")
 for i in 180:
  await frames(1)
  if route.failure_time==0 and not trial.broken:break
 for i in 90:
  await frames(1)
  if route.respawn_reveal<=0 and level.player.is_on_floor():break
 await frames(3)
 check(route.failure_time==0 and not trial.broken,"automatic local respawn completes without repeated failure")
 check(escape.stumble_age<0 and route.art.chase_chamber.collapse_age<0,"retry resets knockdown and extended cave collapse")
 await lever()
 check(trial.launched,"rear lever works after automatic respawn reveal")
 Input.action_press("move_right");Input.action_press("jump")
 var boarded:=false
 for i in 100:
  await frames(1)
  if escape.is_riding():boarded=true;break
 Input.action_release("move_right");Input.action_release("jump")
 check(boarded,"normal jump still boards the longer route")
 var middle:=false
 var final_run:=false
 for i in 950:
  await frames(1)
  if trial.cart_x>-1940 and not middle:
   middle=true;await snap("03-extended-descent")
  if trial.cart_x>-1490 and not final_run:
   final_run=true;await snap("04-cave-closing-behind")
  if escape.stopped_once:break
 check(escape.stopped_once and escape.saved and route.failure_time==0,"longer descent reaches physical chock safely")
 check(trial.PARK_X-route.MINE_CART_X>1500 and trial.impact_age>3.5,"extended run lasts beyond original short room")
 check(escape.chase_lamp.energy<.001 and escape.end_lamp.energy==1,"pursuing collapse drops rear lamp while stop area stays lit")
 await frames(20);await snap("05-new-stop")
 print("ESCAPE V3 ","PASS" if errors==0 else "FAIL"," distance=",trial.PARK_X-route.MINE_CART_X," wall-to-stop=",trial.impact_age)
 quit(0 if errors==0 else 1)
