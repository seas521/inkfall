extends SceneTree

# Windowed capture: the water a few moments after a hit (frozen frames).
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD  # the hooded boy (scripts keep the old actor unless told)
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 10:
		await physics_frame
		await process_frame
	var art = level.art
	level.player.position = Vector2(1330.0, 480.0)
	level.player.velocity = Vector2.ZERO
	level.set_physics_process(false)
	level.camera_x = 1500.0 - 640.0
	level.camera.position = Vector2(1500.0, 360.0)
	art.reset_water_impacts()
	art.emit_water_impact(1520.0, 330.0, 26.0)
	var stamps := [0.0, 0.12, 0.3, 0.6, 1.0, 1.6]
	var now := 0.0
	for stamp in stamps:
		while now < stamp - 0.001:
			art.clock += 1.0 / 60.0
			art._update_waves(1.0 / 60.0)
			for k in range(art.water_impacts.size()):
				art.water_impacts[k].age += 1.0 / 60.0
			now += 1.0 / 60.0
		level._present(0.0)
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		DirAccess.make_dir_recursive_absolute("res://artifacts/c-zone-water")
		var image := root.get_texture().get_image()
		image.save_png("res://artifacts/c-zone-water/hit_%03d.png" % int(stamp * 100.0))
	quit(0)
