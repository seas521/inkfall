extends SceneTree

# Compare the same source frame after each real scene's presentation path.
# A running / crouching silhouette naturally has a different bounding box.
const SCENE = preload("res://scenes/debug/c_zone_river.tscn")
const Pose = preload("res://scripts/actors/actor_pose_state.gd")
var level
var failures := 0
var baseline := Vector2.ZERO

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok:
		failures += 1

func _measure(label: String) -> void:
	level._present(0.0)
	var actor = level.actor
	_check(is_equal_approx(actor.pose.visual_scale, Pose.HOOD_VISUAL_SCALE), label+": shared gameplay scale")
	_check(level.camera.zoom.is_equal_approx(Vector2.ONE), label+": camera at 1:1")
	# Remove breathing phase and action posture from the comparison.
	actor.breath_ramp = 0.0
	actor.squash = 1.0
	actor.play(&"idle_left", 0)
	actor._apply()
	level.camera.force_update_scroll()
	var transform: Transform2D = actor.sprite.get_global_transform_with_canvas()
	var size: Vector2 = actor.sprite.texture.get_size()
	var projected := Vector2(transform.x.length()*size.x,transform.y.length()*size.y)
	if baseline == Vector2.ZERO:
		baseline = projected
	_check(projected.is_equal_approx(baseline), "%s: same standing frame %.3f × %.3f logical pixels" % [label,projected.x,projected.y])

func _run() -> void:
	level = SCENE.instantiate()
	root.add_child(level)
	await process_frame
	level.set_physics_process(false)
	_measure("C river")
	level.debug_enter_marsh_act()
	_measure("C marsh")
	level.debug_enter_cliff_act()
	_measure("C bridge and lift")
	level.debug_enter_forest_act()
	_measure("C forest")
	level.debug_enter_scene1()
	_measure("giant pursuit")
	level.debug_enter_log_bridge()
	_measure("log bridge")
	_check(is_equal_approx(Pose.new().visual_scale,Pose.HOOD_VISUAL_SCALE),"new pose uses the common scale by default")
	var pose = Pose.new()
	pose.apply({})
	_check(is_equal_approx(pose.visual_scale,Pose.HOOD_VISUAL_SCALE),"omitted scene scale falls back to the common size")
	print("actor scale smoke OK" if failures == 0 else "actor scale smoke: %d FAILED" % failures)
	quit(0 if failures == 0 else 1)
