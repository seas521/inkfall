extends SceneTree

const Manifest = preload("res://scripts/actors/crooked_tower_vector_manifest.gd")

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	for clip_name in Manifest.CLIPS.keys():
		var clip: StringName = clip_name
		var metadata: Dictionary = Manifest.CLIPS[clip]
		var frame_count := int(metadata["frames"])
		var keys := _clip_keys(clip)
		if keys.is_empty():
			push_error("Missing vector key poses for %s" % clip)
			quit(1)
			return
		var frames := _bake(keys, frame_count, bool(metadata["loop"]))
		var directory := "%s/%s" % [Manifest.FRAME_ROOT, String(clip)]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		for frame_index in range(frames.size()):
			var path := Manifest.frame_path(clip, frame_index)
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				push_error("Unable to write vector frame: %s" % path)
				quit(1)
				return
			file.store_string(_svg_for_pose(frames[frame_index], _equipment_for_clip(clip), clip, frame_index))
		print("Built independent SVG clip ", clip, " (", frame_count, " frames)")
	quit(0)

func _clip_keys(clip: StringName) -> Array:
	match clip:
		&"idle":
			return [
				_p(),
				_p(0, 0.8, 0.005, 0, 0.2, -0.008, 5, 0, -5, 0, 13, 1, -12, 2),
				_with_eye(_p(0, 0.2, -0.01, 0, -0.5, -0.025, 5, 0, -5, 0, 12, 0, -11, 3), 0.82),
				_p(0, 0, 0.0, 0, 0, 0.0, 5, 0, -5, 0, 13, 1, -12, 2),
			]
		&"start":
			return [
				_p(),
				_p(1, 2, 0.06, 1, 0, 0.02, 6, 0, -5, 0, 8, -1, -8, 4),
				_p(3, -1, 0.14, 2, -1, 0.045, 12, 0, -7, -3, 3, -6, -3, 7),
			]
		&"walk":
			return _walk_keys()
		&"carry_walk":
			return _equipped_walk_keys(&"throwable")
		&"shield_walk":
			return _equipped_walk_keys(&"shield")
		&"blade_walk":
			return _equipped_walk_keys(&"blade")
		&"stop":
			return [
				_p(3, -1, 0.14, 2, -1, 0.04, 11, 0, -7, -3, 2, -5, -2, 7),
				_p(2, 3, -0.08, 1, 1, -0.03, 7, 0, -7, 0, 8, 4, -8, 1),
				_p(),
			]
		&"turn":
			return [
				_p(1, 0, 0.08, 2, 0, 0.06),
				_p(0, 3, 0.0, 0, 1, 0.0, 3, 0, -3, 0, 8, 3, -8, 3, 0.88, 1.0),
				_p(),
			]
		&"takeoff":
			return [
				_p(),
				_p(1, 5, 0.08, 1, 3, 0.03, 7, 0, -7, 0, 8, 6, -8, 6, 1.08, 0.86),
				_p(3, -4, 0.16, 3, -5, 0.07, 5, -7, -4, -5, 15, -9, -8, 6, 0.96, 1.08),
			]
		&"rise":
			return [
				_p(3, -12, 0.15, 3, -12, 0.06, 4, -8, -5, -6, 15, -9, -8, 6),
				_p(2, -20, 0.10, 2, -20, 0.04, 1, -10, -7, -6, 13, -11, -7, 7),
			]
		&"apex":
			return [
				_p(2, -24, 0.035, 2, -25, 0.015, 1, -7, -6, -8, 11, -9, -9, 3),
				_p(1, -25, -0.01, 1, -26, -0.01, -1, -6, -5, -7, 9, -6, -10, 1),
			]
		&"fall":
			return [
				_p(1, -22, -0.04, 1, -23, -0.02, 4, -5, -6, -7, 9, -3, -9, -1),
				_p(0, -14, -0.08, 0, -15, -0.03, 8, -2, -7, -4, 8, 1, -8, -3),
			]
		&"land":
			return [
				_p(0, -4, -0.08, 0, -5, -0.03, 8, -1, -7, -2),
				_p(2, 6, 0.07, 2, 4, 0.03, 9, 0, -9, 0, 8, 5, -9, 5, 1.12, 0.82),
				_p(0, 2, -0.02, 0, 1, -0.01, 6, 0, -6, 0),
				_p(),
			]
		&"pickup":
			return [
				_p(),
				_p(2, 4, 0.18, 2, 2, 0.06, 6, 0, -6, 0, 15, 10, 8, 10, 1, 1, 0, 0, 0.8),
				_p(3, 7, 0.30, 3, 4, 0.10, 7, 0, -6, 0, 17, 18, 10, 17, 1, 1, 18, 19, 0.65),
				_p(0, 0, 0.0, 0, 0, 0.0, 5, 0, -5, 0, 15, -8, 7, -8, 1, 1, 14, -10, 1.0),
			]
		&"carry":
			return [
				_p(0, 0, 0, 0, 0, 0, 5, 0, -5, 0, 15, -8, 7, -8, 1, 1, 14, -10),
				_p(0, 0.8, 0.005, 0, 0.4, -0.01, 6, 0, -5, -1, 15, -9, 7, -9, 1, 1, 14, -11),
			]
		&"put_down":
			return [
				_p(0, 0, 0, 0, 0, 0, 5, 0, -5, 0, 15, -8, 7, -8, 1, 1, 14, -10),
				_p(3, 7, 0.28, 3, 4, 0.09, 7, 0, -6, 0, 17, 18, 10, 17, 1, 1, 18, 19),
				_p(),
			]
		&"throw_charge":
			return [
				_p(-3, 1, -0.12, -2, 0, -0.04, 6, 0, -6, 0, 9, -18, 3, -13, 1, 1, 8, -19),
				_p(-5, 2, -0.20, -3, 0, -0.07, 7, 0, -7, 0, 6, -21, 0, -16, 1, 1, 5, -22),
			]
		&"throw_release":
			return [
				_p(-5, 2, -0.20, -3, 0, -0.07, 7, 0, -7, 0, 6, -21, 0, -16, 1, 1, 5, -22),
				_p(3, -1, 0.20, 2, -1, 0.07, 8, 0, -5, -2, 22, -12, -8, 3, 1, 1, 26, -14),
				_p(6, 0, 0.25, 4, 0, 0.10, 10, 0, -5, -2, 28, 0, -10, 4, 1, 0),
				_p(0, 0, 0.02, 0, 0, 0.0, 5, 0, -5, 0, 12, 0, -10, 2),
			]
		&"shield_equip":
			return [_p(), _shield_pose(6, 7, 0.55), _shield_pose(14, -2, 0.16)]
		&"shield_ready":
			return [_shield_pose(14, -2, 0.16), _shield_pose(14, -1, 0.12, 0, 0.5)]
		&"shield_raise":
			return [_shield_pose(14, -2, 0.32), _shield_pose(20, -11, 0.0, -1), _shield_pose(22, -12, -0.03, -2)]
		&"shield_guard":
			return [_shield_pose(22, -12, -0.03, -2), _shield_pose(21, -13, -0.05, -2, 0.8)]
		&"shield_lower":
			return [_shield_pose(22, -12, -0.03, -2), _shield_pose(14, -2, 0.28), _shield_pose(14, -2, 0.16)]
		&"shield_parry":
			return [
				_shield_pose(14, -2, -0.82),
				_shield_pose(7, -13, -1.05, -4),
				_shield_pose(27, -9, 0.18, 5),
				_shield_pose(30, -1, 0.62, 7),
				_shield_pose(14, -2, 0.16),
			]
		&"shield_block":
			return [
				_shield_pose(22, -12, -0.03, -2),
				_shield_pose(13, -12, -0.10, -7, 4),
				_shield_pose(18, -12, -0.04, -4, 2),
				_shield_pose(22, -12, -0.03, -2),
			]
		&"blade_equip":
			return [_p(), _blade_pose(5, 7, 1.05), _blade_pose(14, 0, -0.18)]
		&"blade_ready":
			return [_blade_pose(14, 0, -0.18), _blade_pose(14, 1, -0.14, 0, 0.5)]
		&"blade_swing":
			return [
				_blade_pose(14, 0, -0.18),
				_blade_pose(3, -10, -2.55, -3),
				_blade_pose(8, -17, -1.55, -4),
				_blade_pose(25, -12, -0.50, 3),
				_blade_pose(31, 1, 0.48, 7),
				_blade_pose(21, 7, 0.72, 5),
				_blade_pose(14, 0, -0.18),
			]
		&"push_engage":
			return [_p(), _push_pose(17, -9, 0.12), _push_pose(27, -10, 0.24, 4)]
		&"push":
			return _push_keys()
		&"push_release":
			return [_push_pose(27, -10, 0.24, 4), _push_pose(18, -3, -0.06, -1), _p()]
		&"hit":
			return [
				_p(),
				_p(-5, 0, -0.24, -4, 0, -0.12, 4, 0, -7, 0, 4, 4, -14, -6),
				_p(-8, 4, -0.42, -7, 2, -0.20, 1, 0, -9, 0, -5, 8, -16, -10, 0.92, 1.05, 0, 0, 0.45),
				_p(),
			]
		&"failure":
			return [
				_p(),
				_p(-6, 5, -0.36, -5, 3, -0.18, 2, 0, -8, 0, -5, 8, -15, -9),
				_p(-10, 13, -0.88, -9, 11, -0.48, -3, 0, -11, 0, -12, 14, -17, 4),
				_p(-13, 25, -1.30, -12, 23, -0.76, -9, 0, -15, 0, -16, 16, -18, 9, 1, 1, 0, 0, 0.35),
			]
	return []

func _walk_keys() -> Array:
	return [
		_p(2, 0, 0.12, 2, 0, 0.04, 14, 0, -10, -4, -9, 2, 13, -8),
		_p(3, 3, 0.16, 2, 1, 0.05, 10, 0, -6, -5, -4, -5, 8, -2, 1.04, 0.94),
		_p(2, 0, 0.14, 2, 0, 0.04, 1, -4, 10, 0, 12, -8, -8, 2),
		_p(3, -2, 0.15, 2, -1, 0.05, -5, -6, 9, 0, 8, -2, -4, -5, 0.98, 1.04),
		_p(2, 0, 0.12, 2, 0, 0.04, -10, -4, 14, 0, 13, -8, -9, 2),
		_p(3, 3, 0.16, 2, 1, 0.05, -6, -5, 10, 0, 8, -2, -4, -5, 1.04, 0.94),
		_p(2, 0, 0.14, 2, 0, 0.04, 10, 0, 1, -4, -8, 2, 12, -8),
		_p(3, -2, 0.15, 2, -1, 0.05, 9, 0, -5, -6, -4, -5, 8, -2, 0.98, 1.04),
	]

func _push_keys() -> Array:
	return [
		_push_pose(27, -10, 0.24, 4, 8, 0, -9, 0),
		_push_pose(27, -10, 0.27, 5, 11, 0, -6, -3),
		_push_pose(27, -10, 0.25, 4, 5, -3, -10, 0),
		_push_pose(27, -10, 0.28, 5, -7, -3, 10, 0),
		_push_pose(27, -10, 0.24, 4, -9, 0, 8, 0),
		_push_pose(27, -10, 0.26, 5, -5, -2, 6, -2),
	]

func _equipped_walk_keys(equipment: StringName) -> Array:
	var result: Array = []
	for source_pose in _walk_keys():
		var pose: Dictionary = source_pose.duplicate()
		if equipment == &"throwable":
			pose["fhx"] = 15.0
			pose["fhy"] = -8.0
			pose["bhx"] = 7.0
			pose["bhy"] = -8.0
			pose["ox"] = 14.0
			pose["oy"] = -10.0
		elif equipment == &"shield":
			pose["fhx"] = 14.0
			pose["fhy"] = -2.0
			pose["bhx"] = -10.0
			pose["bhy"] = 2.0
			pose["ea"] = 0.16
		elif equipment == &"blade":
			pose["fhx"] = 14.0
			pose["fhy"] = 0.0
			pose["bhx"] = -11.0
			pose["bhy"] = 2.0
			pose["ea"] = -0.18
		result.append(pose)
	return result

func _shield_pose(hand_x: float, hand_y: float, shield_angle: float, body_x: float = 0.0, body_y: float = 0.0) -> Dictionary:
	return _p(body_x, body_y, -0.06 if hand_x > 18.0 else 0.0, body_x * 0.7, body_y, -0.02, 5, 0, -5, 0, hand_x, hand_y, hand_x - 7, hand_y + 8, 1, 1, 0, 0, 1, shield_angle)

func _blade_pose(hand_x: float, hand_y: float, blade_angle: float, body_x: float = 0.0, body_y: float = 0.0) -> Dictionary:
	return _p(body_x, body_y, 0.07 if hand_x > 20.0 else 0.0, body_x * 0.7, body_y, 0.03, 5, 0, -5, 0, hand_x, hand_y, -12, 2, 1, 1, 0, 0, 1, blade_angle)

func _push_pose(
	hand_x: float,
	hand_y: float,
	body_rotation: float,
	body_x: float = 4.0,
	front_foot_x: float = 8.0,
	front_foot_y: float = 0.0,
	back_foot_x: float = -9.0,
	back_foot_y: float = 0.0
) -> Dictionary:
	return _p(body_x, 2, body_rotation, body_x * 0.65, 1, body_rotation * 0.30, front_foot_x, front_foot_y, back_foot_x, back_foot_y, hand_x, hand_y, hand_x - 1, hand_y + 9)

func _p(
	body_x: float = 0.0,
	body_y: float = 0.0,
	body_rotation: float = 0.0,
	head_x: float = 0.0,
	head_y: float = 0.0,
	head_rotation: float = 0.0,
	front_foot_x: float = 5.0,
	front_foot_y: float = 0.0,
	back_foot_x: float = -5.0,
	back_foot_y: float = 0.0,
	front_hand_x: float = 13.0,
	front_hand_y: float = 1.0,
	back_hand_x: float = -12.0,
	back_hand_y: float = 2.0,
	scale_x: float = 1.0,
	scale_y: float = 1.0,
	object_x: float = 0.0,
	object_y: float = 0.0,
	eye_open: float = 1.0,
	equipment_angle: float = 0.0
) -> Dictionary:
	return {
		"bx": body_x, "by": body_y, "br": body_rotation,
		"hx": head_x, "hy": head_y, "hr": head_rotation,
		"ffx": front_foot_x, "ffy": front_foot_y,
		"bfx": back_foot_x, "bfy": back_foot_y,
		"fhx": front_hand_x, "fhy": front_hand_y,
		"bhx": back_hand_x, "bhy": back_hand_y,
		"sx": scale_x, "sy": scale_y,
		"ox": object_x, "oy": object_y,
		"eye": eye_open, "ea": equipment_angle,
	}

func _with_eye(pose: Dictionary, eye_open: float) -> Dictionary:
	pose["eye"] = eye_open
	return pose

func _bake(keys: Array, frame_count: int, loop: bool) -> Array:
	var result: Array = []
	var segment_count := keys.size() if loop else keys.size() - 1
	for frame_index in range(frame_count):
		var normalized := float(frame_index) / float(frame_count if loop else maxi(1, frame_count - 1))
		var segment_value := normalized * float(segment_count)
		var from_index := mini(int(floor(segment_value)), keys.size() - 1)
		var to_index := (from_index + 1) % keys.size() if loop else mini(from_index + 1, keys.size() - 1)
		var weight := smoothstep(0.0, 1.0, segment_value - floor(segment_value))
		result.append(_lerp_pose(keys[from_index], keys[to_index], weight))
	return result

func _lerp_pose(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var result := {}
	for key in from.keys():
		result[key] = lerpf(float(from[key]), float(to[key]), weight)
	return result

func _equipment_for_clip(clip: StringName) -> StringName:
	if clip in [&"pickup", &"carry", &"put_down", &"throw_charge", &"throw_release"]:
		return &"throwable"
	if clip == &"carry_walk":
		return &"throwable"
	if clip.begins_with("shield"):
		return &"shield"
	if clip.begins_with("blade"):
		return &"blade"
	return &"none"

func _svg_for_pose(p: Dictionary, equipment: StringName, clip: StringName, frame_index: int) -> String:
	var body := Vector2(92.0 + float(p["bx"]), 140.0 + float(p["by"]))
	var head := Vector2(98.0 + float(p["hx"]), 78.0 + float(p["hy"]))
	var front_foot := Manifest.ROOT + Vector2(float(p["ffx"]), float(p["ffy"]))
	var back_foot := Manifest.ROOT + Vector2(float(p["bfx"]), float(p["bfy"]))
	var front_hand := body + Vector2(float(p["fhx"]), float(p["fhy"]))
	var back_hand := body + Vector2(float(p["bhx"]), float(p["bhy"]))
	var front_shoulder := body + Vector2(12.0, -13.0)
	var back_shoulder := body + Vector2(-11.0, -12.0)
	var front_hip := body + Vector2(7.0, 14.0)
	var back_hip := body + Vector2(-7.0, 14.0)
	var front_knee := front_hip.lerp(front_foot, 0.55) + Vector2(3.0, -1.0)
	var back_knee := back_hip.lerp(back_foot, 0.55) + Vector2(-3.0, 0.0)
	var front_elbow := front_shoulder.lerp(front_hand, 0.52) + Vector2(3.0, 2.0)
	var back_elbow := back_shoulder.lerp(back_hand, 0.52) + Vector2(-3.0, 2.0)
	var equipment_svg := _equipment_svg(equipment, front_hand, back_hand, float(p["ea"]), p, clip)
	var eye_width := 6.8 * float(p["eye"])
	var body_path := _polygon_path(PackedVector2Array([
		body + Vector2(-15.0, -23.0),
		body + Vector2(-20.0, -7.0),
		body + Vector2(-16.0, 13.0),
		body + Vector2(-11.0, 22.0),
		body + Vector2(-3.0, 18.0),
		body + Vector2(4.0, 24.0),
		body + Vector2(12.0, 18.0),
		body + Vector2(17.0, 12.0),
		body + Vector2(19.0, -8.0),
		body + Vector2(14.0, -23.0),
	]))
	var helmet_path := _polygon_path(PackedVector2Array([
		head + Vector2(-49.0, -47.0),
		head + Vector2(-10.0, -38.0),
		head + Vector2(-10.0, -29.0),
		head + Vector2(3.0, -31.0),
		head + Vector2(3.0, -41.0),
		head + Vector2(18.0, -37.0),
		head + Vector2(18.0, -28.0),
		head + Vector2(36.0, -22.0),
		head + Vector2(37.0, 8.0),
		head + Vector2(24.0, 11.0),
		head + Vector2(33.0, 18.0),
		head + Vector2(30.0, 35.0),
		head + Vector2(17.0, 39.0),
		head + Vector2(6.0, 32.0),
		head + Vector2(-35.0, 36.0),
		head + Vector2(-48.0, 16.0),
		head + Vector2(-44.0, -10.0),
	]))
	var body_transform := "rotate(%.2f %.2f %.2f) scale(%.3f %.3f)" % [
		rad_to_deg(float(p["br"])), body.x, body.y, float(p["sx"]), float(p["sy"]),
	]
	var helmet_transform := "rotate(%.2f %.2f %.2f) scale(%.3f %.3f)" % [
		rad_to_deg(float(p["hr"])), head.x, head.y, float(p["sx"]), float(p["sy"]),
	]
	var eye_svg := "<ellipse cx=\"%.2f\" cy=\"%.2f\" rx=\"%.2f\" ry=\"3.8\" fill=\"#ffad42\"/>" % [
		head.x + 20.5, head.y + 10.0, eye_width,
	]
	var mouth_svg := "<path d=\"%s\" fill=\"none\" stroke=\"#d7792d\" stroke-width=\"2.5\" stroke-linecap=\"round\"/>" % _quadratic_path(
		head + Vector2(18.0, 20.0),
		head + Vector2(22.0, 23.0),
		head + Vector2(26.0, 19.5)
	)
	return """<svg xmlns="http://www.w3.org/2000/svg" width="192" height="192" viewBox="0 0 192 192">
<!-- %s | fixed canvas 192x192 | root 96,174 -->
<g fill="#010203" stroke="#010203" stroke-linecap="round" stroke-linejoin="round">
<path d="%s" fill="none" stroke-width="11"/>
<path d="%s" fill="none" stroke-width="12"/>
<path d="%s" fill="none" stroke-width="10"/>
<g transform="%s"><path d="%s"/></g>
<path d="%s" fill="none" stroke-width="11"/>
<circle cx="%s" cy="%s" r="5.8"/>
<circle cx="%s" cy="%s" r="5.4"/>
%s
<g transform="%s"><path d="%s"/></g>
</g>
%s
%s
</svg>""" % [
		"%s frame %02d" % [String(clip), frame_index],
		_quadratic_path(back_hip, back_knee, back_foot + Vector2(0.0, -2.0)),
		_quadratic_path(front_hip, front_knee, front_foot + Vector2(0.0, -2.0)),
		_quadratic_path(back_shoulder, back_elbow, back_hand),
		body_transform,
		body_path,
		_quadratic_path(front_shoulder, front_elbow, front_hand),
		"%.2f" % back_hand.x, "%.2f" % back_hand.y,
		"%.2f" % front_hand.x, "%.2f" % front_hand.y,
		equipment_svg,
		helmet_transform,
		helmet_path,
		eye_svg,
		mouth_svg,
	]

func _quadratic_path(start: Vector2, control: Vector2, finish: Vector2) -> String:
	return "M %.2f %.2f Q %.2f %.2f %.2f %.2f" % [
		start.x, start.y, control.x, control.y, finish.x, finish.y,
	]

func _polygon_path(points: PackedVector2Array) -> String:
	if points.is_empty():
		return ""
	var result := "M %.2f %.2f" % [points[0].x, points[0].y]
	for point_index in range(1, points.size()):
		result += " L %.2f %.2f" % [points[point_index].x, points[point_index].y]
	return result + " Z"

func _equipment_svg(equipment: StringName, front_hand: Vector2, back_hand: Vector2, angle: float, p: Dictionary, clip: StringName) -> String:
	if equipment == &"throwable":
		if clip == &"throw_release" and float(p["ox"]) == 0.0:
			return ""
		var center := Vector2(92.0 + float(p["bx"]), 140.0 + float(p["by"])) + Vector2(float(p["ox"]), float(p["oy"]))
		if center == Vector2(92.0 + float(p["bx"]), 140.0 + float(p["by"])):
			center = front_hand.lerp(back_hand, 0.45) + Vector2(3.0, -3.0)
		return "<circle cx=\"%.2f\" cy=\"%.2f\" r=\"7.0\" fill=\"#010203\"/>" % [center.x, center.y]
	if equipment == &"shield":
		var center := front_hand + Vector2(8.0, 0.0)
		return """<g transform="rotate(%.2f %.2f %.2f)"><path d="M %.2f %.2f Q %.2f %.2f %.2f %.2f L %.2f %.2f Q %.2f %.2f %.2f %.2f Q %.2f %.2f %.2f %.2f Z" fill="#010203"/></g>""" % [
			rad_to_deg(angle), center.x, center.y,
			center.x - 12.0, center.y - 20.0, center.x, center.y - 24.0, center.x + 13.0, center.y - 18.0,
			center.x + 15.0, center.y + 4.0, center.x + 8.0, center.y + 16.0, center.x, center.y + 22.0,
			center.x - 13.0, center.y + 11.0, center.x - 12.0, center.y - 20.0,
		]
	if equipment == &"blade":
		return """<g transform="rotate(%.2f %.2f %.2f)"><path d="M %.2f %.2f L %.2f %.2f L %.2f %.2f L %.2f %.2f Z" fill="#010203"/><path d="M %.2f %.2f L %.2f %.2f" stroke="#010203" stroke-width="5"/></g>""" % [
			rad_to_deg(angle), front_hand.x, front_hand.y,
			front_hand.x + 3.0, front_hand.y - 3.2, front_hand.x + 41.0, front_hand.y - 1.6,
			front_hand.x + 48.0, front_hand.y, front_hand.x + 3.0, front_hand.y + 3.2,
			front_hand.x - 6.0, front_hand.y, front_hand.x + 6.0, front_hand.y,
		]
	return ""
