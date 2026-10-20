# Preserved broken-crate prototype. Develop the replacement raft separately.
extends Node2D

const Art = preload("res://scripts/prototypes/c_zone_broken_crate/river_art.gd")
const Actor = preload("res://scripts/prototypes/c_zone_broken_crate/river_actor.gd")
const Pose = preload("res://scripts/actors/actor_pose_state.gd")
const Fan = preload("res://scripts/prototypes/c_zone_broken_crate/fan_art.gd")

const WORLD_WIDTH := 2560.0
const PLAYER_SIZE := Vector2(26, 54)
const CRATE_SIZE := Vector2(102, 94)
const CRATE_START := Vector2(422, 456)
const FAN_SPOT := Vector2(447, 548)
const WATER_Y := 575.0
const GRIP_REACH := 22.5
const CRATE_CONTACT_INSET := 5.0
const GRIP_TIME := 16.0 / 24.0
const RELEASE_TIME := 14.0 / 24.0
const SLIDE_STOP_X := 1240.0
const RETURN_SLIDE_STOP_X := 1870.0

@export var return_to_debug_menu := false
var LEFT_PROFILE := PackedVector2Array([
	Vector2(-120, 320), Vector2(5, 365), Vector2(225, 550),
	Vector2(1090, 550), Vector2(1180, 584), Vector2(1270, 630),
	Vector2(1350, 850), Vector2(-120, 850)
])
var RIGHT_PROFILE := PackedVector2Array([
	Vector2(1880, 850), Vector2(1950, 625), Vector2(2110, 550),
	Vector2(2700, 550), Vector2(2700, 850)
])

var player: CharacterBody2D
var crate: CharacterBody2D
var crate_shape: CollisionShape2D
var crate_tilt := 0.0
var float_time := 0.0
var launching := false
var launch_direction := 1.0
var float_direction := 1.0
var entry_brake := false
var beached := false
var load_sink := 0.0
var sink_speed := 0.0
var load_rock := 0.0
var rock_speed := 0.0
var actor: Node2D
var fan: Node2D
var art: Node2D
var camera: Camera2D
var pose = Pose.new()
var clock := 0.0
var camera_x := 0.0
var facing := 1.0
var fan_owned := false
var fan_revealed := false
var floating := false
var dragging := false
var grip_time := 0.0
var release_time := 0.0
var grip_distance := 0.0
var crate_motion := 0.0
var landed := false # Progress only; returning to the river must still allow buoyancy.
var completed := false
var paused := false
var intro_time := 0.0
var coyote := 0.0
var jump_buffer := 0.0
var fan_cooldown := 0.0
var fan_swing := 0.0
var pickup_time := 0.0
var death_time := 0.0
var checkpoint := 0
var checkpoint_fan := false
var wind_impulses := 0
var crate_wet := false
var player_wet := false
var debug_visible := false
var debug_label: Label
var pause_panel: Control
var sound: AudioStreamPlayer
var fan_button: Button

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("979797"))
	_create_ground(LEFT_PROFILE)
	_create_ground(RIGHT_PROFILE)
	crate = _body(CRATE_SIZE, 2, 1)
	crate_shape = crate.get_child(0)
	crate.floor_snap_length = 16.0
	player = _body(PLAYER_SIZE, 4, 3)
	var player_shape := CapsuleShape2D.new()
	player_shape.radius = PLAYER_SIZE.x * 0.5
	player_shape.height = PLAYER_SIZE.y
	(player.get_child(0) as CollisionShape2D).shape = player_shape
	player.floor_snap_length = 12.0
	player.floor_max_angle = deg_to_rad(48.0)
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	art = Art.new()
	art.level = self
	add_child(art)
	actor = Actor.new()
	actor.z_index = 5
	add_child(actor)
	fan = Fan.new()
	fan.z_index = 6
	add_child(fan)
	_create_ui()
	sound = AudioStreamPlayer.new()
	var ambience = load("res://assets/audio/level01/ambience_wind.mp3").duplicate()
	ambience.loop = true
	sound.stream = ambience
	sound.volume_db = -29.0
	add_child(sound)
	sound.play()
	reset_all()

func _body(size: Vector2, layer: int, mask: int) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = layer
	body.collision_mask = mask
	body.safe_margin = 0.08
	body.platform_floor_layers = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	shape.position = size * 0.5
	body.add_child(shape)
	add_child(body)
	return body

func _create_ground(points: PackedVector2Array) -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	ground.add_child(shape)
	add_child(ground)

func reset_all() -> void:
	checkpoint = 0
	checkpoint_fan = false
	fan_owned = false
	fan_revealed = false
	landed = false
	completed = false
	wind_impulses = 0
	clock = 0.0
	restore_checkpoint()
	player.position = Vector2(565, 445)
	intro_time = 0.38

func restore_checkpoint() -> void:
	player.position = Vector2(590, 496)
	crate.position = CRATE_START
	if checkpoint == 1:
		player.position = Vector2(1050, 496)
		crate.position = Vector2(1150, 482)
	elif checkpoint == 2:
		player.position = Vector2(2270, 496)
		crate.position = Vector2(2140, 456)
	fan_owned = checkpoint_fan
	fan_revealed = checkpoint > 0
	player.velocity = Vector2.ZERO
	crate.velocity = Vector2.ZERO
	crate_tilt = 0.0
	crate_shape.rotation = 0.0
	float_time = 0.0
	launching = false
	launch_direction = -1.0 if checkpoint == 2 else 1.0
	float_direction = launch_direction
	entry_brake = false
	beached = checkpoint == 2
	landed = checkpoint == 2
	completed = false
	load_sink = 0.0
	sink_speed = 0.0
	load_rock = 0.0
	rock_speed = 0.0
	floating = false
	dragging = false
	grip_time = 0.0
	release_time = 0.0
	grip_distance = 0.0
	crate_motion = 0.0
	actor.reset_grip_animation()
	actor.locomotion_hold_time = 0.0
	actor.support_offset = 0.0
	crate_wet = false
	player_wet = false
	art.reset_water_impacts()
	intro_time = 0.0
	death_time = 0.0
	fan_cooldown = 0.0
	fan_swing = 0.0
	pickup_time = 0.0
	coyote = 0.0
	jump_buffer = 0.0
	facing = 1.0
	camera_x = clampf(player.position.x - 540.0, 0.0, WORLD_WIDTH - 1280.0)
	camera.position.x = camera_x + 640.0
	_present(0.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			if event.shift_pressed:
				reset_all()
			else:
				restore_checkpoint()
		KEY_F1:
			debug_visible = not debug_visible
			debug_label.visible = debug_visible
		KEY_ESCAPE:
			if return_to_debug_menu:
				_return_to_debug()
			else:
				_set_paused(not paused)

func _return_to_debug() -> void:
	get_tree().set_meta(&"inkfall_debug_return", 5)
	var error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		get_tree().remove_meta(&"inkfall_debug_return")
		push_error("Unable to return to DEBUG: %s" % error)

func _physics_process(delta: float) -> void:
	if paused:
		return
	clock += delta
	grip_time = maxf(0.0, grip_time - delta)
	release_time = maxf(0.0, release_time - delta)
	fan_cooldown = maxf(0.0, fan_cooldown - delta)
	fan_swing = maxf(0.0, fan_swing - delta)
	pickup_time = maxf(0.0, pickup_time - delta)
	if death_time > 0.0:
		death_time += delta
		player.position.y += 28.0 * delta
		if death_time > 0.8:
			restore_checkpoint()
		_present(delta)
		return
	var direction := Input.get_axis("move_left", "move_right")
	if direction * launch_direction <= 0.0 or Input.is_action_just_pressed("jump"):
		entry_brake = false
	if intro_time > 0.0:
		intro_time = maxf(0.0, intro_time - delta)
		direction = 1.0
		player.velocity.x = 260.0
	_update_interaction(direction)
	var previous_crate := crate.position
	var previous_lowest := _lowest_crate_y()
	var previous_feet_y := player.position.y + PLAYER_SIZE.y
	var riding := is_riding()
	var rider_local := (player.position + Vector2(13,54) - crate.position - CRATE_SIZE * 0.5).rotated(-crate_tilt)
	_update_crate(delta, direction, riding)
	if riding:
		# Carry the contact point through translation and rotation on either bank.
		player.position = crate.position + CRATE_SIZE * 0.5 + rider_local.rotated(crate_tilt) - Vector2(13,54)
	var impact_speed := player.velocity.y
	_update_player(delta, direction, (crate.position.x - previous_crate.x) / delta)
	_update_water_contact(delta, previous_lowest, previous_feet_y)
	if floating and is_riding() and not riding:
		sink_speed += clampf(impact_speed * 0.09, 14.0, 48.0)
		var impact_offset := clampf((player.position.x + 13.0 - crate.position.x - 51.0) / 51.0, -1.0, 1.0)
		rock_speed += impact_offset * 0.65
		art.emit_water_impact(player.position.x + 13.0, impact_speed * 0.45, 26.0)
	crate_motion = crate.position.x - previous_crate.x
	if dragging:
		grip_distance += absf(crate_motion)
	if not fan_revealed and absf(crate.position.x - CRATE_START.x) > 125.0:
		fan_revealed = true
	if floating and checkpoint == 0:
		checkpoint = 1
		checkpoint_fan = fan_owned
	if player.position.y + PLAYER_SIZE.y > 659.0:
		death_time = 0.001
		dragging = false
	if crate.position.x > 2115.0 and player.position.x > 2100.0 and player.is_on_floor():
		checkpoint = 2
		checkpoint_fan = fan_owned
		landed = true
	elif crate.position.x < 1000.0 and player.position.x < 1090.0 and player.is_on_floor() and checkpoint > 0:
		checkpoint = 1
		checkpoint_fan = fan_owned
	if landed and player.position.x > 2390.0:
		completed = true
	var target_camera := clampf(player.position.x - 525.0, 0.0, WORLD_WIDTH - 1280.0)
	camera_x = lerpf(camera_x, target_camera, 1.0 - exp(-delta * 3.8))
	camera.position.x = camera_x + 640.0
	_present(delta)

func is_riding() -> bool:
	var feet := player.position + Vector2(13, 54)
	var center := crate.position + CRATE_SIZE * 0.5
	var top_center_x := center.x + sin(crate_tilt) * CRATE_SIZE.y * 0.5
	var half_width := cos(crate_tilt) * CRATE_SIZE.x * 0.5
	return absf(feet.y - crate_top_at(feet.x)) < 12.0 and absf(feet.x - top_center_x) < half_width + 3.0 and player.velocity.y >= -2.0

func crate_top_at(world_x: float) -> float:
	var center := crate.position + CRATE_SIZE * 0.5
	return center.y + (world_x - center.x) * tan(crate_tilt) - CRATE_SIZE.y * 0.5 / cos(crate_tilt)

func can_grab() -> bool:
	var p := player.position + PLAYER_SIZE * 0.5
	var c := crate.position + CRATE_SIZE * 0.5
	var side := signf(p.x - c.x)
	var contact := crate_side_contact(side)
	var side_gap := (p.x - contact.x) * side
	return side != 0.0 and side_gap >= 4.0 and side_gap < GRIP_REACH + 24.0 and absf(player.position.y + 36.0 - contact.y) < 48.0 and not is_riding() and player.is_on_floor() and not floating and not launching

func crate_side_contact(side: float) -> Vector2:
	return crate.position + CRATE_SIZE * 0.5 + Vector2(side * (CRATE_SIZE.x * 0.5 - CRATE_CONTACT_INSET), 29.0).rotated(crate_tilt)

func _release_grip() -> void:
	if dragging:
		release_time = RELEASE_TIME
	dragging = false
	grip_time = 0.0

func grip_target_x() -> float:
	return crate_side_contact(-facing).x - facing * GRIP_REACH - PLAYER_SIZE.x * 0.5

func _update_interaction(direction: float) -> void:
	if intro_time > 0.0:
		return
	if Input.is_action_just_pressed("interact"):
		if fan_revealed and not fan_owned and (player.position + Vector2(13, 54)).distance_to(FAN_SPOT) < 80.0:
			fan_owned = true
			checkpoint_fan = true
			pickup_time = 0.32
		elif can_grab():
			dragging = true
			grip_time = GRIP_TIME
			release_time = 0.0
			grip_distance = 0.0
	if not Input.is_action_pressed("interact") or Input.is_action_just_pressed("jump"):
		_release_grip()
	if dragging:
		if not can_grab():
			_release_grip()
		else:
			facing = signf(crate.position.x + 51.0 - player.position.x - 13.0)
	elif direction != 0.0:
		facing = signf(direction)
	if Input.is_action_pressed("blade_toggle") and fan_owned and fan_cooldown <= 0.0 and not dragging:
		swing_fan()

func swing_fan() -> bool:
	if not fan_owned or fan_cooldown > 0.0 or paused or dragging or death_time > 0.0:
		return false
	fan_swing = 0.48
	fan_cooldown = 0.78
	var offset := crate.position + CRATE_SIZE * 0.5 - (player.position + PLAYER_SIZE * 0.5)
	if floating and not launching and not beached and _shore_limit(crate_tilt) > _unloaded_float_y() - 6.0 and offset.length() < 240.0 and (offset.x * facing > -25.0 or is_riding()):
		crate.velocity.x = facing * 205.0
		wind_impulses += 1
		return true
	return false

func ground_y(x: float) -> float:
	if x <= 225.0:
		return 365.0 + (x - 5.0) * 185.0 / 220.0
	if x <= 1090.0:
		return 550.0
	if x <= 1180.0:
		return lerpf(550.0, 584.0, (x - 1090.0) / 90.0)
	if x <= 1270.0:
		return lerpf(584.0, 630.0, (x - 1180.0) / 90.0)
	if x < 1350.0:
		return lerpf(630.0, 850.0, (x - 1270.0) / 80.0)
	if x < 1880.0:
		return 850.0
	if x < 1950.0:
		return lerpf(850.0, 625.0, (x - 1880.0) / 70.0)
	if x < 2110.0:
		return lerpf(625.0, 550.0, (x - 1950.0) / 160.0)
	return 550.0

func _unloaded_float_y() -> float:
	return WATER_Y - 13.0 - CRATE_SIZE.y * 0.5

func _shore_limit(angle: float, ahead_x := 0.0) -> float:
	var limit := 850.0
	for corner in [Vector2(-52,-48), Vector2(52,-48), Vector2(52,48), Vector2(-52,48)]:
		var rotated: Vector2 = corner.rotated(angle)
		limit = minf(limit, ground_y(crate.position.x + ahead_x + 51.0 + rotated.x) - 47.0 - rotated.y - 0.5)
	return limit

func _lowest_crate_y() -> float:
	var half := CRATE_SIZE * 0.5
	return crate.position.y + half.y + absf(sin(crate_tilt)) * half.x + absf(cos(crate_tilt)) * half.y

func crate_waterline_span() -> Vector2:
	var half := CRATE_SIZE * 0.5
	var corners := PackedVector2Array()
	for point in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		corners.append(crate.position + half + point.rotated(crate_tilt))
	var crossings: Array[float] = []
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		if (a.y <= WATER_Y and b.y > WATER_Y) or (b.y <= WATER_Y and a.y > WATER_Y):
			crossings.append(lerpf(a.x, b.x, (WATER_Y - a.y) / (b.y - a.y)))
	if crossings.size() < 2:
		return Vector2(crate.position.x + half.x, crate.position.x + half.x)
	crossings.sort()
	return Vector2(crossings.front(), crossings.back())

func _update_water_contact(delta: float, previous_lowest: float, previous_feet_y: float) -> void:
	var lowest := _lowest_crate_y()
	var in_river := crate.position.x + CRATE_SIZE.x > 1156.0 and crate.position.x < 2060.0
	if not crate_wet and in_river and lowest > WATER_Y + 0.5:
		crate_wet = true
		var span := crate_waterline_span()
		art.emit_water_impact((span.x + span.y) * 0.5, maxf(0.0, (lowest - previous_lowest) / delta), maxf(10.0, (span.y - span.x) * 0.5))
	elif not in_river or lowest < WATER_Y - 6.0:
		crate_wet = false
	var feet := player.position + Vector2(13, 54)
	var player_in_river := feet.x > 1156.0 and feet.x < 2060.0
	if not player_wet and player_in_river and feet.y > WATER_Y + 2.0 and not is_riding():
		player_wet = true
		art.emit_water_impact(feet.x, maxf(0.0, (feet.y - previous_feet_y) / delta), 9.0)
	elif not player_in_river or feet.y < WATER_Y - 6.0:
		player_wet = false

func bank_slope_angle() -> float:
	return clampf(atan2(ground_y(crate.position.x + 97.0) - ground_y(crate.position.x + 5.0), 92.0), -deg_to_rad(35.0), deg_to_rad(35.0))

func bank_downhill_direction() -> float:
	return 1.0 if crate.position.x + 51.0 < 1600.0 else -1.0

func _update_crate(delta: float, direction: float, riding: bool) -> void:
	var slope := bank_slope_angle()
	var downhill := bank_downhill_direction()
	var entering_slope := dragging and grip_time <= 0.0 and direction * downhill > 0.0 and absf(slope) > deg_to_rad(5.0)
	if not floating and not launching and entering_slope:
		launching = true
		beached = false
		launch_direction = downhill
		float_direction = downhill
		entry_brake = facing * downhill < 0.0
		_release_grip()
		crate.velocity.x = 0.0
		if entry_brake:
			player.velocity.x = 0.0
	var was_floating := floating
	var water_contact := _lowest_crate_y() >= WATER_Y and crate.position.y + 47.0 >= WATER_Y - 18.0
	var water_support := crate.position.x + 51.0 > 1156.0 and crate.position.x < 2065.0 and (was_floating or water_contact)
	if was_floating and not launching and crate.velocity.x * downhill < -0.5 and _shore_limit(crate_tilt, crate.velocity.x * delta) <= _unloaded_float_y() + load_sink + 2.0:
		beached = true
		crate.velocity.x = 0.0
	floating = water_support and not beached
	crate.floor_snap_length = 0.0 if floating else 16.0
	float_time = float_time + delta if floating else 0.0
	var sink_target := 11.0 if floating and riding else 0.0
	sink_speed += ((sink_target - load_sink) * 35.0 - sink_speed * 6.0) * delta
	load_sink = clampf(load_sink + sink_speed * delta, -2.0, 20.0)
	var weight_offset := clampf((player.position.x + 13.0 - crate.position.x - 51.0) / 51.0, -1.0, 1.0)
	var rock_target := weight_offset * deg_to_rad(4.0) if floating and riding else 0.0
	rock_speed += ((rock_target - load_rock) * 30.0 - rock_speed * 4.5) * delta
	load_rock = clampf(load_rock + rock_speed * delta, -0.12, 0.12)
	var angle_target := slope
	if floating:
		angle_target = float_direction * deg_to_rad(28.0) + sin(float_time * 2.3) * deg_to_rad(1.8) + sin(float_time * 5.0) * exp(-float_time * 1.4) * 0.10 + load_rock
	var previous_support := _shore_limit(crate_tilt)
	crate_tilt = lerpf(crate_tilt, angle_target, 1.0 - exp(-delta * 5.0))
	crate_shape.rotation = crate_tilt
	if not floating and crate.is_on_floor():
		# Rotate about the supporting bank contact; unsupported motion remains gravity-driven.
		crate.position.y += _shore_limit(crate_tilt) - previous_support
	if floating:
		if not was_floating and not launching:
			crate.velocity.x = 0.0
		_release_grip()
		var shore_limit := minf(_shore_limit(crate_tilt), _shore_limit(crate_tilt, crate.velocity.x * delta))
		var target_y := minf(_unloaded_float_y() + load_sink + sin(clock * 1.8) * 1.3, shore_limit)
		crate.position.y = minf(crate.position.y, shore_limit)
		crate.position.y = move_toward(crate.position.y, target_y, delta * 110.0)
		crate.velocity.y = 0.0
		if not launching:
			crate.velocity.x = move_toward(crate.velocity.x, 0.0, delta * 72.0)
	else:
		# Keep the rotating bottom on the signed bank slope, not an upright land pose.
		crate.position.y = minf(crate.position.y, _shore_limit(crate_tilt))
		crate.velocity.y = minf(900.0, crate.velocity.y + 1500.0 * delta)
		var drag_target := direction * 126.0 if dragging and grip_time <= 0.0 else 0.0
		if not launching:
			crate.velocity.x = move_toward(crate.velocity.x, drag_target, delta * 580.0)
		if dragging and crate.velocity.x * facing < 0.0:
			# A blocked puller must not drag the crate through their own collision body.
			var contact := player.move_and_collide(Vector2(crate.velocity.x * delta, 0), true)
			if contact != null and contact.get_normal().dot(Vector2.UP) < cos(player.floor_max_angle):
				crate.velocity.x = contact.get_travel().x / delta
	if launching:
		var stop_x := SLIDE_STOP_X if launch_direction > 0.0 else RETURN_SLIDE_STOP_X
		if (crate.position.x - stop_x) * launch_direction >= -0.1 or (floating and absf(crate.velocity.x) < 0.5):
			launching = false
			crate.velocity.x = 0.0
		elif floating:
			crate.velocity.x = move_toward(crate.velocity.x, 0.0, delta * 28.0)
		else:
			var downhill_force := 330.0 * sin(crate_tilt) * cos(crate_tilt)
			crate.velocity.x = clampf(crate.velocity.x + downhill_force * delta, -52.0, 52.0)
	# During launch the crate yields to the player, instead of pushing them underwater.
	crate.collision_mask = 5 if launching and not riding else 1
	crate.move_and_slide()
	crate.position.x = clampf(crate.position.x, 260.0, WORLD_WIDTH - 140.0)
	if crate.position.y > 780.0:
		restore_checkpoint()

func _update_player(delta: float, direction: float, crate_speed: float) -> void:
	var grounded := player.is_on_floor() or is_riding()
	coyote = 0.11 if grounded else maxf(0.0, coyote - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump") and intro_time <= 0.0:
		jump_buffer = 0.13
	var speed := 285.0
	var in_shallows := player.position.y + 54.0 > WATER_Y + 10.0
	if in_shallows:
		speed = 160.0
	var target := direction * speed
	if entry_brake:
		target = 0.0
	if dragging:
		target = crate_speed + clampf((grip_target_x() - player.position.x) * 16.0, -110.0, 110.0)
	if intro_time <= 0.0:
		player.velocity.x = move_toward(player.velocity.x, target, delta * 1900.0)
	player.velocity.y = minf(850.0, player.velocity.y + 1500.0 * delta)
	if jump_buffer > 0.0 and coyote > 0.0:
		player.velocity.y = -595.0
		jump_buffer = 0.0
		coyote = 0.0
		dragging = false
	if not Input.is_action_pressed("jump") and player.velocity.y < -210.0:
		player.velocity.y = -210.0
	player.move_and_slide()
	player.position.x = clampf(player.position.x, 20.0, WORLD_WIDTH - 55.0)

func _present(delta: float) -> void:
	# Collision can alternate vx between zero and walking speed. A cancelled
	# release must not resume when the player touches the sliding crate again.
	if release_time > 0.0 and (not player.is_on_floor() or absf(player.velocity.x) >= 30.0 or pickup_time > 0.0 or fan_swing > 0.0):
		release_time = 0.0
	var action: StringName = Pose.ACTION_NONE
	var progress := 0.0
	if pickup_time > 0.0:
		action = Pose.ACTION_PICKUP
		progress = 1.0 - pickup_time / 0.32
	elif fan_swing > 0.0:
		action = Pose.ACTION_THROW_RELEASE
		progress = 1.0 - fan_swing / 0.48
	elif dragging:
		if grip_time > 0.0:
			action = &"grip_engage"
			progress = 1.0 - grip_time / GRIP_TIME
		elif absf(crate_motion) < 0.05:
			action = &"grip_hold"
		else:
			action = &"pull" if crate_motion * facing < 0.0 else &"push"
	elif release_time > 0.0:
		action = &"grip_release"
		progress = 1.0 - release_time / RELEASE_TIME
	pose.apply({
		"feet": player.position + Vector2(13, 54),
		"velocity": player.velocity, "grounded": player.is_on_floor() or is_riding(),
		"facing": facing, "action": action, "action_progress": progress,
		"monochrome": true, "visual_scale": 0.90,
	})
	actor.grip_distance = grip_distance
	actor.sync_pose(delta, pose)
	actor.apply_surface_contact(delta, player, pose.grounded)
	actor.modulate.a = 1.0 - clampf(death_time / 0.8, 0.0, 1.0)
	fan.visible = fan_owned and death_time <= 0.0 and not dragging
	fan.position = player.position + Vector2(13 + facing * 15, 26)
	fan.scale.x = facing
	fan.rotation = facing * (-0.3 + sin(progress * PI * 1.4) * 1.85) if fan_swing > 0.0 else facing * -0.5
	fan.queue_redraw()
	fan_button.visible = fan_owned and not paused
	fan_button.disabled = fan_cooldown > 0.0 or dragging or death_time > 0.0
	fan_button.modulate.a = 0.45 if fan_button.disabled else 0.90
	art.sync(delta, camera_x, true)
	if debug_visible:
		debug_label.text = "C / RIVER   |   %s\nPLAYER %.0f, %.0f   CRATE %.0f, %.0f\nFAN %s   FLOAT %s   WIND %d   CHECKPOINT %d" % ["COMPLETE" if completed else "PLAY", player.position.x, player.position.y, crate.position.x, crate.position.y, fan_owned, floating, wind_impulses, checkpoint]

func _create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	debug_label = Label.new()
	debug_label.position = Vector2(24, 20)
	debug_label.add_theme_font_size_override("font_size", 16)
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	debug_label.hide()
	layer.add_child(debug_label)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	fan_button = Button.new()
	fan_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fan_button.offset_left = -82.0
	fan_button.offset_top = -84.0
	fan_button.offset_right = -26.0
	fan_button.offset_bottom = -28.0
	fan_button.focus_mode = Control.FOCUS_NONE
	fan_button.tooltip_text = "挥动芭蕉扇"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.07, 0.70)
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = Color(0.6, 0.6, 0.6, 0.40)
	for state in ["normal", "hover", "pressed", "disabled"]:
		fan_button.add_theme_stylebox_override(state, style)
	var icon := Fan.new()
	icon.ink = Color("d5d5d5")
	icon.position = Vector2(28,43)
	icon.scale = Vector2.ONE * 0.42
	icon.rotation = 0.35
	fan_button.add_child(icon)
	fan_button.pressed.connect(swing_fan)
	hud.add_child(fan_button)
	fan_button.hide()
	pause_panel = Control.new()
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(pause_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(shade)
	var column := VBoxContainer.new()
	column.position = Vector2(520, 250)
	column.size = Vector2(240, 200)
	column.add_theme_constant_override("separation", 18)
	pause_panel.add_child(column)
	for title in ["继续", "回到岸边", "重置第一幕"]:
		var button := Button.new()
		button.text = title
		button.custom_minimum_size = Vector2(240, 44)
		column.add_child(button)
		button.pressed.connect(func():
			if title == "回到岸边": restore_checkpoint()
			if title == "重置第一幕": reset_all()
			_set_paused(false)
		)
	pause_panel.hide()

func _set_paused(value: bool) -> void:
	paused = value
	pause_panel.visible = value
	fan_button.visible = fan_owned and not value
	if value:
		pause_panel.get_child(1).get_child(0).grab_focus()
