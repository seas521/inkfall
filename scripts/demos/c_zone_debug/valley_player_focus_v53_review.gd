extends "res://scripts/demos/c_zone_debug/valley_production_v42_capture.gd"
var failed:=false
func shot(label:String,x:float,facing:int,lit:bool=true)->void:
 place(Vector2(x,level.ground_y(x)))
 level.facing=facing;level.camera_x=0.;level.camera_y=0.
 level.camera.position=Vector2(640,360)
 for i in 20:
  level._present(0)
  if not lit:
   level.actor.set_forest_light(false,null,Vector2.ZERO,0.)
   level.art.valley_player_light.hide()
   level.art.valley_player_focus.sync(false)
  await frames(1)
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var directory:="res://artifacts/valley-player-focus-v53"+("/1080p" if OS.get_environment("INKFALL_LIGHT_1080")=="1" else "")
 DirAccess.make_dir_recursive_absolute(directory)
 var raw=FileAccess.open(directory+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(directory+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
 print("VALLEY PLAYER FOCUS CAPTURE ",label," feet=",level.actor.position," camera=",level.camera.position)
func camera_shot(label:String,x:float,y:float)->void:
 place(Vector2(x,y));level.facing=1
 for i in 20:level._present(0);await frames(1)
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 var directory:="res://artifacts/valley-player-focus-v53"+("/1080p" if OS.get_environment("INKFALL_LIGHT_1080")=="1" else "")
 DirAccess.make_dir_recursive_absolute(directory)
 var raw=FileAccess.open(directory+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta=FileAccess.open(directory+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
 print("VALLEY PLAYER FOCUS COVERAGE ",label)
func run()->void:
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1920,1080) if OS.get_environment("INKFALL_LIGHT_1080")=="1" else Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
 level.set_physics_process(false)
 route.in_c_zone=true;route.active=false;level.log_bridge.active=false
 route.prepare_c_zone_preview();level.debug_enter_marsh_act();route.art.sync(0)
 await shot("01-shade-before",430,1,false)
 await shot("02-shade-after",430,1)
 await shot("03-light-before",950,1,false)
 await shot("04-light-after",950,1)
 var mask_image:Image=level.art.valley_player_focus.mask_view.get_texture().get_image()
 var body_alpha:=0.0
 for y in range(238,263):
  for x in range(466,484):body_alpha=maxf(body_alpha,mask_image.get_pixel(x,y).a)
 if body_alpha<.25 or mask_image.get_pixel(200,150).a>.05:
  failed=true;push_error("focus coverage must contain the actor and exclude the distant forest")
 await shot("05-light-facing-left",950,-1)
 await camera_shot("06-river",1600.,575.)
 await camera_shot("07-hill",4200.,level.marsh_rock_surface_y(4200.))
 # A region change must not leave a bright silhouette in the cave/upper forest.
 route.in_c_zone=false;route.active=true
 level.art.sync(0,-4000,true)
 var amount:float=level.actor.sprite.material.get_shader_parameter("forest_received_light")
 if amount!=0. or level.art.valley_player_light.visible or level.art.valley_player_focus.enabled:
  failed=true;push_error("valley illumination leaked outside valley")
 var gap:Color=level.art.valley_player_light._surface(3500.)
 if gap.b!=0.:failed=true;push_error("gap received an invented ground surface")
 var water:Color=level.art.valley_player_light._surface(1600.)
 if water.g!=1.:failed=true;push_error("river exclusion is missing")
 print("VALLEY PLAYER FOCUS V53 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
