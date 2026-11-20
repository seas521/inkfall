extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
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
 var x:float=trial.WALL_X-125
 level.player.position=Vector2(x-13,route.mine_floor_y(x)-54)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=route.mine_floor_y(x)
 await frames(70)
 trial.launched=true;trial.cart_x=trial.WALL_X-48;trial.cart_speed=180
 trial.break_wall()
 for n in [8,18,48,100]:
  await frames(n)
  await RenderingServer.frame_post_draw
  var img=root.get_texture().get_image()
  img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
  img.save_png("res://artifacts/mine-cart-v1/review/dust-%03d.png"%n)
 await frames(180)
 assert(trial.dust.is_empty())
 print("MINE DUST REVIEW PASS particles clear after collapse")
 quit()
