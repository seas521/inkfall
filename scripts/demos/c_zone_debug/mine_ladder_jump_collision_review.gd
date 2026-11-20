extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
var penetrations:=0
func in_rock()->bool:
 var center:Vector2=route.feet()-Vector2(0,27)-room.ORIGIN
 if center.x<0 or center.y<0 or center.x>=room.terrain_bits.get_size().x or center.y>=room.terrain_bits.get_size().y:return false
 return room.terrain_bits.get_bitv(Vector2i(center))
func jump_case(index:int,fraction:float,side:float)->void:
 release();route.failure_time=0;route.failure_airborne=false
 room.ladders.cancel();relay._release_passenger()
 var l=room.ladders
 var d:Dictionary=l.definitions()[index]
 level.player.position=Vector2(d.x,d.bottom)-Vector2(13,54);level.player.velocity=Vector2.ZERO
 level.player.collision_mask=43;level.jump_buffer=0;level.jump_windup_left=0
 l.begin(index,false)
 l.mode=l.Mode.EXIT;l.going_up=true;l.frame_from=156;l.frame_to=240
 l.segment_duration=.55;l.segment_time=.55*fraction
 l.segment_from=Vector2(d.x,d.top+40)
 l.physical_feet=Vector2(d.x,lerpf(d.top+40,d.top,smoothstep(156,198,lerpf(156,240,fraction))))
 l._place()
 Input.action_press("move_left" if side<0 else "move_right");Input.action_press("jump")
 for i in 100:
  await frames(1)
  if i==0:Input.action_release("jump")
  if in_rock():penetrations+=1
  if route.failure_time>0:break
 release()
 print("LADDER JUMP ",index," fraction=",fraction," side=",side," feet=",route.feet()," rock=",in_rock())
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for index in 2:
  for fraction in [.0,.4,.8]:
   for side in [-1.,1.]:await jump_case(index,fraction,side)
 check(penetrations==0,"ladder dismount must never place the capsule inside geology: "+str(penetrations))
 print("MINE LADDER JUMP COLLISION ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
