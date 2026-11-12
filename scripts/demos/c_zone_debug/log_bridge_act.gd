extends Node2D

# First playable descent puzzle. Geometry is in the same world as scene 1 / C.
# The pin, pivoting log and banks are independent bodies, never baked in a plate.
const Pose = preload("res://scripts/actors/actor_pose_state.gd")
const Art = preload("res://scripts/demos/c_zone_debug/log_bridge_art.gd")
const ORIGIN := Vector2(-3525,-4270)
const PIVOT := ORIGIN+Vector2(430,400)
const LEFT := Rect2(ORIGIN+Vector2(-500,400),Vector2(945,650))
const RIGHT := Rect2(ORIGIN+Vector2(770,555),Vector2(485,500))
const LENGTH := 380.0
const THICK := 26.0
const START_ANGLE := -1.099557429  # -63 degrees
const END_ANGLE := 0.4188790205   # 24 degrees, end rests on the right bank
const PIN_HOME := PIVOT+Vector2(10,-38)
const PIN_TRAVEL := 52.0
const SUPPORTED_RELEASE_ANGLE := -0.6981317008 # -40 degrees, before free fall
const SUPPORT_LOCAL := Vector2(35,THICK)
const GRIP_SECONDS := 16.0/24.0
const RELEASE_SECONDS := 14.0/24.0
const PULL_SPEED := 70.0

enum State { PROPPED, FALLING, SETTLING, BRIDGED }
var level
var art: Node2D
var active := false
var state := State.PROPPED
var angle := START_ANGLE
var angular_speed := 0.0
var settling := 0.0
var extraction := 0.0
var gripping := false
var grip_elapsed := 0.0
var release_left := 0.0
var grip_distance := 0.0
var hand_start := Vector2.ZERO
var grip_start := Vector2.ZERO
var pull_motion := 0.0
var reached_bank := false
var failure_time := 0.0
var restored := false
var deaths := 0
var landings := 0
var was_grounded := false
var bridge_deflection := 0.0
var bridge_sway_speed := 0.0
var bridge_loaded := false
var bridge_step_distance := 0.0
var last_load_x := 0.0
var bridge_impulses := 0
var pull_feedback_distance := 0.0
var pull_sound_cooldown := 0.0
var feedback_clock := 0.0
var feedback_frame := -1
var shake_energy := 0.0
var camera_bob := 0.0
var camera_bob_speed := 0.0
var air_max_speed := 0.0
var landing_impulses := 0
var impact_impulses := 0
var left_bank_reached := false
var respawn_to_top := false
var failure_kind: StringName = &"void"
var fall_in_air := false
var fall_peak_y := 0.0
var log_body: AnimatableBody2D
var pin_body: RigidBody2D
var sounds := {}
var exit_shoulder:StaticBody2D
var exit_open:=false

func _ready() -> void:
	_bank(LEFT)
	_bank(RIGHT)
	# A grounded timber bed carries the sliding wedge; it is also solid to
	# the player, rather than a decorative support he can fall through.
	_bank(Rect2(PIVOT+Vector2(12,0),Vector2(wedge_tip_home().x-PIVOT.x-7,12)))
	# A natural rock shoulder closes the prototype's far end.
	exit_shoulder=_bank(Rect2(ORIGIN+Vector2(1225,425),Vector2(65,630)))
	log_body = AnimatableBody2D.new()
	log_body.collision_layer = 1
	log_body.collision_mask = 0
	log_body.sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(LENGTH,THICK)
	shape.shape = rect
	shape.position = rect.size*0.5
	log_body.add_child(shape)
	add_child(log_body)
	log_body.transform = Transform2D(angle,PIVOT)
	pin_body = RigidBody2D.new()
	pin_body.collision_layer = 16  # collides with the ground, never trips the boy
	pin_body.collision_mask = 1
	pin_body.freeze = true
	pin_body.gravity_scale = 1.0
	pin_body.position = PIN_HOME
	var pin_shape := CollisionShape2D.new()
	var pin_rect := RectangleShape2D.new()
	pin_rect.size = Vector2(57,12)
	pin_shape.shape = pin_rect
	pin_shape.position=Vector2(-7.5,12.5)
	pin_shape.rotation=0.455
	pin_body.add_child(pin_shape)
	var wedge_shape:=CollisionPolygon2D.new()
	wedge_shape.polygon=wedge_polygon()
	pin_body.add_child(wedge_shape)
	pin_body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	pin_body.center_of_mass=Vector2(18,21)
	var material_value := PhysicsMaterial.new()
	material_value.friction = 0.85
	material_value.bounce = 0.05
	pin_body.physics_material_override = material_value
	add_child(pin_body)
	art = Art.new()
	art.puzzle = self
	add_child(art)
	for item in [["creak","tree_creak_01.mp3",-23.0],["release","tree_creak_03.mp3",-18.0],["impact","body_impact.mp3",-15.0]]:
		var sound := AudioStreamPlayer.new()
		sound.stream = load("res://assets/audio/level01/"+item[1])
		sound.volume_db = item[2]
		add_child(sound)
		sounds[item[0]] = sound

func _bank(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)
	return body

func set_exit_open(enabled:bool)->void:
	exit_open=enabled
	exit_shoulder.collision_layer=0 if enabled else 1

func enter(place_at_start := false) -> void:
	active = true
	level.descent.stop()
	level.descent.art.set_active(false)
	level.scene1.cut = level.scene1.Cut.DONE
	# Direct DEBUG entry has never ticked the forest's lying / get-up intro.
	# Its stale intro lock otherwise cancels every jump, including the windup.
	level.scene1.intro_time = maxf(level.scene1.intro_time,level.scene1.LIE_TIME+level.scene1.GET_UP_TIME)
	level.scene1.flock_on = false
	level.checkpoint = 7
	level.intro_time = 0.0
	level.climb_time = -1.0
	level.climb_cooldown = 0.0
	level.dragging = false
	level.puzzle_box_dragging = false
	level.entry_brake = false
	level.rock_lock_time = 0.0
	level.marsh_hit_time = 0.0
	level.death_time = 0.0
	level.fan_owned = false
	level.fan.hide()
	level.rope_art.hide()
	level.camera.zoom = Vector2.ONE
	if place_at_start:
		left_bank_reached = true
		respawn()
		_snap_follow_camera()
	elif not level.player.is_on_floor() and level.player.velocity.y>0:
		begin_fall_tracking(Vector2(level.player.position.x+13,level.scene1.ground_top(level.scene1.CLIFF_X)))
	art.sync(0.0,Vector2(level.camera_x,level.camera_y),true)

func stop() -> void:
	if level.rope_ladder != null:
		level.rope_ladder.stop()
	active = false
	gripping = false
	shake_energy=0.0
	camera_bob=0.0
	camera_bob_speed=0.0
	level.camera.offset=Vector2.ZERO
	level.art.landmark_output.position=Vector2.ZERO
	art.sync(0.0,Vector2.ZERO,false)

func reset_chapter() -> void:
	# An ordinary checkpoint preserves the mechanism. Restarting the whole
	# forest-to-bridge route restores its initial, supported state instead.
	stop()
	state=State.PROPPED
	angle=START_ANGLE
	angular_speed=0.0
	settling=0.0
	extraction=0.0
	release_left=0.0
	grip_elapsed=0.0
	grip_distance=0.0
	pull_motion=0.0
	reached_bank=false
	left_bank_reached=false
	respawn_to_top=false
	failure_time=0.0
	restored=false
	fall_in_air=false
	was_grounded=true
	air_max_speed=0.0
	bridge_deflection=0.0
	bridge_sway_speed=0.0
	bridge_loaded=false
	bridge_step_distance=0.0
	pull_feedback_distance=0.0
	pull_sound_cooldown=0.0
	log_body.transform=Transform2D(angle,PIVOT)
	pin_body.freeze=true
	pin_body.position=PIN_HOME
	pin_body.rotation=0.0
	pin_body.linear_velocity=Vector2.ZERO
	pin_body.angular_velocity=0.0
	for sound in sounds.values():sound.stop()
	art.particles.clear()
	art.dust_puffs.clear()

func respawn() -> void:
	if level.rope_ladder != null:
		level.rope_ladder.stop()
	respawn_to_top = not left_bank_reached and not reached_bank
	if respawn_to_top:
		var top:Vector2=level.rope_ladder.anchor()
		var x:=top.x-18
		level.player.position=Vector2(x,level.scene1.ground_top(x))-Vector2(13,54)
		# Relocate the camera while the death iris is fully closed, rather
		# than finishing a long vertical pan after the picture has reopened.
		_snap_follow_camera()
	else:
		level.player.position = (ORIGIN+Vector2(875,555) if reached_bank else ORIGIN+Vector2(180,400))-Vector2(13,56)
	level.player.velocity = Vector2.ZERO
	level.facing = 1.0
	level.jump_buffer = 0.0
	level.jump_windup_left = 0.0
	level.coyote = 0.0
	gripping = false
	release_left = 0.0
	fall_in_air = false
	air_max_speed=0.0
	was_grounded=true
	shake_energy=0.0
	camera_bob=0.0
	camera_bob_speed=0.0
	if respawn_to_top and failure_time<=0:
		_release_to_top()
	# World state intentionally stays: a completed bridge is never replayed.

func _release_to_top() -> void:
	stop()
	respawn_to_top=false
	level.checkpoint=6
	level.scene1.cut=level.scene1.Cut.DONE
	level.scene1.intro_time=99

func begin_fall_tracking(at:Vector2)->void:
	fall_in_air=true
	fall_peak_y=at.y

func observe_fall()->bool:
	var sole:Vector2=level.player.position+Vector2(13,54)
	if not level.player.is_on_floor():
		if not fall_in_air:
			begin_fall_tracking(sole)
		fall_peak_y=minf(fall_peak_y,sole.y)
	elif fall_in_air:
		fall_in_air=false
		if sole.y-fall_peak_y>level.LETHAL_FALL:
			fail(&"fall")
			return true
	return false

func save_ground_checkpoint()->void:
	var sole:Vector2=level.player.position+Vector2(13,54)
	if level.player.is_on_floor() and absf(sole.y-LEFT.position.y)<8 and sole.x<LEFT.end.x:
		left_bank_reached=true

func fail(kind:StringName)->void:
	if failure_time>0:
		return
	failure_kind=kind
	failure_time=0.001
	restored=false
	deaths+=1
	gripping=false
	fall_in_air=false
	level.player.velocity=Vector2.ZERO

func pin_hand() -> Vector2:
	return PIN_HOME-Vector2(extraction+28,0)

func grip_feet_x() -> float:
	return pin_hand().x-31.0

func can_grab() -> bool:
	var feet: Vector2 = level.player.position+Vector2(13,54)
	return state == State.PROPPED and level.player.is_on_floor() and absf(feet.x-grip_feet_x()) < 34 and absf(feet.y-LEFT.position.y) < 7

func _update_log(delta: float) -> void:
	if state == State.PROPPED:
		_sync_supported_pose(delta)
	elif state == State.FALLING:
		angular_speed = minf(2.1,angular_speed+4.0*maxf(0.15,cos(angle))*delta)
		angle += angular_speed*delta
		if angle >= END_ANGLE:
			angle = END_ANGLE
			state = State.SETTLING
			settling = 0.0
			bridge_deflection = 0.0
			bridge_sway_speed = 0.32
			impact_impulses+=1
			shake_energy=maxf(shake_energy,7.0)
			camera_bob_speed+=130.0
			sounds.impact.play()
			art.impact()
	elif state == State.SETTLING:
		settling += delta
		# Impact rings through the whole trunk before the slower footstep spring.
		bridge_sway_speed += (-110*bridge_deflection-8*bridge_sway_speed)*delta
		bridge_deflection = clampf(bridge_deflection+bridge_sway_speed*delta,-0.015,0.030)
		var rattle := sin(settling*58)*0.0035*exp(-settling*7)
		angle = END_ANGLE+bridge_deflection+rattle
		if settling >= 1.05 and absf(bridge_deflection)<0.004:
			state = State.BRIDGED
	elif state == State.BRIDGED:
		var loaded := _on_log()
		var local_feet: Vector2 = log_body.to_local(level.player.position+Vector2(13,54))
		var weight := sin(PI*clampf(local_feet.x/LENGTH,0,1)) if loaded else 0.0
		if loaded and not bridge_loaded:
			bridge_sway_speed += 0.055*maxf(0.25,weight)
			bridge_impulses += 1
			sounds.creak.play()
			bridge_step_distance = 0
		elif loaded:
			bridge_step_distance += absf(local_feet.x-last_load_x)
			if bridge_step_distance >= 24:
				bridge_step_distance = fmod(bridge_step_distance,24)
				bridge_sway_speed += 0.014*maxf(0.3,weight)
				bridge_impulses += 1
		bridge_loaded = loaded
		last_load_x = local_feet.x
		bridge_sway_speed += ((0.008*weight-bridge_deflection)*65-bridge_sway_speed*5.5)*delta
		bridge_deflection = clampf(bridge_deflection+bridge_sway_speed*delta,-0.004,0.014)
		angle = END_ANGLE+bridge_deflection
	log_body.transform = Transform2D(angle,PIVOT)

func _on_log() -> bool:
	if not active or not level.player.is_on_floor():
		return false
	for i in level.player.get_slide_collision_count():
		var contact = level.player.get_slide_collision(i)
		if contact.get_collider() == log_body and contact.get_normal().y < -0.6:
			return true
	# Floor snapping can establish floor support without adding a slide
	# collision to this frame's list. Check that supported sole geometrically.
	var sole: Vector2 = log_body.to_local(level.player.position+Vector2(13,54))
	return sole.x>12 and sole.x<LENGTH-12 and absf(sole.y)<8

func wedge_slope()->float:
	var first:Vector2=SUPPORT_LOCAL.rotated(START_ANGLE)
	var last:Vector2=SUPPORT_LOCAL.rotated(SUPPORTED_RELEASE_ANGLE)
	return (last.y-first.y)/(last.x-first.x+PIN_TRAVEL)

func wedge_tip_home()->Vector2:
	return PIVOT+SUPPORT_LOCAL.rotated(SUPPORTED_RELEASE_ANGLE)+Vector2(PIN_TRAVEL,0)

func wedge_top_y(world_x:float)->float:
	var first:Vector2=PIVOT+SUPPORT_LOCAL.rotated(START_ANGLE)
	return first.y+wedge_slope()*(world_x-first.x+extraction)

func support_world()->Vector2:
	return PIVOT+SUPPORT_LOCAL.rotated(angle)

func support_remaining()->float:
	return wedge_tip_home().x-extraction-support_world().x

func wedge_polygon()->PackedVector2Array:
	var first:Vector2=PIVOT+SUPPORT_LOCAL.rotated(START_ANGLE)
	var left:Vector2=first-Vector2(12,12*wedge_slope())
	var tip:Vector2=wedge_tip_home()
	return PackedVector2Array([left-PIN_HOME,tip-PIN_HOME,Vector2(tip.x-1,PIVOT.y)-PIN_HOME,Vector2(left.x-1,PIVOT.y)-PIN_HOME])

func _sync_supported_pose(delta:float)->void:
	# Solve contact against the RIGID wedge ramp, not a percentage animation.
	# The bridge follows the lowering ramp immediately and cannot hang above it.
	var low:float=START_ANGLE
	var high:float=SUPPORTED_RELEASE_ANGLE
	for i in 26:
		var mid:float=(low+high)*0.5
		var point:Vector2=PIVOT+SUPPORT_LOCAL.rotated(mid)
		if point.y<wedge_top_y(point.x): low=mid
		else: high=mid
	var next_angle:float=(low+high)*0.5
	angular_speed=maxf(0.0,(next_angle-angle)/maxf(delta,0.0001))
	angle=next_angle
	log_body.transform=Transform2D(angle,PIVOT)

func _pull(delta: float, direction: float) -> void:
	pull_motion = 0.0
	grip_elapsed += delta
	var player: CharacterBody2D = level.player
	player.velocity.y = minf(850,player.velocity.y+1500*delta)
	if grip_elapsed < GRIP_SECONDS:
		var desired := grip_start.lerp(Vector2(grip_feet_x()-13,grip_start.y),smoothstep(0,GRIP_SECONDS,grip_elapsed))
		player.velocity.x = (desired.x-player.position.x)/delta
		player.move_and_slide()
		return
	if direction < -0.1:
		var before := player.position.x
		var resistance:float=lerpf(0.60,1.0,extraction/PIN_TRAVEL)
		player.velocity.x = -minf(PULL_SPEED*resistance,(PIN_TRAVEL-extraction)/delta)
		player.move_and_slide()
		var travel := maxf(0,before-player.position.x)
		extraction = minf(PIN_TRAVEL,extraction+travel)
		grip_distance += travel
		pull_motion = travel
		pin_body.position = PIN_HOME-Vector2(extraction,0)
		_sync_supported_pose(delta)
		if travel>0.001:
			art.scrape(travel,extraction/PIN_TRAVEL)
			pull_feedback_distance+=travel
			if pull_feedback_distance>=4.0:
				pull_feedback_distance=fmod(pull_feedback_distance,4.0)
				shake_energy=maxf(shake_energy,0.35)
				if pull_sound_cooldown<=0.0:
					sounds.creak.pitch_scale=lerpf(1.0,0.78,extraction/PIN_TRAVEL)
					if not sounds.creak.playing: sounds.creak.play()
					pull_sound_cooldown=0.28
		if support_remaining()<=0.001:
			state = State.FALLING
			angular_speed = maxf(0.12,angular_speed)
			gripping = false
			release_left = RELEASE_SECONDS
			pin_body.freeze = false
			pin_body.linear_velocity = Vector2(-55,12)
			pin_body.angular_velocity = -1.1
			sounds.release.play()
			art.release_dust()
	else:
		player.velocity.x = 0.0
		player.move_and_slide()

func tick(delta: float) -> bool:
	if not active:
		var p: Vector2 = level.player.position
		if p.x > -3515 and p.x < PIVOT.x-60 and p.y > -4470 and p.y < -4200 and not level.descent.enabled:
			enter(false)
		else:
			return false
	_tick_feedback(delta)
	_update_log(delta)
	release_left = maxf(0,release_left-delta)
	if failure_time > 0:
		failure_time += delta
		var restore_at:=0.85 if failure_kind==&"fall" else 0.45
		var finish_at:=1.25 if failure_kind==&"fall" else 0.85
		if failure_time >= restore_at and not restored:
			respawn()
			restored = true
		if failure_time > finish_at:
			failure_time = 0.0
			if respawn_to_top:
				_release_to_top()
				level._present(0.0)
				return true
		_update_camera(delta)
		_present(delta)
		return true
	var direction := Input.get_axis("move_left","move_right")
	var approach_speed:float=maxf(0.0,level.player.velocity.y)
	if gripping and (not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump") or not level.player.is_on_floor()):
		gripping = false
		release_left = 0.0 if Input.is_action_just_pressed("jump") else RELEASE_SECONDS
	if not gripping and Input.is_action_just_pressed("interact") and can_grab():
		gripping = true
		grip_elapsed = 0.0
		grip_start = level.player.position
		grip_distance = 0.0
		hand_start = level.actor.grip_hand_world()
		level.facing = 1.0
		sounds.creak.play()
	if gripping:
		_pull(delta,direction)
	else:
		if absf(direction) > 0.01:
			level.facing = signf(direction)
		level._update_player(delta,direction,0.0)
	if observe_fall():
		_update_camera(delta)
		_present(delta)
		return true
	save_ground_checkpoint()
	var grounded: bool = level.player.is_on_floor()
	if grounded and not was_grounded:
		landings += 1
		landing_feedback(maxf(approach_speed,air_max_speed))
	if grounded:
		air_max_speed=0.0
	else:
		air_max_speed=maxf(air_max_speed,level.player.velocity.y)
	was_grounded = grounded
	var feet: Vector2 = level.player.position+Vector2(13,54)
	if grounded and feet.x > RIGHT.position.x+45 and absf(feet.y-RIGHT.position.y) < 8:
		reached_bank = true
	if feet.y > LEFT.position.y+650:
		fail(&"void")
	_update_camera(delta)
	_present(delta)
	return true

func _update_camera(delta: float) -> void:
	# Forest, ladder, banks and bridge all follow the same physical actor.
	# Changing movement mode never introduces a different camera anchor.
	level._update_camera(delta)
	level.camera.offset = camera_feedback_offset()

func _snap_follow_camera()->void:
	# DEBUG entry and the fully closed death iris only, never a traversal handoff.
	level.camera_x=clampf(level.player.position.x-525.0,level.WORLD_MIN_X,level.WORLD_WIDTH-1280.0)
	level.camera_y=level._camera_target_y()
	level.camera.position=Vector2(level.camera_x+640,level.camera_y+360)
	level.camera.offset=Vector2.ZERO

func _tick_feedback(delta:float)->void:
	var frame_id:int=Engine.get_physics_frames()
	if frame_id==feedback_frame: return
	feedback_frame=frame_id
	feedback_clock+=delta
	pull_sound_cooldown=maxf(0,pull_sound_cooldown-delta)
	shake_energy*=exp(-delta*9.0)
	camera_bob_speed+=(-105.0*camera_bob-13.0*camera_bob_speed)*delta
	camera_bob=clampf(camera_bob+camera_bob_speed*delta,-9.0,9.0)

func camera_feedback_offset()->Vector2:
	return Vector2(sin(feedback_clock*47.0),cos(feedback_clock*59.0)*0.60)*shake_energy+Vector2(0,camera_bob)

func landing_feedback(speed:float,ladder_drop:=false)->void:
	if speed<120.0: return
	landing_impulses+=1
	# Ordinary hops get only the smooth vertical camera follow. The child
	# never produces the heavy, high-frequency shake reserved for the log.
	if speed<650.0:
		if ladder_drop:
			camera_bob_speed+=18.0
			art.landing_dust(level.player.position+Vector2(13,54),0.65)
		return
	var force:float=clampf((speed-550.0)/130.0,0.8,2.4)
	camera_bob_speed+=force*24.0
	shake_energy=maxf(shake_energy,force*0.35)
	art.landing_dust(level.player.position+Vector2(13,54),force)

func _present(delta: float) -> void:
	var action: StringName = Pose.ACTION_NONE
	var progress := 0.0
	if failure_time > 0 and not restored:
		if failure_kind==&"fall":
			action=Pose.ACTION_FALL_IMPACT if failure_time<0.542 else Pose.ACTION_DOWNED
			progress=clampf(failure_time/0.542,0,1)
		else:
			action = Pose.ACTION_UNCONTROLLED_FALL
			progress = failure_time
	elif gripping:
		if grip_elapsed < GRIP_SECONDS:
			action = &"grip_engage"
			progress = grip_elapsed/GRIP_SECONDS
		else:
			action = &"pull" if pull_motion > 0.01 else &"grip_hold"
	elif release_left > 0:
		action = &"grip_release"
		progress = 1-release_left/RELEASE_SECONDS
	elif level.scene1.low_stance.active():
		var low_pose:Dictionary=level.scene1.low_stance.pose_info()
		action=low_pose.action
		progress=low_pose.progress
	var pose = Pose.new()
	pose.apply({"feet":level.player.position+Vector2(13,54),"velocity":level.player.velocity,"grounded":level.player.is_on_floor(),"facing":level.facing,"action":action,"action_progress":progress,"visual_scale":Pose.HOOD_VISUAL_SCALE,"fog_blur":level.ACTOR_EDGE_SOFTNESS,"jump_windup":(1.0-level.jump_windup_left/Pose.HOOD_JUMP_WINDUP) if level.jump_windup_left>0.0 else -1.0})
	level.actor.grip_distance = grip_distance
	level.actor.rope_allowed = false
	level.actor.contact_reach = 31.0
	level.actor.contact_sink = 0.0
	level.actor.sync_pose(delta,pose)
	level.actor.rotation = 0.0
	level.actor.modulate.a = level.rope_ladder.fog_visibility_at(level.player.position+Vector2(13,54)) if level.rope_ladder != null else 1.0
	level.actor.apply_surface_contact(delta,level.player,level.player.is_on_floor())
	# Align the same hand marker used by C's lever to the independent pin.
	if gripping:
		var blend := smoothstep(0,GRIP_SECONDS,grip_elapsed)
		var target: Vector2 = hand_start.lerp(pin_hand(),blend)
		level.actor.position += target-level.actor.grip_hand_world()
	_present_world(delta)

func _present_world(delta:float)->void:
	# Shared scenery only. A recorded ladder pose must never be preceded by
	# an idle/air pose update of the same actor in the same physics frame.
	var origin := Vector2(level.camera_x,level.camera_y)
	level.art.sync(delta,origin.x,true)
	# The very distant vista stays steady while the nearby banks take the hit.
	level.art.landmark_output.position=Vector2.ZERO
	var entrance:float=level.rope_ladder.entry_mix() if level.rope_ladder != null else 1.0
	level.marsh_art.sync(delta,origin.x,entrance<0.999)
	for stage in [level.marsh_art.back_stage,level.marsh_art.front_stage]:
		stage.sprite.modulate.a=1.0-entrance
		stage.material.set_shader_parameter("opacity",1.0-entrance)
	art.sync(delta,origin,true)
	if level.iris != null:
		var shade := smoothstep(0.45,0.8,failure_time) if not restored else 1-smoothstep(0.85,1.25,failure_time)
		if failure_kind!=&"fall":
			shade=smoothstep(0,0.35,failure_time) if not restored else 1-smoothstep(0.45,0.85,failure_time)
		level.iris.call("set_state",shade if failure_time > 0 else 0.0,level.player.position-origin+Vector2(13,27))
