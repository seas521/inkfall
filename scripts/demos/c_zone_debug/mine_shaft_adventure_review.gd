extends SceneTree
var level
var route
var shaft
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,label:String)->void:
 print(label,": ",ok," feet=",route.feet())
 if not ok:quit(1)
func walk(x:float)->void:
 var dir:String="move_right" if route.feet().x<x else "move_left"
 Input.action_press(dir)
 for i in 200:
  await frames(1)
  if absf(route.feet().x-x)<3:break
 Input.action_release(dir);await frames(3)
func jump_to(x:float,y:float)->void:
 var dir:String="move_right" if route.feet().x<x else "move_left"
 Input.action_press(dir);Input.action_press("jump")
 var airborne:=false
 for i in 150:
  await frames(1)
  if not level.player.is_on_floor():airborne=true
  if absf(route.feet().x-x)<3:Input.action_release(dir)
  if airborne and level.player.is_on_floor():break
 Input.action_release(dir);Input.action_release("jump");await frames(2)
 check(absf(route.feet().y-y)<25 and route.failure_time==0,"land on intended descending ledge")
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(8);level.enter_mine_shaft_test();route=level.bridge_to_c;shaft=route.shaft
 shaft.jammed=false;shaft.pin_locked=true;shaft.routed=true;shaft.cart_on_cage=true
 shaft.arrived=true;shaft.cage_y=shaft.EXIT_Y;route.mine_trial.cart_x=shaft.CAGE_X
 level.player.position=Vector2(-988-13,shaft.EXIT_Y-55);level.player.velocity=Vector2.ZERO
 shaft.fall_y=shaft.EXIT_Y;route.fall_origin=shaft.EXIT_Y
 await frames(8)
 await walk(-832)
 check(shaft.checkpoint==3,"safe exit saves before adventure")
 route.fail();route.restore_checkpoint();await frames(5)
 check(shaft.arrived and shaft.checkpoint==3,"action retry restores lower exit instead of replaying puzzle")
 await walk(-832)
 await jump_to(-730,-425)
 await walk(-690)
 await jump_to(-580,-335)
 await walk(-578)
 await jump_to(-635,-238)
 await walk(-630)
 await jump_to(-495,-154)
 await walk(-500)
 await jump_to(-565,-57)
 await walk(-556)
 await jump_to(-435,25)
 await walk(-438)
 await jump_to(-485,123)
 await walk(-480)
 await jump_to(-395,205)
 await walk(-287)
 await jump_to(-205,303)
 await walk(-185)
 check(route.in_c_zone,"exit joins C at original left slope")
 check(route.feet().distance_to(Vector2(-185,309))<40,"handoff preserves world position")
 print("MINE ADVENTURE PASS")
 quit()
