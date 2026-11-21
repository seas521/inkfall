extends "res://scripts/demos/c_zone_debug/chapter_light_v54_review.gd"
# Native camera/optical regressions. This never appears in the runtime menu.
func run()->void:
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 output="res://artifacts/plane-contact-v55/cinema-review"
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false;level.set_physics_process(false)
 place(Vector2(-6450,S.ground_top(-6450)))
 for i in 8:level._present(1./60.);await process_frame
 check(is_equal_approx(level.camera.zoom.x,1.),"forest retains the approved traversal framing")
 await capture("01-forest")
 level.enter_mine_cart_pair_test();level.set_physics_process(false)
 var room=route.mine_trial.gap.art.pair_room
 place(Vector2(0,room.MID_Y))
 var before:=1.0
 for i in 150:
  route._present(1./60.)
  var current:float=level.camera.zoom.x
  check(current<=before+.00001 and before-current<.008,"pullback frame %d remains gradual"%i) if i in [0,1,20,149] else pass_check(current<=before+.00001 and before-current<.008)
  before=current;await process_frame
 check(level.camera.zoom.x<.905 and level.camera.zoom.x>.899,"hoist reveals more space without changing the actor scale")
 check((route.mine_trial.masonry.visibility_layer&level.art.valley_player_focus.MASK)!=0,"breakable wall participates in the live gameplay focus")
 var cached:float=level.chapter_framing.target(level)
 level.player.position.y-=70
 check(is_equal_approx(cached,level.chapter_framing.target(level)),"ordinary jumping does not change the camera goal")
 level.player.position.y+=70
 await capture("02-hoist-wide")
 var field=level.art.valley_player_light
 var inverse:Transform2D=level.get_canvas_transform().affine_inverse()
 var origin:Vector2=field.light_material.get_shader_parameter("world_origin")
 check(origin.distance_to(inverse*Vector2.ZERO)<.1,"shared lighting uses the zoomed camera inverse")
 var focal=level.art.valley_player_focus
 var mask_ratio:Vector2=Vector2(focal.mask_view.size)/level.get_viewport_rect().size
 check(focal.mask_view.canvas_transform.origin.distance_to((Transform2D(Vector2(mask_ratio.x,0),Vector2(0,mask_ratio.y),Vector2.ZERO)*level.get_canvas_transform()).origin)<.1,"coverage remains registered under the pullback")
 route.respawn_reveal=.2;route._sync_death_iris()
 var iris_centre:Vector2=level.iris.material.get_shader_parameter("center")
 var expected_centre:Vector2=level.get_canvas_transform()*(route.feet()-Vector2(0,27))/level.get_viewport_rect().size
 check(iris_centre.distance_to(expected_centre)<.001,"respawn iris stays on the actor at the actual window scale")
 route.respawn_reveal=0.;route._sync_death_iris()
 place(Vector2(1080,room.TRACK_Y))
 var relay=room.relay
 relay.charge_owner=true
 for i in 40:route._present(1./60.);await process_frame
 var centre:Vector2=level.camera.position
 level.sync_chapter_camera(1./60.)
 check(level.camera.position.is_equal_approx(centre),"optical framing does not fight the relay event centre")
 relay.charge_owner=false
 await capture("03-relay-wide")
 # Return to normal before the authored handoff, without an instantaneous snap.
 place(Vector2(2700,relay.EXIT_Y))
 for i in 220:route._present(1./60.);await process_frame
 check(level.camera.zoom.x>.999,"mine exit settles to traversal scale before the valley")
 level.enter_valley_test();level.set_physics_process(false)
 place(Vector2(6800,392))
 for i in 60:level._present(1./60.);await process_frame
 check(level.camera.zoom.x>.999,"valley keeps the approved canvas coverage")
 await capture("04-valley-light")
 level.hide()
 for i in 4:await process_frame
 check(not field.visible and not focal.enabled,"leaving gameplay releases optical receiver views")
 var file:=FileAccess.open(output+"/result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failed":failed}));file.close()
 print("CINEMA V55 ","FAIL" if failed else "PASS"," checks=",checks)
 level.queue_free();await frames(3);quit(1 if failed else 0)
func pass_check(ok:bool)->void:
 if not ok:check(false,"intermediate camera frame is continuous")
