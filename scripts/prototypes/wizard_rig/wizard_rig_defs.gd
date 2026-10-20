extends RefCounted

# Cut-out definition of the wizard apprentice, measured on the AI rig-pose sheet.
# All numbers below are in the coordinates of the 768x1024 preview of the 864x1152 master, so
# K converts them to master pixels. Parts overlap at the joints (all pure black, so overlap is
# invisible at rest and hides the gap when a joint rotates).

const K := 1.125
const FEET_Y := 885.0
const CENTER_X := 390.0

# name -> {parent, pivot, rest, z, poly}
# `rest` is the angle (degrees, "forward" convention) that makes the part hang straight down.
static func build() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	parts.append({"name": "pelvis", "parent": "", "pivot": Vector2(390, 640), "z": 0})

	# --- legs -------------------------------------------------------------------------------
	for side in ["far", "near"]:
		var hip: Vector2 = Vector2(360, 705) if side == "far" else Vector2(420, 705)
		var knee: Vector2 = Vector2(358, 782) if side == "far" else Vector2(421, 780)
		var ankle: Vector2 = Vector2(358, 848) if side == "far" else Vector2(426, 845)
		var x0: float = 322.0 if side == "far" else 398.0
		var x1: float = 392.0 if side == "far" else 452.0
		var foot_x0: float = 318.0 if side == "far" else 400.0
		var foot_x1: float = 408.0 if side == "far" else 505.0
		var z: int = 1 if side == "far" else 2
		parts.append({"name": "thigh_" + side, "parent": "pelvis", "pivot": hip, "z": z,
			"poly": _rect(x0, 690.0, x1, knee.y + 8.0)})
		parts.append({"name": "shin_" + side, "parent": "thigh_" + side, "pivot": knee, "z": z,
			"poly": _rect(x0, knee.y - 8.0, x1, ankle.y + 6.0)})
		parts.append({"name": "foot_" + side, "parent": "shin_" + side, "pivot": ankle, "z": z,
			"poly": _rect(foot_x0, ankle.y - 6.0, foot_x1, 895.0)})

	# --- torso, robe -------------------------------------------------------------------------
	parts.append({"name": "torso", "parent": "pelvis", "pivot": Vector2(390, 600), "z": 3,
		"poly": _rect(296.0, 318.0, 474.0, 604.0)})
	parts.append({"name": "skirt", "parent": "pelvis", "pivot": Vector2(390, 548), "z": 4,
		"poly": _rect(262.0, 540.0, 510.0, 742.0)})

	# --- head, hat ---------------------------------------------------------------------------
	parts.append({"name": "head", "parent": "torso", "pivot": Vector2(385, 336), "z": 5,
		"poly": PackedVector2Array([Vector2(305, 80), Vector2(545, 80), Vector2(545, 352),
			Vector2(236, 352), Vector2(236, 246), Vector2(298, 246)])})
	parts.append({"name": "hat_tip", "parent": "head", "pivot": Vector2(302, 165), "z": 6,
		"poly": PackedVector2Array([Vector2(185, 80), Vector2(314, 80), Vector2(322, 130),
			Vector2(308, 205), Vector2(300, 252), Vector2(185, 252)])})

	# --- arms: a whole-arm outline, then split at the elbow ---------------------------------------
	var far_arm := PackedVector2Array([Vector2(354, 378), Vector2(335, 384), Vector2(300, 430),
		Vector2(250, 490), Vector2(226, 522), Vector2(200, 556), Vector2(196, 592),
		Vector2(214, 612), Vector2(272, 612), Vector2(306, 602), Vector2(338, 545),
		Vector2(354, 472)])
	var near_arm := PackedVector2Array([Vector2(436, 368), Vector2(458, 376), Vector2(500, 436),
		Vector2(536, 508), Vector2(562, 520), Vector2(580, 552), Vector2(566, 592),
		Vector2(520, 596), Vector2(494, 590), Vector2(470, 560), Vector2(442, 470)])
	_add_arm(parts, "far", far_arm, Vector2(350, 398), Vector2(292, 482), Vector2(222, 585), 0)
	_add_arm(parts, "near", near_arm, Vector2(438, 392), Vector2(487, 472), Vector2(548, 570), 7)
	return parts

static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

static func _add_arm(parts: Array[Dictionary], side: String, outline: PackedVector2Array, shoulder: Vector2, elbow: Vector2, hand: Vector2, z: int) -> void:
	var axis := (hand - shoulder).normalized()
	var perp := Vector2(-axis.y, axis.x)
	var big := 400.0
	# Upper arm: everything on the shoulder side of the elbow line, with 8px overlap past it.
	var cut_a := elbow + axis * 8.0
	var upper_half := PackedVector2Array([cut_a + perp * big, cut_a + perp * big - axis * big * 2.0,
		cut_a - perp * big - axis * big * 2.0, cut_a - perp * big])
	var cut_b := elbow - axis * 8.0
	var lower_half := PackedVector2Array([cut_b + perp * big, cut_b + perp * big + axis * big * 2.0,
		cut_b - perp * big + axis * big * 2.0, cut_b - perp * big])
	var upper := _first(Geometry2D.intersect_polygons(outline, upper_half))
	var lower := _first(Geometry2D.intersect_polygons(outline, lower_half))
	# `rest`: the angle that turns the A-pose arm so it hangs straight down.
	var rest := rad_to_deg(atan2(hand.x - shoulder.x, hand.y - shoulder.y))
	parts.append({"name": "arm_%s_up" % side, "parent": "torso", "pivot": shoulder, "z": z, "poly": upper, "rest": rest})
	parts.append({"name": "arm_%s_fore" % side, "parent": "arm_%s_up" % side, "pivot": elbow, "z": z, "poly": lower, "rest": 0.0})

static func _first(polys: Array[PackedVector2Array]) -> PackedVector2Array:
	if polys.is_empty():
		return PackedVector2Array()
	var best := polys[0]
	for p in polys:
		if p.size() > best.size():
			best = p
	return best
