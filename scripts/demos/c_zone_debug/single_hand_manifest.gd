extends RefCounted

const Source = preload("res://scripts/actors/seedance_actor_manifest.gd")
const FRAME_ROOT := "res://assets/art/c_zone_debug/single_hand_v1"
const CLIPS: Array[StringName] = [&"carry", &"carry_run", &"carry_takeoff", &"carry_rise", &"carry_apex", &"carry_fall", &"carry_land", &"pickup", &"put_down"]
const ARM_ROOT := Vector2(132, 167)
const GRIP_POINT := Vector2(167, 178)

static func frame_path(clip: StringName, index: int) -> String:
	return "%s/%s/frame_%02d.png" % [FRAME_ROOT, clip, index]

static func arm_transform(clip: StringName, index: int) -> Transform2D:
	if clip == &"put_down":
		clip = &"pickup"
		index = 7-index
	var marker: Vector2 = Source.small_item_anchor(clip,index)-Source.SMALL_ITEM_CENTER_OFFSET
	var origin := marker+Vector2(-27,-7)
	var angle := 0.0
	if clip == &"pickup":
		var origins := [Vector2(122,160),Vector2(125,167),Vector2(124,177),Vector2(123,180),Vector2(122,180),Vector2(122,175),Vector2(128,164),Vector2(130,158)]
		var angles := [0.62,0.58,0.48,0.44,0.40,0.28,0.08,0.0]
		origin = origins[index]
		angle = angles[index]
	return Transform2D(angle,origin)

static func hand_anchor(clip: StringName, index: int) -> Vector2:
	return arm_transform(clip,index)*(GRIP_POINT-ARM_ROOT)
