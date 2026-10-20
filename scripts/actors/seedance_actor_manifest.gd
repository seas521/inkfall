extends RefCounted

const CANVAS_SIZE := Vector2i(256, 256)
const ROOT := Vector2(128.0, 232.0)
const FRAME_ROOT := "res://assets/art/actors/crooked_tower_seedance"
const SMALL_ITEM_CENTER_OFFSET := Vector2(-1.5, 1.5)

const SMALL_ITEM_ANCHORS := {
	&"pickup": [
		Vector2(183.9, 201.2),
		Vector2(173.2, 201.3),
		Vector2(157.2, 201.3),
		Vector2(152.2, 201.3),
		Vector2(151.6, 201.0),
		Vector2(151.0, 192.6),
		Vector2(155.5, 170.2),
		Vector2(157.5, 163.2),
	],
	&"carry": [
		Vector2(159.7, 168.9),
	],
	&"carry_run": [
		Vector2(165.5, 170.4),
		Vector2(167.0, 172.5),
		Vector2(168.0, 169.8),
		Vector2(168.2, 167.8),
		Vector2(162.5, 174.8),
		Vector2(160.4, 174.2),
		Vector2(170.1, 169.2),
		Vector2(171.4, 171.5),
		Vector2(172.8, 170.6),
		Vector2(171.0, 168.5),
		Vector2(166.2, 174.0),
		Vector2(159.6, 173.1),
		Vector2(163.2, 171.1),
		Vector2(165.6, 173.4),
		Vector2(167.8, 170.2),
	],
	&"carry_takeoff": [
		Vector2(155.0, 181.7),
		Vector2(154.5, 182.2),
		Vector2(155.4, 170.2),
		Vector2(158.6, 163.1),
	],
	&"carry_rise": [
		Vector2(157.5, 164.3),
		Vector2(160.6, 154.9),
		Vector2(161.7, 145.7),
		Vector2(162.3, 146.0),
	],
	&"carry_apex": [
		Vector2(161.8, 148.5),
		Vector2(162.4, 146.8),
		Vector2(162.8, 154.4),
	],
	&"carry_fall": [
		Vector2(162.8, 154.4),
		Vector2(163.5, 147.6),
		Vector2(156.3, 156.2),
		Vector2(155.4, 156.2),
	],
	&"carry_land": [
		Vector2(155.5, 180.0),
		Vector2(157.5, 173.5),
		Vector2(158.6, 171.1),
		Vector2(159.6, 168.4),
		Vector2(159.5, 168.2),
		Vector2(159.5, 168.2),
	],
	&"throw_charge": [
		Vector2(158.5, 162.0),
		Vector2(135.8, 161.5),
		Vector2(69.6, 137.6),
		Vector2(59.0, 129.7),
		Vector2(56.5, 130.7),
		Vector2(55.4, 131.6),
		Vector2(51.7, 134.7),
	],
	&"throw_release": [
		Vector2(51.9, 134.9),
		Vector2(51.4, 135.1),
		Vector2(49.3, 136.1),
		Vector2(135.5, 88.8),
	],
}

const CLIPS := {
	&"idle": {"frames": 1, "fps": 1.0, "loop": true},
	&"run": {"frames": 15, "fps": 24.0, "loop": true},
	&"takeoff": {"frames": 5, "fps": 40.0, "loop": false},
	&"rise": {"frames": 5, "fps": 14.0, "loop": true},
	&"apex": {"frames": 5, "fps": 10.0, "loop": true},
	&"fall": {"frames": 6, "fps": 14.0, "loop": true},
	&"land": {
		"frames": 15,
		"fps": 24.0,
		"loop": false,
		"soft_frame_order": [0, 1, 2, 3, 4],
		"medium_frame_order": [4, 5, 7, 9, 11, 13, 14],
		"hard_frame_order": [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
	},
	&"pickup": {"frames": 8, "fps": 26.0, "loop": false},
	&"carry": {"frames": 1, "fps": 1.0, "loop": true},
	&"carry_run": {"frames": 15, "fps": 24.0, "loop": true},
	&"carry_takeoff": {"frames": 4, "fps": 32.0, "loop": false},
	&"carry_rise": {"frames": 4, "fps": 12.0, "loop": true},
	&"carry_apex": {"frames": 3, "fps": 8.0, "loop": true},
	&"carry_fall": {"frames": 4, "fps": 12.0, "loop": true},
	&"carry_land": {"frames": 6, "fps": 24.0, "loop": false},
	&"put_down": {"frames": 8, "fps": 26.0, "loop": false},
	&"throw_charge": {"frames": 7, "fps": 10.0, "loop": false},
	&"throw_release": {"frames": 10, "fps": 28.0, "loop": false},
	&"shield_equip": {"frames": 1, "fps": 1.0, "loop": false},
	&"shield_ready": {"frames": 1, "fps": 1.0, "loop": true},
	&"shield_walk": {"frames": 24, "fps": 24.0, "loop": true, "distance": 232.0},
	&"shield_takeoff": {"frames": 4, "fps": 24.0, "loop": false, "frame_scale": 1.152},
	&"shield_rise": {"frames": 8, "fps": 48.0, "loop": true, "frame_scale": 1.152},
	&"shield_apex": {"frames": 5, "fps": 48.0, "loop": true, "frame_scale": 1.152},
	&"shield_fall": {"frames": 3, "fps": 24.0, "loop": true, "frame_scale": 1.152},
	&"shield_land": {"frames": 4, "fps": 24.0, "loop": false, "frame_scale": 1.152},
	&"shield_raise": {"frames": 6, "fps": 30.0, "loop": false},
	&"shield_guard": {"frames": 1, "fps": 1.0, "loop": true},
	&"shield_lower": {"frames": 6, "fps": 28.0, "loop": false},
	&"shield_parry": {"frames": 42, "fps": 36.0, "loop": false, "offset_x": 46.8, "frame_scale": 1.307},
	&"shield_block": {"frames": 8, "fps": 32.0, "loop": false},
	&"blade_equip": {"frames": 15, "fps": 24.0, "loop": false, "offset_x": -49.6, "frame_scale": 1.144},
	&"blade_ready": {"frames": 1, "fps": 1.0, "loop": true, "offset_x": -49.6, "frame_scale": 1.144},
	&"blade_run": {"frames": 45, "fps": 24.0, "loop": true, "distance": 232.0, "offset_x": -49.6, "frame_scale": 1.144},
	&"blade_swing": {"frames": 17, "fps": 24.0, "loop": false, "offset_x": 25.9, "frame_scale": 1.560},
	&"blade_sheathe": {"frames": 15, "fps": 24.0, "loop": false, "offset_x": -49.6, "frame_scale": 1.144},
	&"blade_sheathe_run": {"frames": 40, "fps": 24.0, "loop": false, "offset_x": -3.6, "frame_scale": 1.445},
	&"blade_draw_run": {"frames": 11, "fps": 24.0, "loop": false, "offset_x": -3.6, "frame_scale": 1.445},
	&"blade_sheathe_guard": {"frames": 14, "fps": 24.0, "loop": false, "offset_x": -3.6, "frame_scale": 1.445},
	&"combo_takeoff": {"frames": 3, "fps": 24.0, "loop": false, "offset_x": -3.6, "frame_scale": 1.445},
	&"combo_rise": {"frames": 10, "fps": 50.0, "loop": true, "offset_x": -3.6, "frame_scale": 1.445},
	&"combo_apex": {"frames": 6, "fps": 48.0, "loop": true, "offset_x": -3.6, "frame_scale": 1.445},
	&"combo_fall": {"frames": 8, "fps": 24.0, "loop": true, "offset_x": -3.6, "frame_scale": 1.445},
	&"combo_land": {
		"frames": 9,
		"fps": 24.0,
		"loop": false,
		"offset_x": -3.6,
		"frame_scale": 1.445,
	},
	&"combo_shield_parry": {"frames": 18, "fps": 24.0, "loop": false, "offset_x": -3.6, "frame_scale": 1.445},
	&"hit": {"frames": 14, "fps": 24.0, "loop": false},
	&"knockdown": {"frames": 34, "fps": 24.0, "loop": false, "offset_x": -82.2, "frame_scale": 1.144},
	&"downed": {"frames": 30, "fps": 24.0, "loop": true, "offset_x": -82.2, "frame_scale": 1.144},
	&"get_up": {"frames": 57, "fps": 24.0, "loop": false, "offset_x": -44.4, "frame_scale": 1.144},
	&"uncontrolled_fall": {"frames": 41, "fps": 24.0, "loop": false, "offset_x": 19.0, "frame_scale": 1.073},
	&"fall_impact": {"frames": 13, "fps": 24.0, "loop": false, "offset_x": 37.9, "frame_scale": 1.073},
	&"fall_downed": {"frames": 11, "fps": 24.0, "loop": true, "offset_x": 27.6, "frame_scale": 1.073},
}

static func frame_path(clip: StringName, frame_index: int) -> String:
	return "%s/%s/frame_%02d.png" % [FRAME_ROOT, String(clip), frame_index]

static func small_item_anchor(clip: StringName, frame_index: int):
	var anchor_clip := clip
	var anchor_index := frame_index
	if clip == &"put_down":
		anchor_clip = &"pickup"
		anchor_index = int(CLIPS[&"pickup"]["frames"]) - 1 - frame_index
	if not SMALL_ITEM_ANCHORS.has(anchor_clip):
		return null
	var anchors: Array = SMALL_ITEM_ANCHORS[anchor_clip]
	if anchor_index < 0 or anchor_index >= anchors.size():
		return null
	return Vector2(anchors[anchor_index]) + SMALL_ITEM_CENTER_OFFSET
