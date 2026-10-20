extends SceneTree

# Windowed capture of the shaft entry (fall -> impact -> lying -> get up) with the hooded boy: /tmp/hood_shaft/NN_<phase>_<action>.png
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const MAIN_SCENE = preload("res://scenes/main.tscn")
const OUT := "/tmp/hood_shaft"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	var controller = main.active_controller
	controller._enter_shaft()
	var shot := 0
	var t := 0.0
	while t < 9.0:
		await create_timer(0.2).timeout
		t += 0.2
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("%s/%02d_p%d_%s.png" % [OUT, shot, controller.shaft_entry_phase, controller.actor_action])
		print(shot, " phase=", controller.shaft_entry_phase, " action=", controller.actor_action, " clip=", main.art_actor.hood_actor.current_clip, " pos=", controller.player_position)
		shot += 1
	quit(0)
