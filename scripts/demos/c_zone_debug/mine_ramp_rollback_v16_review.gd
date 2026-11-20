extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-ramp-rollback-v16/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
var baseline:=OS.get_environment("INKFALL_RAMP_BASELINE")=="1"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(1000,1640,false)
 await warp(Vector2(1586,room.TRACK_Y))
 Input.action_press("interact");Input.action_press("move_right")
 var peak:float=room.bays[1];var grip_seen:=false
 for i in 520:
  await frames(1);peak=maxf(peak,room.bays[1]);grip_seen=grip_seen or room.cart_gripped
  if i%120==0:print("RAMP PUSH ",i," x=",room.bays[1]," feet=",route.feet()," grip=",room.cart_gripped," rider=",relay.rider," floor=",level.player.is_on_floor())
 if not baseline:
  check(absf(room.cart_motion_speed)<.1 and room.cart_gripped,"at the force limit cart must settle while player keeps a supported grip")
 var at_release:float=room.bays[1]
 await shot("01-uphill-limit")
 release()
 var start:Vector2=route.feet();var min_v:=0.
 for i in 150:
  await frames(1);min_v=minf(min_v,relay.velocities[1])
  if i==35:await shot("02-rolling-back")
  if i==55:Input.action_press("move_left")
 var end:Vector2=route.feet();release()
 print("RAMP RESULT ",{"peak":peak,"release_x":at_release,"end_x":room.bays[1],"min_v":min_v,"player_from":start,"player_to":end,"rider":relay.rider,"failure":route.failure_time})
 if not baseline:
  check(grip_seen,"real F+right must push the cart")
  check(peak>1690 and peak<1780,"uphill effort must stop before the unsupported steep section")
  check(room.bays[1]<at_release-35 and min_v< -20,"release on the bend must roll downhill under gravity")
  check(relay.rider<0 and not room.cart_gripped,"release must free player rather than attract them into cart")
  check(end.x<start.x-100 and route.failure_time==0,"player must walk safely away")
 if not baseline:
  await setup_pair(1000,1788.75,false)
  level.player.position=Vector2(1737.7,-2915.92)-Vector2(13,54);level.player.velocity=Vector2.ZERO
  Input.action_press("move_left");await frames(150);release()
  check(room.bays[1]<1700 and route.feet().x<1650 and route.failure_time==0,"a previously stranded ramp car must resume gravity and free the player")
  await setup_pair(900,1400,false);await frames(100)
  check(absf(room.bays[0]-900)<.01 and absf(room.bays[1]-1400)<.01,"flat staging placements must remain parked")
 print("MINE RAMP ROLLBACK ","BASELINE" if baseline else ("FAIL" if failed else "PASS"))
 quit(1 if failed else 0)
