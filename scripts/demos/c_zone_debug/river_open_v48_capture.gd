extends "res://scripts/demos/c_zone_debug/valley_production_v42_capture.gd"
func run()->void:
 phase="river-open-v48"
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
 for x in [1200.,1600.,2000.,4060.]:
  level.floating=x<2100
  level.crate.position=Vector2(x-72,level._unloaded_float_y()+level._load_sink_target())
  level.art.disturb(x,100.,45.)
  for i in 24:level.art._update_waves(1.0/60.0)
  place(Vector2(x,level.crate.position.y if x<2100 else level.marsh_rock_surface_y(x)))
  await snap("river-"+str(int(x)))
 quit()
