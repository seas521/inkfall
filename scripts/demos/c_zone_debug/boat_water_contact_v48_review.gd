extends "res://scripts/demos/c_zone_debug/valley_production_v42_capture.gd"
var failed:=false
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failed=true;push_error(label)
func run()->void:
 phase="boat-contact-v48"
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
 level.set_physics_process(false)
 route.in_c_zone=true;route.active=false;level.log_bridge.active=false
 route.prepare_c_zone_preview();level.debug_enter_marsh_act();route.art.sync(0)
 var unloaded_y:=0.0
 for mode in ["empty","loaded","moving","tilted"]:
  level.crate.position=Vector2(1500,level._unloaded_float_y())
  level.crate.velocity=Vector2.ZERO;level.floating=true;level.beached=false
  level.launching=false;level.float_time=10.;level.load_sink=0.;level.sink_speed=0.
  level.crate_tilt=0.;level.load_rock=0.;level.rock_speed=0.
  place(Vector2(1572,level.crate.position.y))
  for i in 180:
   level.clock+=1.0/60.
   level._update_crate(1.0/60.,0.,mode!="empty")
   if mode=="moving":level.art.raft_waves(1572,72,90,0,0,1.0/60.)
   level.art._update_waves(1.0/60.)
  if mode=="empty":unloaded_y=level.crate.position.y
  if mode=="loaded":check(level.crate.position.y>unloaded_y+2.,"passenger adds visible draft without sinking the gunwale")
  if mode=="tilted":level.crate_tilt=deg_to_rad(9.)
  var span:Vector2=level.crate_waterline_span()
  check(span.y-span.x>90. and span.y-span.x<165.,mode+" has two distinct hull/water contacts")
  var pivot:Vector2=level.crate.position+level.CRATE_SIZE*.5
  for x in [span.x,span.y]:
   var p:Vector2=(Vector2(x,level.art.water_line(x))-pivot).rotated(-level.crate_tilt)+level.CRATE_SIZE*.5
   var distance:=1000.
   var hull:PackedVector2Array=PackedVector2Array(level.BOAT_HULL_PROFILE)
   for i in hull.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,hull[i],hull[(i+1)%hull.size()])))
   check(distance<.15,mode+" contact lies on visible hull, within 0.15px")
  place(Vector2(1572,level.crate.position.y));await snap("boat-"+mode)
  print("BOAT CONTACT ",mode," draft=",level.crate.position.y," span=",span)
 print("BOAT WATER CONTACT V48 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
