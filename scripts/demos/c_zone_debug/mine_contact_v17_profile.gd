extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
var held_scripts:Array=[]
func _initialize()->void:
 if OS.get_environment("INKFALL_CONTACT_BASELINE")=="1":
  for name in ["mine_cart_relay.gd","mine_cart_pair_room.gd","mine_relay_art.gd"]:
   var script:=GDScript.new()
   script.source_code=FileAccess.get_file_as_string("res://artifacts/mine-contact-unified-v17/before/scripts/chapters/"+name)
   if script.reload()!=OK:quit(2);return
   script.take_over_path("res://scripts/chapters/"+name);held_scripts.append(script)
 call_deferred("run")
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(915,1140,true)
 level.set_physics_process(false)
 relay.angle=-1.28;relay.angular_speed=0;relay.pendulum_live=true;relay.state=relay.State.SWINGING
 var times:Array=[]
 for i in 1800:
  var start:=Time.get_ticks_usec();relay._integrate(1./120);times.append(Time.get_ticks_usec()-start)
 times.sort()
 var stats:Dictionary={"baseline":OS.get_environment("INKFALL_CONTACT_BASELINE")=="1","substep_usec_p50":times[times.size()/2],"substep_usec_p95":times[int(times.size()*.95)],"substep_usec_p99":times[int(times.size()*.99)],"substep_usec_max":times[-1],"substeps":times.size()}
 print("CONTACT PROFILE ",stats)
 var file:=FileAccess.open("res://artifacts/mine-contact-unified-v17/"+("profile-before.json" if stats.baseline else "profile-after.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(stats,"  "))
 quit()
