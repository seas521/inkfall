extends SceneTree
var level
var route
var trial
var escape
var failed:=false
var trace:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,label:String)->void:
 print(label,": ",ok)
 if not ok:failed=true;quit(1)
func place(x:float,y:float)->void:
 level.player.position=Vector2(x-13,y-55);level.player.velocity=Vector2.ZERO
 route.fall_origin=y
 await frames(15)
func lever()->void:
 Input.action_press("interact")
 for i in 240:
  await frames(1)
  if trial.launched and trial.operation=="":break
 Input.action_release("interact")
func snap(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-escape-v1/"+name+".png")
func run()->void:
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_root_cliff_test();route=level.bridge_to_c
 route.checkpoint_step=3;route.restore_checkpoint();trial=route.mine_trial;escape=trial.escape
 await place(trial.GRIP_X,trial.ground(trial.GRIP_X))
 check(not route.shaft_preview and not route.shaft.visible,"old lift puzzle remains isolated")
 await lever()
 check(trial.launched,"rear lever stroke releases cart")
 # Missing the vehicle must have an immediate local consequence.
 var crushed:=false
 for i in 600:
  await frames(1)
  if route.failure_time>0:crushed=escape.crushed;break
 print("CRUSH TRACE feet=",route.feet()," floor=",trial.ground(route.feet().x)," age=",trial.impact_age," failure=",route.failure_time," cart=",trial.cart_x," fallorigin=",route.fall_origin)
 check(crushed,"missed boarding is crushed by bearing-roof collapse")
 await snap("01-missed-boarding")
 route.restore_checkpoint();await frames(12)
 check(not trial.broken and not trial.launched and not escape.saved,"retry restores wall and parked cart")
 check(absf(route.feet().x-trial.GRIP_X)<60,"retry is near release lever")
 await lever()
 check(trial.launched,"retry lever can be used directly from respawn")
 Input.action_press("move_right");Input.action_press("jump")
 var boarded:=false
 for i in 100:
  await frames(1)
  if escape.is_riding():boarded=true;break
 # Keep the original boarding input held: it must not push the rider out.
 await frames(45)
 check(absf(route.feet().x-trial.cart_x)<20,"held boarding input settles inside tub")
 Input.action_release("move_right");Input.action_release("jump")
 print("BOARD TRACE ",route.feet()," cart=",trial.cart_position()," launched_age=",escape.launch_age)
 check(boarded,"normal Space plus right boards cart without teleport")
 await snap("02-boarded")
 var onset:=false
 for i in 700:
  await frames(1)
  if trial.broken and not onset:
   onset=true;await snap("03-impact")
  if trial.broken and trial.impact_age>.65 and trial.impact_age<.69:await snap("04-roof-falling")
  if escape.stopped_once:break
 check(escape.stopped_once and trial.cart_speed==0 and escape.chock_present,"stone chock stops vehicle before rail break")
 check(route.failure_time==0 and escape.saved,"rider escapes collapse and gains checkpoint")
 check(absf(route.feet().x-trial.cart_x)<45,"actor stays on moving cart")
 check(trial.cart_x<escape.EDGE_X-60,"stopped cart remains safely behind edge")
 await snap("05-stone-stop")
 # A fresh jump must dismount even after the full escape ride.
 Input.action_press("move_right");Input.action_press("jump")
 var reseated:=false;var left_tub:=false
 for i in 45:
  await frames(1)
  if level.player.velocity.y< -100:left_tub=true
  if left_tub and level.actor.pose.action==&"mine_cart_ride":reseated=true
 Input.action_release("jump");Input.action_release("move_right")
 check(left_tub and not reseated and route.feet().x>trial.cart_x+70,"front boarding can jump out after escape")
 # The new chock is now a physical prerequisite, not an invisible park clamp.
 check(not trial.escape.try_recover(),"stone must be carried aside before cart recovery")
 route.fail();route.restore_checkpoint();await frames(6)
 check(trial.broken and escape.saved and not escape.falling,"later death preserves the completed mine escape")
 check(not trial.gap.coast,"cart stays at rest until player charges it uphill")
 check(trial.gap.RAIL_END>escape.EDGE_X+50,"rail projects over actual cliff")
 print("MINE CART ESCAPE ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
