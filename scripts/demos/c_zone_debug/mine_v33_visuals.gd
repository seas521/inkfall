extends "res://scripts/demos/c_zone_debug/mine_complete_v33_review.gd"
func still(label:String,center:Vector2,zoom_value:float=1.5)->void:
 level.set_physics_process(false)
 level.camera.zoom=Vector2.ONE*zoom_value
 level.camera.position=center;level.camera.offset=Vector2.ZERO;level.camera.force_update_scroll()
 level.camera_x=center.x-640./zoom_value;level.camera_y=center.y-360./zoom_value
 await frames(3);await shot(label)
 level.set_physics_process(true)
func run()->void:
 root.size=Vector2i(1280,720)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders;hoist=room.hoist
 room.restraint_cleared=true;room.pressure.rise=room.scenery.mechanisms.CLAMP_TRAVEL;room.pressure._present()
 for x in [610.,660.,720.]:
  room.bays[0]=x;room.relay.velocities[0]=0;room.relay.positions[0]=Vector2(x,room.TRACK_Y)
  await warp(Vector2(x-60,room.TRACK_Y));await frames(20)
  await still("09-post-final-"+str(int(x)),Vector2(625,room.TRACK_Y-130),1.6)
 for offset in [-14.,0.,14.]:
  hoist.reset();hoist.location=hoist.Location.BASKET;hoist.load_offset_x=offset
  await warp(Vector2(-180,room.MID_Y))
  for i in 300:await frames(1)
  await still("10-static-load-"+str(int(offset)),hoist.stone_origin+Vector2(-20,-50),2.)
 # Re-enter the earlier cart section to inspect its actual rounded terrain.
 level.camera.zoom=Vector2.ONE
 level.enter_mine_cart_gap_test();await frames(25)
 var t=route.mine_trial
 level.player.position=Vector2(-1330,t.ground(-1330))-Vector2(13,54);level.player.velocity=Vector2.ZERO;route.fall_origin=t.ground(-1330)
 await frames(20)
 await still("11-rounded-recovery-crest",Vector2(-1320,t.ground(-1320)-90),1.65)
 print("V33 VISUAL CAPTURE PASS")
 quit(1 if failed else 0)
