extends "res://scripts/demos/c_zone_debug/mine_cart_physics_review.gd"
var failed:=false
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(8)
 level.enter_mine_cart_gap_test();route=level.bridge_to_c;trial=route.mine_trial;gap=trial.gap;escape=trial.escape
 var previous_grade:=0.;var maximum_grade_step:=0.
 for i in 5201:
  var x:float=-1620.+float(i)*.1
  var grade:float=(route.mine_floor_base_y(x+.5)-route.mine_floor_base_y(x-.5))/1.0
  if i>0:maximum_grade_step=maxf(maximum_grade_step,absf(grade-previous_grade))
  previous_grade=grade
 check(maximum_grade_step<.003,"recovery crest must have no sharp tangent changes")
 for right in [true,false]:
  await setup(-1100)
  var start:float=-1430 if right else -1195
  var target:float=-1195 if right else -1430
  level.player.position=Vector2(start,trial.ground(start))-Vector2(13,54);level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(start)
  await frames(20)
  var key:="move_right" if right else "move_left"
  Input.action_press(key)
  var stalled:=0;var peak_stalled:=0;var air_frames:=0
  for i in 500:
   var before:float=route.feet().x
   await frames(1)
   if i>20:
    stalled=stalled+1 if absf(route.feet().x-before)<.05 else 0
    peak_stalled=maxi(peak_stalled,stalled)
    if not level.player.is_on_floor():air_frames+=1
   if (route.feet().x-target)*(1 if right else -1)>=0:break
  release_keys()
  check(absf(route.feet().x-target)<5,"walk must cross the rounded crest in both directions")
  check(peak_stalled==0 and air_frames<3,"crest cannot create a repeated collision stall or airborne bump")
  print("CREST WALK ",{"right":right,"end":route.feet(),"stalled":peak_stalled,"air_frames":air_frames})
 print("CREST V33 ","FAIL" if failed else "PASS"," max grade step ",maximum_grade_step)
 quit(1 if failed else 0)
