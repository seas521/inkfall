extends SceneTree
var level
var route
var trial
var phase:="warmup"
var times:Dictionary={}
var last_us:=0
func _initialize()->void:call_deferred("run")
func _process(_delta:float)->bool:
 var now:=Time.get_ticks_usec()
 if last_us>0 and phase!="warmup":
  if not times.has(phase):times[phase]={"frame":[],"physics":[],"process":[],"draws":[]}
  times[phase].frame.append((now-last_us)/1000.0)
  times[phase].physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
  times[phase].process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
  times[phase].draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
 last_us=now
 return false
func frames(n:int)->void:
 for i in n:await physics_frame
func stats(values:Array)->Dictionary:
 values.sort()
 return {"p50":snappedf(values[int(values.size()*.5)],.01),"p95":snappedf(values[mini(values.size()-1,int(values.size()*.95))],.01),"max":snappedf(values[-1],.01),"n":values.size()}
func run()->void:
 root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 if DisplayServer.get_name()!="headless":preload("res://scripts/effects/film_look.gd").attach(level)
 await frames(8);level.enter_root_cliff_test()
 route=level.bridge_to_c;route.checkpoint_step=3;route.restore_checkpoint();trial=route.mine_trial
 level.player.position=Vector2(trial.GRIP_X-13,trial.ground(trial.GRIP_X)-55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=trial.ground(trial.GRIP_X)
 await frames(30)
 phase="idle";await frames(60)
 phase="lever";Input.action_press("interact")
 for i in 260:
  await frames(1)
  if trial.launched and trial.operation=="":break
 Input.action_release("interact")
 phase="boarding";Input.action_press("move_right");Input.action_press("jump")
 for i in 100:
  await frames(1)
  if trial.escape.is_riding():break
 Input.action_release("move_right");Input.action_release("jump")
 assert(trial.escape.is_riding())
 phase="approach"
 for i in 800:
  await frames(1)
  if trial.broken:phase="collapse"
  if trial.escape.stopped_once:break
 assert(trial.escape.saved and route.failure_time==0)
 phase="parked";await frames(90)
 phase="warmup";await frames(90)
 var updates:int=route.art.cart_visual.render_updates
 var pad_updates:int=trial.escape.floor_pad_updates
 phase="settled";await frames(60)
 print("SETTLED WORK cart_texture_updates=",route.art.cart_visual.render_updates-updates," floor_pad_updates=",trial.escape.floor_pad_updates-pad_updates)
 phase="warmup"
 var result:Dictionary={}
 for key in times:
  result[key]={}
  for counter in times[key]:result[key][counter]=stats(times[key][counter])
 print("MINE PERFORMANCE ",JSON.stringify(result))
 quit()
