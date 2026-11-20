extends SceneTree

const DIR="res://artifacts/mine-descent-v4/review"
var level
var route
var failures:Array[String]=[]
var capture:=false

func _initialize()->void: call_deferred("run")

func frames(n:int)->void:
 for i in n: await physics_frame

func check(ok:bool,message:String)->void:
 if not ok:
  failures.append(message)
  push_error(message)

func snap(label:String)->void:
 if not capture:return
 await RenderingServer.frame_post_draw
 var picture:Image=root.get_texture().get_image()
 picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 picture.save_png(DIR+"/"+label+".png")

func check_landmark()->void:
 var expected:Vector2=Vector2(level.camera_x,level.camera_y)-level.log_bridge.ORIGIN
 var terrain:Vector2=level.log_bridge.art.depth.material.get_shader_parameter("camera")
 check(terrain.distance_to(expected)<0.1,"house and distant mountain must use the same current camera")

func run()->void:
 capture=DisplayServer.get_name()!="headless"
 if capture:
  root.content_scale_size=Vector2i(1280,720)
  root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(1280,720))
 DirAccess.make_dir_recursive_absolute(DIR)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
 root.add_child(level)
 if capture:preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 route=level.bridge_to_c
 level.debug_enter_rope_ladder(false)
 await frames(10)
 await snap("01-cliff")
 Input.action_press("climb_down")
 var mid_saved:=false
 for i in 1800:
  await frames(1)
  if i%60==0:check_landmark()
  if not mid_saved and level.rope_ladder.feet().y> -4180:
   await snap("02-ladder-middle")
   mid_saved=true
  if level.rope_ladder.at_bottom:break
 Input.action_release("climb_down")
 check(level.rope_ladder.at_bottom,"must reach the bottom of the ladder")
 await snap("03-ladder-bottom")
 print("BOTTOM ",route.feet())
 Input.action_press("jump")
 await frames(2)
 Input.action_release("jump")
 for i in 180:
  await frames(1)
  if route.active and level.player.is_on_floor():break
 check(route.active and level.player.is_on_floor(),"ladder dismount must land on the short shelf")
 print("LANDING feet=",route.feet()," rope=",level.rope_ladder.mode," active=",route.active)
 await snap("04-short-landing")
 if not route.active or not level.player.is_on_floor():
  quit(1)
  return
 for target in route.STEPS.size():
  var direction:=1.0 if target%2==0 or target==route.MOUTH_STEP else -1.0
  var source:Dictionary=route.landing if target==0 else route.ledges[target-1]
  var top:PackedVector2Array=source.top
  var takeoff:float=top[-1].x-5 if direction>0 else top[0].x+5
  var action:="move_right" if direction>0 else "move_left"
  Input.action_press(action)
  for i in 100:
   await frames(1)
   if (route.feet().x-takeoff)*direction>=0:break
  Input.action_press("jump")
  var airborne:=false
  var landed:=false
  for i in 260:
   await frames(1)
   if not level.player.is_on_floor():airborne=true
   if route.failure_time>0:break
   if airborne and level.player.is_on_floor():
    landed=true
    break
  Input.action_release("jump")
  Input.action_release(action)
  check(landed and route.failure_time<=0 and route.last_step==target,"jump "+str(target+1)+" must reach its opposing stone without death")
  print("JUMP ",target+1," feet=",route.feet()," landed=",landed," shelf=",route.last_step," failure=",route.failure_time)
  await snap("05-jump-"+str(target+1))
  if not landed or route.failure_time>0:break
  await frames(3)
 check_landmark()
 print("TRAVERSAL ","PASS" if failures.is_empty() else "FAIL", " ",failures)
 quit(0 if failures.is_empty() else 1)
