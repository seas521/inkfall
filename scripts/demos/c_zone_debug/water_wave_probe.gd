extends SceneTree

# Water swell numbers (headless): a hit, the raft's wake and a drowning stroke; prints the swell height (px) over time.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _peak() -> float:
	var m := 0.0
	for h in level.art.wave_h:
		m = maxf(m, absf(h))
	return m

func _series(label: String, seconds: float, driver: Callable = Callable()) -> void:
	await physics_frame
	var out := label + ":"
	var frames := int(seconds * 60.0)
	for i in frames:
		if driver.is_valid():
			driver.call(1.0 / 60.0)
		await physics_frame
		await process_frame
		if i % 15 == 14:
			out += " %.1f" % _peak()
	print(out)

func _run() -> void:
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD  # the hooded boy (scripts keep the old actor unless told)
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 20:
		await physics_frame
	var art = level.art
	art.emit_water_impact(1600.0, 120.0, 26.0)
	await _series("raft lands (slow)  t=.25 s steps", 4.0)
	art._clear_waves()
	art.emit_water_impact(1600.0, 380.0, 26.0)
	await _series("raft lands (fast)", 4.0)
	art._clear_waves()
	art.emit_water_impact(1500.0, 300.0, 16.0)
	await _series("boy falls in", 4.0)
	art._clear_waves()
	var xs := [1500.0]
	await _series("raft moving 80 px/s for 3 s then stops", 5.0, func(d):
		if xs[0] < 1740.0:
			xs[0] += 80.0 * d
			art.raft_waves(xs[0], 70.0, 80.0, 0.0, 0.0, d))
	art._clear_waves()
	art.emit_struggle_splash(1500.0, 1.0)
	await _series("one drowning stroke", 3.0)
	quit()
