extends SceneTree
var level
var route
var trial
var gap
var escape
var failed:=false
var rows:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,label:String)->bool:
 if not ok:
  failed=true;push_error(label)
 return ok
func capture(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var img=root.get_texture().get_image();img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
 img.save_png("res://artifacts/mine-cart-interaction-v3/"+label+".png")
func keys_up()->void:
 for key in ["interact","jump","move_left","move_right"]:Input.action_release(key)
func setup(x:float,coast:bool=false)->void:
 keys_up();gap.platform_reached=false;gap.bank_reached=false;gap.restore()
 gap.rock_state=4;gap.rock_cleared=true;gap.rock_visible=false;escape.remove_stop_rock()
 # Settle a repositioned AnimatableBody before placing a test passenger.
 # Otherwise the fixture itself sweeps the capsule tens of pixels away.
 level.player.collision_mask=0
 level.player.position=Vector2(x+200,trial.ground(x)-140)
 trial.cart_x=x;trial.cart_speed=0;trial.operation="";gap.coast=coast;trial.sync_visual(0)
 await frames(3)
 level.player.collision_mask=route.PLAYER_COLLISION_MASK
 escape.riding=false;escape.ride_age=0
 level.jump_windup_left=0;level.jump_buffer=0;level.climb_time=-1
 level.player.velocity=Vector2.ZERO
 route.failure_time=0;route.failure_airborne=false;route.fall_origin=trial.ground(x)
func seated_jump(x:float,direction:float,tap:bool)->void:
 await setup(x)
 level.player.position=escape.cart_position()+Vector2(-22,-102)
 await frames(35);gap.coast=true
 if not check(escape.is_riding(),"setup must seat on cart"):return
 if x==-1080 and direction>0 and tap:await capture("01-stopped-car-before-jump")
 var key:String="move_left" if direction<0 else "move_right"
 Input.action_press(key);Input.action_press("jump")
 var rise:=false;var reseated:=false;var max_height:=0.;var clearance:=0.
 for i in 46:
  await frames(1)
  if tap and i==2:Input.action_release("jump")
  if x==-1080 and direction>0 and tap and i==16:await capture("02-stopped-car-jump-clear")
  if level.player.velocity.y< -100:rise=true
  if rise:
   max_height=maxf(max_height,escape.cart_position().y-47-route.feet().y)
   clearance=maxf(clearance,(route.feet().x-trial.cart_x)*direction)
   if level.actor.pose.action==&"mine_cart_ride":reseated=true
 keys_up()
 var row={"kind":"jump","x":x,"direction":direction,"tap":tap,"rose":rise,"reseated":reseated,"height":max_height,"clearance":clearance}
 rows.append(row);print(JSON.stringify(row))
 check(rise and not reseated and clearance>50,"jump out of a coasting/stopped cart must clear its side: "+JSON.stringify(row))
func vertical_hop(offset:float=-9)->void:
 await setup(-1080)
 level.player.position=escape.cart_position()+Vector2(-22,-102);await frames(35);gap.coast=true
 level.player.position.x=trial.cart_x+offset-13;level.player.velocity=Vector2.ZERO
 Input.action_press("jump");await frames(3);Input.action_release("jump")
 var rose:=false;var seated_again:=false
 for i in 70:
  await frames(1)
  if level.player.velocity.y< -100:rose=true
  if rose and level.actor.pose.action==&"mine_cart_ride":seated_again=true
 check(rose and not seated_again,"a vertical hop must not trigger seat-centering suction on roof contact")
 Input.action_press("move_right");await frames(60);keys_up()
 check(route.feet().x-trial.cart_x>50,"standing on the roof after a hop must keep movement control")
 rows.append({"kind":"vertical hop then walk out","offset":offset,"rose":rose,"reseated":seated_again})
func brake(x:float,speed:float,side:float,axis:float=0)->void:
 await setup(x)
 var px:float=x+side*54
 level.player.position=Vector2(px-13,trial.ground(px)-55);await frames(20)
 check(absf(route.feet().x-trial.cart_x-side*54)<1,"brake fixture must start at actual hand reach")
 trial.cart_speed=speed;gap.coast=true
 Input.action_press("interact")
 if axis<0:Input.action_press("move_left")
 if axis>0:Input.action_press("move_right")
 var largest_step:=0.;var largest_speed:=absf(speed);var old_x:float=trial.cart_x
 var last_tick:int=Engine.get_physics_frames()
 var active:=false;var reversed_fast:=false
 for i in 50:
  await frames(1)
  var ticks:int=maxi(1,Engine.get_physics_frames()-last_tick)
  largest_step=maxf(largest_step,absf(trial.cart_x-old_x)/float(ticks));old_x=trial.cart_x;last_tick=Engine.get_physics_frames()
  largest_speed=maxf(largest_speed,absf(trial.cart_speed))
  if trial.operation=="recover":active=true
  if x==-1060 and side>0 and i in [2,14,36]:await capture("brake-%02d"%i)
  if trial.cart_speed*speed<0 and absf(trial.cart_speed)>66:reversed_fast=true
 keys_up()
 var row={"kind":"brake","x":x,"speed":speed,"side":side,"axis":axis,"gripped":active,"max_step":largest_step,"max_speed":largest_speed,"end_speed":trial.cart_speed,"fast_reverse":reversed_fast,"falling":escape.falling}
 rows.append(row);print(JSON.stringify(row))
 check(active,"F must catch a reachable cart")
 check(largest_step<absf(speed)/60+1.5 and largest_speed<absf(speed)+20 and not reversed_fast,"catching F must not teleport or manufacture reverse velocity: "+JSON.stringify(row))
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;gap=trial.gap;escape=trial.escape
 for x:float in [-1140,-1080,-1035,-985]:
  for direction:float in [-1,1]:
   for tap:bool in [true,false]:await seated_jump(x,direction,tap)
 for x:float in [-1130,-1060,-1020]:
  for side:float in [-1,1]:await brake(x,140,side)
 for offset:float in [-9,27,39]:await vertical_hop(offset)
 await brake(-1035,180,1,-1)
 await brake(-1320,-80,-1)
 await brake(-1320,-80,1,1)
 var f:=FileAccess.open("res://artifacts/mine-cart-interaction-v3/matrix.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
 print("CART INTERACTION MATRIX ","FAIL" if failed else "PASS"," cases ",rows.size())
 quit(1 if failed else 0)
