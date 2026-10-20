extends Node2D

const SCREEN := Vector2(1280.0, 720.0)
const BAT_COUNT := 14
const FLOCK_IMPACT_TIME := 0.82
const FLOCK_EXIT_TIME := 2.05

var clock := 0.0
var sequence_time := 0.0
var target := Vector2(390.0, 398.0)


func _ready() -> void:
	z_index = 11
	hide()


func sync(
	delta: float,
	next_sequence_time: float,
	target_world: Vector2,
	camera_y: float,
	active: bool
) -> void:
	visible = active
	if not active:
		return
	clock += delta
	sequence_time = next_sequence_time
	target = target_world - Vector2(0.0, camera_y)
	queue_redraw()


func _draw() -> void:
	for bat_index in range(BAT_COUNT):
		var delay := float(bat_index % 7) * 0.045 + float(bat_index / 7) * 0.13
		var local_time := sequence_time - delay
		if local_time <= 0.0:
			continue
		var position_value := _bat_position(bat_index, local_time)
		if (
			position_value.x < -220.0
			or position_value.x > SCREEN.x + 180.0
			or position_value.y < -160.0
			or position_value.y > SCREEN.y + 180.0
		):
			continue
		var next_position := _bat_position(bat_index, local_time + 0.012)
		var direction := next_position - position_value
		var angle := direction.angle() if direction.length_squared() > 0.01 else -2.1
		var depth_scale := 0.72 + float((bat_index * 5) % 8) * 0.055
		_draw_bat(position_value, angle, depth_scale, bat_index)


func _bat_position(bat_index: int, local_time: float) -> Vector2:
	var delay := float(bat_index % 7) * 0.045 + float(bat_index / 7) * 0.13
	var start := Vector2(
		528.0 + float((bat_index * 47) % 164),
		748.0 + float((bat_index * 31) % 112)
	)
	var impact_offset := Vector2.ZERO
	if bat_index > 0:
		impact_offset = Vector2(
			float((bat_index * 37) % 92) - 46.0,
			float((bat_index * 53) % 62) - 31.0
		)
	var impact := target + impact_offset
	var personal_impact_time := maxf(
		0.30,
		FLOCK_IMPACT_TIME - delay + float(bat_index % 4) * 0.018
	)
	if local_time <= personal_impact_time:
		var ratio := clampf(local_time / personal_impact_time, 0.0, 1.0)
		var eased := smoothstep(0.0, 1.0, ratio)
		var crosswind := sin(ratio * PI) * (10.0 + float(bat_index % 5) * 3.5)
		return start.lerp(impact, eased) + Vector2(crosswind, -crosswind * 0.28)

	var exit := Vector2(
		-150.0 - float((bat_index * 29) % 180),
		-40.0 + float((bat_index * 41) % 240)
	)
	var personal_exit_time := maxf(
		personal_impact_time + 0.72,
		FLOCK_EXIT_TIME - delay + float(bat_index % 3) * 0.06
	)
	var exit_ratio := clampf(
		(local_time - personal_impact_time) / (personal_exit_time - personal_impact_time),
		0.0,
		1.0
	)
	var eased_exit := 1.0 - pow(1.0 - exit_ratio, 2.0)
	var wake := sin(exit_ratio * PI) * Vector2(0.0, -18.0 - float(bat_index % 3) * 7.0)
	return impact.lerp(exit, eased_exit) + wake


func _draw_bat(center: Vector2, angle: float, scale_factor: float, bat_index: int) -> void:
	var flap := sin(clock * (17.0 + float(bat_index % 3) * 1.8) + float(bat_index) * 1.73)
	var wing_reach := 11.0 + float(bat_index % 4) * 0.8
	var wing_lift := 4.5 + flap * 4.2
	var ink := Color(0.002, 0.003, 0.003, 0.98)
	var membrane := Color(0.25, 0.26, 0.25, 0.19)

	draw_set_transform(center, angle, Vector2.ONE * scale_factor)

	var upper_wing := PackedVector2Array([
		Vector2(-2.0, -1.0),
		Vector2(-5.0, -5.0 - wing_lift * 0.35),
		Vector2(-wing_reach, -8.0 - wing_lift),
		Vector2(-8.0, -1.5),
		Vector2(-3.0, 1.0),
	])
	var lower_wing := PackedVector2Array([
		Vector2(-1.0, 1.0),
		Vector2(-5.0, 4.0 + wing_lift * 0.28),
		Vector2(-wing_reach + 1.0, 7.0 + wing_lift * 0.82),
		Vector2(-7.0, 1.5),
		Vector2(-2.0, -1.0),
	])
	draw_colored_polygon(upper_wing, ink)
	draw_colored_polygon(lower_wing, ink)

	var upper_membrane := PackedVector2Array([
		Vector2(-4.0, -2.0),
		Vector2(-6.0, -5.0 - wing_lift * 0.28),
		Vector2(-9.2, -6.1 - wing_lift * 0.58),
		Vector2(-7.0, -1.5),
	])
	var lower_membrane := PackedVector2Array([
		Vector2(-3.5, 1.8),
		Vector2(-6.0, 3.7 + wing_lift * 0.20),
		Vector2(-8.8, 5.2 + wing_lift * 0.48),
		Vector2(-6.5, 1.4),
	])
	draw_colored_polygon(upper_membrane, membrane)
	draw_colored_polygon(lower_membrane, membrane)

	draw_circle(Vector2(1.5, 0.0), 3.0, ink, true, -1.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(2.5, -1.5),
			Vector2(5.8, -3.6),
			Vector2(5.0, -0.2),
		]),
		ink
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(2.5, 1.5),
			Vector2(5.8, 3.6),
			Vector2(5.0, 0.2),
		]),
		ink
	)
	draw_set_transform(Vector2.ZERO)
