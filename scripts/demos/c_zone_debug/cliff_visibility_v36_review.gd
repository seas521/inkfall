extends SceneTree
var level
var phase:=OS.get_environment("INKFALL_CLIFF_PHASE")
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func shot(label:String)->void:
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var dir:="res://artifacts/cliff-visibility-lamp-v36/"+phase
 DirAccess.make_dir_recursive_absolute(dir)
 var raw=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 if phase.is_empty():phase="after"
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(20)
 level.debug_enter_rope_ladder(false);await frames(5)
 if phase=="play":
  DisplayServer.window_set_title("Inkfall · 悬崖与灯线修复预览")
  print("CLIFF V36 PLAY READY: descend from the ladder top")
  return
 Input.action_press("climb_down")
 for i in 650:
  await frames(1)
  if i in [180,260,340,420,500,580,640]:
   print("CLIFF REVEAL ",{"frame":i,"feet":level.player.position+Vector2(13,54),"cam":Vector2(level.camera_x,level.camera_y),"legacy":level.log_bridge.art.ink_stage.output.is_visible_in_tree(),"mountain":level.bridge_to_c.art.mountain.is_visible_in_tree(),"route":level.bridge_to_c.active})
   await shot("ladder-"+str(i))
   if i==340:
    level.set_physics_process(false)
    level.log_bridge.art.ink_stage.output.hide();await frames(2);await shot("ladder-340-no-legacy")
    level.log_bridge.art.ink_stage.output.show();level.set_physics_process(true)
 Input.action_release("climb_down")
 level.enter_mine_cart_gap_test();await frames(20)
 var route=level.bridge_to_c
 route.art.chase_chamber.set_collapse(-1)
 var fixtures=[route.art.chamber.lamp,route.art.chase_chamber.lamp,route.mine_trial.escape.chase_lamp,route.mine_trial.escape.end_lamp]
 for lamp in fixtures:
  lamp.restore_fixture()
  var chamber=route.art.chamber if lamp.position.x< -2220 else route.art.chase_chamber
  print("MINE CEILING LAMP ",{"x":lamp.global_position.x,"pivot":lamp.global_position,"roof":chamber.ceiling_y(lamp.global_position.x),"bulb":lamp.light_position(),"length":lamp.cable_length})
  if lamp==route.art.chase_chamber.lamp:
   level.set_physics_process(false)
   level.camera_x=lamp.global_position.x-600;level.camera_y=chamber.ceiling_y(lamp.position.x)-70;level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
   route.art.sync(0);level.art.sync(0,level.camera_x,true);await frames(4);await shot("penultimate-lamp")
 print("CLIFF VISIBILITY CAPTURE ",phase," COMPLETE");quit()
