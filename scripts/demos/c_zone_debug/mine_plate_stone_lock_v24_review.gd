extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 room.reset_puzzle()
 var hoist=room.hoist
 # The initial stone must remain recoverable for the hoist puzzle.
 await warp(hoist.stone_home+Vector2(-45,hoist.STONE_BOTTOM))
 Input.action_press("interact");await frames(3)
 check(hoist.task!=hoist.Task.NONE and not hoist.plate_locked(),"uncommitted lower-shaft stone must remain pickable")
 release();hoist.reset()
 # Move the one supported stone onto the pressure plate, then use actual
 # F presses from both sides before and after the restraint opens.
 hoist.stone_origin=Vector2(room.pressure.plate_rest.x,room.MID_Y-hoist.STONE_BOTTOM+1)
 hoist.stone.position=hoist.stone_origin;hoist._register_weight()
 await warp(Vector2(room.pressure.plate_rest.x-48,room.MID_Y))
 check(hoist.plate_locked(),"grounded pressure-plate load must be committed immediately")
 Input.action_press("interact");await frames(3);release();await frames(2)
 check(hoist.task==hoist.Task.NONE and not hoist.attached,"F must not start a pickup before unlock completes")
 await frames(100)
 check(room.restraint_cleared and room.pressure.released,"committed stone must still unlock the car")
 for side in [-1.0,1.0]:
  await warp(Vector2(room.pressure.plate_rest.x+side*48,room.MID_Y))
  var start:float=route.feet().x
  Input.action_press("interact");await frames(50);release();await frames(5)
  check(hoist.task==hoist.Task.NONE and not hoist.attached and hoist.location==hoist.Location.GROUND,"unlocked plate stone cannot be picked up from either side")
  check(absf(route.feet().x-start)<.5,"blocked pickup must not cause automatic approach movement")
  check(hoist.plate_locked() and room.pressure.load_active,"stone must remain seated on and pressing the pedal")
 relay._save_attempt();route.fail();route.restore_checkpoint();await frames(20)
 check(hoist.plate_locked() and not hoist.attached,"respawn must not make the committed plate load recoverable")
 room.reset_puzzle();await frames(3)
 check(not hoist.plate_locked() and hoist.stone_origin.distance_to(hoist.stone_home)<.1,"explicit puzzle reset restores the original movable stone")
 print("MINE PLATE STONE LOCK V24 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
