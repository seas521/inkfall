extends "res://scripts/actors/seedance_frame_actor.gd"

const Grip = preload("res://scripts/demos/c_zone_debug/seedance_grip_manifest.gd")
const SurfaceContact = preload("res://scripts/demos/c_zone_debug/surface_contact.gd")
const Hand = preload("res://scripts/demos/c_zone_debug/single_hand_manifest.gd")
const Swing = preload("res://scripts/demos/c_zone_debug/fan_swing_manifest.gd")
const Drown = preload("res://scripts/demos/c_zone_debug/drown_manifest.gd")
const LOCOMOTION_HOLD_TIME := 0.12
var grip_distance := 0.0
var locomotion_hold_time := 0.0
var surface_contact = SurfaceContact.new()
var support_offset := 0.0
var support_point := Vector2.ZERO
var support_valid := false
var held_clip: StringName = &"grip_hold"
var held_frame := 0
var movement_clip: StringName = &""
var movement_start_distance := 0.0

func fan_hand_position() -> Vector2:
	if current_clip == Swing.CLIP:
		return to_global(animated.position + Swing.HANDS[current_frame_index] * animated.scale)
	if pose.small_item_kind == &"fan" and Hand.CLIPS.has(current_clip):
		return to_global(animated.position+Hand.hand_anchor(current_clip,current_frame_index)*animated.scale)
	var anchor = Manifest.small_item_anchor(current_clip,current_frame_index)
	if anchor == null and current_clip == &"throw_release":
		anchor = Manifest.small_item_anchor(current_clip,3)
	if anchor == null:
		anchor = Manifest.small_item_anchor(&"carry",0)
	return to_global(animated.position + Vector2(anchor)*animated.scale)

func fan_swing_angle() -> float:
	if current_clip == Swing.CLIP:
		return Swing.angle(current_frame_index)
	# Keep locomotion and airborne legs until matching moving swing frames exist.
	return 0.9 + sin(pose.action_progress * PI * 2.0) * 0.45

func _apply_small_item(metadata: Dictionary, frame_index: int) -> void:
	if pose.small_item_kind != &"fan":
		super._apply_small_item(metadata,frame_index)
		return
	# Local complete frames contain an empty grip, with no baked prop or marker.
	small_item.hide()
	(animated.material as ShaderMaterial).set_shader_parameter("marker_center",Vector2(-100,-100))

func reset_grip_animation() -> void:
	held_clip = &"grip_hold"
	held_frame = 0
	movement_clip = &""
	movement_start_distance = grip_distance

func apply_surface_contact(delta: float, body: CharacterBody2D, grounded: bool) -> void:
	var target := 0.0
	support_valid = false
	if grounded:
		var contact: Dictionary = surface_contact.solve(animated, body)
		support_valid = contact.valid
		support_point = contact.point
		target = contact.offset if support_valid else 0.0
	# A small visual correction only; physics, scale and the frame root stay intact.
	support_offset = move_toward(support_offset, target, delta * 100.0) if delta > 0.0 else target
	position.y += support_offset

func _build_sprite_frames() -> SpriteFrames:
	var library := super._build_sprite_frames()
	for clip in Hand.CLIPS:
		for i in int(Manifest.CLIPS[clip].frames):
			library.set_frame(clip,i,load(Hand.frame_path(clip,i)))
	for clip: StringName in Grip.CLIPS:
		library.add_animation(clip)
		library.set_animation_loop(clip, bool(Grip.CLIPS[clip].loop))
		library.set_animation_speed(clip, 24.0)
		for i in int(Grip.CLIPS[clip].frames):
			library.add_frame(clip, load(Grip.frame_path(clip, i)))
	library.add_animation(Swing.CLIP)
	library.set_animation_loop(Swing.CLIP, false)
	library.set_animation_speed(Swing.CLIP, 24.0)
	for i in Swing.COUNT:
		library.add_frame(Swing.CLIP, load(Swing.frame_path(i)))
	library.add_animation(Drown.CLIP)
	library.set_animation_loop(Drown.CLIP,false)
	for i in Drown.COUNT:
		library.add_frame(Drown.CLIP,load(Drown.frame_path(i)))
	return library

func sync_pose(delta: float, next_pose) -> void:
	if not next_pose.grounded or next_pose.action != ActorPoseState.ACTION_NONE:
		locomotion_hold_time = 0.0
	elif absf(next_pose.velocity.x) > 25.0:
		locomotion_hold_time = LOCOMOTION_HOLD_TIME
	else:
		locomotion_hold_time = maxf(0.0, locomotion_hold_time - delta)
	super.sync_pose(delta, next_pose)

func _choose_clip() -> StringName:
	if pose.action == Drown.CLIP:
		return Drown.CLIP
	if Grip.CLIPS.has(pose.action):
		return pose.action
	# The new full-body clip is grounded-only; never freeze walking/jumping legs.
	if pose.small_item_kind == &"fan" and pose.action == ActorPoseState.ACTION_THROW_RELEASE:
		if not pose.grounded:
			if takeoff_time>0.0:
				return &"carry_takeoff"
			return &"carry_rise" if pose.velocity.y < -85.0 else (&"carry_apex" if pose.velocity.y < 95.0 else &"carry_fall")
		if landing_time>0.0:
			return &"carry_land"
		return &"carry_run" if absf(pose.velocity.x)>25.0 else Swing.CLIP
	var selected := super._choose_clip()
	# Keep the distance-driven walk pose through brief collision stalls, without
	# advancing its feet or delaying jump, grip, landing, or other actions.
	if selected == &"idle" and current_clip == &"run" and locomotion_hold_time > 0.0:
		return &"run"
	return selected

func _apply_frame() -> void:
	if current_clip == Drown.CLIP:
		reset_grip_animation()
		current_frame_index = Drown.frame_at(pose.action_progress)
		animated.scale = Vector2.ONE
		animated.position = -Drown.ROOT
		animated.flip_h = false
		animated.animation = Drown.CLIP
		animated.frame = current_frame_index
		small_item.hide()
		(animated.material as ShaderMaterial).set_shader_parameter("marker_center",Vector2(-100,-100))
		return
	if current_clip == Swing.CLIP:
		reset_grip_animation()
		current_frame_index = Swing.frame_at(pose.action_progress)
		animated.scale = Vector2.ONE
		animated.position = -Swing.ROOT
		animated.flip_h = false
		animated.animation = Swing.CLIP
		animated.frame = current_frame_index
		small_item.hide()
		(animated.material as ShaderMaterial).set_shader_parameter("marker_center", Vector2(-100,-100))
		return
	if not Grip.CLIPS.has(current_clip):
		reset_grip_animation()
		var saved_action: StringName = pose.action
		if pose.small_item_kind == &"fan" and pose.action == ActorPoseState.ACTION_THROW_RELEASE:
			pose.action = ActorPoseState.ACTION_NONE
		super._apply_frame()
		pose.action = saved_action
		return
	var render_clip := current_clip
	var count := int(Grip.CLIPS[current_clip].frames)
	var index := clampi(int(pose.action_progress * float(count)), 0, count - 1)
	if current_clip == &"grip_engage":
		reset_grip_animation()
	if current_clip in [&"pull", &"push"]:
		if movement_clip != current_clip:
			movement_clip = current_clip
			movement_start_distance = grip_distance
		var step := int(floor(maxf(0.0, grip_distance - movement_start_distance) / Grip.CYCLE_DISTANCE * count))
		var lead := int(Grip.CLIPS[&"pull_enter"].frames) if current_clip == &"pull" else 0
		if step < lead:
			render_clip = &"pull_enter"
			index = step
		else:
			index = (step - lead) % count
	elif current_clip == &"grip_hold":
		# Hold the actual last effort pose, including a partially completed entry.
		render_clip = held_clip
		index = held_frame
	if current_clip != &"grip_release":
		held_clip = render_clip
		held_frame = index
	animated.scale = Vector2.ONE
	animated.position = -Grip.ROOT
	animated.flip_h = false
	animated.animation = render_clip
	animated.frame = index
	current_frame_index = index
	small_item.hide()
	(animated.material as ShaderMaterial).set_shader_parameter("marker_center", Vector2(-100,-100))
