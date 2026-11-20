extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for side in [-1.,1.]:
  await setup_pair(830,1350,false)
  await warp(Vector2(relay.LEVER.x+side*relay.SLIDER_STANCE_X,room.TRACK_Y))
  var initial:float=relay.angle
  var worst_reverse:=0.0
  Input.action_press("interact")
  var previous:float=relay.angle
  for i in 420:
   await frames(1)
   worst_reverse=minf(worst_reverse,(relay.angle-previous)*side)
   check((relay.angle-initial)*side>=-.001,"parked head must never initially move opposite the selected haul")
   previous=relay.angle
   if relay.charge>.997:break
  check(relay.charge_owner and absf(relay.angle-side*relay.MAX_ANGLE)<.025,"selected side must still reach its full haul")
  print("HAUL START ",side," reverse_step=",worst_reverse," final=",relay.angle)
  Input.action_release("interact");await frames(2)
  var saw_return:=false;var previous_weight:=1.0;var max_pan:=0.0
  var previous_camera:=Vector2(level.camera_x,level.camera_y)
  for i in 340:
   await frames(1)
   var now:=Vector2(level.camera_x,level.camera_y)
   if relay.release_camera_weight>0 and relay.release_camera_time<=0:
    saw_return=true
    check(relay.release_camera_weight<=previous_weight+.0001,"observation return must blend monotonically")
    max_pan=maxf(max_pan,now.distance_to(previous_camera))
    check(now.distance_to(previous_camera)<5.2,"stationary-player camera return must not snap or rush across frame")
   previous_weight=relay.release_camera_weight;previous_camera=now
   if saw_return and not relay.release_camera_owns():break
  check(saw_return and not relay.release_camera_owns(),"observation must finish a visible blend back to normal control")
  var before:=Vector2(level.camera_x,level.camera_y)
  await frames(1)
  check(Vector2(level.camera_x,level.camera_y).distance_to(before)<10,"handoff to normal follow must remain continuous")
  print("CAMERA RETURN ",side," max_step=",max_pan," end=",Vector2(level.camera_x,level.camera_y))
 print("MINE HAUL CAMERA V28 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
