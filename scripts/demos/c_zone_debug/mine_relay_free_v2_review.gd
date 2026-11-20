extends "res://scripts/demos/c_zone_debug/mine_cart_relay_review.gd"
var v2_cases:Array=[]
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var dir:="res://artifacts/mine-relay-free-v2/game";DirAccess.make_dir_recursive_absolute(dir)
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func setup_pair(x0:float,x1:float,stone:bool=true)->void:
 release();route.failure_time=0;route.failure_airborne=false;route.respawn_reveal=0
 room.release_cart();room.ladders.cancel();room.bays=[x0,x1];room.cart_distance=0;relay.reset()
 var h=room.hoist;h.task=h.Task.NONE;h.attached=false;h.location=h.Location.CART if stone else h.Location.GROUND
 h.stone_origin=relay.stone_seat() if stone else Vector2(room.pressure.plate_rest.x,room.MID_Y+3)
 h.stone.position=h.stone_origin;h._register_weight()
 # Start at the actual left handle stance, outside the receiver's grip
 # zone. A nearer reachable cart now intentionally takes priority over F.
 await warp(Vector2(relay.LEVER.x-relay.SLIDER_STANCE_X,room.TRACK_Y));relay._save_attempt()
func shunt(index:int,direction:float,ticks:int)->void:
 var start:float=room.bays[index]
 var side:float=-1 if direction>0 else 1
 await warp(Vector2(start+side*54,relay.cart_at(index).y))
 Input.action_press("interact");Input.action_press("move_right" if direction>0 else "move_left")
 await frames(ticks)
 print("SHUNT ",{"index":index,"from":start,"to":room.bays[index],"grip":room.cart_gripped,"selected":room.cart_grip_index,"hoist_task":room.hoist.task,"feet":route.feet(),"rider":relay.rider,"state":relay.state})
 check(room.cart_gripped and room.cart_grip_index==index,"F+direction must grip the selected car in the current puzzle state")
 Input.action_release("move_left");Input.action_release("move_right");await frames(45)
 check(absf(room.cart_speed)<.1,"holding F without direction must brake smoothly")
 Input.action_release("interact");await frames(2)
 check((room.bays[index]-start)*direction>12,"selected cart must move without the old parking cap")
 var stopped:float=room.bays[index];await frames(30)
 if absf(relay.track_angle(stopped))<.0001:
  check(absf(room.bays[index]-stopped)<.1,"a braked cart on level track must retain its arranged position")
 else:
  check(absf(room.bays[index]-stopped)<.1,"manual slope placement must stay parked after releasing F")
func trial(name:String,x0:float,x1:float,want_success:bool,amount:float=1.0)->void:
 await setup_pair(x0,x1);await wind(amount);await board(1)
 var captured:=false;var contact_seen:=false
 for i in 1000:
  await frames(1)
  if relay.contact_age>=0:
   contact_seen=true
   check(absf(room.bays[1]-room.bays[0])>=relay.CART_GAP-.15,"buffer contact must remain nonpenetrating during the visual compression")
   if not captured:captured=true;await shot(name+"-contact")
  if relay.airborne and relay.positions[1].x>2090 and relay.positions[1].x<2110:await shot(name+"-flight")
  if relay.cart_landed or relay.rolling_back or route.failure_time>0 or relay.cart_lost[1]:break
 var success:bool=relay.cart_landed
 check(success==want_success,name+" outcome mismatch "+str(relay.positions[1])+" collision="+str(relay.last_collision))
 if want_success or not relay.last_collision.is_empty():
  check(contact_seen,"actual collision must include visible compression before rebound")
  check(relay.last_collision.get("momentum_error",INF)<.001,"cart contact impulse must conserve pair momentum")
 else:
  check(absf(room.bays[1]-x1)<.01,"a weak attempt that never reaches the receiver must leave it parked")
 var data:Dictionary={"name":name,"success":success,"contact":relay.last_collision.duplicate(),"hammer":relay.last_hammer_contact.duplicate(),"car":str(relay.positions[1])}
 v2_cases.append(data);print("FREE RELAY CASE ",data)
 await shot(name+"-result")
func run()->void:
 if DisplayServer.get_name()=="headless":
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
  await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 else:
  var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
  await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(808,1350)
 await shunt(0,1,100);check(room.bays[0]>850,"second car must push beyond old fixed station")
 await shunt(0,-1,90)
 await shunt(1,1,100);await shunt(1,-1,65)
 await shot("00-free-placement")
 await trial("01-good-a",830,1140,true)
 await trial("02-good-b",840,1180,true)
 await trial("03-default-third-bad",808,1350,false)
 await trial("04-weak-preserved",808,1140,false,.10)
 # Failed but recoverable cars remain where they physically stopped.
 relay._release_passenger();relay.air_active=false
 await warp(Vector2(relay.LEVER.x-28,room.TRACK_Y))
 await frames(200);relay.velocities=[0.,0.]
 var before:Array=room.bays.duplicate();var load:bool=relay.stone_loaded()
 await warp(Vector2(relay.LEVER.x-28,room.TRACK_Y))
 Input.action_press("interact");await frames(3)
 print("REARM ",{"feet":route.feet(),"state":relay.state,"owner":relay.charge_owner,"hoist":room.hoist.task,"rider":relay.rider,"before":before,"after":room.bays})
 check(relay.charge_owner,"F after a failed attempt must wind only the hammer")
 check(absf(room.bays[0]-before[0])<.1 and absf(room.bays[1]-before[1])<.1,"crank must preserve both actual cart positions, not respawn them")
 check(relay.stone_loaded()==load,"winding must preserve the current ballast")
 Input.action_release("interact");await frames(2)
 relay.charge_owner=false;relay.state=relay.State.FAILED;relay.angle=0;relay.angular_speed=0
 await shunt(0,-1,70);await shunt(1,1,70)
 # Missed hammer contact cannot accelerate a distant car by a docking flag.
 await setup_pair(1090,1140);await wind();await frames(300)
 check(relay.last_hammer_contact.is_empty(),"hammer must miss a car outside its actual sweep")
 check(absf(relay.velocities[0])<.1,"a miss cannot remotely launch a car")
 # Death/explicit R now restarts both cars at the fixed relay homes.
 await setup_pair(830,1150);route.fail();route.restore_checkpoint();await frames(20)
 check(absf(room.bays[0]-relay.STAGE_X)<.1 and absf(room.bays[1]-relay.THIRD_X)<.1,"checkpoint restore must return both cars to relay homes")
 var out:=FileAccess.open("res://artifacts/mine-relay-free-v2/review.json",FileAccess.WRITE);out.store_string(JSON.stringify({"passed":not failed,"cases":v2_cases},"  "))
 print("MINE RELAY FREE V2 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
