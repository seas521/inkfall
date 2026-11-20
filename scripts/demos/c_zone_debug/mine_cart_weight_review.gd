extends SceneTree
var level
var route
var trial
var escape
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func snap(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-performance-v1/"+name+".png")
func run()->void:
 root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_root_cliff_test();route=level.bridge_to_c
 route.checkpoint_step=3;route.restore_checkpoint();trial=route.mine_trial;escape=trial.escape
 level.player.position=Vector2(trial.GRIP_X-13,trial.ground(trial.GRIP_X)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(trial.GRIP_X)
 await frames(15)
 Input.action_press("interact")
 for i in 260:
  await frames(1)
  if trial.launched and trial.operation=="":break
 Input.action_release("interact");Input.action_press("move_right");Input.action_press("jump")
 for i in 100:
  await frames(1)
  if escape.is_riding():break
 Input.action_release("move_right");Input.action_release("jump")
 assert(escape.is_riding())
 var cracked:=false
 var broken:=false
 var contacted:=false
 var skidding:=false
 var sparks:=false
 var previous_speed:=1000.0
 var brake_start:=0.0
 var brake_frames:=0
 for i in 900:
  await frames(1)
  if trial.broken and trial.impact_age>.16 and not cracked:cracked=true;await snap("01-joints-loaded")
  if trial.broken and trial.impact_age>.70 and not broken:broken=true;await snap("02-wood-fractures")
  if escape.braking:
   if not contacted:
    contacted=true;brake_start=trial.cart_x
    assert(trial.cart_speed>250)
    await snap("03-wheel-contact")
   brake_frames+=1
   assert(trial.cart_speed<=previous_speed+.01)
   previous_speed=trial.cart_speed
   sparks=sparks or not escape.sparks.is_empty()
   if escape.brake_age>escape.brake_duration*.42 and not skidding:
    skidding=true;await snap("04-skidding-brake")
    assert(escape.skid_loss>8 and escape.brake_load()>.5)
  if escape.stopped_once:break
 assert(contacted and skidding and sparks and brake_frames>=20)
 assert(escape.brake_duration>.45 and trial.cart_x-brake_start>65)
 assert(trial.cart_speed==0 and absf(trial.cart_x-trial.PARK_X)<.1)
 assert(escape.saved and route.failure_time==0)
 await frames(30);await snap("05-settled-cart")
 for support in escape.timber_supports:
  assert(support.parts.size()>support.beams.size())
  assert(support.parts.any(func(part):return part.land_time>=0))
 var renders:int=route.art.cart_visual.render_updates
 await frames(150)
 var after:int=route.art.cart_visual.render_updates
 await frames(45)
 assert(route.art.cart_visual.render_updates==after)
 assert(escape.sparks.is_empty())
 assert(escape.peak_sparks>=24 and escape.peak_sparks<=escape.MAX_SPARKS)
 assert(escape.timber_supports.all(func(support):return support.parts.all(func(part):return part.land_time>=0)))
 print("WEIGHT PASS: brake frames=",brake_frames," duration=",escape.brake_duration," slide=",trial.cart_x-brake_start," sparks and locked front wheel; split supports settled; static render cache=",after-renders)
 quit()
