extends Node2D

# Stand-alone lab for the cut-out wizard. It is not connected to level 1.
#   A / D or arrows  walk, hold Shift to run     Space  jump
#   1  scared recoil     2  fall from height, lie, get up     C  show/hide the current knight
#   R  reset

const Rig = preload("res://scripts/prototypes/wizard_rig/wizard_rig.gd")
const Poses = preload("res://scripts/prototypes/wizard_rig/wizard_poses.gd")
const OLD_ROOT := "res://assets/art/actors/crooked_tower_seedance"

const GROUND_Y := 560.0
const WALK_SPEED := 150.0
const RUN_SPEED := 330.0
const ACCEL := 1500.0
const BRAKE := 1900.0
const JUMP_SPEED := 640.0
const GRAVITY := 1750.0
const RIG_SCALE := 0.2

var rig: Node2D
var leg_px: float
var pos_x := 640.0
var vx := 0.0
var height := 0.0
var vy := 0.0
var phase := 0.0
var landing := 0.0
var facing_target := 1.0
var mode := "free"
var seq_t := 0.0
var seq_start_x := 0.0
var seq_keys: Array = []
var last_pelvis_dy := 0.0
var fall_t := 0.0
var old_sprite: Sprite2D
var old_clock := 0.0
var label: Label
var skid := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.74, 0.745, 0.75))
	rig = Rig.new()
	rig.rig_scale = RIG_SCALE
	add_child(rig)
	rig.z_index = 0
	leg_px = (885.0 - 705.0) * 1.125 * RIG_SCALE
	_build_stage()
	_build_old_knight()
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	label.text = "A/D 走  Shift 跑  Space 跳  1 惊恐后退  2 坠落/趴地/爬起  C 对比当前角色  R 重置"
	add_child(label)
	reset()

func _build_stage() -> void:
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(-200, GROUND_Y), Vector2(1500, GROUND_Y), Vector2(1500, 900), Vector2(-200, 900)])
	ground.color = Color(0.012, 0.013, 0.013)
	ground.z_index = -2
	add_child(ground)

func _build_old_knight() -> void:
	old_sprite = Sprite2D.new()
	old_sprite.centered = false
	old_sprite.position = Vector2(150, GROUND_Y - 232.0 * 0.8)
	old_sprite.scale = Vector2(0.8, 0.8)
	old_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	old_sprite.visible = false
	add_child(old_sprite)

func reset() -> void:
	pos_x = 640.0
	vx = 0.0
	height = 0.0
	vy = 0.0
	mode = "free"
	landing = 0.0
	skid = 0.0
	facing_target = 1.0
	rig.facing = 1.0
	rig.flip = 1.0
	rig.set_target(Poses.idle(0.0))
	rig.step(0.0, true)
	rig.apply()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: start_scared()
		KEY_2: start_fall()
		KEY_R: reset()
		KEY_C: old_sprite.visible = not old_sprite.visible
		KEY_SPACE: jump()

func jump() -> void:
	if mode == "free" and height <= 0.0:
		vy = -JUMP_SPEED
		height = 0.01
		landing = 0.0

func start_scared() -> void:
	if mode != "free" or height > 0.0:
		return
	mode = "scared"
	seq_t = 0.0
	seq_start_x = pos_x
	seq_keys = Poses.scared_keys()
	vx = 0.0

func start_fall() -> void:
	if mode != "free":
		return
	mode = "fall_air"
	fall_t = 0.0
	height = Poses.FALL_HEIGHT
	vy = 0.0
	vx = 0.0

func _process(delta: float) -> void:
	tick(delta, _read_input())

func _read_input() -> Dictionary:
	var dir := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	return {"dir": dir, "run": Input.is_key_pressed(KEY_SHIFT)}

func tick(delta: float, input: Dictionary) -> void:
	old_clock += delta
	_update_old_knight()
	var previous_x := pos_x
	var previous_height := height
	match mode:
		"free": _tick_free(delta, input)
		"scared": _tick_scared(delta)
		"fall_air": _tick_fall_air(delta)
		"fall_down": _tick_fall_down(delta)
	# Spring drive: how fast the body is moving along its facing direction, and vertically.
	var forward_speed: float = (pos_x - previous_x) / maxf(delta, 0.0001) * float(rig.facing)
	var vertical_speed: float = -(previous_height - height) / maxf(delta, 0.0001)
	var pelvis_dy := float(rig.target[&"pelvis_dy"])
	if mode == "fall_down":
		vertical_speed -= (pelvis_dy - last_pelvis_dy) / maxf(delta, 0.0001) * 0.3
	last_pelvis_dy = pelvis_dy
	rig.step(delta)
	rig.step_springs(delta, forward_speed, vertical_speed, 0.0)
	rig.position = Vector2(pos_x, GROUND_Y - height)
	rig.apply()

func _tick_free(delta: float, input: Dictionary) -> void:
	var dir: float = input.dir
	var wants_run: bool = input.run
	var top := RUN_SPEED if wants_run else WALK_SPEED
	var target_speed := dir * top
	var rate := ACCEL if (absf(target_speed) > absf(vx) and signf(target_speed) == signf(vx) or vx == 0.0) else BRAKE
	if height > 0.0:
		rate *= 0.45
	var previous_speed := absf(vx)
	vx = move_toward(vx, target_speed, rate * delta)
	if dir != 0.0:
		facing_target = signf(dir)
	rig.facing = move_toward(rig.facing, facing_target, delta * 14.0)
	pos_x = clampf(pos_x + vx * delta, 330.0, 1250.0)

	if height > 0.0 or vy != 0.0:
		vy += GRAVITY * delta
		height -= vy * delta
		if height <= 0.0:
			height = 0.0
			landing = clampf(vy / JUMP_SPEED, 0.2, 1.0)
			vy = 0.0
		else:
			rig.set_target(Poses.air(clampf(vy / JUMP_SPEED, -1.0, 1.0)))
			return
	if landing > 0.0:
		landing = maxf(0.0, landing - delta * 5.0)
		rig.set_target(Poses.air(1.0, landing))
		return
	var speed := absf(vx)
	# Braking from a run: dig the heels in.
	var braking := dir == 0.0 or signf(dir) != signf(vx)
	if speed > 150.0 and braking and speed < previous_speed + 1.0:
		skid = minf(1.0, skid + delta * 8.0)
	else:
		skid = maxf(0.0, skid - delta * 5.0)
	if speed > 18.0 and skid < 0.5:
		var r := clampf((speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED), 0.0, 1.0)
		var stride := 4.0 * leg_px * sin(deg_to_rad(lerpf(26.0, 46.0, r))) * 0.92
		phase += TAU * speed * delta / stride
		rig.set_target(Poses.locomotion(phase, r, leg_px))
	elif skid >= 0.5:
		rig.set_target({
			&"spine": -12.0, &"head": 4.0, &"arm_near_up": 48.0, &"arm_near_fore": 20.0,
			&"arm_far_up": 30.0, &"arm_far_fore": 20.0, &"thigh_near": 30.0, &"shin_near": 14.0,
			&"thigh_far": -26.0, &"shin_far": 28.0, &"pelvis_dy": 8.0,
		})
	else:
		phase = fmod(phase, PI) if speed < 1.0 else phase
		rig.set_target(Poses.idle(old_clock))

func _tick_scared(delta: float) -> void:
	seq_t += delta
	var pose := Poses.sample(seq_keys, seq_t)
	var tremble := 0.0
	if seq_t > 0.5 and seq_t < 1.7:
		tremble = smoothstep(0.5, 0.8, seq_t) * (1.0 - smoothstep(1.3, 1.7, seq_t))
	var shake := Poses.scared_tremble(seq_t, tremble)
	for k in shake.keys():
		pose[k] = float(pose.get(k, 0.0)) + float(shake[k])
	pos_x = seq_start_x + float(pose.get(&"rx", 0.0)) * facing_target
	rig.set_target(pose)
	if seq_t >= float(seq_keys[seq_keys.size() - 1][0]):
		mode = "free"

func _tick_fall_air(delta: float) -> void:
	fall_t += delta
	vy += Poses.FALL_GRAVITY * delta
	height -= vy * delta
	var s := fall_t
	var flail := sin(s * 23.0)
	var pose := {
		&"spine": 8.0 + 7.0 * sin(s * 9.0), &"head": 10.0 + 8.0 * sin(s * 13.0 + 1.0),
		&"arm_near_up": 118.0 + 50.0 * flail, &"arm_near_fore": 36.0 + 28.0 * sin(s * 23.0 + 1.0),
		&"arm_far_up": 100.0 + 50.0 * sin(s * 23.0 + 2.4), &"arm_far_fore": 34.0 + 26.0 * sin(s * 23.0 + 3.0),
		&"thigh_near": 22.0 + 30.0 * sin(s * 19.0), &"shin_near": 46.0 + 26.0 * sin(s * 19.0 + 1.3),
		&"thigh_far": -12.0 + 28.0 * sin(s * 19.0 + 2.6), &"shin_far": 40.0 + 24.0 * sin(s * 19.0 + 3.9),
		&"foot_near": 14.0, &"foot_far": 12.0,
	}
	rig.set_target(pose)
	if height <= 0.0:
		height = 0.0
		mode = "fall_down"
		seq_t = 0.0
		seq_start_x = pos_x
		seq_keys = Poses.impact_keys()
		# Ground hit: the springs get one hard kick.
		rig.tip_spring.y += 520.0
		rig.skirt_spring.y -= 260.0

func _tick_fall_down(delta: float) -> void:
	seq_t += delta
	var pose := Poses.sample(seq_keys, seq_t)
	# Heaving breaths while lying down.
	if seq_t > 0.6 and seq_t < 1.9:
		var heave := sin(seq_t * 9.0) * smoothstep(0.6, 0.9, seq_t) * (1.0 - smoothstep(1.6, 1.9, seq_t))
		pose[&"pelvis_dy"] = float(pose.get(&"pelvis_dy", 0.0)) + heave * 1.4
		pose[&"spine"] = float(pose.get(&"spine", 0.0)) + heave * 2.0
	pos_x = seq_start_x + float(pose.get(&"rx", 0.0)) * facing_target
	rig.set_target(pose)
	if seq_t >= float(seq_keys[seq_keys.size() - 1][0]):
		mode = "free"

func _update_old_knight() -> void:
	if not old_sprite.visible:
		return
	var index := int(old_clock * 24.0) % 15
	old_sprite.texture = load("%s/run/frame_%02d.png" % [OLD_ROOT, index])
