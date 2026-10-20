extends Node2D

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const Manifest = preload("res://scripts/actors/crooked_tower_vector_manifest.gd")

const DISPLAY_SCALE := 0.47

var pose
var animated: AnimatedSprite2D
var head_glow: Sprite2D
var current_clip: StringName = &"idle"
var clip_time := 0.0
var travel_distance := 0.0
var previous_feet := Vector2.ZERO
var previous_ground := false
var previous_facing := 1.0
var previous_speed := 0.0
var takeoff_time := 0.0
var landing_time := 0.0
var start_time := 0.0
var stop_time := 0.0
var turn_time := 0.0

func _ready() -> void:
	animated = AnimatedSprite2D.new()
	animated.centered = false
	animated.position = -Manifest.ROOT
	animated.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	animated.sprite_frames = _build_sprite_frames()
	animated.animation = &"idle"
	animated.pause()
	add_child(animated)
	head_glow = Sprite2D.new()
	head_glow.show_behind_parent = true
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.26, 0.64, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.57, 0.19, 0.22),
		Color(0.84, 0.32, 0.07, 0.068),
		Color(0.42, 0.12, 0.02, 0.016),
		Color.TRANSPARENT,
	])
	var glow_texture := GradientTexture2D.new()
	glow_texture.width = 96
	glow_texture.height = 96
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	head_glow.texture = glow_texture
	head_glow.position = Vector2(22.0, -88.0)
	head_glow.scale = Vector2(0.58, 0.48)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	head_glow.material = additive
	add_child(head_glow)
	hide()

func _build_sprite_frames() -> SpriteFrames:
	var library := SpriteFrames.new()
	if library.has_animation(&"default"):
		library.remove_animation(&"default")
	for clip_name in Manifest.CLIPS.keys():
		var clip: StringName = clip_name
		var metadata: Dictionary = Manifest.CLIPS[clip]
		library.add_animation(clip)
		library.set_animation_speed(clip, float(metadata["fps"]))
		library.set_animation_loop(clip, bool(metadata["loop"]))
		for frame_index in range(int(metadata["frames"])):
			var texture_value: Texture2D = load(Manifest.frame_path(clip, frame_index))
			if texture_value == null:
				push_error("Missing independent vector frame: %s" % Manifest.frame_path(clip, frame_index))
				continue
			library.add_frame(clip, texture_value)
	return library

func sync_pose(delta: float, next_pose) -> void:
	pose = next_pose
	show()
	var speed := absf(pose.velocity.x)
	if previous_feet != Vector2.ZERO:
		travel_distance += absf(pose.feet.x - previous_feet.x)
	if pose.facing != previous_facing:
		turn_time = 0.14
	if not pose.grounded and previous_ground:
		takeoff_time = 0.11
	if pose.grounded and not previous_ground:
		landing_time = 0.18
	if speed > 25.0 and previous_speed <= 25.0 and pose.grounded:
		start_time = 0.14
	if speed <= 25.0 and previous_speed > 25.0 and pose.grounded:
		stop_time = 0.14
	takeoff_time = maxf(0.0, takeoff_time - delta)
	landing_time = maxf(0.0, landing_time - delta)
	start_time = maxf(0.0, start_time - delta)
	stop_time = maxf(0.0, stop_time - delta)
	turn_time = maxf(0.0, turn_time - delta)
	var next_clip := _choose_clip()
	if next_clip != current_clip:
		current_clip = next_clip
		clip_time = 0.0
	else:
		clip_time += delta
	_apply_frame()
	position = pose.feet
	scale = Vector2(pose.facing * DISPLAY_SCALE, DISPLAY_SCALE)
	var fade := 1.0
	if pose.failure_time > 0.0:
		fade = 1.0 - smoothstep(0.80, 1.0, pose.failure_time / maxf(0.01, pose.failure_duration))
	modulate.a = fade
	head_glow.modulate = Color(1.0, 0.49, 0.13, fade * (0.07 + pose.light_exposure * 0.05))
	previous_feet = pose.feet
	previous_ground = pose.grounded
	previous_facing = pose.facing
	previous_speed = speed

func _choose_clip() -> StringName:
	if pose.failure_time > 0.0:
		return &"failure"
	match pose.action:
		ActorPoseState.ACTION_PICKUP: return &"pickup"
		ActorPoseState.ACTION_PUT_DOWN: return &"put_down"
		ActorPoseState.ACTION_THROW_CHARGE: return &"throw_charge"
		ActorPoseState.ACTION_THROW_RELEASE: return &"throw_release"
		ActorPoseState.ACTION_SHIELD_EQUIP: return &"shield_equip"
		ActorPoseState.ACTION_SHIELD_RAISE: return &"shield_raise"
		ActorPoseState.ACTION_SHIELD_GUARD: return &"shield_guard"
		ActorPoseState.ACTION_SHIELD_LOWER: return &"shield_lower"
		ActorPoseState.ACTION_SHIELD_PARRY: return &"shield_parry"
		ActorPoseState.ACTION_SHIELD_BLOCK: return &"shield_block"
		ActorPoseState.ACTION_BLADE_EQUIP: return &"blade_equip"
		ActorPoseState.ACTION_BLADE_SWING: return &"blade_swing"
		ActorPoseState.ACTION_PUSH_ENGAGE: return &"push_engage"
		ActorPoseState.ACTION_PUSH: return &"push"
		ActorPoseState.ACTION_PUSH_RELEASE: return &"push_release"
		ActorPoseState.ACTION_HIT: return &"hit"
	if not pose.grounded:
		if takeoff_time > 0.0:
			return &"takeoff"
		if pose.velocity.y < -85.0:
			return &"rise"
		if pose.velocity.y < 95.0:
			return &"apex"
		return &"fall"
	if landing_time > 0.0:
		return &"land"
	if turn_time > 0.0:
		return &"turn"
	var moving := absf(pose.velocity.x) > 25.0
	if moving and start_time > 0.0:
		return &"start"
	if moving:
		if pose.equipment == ActorPoseState.EQUIPMENT_THROWABLE:
			return &"carry_walk"
		if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD:
			return &"shield_walk"
		if pose.equipment == ActorPoseState.EQUIPMENT_BLADE:
			return &"blade_walk"
		return &"walk"
	if stop_time > 0.0:
		return &"stop"
	if pose.equipment == ActorPoseState.EQUIPMENT_THROWABLE:
		return &"carry"
	if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD:
		return &"shield_ready"
	if pose.equipment == ActorPoseState.EQUIPMENT_BLADE:
		return &"blade_ready"
	return &"idle"

func _apply_frame() -> void:
	var metadata: Dictionary = Manifest.CLIPS[current_clip]
	var frame_count := int(metadata["frames"])
	var fps := float(metadata["fps"])
	var loop := bool(metadata["loop"])
	var frame_index := 0
	if current_clip in [&"walk", &"carry_walk", &"shield_walk", &"blade_walk"]:
		frame_index = int(travel_distance / 14.0) % frame_count
	elif current_clip == &"failure":
		var failure_progress: float = clampf(pose.failure_time / maxf(0.01, pose.failure_duration), 0.0, 1.0)
		frame_index = mini(frame_count - 1, int(round(failure_progress * float(frame_count - 1))))
	elif pose.action != ActorPoseState.ACTION_NONE:
		if loop:
			frame_index = int(clip_time * fps) % frame_count
		else:
			frame_index = mini(frame_count - 1, int(round(pose.action_progress * float(frame_count - 1))))
	elif loop:
		frame_index = int(clip_time * fps) % frame_count
	else:
		frame_index = mini(frame_count - 1, int(clip_time * fps))
	animated.animation = current_clip
	animated.frame = frame_index
