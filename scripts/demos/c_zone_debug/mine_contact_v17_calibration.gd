extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for material:Vector2 in [Vector2(.45,.40),Vector2(.40,.40),Vector2(.43,.45)]:
  await setup_pair(830,1140,true);relay.iron_restitution=material;await wind();await approach_and_board(1)
  for i in 800:
   await frames(1)
   if relay.cart_landed or route.failure_time>0:break
  print("UNIFIED MATERIAL ",material," landed=",relay.cart_landed," car=",relay.positions[1]," hammer=",relay.last_hammer_contact," collision=",relay.last_collision)
 quit(1 if failed else 0)
