extends SceneTree
var level
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
 level.debug_enter_rope_ladder()
 level.scene1.cut=level.scene1.Cut.DONE
 level.scene1.intro_time=99
 var ladder=level.rope_ladder
 var top:Vector2=ladder.anchor()
 level.player.position=Vector2(top.x-18-13,level.scene1.ground_top(top.x-18)-54)
 level.player.velocity=Vector2.ZERO
 await frames(12)
 Input.action_press("climb_down")
 for i in 650:
  await frames(1)
  if ladder.feet().y>top.y+310:break
 Input.action_release("climb_down")
 await frames(3)
 Input.action_press("move_left")
 Input.action_press("jump")
 await frames(2)
 Input.action_release("jump")
 for i in 360:
  if i==25:Input.action_release("move_left")
  await frames(1)
  if i%60==0:print("HANDOFF ",i," feet=",ladder.feet()," ladder=",ladder.mode," bridge_dead=",level.log_bridge.failure_time," mine=",level.bridge_to_c.active," mine_dead=",level.bridge_to_c.failure_time)
 check(level.log_bridge.deaths==1,"one death for one middle-ladder fall")
 check(level.log_bridge.failure_time==0 and level.bridge_to_c.failure_time==0 and level.bridge_to_c.respawn_reveal==0,"both death timelines finish")
 check(not level.bridge_to_c.active and not ladder.active(),"upper checkpoint owns controls after respawn")
 check(level.player.is_on_floor() and absf(ladder.feet().y-top.y)<12,"respawn returns to solid upper cliff")
 check(level.iris==null or not level.iris.rect.visible,"death iris does not keep cycling")
 Input.action_press("climb_down")
 await frames(115)
 Input.action_release("climb_down")
 check(ladder.active(),"player can descend again after respawn")
 # Reverse journey: lower platform is the last reached safe endpoint.
 ladder.stop()
 level.enter_root_cliff_test()
 await frames(15)
 ladder.catch_from_bank()
 await frames(55)
 Input.action_press("climb_up")
 for i in 1200:
  await frames(1)
  if ladder.feet().y<top.y+310:break
 Input.action_release("climb_up")
 await frames(3)
 Input.action_press("move_left")
 Input.action_press("jump")
 await frames(2)
 Input.action_release("jump")
 for i in 360:
  if i==25:Input.action_release("move_left")
  await frames(1)
 var mine=level.bridge_to_c
 print("REVERSE RESPAWN feet=",ladder.feet()," logdeath=",level.log_bridge.failure_time," mine=",mine.active)
 check(level.log_bridge.failure_time==0 and mine.failure_time==0,"reverse journey death finishes")
 check(level.player.is_on_floor() and absf(ladder.feet().y-mine.Geometry.surface_y(mine.landing,ladder.feet().x))<5,"reverse journey returns to actual short platform")
 check(level.log_bridge.left_bank_reached,"lower checkpoint survives incomplete upward climb")
 ladder.catch_from_bank()
 await frames(55)
 var returned:int=ladder.returned_top
 Input.action_press("climb_up")
 for i in 1600:
  await frames(1)
  if ladder.returned_top>returned:break
 Input.action_release("climb_up")
 await frames(15)
 check(ladder.returned_top>returned and not level.log_bridge.left_bank_reached,"completed ascent restores upper checkpoint priority")
 print("LADDER RESPAWN ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
