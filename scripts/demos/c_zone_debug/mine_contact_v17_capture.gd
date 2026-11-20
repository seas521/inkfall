extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
var peak_physics_ms:=0.0
func shot(label:String)->void:
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-contact-unified-v17/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(830,1140,true);await shot("00-arranged")
 await wind();await board(1)
 var hammer_seen:=false;var carts_seen:=false;var after:=false
 for i in 800:
  await frames(1)
  peak_physics_ms=maxf(peak_physics_ms,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
  if not hammer_seen and float(relay.last_hammer_contact.get("incoming",0))>0:
   hammer_seen=true;await shot("01-hammer-contact")
  if not carts_seen and relay.contact_age>=0:
   carts_seen=true;await shot("02-cart-contact")
  if carts_seen and not after and relay.contact_age<0:
   after=true;await shot("03-carts-separating")
  if relay.cart_landed or route.failure_time>0:break
 check(relay.cart_landed and hammer_seen and carts_seen,"unified real scene must show hammer, buffers and a successful weighted flight")
 await shot("04-landed")
 await setup_pair(400,980,false);room.restraint_cleared=true
 await warp(Vector2(1180,room.TRACK_Y));await frames(30)
 relay.angle=1.1;relay.angular_speed=0;relay.pendulum_live=true;relay.state=relay.State.SWINGING
 for i in 180:
  await frames(1)
  if relay.last_hammer_contact.get("cart",-1)==1:break
 check(relay.last_hammer_contact.get("kind","")=="roof","same solver must produce the downward roof contact")
 await shot("05-roof-contact");await frames(8);await shot("06-roof-recoil")
 print("UNIFIED SCENE peak_physics_monitor_ms=",peak_physics_ms)
 print("MINE CONTACT V17 VISUAL ","FAIL" if failed else "PASS");quit(1 if failed else 0)
