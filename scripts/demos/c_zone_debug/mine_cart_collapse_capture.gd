extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_root_cliff_test()
 var route=level.bridge_to_c
 route.checkpoint_step=3;route.restore_checkpoint()
 var trial=route.mine_trial
 await frames(12)
 level.set_physics_process(false)
 level.player.position=Vector2(trial.PARK_X-75-13,trial.ground(trial.PARK_X-75)-55)
 level.player.velocity=Vector2.ZERO
 level.camera_x=-3210;level.camera_y=-3690
 level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
 trial.cart_x=trial.PARK_X;trial.cart_speed=0
 trial.escape.stopped_once=true;trial.escape.saved=true
 trial.launched=true
 route._present(0.0)
 trial.break_wall()
 var lamp_home:Vector2=route.art.chamber.lamp.light_position()
 var floor_home:float=route.mine_floor_y(-2720)
 var age:=0.0
 for time in [0.0,0.25,0.45,0.65,0.90,1.10,1.35,2.4,5.8]:
  while age<time:
   trial.tick_failure_visual(1.0/120.0)
   age+=1.0/120.0
  route.art.sync(0.0)
  await frames(2);await RenderingServer.frame_post_draw
  var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
  img.save_png("res://artifacts/mine-cart-escape-v1/collapse-%03d.png"%int(time*100))
 var rack=trial.escape.tool_parts[0].node
 assert(absf(rack.rotation)>0.9)
 assert(trial.miner.position.distance_to(trial.escape.miner_home)>1)
 assert(trial.escape.roof.all(func(chunk):return chunk.landed))
 assert(route.art.chamber.roof_shift(-2720)>180)
 assert(route.mine_floor_y(-2720)-floor_home>10)
 assert(trial.escape.floor_pads.any(func(part):return part.last.x-route.mine_floor_base_y(part.a)>10))
 assert(route.art.chamber.lamp.light_position().y-lamp_home.y>100)
 assert(route.art.chamber.lamp.energy<.001)
 assert(absf(route.art.chamber.lamp.light_position().y-(route.mine_floor_y(route.art.chamber.lamp.global_position.x)-8))<1)
 assert(route.art.chamber.floor_shift(trial.PARK_X)==0)
 trial.reset()
 assert(route.art.chamber.collapse_age<0)
 assert(route.art.chamber.lamp.energy==1)
 assert(absf(route.art.chamber.lamp.swing.position.y)<.001)
 assert(absf(route.mine_floor_y(-2720)-floor_home)<.001)
 assert(absf(rack.rotation)<0.0001)
 assert(trial.miner.position.is_equal_approx(trial.escape.miner_home))
 print("COLLAPSE VISUAL PASS: continuous ceiling, solid sinking ground, fallen extinguished lamp, reacting props, safe exit and clean reset")
 quit()
