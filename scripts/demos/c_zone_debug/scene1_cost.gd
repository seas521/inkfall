extends SceneTree

# Where a physics step of scene 1 goes (headless, CPU only): the whole step, then its parts, ms per call over 120 calls.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
var level

func _initialize() -> void:
	call_deferred("_run")

func _time(label: String, callable: Callable, calls := 120) -> void:
	var start := Time.get_ticks_usec()
	for i in calls:
		callable.call()
	print("COST %-34s %6.2f ms" % [label, (Time.get_ticks_usec() - start) / 1000.0 / calls])

func _run() -> void:
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 20:
		await physics_frame
	level.debug_enter_scene1()
	for i in 40:
		await physics_frame
	var stage := OS.get_environment("S1_STAGE") if OS.has_environment("S1_STAGE") else "lying"
	if stage == "walk":
		level.scene1.intro_time = 99.0
		Input.action_press("move_right")
		for i in 90:
			await physics_frame
	print("COST stage %s, x %.0f" % [stage, level.player.position.x])
	level.set_physics_process(false)
	var d := 1.0 / 60.0
	_time("whole _physics_process", func(): level._physics_process(d))
	_time("scene1.tick", func(): level.scene1.tick(d))
	_time("_present", func(): level._present(d))
	_time("art.sync", func(): level.art.sync(d, level.camera_x, true))
	_time("marsh_art.sync", func(): level.marsh_art.sync(d, level.camera_x, true))
	_time("hood actor sync_pose", func(): level.actor.sync_pose(d, level.pose))
	_time("_update_camera", func(): level._update_camera(d))
	_time("_update_player", func(): level._update_player(d, 0.0, 0.0))
	_time("_update_marsh_rocks", func(): level._update_marsh_rocks(d))
	_time("cliff.tick", func(): level.cliff.tick(d))
	_time("forest.tick", func(): level.forest.tick(d))
	Input.action_release("move_right")
	quit()
