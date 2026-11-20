extends SceneTree
var level
var route
var gap
var image_index:=0
func _initialize()->void:call_deferred("run")
func frames(n:int,capture:bool=false)->void:
 for i in n:
  await physics_frame
  if capture and i%2==0 and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
   img.save_png("res://artifacts/heavy-mime-integration-v2/gameplay/f-%04d.png"%image_index);image_index+=1
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_mine_cart_gap_test();route=level.bridge_to_c;gap=route.mine_trial.gap
 var x:float=route.mine_trial.escape.chock_body.position.x+45
 level.player.position=Vector2(x-13,route.mine_trial.ground(x)-55);level.player.velocity=Vector2.ZERO;route.fall_origin=route.mine_trial.ground(x)
 await frames(25);await frames(12,true)
 Input.action_press("interact");await frames(2);Input.action_release("interact")
 await frames(115,true);assert(gap.rock_state==2)
 await frames(20,true)
 Input.action_press("move_left");await frames(55,true);Input.action_release("move_left");await frames(16,true)
 Input.action_press("move_right");await frames(32,true);Input.action_release("move_right");await frames(16,true)
 Input.action_press("interact");await frames(2);Input.action_release("interact")
 await frames(160,true)
 assert(gap.rock_state in [4,5,6] and route.failure_time<=0,"new mime sequence must leave normal player control")
 print("MIME GAMEPLAY PASS captured ",image_index," frames; stone ",gap.rock_state)
 quit()
