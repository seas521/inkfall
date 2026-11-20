extends SceneTree
var level
var route
var shaft
var failed:=false
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(value:bool,label:String)->void:
 print(label,": ",value)
 if not value:failed=true;quit(1)
func place(x:float,y:float)->void:
 level.player.position=Vector2(x-13,y-55);level.player.velocity=Vector2.ZERO
 route.fall_origin=y;shaft.fall_y=y
 await frames(12)
func use(n:int=80)->void:
 Input.action_press("interact");await frames(n)
 Input.action_release("interact");await frames(8)
func walk(x:float,limit:int=600)->void:
 var dir:String="move_right" if route.feet().x<x else "move_left"
 Input.action_press(dir)
 for i in limit:
  await frames(1)
  if absf(route.feet().x-x)<3:break
 Input.action_release(dir);await frames(8)
func move_cart(x:float)->void:
 Input.action_press("interact");await frames(30)
 var dir:String="move_right" if route.mine_trial.cart_x<x else "move_left"
 Input.action_press(dir)
 for i in 1000:
  await frames(1)
  if absf(route.mine_trial.cart_x-x)<1 or shaft.cart_on_cage:break
 Input.action_release(dir);Input.action_release("interact");await frames(10)
func snap(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await frames(20);await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-shaft-v1/"+name+".png")
func run()->void:
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_mine_shaft_test()
 route=level.bridge_to_c;shaft=route.shaft;await frames(20)
 check(shaft.jammed and not shaft.routed,"transport starts unsolved")
 await snap("01-upper")
 await place(shaft.POINTS_X,shaft.UPPER);await use()
 check(not shaft.routed,"cannot bypass load and pin at points")
 await place(shaft.PROBE_X,shaft.UPPER);await use()
 check(shaft.inspected and shaft.hatch.collision_layer==0,"probe reveals service access")
 await walk(-1950);await frames(90)
 check(route.feet().y>shaft.UPPER+35 and route.failure_time==0,"hatch leads onto physical service ramp")
 await walk(-1693)
 check(absf(route.feet().y-shaft.LOWER)<12,"walk down to jammed transmission")
 await use(100)
 check(not shaft.jammed and shaft.checkpoint==1,"push stone frees transmission")
 await snap("02-service")
 await walk(shaft.LADDER_X)
 Input.action_press("climb_up");await frames(180);Input.action_release("climb_up");await frames(10)
 check(absf(route.feet().y-shaft.UPPER)<12 and not shaft.ladder,"return ladder reaches main deck")
 await walk(-2016)
 await move_cart(shaft.TRAY_X);await frames(100)
 check(absf(route.mine_trial.cart_x-shaft.TRAY_X)<3 and shaft.tray_depth>23,"cart loads the weighbridge")
 check(shaft.gate.collision_layer==0,"loaded platform opens lower gate")
 await walk(shaft.LADDER_X)
 Input.action_press("climb_down");await frames(180);Input.action_release("climb_down");await frames(10)
 check(absf(route.feet().y-shaft.LOWER)<12,"descend service ladder")
 await walk(shaft.PIN_X);await use()
 check(shaft.pin_locked,"insert pin under load")
 await snap("03-pin")
 await walk(shaft.LADDER_X)
 Input.action_press("climb_up");await frames(180);Input.action_release("climb_up");await frames(10)
 await walk(shaft.TRAY_X+54)
 await move_cart(-1400);await frames(80)
 check(absf(route.mine_trial.cart_x+1400)<4,"cart can be retrieved from loaded tray")
 check(shaft.pin_locked and shaft.tray_depth>25,"pin holds after cart is removed")
 await place(shaft.PIN_X,shaft.LOWER);await use()
 check(shaft.pin_locked,"loaded pin cannot be pulled out unsafely")
 await place(shaft.POINTS_X,shaft.UPPER);await use();await frames(220)
 check(shaft.routed and absf(shaft.cage_y-shaft.UPPER)<2,"clutch docks cage only after load transfer")
 await walk(-1346);await move_cart(shaft.CAGE_X)
 check(shaft.cart_on_cage,"cart crosses switched rail onto cage")
 await snap("04-loaded-cage")
 await use()
 check(shaft.descending,"onboard release starts controlled descent")
 for i in 800:
  await frames(1)
  if route.failure_time>0:break
 check(shaft.hazard_hits==1 and route.failure_time>0,"standing into the first low beam is fatal")
 route.restore_checkpoint();await frames(8)
 check(shaft.pin_locked and shaft.cart_on_cage and not shaft.descending,"beam death restores a safe loaded cage")
 await use()
 Input.action_press("climb_down")
 for i in 2600:
  await frames(1)
  if shaft.arrived:break
 Input.action_release("climb_down");await frames(4)
 check(shaft.arrived and route.failure_time==0,"crouch clears both shaft beams")
 check(absf(route.feet().y-shaft.cage_y)<20,"cage carries actor without drift or scale change")
 await snap("05-lower-exit")
 # Death retries never replay the solved multi-step puzzle.
 route.fail();route.restore_checkpoint();await frames(5)
 check(shaft.pin_locked and shaft.cart_on_cage and shaft.routed and not shaft.descending,"safe checkpoint retains solved transport")
 shaft.reset();route.mine_trial.reset();await frames(2)
 check(shaft.jammed and not shaft.pin_locked and shaft.fragile_body.collision_layer==1,"full restart restores puzzle and fragile deck")
 print("MINE SHAFT ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
