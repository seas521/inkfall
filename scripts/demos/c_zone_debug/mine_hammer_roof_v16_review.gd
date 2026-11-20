extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(400,980,false);level.set_physics_process(false)
 for x in [920.,960.,980.,1000.,1020.]:
  room.bays=[400.,x];relay.reset();relay.angle=1.1;relay.angular_speed=0;relay.pendulum_live=true;relay.state=relay.State.SWINGING
  for i in 300:
   relay._integrate(1./120)
   if relay.angle<-.5 or not relay.last_hammer_contact.is_empty():break
  if x<=980:
   check(not relay.last_hammer_contact.is_empty(),"actual side or roof contact must produce impact feedback")
  else:
   check(relay.last_hammer_contact.is_empty() and absf(room.bays[1]-x)<.01,"a genuine clear miss must not remotely push a cart")
  if x==980:
   check(relay.last_hammer_contact.get("kind","")=="roof" and relay.angular_speed>0,"descending roof contact must recoil the head")
   check(absf(room.bays[1]-x)<.01,"roof normal load must compress suspension without teleporting the cart sideways")
  print("ROOF HIT ",x," -> ",room.bays[1]," contact=",relay.last_hammer_contact," omega=",relay.angular_speed)
 print("MINE HAMMER ROOF ","FAIL" if failed else "PASS");quit(1 if failed else 0)
