extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for index in 2:
  for side in [-1.,1.]:
   for direction in [-1.,1.]:
    var start:float=1250. if direction<0 else 850.
    await setup_pair(start if index==0 else 450.,start if index==1 else 450.,false)
    room.restraint_cleared=true;relay.angle=1.28;relay.pendulum_live=false
    await warp(Vector2(start+side*54,room.TRACK_Y))
    Input.action_press("interact");await frames(25)
    check(room.cart_gripped and room.cart_grip_index==index,"real F must grip selected cart before crossing")
    Input.action_press("move_left" if direction<0 else "move_right")
    var before:Vector2=route.feet()
    var dropped:=false
    for i in 620:
     await frames(1)
     if not room.cart_gripped:
      print("GRIP DROPPED ",{"cart":index,"side":side,"direction":direction,"frame":i,"before":before,"feet":route.feet(),"car_x":room.bays[index],"floor":level.player.is_on_floor(),"velocity":level.player.velocity,"slider":relay.charge_owner,"rider":relay.rider,"holding_F":Input.is_action_pressed("interact")})
      for j in level.player.get_slide_collision_count():
       var hit=level.player.get_slide_collision(j)
       print("CROSS COLLIDER ",hit.get_position()," normal=",hit.get_normal()," body=",hit.get_collider())
      dropped=true;break
     before=route.feet()
     if (room.bays[index]-start)*direction>400:break
    check(not dropped,"held F must not drop either cart while crossing the controller")
    check((room.bays[index]-start)*direction>395,"cart must cross the full controller and floor seam")
    print("CROSS RESULT ",index," side=",side," direction=",direction," x=",room.bays[index])
    release();await frames(3)
 print("MINE CART CROSS SLIDER V28 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
