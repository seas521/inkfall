extends SceneTree
const S=preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
var level
var route
var report:Array=[]
var phase:=OS.get_environment("INKFALL_VALLEY_PHASE")
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func place(at:Vector2)->void:
 level.player.position=at-Vector2(13,54);level.player.velocity=Vector2.ZERO
 level.facing=1;level.camera_x=at.x-525;level.camera_y=level._camera_target_y()
 level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
 level.camera.offset=Vector2.ZERO;level.camera.zoom=Vector2.ONE
func snap(label:String,root_pose:bool=false)->void:
 if phase=="after-1920" and label not in ["01-upper-forest-start","04-cliff-grass","14-valley-rock-hill"]:return
 for i in 40:
  if root_pose:route._present(0)
  else:level._present(0)
  await frames(1)
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var directory:="res://artifacts/valley-forest-depth-v37/"+phase
 DirAccess.make_dir_recursive_absolute(directory)
 var raw=FileAccess.open(directory+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(directory+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
 var film=get_nodes_in_group("film_look")[0]
 var record={"shot":label,"feet":str(level.player.position+Vector2(13,54)),"camera":str(level.camera.position),"actor_clip":String(level.actor.current_clip),"actor_softness":level.actor.pose.fog_blur,"mine_grade":film.mine_amount,"environment_softness":film.lens_material.get_shader_parameter("environment_softness"),"route_softness":film.lens_material.get_shader_parameter("route_softness"),"film_layers":get_nodes_in_group("film_look").size()}
 report.append(record);print("ROUTE OPTICS ",record)
func run()->void:
 if phase.is_empty():phase="after"
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1920,1080) if phase=="after-1920" else Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 if phase=="play":
  DisplayServer.window_set_title("Inkfall · 谷底森林光影预览 v37")
  route.in_c_zone=true;route.active=false;level.log_bridge.active=false
  route.prepare_c_zone_preview();level.debug_enter_marsh_act();route.art.sync(0)
  place(Vector2(230,level.ground_y(230)));level._present(0)
  print("VALLEY V37 PLAY READY")
  return
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
 level.set_physics_process(false)
 route.in_c_zone=true;route.active=false;level.log_bridge.active=false
 route.prepare_c_zone_preview();level.debug_enter_marsh_act();route.art.sync(0)
 for entry in [["11-valley-entry",-110.],["12-valley-river-and-boat",230.],["13-valley-swing-bank",2890.],["14-valley-rock-hill",4060.],["15-valley-later-cliff",7035.]]:
  var x:float=entry[1]
  var y:float=level.ground_y(x) if x<2780 else (430. if x<3300 else level.marsh_rock_surface_y(x))
  if x>7000:y=390.
  place(Vector2(x,y));await snap(entry[0])
 var file=FileAccess.open("res://artifacts/valley-forest-depth-v37/"+phase+"/coverage.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 print("ROUTE OPTICS CAPTURE ",phase," COMPLETE ",report.size());quit()
