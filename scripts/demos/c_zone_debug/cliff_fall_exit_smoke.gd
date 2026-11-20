extends SceneTree
var level
var route
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message)
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
 root.add_child(level)
 await frames(8)
 level.enter_root_cliff_test()
 route=level.bridge_to_c
 route.checkpoint_step=0
 route.restore_checkpoint()
 var tree=route.trees[1]
 var x:float=tree.branch.global_position.x+3
 var y:float=route.Geometry.surface_y({"top":tree.world_top()},x)
 level.player.position=Vector2(x-13,y-55)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=y
 route.last_step=1
 level.camera_y=y-440
 level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
 for i in 100:
  await frames(1)
  if route.failure_time>0:break
 check(route.failure_airborne,"branch failure is a free fall")
 var camera:Vector2=level.camera.position
 var previous_y:float=level.player.position.y
 var exit_seen:=false
 var falling_frames:=0
 var fall_frames:Dictionary={}
 var saw_closing:=false
 for i in 180:
  await frames(1)
  if route.failure_time<=0:break
  falling_frames+=1
  check(level.player.position.y>previous_y,"fatal fall continues moving down")
  previous_y=level.player.position.y
  check(level.camera.position.is_equal_approx(camera),"camera stays at fall location")
  check(level.actor.current_clip!=&"fall_impact" and level.actor.current_clip!=&"downed","no airborne ground-impact pose")
  check(level.actor.current_clip==&"fall_loop","actual forest fall animation is playing")
  fall_frames[level.actor.current_frame_index]=true
  if route.failure_close>0:
   saw_closing=true
   check(exit_seen,"iris closes only after body leaves the frame")
  if level.player.get_global_transform_with_canvas().origin.y>level.get_viewport_rect().size.y:exit_seen=true
 check(falling_frames>5 and exit_seen,"body visibly falls out before respawn")
 check(route.failure_time==0 and not route.failure_airborne and level.player.collision_mask==11,"respawn restores normal control/collision")
 check(fall_frames.size()>3,"fall animation advances rather than freezing on a pose")
 check(saw_closing and route.respawn_reveal>0,"iris closes and begins opening at the checkpoint")
 check(float(level.iris.material.get_shader_parameter("amount"))>0.99,"checkpoint relocation happens behind full black")
 await frames(35)
 check(route.respawn_reveal==0 and not level.iris.rect.visible,"iris fully opens after respawn")
 print("FALL EXIT ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
