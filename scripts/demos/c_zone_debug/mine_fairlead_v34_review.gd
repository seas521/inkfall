extends "res://scripts/demos/c_zone_debug/mine_pair_ladders_review.gd"
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 level.set_physics_process(false)
 level.camera.zoom=Vector2.ONE*2.0
 var center:Vector2=room.ORIGIN+Vector2(1184,483)
 level.camera.position=center;level.camera.offset=Vector2.ZERO;level.camera.force_update_scroll()
 level.camera_x=center.x-320.;level.camera_y=center.y-180.
 await frames(3)
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var dir:="res://artifacts/mine-restraint-fairlead-v34/game"
 DirAccess.make_dir_recursive_absolute(dir)
 var raw=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
 level.camera.zoom=Vector2.ONE;level.set_physics_process(true)
func inspect()->void:
 var rig=room.scenery.mechanisms
 var p:PackedVector2Array=rig.clamp_rope.points
 var inlet:Marker2D=rig.restraint_fairlead.get_node("inlet")
 var outlet:Marker2D=rig.restraint_fairlead.get_node("outlet")
 var world_eye:Vector2=rig.restraint_rope_eye.global_position
 check(p.size()==6,"route must explicitly pass through inlet and outlet")
 check(rig.clamp_rope.to_global(p[3]).distance_to(inlet.global_position)<.001,"line must pass through the measured beam inlet")
 check(rig.clamp_rope.to_global(p[4]).distance_to(outlet.global_position)<.001,"line must pass through the protruding outlet")
 check(rig.clamp_rope.to_global(p[-1]).distance_to(world_eye)<.001,"line must attach inside the upper moving ring")
 check(absf(world_eye.x-outlet.global_position.x)<.001,"saddle fitting cannot pull the hanging line sideways")
 var plate_anchor:Marker2D=rig.parts["pressure_plate"].get_node("rope_anchor")
 check(rig.clamp_rope.to_global(p[0]).distance_to(plate_anchor.global_position)<.001,"plate end must remain attached")
func run()->void:
 root.size=Vector2i(1280,720)
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;control=room.ladders
 var rig=room.scenery.mechanisms
 for travel in range(43):
  rig.set_restraint_rise(float(travel));inspect()
 rig.set_restraint_rise(0);await shot("01-guide-lowered")
 await warp(Vector2(room.pressure.plate_rest.x,room.MID_Y))
 for i in 90:
  await frames(1);inspect()
 check(room.pressure.released,"real pressure input must still lift the restraint")
 await shot("02-guide-raised")
 await warp(Vector2(70,room.MID_Y))
 for i in 100:
  await frames(1);inspect()
 check(not room.pressure.released and room.pressure.rise==0,"unloaded plate must still lower the restraint")
 await shot("03-guide-returned")
 print("MINE FAIRLEAD V34 ","FAIL" if failed else "PASS"," sampled43static+190live positions")
 quit(1 if failed else 0)
