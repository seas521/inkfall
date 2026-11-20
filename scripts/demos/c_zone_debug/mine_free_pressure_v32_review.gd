extends "res://scripts/demos/c_zone_debug/mine_basket_free_throw_v32_review.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders;hoist=room.hoist
 for attempt in [[-170.,1.,false],[-70.,1.,true],[70.,-1.,true],[170.,-1.,false]]:
  room.restraint_cleared=false;room.pressure.reset();hoist.reset()
  await warp(Vector2(hoist.stone_origin.x-40,room.lower_floor_y(hoist.stone_origin.x)))
  await tap();await wait_task(hoist.Task.CARRY)
  await warp(Vector2(room.pressure.plate_rest.x+float(attempt[0]),room.MID_Y))
  level.facing=float(attempt[1]);await frames(2)
  var before:Vector2=route.feet()
  await tap()
  for i in 160:
   await frames(1)
   if hoist.location==hoist.Location.AIR:break
  check(hoist.location==hoist.Location.AIR,"F must release a ballistic load")
  check(absf(hoist.stone_velocity.x-float(attempt[1])*85)<.1,"launch cannot home to the pressure plate")
  check(absf(route.feet().x-before.x)<.1,"throw cannot auto-walk to a destination")
  await wait_task(hoist.Task.NONE);await frames(90)
  check(hoist.plate_locked()==bool(attempt[2]),"free throw must permit both accurate and missed landings")
  check(room.restraint_cleared==bool(attempt[2]),"only a physically landed pressure load can latch the cart")
  print("FREE PRESSURE THROW ",{"offset":attempt[0],"aim":attempt[1],"hit":hoist.plate_locked(),"land_x_from_plate":hoist.stone_origin.x-room.pressure.plate_rest.x})
 print("FREE PRESSURE HIT AND MISS ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
