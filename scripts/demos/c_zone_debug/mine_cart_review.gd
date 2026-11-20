extends SceneTree
var level
var route
var trial
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,label:String)->void:
 print(label,": ",ok)
 if not ok:failures.append(label)
func walk(x:float)->void:
 var direction:String="move_right" if route.feet().x<x else "move_left"
 Input.action_press(direction)
 for i in 600:
  await frames(1)
  if absf(route.feet().x-x)<3:break
 Input.action_release(direction)
 await frames(16)
func use(n:int)->void:
 Input.action_press("interact");await frames(n)
 Input.action_release("interact");await frames(8)
func snap(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image()
 img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-v1/review/"+label+".png")
func run()->void:
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_root_cliff_test();route=level.bridge_to_c
 route.checkpoint_step=3;route.restore_checkpoint();trial=route.mine_trial
 await frames(15)
 await walk(-2960);await snap("01-entrance")
 await walk(trial.BRAKE_X)
 await snap("02-locked")
 check(trial.cart_speed==0 and not trial.broken and trial.wall.collision_layer==1,"initial cart locked and wall solid")
 check(trial.cart_body.collision_layer==1,"cart has solid body")
 check(trial.find_children("*","Sprite2D",true,false).size()==2,"only work corner and miner remain, no fire props")
 await use(20);await frames(35)
 check(not trial.launched and trial.brake_progress==0,"release early keeps stop raised")
 Input.action_press("interact")
 await frames(75)
 check(level.actor.current_clip==&"grip_to_pull", "lever uses backwards pulling stroke")
 check(route.feet().x<trial.GRIP_X-1, "player steps back while facing handle")
 await snap("02b-pull")
 check(trial.hand_contact and trial.lever_handle().distance_to(level.actor.grip_hand_world())<2.5, "handle remains in the pulling hand (gap %.2f)" % trial.lever_handle().distance_to(level.actor.grip_hand_world()))
 check(not trial.launched, "cart stays locked during effort")
 await frames(70)
 Input.action_release("interact");await frames(8)
 check(trial.launched and trial.brake_progress==1,"hold lever lowers stop")
 check(not trial.broken,"wall remains until cart contact")
 for i in 400:
  await frames(1)
  if trial.broken:break
 check(trial.broken and trial.impact_age<0.1,"impact occurs at wall")
 check(absf(trial.cart_x-(trial.WALL_X-48))<8,"cart front contacts before collapse")
 check(trial.wall.collision_layer==0 and trial.shake>0 and not trial.dust.is_empty(),"impact opens passage with dust and shake")
 await snap("03-impact")
 await walk(-2240)
 check(route.feet().x>-2250 and route.failure_time==0,"walk through broken wall")
 await snap("04-open")
 await frames(400)
 check(absf(trial.cart_x-trial.PARK_X)<1 and trial.cart_speed==0,"cart stops at lower rail end")
 route.restore_checkpoint();await frames(10)
 check(trial.broken and trial.operation=="","checkpoint preserves cleared obstacle")
 trial.reset();await frames(5)
 check(not trial.broken and not trial.launched and trial.wall.collision_layer==1 and trial.cart_speed==0,"restart restores lock and wall")
 print("MINE CART ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
