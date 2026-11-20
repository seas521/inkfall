extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func await_landing(name:String)->void:
 for i in 800:
  await frames(1)
  if relay.cart_landed or route.failure_time>0:break
 check(relay.cart_landed,name+" must land on the exit shelf")
 check(route.failure_time==0,name+" must not cause an unintended death")
 print("V2 ROUTE ",name," landed=",relay.cart_landed," position=",relay.positions[1])
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(830,1140,true);await wind();await approach_and_board(1)
 await await_landing("ballast")
 await setup_pair(830,1140,false);await wind();await approach_and_board(0)
 for i in 500:
  await frames(1)
  if relay.collision_done:break
 check(relay.rider==0 and relay.collision_done,"reaction route must be seated at actual contact")
 await frames(8)
 Input.action_press("move_right");Input.action_press("jump")
 for i in 85:
  await frames(1)
  if relay.rider==1:break
 release();check(relay.rider==1,"visible compression/rebound must give a playable transfer jump")
 await await_landing("player-transfer")
 await frames(220);Input.action_press("jump");Input.action_press("move_right");await frames(40);release()
 Input.action_press("move_right")
 for i in 420:
  await frames(1)
  if route.in_c_zone:break
 release();await frames(100)
 check(route.in_c_zone and level.player.is_on_floor(),"revised free placement must still connect to the existing valley")
 var out:=FileAccess.open("res://artifacts/mine-relay-free-v2/routes-review.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"passed":not failed,"in_valley":route.in_c_zone,"collision":relay.last_collision},"  "))
 print("MINE RELAY V2 ROUTES ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
