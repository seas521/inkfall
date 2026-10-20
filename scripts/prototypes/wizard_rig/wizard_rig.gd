extends Node2D

# Cut-out puppet of the wizard apprentice. A pose is a dictionary of joint angles in degrees using
# a "forward" convention (positive = towards the direction the character faces), which the rig turns
# into node rotations. Poses are never applied directly: they are the *target* the joints ease to,
# which is what makes switching between actions continuous instead of a hard cut.

const Defs = preload("res://scripts/prototypes/wizard_rig/wizard_rig_defs.gd")
const MASTER: Texture2D = preload("res://assets/art/prototypes/wizard_rig/wizard_master.png")

const JOINTS: Array[StringName] = [
	&"spine", &"head",
	&"arm_far_up", &"arm_far_fore", &"arm_near_up", &"arm_near_fore",
	&"thigh_far", &"shin_far", &"foot_far", &"thigh_near", &"shin_near", &"foot_near",
	&"pelvis_rot", &"pelvis_dx", &"pelvis_dy",
]
# How quickly each joint follows its target (1/s). Hands and head trail the body a little.
const FOLLOW := {
	&"spine": 16.0, &"head": 13.0, &"arm_far_up": 18.0, &"arm_far_fore": 14.0, &"arm_near_up": 18.0,
	&"arm_near_fore": 14.0, &"thigh_far": 24.0, &"shin_far": 24.0, &"foot_far": 22.0,
	&"thigh_near": 24.0, &"shin_near": 24.0, &"foot_near": 22.0,
	&"pelvis_rot": 14.0, &"pelvis_dx": 20.0, &"pelvis_dy": 26.0,
}

@export var rig_scale := 0.2

var nodes: Dictionary = {}
var rest: Dictionary = {}
var pivots: Dictionary = {}
var parent_of: Dictionary = {}
var current: Dictionary = {}
var target: Dictionary = {}
# Secondary motion: damped springs that lag behind the body (angle, velocity).
var tip_spring := Vector2.ZERO
var skirt_spring := Vector2.ZERO
var facing := 1.0
var flip := 1.0
var clock := 0.0
var pelvis_base := Vector2.ZERO

func _ready() -> void:
	scale = Vector2(rig_scale, rig_scale)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for joint in JOINTS:
		current[joint] = 0.0
		target[joint] = 0.0
	var holder := Node2D.new()
	holder.name = "Body"
	add_child(holder)
	for part in Defs.build():
		var name: String = part.name
		pivots[name] = part.pivot * Defs.K
		parent_of[name] = part.parent
		rest[name] = float(part.get("rest", 0.0))
		var node: Node2D
		if part.has("poly"):
			var poly_node := Polygon2D.new()
			var points := PackedVector2Array()
			for p in part.poly as PackedVector2Array:
				points.append(p * Defs.K)
			poly_node.polygon = points
			poly_node.uv = points
			poly_node.texture = MASTER
			poly_node.offset = -(part.pivot * Defs.K)
			poly_node.z_index = int(part.z)
			poly_node.z_as_relative = false
			node = poly_node
		else:
			node = Node2D.new()
		nodes[name] = node
		var parent_node: Node = holder if part.parent == "" else nodes[part.parent]
		parent_node.add_child(node)
		if part.parent == "":
			pelvis_base = Vector2(0.0, -(Defs.FEET_Y - part.pivot.y) * Defs.K)
			node.position = pelvis_base
		else:
			node.position = (part.pivot - _pivot_display(part.parent)) * Defs.K
	apply()

func _pivot_display(name: String) -> Vector2:
	return (pivots[name] as Vector2) / Defs.K

func set_target(pose: Dictionary) -> void:
	for joint in JOINTS:
		target[joint] = float(pose.get(joint, 0.0))

# Eases every joint towards its target; `snap` jumps straight there.
func step(delta: float, snap := false) -> void:
	clock += delta
	for joint in JOINTS:
		var follow: float = float(FOLLOW.get(joint, 16.0))
		current[joint] = float(target[joint]) if snap else lerpf(float(current[joint]), float(target[joint]), 1.0 - exp(-follow * delta))

# Drives the hat tip and the robe hem. `drive_*` is how hard the body is pushing them backwards
# (speed along the facing direction) and upwards (vertical speed), in rig-scale-free units.
func step_springs(delta: float, drive_back: float, drive_up: float, body_spin: float) -> void:
	var tip_goal := clampf(drive_back * 0.075 + drive_up * 0.045 + body_spin * 0.35 + sin(clock * 1.7) * 1.2, -40.0, 55.0)
	tip_spring = _spring(tip_spring, tip_goal, 85.0, 6.2, delta)
	var skirt_goal := clampf(drive_back * 0.032 + drive_up * 0.02 + sin(clock * 1.3 + 1.0) * 0.8, -18.0, 26.0)
	skirt_spring = _spring(skirt_spring, skirt_goal, 70.0, 7.0, delta)

func _spring(state: Vector2, goal: float, stiffness: float, damping: float, delta: float) -> Vector2:
	var acceleration := stiffness * (goal - state.x) - damping * state.y
	var velocity := state.y + acceleration * delta
	return Vector2(state.x + velocity * delta, velocity)

func apply() -> void:
	scale = Vector2(rig_scale * flip * facing, rig_scale)
	var pelvis: Node2D = nodes["pelvis"]
	pelvis.position = pelvis_base + Vector2(float(current[&"pelvis_dx"]), float(current[&"pelvis_dy"])) / rig_scale
	pelvis.rotation = deg_to_rad(float(current[&"pelvis_rot"]))
	_rotate("torso", float(current[&"spine"]))
	_rotate("head", float(current[&"head"]))
	_rotate("hat_tip", -tip_spring.x)
	_rotate("skirt", skirt_spring.x)
	for side in ["far", "near"]:
		_rotate_limb("arm_%s_up" % side, float(current[StringName("arm_%s_up" % side)]))
		_rotate_limb("arm_%s_fore" % side, float(current[StringName("arm_%s_fore" % side)]))
		_rotate_limb("thigh_" + side, float(current[StringName("thigh_" + side)]))
		_rotate("shin_" + side, float(current[StringName("shin_" + side)]))
		_rotate("foot_" + side, float(current[StringName("foot_" + side)]))

func _rotate(name: String, degrees: float) -> void:
	(nodes[name] as Node2D).rotation = deg_to_rad(degrees)

# Limbs hang straight down at 0 and swing forward for positive values.
func _rotate_limb(name: String, forward: float) -> void:
	(nodes[name] as Node2D).rotation = deg_to_rad(float(rest[name]) - forward)
