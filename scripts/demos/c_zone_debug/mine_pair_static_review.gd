extends SceneTree
var level
var route
var room
var report:Array=[]
var failed:=false
var output_dir:=OS.get_environment("INKFALL_PAIR_REVIEW_DIR")
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,label:String)->void:
 if not ok:failed=true;push_error(label)
func capture(label:String,feet:Vector2,center:Vector2,zoom_value:float=1)->void:
 level.process_mode=Node.PROCESS_MODE_INHERIT
 level.player.velocity=Vector2.ZERO;level.player.position=feet-Vector2(13,54)
 level.bridge_to_c.fall_origin=feet.y;await frames(25)
 check(route.failure_time==0,"static inspection position must have real support: "+label)
 var actual:Vector2=route.feet()
 check(absf(actual.y-feet.y)<8,"art contact plane must match collider: "+label+str(actual-feet))
 level.process_mode=Node.PROCESS_MODE_DISABLED
 level.camera.zoom=Vector2.ONE*zoom_value
 level.camera.position=center;level.camera.offset=Vector2.ZERO;level.camera.force_update_scroll()
 level.camera_x=center.x-640/zoom_value;level.camera_y=center.y-360/zoom_value
 room.tick(0)
 await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  var img=root.get_texture().get_image();
  if root.use_hdr_2d:
   img.convert(Image.FORMAT_RGB8);img.linear_to_srgb()
  img.resize(1280,720,Image.INTERPOLATE_LANCZOS)
  img.save_png(output_dir+"/"+label+".png")
 report.append({"label":label,"feet":[actual.x,actual.y],"center":[center.x,center.y],"zoom":zoom_value})
 level.camera.zoom=Vector2.ONE
func run()->void:
 if output_dir.is_empty():output_dir="res://artifacts/mine-pair-integration-v1"
 DirAccess.make_dir_recursive_absolute(output_dir)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room
 await frames(25)
 check(room.carts.size()==2,"exactly two parked full-size carts")
 check(route.mine_trial.gap.bank.collision_layer==0,"old solid bank must not fill the shaft")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  var live:=root.get_texture().get_image();
  if root.use_hdr_2d:
   live.convert(Image.FORMAT_RGB8);live.linear_to_srgb()
  live.resize(1280,720,Image.INTERPOLATE_LANCZOS)
  live.save_png(output_dir+"/00-live-camera.png")
 await capture("01-entry",Vector2(-540,room.MID_Y),Vector2(-475,-3140))
 await capture("02-main-deck",Vector2(70,room.MID_Y),Vector2(0,-3180))
 await capture("03-lower-adit",Vector2(0,room.lower_floor_y(0)),Vector2(-80,room.LOWER_Y-140))
 await capture("04-track-terrace",Vector2(740,room.TRACK_Y),Vector2(600,room.TRACK_Y-150))
 await capture("05-upper-service",Vector2(-380,room.UPPER_Y),Vector2(-210,room.UPPER_Y-80))
 await capture("06-overview",Vector2(70,room.MID_Y),Vector2(170,-3074),.73)
 level.process_mode=Node.PROCESS_MODE_INHERIT
 # Walk in from the earned bank checkpoint through the mid-level room.
 level.player.position=Vector2(-580-13,room.MID_Y-55);level.player.velocity=Vector2.ZERO
 await frames(20);Input.action_press("move_right")
 for i in 500:
  await frames(1)
  if route.feet().x>285:break
 Input.action_release("move_right")
 check(route.failure_time==0 and route.feet().x>285,"walk past sign, ladder and all main-deck posts without jumping: "+str(route.feet()))
 Input.action_press("move_left")
 for i in 500:
  await frames(1)
  if route.feet().x< -575:break
 Input.action_release("move_left")
 check(route.failure_time==0 and route.feet().x< -575,"return through main-deck decoration without jumping: "+str(route.feet()))
 # Lower ladder plinth and tool racks are also scenery, not small walls.
 level.player.position=Vector2(-420-13,room.lower_floor_y(-420)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=room.lower_floor_y(-420)
 await frames(20);Input.action_press("move_right")
 for i in 500:
  await frames(1)
  if route.feet().x>150:break
 Input.action_release("move_right")
 check(route.failure_time==0 and route.feet().x>150,"walk past lower ladder and tool rack without jumping: "+str(route.feet()))
 # Stair angle is steeper than the generic forest slope limit. Both
 # directions must work after removing the accidental stair art collider.
 level.player.position=Vector2(270-13,room.MID_Y-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=room.MID_Y
 await frames(20);Input.action_press("move_right")
 for i in 240:
  await frames(1)
  if route.feet().x>460:break
 Input.action_release("move_right")
 check(route.failure_time==0 and route.feet().x>460 and absf(route.feet().y-room.TRACK_Y)<10,"walk down stairs to rail without falling through: "+str(route.feet()))
 Input.action_press("move_left")
 for i in 240:
  await frames(1)
  if route.feet().x<280:break
 Input.action_release("move_left")
 check(route.failure_time==0 and route.feet().x<280 and absf(route.feet().y-room.MID_Y)<10,"walk back up stairs without jumping: "+str(route.feet()))
 for station:int in [1,2,3,4]:
  var key:=InputEventKey.new();key.physical_keycode=KEY_1+station-1;key.keycode=key.physical_keycode;key.pressed=true
  Input.parse_input_event(key);await frames(25)
  key=InputEventKey.new();key.physical_keycode=KEY_1+station-1;key.keycode=key.physical_keycode;key.pressed=false;Input.parse_input_event(key)
  var expected:float=[room.MID_Y,room.UPPER_Y,room.lower_floor_y(0),room.TRACK_Y][station-1]
  check(absf(route.feet().y-expected)<8,"debug art station must reach its real platform: "+str(station))
 # Ambient fixtures may sway; puzzle mechanisms remain at their rest pose.
 for node in room.lamps:check(node.elapsed>0,"all near and rear lamps must simulate their suspension")
 check(room.scenery.mechanisms.clamp_rise==0 and room.scenery.mechanisms.basket_rise==0,"ambient lamps must not activate puzzle mechanisms")
 room.set_enabled(false)
 for body in room.bodies:check(body.collision_layer==0,"disabled scene must release all collision")
 room.set_enabled(true)
 var f:=FileAccess.open(output_dir+"/review.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print("MINE PAIR STATIC ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
