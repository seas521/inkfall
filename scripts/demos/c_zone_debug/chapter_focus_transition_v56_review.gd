extends "res://scripts/demos/c_zone_debug/chapter_visual_v55_review.gd"
# Continuous optical-boundary review, not a legal gameplay traversal.
func run()->void:
 output="res://artifacts/carcass-focus-v56/transitions"
 DirAccess.make_dir_recursive_absolute(output)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(18);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false;level.set_physics_process(false)
 place(Vector2(-3610,-3870))
 for i in 12:level._present(DT);await process_frame
 var focus=level.art.valley_player_focus
 check((route.swing_rope.visibility_layer&focus.MASK)!=0,"rope has stable depth before descent owns input")
 var previous:Vector2=focus.focus_anchor
 for i in 144:
  level.player.position=Vector2(lerpf(-3610,-3210,float(i)/143.),-3870)-Vector2(13,54)
  route.active=i>=48
  level._update_camera(DT)
  if route.active:route._present(DT)
  else:level._present(DT)
  check(focus.focus_anchor.distance_to(previous)<18.,"rope handoff preserves continuous focus") if i==48 else pass_check(focus.focus_anchor.distance_to(previous)<18.)
  previous=focus.focus_anchor
  check((route.swing_rope.visibility_layer&focus.MASK)!=0,"rope remains registered after handoff") if i==49 else pass_check((route.swing_rope.visibility_layer&focus.MASK)!=0)
  await record("rope-approach-and-handoff")
 place(Vector2(-3140,route.mine_trial.ground(-3140)))
 focus._update_focus(focus._region(),true) # explicit cut between the two independent review paths
 for i in 12:route._present(DT);await process_frame
 previous=focus.focus_anchor
 for i in 144:
  var x:=lerpf(-3140,-2680,float(i)/143.)
  level.player.position=Vector2(x,route.mine_trial.ground(x))-Vector2(13,54)
  route._present(DT)
  pass_check(focus.focus_anchor.distance_to(previous)<18.)
  pass_check((route.mine_trial.miner.visibility_layer&focus.MASK)!=0)
  pass_check((route.mine_trial.rear_tools.visibility_layer&focus.MASK)!=0)
  previous=focus.focus_anchor
  await record("miner-approach-and-pass")
 check((route.art.mountain.visibility_layer&focus.MASK)==0,"depth registration still excludes opaque exterior background")
 # Real input on the safe bank: inspect illumination during motion,
 # unlike the explicitly scripted optical-boundary paths above.
 level.enter_valley_test();place(Vector2(850.,level.ground_y(850.)))
 level.set_physics_process(true);Engine.max_fps=30
 await frames(24)
 var bank_start:float=level.player.position.x
 Input.action_press("move_right")
 for i in 72:await record("bank-walk-through-light")
 Input.action_release("move_right")
 check(level.player.position.x>bank_start+120.,"bank lighting is reviewed during real responsive movement")
 Input.action_press("move_left")
 for i in 72:await record("bank-return-through-light")
 Input.action_release("move_left")
 for i in 24:await record("bank-rest-after-light")
 check(level.art.crate_art.material!=null and level.art.valley_player_light.surface_receivers.has(level.art.crate_art.get_instance_id()),"boat receives the shared world light on its real geometry")
 var file:=FileAccess.open(output+"/frames.json",FileAccess.WRITE);file.store_string(JSON.stringify(records));file.close()
 file=FileAccess.open(output+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify({"failed":failed,"frames":serial}));file.close()
 print("FOCUS TRANSITION V56 ","FAIL" if failed else "PASS"," frames=",serial)
 level.queue_free();await frames(3);quit(1 if failed else 0)
func pass_check(ok:bool)->void:
 if not ok:check(false,"optical continuity or world-depth registration changed")
