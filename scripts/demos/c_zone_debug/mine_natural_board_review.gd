extends SceneTree
var level
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 for distance:float in [59,75,95,115]:
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
  if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
  await frames(8)
  level.enter_root_cliff_test();var route=level.bridge_to_c
  route.checkpoint_step=3;route.restore_checkpoint();var trial=route.mine_trial
  route.swing_rope.reset() # natural rope traversal previously restored mask 11
  var x:float=trial.cart_x-distance
  level.player.position=Vector2(x-13,trial.ground(x)-55);level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(x);await frames(20)
  var max_height:=0.0;var boarded:=false
  Input.action_press("move_right");Input.action_press("jump")
  for i in 100:
   await frames(1)
   if i==1:Input.action_release("jump")
   max_height=maxf(max_height,trial.cart_position().y-route.feet().y)
   if trial.escape.is_riding():boarded=true;break
  Input.action_release("move_right");Input.action_release("jump")
  await frames(60)
  assert(boarded and trial.escape.is_riding() and absf(route.feet().x-trial.cart_x)<20,"natural rope traversal must preserve cart collisions and a stable seat")
  if distance==59 and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://artifacts/mine-natural-boarding-v1/locked-cart-seated.png")
  print("STABLE ",trial.escape.is_riding()," local ",route.feet()-trial.cart_position()," floor ",level.player.is_on_floor())
  print("LOCKED BOARD distance ",distance," success ",boarded," peak ",max_height," feet ",route.feet()-trial.cart_position()," mask ",level.player.collision_mask)

  level.queue_free();await frames(2)
 print("NATURAL BOARD PASS")
 quit()
