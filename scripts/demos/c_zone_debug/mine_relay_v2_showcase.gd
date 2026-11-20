extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func camera_shot(label:String,at:Vector2)->void:
 level.set_physics_process(false)
 level.camera_x=at.x;level.camera_y=at.y;level.camera.position=at+Vector2(640,360)
 await frames(3);await shot(label)
 level.set_physics_process(true)
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(830,1140)
 await camera_shot("10-layout-compact",Vector2(200,-3525))
 Input.action_press("interact")
 for i in 400:
  await frames(1)
  if relay.state==relay.State.COUNTDOWN:break
 Input.action_release("interact")
 await camera_shot("11-warning-and-control",Vector2(160,-3525))
 await board(1)
 var hammer_shot:=false;var car_shot:=false
 for i in 600:
  await frames(1)
  if not hammer_shot and relay.hammer_struck:
   hammer_shot=true;await camera_shot("12-hammer-contact",Vector2(200,-3420))
  if not car_shot and relay.contact_age>=0:
   car_shot=true;await camera_shot("13-car-contact-sparks",Vector2(900,-3400))
  if relay.cart_landed:break
 check(relay.cart_landed,"showcase must reach the valley bank")
 await shot("14-arrival")
 print("COMPACT RELAY SHOWCASE ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
