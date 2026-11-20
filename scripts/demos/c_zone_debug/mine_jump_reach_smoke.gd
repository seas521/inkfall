extends SceneTree
var level
var route
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate()
 root.add_child(level)
 await frames(8)
 level.enter_root_cliff_test()
 route=level.bridge_to_c
 route.checkpoint_step=0
 for scenario in [{"offset":-50.0,"run":false},{"offset":-35.0,"run":false},{"offset":-22.0,"run":false},{"offset":-50.0,"run":true},{"offset":-35.0,"run":true},{"offset":-22.0,"run":true}]:
  var start:float=scenario.offset
  for hold in [3,60]:
   route.restore_checkpoint()
   var tree=route.trees[1]
   var x:float=tree.branch.global_position.x+start
   var y:float=route.Geometry.surface_y({"top":tree.world_top()},x)
   level.player.position=Vector2(x-13-(45 if scenario.run else 0),y-55)
   level.player.velocity=Vector2.ZERO
   route.fall_origin=y
   route.last_step=1
   await frames(8)
   Input.action_press("move_right")
   if scenario.run:
    for i in 90:
     await frames(1)
     if route.feet().x>=x or route.failure_time>0:break
   Input.action_press("jump")
   var airborne:=false
   for i in 120:
    if i==hold:Input.action_release("jump")
    await frames(1)
    if not level.player.is_on_floor():airborne=true
    if route.failure_time>0 or (airborne and level.player.is_on_floor()):break
   Input.action_release("jump")
   Input.action_release("move_right")
   print("JUMP run=",scenario.run," start=",start," hold=",hold," feet=",route.feet()," drop=",route.feet().y-route.fall_origin," fail=",route.failure_time," doomed=",route.doomed_branch!=null," step=",route.last_step)
   if route.failure_time>0 or route.last_step!=2:failures.append(str(scenario)+"/"+str(hold))
 print("JUMP MATRIX ",failures)
 quit(0 if failures.is_empty() else 1)
