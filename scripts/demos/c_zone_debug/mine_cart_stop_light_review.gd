extends SceneTree
var level
var route
var trial
var escape
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func brightness(img:Image,at:Vector2)->float:
 var pixel:Vector2=level.get_global_transform_with_canvas()*at
 var value:=0.0
 for y in range(-2,3):
  for x in range(-2,3):value+=img.get_pixelv(Vector2i(pixel)+Vector2i(x,y)).r
 return value/25.0
func run()->void:
 root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_root_cliff_test()
 route=level.bridge_to_c;route.checkpoint_step=3;route.restore_checkpoint()
 trial=route.mine_trial;escape=trial.escape
 await frames(12);level.set_physics_process(false)
 trial.launched=true;trial.broken=true;trial.wall.collision_layer=0
 trial.cart_x=trial.PARK_X;trial.cart_speed=0;trial.impact_age=8
 escape.stopped_once=true;escape.saved=true;escape.riding=true;escape.ride_age=1;escape.seat_start=Vector2(-9,-47)
 escape._update_collapse(0)
 var y:float=trial.ground(trial.PARK_X)
 level.player.position=Vector2(trial.PARK_X-22,y-101);level.player.velocity=Vector2.ZERO
 level.camera_x=trial.PARK_X-600;level.camera_y=y-460
 level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
 for phase in [0.0,1.1,3.2]:
  escape.end_lamp.elapsed=phase;escape.end_lamp.update_swing(0);escape._update_lighting()
  route._present(0)
  await frames(3);await RenderingServer.frame_post_draw
  var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
  img.save_png("res://artifacts/mine-cart-stop-light-v1/stop-%02d.png"%int(phase*10))
  var rear:=brightness(img,Vector2(trial.PARK_X-65,y-75))
  var front:=brightness(img,Vector2(trial.PARK_X+55,y-78))
  var body:=brightness(img,route.art.cart_sprite.to_global(Vector2(0,-24)))
  print("STOP LIGHT phase=",phase," rear=",rear," front=",front," body=",body)
  assert(rear>.08 and front>.08)
  assert(body<.025)
 # Also review the place the player stands to recover the cart.
 escape.riding=false;escape.ride_age=0
 var rear_x:float=trial.PARK_X-67
 level.player.position=Vector2(rear_x-13,trial.ground(rear_x)-54)
 route._present(0)
 await frames(3);await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-stop-light-v1/rear-grip.png")
 print("STOP LIGHT PASS: wall lights around black cart through shade swing, including rear grip")
 quit()
