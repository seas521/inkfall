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
 await frames(8);level.enter_mine_shaft_test()
 var route=level.bridge_to_c
 var shaft=route.shaft
 for shot in [["upper",Vector2(-1530,-3170)],["service",Vector2(-1450,-2940)],["cage",Vector2(-1150,-3170)],["exit",Vector2(-900,-520)]]:
  if shot[0]=="service":shaft.jammed=false;shaft.inspected=true
  if shot[0]=="exit":shaft.arrived=true;shaft.cage_y=shaft.EXIT_Y
  var p:Vector2=shot[1]
  level.player.position=p-Vector2(13,55);level.player.velocity=Vector2.ZERO
  route.fall_origin=p.y;shaft.fall_y=p.y
  level.camera_x=p.x-540;level.camera_y=p.y-495
  level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
  await frames(12);await RenderingServer.frame_post_draw
  var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
  img.save_png("res://artifacts/mine-shaft-v1/capture-"+shot[0]+".png")
 shaft.jammed=false;shaft.pin_locked=true;shaft.routed=true;shaft.cart_on_cage=true
 shaft.arrived=false;shaft.descending=false;shaft.cage_y=shaft.UPPER
 route.mine_trial.cart_x=shaft.CAGE_X
 level.player.position=Vector2(-1100-13,shaft.UPPER-55)
 level.player.velocity=Vector2.ZERO;shaft.fall_y=shaft.UPPER;route.fall_origin=shaft.UPPER
 level.camera_x=-1640;level.camera_y=shaft.UPPER-495
 level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
 await frames(20);await RenderingServer.frame_post_draw
 var ready=root.get_texture().get_image();ready.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 ready.save_png("res://artifacts/mine-shaft-v1/capture-ready.png")
 print("MINE SHAFT CAPTURE PASS")
 quit()
