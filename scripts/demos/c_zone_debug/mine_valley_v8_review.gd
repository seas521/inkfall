extends "res://scripts/demos/c_zone_debug/mine_relay_v2_routes_review.gd"
var transitions:Array=[]
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-valley-exit-v8/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(830,1140,true);await wind();await approach_and_board(1)
 await await_landing("continuous-exit");await frames(220)
 await shot("01-landed")
 Input.action_press("jump");Input.action_press("move_right");await frames(40);Input.action_release("jump")
 var n:=0;var previous_screen:Vector2;var previous_velocity:Vector2
 var last_capture:=-1
 for i in 650:
  previous_screen=route.feet()-Vector2(level.camera_x,level.camera_y)
  previous_velocity=level.player.velocity
  await frames(1)
  var p:Vector2=route.feet()
  if route.in_c_zone:
   var now:Vector2=p-Vector2(level.camera_x,level.camera_y)
   print("HANDOFF screen ",previous_screen," -> ",now," velocity ",previous_velocity," -> ",level.player.velocity," camera ",Vector2(level.camera_x,level.camera_y))
   check(now.distance_to(previous_screen)<8,"coordinate handoff must preserve screen position")
   check(level.player.velocity.distance_to(previous_velocity)<30,"handoff must preserve walking velocity")
   check(relay.exit_scene.detached and relay.cart_detached,"landing and parked cart must remain behind player")
   await shot("05-c-handoff");break
  var part:int=0 if p.x<2800 else (1 if p.x<3080 else (2 if p.x<3350 else 3))
  if part!=last_capture:
   last_capture=part;await shot("walk-"+str(part))
  if level.player.is_on_floor() and p.x>2760:
   n+=1
   check(absf(p.y-relay.exit_scene.ground_y(p.x))<4,"feet must follow the registered bank")
  check(route.failure_time==0,"walk-down must not trigger death")
 release();await frames(80)
 check(route.in_c_zone and level.player.is_on_floor(),"player must walk into existing C forest")
 check(n>120,"exit must include a substantial grounded downhill walk")
 await shot("06-c-forest")
 level.enter_mine_cart_pair_test();await frames(35)
 check(not relay.exit_scene.detached and not relay.cart_detached,"replay must restore exit and cart ownership")
 check(relay.exit_scene.position==Vector2.ZERO,"replay must remove the C coordinate offset")
 check(room.cart_bodies[1].get_parent()==room,"cart collision must return to the room on replay")
 print("MINE VALLEY V8 ","FAIL" if failed else "PASS"," grounded_frames=",n)
 quit(1 if failed else 0)
