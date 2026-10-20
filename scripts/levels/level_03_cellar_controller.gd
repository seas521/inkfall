extends Node2D

signal rescued

const Palette = preload("res://scripts/shared/inkfall_palette.gd")
const SCREEN := Palette.SCREEN
const PLAYER_SIZE := Palette.PLAYER_SIZE
const GRAVITY := Palette.GRAVITY
const INK := Palette.INK
const PAPER := Palette.PAPER
const PALE := Palette.PALE
const MID := Palette.MID
const WATER := Palette.WATER
const GAS := Palette.GAS
const FIRE := Palette.FIRE
const HEMP := Palette.HEMP
const CELLAR_WORLD_SIZE := Vector2(8760.0, 4070.0)
const CELLAR_CHAMBER_SIZE := Vector2(1120.0, 650.0)
const CELLAR_FLOOR_Y := 560.0
const CELLAR_LIGHT_RADIUS := 185.0
const CELLAR_LIGHT_FEATHER := 105.0
const CELLAR_WELL_RUBBLE_HITS_REQUIRED := 3
const CELLAR_ASCENT_DURATION := 1.20
const CELLAR_ASCENT_HEIGHT := 420.0
const CELLAR_START_SPAWN := Vector2(225.0, 586.0)
const CELLAR_KEY_COLOR := Palette.CELLAR_KEY_COLOR
const CELLAR_STONE_COLOR := Palette.CELLAR_STONE_COLOR
const CELLAR_BG := Palette.CELLAR_BG
const CELLAR_WALL := Palette.CELLAR_WALL
const CELLAR_LINE := Palette.CELLAR_LINE
const CELLAR_SHAFT_UP_ROOMS: Array[String] = ["J", "WB", "RS", "PS"]

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
var regular_jump_active: bool:
	get: return game_context.regular_jump_active
	set(value): game_context.regular_jump_active = value
var failure_flash: float:
	get: return game_context.failure_flash
	set(value): game_context.failure_flash = value

var host
var ui_font: Font
var elapsed := 0.0
var completion_time := 0.0
var rescued_state := false
var room_intro_time := 0.0
var cellar_region := "A"
var cellar_camera := Vector2.ZERO
var cellar_checkpoint_region := "A"
var cellar_checkpoint_position := CELLAR_START_SPAWN
var cellar_has_key := false
var cellar_has_rope := false
var cellar_rope_installed := false
var cellar_has_pickaxe := false
var cellar_well_rubble_hits := 0
var cellar_prison_discovered := false
var cellar_key_collected := false
var cellar_rescue_started := false
var cellar_intro_time := 0.0
var cellar_transition_time := 0.0
var cellar_focus_time := 0.0
var cellar_focus_kind := ""
var cellar_failure_time := 0.0
var cellar_failure_kind := ""
var cellar_wall_hit_time := 0.0
var cellar_spawn_grace_time := 0.0
var cellar_dust: Array[Dictionary] = []
var cellar_ascent_active := false
var cellar_ascent_time := 0.0
var cellar_ascent_portal: Dictionary = {}
var cellar_ascent_start := Vector2.ZERO

func enter(context, font: Font, game_host) -> void:
	game_context = context
	ui_font = font
	host = game_host
	visible = true
	reset()

func leave() -> void:
	visible = false

func reset() -> void:
	rescued_state = false
	completion_time = 0.0
	_reset_cellar_state()
	_enter_cellar_maze(false)
	queue_redraw()

func physics_tick(delta: float) -> void:
	elapsed += delta
	failure_flash = maxf(0.0, failure_flash - delta)
	cellar_intro_time = maxf(0.0, cellar_intro_time - delta)
	cellar_transition_time = maxf(0.0, cellar_transition_time - delta)
	cellar_focus_time = maxf(0.0, cellar_focus_time - delta)
	cellar_wall_hit_time = maxf(0.0, cellar_wall_hit_time - delta)
	cellar_spawn_grace_time = maxf(0.0, cellar_spawn_grace_time - delta)
	if rescued_state:
		_update_cellar_rescued(delta)
	else:
		_update_cellar_maze(delta)
	queue_redraw()

func presentation_state() -> Dictionary:
	return {"active": false, "stage": "rescued" if rescued_state else "cellar", "region": cellar_region}

func sync_environment(_env_fx: Node2D) -> void:
	pass

func _draw() -> void:
	draw_world()
	if not rescued_state:
		_draw_player()
		if cellar_failure_time > 0.0: _draw_cellar_failure_effect()
		_draw_cellar_darkness()
	draw_ui()
	if cellar_transition_time > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(CELLAR_BG, clampf(cellar_transition_time / 0.7, 0.0, 0.96)))
	if failure_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(INK, failure_flash * 0.7))

func draw_world() -> void:
	if rescued_state: _draw_cellar_rescued()
	else: _draw_cellar_maze()

func draw_ui() -> void:
	var room_name := "D · 地牢深处" if rescued_state else _cellar_region_label()
	draw_string(ui_font, Vector2(28.0, 36.0), "INKFALL · 1-03 月炉木屋", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, PAPER)
	draw_string(ui_font, Vector2(28.0, 64.0), room_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(PAPER, 0.62))
	var controls := "T 重新开始 1-03　Esc 返回 DEBUG" if rescued_state else "A / D 移动　Space 跳跃　F 交互 / 升降台　T 重置"
	draw_string(ui_font, Vector2(28.0, 694.0), controls, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(PAPER, 0.64))
	if not rescued_state:
		_draw_cellar_rope_icon(Vector2(1080.0, 42.0), 0.42, 1.0 if cellar_has_rope or cellar_rope_installed else 0.18)
		_draw_cellar_pickaxe_icon(Vector2(1145.0, 42.0), 0.42, 1.0 if cellar_has_pickaxe else 0.18)
		_draw_cellar_key(Vector2(1210.0, 42.0), 0.38, 1.0 if cellar_has_key else 0.18)

func _update_player(delta: float, platforms: Array[Rect2], bounds: Vector2, allow_input: bool) -> void:
	host.update_shared_player(game_context, delta, platforms, bounds, allow_input)

func _enter_cellar_maze(reset_maze: bool) -> void:
	if reset_maze:
		_reset_cellar_state()
	cellar_region = "A"
	# The preceding CELLAR_READY room already owns the falling shot. Enter the
	# playable maze on the landing frame instead of starting a second fall.
	player_position = CELLAR_START_SPAWN
	player_velocity = Vector2.ZERO
	player_facing = 1.0
	on_ground = true
	regular_jump_active = false
	cellar_camera = _cellar_camera_target()
	cellar_checkpoint_region = "A"
	cellar_checkpoint_position = CELLAR_START_SPAWN
	cellar_intro_time = 0.82
	cellar_transition_time = 0.52
	cellar_spawn_grace_time = 0.22
	cellar_focus_time = 0.0
	cellar_focus_kind = ""
	room_intro_time = 0.0

func _reset_cellar_state() -> void:
	cellar_has_key = false
	cellar_has_rope = false
	cellar_rope_installed = false
	cellar_has_pickaxe = false
	cellar_well_rubble_hits = 0
	cellar_prison_discovered = false
	cellar_key_collected = false
	cellar_rescue_started = false
	cellar_failure_time = 0.0
	cellar_failure_kind = ""
	cellar_wall_hit_time = 0.0
	cellar_spawn_grace_time = 0.0
	cellar_dust.clear()
	cellar_ascent_active = false
	cellar_ascent_time = 0.0
	cellar_ascent_portal.clear()
	cellar_ascent_start = Vector2.ZERO

func _update_cellar_maze(delta: float) -> void:
	if cellar_failure_time > 0.0:
		_update_cellar_failure(delta)
		_update_cellar_camera(delta)
		return

	if cellar_ascent_active:
		_update_cellar_ascent(delta)
		_update_cellar_dust(delta)
		_update_cellar_camera(delta)
		return

	if cellar_rescue_started:
		player_velocity = Vector2.ZERO
		_update_cellar_camera(delta)
		if cellar_focus_time <= 0.05:
			rescued_state = true
			completion_time = 0.0
			cellar_transition_time = 0.7
			rescued.emit()
		return

	var chamber: Rect2 = _cellar_region_rect(cellar_region)
	var allow_input: bool = cellar_intro_time <= 0.55 and cellar_transition_time <= 0.08 and cellar_focus_time <= 0.55
	var platforms: Array[Rect2] = _cellar_platforms(cellar_region)
	_update_player(delta, platforms, Vector2(chamber.position.x + 22.0, chamber.end.x - 22.0), allow_input)
	_stabilize_cellar_spawn(platforms)
	_update_cellar_dust(delta)
	_update_cellar_camera(delta)
	if _try_cellar_auto_portal():
		return
	var region_before_interaction: String = cellar_region
	_try_cellar_interaction()
	if cellar_region != region_before_interaction:
		return

	if player_position.y > chamber.end.y + 95.0:
		_start_cellar_failure("fall")

func _stabilize_cellar_spawn(platforms: Array[Rect2]) -> void:
	if cellar_spawn_grace_time <= 0.0 or player_velocity.y < 0.0:
		return
	var player_bottom: float = player_position.y + PLAYER_SIZE.y
	for platform_rect in platforms:
		var horizontal_overlap: bool = (
			player_position.x + PLAYER_SIZE.x > platform_rect.position.x + 3.0
			and player_position.x < platform_rect.end.x - 3.0
		)
		if not horizontal_overlap:
			continue
		if player_bottom < platform_rect.position.y - 6.0 or player_position.y > platform_rect.position.y + 24.0:
			continue
		player_position.y = platform_rect.position.y - PLAYER_SIZE.y
		player_velocity.y = 0.0
		on_ground = true
		return

func _update_cellar_rescued(delta: float) -> void:
	completion_time += delta
	player_velocity = Vector2.ZERO

func _update_cellar_camera(delta: float) -> void:
	var target: Vector2 = _cellar_camera_target()
	var camera_weight: float = 1.0 - exp(-8.5 * delta)
	cellar_camera = cellar_camera.lerp(target, camera_weight)

func _cellar_camera_target() -> Vector2:
	var focus_world: Vector2 = player_position + PLAYER_SIZE * 0.5
	if cellar_focus_time > 0.55:
		if cellar_focus_kind == "prison" or cellar_focus_kind == "rescue" or cellar_focus_kind == "need_key":
			focus_world = _cellar_region_origin("R") + Vector2(930.0, 405.0)
		elif cellar_focus_kind == "key":
			focus_world = _cellar_region_origin("WB") + Vector2(570.0, 450.0)
		elif cellar_focus_kind == "rope":
			focus_world = _cellar_region_origin("RS") + Vector2(790.0, 455.0)
		elif cellar_focus_kind == "pickaxe":
			focus_world = _cellar_region_origin("PS") + Vector2(330.0, 455.0)
		elif cellar_focus_kind == "well" or cellar_focus_kind == "need_rope":
			focus_world = _cellar_region_origin("W") + Vector2(815.0, 475.0)
		elif cellar_focus_kind == "need_pickaxe":
			focus_world = _cellar_region_origin("WB") + Vector2(570.0, 470.0)
	var target: Vector2 = focus_world - SCREEN * 0.5
	return Vector2(
		clampf(target.x, 0.0, CELLAR_WORLD_SIZE.x - SCREEN.x),
		clampf(target.y, 0.0, CELLAR_WORLD_SIZE.y - SCREEN.y)
	)

func _cellar_region_origin(region_id: String) -> Vector2:
	match region_id:
		"A":
			return Vector2(80.0, 80.0)
		"B":
			return Vector2(1320.0, 80.0)
		"C":
			return Vector2(2560.0, 80.0)
		"D":
			return Vector2(3800.0, 80.0)
		"E":
			return Vector2(80.0, 880.0)
		"F":
			return Vector2(1320.0, 880.0)
		"G":
			return Vector2(2560.0, 880.0)
		"H":
			return Vector2(3800.0, 880.0)
		"I":
			return Vector2(5040.0, 880.0)
		"W":
			return Vector2(80.0, 1680.0)
		"J":
			return Vector2(1320.0, 1680.0)
		"K":
			return Vector2(2560.0, 1680.0)
		"L":
			return Vector2(3800.0, 1680.0)
		"M":
			return Vector2(5040.0, 1680.0)
		"RS":
			return Vector2(6280.0, 1680.0)
		"X1":
			return Vector2(7520.0, 1680.0)
		"WB":
			return Vector2(80.0, 2480.0)
		"X3":
			return Vector2(1320.0, 2480.0)
		"N":
			return Vector2(2560.0, 2480.0)
		"O":
			return Vector2(3800.0, 2480.0)
		"Q":
			return Vector2(5040.0, 2480.0)
		"R":
			return Vector2(6280.0, 2480.0)
		"X2":
			return Vector2(7520.0, 2480.0)
		"PS":
			return Vector2(2560.0, 3280.0)
	return Vector2(80.0, 80.0)

func _cellar_region_rect(region_id: String) -> Rect2:
	return Rect2(_cellar_region_origin(region_id), CELLAR_CHAMBER_SIZE)

func _cellar_platforms(region_id: String) -> Array[Rect2]:
	var origin: Vector2 = _cellar_region_origin(region_id)
	var platforms: Array[Rect2] = []
	var gaps: Array[Rect2] = []
	for portal in _cellar_portals_for(region_id):
		var side: String = String(portal["side"])
		if side.begins_with("down"):
			var zone: Rect2 = portal["zone"]
			gaps.append(Rect2(zone.position.x - origin.x + 18.0, 0.0, zone.size.x - 36.0, 1.0))
	for gap_index in range(gaps.size()):
		for later_index in range(gap_index + 1, gaps.size()):
			if gaps[later_index].position.x < gaps[gap_index].position.x:
				var swap_gap: Rect2 = gaps[gap_index]
				gaps[gap_index] = gaps[later_index]
				gaps[later_index] = swap_gap
	var cursor_x: float = 30.0
	for gap in gaps:
		if gap.position.x - cursor_x > 24.0:
			platforms.append(Rect2(origin + Vector2(cursor_x, CELLAR_FLOOR_Y), Vector2(gap.position.x - cursor_x, 90.0)))
		cursor_x = gap.end.x
	if 1090.0 - cursor_x > 24.0:
		platforms.append(Rect2(origin + Vector2(cursor_x, CELLAR_FLOOR_Y), Vector2(1090.0 - cursor_x, 90.0)))
	return platforms

func _cellar_portal_local_rect(region_id: String, side: String) -> Rect2:
	match side:
		"left":
			return Rect2(28.0, 410.0, 150.0, 170.0)
		"right":
			return Rect2(942.0, 410.0, 150.0, 170.0)
		"up", "up_left":
			if CELLAR_SHAFT_UP_ROOMS.has(region_id):
				return Rect2(730.0, 390.0, 170.0, 190.0)
			return Rect2(200.0, 390.0, 160.0, 190.0)
		"up_right":
			if region_id == "O":
				return Rect2(410.0, 390.0, 160.0, 190.0)
			return Rect2(500.0, 390.0, 160.0, 190.0)
		"down_left":
			return Rect2(410.0, 420.0, 170.0, 190.0)
		"down", "down_right":
			return Rect2(730.0, 420.0, 170.0, 190.0)
	return Rect2(465.0, 420.0, 190.0, 155.0)

func _cellar_safe_floor_x(region_id: String, desired_rel_x: float) -> float:
	var origin: Vector2 = _cellar_region_origin(region_id)
	var platforms: Array[Rect2] = _cellar_platforms(region_id)
	var desired_world_x: float = origin.x + desired_rel_x
	var best_x: float = 540.0
	var best_dist: float = 100000.0
	for platform_rect in platforms:
		if platform_rect.size.x < PLAYER_SIZE.x + 20.0:
			continue
		var min_x: float = platform_rect.position.x + 10.0
		var max_x: float = platform_rect.end.x - PLAYER_SIZE.x - 10.0
		if max_x < min_x:
			continue
		var candidate: float = clampf(desired_world_x, min_x, max_x)
		var dist: float = absf(candidate - desired_world_x)
		if dist < best_dist:
			best_dist = dist
			best_x = candidate - origin.x
	return best_x

func _cellar_nudge_onto_floor() -> void:
	var origin: Vector2 = _cellar_region_origin(cellar_region)
	var rel_x: float = _cellar_safe_floor_x(cellar_region, player_position.x - origin.x)
	player_position.x = origin.x + rel_x
	player_position.y = origin.y + CELLAR_FLOOR_Y - PLAYER_SIZE.y - 2.0
	player_velocity = Vector2.ZERO
	on_ground = true

func _cellar_spawn(region_id: String, entry_side: String) -> Vector2:
	var origin: Vector2 = _cellar_region_origin(region_id)
	var floor_y: float = origin.y + CELLAR_FLOOR_Y - PLAYER_SIZE.y - 2.0
	var rel_x: float = 540.0
	match entry_side:
		"left":
			rel_x = 145.0
		"right":
			rel_x = 945.0
		_:
			var local_zone: Rect2 = _cellar_portal_local_rect(region_id, entry_side)
			if entry_side.begins_with("down"):
				rel_x = local_zone.position.x - PLAYER_SIZE.x - 58.0
			else:
				rel_x = local_zone.get_center().x - PLAYER_SIZE.x * 0.5
	rel_x = _cellar_safe_floor_x(region_id, rel_x)
	return Vector2(origin.x + rel_x, floor_y)

func _cellar_make_portal(region_id: String, side: String, target: String, target_side: String) -> Dictionary:
	var origin: Vector2 = _cellar_region_origin(region_id)
	var local_zone: Rect2 = _cellar_portal_local_rect(region_id, side)
	return {
		"zone": Rect2(origin + local_zone.position, local_zone.size),
		"side": side,
		"target": target,
		"target_side": target_side,
	}

func _cellar_portals() -> Array[Dictionary]:
	return _cellar_portals_for(cellar_region)

func _cellar_portals_for(region_id: String) -> Array[Dictionary]:
	var portals: Array[Dictionary] = []
	match region_id:
		"A": portals = [_cellar_make_portal("A", "right", "B", "left")]
		"B": portals = [_cellar_make_portal("B", "left", "A", "right"), _cellar_make_portal("B", "right", "C", "left")]
		"C": portals = [_cellar_make_portal("C", "left", "B", "right"), _cellar_make_portal("C", "right", "D", "left")]
		"D": portals = [_cellar_make_portal("D", "left", "C", "right"), _cellar_make_portal("D", "down_left", "E", "up"), _cellar_make_portal("D", "down_right", "I", "up")]
		"E": portals = [_cellar_make_portal("E", "up", "D", "down_left"), _cellar_make_portal("E", "right", "F", "left"), _cellar_make_portal("E", "down", "J", "up")]
		"F": portals = [_cellar_make_portal("F", "left", "E", "right"), _cellar_make_portal("F", "right", "G", "left"), _cellar_make_portal("F", "down", "X1", "up")]
		"G": portals = [_cellar_make_portal("G", "left", "F", "right"), _cellar_make_portal("G", "right", "H", "left"), _cellar_make_portal("G", "down_left", "K", "up_right"), _cellar_make_portal("G", "down_right", "L", "up_left")]
		"H": portals = [_cellar_make_portal("H", "left", "G", "right"), _cellar_make_portal("H", "right", "I", "left"), _cellar_make_portal("H", "down", "RS", "up")]
		"I": portals = [_cellar_make_portal("I", "left", "H", "right"), _cellar_make_portal("I", "up", "D", "down_right"), _cellar_make_portal("I", "down", "M", "up")]
		"J": portals = [_cellar_make_portal("J", "up", "E", "down"), _cellar_make_portal("J", "left", "W", "right"), _cellar_make_portal("J", "right", "K", "left")]
		"K": portals = [_cellar_make_portal("K", "left", "J", "right"), _cellar_make_portal("K", "up_right", "G", "down_left"), _cellar_make_portal("K", "right", "L", "left"), _cellar_make_portal("K", "down", "N", "up")]
		"L": portals = [_cellar_make_portal("L", "left", "K", "right"), _cellar_make_portal("L", "up_left", "G", "down_right"), _cellar_make_portal("L", "right", "M", "left"), _cellar_make_portal("L", "down", "X2", "up")]
		"M": portals = [_cellar_make_portal("M", "left", "L", "right"), _cellar_make_portal("M", "up", "I", "down"), _cellar_make_portal("M", "down_left", "O", "up_right"), _cellar_make_portal("M", "down_right", "X3", "up")]
		"N": portals = [_cellar_make_portal("N", "up", "K", "down"), _cellar_make_portal("N", "right", "O", "left"), _cellar_make_portal("N", "down", "PS", "up")]
		"O": portals = [_cellar_make_portal("O", "left", "N", "right"), _cellar_make_portal("O", "up_right", "M", "down_left"), _cellar_make_portal("O", "right", "Q", "left")]
		"W":
			portals = [_cellar_make_portal("W", "right", "J", "left")]
			if cellar_rope_installed:
				portals.append(_cellar_make_portal("W", "down", "WB", "up"))
		"WB": portals = [_cellar_make_portal("WB", "up", "W", "down")]
		"Q": portals = [_cellar_make_portal("Q", "left", "O", "right"), _cellar_make_portal("Q", "right", "R", "left")]
		"R": portals = [_cellar_make_portal("R", "left", "Q", "right")]
		"RS": portals = [_cellar_make_portal("RS", "up", "H", "down")]
		"PS": portals = [_cellar_make_portal("PS", "up", "N", "down")]
		"X1": portals = [_cellar_make_portal("X1", "up", "F", "down")]
		"X2": portals = [_cellar_make_portal("X2", "up", "L", "down")]
		"X3": portals = [_cellar_make_portal("X3", "up", "M", "down_right")]
	return portals

func _transition_cellar_portal(portal: Dictionary, falling: bool) -> void:
	cellar_region = String(portal["target"])
	player_position = _cellar_spawn(cellar_region, String(portal["target_side"]))
	player_velocity = Vector2.ZERO
	on_ground = true
	regular_jump_active = false
	cellar_transition_time = 0.28
	cellar_spawn_grace_time = 0.20
	if falling:
		var target_origin: Vector2 = _cellar_region_origin(cellar_region)
		player_position.y = target_origin.y + 105.0
		player_velocity.y = 285.0
		on_ground = false
		cellar_transition_time = 0.18
		cellar_spawn_grace_time = 0.12
	else:
		_cellar_nudge_onto_floor()
	if cellar_region == "R" and not cellar_prison_discovered:
		cellar_prison_discovered = true
		cellar_focus_time = 2.2
		cellar_focus_kind = "prison"
	cellar_camera = _cellar_camera_target()

func _try_cellar_auto_portal() -> bool:
	if cellar_transition_time > 0.0 or cellar_focus_time > 0.55 or cellar_intro_time > 0.55:
		return false
	var origin: Vector2 = _cellar_region_origin(cellar_region)
	var direction: float = Input.get_axis("move_left", "move_right")
	var player_center_x: float = player_position.x + PLAYER_SIZE.x * 0.5
	var player_bottom: float = player_position.y + PLAYER_SIZE.y
	for portal in _cellar_portals():
		var side: String = String(portal["side"])
		var zone: Rect2 = portal["zone"]
		if side == "left" and direction < -0.35 and player_position.x <= origin.x + 30.0:
			_transition_cellar_portal(portal, false)
			return true
		if side == "right" and direction > 0.35 and player_position.x >= origin.x + CELLAR_CHAMBER_SIZE.x - PLAYER_SIZE.x - 30.0:
			_transition_cellar_portal(portal, false)
			return true
		if cellar_spawn_grace_time > 0.0:
			continue
		if side.begins_with("down") and not on_ground and player_velocity.y > 40.0 and player_bottom > origin.y + CELLAR_FLOOR_Y + 14.0 and player_center_x >= zone.position.x and player_center_x <= zone.end.x:
			_transition_cellar_portal(portal, true)
			return true
	return false

func _try_cellar_interaction() -> void:
	if not Input.is_action_just_pressed("interact") or cellar_transition_time > 0.0 or cellar_focus_time > 0.55:
		return
	var player_rect: Rect2 = Rect2(player_position, PLAYER_SIZE)
	var origin: Vector2 = _cellar_region_origin(cellar_region)

	if cellar_region == "RS" and not cellar_has_rope and not cellar_rope_installed:
		var rope_zone: Rect2 = Rect2(origin + Vector2(675.0, 420.0), Vector2(220.0, 150.0))
		if player_rect.intersects(rope_zone):
			cellar_has_rope = true
			cellar_focus_time = 1.15
			cellar_focus_kind = "rope"
			return

	if cellar_region == "PS" and not cellar_has_pickaxe:
		var pickaxe_zone: Rect2 = Rect2(origin + Vector2(220.0, 410.0), Vector2(220.0, 160.0))
		if player_rect.intersects(pickaxe_zone):
			cellar_has_pickaxe = true
			cellar_focus_time = 1.15
			cellar_focus_kind = "pickaxe"
			return

	if cellar_region == "W" and not cellar_rope_installed:
		var well_anchor_zone: Rect2 = Rect2(origin + Vector2(560.0, 400.0), Vector2(150.0, 175.0))
		if player_rect.intersects(well_anchor_zone):
			cellar_focus_time = 1.0
			if cellar_has_rope:
				cellar_has_rope = false
				cellar_rope_installed = true
				cellar_focus_kind = "well"
			else:
				cellar_focus_kind = "need_rope"
			return

	if cellar_region == "WB":
		var rubble_zone: Rect2 = Rect2(origin + Vector2(430.0, 365.0), Vector2(285.0, 210.0))
		if player_rect.intersects(rubble_zone):
			if cellar_well_rubble_hits < CELLAR_WELL_RUBBLE_HITS_REQUIRED:
				if cellar_has_pickaxe:
					cellar_well_rubble_hits += 1
					cellar_wall_hit_time = 0.42
					_spawn_cellar_dust(origin + Vector2(570.0, 510.0), CELLAR_STONE_COLOR)
				else:
					cellar_focus_time = 1.0
					cellar_focus_kind = "need_pickaxe"
				return
			if not cellar_has_key:
				cellar_has_key = true
				cellar_key_collected = true
				cellar_focus_time = 1.8
				cellar_focus_kind = "key"
				return

	if cellar_region == "R":
		var prison_zone: Rect2 = Rect2(origin + Vector2(790.0, 315.0), Vector2(280.0, 270.0))
		if player_rect.intersects(prison_zone):
			if cellar_has_key:
				cellar_wall_hit_time = 0.42
				cellar_rescue_started = true
				cellar_focus_time = 2.7
				cellar_focus_kind = "rescue"
			else:
				cellar_focus_time = 1.0
				cellar_focus_kind = "need_key"
			return

	if not on_ground:
		return
	for portal in _cellar_portals():
		var side: String = String(portal["side"])
		if not side.begins_with("up"):
			continue
		var portal_zone: Rect2 = portal["zone"]
		if not player_rect.intersects(portal_zone):
			continue
		_start_cellar_ascent(portal)
		return

func _start_cellar_ascent(portal: Dictionary) -> void:
	cellar_ascent_active = true
	cellar_ascent_time = 0.0
	cellar_ascent_portal = portal.duplicate(true)
	var lift_zone: Rect2 = portal["zone"]
	cellar_ascent_start = Vector2(
		lift_zone.get_center().x - PLAYER_SIZE.x * 0.5,
		_cellar_region_origin(cellar_region).y + CELLAR_FLOOR_Y - PLAYER_SIZE.y - 2.0
	)
	player_position = cellar_ascent_start
	player_velocity = Vector2.ZERO
	on_ground = true
	regular_jump_active = false

func _cellar_ascent_ratio() -> float:
	var ratio: float = clampf(cellar_ascent_time / CELLAR_ASCENT_DURATION, 0.0, 1.0)
	return ratio * ratio * (3.0 - 2.0 * ratio)

func _cellar_is_active_ascent_portal(portal: Dictionary) -> bool:
	if not cellar_ascent_active or cellar_ascent_portal.is_empty():
		return false
	return (
		String(cellar_ascent_portal["side"]) == String(portal["side"])
		and String(cellar_ascent_portal["target"]) == String(portal["target"])
	)

func _update_cellar_ascent(delta: float) -> void:
	cellar_ascent_time = minf(CELLAR_ASCENT_DURATION, cellar_ascent_time + delta)
	var rise: float = CELLAR_ASCENT_HEIGHT * _cellar_ascent_ratio()
	player_position = cellar_ascent_start - Vector2(0.0, rise)
	player_velocity = Vector2.ZERO
	on_ground = true
	if cellar_ascent_time < CELLAR_ASCENT_DURATION:
		return
	var destination: Dictionary = cellar_ascent_portal.duplicate(true)
	cellar_ascent_active = false
	cellar_ascent_time = 0.0
	cellar_ascent_portal.clear()
	_transition_cellar_portal(destination, false)

func _spawn_cellar_dust(origin: Vector2, color_value: Color) -> void:
	for dust_index in range(7):
		var angle: float = -PI + float(dust_index) * PI / 6.0
		cellar_dust.append({
			"position": origin,
			"velocity": Vector2(cos(angle) * (35.0 + float(dust_index % 3) * 20.0), sin(angle) * 42.0 - 28.0),
			"life": 0.55,
			"color": color_value,
		})

func _update_cellar_dust(delta: float) -> void:
	for dust_index in range(cellar_dust.size() - 1, -1, -1):
		var dust: Dictionary = cellar_dust[dust_index]
		var life: float = float(dust["life"]) - delta
		var velocity: Vector2 = dust["velocity"]
		var position_value: Vector2 = dust["position"]
		velocity.y += GRAVITY * delta * 0.18
		position_value += velocity * delta
		dust["life"] = life
		dust["velocity"] = velocity
		dust["position"] = position_value
		cellar_dust[dust_index] = dust
		if life <= 0.0:
			cellar_dust.remove_at(dust_index)

func _start_cellar_failure(kind: String) -> void:
	if cellar_failure_time > 0.0:
		return
	cellar_failure_time = 0.001
	cellar_failure_kind = kind
	player_velocity = Vector2(-player_facing * 150.0, -210.0)
	on_ground = false
	regular_jump_active = false

func _update_cellar_failure(delta: float) -> void:
	cellar_failure_time += delta
	player_velocity.y += GRAVITY * delta
	player_position += player_velocity * delta
	if cellar_failure_time < 0.72:
		return
	cellar_failure_time = 0.0
	cellar_failure_kind = ""
	cellar_region = cellar_checkpoint_region
	player_position = cellar_checkpoint_position
	player_velocity = Vector2.ZERO
	on_ground = false
	regular_jump_active = false
	cellar_transition_time = 0.48
	cellar_spawn_grace_time = 0.22
	cellar_camera = _cellar_camera_target()
	cellar_dust.clear()
	failure_flash = 0.22

func _draw_cellar_maze() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), CELLAR_BG)
	_draw_cellar_background()
	for platform_rect in _cellar_platforms(cellar_region):
		_draw_cellar_platform(platform_rect)
	_draw_cellar_region_landmark()
	# Route openings stay above room dressing so landmarks never hide exits.
	_draw_cellar_portals()
	_draw_cellar_dust()
	_draw_cellar_context_prompt()

func _draw_cellar_background() -> void:
	var chamber: Rect2 = _cellar_region_rect(cellar_region)
	var chamber_screen: Rect2 = _world_rect_to_screen(chamber)
	draw_rect(chamber_screen, Color("101416"))
	# Repeated, offset rock contours make every screen feel like another stretch
	# of one continuous mine instead of a chain of enclosed rooms.
	for depth_index in range(5):
		var inset: float = 28.0 + float(depth_index) * 42.0
		var contour_color: Color = Color(CELLAR_LINE, 0.035 + float(depth_index) * 0.018)
		var contour: PackedVector2Array = PackedVector2Array([
			chamber_screen.position + Vector2(inset, 52.0),
			chamber_screen.position + Vector2(inset + 65.0, 118.0 + float(depth_index % 2) * 32.0),
			chamber_screen.position + Vector2(inset + 28.0, 255.0),
			chamber_screen.position + Vector2(inset + 86.0, 402.0),
		])
		draw_polyline(contour, contour_color, 5.0, true)
		var mirrored: PackedVector2Array = PackedVector2Array()
		for point in contour:
			mirrored.append(Vector2(chamber_screen.end.x - (point.x - chamber_screen.position.x), point.y + 17.0))
		draw_polyline(mirrored, contour_color, 5.0, true)
	for vein_index in range(8):
		var vein_x: float = chamber.position.x + 65.0 + float(vein_index) * 142.0
		var vein_start: Vector2 = _world_to_screen(Vector2(vein_x, chamber.position.y + 35.0))
		var vein_end: Vector2 = vein_start + Vector2(sin(float(vein_index) * 2.1) * 52.0, 90.0 + float(vein_index % 3) * 34.0)
		draw_line(vein_start, vein_end, Color("07090a"), 12.0 - float(vein_index % 3) * 2.0, true)
	if cellar_region == "A" or cellar_region == "B" or cellar_region == "C":
		var brick_alpha: float = 0.15 if cellar_region == "A" else 0.10 if cellar_region == "B" else 0.055
		for brick_row in range(5):
			for brick_column in range(8):
				var brick_x: float = chamber.position.x + 45.0 + float(brick_column) * 138.0 + (58.0 if brick_row % 2 == 1 else 0.0)
				var brick_y: float = chamber.position.y + 145.0 + float(brick_row) * 73.0
				draw_rect(_world_rect_to_screen(Rect2(brick_x, brick_y, 108.0, 43.0)), Color(CELLAR_LINE, brick_alpha), false, 2.0)
	var left_wall: PackedVector2Array = PackedVector2Array([
		chamber_screen.position, chamber_screen.position + Vector2(92.0, 0.0),
		chamber_screen.position + Vector2(125.0, 126.0), chamber_screen.position + Vector2(82.0, 255.0),
		chamber_screen.position + Vector2(132.0, 390.0), chamber_screen.position + Vector2(105.0, chamber_screen.size.y),
		chamber_screen.position + Vector2(0.0, chamber_screen.size.y),
	])
	draw_polygon(left_wall, PackedColorArray([Color("050708")]))
	var right_wall: PackedVector2Array = PackedVector2Array()
	for point in left_wall:
		right_wall.append(Vector2(chamber_screen.end.x - (point.x - chamber_screen.position.x), point.y))
	draw_polygon(right_wall, PackedColorArray([Color("050708")]))

func _draw_cellar_region_landmark() -> void:
	var origin: Vector2 = _cellar_region_origin(cellar_region)
	match cellar_region:
		"A": _draw_cellar_entrance(origin)
		"B": _draw_cellar_wine_room(origin)
		"C": _draw_cellar_root_breach(origin)
		"D": _draw_cellar_drop_room(origin)
		"E": _draw_cellar_track_slope(origin)
		"F": _draw_cellar_collapsed_working(origin)
		"G": _draw_cellar_hub(origin)
		"H": _draw_cellar_high_bridge(origin)
		"I": _draw_cellar_main_tunnel(origin)
		"J": _draw_cellar_snake_supports(origin)
		"K": _draw_cellar_survey_crosscut(origin)
		"L": _draw_cellar_broken_trolley(origin)
		"M": _draw_cellar_seepage(origin)
		"N": _draw_cellar_rock_room(origin)
		"O": _draw_cellar_confluence(origin)
		"Q": _draw_cellar_cage_gallery(origin)
		"RS": _draw_cellar_rope_cache(origin)
		"PS": _draw_cellar_pickaxe_cache(origin)
		"W": _draw_cellar_well(origin)
		"WB": _draw_cellar_well_bottom(origin)
		"R": _draw_cellar_prison(origin)
		"X1", "X2", "X3": _draw_cellar_dead_end(origin)
		_: _draw_cellar_mine_segment(origin)

func _draw_cellar_transition_segment(origin: Vector2) -> void:
	for beam_index in range(3):
		var beam_x: float = origin.x + 260.0 + float(beam_index) * 300.0
		draw_line(_world_to_screen(Vector2(beam_x, origin.y + 235.0)), _world_to_screen(Vector2(beam_x, origin.y + 560.0)), Color(CELLAR_LINE, 0.22), 9.0, true)
		draw_line(_world_to_screen(Vector2(beam_x - 45.0, origin.y + 235.0)), _world_to_screen(Vector2(beam_x + 80.0, origin.y + 235.0)), Color(CELLAR_LINE, 0.22), 9.0, true)
	if cellar_region == "B":
		for barrel_index in range(4):
			var barrel_center: Vector2 = _world_to_screen(origin + Vector2(300.0 + float(barrel_index) * 155.0, 520.0))
			draw_circle(barrel_center, 35.0, Color(CELLAR_LINE, 0.13))
			draw_circle(barrel_center, 35.0, Color(CELLAR_LINE, 0.30), false, 3.0, true)
	if cellar_region == "C":
		for rock_index in range(6):
			_draw_cellar_stone(_world_to_screen(origin + Vector2(300.0 + float(rock_index) * 110.0, 525.0 - float(rock_index % 2) * 17.0)), 22.0 + float(rock_index % 3) * 5.0)

func _draw_cellar_mine_segment(origin: Vector2) -> void:
	var segment_seed: int = absi(cellar_region.hash())
	for support_index in range(3):
		var support_x: float = origin.x + 250.0 + float(support_index) * 310.0 + float(segment_seed % 31)
		draw_line(_world_to_screen(Vector2(support_x, origin.y + 250.0)), _world_to_screen(Vector2(support_x, origin.y + 560.0)), Color(HEMP, 0.42), 10.0, true)
		draw_line(_world_to_screen(Vector2(support_x - 48.0, origin.y + 250.0)), _world_to_screen(Vector2(support_x + 70.0, origin.y + 250.0)), Color(HEMP, 0.42), 10.0, true)
	for rail_index in range(2):
		var rail_y: float = origin.y + 548.0 + float(rail_index) * 9.0
		draw_line(_world_to_screen(Vector2(origin.x + 120.0, rail_y)), _world_to_screen(Vector2(origin.x + 1000.0, rail_y)), Color(CELLAR_LINE, 0.20), 3.0, true)
	for tie_index in range(10):
		var tie_x: float = origin.x + 150.0 + float(tie_index) * 92.0
		draw_line(_world_to_screen(Vector2(tie_x, origin.y + 540.0)), _world_to_screen(Vector2(tie_x + 18.0, origin.y + 566.0)), Color(HEMP, 0.35), 5.0, true)

func _draw_cellar_entrance(origin: Vector2) -> void:
	_draw_cellar_transition_segment(origin)
	var hatch: Rect2 = _world_rect_to_screen(Rect2(origin + Vector2(420.0, 72.0), Vector2(280.0, 72.0)))
	draw_rect(hatch, Color("050708"))
	draw_rect(hatch, Color(CELLAR_LINE, 0.40), false, 6.0)
	for slat_index in range(5):
		var slat_x: float = hatch.position.x + 28.0 + float(slat_index) * 55.0
		draw_line(Vector2(slat_x, hatch.position.y + 8.0), Vector2(slat_x, hatch.end.y - 8.0), Color(HEMP, 0.34), 5.0, true)
	var light_wedge: PackedVector2Array = PackedVector2Array([
		hatch.position + Vector2(55.0, hatch.size.y),
		hatch.end - Vector2(55.0, 0.0),
		_world_to_screen(origin + Vector2(790.0, 505.0)),
		_world_to_screen(origin + Vector2(330.0, 505.0)),
	])
	draw_polygon(light_wedge, PackedColorArray([Color(PAPER, 0.035)]))

func _draw_cellar_root_breach(origin: Vector2) -> void:
	_draw_cellar_transition_segment(origin)
	for root_index in range(7):
		var root_x: float = origin.x + 100.0 + float(root_index) * 155.0
		var sway: float = sin(float(root_index) * 1.8) * 54.0
		var points: PackedVector2Array = PackedVector2Array([
			_world_to_screen(Vector2(root_x, origin.y + 18.0)),
			_world_to_screen(Vector2(root_x + sway, origin.y + 170.0)),
			_world_to_screen(Vector2(root_x - sway * 0.35, origin.y + 350.0)),
			_world_to_screen(Vector2(root_x + sway * 0.65, origin.y + 540.0)),
		])
		draw_polyline(points, Color(HEMP, 0.34 + float(root_index % 2) * 0.10), 11.0 - float(root_index % 3) * 2.0, true)
	draw_arc(_world_to_screen(origin + Vector2(560.0, 185.0)), 138.0, PI * 0.08, PI * 0.92, 30, Color(CELLAR_LINE, 0.20), 7.0, true)

func _draw_cellar_track_slope(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var rail_start: Vector2 = _world_to_screen(origin + Vector2(145.0, 475.0))
	var rail_end: Vector2 = _world_to_screen(origin + Vector2(960.0, 330.0))
	for rail_offset in [-10.0, 10.0]:
		draw_line(rail_start + Vector2(0.0, rail_offset), rail_end + Vector2(0.0, rail_offset), Color(CELLAR_LINE, 0.34), 4.0, true)
	for tie_index in range(9):
		var ratio: float = float(tie_index) / 8.0
		var tie_center: Vector2 = rail_start.lerp(rail_end, ratio)
		draw_line(tie_center + Vector2(-18.0, -16.0), tie_center + Vector2(18.0, 16.0), Color(HEMP, 0.48), 6.0, true)
	var brake_wheel: Vector2 = _world_to_screen(origin + Vector2(275.0, 390.0))
	draw_circle(brake_wheel, 38.0, Color("0b0e0f"))
	draw_circle(brake_wheel, 38.0, Color(CELLAR_LINE, 0.42), false, 5.0, true)
	for spoke_index in range(6):
		var angle: float = float(spoke_index) * TAU / 6.0
		draw_line(brake_wheel, brake_wheel + Vector2(cos(angle), sin(angle)) * 34.0, Color(CELLAR_LINE, 0.30), 3.0, true)

func _draw_cellar_collapsed_working(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var collapse_peak: Vector2 = _world_to_screen(origin + Vector2(575.0, 210.0))
	for beam_index in range(6):
		var foot_x: float = origin.x + 250.0 + float(beam_index) * 135.0
		var foot: Vector2 = _world_to_screen(Vector2(foot_x, origin.y + 548.0))
		var lean: Vector2 = collapse_peak + Vector2((float(beam_index) - 2.5) * 24.0, float(beam_index % 2) * 32.0)
		draw_line(foot, lean, Color(HEMP, 0.54), 12.0, true)
	for rock_index in range(9):
		var rock_center: Vector2 = _world_to_screen(origin + Vector2(420.0 + float(rock_index % 5) * 70.0, 522.0 - float(rock_index / 5) * 55.0))
		_draw_cellar_stone(rock_center, 18.0 + float(rock_index % 3) * 5.0)

func _draw_cellar_main_tunnel(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var tall_arch_center: Vector2 = _world_to_screen(origin + Vector2(560.0, 370.0))
	draw_arc(tall_arch_center, 235.0, PI, TAU, 38, Color(CELLAR_LINE, 0.34), 11.0, true)
	draw_line(tall_arch_center + Vector2(-235.0, 0.0), tall_arch_center + Vector2(-235.0, 180.0), Color(CELLAR_LINE, 0.34), 11.0, true)
	draw_line(tall_arch_center + Vector2(235.0, 0.0), tall_arch_center + Vector2(235.0, 180.0), Color(CELLAR_LINE, 0.34), 11.0, true)
	for chain_index in range(3):
		var chain_x: float = origin.x + 430.0 + float(chain_index) * 130.0
		for link_index in range(6):
			var link_center: Vector2 = _world_to_screen(Vector2(chain_x, origin.y + 80.0 + float(link_index) * 34.0))
			draw_arc(link_center, 10.0, 0.0, TAU, 12, Color(CELLAR_LINE, 0.32), 3.0, true)
	var direction_board: Rect2 = _world_rect_to_screen(Rect2(origin + Vector2(770.0, 285.0), Vector2(155.0, 72.0)))
	draw_rect(direction_board, Color("111617"))
	draw_rect(direction_board, Color(HEMP, 0.52), false, 5.0)
	draw_line(direction_board.position + Vector2(25.0, 36.0), direction_board.end - Vector2(25.0, 36.0), Color(CELLAR_LINE, 0.42), 5.0, true)

func _draw_cellar_snake_supports(origin: Vector2) -> void:
	for support_index in range(5):
		var base_x: float = origin.x + 145.0 + float(support_index) * 205.0
		var bend: float = (-1.0 if support_index % 2 == 0 else 1.0) * (42.0 + float(support_index % 3) * 12.0)
		var support: PackedVector2Array = PackedVector2Array([
			_world_to_screen(Vector2(base_x, origin.y + 555.0)),
			_world_to_screen(Vector2(base_x + bend, origin.y + 430.0)),
			_world_to_screen(Vector2(base_x - bend * 0.5, origin.y + 300.0)),
			_world_to_screen(Vector2(base_x + bend * 0.25, origin.y + 190.0)),
		])
		draw_polyline(support, Color(HEMP, 0.52), 10.0, true)
	draw_polyline(PackedVector2Array([
		_world_to_screen(origin + Vector2(80.0, 255.0)),
		_world_to_screen(origin + Vector2(330.0, 205.0)),
		_world_to_screen(origin + Vector2(600.0, 265.0)),
		_world_to_screen(origin + Vector2(850.0, 190.0)),
		_world_to_screen(origin + Vector2(1040.0, 245.0)),
	]), Color(CELLAR_LINE, 0.24), 8.0, true)

func _draw_cellar_survey_crosscut(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var board: Rect2 = _world_rect_to_screen(Rect2(origin + Vector2(365.0, 190.0), Vector2(390.0, 245.0)))
	draw_rect(board, Color("101416"))
	draw_rect(board, Color(HEMP, 0.48), false, 7.0)
	for grid_index in range(1, 4):
		var grid_x: float = board.position.x + float(grid_index) * board.size.x / 4.0
		draw_line(Vector2(grid_x, board.position.y), Vector2(grid_x, board.end.y), Color(CELLAR_LINE, 0.13), 2.0, true)
	for grid_index in range(1, 3):
		var grid_y: float = board.position.y + float(grid_index) * board.size.y / 3.0
		draw_line(Vector2(board.position.x, grid_y), Vector2(board.end.x, grid_y), Color(CELLAR_LINE, 0.13), 2.0, true)
	var route: PackedVector2Array = PackedVector2Array([
		board.position + Vector2(35.0, 190.0),
		board.position + Vector2(115.0, 120.0),
		board.position + Vector2(205.0, 145.0),
		board.position + Vector2(275.0, 60.0),
		board.position + Vector2(350.0, 85.0),
	])
	draw_polyline(route, Color(PAPER, 0.42), 4.0, true)
	for route_point in route:
		draw_circle(route_point, 7.0, Color(PAPER, 0.48))

func _draw_cellar_broken_trolley(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var cart: Rect2 = _world_rect_to_screen(Rect2(origin + Vector2(430.0, 405.0), Vector2(290.0, 105.0)))
	var cart_body: PackedVector2Array = PackedVector2Array([
		cart.position,
		cart.position + Vector2(cart.size.x, 18.0),
		cart.end - Vector2(42.0, 0.0),
		cart.end - Vector2(cart.size.x - 42.0, 0.0),
	])
	draw_polygon(cart_body, PackedColorArray([Color("222729")]))
	draw_polyline(cart_body, Color(CELLAR_LINE, 0.42), 6.0, true)
	draw_circle(cart.end - Vector2(225.0, -8.0), 29.0, Color("090c0d"))
	draw_circle(cart.end - Vector2(225.0, -8.0), 29.0, Color(CELLAR_LINE, 0.40), false, 5.0, true)
	var detached_wheel: Vector2 = _world_to_screen(origin + Vector2(790.0, 526.0))
	draw_circle(detached_wheel, 29.0, Color("090c0d"))
	draw_circle(detached_wheel, 29.0, Color(CELLAR_LINE, 0.40), false, 5.0, true)
	draw_line(cart.position + Vector2(18.0, -28.0), cart.end + Vector2(-18.0, 25.0), Color(HEMP, 0.56), 8.0, true)

func _draw_cellar_cage_gallery(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	for cage_index in range(3):
		var cage: Rect2 = _world_rect_to_screen(Rect2(origin + Vector2(195.0 + float(cage_index) * 275.0, 245.0), Vector2(185.0, 285.0)))
		draw_rect(cage, Color("050708"))
		draw_rect(cage, Color(CELLAR_LINE, 0.40), false, 6.0)
		for bar_index in range(4):
			var bar_x: float = cage.position.x + 28.0 + float(bar_index) * 43.0
			draw_line(Vector2(bar_x, cage.position.y), Vector2(bar_x, cage.end.y), Color(CELLAR_LINE, 0.32), 4.0, true)
		var hanging_x: float = cage.get_center().x
		draw_line(Vector2(hanging_x, cage.position.y - 130.0), Vector2(hanging_x, cage.position.y), Color(CELLAR_LINE, 0.24), 4.0, true)

func _draw_cellar_rope_cache(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var hoist_center: Vector2 = _world_to_screen(origin + Vector2(790.0, 420.0))
	draw_line(hoist_center + Vector2(-95.0, 120.0), hoist_center + Vector2(-55.0, -100.0), Color(HEMP, 0.48), 10.0, true)
	draw_line(hoist_center + Vector2(95.0, 120.0), hoist_center + Vector2(55.0, -100.0), Color(HEMP, 0.48), 10.0, true)
	draw_line(hoist_center + Vector2(-55.0, -100.0), hoist_center + Vector2(55.0, -100.0), Color(HEMP, 0.48), 10.0, true)
	if not cellar_has_rope and not cellar_rope_installed:
		_draw_cellar_rope_icon(hoist_center + Vector2(0.0, 65.0), 1.0, 1.0)

func _draw_cellar_pickaxe_cache(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var rack: Rect2 = _world_rect_to_screen(Rect2(origin + Vector2(220.0, 355.0), Vector2(220.0, 205.0)))
	draw_line(rack.position, Vector2(rack.position.x, rack.end.y), Color(HEMP, 0.42), 8.0, true)
	draw_line(Vector2(rack.end.x, rack.position.y), rack.end, Color(HEMP, 0.42), 8.0, true)
	draw_line(rack.position, Vector2(rack.end.x, rack.position.y), Color(HEMP, 0.42), 8.0, true)
	if not cellar_has_pickaxe:
		_draw_cellar_pickaxe_icon(rack.get_center() + Vector2(0.0, 22.0), 1.0, 1.0)

func _draw_cellar_well(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var center: Vector2 = _world_to_screen(origin + Vector2(820.0, 535.0))
	_draw_cellar_ellipse(center + Vector2(0.0, 8.0), Vector2(92.0, 26.0), Color("020304"))
	draw_arc(center, 92.0, PI, TAU, 28, Color(CELLAR_LINE, 0.46), 7.0, true)
	draw_line(center + Vector2(-105.0, 22.0), center + Vector2(-105.0, -120.0), Color(HEMP, 0.48), 10.0, true)
	draw_line(center + Vector2(105.0, 22.0), center + Vector2(105.0, -120.0), Color(HEMP, 0.48), 10.0, true)
	draw_line(center + Vector2(-105.0, -120.0), center + Vector2(105.0, -120.0), Color(HEMP, 0.48), 10.0, true)
	if cellar_rope_installed:
		draw_line(center + Vector2(0.0, -112.0), center + Vector2(0.0, 110.0), HEMP, 7.0, true)
	else:
		draw_line(center + Vector2(-8.0, -112.0), center + Vector2(-2.0, -70.0), Color(HEMP, 0.52), 7.0, true)
		_draw_cellar_rope_icon(center + Vector2(0.0, -58.0), 0.48, 0.28)

func _draw_cellar_well_bottom(origin: Vector2) -> void:
	for rope_index in range(2):
		var rope_x: float = origin.x + 790.0 + float(rope_index) * 42.0
		draw_line(_world_to_screen(Vector2(rope_x, origin.y + 35.0)), _world_to_screen(Vector2(rope_x, origin.y + 520.0)), Color(HEMP, 0.44), 5.0, true)
	var remaining: int = maxi(0, 13 - cellar_well_rubble_hits * 4)
	for rock_index in range(remaining):
		var column: int = rock_index % 5
		var row: int = int(rock_index / 5)
		var rock_center: Vector2 = _world_to_screen(origin + Vector2(470.0 + float(column) * 55.0 + float(row) * 16.0, 525.0 - float(row) * 42.0))
		_draw_cellar_stone(rock_center, 21.0 + float(rock_index % 3) * 5.0)
	if cellar_well_rubble_hits >= CELLAR_WELL_RUBBLE_HITS_REQUIRED and not cellar_has_key:
		var key_center: Vector2 = _world_to_screen(origin + Vector2(570.0, 505.0))
		draw_circle(key_center, 48.0, Color(CELLAR_KEY_COLOR, 0.10))
		_draw_cellar_key(key_center, 0.78, 1.0)
	elif cellar_focus_kind == "need_pickaxe" and cellar_focus_time > 0.0:
		var hint_center: Vector2 = _world_to_screen(origin + Vector2(570.0, 390.0))
		var hint_alpha: float = 0.42 + sin(elapsed * 8.0) * 0.16
		draw_circle(hint_center, 48.0, Color(PAPER, hint_alpha * 0.12))
		_draw_cellar_pickaxe_icon(hint_center, 0.65, hint_alpha)

func _draw_cellar_dead_end(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	if cellar_region == "X1":
		for rock_index in range(18):
			var column: int = rock_index % 6
			var row: int = int(rock_index / 6)
			var center: Vector2 = _world_to_screen(origin + Vector2(430.0 + float(column) * 48.0 - float(row) * 18.0, 532.0 - float(row) * 47.0))
			_draw_cellar_stone(center, 24.0 + float(rock_index % 4) * 4.0)
		draw_line(_world_to_screen(origin + Vector2(330.0, 210.0)), _world_to_screen(origin + Vector2(760.0, 540.0)), Color(HEMP, 0.58), 15.0, true)
		draw_line(_world_to_screen(origin + Vector2(790.0, 180.0)), _world_to_screen(origin + Vector2(460.0, 545.0)), Color(HEMP, 0.52), 13.0, true)
	elif cellar_region == "X2":
		var fissure: PackedVector2Array = PackedVector2Array([
			_world_to_screen(origin + Vector2(560.0, 35.0)),
			_world_to_screen(origin + Vector2(505.0, 145.0)),
			_world_to_screen(origin + Vector2(585.0, 245.0)),
			_world_to_screen(origin + Vector2(515.0, 360.0)),
			_world_to_screen(origin + Vector2(565.0, 555.0)),
		])
		draw_polyline(fissure, Color("020304"), 34.0, true)
		draw_polyline(fissure, Color(CELLAR_LINE, 0.34), 5.0, true)
		for echo_index in range(4):
			draw_arc(_world_to_screen(origin + Vector2(560.0, 360.0)), 70.0 + float(echo_index) * 42.0, PI * 1.12, PI * 1.88, 20, Color(CELLAR_LINE, 0.08), 2.0, true)
	else:
		var bumper: Vector2 = _world_to_screen(origin + Vector2(770.0, 512.0))
		draw_line(bumper + Vector2(-55.0, 38.0), bumper + Vector2(0.0, -95.0), Color(HEMP, 0.58), 11.0, true)
		draw_line(bumper + Vector2(55.0, 38.0), bumper + Vector2(0.0, -95.0), Color(HEMP, 0.58), 11.0, true)
		var minecart: Rect2 = _world_rect_to_screen(Rect2(origin + Vector2(420.0, 410.0), Vector2(250.0, 105.0)))
		draw_rect(minecart, Color("222729"))
		draw_rect(minecart, Color(CELLAR_LINE, 0.42), false, 6.0)
		draw_circle(minecart.end + Vector2(-190.0, 20.0), 27.0, Color("060809"))
		draw_circle(minecart.end + Vector2(-55.0, 20.0), 27.0, Color("060809"))
		draw_circle(minecart.end + Vector2(-190.0, 20.0), 27.0, Color(CELLAR_LINE, 0.36), false, 5.0, true)
		draw_circle(minecart.end + Vector2(-55.0, 20.0), 27.0, Color(CELLAR_LINE, 0.36), false, 5.0, true)

func _draw_cellar_rope_icon(center: Vector2, scale_factor: float, alpha: float) -> void:
	for ring_index in range(3):
		draw_arc(center, (30.0 - float(ring_index) * 7.0) * scale_factor, 0.0, TAU, 28, Color(HEMP, alpha), 5.0 * scale_factor, true)
	draw_line(center + Vector2(22.0, 20.0) * scale_factor, center + Vector2(42.0, 38.0) * scale_factor, Color(HEMP, alpha), 5.0 * scale_factor, true)

func _draw_cellar_pickaxe_icon(center: Vector2, scale_factor: float, alpha: float) -> void:
	draw_line(center + Vector2(-24.0, 44.0) * scale_factor, center + Vector2(18.0, -32.0) * scale_factor, Color(HEMP, alpha), 7.0 * scale_factor, true)
	draw_arc(center + Vector2(13.0, -29.0) * scale_factor, 34.0 * scale_factor, PI * 1.12, PI * 1.90, 18, Color(CELLAR_STONE_COLOR, alpha), 7.0 * scale_factor, true)

func _draw_cellar_ellipse(center: Vector2, radii: Vector2, color_value: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index in range(32):
		var angle: float = float(point_index) * TAU / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polygon(points, PackedColorArray([color_value]))

func _draw_cellar_hub(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var cistern_center := _world_to_screen(origin + Vector2(655.0, 300.0))
	for ring_index in range(4):
		draw_arc(cistern_center, 125.0 + float(ring_index) * 28.0, PI, TAU, 42, Color(CELLAR_LINE, 0.12 + float(ring_index) * 0.035), 5.0, true)
	var grate := _world_rect_to_screen(Rect2(origin + Vector2(430.0, 118.0), Vector2(260.0, 104.0)))
	draw_rect(grate, Color("07090a"))
	draw_rect(grate, Color(CELLAR_LINE, 0.38), false, 5.0)
	for bar_index in range(7):
		var bar_x: float = grate.position.x + 24.0 + float(bar_index) * 35.0
		draw_line(Vector2(bar_x, grate.position.y), Vector2(bar_x, grate.end.y), Color(CELLAR_LINE, 0.34), 4.0, true)
	var help_phase: float = fmod(elapsed, 3.8)
	if help_phase < 1.8 and not cellar_has_key:
		var wave_center := _world_to_screen(origin + Vector2(1040.0, 430.0))
		var wave_alpha: float = sin(help_phase / 1.8 * PI) * 0.28
		for wave_index in range(3):
			draw_arc(wave_center, 24.0 + float(wave_index) * 19.0 + help_phase * 8.0, PI * 0.65, PI * 1.35, 16, Color(PAPER, wave_alpha), 2.0, true)

func _draw_cellar_wine_room(origin: Vector2) -> void:
	_draw_cellar_transition_segment(origin)
	for rack_index in range(3):
		var rack := _world_rect_to_screen(Rect2(origin + Vector2(190.0 + float(rack_index) * 285.0, 235.0), Vector2(205.0, 300.0)))
		draw_rect(rack, Color("0b0e0f"))
		draw_rect(rack, Color(CELLAR_LINE, 0.42), false, 5.0)
		for shelf_index in range(3):
			var shelf_y: float = rack.position.y + 70.0 + float(shelf_index) * 78.0
			draw_line(Vector2(rack.position.x, shelf_y), Vector2(rack.end.x, shelf_y), Color(CELLAR_LINE, 0.35), 4.0, true)
			for bottle_index in range(4):
				var bottle_center := Vector2(rack.position.x + 29.0 + float(bottle_index) * 48.0, shelf_y - 17.0)
				draw_rect(Rect2(bottle_center - Vector2(7.0, 17.0), Vector2(14.0, 28.0)), Color(CELLAR_LINE, 0.18))
				draw_line(bottle_center - Vector2(3.0, 22.0), bottle_center + Vector2(3.0, -22.0), Color(CELLAR_LINE, 0.28), 3.0, true)

func _draw_cellar_store_room(origin: Vector2) -> void:
	for crate_index in range(8):
		var crate_world := Rect2(origin + Vector2(145.0 + float(crate_index % 4) * 205.0, 470.0 - float(crate_index / 4) * 112.0), Vector2(145.0, 88.0))
		var crate := _world_rect_to_screen(crate_world)
		draw_rect(crate, Color("15191a"))
		draw_rect(crate, Color(CELLAR_LINE, 0.34), false, 4.0)
		draw_line(crate.position + Vector2(9.0, 8.0), crate.end - Vector2(9.0, 8.0), Color(CELLAR_LINE, 0.23), 3.0, true)
		draw_line(Vector2(crate.end.x - 9.0, crate.position.y + 8.0), Vector2(crate.position.x + 9.0, crate.end.y - 8.0), Color(CELLAR_LINE, 0.23), 3.0, true)

func _draw_cellar_drop_room(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	for beam_index in range(5):
		var beam_start := _world_to_screen(origin + Vector2(90.0 + float(beam_index) * 235.0, 120.0 + float(beam_index % 2) * 72.0))
		draw_line(beam_start, beam_start + Vector2(150.0, 70.0), Color(CELLAR_LINE, 0.27), 9.0, true)

func _draw_cellar_high_bridge(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	draw_line(_world_to_screen(origin + Vector2(210.0, 268.0)), _world_to_screen(origin + Vector2(910.0, 268.0)), Color(HEMP, 0.28), 5.0, true)
	draw_line(_world_to_screen(origin + Vector2(190.0, 292.0)), _world_to_screen(origin + Vector2(930.0, 292.0)), Color(CELLAR_LINE, 0.16), 3.0, true)
	for post_index in range(5):
		var post_x: float = origin.x + 250.0 + float(post_index) * 150.0
		draw_line(_world_to_screen(Vector2(post_x, origin.y + 268.0)), _world_to_screen(Vector2(post_x, origin.y + 560.0)), Color(HEMP, 0.22), 5.0, true)

func _draw_cellar_seepage(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	for drip_index in range(7):
		var drip_x: float = origin.x + 180.0 + float(drip_index) * 110.0
		var drip_phase: float = fmod(elapsed * 1.6 + float(drip_index) * 0.37, 1.0)
		var drip_start := _world_to_screen(Vector2(drip_x, origin.y + 90.0))
		var drip_end := _world_to_screen(Vector2(drip_x - 6.0, origin.y + 90.0 + drip_phase * 430.0))
		draw_line(drip_start, drip_end, Color(WATER, 0.18 + drip_phase * 0.16), 2.0, true)
	var pool := _world_to_screen(origin + Vector2(560.0, 552.0))
	_draw_cellar_ellipse(pool, Vector2(210.0, 16.0), Color(WATER, 0.10))
	draw_arc(pool, 210.0, PI, TAU, 22, Color(WATER, 0.22), 3.0, true)

func _draw_cellar_confluence(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	var knot := _world_to_screen(origin + Vector2(560.0, 250.0))
	for ring_index in range(3):
		draw_arc(knot, 48.0 + float(ring_index) * 22.0, PI * 0.15, PI * 0.85, 18, Color(CELLAR_LINE, 0.16 + float(ring_index) * 0.06), 5.0, true)
	draw_line(_world_to_screen(origin + Vector2(180.0, 210.0)), knot, Color(CELLAR_LINE, 0.22), 6.0, true)
	draw_line(_world_to_screen(origin + Vector2(940.0, 210.0)), knot, Color(CELLAR_LINE, 0.22), 6.0, true)
	draw_line(knot, _world_to_screen(origin + Vector2(560.0, 520.0)), Color(HEMP, 0.30), 5.0, true)

func _draw_cellar_false_gallery(origin: Vector2) -> void:
	for arch_index in range(5):
		var arch_center := _world_to_screen(origin + Vector2(150.0 + float(arch_index) * 205.0, 365.0))
		draw_arc(arch_center, 82.0, PI, TAU, 24, Color(CELLAR_LINE, 0.28 if arch_index != 2 else 0.12), 7.0, true)
		draw_line(arch_center + Vector2(-82.0, 0.0), arch_center + Vector2(-82.0, 170.0), Color(CELLAR_LINE, 0.28), 7.0, true)
		draw_line(arch_center + Vector2(82.0, 0.0), arch_center + Vector2(82.0, 170.0), Color(CELLAR_LINE, 0.28), 7.0, true)

func _draw_cellar_chain_room(origin: Vector2) -> void:
	for blade_index in range(3):
		var pivot := origin + Vector2(300.0 + float(blade_index) * 255.0, 105.0)
		var swing_angle: float = sin(elapsed * 1.65 + float(blade_index) * 1.7) * 0.72
		var center: Vector2 = pivot + Vector2(sin(swing_angle) * 190.0, cos(swing_angle) * 190.0)
		draw_line(_world_to_screen(pivot), _world_to_screen(center), Color(CELLAR_LINE, 0.46), 4.0, true)
		draw_circle(_world_to_screen(center), 25.0, CELLAR_STONE_COLOR)
		draw_circle(_world_to_screen(center), 25.0, CELLAR_BG, false, 4.0, true)
		for tooth_index in range(8):
			var angle: float = float(tooth_index) * TAU / 8.0
			var tooth_start := _world_to_screen(center) + Vector2(cos(angle), sin(angle)) * 23.0
			var tooth_end := _world_to_screen(center) + Vector2(cos(angle), sin(angle)) * 35.0
			draw_line(tooth_start, tooth_end, CELLAR_STONE_COLOR, 5.0, true)

func _draw_cellar_rock_room(origin: Vector2) -> void:
	_draw_cellar_mine_segment(origin)
	for crack_index in range(6):
		var crack_start := _world_to_screen(origin + Vector2(135.0 + float(crack_index) * 175.0, 15.0))
		var crack_points := PackedVector2Array([crack_start, crack_start + Vector2(-20.0, 62.0), crack_start + Vector2(14.0, 112.0), crack_start + Vector2(-8.0, 170.0)])
		draw_polyline(crack_points, Color(CELLAR_LINE, 0.26), 4.0, true)

func _draw_cellar_prison(origin: Vector2) -> void:
	var cell: Rect2 = _world_rect_to_screen(Rect2(origin + Vector2(760.0, 205.0), Vector2(310.0, 355.0)))
	draw_rect(cell, Color("050708"))
	for bar_index in range(7):
		var bar_x: float = cell.position.x + 22.0 + float(bar_index) * 44.0
		draw_line(Vector2(bar_x, cell.position.y), Vector2(bar_x, cell.end.y), Color(CELLAR_LINE, 0.72), 7.0, true)
	draw_line(cell.position, Vector2(cell.end.x, cell.position.y), Color(CELLAR_LINE, 0.72), 8.0, true)
	var lock_center: Vector2 = _world_to_screen(origin + Vector2(805.0, 415.0))
	draw_rect(Rect2(lock_center - Vector2(17.0, 19.0), Vector2(34.0, 38.0)), CELLAR_KEY_COLOR if cellar_has_key else CELLAR_STONE_COLOR)
	draw_circle(lock_center, 5.0, CELLAR_BG)
	if cellar_focus_kind == "need_key" and cellar_focus_time > 0.0:
		var key_hint_alpha: float = 0.42 + sin(elapsed * 8.0) * 0.16
		_draw_cellar_key(lock_center + Vector2(-78.0, -62.0), 0.48, key_hint_alpha)
	var mage_center: Vector2 = _world_to_screen(origin + Vector2(940.0, 468.0))
	draw_circle(mage_center + Vector2(0.0, -72.0), 17.0, PALE)
	draw_arc(mage_center + Vector2(0.0, -72.0), 28.0, PI, TAU, 18, PALE, 7.0, true)
	draw_line(mage_center + Vector2(0.0, -55.0), mage_center + Vector2(-9.0, 0.0), PALE, 8.0, true)
	draw_line(mage_center + Vector2(-9.0, 0.0), mage_center + Vector2(-30.0, 47.0), PALE, 6.0, true)
	draw_line(mage_center + Vector2(-2.0, -38.0), mage_center + Vector2(42.0, 32.0), HEMP, 5.0, true)
	if not cellar_rescue_started:
		var help_phase: float = fmod(elapsed, 3.2)
		if help_phase < 1.45:
			var help_alpha: float = sin(help_phase / 1.45 * PI)
			draw_string(ui_font, mage_center + Vector2(-33.0, -116.0), "Help…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(PAPER, help_alpha * 0.72))
			for ring_index in range(2):
				draw_arc(mage_center + Vector2(0.0, -72.0), 35.0 + float(ring_index) * 16.0 + help_phase * 7.0, PI * 1.08, PI * 1.92, 16, Color(PAPER, help_alpha * 0.32), 2.0, true)

func _draw_cellar_portals() -> void:
	for portal in _cellar_portals():
		var zone: Rect2 = portal["zone"]
		var side: String = String(portal["side"])
		var screen_zone: Rect2 = _world_rect_to_screen(zone)
		if side == "left" or side == "right":
			var edge_x: float = screen_zone.position.x if side == "left" else screen_zone.end.x
			var inward: float = 1.0 if side == "left" else -1.0
			var tunnel: PackedVector2Array = PackedVector2Array([
				Vector2(edge_x, screen_zone.position.y - 18.0),
				Vector2(edge_x + inward * 118.0, screen_zone.position.y + 14.0),
				Vector2(edge_x + inward * 94.0, screen_zone.end.y),
				Vector2(edge_x, screen_zone.end.y),
			])
			draw_polygon(tunnel, PackedColorArray([Color("020304")]))
			draw_line(Vector2(edge_x, screen_zone.position.y - 18.0), Vector2(edge_x + inward * 118.0, screen_zone.position.y + 14.0), Color(CELLAR_LINE, 0.22), 5.0, true)
			for rail_offset in range(2):
				var rail_y: float = screen_zone.end.y - 22.0 + float(rail_offset) * 9.0
				draw_line(Vector2(edge_x, rail_y), Vector2(edge_x + inward * 145.0, rail_y - 4.0), Color(CELLAR_LINE, 0.24), 3.0, true)
		elif side.begins_with("down"):
			var pit_center: Vector2 = Vector2(screen_zone.get_center().x, screen_zone.end.y - 21.0)
			_draw_cellar_ellipse(pit_center, Vector2(screen_zone.size.x * 0.42, 23.0), Color("020304"))
			draw_arc(pit_center, screen_zone.size.x * 0.42, PI, TAU, 24, Color(CELLAR_LINE, 0.32), 5.0, true)
			for depth_line in range(4):
				var line_x: float = pit_center.x - 52.0 + float(depth_line) * 35.0
				draw_line(Vector2(line_x, pit_center.y + 8.0), Vector2(line_x - 8.0, pit_center.y + 62.0), Color(CELLAR_LINE, 0.10), 3.0, true)
		elif side.begins_with("up"):
			var lift_center: Vector2 = Vector2(screen_zone.get_center().x, screen_zone.end.y - 24.0)
			var ascent_offset: float = CELLAR_ASCENT_HEIGHT * _cellar_ascent_ratio() if _cellar_is_active_ascent_portal(portal) else 0.0
			lift_center.y -= ascent_offset
			var ceiling_center: Vector2 = Vector2(screen_zone.get_center().x, _world_to_screen(Vector2(0.0, _cellar_region_origin(cellar_region).y + 58.0)).y)
			_draw_cellar_ellipse(ceiling_center, Vector2(screen_zone.size.x * 0.34, 16.0), Color("020304"))
			draw_arc(ceiling_center, screen_zone.size.x * 0.34, 0.0, PI, 18, Color(CELLAR_LINE, 0.28), 4.0, true)
			if cellar_region == "WB":
				draw_line(ceiling_center, lift_center + Vector2(0.0, 10.0), Color(HEMP, 0.68), 7.0, true)
				draw_arc(lift_center + Vector2(0.0, -12.0), 18.0, 0.0, TAU, 18, Color(HEMP, 0.62), 4.0, true)
			else:
				draw_line(ceiling_center + Vector2(-42.0, 0.0), lift_center + Vector2(-42.0, 0.0), Color(CELLAR_LINE, 0.30), 4.0, true)
				draw_line(ceiling_center + Vector2(42.0, 0.0), lift_center + Vector2(42.0, 0.0), Color(CELLAR_LINE, 0.30), 4.0, true)
				draw_line(ceiling_center, lift_center + Vector2(0.0, -10.0), Color(HEMP, 0.48), 5.0, true)
				draw_rect(Rect2(lift_center + Vector2(-64.0, -10.0), Vector2(128.0, 18.0)), Color(HEMP, 0.62))
				draw_line(lift_center + Vector2(-64.0, -10.0), lift_center + Vector2(64.0, -10.0), Color(CELLAR_LINE, 0.46), 3.0, true)

func _draw_cellar_platform(world_rect: Rect2) -> void:
	var screen_rect: Rect2 = _world_rect_to_screen(world_rect)
	var top_points: PackedVector2Array = PackedVector2Array([
		screen_rect.position + Vector2(0.0, 6.0),
		screen_rect.position + Vector2(screen_rect.size.x * 0.25, 0.0),
		screen_rect.position + Vector2(screen_rect.size.x * 0.53, 5.0),
		screen_rect.position + Vector2(screen_rect.size.x * 0.78, 1.0),
		screen_rect.position + Vector2(screen_rect.size.x, 7.0),
		screen_rect.end,
		Vector2(screen_rect.position.x, screen_rect.end.y),
	])
	draw_polygon(top_points, PackedColorArray([Color("b9bfba")]))
	draw_polyline(PackedVector2Array([top_points[0], top_points[1], top_points[2], top_points[3], top_points[4]]), CELLAR_BG, 4.0, true)
	for scratch_index in range(maxi(1, int(world_rect.size.x / 105.0))):
		var scratch_x: float = screen_rect.position.x + 45.0 + float(scratch_index) * 103.0
		draw_line(Vector2(scratch_x, screen_rect.position.y + 17.0), Vector2(scratch_x - 15.0, screen_rect.position.y + 55.0), Color(CELLAR_BG, 0.46), 2.0, true)

func _draw_cellar_dust() -> void:
	for dust in cellar_dust:
		var life: float = float(dust["life"])
		var color_value: Color = dust["color"]
		draw_circle(_world_to_screen(dust["position"]), 4.0 + life * 8.0, Color(color_value, life * 0.65))

func _draw_cellar_stone(center: Vector2, radius: float) -> void:
	var stone: PackedVector2Array = PackedVector2Array([
		center + Vector2(-radius, 3.0), center + Vector2(-radius * 0.58, -radius * 0.76),
		center + Vector2(radius * 0.25, -radius), center + Vector2(radius, -radius * 0.12),
		center + Vector2(radius * 0.70, radius * 0.72), center + Vector2(-radius * 0.42, radius),
	])
	draw_polygon(stone, PackedColorArray([CELLAR_STONE_COLOR]))
	draw_polyline(stone, CELLAR_BG, 3.0, true)
	draw_line(center + Vector2(-radius * 0.42, -radius * 0.3), center + Vector2(radius * 0.28, radius * 0.12), Color(CELLAR_BG, 0.32), 2.0, true)

func _draw_cellar_cracked_wall(center_world: Vector2, hits: int, required_hits: int, optional: bool) -> void:
	if hits >= required_hits:
		return
	var wall := _world_rect_to_screen(Rect2(center_world - Vector2(55.0, 140.0), Vector2(110.0, 280.0)))
	draw_rect(wall, Color("2b3032"))
	draw_rect(wall, Color(CELLAR_LINE, 0.22), false, 4.0)
	var crack_center := wall.get_center()
	var crack_scale: float = 0.75 + float(hits) * 0.24
	var crack_points := PackedVector2Array([
		crack_center + Vector2(0.0, -70.0) * crack_scale,
		crack_center + Vector2(-18.0, -34.0) * crack_scale,
		crack_center + Vector2(12.0, -4.0) * crack_scale,
		crack_center + Vector2(-24.0, 31.0) * crack_scale,
		crack_center + Vector2(9.0, 78.0) * crack_scale,
	])
	draw_polyline(crack_points, Color(PAPER, 0.62 if optional else 0.78), 3.0 + float(hits), true)
	for branch_index in range(3 + hits):
		var branch_point: Vector2 = crack_center + Vector2(-15.0 + float(branch_index) * 9.0, -28.0 + float(branch_index) * 26.0)
		draw_line(branch_point, branch_point + Vector2((-22.0 if branch_index % 2 == 0 else 24.0), 17.0), Color(PAPER, 0.42), 2.0, true)

func _draw_cellar_key(center: Vector2, scale_factor: float, alpha: float) -> void:
	var key_color: Color = Color(CELLAR_KEY_COLOR, alpha)
	draw_circle(center + Vector2(-31.0, 0.0) * scale_factor, 18.0 * scale_factor, key_color, false, 6.0 * scale_factor, true)
	draw_line(center + Vector2(-13.0, 0.0) * scale_factor, center + Vector2(47.0, 0.0) * scale_factor, key_color, 8.0 * scale_factor, true)
	draw_line(center + Vector2(24.0, 0.0) * scale_factor, center + Vector2(24.0, 18.0) * scale_factor, key_color, 7.0 * scale_factor, true)
	draw_line(center + Vector2(42.0, 0.0) * scale_factor, center + Vector2(42.0, 13.0) * scale_factor, key_color, 7.0 * scale_factor, true)

func _draw_cellar_context_prompt() -> void:
	if cellar_transition_time > 0.0 or cellar_focus_time > 0.55 or cellar_ascent_active:
		return
	var player_rect: Rect2 = Rect2(player_position, PLAYER_SIZE)
	var origin: Vector2 = _cellar_region_origin(cellar_region)
	var prompt_world: Vector2 = Vector2.ZERO
	var has_prompt: bool = false
	if cellar_region == "RS" and not cellar_has_rope and not cellar_rope_installed:
		var rope_zone: Rect2 = Rect2(origin + Vector2(675.0, 420.0), Vector2(220.0, 150.0))
		if player_rect.intersects(rope_zone):
			prompt_world = rope_zone.get_center() - Vector2(0.0, 118.0)
			has_prompt = true
	elif cellar_region == "PS" and not cellar_has_pickaxe:
		var pickaxe_zone: Rect2 = Rect2(origin + Vector2(220.0, 410.0), Vector2(220.0, 160.0))
		if player_rect.intersects(pickaxe_zone):
			prompt_world = pickaxe_zone.get_center() - Vector2(0.0, 125.0)
			has_prompt = true
	elif cellar_region == "W" and not cellar_rope_installed:
		var well_zone: Rect2 = Rect2(origin + Vector2(560.0, 400.0), Vector2(150.0, 175.0))
		if player_rect.intersects(well_zone):
			prompt_world = well_zone.get_center() - Vector2(0.0, 145.0)
			has_prompt = true
	elif cellar_region == "WB" and not cellar_has_key:
		var rubble_zone: Rect2 = Rect2(origin + Vector2(430.0, 365.0), Vector2(285.0, 210.0))
		if player_rect.intersects(rubble_zone):
			prompt_world = rubble_zone.get_center() - Vector2(0.0, 150.0)
			has_prompt = true
	elif cellar_region == "R":
		var prison_zone: Rect2 = Rect2(origin + Vector2(790.0, 315.0), Vector2(280.0, 270.0))
		if player_rect.intersects(prison_zone):
			prompt_world = prison_zone.get_center() - Vector2(0.0, 170.0)
			has_prompt = true
	if has_prompt:
		_draw_f_prompt(_world_to_screen(prompt_world))
		return
	if not on_ground:
		return
	for portal in _cellar_portals():
		var side: String = String(portal["side"])
		if not side.begins_with("up"):
			continue
		var zone: Rect2 = portal["zone"]
		if player_rect.intersects(zone):
			_draw_f_prompt(_world_to_screen(zone.get_center() - Vector2(0.0, 118.0)))
			return

func _draw_cellar_darkness() -> void:
	var light_world: Vector2 = player_position + PLAYER_SIZE * 0.5 + Vector2(player_facing * 42.0, 0.0)
	if not on_ground and player_velocity.y > 80.0:
		light_world += Vector2(0.0, 55.0)
	if cellar_focus_time > 0.55:
		if cellar_focus_kind == "prison" or cellar_focus_kind == "rescue" or cellar_focus_kind == "need_key":
			light_world = _cellar_region_origin("R") + Vector2(930.0, 410.0)
		elif cellar_focus_kind == "key":
			light_world = _cellar_region_origin("WB") + Vector2(570.0, 455.0)
		elif cellar_focus_kind == "rope":
			light_world = _cellar_region_origin("RS") + Vector2(790.0, 455.0)
		elif cellar_focus_kind == "pickaxe":
			light_world = _cellar_region_origin("PS") + Vector2(755.0, 455.0)
		elif cellar_focus_kind == "well" or cellar_focus_kind == "need_rope":
			light_world = _cellar_region_origin("W") + Vector2(815.0, 475.0)
		elif cellar_focus_kind == "need_pickaxe":
			light_world = _cellar_region_origin("WB") + Vector2(570.0, 470.0)
	var center: Vector2 = _world_to_screen(light_world)
	var band_count: int = 12
	for band_index in range(band_count):
		var inner_radius: float = CELLAR_LIGHT_RADIUS + CELLAR_LIGHT_FEATHER * float(band_index) / float(band_count)
		var outer_radius: float = CELLAR_LIGHT_RADIUS + CELLAR_LIGHT_FEATHER * float(band_index + 1) / float(band_count)
		var band_alpha: float = 0.07 + float(band_index) / float(band_count - 1) * 0.83
		_draw_cellar_annulus(center, inner_radius, outer_radius, Color(CELLAR_BG, band_alpha))
	_draw_cellar_annulus(center, CELLAR_LIGHT_RADIUS + CELLAR_LIGHT_FEATHER, 2200.0, Color(CELLAR_BG, 0.985))
	draw_arc(center, CELLAR_LIGHT_RADIUS + 5.0, 0.0, TAU, 72, Color(PAPER, 0.07), 2.0, true)
	if cellar_intro_time > 0.55 or cellar_focus_time > 0.55:
		draw_rect(Rect2(0.0, 0.0, SCREEN.x, 42.0), CELLAR_BG)
		draw_rect(Rect2(0.0, SCREEN.y - 42.0, SCREEN.x, 42.0), CELLAR_BG)

func _draw_cellar_annulus(center: Vector2, inner_radius: float, outer_radius: float, color_value: Color) -> void:
	var segment_count: int = 72
	for segment_index in range(segment_count):
		var angle_a: float = float(segment_index) * TAU / float(segment_count)
		var angle_b: float = float(segment_index + 1) * TAU / float(segment_count)
		var points: PackedVector2Array = PackedVector2Array([
			center + Vector2(cos(angle_a), sin(angle_a)) * inner_radius,
			center + Vector2(cos(angle_a), sin(angle_a)) * outer_radius,
			center + Vector2(cos(angle_b), sin(angle_b)) * outer_radius,
			center + Vector2(cos(angle_b), sin(angle_b)) * inner_radius,
		])
		draw_polygon(points, PackedColorArray([color_value]))

func _draw_cellar_failure_effect() -> void:
	var center: Vector2 = _world_to_screen(player_position + PLAYER_SIZE * 0.5)
	var alpha: float = clampf(1.0 - cellar_failure_time / 0.72, 0.0, 1.0)
	var effect_color: Color = GAS if cellar_failure_kind == "gas" else FIRE if cellar_failure_kind == "rock" else PAPER
	for slash_index in range(8):
		var angle: float = float(slash_index) * TAU / 8.0
		var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * 22.0
		var finish: Vector2 = center + Vector2(cos(angle), sin(angle)) * (42.0 + cellar_failure_time * 38.0)
		draw_line(start, finish, Color(effect_color, alpha), 4.0, true)

func _draw_cellar_rescued() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), CELLAR_BG)
	var cell_opening: Rect2 = Rect2(305.0, 115.0, 670.0, 500.0)
	draw_rect(cell_opening, Color("111617"))
	for bar_index in range(8):
		var bar_x: float = cell_opening.position.x + 34.0 + float(bar_index) * 84.0
		var lean: float = -55.0 if bar_index >= 4 else 0.0
		draw_line(Vector2(bar_x, cell_opening.position.y), Vector2(bar_x + lean, cell_opening.end.y), Color(CELLAR_LINE, 0.38), 8.0, true)
	draw_circle(Vector2(640.0, 310.0), 24.0, PALE)
	draw_arc(Vector2(640.0, 310.0), 38.0, PI, TAU, 22, PALE, 9.0, true)
	draw_line(Vector2(640.0, 334.0), Vector2(620.0, 430.0), PALE, 10.0, true)
	draw_line(Vector2(620.0, 430.0), Vector2(580.0, 505.0), PALE, 7.0, true)
	var title: String = "监牢已经打开"
	var title_width: float = ui_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32).x
	draw_string(ui_font, Vector2((SCREEN.x - title_width) * 0.5, 570.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 32, PAPER)


func _cellar_region_label() -> String:
	match cellar_region:
		"A": return "地窖入口"
		"B": return "酒窖残层"
		"C": return "根下破口"
		"D": return "上层岔脊"
		"E": return "西侧旧轨坡"
		"F": return "塌梁采掘带"
		"G": return "中央矿脉结"
		"H": return "高位窄桥"
		"I": return "东侧主矿道"
		"J": return "木撑蛇道"
		"K": return "西下横切巷"
		"L": return "东下横切巷"
		"M": return "渗水弯沟"
		"N": return "螺旋沉降道"
		"O": return "岩底交汇处"
		"RS": return "废弃绞车台"
		"PS": return "废工具坑"
		"W": return "西端废井口"
		"WB": return "废井底"
		"Q": return "囚笼裂谷"
		"R": return "岩底监牢"
		"X1": return "塌死采面"
		"X2": return "无风裂隙"
		"X3": return "废矿车终点"
	return "根下旧矿"

func _cellar_screen_shake_offset() -> Vector2:
	var strength: float = 0.0
	if cellar_wall_hit_time > 0.0:
		strength = 7.0 * clampf(cellar_wall_hit_time / 0.48, 0.0, 1.0)
	elif cellar_failure_time > 0.0:
		strength = 5.0 * clampf(1.0 - cellar_failure_time / 0.72, 0.0, 1.0)
	if strength <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(elapsed * 63.0) * strength, cos(elapsed * 51.0) * strength * 0.65)


func _draw_f_prompt(center: Vector2) -> void:
	draw_circle(center, 17.0, PAPER)
	draw_circle(center, 17.0, INK, false, 2.0, true)
	var key_size: Vector2 = ui_font.get_string_size("F", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15)
	draw_string(ui_font, center - key_size * 0.5 + Vector2(0.0, key_size.y * 0.72), "F", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, INK)

func _draw_player() -> void:
	var p := _world_to_screen(player_position)
	var center_x := p.x + PLAYER_SIZE.x * 0.5
	var walk_phase := sin(elapsed * 12.0) if absf(player_velocity.x) > 25.0 and on_ground else 0.0
	var head_center := Vector2(center_x, p.y + 15.0)
	draw_line(Vector2(center_x - 3.0, p.y + 40.0), Vector2(center_x - 7.0 - walk_phase * 5.0, p.y + 54.0), PAPER, 3.0, true)
	draw_line(Vector2(center_x + 3.0, p.y + 40.0), Vector2(center_x + 7.0 + walk_phase * 5.0, p.y + 54.0), PAPER, 3.0, true)
	var cloak := PackedVector2Array([Vector2(center_x, p.y + 24.0), Vector2(center_x - 12.0, p.y + 45.0), Vector2(center_x + 12.0, p.y + 45.0)])
	draw_polygon(cloak, PackedColorArray([Color("111617")]))
	draw_polyline(cloak, PAPER, 3.0, true)
	draw_circle(head_center, 9.5, Color("111617"), true, -1.0, true)
	draw_circle(head_center, 9.5, PAPER, false, 3.0, true)
	draw_circle(head_center + Vector2(player_facing * 3.0, -1.0), 1.2, PAPER)
	var hat := PackedVector2Array([Vector2(center_x - 14.0, p.y + 8.0), Vector2(center_x + 14.0, p.y + 8.0), Vector2(center_x - 2.0, p.y - 13.0), Vector2(center_x + 1.0, p.y + 2.0)])
	draw_polygon(hat, PackedColorArray([Color("111617")]))
	var outline := hat.duplicate(); outline.append(hat[0])
	draw_polyline(outline, PAPER, 2.5, true)
	draw_line(Vector2(center_x - 16.0, p.y + 8.0), Vector2(center_x + 16.0, p.y + 8.0), PAPER, 4.0, true)
	var shoulder := Vector2(center_x, p.y + 29.0)
	draw_line(shoulder, shoulder + Vector2(player_facing * 13.0, 8.0 + walk_phase * 2.0), PAPER, 3.0, true)
	draw_line(shoulder, shoulder + Vector2(-player_facing * 10.0, 7.0 - walk_phase * 2.0), PAPER, 3.0, true)

func _world_to_screen(world_position: Vector2) -> Vector2:
	return world_position - cellar_camera + _cellar_screen_shake_offset()

func _world_rect_to_screen(world_rect: Rect2) -> Rect2:
	return Rect2(_world_to_screen(world_rect.position), world_rect.size)

func debug_state() -> Dictionary:
	return {"region": cellar_region, "portals": _cellar_portals(), "ascent": cellar_ascent_active, "rescued": rescued_state, "rope": cellar_has_rope, "pickaxe": cellar_has_pickaxe, "key": cellar_has_key}
