extends "res://scripts/demos/c_zone_debug/chapter_player_plane_v54_review.gd"
# Compare actual HDR body pixels with receiving light enabled/disabled while
# retaining the background's original light. This is an internal review only.
var light_report:Array=[]
func freeze_film_noise()->void:
 for film in get_nodes_in_group("film_look"):
  film.lens_material.set_shader_parameter("grain",0.)
  film.lens_material.set_shader_parameter("flicker",0.)
  film.lens_material.set_shader_parameter("scratches",0.)
func body_energy(image:Image)->Dictionary:
 var mask:Image=level.art.valley_player_focus.mask_view.get_texture().get_image()
 var feet:Vector2=level.actor.global_position
 var a:Vector2=level.get_canvas_transform()*(feet+Vector2(-17,-65))/level.get_viewport_rect().size*Vector2(image.get_size())
 var b:Vector2=level.get_canvas_transform()*(feet+Vector2(17,-12))/level.get_viewport_rect().size*Vector2(image.get_size())
 var total:=0.;var count:=0
 for y in range(maxi(0,int(a.y)),mini(image.get_height(),int(b.y))):
  for x in range(maxi(0,int(a.x)),mini(image.get_width(),int(b.x))):
   var p:=Vector2i(Vector2(x,y)/Vector2(image.get_size())*Vector2(mask.get_size()))
   var c:=image.get_pixel(x,y);var value:=c.get_luminance()
   if mask.get_pixelv(p).a>.92 and value<.08:
    total+=value;count+=1
 return {"mean":total/maxi(count,1),"count":count}
func light_pair(label:String,root_pose:bool=false)->void:
 # Isolate body pixels from the newly authored foreground clumps. Otherwise
 # this ROI also measures grass in front of the actor, not just the actor.
 var clumps=level.art.contact_grass
 var clumps_visible:bool=clumps.visible
 clumps.hide()
 for i in 8:present(root_pose);clumps.hide();freeze_film_noise();await frames(1)
 await RenderingServer.frame_post_draw
 var lit:=body_energy(root.get_texture().get_image())
 var field=level.art.valley_player_light
 var irradiance:=-1.0
 if field.transport_active:
  var transport:Image=field.transport_view.get_texture().get_image()
  var uv:Vector2=level.get_canvas_transform()*(level.actor.global_position-Vector2(0,40))/level.get_viewport_rect().size
  var pixel:=Vector2i(uv*Vector2(transport.get_size())).clamp(Vector2i.ZERO,transport.get_size()-Vector2i.ONE)
  irradiance=transport.get_pixelv(pixel).r
 await capture(label+"-on")
 for i in 8:
  present(root_pose);freeze_film_noise()
  clumps.hide()
  field.hide();level.actor.set_forest_light(false,null,Vector2.ZERO,0.)
  level.actor.set_chapter_lights(0,field.sources,field.axes,0,field.barriers,0.,0.)
  await frames(1)
 await RenderingServer.frame_post_draw
 var unlit:=body_energy(root.get_texture().get_image())
 await capture(label+"-receiving-off")
 light_report.append({"shot":label,"on":lit,"receiving_off":unlit,"incident_at_body":irradiance,"foreground_clumps_isolated":true})
 check(lit.count>40 and unlit.count>40,label+" samples opaque body pixels")
 if irradiance>=0.0 and irradiance<.08:
  check(float(lit.mean)<float(unlit.mean)+.003,label+" occluded/weakly lit body does not receive a forced bright fill")
 else:
  check(float(lit.mean)>float(unlit.mean)+.00001,label+" real body pixels respond to accessible illumination")
 clumps.visible=clumps_visible
 for i in 4:present(root_pose);await frames(1)
func run()->void:
 var high:=OS.get_environment("INKFALL_FOCUS_1080")=="1"
 output="res://artifacts/chapter-player-plane-v54/light-review"+("-1080p" if high else "")
 DirAccess.make_dir_recursive_absolute(output)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1920,1080) if high else Vector2i(1280,720)
 root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
 await settle(Vector2(-6450.,S.ground_top(-6450.)))
 await light_pair("01-forest-opening")
 await settle(Vector2(-7850.,S.ground_top(-7850.)))
 for i in 5:present();await frames(1)
 await capture("02-forest-shade")
 level.enter_mine_cart_pair_test()
 var room=route.mine_trial.gap.art.pair_room
 for fixture in room.lamps:fixture.set_process(false)
 await settle(Vector2(181.,room.MID_Y))
 await light_pair("03-under-mine-lamp",true)
 var fixture=room.lamps[1]
 var field=level.art.valley_player_light
 for angle:float in [-.12,.12]:
  fixture.set_angle(angle);present(true)
  var found:=-1
  for i in field.source_count:
   if Vector2(field.sources[i].x,field.sources[i].y).distance_to(fixture.light_position())<.01:found=i
  check(found>=0,"swinging bulb world position reaches the receiving field")
  if found>=0:
   check(field.axes[found].distance_to(Vector2.DOWN.rotated(fixture.light_angle()))<.0001,"receiving direction follows the real shade angle")
  for i in 4:present(true);freeze_film_noise();await frames(1)
  await capture("04-lamp-left" if angle<0 else "05-lamp-right")
 check(field.barrier_count==2,"upper and middle decks interrupt overhead illumination")
 for fixture_node in room.lamps:fixture_node.set_process(true)
 level.enter_valley_test();await settle(Vector2(950.,level.ground_y(950.)))
 await light_pair("06-valley-opening")
 await settle(Vector2(6800.,level.marsh_rock_surface_y(6800.)))
 level.fan_owned=false;level.cliff.carrying=0
 level.cliff.stones[0]["state"]=level.CliffAct.Stone.HELD
 for i in 8:present();await frames(1)
 await light_pair("07-far-bank-holding-stone")
 check(field._surface(1600.).g==1.,"open water remains excluded from ground illumination")
 check(field._surface(3500.).b==0.,"valley gaps do not acquire a luminous floor")
 level.hide();await frames(3)
 check(not field.visible,"shared receiving light does not leak into menus")
 var file:=FileAccess.open(output+"/result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"failed":failed,"checks":checks,"shots":light_report},"  "));file.close()
 print("CHAPTER LIGHT V54 ","FAIL" if failed else "PASS"," ",light_report)
 level.queue_free();await frames(3);quit(1 if failed else 0)
