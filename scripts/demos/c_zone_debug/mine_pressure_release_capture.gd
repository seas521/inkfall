extends "res://scripts/demos/c_zone_debug/mine_pair_main_entry_review.gd"
func run()->void:
 output="res://artifacts/mine-pressure-release-v1/game"
 DirAccess.make_dir_recursive_absolute(output)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 await frames(15);main.debug_selection=16;main._start_debug_level();await frames(90)
 var level=main.river
 var route=level.bridge_to_c
 var room=route.mine_trial.gap.art.pair_room
 var pressure=room.pressure
 level.player.position=Vector2(pressure.plate_rest.x-70,room.MID_Y)-Vector2(13,55)
 level.player.velocity=Vector2.ZERO;route.fall_origin=room.MID_Y
 await frames(50);await shot("00-approach")
 Input.action_press("move_right")
 for i in 100:
  await frames(1)
  if pressure.load_active:break
 Input.action_release("move_right")
 for i in 30:
  await frames(1)
  if not pressure.motes.is_empty():break
 await frames(8)
 await shot("01-pedal-contact-dust")
 await frames(75)
 check(pressure.released,"real walk onto the pedal must lift the restraint")
 await shot("02-cart-released")
 Input.action_press("move_left");await frames(65);Input.action_release("move_left")
 await frames(80)
 check(not pressure.released,"walking away must close the restraint")
 await shot("03-pedal-restored")
 room.mechanical_impulse(room.lamps[1].global_position,.08)
 await frames(25);await shot("04-impact-light-response")
 print("MINE PRESSURE LIVE CAPTURE ","FAIL" if failed else "PASS")
 if OS.get_environment("INKFALL_PRESSURE_LEAVE_OPEN")=="1" and not failed:return
 quit(1 if failed else 0)
