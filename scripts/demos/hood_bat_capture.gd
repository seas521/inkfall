extends SceneTree

# Windowed capture of the bat event with the hooded boy: godot --path . --script res://scripts/demos/hood_bat_capture.gd
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const MAIN_SCENE = preload("res://scenes/main.tscn")
const OUT := "/tmp/hood_bat"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await create_timer(0.6).timeout
	var controller = main.active_controller
	controller.player_position = Vector2(360.0, 371.0)
	controller.player_velocity = Vector2.ZERO
	main.game_context.on_ground = true
	var t := 0.0
	var shot := 0
	while t < 7.2:
		await create_timer(0.3).timeout
		t += 0.3
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s/%02d_%s.png" % [OUT, shot, controller.actor_action])
		shot += 1
	quit(0)
