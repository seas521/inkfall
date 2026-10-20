# Preserved broken-crate prototype. Develop the replacement raft separately.
extends "res://scripts/actors/seedance_frame_actor.gd"

const Grip = preload("res://scripts/prototypes/c_zone_broken_crate/seedance_grip_manifest.gd")
const SurfaceContact = preload("res://scripts/prototypes/c_zone_broken_crate/surface_contact.gd")
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
	for clip: StringName in Grip.CLIPS:
		library.add_animation(clip)
		library.set_animation_loop(clip, bool(Grip.CLIPS[clip].loop))
		library.set_animation_speed(clip, 24.0)
		for i in int(Grip.CLIPS[clip].frames):
			library.add_frame(clip, load(Grip.frame_path(clip, i)))
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
	if Grip.CLIPS.has(pose.action):
		return pose.action
	var selected := super._choose_clip()
	# Keep the distance-driven walk pose through brief collision stalls, without
	# advancing its feet or delaying jump, grip, landing, or other actions.
	if selected == &"idle" and current_clip == &"run" and locomotion_hold_time > 0.0:
		return &"run"
	return selected

func _apply_frame() -> void:
	if not Grip.CLIPS.has(current_clip):
		reset_grip_animation()
		super._apply_frame()
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
