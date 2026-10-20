extends RefCounted

# Reviewed 8441 video, continuous 24 fps extraction; no per-clip resizing.
const ROOT := Vector2(192, 280)
const CANVAS := Vector2i(384, 320)
const CYCLE_DISTANCE := 73.5 # 14 frames at 24 fps when moving at 126 units/s.
const CLIPS := {
	&"grip_engage": {"folder": "push", "start": 0, "frames": 16, "loop": false},
	&"grip_hold": {"folder": "push", "start": 15, "frames": 1, "loop": true},
	&"push": {"folder": "push_step", "start": 0, "frames": 14, "loop": true},
	&"pull_enter": {"folder": "pull", "start": 0, "frames": 15, "loop": false},
	&"pull": {"folder": "pull_cycle", "start": 0, "frames": 14, "loop": true},
	&"grip_release": {"folder": "release", "start": 0, "frames": 14, "loop": false},
}

static func frame_path(clip: StringName, index: int) -> String:
	var entry: Dictionary = CLIPS[clip]
	return "res://assets/art/c_zone_debug/seedance_grip_8441/%s/frame_%03d.png" % [entry.folder, int(entry.start) + index]
