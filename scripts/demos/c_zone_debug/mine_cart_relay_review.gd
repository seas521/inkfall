extends SceneTree
var level
var route
var room
var relay
var failed:=false
var cases:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(value:bool,message:String)->void:
 if not value:failed=true;push_error(message)
func release()->void:
 for a in ["move_left","move_right","jump","interact","climb_down","climb_up"]:Input.action_release(a)
func warp(at:Vector2)->void:
 release();level.player.position=at-Vector2(13,54);level.player.velocity=Vector2.ZERO
 level.jump_buffer=0;level.jump_windup_left=0;level.climb_time=-1
 level.scene1.low_stance.reset();route.fall_origin=at.y
 await frames(8)
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var dir:="res://artifacts/mine-relay-v1/game"
 DirAccess.make_dir_recursive_absolute(dir)
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func prepare(stone:bool)->void:
 release();route.failure_time=0;route.failure_airborne=false;route.respawn_reveal=0
 room.release_cart();room.ladders.cancel()
 room.bays=[relay.STAGE_X,relay.THIRD_X];room.carts_joined=true;relay.reset()
 var h=room.hoist
 h.task=h.Task.NONE;h.attached=false;h.location=h.Location.CART if stone else h.Location.GROUND
 h.stone_origin=relay.stone_seat() if stone else Vector2(room.pressure.plate_rest.x,room.MID_Y+3)
 h.stone.position=h.stone_origin;h._register_weight()
 await warp(Vector2(relay.LEVER.x-28,room.TRACK_Y))
 relay._save_attempt()
func wind(amount:float=1.0)->void:
 var sole_error:=0.0
 Input.action_press("interact")
 for i in 400:
  await frames(1)
  if relay.charge_owner and relay.lever_contact:sole_error=maxf(sole_error,absf(room.ladders.sole_world_y()-(room.TRACK_Y+4)))
  if relay.state==relay.State.COUNTDOWN or relay.charge>=amount:break
 Input.action_release("interact");await frames(2)
 check(relay.state in [relay.State.SWINGING,relay.State.ROLLING,relay.State.FLIGHT],"releasing F must immediately free the pendulum")
 check(relay.hand_gap<.1,"winding hand must hold the real crank")
 check(sole_error<.1,"winding effort must not lift or sink the planted shoes")
 print("RELAY CHARGED ",relay.charge," hand gap ",relay.hand_gap," sole error ",sole_error," bays=",room.bays," omega=",relay.angular_speed," blocked=",relay.haul_blocked," hit=",relay.last_hammer_contact)
func board(index:int)->void:
 var at:Vector2=relay.cart_at(index)
 await warp(Vector2(at.x-75,room.TRACK_Y))
 Input.action_press("jump");Input.action_press("move_right")
 for i in 80:
  await frames(1)
  if route.feet().x>at.x-4:Input.action_release("move_right")
  if relay.rider==index:break
 release();await frames(1)
 check(relay.rider==index,"real jump must board cart "+str(index)+" feet="+str(route.feet()))
func approach_and_board(index:int)->void:
 # No warp after winding: verify the real countdown allows the player
 # to travel from the crank to either alternative boarding position.
 var side:float=1 if index==0 else -1
 var target:float=relay.cart_at(index).x+side*75
 # A free-positioned donor can occupy the old fixed approach coordinate.
 # Jump from the actual clear gap instead of walking into its tub.
 if index==1 and absf(target-relay.cart_at(0).x)<48 and absf(route.feet().x-relay.cart_at(index).x)<110:
  target=route.feet().x
 for i in 220:
  var dx:float=target-route.feet().x
  if absf(dx)<4:break
  Input.action_press("move_right" if dx>0 else "move_left")
  Input.action_release("move_left" if dx>0 else "move_right")
  await frames(1)
 release();await frames(2)
 check(absf(route.feet().x-target)<9,"crank-side walk must reach the boarding approach before release")
 Input.action_press("move_left" if side>0 else "move_right");Input.action_press("jump")
 for i in 85:
  await frames(1)
  if (route.feet().x-relay.cart_at(index).x)*side<4:
   Input.action_release("move_left");Input.action_release("move_right")
  if relay.rider==index:break
 release();await frames(1)
 check(relay.rider==index,"the real release delay must permit boarding from the crank")
func finish_case(name:String,want_success:bool)->void:
 var captured:=false
 for i in 900:
  await frames(1)
  if relay.collision_done and not captured:
   captured=true;await shot(name+"-impact")
  if relay.airborne and relay.positions[1].x>2070 and relay.positions[1].x<2090:await shot(name+"-flight")
  if relay.state in [relay.State.LANDED,relay.State.FAILED] or route.failure_time>0:break
 var success:bool=relay.state==relay.State.LANDED
 check(success==want_success,name+" unexpected outcome state="+str(relay.state)+" position="+str(relay.positions[1]))
 check(relay.last_collision.get("momentum_error",INF)<.001,name+" must conserve collision momentum")
 var result:Dictionary={"name":name,"success":success,"state":relay.state,"position":str(relay.positions[1]),"collision":relay.last_collision.duplicate(),"rider":relay.rider,"landing_speed":relay.landing_speed}
 cases.append(result);print("RELAY CASE ",result)
 await shot(name+"-result")
func run()->void:
 if DisplayServer.get_name()=="headless":
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
  await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 else:
  var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
  await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await prepare(true);await shot("00-winch-ready");await wind();await shot("01-hammer-raised");await approach_and_board(1)
 await finish_case("02-stone",true)
 await prepare(false);await wind();await board(1);await finish_case("03-empty",false)
 var home:Vector2=relay.restore_attempt()
 check(relay.state==relay.State.READY and relay.staged() and relay.rider<0,"failed launch must restore a playable local attempt")
 check(level.player.collision_mask==43,"retry must restore player collisions")
 await prepare(true);await wind(.68);await board(1);await finish_case("04-undercharged",false)
 await prepare(false);await wind();await approach_and_board(0)
 for i in 500:
  await frames(1)
  if relay.collision_done:break
 check(relay.collision_done and relay.rider==0,"reaction route must reach impact seated in second cart")
 Input.action_press("move_right");Input.action_press("jump")
 for i in 75:
  await frames(1)
  if relay.rider==1:break
 release()
 check(relay.rider==1,"a timely real jump must transfer from second to third cart")
 await finish_case("05-player-transfer",true)
 await prepare(true);await wind(.23);await board(1);await finish_case("07-weak-roll-back",false)
 check(relay.rolling_back,"very weak launch must roll down the actual grade")
 await frames(120)
 Input.action_press("jump");Input.action_press("move_left");await frames(40);release()
 check(relay.rider<0,"a stalled car must still allow dismounting")
 await warp(Vector2(relay.LEVER.x-28,room.TRACK_Y))
 Input.action_press("interact");await frames(2);Input.action_release("interact")
 check(relay.state==relay.State.READY and relay.staged() and relay.stone_loaded(),"real F reset must recover both cars and the original ballast")
 await prepare(false);await wind()
 for i in 700:
  await frames(1)
  if relay.state in [relay.State.LANDED,relay.State.FAILED]:break
 await frames(230)
 check(route.failure_time==0,"an unattended cart must not magically kill a safely grounded player")
 if relay.rider>=0:
  Input.action_press("jump");Input.action_press("move_left");await frames(40);release()
 await warp(Vector2(relay.LEVER.x-28,room.TRACK_Y))
 Input.action_press("interact");await frames(2);Input.action_release("interact")
 check(relay.state==relay.State.READY and relay.staged(),"missed boarding must remain recoverable through the crank's local retry")
 # An unweighted walking jump cannot cross the physical takeoff gap.
 await prepare(false);await warp(Vector2(1730,room.TRACK_Y))
 Input.action_press("move_right");Input.action_press("jump");await frames(65);release()
 check(route.feet().x<relay.EXIT_X,"player must not bypass the mine carts with a normal jump")
 var dir:="res://artifacts/mine-relay-v1";DirAccess.make_dir_recursive_absolute(dir)
 var out:=FileAccess.open(dir+"/review.json",FileAccess.WRITE);out.store_string(JSON.stringify({"passed":not failed,"cases":cases},"  "))
 print("MINE CART RELAY ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
