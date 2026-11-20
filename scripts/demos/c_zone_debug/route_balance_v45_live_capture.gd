extends "res://scripts/demos/c_zone_debug/route_balance_v45_capture.gd"
func run()->void:
 phase="live"
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false
 place(Vector2(S.CLIFF_X-700.,S.ground_top(S.CLIFF_X-700.)))
 await frames(80);level.set_physics_process(false);await snap("cliff-standing")
 level.enter_mine_cart_pair_test();level.set_physics_process(true)
 await frames(130);level.set_physics_process(false);await snap("mine-standing",true)
 route.in_c_zone=true;route.active=false;level.log_bridge.active=false
 route.prepare_c_zone_preview();level.debug_enter_marsh_act();route.art.sync(0)
 place(Vector2(2890.,430.));level.set_physics_process(true)
 await frames(100);level.set_physics_process(false);await snap("valley-standing")
 print("ROUTE FOCUS V45 LIVE CAPTURE COMPLETE");quit()
