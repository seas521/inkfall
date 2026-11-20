extends "res://scripts/demos/c_zone_debug/valley_production_v42_capture.gd"
var failed:=false
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func run()->void:
 phase="coverage"
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
 route.in_c_zone=true;route.active=false;level.log_bridge.active=false
 route.prepare_c_zone_preview();level.debug_enter_marsh_act();route.art.sync(0)
 level.set_physics_process(false)
 for x in [8000.,10000.]:
  place(Vector2(x,level.forest.ground_y(x)));await snap("upper-C-"+str(int(x)))
  check(level.art.valley_depth.visible,"background must extend through the upper C forest")
 # Verify actual walking, not just camera teleports, with the new art present.
 place(Vector2(240,level.ground_y(240)));level.set_physics_process(true)
 await frames(8)
 var start_x:float=level.player.position.x
 var start_cam:float=level.camera_x
 var backdrop=level.art.valley_depth
 var start_tree:Vector2=backdrop.trees[6].sprite.position
 Input.action_press("move_right");await frames(65);Input.action_release("move_right")
 var travel:float=level.player.position.x-start_x
 var camera_travel:float=level.camera_x-start_cam
 var actual:float=start_tree.x-backdrop.trees[6].sprite.position.x
 var expected:float=camera_travel*backdrop.trees[6].ratio
 check(travel>50,"new decorative art must not obstruct normal walking")
 check(absf(actual-expected)<1.,"middle trees must scroll continuously at their own depth")
 level.set_physics_process(false);await snap("walking-river-bank")
 check(level.art.valley_near.trees.is_empty(),"player plane must remain clear of new rear trunks")
 check(level.art.valley_front.trees.size()==1,"only one sparse foreground accent is intended")
 check(get_nodes_in_group("film_look").size()==1,"retain the one shared film pass")
 print("VALLEY V42 MOTION ","FAIL" if failed else "PASS"," walk=",travel," parallax_error=",actual-expected)
 quit(1 if failed else 0)
