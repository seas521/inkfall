extends RefCounted

const CLIP: StringName = &"fan_swing"
const Data = preload("res://scripts/demos/c_zone_debug/fan_swing_seedance_data.gd")
const COUNT := Data.COUNT
const DURATION := Data.DURATION
const COOLDOWN := DURATION + 0.08
const ROOT := Vector2(128, 232)
const HANDS := Data.HANDS

static func frame_path(index: int) -> String:
	return "res://assets/art/c_zone_debug/fan_swing_seedance_8496/frame_%03d.png" % index

static func angle(index: int) -> float:
	return deg_to_rad(Data.ANGLES[clampi(index,0,COUNT-1)])

static func frame_at(progress: float) -> int:
	var time := clampf(progress,0.0,1.0) * DURATION
	for i in COUNT:
		if time < Data.ENDS[i]:
			return i
	return COUNT - 1

static func frame_progress(index: int) -> float:
	var start: float = Data.ENDS[index-1] if index > 0 else 0.0
	return (start + Data.ENDS[index]) * 0.5 / DURATION
