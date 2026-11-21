extends "res://scripts/demos/c_zone_debug/chapter_light_v54_review.gd"
func transport_value(at:Vector2)->Color:
 var image:Image=level.art.valley_player_light.transport_view.get_texture().get_image()
 var uv:Vector2=level.get_canvas_transform()*at/level.get_viewport_rect().size
 var px:=Vector2i(uv*Vector2(image.get_size()))
 return image.get_pixelv(px.clamp(Vector2i.ZERO,image.get_size()-Vector2i.ONE))
func run()->void:
 output="res://artifacts/carcass-focus-v56/sun-transport-review"
 DirAccess.make_dir_recursive_absolute(output)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(15);route=level.bridge_to_c;level.enter_valley_test()
 await settle(Vector2(950,level.ground_y(950)))
 for i in 12:present();await process_frame
 var field=level.art.valley_player_light
 check(field.transport_active,"foreground receivers use the cached visible sunlight field")
 await capture("01-native-bank")
 var sample_at:=Vector2(950,500)
 var native_value:=transport_value(sample_at)
 check(native_value.r>.02 and native_value.g>.8,"the open bank has an unobstructed upstream light path")
 # A synthetic opaque screen is a visibility test fixture, not new game art.
 # Keep the same source/camera; place it only in the occlusion input.
 var image:=Image.create(128,72,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
 for y in range(20,40):
  for x in range(67,72):image.set_pixel(x,y,Color.BLACK)
 field.transport_material.set_shader_parameter("blocker_texture",ImageTexture.create_from_image(image))
 field.transport_material.set_shader_parameter("blocker_rect",Vector4(425,0,1280,720))
 field.transport_material.set_shader_parameter("blocker_ready",1.)
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 var blocked:=transport_value(sample_at)
 check(blocked.r<native_value.r*.15 and blocked.g<.15,"a real opaque light-path mask suppresses incident energy, not just air brightness")
 field.sync_terrain_projection()
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 var restored:=transport_value(sample_at)
 check(restored.r>native_value.r*.9,"removing the occluder restores the same source energy")
 var before_density:float=restored.b
 field.transport_material.set_shader_parameter("forest_light_clock",float(level.art.valley_depth.clock)+.04)
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 check(absf(transport_value(sample_at).b-before_density)<.02,"medium density evolves continuously without per-frame noise flashes")
 level.hide()
 for i in 4:await process_frame
 check(not field.transport_active and field.transport_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"the transport pass stops when gameplay is hidden")
 var f:=FileAccess.open(output+"/result.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"failed":failed,"checks":checks,"native":str(native_value),"blocked":str(blocked),"restored":str(restored)}));f.close()
 print("SUN TRANSPORT V56 ","FAIL" if failed else "PASS"," checks=",checks)
 level.queue_free();await frames(3);quit(1 if failed else 0)
