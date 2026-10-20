extends SceneTree

const MAIN_SCENE = preload("res://scenes/main.tscn")
const Level01Controller = preload("res://scripts/levels/level_01_controller.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(5)
	var controller = main.active_controller
	controller._enter_shaft()
	_assert(
		controller.actor_action == ActorPoseState.ACTION_UNCONTROLLED_FALL,
		"entry starts the uncontrolled-fall clip"
	)
	var peak_fall_speed := 0.0
	var reached_impact := false
	for _frame_index in range(180):
		await physics_frame
		peak_fall_speed = maxf(peak_fall_speed, controller.player_velocity.y)
		if controller.shaft_entry_phase == Level01Controller.ShaftEntryPhase.IMPACT:
			reached_impact = true
			break
	_assert(reached_impact, "the branch pile catches the entry fall")
	_assert(peak_fall_speed <= 558.0, "entry fall speed stays cinematically capped")
	_assert(
		controller.actor_action == ActorPoseState.ACTION_FALL_IMPACT,
		"catch starts the fall-impact clip"
	)
	_assert(main.art_actor.pose.clip_flip_h, "entry impact keeps the fall-facing orientation")
	_assert(
		absf(controller.player_position.y + 54.0 - 620.0) <= 6.0,
		"actor lands on the branch-pile collision"
	)

	var recovered := false
	var saw_aligned_get_up := false
	for _frame_index in range(260):
		await physics_frame
		if controller.shaft_entry_phase == Level01Controller.ShaftEntryPhase.GET_UP:
			saw_aligned_get_up = (
				main.art_actor.pose.clip_flip_h
				and main.art_actor.pose.frame_root_offset.x >= 30.0
			)
		if controller.shaft_entry_phase == Level01Controller.ShaftEntryPhase.DONE:
			recovered = true
			break
	_assert(recovered, "impact chains through downed and get-up")
	_assert(saw_aligned_get_up, "get-up keeps the fall-facing orientation and the aligned recovery root")
	_assert(controller.player_facing < 0.0, "he stands up facing the way he fell")
	_assert(controller.actor_action == ActorPoseState.ACTION_NONE, "recovery restores locomotion")
	_assert(main.game_context.on_ground, "actor remains grounded after recovery")
	print("level01_shaft_entry_smoke: PASS")
	quit()

func _frames(count: int) -> void:
	for _frame_index in range(count):
		await physics_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("level01_shaft_entry_smoke: " + message)
	quit(1)
