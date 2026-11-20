extends "res://scripts/demos/c_zone_debug/mine_entry_walk_review.gd"
var lap:=0
var last_usec:=0
var samples:Array=[]
var recording:=false
func sample_frame()->void:
 var now:=Time.get_ticks_usec()
 if recording and route!=null and last_usec>0:
  var wall:=float(now-last_usec)/1000.
  var row:Dictionary={"lap":lap,"ms":wall,"x":route.feet().x,"y":route.feet().y,"vx":level.player.velocity.x,"clip":String(level.actor.current_clip),"frame":level.actor.current_frame_index,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.}
  samples.append(row)
  if wall>45:print("ENTRY HITCH ",row)
 last_usec=now
func shot(_label:String)->void:pass
func run()->void:
 process_frame.connect(sample_frame)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=11;main._start_debug_level();await frames(90);level=main.river;route=level.bridge_to_c
 for trial in 2:
  lap=trial;route.checkpoint_step=2;route.reached_step=2;route.restore_checkpoint();await frames(25)
  recording=true
  Input.action_press("move_right")
  for i in 420:
   await frames(1)
   if route.failure_time>0 or route.feet().x> -2950:break
  Input.action_release("move_right");recording=false
  check(route.failure_time==0 and route.feet().x> -2960,"walk must reach mine without blocking")
  await frames(20)
 var out:=FileAccess.open("res://artifacts/mine-entry-hitch-v15/"+("before" if OS.get_environment("INKFALL_ENTRY_BASELINE")=="1" else "after")+".json",FileAccess.WRITE)
 out.store_string(JSON.stringify(samples,"  "))
 for trial in 2:
  var peak:=0.;var slow:=0
  for row in samples:
   if row.lap==trial:peak=maxf(peak,row.ms);slow+=int(row.ms>45)
  print("ENTRY PERF lap=",trial," peak_ms=",peak," slow_frames=",slow)
 print("MINE ENTRY HITCH ","FAIL" if failed else "PASS");quit(1 if failed else 0)
