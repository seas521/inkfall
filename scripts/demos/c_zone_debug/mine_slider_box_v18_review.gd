extends "res://scripts/demos/c_zone_debug/mine_slider_v9_review.gd"
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-slider-box-v18/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func pull(side:float,seconds:float=6.5)->void:
 await warp(Vector2(relay.LEVER.x+side*relay.SLIDER_STANCE_X,room.TRACK_Y))
 var art=relay.art
 var source:Image=art.slider_sprite.texture.get_image()
 Input.action_press("interact")
 var max_gap:=0.;var missed:=0
 for i in int(seconds*60):
  await frames(1)
  if relay.lever_contact:
   max_gap=maxf(max_gap,relay.hand_gap)
   var pixel:Vector2=art.slider_sprite.to_local(relay.slider_palm_world())+Vector2(source.get_size())*.5
   if not Rect2(Vector2.ZERO,source.get_size()).has_point(pixel) or source.get_pixelv(Vector2i(pixel)).a<.7:missed+=1
  if i==52:await shot("01-moving-left-sparks" if side<0 else "04-moving-right-sparks")
 check(max_gap<.2 and missed==0,"native palm must overlap the actual opaque handle throughout movement: "+str(missed))
 check(absf(relay.angle-side*relay.MAX_ANGLE)<.025,"box must retain directional haul")
 check(absf(absf(relay.slider_position)-relay.SLIDER_TRAVEL)<.1,"box must reach the rail end stop")
 var material:ShaderMaterial=art.slider_sprite.material
 check(float(material.get_shader_parameter("lamp_left" if side<0 else "lamp_right"))>.95,"corresponding direction must light")
 check(float(material.get_shader_parameter("lamp_right" if side<0 else "lamp_left"))==0,"opposite direction must remain unlit")
 check(art.slider_spark_emitted>30,"physical box travel must emit electrical contact sparks")
 var count:int=art.slider_spark_emitted
 await frames(30)
 check(art.slider_spark_emitted==count and art.slider_sparks.is_empty(),"stationary full-stroke box must stop generating sparks")
 await shot("02-left-limit" if side<0 else "05-right-limit")
 relay._release_hammer();Input.action_release("interact");await frames(90)
 check(absf(relay.slider_position)<.1,"box must retain damped return")
 check(art.slider_spark_emitted==count and art.slider_sparks.is_empty(),"unpowered return must not keep arcing")
 print("BOX CONTACT ",side," max_gap=",max_gap," native_alpha_misses=",missed," sparks=",count)
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(1350,1550,false)
 await warp(Vector2(relay.LEVER.x-85,room.TRACK_Y));await frames(40)
 check(float(relay.art.slider_sprite.material.get_shader_parameter("idle_strength"))>.015,"unlit arrows must remain visibly printed")
 await shot("00-idle-gray-arrows")
 await pull(-1);await pull(1)
 await shot("06-return-gray-arrows")
 print("MINE SLIDER BOX V18 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
