extends SceneTree

# The first level's entry fall into the shaft, from the drop to standing up, as a strip of frames.
const MAIN_SCENE = preload("res://scenes/main.tscn")
const Level01Controller = preload("res://scripts/levels/level_01_controller.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main = MAIN_SCENE.instantiate()
	root.add_child(main)
	await _frames(5)
	var controller = main.active_controller
	controller._enter_shaft()
	var shot := 0
	var last_phase := -1
	for frame in range(900):
		await physics_frame
		await process_frame
		var phase: int = controller.shaft_entry_phase
		var every := 10 if phase >= Level01Controller.ShaftEntryPhase.IMPACT else 25
		if frame % every == 0 or phase != last_phase:
			RenderingServer.force_draw()
			DirAccess.make_dir_recursive_absolute("res://artifacts/level01/entry")
			root.get_texture().get_image().save_png("res://artifacts/level01/entry/%03d-p%d.png" % [shot, phase])
			print(shot, " phase=", phase, " pos=", controller.player_position, " facing=", controller.player_facing, " flip=", main.art_actor.pose.clip_flip_h)
			shot += 1
		last_phase = phase
		if phase == Level01Controller.ShaftEntryPhase.DONE and frame > 30:
			if shot > 40:
				break
	quit(0)

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
