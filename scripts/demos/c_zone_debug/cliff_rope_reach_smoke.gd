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
 var rope=route.swing_rope
 for offset in [12.0,28.0,44.0]:
  for hold in [3,45]:
   route.restore_checkpoint()
   var x:float=rope.anchor().x+offset
   var y:float=route.Geometry.surface_y(route.ledges[0],x)
   level.player.position=Vector2(x-13,y-55)
   level.player.velocity=Vector2.ZERO
   route.fall_origin=y
   route.last_step=0
   await frames(20)
   var before:int=rope.catches
   Input.action_press("jump")
   for i in 45:
    if i==hold:Input.action_release("jump")
    await frames(1)
    if rope.catches>before:break
   Input.action_release("jump")
   print("GRAB offset=",offset," hold=",hold," caught=",rope.catches>before," grip=",rope.grip)
   check(rope.catches>before,"near jump grab "+str(offset)+"/"+str(hold))
 # A fresh midair jump intent can catch a lower part, without last_step==0.
 for height in [180.0,270.0]:
  route.restore_checkpoint()
  await frames(20)
  var contact:Vector2=rope._sample_fiber(height)
  level.player.position=contact+Vector2(18,61)-Vector2(13,54)
  level.player.velocity=Vector2(0,25)
  route.fall_origin=route.feet().y
  route.last_step=1
  await frames(1)
  var before:int=rope.catches
  Input.action_press("jump")
  await frames(3)
  Input.action_release("jump")
  print("LOWER GRAB ",height," caught=",rope.catches>before," grip=",rope.grip)
  check(rope.catches>before,"lower strand catch "+str(height))
 route.restore_checkpoint()
 await frames(20)
 var far:Vector2=rope._sample_fiber(220)
 level.player.position=far+Vector2(110,61)-Vector2(13,54)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=route.feet().y
 await frames(1)
 var before:int=rope.catches
 Input.action_press("jump")
 await frames(12)
 Input.action_release("jump")
 check(rope.catches==before,"no distant magnetic catch")
 print("REACH MATRIX ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
