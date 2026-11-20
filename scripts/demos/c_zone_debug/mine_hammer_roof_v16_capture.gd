extends "res://scripts/demos/c_zone_debug/mine_ramp_rollback_v16_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(400,980,false);await warp(Vector2(1180,room.TRACK_Y));await frames(30)
 relay.angle=1.1;relay.angular_speed=0;relay.pendulum_live=true;relay.state=relay.State.SWINGING
 await frames(1);await shot("03-right-drop")
 for i in 180:
  await frames(1)
  if relay.last_hammer_contact.get("kind","")=="roof":break
 check(relay.last_hammer_contact.get("kind","")=="roof","real downward swing must hit the cart roof")
 await shot("04-roof-contact")
 await frames(6);await shot("05-roof-response")
 print("MINE HAMMER ROOF VISUAL ","FAIL" if failed else "PASS");quit(1 if failed else 0)
