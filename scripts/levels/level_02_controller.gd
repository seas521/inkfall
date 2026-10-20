extends Node2D

signal completed

const Palette = preload("res://scripts/shared/inkfall_palette.gd")
const SCREEN := Palette.SCREEN
const PLAYER_SIZE := Palette.PLAYER_SIZE
const GRAVITY := Palette.GRAVITY
const THROW_HOLD_THRESHOLD := Palette.THROW_HOLD_THRESHOLD
const THROW_MIN_SPEED := Palette.THROW_MIN_SPEED
const THROW_MAX_SPEED := Palette.THROW_MAX_SPEED
const SHAFT_FATAL_FALL_SPEED := Palette.SHAFT_FATAL_FALL_SPEED
const INK := Palette.INK
const PAPER := Palette.PAPER
const PALE := Palette.PALE
const MID := Palette.MID
const WATER := Palette.WATER
const WATER_PALE := Palette.WATER_PALE
const GAS := Palette.GAS
const FIRE := Palette.FIRE
const HEMP := Palette.HEMP
const HEMP_LIGHT := Palette.HEMP_LIGHT
const GOLD := Palette.GOLD
const GOLD_LIGHT := Palette.GOLD_LIGHT

const LEVEL2_CLIFF_PLATFORMS: Array[Rect2] = [
	Rect2(-80.0, 400.0, 500.0, 360.0),
	Rect2(1000.0, 430.0, 380.0, 330.0),
]
const LEVEL2_SLOPE_START := Vector2(390.0, 400.0)
const LEVEL2_SLOPE_END := Vector2(760.0, 670.0)

const ROPEWAY_PLATFORMS: Array[Rect2] = [
	Rect2(40.0, 220.0, 220.0, 26.0),
	Rect2(390.0, 300.0, 78.0, 22.0),
	Rect2(700.0, 380.0, 42.0, 22.0),
	Rect2(975.0, 455.0, 68.0, 22.0),
	Rect2(1275.0, 525.0, 42.0, 22.0),
	Rect2(1660.0, 575.0, 48.0, 22.0),
	Rect2(1840.0, 565.0, 120.0, 24.0),
	Rect2(2050.0, 470.0, 285.0, 90.0),
]
const ROPEWAY_KNOTS: Array[Rect2] = [
	Rect2(408.0, 264.0, 42.0, 32.0),
	Rect2(700.0, 226.0, 42.0, 32.0),
	Rect2(988.0, 419.0, 42.0, 32.0),
	Rect2(1275.0, 371.0, 42.0, 32.0),
	Rect2(1663.0, 493.0, 42.0, 32.0),
]
const ROPEWAY_KNOT_HANGING: Array[bool] = [false, true, false, true, true]
const ROPEWAY_KNOT_APEX_REQUIRED: Array[bool] = [false, true, false, true, false]
const ROPEWAY_CLIMB_ZONE := Rect2(2140.0, 250.0, 195.0, 215.0)
const ROPEWAY_CLIMB_ANCHOR := Vector2(2265.0, 205.0)
const ROPEWAY_TRIGGER_X := 300.0
const ROPEWAY_BOULDER_RADIUS := 42.0
const ROPEWAY_BOULDER_START_SPEED := 135.0
const ROPEWAY_BOULDER_ACCELERATION := 12.0
const ROPEWAY_BOULDER_MAX_SPEED := 265.0
var ropeway_boulder_path: PackedVector2Array = PackedVector2Array([
	Vector2(68.0, 176.0), Vector2(236.0, 176.0),
	Vector2(403.0, 256.0), Vector2(454.0, 256.0),
	Vector2(708.0, 336.0), Vector2(734.0, 336.0),
	Vector2(989.0, 411.0), Vector2(1029.0, 411.0),
	Vector2(1283.0, 481.0), Vector2(1310.0, 481.0),
	Vector2(1410.0, 516.0), Vector2(1518.0, 516.0),
	Vector2(1664.0, 531.0), Vector2(1698.0, 531.0),
	Vector2(1854.0, 521.0), Vector2(1992.0, 521.0),
])

const CAVE_WORLD_WIDTH := 4700.0
const CAVE_PLATFORMS: Array[Rect2] = [
	Rect2(-80.0, 590.0, 600.0, 150.0),
	Rect2(610.0, 550.0, 340.0, 190.0),
	Rect2(1050.0, 505.0, 360.0, 235.0),
	Rect2(1510.0, 465.0, 350.0, 275.0),
	Rect2(1970.0, 415.0, 340.0, 325.0),
	Rect2(2410.0, 370.0, 330.0, 370.0),
	Rect2(2840.0, 330.0, 460.0, 410.0),
	Rect2(3400.0, 285.0, 330.0, 455.0),
	Rect2(3830.0, 240.0, 330.0, 500.0),
	Rect2(4260.0, 195.0, 440.0, 545.0),
]
const CAVE_CHEST := Rect2(170.0, 516.0, 92.0, 74.0)
const CAVE_CHEST_INTERACTION := Rect2(126.0, 466.0, 180.0, 140.0)
const CAVE_START_POSITION := Vector2(88.0, 536.0)
const CAVE_SHIELD_CHECKPOINT := Vector2(330.0, 536.0)
const CAVE_SHIELD_GATE_X := 315.0
const CAVE_EXIT_X := 4570.0
const CAVE_ROLLING_SOURCE_X := 4100.0
const CAVE_ROLLING_INITIAL_DELAY := 0.45
const CAVE_ROLLING_BASE_INTERVAL := 2.35
const CAVE_ROLLING_MIN_INTERVAL := 1.55
const CAVE_ROLLING_PATTERN: Array[String] = ["small", "small", "large", "small", "large"]
const CAVE_ARROW_LAUNCHER := Vector2(1832.0, 437.0)
const CAVE_ARROW_LAUNCHER_HITBOX := Rect2(1790.0, 390.0, 82.0, 92.0)
const CAVE_ARROW_TRIGGER := Rect2(1460.0, 350.0, 430.0, 145.0)
const CAVE_MID_CHECKPOINT_ZONE := Rect2(1985.0, 335.0, 175.0, 100.0)
const CAVE_MID_CHECKPOINT_POSITION := Vector2(2035.0, 361.0)
const CAVE_ARROW_INTERVAL := 0.72
const CAVE_ARROW_SPEED := 455.0
const CAVE_ROLLING_ACCELERATION := 14.0
const SHIELD_HOLD_THRESHOLD := 0.20
const SHIELD_PARRY_DURATION := 0.20
const SHIELD_SHATTER_DURATION := 0.48

enum Room { LEVEL_02_CLIFFS = 4, LEVEL_02_ROPEWAY = 5, LEVEL_02_CAVE = 6, LEVEL_02_COMPLETE = 7 }


var game_context
var player_position: Vector2:
	get: return game_context.player_position
	set(value): game_context.player_position = value
var player_velocity: Vector2:
	get: return game_context.player_velocity
	set(value): game_context.player_velocity = value
var player_facing: float:
	get: return game_context.player_facing
	set(value): game_context.player_facing = value
var on_ground: bool:
	get: return game_context.on_ground
	set(value): game_context.on_ground = value
var coyote_time: float:
	get: return game_context.coyote_time
	set(value): game_context.coyote_time = value
var jump_buffer: float:
	get: return game_context.jump_buffer
	set(value): game_context.jump_buffer = value
var regular_jump_active: bool:
	get: return game_context.regular_jump_active
	set(value): game_context.regular_jump_active = value
var camera_axis: float:
	get: return game_context.camera_axis
	set(value): game_context.camera_axis = value
var failure_flash: float:
	get: return game_context.failure_flash
	set(value): game_context.failure_flash = value

var host
var room := Room.LEVEL_02_CLIFFS
var elapsed := 0.0
var room_intro_time := 4.0
var entry_fall_lock := 0.0
var checkpoint_position := Vector2.ZERO
var completion_time := 0.0
var ui_font: Font
var level2_slide_active := false
var ropeway_knots: Array[bool] = [false, false, false, false, false]
var ropeway_knot_count := 0
var ropeway_chase_state := "idle"
var ropeway_warning_time := 0.0
var ropeway_boulder_progress := 0.0
var ropeway_boulder_position := Vector2(68.0, 176.0)
var ropeway_boulder_angle := 0.0
var ropeway_boulder_speed: float = ROPEWAY_BOULDER_START_SPEED
var ropeway_boulder_fall_velocity := 0.0
var ropeway_failure_time := 0.0
var ropeway_failure_reason := ""
var ropeway_collect_time := 0.0
var ropeway_collect_origin := Vector2.ZERO
var ropeway_rope_installed := false
var ropeway_climb_time := 0.0
var ropeway_status_text := ""
var ropeway_status_time := 0.0
var cave_chest_open := false
var shield_acquired := false
var shield_pickup_time := 0.0
var shield_input_active := false
var shield_press_time := 0.0
var shield_guarding := false
var shield_parry_time := 0.0
var shield_parry_hit_time := 0.0
var shield_block_hit_time := 0.0
var cave_rolling_rocks: Array[Dictionary] = []
var cave_falling_rocks: Array[Dictionary] = []
var cave_arrows: Array[Dictionary] = []
var cave_dust_puffs: Array[Dictionary] = []
var cave_rolling_spawn_timer := CAVE_ROLLING_INITIAL_DELAY
var cave_rolling_spawn_count := 0
var cave_drop_event_index := 0
var cave_arrow_launcher_destroyed := false
var cave_mid_checkpoint_active := false
var cave_failure_time := 0.0
var cave_failure_reason := ""
var cave_status_text := ""
var cave_status_time := 0.0
var cave_tutorial_time := 0.0
var cave_entry_fade_time := 0.0
var cave_arrow_timer := 0.58
var cave_rock_impact_time := 0.0
var cave_rock_impact_strength := 0.0


func enter(context, font: Font, game_host) -> void:
	game_context = context
	ui_font = font
	host = game_host
	visible = true
	reset()

func leave() -> void:
	visible = false

func reset() -> void:
	room = Room.LEVEL_02_CLIFFS
	player_position = Vector2(150.0, 400.0 - PLAYER_SIZE.y)
	player_velocity = Vector2.ZERO
	checkpoint_position = player_position
	camera_axis = 0.0
	room_intro_time = 4.0
	entry_fall_lock = 0.0
	failure_flash = 0.0
	completion_time = 0.0
	level2_slide_active = false
	on_ground = false
	regular_jump_active = false
	queue_redraw()

func restart_current() -> void:
	match room:
		Room.LEVEL_02_CLIFFS:
			player_position = Vector2(150.0, 400.0 - PLAYER_SIZE.y)
			checkpoint_position = player_position
			camera_axis = 0.0
			level2_slide_active = false
		Room.LEVEL_02_ROPEWAY:
			player_position = Vector2(115.0, ROPEWAY_PLATFORMS[0].position.y - PLAYER_SIZE.y)
			checkpoint_position = player_position
			camera_axis = 0.0
			entry_fall_lock = 0.0
			_reset_ropeway_attempt()
		Room.LEVEL_02_CAVE, Room.LEVEL_02_COMPLETE:
			room = Room.LEVEL_02_CAVE
			_reset_cave_attempt(true)
	player_velocity = Vector2.ZERO
	on_ground = false
	regular_jump_active = false
	ropeway_failure_time = 0.0
	failure_flash = 0.18
	queue_redraw()

func physics_tick(delta: float) -> void:
	elapsed += delta
	room_intro_time = maxf(0.0, room_intro_time - delta)
	entry_fall_lock = maxf(0.0, entry_fall_lock - delta)
	failure_flash = maxf(0.0, failure_flash - delta)
	ropeway_collect_time = maxf(0.0, ropeway_collect_time - delta)
	ropeway_status_time = maxf(0.0, ropeway_status_time - delta)
	shield_pickup_time = maxf(0.0, shield_pickup_time - delta)
	shield_parry_hit_time = maxf(0.0, shield_parry_hit_time - delta)
	shield_block_hit_time = maxf(0.0, shield_block_hit_time - delta)
	cave_status_time = maxf(0.0, cave_status_time - delta)
	cave_tutorial_time = maxf(0.0, cave_tutorial_time - delta)
	cave_entry_fade_time = maxf(0.0, cave_entry_fade_time - delta)
	cave_rock_impact_time = maxf(0.0, cave_rock_impact_time - delta)
	match room:
		Room.LEVEL_02_CLIFFS: _update_level_02_cliffs(delta)
		Room.LEVEL_02_ROPEWAY: _update_level_02_ropeway(delta)
		Room.LEVEL_02_CAVE: _update_level_02_cave(delta)
		Room.LEVEL_02_COMPLETE: _update_level_02_complete(delta)
	queue_redraw()

func sync_environment(_env_fx: Node2D) -> void:
	pass

func presentation_state() -> Dictionary:
	return {"active": false}

func _draw() -> void:
	draw_world()
	_draw_player()
	if room == Room.LEVEL_02_ROPEWAY and ropeway_knot_count > 0 and not ropeway_rope_installed: _draw_ropeway_held_coil()
	if room == Room.LEVEL_02_ROPEWAY and ropeway_failure_time > 0.0: _draw_ropeway_failure_effect()
	if room == Room.LEVEL_02_CAVE and cave_failure_time > 0.0: _draw_cave_failure_effect()
	draw_ui()
	if cave_entry_fade_time > 0.0 and (room == Room.LEVEL_02_CAVE or room == Room.LEVEL_02_COMPLETE):
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(INK, clampf(cave_entry_fade_time / 0.85, 0.0, 1.0)))
	if failure_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(INK, failure_flash * 0.7))

func draw_world() -> void:
	match room:
		Room.LEVEL_02_CLIFFS: _draw_level_02_cliffs()
		Room.LEVEL_02_ROPEWAY: _draw_level_02_ropeway()
		_: _draw_level_02_cave()

func draw_ui() -> void:
	draw_string(ui_font, Vector2(28.0, 36.0), "INKFALL · 1-02 风化绳崖", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, INK)
	draw_string(ui_font, Vector2(28.0, 64.0), _room_name(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(INK, 0.62))
	var controls := "A / D 移动　Space 跳跃　T 重置"
	if room == Room.LEVEL_02_ROPEWAY: controls = "A / D 移动　Space 跳跃　F 收绳 / 架绳　T 重置"
	elif room == Room.LEVEL_02_CAVE or room == Room.LEVEL_02_COMPLETE: controls = "A / D 移动　Space 跳跃　R 短按盾反 / 长按举盾　T 重置"
	draw_string(ui_font, Vector2(28.0, 694.0), controls, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(INK, 0.64))
	if room == Room.LEVEL_02_ROPEWAY:
		draw_string(ui_font, Vector2(1080.0, 42.0), "长绳：%d / %d" % [ropeway_knot_count, ROPEWAY_KNOTS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, HEMP)
		if ropeway_status_time > 0.0 and ropeway_status_text != "":
			_draw_center_status(ropeway_status_text, Color(INK, clampf(ropeway_status_time, 0.0, 1.0)))
	elif room == Room.LEVEL_02_CAVE or room == Room.LEVEL_02_COMPLETE:
		var shield_text := "盾牌：已取得" if shield_acquired else "盾牌：未取得"
		draw_string(ui_font, Vector2(1085.0, 42.0), shield_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, GOLD if shield_acquired else MID)
		if cave_tutorial_time > 0.0:
			var alpha := clampf(cave_tutorial_time, 0.0, 1.0)
			var panel := Rect2(330.0, 252.0, 620.0, 174.0)
			draw_rect(panel, Color(PAPER, alpha * 0.94)); draw_rect(panel, Color(INK, alpha), false, 4.0)
			_draw_centered("获得盾牌", 302.0, 28, Color(GOLD, alpha))
			_draw_centered("短按 R：挥盾盾反，击碎迎面滚石", 350.0, 19, Color(INK, alpha))
			_draw_centered("长按 R：持续举盾，抵挡横向飞箭", 386.0, 19, Color(INK, alpha))
		elif cave_status_time > 0.0 and cave_status_text != "":
			_draw_center_status(cave_status_text, Color(GOLD, clampf(cave_status_time, 0.0, 1.0)))
	if room_intro_time > 0.0:
		_draw_centered(_room_intro_text(), 118.0, 22, Color(INK, clampf(room_intro_time, 0.0, 1.0) * 0.85))
	if room == Room.LEVEL_02_COMPLETE and completion_time > 0.45:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(PAPER, 0.88))
		_draw_centered("第二关灰盒完成", 330.0, 42, INK)
		_draw_centered("穿过盾行山洞，你抵达了对岸木屋的篝火。按 F 进入木屋。", 372.0, 18, Color(INK, 0.68))

func _draw_center_status(text: String, color: Color) -> void:
	_draw_centered(text, 105.0, 20, color)

func _draw_centered(text: String, y: float, size: int, color: Color) -> void:
	var width := ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(ui_font, Vector2((SCREEN.x - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)

func _room_name() -> String:
	match room:
		Room.LEVEL_02_CLIFFS: return "A · 双崖上层"
		Room.LEVEL_02_ROPEWAY: return "E · 风化绳道"
		Room.LEVEL_02_CAVE: return "F · 盾行山洞"
		_: return "G · 木屋外缘"

func _room_intro_text() -> String:
	match room:
		Room.LEVEL_02_CLIFFS: return "对岸的火还亮着；道路藏在左侧悬崖下方。"
		Room.LEVEL_02_ROPEWAY: return "收起沿途长绳；身后的滚石不会等你。"
		_: return "洞口的宝箱仍在发光；山路一直通向对岸的火。"

func _world_to_screen(world_position: Vector2) -> Vector2:
	if room == Room.LEVEL_02_ROPEWAY: return world_position - Vector2(camera_axis, 0.0) + _ropeway_screen_shake_offset()
	if room == Room.LEVEL_02_CAVE or room == Room.LEVEL_02_COMPLETE: return world_position - Vector2(camera_axis, 0.0) + _cave_screen_shake_offset()
	return world_position

func _world_rect_to_screen(world_rect: Rect2) -> Rect2:
	return Rect2(_world_to_screen(world_rect.position), world_rect.size)

func _draw_shared_hut_forecourt(base: Vector2, scale_factor: float, tree_hits_value: int, axe_state: String) -> void:
	host.draw_shared_hut_forecourt(self, base, scale_factor, tree_hits_value, axe_state, elapsed, 0.0)

func _enter_level_02_cliffs() -> void:
	room = Room.LEVEL_02_CLIFFS
	player_position = Vector2(150.0, 400.0 - PLAYER_SIZE.y)
	player_velocity = Vector2.ZERO
	checkpoint_position = player_position
	camera_axis = 0.0
	room_intro_time = 4.0
	entry_fall_lock = 0.0
	failure_flash = 0.0
	completion_time = 0.0
	level2_slide_active = false
	on_ground = false
	regular_jump_active = false

func _update_level_02_cliffs(delta: float) -> void:
	_update_player(delta, LEVEL2_CLIFF_PLATFORMS, Vector2(-20.0, 1280.0), not level2_slide_active)
	camera_axis = 0.0

	var foot_x: float = player_position.x + PLAYER_SIZE.x * 0.5
	if foot_x >= LEVEL2_SLOPE_START.x and foot_x <= LEVEL2_SLOPE_END.x:
		var slope_ratio: float = inverse_lerp(LEVEL2_SLOPE_START.x, LEVEL2_SLOPE_END.x, foot_x)
		var slope_y: float = lerpf(LEVEL2_SLOPE_START.y, LEVEL2_SLOPE_END.y, slope_ratio)
		var player_bottom: float = player_position.y + PLAYER_SIZE.y
		if level2_slide_active or (player_velocity.y >= 0.0 and player_bottom >= slope_y - 9.0 and player_bottom <= slope_y + 40.0):
			level2_slide_active = true
			player_position.y = slope_y - PLAYER_SIZE.y
			player_velocity.x = maxf(player_velocity.x, 315.0)
			player_velocity.y = 0.0
			player_facing = 1.0
			on_ground = true

	if level2_slide_active and (foot_x >= LEVEL2_SLOPE_END.x - 8.0 or player_position.y > 610.0):
		_enter_level_02_ropeway()
		return
	if player_position.y > SCREEN.y + 80.0:
		_fail_and_respawn()

func _fail_and_respawn() -> void:
	player_position = checkpoint_position
	player_velocity = Vector2.ZERO
	on_ground = false
	regular_jump_active = false
	level2_slide_active = false
	failure_flash = 0.32

func _enter_level_02_ropeway() -> void:
	room = Room.LEVEL_02_ROPEWAY
	player_position = Vector2(115.0, 78.0)
	player_velocity = Vector2(250.0, 470.0)
	checkpoint_position = Vector2(115.0, ROPEWAY_PLATFORMS[0].position.y - PLAYER_SIZE.y)
	camera_axis = 0.0
	room_intro_time = 3.2
	entry_fall_lock = 0.58
	on_ground = false
	regular_jump_active = false
	_reset_ropeway_attempt()

func _update_level_02_ropeway(delta: float) -> void:
	if ropeway_failure_time > 0.0:
		_update_ropeway_failure(delta)
		return
	if ropeway_rope_installed:
		_update_ropeway_climb(delta)
		return

	var previous_moving_platforms: Array[Rect2] = [_ropeway_moving_platform(elapsed - delta)]
	var moving_platforms: Array[Rect2] = [_ropeway_moving_platform(elapsed)]
	_carry_player_with_dynamic_platform(previous_moving_platforms, moving_platforms)
	var ropeway_collision_platforms: Array[Rect2] = []
	ropeway_collision_platforms.append_array(ROPEWAY_PLATFORMS)
	ropeway_collision_platforms.append_array(moving_platforms)
	_update_player(delta, ropeway_collision_platforms, Vector2(0.0, 2390.0), entry_fall_lock <= 0.0)
	camera_axis = clampf(player_position.x - 330.0, 0.0, 1110.0)
	_update_ropeway_chase(delta)
	_try_ropeway_interaction()

	var player_rect := Rect2(player_position, PLAYER_SIZE)
	if ropeway_chase_state == "rolling" or ropeway_chase_state == "jammed":
		if player_rect.intersects(_ropeway_boulder_rect()):
			_start_ropeway_failure("滚石追上了你")
			return
	if player_position.y > SCREEN.y + 70.0:
		_start_ropeway_failure("坠入深坑")

func _update_level_02_complete(delta: float) -> void:
	completion_time += delta
	player_velocity = Vector2.ZERO
	if completion_time > 0.45 and Input.is_action_just_pressed("interact"):
		completed.emit()

func _reset_ropeway_attempt() -> void:
	ropeway_knots = [false, false, false, false, false]
	ropeway_knot_count = 0
	ropeway_chase_state = "idle"
	ropeway_warning_time = 0.0
	ropeway_boulder_progress = 0.0
	ropeway_boulder_position = ropeway_boulder_path[0]
	ropeway_boulder_angle = 0.0
	ropeway_boulder_speed = ROPEWAY_BOULDER_START_SPEED
	ropeway_boulder_fall_velocity = 0.0
	ropeway_failure_time = 0.0
	ropeway_failure_reason = ""
	ropeway_collect_time = 0.0
	ropeway_collect_origin = Vector2.ZERO
	ropeway_rope_installed = false
	ropeway_climb_time = 0.0
	ropeway_status_text = ""
	ropeway_status_time = 0.0

func _update_ropeway_chase(delta: float) -> void:
	if ropeway_chase_state == "idle" and player_position.x + PLAYER_SIZE.x * 0.5 >= ROPEWAY_TRIGGER_X:
		ropeway_chase_state = "warning"
		ropeway_warning_time = 0.68
		ropeway_status_text = "身后的石槽开始震动"
		ropeway_status_time = 1.7
	elif ropeway_chase_state == "warning":
		ropeway_warning_time = maxf(0.0, ropeway_warning_time - delta)
		ropeway_boulder_position = ropeway_boulder_path[0] + Vector2(
			sin(elapsed * 28.0) * 3.0,
			absf(sin(elapsed * 19.0)) * 2.0
		)
		if ropeway_warning_time <= 0.0:
			ropeway_chase_state = "rolling"
	elif ropeway_chase_state == "rolling":
		var path_length: float = _ropeway_path_length()
		ropeway_boulder_speed = minf(
			ROPEWAY_BOULDER_MAX_SPEED,
			ropeway_boulder_speed + ROPEWAY_BOULDER_ACCELERATION * delta
		)
		ropeway_boulder_progress = minf(
			1.0,
			ropeway_boulder_progress + delta * ropeway_boulder_speed / path_length
		)
		ropeway_boulder_position = _point_on_ropeway_path(ropeway_boulder_progress)
		ropeway_boulder_angle += delta * ropeway_boulder_speed / ROPEWAY_BOULDER_RADIUS
		if ropeway_boulder_progress >= 0.999:
			ropeway_chase_state = "falling"
			ropeway_boulder_fall_velocity = 90.0
	elif ropeway_chase_state == "falling":
		ropeway_boulder_fall_velocity += GRAVITY * delta
		ropeway_boulder_position.y += ropeway_boulder_fall_velocity * delta
		ropeway_boulder_angle += delta * 8.4
		if ropeway_boulder_position.y > 820.0:
			ropeway_chase_state = "gone"

func _try_ropeway_interaction() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var active_knot: int = _active_ropeway_knot()
	if active_knot >= 0 and _can_collect_ropeway_knot(active_knot):
		ropeway_knots[active_knot] = true
		ropeway_knot_count += 1
		ropeway_collect_origin = ROPEWAY_KNOTS[active_knot].get_center()
		ropeway_collect_time = 0.48
		ropeway_status_text = "长绳 %d / 5" % ropeway_knot_count
		ropeway_status_time = 1.25
		return
	if active_knot >= 0 and ROPEWAY_KNOT_APEX_REQUIRED[active_knot] and _ropeway_knot_prompt_visible(active_knot):
		ropeway_status_text = "要在跳跃最高点收绳"
		ropeway_status_time = 0.9
		return

	var player_rect := Rect2(player_position, PLAYER_SIZE)
	if not player_rect.intersects(ROPEWAY_CLIMB_ZONE):
		return
	if ropeway_knot_count < ROPEWAY_KNOTS.size():
		ropeway_status_text = "绳子还不够长"
		ropeway_status_time = 1.4
		return
	ropeway_rope_installed = true
	ropeway_climb_time = 0.001
	player_position = Vector2(ROPEWAY_CLIMB_ANCHOR.x - PLAYER_SIZE.x * 0.5, 416.0)
	player_velocity = Vector2.ZERO
	on_ground = false
	ropeway_status_text = "抛出绳头"
	ropeway_status_time = 1.0

func _active_ropeway_knot() -> int:
	for index in range(ropeway_knots.size()):
		if not ropeway_knots[index]:
			return index
	return -1

func _can_collect_ropeway_knot(index: int) -> bool:
	var knot: Rect2 = ROPEWAY_KNOTS[index]
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	if ROPEWAY_KNOT_APEX_REQUIRED[index]:
		return (
			not on_ground
			and absf(player_velocity.y) <= 115.0
			and player_rect.intersects(_ropeway_apex_pickup_zone(index))
		)
	if ROPEWAY_KNOT_HANGING[index]:
		return player_rect.grow(10.0).intersects(knot)
	return player_rect.grow(12.0).intersects(knot) or (player_position + PLAYER_SIZE * 0.5).distance_to(knot.get_center()) < 62.0

func _ropeway_apex_pickup_zone(index: int) -> Rect2:
	var knot: Rect2 = ROPEWAY_KNOTS[index]
	# Keep the original vertical tolerance, but widen the horizontal reach so the
	# player can collect from either side of the jump instead of pixel-aligning.
	return Rect2(knot.position - Vector2(28.0, 7.0), knot.size + Vector2(56.0, 14.0))

func _ropeway_knot_prompt_visible(index: int) -> bool:
	if _can_collect_ropeway_knot(index):
		return true
	if not ROPEWAY_KNOT_HANGING[index]:
		return false
	var knot: Rect2 = ROPEWAY_KNOTS[index]
	var player_center: Vector2 = player_position + PLAYER_SIZE * 0.5
	var horizontal_prompt_reach: float = 72.0 if ROPEWAY_KNOT_APEX_REQUIRED[index] else 34.0
	return absf(player_center.x - knot.get_center().x) < horizontal_prompt_reach and player_center.y > knot.get_center().y

func _update_ropeway_climb(delta: float) -> void:
	ropeway_climb_time += delta
	_update_ropeway_chase(delta)
	var climb_ratio: float = clampf(ropeway_climb_time / 1.55, 0.0, 1.0)
	var climb_ease: float = smoothstep(0.0, 1.0, climb_ratio)
	player_position.x = ROPEWAY_CLIMB_ANCHOR.x - PLAYER_SIZE.x * 0.5 + sin(climb_ratio * TAU * 3.0) * 2.5
	player_position.y = lerpf(416.0, 138.0, climb_ease)
	player_velocity = Vector2.ZERO
	camera_axis = 1110.0
	if climb_ratio >= 1.0:
		_enter_level_02_cave()

func _start_ropeway_failure(reason: String) -> void:
	ropeway_failure_reason = reason
	ropeway_failure_time = 0.001
	player_velocity = Vector2(-player_facing * 150.0, -185.0)
	on_ground = false
	regular_jump_active = false

func _update_ropeway_failure(delta: float) -> void:
	ropeway_failure_time += delta
	player_velocity.y += GRAVITY * delta
	player_position += player_velocity * delta
	camera_axis = clampf(player_position.x - 330.0, 0.0, 1110.0)
	if ropeway_failure_time >= 0.78:
		player_position = checkpoint_position
		player_velocity = Vector2.ZERO
		camera_axis = 0.0
		entry_fall_lock = 0.0
		on_ground = false
		regular_jump_active = false
		failure_flash = 0.28
		_reset_ropeway_attempt()

func _ropeway_boulder_rect() -> Rect2:
	var diameter: float = ROPEWAY_BOULDER_RADIUS * 1.82
	return Rect2(
		ropeway_boulder_position - Vector2(diameter, diameter) * 0.5,
		Vector2(diameter, diameter)
	)

func _ropeway_path_length() -> float:
	var total: float = 0.0
	for index in range(ropeway_boulder_path.size() - 1):
		total += ropeway_boulder_path[index].distance_to(ropeway_boulder_path[index + 1])
	return maxf(total, 1.0)

func _point_on_ropeway_path(amount: float) -> Vector2:
	var remaining: float = clampf(amount, 0.0, 1.0) * _ropeway_path_length()
	for index in range(ropeway_boulder_path.size() - 1):
		var start: Vector2 = ropeway_boulder_path[index]
		var finish: Vector2 = ropeway_boulder_path[index + 1]
		var span: float = start.distance_to(finish)
		if remaining <= span or index == ropeway_boulder_path.size() - 2:
			var ratio: float = 0.0 if span <= 0.001 else remaining / span
			return start.lerp(finish, clampf(ratio, 0.0, 1.0))
		remaining -= span
	return ropeway_boulder_path[ropeway_boulder_path.size() - 1]

func _ropeway_moving_platform(sample_time: float) -> Rect2:
	return Rect2(1435.0 + sin(sample_time * 1.45) * 65.0, 560.0, 48.0, 20.0)

func _enter_level_02_cave() -> void:
	room = Room.LEVEL_02_CAVE
	cave_chest_open = false
	shield_acquired = false
	_reset_cave_attempt(false)
	room_intro_time = 4.2
	cave_entry_fade_time = 0.85

func _reset_cave_attempt(preserve_shield: bool) -> void:
	var keep_mid_checkpoint: bool = preserve_shield and cave_mid_checkpoint_active
	if not preserve_shield:
		cave_chest_open = false
		shield_acquired = false
		cave_mid_checkpoint_active = false
	if keep_mid_checkpoint:
		player_position = CAVE_MID_CHECKPOINT_POSITION
	elif shield_acquired:
		player_position = CAVE_SHIELD_CHECKPOINT
	else:
		player_position = CAVE_START_POSITION
	checkpoint_position = player_position
	player_velocity = Vector2.ZERO
	player_facing = 1.0
	on_ground = false
	regular_jump_active = false
	camera_axis = clampf(player_position.x - 390.0, 0.0, CAVE_WORLD_WIDTH - SCREEN.x)
	shield_pickup_time = 0.0
	shield_input_active = false
	shield_press_time = 0.0
	shield_guarding = false
	shield_parry_time = 0.0
	shield_parry_hit_time = 0.0
	shield_block_hit_time = 0.0
	cave_rolling_rocks.clear()
	cave_falling_rocks.clear()
	cave_arrows.clear()
	cave_dust_puffs.clear()
	cave_rolling_spawn_timer = CAVE_ROLLING_INITIAL_DELAY
	cave_rolling_spawn_count = 0
	cave_drop_event_index = 0
	if keep_mid_checkpoint:
		var drop_schedule: Array[Dictionary] = _cave_drop_schedule()
		while (
			cave_drop_event_index < drop_schedule.size()
			and float(drop_schedule[cave_drop_event_index]["trigger_x"]) <= CAVE_MID_CHECKPOINT_POSITION.x
		):
			cave_drop_event_index += 1
	cave_arrow_launcher_destroyed = keep_mid_checkpoint
	cave_failure_time = 0.0
	cave_failure_reason = ""
	cave_status_text = ""
	cave_status_time = 0.0
	cave_tutorial_time = 0.0
	cave_arrow_timer = 0.58
	cave_rock_impact_time = 0.0
	cave_rock_impact_strength = 0.0

func _update_level_02_cave(delta: float) -> void:
	if cave_failure_time > 0.0:
		_update_cave_failure(delta)
		return

	_update_player(delta, CAVE_PLATFORMS, Vector2(-20.0, CAVE_WORLD_WIDTH), true)
	camera_axis = clampf(player_position.x - 390.0, 0.0, CAVE_WORLD_WIDTH - SCREEN.x)

	if not shield_acquired:
		player_position.x = minf(player_position.x, CAVE_SHIELD_GATE_X)
		if player_velocity.x > 0.0 and player_position.x >= CAVE_SHIELD_GATE_X:
			player_velocity.x = 0.0
		_try_open_cave_chest()
	else:
		_update_shield_action(delta)
		_update_cave_mid_checkpoint()
		if shield_pickup_time <= 0.35:
			_update_cave_rolling_source(delta)
			_trigger_cave_drop_hazards()

	_update_cave_rolling_rocks(delta)
	_update_cave_falling_rocks(delta)
	_update_cave_arrow_trap(delta)
	_update_cave_dust(delta)
	_resolve_cave_hazard_collisions()
	if cave_failure_time > 0.0:
		return

	if player_position.y > SCREEN.y + 90.0:
		_start_cave_failure("坠入断崖")
		return
	if player_position.x + PLAYER_SIZE.x * 0.5 >= CAVE_EXIT_X:
		room = Room.LEVEL_02_COMPLETE
		completion_time = 0.0
		player_velocity = Vector2.ZERO

func _try_open_cave_chest() -> void:
	if cave_chest_open or not Input.is_action_just_pressed("interact"):
		return
	if not Rect2(player_position, PLAYER_SIZE).intersects(CAVE_CHEST_INTERACTION):
		return
	cave_chest_open = true
	shield_acquired = true
	shield_pickup_time = 0.95
	checkpoint_position = CAVE_SHIELD_CHECKPOINT
	cave_status_text = "获得盾牌"
	cave_status_time = 1.7
	cave_tutorial_time = 4.6

func _update_cave_mid_checkpoint() -> void:
	if cave_mid_checkpoint_active or not on_ground:
		return
	var player_rect: Rect2 = Rect2(player_position, PLAYER_SIZE)
	if not player_rect.intersects(CAVE_MID_CHECKPOINT_ZONE):
		return
	cave_mid_checkpoint_active = true
	checkpoint_position = CAVE_MID_CHECKPOINT_POSITION
	cave_arrow_launcher_destroyed = true
	cave_status_text = "山洞中段检查点已记录"
	cave_status_time = 2.0

func _update_shield_action(delta: float) -> void:
	shield_parry_time = maxf(0.0, shield_parry_time - delta)
	if Input.is_action_just_pressed("shield"):
		shield_input_active = true
		shield_press_time = 0.0
		shield_guarding = false
	if not shield_input_active:
		return
	if Input.is_action_pressed("shield"):
		shield_press_time += delta
		if shield_press_time >= SHIELD_HOLD_THRESHOLD:
			shield_guarding = true
		return
	if not shield_guarding:
		shield_parry_time = SHIELD_PARRY_DURATION
	shield_input_active = false
	shield_press_time = 0.0
	shield_guarding = false

func _update_cave_rolling_source(delta: float) -> void:
	cave_rolling_spawn_timer -= delta
	while cave_rolling_spawn_timer <= 0.0:
		var pattern_index: int = cave_rolling_spawn_count % CAVE_ROLLING_PATTERN.size()
		var kind: String = CAVE_ROLLING_PATTERN[pattern_index]
		var launch_speed: float = 455.0 if kind == "large" else 500.0
		_spawn_cave_rolling_rock(kind, CAVE_ROLLING_SOURCE_X, launch_speed, true)
		cave_rolling_spawn_count += 1
		var next_interval: float = maxf(
			CAVE_ROLLING_MIN_INTERVAL,
			CAVE_ROLLING_BASE_INTERVAL - float(cave_rolling_spawn_count) * 0.055
		)
		cave_rolling_spawn_timer += next_interval

func _trigger_cave_drop_hazards() -> void:
	var drop_schedule: Array[Dictionary] = _cave_drop_schedule()
	while cave_drop_event_index < drop_schedule.size():
		var drop_event: Dictionary = drop_schedule[cave_drop_event_index]
		if player_position.x < float(drop_event["trigger_x"]):
			break
		_spawn_cave_falling_rock(float(drop_event["drop_x"]), float(drop_event["warning_time"]))
		cave_drop_event_index += 1

func _cave_drop_schedule() -> Array[Dictionary]:
	return [
		{"trigger_x": 420.0, "drop_x": 565.0, "warning_time": 0.72},
		{"trigger_x": 850.0, "drop_x": 1000.0, "warning_time": 0.66},
		{"trigger_x": 1305.0, "drop_x": 1460.0, "warning_time": 0.62},
		{"trigger_x": 1745.0, "drop_x": 1915.0, "warning_time": 0.58},
		{"trigger_x": 2185.0, "drop_x": 2360.0, "warning_time": 0.55},
		{"trigger_x": 2610.0, "drop_x": 2790.0, "warning_time": 0.52},
		{"trigger_x": 3060.0, "drop_x": 3350.0, "warning_time": 0.50},
		{"trigger_x": 3500.0, "drop_x": 3780.0, "warning_time": 0.48},
		{"trigger_x": 3930.0, "drop_x": 4210.0, "warning_time": 0.46},
	]

func _spawn_cave_rolling_rock(kind: String, spawn_x: float, speed: float, drop_from_source: bool) -> void:
	var radius: float = 64.0 if kind == "large" else 22.0
	var floor_y: float = _cave_platform_floor_y(spawn_x)
	cave_rolling_rocks.append({
		"kind": kind,
		"position": Vector2(spawn_x, 42.0 if drop_from_source else floor_y - radius),
		"speed": speed,
		"radius": radius,
		"angle": 0.0,
		"state": "falling" if drop_from_source else "rolling",
		"fall_velocity": 0.0,
		"shatter_time": 0.0,
	})

func _spawn_cave_falling_rock(drop_x: float, warning_time: float) -> void:
	cave_falling_rocks.append({
		"position": Vector2(drop_x, 72.0),
		"radius": 25.0,
		"state": "warning",
		"warning_time": warning_time,
		"fall_velocity": 0.0,
		"angle": 0.0,
	})

func _update_cave_rolling_rocks(delta: float) -> void:
	for index in range(cave_rolling_rocks.size()):
		var rock: Dictionary = cave_rolling_rocks[index]
		var state: String = String(rock["state"])
		if state == "rolling":
			var speed: float = float(rock["speed"]) + CAVE_ROLLING_ACCELERATION * delta
			var radius: float = float(rock["radius"])
			var position_value: Vector2 = rock["position"]
			position_value.x -= speed * delta
			var floor_y: float = _cave_platform_floor_y(position_value.x)
			if floor_y < SCREEN.y:
				position_value.y = floor_y - radius
			else:
				rock["state"] = "falling"
				rock["fall_velocity"] = 0.0
			rock["speed"] = speed
			rock["position"] = position_value
			rock["angle"] = float(rock["angle"]) - speed * delta / radius
		elif state == "falling":
			var radius: float = float(rock["radius"])
			var speed: float = float(rock["speed"]) + CAVE_ROLLING_ACCELERATION * delta
			var falling_position: Vector2 = rock["position"]
			var previous_bottom: float = falling_position.y + radius
			var fall_velocity: float = float(rock["fall_velocity"]) + GRAVITY * delta
			falling_position.x -= speed * delta
			falling_position.y += fall_velocity * delta
			var floor_y: float = _cave_platform_floor_y(falling_position.x)
			var new_bottom: float = falling_position.y + radius
			var landing_tolerance: float = maxf(16.0, radius * 0.42)
			if (
				floor_y < SCREEN.y
				and previous_bottom <= floor_y + 8.0
				and new_bottom >= floor_y
				and new_bottom <= floor_y + landing_tolerance
			):
				falling_position.y = floor_y - radius
				rock["state"] = "rolling"
				rock["fall_velocity"] = 0.0
				_spawn_cave_dust(Vector2(falling_position.x, floor_y), radius)
			else:
				rock["fall_velocity"] = fall_velocity
			rock["position"] = falling_position
			rock["speed"] = speed
			rock["angle"] = float(rock["angle"]) - speed * delta / radius
			if falling_position.y > 820.0 or falling_position.x < -140.0:
				rock["state"] = "gone"
		elif state == "shattered":
			var shatter_time: float = maxf(0.0, float(rock["shatter_time"]) - delta)
			rock["shatter_time"] = shatter_time
			if shatter_time <= 0.0:
				rock["state"] = "gone"
		cave_rolling_rocks[index] = rock

func _update_cave_falling_rocks(delta: float) -> void:
	for index in range(cave_falling_rocks.size()):
		var rock: Dictionary = cave_falling_rocks[index]
		var state: String = String(rock["state"])
		if state == "warning":
			var warning_time: float = maxf(0.0, float(rock["warning_time"]) - delta)
			rock["warning_time"] = warning_time
			if warning_time <= 0.0:
				rock["state"] = "falling"
				rock["fall_velocity"] = 90.0
		elif state == "falling":
			var position_value: Vector2 = rock["position"]
			var fall_velocity: float = float(rock["fall_velocity"]) + GRAVITY * delta
			position_value.y += fall_velocity * delta
			rock["position"] = position_value
			rock["fall_velocity"] = fall_velocity
			rock["angle"] = float(rock["angle"]) + delta * 8.0
			if position_value.y > 820.0:
				rock["state"] = "gone"
		cave_falling_rocks[index] = rock

func _spawn_cave_dust(impact_position: Vector2, rock_radius: float) -> void:
	var dust_scale: float = clampf(rock_radius / 32.0, 0.75, 2.1)
	cave_dust_puffs.append({
		"position": impact_position,
		"time": 0.62,
		"scale": dust_scale,
	})
	if cave_rock_impact_time <= 0.0:
		cave_rock_impact_strength = 0.0
	var viewport_center_x: float = camera_axis + SCREEN.x * 0.5
	var visibility: float = clampf(1.0 - absf(impact_position.x - viewport_center_x) / 900.0, 0.0, 1.0)
	if visibility > 0.0:
		cave_rock_impact_time = 0.20
		cave_rock_impact_strength = maxf(cave_rock_impact_strength, dust_scale * visibility)

func _update_cave_dust(delta: float) -> void:
	for index in range(cave_dust_puffs.size() - 1, -1, -1):
		var puff: Dictionary = cave_dust_puffs[index]
		var remaining: float = float(puff["time"]) - delta
		if remaining <= 0.0:
			cave_dust_puffs.remove_at(index)
			continue
		puff["time"] = remaining
		cave_dust_puffs[index] = puff

func _update_cave_arrow_trap(delta: float) -> void:
	var player_center: Vector2 = player_position + PLAYER_SIZE * 0.5
	if not cave_arrow_launcher_destroyed and shield_acquired and CAVE_ARROW_TRIGGER.has_point(player_center):
		cave_arrow_timer -= delta
		if cave_arrow_timer <= 0.0:
			cave_arrows.append({
				"position": CAVE_ARROW_LAUNCHER,
				"state": "flying",
			})
			cave_arrow_timer = CAVE_ARROW_INTERVAL
	elif player_center.x < CAVE_ARROW_TRIGGER.position.x:
		cave_arrow_timer = minf(cave_arrow_timer, 0.58)

	for index in range(cave_arrows.size()):
		var arrow: Dictionary = cave_arrows[index]
		if String(arrow["state"]) != "flying":
			continue
		var arrow_position: Vector2 = arrow["position"]
		arrow_position.x -= CAVE_ARROW_SPEED * delta
		arrow["position"] = arrow_position
		if arrow_position.x < 1410.0:
			arrow["state"] = "gone"
		cave_arrows[index] = arrow

func _resolve_cave_hazard_collisions() -> void:
	var player_rect: Rect2 = Rect2(player_position, PLAYER_SIZE).grow(-2.0)
	var parry_rect: Rect2 = _shield_parry_rect()
	var guard_rect: Rect2 = _shield_guard_rect()
	if (
		not cave_arrow_launcher_destroyed
		and shield_parry_time > 0.0
		and parry_rect.intersects(CAVE_ARROW_LAUNCHER_HITBOX)
	):
		cave_arrow_launcher_destroyed = true
		shield_parry_time = 0.0
		shield_parry_hit_time = 0.30
		cave_status_text = "弩机已摧毁"
		cave_status_time = 1.35
	for index in range(cave_rolling_rocks.size()):
		var rock: Dictionary = cave_rolling_rocks[index]
		var rock_state: String = String(rock["state"])
		if rock_state != "rolling" and rock_state != "falling":
			continue
		var rock_rect: Rect2 = _cave_rock_rect(rock)
		if shield_parry_time > 0.0 and parry_rect.intersects(rock_rect):
			rock["state"] = "shattered"
			rock["shatter_time"] = SHIELD_SHATTER_DURATION
			cave_rolling_rocks[index] = rock
			shield_parry_time = 0.0
			shield_parry_hit_time = 0.30
			continue
		if player_rect.intersects(rock_rect):
			_start_cave_failure("举盾挡不住滚石" if shield_guarding else "被滚石撞倒")
			return

	for rock in cave_falling_rocks:
		if String(rock["state"]) != "falling":
			continue
		if player_rect.intersects(_cave_rock_rect(rock)):
			_start_cave_failure("被头顶落石砸中")
			return

	for index in range(cave_arrows.size()):
		var arrow: Dictionary = cave_arrows[index]
		if String(arrow["state"]) != "flying":
			continue
		var arrow_position: Vector2 = arrow["position"]
		var arrow_rect: Rect2 = Rect2(arrow_position - Vector2(24.0, 4.0), Vector2(48.0, 8.0))
		if shield_guarding and guard_rect.intersects(arrow_rect):
			arrow["state"] = "gone"
			cave_arrows[index] = arrow
			shield_block_hit_time = 0.16
			continue
		if player_rect.intersects(arrow_rect):
			_start_cave_failure("飞箭需要持续举盾")
			return

func _cave_platform_floor_y(world_x: float) -> float:
	for platform_rect in CAVE_PLATFORMS:
		if world_x >= platform_rect.position.x and world_x <= platform_rect.end.x:
			return platform_rect.position.y
	return 760.0

func _cave_rock_rect(rock: Dictionary) -> Rect2:
	var radius: float = float(rock["radius"])
	var position_value: Vector2 = rock["position"]
	return Rect2(position_value - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))

func _shield_parry_rect() -> Rect2:
	var center: Vector2 = player_position + PLAYER_SIZE * 0.5
	if player_facing >= 0.0:
		return Rect2(center + Vector2(5.0, -48.0), Vector2(78.0, 96.0))
	return Rect2(center + Vector2(-83.0, -48.0), Vector2(78.0, 96.0))

func _shield_guard_rect() -> Rect2:
	var center: Vector2 = player_position + PLAYER_SIZE * 0.5
	if player_facing >= 0.0:
		return Rect2(center + Vector2(4.0, -36.0), Vector2(46.0, 72.0))
	return Rect2(center + Vector2(-50.0, -36.0), Vector2(46.0, 72.0))

func _start_cave_failure(reason: String) -> void:
	if cave_failure_time > 0.0:
		return
	cave_failure_time = 0.001
	cave_failure_reason = reason
	shield_input_active = false
	shield_guarding = false
	shield_parry_time = 0.0
	player_velocity = Vector2(-player_facing * 145.0, -210.0)
	on_ground = false
	regular_jump_active = false

func _update_cave_failure(delta: float) -> void:
	cave_failure_time += delta
	player_velocity.y += GRAVITY * delta
	player_position += player_velocity * delta
	camera_axis = clampf(player_position.x - 390.0, 0.0, CAVE_WORLD_WIDTH - SCREEN.x)
	if cave_failure_time >= 0.78:
		_reset_cave_attempt(true)
		failure_flash = 0.28

func _update_player(delta: float, platform_list: Array[Rect2], horizontal_bounds: Vector2, allow_input: bool) -> void:
	host.update_shared_player(game_context, delta, platform_list, horizontal_bounds, allow_input)

func _carry_player_with_dynamic_platform(previous_rects: Array[Rect2], current_rects: Array[Rect2]) -> void:
	host.carry_shared_player(game_context, previous_rects, current_rects)

func _draw_player() -> void:
	var p := _world_to_screen(player_position)
	var center_x := p.x + PLAYER_SIZE.x * 0.5
	var walk_phase := sin(elapsed * 12.0) if absf(player_velocity.x) > 25.0 and on_ground else 0.0
	var head_center := Vector2(center_x, p.y + 15.0)
	var in_cellar := false
	var body_ink: Color = PAPER if in_cellar else INK
	var body_fill: Color = Color("111617") if in_cellar else PAPER

	draw_line(Vector2(center_x - 3.0, p.y + 40.0), Vector2(center_x - 7.0 - walk_phase * 5.0, p.y + 54.0), body_ink, 3.0, true)
	draw_line(Vector2(center_x + 3.0, p.y + 40.0), Vector2(center_x + 7.0 + walk_phase * 5.0, p.y + 54.0), body_ink, 3.0, true)
	var cloak := PackedVector2Array([
		Vector2(center_x, p.y + 24.0),
		Vector2(center_x - 12.0, p.y + 45.0),
		Vector2(center_x + 12.0, p.y + 45.0),
	])
	draw_polygon(cloak, PackedColorArray([body_fill]))
	draw_polyline(cloak, body_ink, 3.0, true)
	draw_circle(head_center, 9.5, body_fill, true, -1.0, true)
	draw_circle(head_center, 9.5, body_ink, false, 3.0, true)

	var look := player_facing
	draw_circle(head_center + Vector2(look * 3.0, -1.0), 1.2, body_ink)
	var hat := PackedVector2Array([
		Vector2(center_x - 14.0, p.y + 8.0),
		Vector2(center_x + 14.0, p.y + 8.0),
		Vector2(center_x - 2.0, p.y - 13.0),
		Vector2(center_x + 1.0, p.y + 2.0),
	])
	draw_polygon(hat, PackedColorArray([body_fill if in_cellar else INK]))
	if in_cellar:
		var hat_outline: PackedVector2Array = hat.duplicate()
		hat_outline.append(hat[0])
		draw_polyline(hat_outline, body_ink, 2.5, true)
	draw_line(Vector2(center_x - 16.0, p.y + 8.0), Vector2(center_x + 16.0, p.y + 8.0), body_ink, 4.0, true)

	var shoulder := Vector2(center_x, p.y + 29.0)
	if true:
		draw_line(shoulder, shoulder + Vector2(player_facing * 13.0, 8.0 + walk_phase * 2.0), body_ink, 3.0, true)
		draw_line(shoulder, shoulder + Vector2(-player_facing * 10.0, 7.0 - walk_phase * 2.0), body_ink, 3.0, true)
	if (room == Room.LEVEL_02_CAVE or room == Room.LEVEL_02_COMPLETE) and shield_acquired:
		_draw_player_shield(p)

func _draw_level_02_cliffs() -> void:
	_draw_far_hills()
	draw_polygon(PackedVector2Array([
		Vector2(0.0, 400.0),
		LEVEL2_SLOPE_START,
		LEVEL2_SLOPE_END,
		Vector2(760.0, SCREEN.y),
		Vector2(0.0, SCREEN.y),
	]), PackedColorArray([INK]))
	draw_line(Vector2(0.0, 400.0), LEVEL2_SLOPE_START, PAPER, 4.0, true)
	draw_line(LEVEL2_SLOPE_START, LEVEL2_SLOPE_END, PAPER, 5.0, true)
	for mark_index in range(7):
		var mark_ratio: float = (float(mark_index) + 0.5) / 7.0
		var mark: Vector2 = LEVEL2_SLOPE_START.lerp(LEVEL2_SLOPE_END, mark_ratio)
		draw_line(mark + Vector2(-7.0, 8.0), mark + Vector2(13.0, 21.0), Color(PAPER, 0.35), 2.0, true)

	draw_polygon(PackedVector2Array([
		Vector2(770.0, 430.0), Vector2(1280.0, 430.0),
		Vector2(1280.0, 720.0), Vector2(960.0, 720.0),
		Vector2(975.0, 555.0),
	]), PackedColorArray([INK]))
	draw_line(Vector2(770.0, 430.0), Vector2(1280.0, 430.0), PAPER, 4.0, true)
	_draw_shared_hut_forecourt(Vector2(1158.0, 430.0), 0.50, 0, "ground")

	draw_line(Vector2(74.0, 150.0), Vector2(74.0, 400.0), Color(MID, 0.55), 3.0, true)
	draw_line(Vector2(232.0, 150.0), Vector2(232.0, 400.0), Color(MID, 0.55), 3.0, true)
	draw_rect(Rect2(88.0, 382.0, 130.0, 18.0), PAPER)
	draw_rect(Rect2(88.0, 382.0, 130.0, 18.0), INK, false, 3.0)

func _draw_level_02_ropeway() -> void:
	_draw_ropeway_background()
	for platform_rect in ROPEWAY_PLATFORMS:
		_draw_platform(_world_rect_to_screen(platform_rect))
	_draw_moving_platform(_world_rect_to_screen(_ropeway_moving_platform(elapsed)))
	_draw_ropeway_guide_ropes()
	_draw_ropeway_collectible_rope()
	_draw_ropeway_knots()
	_draw_ropeway_climb_anchor()
	_draw_ropeway_boulder()

func _draw_ropeway_background() -> void:
	for ridge_index in range(5):
		var base_y: float = 145.0 + float(ridge_index) * 92.0
		var ridge := PackedVector2Array()
		for point_index in range(10):
			var world_x: float = float(point_index) * 270.0
			var world_y: float = base_y + sin(float(point_index) * 1.7 + float(ridge_index)) * 35.0
			ridge.append(_world_to_screen(Vector2(world_x, world_y)))
		draw_polyline(ridge, Color(MID, 0.12 + float(ridge_index) * 0.035), 2.0 + float(ridge_index) * 0.5, true)
	draw_rect(_world_rect_to_screen(Rect2(0.0, 635.0, 2390.0, 100.0)), INK)
	draw_polygon(PackedVector2Array([
		_world_to_screen(Vector2(1960.0, 565.0)),
		_world_to_screen(Vector2(2050.0, 470.0)),
		_world_to_screen(Vector2(2050.0, 720.0)),
		_world_to_screen(Vector2(1938.0, 720.0)),
	]), PackedColorArray([INK]))
	draw_line(_world_to_screen(Vector2(2350.0, 80.0)), _world_to_screen(Vector2(2350.0, 560.0)), INK, 12.0, true)

func _draw_ropeway_guide_ropes() -> void:
	var guide := PackedVector2Array()
	for point in ropeway_boulder_path:
		guide.append(_world_to_screen(point + Vector2(0.0, 43.0)))
	draw_polyline(guide, Color(MID, 0.5), 3.0, true)
	for platform_rect in ROPEWAY_PLATFORMS:
		var center: Vector2 = _world_to_screen(platform_rect.get_center())
		draw_line(center + Vector2(0.0, -2.0), center + Vector2(0.0, -42.0), Color(MID, 0.38), 2.0, true)
	var moving_platform := _ropeway_moving_platform(elapsed)
	var moving_center := _world_to_screen(moving_platform.get_center())
	var moving_track_start := _world_to_screen(Vector2(1370.0, 530.0))
	var moving_track_end := _world_to_screen(Vector2(1548.0, 530.0))
	draw_line(moving_track_start, moving_track_end, Color(MID, 0.42), 2.0, true)
	draw_line(moving_center + Vector2(0.0, -10.0), Vector2(moving_center.x, moving_track_start.y), Color(MID, 0.55), 2.0, true)

func _draw_ropeway_collectible_rope() -> void:
	var rope_points := PackedVector2Array()
	for knot in ROPEWAY_KNOTS:
		rope_points.append(knot.get_center())
	rope_points.append(Vector2(2220.0, 470.0))
	for index in range(ropeway_knot_count, rope_points.size() - 1):
		var start: Vector2 = _world_to_screen(rope_points[index])
		var finish: Vector2 = _world_to_screen(rope_points[index + 1])
		var middle: Vector2 = (start + finish) * 0.5 + Vector2(0.0, 14.0)
		draw_polyline(PackedVector2Array([start, middle, finish]), INK, 5.0, true)
		draw_polyline(PackedVector2Array([start, middle, finish]), HEMP, 2.5, true)
	if ropeway_collect_time > 0.0:
		var progress: float = 1.0 - ropeway_collect_time / 0.48
		var source: Vector2 = _world_to_screen(ropeway_collect_origin)
		var hand: Vector2 = _world_to_screen(player_position + Vector2(PLAYER_SIZE.x * 0.5 + player_facing * 14.0, 31.0))
		var moving_point: Vector2 = source.lerp(hand, smoothstep(0.0, 1.0, progress))
		draw_line(moving_point, hand, Color(HEMP, 1.0 - progress * 0.35), 4.0, true)
		draw_circle(moving_point, 4.0, HEMP_LIGHT)
		draw_circle(moving_point, 4.0, INK, false, 2.0)

func _draw_ropeway_knots() -> void:
	var active: int = _active_ropeway_knot()
	for index in range(ROPEWAY_KNOTS.size()):
		var knot: Rect2 = ROPEWAY_KNOTS[index]
		var center: Vector2 = _world_to_screen(knot.get_center())
		if ropeway_knots[index]:
			draw_arc(center, 9.0, 0.15, PI * 1.55, 16, Color(HEMP, 0.52), 2.0, true)
			continue
		var apex_ready: bool = (
			index == active
			and ROPEWAY_KNOT_APEX_REQUIRED[index]
			and _can_collect_ropeway_knot(index)
		)
		if apex_ready:
			var glow_pulse: float = (sin(elapsed * 13.0) + 1.0) * 2.0
			draw_circle(center, 25.0 + glow_pulse, Color(HEMP_LIGHT, 0.2))
			draw_arc(center, 20.0 + glow_pulse, 0.0, TAU, 28, Color(HEMP_LIGHT, 0.95), 3.0, true)
			for ray_index in range(8):
				var ray_direction := Vector2.RIGHT.rotated(float(ray_index) * TAU / 8.0)
				draw_line(
					center + ray_direction * 24.0,
					center + ray_direction * (31.0 + glow_pulse),
					Color(HEMP_LIGHT, 0.9),
					2.0,
					true
				)
		if ROPEWAY_KNOT_HANGING[index]:
			draw_line(center + Vector2(0.0, -34.0), center, INK, 5.0, true)
			draw_line(center + Vector2(0.0, -34.0), center, HEMP, 2.5, true)
		draw_circle(center, 12.0, HEMP_LIGHT)
		draw_circle(center, 12.0, INK, false, 3.0, true)
		draw_arc(center, 6.0, 0.0, TAU, 18, INK, 2.0, true)
		if ROPEWAY_KNOT_APEX_REQUIRED[index]:
			draw_line(center + Vector2(-9.0, -22.0), center + Vector2(0.0, -31.0), INK, 2.0, true)
			draw_line(center + Vector2(0.0, -31.0), center + Vector2(9.0, -22.0), INK, 2.0, true)
		if index == active:
			draw_circle(center, 17.0 + sin(elapsed * 5.0) * 2.0, Color(INK, 0.35), false, 2.0, true)
	if active >= 0 and _ropeway_knot_prompt_visible(active):
		_draw_key_prompt(_world_to_screen(ROPEWAY_KNOTS[active].get_center()) + Vector2(0.0, -54.0), "F", "")

func _draw_ropeway_climb_anchor() -> void:
	var anchor: Vector2 = _world_to_screen(ROPEWAY_CLIMB_ANCHOR)
	draw_circle(anchor, 18.0, PAPER)
	draw_circle(anchor, 18.0, INK, false, 4.0, true)
	draw_line(anchor + Vector2(0.0, -18.0), anchor + Vector2(0.0, -52.0), INK, 4.0, true)
	if ropeway_rope_installed:
		draw_line(anchor, _world_to_screen(Vector2(ROPEWAY_CLIMB_ANCHOR.x, 470.0)), INK, 5.0, true)
		draw_line(anchor, _world_to_screen(Vector2(ROPEWAY_CLIMB_ANCHOR.x, 470.0)), HEMP, 2.5, true)
		return
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	if player_rect.intersects(ROPEWAY_CLIMB_ZONE):
		var label: String = "架设长绳" if ropeway_knot_count >= ROPEWAY_KNOTS.size() else "绳长不足"
		_draw_key_prompt(anchor + Vector2(0.0, 55.0), "F", label)

func _draw_ropeway_boulder() -> void:
	if ropeway_chase_state == "gone":
		return
	var center: Vector2 = _world_to_screen(ropeway_boulder_position)
	var radius: float = ROPEWAY_BOULDER_RADIUS
	if ropeway_chase_state == "warning":
		draw_circle(center, radius + 10.0 + sin(elapsed * 18.0) * 3.0, Color(FIRE, 0.8), false, 4.0, true)
	var rock_offsets: Array[Vector2] = [
		Vector2(-39.0, -11.0), Vector2(-27.0, -34.0), Vector2(-5.0, -41.0),
		Vector2(20.0, -35.0), Vector2(39.0, -17.0), Vector2(41.0, 9.0),
		Vector2(25.0, 34.0), Vector2(2.0, 40.0), Vector2(-25.0, 31.0),
		Vector2(-42.0, 11.0),
	]
	var rock_points := PackedVector2Array()
	for offset in rock_offsets:
		rock_points.append(center + offset.rotated(ropeway_boulder_angle))
	draw_polygon(rock_points, PackedColorArray([Color("777a78")]))
	var rock_outline: PackedVector2Array = rock_points.duplicate()
	rock_outline.append(rock_points[0])
	draw_polyline(rock_outline, INK, 4.0, true)

	var facet_a := center + Vector2(-19.0, -16.0).rotated(ropeway_boulder_angle)
	var facet_b := center + Vector2(9.0, -25.0).rotated(ropeway_boulder_angle)
	var facet_c := center + Vector2(24.0, 4.0).rotated(ropeway_boulder_angle)
	var facet_d := center + Vector2(-7.0, 23.0).rotated(ropeway_boulder_angle)
	draw_line(facet_a, facet_b, INK, 2.5, true)
	draw_line(facet_b, facet_c, INK, 2.5, true)
	draw_line(facet_c, facet_d, INK, 2.5, true)
	draw_line(facet_d, facet_a, Color(INK, 0.55), 1.5, true)
	draw_line(facet_a, center + Vector2(-29.0, 8.0).rotated(ropeway_boulder_angle), Color(PAPER, 0.72), 2.0, true)
	draw_line(facet_c, center + Vector2(29.0, 19.0).rotated(ropeway_boulder_angle), Color(PAPER, 0.55), 2.0, true)

func _draw_ropeway_held_coil() -> void:
	var hand_world: Vector2 = player_position + Vector2(PLAYER_SIZE.x * 0.5 + player_facing * 15.0, 31.0)
	var hand: Vector2 = _world_to_screen(hand_world)
	var loop_count: int = 1 + ropeway_knot_count
	for loop_index in range(loop_count):
		var radius: float = 5.0 + float(loop_index) * 2.0
		var loop_center := hand + Vector2(float(loop_index % 2) * 1.5, 0.0)
		draw_arc(loop_center, radius, 0.0, TAU, 20, INK, 3.5, true)
		draw_arc(loop_center, radius, 0.0, TAU, 20, HEMP, 1.8, true)

func _draw_ropeway_failure_effect() -> void:
	var center: Vector2 = _world_to_screen(player_position + PLAYER_SIZE * 0.5)
	var alpha: float = clampf(1.0 - ropeway_failure_time / 0.78, 0.0, 1.0)
	draw_circle(center, 28.0 + ropeway_failure_time * 38.0, Color(FIRE, alpha), false, 4.0, true)
	draw_string(ui_font, center + Vector2(-45.0, -48.0), ropeway_failure_reason, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(INK, alpha))

func _draw_level_02_cave() -> void:
	_draw_cave_background()
	for platform_rect in CAVE_PLATFORMS:
		var screen_rect: Rect2 = _world_rect_to_screen(platform_rect)
		draw_rect(screen_rect, INK)
		draw_line(screen_rect.position, Vector2(screen_rect.end.x, screen_rect.position.y), PAPER, 4.0, true)
		for mark_index in range(maxi(1, int(platform_rect.size.x / 95.0))):
			var mark_x: float = screen_rect.position.x + 34.0 + float(mark_index) * 92.0
			draw_line(Vector2(mark_x, screen_rect.position.y + 13.0), Vector2(mark_x + 15.0, screen_rect.position.y + 28.0), Color(PAPER, 0.2), 2.0, true)
	_draw_cave_exit()
	_draw_cave_chest()
	_draw_cave_mid_checkpoint()
	_draw_cave_rolling_source()
	_draw_cave_arrow_trap()
	_draw_cave_falling_rocks()
	_draw_cave_dust()
	_draw_cave_rolling_rocks()

func _draw_cave_background() -> void:
	for layer_index in range(4):
		var ceiling_line := PackedVector2Array()
		for point_index in range(19):
			var world_x: float = float(point_index) * 270.0 - 80.0
			var world_y: float = 78.0 + float(layer_index) * 42.0 + sin(float(point_index) * 1.43 + float(layer_index)) * 28.0
			ceiling_line.append(_world_to_screen(Vector2(world_x, world_y)))
		draw_polyline(ceiling_line, Color(MID, 0.16 + float(layer_index) * 0.055), 3.0 + float(layer_index), true)
	for root_index in range(25):
		var root_x: float = float(root_index) * 205.0 - 40.0
		var root_start: Vector2 = _world_to_screen(Vector2(root_x, 0.0))
		var root_end: Vector2 = _world_to_screen(Vector2(root_x + sin(float(root_index) * 1.7) * 36.0, 105.0 + fmod(float(root_index) * 31.0, 92.0)))
		draw_line(root_start, root_end, Color(INK, 0.24), 5.0, true)
	for gap_index in range(CAVE_PLATFORMS.size() - 1):
		var left_platform: Rect2 = CAVE_PLATFORMS[gap_index]
		var right_platform: Rect2 = CAVE_PLATFORMS[gap_index + 1]
		var gap_left: float = left_platform.end.x
		var gap_right: float = right_platform.position.x
		var lip_left: Vector2 = _world_to_screen(Vector2(gap_left, left_platform.position.y))
		var lip_right: Vector2 = _world_to_screen(Vector2(gap_right, right_platform.position.y))
		draw_line(lip_left, lip_left + Vector2(18.0, 58.0), Color(MID, 0.55), 3.0, true)
		draw_line(lip_right, lip_right + Vector2(-18.0, 58.0), Color(MID, 0.55), 3.0, true)

func _draw_cave_exit() -> void:
	var outdoor_rect: Rect2 = _world_rect_to_screen(Rect2(4190.0, 0.0, 510.0, 195.0))
	draw_rect(outdoor_rect, Color(PALE, 0.42))
	var mouth_points := PackedVector2Array([
		_world_to_screen(Vector2(4175.0, 195.0)),
		_world_to_screen(Vector2(4210.0, 105.0)),
		_world_to_screen(Vector2(4310.0, 54.0)),
		_world_to_screen(Vector2(4440.0, 42.0)),
		_world_to_screen(Vector2(4600.0, 78.0)),
		_world_to_screen(Vector2(4700.0, 150.0)),
	])
	draw_polyline(mouth_points, INK, 12.0, true)
	_draw_shared_hut_forecourt(_world_to_screen(Vector2(4580.0, 195.0)), 0.42, 0, "ground")

func _draw_cave_rolling_source() -> void:
	var source: Vector2 = _world_to_screen(Vector2(CAVE_ROLLING_SOURCE_X, 34.0))
	var chute_points := PackedVector2Array([
		source + Vector2(-54.0, -38.0),
		source + Vector2(-36.0, 32.0),
		source + Vector2(36.0, 32.0),
		source + Vector2(54.0, -38.0),
	])
	draw_polyline(chute_points, INK, 7.0, true)
	draw_line(source + Vector2(-36.0, 32.0), source + Vector2(36.0, 32.0), Color(PAPER, 0.7), 3.0, true)
	for dust_index in range(3):
		var dust_center: Vector2 = source + Vector2(-22.0 + float(dust_index) * 22.0, 46.0 + fmod(elapsed * 28.0 + float(dust_index) * 11.0, 28.0))
		draw_circle(dust_center, 3.0 + float(dust_index), Color(MID, 0.28))

func _draw_cave_chest() -> void:
	var chest: Rect2 = _world_rect_to_screen(CAVE_CHEST)
	if not cave_chest_open:
		var pulse: float = (sin(elapsed * 4.5) + 1.0) * 4.0
		draw_circle(chest.get_center(), 58.0 + pulse, Color(GOLD, 0.10))
		draw_arc(chest.get_center(), 49.0 + pulse, 0.0, TAU, 36, Color(GOLD, 0.62), 3.0, true)
	draw_rect(Rect2(chest.position + Vector2(0.0, 28.0), Vector2(chest.size.x, chest.size.y - 28.0)), PAPER)
	draw_rect(Rect2(chest.position + Vector2(0.0, 28.0), Vector2(chest.size.x, chest.size.y - 28.0)), INK, false, 4.0)
	if cave_chest_open:
		draw_line(chest.position + Vector2(4.0, 28.0), chest.position + Vector2(18.0, -4.0), INK, 5.0, true)
		draw_line(chest.position + Vector2(18.0, -4.0), chest.position + Vector2(83.0, 13.0), INK, 5.0, true)
	else:
		draw_arc(chest.get_center() + Vector2(0.0, 28.0), 43.0, PI, TAU, 28, INK, 5.0, true)
		draw_rect(Rect2(chest.get_center() + Vector2(-7.0, 23.0), Vector2(14.0, 20.0)), GOLD)
	if not cave_chest_open and Rect2(player_position, PLAYER_SIZE).intersects(CAVE_CHEST_INTERACTION):
		_draw_key_prompt(chest.get_center() + Vector2(0.0, -62.0), "F", "")
	if shield_pickup_time > 0.0:
		var pickup_progress: float = 1.0 - shield_pickup_time / 0.95
		var source: Vector2 = chest.get_center() + Vector2(0.0, -18.0)
		var target: Vector2 = _world_to_screen(player_position + Vector2(PLAYER_SIZE.x * 0.5, 25.0))
		var arc_height: float = sin(clampf(pickup_progress, 0.0, 1.0) * PI) * 58.0
		var shield_center: Vector2 = source.lerp(target, smoothstep(0.0, 1.0, pickup_progress)) - Vector2(0.0, arc_height)
		_draw_shield_shape(shield_center, pickup_progress * 1.8, 0.82, GOLD_LIGHT)

func _draw_cave_mid_checkpoint() -> void:
	var marker_world: Vector2 = CAVE_MID_CHECKPOINT_POSITION + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y)
	var anchor: Vector2 = _world_to_screen(marker_world)
	var marker_color: Color = GOLD if cave_mid_checkpoint_active else Color(PAPER, 0.58)
	draw_line(anchor + Vector2(0.0, -46.0), anchor + Vector2(0.0, -5.0), INK, 4.0, true)
	draw_arc(anchor + Vector2(0.0, -49.0), 15.0, 0.0, TAU, 24, marker_color, 4.0, true)
	draw_circle(anchor + Vector2(0.0, -49.0), 5.0, marker_color)
	if cave_mid_checkpoint_active:
		draw_arc(anchor + Vector2(0.0, -49.0), 24.0 + sin(elapsed * 4.0) * 3.0, 0.0, TAU, 30, Color(GOLD, 0.42), 3.0, true)

func _draw_cave_rolling_rocks() -> void:
	for index in range(cave_rolling_rocks.size()):
		var rock: Dictionary = cave_rolling_rocks[index]
		var state: String = String(rock["state"])
		if state == "gone":
			continue
		var rock_position: Vector2 = rock["position"]
		var center: Vector2 = _world_to_screen(rock_position)
		var radius: float = float(rock["radius"])
		if state == "shattered":
			var shatter_ratio: float = 1.0 - float(rock["shatter_time"]) / SHIELD_SHATTER_DURATION
			for fragment_index in range(9):
				var angle: float = float(fragment_index) * TAU / 9.0 + float(index) * 0.37
				var travel: float = 12.0 + shatter_ratio * (38.0 + float(fragment_index % 3) * 8.0)
				var fragment_center: Vector2 = center + Vector2(cos(angle), sin(angle)) * travel + Vector2(0.0, shatter_ratio * shatter_ratio * 34.0)
				draw_circle(fragment_center, maxf(2.0, radius * 0.12), Color(INK, 1.0 - shatter_ratio * 0.75))
			continue
		_draw_cave_rock_shape(center, radius, float(rock["angle"]))

func _draw_cave_dust() -> void:
	for puff in cave_dust_puffs:
		var remaining: float = float(puff["time"])
		var progress: float = 1.0 - remaining / 0.62
		var dust_scale: float = float(puff["scale"])
		var origin_world: Vector2 = puff["position"]
		var origin: Vector2 = _world_to_screen(origin_world)
		for cloud_index in range(9):
			var spread_direction: float = -1.0 + float(cloud_index) / 4.0
			var cloud_center: Vector2 = origin + Vector2(
				spread_direction * (18.0 + progress * 42.0) * dust_scale,
				-6.0 - sin(float(cloud_index) * 1.7) * 5.0 - progress * 22.0
			)
			var cloud_radius: float = (5.0 + float(cloud_index % 3) * 2.5) * dust_scale * (1.0 - progress * 0.45)
			draw_circle(cloud_center, cloud_radius, Color(MID, (1.0 - progress) * 0.34))

func _draw_cave_falling_rocks() -> void:
	for rock in cave_falling_rocks:
		var state: String = String(rock["state"])
		if state == "gone":
			continue
		var rock_position: Vector2 = rock["position"]
		var center: Vector2 = _world_to_screen(rock_position)
		if state == "warning":
			var warning_ratio: float = clampf(float(rock["warning_time"]) / 0.72, 0.0, 1.0)
			draw_circle(center, 18.0 + sin(elapsed * 18.0) * 3.0, Color(FIRE, 0.16))
			draw_arc(center, 22.0, 0.0, TAU, 24, Color(FIRE, 0.82), 3.0, true)
			for debris_index in range(4):
				var debris_y: float = 24.0 + fmod(elapsed * (95.0 + debris_index * 11.0) + debris_index * 19.0, 82.0)
				draw_circle(center + Vector2(-13.0 + debris_index * 9.0, debris_y), 2.5, Color(INK, 0.55 + warning_ratio * 0.2))
			continue
		_draw_cave_rock_shape(center, float(rock["radius"]), float(rock["angle"]))
		for speed_line_index in range(3):
			var line_x: float = center.x - 15.0 + float(speed_line_index) * 15.0
			draw_line(Vector2(line_x, center.y - 48.0), Vector2(line_x, center.y - 29.0), Color(MID, 0.6), 2.0, true)

func _draw_cave_arrow_trap() -> void:
	var launcher: Vector2 = _world_to_screen(CAVE_ARROW_LAUNCHER)
	if cave_arrow_launcher_destroyed:
		for fragment_index in range(7):
			var fragment_angle: float = -2.6 + float(fragment_index) * 0.55
			var fragment_start: Vector2 = launcher + Vector2(cos(fragment_angle), sin(fragment_angle)) * 7.0
			var fragment_end: Vector2 = launcher + Vector2(cos(fragment_angle), sin(fragment_angle)) * (20.0 + float(fragment_index % 2) * 9.0)
			draw_line(fragment_start, fragment_end, Color(INK, 0.72), 4.0, true)
		draw_circle(launcher + Vector2(8.0, 20.0), 9.0, Color(INK, 0.72))
		_draw_cave_arrows()
		return
	draw_line(launcher + Vector2(18.0, -30.0), launcher + Vector2(18.0, 28.0), INK, 6.0, true)
	draw_arc(launcher + Vector2(4.0, 0.0), 27.0, -PI * 0.5, PI * 0.5, 22, INK, 4.0, true)
	draw_line(launcher + Vector2(4.0, -27.0), launcher + Vector2(4.0, 27.0), Color(MID, 0.75), 2.0, true)
	draw_line(launcher + Vector2(-28.0, 0.0), launcher + Vector2(18.0, 0.0), INK, 3.0, true)
	var shield_mark: Vector2 = launcher + Vector2(35.0, -42.0)
	draw_arc(shield_mark, 12.0, 0.0, PI, 16, GOLD, 3.0, true)
	draw_line(shield_mark + Vector2(-12.0, 0.0), shield_mark + Vector2(0.0, 16.0), GOLD, 3.0, true)
	draw_line(shield_mark + Vector2(12.0, 0.0), shield_mark + Vector2(0.0, 16.0), GOLD, 3.0, true)
	if Rect2(player_position, PLAYER_SIZE).grow(82.0).intersects(CAVE_ARROW_LAUNCHER_HITBOX):
		_draw_key_prompt(launcher + Vector2(0.0, -68.0), "F", "挥盾击毁")
	_draw_cave_arrows()

func _draw_cave_arrows() -> void:
	for arrow in cave_arrows:
		if String(arrow["state"]) != "flying":
			continue
		var arrow_position: Vector2 = arrow["position"]
		var arrow_center: Vector2 = _world_to_screen(arrow_position)
		draw_line(arrow_center + Vector2(-23.0, 0.0), arrow_center + Vector2(21.0, 0.0), INK, 3.0, true)
		draw_line(arrow_center + Vector2(-23.0, 0.0), arrow_center + Vector2(-13.0, -7.0), INK, 3.0, true)
		draw_line(arrow_center + Vector2(-23.0, 0.0), arrow_center + Vector2(-13.0, 7.0), INK, 3.0, true)
		draw_line(arrow_center + Vector2(21.0, 0.0), arrow_center + Vector2(14.0, -6.0), Color(MID, 0.8), 2.0, true)
		draw_line(arrow_center + Vector2(21.0, 0.0), arrow_center + Vector2(14.0, 6.0), Color(MID, 0.8), 2.0, true)

func _draw_cave_rock_shape(center: Vector2, radius: float, angle: float) -> void:
	var offsets: Array[Vector2] = [
		Vector2(-0.94, -0.22), Vector2(-0.58, -0.84), Vector2(-0.08, -1.0),
		Vector2(0.62, -0.78), Vector2(0.98, -0.18), Vector2(0.88, 0.52),
		Vector2(0.28, 0.94), Vector2(-0.45, 0.82), Vector2(-1.0, 0.34),
	]
	var points := PackedVector2Array()
	for offset in offsets:
		points.append(center + (offset * radius).rotated(angle))
	draw_polygon(points, PackedColorArray([Color("6f7271")]))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, INK, 4.0, true)
	draw_line(center + Vector2(-0.45, -0.38).rotated(angle) * radius, center + Vector2(0.34, -0.52).rotated(angle) * radius, INK, 2.5, true)
	draw_line(center + Vector2(0.34, -0.52).rotated(angle) * radius, center + Vector2(0.55, 0.18).rotated(angle) * radius, INK, 2.5, true)
	draw_line(center + Vector2(-0.28, 0.42).rotated(angle) * radius, center + Vector2(0.55, 0.18).rotated(angle) * radius, Color(PAPER, 0.6), 2.0, true)

func _draw_cave_failure_effect() -> void:
	var center: Vector2 = _world_to_screen(player_position + PLAYER_SIZE * 0.5)
	var alpha: float = clampf(1.0 - cave_failure_time / 0.78, 0.0, 1.0)
	draw_arc(center, 24.0 + cave_failure_time * 44.0, 0.0, TAU, 30, Color(FIRE, alpha), 4.0, true)
	for slash_index in range(6):
		var slash_angle: float = float(slash_index) * TAU / 6.0
		draw_line(center + Vector2(cos(slash_angle), sin(slash_angle)) * 15.0, center + Vector2(cos(slash_angle), sin(slash_angle)) * 34.0, Color(INK, alpha), 3.0, true)
	draw_string(ui_font, center + Vector2(-62.0, -52.0), cave_failure_reason, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(INK, alpha))

func _draw_far_hills() -> void:
	var back_line := PackedVector2Array([
		Vector2(0.0, 420.0), Vector2(120.0, 350.0), Vector2(230.0, 405.0),
		Vector2(380.0, 310.0), Vector2(530.0, 400.0), Vector2(670.0, 330.0),
		Vector2(820.0, 410.0), Vector2(1010.0, 325.0), Vector2(1280.0, 390.0),
	])
	draw_polyline(back_line, PALE, 3.0, true)
	draw_circle(Vector2(1035.0, 150.0), 45.0, Color(PALE, 0.55), false, 3.0, true)
	for index in 8:
		var x := 70.0 + index * 160.0
		draw_line(Vector2(x, 455.0), Vector2(x + 18.0, 360.0 - fmod(index * 31.0, 54.0)), Color(MID, 0.34), 2.0, true)

func _draw_platform(screen_rect: Rect2) -> void:
	draw_rect(screen_rect, PAPER)
	draw_rect(screen_rect, INK, false, 3.0)
	draw_line(screen_rect.position + Vector2(7.0, 7.0), screen_rect.end - Vector2(7.0, screen_rect.size.y - 7.0), Color(MID, 0.55), 1.5, true)

func _draw_moving_platform(screen_rect: Rect2) -> void:
	_draw_platform(screen_rect)
	var center := screen_rect.get_center()
	draw_line(center + Vector2(-13.0, 0.0), center + Vector2(13.0, 0.0), INK, 2.0, true)
	draw_line(center + Vector2(-13.0, 0.0), center + Vector2(-7.0, -5.0), INK, 2.0, true)
	draw_line(center + Vector2(13.0, 0.0), center + Vector2(7.0, 5.0), INK, 2.0, true)

func _draw_player_shield(player_screen_position: Vector2) -> void:
	if shield_pickup_time > 0.05:
		return
	var facing: float = player_facing
	var shield_center := player_screen_position + Vector2(13.0 + facing * 20.0, 33.0)
	var shield_rotation: float = 0.12 * facing
	var fill_color: Color = PAPER
	if shield_guarding:
		shield_center = player_screen_position + Vector2(13.0 + facing * 26.0, 29.0)
		shield_rotation = 0.0
	elif shield_parry_time > 0.0:
		var parry_ratio: float = 1.0 - shield_parry_time / SHIELD_PARRY_DURATION
		shield_center = player_screen_position + Vector2(13.0 + facing * 28.0, 29.0)
		shield_rotation = lerpf(-0.95, 0.78, parry_ratio) * facing
		fill_color = GOLD_LIGHT
		draw_arc(shield_center, 34.0 + parry_ratio * 8.0, -1.35, 1.35, 24, Color(GOLD, 0.92), 5.0, true)
	elif shield_input_active:
		shield_center = player_screen_position + Vector2(13.0 + facing * 22.0, 32.0)
		shield_rotation = -0.28 * facing
	_draw_shield_shape(shield_center, shield_rotation, 1.0, fill_color, facing)
	if shield_block_hit_time > 0.0 or shield_parry_hit_time > 0.0:
		var impact_ratio: float = maxf(
			shield_block_hit_time / 0.16,
			shield_parry_hit_time / 0.30
		)
		for spark_index in range(7):
			var spark_angle: float = -1.15 + float(spark_index) * 0.38
			var direction := Vector2(cos(spark_angle) * facing, sin(spark_angle))
			draw_line(
				shield_center + direction * 23.0,
				shield_center + direction * (30.0 + impact_ratio * 15.0),
				Color(GOLD, impact_ratio),
				3.0,
				true
			)

func _draw_shield_shape(center: Vector2, rotation: float, scale_factor: float, fill_color: Color, facing: float = 1.0) -> void:
	var local_points: Array[Vector2] = [
		Vector2(-13.0, -19.0), Vector2(13.0, -19.0), Vector2(15.0, 1.0),
		Vector2(8.0, 14.0), Vector2(0.0, 21.0), Vector2(-8.0, 14.0), Vector2(-15.0, 1.0),
	]
	var shield_points := PackedVector2Array()
	for local_point in local_points:
		var mirrored_point := Vector2(local_point.x * facing, local_point.y) * scale_factor
		shield_points.append(center + mirrored_point.rotated(rotation))
	draw_polygon(shield_points, PackedColorArray([fill_color]))
	var outline: PackedVector2Array = shield_points.duplicate()
	outline.append(shield_points[0])
	draw_polyline(outline, INK, 3.0, true)
	var emblem_top: Vector2 = center + Vector2(0.0, -10.0 * scale_factor).rotated(rotation)
	var emblem_bottom: Vector2 = center + Vector2(0.0, 11.0 * scale_factor).rotated(rotation)
	draw_line(emblem_top, emblem_bottom, GOLD, 2.5, true)
	draw_circle(center, 3.5 * scale_factor, GOLD)

func _draw_key_prompt(center: Vector2, key: String, label: String) -> void:
	draw_circle(center, 17.0, PAPER)
	draw_circle(center, 17.0, INK, false, 2.0, true)
	var key_size := ui_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15)
	draw_string(ui_font, center - key_size * 0.5 + Vector2(0.0, key_size.y * 0.72), key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, INK)
	var label_size := ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)
	draw_string(ui_font, center + Vector2(-label_size.x * 0.5, 37.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(INK, 0.7))

func _cave_screen_shake_offset() -> Vector2:
	var strength: float = 0.0
	if shield_parry_hit_time > 0.0:
		strength = 5.5 * shield_parry_hit_time / 0.30
	elif shield_block_hit_time > 0.0:
		strength = 2.6 * shield_block_hit_time / 0.16
	elif cave_rock_impact_time > 0.0:
		strength = 3.2 * cave_rock_impact_strength * cave_rock_impact_time / 0.20
	elif cave_failure_time > 0.0:
		strength = 4.0 * clampf(1.0 - cave_failure_time / 0.78, 0.0, 1.0)
	if strength <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(elapsed * 54.0) * strength, cos(elapsed * 47.0) * strength * 0.68)

func _ropeway_screen_shake_offset() -> Vector2:
	var strength: float = 0.0
	if ropeway_chase_state == "warning":
		strength = 2.2
	elif ropeway_chase_state == "rolling":
		var speed_ratio: float = inverse_lerp(
			ROPEWAY_BOULDER_START_SPEED,
			ROPEWAY_BOULDER_MAX_SPEED,
			ropeway_boulder_speed
		)
		var player_center_x: float = player_position.x + PLAYER_SIZE.x * 0.5
		var separation: float = maxf(0.0, player_center_x - ropeway_boulder_position.x)
		var proximity: float = 1.0 - clampf(separation / 720.0, 0.0, 1.0)
		var rock_impact: float = 0.48 + absf(sin(ropeway_boulder_angle * 1.7)) * 0.52
		strength = (1.4 + speed_ratio * 2.8 + proximity * 3.2) * rock_impact
	elif ropeway_chase_state == "falling":
		strength = clampf(4.5 + ropeway_boulder_fall_velocity / 190.0, 4.5, 9.0)
	if strength <= 0.0:
		return Vector2.ZERO
	return Vector2(
		sin(elapsed * 47.0) * strength,
		cos(elapsed * 41.0 + 0.8) * strength * 0.68
	)
