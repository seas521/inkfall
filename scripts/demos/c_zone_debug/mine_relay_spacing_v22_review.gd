extends "res://scripts/demos/c_zone_debug/mine_relay_v2_routes_review.gd"
func empty_route()->void:
 await setup_pair(830,1140,false);await wind();await approach_and_board(1)
 await await_landing("empty-donor-spacing")
 print("EMPTY RELAY spacing=",relay.strike_spacing," quality=",relay.contact_quality," collision=",relay.last_collision)
 check(not relay.stone_loaded(),"success must not require loading the donor")
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await empty_route()
 for item in [["close",830.,970.,1.28],["low",830.,1140.,.25],["wrong-left",1100.,1450.,1.28],["spaced",830.,1200.,1.28]]:
  await setup_pair(item[1],item[2],false)
  await warp(Vector2(item[2]+100,room.TRACK_Y))
  relay._board(1)
  relay.angle=-float(item[3]);relay.angular_speed=0;relay.pendulum_live=true;relay.state=relay.State.SWINGING
  for i in 1400:
   await frames(1)
   if relay.cart_landed or relay.cart_lost[1] or route.failure_time>0:break
  print("SPACING CASE ",item[0]," landed=",relay.cart_landed," spacing=",relay.strike_spacing," quality=",relay.contact_quality," pos=",relay.positions[1]," collision=",relay.last_collision)
  if item[0]!="spaced":check(not relay.cart_landed,"insufficient spacing, charge or wrong strike position must still fail: "+str(item[0]))
  else:check(relay.cart_landed,"sufficiently spaced empty cars must complete the relay")
 print("MINE RELAY SPACING V22 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
