extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
var results:Array=[]
func empty_attempt(label:String,trigger:String)->void:
 await setup_pair(830,1140,false);await wind();await approach_and_board(1)
 var pressed:=false;var released_seat:=false;var airborne_seen:=false
 for i in 850:
  await frames(1)
  airborne_seen=airborne_seen or relay.airborne
  var p:Vector2=relay.cart_at(1)
  var at_trigger:=false
  match trigger:
   "ramp":at_trigger=not relay.airborne and p.x>relay.RAMP_START+20
   "takeoff":at_trigger=relay.airborne
   "apex":at_trigger=relay.airborne and relay.flight_velocity.y> -10
   "near-bank":at_trigger=relay.airborne and p.x>relay.EXIT_X-200
   "spam":at_trigger=relay.airborne and i%4==0
  if at_trigger and (not pressed or trigger=="spam"):
   Input.action_press("jump");Input.action_press("move_right");pressed=true
  else:Input.action_release("jump")
  if pressed and relay.rider<0 and route.failure_time<=0:released_seat=true
  if route.failure_time>0 or relay.cart_landed:break
 release()
 check(pressed,label+" must exercise actual jump input")
 check(airborne_seen,label+" must exercise real unsupported flight")
 check(not released_seat,label+" must not grant another takeoff during flight")
 check(not relay.cart_landed and not route.in_c_zone,label+" must not reach exit without ballast")
 results.append({"case":label,"pressed":pressed,"seat_released":released_seat,"failed":route.failure_time>0,"cart":str(relay.cart_at(1))})
 print("AIR JUMP ",results[-1])
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 # Holding a forbidden air-jump must not auto-fire when the car lands;
 # a fresh press after landing restores an ordinary dismount.
 await setup_pair(830,1140,true);await wind();await approach_and_board(1)
 for i in 600:
  await frames(1)
  if relay.airborne:break
 check(relay.airborne,"loaded case must enter real flight")
 Input.action_press("jump")
 for i in 400:
  await frames(1)
  if relay.cart_landed or route.failure_time>0:break
 await frames(3)
 check(relay.cart_landed and relay.rider==1,"blocked air input must not be buffered into an automatic landing jump")
 Input.action_release("jump");await frames(2)
 Input.action_press("jump");Input.action_press("move_right");await frames(4);release()
 check(relay.rider<0 and route.failure_time==0,"fresh landing jump must remain available")
 for kind in ["ramp","takeoff","apex","near-bank","spam"]:
  await empty_attempt(kind,kind)
 # A parked car on the ramp still permits a normal dismount.
 await setup_pair(830,1730,false)
 relay._board(1);await frames(2)
 Input.action_press("jump");Input.action_press("move_left");await frames(3);release()
 check(relay.rider<0,"stationary ramp cart must still allow jumping out")
 var out:=FileAccess.open("res://artifacts/mine-relay-air-jump-v6/review.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"passed":not failed,"cases":results},"  "))
 print("MINE RELAY AIR JUMP ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
