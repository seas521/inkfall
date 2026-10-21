extends SceneTree

# The hooded boy jumps onto the floating boat (headless): how the boat and the water react, every 0.25 s.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
var level

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	ActorStyleHost.style_override = ActorPoseState.STYLE_HOOD
	level = SCENE.instantiate()
	root.add_child(level)
	for i in 20:
		await physics_frame
	level.floating = true
	level.crate.position = Vector2(1500.0, level.CRATE_START.y)
	level.crate.velocity = Vector2.ZERO
	level.player.position = level.crate.position + Vector2(66.0, -150.0)
	level.player.velocity = Vector2.ZERO
	for i in 120:
		await physics_frame
	var art = level.art
	var rows := PackedStringArray()
	var peak_all := 0.0
	var landed := false
	for i in 300:
		await physics_frame
		await process_frame
		var peak := 0.0
		for h in art.wave_h:
			peak = maxf(peak, absf(h))
		peak_all = maxf(peak_all, peak)
		if i % 15 == 0:
			rows.append("t=%.2f swell %.1f tilt %.2f deg crate_y %.1f rider_feet_off %.1f riding %s" % [i / 60.0, peak, rad_to_deg(level.crate_tilt), level.crate.position.y, (level.player.position.y + 54.0) - (level.crate.position.y), level.is_riding()])
	for r in rows:
		print(r)
	print("peak swell %.1f px" % peak_all)
	ActorStyleHost.style_override = &""
	quit()
