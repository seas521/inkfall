extends "res://scripts/demos/c_zone_debug/mine_cart_relay_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await prepare(true);await wind();await board(1);await finish_case("06-valley-landing",true)
 await frames(200)
 Input.action_press("jump");Input.action_press("move_right");await frames(40);release();await frames(8)
 check(relay.rider<0,"fresh jump must dismount the landed cart onto the far bank")
 Input.action_press("move_right")
 for i in 450:
  await frames(1)
  if i%100==0:print("EXIT WALK ",{"feet":route.feet(),"cart":relay.positions[1],"rider":relay.rider,"state":relay.state,"completed":relay.completed,"transition":relay.transition_age,"velocity":level.player.velocity})
  if route.in_c_zone:break
 release();await frames(100)
 check(route.in_c_zone and not route.active,"exit footpath must hand off to the existing valley forest")
 check(not room.enabled and not relay.visible,"mine geometry and fixtures must disable after the valley handoff")
 check(relay.transition_age<0,"root-occluded transition must completely reveal the valley")
 check(level.player.collision_mask==11,"the existing valley must regain its original physics mask")
 check(route.failure_time==0,"arrival must not trigger a mine death loop")
 print("MINE RELAY VALLEY EXIT ","FAIL" if failed else "PASS"," feet=",route.feet()," grounded=",level.player.is_on_floor())
 quit(1 if failed else 0)
