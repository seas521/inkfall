extends SceneTree
var level
var route
var trial
var escape
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,label:String)->bool:
 print(label,": ",ok)
 if not ok:quit(1)
 return ok
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 var results:Array=[]
 for direction:float in [-1,1,-1,1]:
  level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;escape=trial.escape
  level.player.position=escape.cart_position()+Vector2(-22,-102)
  level.player.velocity=Vector2.ZERO;route.fall_origin=route.feet().y
  await frames(25)
  if not check(escape.is_riding(),"seated before jump"):return
  var start:Vector2=route.feet()
  var move:String="move_right" if direction>0 else "move_left"
  Input.action_press(move);Input.action_press("jump")
  var rose:=false;var cancelled_pose:=false;var returned:=false;var clearance:=0.0
  for i in 45:
   await frames(1)
   if level.jump_windup_left>0 and level.actor.pose.action!=&"mine_cart_ride":cancelled_pose=true
   if level.player.velocity.y< -100:rose=true
   if rose:
    clearance=maxf(clearance,(route.feet().x-start.x)*direction)
    if level.actor.pose.action==&"mine_cart_ride":returned=true
  Input.action_release(move);Input.action_release("jump")
  results.append({"direction":direction,"clearance":clearance})
  if not check(rose and cancelled_pose and not returned and clearance>60,"jump leaves parked cart without reseating"):return
 # Check continuous motion through cable release and floor contact.
 var lamp=preload("res://scripts/chapters/mine_pendant.gd").new();root.add_child(lamp)
 lamp.position=Vector2(0,0);lamp.phase=.8;lamp.update_swing(.4)
 var last:float=lamp.swing.rotation;var max_step:=0.0
 for i in 241:
  lamp.set_failure(float(i)/120,210)
  var angle:float=lamp.swing.rotation
  max_step=maxf(max_step,absf(angle-last));last=angle
 if not check(max_step<.06,"lamp releases and settles without angular snapping"):return
 print("EXIT LAMPS PASS ",JSON.stringify(results)," lamp max angle step ",max_step)
 quit()
