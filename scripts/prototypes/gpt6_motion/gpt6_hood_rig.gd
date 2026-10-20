extends Node3D

const MODEL = preload("res://assets/art/prototypes/gpt6_hood/gpt6_hood_boy.glb")
const LEG_UPPER := 0.34
const LEG_LOWER := 0.33

var skeleton: Skeleton3D
var bones: Dictionary = {}
var rests: Dictionary = {}
var solved: Dictionary = {}
var springs: Dictionary = {}
var feet: Array[Dictionary] = []
var phase := 0.0
var clock := 0.0
var motion_blend := 0.0
var run_blend := 0.0
var landing_offset := 0.0
var landing_velocity := 0.0
var air_blend := 0.0
var facing := 1.0
var last_grounded := true
var was_moving := false
var state_name := "IDLE"
var joints: Dictionary = {}
var max_contact_error := 0.0


func _ready() -> void:
	var model := MODEL.instantiate()
	add_child(model)
	skeleton = _find_skeleton(model)
	assert(skeleton != null, "GPT6 asset must contain a Skeleton3D")
	for index in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(index)
		bones[name] = index
		rests[name] = skeleton.get_bone_global_rest(index)
	_style_meshes(model)
	reset_motion()


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null


func _style_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var label := str(node.name)
		if label.begins_with("AmberEye"):
			mat.albedo_color = Color(1.0, 0.78, 0.39)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.55, 0.12)
			mat.emission_energy_multiplier = 0.35
		elif label.begins_with("Face"):
			mat.albedo_color = Color(0.004, 0.005, 0.005)
		elif label.begins_with("Hood") or label.begins_with("Coat") or label.begins_with("Sleeve"):
			mat.albedo_color = Color(0.052, 0.056, 0.055)
		else:
			mat.albedo_color = Color(0.011, 0.013, 0.013)
		node.material_override = mat
	for child in node.get_children():
		_style_meshes(child)


func reset_motion() -> void:
	phase = 0.0
	clock = 0.0
	motion_blend = 0.0
	run_blend = 0.0
	landing_offset = 0.0
	landing_velocity = 0.0
	air_blend = 0.0
	rotation.y = 0.0
	facing = 1.0
	last_grounded = true
	was_moving = false
	springs.clear()
	feet.clear()
	for index in 2:
		var x := global_position.x + (-0.07 if index == 0 else 0.07)
		feet.append({
			"contact": true, "anchor": x, "x": x, "height": 0.09,
			"from": x, "settle": 1.0, "settling": false, "lift_height": 0.09,
			"swing_start": 0.0, "pitch": 0.0,
		})


func _spring(key: String, target: float, frequency: float, damping: float, delta: float) -> float:
	if not springs.has(key):
		springs[key] = Vector2(target, 0.0)
	var value: Vector2 = springs[key]
	var steps := maxi(1, ceili(delta / 0.008))
	var step := delta / steps
	for index in steps:
		value.y += ((target - value.x) * frequency * frequency - 2.0 * damping * frequency * value.y) * step
		value.x += value.y * step
	springs[key] = value
	return value.x


func animate(delta: float, data: Dictionary) -> void:
	clock += delta
	var vx: float = data.velocity.x
	var vy: float = data.velocity.y
	var speed := absf(vx)
	var grounded: bool = data.grounded
	var moving := speed > 0.10
	var direction: float = data.direction
	var previous_facing := facing
	if absf(vx) > 0.18:
		facing = signf(vx)
	elif direction != 0.0:
		facing = signf(direction)
	var target_yaw := 0.0 if facing > 0.0 else PI
	rotation.y = rotate_toward(rotation.y, target_yaw, delta * 15.0)
	var turning := absf(angle_difference(rotation.y, target_yaw)) > 0.04
	motion_blend = move_toward(motion_blend, clampf(speed / 0.8, 0.0, 1.0), delta * 5.0)
	run_blend = lerpf(run_blend, clampf((speed - 1.0) / 1.7, 0.0, 1.0), 1.0 - exp(-delta * 8.0))
	air_blend = move_toward(air_blend, 0.0 if grounded else 1.0, delta * 10.0)
	if grounded and not last_grounded:
		landing_velocity = -clampf(float(data.impact) * 0.55, 0.6, 2.8)
		for foot in feet:
			foot.contact = true
			foot.anchor = foot.x
			foot.settling = false
	if not grounded and last_grounded:
		landing_velocity = -0.8
	var substeps := maxi(1, ceili(delta / 0.008))
	for index in substeps:
		var step := delta / substeps
		landing_velocity += (-landing_offset * 400.0 - landing_velocity * 29.0) * step
		landing_offset = clampf(landing_offset + landing_velocity * step, -0.16, 0.07)

	var stride := lerpf(0.96, 1.30, run_blend)
	if grounded and moving:
		phase += speed * delta / stride
	var duty := lerpf(0.54, 0.46, run_blend)
	if moving and grounded and (not was_moving or not last_grounded or previous_facing != facing):
		phase = duty * 0.5
	var front := stride * duty * 0.5
	for index in 2:
		_update_foot(index, delta, grounded, moving, duty, front, vx, vy)

	var braking := grounded and speed > 0.25 and (direction == 0.0 or signf(direction) != signf(vx))
	var accel: float = data.acceleration * facing
	var lean_target := run_blend * 0.06 * motion_blend
	lean_target += clampf(accel * 0.003, -0.08, 0.045)
	if braking:
		lean_target -= 0.06
	if not grounded:
		lean_target = lerpf(0.16, -0.045, clampf((3.0 - vy) / 7.0, 0.0, 1.0))
	var lean := _spring("lean", lean_target, 16.0, 0.86, delta)
	var bounce := -cos(phase * TAU * 2.0) * lerpf(0.002, 0.015, run_blend) * motion_blend * (1.0 - air_blend)
	var breathe := sin(clock * 2.2) * 0.004 * (1.0 - motion_blend)
	var pelvis_y := lerpf(0.756, lerpf(0.780, 0.745, run_blend), motion_blend) + bounce + breathe + landing_offset
	# Only a support foot controls hip height. Lowering the hips to reach a
	# trailing swing foot forces the stance knee into an unnatural crouch.
	for index in 2:
		var foot: Dictionary = feet[index]
		if not foot.contact:
			continue
		var depth := 0.0715 if index == 0 else -0.0715
		var world_depth := (global_transform.basis * Vector3(0, 0, depth)).z
		var local_foot := to_local(Vector3(foot.x, global_position.y + foot.height, global_position.z + world_depth))
		var horizontal := Vector2(local_foot.x, local_foot.z - depth).length()
		var reach := sqrt(maxf(0.01, pow(LEG_UPPER + LEG_LOWER - 0.0015, 2.0) - horizontal * horizontal))
		pelvis_y = minf(pelvis_y, float(foot.height) + reach)
	var hip := Vector3(0.0, pelvis_y, 0.0)
	var chest := hip + Vector3(sin(lean) * 0.25, cos(lean) * 0.25, 0.0)
	var neck := chest + Vector3(sin(lean * 0.8) * 0.33, cos(lean * 0.8) * 0.33, 0.0)
	solved.clear()
	joints.clear()
	_bone("Root", Vector3.ZERO, Vector3.UP)
	_bone("Pelvis", hip, chest - hip)
	_bone("Chest", chest, neck - chest)
	var head_angle := _spring("head", -lean * 0.28 + sin(clock * 0.9) * 0.012, 13.0, 0.85, delta)
	_bone("Head", neck, Vector3(sin(head_angle), cos(head_angle), 0.0))

	for index in 2:
		var side := "Near" if index == 0 else "Far"
		var depth := 0.0715 if index == 0 else -0.0715
		var leg_hip := hip + Vector3(0, 0, depth)
		var foot: Dictionary = feet[index]
		var world_depth := (global_transform.basis * Vector3(0, 0, depth)).z
		var ankle := to_local(Vector3(foot.x, global_position.y + foot.height, global_position.z + world_depth))
		if not foot.contact:
			var offset := ankle - leg_hip
			ankle = leg_hip + offset.limit_length(LEG_UPPER + LEG_LOWER - 0.0015)
		var knee := _two_bone(leg_hip, ankle, LEG_UPPER, LEG_LOWER, Vector3.RIGHT)
		_bone("Thigh" + side, leg_hip, knee - leg_hip)
		_bone("Shin" + side, knee, ankle - knee)
		var toe_angle: float = foot.pitch
		_bone("Foot" + side, ankle, Basis(Vector3.BACK, toe_angle) * Vector3(0.15, -0.045, 0))
		joints[side + "Ankle"] = to_global(ankle)
		joints[side + "Knee"] = to_global(knee)
		if foot.contact and grounded and not turning:
			max_contact_error = maxf(max_contact_error, absf(joints[side + "Ankle"].x - float(foot.anchor)))

		var arm_phase := phase * TAU + (0.0 if index == 0 else PI)
		# The arm opposes its same-side leg, rather than moving in lockstep.
		var swing := -cos(arm_phase) * lerpf(0.32, 0.70, run_blend) * motion_blend
		var idle_arm := 0.29 if index == 0 else -0.30
		var upper_angle := swing - lean * 0.6 + lerpf(idle_arm, -0.10, motion_blend)
		var bend := lerpf(0.06, 0.85, run_blend) + 0.15 * sin(arm_phase) * motion_blend
		if braking:
			upper_angle = lerpf(upper_angle, -0.50, 0.6)
			bend += 0.25
		var air_arm := lerpf(-0.65, 0.65, clampf((3.0 - vy) / 7.0, 0.0, 1.0))
		upper_angle = lerpf(upper_angle, air_arm + index * 0.23, air_blend)
		bend = lerpf(bend, 0.72, air_blend)
		upper_angle = _spring("arm" + side, upper_angle, 24.0, 0.90, delta)
		var shoulder := neck + Vector3(0.025 if index == 0 else -0.045, -0.07, depth / 0.55)
		var elbow := shoulder + Vector3(sin(upper_angle), -cos(upper_angle), 0) * 0.25
		var wrist := elbow + Vector3(sin(upper_angle + bend), -cos(upper_angle + bend), 0) * 0.33
		_bone("UpperArm" + side, shoulder, elbow - shoulder)
		_bone("Forearm" + side, elbow, wrist - elbow)
		_bone("Hand" + side, wrist, Vector3(sin(upper_angle + bend - 0.15), -cos(upper_angle + bend - 0.15), 0))

	var cloth_drive := clampf(accel * 0.012, -0.25, 0.25) + sin(phase * TAU) * motion_blend * 0.045
	cloth_drive += landing_velocity * 0.06
	var hood_a := _spring("hood_a", cloth_drive - lean * 0.25, 13.0, 0.53, delta)
	var hood_b := _spring("hood_b", hood_a * 1.35 + speed * 0.025, 10.0, 0.48, delta)
	_secondary("HoodA", "Head", hood_a)
	_secondary("HoodB", "HoodA", hood_b)
	_secondary("HemBack", "Pelvis", _spring("hem_back", -cloth_drive * 0.8 - run_blend * 0.13, 15.0, 0.58, delta))
	_secondary("HemFront", "Pelvis", _spring("hem_front", -cloth_drive * 0.5 + sin(phase * TAU + 0.8) * motion_blend * 0.06, 17.0, 0.65, delta))
	state_name = "IDLE"
	if not grounded:
		state_name = "RISE" if vy > 0.6 else ("FALL" if vy < -0.6 else "APEX")
	elif landing_offset < -0.025:
		state_name = "LAND"
	elif turning:
		state_name = "TURN"
	elif braking:
		state_name = "BRAKE"
	elif moving:
		state_name = "RUN" if run_blend > 0.35 else "WALK"
	last_grounded = grounded
	was_moving = moving


func _update_foot(index: int, delta: float, grounded: bool, moving: bool, duty: float, front: float, vx: float, vy: float) -> void:
	var foot: Dictionary = feet[index]
	if not grounded:
		var descending := clampf((2.5 - vy) / 6.0, 0.0, 1.0)
		var x := lerpf(0.26 if index == 0 else -0.25, 0.17 if index == 0 else -0.14, descending)
		var y := lerpf(0.21 if index == 0 else 0.34, 0.09, descending)
		foot.x = lerpf(foot.x, global_position.x + x * facing, 1.0 - exp(-delta * 20.0))
		foot.height = lerpf(foot.height, y, 1.0 - exp(-delta * 18.0))
		foot.contact = false
		foot.settling = false
		foot.pitch = lerpf(foot.pitch, 0.06, 1.0 - exp(-delta * 12.0))
		return
	if moving:
		var p := fposmod(phase + (0.0 if index == 0 else 0.5), 1.0)
		var stance := p < duty
		if stance:
			if not foot.contact:
				foot.anchor = global_position.x + facing * front
			foot.x = foot.anchor
			foot.height = 0.09
			foot.pitch = lerpf(foot.pitch, 0.0, 1.0 - exp(-delta * 35.0))
		else:
			if foot.contact:
				foot.from = foot.x
				foot.swing_start = p
				foot.lift_height = foot.height
			var t := clampf((p - float(foot.swing_start)) / maxf(0.001, 1.0 - float(foot.swing_start)), 0.0, 1.0)
			var landing_x := global_position.x + facing * front + vx * (1.0 - t) * 0.06
			foot.x = lerpf(foot.from, landing_x, smoothstep(0.0, 1.0, t))
			foot.height = lerpf(foot.lift_height, 0.09, smoothstep(0.0, 1.0, t)) + sin(PI * t) * lerpf(0.065, 0.25, run_blend) * motion_blend
			var swing_pitch := lerpf(-0.18, 0.16, smoothstep(0.0, 0.8, t))
			foot.pitch = lerpf(foot.pitch, swing_pitch, 1.0 - exp(-delta * 25.0))
		foot.contact = stance
		foot.settling = false
		return
	var rest_x := global_position.x + facing * (-0.07 if index == 0 else 0.07)
	if not foot.settling and (not foot.contact or absf(foot.x - rest_x) > 0.035):
		foot.settling = true
		foot.from = foot.x
		foot.settle = 0.0
		foot.lift_height = foot.height
	if foot.settling:
		foot.settle = minf(1.0, foot.settle + delta / 0.24)
		foot.x = lerpf(foot.from, rest_x, smoothstep(0.0, 1.0, foot.settle))
		foot.height = lerpf(foot.lift_height, 0.09, smoothstep(0.0, 1.0, foot.settle)) + sin(PI * foot.settle) * 0.055
		foot.contact = foot.settle >= 1.0
		foot.pitch = lerpf(foot.pitch, 0.0, 1.0 - exp(-delta * 20.0))
		if foot.contact:
			foot.anchor = foot.x
			foot.settling = false
	else:
		foot.x = foot.anchor
		foot.height = 0.09
		foot.contact = true
		foot.pitch = 0.0


func _two_bone(start: Vector3, end: Vector3, upper: float, lower: float, bend: Vector3) -> Vector3:
	var direction := (end - start).normalized()
	var distance := clampf(start.distance_to(end), 0.02, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var across := sqrt(maxf(0.0, upper * upper - along * along))
	var perpendicular := (bend - direction * bend.dot(direction)).normalized()
	return start + direction * along + perpendicular * across


func _bone(name: String, origin: Vector3, direction: Vector3) -> void:
	var index: int = bones[name]
	var rest: Transform3D = rests[name]
	var swing := Quaternion(rest.basis.y.normalized(), direction.normalized())
	var wanted := Transform3D(Basis(swing) * rest.basis, origin)
	var parent := skeleton.get_bone_parent(index)
	var parent_pose := Transform3D.IDENTITY
	if parent >= 0:
		parent_pose = solved[skeleton.get_bone_name(parent)]
	var local := parent_pose.affine_inverse() * wanted
	skeleton.set_bone_pose_position(index, local.origin)
	skeleton.set_bone_pose_rotation(index, local.basis.get_rotation_quaternion())
	skeleton.set_bone_pose_scale(index, Vector3.ONE)
	solved[name] = wanted


func _secondary(name: String, parent_name: String, angle: float) -> void:
	var parent_pose: Transform3D = solved[parent_name]
	var parent_rest: Transform3D = rests[parent_name]
	var rest: Transform3D = rests[name]
	var carried := parent_pose * parent_rest.affine_inverse() * rest
	_bone(name, carried.origin, Basis(Vector3.BACK, angle) * carried.basis.y)
