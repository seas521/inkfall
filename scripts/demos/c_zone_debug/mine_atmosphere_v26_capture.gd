extends "res://scripts/demos/c_zone_debug/valley_return_v25_review.gd"
func shot(label:String)->void:
 await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-atmosphere-v26/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 await setup_pair(830,1140,false)
 level.set_physics_process(false)
 var escape=route.mine_trial.escape
 route.art.chase_chamber.set_collapse(-1);escape.end_lamp.restore_fixture()
 var views:=[Vector2(-570,-3480),Vector2(240,-3470),escape.end_lamp.position-Vector2(650,130)]
 for i in views.size():
  level.camera_x=views[i].x;level.camera_y=views[i].y
  level.camera.position=views[i]+Vector2(640,360)
  for j in 45:
   route.art.sync(0);level.art.sync(0,level.camera_x,true);await frames(1)
  var film=get_nodes_in_group("film_look")[0]
  check(film.mine_amount>.85,"underground diffusion profile must cover the entire mine")
  await shot(["01-hoist-chamber","02-relay-machinery","03-lamp-and-stopping-bay"][i])
 # Exiting to C releases only the mine grade, without altering the common
 # black surround or the forest's established independent film settings.
 route.in_c_zone=true;route.active=false
 for j in 50:level.art.sync(0,level.camera_x,true);await frames(1)
 check(get_nodes_in_group("film_look")[0].mine_amount<.03,"C must retain its own established atmosphere")
 print("MINE ATMOSPHERE V26 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
