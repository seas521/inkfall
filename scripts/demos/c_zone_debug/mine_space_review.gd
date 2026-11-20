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
 level.player.position=Vector2(-2750-13,route.mine_floor_y(-2750)-54)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=route.mine_floor_y(-2750)
 await frames(80)
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image()
 img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-v1/review/05-layout.png")
 var props=route.mine_trial.rear_tools
 var bounds:Rect2i=props.texture.get_image().get_used_rect()
 var foot_y:float=props.position.y+float(bounds.end.y)*props.scale.y
 assert(absf(foot_y-route.mine_floor_y(-2950)-2)<0.1)
 assert(props.z_index+route.mine_trial.z_index<level.actor.z_index)
 assert(route.failure_time==0)
 route.mine_trial.break_wall()
 route.mine_trial.cart_x=route.mine_trial.PARK_X
 await frames(100)
 await RenderingServer.frame_post_draw
 img=root.get_texture().get_image()
 img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-v1/review/06-open-layout.png")
 var chamber=route.art.chamber
 chamber.set_process(false)
 for phase in 2:
  chamber.lamp.elapsed=1.0 if phase==0 else 3.1
  chamber._process(0)
  route.art.sync(0.0)
  route.mine_trial.sync_visual(0)
  await frames(2)
  await RenderingServer.frame_post_draw
  img=root.get_texture().get_image()
  img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
  img.save_png("res://artifacts/mine-cart-v1/review/10-lamp-%d.png"%phase)
 level.player.position=Vector2(-3060-13,route.mine_floor_y(-3060)-54)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=route.mine_floor_y(-3060)
 await frames(70)
 await RenderingServer.frame_post_draw
 img=root.get_texture().get_image()
 img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-v1/review/11-entrance-ground.png")
 print("MINE SPACE PASS")
 quit()
