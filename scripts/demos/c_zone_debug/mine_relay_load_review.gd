extends "res://scripts/demos/c_zone_debug/mine_hoist_chain_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders;hoist=room.hoist
 # Start from the previously verified hoist output, then use only real
 # walking/pushing/pickup/throw input for the new reusable-load chain.
 hoist.location=hoist.Location.GROUND;hoist.task=hoist.Task.NONE
 hoist.stone_origin=Vector2(room.pressure.plate_rest.x,room.MID_Y+3);hoist.stone.position=hoist.stone_origin;hoist._register_weight()
 await warp(Vector2(room.STAIR_END+38,room.TRACK_Y));await frames(100)
 check(room.pressure.released,"existing stone must hold the released clamp")
 Input.action_press("interact");Input.action_press("move_right");await frames(420)
 Input.action_release("move_right");await frames(45)
 Input.action_release("interact");release();await frames(5)
 check(room.bays[0]>room.relay.STAGE_X,"real push must freely arrange the car beyond the old fixed station")
 await walk_to(hoist.stone_origin.x-40);await tap();await wait_task(hoist.Task.CARRY)
 check(hoist.attached,"stone must be recovered from the original pressure plate")
 await walk_to(room.bays[0]-65);await tap();await wait_task(hoist.Task.NONE)
 await frames(65)
 check(hoist.location==hoist.Location.CART and not hoist.attached,"existing heavy-item throw must load the actual cart")
 check(not room.pressure.load_active,"recovering the same rock must release the old pressure plate")
 check(room.relay.stone_loaded(),"the real visible cart load must contribute mass")
 var stone:Vector2=hoist.stone_origin
 var deck:Vector2=room.relay.stone_seat()
 check(stone.distance_to(deck)<.1,"load must settle inside the cart, not float outside")
 # The loaded tub is a real obstacle. Step into it, then dismount on the
 # other side using fresh jump input; never walk through the car body.
 Input.action_press("move_right");Input.action_press("jump")
 for i in 85:
  await frames(1)
  if room.relay.rider==0:break
 release();await frames(2)
 check(room.relay.rider==0,"loaded car must accept a real roof landing")
 Input.action_press("move_right");Input.action_press("jump");await frames(40);release()
 check(route.feet().x>room.bays[0]+45,"fresh jump must leave the parked second cart")
 await walk_to(room.relay.LEVER.x-28);await frames(5)
 check(room.relay.checkpoint_active and room.relay.checkpoint_load,"local retry must preserve the loaded setup")
 route.fail();route.restore_checkpoint();await frames(25)
 check(hoist.location==hoist.Location.CART and room.relay.stone_loaded(),"retry cannot lose or duplicate the cart's ballast")
 check(level.player.is_on_floor() and route.failure_time==0,"local retry must return to a safe crank-side floor")
 var out:=FileAccess.open("res://artifacts/mine-relay-v1/load-review.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"passed":not failed,"stone":str(hoist.stone_origin),"cart":str(room.relay.cart_at(0)),"throws":hoist.throws},"  "))
 print("MINE RELAY LOAD ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
