extends SceneTree
var failed:=false
var main
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,label:String)->void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failed=true;push_error(label)
func run()->void:
 main=load("res://scenes/main.tscn").instantiate();main.debug_start_level=0;root.add_child(main)
 await frames(10)
 check(main.debug_selector_open and main.river==null,"menu mode opens the runtime selector")
 check(main.DEBUG_ENTRIES.size()==3,"exactly three gameplay choices")
 var hint:=""
 for p in main.get_property_list():
  if p.name=="debug_start_level":hint=p.hint_string
 check(hint.split(",").size()==4,"editor exposes only menu, chapter, ladder and valley")
 check(hint.contains("完整版:5") and hint.contains("绳梯:8") and hint.contains("入口:18"),"editor preserves explicit serialized launch IDs")
 main.debug_selection=main.SCENE1_DEBUG_INDEX
 main._move_menu_selection(1);check(main.debug_selection==main.ROPE_LADDER_DEBUG_INDEX,"down selects ladder without hidden entries")
 main._move_menu_selection(1);check(main.debug_selection==main.VALLEY_ENTRY_DEBUG_INDEX,"down selects valley")
 main._move_menu_selection(1);check(main.debug_selection==main.VALLEY_ENTRY_DEBUG_INDEX,"selection stays at final visible row")
 check(main._menu_selection(12)==main.SCENE1_DEBUG_INDEX,"obsolete return IDs fall back to chapter")
 for entry in main.DEBUG_ENTRIES:
  main.debug_selection=entry.id;main._start_debug_level();await frames(12)
  var level=main.river
  check(level!=null and level.scene_file_path==main.CHAPTER_ROUTE,entry.title+" uses continuous chapter")
  if entry.id==main.SCENE1_DEBUG_INDEX:
   check(level.checkpoint==6 and level.scene1.cp==0,"full chapter begins at upper forest intro")
  elif entry.id==main.ROPE_LADDER_DEBUG_INDEX:
   check(absf(level.player.position.x+13-(level.scene1.CLIFF_X-18))<12,"ladder test starts at the cliff ladder")
   check(level.bridge_to_c.enabled,"ladder test retains the route toward mine and valley")
  else:
   var route=level.bridge_to_c;var relay=route.mine_trial.gap.art.pair_room.relay
   check(route.in_c_zone and route.c_zone_prepared and not route.active,"valley starts through prepared C handoff")
   check(level.player.position.x>-220 and level.player.position.x<0,"valley entry is the mine exit slope")
   check(relay.handoff_done and relay.exit_scene.detached,"exit supports and reverse crossing are ready")
   check(level.puzzle_box.position==level.PUZZLE_BOX_START,"valley box begins at unsolved position")
   level.restore_checkpoint();await frames(5)
   check(route.in_c_zone and level.player.position.x>0,"normal restart stays in C")
   var foot:=Vector2(-300,level.ground_y(-300))
   level.player.position=foot-Vector2(13,54)
   check(relay.try_return_from_valley(),"valley test can return uphill into mine")
   await frames(8)
   check(route.active and route.failure_time==0,"return does not trigger forest death logic")
  main._show_debug_selector();await frames(3)
  check(main.debug_selector_open and main.debug_selection==entry.id,"cancel returns to the selected visible row")
 main.queue_free();await frames(4)
 for choice in [5,8,18]:
  main=load("res://scenes/main.tscn").instantiate()
  main.debug_start_level=choice
  root.add_child(main);await frames(4)
  check(not main.debug_selector_open and main.river!=null,"editor launch value "+str(choice)+" enters gameplay")
  check(main.debug_selection==choice-1,"editor launch value "+str(choice)+" selects the matching stable ID")
  main._show_debug_selector();await frames(2);main.queue_free();await frames(3)
 print("CHAPTER MENU V47 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
