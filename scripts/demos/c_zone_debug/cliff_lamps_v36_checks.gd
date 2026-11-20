extends SceneTree
var failed:=false
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func run()->void:
 var level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level);await frames(15)
 level.debug_enter_rope_ladder(false);await frames(5)
 var route=level.bridge_to_c
 check(route.art.mountain.material!=null,"geology shader must be ready before the descent")
 Input.action_press("climb_down")
 var entering_frames:=0
 for i in 650:
  await frames(1)
  # Its ridge is already in the render pre-roll while the old cull box
  # still excluded it. Visibility cannot be left stale until y=-4840.
  if level.camera_y> -5000 and level.camera_y< -4840:
   entering_frames+=1
   check(route.art.mountain.is_visible_in_tree(),"visible/pre-visible rock cannot wait for the lower mine-room cull box")
 Input.action_release("climb_down")
 check(entering_frames>80,"test must exercise the former delayed activation region")
 check(route.failure_time==0,"descending the ladder must remain playable")
 print("EARLY ROCK REVEAL PASS frames=",entering_frames)
 level.rope_ladder.stop();level.enter_mine_cart_gap_test();await frames(10)
 route.art.chamber.set_collapse(-1);route.art.chase_chamber.set_collapse(-1)
 var fixtures=[route.art.chamber.lamp,route.art.chase_chamber.lamp,route.mine_trial.escape.chase_lamp,route.mine_trial.escape.end_lamp]
 for lamp in fixtures:
  lamp.restore_fixture()
  var chamber=route.art.chamber if lamp.position.x< -2220 else route.art.chase_chamber
  var roof:float=chamber.ceiling_y(lamp.global_position.x)
  check(lamp.global_position.y<=roof-8.,"each cable pivot must embed in actual rock")
  for i in 180:
   lamp.update_swing(1./60.)
   var wire_tip:Vector2=lamp.swing.to_global(Vector2(0,lamp.cable_length))
   var fixture_top:Vector2=lamp.fixture.to_global(Vector2(lamp.fixture.texture.get_width()*.5,0))
   check(wire_tip.distance_to(fixture_top)<.001,"cable and housing must remain connected through swing")
  print("ROOTED LAMP ",{"x":lamp.position.x,"roof_gap":roof-lamp.position.y,"cable":lamp.cable_length})
 check(route.art.chase_chamber.lamp.cable_length>100.,"penultimate fixture needs the actual longer ceiling cable")
 print("CLIFF AND LAMP V36 ","FAIL" if failed else "PASS")
 quit(1 if failed else 0)
