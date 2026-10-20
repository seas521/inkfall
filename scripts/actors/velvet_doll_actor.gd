extends Node2D

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")

var pose
var clock := 0.0
var step_phase := 0.0
var move_blend := 0.0
var light_blend := 0.0
var cloak_lag := 0.0
var scarf_lag := 0.0
var landing_impulse := 0.0
var takeoff_impulse := 0.0
var turn_impulse := 0.0
var previous_ground := false
var previous_facing := 1.0
var head_glow: Sprite2D

func _ready() -> void:
	head_glow = Sprite2D.new()
	head_glow.show_behind_parent = true
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.48, 0.12, 0.42),
		Color(0.78, 0.27, 0.055, 0.16),
		Color(0.42, 0.10, 0.02, 0.035),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var glow_texture := GradientTexture2D.new()
	glow_texture.width = 128
	glow_texture.height = 128
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	head_glow.texture = glow_texture
	head_glow.position = Vector2(0.0, -47.0)
	head_glow.scale = Vector2(0.40, 0.36)
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	head_glow.material = glow_material
	add_child(head_glow)
	hide()

func sync_pose(delta: float, next_pose) -> void:
	pose = next_pose
	show()
	clock += delta
	position = pose.feet
	if pose.facing != previous_facing:
		turn_impulse = 1.0
	if pose.grounded and not previous_ground:
		landing_impulse = clampf(absf(pose.velocity.y) / 620.0 + 0.42, 0.42, 1.0)
	elif not pose.grounded and previous_ground:
		takeoff_impulse = 1.0
	var speed_ratio := clampf(absf(pose.velocity.x) / 285.0, 0.0, 1.0)
	if pose.grounded and speed_ratio > 0.02:
		step_phase += absf(pose.velocity.x) * delta / 76.0 * TAU
	move_blend = lerpf(move_blend, speed_ratio if pose.grounded else speed_ratio * 0.35, 1.0 - exp(-10.0 * delta))
	light_blend = lerpf(light_blend, pose.light_exposure, 1.0 - exp(-4.8 * delta))
	var forward_speed: float = pose.velocity.x * pose.facing
	cloak_lag = lerpf(cloak_lag, clampf(-forward_speed / 285.0 * 5.5, -6.0, 3.0), 1.0 - exp(-6.0 * delta))
	scarf_lag = lerpf(scarf_lag, clampf(-forward_speed / 285.0 * 9.0, -11.0, 4.0), 1.0 - exp(-4.2 * delta))
	landing_impulse = move_toward(landing_impulse, 0.0, delta / 0.16)
	takeoff_impulse = move_toward(takeoff_impulse, 0.0, delta / 0.13)
	turn_impulse = move_toward(turn_impulse, 0.0, delta / 0.16)
	scale = Vector2(pose.facing * 1.08, 1.08)
	var fade := 1.0
	if pose.failure_time > 0.0:
		fade = 1.0 - smoothstep(0.58, 1.0, pose.failure_time / maxf(0.01, pose.failure_duration))
	modulate.a = fade
	head_glow.modulate = Color(1.0, 0.55, 0.18, fade * (0.16 + light_blend * 0.11) * (0.94 + sin(clock * 1.6) * 0.06))
	previous_ground = pose.grounded
	previous_facing = pose.facing
	queue_redraw()

func _draw() -> void:
	if pose == null:
		return
	var action: StringName = pose.action
	var progress: float = pose.action_progress
	var gait := sin(step_phase)
	var lift_left := maxf(0.0, sin(step_phase)) * move_blend
	var lift_right := maxf(0.0, -sin(step_phase)) * move_blend
	var bob := -absf(cos(step_phase)) * 1.25 * move_blend
	var breathe := sin(clock * 2.15) * 0.45
	var body_lean := clampf(pose.velocity.x * pose.facing / 285.0, -1.0, 1.0) * 0.075 * move_blend
	var body_shift := Vector2(0.0, bob + breathe)
	var squash_x := 1.0 + landing_impulse * 0.12 - takeoff_impulse * 0.05
	var squash_y := 1.0 - landing_impulse * 0.15 + takeoff_impulse * 0.10

	var pushing := action == ActorPoseState.ACTION_PUSH or action == ActorPoseState.ACTION_PUSH_ENGAGE
	var push_releasing := action == ActorPoseState.ACTION_PUSH_RELEASE
	var picking := action == ActorPoseState.ACTION_PICKUP or action == ActorPoseState.ACTION_PUT_DOWN
	var hit_reaction: bool = action == ActorPoseState.ACTION_HIT or pose.impact > 0.55
	if not pose.grounded:
		body_shift.y += 1.0 if pose.velocity.y < 0.0 else 2.0
		body_lean += clampf(pose.velocity.x * pose.facing / 500.0, -0.20, 0.20)
	if pushing:
		var engage := smoothstep(0.0, 0.45, progress) if action == ActorPoseState.ACTION_PUSH_ENGAGE else 1.0
		body_shift.x += 4.8 * engage
		body_shift.y += 1.8 * engage
		body_lean += 0.22 * engage
		squash_y -= 0.055 * engage
	elif push_releasing:
		body_shift.x += lerpf(4.8, -1.4, progress)
		body_lean += lerpf(0.22, -0.06, progress)
	if picking:
		var bend := sin(progress * PI)
		body_shift += Vector2(2.5, 4.0) * bend
		body_lean += 0.30 * bend
		squash_y -= 0.06 * bend
	if action == ActorPoseState.ACTION_THROW_CHARGE:
		body_shift.x -= 2.0 + pose.effort * 1.8
		body_lean -= 0.10 + pose.effort * 0.08
	elif action == ActorPoseState.ACTION_THROW_RELEASE:
		var release_envelope := sin(progress * PI)
		body_shift.x += release_envelope * 3.8
		body_lean += release_envelope * 0.20
	if action == ActorPoseState.ACTION_SHIELD_GUARD or action == ActorPoseState.ACTION_SHIELD_RAISE:
		body_shift.x -= 1.3
		body_lean -= 0.08
	elif action == ActorPoseState.ACTION_SHIELD_PARRY:
		body_shift.x += sin(progress * PI) * 3.2
		body_lean += sin(progress * PI) * 0.17
	elif action == ActorPoseState.ACTION_SHIELD_BLOCK:
		body_shift.x -= sin(progress * PI) * (3.0 + pose.impact * 3.0)
		body_lean -= sin(progress * PI) * 0.19
	if action == ActorPoseState.ACTION_BLADE_SWING:
		body_shift.x += sin(progress * PI) * 2.8
		body_lean += sin(progress * PI) * 0.15
	if hit_reaction:
		body_shift.x -= 4.5 * maxf(pose.impact, sin(progress * PI))
		body_lean -= 0.24
		turn_impulse = maxf(turn_impulse, pose.impact * 0.4)
	if pose.failure_time > 0.0:
		var failure_progress := clampf(pose.failure_time / maxf(0.01, pose.failure_duration), 0.0, 1.0)
		body_shift.y += smoothstep(0.08, 0.82, failure_progress) * 16.0
		body_shift.x -= sin(failure_progress * PI) * 4.0
		body_lean -= smoothstep(0.0, 0.72, failure_progress) * 0.82
		squash_y *= lerpf(1.0, 0.62, smoothstep(0.38, 0.92, failure_progress))

	var body_rotation := body_lean + sin(clock * 12.0) * turn_impulse * 0.04
	var body_origin := body_shift + Vector2(0.0, -1.0)
	var exposure := clampf(0.12 + light_blend * 0.88, 0.0, 1.0)
	var black := Color(0.006, 0.008, 0.009)
	var velvet := Color(0.018, 0.022, 0.023).lerp(Color(0.115, 0.126, 0.121), exposure)
	var velvet_lit := Color(0.035, 0.041, 0.041).lerp(Color(0.32, 0.34, 0.325), exposure)
	var face := Color(0.004, 0.005, 0.006)
	var boot := Color(0.008, 0.010, 0.011).lerp(Color(0.045, 0.049, 0.048), exposure)
	var amber := Color(0.84, 0.50, 0.20).lerp(Color(1.0, 0.73, 0.34), exposure)

	_draw_scarf_back(body_origin, body_rotation, velvet, exposure)
	_draw_legs(body_origin, gait, lift_left, lift_right, boot, pushing)

	var shoulder_front := body_origin + Vector2(8.5, -29.0).rotated(body_rotation)
	var shoulder_back := body_origin + Vector2(-7.5, -29.0).rotated(body_rotation)
	var hand_front := body_origin + Vector2(12.0 + gait * 2.4 * move_blend, -17.0).rotated(body_rotation)
	var hand_back := body_origin + Vector2(-10.0 - gait * 2.0 * move_blend, -18.0).rotated(body_rotation)
	var arm_targets := _action_hands(body_origin, shoulder_front, shoulder_back, hand_front, hand_back, progress)
	hand_front = arm_targets[0]
	hand_back = arm_targets[1]

	_draw_arm(shoulder_back, hand_back, 4.3, black, velvet)
	_draw_torso(body_origin, body_rotation, squash_x, squash_y, velvet, velvet_lit, exposure)
	_draw_shoulder_armor(body_origin, body_rotation, black, velvet_lit, exposure)
	_draw_arm(shoulder_front, hand_front, 4.7, black, velvet_lit)
	_draw_equipment(hand_front, hand_back, amber, velvet_lit, progress)
	_draw_helmet(body_origin, body_rotation, squash_x, squash_y, black, velvet, velvet_lit, face, amber, exposure)
	_draw_charm(body_origin, body_rotation, amber, exposure)

func _action_hands(
	body_origin: Vector2,
	shoulder_front: Vector2,
	shoulder_back: Vector2,
	default_front: Vector2,
	default_back: Vector2,
	progress: float
) -> Array[Vector2]:
	var front := default_front
	var back := default_back
	var action: StringName = pose.action
	var equipment: StringName = pose.equipment
	if action == ActorPoseState.ACTION_PICKUP or action == ActorPoseState.ACTION_PUT_DOWN:
		var bend := sin(progress * PI)
		front = shoulder_front.lerp(body_origin + Vector2(13.0, -3.0), bend)
		back = shoulder_back.lerp(body_origin + Vector2(6.0, -5.0), bend)
	elif action == ActorPoseState.ACTION_THROW_CHARGE:
		var direction := Vector2(cos(pose.aim_angle), sin(pose.aim_angle))
		front = shoulder_front + direction * 14.0
		back = front + Vector2(-5.0, 5.0)
	elif action == ActorPoseState.ACTION_THROW_RELEASE:
		var release_angle := lerpf(pose.aim_angle - 0.55, 0.58, smoothstep(0.05, 0.72, progress))
		var release_direction := Vector2(cos(release_angle), sin(release_angle))
		front = shoulder_front + release_direction * 18.0
		back = shoulder_back + Vector2(5.0, 12.0)
	elif equipment == ActorPoseState.EQUIPMENT_THROWABLE:
		front = body_origin + Vector2(14.0, -25.0)
		back = body_origin + Vector2(7.0, -24.0)
	elif action == ActorPoseState.ACTION_SHIELD_GUARD or action == ActorPoseState.ACTION_SHIELD_RAISE or action == ActorPoseState.ACTION_SHIELD_LOWER or action == ActorPoseState.ACTION_SHIELD_BLOCK:
		front = body_origin + Vector2(15.5, -27.0)
		back = body_origin + Vector2(11.0, -21.0)
	elif action == ActorPoseState.ACTION_SHIELD_PARRY:
		var angle := lerpf(-0.92, 0.55, smoothstep(0.04, 0.74, progress))
		front = shoulder_front + Vector2(cos(angle), sin(angle)) * 15.0
		back = body_origin + Vector2(-5.0, -18.0)
	elif equipment == ActorPoseState.EQUIPMENT_SHIELD:
		front = body_origin + Vector2(14.0, -22.0)
		back = body_origin + Vector2(-8.0, -18.0)
	elif action == ActorPoseState.ACTION_BLADE_SWING:
		var blade_angle := _blade_angle(progress)
		front = shoulder_front + Vector2(cos(blade_angle), sin(blade_angle)) * 13.0
		back = body_origin + Vector2(-4.0, -19.0)
	elif equipment == ActorPoseState.EQUIPMENT_BLADE:
		front = body_origin + Vector2(13.0, -21.0)
		back = body_origin + Vector2(-8.0, -18.0)
	if action == ActorPoseState.ACTION_PUSH_ENGAGE or action == ActorPoseState.ACTION_PUSH:
		var reach := smoothstep(0.0, 0.45, progress) if action == ActorPoseState.ACTION_PUSH_ENGAGE else 1.0
		front = default_front.lerp(body_origin + Vector2(22.0, -27.0), reach)
		back = default_back.lerp(body_origin + Vector2(21.0, -19.0), reach)
	elif action == ActorPoseState.ACTION_PUSH_RELEASE:
		front = body_origin + Vector2(lerpf(22.0, 12.0, progress), lerpf(-27.0, -17.0, progress))
		back = body_origin + Vector2(lerpf(21.0, -8.0, progress), lerpf(-19.0, -18.0, progress))
	return [front, back]

func _draw_legs(body_origin: Vector2, gait: float, lift_left: float, lift_right: float, boot: Color, pushing: bool) -> void:
	var hip_left := body_origin + Vector2(-4.8, -15.0)
	var hip_right := body_origin + Vector2(4.8, -15.0)
	var left_foot := Vector2(-5.5 + gait * 5.8 * move_blend, -lift_left * 3.4)
	var right_foot := Vector2(5.5 - gait * 5.8 * move_blend, -lift_right * 3.4)
	if not pose.grounded:
		var tuck := clampf(absf(pose.velocity.y) / 520.0, 0.2, 1.0)
		left_foot = Vector2(-5.0, -5.0 - tuck * 2.0)
		right_foot = Vector2(6.0, -3.5 - tuck)
	elif pushing:
		left_foot = Vector2(-8.0 + gait * 2.4, 0.0)
		right_foot = Vector2(7.0 - gait * 2.0, 0.0)
	_draw_capsule(hip_left, left_foot + Vector2(0.0, -1.5), 4.6, boot)
	_draw_capsule(hip_right, right_foot + Vector2(0.0, -1.5), 4.8, boot)
	_draw_boot(left_foot, boot)
	_draw_boot(right_foot, boot)

func _draw_boot(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(-4.2, -3.0),
		center + Vector2(3.2, -2.8),
		center + Vector2(5.5, 0.0),
		center + Vector2(-4.8, 0.0),
	])
	draw_colored_polygon(points, color)

func _draw_scarf_back(body_origin: Vector2, rotation_value: float, color: Color, exposure: float) -> void:
	var cape_anchor := body_origin + Vector2(-7.0, -32.0).rotated(rotation_value)
	var cape_wave := sin(clock * 2.6 + step_phase * 0.38) * (0.7 + move_blend * 1.4)
	var cape := PackedVector2Array([
		cape_anchor,
		cape_anchor + Vector2(-9.0 + cloak_lag * 0.25, 7.0),
		cape_anchor + Vector2(-13.0 + cloak_lag * 0.65, 24.0 + cape_wave),
		cape_anchor + Vector2(-4.0 + cloak_lag * 0.82, 19.0 - cape_wave * 0.35),
		cape_anchor + Vector2(1.0, 8.0),
	])
	draw_colored_polygon(cape, color.lerp(Color(0.12, 0.13, 0.125), exposure * 0.16))
	var anchor := body_origin + Vector2(-5.0, -38.0).rotated(rotation_value)
	var flutter := sin(clock * 3.1 + step_phase * 0.35) * (1.0 + move_blend * 1.7)
	var tail := PackedVector2Array([
		anchor,
		anchor + Vector2(-8.0 + scarf_lag, 4.0 + flutter),
		anchor + Vector2(-18.0 + scarf_lag * 1.4, 10.0 - flutter * 0.5),
		anchor + Vector2(-13.0 + scarf_lag * 1.2, 14.0 - flutter * 0.2),
		anchor + Vector2(-5.0, 8.0),
	])
	draw_colored_polygon(tail, color.lerp(Color(0.13, 0.14, 0.135), exposure * 0.22))

func _draw_torso(
	body_origin: Vector2,
	rotation_value: float,
	squash_x: float,
	squash_y: float,
	base: Color,
	lit: Color,
	exposure: float
) -> void:
	draw_set_transform(body_origin, rotation_value, Vector2(squash_x, squash_y))
	var torso := PackedVector2Array([
		Vector2(-9.5, -34.0),
		Vector2(10.0, -34.0),
		Vector2(11.5, -20.0),
		Vector2(8.0, -12.0),
		Vector2(3.0, -9.0),
		Vector2(-2.0, -12.0),
		Vector2(-8.5, -9.5),
		Vector2(-11.0, -20.0),
	])
	_draw_feathered_shape(torso, base, 0.85)
	var light_patch := PackedVector2Array([
		Vector2(0.5, -32.0),
		Vector2(8.0, -31.0),
		Vector2(8.5, -21.0),
		Vector2(4.5, -14.0),
		Vector2(-0.5, -17.0),
	])
	draw_colored_polygon(light_patch, Color(lit, 0.24 + exposure * 0.42))
	var belt := PackedVector2Array([
		Vector2(-9.0, -17.5),
		Vector2(8.5, -17.5),
		Vector2(8.2, -14.2),
		Vector2(-8.5, -14.2),
	])
	draw_colored_polygon(belt, Color(0.055, 0.036, 0.024, 0.92))
	for grain_index in range(5):
		var gx := -5.0 + float((grain_index * 7) % 11)
		var gy := -29.0 + float((grain_index * 9) % 12)
		draw_circle(Vector2(gx, gy), 0.42, Color(lit, 0.08 + exposure * 0.08), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_shoulder_armor(
	body_origin: Vector2,
	rotation_value: float,
	black: Color,
	lit: Color,
	exposure: float
) -> void:
	var front := body_origin + Vector2(9.5, -31.0).rotated(rotation_value)
	var back := body_origin + Vector2(-8.5, -31.0).rotated(rotation_value)
	draw_circle(back, 5.4, black, true, -1.0, true)
	draw_circle(back + Vector2(0.5, -0.5), 4.3, Color(lit, 0.25 + exposure * 0.18), true, -1.0, true)
	draw_circle(front, 6.2, black, true, -1.0, true)
	draw_circle(front + Vector2(0.7, -0.7), 5.0, Color(lit, 0.38 + exposure * 0.24), true, -1.0, true)

func _draw_helmet(
	body_origin: Vector2,
	rotation_value: float,
	squash_x: float,
	squash_y: float,
	black: Color,
	base: Color,
	lit: Color,
	face: Color,
	amber: Color,
	exposure: float
) -> void:
	var idle_cycle := fposmod(clock, 6.2) / 6.2
	var cute_tilt := sin(smoothstep(0.70, 0.78, idle_cycle) * PI) * (1.0 - move_blend) * (1.0 if pose.grounded else 0.0)
	var helmet_rotation := rotation_value * 0.42 - cute_tilt * 0.07 + turn_impulse * 0.05
	draw_set_transform(body_origin + Vector2(0.0, -47.0), helmet_rotation, Vector2(squash_x * 1.02, squash_y * 0.94))
	var pumpkin_dark := Color(0.030, 0.019, 0.013).lerp(Color(0.092, 0.046, 0.020), exposure)
	var pumpkin := Color(0.060, 0.031, 0.015).lerp(Color(0.19, 0.092, 0.030), exposure)
	var pumpkin_lit := Color(0.09, 0.043, 0.018).lerp(Color(0.28, 0.135, 0.045), exposure)
	draw_circle(Vector2.ZERO, 12.4, black, true, -1.0, true)
	draw_circle(Vector2(-0.4, -0.2), 11.6, pumpkin_dark, true, -1.0, true)
	draw_circle(Vector2(0.6, -0.5), 10.7, pumpkin, true, -1.0, true)
	var light_plane := PackedVector2Array([
		Vector2(0.5, -10.0),
		Vector2(7.5, -7.5),
		Vector2(9.8, -1.0),
		Vector2(6.6, 7.0),
		Vector2(1.5, 8.7),
		Vector2(-0.5, 2.0),
	])
	draw_colored_polygon(light_plane, Color(pumpkin_lit, 0.42 + exposure * 0.28))
	for groove_x in [-5.7, -2.8, 2.8, 5.7]:
		draw_arc(Vector2(groove_x * 0.15, 0.0), 10.3, -1.30 + groove_x * 0.012, 1.30 + groove_x * 0.012, 18, Color(pumpkin_dark, 0.46), 0.85, true)
	var visor := PackedVector2Array([
		Vector2(-8.7, -1.2),
		Vector2(-1.1, 0.2),
		Vector2(0.4, 1.2),
		Vector2(8.6, -1.4),
		Vector2(7.0, 4.1),
		Vector2(1.2, 3.4),
		Vector2(-0.5, 2.7),
		Vector2(-7.2, 4.0),
	])
	draw_colored_polygon(visor, face)
	draw_circle(Vector2(-4.2, 1.2), 1.05, Color(amber, 0.90), true, -1.0, true)
	draw_circle(Vector2(4.2, 1.1), 1.05, Color(amber, 0.90), true, -1.0, true)
	draw_line(Vector2(-1.8, -11.2), Vector2(-0.8, -15.0), Color(0.13, 0.074, 0.031), 2.6, true)
	draw_line(Vector2(-0.8, -15.0), Vector2(1.2, -16.5), Color(0.10, 0.058, 0.026), 2.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_arm(shoulder: Vector2, hand: Vector2, width: float, under_color: Color, fabric_color: Color) -> void:
	var elbow := shoulder.lerp(hand, 0.52) + Vector2(0.0, 2.5)
	_draw_capsule(shoulder, elbow, width + 1.8, under_color)
	_draw_capsule(elbow, hand, width, fabric_color)
	draw_circle(hand, width * 0.54, under_color, true, -1.0, true)

func _draw_charm(body_origin: Vector2, rotation_value: float, amber: Color, exposure: float) -> void:
	var center := body_origin + Vector2(1.0, -15.8).rotated(rotation_value)
	draw_circle(center, 3.6, Color(amber, 0.025 + exposure * 0.025), true, -1.0, true)
	draw_circle(center, 2.1, Color(0.11, 0.064, 0.025, 0.96), true, -1.0, true)
	draw_circle(center, 0.85, Color(amber, 0.68), true, -1.0, true)

func _draw_equipment(front_hand: Vector2, back_hand: Vector2, amber: Color, lit: Color, progress: float) -> void:
	var action: StringName = pose.action
	if (
		pose.equipment == ActorPoseState.EQUIPMENT_THROWABLE
		or (action == ActorPoseState.ACTION_THROW_RELEASE and progress < 0.34)
		or (action == ActorPoseState.ACTION_PUT_DOWN and progress < 0.66)
	):
		var object_center := (front_hand + back_hand) * 0.5 + Vector2(2.0, -2.0)
		_draw_throwable(object_center, amber, lit)
	if pose.equipment == ActorPoseState.EQUIPMENT_SHIELD:
		var shield_center := front_hand + Vector2(6.5, 0.0)
		var angle := 0.14
		if action == ActorPoseState.ACTION_SHIELD_RAISE:
			angle = lerpf(0.34, 0.0, progress)
		elif action == ActorPoseState.ACTION_SHIELD_GUARD or action == ActorPoseState.ACTION_SHIELD_BLOCK:
			angle = 0.0
		elif action == ActorPoseState.ACTION_SHIELD_LOWER:
			angle = lerpf(0.0, 0.34, progress)
		elif action == ActorPoseState.ACTION_SHIELD_PARRY:
			angle = lerpf(-0.92, 0.55, smoothstep(0.04, 0.74, progress))
		_draw_shield(shield_center, angle, amber, lit, pose.impact)
	if pose.equipment == ActorPoseState.EQUIPMENT_BLADE:
		var angle := -0.18
		if action == ActorPoseState.ACTION_BLADE_EQUIP:
			angle = lerpf(1.15, -0.18, smoothstep(0.0, 1.0, progress))
		elif action == ActorPoseState.ACTION_BLADE_SWING:
			angle = _blade_angle(progress)
		_draw_blade(front_hand, angle, amber, lit)

func _blade_angle(progress: float) -> float:
	if progress < 0.24:
		return lerpf(-0.22, -1.78, smoothstep(0.0, 0.24, progress))
	if progress < 0.68:
		return lerpf(-1.78, 0.58, smoothstep(0.24, 0.68, progress))
	return lerpf(0.58, -0.18, smoothstep(0.68, 1.0, progress))

func _draw_throwable(center: Vector2, amber: Color, lit: Color) -> void:
	draw_circle(center, 7.0, Color(0.004, 0.006, 0.007), true, -1.0, true)
	draw_circle(center + Vector2(1.5, -1.2), 5.2, Color(lit, 0.55), true, -1.0, true)
	draw_arc(center, 4.0, -1.2, 1.4, 12, Color(amber, 0.58), 1.2, true)

func _draw_shield(center: Vector2, rotation_value: float, amber: Color, lit: Color, impact: float) -> void:
	draw_set_transform(center, rotation_value, Vector2.ONE)
	var shield := PackedVector2Array([
		Vector2(-11.0, -18.0),
		Vector2(9.0, -18.0),
		Vector2(14.0, -8.0),
		Vector2(12.0, 8.0),
		Vector2(2.0, 20.0),
		Vector2(-9.0, 13.0),
		Vector2(-14.0, 0.0),
	])
	_draw_feathered_shape(shield, Color(0.006, 0.008, 0.009), 1.0)
	var plane := PackedVector2Array([
		Vector2(-2.0, -15.0),
		Vector2(7.0, -13.0),
		Vector2(10.0, -5.0),
		Vector2(7.0, 9.0),
		Vector2(1.0, 15.0),
		Vector2(-2.0, 4.0),
	])
	draw_colored_polygon(plane, Color(lit, 0.48 + impact * 0.12))
	draw_circle(Vector2(0.5, -1.0), 3.1, Color(amber, 0.82), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_blade(hand: Vector2, angle: float, amber: Color, lit: Color) -> void:
	draw_set_transform(hand, angle, Vector2.ONE)
	draw_line(Vector2(-3.0, 0.0), Vector2(5.0, 0.0), Color(amber, 0.92), 4.0, true)
	draw_circle(Vector2.ZERO, 2.5, Color(0.008, 0.01, 0.011), true, -1.0, true)
	var blade := PackedVector2Array([
		Vector2(3.0, -2.4),
		Vector2(31.0, -1.6),
		Vector2(37.0, 0.0),
		Vector2(30.0, 2.0),
		Vector2(3.0, 2.5),
	])
	draw_colored_polygon(blade, Color(0.012, 0.015, 0.016))
	var blade_plane := PackedVector2Array([
		Vector2(6.0, -1.2),
		Vector2(29.0, -0.9),
		Vector2(34.0, 0.0),
		Vector2(8.0, 0.4),
	])
	draw_colored_polygon(blade_plane, Color(lit, 0.68))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_capsule(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, color, width, true)
	draw_circle(from, width * 0.5, color, true, -1.0, true)
	draw_circle(to, width * 0.5, color, true, -1.0, true)

func _draw_feathered_shape(points: PackedVector2Array, core: Color, radius: float) -> void:
	for sample_index in range(8):
		var angle := float(sample_index) * TAU / 8.0
		var offset := Vector2(cos(angle), sin(angle)) * radius
		var shifted := PackedVector2Array()
		for point in points:
			shifted.append(point + offset)
		draw_colored_polygon(shifted, Color(0.0, 0.0, 0.0, 0.035))
	draw_colored_polygon(points, core)
