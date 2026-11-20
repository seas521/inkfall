extends "res://scripts/demos/c_zone_debug/mine_hoist_chain_review.gd"
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90)
 level=main.river;route=level.bridge_to_c
 room=route.mine_trial.gap.art.pair_room;control=room.ladders;hoist=room.hoist
 # Only the initial QA approach is warped. The pickup, loaded walk,
 # grounded putdown and dust use normal player input and presentation.
 var x:float=hoist.stone_origin.x-40
 await warp(Vector2(x,room.lower_floor_y(x)))
 await tap();await wait_task(hoist.Task.CARRY)
 await walk_to(hoist.stone_home.x+55)
 await tap();await wait_task(hoist.Task.NONE)
 await shot("08-visible-ground-contact")
 var bottom:float=hoist.stone_origin.y+hoist.STONE_BOTTOM
 check(absf(bottom-hoist._contact_floor(hoist.stone_origin))<3,"visible stone bottom must contact the physical lower terrain")
 check(saw_ground_dust,"the real landing must produce dust")
 print("MINE HOIST CONTACT CAPTURE ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
