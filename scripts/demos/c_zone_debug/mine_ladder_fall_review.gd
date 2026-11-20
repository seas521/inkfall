extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func drop_case(distance:float,side:float,fatal:bool)->void:
 release();route.failure_time=0;route.failure_airborne=false;route.respawn_reveal=0
 room.ladders.cancel();relay._release_passenger();room.hoist.task=room.hoist.Task.NONE
 room.gap.air_active=false
 var l=room.ladders;var d:Dictionary=l.definitions()[1]
 level.player.position=Vector2(d.x,d.bottom)-Vector2(13,54)
 level.player.velocity=Vector2.ZERO;level.player.collision_mask=43
 l.begin(1,false);l.mode=l.Mode.CLIMB;l.going_up=true
 l.physical_feet=Vector2(d.x,d.bottom-distance);l._place()
 Input.action_press("jump");Input.action_press("move_right" if side>0 else "move_left")
 var died:=false
 for i in 200:
  await frames(1)
  if i==0:Input.action_release("jump")
  if route.failure_time>0:died=true;break
  if i>10 and level.player.is_on_floor():break
 release()
 check(died==fatal,"ladder fall mismatch distance="+str(distance)+" side="+str(side)+" feet="+str(route.feet()))
 if fatal:check(route.failure_airborne,"fatal long falls should keep falling out of view")
 print("LADDER DROP ",distance," side=",side," died=",died," feet=",route.feet())
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await drop_case(70,1,false)
 await drop_case(230,1,true)
 await drop_case(310,1,true)
 print("MINE LADDER FALL ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
