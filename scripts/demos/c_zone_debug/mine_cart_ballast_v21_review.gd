extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-cart-ballast-v21/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 room.reset_puzzle();await setup_pair(523,1350,false)
 room.hoist.stone_origin=room.hoist.stone_home;room.hoist.stone.position=room.hoist.stone_home;room.hoist._register_weight()
 await warp(Vector2(room.pressure.plate_rest.x,room.MID_Y))
 for i in 120:
  await frames(1)
  if room.pressure.released:break
 check(room.pressure.released and not room.restraint_cleared,"player must hold the lift without permanently unlocking it")
 check(absf(room.bays[0]-523)<.01,"unlock must not require pushing out of the frame")
 await warp(Vector2(70,room.MID_Y));await frames(150)
 check(not room.pressure.load_active and room.pressure.depression<.01,"unloaded pedal still returns normally")
 check(not room.pressure.released and room.restraint_locked(),"walking off without a stone must relock the parked car")
 check(room.pressure.rise==0,"player-only preview must visibly close after leaving")
 var hoist=room.hoist
 hoist.stone_origin=Vector2(room.pressure.plate_rest.x,room.MID_Y-hoist.STONE_BOTTOM+1)
 hoist.stone.position=hoist.stone_origin;hoist._register_weight();await frames(100)
 check(room.restraint_cleared and room.pressure.released,"grounded stone must replace player and latch release")
 # Drop the real load through the rim and let the flight state settle it.
 hoist.location=hoist.Location.AIR;hoist.task=hoist.Task.NONE;hoist.attached=false
 hoist.place_in_cart=true;hoist.inside_cart=false
 hoist.stone_origin=relay.cart_at(0)+Vector2(7,-100);hoist.stone_velocity=Vector2.ZERO
 await frames(60)
 check(hoist.location==hoist.Location.CART and relay.stone_loaded(),"falling load must settle into cart")
 check(hoist.stone_origin.distance_to(relay.stone_seat())<.01,"visible ballast follows its permanent seat")
 check(hoist.stone_origin.y-hoist.STONE_CENTER*2<relay.cart_at(0).y-52-12,"stone must visibly protrude above tub rim")
 for side in [-1.0,1.0]:
  await warp(relay.cart_at(0)+Vector2(side*54,0))
  Input.action_press("interact");await frames(45)
  check(room.cart_gripped and room.cart_grip_index==0,"stationary F must grip loaded cart")
  check(hoist.task==hoist.Task.NONE and not hoist.attached,"loaded stone must never start automatic pickup approach")
  var start:float=room.bays[0]
  var direction:float=1.0 if side<0 else -1.0
  Input.action_press("move_right" if direction>0 else "move_left");await frames(65)
  check((room.bays[0]-start)*direction>12,"loaded cart must remain controllable in either direction")
  check(hoist.location==hoist.Location.CART,"push/pull must not extract or lose committed ballast")
  release();await frames(25)
  var stopped:float=route.feet().x
  await frames(35)
  check(absf(route.feet().x-stopped)<.2 and hoist.task==hoist.Task.NONE,"release must not leave automatic walking active")
  check(not room.restraint_locked(),"returning a loaded cart under its original frame must not relock")
 await shot("01-stone-above-rim-unlocked")
 room.reset_puzzle();await frames(3)
 check(not room.restraint_cleared and not room.pressure.released,"explicit puzzle reset restores the initial locked state")
 print("MINE CART BALLAST V21 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
