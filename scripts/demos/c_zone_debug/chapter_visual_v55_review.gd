extends "res://scripts/demos/c_zone_debug/chapter_light_v54_review.gd"
# Offline continuous rendering audit. Sweeps bypass gameplay, not a playthrough.
var records:Array=[]
var serial:=0
const DT:=1.0/24.0
func record(label:String)->void:
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 if serial%24==0:
  var raw:=FileAccess.open(output+"/%05d-native.linear"%serial,FileAccess.WRITE)
  raw.store_buffer(im.get_data());raw.close()
  var meta:=FileAccess.open(output+"/%05d-native.json"%serial,FileAccess.WRITE)
  meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
 im.resize(640,360,Image.INTERPOLATE_BILINEAR)
 var file:=FileAccess.open(output+"/%05d.frame"%serial,FileAccess.WRITE)
 file.store_buffer(im.get_data());file.close()
 var focal=level.art.valley_player_focus
 records.append({"frame":serial,"segment":label,"feet":level.player.position+Vector2(13,54),"camera":level.camera.position,"zoom":level.camera.zoom.x,"region":focal.discovery_region,"focus":focal.focus_anchor,"format":im.get_format(),"frame_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.})
 serial+=1
func sweep(label:String,points:PackedVector2Array,count:int)->void:
 place(points[0]);present(route.active)
 for i in 16:present(route.active);await frames(1)
 for i in count:
  var t:=float(i)/float(count-1)*float(points.size()-1)
  var idx:=mini(int(t),points.size()-2)
  var feet:=points[idx].lerp(points[idx+1],t-float(idx))
  level.player.position=feet-Vector2(13,54);level.player.velocity=Vector2(140,0)
  if route.active:route._present(DT)
  else:level._update_camera(DT);level._present(DT)
  await record(label)
 print("AUDIT SEGMENT ",label," total frames=",serial)
func run()->void:
 output="res://artifacts/plane-contact-v55/continuous"+("-final" if OS.get_environment("INKFALL_V55_FINAL")=="1" else "")
 if not OS.get_environment("INKFALL_VISUAL_OUTPUT").is_empty():output=OS.get_environment("INKFALL_VISUAL_OUTPUT")
 DirAccess.make_dir_recursive_absolute(output)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false;level.set_physics_process(false)
 var forest:=PackedVector2Array()
 for i in 61:
  var x:=lerpf(-9270.,-3540.,float(i)/60.)
  forest.append(Vector2(x,S.ground_top(x)))
 await sweep("upper-forest",forest,360)
 level.enter_root_cliff_test();level.set_physics_process(false)
 await sweep("gorge-descent",PackedVector2Array([Vector2(-3450,-4070),Vector2(-3370,-3760),Vector2(-3500,-3450),Vector2(-3200,-3370),Vector2(-2890,-3405)]),192)
 level.enter_mine_cart_gap_test();level.set_physics_process(false)
 var tunnel:=PackedVector2Array()
 for i in 31:
  var x:=lerpf(-2810.,-1100.,float(i)/30.)
  tunnel.append(Vector2(x,route.mine_trial.ground(x)))
 await sweep("mine-tunnel",tunnel,192)
 level.enter_mine_cart_pair_test();level.set_physics_process(false)
 var room=route.mine_trial.gap.art.pair_room
 await sweep("hoist-upper-lower",PackedVector2Array([Vector2(-430,room.UPPER_Y),Vector2(-180,room.MID_Y),Vector2(-180,room.LOWER_Y),Vector2(160,room.LOWER_Y),Vector2(180,room.MID_Y),Vector2(560,room.TRACK_Y)]),192)
 await sweep("relay-and-exit",PackedVector2Array([Vector2(560,room.TRACK_Y),Vector2(1100,room.TRACK_Y),Vector2(1600,room.TRACK_Y),Vector2(1900,-3180),Vector2(2310,-2928),Vector2(2760,-2928)]),192)
 level.enter_valley_test();level.set_physics_process(false)
 await sweep("valley-river",PackedVector2Array([Vector2(-110,550),Vector2(950,level.ground_y(950)),Vector2(1600,575),Vector2(2450,level.ground_y(2450)),Vector2(2890,430)]),240)
 await sweep("valley-forest",PackedVector2Array([Vector2(2890,430),Vector2(3220,430),Vector2(3800,420),Vector2(4200,level.marsh_rock_surface_y(4200)),Vector2(4890,454),Vector2(5900,414),Vector2(6800,392),Vector2(7035,392)]),288)
 var manifest:=FileAccess.open(output+"/frames.json",FileAccess.WRITE)
 manifest.store_string(JSON.stringify(records));manifest.close()
 print("CHAPTER VISUAL AUDIT COMPLETE frames=",serial)
 level.queue_free();await frames(3);quit()
