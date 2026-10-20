extends RefCounted

const CLIP: StringName = &"water_drown"
const COUNT := 8
const ROOT := Vector2(128,232)
const DURATION := 2.70
const STRUGGLE := 1.70
const PADDLE := [0,1,0,2,0,3,0,1]

static func frame_path(index: int) -> String:
	return "res://assets/art/c_zone_debug/drown_v1/frame_%02d.png" % index

static func frame_at(progress: float) -> int:
	var time := progress * DURATION
	if time < STRUGGLE:
		return PADDLE[mini(int(time / STRUGGLE * PADDLE.size()),PADDLE.size()-1)]
	return [5,4,6,7][clampi(int((time-STRUGGLE)/(DURATION-STRUGGLE)*4),0,3)]
