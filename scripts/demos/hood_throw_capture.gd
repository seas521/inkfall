extends SceneTree

# Windowed capture: pick a stone up, wind up, throw, then pick up and put down.  /tmp/hood_throw/NN_<action>.png
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const MAIN_SCENE = preload("res://scenes/main.tscn")
const OUT := "/tmp/hood_throw"
var shot := 0
var controller

func _initialize() -> void:
	call_deferred("_run")

func _snap(tag: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	image.save_png("%s/%02d_%s_%s.png" % [OUT, shot, tag, controller.actor_action])
	shot += 1

func _wait_snaps(seconds: float, step: float, tag: String) -> void:
	var t := 0.0
	while t < seconds:
		await create_timer(step).timeout
		t += step
		_snap(tag)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	controller = main.active_controller
	controller.debug_enter_cavern_demo()
	await create_timer(0.5).timeout
	controller.player_position = Vector2(328.0, 440.0)
	controller.player_velocity = Vector2.ZERO
	controller.player_facing = 1.0
	await create_timer(0.6).timeout
	_snap("before")
	Input.action_press("interact")
	await create_timer(0.1).timeout
	Input.action_release("interact")
	await _wait_snaps(1.4, 0.1, "pick")
	Input.action_press("interact")
	await _wait_snaps(0.8, 0.1, "charge")
	Input.action_release("interact")
	await _wait_snaps(1.4, 0.1, "throw")
	quit(0)
