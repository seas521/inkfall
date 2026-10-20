extends Node2D

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")

const CELL_SIZE := Vector2(224.0, 224.0)
const ROOT := Vector2(112.0, 198.0)
const DISPLAY_SCALE := 0.44

const ATLASES := {
	&"idle": preload("res://assets/art/actors/crooked_tower/idle.png"),
	&"walk": preload("res://assets/art/actors/crooked_tower/walk.png"),
	&"jump": preload("res://assets/art/actors/crooked_tower/jump.png"),
	&"throw": preload("res://assets/art/actors/crooked_tower/throw.png"),
	&"shield": preload("res://assets/art/actors/crooked_tower/shield.png"),
	&"sword": preload("res://assets/art/actors/crooked_tower/sword.png"),
	&"push": preload("res://assets/art/actors/crooked_tower/push.png"),
	&"hit_fall": preload("res://assets/art/actors/crooked_tower/hit_fall.png"),
}

const CLIPS := {
	&"idle": [&"idle", 0, 7, 8.0, true],
	&"start": [&"walk", 0, 3, 18.0, false],
	&"walk": [&"walk", 0, 11, 19.0, true],
	&"stop": [&"walk", 8, 11, 18.0, false],
	&"turn": [&"idle", 4, 7, 18.0, false],
	&"takeoff": [&"jump", 0, 2, 20.0, false],
	&"rise": [&"jump", 2, 5, 16.0, false],
	&"apex": [&"jump", 5, 6, 10.0, true],
	&"fall": [&"jump", 6, 8, 14.0, true],
	&"land": [&"jump", 8, 11, 20.0, false],
	&"pickup": [&"throw", 0, 4, 18.0, false],
	&"carry": [&"throw", 4, 5, 8.0, true],
	&"put_down": [&"throw", 3, 0, 18.0, false],
	&"throw_charge": [&"throw", 5, 7, 10.0, true],
	&"throw_release": [&"throw", 7, 11, 22.0, false],
	&"shield_equip": [&"shield", 0, 2, 18.0, false],
	&"shield_ready": [&"shield", 0, 1, 7.0, true],
	&"shield_raise": [&"shield", 0, 2, 20.0, false],
	&"shield_guard": [&"shield", 2, 3, 8.0, true],
	&"shield_lower": [&"shield", 2, 0, 18.0, false],
	&"shield_parry": [&"shield", 4, 7, 24.0, false],
	&"shield_block": [&"shield", 3, 5, 24.0, false],
	&"blade_equip": [&"sword", 0, 1, 18.0, false],
	&"blade_ready": [&"sword", 0, 0, 1.0, true],
	&"blade_swing": [&"sword", 0, 7, 24.0, false],
	&"push_engage": [&"push", 0, 2, 18.0, false],
	&"push": [&"push", 2, 9, 17.0, true],
	&"push_release": [&"push", 9, 11, 18.0, false],
	&"hit": [&"hit_fall", 0, 4, 22.0, false],
	&"failure": [&"hit_fall", 4, 11, 16.0, false],
}

var pose
var sprite: Sprite2D
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
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.position = -ROOT
	add_child(sprite)
	head_glow = Sprite2D.new()
	head_glow.show_behind_parent = true
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.24, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.58, 0.20, 0.24),
		Color(0.86, 0.35, 0.08, 0.075),
		Color(0.43, 0.13, 0.02, 0.018),
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
	head_glow.position = Vector2(20.0, -116.0)
	head_glow.scale = Vector2(0.55, 0.48)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	head_glow.material = additive
	add_child(head_glow)
	hide()

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
		fade = 1.0 - smoothstep(0.78, 1.0, pose.failure_time / maxf(0.01, pose.failure_duration))
	modulate.a = fade
	head_glow.modulate = Color(1.0, 0.49, 0.13, fade * (0.08 + pose.light_exposure * 0.055))
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
	var clip: Array = CLIPS[current_clip]
	var atlas_name: StringName = clip[0]
	var start_frame := int(clip[1])
	var end_frame := int(clip[2])
	var fps := float(clip[3])
	var loop := bool(clip[4])
	var frame_count := absi(end_frame - start_frame) + 1
	var local_frame := 0
	if current_clip == &"walk":
		local_frame = int(travel_distance / 14.0) % frame_count
	elif current_clip == &"failure":
		var failure_progress: float = clampf(pose.failure_time / maxf(0.01, pose.failure_duration), 0.0, 1.0)
		local_frame = mini(frame_count - 1, int(round(failure_progress * float(frame_count - 1))))
	elif pose.action != ActorPoseState.ACTION_NONE:
		if loop:
			local_frame = int(clip_time * fps) % frame_count
		else:
			local_frame = mini(frame_count - 1, int(round(pose.action_progress * float(frame_count - 1))))
	elif loop:
		local_frame = int(clip_time * fps) % frame_count
	else:
		local_frame = mini(frame_count - 1, int(clip_time * fps))
	var direction := 1 if end_frame >= start_frame else -1
	var atlas_frame := start_frame + local_frame * direction
	sprite.texture = ATLASES[atlas_name]
	sprite.region_rect = Rect2(float(atlas_frame) * CELL_SIZE.x, 0.0, CELL_SIZE.x, CELL_SIZE.y)
