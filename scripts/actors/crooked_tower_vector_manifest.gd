extends RefCounted

const CANVAS_SIZE := Vector2i(192, 192)
const ROOT := Vector2(96.0, 174.0)
const FRAME_ROOT := "res://assets/art/actors/crooked_tower_vector"

const CLIPS := {
	&"idle": {"frames": 8, "fps": 8.0, "loop": true},
	&"start": {"frames": 4, "fps": 18.0, "loop": false},
	&"walk": {"frames": 12, "fps": 20.0, "loop": true},
	&"stop": {"frames": 4, "fps": 18.0, "loop": false},
	&"turn": {"frames": 4, "fps": 20.0, "loop": false},
	&"takeoff": {"frames": 4, "fps": 20.0, "loop": false},
	&"rise": {"frames": 4, "fps": 14.0, "loop": true},
	&"apex": {"frames": 3, "fps": 9.0, "loop": true},
	&"fall": {"frames": 4, "fps": 12.0, "loop": true},
	&"land": {"frames": 6, "fps": 20.0, "loop": false},
	&"pickup": {"frames": 8, "fps": 18.0, "loop": false},
	&"carry": {"frames": 4, "fps": 8.0, "loop": true},
	&"carry_walk": {"frames": 12, "fps": 18.0, "loop": true},
	&"put_down": {"frames": 6, "fps": 18.0, "loop": false},
	&"throw_charge": {"frames": 6, "fps": 10.0, "loop": true},
	&"throw_release": {"frames": 8, "fps": 22.0, "loop": false},
	&"shield_equip": {"frames": 6, "fps": 18.0, "loop": false},
	&"shield_ready": {"frames": 4, "fps": 7.0, "loop": true},
	&"shield_walk": {"frames": 12, "fps": 18.0, "loop": true},
	&"shield_raise": {"frames": 5, "fps": 20.0, "loop": false},
	&"shield_guard": {"frames": 6, "fps": 9.0, "loop": true},
	&"shield_lower": {"frames": 5, "fps": 18.0, "loop": false},
	&"shield_parry": {"frames": 8, "fps": 24.0, "loop": false},
	&"shield_block": {"frames": 6, "fps": 24.0, "loop": false},
	&"blade_equip": {"frames": 6, "fps": 18.0, "loop": false},
	&"blade_ready": {"frames": 4, "fps": 7.0, "loop": true},
	&"blade_walk": {"frames": 12, "fps": 18.0, "loop": true},
	&"blade_swing": {"frames": 10, "fps": 24.0, "loop": false},
	&"push_engage": {"frames": 5, "fps": 18.0, "loop": false},
	&"push": {"frames": 10, "fps": 17.0, "loop": true},
	&"push_release": {"frames": 5, "fps": 18.0, "loop": false},
	&"hit": {"frames": 6, "fps": 22.0, "loop": false},
	&"failure": {"frames": 8, "fps": 16.0, "loop": false},
}

static func frame_path(clip: StringName, frame_index: int) -> String:
	return "%s/%s/frame_%02d.svg" % [FRAME_ROOT, String(clip), frame_index]
