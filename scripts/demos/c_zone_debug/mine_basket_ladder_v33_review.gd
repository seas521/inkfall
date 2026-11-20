extends "res://scripts/demos/c_zone_debug/mine_basket_free_throw_v32_review.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders;hoist=room.hoist
 for index in [0,1]:
  var d:Dictionary=control.definitions()[index]
  await warp(Vector2(d.x,d.top));Input.action_press("climb_down")
  await frames(2);check(control.active(),"S must engage the ladder")
  for i in 1000:
   await frames(1)
   if not control.active():break
  await frames(60)
  check(not level.scene1.low_stance.active(),"held descent key must not crouch after dismount")
  Input.action_release("climb_down");await frames(2)
  Input.action_press("climb_down");await frames(12)
  check(level.scene1.low_stance.active(),"a fresh S press must still crouch")
  Input.action_release("climb_down");level.scene1.low_stance.reset();await frames(2)
  print("LADDER DOWN KEY CONSUMPTION PASS ",index)
 var offsets:Array=[]
 for drop_x in [-14.,0.,14.]:
  hoist.reset();await frames(3)
  var basket=room.scenery.mechanisms.basket
  hoist.location=hoist.Location.AIR;hoist.place_in_cart=false;hoist.facing=1
  hoist.stone_origin=basket.position+Vector2(drop_x,-80)
  hoist.stone_velocity=Vector2(0,100)
  var peak_bob:=0.;var peak_sway:=0.
  for i in 300:
   await frames(1)
   peak_bob=maxf(peak_bob,absf(hoist.basket_bob));peak_sway=maxf(peak_sway,absf(hoist.sway))
  check(hoist.loaded(),"a vertical drop through the mouth must stay inside")
  check(peak_bob>3.0,"heavy impact must create visible sag even for a centred vertical drop")
  check(absf(hoist.basket_bob)<.05,"vertical impact must damp rather than loop")
  if absf(drop_x)>1:
   check(hoist.load_offset_x*drop_x>0 and hoist.load_tilt*drop_x>0,"off-centre load must retain the correct static lean")
  else:check(absf(hoist.load_offset_x)<5 and absf(hoist.load_tilt)<.04,"centred load must not prefer the right")
  offsets.append(hoist.load_offset_x)
  print("WEIGHTED BASKET ",{"drop_x":drop_x,"seat_x":hoist.load_offset_x,"tilt":hoist.load_tilt,"peak_bob":peak_bob,"peak_sway":peak_sway})
 check(float(offsets[2])-float(offsets[0])>15,"landing must preserve multiple actual load positions")
 print("MINE BASKET AND LADDER V33 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
