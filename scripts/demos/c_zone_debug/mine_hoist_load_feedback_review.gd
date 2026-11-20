extends "res://scripts/demos/c_zone_debug/mine_hoist_steel_cable_review.gd"
func cable_error()->float:
 var points:PackedVector2Array=rig.basket_rope.points
 return absf(points[-1].x-points[-2].x)
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 room=level.bridge_to_c.mine_trial.gap.art.pair_room;rig=room.scenery.mechanisms
 level.set_physics_process(false)
 var h=room.hoist
 for fraction in [0.,.5,1.]:
  h.reset();h.rise=rig.basket_travel*fraction;h.target_top=fraction>.5
  h._present_basket()
  check(cable_error()<.001,"resting cable must hang vertically at every height")
 # Settle at top, load and unload with the same world integrator as gameplay.
 h.rise=rig.basket_travel;h.target_top=true;h.location=h.Location.BASKET
 h.tick_world(1.0/60)
 check(h.was_loaded and h.load_pulse>0,"loading must produce a tension response")
 for i in 600:h.tick_world(1.0/60)
 check(cable_error()<.05,"loaded dock must settle vertically")
 h.location=h.Location.ARMS;h.tick_world(1.0/60)
 check(not h.was_loaded and h.load_pulse<0,"unloading must release tension")
 var peak:=0.0
 for i in 240:
  h.tick_world(1.0/60);peak=maxf(peak,absf(h.sway))
  var path:PackedVector2Array=rig.basket_rope.points
  check(rig.basket_rope.to_global(path[-1]).distance_to(rig.basket.to_global(Vector2(0,-84)))<.001,"unload rebound must keep cable attached")
 check(peak>.0005,"unloading must have visible but restrained settling motion")
 check(cable_error()<.15 and absf(h.sway_speed)<.001,"empty basket must return vertical after unloading")
 check(absf(rig.basket.position.y+26-room.MID_Y)<.1,"docked basket must not float after unloading")
 if DisplayServer.get_name()!="headless":
  level.camera_x=-770;level.camera_y=-3560;level.camera.position=Vector2(-130,-3200)
  level.bridge_to_c._present(0)
  await frames(4)
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image()
  var directory:="res://artifacts/mine-hoist-load-feedback-v2/game"
  DirAccess.make_dir_recursive_absolute(directory)
  var raw:=FileAccess.open(directory+"/empty-docked.linear",FileAccess.WRITE);raw.store_buffer(image.get_data());raw.close()
  var meta:=FileAccess.open(directory+"/empty-docked.json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[image.get_width(),image.get_height()],"format":image.get_format()}));meta.close()
 print("MINE HOIST LOAD FEEDBACK ","FAIL" if failed else "PASS"," peak=",peak," cable_error=",cable_error())
 quit(1 if failed else 0)
