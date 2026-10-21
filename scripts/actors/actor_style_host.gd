extends Node2D

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const HoodFrameActor = preload("res://scripts/actors/hood_frame_actor.gd")

# Every controller that asks for "the player" gets the hooded boy: he is the only character. (The earlier characters, the
# crooked-tower knight and the witch, are gone, and so is the switch between looks.)
var pose = ActorPoseState.new()
var hood_actor: Node2D
var hood_zone := "level1"

func _ready() -> void:
	hood_actor = HoodFrameActor.new()
	add_child(hood_actor)
	hood_actor.hide()

func present(delta: float, state: Dictionary) -> void:
	pose.apply(state)
	pose.style_id = ActorPoseState.STYLE_HOOD
	visible = pose.active
	if not pose.active:
		hood_actor.hide()
		return
	hood_actor.call("load_zone", hood_zone)
	hood_actor.call("sync_pose", delta, pose)
