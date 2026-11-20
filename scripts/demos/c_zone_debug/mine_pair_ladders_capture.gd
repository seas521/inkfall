extends "res://scripts/demos/c_zone_debug/mine_pair_main_entry_review.gd"
# Real input-driven traversal captures; no source-frame posing.
func run()->void:
 output="res://artifacts/mine-pair-ladders-live/game"
 DirAccess.make_dir_recursive_absolute(output)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90)
 var level=main.river
 var room=level.bridge_to_c.mine_trial.gap.art.pair_room
 check_ladder_planes(room)
 var control=room.ladders
 level.player.position=Vector2(-445-13,room.MID_Y-55);level.player.velocity=Vector2.ZERO
 level.bridge_to_c.fall_origin=room.MID_Y;await frames(20)
 Input.action_press("climb_up")
 for i in 250:
  await frames(1)
  if control.mode==control.Mode.CLIMB:break
 await frames(70);Input.action_release("climb_up");await frames(4)
 check(control.active(),"upper ladder must be driven by real input")
 await shot("00-upper-ladder-hold")
 Input.action_press("climb_up")
 for i in 700:
  await frames(1)
  if not control.active():break
 Input.action_release("climb_up");await frames(15)
 check(level.player.is_on_floor() and absf(level.bridge_to_c.feet().y-room.UPPER_Y)<8,"upper step-off must have real floor support")
 await shot("01-upper-ladder-step-off")
 control.cancel();level.player.position=Vector2(-390-13,room.MID_Y-55);level.player.velocity=Vector2.ZERO
 level.bridge_to_c.fall_origin=room.MID_Y;await frames(20)
 Input.action_press("climb_down")
 var caught_turn:=false
 var caught_step:=false
 for i in 250:
  await frames(1)
  if control.active() and control.mode==control.Mode.ENTER:
   if not caught_turn and control.source_frame<215:
    caught_turn=true;await shot("02a-down-turn-on-platform")
   if not caught_step and control.source_frame<180:
    caught_step=true;await shot("02b-down-step-from-front")
  if control.mode==control.Mode.CLIMB:break
 await frames(80);Input.action_release("climb_down");await frames(4)
 check(control.active() and control.ladder_index==1,"lower ladder must be driven by S")
 await shot("02-lower-ladder-hold")
 control.cancel();level.player.position=Vector2(70-13,room.MID_Y-55);level.player.velocity=Vector2.ZERO
 level.bridge_to_c.fall_origin=room.MID_Y;await frames(100)
 await shot("03-roof-supported-lamp")
 print("MINE PAIR LIVE LADDER CAPTURE ","FAIL" if failed else "PASS")
 if OS.get_environment("INKFALL_LADDER_LEAVE_OPEN")=="1" and not failed:return
 quit(1 if failed else 0)
