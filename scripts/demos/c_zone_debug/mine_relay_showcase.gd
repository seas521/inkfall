extends "res://scripts/demos/c_zone_debug/mine_cart_relay_review.gd"
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 relay.debug_prepare(true);await frames(30);await shot("10-final-ready")
 await wind();await shot("11-final-full-charge")
 await board(1)
 var impact_shot:=false;var flight_shot:=false
 for i in 800:
  await frames(1)
  if relay.collision_done and not impact_shot:
   impact_shot=true;await shot("12-final-collision")
  if relay.airborne and relay.positions[1].x>2080 and not flight_shot:
   flight_shot=true;await shot("13-final-flight")
  if relay.state==relay.State.LANDED:break
 check(relay.state==relay.State.LANDED,"showcase must reach the forest-side bank")
 await shot("14-final-landing");await frames(200)
 Input.action_press("jump");Input.action_press("move_right");await frames(40);release()
 Input.action_press("move_right")
 for i in 350:
  await frames(1)
  if route.in_c_zone:break
 release();await frames(110);await shot("15-final-valley")
 check(route.in_c_zone and level.player.is_on_floor(),"showcase must finish supported in the real C forest")
 print("MINE RELAY SHOWCASE ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
