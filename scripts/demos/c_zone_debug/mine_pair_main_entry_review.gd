extends SceneTree
# Review the same main scene/menu entry used by the player, with no camera,
# exposure or post-process overrides. Captures are native viewport output.
var failed:=false
var output:=OS.get_environment("INKFALL_PAIR_REVIEW_DIR")
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func check_ladder_planes(room:Node)->void:
 var foreground_image:Image=room.scenery.cached_views[4].get_texture().get_image()
 var structure_image:Image=room.scenery.cached_views[3].get_texture().get_image()
 for point:Vector2i in [Vector2i(207,500),Vector2i(258,550),Vector2i(275,525)]:
  check(foreground_image.get_pixelv(point).a<.02,"ladder rail must not become a foreground occluder")
  check(structure_image.get_pixelv(point).a>.2,"ladder rail color must remain on its structural plane")
func opaque_at(cart:Node2D,at:Vector2)->bool:
 for sprite:Sprite2D in [cart.front,cart.back]:
  var image:=sprite.texture.get_image()
  var pixel:=Vector2i(sprite.to_local(at)+Vector2(image.get_size())*.5)
  if Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel) and image.get_pixelv(pixel).a>.5:return true
 return false
func shot(label:String)->void:
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 # HDR 2D readback stores linear values. PNG needs display sRGB, as
 # the OS window presents it. Never assess art from unconverted readback.
 if root.use_hdr_2d:
  var raw=FileAccess.open(output+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(image.get_data());raw.close()
  var meta=FileAccess.open(output+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[image.get_width(),image.get_height()],"format":image.get_format(),"rgba_half":image.get_format()==Image.FORMAT_RGBAH,"rgba_float":image.get_format()==Image.FORMAT_RGBAF}));meta.close()
  image.convert(Image.FORMAT_RGB8);image.linear_to_srgb()
 image.save_png(output+"/"+label+".png")
func run()->void:
 if output.is_empty():output="res://artifacts/mine-pair-layered-v3/main-entry"
 DirAccess.make_dir_recursive_absolute(output)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15)
 # Explicitly use menu flow rather than instantiating chapter/film separately.
 main.debug_selection=16;main._start_debug_level()
 await frames(90)
 var level=main.river
 var room=level.bridge_to_c.mine_trial.gap.art.pair_room
 check_ladder_planes(room)
 var films=get_nodes_in_group(&"film_look")
 check(films.size()==1,"normal main entry must attach exactly one film pass")
 check(room.scenery.SOURCE.resource_path.ends_with("environment-registered.png"),"new far wall must be live")
 check(room.scenery.far_gallery!=null and room.scenery.back_supports!=null,"independent far depth layers must be live")
 check(room.scenery.REGISTERED.get_shader_uniform_list().size()>0,"volume shader must compile")
 var mechanism=room.scenery.mechanisms
 var rack:Node2D=mechanism.parts["upper_tool_rack"]
 for i in 3:
  var tool:Node2D=mechanism.parts[["hung_pick_long","hung_pick_short","hung_rope_coil"][i]]
  check(tool.get_node("hanging_eye").global_position.distance_to(rack.get_node("hook_"+str(i)).global_position)<.01,"individual tool eye must meet its own rack hook")
 var support_art=room.scenery.SOURCE.get_image()
 for fixture in room.lamps:
  var at:Vector2=fixture.position
  var rest:Vector3=Vector3(fixture.elapsed,fixture.swing_angle,fixture.angular_velocity)
  var support_pixel:=Vector2i(fixture.BULBS[fixture.lamp_index].x,fixture.ANCHOR_Y[fixture.lamp_index])
  check(support_art.get_pixelv(support_pixel).get_luminance()<.55,"lamp mounting plate must lie on authored rock or timber")
  for i in 120:fixture.advance_swing(1.0/60.0)
  var at_60:float=fixture.swing_angle
  check(absf(at_60-rest.y)>.0001,"every near/rear fixture must actually move")
  check(fixture.position==at,"lamp pivot must remain fixed to support")
  check(absf(fixture.light_position().distance_to(fixture.mounting_eye.global_position)-fixture.suspension_length)<.01,"swing must preserve suspension length")
  check(fixture.cable.to_global(fixture.cable.points[0]).distance_to(fixture.mounting_eye.global_position)<.01,"swinging wire must remain attached to fixed mounting eye")
  fixture.elapsed=rest.x;fixture.swing_angle=rest.y;fixture.angular_velocity=rest.z
  for i in 60:fixture.advance_swing(1.0/30.0)
  check(absf(fixture.swing_angle-at_60)<.0001,"pendant motion must agree at 30 and 60 fps")
  fixture.elapsed=rest.x;fixture.swing_angle=rest.y;fixture.angular_velocity=rest.z;fixture.set_angle(rest.y)
 var plate:Node2D=mechanism.parts["pressure_plate"]
 var anchor:Marker2D=plate.get_node("rope_anchor")
 check(mechanism.clamp_rope.to_global(mechanism.clamp_rope.points[0]).distance_to(anchor.global_position)<.01,"rope must terminate at the pressure board eye")
 var plate_rest:Transform2D=plate.transform
 plate.position.y+=5;plate.rotation=.04;mechanism._sync_ropes()
 check(mechanism.clamp_rope.to_global(mechanism.clamp_rope.points[0]).distance_to(anchor.global_position)<.01,"rope eye must follow board travel and tilt")
 plate.transform=plate_rest;mechanism._sync_ropes()
 for cart in room.carts:
  var bottom:float=-INF
  for sprite:Sprite2D in [cart.front,cart.back]:
   var image:=sprite.texture.get_image()
   var found:=false
   for y in range(image.get_height()-1,159,-1):
    for x in image.get_width():
     if image.get_pixel(x,y).a>.5:
      bottom=maxf(bottom,sprite.position.y+(y-160)*sprite.scale.y)
      found=true;break
    if found:break
  print("PARKED CART TREAD ",bottom-room.TRACK_Y," relative to nominal rail")
  check(absf(bottom-room.TRACK_Y-1.0)<2.5,"opaque tire tread must meet the rail crown")
 for body in room.bodies:
  if body.has_meta("cart_preview"):
   check(body.get_child(0).shape.size==level.bridge_to_c.mine_trial.cart_body.get_child(0).shape.size,"parked car collider must match original cart dimensions")
 var parked:=Vector2(room.carts[0].front.position)
 var clamp_rest:=Vector2(mechanism.moving_clamp.position)
 var basket_rest:=Vector2(mechanism.basket.position)
 mechanism.set_restraint_rise(mechanism.CLAMP_TRAVEL)
 check(room.carts[0].front.position==parked,"lifting restraint must never move or crop cart")
 check(absf(mechanism.moving_clamp.position.y-clamp_rest.y+mechanism.CLAMP_TRAVEL)<.01,"independent restraint travel")
 check(absf(mechanism.guide_wheel.rotation-mechanism.CLAMP_TRAVEL/mechanism.GUIDE_RADIUS)<.01,"guide wheel phase follows rope travel")
 mechanism.set_basket_rise(mechanism.basket_travel)
 check(absf(mechanism.basket.position.y-basket_rest.y+mechanism.basket_travel)<.01,"basket reaches unloading plane")
 check(absf(mechanism.crown_wheel.rotation+mechanism.basket_travel/44.0)<.01,"crown wheel phase follows rope travel")
 mechanism.reset_pose()
 check(mechanism.moving_clamp.position==clamp_rest and mechanism.basket.position==basket_rest,"mechanism test restores static art pose")
 var reference=room.scenery.SOURCE.get_image()
 var cached:Array=[]
 for view in room.scenery.cached_views:cached.append(view.get_texture().get_image())
 var worst:=0.0;var worst_at:=Vector2i.ZERO;var worst_values:Array=[]
 var far_worst:=0.0
 for y in range(20,921,23):
  for x in range(140,1650,23):
   var composite:=Color(0,0,0,0)
   var values:Array=[]
   for plane in cached:
    var c:Color=plane.get_pixel(x,y);values.append([c.r,c.g,c.b,c.a])
    composite=Color(c.r+composite.r*(1-c.a),c.g+composite.g*(1-c.a),c.b+composite.b*(1-c.a),c.a+composite.a*(1-c.a))
   var expected:Color=reference.get_pixel(x,y).srgb_to_linear()
   var error:=maxf(absf(composite.r-expected.r),maxf(absf(composite.g-expected.g),absf(composite.b-expected.b)))
   if cached[3].get_pixel(x,y).a<.001 and cached[4].get_pixel(x,y).a<.001:far_worst=maxf(far_worst,error)
   if error>worst:worst=error;worst_at=Vector2i(x,y);worst_values=values
 var diagnostic=FileAccess.open(output+"/layer-reconstruction.json",FileAccess.WRITE)
 diagnostic.store_string(JSON.stringify({"near_plane_reink":true,"worst_far":far_worst,"worst_source_difference":worst,"at":str(worst_at),"planes":worst_values},"  "))
 check(far_worst<.001,"near-plane ink change must preserve the authored far values")
 print("SOURCE DIFFERENCE AFTER NEAR-PLANE REINK ",worst," at ",worst_at)
 var dark_structure:Image=room.scenery.cached_views[3].get_texture().get_image()
 for point:Vector2i in [Vector2i(207,450),Vector2i(258,650),Vector2i(360,470)]:
  var c:Color=dark_structure.get_pixelv(point)
  if c.a>.99:check(maxf(c.r,maxf(c.g,c.b))<.0003,"opaque interactive structure must share the actor's dense ink")
 await shot("00-normal-entry")
 if OS.get_environment("INKFALL_PAIR_INTERACTIVE")=="1":
  print("MINE PAIR INTERACTIVE STATIC REVIEW READY");return
 if OS.get_environment("INKFALL_REVIEW_HOLD")=="1":await create_timer(30).timeout
 for station:int in [2,3,4,1]:
  var event:=InputEventKey.new();event.physical_keycode=KEY_1+station-1;event.keycode=event.physical_keycode;event.pressed=true
  Input.parse_input_event(event);await frames(1)
  event=InputEventKey.new();event.physical_keycode=KEY_1+station-1;event.keycode=event.physical_keycode;event.pressed=false;Input.parse_input_event(event)
  await frames(100)
  await shot("0"+str(station)+"-station")
 # Inspect the descending transition itself, rather than only flat decks.
 var stair_x:=375.0
 var stair_y:float=room.floor_y(stair_x)
 level.player.position=Vector2(stair_x-13,stair_y-55);level.player.velocity=Vector2.ZERO
 level.bridge_to_c.fall_origin=stair_y
 await frames(100)
 check(level.bridge_to_c.failure_time==0,"stair lighting inspection must have real support")
 check(level.player.is_on_floor() and absf(level.bridge_to_c.feet().y-stair_y)<10,"stair inspection must remain supported after scenery collision cleanup")
 await shot("05-stair-passage")
 # The clamp shoes must actually intersect the opaque cart lip, then
 # clear it on lifting. Checking only node displacement misses floating art.
 check(room.carts[0].get_script()==level.bridge_to_c.art.cart_visual.get_script(),"all three cars must use the same original cart visual")
 for side:float in [-1.0,1.0]:
  var shoe_x:float=mechanism.moving_clamp.position.x+side*54.0*mechanism.moving_clamp.scale.x
  var rest_hit:=false;var raised_hit:=false
  for offset in range(0,21):
   var at:=Vector2(shoe_x,mechanism.moving_clamp.position.y+offset)
   rest_hit=rest_hit or opaque_at(room.carts[0],at)
   raised_hit=raised_hit or opaque_at(room.carts[0],at-Vector2(0,mechanism.CLAMP_TRAVEL))
  check(rest_hit,"both restraint shoes must bear on opaque cart rim")
  check(not raised_hit,"raised restraint must clear cart rim")
 check(absf(mechanism.basket.position.y+26-room.lower_floor_y(mechanism.basket.position.x))<.1,"basket bottom must rest on the actual floor")
 mechanism.set_restraint_rise(mechanism.CLAMP_TRAVEL)
 await frames(3);await shot("06-restraint-raised")
 mechanism.reset_pose();await frames(3);await shot("07-restraint-closed")
 await frames(90);await shot("08-lamps-later")
 var record={"film_count":films.size(),"film_visible":films[0].visible if films.size()>0 else false,"softness":films[0].lens_material.get_shader_parameter("environment_softness") if films.size()>0 else -1,"viewport":str(root.get_visible_rect()),"wall":room.scenery.SOURCE.resource_path,"camera":str(level.camera.position),"puzzle_static":true,"ambient_lamps_sway":true}
 var file=FileAccess.open(output+"/actual-entry.json",FileAccess.WRITE);file.store_string(JSON.stringify(record,"  "))
 print("MINE PAIR MAIN ENTRY ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
