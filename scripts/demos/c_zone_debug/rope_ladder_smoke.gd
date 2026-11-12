extends SceneTree

const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level
var ladder
var failures := 0
func _initialize(): call_deferred("_run")
func _frames(n:int):
	for i in n: await physics_frame
func _check(ok:bool,label:String):
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func _feet()->Vector2: return level.player.position+Vector2(13,54)
func _run():
	level=SCENE.instantiate()
	root.add_child(level)
	await _frames(8)
	ladder=level.rope_ladder
	_check(ladder.length()>500,"the suspended route spans a deep gorge rather than a short step")
	_check(level.log_bridge.LEFT.position.y-(ladder.anchor().y+ladder.length())>=79,"the ladder ends visibly suspended above the landing")
	# Reproduce the old pop: the camera already sees the cliff while the
	# player's feet are still outside the former 650 px proximity gate.
	var previous_position:Vector2=level.player.position
	var previous_camera:=Vector2(level.camera_x,level.camera_y)
	level.player.position=ladder.anchor()-Vector2(900,54)
	level.camera_x=ladder.anchor().x-1200
	level.camera_y=ladder.anchor().y-500
	ladder._update_art()
	_check(ladder.art_visible and ladder.art.visible and ladder.art.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"ladder is drawn before entering the viewport even while the player is far away")
	level.camera_x=ladder.anchor().x-1650
	ladder._update_art()
	_check(ladder.art_visible,"ladder viewport warms up before the right edge reaches the rope")
	level.camera_x=ladder.anchor().x-2200
	ladder._update_art()
	_check(not ladder.art_visible and ladder.art.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"distant offscreen ladder still avoids unnecessary rendering")
	level.player.position=previous_position
	level.camera_x=previous_camera.x
	level.camera_y=previous_camera.y
	level.debug_enter_rope_ladder()
	level.scene1.cut=level.scene1.Cut.DONE
	level.scene1.intro_time=99
	var top:Vector2=ladder.anchor()
	level.player.position=Vector2(top.x-18-13,level.scene1.ground_top(top.x-18)-54)
	level.player.velocity=Vector2.ZERO
	await _frames(12)
	_check(level.player.is_on_floor(),"standing on the actual cliff before mounting")
	_check(level.art.grass_art.visible and level.art.grass_band.visible,"the original grassy ground remains at the cliff after the backdrop transition")
	var destination:int=level.art.surface_art.far_group.get_instance_id()
	_check(level.art.landmark_layer.visible and level.art.landmark_output.visible,"the original house and campfire remain visible at the cliff")
	Input.action_press("climb_down")
	await _frames(115)
	Input.action_release("climb_down")
	await _frames(3)
	_check(ladder.active() and level.actor.current_clip==&"rope_ladder" and not level.scene1.low_stance.active(),"S gives ladder descent priority over crouching at contact")
	_check(level.art.grass_art.visible and level.art.grass_band.visible,"mounting keeps the same world-space grass and ground cover")
	_check(level.art.landmark_layer.visible and level.art.landmark_output.visible and level.art.surface_art.far_group.get_instance_id()==destination and level.art.landmark_layer.layer>level.log_bridge.art.back.layer,"mounting preserves the same animated destination above the gorge backdrop")
	var y0:float=_feet().y
	var f0:float=ladder.frame
	await _frames(30)
	_check(absf(_feet().y-y0)<2 and is_equal_approx(ladder.frame,f0),"releasing W/S holds the current recorded contact pose")
	# Reproduce the dangerous shortcut from the middle of the suspended route.
	Input.action_press("climb_down")
	for i in 450:
		await physics_frame
		if _feet().y>top.y+310: break
	Input.action_release("climb_down")
	await _frames(3)
	var deaths_before:int=level.log_bridge.deaths
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(170)
	_check(level.log_bridge.deaths==deaths_before+1,"jumping from the middle of the ladder is a lethal fall")
	_check(not level.log_bridge.active and not level.log_bridge.left_bank_reached and level.player.is_on_floor() and absf(_feet().y-top.y)<12,"a failed first descent returns to the cliff checkpoint without unlocking the lower bank")
	Input.action_press("climb_down")
	await _frames(115)
	Input.action_release("climb_down")
	await _frames(3)
	y0=_feet().y
	Input.action_press("climb_down")
	var swing_min:=100.0
	var swing_max:=-100.0
	var max_pose_updates:=0
	for i in 1800:
		var before_pose:int=level.actor.pose_sync_count
		await physics_frame
		max_pose_updates=maxi(max_pose_updates,level.actor.pose_sync_count-before_pose)
		swing_min=minf(swing_min,ladder.swing)
		swing_max=maxf(swing_max,ladder.swing)
		if ladder.at_bottom: break
	Input.action_release("climb_down")
	_check(_feet().y>y0+25 and ladder.at_bottom,"S continues down to the lower end")
	_check(swing_max-swing_min>3.0,"alternating climbing weight keeps the suspended ladder swaying")
	_check(max_pose_updates==1,"climbing updates exactly one actor pose per physics frame")
	var background=level.log_bridge.art.depth.material.get_shader_parameter("ravine")
	var low:float=_feet().y
	var jumps_before:int=ladder.jumps
	Input.action_press("climb_up")
	await _frames(40)
	Input.action_release("climb_up")
	_check(_feet().y<low-8 and ladder.jumps==jumps_before,"W climbs upward without jumping")
	Input.action_press("climb_down")
	for i in 500:
		await physics_frame
		if ladder.at_bottom: break
	Input.action_release("climb_down")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var landings_before:int=level.log_bridge.landing_impulses
	var landing_camera_peak:=0.0
	for i in 130:
		await physics_frame
		landing_camera_peak=maxf(landing_camera_peak,level.camera.offset.length())
	_check(level.log_bridge.landing_impulses>landings_before and landing_camera_peak>0.1 and landing_camera_peak<1.5,"ladder dismount gently settles the camera without heavy shake")
	_check(not ladder.active() and ladder.jumps==jumps_before+1 and level.player.is_on_floor(),"Space pushes off the ladder and physically lands on the lower bank")
	_check(level.actor.current_clip==&"idle_left" and is_zero_approx(level.actor.landing_time) and not level.actor.ghost.visible,"bank handoff resumes stable idle without replaying a landing")
	_check(level.player.collision_mask==11,"normal collision mask restored after dismount")
	_check(not level.rope_ladder.art.fog_layer.visible and not level.log_bridge.art.near_stage.output.visible and level.log_bridge.art.depth.material.get_shader_parameter("ravine")==background and is_equal_approx(ladder.entry_mix(),1.0),"landing keeps the same gorge plate, with no fog veil or cropped foreground rectangle")
	_check(level.log_bridge.left_bank_reached,"a safe low dismount saves the lower bank checkpoint")
	Input.action_press("climb_down")
	await _frames(42)
	Input.action_release("climb_down")
	var low_shape:=level.player.get_child(0).shape as CapsuleShape2D
	_check(level.scene1.low_stance.active() and level.actor.current_clip in [&"low_enter",&"low_idle"] and is_equal_approx(low_shape.height,40.0),"S remains a usable crouch on the lower bank after leaving the ladder")
	await _frames(50)
	_check(not level.scene1.low_stance.active(),"releasing S stands normally after the ladder section")
	# No inner exclusion ring and no facing requirement: directly underneath
	# and several nearby positions all respond to the same Space press.
	for offset in [22.0,40.0]:
		ladder.stop()
		level.player.position=Vector2(top.x+offset-13,level.log_bridge.LEFT.position.y-54)
		level.player.velocity=Vector2.ZERO
		level.log_bridge.fall_in_air=false
		level.facing=1
		await _frames(24)
		var catches:int=ladder.caught
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		_check(ladder.active() and ladder.caught==catches+1,"Space catches from %.0f px away even while facing away"%offset)
	ladder.stop()
	level.player.position=Vector2(top.x+200-13,level.log_bridge.LEFT.position.y-54)
	level.player.velocity=Vector2.ZERO
	level.log_bridge.fall_in_air=false
	await _frames(24)
	var catches:int=ladder.caught
	Input.action_press("jump")
	await _frames(18)
	Input.action_release("jump")
	_check(not ladder.active() and ladder.caught==catches,"outside the catch radius Space remains a normal jump")
	await _frames(80)
	# Walk into the lower catch range, then climb the complete return route.
	level.player.position=Vector2(top.x+68-13,level.log_bridge.LEFT.position.y-54)
	level.player.velocity=Vector2.ZERO
	await _frames(10)
	level.facing=-1
	Input.action_press("climb_up")
	await _frames(10)
	_check(not ladder.active() and level.player.is_on_floor(),"W alone never launches a jump from the lower bank")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	for i in 1800:
		await physics_frame
		if ladder.returned_top>0: break
	Input.action_release("climb_up")
	await _frames(15)
	_check(ladder.caught==catches+1 and ladder.returned_top==1,"Space catches the suspended end, then W climbs up and plays the top exit")
	_check(not ladder.active() and not level.log_bridge.active and level.player.is_on_floor() and _feet().x<level.scene1.CLIFF_X,"return finishes on the real cliff and restores forest control")
	_check(level.actor.current_clip==&"idle_left" and level.actor.eye_light.visible and is_zero_approx(level.actor.landing_time),"cliff handoff retains the unified eye in stable idle")
	_check(is_equal_approx(level.actor.pose.visual_scale,0.9) and level.camera.zoom==Vector2.ONE,"climbing never changes the common character or camera scale")
	print("rope ladder smoke OK" if failures==0 else "rope ladder smoke: %d FAILED"%failures)
	quit(0 if failures==0 else 1)
