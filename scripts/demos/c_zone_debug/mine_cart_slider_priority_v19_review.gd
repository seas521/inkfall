extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for index in 2:
  for side in [-1.0,1.0]:
   for direction in [-1.0,1.0]:
    await setup_pair(relay.LEVER.x if index==0 else 1500.,relay.LEVER.x if index==1 else 1500.,false)
    room.restraint_cleared=true
    await warp(Vector2(relay.LEVER.x+side*relay.SLIDER_STANCE_X,room.TRACK_Y))
    check(room.cart_grip_candidate(route.feet())==index,"overlapping cart must be reachable from either side")
    # Start without directional input: this is the ambiguous F press that
    # previously let the slider steal the interaction before cart control.
    Input.action_press("interact");await frames(3)
    check(room.cart_gripped and room.cart_grip_index==index,"F must select cart before overlapping slider")
    check(not relay.charge_owner,"slider must not acquire a reachable cart's F press")
    var start:float=room.bays[index]
    Input.action_press("move_left" if direction<0 else "move_right")
    await frames(80)
    check((room.bays[index]-start)*direction>12,"selected cart must actually push/pull free of the slider")
    check(not relay.charge_owner and absf(relay.slider_position)<.01,"cart movement must not drag slider")
    print("PRIORITY CASE ",index," side=",side," direction=",direction," moved=",room.bays[index]-start)
    release();await frames(3)
    check(not room.cart_gripped,"releasing F must release cart normally")
 # An unobstructed slider retains its normal interaction from either side.
 for side in [-1.0,1.0]:
  await setup_pair(1350,1550,false)
  await warp(Vector2(relay.LEVER.x+side*relay.SLIDER_STANCE_X,room.TRACK_Y))
  Input.action_press("interact");await frames(4)
  check(relay.charge_owner and not room.cart_gripped,"slider remains usable when no cart is reachable")
  release();await frames(3)
 print("MINE CART SLIDER PRIORITY V19 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
