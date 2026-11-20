extends "res://scripts/demos/c_zone_debug/valley_production_v42_capture.gd"
func run()->void:
 phase=OS.get_environment("INKFALL_GRASS_PHASE")
 if phase.is_empty():phase="after"
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
 if phase=="play":
  DisplayServer.window_set_title("Inkfall · 悬崖草皮统一预览 v43")
  var x:float=S.CLIFF_X-700.;place(Vector2(x,S.ground_top(x)));level._present(0)
  print("CLIFF GRASS V43 PLAY READY");return
 level.set_physics_process(false)
 for offset in [1100.,600.,220.]:
  var x:float=S.CLIFF_X-offset;place(Vector2(x,S.ground_top(x)))
  for i in 30:level._present(0);await frames(1)
  await RenderingServer.frame_post_draw
  var folder="res://artifacts/cliff-grass-unify-v43/"+phase;DirAccess.make_dir_recursive_absolute(folder)
  var label="cliff-"+str(int(offset));var im=root.get_texture().get_image()
  var f=FileAccess.open(folder+"/"+label+".linear",FileAccess.WRITE);f.store_buffer(im.get_data());f.close()
  f=FileAccess.open(folder+"/"+label+".json",FileAccess.WRITE);f.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));f.close()
  print("CLIFF GRASS ",phase," offset=",offset," visible=",level.art.grass_art.visible)
 print("CLIFF GRASS CAPTURE COMPLETE");quit()
