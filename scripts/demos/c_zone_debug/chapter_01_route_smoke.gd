extends SceneTree

const MAIN=preload("res://scenes/main.tscn")
var failures:=0
func _initialize():call_deferred("_run")
func _check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok:failures+=1
func _run():
	var main=MAIN.instantiate()
	root.add_child(main)
	await physics_frame
	var level=main.river
	_check(level!=null and level.scene_file_path==main.CHAPTER_ROUTE,"default entry loads the standalone continuous chapter")
	_check(level.checkpoint==6 and level.scene1.cp==0 and level.scene1.locks_move(),"chapter begins with the forest lying/get-up intro")
	_check(not level.log_bridge.active and not level.descent.enabled,"chapter does not begin at the bridge or art tour")
	main._show_debug_selector()
	main.debug_selection=main.CLIFF_ENTRY_DEBUG_INDEX
	main._start_debug_level()
	await physics_frame
	level=main.river
	_check(main.MAX_DEBUG_INDEX>=8 and level.debug_return_index==8,"cliff has its own selectable DEBUG entry")
	_check(level.scene_file_path==main.CHAPTER_ROUTE and level.scene1.cp==3 and level.scene1.cut==level.scene1.Cut.NONE,"cliff entry retains the upcoming automatic walk and flock")
	_check(absf(level.player.position.x+13-(level.scene1.AUTO_X-30))<2,"cliff test starts at the forest edge, before the cinematic")
	var actor_id:int=level.actor.get_instance_id()
	var camera_id:int=level.camera.get_instance_id()
	level.log_bridge.enter(true)
	await physics_frame
	_check(level.actor.get_instance_id()==actor_id and level.camera.get_instance_id()==camera_id,"forest and bridge share the same actor and follow camera")
	var b=level.log_bridge
	# Completed mechanism fixture; actual pulling/crossing is exercised by
	# log_bridge_smoke. Here test the new chapter's checkpoint/reset owner.
	b.state=b.State.BRIDGED
	b.extraction=b.PIN_TRAVEL
	b.angle=b.END_ANGLE
	b.log_body.transform=Transform2D(b.angle,b.PIVOT)
	b.left_bank_reached=true
	level.restore_checkpoint()
	_check(b.state==b.State.BRIDGED and b.active,"R retains the unlocked bridge and the lower checkpoint")
	level._act_finished()
	_check(not level.completed and main.river==level,"chapter never invokes the C-zone completion handoff")
	level.reset_all()
	_check(level.checkpoint==6 and level.scene1.cp==0 and level.scene1.locks_move(),"whole-chapter restart returns to the forest intro")
	_check(b.state==b.State.PROPPED and b.extraction==0 and not b.left_bank_reached and b.pin_body.freeze,"whole-chapter restart restores the supported bridge and wedge")
	level.actor.current_frame_index=233
	_check(level.actor._blend_time(&"rope_ladder",&"idle_left")==0,"upright cliff exit adds no temporary extra-wide ghost")
	level.actor.current_frame_index=118
	_check(level.actor._blend_time(&"rope_ladder",&"idle_left")>0,"lower dismount keeps its existing landing transition")
	main._show_debug_selector()
	_check(main.debug_selector_open,"Esc returns to the DEBUG list")
	print("chapter 01 route smoke OK" if failures==0 else "chapter 01 route smoke FAILED")
	quit(0 if failures==0 else 1)
