extends "res://scripts/demos/c_zone_debug/mine_directional_pendulum_review.gd"
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-slider-control-v9/game"
 DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func pull(side:float,seconds:float=6.5)->void:
 await warp(Vector2(relay.LEVER.x+side*56,room.TRACK_Y))
 Input.action_press("interact")
 var max_gap:=0.0
 var low:=INF;var high:=-INF
 for i in int(seconds*60):
  await frames(1)
  if relay.lever_contact:
   max_gap=maxf(max_gap,relay.hand_gap)
   var palm:Vector2=relay.slider_palm_world()
   low=minf(low,palm.y-room.TRACK_Y);high=maxf(high,palm.y-room.TRACK_Y)
   check(palm.y>=room.TRACK_Y-43.5 and palm.y<=room.TRACK_Y-27,"native palm must lie inside the visible grip bar")
  if i==52:await shot("moving-left" if side<0 else "moving-right")
 check(max_gap<.2,"actual tracked palm must remain on handle throughout loaded movement")
 check(absf(relay.angle-side*relay.MAX_ANGLE)<.025,"full slide must haul to the selected side")
 check(relay.charge_owner,"player must retain grip at the stop")
 await shot("left-haul" if side<0 else "right-haul")
 print("SLIDER CONTACT ",side," max_gap=",max_gap," palm heights=",Vector2(low,high))
 var angle:float=relay.angle;var omega:float=relay.angular_speed
 relay._release_hammer();Input.action_release("interact")
 check(relay.angle==angle and relay.angular_speed==omega,"release must preserve pendulum momentum")
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(1350,1550,false)
 await warp(Vector2(relay.LEVER.x-56,room.TRACK_Y));await frames(30)
 await shot("00-neutral")
 for side in [-1.0,1.0]:
  await pull(side,6.5)
  check(absf(absf(relay.slider_position)-relay.SLIDER_TRAVEL)<.1,"carriage must meet the end stop")
  check(relay.slider_lamp>.95,"full travel must illuminate central indicator")
  var sm:ShaderMaterial=relay.art.slider_sprite.material
  check(float(sm.get_shader_parameter("lamp_left" if side<0 else "lamp_right"))>.95,"only the reached direction arrow must illuminate")
  check(float(sm.get_shader_parameter("lamp_right" if side<0 else "lamp_left"))==0.0,"opposite arrow must remain dark")
  await frames(90)
  check(absf(relay.slider_position)<.1,"released carriage must spring smoothly back to neutral")
  check(relay.slider_lamp<.01,"neutral indicator must be unlit")
  await shot("return-left" if side<0 else "return-right")
 print("MINE SLIDER V9 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
