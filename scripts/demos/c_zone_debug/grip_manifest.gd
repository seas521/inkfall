extends RefCounted

# Local full-frame placeholders; replace with continuous Seedance clips later.
const ROOT := Vector2(96, 174)
const SCALE := 0.45
const HAND := Vector2(50, -40)
const CYCLE_DISTANCE := 36.0
const CLIPS := {
	&"grip_engage": {"frames": 8, "loop": false},
	&"grip_hold": {"frames": 1, "loop": true},
	&"pull": {"frames": 24, "loop": true},
	&"push": {"frames": 24, "loop": true},
	&"grip_release": {"frames": 8, "loop": false},
}

static func frame_path(clip: StringName, index: int) -> String:
	return "res://assets/art/c_zone_debug/grip/%s/frame_%02d.svg" % [clip, index + 1]
