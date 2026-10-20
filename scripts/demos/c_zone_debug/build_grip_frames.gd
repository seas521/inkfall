extends "res://scripts/tools/build_crooked_tower_vector_frames.gd"

const Grip = preload("res://scripts/demos/c_zone_debug/grip_manifest.gd")

func _build() -> void:
	for clip: StringName in Grip.CLIPS:
		var metadata: Dictionary = Grip.CLIPS[clip]
		var keys: Array
		match clip:
			&"grip_engage": keys = [_p(), _grip_pose(0.0), _grip_pose(0.0)]
			&"grip_hold": keys = [_grip_pose(0.0)]
			&"grip_release": keys = [_grip_pose(0.0), _p()]
			_:
				keys = []
				for i in range(8):
					keys.append(_grip_pose(float(i) * TAU / 8.0, clip == &"pull", true))
		var frames := _bake(keys, int(metadata.frames), bool(metadata.loop))
		DirAccess.make_dir_recursive_absolute(Grip.frame_path(clip, 0).get_base_dir())
		for i in frames.size():
			var file := FileAccess.open(Grip.frame_path(clip, i), FileAccess.WRITE)
			if file == null:
				push_error("Cannot write grip frame")
				quit(1)
				return
			file.store_string(_svg_for_pose(frames[i], &"none", clip, i))
		print("Built C river placeholder: ", clip)
	quit()

func _grip_pose(phase: float, pulling := false, moving := false) -> Dictionary:
	var bx := -5.0 if pulling else 2.0
	var by := 1.0
	var step := sin(phase) * 9.0 if moving else 5.0
	var lift_front := -maxf(0.0, cos(phase)) * 3.0 if moving else 0.0
	var lift_back := -maxf(0.0, -cos(phase)) * 3.0 if moving else 0.0
	if pulling:
		step = -step
	# Hands stay at a fixed world anchor while the complete pose is baked offline.
	return _p(bx, by, -0.12 if pulling else 0.13, bx * 0.65, 0, -0.04 if pulling else 0.03,
		step, lift_front, -step, lift_back, 54.0 - bx, -6.0 - by, 54.0 - bx, 0.0 - by)
