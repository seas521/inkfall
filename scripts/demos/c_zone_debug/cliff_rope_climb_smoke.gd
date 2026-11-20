extends SceneTree
var level
var route
var failures:Array[String]=[]
var capture:=false
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->void:
 if not ok:failures.append(message);push_error(message)
func snap(name:String)->void:
 if not capture:return
 await RenderingServer.frame_post_draw
 var image:Image=root.get_texture().get_image()
 image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 image.save_png("res://artifacts/rope-swing/"+name+".png")
func run()->void:
 capture=DisplayServer.get_name()!="headless"
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
 root.add_child(level)
 if capture:preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_root_cliff_test()
 route=level.bridge_to_c
 var rope=route.swing_rope
 var top:PackedVector2Array=route.trees[0].world_top()
 var x:float=top[0].x+3
 var ground:float=route.Geometry.surface_y(route.ledges[0],x)
 level.player.position=Vector2(x-13,ground-55)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=ground
 route.last_step=0
 level.camera_x=x-640
 level.camera_y=ground-470
 await frames(12)
 await snap("01-before-catch")
 check(level.player.is_on_floor(),"start on first tree")
 print("START ",route.feet()," rope=",rope.hand()," top=",top[0])
 Input.action_press("jump")
 for i in 75:
  await frames(1)
  if rope.catches>0:break
 Input.action_release("jump")
 check(rope.catches==1,"ordinary jump must reach the hanging rope")
 print("CAUGHT ",rope.catches," feet=",route.feet()," state=",rope.state)
 if rope.catches==0:quit(1);return
 await frames(60)
 await snap("02-hanging")
 Input.action_press("climb_down")
 await frames(80)
 Input.action_release("climb_down")
 var lower:float=rope.grip
 check(lower>rope.MIN_GRIP+65,"S descends along rope")
 await frames(20)
 check(absf(rope.grip-lower)<0.01,"released S holds grip depth")
 await snap("07-down")
 Input.action_press("climb_up")
 await frames(50)
 Input.action_release("climb_up")
 check(rope.grip<lower-35 and rope.climbing_up,"W uses upward clip and climbs")
 await snap("08-up")
 Input.action_press("climb_up")
 await frames(100)
 Input.action_release("climb_up")
 check(absf(rope.grip-rope.MIN_GRIP)<0.01,"W can return to original catch height")
 Input.action_press("climb_down")
 await frames(260)
 Input.action_release("climb_down")
 check(absf(rope.grip-rope.LENGTH)<0.01,"down reaches bottom without overrunning")
 await snap("09-bottom")
 Input.action_press("move_left")
 check(rope.hand_error<1,"hands stay attached to simulated rope")
 for i in 180:
  await frames(1)
  if rope.state==rope.State.HANG and rope.angle< -0.34 and rope.omega< -0.4:break
 check(rope.angle< -0.34 and rope.omega< -0.4,"swing has a real outward release window")
 print("RELEASE WINDOW ",rope.angle," ",rope.omega," feet=",route.feet())
 await snap("03-swing-left")
 var bend:=0.0
 var axis:Vector2=(rope.hand()-rope.anchor()).normalized()
 for point in rope.rope_points:
  bend=maxf(bend,absf((point-rope.anchor()).cross(axis)))
 print("ROPE BEND ",bend)
 check(bend<15,"loaded upper rope stays taut without a large artificial bow")
 Input.action_press("jump")
 await frames(2)
 Input.action_release("jump")
 check(rope.releases==1,"space must release the rope")
 print("RELEASED ",route.feet()," v=",level.player.velocity)
 for i in 120:
  await frames(1)
  if route.failure_time>0 or (level.player.is_on_floor() and not rope.presenting()):break
 Input.action_release("move_left")
 await frames(2)
 await snap("04-opposite-tree")
 print("LANDED ",route.feet()," step=",route.last_step," fail=",route.failure_time)
 check(level.player.is_on_floor() and route.last_step==1 and route.failure_time==0,"swing must land safely on opposite tree")
 for target in [2,3]:
  var ledge:Dictionary=route.ledges[target-1]
  var edge:float=route.trees[1].branch.global_position.x-28 if target==2 else ledge.top[-1].x-28
  Input.action_press("move_right")
  for i in 120:
   await frames(1)
   if route.feet().x>=edge:break
  Input.action_press("jump")
  var airborne:=false
  for i in 100:
   await frames(1)
   if not level.player.is_on_floor():airborne=true
   if airborne and level.player.is_on_floor():break
   if route.failure_time>0:break
  Input.action_release("jump")
  Input.action_release("move_right")
  await frames(2)
  check(route.last_step==target and route.failure_time==0,"remaining jump "+str(target)+" must reach the mine route safely")
  if target==2:check(route.feet().x>route.ledges[2].top[0].x+12,"last tree landing has room beyond its tip")
  print("NEXT ",target," ",route.feet()," step=",route.last_step," fail=",route.failure_time)
 await snap("05-mine-door")
 await frames(360)
 check(absf(rope.angle)<0.04 and absf(rope.omega)<0.04,"released rope settles into gentle wind sway")
 var residual:=0.0
 for point in rope.rope_points:residual=maxf(residual,absf((point-rope.anchor()).cross((rope.hand()-rope.anchor()).normalized())))
 print("REST ",rope.angle," ",rope.omega," deviation=",residual)
 check(residual<2,"unloaded rope must not retain a kink")
 await snap("06-rope-rest")
 # Continue the actual rope/tree traversal into the locked cart, without
 # a checkpoint restore that could silently repair the collision mask.
 check(level.player.collision_mask==route.PLAYER_COLLISION_MASK,"natural traversal retains mine cart collision layer")
 Input.action_press("move_right")
 for i in 180:
  await frames(1)
  if route.feet().x>=route.mine_trial.GRIP_X:break
 Input.action_press("jump")
 var boarded:=false
 for i in 100:
  await frames(1)
  if i==1:Input.action_release("jump")
  if route.mine_trial.escape.is_riding():boarded=true;break
 Input.action_release("move_right");Input.action_release("jump")
 await frames(60)
 check(boarded and route.mine_trial.escape.is_riding() and not route.mine_trial.launched,"first natural approach boards locked cart and remains seated")
 print("NATURAL ROUTE LOCKED CART ",boarded," mask=",level.player.collision_mask," feet=",route.feet())
 route.restore_checkpoint()
 check(not rope.presenting() and level.player.collision_mask==route.PLAYER_COLLISION_MASK,"reset restores body collision and detaches rope")
 # A tap-jump that never catches the rope must not bypass the descent.
 route.checkpoint_step=0
 route.restore_checkpoint()
 await frames(3)
 var first:PackedVector2Array=route.trees[0].world_top()
 var edge_x:float=first[0].x+3
 var edge_y:float=route.Geometry.surface_y(route.ledges[0],edge_x)
 level.player.position=Vector2(edge_x-13,edge_y-55)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=edge_y
 route.last_step=0
 await frames(8)
 Input.action_press("move_left")
 Input.action_press("jump")
 await frames(1)
 Input.action_release("jump")
 var bypass:=false
 for i in 120:
  await frames(1)
  if route.last_step==1 and route.failure_time==0:bypass=true;break
  if route.failure_time>0:break
 Input.action_release("move_left")
 check(not bypass,"ordinary jump cannot bypass rope descent")
 route.restore_checkpoint()
 # The same initial angle returns toward vertical more slowly on a longer rope.
 var rates:Array[float]=[]
 for depth in [220.0,255.0]:
  rope.state=rope.State.HANG
  rope.grip=depth
  rope.angle=0.10
  rope.omega=0
  rope.frame=73
  rope.climb_pose=false
  await frames(1)
  rates.append(absf(rope.omega))
 check(rates[1]<rates[0],"longer loaded length produces slower gravitational swing response")
 route.restore_checkpoint()
 # No safe shortcut from the bottom grip directly to the lower right tree or mine.
 for steer in [0,1]:
  route.checkpoint_step=0
  route.restore_checkpoint()
  rope.state=rope.State.HANG
  rope.grip=rope.LENGTH
  rope.angle=0
  rope.omega=0
  rope.frame=73
  rope.age=1
  rope.climb_pose=false
  level.player.collision_mask=0
  await frames(2)
  if steer:Input.action_press("move_right")
  Input.action_press("jump")
  await frames(2)
  Input.action_release("jump")
  var shortcut:=false
  for i in 150:
   await frames(1)
   if route.failure_time>0:break
   if route.last_step>=2 and level.player.is_on_floor():shortcut=true;break
  Input.action_release("move_right")
  check(not shortcut,"bottom release cannot skip opposite tree, steering="+str(steer))
 route.restore_checkpoint()
 rope.state=rope.State.HANG
 rope.grip=rope.MIN_GRIP+10
 rope.angle=0
 rope.omega=0
 rope.climb_pose=true
 rope.frame=50
 level.player.collision_mask=0
 Input.action_press("move_left")
 await frames(15)
 Input.action_release("move_left")
 check(absf(rope.angle)>0.015,"upper grip can swing without reaching rope end")
 route.restore_checkpoint()
 rope._step_fibers(1.0/60.0)
 var touch:Vector2=rope._sample_fiber(170)
 var contacts:int=rope.contact_impulses
 rope.body_history=true
 rope.previous_body=touch-Vector2(25,0)
 level.player.position=touch+Vector2(20,30)-Vector2(13,54)
 rope._touch_free_rope(1.0/60.0)
 check(rope.contact_impulses>contacts,"crossing free rope imparts contact motion")
 route.restore_checkpoint()
 var twig_tree=route.trees[2]
 twig_tree.touch_twigs(twig_tree.branch.to_global(twig_tree.twig_area.get_center()),Vector2(100,250))
 check(twig_tree.twig_broken,"thin twig breaks under falling body instead of supporting it")
 twig_tree.tick(0.1,false,false,0)
 check(twig_tree.twig.position.y>0,"broken twig visibly falls independently of thick trunk")
 twig_tree.reset()
 check(not twig_tree.twig_broken and twig_tree.twig.position==Vector2.ZERO,"checkpoint restores twig")
 route.checkpoint_step=0
 route.restore_checkpoint()
 var trap=route.trees[1]
 var safe_x:float=trap.branch.global_position.x-26
 var safe_y:float=route.Geometry.surface_y({"top":trap.world_top()},safe_x)
 level.player.position=Vector2(safe_x-13,safe_y-55)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=safe_y
 route.last_step=1
 await frames(35)
 check(not trap.committed and not trap.broken and route.doomed_branch==null,"inner intact wood remains safe indefinitely")
 var bad_x:float=trap.branch.global_position.x+10
 var bad_y:float=route.Geometry.surface_y({"top":trap.world_top()},bad_x)
 level.player.position=Vector2(bad_x-13,bad_y-54-50)
 level.player.velocity=Vector2(0,80)
 route.fall_origin=bad_y-50
 for i in 110:
  await frames(1)
  if route.failure_time>0:break
 check(trap.broken and route.failure_time>0,"landing on outer broken tip collapses and kills player")
 route.restore_checkpoint()
 # Standing across the fracture must not leave a locked actor supported by
 # the remaining inner collider after the outer piece has fallen away.
 for offset in [1.0,3.0,6.0]:
  route.restore_checkpoint()
  var seam_x:float=trap.branch.global_position.x+offset
  var seam_y:float=route.Geometry.surface_y({"top":trap.world_top()},seam_x)
  level.player.position=Vector2(seam_x-13,seam_y-55)
  level.player.velocity=Vector2.ZERO
  route.fall_origin=seam_y
  route.last_step=1
  for i in 100:
   await frames(1)
   if route.failure_time>0:break
  check(route.failure_time>0,"fracture seam cannot softlock at offset "+str(offset))
 route.restore_checkpoint()
 print("CLIMB SWING ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
