extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 # Actual held input, released while still moving; no preliminary braking.
 await setup_pair(830,1140,false)
 await warp(Vector2(776,room.TRACK_Y))
 Input.action_press("interact");Input.action_press("move_right");await frames(75)
 check(room.cart_gripped and room.cart_speed>10,"must be actively pushing before release")
 Input.action_release("interact");Input.action_release("move_right");await frames(2)
 var parked:float=room.bays[0];await frames(120)
 check(absf(room.bays[0]-parked)<.001,"released manually pushed cart must remain parked")
 # Park a manually handled car on the ramp, not only the flat floor.
 await setup_pair(830,1740,false)
 room.cart_gripped=true;room.cart_grip_index=1;room.cart_speed=45;relay.velocities[1]=45
 room.release_cart();parked=room.bays[1];await frames(120)
 check(absf(room.bays[1]-parked)<.001 and relay.velocities[1]==0,"manual placement on slope must not auto-slide")
 # A real swing must kill a grounded player standing in its path.
 await setup_pair(1100,1350,false)
 await warp(Vector2(740,room.TRACK_Y))
 relay.state=relay.State.SWINGING;relay.angle=-.60;relay.angular_speed=0
 for i in 150:
  await frames(1)
  if route.failure_time>0:break
 check(route.failure_time>0,"moving hammer must kill player in its actual sweep")
 # Restore then verify side clearance, idle safety, and fast swept contact.
 await setup_pair(1100,1350,false)
 await warp(Vector2(900,room.TRACK_Y))
 relay.angle=0;relay.angular_speed=2
 check(not relay._check_hammer_player(-.1,.1),"nearby player outside head sweep must remain safe")
 await warp(Vector2(740,room.TRACK_Y))
 relay.angular_speed=0
 check(not relay._check_hammer_player(0,0),"idle parked hammer must not kill on proximity")
 relay.angular_speed=5
 check(relay._check_hammer_player(-.22,.22),"fast head sweep must not tunnel through player")
 # Full relay impulse remains functional with manually parked cars.
 await setup_pair(830,1140,true);await wind();await approach_and_board(1)
 for i in 800:
  await frames(1)
  if relay.cart_landed or route.failure_time>0:break
 check(relay.cart_landed and route.failure_time==0,"hammer and cart impacts must still launch and land")
 print("MINE RELAY CONTACT V3 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
