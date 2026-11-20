extends "res://scripts/demos/c_zone_debug/mine_cart_interaction_matrix_review.gd"
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8)
 level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;gap=trial.gap;escape=trial.escape
 check(route.art.cart_visual.grip_outline.size()>3,"actual mesh silhouette must exist")
 for x:float in [-1335,-1125]:
  for side:float in [-1,1]:
   await setup(x)
   var px:float=x+side*54
   level.player.position=Vector2(px-13,trial.ground(px)-55);await frames(20)
   Input.action_press("interact");await frames(25)
   for axis:float in [-1,0,1]:
    Input.action_release("move_left");Input.action_release("move_right")
    if axis<0:Input.action_press("move_left")
    if axis>0:Input.action_press("move_right")
    var worst:=0.;var min_offset:=INF;var max_offset:=-INF
    for i in 90:
     await frames(1)
     var actor=level.actor
     var hand:Vector2=actor.grip_hand_world()
     var target:Vector2=route.art.cart_visual.grip_surface(escape.cart_position(),escape.visual_motion(),hand.y,side)
     worst=maxf(worst,hand.distance_to(target));min_offset=minf(min_offset,actor.body.position.x);max_offset=maxf(max_offset,actor.body.position.x)
     check(trial.operation=="recover","push/pull must retain grip")
     check(actor.current_clip in [&"grip_hold",&"grip_engage",&"push",&"pull",&"grip_to_pull"],"real grip clip must be active")
    var row={"x":x,"side":side,"axis":axis,"max_hand_error":worst,"body_offset_min":min_offset,"body_offset_max":max_offset}
    print(JSON.stringify(row));rows.append(row)
    check(worst<1.5,"palms must stay on cart across push/pull/hold: "+JSON.stringify(row))
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     var image:=root.get_texture().get_image()
     image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
     image.save_png("res://artifacts/mine-cart-hand-contact-v1/contact-%d-%d-%d.png"%[int(x),int(side),int(axis)])
   keys_up();await frames(1)
 var f:=FileAccess.open("res://artifacts/mine-cart-hand-contact-v1/contact.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
 print("CART HAND CONTACT ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
