extends Node2D

const Pose = preload("res://scripts/actors/actor_pose_state.gd")
const Frames = preload("res://scripts/actors/rope_ladder_manifest.gd")
const EyeTracks = preload("res://scripts/actors/hood_eye_tracks.gd")
const Scene1 = preload("res://scripts/demos/c_zone_debug/scene1_act.gd")
const Art = preload("res://scripts/demos/c_zone_debug/rope_ladder_art.gd")
const DISPLAY := 0.42*Pose.HOOD_VISUAL_SCALE
const CATCH_RADIUS := 85.0
const CATCH_FROM := 128.0
const CATCH_LAUNCH := 140.0
const CATCH_CONTACT := 147.0
const CATCH_END := 159.0
enum Mode { NONE, MOUNT, HOLD, CLIMB, EXIT, CATCH, TAKEOFF, AIR, LAND }
var level
var art: Node2D
var mode := Mode.NONE
var frame := 42.0
var source_origin := Vector2.ZERO
var segment_origin := Vector2.ZERO
var segment_from := Vector2.ZERO
var climb_direction := 0
var jump_direction := 1.0
var swing := 0.0
var swing_speed := 0.0
var cooldown := 0.0
var original_mask := 11
var returned_top := 0
var caught := 0
var jumps := 0
var last_hand := Vector2.ZERO
var art_visible := false
var at_bottom := false
var clock := 0.0
var catch_hand_y := 0.0

func _ready() -> void:
	art = Art.new()
	art.ladder = self
	add_child(art)

func anchor() -> Vector2:
	return Vector2(Scene1.CLIFF_X-8,Scene1.ground_top(Scene1.CLIFF_X)-2)

func source_scale() -> float:
	return float(Frames.DATA.scale)*DISPLAY

func length() -> float:
	return level.log_bridge.LEFT.position.y-anchor().y-80.0

func rung_pitch() -> float:
	return 90.0*source_scale()

func lower_feet_y() -> float:
	var first:=100.0*source_scale()
	var last:=first+floorf((length()-4.0-first)/rung_pitch())*rung_pitch()
	return anchor().y+last+1.5

func bend(depth: float) -> float:
	var t := clampf(depth/maxf(length(),1.0),0,1)
	return swing*pow(t,0.8)+sin(t*PI)*swing*0.12

func entry_mix() -> float:
	# Establish the gorge while approaching the edge, then retain it through
	# climbing, jumping, landing and returning. No movement-mode switching.
	var p:=feet()
	if level.descent.enabled or p.x>Scene1.CLIFF_X+1400 or p.y>level.log_bridge.LEFT.position.y+250:
		return 0.0
	return smoothstep(Scene1.CLIFF_X-520,Scene1.CLIFF_X-260,p.x)

func fog_visibility_at(point: Vector2) -> float:
	return 1.0

func _process(delta:float)->void:
	if level.paused:
		return
	_update_art()
	if not level.log_bridge.active:
		# The same world-space backdrop is already present at the cliff lip.
		level.log_bridge.art.sync(delta,Vector2(level.camera_x,level.camera_y),level.camera_x < -2400.0 and not level.descent.enabled)

func active() -> bool:
	return mode != Mode.NONE

func _track(index: float, field: String) -> Vector2:
	var i := clampi(int(index),0,240)
	var p: Array = Frames.DATA.tracks[i][field]
	return (Vector2(p[0],p[1])-Vector2(384,365))*source_scale()

func feet() -> Vector2:
	return level.player.position+Vector2(13,54)

func _eye() -> Vector2:
	return source_origin+_track(frame,"eye")

func _begin(next: Mode, first: float) -> void:
	if level.scene1.low_stance!=null:level.scene1.low_stance.reset()
	mode = next
	frame = first
	segment_origin = source_origin
	segment_from = feet()
	level.player.velocity = Vector2.ZERO
	level.actor.load_group("rope_ladder")
	level.actor.begin_rope_ladder()
	level.player.collision_mask = 0
	level.jump_buffer = 0.0
	level.jump_windup_left = 0.0
	level.climb_time = -1.0
	level.facing = -1.0
	at_bottom = false

func mount_top() -> void:
	var from := feet()
	level.log_bridge.enter(false)
	source_origin = from-_track(10,"feet")
	_begin(Mode.MOUNT,10)
	swing_speed += 4.0

func catch_from_bank() -> void:
	level.log_bridge.enter(false)
	source_origin = feet()-_track(CATCH_FROM,"feet")
	_begin(Mode.CATCH,CATCH_FROM)
	var target:=anchor()
	target.y=lower_feet_y()+rung_pitch()*2-_track(CATCH_END,"feet").y
	var reach_y:float=target.y+_track(CATCH_END,"hand").y
	var first_rung:float=anchor().y+100.0*source_scale()
	catch_hand_y=first_rung+roundf((reach_y-first_rung)/rung_pitch())*rung_pitch()
	caught += 1

func _catch_hand() -> Vector2:
	return Vector2(anchor().x+bend(catch_hand_y-anchor().y),catch_hand_y)

func _catch_head(index:float) -> Vector2:
	var eye:Array=EyeTracks.DATA.rope_ladder[clampi(int(index),0,240)]
	return Vector2(float(eye[0]),float(eye[1]))*DISPLAY

func _present_catch_motion() -> void:
	if frame<=CATCH_LAUNCH:
		# The source crouch is still supported by the bank. Translating its
		# root toward the ladder here used to lift the crouch into thin air.
		source_origin=segment_from-_track(frame,"feet")
	elif frame<CATCH_CONTACT:
		var t:float=(frame-CATCH_LAUNCH)/(CATCH_CONTACT-CATCH_LAUNCH)
		var from_head:Vector2=segment_from-_track(CATCH_LAUNCH,"feet")+_catch_head(CATCH_LAUNCH)
		var to_head:Vector2=_catch_hand()-_track(CATCH_CONTACT,"hand")+_catch_head(CATCH_CONTACT)
		# One continuous flight. Anchor the torso via the head, not the
		# swinging lowest foot, so tucking a leg cannot launch a second hop.
		var head:Vector2=from_head.lerp(to_head,t)+Vector2(0,-40.0*t*(1.0-t))
		source_origin=head-_catch_head(frame)
	else:
		# Weight is now on the rung. Keep the recorded hand attached while
		# the legs swing underneath and find their footholds.
		source_origin=_catch_hand()-_track(frame,"hand")
	_follow_source()

func can_catch_from_bank() -> bool:
	if not level.log_bridge.active or cooldown>0 or not level.player.is_on_floor():
		return false
	var end_x:float=anchor().x+bend(length())
	return absf(feet().x-end_x)<=CATCH_RADIUS and absf(feet().y-level.log_bridge.LEFT.position.y)<12

func stop() -> void:
	if level.player != null:
		level.player.collision_mask = original_mask
	mode = Mode.NONE
	climb_direction = 0
	cooldown = 0.3

func _start_climb(direction: int) -> void:
	if direction < 0:
		at_bottom = false
	var hand := source_origin+_track(frame,"hand")
	var target := 42 if direction > 0 else 159
	if direction < 0 and int(frame) >= 42 and int(frame) <= 67:
		target = int(Frames.DATA.up_from_down[int(frame)-42])
	elif direction > 0 and int(frame) >= 159 and int(frame) <= 183:
		target = int(Frames.DATA.down_from_up[int(frame)-159])
	elif direction == climb_direction:
		target = int(frame)
	frame = target
	source_origin = hand-_track(frame,"hand")
	climb_direction = direction
	mode = Mode.CLIMB
	swing_speed += direction*1.1

func _start_exit() -> void:
	var eye := _eye()
	source_origin = eye-_track(194,"eye")
	_begin(Mode.EXIT,194)

func _jump_off() -> void:
	level.log_bridge.begin_fall_tracking(feet())
	jump_direction = Input.get_axis("move_left","move_right")
	if absf(jump_direction) < 0.1:
		jump_direction = 1.0
	source_origin = feet()-_track(91,"feet")
	_begin(Mode.TAKEOFF,91)
	jumps += 1
	swing_speed -= jump_direction*7.0

func tick(delta: float) -> bool:
	clock += delta
	cooldown = maxf(0,cooldown-delta)
	var previous_swing := swing
	if mode == Mode.CLIMB:
		# Alternating weight transfers keep exciting the flexible ladder.
		# The forcing stops when the player releases W/S, then it settles.
		swing_speed += sin(frame*TAU/26.0)*90.0*delta
	swing_speed += (-15.0*swing-3.0*swing_speed)*delta
	swing = clampf(swing+swing_speed*delta,-12.0,12.0)
	if not active():
		var top := anchor()
		var p := feet()
		if cooldown <= 0 and not level.descent.enabled and level.player.is_on_floor() and level.log_bridge.failure_time<=0:
			var top_mount:bool=absf(p.x-(top.x-18))<40 and absf(p.y-(top.y+2))<12 and Input.is_action_pressed("climb_down")
			if top_mount:
				# Ladder descent owns S at contact, even if the player approached
				# while crouched. Clear that pose before evaluating movement locks.
				if level.scene1.low_stance.active():level.scene1.low_stance.reset()
				if not level.scene1.locks_jump():mount_top()
			elif can_catch_from_bank() and Input.is_action_just_pressed("jump"):
				catch_from_bank()
		_update_art()
		if not active():
			return false
	level.log_bridge._tick_feedback(delta)
	var wants := int(Input.is_action_pressed("climb_down"))-int(Input.is_action_pressed("climb_up"))
	if mode in [Mode.HOLD,Mode.CLIMB]:
		if Input.is_action_just_pressed("jump"):
			_jump_off()
		elif wants == 0:
			mode = Mode.HOLD
		elif (mode == Mode.HOLD or climb_direction != wants) and not (wants>0 and at_bottom):
			_start_climb(wants)
	match mode:
		Mode.MOUNT:
			frame = minf(42,frame+delta*24)
			var u := smoothstep(10,42,frame)
			source_origin = segment_origin.lerp(anchor(),u)
			_follow_source()
			if frame >= 42:
				mode = Mode.HOLD
		Mode.CATCH:
			var previous_frame:float=frame
			frame = minf(CATCH_END,frame+delta*24)
			if previous_frame<CATCH_CONTACT and frame>=CATCH_CONTACT:
				swing_speed-=5.0
			_present_catch_motion()
			if frame >= CATCH_END:
				mode = Mode.HOLD
		Mode.CLIMB:
			var start := 42 if climb_direction>0 else 159
			var end := 68 if climb_direction>0 else 184
			frame += delta*24
			if frame >= end:
				# One complete recorded left/right cycle advances exactly two rungs.
				source_origin.y += float(climb_direction)*rung_pitch()*2
				frame = start+fposmod(frame-start,end-start)
			_follow_source()
			if climb_direction<0 and _eye().y <= anchor().y+_track(194,"eye").y+2:
				_start_exit()
			elif climb_direction>0 and feet().y >= lower_feet_y():
				mode = Mode.HOLD
				at_bottom = true
		Mode.HOLD:
			_follow_source()
		Mode.EXIT:
			frame = minf(234,frame+delta*24)
			source_origin = segment_origin.lerp(anchor(),smoothstep(194,234,frame))
			_follow_source()
			if frame >= 234:
				_finish_top()
		Mode.TAKEOFF:
			frame = minf(100,frame+delta*24)
			_follow_source()
			if frame >= 100:
				mode = Mode.AIR
				frame = 101
				level.player.collision_mask = original_mask
				level.player.velocity = Vector2(jump_direction*145,-170)
		Mode.AIR:
			level.player.velocity.y = minf(850,level.player.velocity.y+1500*delta)
			var impact_speed:float=maxf(0.0,level.player.velocity.y)
			var side := Input.get_axis("move_left","move_right")
			if absf(side)>0.1:
				level.player.velocity.x = move_toward(level.player.velocity.x,side*145,delta*600)
			level.player.move_and_slide()
			frame = minf(108,frame+delta*24)
			source_origin = feet()-_track(frame,"feet")
			if level.log_bridge.observe_fall():
				stop()
				level.log_bridge._present(delta)
				_update_art()
				return true
			if level.player.is_on_floor():
				level.log_bridge.landing_feedback(impact_speed,true)
				level.log_bridge.was_grounded=true
				level.log_bridge.air_max_speed=0.0
				level.log_bridge.save_ground_checkpoint()
				mode = Mode.LAND
				frame = 109
		Mode.LAND:
			frame = minf(119,frame+delta*24)
			level.player.velocity = Vector2(0,40)
			level.player.move_and_slide()
			source_origin = feet()-_track(frame,"feet")
			if frame >=119:
				level.actor.finish_rope_ladder()
				stop()
	if active():
		if mode in [Mode.HOLD,Mode.CLIMB]:
			# Whole-body transport with the same flexible rail, never scale the boy.
			var depth := maxf(0,_eye().y-anchor().y+25)
			source_origin.x += (swing-previous_swing)*pow(clampf(depth/maxf(length(),1),0,1),0.8)
		_present(delta)
	_update_art()
	return active()

func _follow_source() -> void:
	level.player.position = source_origin+_track(frame,"feet")-Vector2(13,54)
	level.player.velocity = Vector2.ZERO

func _finish_top() -> void:
	var end_feet:=feet()
	stop()
	returned_top += 1
	level.log_bridge.stop()
	level.checkpoint = 6
	level.scene1.cut = Scene1.Cut.DONE
	level.scene1.intro_time = 99
	level.player.position = Vector2(end_feet.x,Scene1.ground_top(end_feet.x))-Vector2(13,54)
	level.player.velocity = Vector2.ZERO
	level.facing = -1
	level.actor.finish_rope_ladder()

func _present(delta: float) -> void:
	level.log_bridge._update_camera(delta)
	var pose = Pose.new()
	pose.apply({"feet":source_origin,"grounded":false,"velocity":Vector2.ZERO,"facing":-1,
		"action":&"rope_ladder","action_progress":frame/240.0,"visual_scale":Pose.HOOD_VISUAL_SCALE,"fog_blur":level.ACTOR_EDGE_SOFTNESS})
	level.actor.sync_pose(delta,pose)
	level.actor.body_offset = Vector2.ZERO
	level.actor.body.position = Vector2.ZERO
	level.actor.rotation = 0
	level.actor.ghost.hide()
	if mode==Mode.LAND or (mode==Mode.EXIT and frame>=233.0):
		level.actor.apply_surface_contact(delta,level.player,true)
	# Wide drifting fog pockets veil the whole figure, including his eye.
	level.actor.modulate.a = fog_visibility_at(feet())
	last_hand = source_origin+_track(frame,"hand")
	level.log_bridge._present_world(delta)

func _update_art() -> void:
	# Camera lead exposes the cliff before the player enters its interaction
	# radius. Warm the ladder viewport offscreen, including its full drop.
	var origin:=Vector2(level.camera_x,level.camera_y)
	var camera_bounds:=Rect2(origin,Vector2(1280,720)).grow(256.0)
	var ladder_bounds:=Rect2(anchor()-Vector2(140,16),Vector2(280,length()+40))
	art_visible = not level.descent.enabled and (level.log_bridge.active or camera_bounds.intersects(ladder_bounds))
	art.sync(origin,art_visible)
