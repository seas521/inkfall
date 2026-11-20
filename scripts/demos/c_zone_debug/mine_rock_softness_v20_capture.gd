extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func shot(label:String)->void:
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-rock-softness-v20/"+OS.get_environment("INKFALL_ROCK_CAPTURE")
 DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(830,1140,true);await frames(20)
 level.set_physics_process(false)
 var views:=[Vector2(-260,-3040),Vector2(1100,-3060),Vector2(2260,-3080),Vector2(2910,-3060)]
 var names:=["01-hoist-rock","02-launch-bank","03-opposite-bank","04-forest-join"]
 for i in views.size():
  level.camera.position=views[i];level.camera.reset_smoothing();await frames(3)
  await shot(names[i])
 print("ROCK SOFTNESS CAPTURE COMPLETE");quit()
