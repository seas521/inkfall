extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-release-camera-v23/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 for side in [-1.0,1.0]:
  await setup_pair(830,1350,false)
  await warp(Vector2(relay.LEVER.x+side*relay.SLIDER_STANCE_X,room.TRACK_Y))
  Input.action_press("interact")
  for i in 420:
   await frames(1)
   if relay.charge>.995:break
  check(relay.charge_owner,"real input must haul from either slider handle")
  var previous_hit:Dictionary=relay.last_hammer_contact.duplicate()
  Input.action_release("interact");await frames(2)
  check(relay.release_camera_owns() and relay.camera_owns(),"letting go must retain strike camera ownership")
  await shot("release-"+str(int(side)))
  var saw_hit:=false
  for i in 180:
   await frames(1)
   if relay.last_hammer_contact!=previous_hit:
    saw_hit=true
    var origin:=Vector2(level.camera_x,level.camera_y)
    var head:Vector2=relay.PIVOT+Vector2(sin(relay.angle),cos(relay.angle))*relay.LENGTH
    var screen_head:=head-origin
    var screen_cart:Vector2=relay.cart_at(0)-origin
    var screen_player:Vector2=route.feet()-origin
    print("STRIKE CAMERA ",side," head=",screen_head," cart=",screen_cart," player=",screen_player)
    check(screen_head.x>140 and screen_head.x<1140 and screen_head.y>100 and screen_head.y<620,"head must remain clear of vignette during strike")
    check(screen_cart.x>140 and screen_cart.x<1140 and screen_cart.y<640,"struck left cart must be visible")
    check(screen_player.x>110 and screen_player.x<1170,"camera must retain the player")
    await shot("impact-"+str(int(side)));break
  check(saw_hit,"camera review must observe a real post-release hit")
  await frames(180)
  check(not relay.release_camera_owns(),"observation must time out and return camera control")
 # Save an arbitrary layout, then die after moving, flying and damaging
 # the cars. Both scene bodies and drawings must return to fixed homes.
 await setup_pair(900,1500,false);room.restraint_cleared=true;relay._save_attempt()
 room.bays=[1200.,1900.];relay.velocities=[-80.,350.]
 relay.cart_lost=[true,true];relay.airborne=true;relay.wrecked=true
 route.fail()
 for i in 300:
  await frames(1)
  if route.failure_time==0 and not relay.wrecked:break
 await frames(20)
 print("RESPAWN CARTS ",room.bays," velocities=",relay.velocities," airborne=",relay.airborne," wrecked=",relay.wrecked," lost=",relay.cart_lost)
 check(absf(room.bays[0]-relay.STAGE_X)<.01 and absf(room.bays[1]-relay.THIRD_X)<.01,"death must reset both cars instead of restoring the saved arrangement")
 check(absf(relay.velocities[0])<.001 and absf(relay.velocities[1])<.001 and not relay.airborne and not relay.wrecked and not relay.cart_lost.has(true),"respawn must clear cart flight, damage and momentum")
 check(room.restraint_cleared and not room.restraint_locked(),"completed restraint unlock must survive relay death")
 for i in 2:
  check(room.cart_bodies[i].position.distance_to(relay.cart_at(i))<.01 and room.cart_bodies[i].collision_layer==33,"reset collider must coincide with reset cart")
 check(not relay.camera_owns() and route.failure_time==0 and level.player.is_on_floor(),"respawn must clear observation and restore safe normal control")
 await shot("respawn-both-cars-home")
 print("MINE RELEASE CAMERA V23 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
