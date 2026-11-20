extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func manipulation(index:int,side:float)->void:
 await setup_pair(830,1350,false)
 await warp(Vector2(room.bays[index]+side*54,room.TRACK_Y))
 Input.action_press("interact")
 for direction in [1.,-1.]:
  Input.action_release("move_left");Input.action_release("move_right")
  Input.action_press("move_right" if direction>0 else "move_left")
  var seen:Dictionary={};var start:float=room.bays[index];var prior:=0.0;var hand_error:=0.0
  for i in 85:
   await frames(1)
   if i>25:
    check(room.cart_grip_distance>=prior,"effort distance must never run backwards")
    prior=room.cart_grip_distance
    seen[str(level.actor.current_clip)+str(level.actor.current_frame_index)]=true
    var hand:Vector2=level.actor.grip_hand_world()
    var contact:Vector2=room.carts[index].grip_surface(relay.cart_at(index),Vector3(relay.pitches[index],0,0),hand.y,side)
    hand_error=maxf(hand_error,absf(hand.x-contact.x))
  check(room.cart_gripped and room.cart_grip_index==index,"must hold selected cart")
  check(absf(room.bays[index]-start)>20,"cart must travel during push/pull")
  check(seen.size()>8,"push/pull must advance body frames, never frozen translation")
  check(hand_error<.15,"moving hands must remain touching cart")
  print("GRIP CASE ",index," side=",side," direction=",direction," distinct_frames=",seen.size()," hand_error=",hand_error)
 release();await frames(3)
 var parked:float=room.bays[index];await frames(40)
 check(absf(parked-room.bays[index])<.001,"release must retain manually chosen position")
func boarding(index:int,side:float)->void:
 await setup_pair(830,1350,false)
 var at:Vector2=relay.cart_at(index)
 await warp(Vector2(at.x+side*75,room.TRACK_Y))
 Input.action_press("jump");Input.action_press("move_left" if side>0 else "move_right")
 for i in 90:
  await frames(1)
  if (route.feet().x-at.x)*side<4:
   Input.action_release("move_left");Input.action_release("move_right")
  if relay.rider==index:break
 release();await frames(2)
 check(relay.rider==index,"both sides must allow boarding a stationary cart")
 Input.action_press("jump");Input.action_press("move_right" if side>0 else "move_left")
 await frames(8)
 check(relay.rider==-1,"jump must immediately release seat ownership")
 await frames(40);release()
 check(relay.rider==-1 and (route.feet().x-at.x)*side>55,"directional dismount must clear cart without suction")
 print("BOARD/DISMOUNT ",index," side=",side," feet=",route.feet())
func empty_shot(x0:float,x1:float)->void:
 await setup_pair(x0,x1,false);await wind();await approach_and_board(1)
 for i in 850:
  await frames(1)
  if relay.cart_landed or relay.cart_lost[1] or route.failure_time>0 or relay.rolling_back:break
 check(not relay.cart_landed,"unweighted donor must not launch passenger cart to valley")
 print("EMPTY DONOR ",x0,"/",x1," landed=",relay.cart_landed," hit=",relay.last_collision)
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for index in 2:
  for side in [-1.,1.]:
   await manipulation(index,side)
   await boarding(index,side)
 await setup_pair(650,1140,false)
 relay.angle=0;relay.angular_speed=0;relay._sync_hammer_body()
 var stopped:float=relay.limit_manual_cart(0,650,830)
 check(stopped>650 and stopped<700,"cart sweep must stop at the parked hammer")
 check(not relay._head_overlaps_cart(0,stopped),"manual cart must stop before penetrating head")
 check(relay.limit_manual_cart(0,830,650)>780,"cart must also stop from the opposite side")
 # A real capsule cannot walk through the same stopped head.
 await warp(Vector2(660,room.TRACK_Y));Input.action_press("move_right");await frames(40);release()
 check(route.feet().x<710,"player must be blocked by stationary hammer head")
 await empty_shot(790,1100)
 await empty_shot(840,1180)
 print("MINE RELAY SOLID V4 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
