extends "res://scripts/demos/c_zone_debug/chapter_light_v54_review.gd"
func shot(label:String,feet:Vector2,facing:int=1)->void:
 await settle(feet);level.facing=facing
 for i in 12:present(route.active);freeze_film_noise();await frames(1)
 await capture(label)
func run()->void:
 output="res://artifacts/plane-contact-v55/after"
 DirAccess.make_dir_recursive_absolute(output)
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
 root.size=Vector2i(1600,900);root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(20);route=level.bridge_to_c
 level.debug_enter_scene1();level.scene1.intro_time=99;level.scene1.cut=S.Cut.NONE
 level.scene1.predator.enabled=false;level.scene1.spider.enabled=false;level.set_physics_process(false)
 level.enter_root_cliff_test();level.set_physics_process(false)
 for i in 3:
  var tree=route.trees[i]
  var surface:PackedVector2Array=tree.world_top()
  var foot:Vector2=surface[int(surface.size()/2)]
  # Capture the actual connected solid surface, not the detachable weak tip.
  if i==1 and not tree.stable_top.is_empty():foot=tree.to_global(tree.stable_top[int(tree.stable_top.size()/2)])
  place(foot)
  for k in 15:present(true);freeze_film_noise();await frames(1)
  var focus=level.art.valley_player_focus
  check(focus.discovery_region==&"gorge","tree "+str(i)+" remains outdoor focal space")
  var sprite:Sprite2D=tree.branch.get_child(0)
  check((sprite.visibility_layer&focus.MASK)!=0,"tree "+str(i)+" bough shares actual gameplay coverage")
  await capture("0"+str(i+1)+"-rooted-tree")
 level.enter_valley_test();await settle(Vector2(6800.,level.marsh_rock_surface_y(6800.)))
 level.fan_owned=false;level.cliff.carrying=0;level.cliff.stones[0]["state"]=level.CliffAct.Stone.HELD
 for face:int in [-1,1]:
  level.facing=face
  for i in 10:present();freeze_film_noise();await frames(1)
  level.cliff._update_stone(0,0.);present();await frames(1)
  check(level.cliff.stones[0].body.position.distance_to(level.actor.fan_hand_position())<3.,"held stone is at the real hand")
  check((level.stone_nodes[0].visibility_layer&level.art.valley_player_focus.MASK)!=0,"standalone held stone shares the playing focus")
  await light_pair("04-stone-left" if face<0 else "05-stone-right")
 print("CONTACT V55 ","FAIL" if failed else "PASS"," ",light_report)
 var file:=FileAccess.open(output+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify({"failed":failed,"lights":light_report}));file.close()
 quit(1 if failed else 0)
