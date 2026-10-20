extends SceneTree

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const Level01SurfaceAudio = preload("res://scripts/audio/level01_surface_audio.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for bus_name in [&"Ambience", &"World", &"Character", &"Event"]:
		_assert(AudioServer.get_bus_index(bus_name) >= 0, "%s audio bus exists" % bus_name)

	var audio = Level01SurfaceAudio.new()
	root.add_child(audio)
	await process_frame

	audio.sync(
		0.5, true, Vector2(170.0, 371.0), Vector2.ZERO, true,
		ActorPoseState.ACTION_NONE, false, false, 0.0
	)
	_assert(audio.ambience_wind.playing, "surface wind loop is playing")
	_assert(audio.ambience_rain.playing, "surface rain loop is playing")
	_assert(audio.cliff_wind.playing, "cliff pressure loop is playing")
	_assert(audio.get_node_or_null("Campfire") == null, "campfire audio is absent")

	audio.sync(
		0.1, true, Vector2(220.0, 371.0), Vector2(285.0, 0.0), true,
		ActorPoseState.ACTION_NONE, false, false, 0.0
	)
	_assert(
		audio.footstep_players[0].playing or audio.footstep_players[1].playing,
		"ground movement triggers a footstep"
	)

	audio.sync(
		0.1, true, Vector2(220.0, 350.0), Vector2(0.0, -520.0), false,
		ActorPoseState.ACTION_NONE, false, false, 0.0
	)
	_assert(audio.jump_cloth.playing, "takeoff triggers cloth movement")
	audio.sync(
		0.1, true, Vector2(220.0, 350.0), Vector2(0.0, 430.0), false,
		ActorPoseState.ACTION_NONE, false, false, 0.0
	)
	audio.sync(
		0.1, true, Vector2(220.0, 371.0), Vector2.ZERO, true,
		ActorPoseState.ACTION_NONE, false, false, 0.0
	)
	_assert(audio.landing.playing, "landing transition triggers the landing sound")

	audio.wolf_time = 0.0
	audio.sync(
		0.1, true, Vector2(220.0, 371.0), Vector2.ZERO, true,
		ActorPoseState.ACTION_NONE, false, false, 0.0
	)
	_assert(audio.distant_wolf_howl.playing, "world ambience can trigger a distant wolf howl")

	audio.sync(
		0.1, true, Vector2(360.0, 371.0), Vector2.ZERO, true,
		ActorPoseState.ACTION_NONE, true, false, 0.10
	)
	_assert(audio.bat_wings.playing, "bat trigger starts wing movement")
	_assert(audio.bat_colony.playing, "bat trigger starts the colony layer")
	_assert(audio.grass_rustle.playing, "bat trigger starts the grass gust")
	audio.sync(
		0.2, true, Vector2(360.0, 371.0), Vector2.ZERO, true,
		ActorPoseState.ACTION_NONE, true, false, 0.32
	)
	_assert(audio.bat_whoosh.playing, "bat approach triggers the whoosh")
	audio.sync(
		0.5, true, Vector2(360.0, 371.0), Vector2.ZERO, true,
		ActorPoseState.ACTION_KNOCKDOWN, true, true, 0.82
	)
	_assert(audio.body_impact.playing, "knockdown triggers the body impact")
	audio.sync(
		0.1, true, Vector2(360.0, 371.0), Vector2.ZERO, true,
		ActorPoseState.ACTION_GET_UP, true, true, 3.50
	)
	_assert(audio.get_up_cloth.playing, "get-up transition triggers cloth movement")

	audio.deactivate()
	_assert(not audio.body_impact.playing, "deactivation stops active one-shots")
	_assert(audio.ambience_wind.volume_db <= -79.0, "deactivation mutes surface ambience")
	audio.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures.append(label)
		push_error("FAIL: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("Level 1-01 surface audio smoke test passed.")
		quit(0)
	else:
		quit(1)
