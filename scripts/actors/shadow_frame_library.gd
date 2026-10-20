extends RefCounted

const FRAME_SIZE := Vector2i(96, 96)
const ROOT := Vector2(48.0, 88.0)

static func build_clips() -> Dictionary:
	var clips := {}
	_add_clip(clips, &"idle", [_p(), _p(0, 0.5, 0.0, 0, 0.4, 0.01), _p(0, 0, 0.0, 0, -0.2, -0.01)], 8, 8.0, true)
	_add_clip(clips, &"start", [_p(), _p(1, 1, 0.08, 1, 0, 0.03, 5, 0, -2, -1, 4, -2, -3, 1), _p(2, -0.5, 0.14, 2, -1, 0.05, 9, 0, -5, -3, 7, -5, -6, 3)], 6, 18.0)
	_add_clip(clips, &"run", _run_keys(), 12, 20.0, true)
	_add_clip(clips, &"carry_run", _equipment_run_keys(&"throwable"), 12, 18.0, true, &"throwable")
	_add_clip(clips, &"shield_run", _equipment_run_keys(&"shield"), 12, 18.0, true, &"shield")
	_add_clip(clips, &"blade_run", _equipment_run_keys(&"blade"), 12, 18.0, true, &"blade")
	_add_clip(clips, &"stop", [_p(2, -0.5, 0.14, 2, -1, 0.05, 8, 0, -5, -2, 7, -4, -6, 3), _p(1, 1.5, -0.08, 1, 1, -0.03, 4, 0, -4, 0, 2, 1, -1, 0), _p()], 6, 18.0)
	_add_clip(clips, &"turn", [_p(1, 0, 0.14, 1, 0, 0.08), _p(0, 2, 0.0, 0, 1, 0.0, 3, 0, -3, 0), _p()], 6, 20.0)

	_add_clip(clips, &"takeoff", [_p(0, 2, 0.02, 0, 1, 0.0, 5, 0, -5, 0), _p(1, 4, 0.12, 1, 2, 0.05, 6, -1, -5, 0, 5, -2, -5, 1), _p(2, -2, 0.16, 2, -2, 0.07, 5, -5, -3, -4, 7, -6, -5, 4)], 5, 20.0)
	_add_clip(clips, &"rise", [_p(2, -2, 0.15, 2, -2, 0.06, 4, -6, -4, -5, 8, -6, -6, 4), _p(1, -3, 0.10, 1, -3, 0.04, 2, -7, -5, -4, 7, -8, -5, 5)], 4, 14.0, true)
	_add_clip(clips, &"apex", [_p(1, -3, 0.04, 1, -3, 0.02, 1, -5, -4, -6, 5, -6, -5, 2), _p(0, -2, -0.01, 0, -2, -0.01, -1, -4, -3, -5, 3, -4, -4, 1)], 4, 10.0, true)
	_add_clip(clips, &"fall", [_p(0, -1, -0.04, 0, -1, -0.02, 4, -3, -4, -5, 2, -2, -2, -1), _p(-1, 0, -0.08, -1, 0, -0.03, 6, -2, -5, -3, 1, 0, -1, -2)], 4, 12.0, true)
	_add_clip(clips, &"land", [_p(-1, 0, -0.08, -1, 0, -0.03, 6, -1, -5, -2), _p(1, 5, 0.08, 1, 3, 0.04, 7, 0, -7, 0, 4, 1, -5, 2), _p(0, 1, -0.02, 0, 1, -0.01, 5, 0, -5, 0), _p()], 7, 20.0)

	_add_clip(clips, &"pickup", [_p(), _p(2, 4, 0.26, 2, 2, 0.10, 5, 0, -5, 0, 9, 12, 3, 11, 0, 0, 0), _p(2, 5, 0.32, 2, 3, 0.12, 6, 0, -5, 0, 11, 17, 5, 16, 0, 0, 1), _p(0, 0, 0.0, 0, 0, 0.0, 5, 0, -5, 0, 9, -8, 3, -7, 0, 0, 1)], 9, 18.0, false, &"throwable")
	_add_clip(clips, &"carry", [_p(0, 0, 0, 0, 0, 0, 5, 0, -5, 0, 9, -8, 3, -7, 0, 0, 1), _p(0, 0.6, 0, 0, 0.4, 0.01, 6, 0, -5, -1, 10, -8, 4, -7, 0, 0, 1)], 8, 12.0, true, &"throwable")
	_add_clip(clips, &"put_down", [_p(0, 0, 0, 0, 0, 0, 5, 0, -5, 0, 9, -8, 3, -7, 0, 0, 1), _p(2, 5, 0.30, 2, 3, 0.10, 6, 0, -5, 0, 11, 17, 5, 16, 0, 0, 1), _p(1, 4, 0.22, 1, 2, 0.08, 5, 0, -5, 0, 9, 13, 3, 12, 0, 0, 0), _p()], 9, 18.0, false, &"throwable")
	_add_clip(clips, &"throw_charge", [_p(-2, 0, -0.12, -2, 0, -0.04, 5, 0, -5, 0, 7, -18, 2, -13, -3, -1, 1), _p(-3, 1, -0.18, -2, 0, -0.06, 6, 0, -6, 0, 5, -20, 0, -15, -5, -1, 1)], 8, 12.0, true, &"throwable")
	_add_clip(clips, &"throw_release", [_p(-3, 1, -0.18, -2, 0, -0.06, 6, 0, -6, 0, 4, -20, 0, -15, -5, -1, 1), _p(3, -1, 0.20, 2, -1, 0.08, 7, 0, -4, -2, 15, -10, -5, 2, 3, 0, 1), _p(5, 0, 0.24, 3, 0, 0.10, 8, 0, -4, -2, 18, 1, -6, 3, 5, 1, 0), _p(0, 0, 0.02, 0, 0, 0.0, 5, 0, -5, 0, 7, -1, -5, 1)], 10, 22.0)

	_add_clip(clips, &"shield_equip", [_p(), _shield_pose(3, 7, 0.55), _shield_pose(8, -1, 0.18)], 7, 18.0, false, &"shield")
	_add_clip(clips, &"shield_ready", [_shield_pose(8, -1, 0.18), _shield_pose(8, 0, 0.15)], 6, 9.0, true, &"shield")
	_add_clip(clips, &"shield_raise", [_shield_pose(8, -1, 0.34), _shield_pose(12, -8, 0.0)], 6, 20.0, false, &"shield")
	_add_clip(clips, &"shield_guard", [_shield_pose(12, -8, 0.0), _shield_pose(11, -8.5, -0.02, 1)], 8, 10.0, true, &"shield")
	_add_clip(clips, &"shield_lower", [_shield_pose(12, -8, 0.0), _shield_pose(8, -1, 0.30)], 6, 18.0, false, &"shield")
	_add_clip(clips, &"shield_parry", [_shield_pose(8, -1, -0.82), _shield_pose(15, -7, -0.25, -1), _shield_pose(17, 0, 0.62, 2), _shield_pose(8, -1, 0.18)], 10, 24.0, false, &"shield")
	_add_clip(clips, &"shield_block", [_shield_pose(12, -8, 0.0), _shield_pose(7, -8, -0.09, 3), _shield_pose(10, -8, 0.0, 1), _shield_pose(12, -8, 0.0)], 8, 26.0, false, &"shield")

	_add_clip(clips, &"blade_equip", [_p(), _blade_pose(5, 6, 1.15), _blade_pose(9, 0, -0.18)], 7, 18.0, false, &"blade")
	_add_clip(clips, &"blade_ready", [_blade_pose(9, 0, -0.18), _blade_pose(9, 1, -0.14)], 6, 9.0, true, &"blade")
	_add_clip(clips, &"blade_swing", [_blade_pose(9, 0, -0.18), _blade_pose(4, -11, -1.60, -2), _blade_pose(9, -16, -1.78, -3), _blade_pose(18, -1, 0.56, 5), _blade_pose(11, 5, 0.66, 3), _blade_pose(9, 0, -0.18)], 12, 26.0, false, &"blade")

	_add_clip(clips, &"push_engage", [_p(), _push_pose(15, -9, 0.16), _push_pose(20, -9, 0.23)], 7, 20.0)
	_add_clip(clips, &"push", _push_keys(), 12, 17.0, true)
	_add_clip(clips, &"push_release", [_push_pose(20, -9, 0.23), _push_pose(11, -2, -0.06), _p()], 7, 18.0)
	_add_clip(clips, &"hit", [_p(), _p(-4, 0, -0.24, -4, 0, -0.12, 4, 0, -6, 0, 1, 1, -8, -5), _p(-6, 3, -0.38, -5, 1, -0.18, 2, 0, -7, 0, -3, 5, -10, -8), _p()], 8, 24.0)
	_add_clip(clips, &"failure", [_p(), _p(-5, 4, -0.32, -5, 2, -0.18, 3, 0, -7, 0, -3, 5, -10, -8), _p(-8, 10, -0.82, -7, 8, -0.44, 0, 0, -9, 0, -8, 12, -12, 4), _p(-10, 18, -1.25, -9, 16, -0.72, -5, 0, -12, 0, -12, 14, -14, 8)], 10, 16.0)
	return clips

static func _run_keys() -> Array:
	return [
		_p(2, 0, 0.14, 2, 0, 0.05, 13, 0, -10, -4, -8, 1, 10, -8, -5),
		_p(3, 2, 0.17, 2, 1, 0.06, 9, 0, -5, -5, -3, -5, 6, -2, -7),
		_p(2, 0, 0.15, 2, 0, 0.05, 1, -4, 10, 0, 9, -8, -7, 1, -5),
		_p(3, 2, 0.17, 2, 1, 0.06, -5, -5, 9, 0, 6, -2, -3, -5, -7),
		_p(2, 0, 0.14, 2, 0, 0.05, -10, -4, 13, 0, 10, -8, -8, 1, -5),
		_p(2, -1, 0.13, 2, -1, 0.04, -2, -2, 4, -2, 2, -5, -1, -3, -4),
	]

static func _equipment_run_keys(equipment: StringName) -> Array:
	var result: Array = []
	for source in _run_keys():
		var pose: Dictionary = source.duplicate()
		pose["ev"] = 1.0
		if equipment == &"throwable":
			pose["fhx"] = 9.0
			pose["fhy"] = -8.0
			pose["bhx"] = 3.0
			pose["bhy"] = -7.0
		elif equipment == &"shield":
			pose["fhx"] = 8.0
			pose["fhy"] = -1.0
			pose["bhx"] = -4.0
			pose["bhy"] = 1.0
			pose["ea"] = 0.18
		elif equipment == &"blade":
			pose["fhx"] = 9.0
			pose["fhy"] = 0.0
			pose["bhx"] = -5.0
			pose["bhy"] = 1.0
			pose["ea"] = -0.18
		result.append(pose)
	return result

static func _push_keys() -> Array:
	return [
		_push_pose(20, -9, 0.23, 0, 5, 0, -7, 0),
		_push_pose(20, -9, 0.25, 1, 8, 0, -5, -2),
		_push_pose(20, -9, 0.24, 0, 4, -2, -8, 0),
		_push_pose(20, -9, 0.26, 1, -5, -2, 8, 0),
		_push_pose(20, -9, 0.23, 0, -7, 0, 5, 0),
		_push_pose(20, -9, 0.24, -1, -3, -1, 3, -1),
	]

static func _shield_pose(hand_x: float, hand_y: float, equipment_angle: float, body_x: float = 0.0) -> Dictionary:
	return _p(body_x, 0, -0.06 if hand_x > 10.0 else 0.0, body_x, 0, -0.02, 5, 0, -5, 0, hand_x, hand_y, hand_x - 5, hand_y + 7, -2, equipment_angle, 1)

static func _blade_pose(hand_x: float, hand_y: float, equipment_angle: float, body_x: float = 0.0) -> Dictionary:
	return _p(body_x, 0, 0.08 if hand_x > 12.0 else 0.0, body_x, 0, 0.03, 5, 0, -5, 0, hand_x, hand_y, -7, 0, -2, equipment_angle, 1)

static func _push_pose(
	hand_x: float,
	hand_y: float,
	body_rotation: float,
	body_y: float = 0.0,
	front_foot_x: float = 7.0,
	front_foot_y: float = 0.0,
	back_foot_x: float = -8.0,
	back_foot_y: float = 0.0
) -> Dictionary:
	return _p(4, body_y + 1, body_rotation, 4, body_y, body_rotation * 0.35, front_foot_x, front_foot_y, back_foot_x, back_foot_y, hand_x, hand_y, hand_x - 1, hand_y + 8, -7)

static func _p(
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
	front_hand_x: float = 8.0,
	front_hand_y: float = 0.0,
	back_hand_x: float = -7.0,
	back_hand_y: float = 1.0,
	cape: float = -2.0,
	equipment_angle: float = 0.0,
	equipment_visible: float = 0.0
) -> Dictionary:
	return {
		"bx": body_x,
		"by": body_y,
		"br": body_rotation,
		"hx": head_x,
		"hy": head_y,
		"hr": head_rotation,
		"ffx": front_foot_x,
		"ffy": front_foot_y,
		"bfx": back_foot_x,
		"bfy": back_foot_y,
		"fhx": front_hand_x,
		"fhy": front_hand_y,
		"bhx": back_hand_x,
		"bhy": back_hand_y,
		"cape": cape,
		"ea": equipment_angle,
		"ev": equipment_visible,
	}

static func _add_clip(
	target: Dictionary,
	name: StringName,
	keys: Array,
	frame_count: int,
	fps: float,
	loop: bool = false,
	equipment: StringName = &"none"
) -> void:
	var baked := _bake(keys, frame_count, loop)
	var textures: Array[Texture2D] = []
	var heads: Array[Vector2] = []
	for pose in baked:
		textures.append(_texture_for_pose(pose, equipment))
		heads.append(Vector2(53.0 + float(pose["hx"]), 34.0 + float(pose["hy"])))
	target[name] = {"frames": textures, "heads": heads, "fps": fps, "loop": loop}

static func _bake(keys: Array, frame_count: int, loop: bool) -> Array:
	var result: Array = []
	if keys.size() == 1:
		for _index in range(frame_count):
			result.append(keys[0].duplicate())
		return result
	var segment_count := keys.size() if loop else keys.size() - 1
	for frame_index in range(frame_count):
		var normalized := float(frame_index) / float(frame_count if loop else maxi(1, frame_count - 1))
		var segment_value := normalized * float(segment_count)
		var from_index := mini(int(floor(segment_value)), keys.size() - 1)
		var to_index := (from_index + 1) % keys.size() if loop else mini(from_index + 1, keys.size() - 1)
		var weight := smoothstep(0.0, 1.0, segment_value - floor(segment_value))
		result.append(_lerp_pose(keys[from_index], keys[to_index], weight))
	return result

static func _lerp_pose(from: Dictionary, to: Dictionary, weight: float) -> Dictionary:
	var result := {}
	for key in from.keys():
		result[key] = lerpf(float(from[key]), float(to[key]), weight)
	return result

static func _texture_for_pose(pose: Dictionary, equipment: StringName) -> Texture2D:
	var svg := _svg_for_pose(pose, equipment)
	var image := Image.new()
	var error := image.load_svg_from_string(svg, 1.0)
	if error != OK:
		push_error("Failed to build shadow animation frame: %s" % error)
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)

static func _svg_for_pose(p: Dictionary, equipment: StringName) -> String:
	var bx := 48.0 + float(p["bx"])
	var by := 60.0 + float(p["by"])
	var hx := 53.0 + float(p["hx"])
	var hy := 34.0 + float(p["hy"])
	var front_foot := Vector2(48.0 + float(p["ffx"]), 88.0 + float(p["ffy"]))
	var back_foot := Vector2(48.0 + float(p["bfx"]), 88.0 + float(p["bfy"]))
	var front_hand := Vector2(48.0 + float(p["fhx"]), 62.0 + float(p["fhy"]))
	var back_hand := Vector2(48.0 + float(p["bhx"]), 62.0 + float(p["bhy"]))
	var front_shoulder := Vector2(bx + 6.0, by - 10.0)
	var back_shoulder := Vector2(bx - 5.0, by - 9.0)
	var front_hip := Vector2(bx + 4.0, by + 8.0)
	var back_hip := Vector2(bx - 4.0, by + 8.0)
	var front_knee := front_hip.lerp(front_foot, 0.52) + Vector2(3.0, -1.0)
	var back_knee := back_hip.lerp(back_foot, 0.52) + Vector2(-2.0, 0.0)
	var front_elbow := front_shoulder.lerp(front_hand, 0.54) + Vector2(2.0, 2.0)
	var back_elbow := back_shoulder.lerp(back_hand, 0.54) + Vector2(-2.0, 2.0)
	var equipment_svg := _equipment_svg(equipment, front_hand, back_hand, float(p["ea"]), float(p["ev"]))
	return """<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">
<g fill="#010203" stroke="#010203" stroke-linecap="round" stroke-linejoin="round">
<path d="M %s %s Q %s %s %s %s" fill="none" stroke-width="7.5"/>
<path d="M %s %s Q %s %s %s %s" fill="none" stroke-width="7.8"/>
<ellipse cx="%s" cy="%s" rx="6.2" ry="3.5" transform="rotate(4 %s %s)"/>
<ellipse cx="%s" cy="%s" rx="6.0" ry="3.4" transform="rotate(-3 %s %s)"/>
<g transform="rotate(%s %s %s)">
<path d="M %s %s Q %s %s %s %s" fill="none" stroke-width="7.0"/>
<path d="M %s %s Q %s %s %s %s" fill="none" stroke-width="7.4"/>
<path d="M %s %s Q %s %s %s %s L %s %s Q %s %s %s %s Z" stroke="none"/>
</g>
<g transform="rotate(%s %s %s)">
<ellipse cx="%s" cy="%s" rx="12.0" ry="10.8" stroke="none"/>
<path d="M %s %s Q %s %s %s %s" fill="none" stroke-width="3.2"/>
</g>
%s
</g>
<ellipse cx="%s" cy="%s" rx="1.25" ry="1.0" fill="#e79a38" opacity="0.88" transform="rotate(%s %s %s)"/>
</svg>""" % [
		back_hip.x, back_hip.y, back_knee.x, back_knee.y, back_foot.x, back_foot.y - 2.0,
		front_hip.x, front_hip.y, front_knee.x, front_knee.y, front_foot.x, front_foot.y - 2.0,
		back_foot.x + 1.0, back_foot.y - 1.0, back_foot.x + 1.0, back_foot.y - 1.0,
		front_foot.x + 2.0, front_foot.y - 1.0, front_foot.x + 2.0, front_foot.y - 1.0,
		rad_to_deg(float(p["br"])), bx, by,
		back_shoulder.x, back_shoulder.y, back_elbow.x, back_elbow.y, back_hand.x, back_hand.y,
		front_shoulder.x, front_shoulder.y, front_elbow.x, front_elbow.y, front_hand.x, front_hand.y,
		bx - 8.0, by - 12.0, bx - 9.0, by - 1.0, bx - 6.0, by + 9.0,
		bx + 8.0, by + 9.0, bx + 10.0, by - 1.0, bx + 7.0, by - 12.0,
		rad_to_deg(float(p["hr"])), hx, hy,
		hx, hy, hx - 1.0, hy - 10.0, hx - 1.0, hy - 10.0, hx + 1.0, hy - 15.0,
		equipment_svg,
		hx + 5.2, hy + 0.2, rad_to_deg(float(p["hr"])), hx, hy,
	]

static func _equipment_svg(equipment: StringName, front_hand: Vector2, back_hand: Vector2, angle: float, visible_value: float) -> String:
	if visible_value < 0.5:
		return ""
	if equipment == &"throwable":
		var center := front_hand.lerp(back_hand, 0.42) + Vector2(3.0, -3.0)
		return "<circle cx=\"%s\" cy=\"%s\" r=\"7.0\" fill=\"#010203\"/>" % [center.x, center.y]
	if equipment == &"shield":
		var center := front_hand + Vector2(7.0, 0.0)
		return """<g transform="rotate(%s %s %s)">
<path d="M %s %s Q %s %s %s %s L %s %s Q %s %s %s %s Q %s %s %s %s Z" fill="#010203"/>
</g>""" % [
			rad_to_deg(angle), center.x, center.y,
			center.x - 11.0, center.y - 18.0, center.x, center.y - 22.0, center.x + 12.0, center.y - 17.0,
			center.x + 14.0, center.y + 3.0, center.x + 8.0, center.y + 14.0, center.x, center.y + 20.0,
			center.x - 12.0, center.y + 10.0, center.x - 11.0, center.y - 18.0,
		]
	if equipment == &"blade":
		return """<g transform="rotate(%s %s %s)">
<path d="M %s %s L %s %s L %s %s L %s %s Z" fill="#010203"/>
<path d="M %s %s L %s %s" stroke="#010203" stroke-width="4.0"/>
</g>""" % [
			rad_to_deg(angle), front_hand.x, front_hand.y,
			front_hand.x + 3.0, front_hand.y - 2.6, front_hand.x + 38.0, front_hand.y - 1.2,
			front_hand.x + 44.0, front_hand.y, front_hand.x + 3.0, front_hand.y + 2.6,
			front_hand.x - 5.0, front_hand.y, front_hand.x + 5.0, front_hand.y,
		]
	return ""
