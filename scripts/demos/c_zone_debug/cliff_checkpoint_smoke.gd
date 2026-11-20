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
 for saved in [-1,0]:
  for target in [2,3]:
   route.checkpoint_step=saved
   route.restore_checkpoint()
   var x:float=route.ledges[target].top[0].x+5 if target==2 else -3010.0
   var y:float=route.Geometry.surface_y(route.ledges[target],x)
   level.player.position=Vector2(x-13,y-54-110)
   level.player.velocity=Vector2(0,600)
   route.fall_origin=y-450
   route.was_grounded=false
   for i in 90:
    await frames(1)
    if route.failure_time>0:break
   if route.failure_time<=0 or route.checkpoint_step!=saved:failures.append("dead contact rewrote "+str(saved)+" -> "+str(target))
   for i in 180:
    await frames(1)
    if route.failure_time<=0:break
   if route.checkpoint_step!=saved or route.last_step!=saved:failures.append("wrong respawn "+str(saved))
   print("RESPAWN saved=",saved," hit=",target," actual=",route.checkpoint_step," feet=",route.feet())
 # A brief/nonsequential contact must not unlock a lower save point either.
 route.checkpoint_step=-1
 route.restore_checkpoint()
 var x:float=route.ledges[2].top[0].x+50
 var y:float=route.Geometry.surface_y(route.ledges[2],x)
 level.player.position=Vector2(x-13,y-55)
 level.player.velocity=Vector2.ZERO
 route.fall_origin=y
 await frames(30)
 if route.checkpoint_step!=-1:failures.append("skipped route credited")
 print("CHECKPOINT ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
