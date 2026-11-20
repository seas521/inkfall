extends "res://scripts/demos/c_zone_debug/mine_hoist_steel_cable_review.gd"
var rope
func deviation()->float:
 var a:Vector2=rope.points[-2];var b:Vector2=rope.points[-1]
 var peak:=0.0
 for i in range(rope.points.size()-2,rope.rendered_points.size()):
  var point:Vector2=rope.rendered_points[i]
  peak=maxf(peak,point.distance_to(Geometry2D.get_closest_point_to_segment(point,a,b)))
 return peak
func connections()->void:
 check(rope.rendered_points[0].distance_to(rig.drum_takeoff)<.001,"hemp must start at drum surface")
 check(rope.to_global(rope.rendered_points[-1]).distance_to(rig.basket.to_global(Vector2(0,-84)))<.001,"flexing hemp must remain tied to basket")
 for i in range(1,rope.points.size()-1):
  check(rope.rendered_points[i].distance_to(rope.points[i])<.001,"rope must remain seated on sheave")
func capture(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 level.camera_x=-770;level.camera_y=-3560;level.camera.position=Vector2(-130,-3200)
 level.bridge_to_c._present(0)
 await frames(3);await RenderingServer.frame_post_draw
 var dir:="res://artifacts/mine-hoist-hemp-v3/game";DirAccess.make_dir_recursive_absolute(dir)
 var im:=root.get_texture().get_image()
 var raw:=FileAccess.open(dir+"/"+name+".linear",FileAccess.WRITE);raw.store_buffer(im.get_data());raw.close()
 var meta:=FileAccess.open(dir+"/"+name+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[im.get_width(),im.get_height()],"format":im.get_format()}));meta.close()
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 room=level.bridge_to_c.mine_trial.gap.art.pair_room;rig=room.scenery.mechanisms;rope=rig.basket_rope
 level.set_physics_process(false)
 var h=room.hoist;h.reset();h.rise=rig.basket_travel;h.target_top=true;h._present_basket()
 rope.tick_motion(1.0/60,false,0)
 check(deviation()<.001,"unforced rope should settle straight")
 var loaded_peak:=0.0
 for i in 90:
  rope.tick_motion(1.0/60,true,0);connections();loaded_peak=maxf(loaded_peak,deviation())
  if i==10:await capture("01-taking-load")
 check(loaded_peak>.15 and loaded_peak<8,"load must make restrained flexible waves")
 for i in 360:rope.tick_motion(1.0/60,true,0)
 check(deviation()<.02,"loaded rope should tighten and settle")
 var empty_peak:=0.0
 for i in 90:
  rope.tick_motion(1.0/60,false,0);connections();empty_peak=maxf(empty_peak,deviation())
  if i==10:await capture("02-releasing-load")
 check(empty_peak>loaded_peak,"releasing tension must show a softer empty rope response")
 for i in 360:rope.tick_motion(1.0/60,false,0)
 check(deviation()<.02,"empty rope must return straight, not retain a sideways bow")
 var before:int=rope.redraws
 for i in 120:rope.tick_motion(1.0/60,false,0)
 check(rope.redraws==before,"settled rope should not redraw every frame")
 # Same acceleration / stop profile at two frame rates must stay stable.
 var results:=[]
 for rate in [60.,120.]:
  rope.reset_motion();rope.tick_motion(1/rate,false,0)
  var peak:=0.0
  for i in int(rate*2):
   var time:float=float(i)/rate
   var speed:float=60*time if time<1 else maxf(0,60-(time-1)*60)
   rope.tick_motion(1/rate,false,speed);peak=maxf(peak,deviation());connections()
  results.append(peak)
 check(absf(results[0]-results[1])<.2,"rope waves must be stable across frame rates")
 var out:=FileAccess.open("res://artifacts/mine-hoist-hemp-v3/review.json",FileAccess.WRITE)
 out.store_string(JSON.stringify({"passed":not failed,"loaded_peak":loaded_peak,"empty_peak":empty_peak,"rate_peaks":results},"  "))
 print("MINE HEMP ROPE ","FAIL" if failed else "PASS"," load=",loaded_peak," empty=",empty_peak," frame_rates=",results)
 quit(1 if failed else 0)
