extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func snap(label:String)->void:
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image()
 img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-v1/review/"+label+".png")
func run()->void:
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
 root.add_child(level)
 preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_root_cliff_test()
 var route=level.bridge_to_c
 route.checkpoint_step=3;route.restore_checkpoint()
 var trial=route.mine_trial
 level.player.position=Vector2(trial.GRIP_X-13,route.mine_floor_y(trial.GRIP_X)-54)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=route.mine_floor_y(trial.GRIP_X)
 await frames(60)
 Input.action_press("interact")
 await frames(38);await snap("07-grip-contact")
 await frames(42);await snap("08-grip-effort")
 assert(trial.hand_contact and not trial.launched)
 assert(trial.lever_handle().distance_to(level.actor.grip_hand_world())<1.5)
 await frames(35);await snap("09-grip-release")
 for i in 120:
  await frames(1)
  if trial.launched and trial.operation=="":break
 Input.action_release("interact")
 assert(trial.launched and trial.operation=="")
 print("MINE GRIP VISUAL PASS")
 quit()
