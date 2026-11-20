extends SceneTree
var level
var route
var failed:=false
var trace:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 var dir:="res://artifacts/mine-entry-walk-v1/game"
 DirAccess.make_dir_recursive_absolute(dir)
 var raw=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);raw.store_buffer(image.get_data());raw.close()
 var meta=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[image.get_width(),image.get_height()],"format":image.get_format()}));meta.close()
func run()->void:
 if DisplayServer.get_name()=="headless":
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
  await frames(10);level.enter_root_cliff_test();await frames(10)
 else:
  var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
  await frames(15);main.debug_selection=11;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;route.checkpoint_step=2;route.reached_step=2;route.restore_checkpoint()
 await frames(25)
 await shot("00-last-bough")
 var airborne:=0
 var captured:=0
 Input.action_press("move_right")
 for i in 420:
  await frames(1)
  var p:Vector2=route.feet()
  if not level.player.is_on_floor():airborne+=1
  trace.append({"x":p.x,"y":p.y,"grounded":level.player.is_on_floor()})
  if captured<3 and p.x>[-3185,-3135,-3060][captured]:
   await shot("0"+str(captured+1)+"-entry-descent");captured+=1
  if route.failure_time>0 or p.x> -2950:break
 Input.action_release("move_right");await frames(20)
 var record_only:=OS.get_environment("INKFALL_ENTRY_BASELINE")=="1"
 if not record_only:
  check(route.feet().x> -2960,"holding right alone must reach the mine without jumping: "+str(route.feet()))
  check(airborne<=3,"descent must remain supported, not turn into a forced drop: "+str(airborne))
  check(route.failure_time==0 and level.player.is_on_floor(),"entry must end safely supported")
  check(route.checkpoint_step==route.MOUTH_STEP,"checkpoint must advance only after reaching the visible mine")
  Input.action_press("move_left")
  for i in 420:
   await frames(1)
   if route.feet().x< -3260:break
  Input.action_release("move_left");await frames(15)
  check(route.feet().x< -3250 and route.failure_time==0,"the same path must allow walking back up to the bough")
  route.restore_checkpoint();await frames(25)
  check(route.feet().x> -3030 and level.player.is_on_floor(),"entry respawn must be on visible mine floor, not inside the hidden shoulder")
  await shot("04-safe-mine-checkpoint")
 var file=FileAccess.open("res://artifacts/mine-entry-walk-v1/"+("before" if record_only else "after")+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":not failed,"airborne_frames":airborne,"feet":str(route.feet()),"trace":trace},"  "))
 print("MINE ENTRY WALK ","BASELINE" if record_only else ("FAIL" if failed else "PASS")," feet=",route.feet()," airborne=",airborne)
 quit(1 if failed else 0)
