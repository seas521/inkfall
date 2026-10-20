extends SceneTree

const LAB = preload("res://scenes/prototypes/gpt6_hood_motion_lab.tscn")
const OUTPUT := "res://artifacts/gpt6_motion"
var lab
var failures: Array[String] = []
var capture := false
var captures: Array[String] = []
var max_height := 0.0
var stance_drift := 0.0
var previous_contacts: Dictionary = {}
var bone_names: Array[String] = []
var max_leg_error := 0.0
var worst_leg: Dictionary = {}
var walk_samples := 0
var walk_knee_total := 0.0
var walk_knee_max := 0.0
var walk_lean_max := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	capture = OS.get_environment("GPT6_CAPTURE") == "1"
	OS.set_environment("GPT6_TEST", "1")
	if capture:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	lab = LAB.instantiate()
	root.add_child(lab)
	await process_frame
	_check(lab.ready_for_test, "Lab did not initialize")
	_check(lab.rig.skeleton.get_bone_count() == 20, "Unexpected skeleton")
	for index in lab.rig.skeleton.get_bone_count():
		bone_names.append(lab.rig.skeleton.get_bone_name(index))
	print("GPT6 skeleton rest: ", lab.rig.skeleton.get_bone_global_rest(lab.rig.bones["Pelvis"]))
	var samples := [0.8, 2.25, 2.45, 2.65, 2.85, 3.05, 3.25, 4.6, 6.05, 6.82, 7.6, 8.82, 9.28, 9.5, 17.15, 23.4]
	var sample_index := 0
	while lab.demo_time < 24.8:
		await process_frame
		max_height = maxf(max_height, lab.body.position.y)
		_check(lab.body.position.is_finite(), "Non-finite player position")
		_check(absf(lab.body.position.z) < 0.001, "Player left the side-scrolling plane")
		_check(lab.body.position.y >= -0.015, "Player penetrated the floor")
		for name in lab.rig.solved:
			var pose: Transform3D = lab.rig.solved[name]
			_check(pose.origin.is_finite(), "Non-finite bone " + str(name))
		if lab.demo_time >= samples[mini(sample_index, samples.size() - 1)] and sample_index < samples.size():
			if capture:
				await _capture("pose_%02d_%s" % [sample_index, lab.rig.state_name.to_lower()])
			sample_index += 1
		_measure_contacts()
		if lab.demo_time > 2.2 and lab.demo_time < 3.7:
			var chest: Transform3D = lab.rig.solved["Chest"]
			var neck: Transform3D = lab.rig.solved["Head"]
			var torso := neck.origin - chest.origin
			walk_lean_max = maxf(walk_lean_max, absf(rad_to_deg(atan2(torso.x, torso.y))))
			for index in 2:
				if lab.rig.feet[index].contact:
					var side := "Near" if index == 0 else "Far"
					var hip: Vector3 = lab.rig.solved["Thigh" + side].origin
					var knee: Vector3 = lab.rig.solved["Shin" + side].origin
					var ankle: Vector3 = lab.rig.solved["Foot" + side].origin
					var angle := rad_to_deg(PI - (hip - knee).angle_to(ankle - knee))
					walk_knee_total += angle
					walk_knee_max = maxf(walk_knee_max, angle)
					walk_samples += 1
		for side in ["Near", "Far"]:
			var ankle: Vector3 = lab.rig.joints[side + "Ankle"]
			var knee: Vector3 = lab.rig.joints[side + "Knee"]
			var error := absf(ankle.distance_to(knee) - lab.rig.LEG_LOWER)
			if error > max_leg_error:
				max_leg_error = error
				worst_leg = {"time": lab.demo_time, "side": side, "body": str(lab.body.position),
					"ankle": str(ankle), "knee": str(knee), "feet": lab.rig.feet.duplicate(true)}
	var coverage: Dictionary = lab.observed_states.duplicate()
	for state in ["IDLE", "WALK", "RUN", "BRAKE", "TURN", "RISE", "FALL", "LAND"]:
		_check(coverage.has(state), "Demo did not exercise " + state)
	_check(max_height > 0.7 and max_height < 1.15, "Unexpected jump height: %s" % max_height)
	_check(stance_drift < 0.01, "Planted ankle drift: %s" % stance_drift)
	_check(max_leg_error < 0.015, "Leg stretched beyond the rig: %s" % max_leg_error)
	_check(walk_samples > 60, "Insufficient walking posture samples")
	_check(walk_knee_total / maxi(1, walk_samples) < 11.0, "Walking support leg remains crouched")
	_check(walk_lean_max < 1.0, "Steady walking torso leans forward")

	lab.set_auto_mode(false)
	lab.manual_override = {"direction": 1.0, "walk": false, "jump": false, "held": true}
	for frame in 35:
		await physics_frame
	_check(lab.body.velocity.x > 2.5, "Manual right input failed")
	lab.manual_override.direction = -1.0
	for frame in 45:
		await physics_frame
	_check(lab.body.velocity.x < -2.5, "Manual reversal failed")
	lab.manual_override = {"direction": 0.0, "walk": false, "jump": false, "held": false}
	for frame in 40:
		await physics_frame
	_check(absf(lab.body.velocity.x) < 0.01, "Braking did not stop")

	var short_jump := await _jump_peak(false)
	var long_jump := await _jump_peak(true)
	_check(long_jump > short_jump + 0.3, "Jump release does not affect height")
	lab.paused = true
	var before: Vector3 = lab.body.position
	for frame in 8:
		await physics_frame
	_check(before.is_equal_approx(lab.body.position), "Pause moved the player")
	lab.paused = false
	lab.playback_speed = 0.5
	for frame in 4:
		await physics_frame
	_check(is_equal_approx(Engine.time_scale, 0.5), "Slow playback did not activate")
	lab.playback_speed = 1.0
	lab.reset_demo()
	_check(lab.body.position.x == -3.0 and lab.demo_time == 0.0, "Reset failed")

	if capture:
		await process_frame
		await process_frame
		lab.paused = true
		for size in [Vector2i(960, 540), Vector2i(800, 600)]:
			DisplayServer.window_set_size(size)
			root.size = size
			await process_frame
			await process_frame
			await _capture("viewport_%dx%d" % [size.x, size.y])
	var report := {
		"passed": failures.is_empty(),
		"failures": failures, "states": coverage.keys(), "bones": bone_names,
		"max_jump_height": max_height, "short_jump": short_jump, "long_jump": long_jump,
		"max_stance_drift": stance_drift, "screenshots": captures,
		"max_leg_error": max_leg_error,
		"worst_leg": worst_leg,
		"walk_stance_knee_mean_deg": walk_knee_total / maxi(1, walk_samples),
		"walk_stance_knee_max_deg": walk_knee_max,
		"walk_torso_lean_max_deg": walk_lean_max,
	}
	var file := FileAccess.open(OUTPUT + "/verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("GPT6 VERIFICATION: ", JSON.stringify(report))
	lab.queue_free()
	await process_frame
	_check(is_equal_approx(Engine.time_scale, 1.0), "Time scale leaked after scene exit")
	quit(0 if failures.is_empty() else 1)


func _measure_contacts() -> void:
	var rig = lab.rig
	var turning: bool = absf(angle_difference(rig.rotation.y, 0.0 if rig.facing > 0.0 else PI)) > 0.04
	for index in 2:
		var side := "Near" if index == 0 else "Far"
		var foot: Dictionary = rig.feet[index]
		var planted: bool = foot.contact and lab.body.is_on_floor() and not turning
		var bone_index: int = rig.bones["Foot" + side]
		var actual: Vector3 = rig.skeleton.to_global(rig.skeleton.get_bone_global_pose(bone_index).origin)
		if planted and previous_contacts.has(side):
			var previous: Dictionary = previous_contacts[side]
			if previous.planted and is_equal_approx(previous.anchor, foot.anchor):
				stance_drift = maxf(stance_drift, absf(actual.x - float(previous.x)))
		previous_contacts[side] = {"planted": planted, "anchor": foot.anchor, "x": actual.x}


func _jump_peak(held: bool) -> float:
	lab.manual_override = {"direction": 0.0, "walk": false, "jump": true, "held": true}
	await physics_frame
	await physics_frame
	lab.manual_override.jump = false
	lab.manual_override.held = held
	var peak := 0.0
	for frame in 85:
		await physics_frame
		peak = maxf(peak, lab.body.position.y)
	return peak


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_check(image != null and not image.is_empty(), "Empty screenshot: " + name)
	if root.use_hdr_2d:
		image.convert(Image.FORMAT_RGB8)
		image.linear_to_srgb()
	var actual_name := name
	if name.begins_with("viewport_"):
		actual_name = "viewport_%dx%d" % [image.get_width(), image.get_height()]
	var path := OUTPUT + "/" + actual_name + ".png"
	image.save_png(ProjectSettings.globalize_path(path))
	captures.append(path)
	var ink_pixels := 0
	var image_size := image.get_size()
	for y in range(int(image_size.y * 0.18), int(image_size.y * 0.70), 3):
		for x in range(int(image_size.x * 0.2), int(image_size.x * 0.8), 3):
			var color := image.get_pixel(x, y)
			if color.r < 0.09 and color.g < 0.09 and color.b < 0.09:
				ink_pixels += 1
	_check(ink_pixels > 50, "Character missing from rendered viewport: " + name)
