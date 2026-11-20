extends SceneTree
var level
var route
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
 root.add_child(level)
 await frames(8)
 level.enter_root_cliff_test()
 route=level.bridge_to_c
 level.set_physics_process(false)
 var rope=route.swing_rope
 rope.state=rope.State.HANG
 rope.climb_pose=true
 rope.grip=180
 rope.age=1
 rope.frame=60
 rope.shown_hand=rope.hand()
 var anchor:Vector2=rope.hand()
 level.camera_x=anchor.x-640
 level.camera_y=anchor.y-320
 level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
 var failures:Array[String]=[]
 for up in [false,true,false]:
  rope.climbing_up=up
  level.player.position=rope.hand()+rope.track("feet_local",60)-Vector2(13,54)
  for i in 8:rope.present(1.0/60.0)
  level.art.sync(0,level.camera_x,true)
  route.art.sync(0)
  if rope.hand_error>1:failures.append("hand detaches on direction change")
  print("UP=",up," body_scale=",level.actor.body.scale," feet_offset=",rope.track("feet_local",60)," hand_error=",rope.hand_error)
  if DisplayServer.get_name()!="headless":
   await frames(3)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://artifacts/cliff-film-v1/rope-"+("up" if up else "down")+".png")
 print("ROPE SCALE ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
