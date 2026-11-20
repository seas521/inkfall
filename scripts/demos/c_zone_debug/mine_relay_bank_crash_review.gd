extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func shot(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-relay-crash-v7/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+name+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+name+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for axle in room.carts[1].axles:
  if axle.get_meta("front_axle",false):print("CRASH AXLE WORLD X ",axle.global_position.x)
 await setup_pair(830,1140,false);await wind();await approach_and_board(1)
 for i in 850:
  await frames(1)
  if relay.wrecked:break
 check(relay.wrecked,"underpowered real flight must hit cliff and wreck")
 check(route.failure_time>0 and route.failure_airborne,"passenger must enter fatal airborne fall")
 check(relay.rider<0 and not relay.air_active,"wreck must release passenger without a rescue jump")
 var start:Vector2=relay.cart_at(1);var pitch:float=relay.pitches[1]
 check(relay.flight_velocity.x<0 and relay.wreck_spin>1,"wall impact must recoil and produce overturning torque")
 check(relay.art.wreck_parts.size()>=10,"wreck must shed wheels and fragments")
 await shot("01-impact")
 await frames(7)
 check(relay.wreck_strain>.35,"front body must visibly buckle before dropping")
 check(room.carts[1].wreck_amount>.35,"wreck deformation must reach cart renderer")
 var detached:=0
 for axle in room.carts[1].axles:
  if axle.get_meta("front_axle",false) and not axle.visible:detached+=1
 check(detached==4,"both rendered halves must remove broken front wheels")
 check(room.carts[0].wreck_amount==0,"other cart must keep its original shape")
 await shot("02-buckled-and-wheel-off")
 await frames(12)
 check(relay.cart_at(1).y>start.y+40,"wreck must fall rather than remain against wall")
 check(relay.pitches[1]>pitch+.4,"wreck must overturn while falling")
 await shot("03-overturning")
 await frames(15);await shot("04-falling-away")
 # Let the actual death / checkpoint state machine finish its transition.
 for i in 300:
  await frames(1)
  if route.failure_time==0 and route.respawn_reveal==0 and not relay.wrecked:break
 check(route.failure_time==0 and not relay.wrecked,"real respawn must finish and restore the cart")
 check(room.carts[1].wreck_amount==0,"checkpoint must restore pristine cart mesh")
 for axle in room.carts[1].axles:check(axle.visible,"checkpoint must restore every wheel")
 check(relay.art.wreck_parts.is_empty(),"checkpoint must clear old wreck fragments")
 await board(1)
 check(relay.rider==1,"cart must remain boardable after actual crash respawn")
 print("MINE RELAY BANK CRASH ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
