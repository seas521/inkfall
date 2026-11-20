extends SceneTree
var level
var route
var room
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 var dir:="res://artifacts/mine-entry-walk-v1/stairs"
 DirAccess.make_dir_recursive_absolute(dir)
 var file=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);file.store_buffer(image.get_data());file.close()
 var meta=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[image.get_width(),image.get_height()],"format":image.get_format()}));meta.close()
func run()->void:
 if DisplayServer.get_name()=="headless":
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
  await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 else:
  var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
  await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room
 level.player.position=Vector2(270,room.MID_Y)-Vector2(13,54);level.player.velocity=Vector2.ZERO
 route.fall_origin=room.MID_Y;await frames(20)
 var trace:Array=[];var airborne:=0
 var captured:=false
 Input.action_press("move_right")
 for i in 240:
  await frames(1)
  var p:Vector2=route.feet()
  if p.x>room.STAIR_START and p.x<room.STAIR_END:
   if not level.player.is_on_floor():airborne+=1
   trace.append({"x":p.x,"y":p.y,"grounded":level.player.is_on_floor(),"clip":String(level.actor.current_clip),"frame":level.actor.current_frame_index,"support":level.actor.support_offset,"offset":level.actor.position.y-p.y,"vy":level.player.velocity.y})
   if not captured and p.x>375:await shot("01-grounded-descent");captured=true
  if p.x>470:break
 Input.action_release("move_right")
 var label:="stair-after" if OS.get_environment("INKFALL_STAIRS_AFTER")=="1" else "stair-before"
 var file=FileAccess.open("res://artifacts/mine-entry-walk-v1/"+label+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"airborne":airborne,"trace":trace},"  "))
 print("MINE STAIR MOTION ",label," airborne=",airborne," frames=",trace.size())
 var largest:=0.0
 for i in range(1,trace.size()):largest=maxf(largest,absf(float(trace[i].offset)-float(trace[i-1].offset)))
 var passed:bool=airborne==0 and (label!="stair-after" or largest<1)
 print("MINE STAIR CONTACT ","PASS" if passed else "FAIL"," max root step=",largest)
 quit(0 if passed else 1)
