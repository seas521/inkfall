extends "res://scripts/demos/c_zone_debug/mine_relay_free_v2_review.gd"
func run()->void:
 level=load("res://scenes/chapters/chapter_01_route.tscn").instantiate();root.add_child(level)
 await frames(10);level.enter_mine_cart_pair_test();await frames(35)
 route=level.bridge_to_c;room=route.mine_trial.gap.art.pair_room;relay=room.relay
 level.player.position=Vector2(3435,relay.exit_scene.ground_y(3435))-Vector2(13,54)
 relay._begin_handoff();await frames(3)
 check(route.in_c_zone and not route.active,"checkpoint review must start after a real-coordinate C handoff")
 for prior in [0,1]:
  level.checkpoint=prior;level.marsh_save=0
  level.death_time=0;level.marsh_hit_time=0
  level.crate.position=level.CRATE_START;level.crate.velocity=Vector2.ZERO
  await warp(Vector2(2810,level.SECOND_ACT_LEDGE.position.y))
  check(level.checkpoint==prior,"save must not fire before reaching the safe bank marker")
  Input.action_press("move_right");await frames(55);release();await frames(3)
  check(level.player.is_on_floor() and level.checkpoint==2 and level.marsh_save==1,"actual bank arrival must save even without raft completion")
  # A real fall in the hanging-deck gap runs the common death and fade.
  await warp(Vector2(3520,level.MARSH_FALL_Y+40))
  var saw_death:bool=level.marsh_hit_time>0 or level.death_time>0
  for i in 450:
   await frames(1)
   saw_death=saw_death or level.marsh_hit_time>0 or level.death_time>0
   if saw_death and level.marsh_hit_time==0 and level.death_time==0 and level.curtain_phase==0 and level.player.is_on_floor():break
  var foot:Vector2=route.feet()
  print("SWING RETRY prior=",prior," feet=",foot," checkpoint=",level.checkpoint," marsh_save=",level.marsh_save)
  check(saw_death and absf(foot.x-level.MARSH_LEDGE_SAVE_X)<5,"death must respawn on current jump section's starting bank")
  check(absf(foot.y-level.SECOND_ACT_LEDGE.position.y)<5 and level.player.is_on_floor(),"retry must be grounded safely beside the puzzle")
 # Later hill and post-rock checkpoints must never be downgraded.
 level.checkpoint=2;level.marsh_save=2
 await warp(Vector2(3000,level.SECOND_ACT_LEDGE.position.y))
 check(level.marsh_save==2,"returning to swing approach must preserve the later hill save")
 level.checkpoint=3;await frames(3)
 check(level.checkpoint==3,"post-rock progress must remain intact")
 print("C SWING CHECKPOINT V29 ","FAIL" if failed else "PASS");quit(1 if failed else 0)
