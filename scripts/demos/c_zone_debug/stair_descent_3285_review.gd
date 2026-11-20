extends SceneTree
var level
var route
var room
var failed:=false
var trace:Array=[]
func _initialize()->void:call_deferred("run")
func frames(n:int)->void:
 for i in n:await physics_frame
func check(ok:bool,message:String)->void:
 if not ok:failed=true;push_error(message)
func release()->void:
 for action in ["move_left","move_right","jump","climb_down","climb_up","interact"]:Input.action_release(action)
func warp(x:float)->void:
 release();room.stairs.reset();room.hoist.task=room.hoist.Task.NONE
 level.scene1.low_stance.reset();level.player.velocity=Vector2.ZERO
 level.player.position=Vector2(x,room.floor_y(x))-Vector2(13,54)
 route.fall_origin=room.floor_y(x);level.climb_time=-1;level.jump_windup_left=0
 await frames(25)
func shot(label:String)->void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 var dir:="res://artifacts/stair-descent-3285-integration/game"
 DirAccess.make_dir_recursive_absolute(dir)
 var file=FileAccess.open(dir+"/"+label+".linear",FileAccess.WRITE);file.store_buffer(image.get_data());file.close()
 var meta=FileAccess.open(dir+"/"+label+".json",FileAccess.WRITE);meta.store_string(JSON.stringify({"size":[image.get_width(),image.get_height()],"format":image.get_format()}));meta.close()
func travel(down:bool)->Dictionary:
 await warp(270 if down else 470)
 Input.action_press("move_right" if down else "move_left")
 var core_frames:=0;var airborne:=0;var action_frames:=0
 var scale_error:=0.;var max_offset_step:=0.;var last_offset:=0.
 var max_foot_error:=0.;var max_eye_step:=0.;var previous_eye:=0.
 var treads:Dictionary={}
 var previous_active:=false;var paused:=false;var captures:=0
 for i in 420:
  await frames(1)
  var p:Vector2=route.feet()
  var actor=level.actor
  if p.x>=room.STAIR_START and p.x<=room.STAIR_END:
   core_frames+=1
   if not level.player.is_on_floor():airborne+=1
  scale_error=maxf(scale_error,absf(absf(actor.body.scale.x)-.378))
  var is_native:bool=String(actor.current_clip).begins_with("mine_stair_")
  if is_native:
   action_frames+=1
   if previous_active:max_offset_step=maxf(max_offset_step,absf(room.stairs.offset-last_offset))
   if previous_active:max_eye_step=maxf(max_eye_step,absf(actor.eye_light.global_position.y-previous_eye))
   previous_eye=actor.eye_light.global_position.y
   max_foot_error=maxf(max_foot_error,room.stairs.contact_error)
   if room.stairs.part=="step":treads[str(room.stairs.segment)]=true
   last_offset=room.stairs.offset
  previous_active=is_native
  if not down and level.player.velocity.x< -1:check(not String(actor.current_clip).begins_with("mine_stair_down"),"upstairs must not play descent frames in reverse")
  trace.append({"down":down,"x":p.x,"y":p.y,"clip":String(actor.current_clip),"frame":actor.current_frame_index,"eye_y":actor.eye_light.global_position.y,"offset":room.stairs.offset,"grounded":level.player.is_on_floor()})
  if ((down and p.x>375) or (not down and p.x<375)) and not paused:
   paused=true;release();await frames(18)
   var stopped:Vector2=route.feet();var held_frame:int=actor.current_frame_index
   await shot("02-paused-down" if down else "05-paused-up")
   await frames(18)
   check(route.feet().distance_to(stopped)<.01 and actor.current_frame_index==held_frame,"release input must hold position and pose without breathing")
   Input.action_press("move_right" if down else "move_left")
  if down and captures<3 and p.x>[320,355,420][captures]:
   await shot("0"+str(captures)+"-native-descent");captures+=1
  if not down and captures<3 and p.x<[425,380,330][captures]:
   await shot("0"+str(captures+3)+"-native-ascent");captures+=1
  if (down and p.x>470) or (not down and p.x<270):break
 release();await frames(15)
 check(level.player.is_on_floor() and route.failure_time==0,"stair traversal must finish on a real safe floor")
 check(airborne==0,"stair traversal must not hop off the collision plane")
 check(float(core_frames)/60.>2.5 and float(core_frames)/60.<3.2,"stair cadence must allow visible weight transfer without becoming a slow cutscene")
 check(action_frames>40,"native video frames must be used in each travel direction")
 check(scale_error<.00001,"actor runtime scale must stay fixed")
 check(max_foot_error<.01,"the planted sole must stay on the actual wooden tread, not float over a ramp")
 check(treads.size()>=9,"actual tread contacts must progress through the staircase")
 check(max_eye_step<8,"native body/head trajectory must not jump between planted poses: "+str(max_eye_step))
 return {"down":down,"core_seconds":core_frames/60.,"airborne_frames":airborne,"native_frames":action_frames,"max_scale_error":scale_error,"max_root_correction_step":max_offset_step,"max_foot_error":max_foot_error,"max_eye_step":max_eye_step,"treads":treads.size()}
func run()->void:
 if DisplayServer.get_name()=="headless":
  level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
  await frames(10);level.enter_mine_cart_pair_test();await frames(30)
 else:
  var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
  await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90);level=main.river
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room
 var results:Array=[]
 results.append(await travel(true));results.append(await travel(false))
 # Reverse at an actual intermediate tread rather than only testing
 # uninterrupted traversals; stale contact ownership must not survive it.
 await warp(365);Input.action_press("move_right");await frames(8)
 Input.action_release("move_right");Input.action_press("move_left")
 await frames(14)
 check(room.stairs.active and not room.stairs.going_down,"mid-stair reversal must select the uphill support sequence")
 check(level.player.is_on_floor() and room.stairs.contact_error<.01,"reversal must retain a real tread contact")
 await warp(345);Input.action_press("move_right");await frames(4)
 check(room.stairs.active,"moving downhill midway must select the native action")
 Input.action_press("jump");await frames(3)
 check(not room.stairs.active,"jump windup must release stair presentation immediately")
 await frames(10);check(not level.player.is_on_floor(),"stair presentation must not swallow a real jump")
 for stair_x in [335.0,375.0,410.0]:
  await warp(stair_x)
  Input.action_press("jump");await frames(10);Input.action_release("jump")
  var left_floor:=false;var landed:=false
  for i in 100:
   await frames(1)
   if not level.player.is_on_floor():left_floor=true
   elif left_floor:landed=true;break
  await frames(5)
  check(landed and room.stairs.active and room.stairs.resting,"vertical stair jump must settle onto a visible tread without walking")
  check(room.stairs.contact_error<.01,"stationary landing sole must touch the visible tread")
  var planted_y:float=level.actor.eye_light.global_position.y
  await frames(15)
  check(absf(level.actor.eye_light.global_position.y-planted_y)<.01,"stationary stair landing must not float or change height afterwards")
  await shot("06-jump-landing-"+str(int(stair_x)))
 await warp(350);Input.action_press("climb_down");await frames(15)
 check(not room.stairs.active,"crouching must retain its own action priority")
 release();level.scene1.low_stance.reset()
 route.fail();route.restore_checkpoint();await frames(25)
 check(not room.stairs.active,"death/reset must clear native stair ownership")
 var file=FileAccess.open("res://artifacts/stair-descent-3285-integration/review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":not failed,"travel":results,"trace":trace},"  "))
 print("STAIR DESCENT 3285 ","FAIL" if failed else "PASS"," ",results)
 quit(1 if failed else 0)
