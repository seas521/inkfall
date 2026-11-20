extends "res://scripts/demos/c_zone_debug/mine_cart_interaction_matrix_review.gd"
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;gap=trial.gap;escape=trial.escape
 for side:float in [-1,1]:
  for delay:int in [0,6,12,24,36]:
   await setup(-1335)
   var px:float=trial.cart_x+side*54
   level.player.position=Vector2(px-13,trial.ground(px)-55);level.player.velocity=Vector2.ZERO;await frames(25)
   Input.action_press("interact");await frames(25)
   check(trial.operation=="recover","release test must start with real grip")
   Input.action_release("interact");await frames(delay)
   if side>0 and delay==24:await capture("release-front-before-jump")
   var key:String="move_right" if side<0 else "move_left"
   Input.action_press(key);Input.action_press("jump")
   var boarded:=false
   for i in 100:
    await frames(1)
    if escape.is_riding():boarded=true;break
   keys_up();await frames(25)
   if side>0 and delay==24:await capture("release-front-seated")
   print("RELEASE BOARD side ",side," delay ",delay," boarded ",boarded," relative ",route.feet()-trial.cart_position()," speed ",trial.cart_speed)
   check(boarded and escape.is_riding(),"released high cart must allow a stable boarding window")
 print("RELEASE BOARD WINDOW ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
