extends "res://scripts/demos/c_zone_debug/mine_relay_v2_routes_review.gd"
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/valley-return-vegetation-v25/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func walk_across(right:bool,target:float)->void:
 Input.action_press("move_right" if right else "move_left")
 var crossed:=false
 for i in 1100:
  var was_c:bool=route.in_c_zone
  var before:Vector2=route.feet()-Vector2(level.camera_x,level.camera_y)
  var velocity:Vector2=level.player.velocity
  var boat_before:Vector2=level.art.global_position+level.art.crate_art.position-Vector2(level.camera_x,level.camera_y)
  await frames(1)
  if was_c!=route.in_c_zone:
   crossed=true
   check((route.feet()-Vector2(level.camera_x,level.camera_y)).distance_to(before)<10,"bidirectional handoff must preserve screen position")
   check(level.player.velocity.distance_to(velocity)<35,"bidirectional handoff must preserve walking velocity")
   var boat_after:Vector2=level.art.global_position+level.art.crate_art.position-Vector2(level.camera_x,level.camera_y)
   check(boat_before.distance_to(boat_after)<12,"boat must stay in the same screen position across the preview/handoff")
  check(route.failure_time==0 and level.death_time==0 and level.marsh_hit_time==0,"return bank must not trigger old forest death logic")
  var x:float=route.feet().x+(3600 if route.in_c_zone else 0)
  if (right and x>target) or (not right and x<target):break
 release();await frames(8)
 check(crossed,"walking must cross the mine/C boundary in the selected direction")
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(830,1140,false);await wind();await approach_and_board(1)
 await await_landing("empty-approach");await frames(210)
 Input.action_press("jump");Input.action_press("move_right");await frames(40);release()
 await frames(20);await shot("01-planted-landing")
 check(route.c_zone_prepared and level.crate.position.distance_to(level.CRATE_START)<1,"boat must already occupy its final C entry position before walking out")
 await walk_across(true,3500);check(route.in_c_zone,"forward crossing enters C")
 check(not level.rock_sequence and not level.limb_broken,"first C entry must rearm the pre-cleared falling-rock trap")
 await shot("02-new-trunk-and-slope")
 level.fan_owned=true;level.checkpoint_fan=true;level.checkpoint=1
 await walk_across(false,3260);check(route.active and not route.in_c_zone,"walking uphill must return to mine")
 await shot("03-returned-uphill")
 await walk_across(true,3500)
 check(level.fan_owned and level.checkpoint==1,"re-entering C must preserve C progress and carried equipment")
 # The actual hill trigger must arm visible falling stones after entry.
 await warp(Vector2(level.ROCK_TRIGGER_X+15,level.marsh_rock_surface_y(level.ROCK_TRIGGER_X+15)))
 await frames(50)
 check(level.rock_sequence and level.marsh_rocks[0].t<10,"C hill must start the real falling-rock sequence")
 var saw_fall:=false
 for i in 130:
  await frames(1)
  if level.marsh_rocks[0].mode in [level.ROCK_FALL,level.ROCK_ROLL]:saw_fall=true;break
 check(saw_fall,"falling rocks must actually leave their waiting state")
 await shot("04-rockfall-restored")
 release();level.death_time=0;level.marsh_hit_time=0
 await warp(Vector2(7035,390));await frames(20);await shot("05-cliff-base")
 # Continuous suspension endpoints retain their actual light height.
 var escape=route.mine_trial.escape
 for fixture in [escape.chase_lamp,escape.end_lamp]:
  var roof:float=route.art.chase_chamber.ceiling_y(fixture.position.x)
  check(fixture.position.y<roof-8,"escape lamp pivot must be embedded in the real rock roof")
  check(fixture.cable_length>52,"continuous cable must span the old unsupported gap")
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  var im:=root.get_texture().get_image()
  for x in [7650.,7700.,7750.]:
   var screen:Vector2=(Vector2(x,650)-Vector2(level.camera_x,level.camera_y))*Vector2(im.get_size())/Vector2(1280,720)
   if Rect2(Vector2.ZERO,im.get_size()).has_point(screen):check(im.get_pixelv(Vector2i(screen)).get_luminance()<.04,"rock beyond the ramp must not expose a rectangular backdrop gap")
  # Inspect the stopping-bay lamp against the actual intact roof.
  await warp(Vector2(-400,relay.exit_scene.ground_y(3200)+3050));await frames(2)
  level.set_physics_process(false)
  route.in_c_zone=false;route.active=true;route.art.sync(0)
  route.art.chase_chamber.set_collapse(-1)
  escape.end_lamp.restore_fixture()
  var fixture=escape.end_lamp
  level.camera_x=fixture.position.x-650;level.camera_y=fixture.position.y-130
  level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
  route.art.sync(0);level.art.sync(0,level.camera_x,true)
  await frames(5);await shot("06-lamp-rooted-in-ceiling")
 print("VALLEY RETURN V25 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
