extends SceneTree
const SCENE=preload("res://scenes/debug/c_zone_river.tscn")
const Bridge=preload("res://scripts/demos/c_zone_debug/log_bridge_act.gd")
var level
var failures:=0
func _initialize(): call_deferred("_run")
func _frames(n:int):
	for i in n: await physics_frame
func _check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func _feet()->Vector2: return level.player.position+Vector2(13,54)
func _jump_check(label:String)->void:
	var y0:float=_feet().y
	var landings_before:int=level.log_bridge.landing_impulses
	Input.action_press("jump")
	await _frames(18)
	_check(_feet().y<y0-24 and not level.player.is_on_floor(),label)
	Input.action_release("jump")
	var camera_peak:=0.0
	for i in 80:
		await physics_frame
		camera_peak=maxf(camera_peak,level.camera.offset.length())
	_check(level.log_bridge.landing_impulses>landings_before and camera_peak<0.15,"ordinary jump landing never shakes the ground view")
func _run():
	level=SCENE.instantiate()
	root.add_child(level)
	await _frames(6)
	level.debug_enter_log_bridge()
	await _frames(12)
	var b=level.log_bridge
	_check(b.active and level.player.is_on_floor(),"debug starts on the real left bank")
	_check(not level.descent.enabled,"playable puzzle is not the art tour")
	var space:=InputEventKey.new()
	space.physical_keycode=KEY_SPACE
	var w:=InputEventKey.new()
	w.physical_keycode=KEY_W
	_check(InputMap.action_has_event("jump",space) and not InputMap.action_has_event("jump",w),"Space is the global jump key and W does not jump")
	await _jump_check("Space jumps from the left bank after direct DEBUG entry")
	# An unsolved fall returns to the left bank, keeping the pin and log available.
	level.player.position=Bridge.ORIGIN+Vector2(650,1060)
	level.player.velocity=Vector2.ZERO
	await _frames(80)
	_check(b.deaths==1 and level.player.is_on_floor() and _feet().x<Bridge.PIVOT.x,"a failed crossing returns to the left bank")
	_check(b.state==Bridge.State.PROPPED,"an unsolved puzzle remains usable after death")
	# Reaching, holding and pulling use actual player inputs and clip transitions.
	level.player.position=Vector2(b.grip_feet_x()-13,Bridge.LEFT.position.y-55)
	level.player.velocity=Vector2.ZERO
	await _frames(8)
	_check(b.can_grab(),"pin is reachable from the safe side")
	Input.action_press("interact")
	await _frames(48)
	await _jump_check("Space releases the chock and jumps without being blocked")
	Input.action_release("interact")
	level.player.position=Vector2(b.grip_feet_x()-13,Bridge.LEFT.position.y-55)
	level.player.velocity=Vector2.ZERO
	await _frames(8)
	Input.action_press("interact")
	await _frames(48)
	_check(b.gripping and b.extraction<0.1,"holding F engages without automatically solving the puzzle")
	_check(level.actor.current_clip in [&"grip_hold",&"grip_engage"],"uses the existing Seedance grip clip")
	Input.action_press("move_right")
	await _frames(12)
	Input.action_release("move_right")
	_check(b.extraction<0.1,"pushing the wrong direction does not extract the pin")
	Input.action_press("move_left")
	await _frames(25)
	Input.action_release("move_left")
	Input.action_release("interact")
	await _frames(4)
	var partial:float=b.extraction
	_check(partial>10 and partial<Bridge.PIN_TRAVEL and b.state==Bridge.State.PROPPED,"a partial pull can be interrupted")
	_check(b.angle>Bridge.START_ANGLE+0.12 and b.art.scrape_count>=2,"partial extraction visibly lowers the supported bridge and emits friction dust")
	_check(absf(b.support_world().y-b.wedge_top_y(b.support_world().x))<0.05 and b.support_remaining()>1.0,"partially extracted wedge remains in real contact with the bridge underside")
	var scrape_before:int=b.art.scrape_count
	var held_angle:float=b.angle
	await _frames(36)
	_check(absf(b.extraction-partial)<0.1,"letting go preserves partial progress")
	_check(b.art.scrape_count==scrape_before,"idle chock emits no new friction dust")
	_check(absf(b.angle-held_angle)<0.001,"releasing the handle holds the mechanically supported angle")
	Input.action_press("interact")
	await _frames(45)
	Input.action_press("move_left")
	var release_continuity:=0.0
	var max_support_error:=0.0
	var previous_extraction:float=b.extraction
	var previous_supported_angle:float=b.angle
	var monotonic_support:=true
	for i in 100:
		var previous_angle:float=b.angle
		await physics_frame
		if b.state==Bridge.State.PROPPED:
			max_support_error=maxf(max_support_error,absf(b.support_world().y-b.wedge_top_y(b.support_world().x)))
			monotonic_support=monotonic_support and b.extraction>=previous_extraction and b.angle>=previous_supported_angle-0.001
			previous_extraction=b.extraction
			previous_supported_angle=b.angle
		if b.state!=Bridge.State.PROPPED:
			release_continuity=absf(b.angle-previous_angle)
			break
	Input.action_release("move_left")
	Input.action_release("interact")
	_check(release_continuity<0.025 and b.angular_speed>=0.12 and b.art.release_count==1,"final release carries the loaded pose into the fall without snapping")
	_check(monotonic_support,"continued extraction monotonically lowers the bridge")
	_check(max_support_error<0.05 and b.support_remaining()<=0.05 and b.angle>=Bridge.SUPPORTED_RELEASE_ANGLE-0.01,"free fall begins at actual wedge tip separation, with no unsupported hanging phase")
	var impact_seen:=false
	var tremor_peak:=0.0
	var impact_camera_peak:=0.0
	for i in 180:
		await physics_frame
		if b.state==Bridge.State.SETTLING:
			impact_seen=impact_seen or b.art.dust_puffs.size()>0
			tremor_peak=maxf(tremor_peak,absf(b.angle-Bridge.END_ANGLE))
			impact_camera_peak=maxf(impact_camera_peak,level.camera.offset.length())
		if b.state==Bridge.State.BRIDGED: break
	_check(impact_seen and b.art.impact_count==1 and tremor_peak>0.003,"impact emits dust at both contacts and shakes the actual bridge body")
	_check(tremor_peak>0.015 and impact_camera_peak>3.0 and b.impact_impulses==1,"heavy bridge impact visibly rebounds and shakes the ground view once")
	_check(b.state==Bridge.State.BRIDGED,"full extraction makes the log fall and settle")
	_check(not b.pin_body.freeze,"released pin is an independent physical object")
	_check(absf(b.log_body.rotation-Bridge.END_ANGLE)<0.004,"the actual bridge collider settles close to the landing angle")
	# This verifies the collision route, not a teleported success condition.
	Input.action_press("move_right")
	for i in 320:
		await physics_frame
		if b._on_log() and b.log_body.to_local(_feet()).x>170:
			break
	Input.action_release("move_right")
	await _frames(5)
	_check(b.bridge_impulses>0 and absf(b.bridge_deflection)>0.0001,"walking onto the log excites its physical spring")
	await _jump_check("Space jumps from the moving bridge surface")
	Input.action_press("move_right")
	await _frames(250)
	Input.action_release("move_right")
	_check(b.reached_bank and level.player.is_on_floor() and _feet().x>Bridge.RIGHT.position.x+45,"walk across the sloping log using the real player controller")
	level.player.position=Bridge.ORIGIN+Vector2(650,1060)
	level.player.velocity=Vector2.ZERO
	await _frames(80)
	_check(b.reached_bank and b.state==Bridge.State.BRIDGED and _feet().x>Bridge.RIGHT.position.x,"death preserves the bridge and the right-bank checkpoint")
	level.restore_checkpoint()
	await _frames(8)
	_check(b.active and b.state==Bridge.State.BRIDGED and _feet().x>Bridge.RIGHT.position.x,"manual checkpoint restore preserves puzzle state")
	# The actual cliff continuation activates while falling, before the old death threshold.
	level.debug_enter_scene1()
	level.scene1.cut=level.scene1.Cut.DONE
	level.player.position=Vector2(-3480,-4510)
	level.player.velocity=Vector2(0,280)
	var deaths_before:int=b.deaths
	await _frames(75)
	_check(b.active and not level.descent.enabled and b.deaths==deaths_before+1,"a direct cliff fall enters the real world and is lethal rather than bypassing the ladder")
	await _frames(100)
	_check(b.active and b.reached_bank and level.player.is_on_floor(),"a lethal fall preserves the previously earned bank checkpoint")
	level.reset_all()
	await _frames(8)
	_check(not b.active and level.checkpoint==0,"full reset leaves the bridge and restores the original first-act checkpoint")
	print("log bridge smoke OK" if failures==0 else "log bridge smoke: %d FAILED"%failures)
	quit(0 if failures==0 else 1)
