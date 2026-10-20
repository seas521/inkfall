extends Node2D

signal completed

const Palette = preload("res://scripts/shared/inkfall_palette.gd")
const LandmarkArt = preload("res://scripts/shared/landmark_art.gd")
const CellarController = preload("res://scripts/levels/level_03_cellar_controller.gd")
const SCREEN := Palette.SCREEN
const PLAYER_SIZE := Palette.PLAYER_SIZE
const INK := Palette.INK
const PAPER := Palette.PAPER
const PALE := Palette.PALE
const MID := Palette.MID
const FIRE := Palette.FIRE
const HEMP := Palette.HEMP
const GOLD := Palette.GOLD
const CELLAR_BG := Palette.CELLAR_BG
const CELLAR_LINE := Palette.CELLAR_LINE
const LEVEL3_HOUSE_WORLD_WIDTH := 2720.0
const LEVEL3_YARD_WORLD_WIDTH := 2300.0
const LEVEL3_HOUSE_DOOR_ZONE := Rect2(38.0, 454.0, 158.0, 145.0)
const LEVEL3_FIREPLACE_ZONE := Rect2(492.0, 448.0, 238.0, 156.0)
const LEVEL3_CHARRED_STICK_ZONE := Rect2(724.0, 516.0, 104.0, 92.0)
const LEVEL3_WINDOW_ZONE := Rect2(1465.0, 205.0, 345.0, 165.0)
const LEVEL3_HATCH_ZONE := Rect2(2310.0, 494.0, 205.0, 156.0)
const LEVEL3_HATCH_GAP := Rect2(2340.0, 584.0, 155.0, 156.0)
const LEVEL3_YARD_DOOR_ZONE := Rect2(1135.0, 432.0, 150.0, 165.0)
const LEVEL3_AXE_ZONE := Rect2(1630.0, 492.0, 145.0, 116.0)
const LEVEL3_TREE_ZONE := Rect2(245.0, 318.0, 245.0, 286.0)
const LEVEL3_BRANCH_ZONE := Rect2(292.0, 514.0, 172.0, 94.0)
const LEVEL3_CAMPFIRE_ZONE := Rect2(642.0, 494.0, 172.0, 112.0)
const LEVEL3_HOUSE_FURNITURE: Array[Rect2] = [Rect2(835.0, 530.0, 96.0, 24.0), Rect2(947.0, 480.0, 96.0, 24.0), Rect2(1059.0, 430.0, 96.0, 24.0), Rect2(1171.0, 380.0, 96.0, 24.0), Rect2(1283.0, 330.0, 610.0, 24.0)]
const LEVEL3_YARD_PLATFORMS: Array[Rect2] = [Rect2(-80.0, 590.0, 2380.0, 150.0)]

enum Stage { HOUSE, YARD, CELLAR_READY, CELLAR, RESCUED }

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
var camera_axis: float:
	get: return game_context.camera_axis
	set(value): game_context.camera_axis = value
var failure_flash: float:
	get: return game_context.failure_flash
	set(value): game_context.failure_flash = value

var host
var ui_font: Font
var room := Stage.HOUSE
var elapsed := 0.0
var completion_time := 0.0
var checkpoint_position := Vector2.ZERO
var level3_held_item := ""
var level3_axe_picked := false
var level3_tree_hits := 0
var level3_branch_available := false
var level3_fireplace_lit := false
var level3_charred_stick_available := false
var level3_curtain_open := false
var level3_window_propped := false
var level3_fire_unlocked := false
var level3_moon_unlocked := false
var level3_wind_unlocked := false
var level3_hatch_unsealed := false
var level3_hatch_open := false
var level3_seal_overlay_open := false
var level3_seal_flash_time := 0.0
var level3_swing_time := 0.0
var level3_transition_time := 0.0
var level3_help_clock := 0.0
var cellar_controller: Node2D

func enter(context, font: Font, game_host) -> void:
	game_context = context
	ui_font = font
	host = game_host
	if cellar_controller == null:
		cellar_controller = CellarController.new()
		add_child(cellar_controller)
		cellar_controller.rescued.connect(_on_cellar_rescued)
	cellar_controller.game_context = context
	cellar_controller.ui_font = font
	cellar_controller.host = game_host
	visible = true
	reset()

func leave() -> void:
	visible = false
	if cellar_controller != null: cellar_controller.leave()

func reset() -> void:
	if cellar_controller != null:
		cellar_controller.game_context = game_context
		cellar_controller.ui_font = ui_font
		cellar_controller.host = host
		cellar_controller.reset()
		cellar_controller.hide()
	_enter_level_03_house(true)
	queue_redraw()

func restart_current() -> void:
	reset()

func physics_tick(delta: float) -> void:
	elapsed += delta
	failure_flash = maxf(0.0, failure_flash - delta)
	level3_seal_flash_time = maxf(0.0, level3_seal_flash_time - delta)
	level3_swing_time = maxf(0.0, level3_swing_time - delta)
	level3_transition_time = maxf(0.0, level3_transition_time - delta)
	level3_help_clock += delta
	match room:
		Stage.HOUSE: _update_level_03_house(delta)
		Stage.YARD: _update_level_03_yard(delta)
		Stage.CELLAR_READY: _update_level_03_cellar_ready(delta)
		Stage.CELLAR, Stage.RESCUED: cellar_controller.physics_tick(delta)
	queue_redraw()

func presentation_state() -> Dictionary:
	return {"active": false, "stage": int(room)}

func sync_environment(env_fx: Node2D) -> void:
	if room == Stage.CELLAR or room == Stage.RESCUED: cellar_controller.sync_environment(env_fx)

func _draw() -> void:
	draw_world()
	if room == Stage.HOUSE or room == Stage.YARD: _draw_player()
	draw_ui()
	if room == Stage.HOUSE and level3_seal_overlay_open: _draw_level_03_seal_overlay()
	if level3_transition_time > 0.0 and room != Stage.CELLAR and room != Stage.RESCUED:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(INK, clampf(level3_transition_time / 0.7, 0.0, 0.92)))
	if failure_flash > 0.0: draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(INK, failure_flash * 0.7))

func draw_world() -> void:
	match room:
		Stage.HOUSE: _draw_level_03_house()
		Stage.YARD: _draw_level_03_yard()
		Stage.CELLAR_READY: _draw_level_03_cellar_ready()

func draw_ui() -> void:
	if room == Stage.CELLAR or room == Stage.RESCUED: return
	draw_string(ui_font, Vector2(28.0, 36.0), "INKFALL · 1-03 月炉木屋", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, PAPER if room == Stage.CELLAR_READY else INK)
	draw_string(ui_font, Vector2(28.0, 64.0), _room_name(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(PAPER if room == Stage.CELLAR_READY else INK, 0.62))
	var controls := "" if room == Stage.CELLAR_READY else "A / D 移动　Space 跳跃　F 交互　T 重置"
	draw_string(ui_font, Vector2(28.0, 694.0), controls, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(PAPER if room == Stage.CELLAR_READY else INK, 0.64))

func _enter_cellar() -> void:
	room = Stage.CELLAR
	cellar_controller.enter(game_context, ui_font, host)

func _on_cellar_rescued() -> void:
	room = Stage.RESCUED

func _update_player(delta: float, platforms: Array[Rect2], bounds: Vector2, allow_input: bool) -> void:
	host.update_shared_player(game_context, delta, platforms, bounds, allow_input)

func _enter_level_03_house(reset_puzzle: bool) -> void:
	room = Stage.HOUSE
	player_position = Vector2(145.0, 590.0 - PLAYER_SIZE.y)
	player_velocity = Vector2.ZERO
	player_facing = 1.0
	on_ground = false
	regular_jump_active = false
	camera_axis = 0.0
	checkpoint_position = player_position
	level3_transition_time = 0.7
	level3_seal_overlay_open = false
	level3_help_clock = 0.0
	if reset_puzzle:
		_reset_level_03_puzzle()

func _reset_level_03_puzzle() -> void:
	level3_held_item = ""
	level3_axe_picked = false
	level3_tree_hits = 0
	level3_branch_available = false
	level3_fireplace_lit = false
	level3_charred_stick_available = false
	level3_curtain_open = false
	level3_window_propped = false
	level3_fire_unlocked = false
	level3_moon_unlocked = false
	level3_wind_unlocked = false
	level3_hatch_unsealed = false
	level3_hatch_open = false
	level3_seal_overlay_open = false
	level3_seal_flash_time = 0.0
	level3_swing_time = 0.0

func _switch_level_03_room(next_room: Stage, next_position: Vector2) -> void:
	room = next_room
	player_position = next_position
	player_velocity = Vector2.ZERO
	on_ground = false
	regular_jump_active = false
	camera_axis = clampf(player_position.x - 360.0, 0.0, LEVEL3_YARD_WORLD_WIDTH - SCREEN.x) if next_room == Stage.YARD else 0.0
	checkpoint_position = player_position
	level3_transition_time = 0.38
	level3_seal_overlay_open = false

func _level_03_house_platforms() -> Array[Rect2]:
	var platforms: Array[Rect2] = []
	if level3_hatch_open:
		platforms.append(Rect2(-80.0, 590.0, LEVEL3_HATCH_GAP.position.x + 80.0, 150.0))
		platforms.append(Rect2(LEVEL3_HATCH_GAP.end.x, 590.0, LEVEL3_HOUSE_WORLD_WIDTH - LEVEL3_HATCH_GAP.end.x + 80.0, 150.0))
	else:
		platforms.append(Rect2(-80.0, 590.0, LEVEL3_HOUSE_WORLD_WIDTH + 160.0, 150.0))
	platforms.append_array(LEVEL3_HOUSE_FURNITURE)
	return platforms

func _update_level_03_house(delta: float) -> void:
	if level3_seal_overlay_open:
		player_velocity = Vector2.ZERO
		if Input.is_action_just_pressed("interact"):
			level3_seal_overlay_open = false
		return

	var house_platforms: Array[Rect2] = _level_03_house_platforms()
	_update_player(delta, house_platforms, Vector2(0.0, LEVEL3_HOUSE_WORLD_WIDTH), true)
	camera_axis = clampf(player_position.x - 360.0, 0.0, LEVEL3_HOUSE_WORLD_WIDTH - SCREEN.x)
	_try_level_03_house_interaction()

	if player_position.y > SCREEN.y + 42.0:
		if level3_hatch_open and player_position.x + PLAYER_SIZE.x * 0.5 >= LEVEL3_HATCH_GAP.position.x and player_position.x <= LEVEL3_HATCH_GAP.end.x:
			room = Stage.CELLAR_READY
			player_velocity = Vector2.ZERO
			completion_time = 0.0
			camera_axis = 0.0
			level3_transition_time = 0.55
		else:
			player_position = checkpoint_position
			player_velocity = Vector2.ZERO
			failure_flash = 0.18

func _try_level_03_house_interaction() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	if player_rect.intersects(LEVEL3_HOUSE_DOOR_ZONE):
		_switch_level_03_room(Stage.YARD, Vector2(1200.0, 590.0 - PLAYER_SIZE.y))
		return
	if level3_charred_stick_available and level3_held_item == "" and player_rect.intersects(LEVEL3_CHARRED_STICK_ZONE):
		level3_charred_stick_available = false
		level3_held_item = "charred_stick"
		return
	if player_rect.intersects(LEVEL3_FIREPLACE_ZONE):
		if not level3_fireplace_lit and level3_held_item == "torch":
			level3_fireplace_lit = true
			level3_fire_unlocked = true
			level3_held_item = ""
			level3_charred_stick_available = true
			level3_seal_flash_time = 1.0
			_update_level_03_seal_state()
		return
	if player_rect.intersects(LEVEL3_WINDOW_ZONE):
		if not level3_curtain_open:
			level3_curtain_open = true
			level3_moon_unlocked = true
			level3_seal_flash_time = 1.0
			_update_level_03_seal_state()
		elif not level3_window_propped and level3_held_item == "charred_stick" and level3_fireplace_lit:
			level3_window_propped = true
			level3_wind_unlocked = true
			level3_held_item = ""
			level3_seal_flash_time = 1.2
			_update_level_03_seal_state()
		return
	if player_rect.intersects(LEVEL3_HATCH_ZONE):
		if not level3_hatch_open and level3_hatch_unsealed:
			level3_hatch_open = true
			level3_seal_flash_time = 0.8
		elif not level3_hatch_open:
			level3_seal_overlay_open = true
			level3_seal_flash_time = 0.4
		return

func _update_level_03_yard(delta: float) -> void:
	_update_player(delta, LEVEL3_YARD_PLATFORMS, Vector2(0.0, LEVEL3_YARD_WORLD_WIDTH), true)
	camera_axis = clampf(player_position.x - 360.0, 0.0, LEVEL3_YARD_WORLD_WIDTH - SCREEN.x)
	_try_level_03_yard_interaction()
	if player_position.y > SCREEN.y + 60.0:
		player_position = checkpoint_position
		player_velocity = Vector2.ZERO
		failure_flash = 0.18

func _try_level_03_yard_interaction() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	if player_rect.intersects(LEVEL3_YARD_DOOR_ZONE):
		_switch_level_03_room(Stage.HOUSE, Vector2(120.0, 590.0 - PLAYER_SIZE.y))
		return
	if not level3_axe_picked and level3_held_item == "" and player_rect.intersects(LEVEL3_AXE_ZONE):
		level3_axe_picked = true
		level3_held_item = "axe"
		return
	if level3_held_item == "axe" and player_rect.intersects(LEVEL3_TREE_ZONE) and level3_tree_hits < 3:
		level3_tree_hits += 1
		level3_swing_time = 0.28
		if level3_tree_hits >= 3:
			level3_held_item = ""
			level3_branch_available = true
		return
	if level3_branch_available and level3_held_item == "" and player_rect.intersects(LEVEL3_BRANCH_ZONE):
		level3_branch_available = false
		level3_held_item = "branch"
		return
	if level3_held_item == "branch" and player_rect.intersects(LEVEL3_CAMPFIRE_ZONE):
		level3_held_item = "torch"
		level3_swing_time = 0.32
		return
	if level3_held_item == "axe" or level3_held_item == "branch" or level3_held_item == "torch" or level3_held_item == "charred_stick":
		level3_swing_time = 0.26

func _update_level_03_seal_state() -> void:
	if not level3_fire_unlocked or not level3_moon_unlocked or not level3_wind_unlocked:
		return
	level3_hatch_unsealed = true
	level3_seal_overlay_open = true
	level3_seal_flash_time = 1.6

func _update_level_03_cellar_ready(delta: float) -> void:
	completion_time += delta
	player_velocity = Vector2.ZERO
	if completion_time >= 1.35:
		_enter_cellar()


func _draw_shared_hut_forecourt(base: Vector2, scale_factor: float, tree_hits_value: int, axe_state: String) -> void:
	LandmarkArt.draw_hut_forecourt(self, base, scale_factor, tree_hits_value, axe_state, elapsed, level3_swing_time)

func _draw_shared_backyard_clutter(base: Vector2, scale_factor: float, axe_state: String) -> void:
	LandmarkArt.draw_backyard(self, base, scale_factor, axe_state)

func _draw_shared_house(base: Vector2, scale_factor: float) -> void:
	LandmarkArt.draw_house(self, base, scale_factor, elapsed)

func _draw_shared_tree(base: Vector2, scale_factor: float, tree_hits_value: int) -> void:
	LandmarkArt.draw_tree(self, base, scale_factor, tree_hits_value, elapsed, level3_swing_time)

func _draw_shared_axe(origin: Vector2, rotation: float, scale_factor: float) -> void:
	LandmarkArt.draw_axe(self, origin, rotation, scale_factor)

func _draw_scaled_fire(origin: Vector2, scale_factor: float) -> void:
	LandmarkArt.draw_fire(self, origin, scale_factor, elapsed)

func _draw_level_03_yard() -> void:
	for band_index in range(6):
		var band_rect := Rect2(0.0, float(band_index) * 120.0, SCREEN.x, 120.0)
		draw_rect(band_rect, Color(0.76 - float(band_index) * 0.035, 0.82 - float(band_index) * 0.035, 0.81 - float(band_index) * 0.03, 1.0))
	for ridge_index in range(3):
		var ridge := PackedVector2Array()
		for point_index in range(12):
			var world_x: float = float(point_index) * 190.0 - 120.0
			var world_y: float = 300.0 + float(ridge_index) * 78.0 + sin(float(point_index) * 1.15 + float(ridge_index)) * 42.0
			ridge.append(_world_to_screen(Vector2(world_x, world_y)))
		draw_polyline(ridge, Color(INK, 0.16 + float(ridge_index) * 0.08), 5.0, true)
	var ground_rect := _world_rect_to_screen(LEVEL3_YARD_PLATFORMS[0])
	draw_rect(ground_rect, INK)
	draw_line(ground_rect.position, Vector2(ground_rect.end.x, ground_rect.position.y), PAPER, 4.0, true)
	var axe_state := ""
	if not level3_axe_picked:
		axe_state = "ground"
	elif level3_tree_hits >= 3:
		axe_state = "stuck"
	_draw_shared_hut_forecourt(_world_to_screen(Vector2(1050.0, 590.0)), 1.0, level3_tree_hits, axe_state)
	if level3_branch_available:
		var branch_start := _world_to_screen(Vector2(306.0, 562.0))
		draw_line(branch_start, branch_start + Vector2(88.0, -19.0), HEMP, 7.0, true)
		draw_line(branch_start + Vector2(54.0, -12.0), branch_start + Vector2(72.0, -32.0), HEMP, 4.0, true)
	_draw_level_03_context_prompt()

func _draw_level_03_house() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color("dedbd0"))
	_draw_level_03_home_backdrop()
	var house_platforms: Array[Rect2] = _level_03_house_platforms()
	for platform_rect in house_platforms:
		if platform_rect.position.y >= 580.0:
			var floor_screen := _world_rect_to_screen(platform_rect)
			draw_rect(floor_screen, INK)
			draw_line(floor_screen.position, Vector2(floor_screen.end.x, floor_screen.position.y), PAPER, 4.0, true)
	_draw_level_03_interior_door()
	_draw_level_03_furniture()
	_draw_level_03_fireplace()
	_draw_level_03_window()
	_draw_level_03_wind_chime()
	_draw_level_03_hatch()
	_draw_level_03_context_prompt()

func _draw_level_03_home_backdrop() -> void:
	# Alternating wall recesses and posts divide the long side-view into lived-in rooms.
	var recesses: Array[Rect2] = [
		Rect2(205.0, 250.0, 250.0, 300.0),
		Rect2(780.0, 250.0, 430.0, 300.0),
		Rect2(1290.0, 110.0, 610.0, 205.0),
		Rect2(1970.0, 260.0, 560.0, 290.0),
	]
	for recess in recesses:
		var recess_screen := _world_rect_to_screen(recess)
		draw_rect(recess_screen, Color(INK, 0.055))
		draw_rect(recess_screen, Color(INK, 0.18), false, 3.0)
	for wall_index in range(18):
		var world_x: float = float(wall_index) * 164.0 - 30.0
		draw_line(_world_to_screen(Vector2(world_x, 84.0)), _world_to_screen(Vector2(world_x - 20.0, 590.0)), Color(INK, 0.10), 3.0, true)
	var roof_peaks: Array[Vector2] = [Vector2(390.0, 60.0), Vector2(1050.0, 98.0), Vector2(1590.0, 42.0), Vector2(2320.0, 82.0)]
	for peak_index in range(roof_peaks.size()):
		var peak: Vector2 = roof_peaks[peak_index]
		var half_span: float = 390.0 if peak_index != 2 else 480.0
		draw_line(_world_to_screen(peak), _world_to_screen(peak + Vector2(-half_span, 150.0)), Color(INK, 0.34), 13.0, true)
		draw_line(_world_to_screen(peak), _world_to_screen(peak + Vector2(half_span, 150.0)), Color(INK, 0.34), 13.0, true)
	for post_x in [190.0, 470.0, 760.0, 1270.0, 1915.0, 2550.0]:
		draw_line(_world_to_screen(Vector2(post_x, 92.0)), _world_to_screen(Vector2(post_x, 590.0)), Color(INK, 0.30), 14.0, true)
	# Background-only household clutter creates false visual candidates without false interactions.
	var shelf := _world_rect_to_screen(Rect2(245.0, 326.0, 180.0, 13.0))
	draw_rect(shelf, HEMP)
	draw_rect(shelf, INK, false, 2.0)
	for jar_index in range(5):
		var jar_center := shelf.position + Vector2(18.0 + float(jar_index) * 35.0, -13.0 - float(jar_index % 2) * 5.0)
		draw_circle(jar_center, 10.0, PALE)
		draw_circle(jar_center, 10.0, INK, false, 2.0, true)
	for herb_index in range(6):
		var herb_root := _world_to_screen(Vector2(820.0 + float(herb_index) * 48.0, 124.0))
		draw_line(herb_root, herb_root + Vector2(0.0, 58.0 + float(herb_index % 2) * 14.0), Color(INK, 0.6), 2.0, true)
		for leaf_index in range(3):
			draw_circle(herb_root + Vector2(-5.0 + float(leaf_index % 2) * 10.0, 40.0 + float(leaf_index) * 11.0), 6.0, Color(INK, 0.24))
	var picture_centers: Array[Vector2] = [Vector2(340.0, 420.0), Vector2(2070.0, 335.0), Vector2(2215.0, 350.0)]
	for picture_index in range(picture_centers.size()):
		var center: Vector2 = _world_to_screen(picture_centers[picture_index])
		var picture_rect := Rect2(center - Vector2(38.0, 30.0), Vector2(76.0, 60.0))
		draw_rect(picture_rect, PAPER)
		draw_rect(picture_rect, INK, false, 3.0)
		draw_polyline(PackedVector2Array([picture_rect.position + Vector2(8.0, 45.0), picture_rect.position + Vector2(29.0, 22.0), picture_rect.position + Vector2(45.0, 39.0), picture_rect.position + Vector2(65.0, 15.0)]), Color(INK, 0.38), 2.0, true)

func _draw_level_03_interior_door() -> void:
	var door := _world_rect_to_screen(Rect2(60.0, 414.0, 118.0, 176.0))
	draw_rect(door, PAPER)
	draw_rect(door, INK, false, 5.0)
	for plank_index in range(3):
		var plank_x: float = door.position.x + 22.0 + float(plank_index) * 29.0
		draw_line(Vector2(plank_x, door.position.y + 5.0), Vector2(plank_x - 7.0, door.end.y - 5.0), Color(INK, 0.28), 2.0, true)
	draw_circle(door.position + Vector2(79.0, 86.0), 4.0, GOLD)

func _draw_level_03_fireplace() -> void:
	var hearth := _world_rect_to_screen(Rect2(505.0, 455.0, 210.0, 135.0))
	draw_rect(hearth, PALE)
	draw_rect(hearth, INK, false, 5.0)
	var opening := _world_rect_to_screen(Rect2(548.0, 497.0, 124.0, 93.0))
	draw_rect(opening, INK)
	if level3_fireplace_lit:
		_draw_scaled_fire(_world_to_screen(Vector2(610.0, 580.0)), 1.12)
		for glow_index in range(3):
			draw_circle(_world_to_screen(Vector2(610.0, 545.0)), 56.0 + float(glow_index) * 26.0, Color(FIRE, 0.07))
		for smoke_index in range(5):
			var smoke_ratio: float = fmod(elapsed * 0.28 + float(smoke_index) * 0.19, 1.0)
			var drift_x: float = smoke_ratio * (170.0 if level3_wind_unlocked else 28.0)
			var smoke_world := Vector2(610.0 + drift_x, 500.0 - smoke_ratio * 205.0)
			draw_circle(_world_to_screen(smoke_world), 6.0 + smoke_ratio * 8.0, Color(MID, (1.0 - smoke_ratio) * 0.25))
	else:
		draw_line(_world_to_screen(Vector2(570.0, 573.0)), _world_to_screen(Vector2(648.0, 548.0)), HEMP, 7.0, true)
		draw_line(_world_to_screen(Vector2(572.0, 548.0)), _world_to_screen(Vector2(650.0, 573.0)), HEMP, 7.0, true)
	draw_line(_world_to_screen(Vector2(498.0, 450.0)), _world_to_screen(Vector2(722.0, 450.0)), INK, 12.0, true)
	var log_basket := _world_rect_to_screen(Rect2(718.0, 542.0, 118.0, 48.0))
	draw_rect(log_basket, Color(INK, 0.12))
	draw_rect(log_basket, INK, false, 3.0)
	for log_index in range(4):
		draw_circle(log_basket.position + Vector2(19.0 + float(log_index) * 26.0, 18.0 + float(log_index % 2) * 12.0), 12.0, HEMP)
	if level3_charred_stick_available:
		var charred_start := _world_to_screen(Vector2(742.0, 572.0))
		draw_line(charred_start, charred_start + Vector2(72.0, -17.0), Color("35383a"), 8.0, true)
		draw_line(charred_start + Vector2(6.0, -2.0), charred_start + Vector2(65.0, -15.0), Color(PALE, 0.35), 2.0, true)

func _draw_level_03_furniture() -> void:
	# A low dining table and chairs make the hearth zone read as a home, not a runway.
	var dining_table := _world_rect_to_screen(Rect2(255.0, 500.0, 178.0, 18.0))
	draw_rect(dining_table, HEMP)
	draw_rect(dining_table, INK, false, 3.0)
	draw_line(dining_table.position + Vector2(22.0, 18.0), dining_table.position + Vector2(17.0, 88.0), INK, 7.0, true)
	draw_line(dining_table.position + Vector2(156.0, 18.0), dining_table.position + Vector2(161.0, 88.0), INK, 7.0, true)
	for cup_index in range(3):
		var cup := Rect2(dining_table.position + Vector2(30.0 + float(cup_index) * 51.0, -17.0), Vector2(18.0, 17.0))
		draw_rect(cup, PAPER)
		draw_rect(cup, INK, false, 2.0)
	var rug := _world_rect_to_screen(Rect2(205.0, 574.0, 520.0, 16.0))
	draw_rect(rug, Color("a9b8ae"))
	for stripe_index in range(9):
		var stripe_x: float = rug.position.x + 18.0 + float(stripe_index) * 55.0
		draw_line(Vector2(stripe_x, rug.position.y + 2.0), Vector2(stripe_x + 14.0, rug.end.y - 2.0), Color(INK, 0.28), 2.0, true)
	# Four real stair steps lead to a broad loft; their collision rects match these boards.
	for stair_index in range(4):
		var stair_rect: Rect2 = _world_rect_to_screen(LEVEL3_HOUSE_FURNITURE[stair_index])
		draw_rect(stair_rect, HEMP)
		draw_rect(stair_rect, INK, false, 3.0)
		draw_line(stair_rect.position + Vector2(10.0, stair_rect.size.y), stair_rect.position + Vector2(10.0, 60.0), Color(INK, 0.72), 5.0, true)
	draw_line(_world_to_screen(Vector2(820.0, 570.0)), _world_to_screen(Vector2(1260.0, 365.0)), INK, 8.0, true)
	var loft_rect: Rect2 = _world_rect_to_screen(LEVEL3_HOUSE_FURNITURE[4])
	draw_rect(loft_rect, HEMP)
	draw_rect(loft_rect, INK, false, 4.0)
	for support_x in [1320.0, 1870.0]:
		draw_line(_world_to_screen(Vector2(support_x, 350.0)), _world_to_screen(Vector2(support_x, 590.0)), Color(INK, 0.72), 10.0, true)
	# Loft bed, blanket, books and boxes are non-interactive silhouette clutter.
	var bed := _world_rect_to_screen(Rect2(1325.0, 278.0, 180.0, 52.0))
	draw_rect(bed, PAPER)
	draw_rect(bed, INK, false, 3.0)
	draw_polygon(PackedVector2Array([bed.position + Vector2(68.0, 0.0), bed.end - Vector2(0.0, 22.0), bed.end, bed.position + Vector2(55.0, bed.size.y)]), PackedColorArray([Color("93a8a0")]))
	for book_index in range(5):
		var book := _world_rect_to_screen(Rect2(1760.0 + float(book_index) * 20.0, 292.0 - float(book_index % 2) * 8.0, 15.0, 38.0 + float(book_index % 2) * 8.0))
		draw_rect(book, PAPER if book_index % 2 == 0 else PALE)
		draw_rect(book, INK, false, 2.0)
	var pantry := _world_rect_to_screen(Rect2(1985.0, 404.0, 205.0, 186.0))
	draw_rect(pantry, Color("b3a88d"))
	draw_rect(pantry, INK, false, 4.0)
	for shelf_index in range(2):
		draw_line(Vector2(pantry.position.x, pantry.position.y + 61.0 + float(shelf_index) * 60.0), Vector2(pantry.end.x, pantry.position.y + 61.0 + float(shelf_index) * 60.0), INK, 3.0)
	for sack_index in range(3):
		var sack_center := _world_to_screen(Vector2(2225.0 + float(sack_index) * 48.0, 565.0 - float(sack_index % 2) * 15.0))
		draw_circle(sack_center, 31.0, PALE)
		draw_circle(sack_center, 31.0, INK, false, 3.0, true)

func _draw_level_03_window() -> void:
	var frame := _world_rect_to_screen(Rect2(1500.0, 175.0, 225.0, 170.0))
	draw_rect(frame, Color("a9cfd2"))
	draw_rect(frame, INK, false, 7.0)
	draw_circle(frame.position + Vector2(112.0, 75.0), 39.0, Color("eef2d5"))
	draw_circle(frame.position + Vector2(129.0, 63.0), 36.0, Color("a9cfd2"))
	if level3_curtain_open:
		var beam := PackedVector2Array([
			frame.position + Vector2(45.0, 145.0),
			frame.end + Vector2(-25.0, -25.0),
			_world_to_screen(Vector2(1850.0, 590.0)),
			_world_to_screen(Vector2(1300.0, 590.0)),
		])
		draw_polygon(beam, PackedColorArray([Color(Color("e8efd2"), 0.18)]))
		draw_polygon(PackedVector2Array([frame.position, frame.position + Vector2(44.0, 0.0), frame.position + Vector2(25.0, 170.0), frame.position + Vector2(-18.0, 170.0)]), PackedColorArray([INK]))
		draw_polygon(PackedVector2Array([frame.end - Vector2(44.0, 170.0), frame.end - Vector2(0.0, 170.0), frame.end + Vector2(18.0, 0.0), frame.end - Vector2(25.0, 0.0)]), PackedColorArray([INK]))
	else:
		draw_polygon(PackedVector2Array([frame.position, frame.end - Vector2(0.0, 170.0), frame.end, frame.position + Vector2(0.0, 170.0)]), PackedColorArray([Color(INK, 0.92)]))
		for fold_index in range(4):
			var fold_x: float = frame.position.x + 30.0 + float(fold_index) * 52.0
			draw_line(Vector2(fold_x, frame.position.y + 8.0), Vector2(fold_x - 7.0, frame.end.y - 7.0), Color(PAPER, 0.18), 3.0, true)
	if level3_window_propped:
		draw_line(frame.position + Vector2(18.0, 150.0), frame.position + Vector2(72.0, 92.0), HEMP, 7.0, true)
		draw_line(frame.position + Vector2(12.0, 156.0), frame.position + Vector2(74.0, 94.0), INK, 2.0, true)
	if level3_wind_unlocked:
		for wind_index in range(4):
			var wind_y: float = frame.position.y + 68.0 + float(wind_index) * 27.0
			var wind_wave := PackedVector2Array()
			for point_index in range(7):
				wind_wave.append(Vector2(frame.end.x + float(point_index) * 34.0, wind_y + sin(elapsed * 5.0 + float(point_index)) * 8.0))
			draw_polyline(wind_wave, Color(Color("77b8bd"), 0.68), 3.0, true)
func _draw_level_03_wind_chime() -> void:
	var anchor := _world_to_screen(Vector2(1885.0, 225.0))
	var sway: float = sin(elapsed * 5.2) * 13.0 if level3_wind_unlocked else 0.0
	draw_line(anchor + Vector2(-42.0, 0.0), anchor + Vector2(42.0, 0.0), INK, 5.0, true)
	for chime_index in range(3):
		var local_sway: float = sway * (0.72 + float(chime_index) * 0.18)
		var string_start := anchor + Vector2(-25.0 + float(chime_index) * 25.0, 0.0)
		var bell_center := string_start + Vector2(local_sway, 58.0 + float(chime_index % 2) * 13.0)
		draw_line(string_start, bell_center, Color(INK, 0.72), 2.0, true)
		var bell := PackedVector2Array([
			bell_center + Vector2(-11.0, 8.0),
			bell_center + Vector2(0.0, -12.0),
			bell_center + Vector2(11.0, 8.0),
		])
		draw_polygon(bell, PackedColorArray([PAPER]))
		draw_polyline(bell, INK, 3.0, true)
	if level3_wind_unlocked:
		for note_index in range(2):
			var note_position := anchor + Vector2(70.0 + float(note_index) * 29.0, 34.0 - float(note_index) * 19.0)
			draw_circle(note_position, 5.0, Color("77b8bd"))
			draw_line(note_position + Vector2(5.0, 0.0), note_position + Vector2(5.0, -18.0), Color("77b8bd"), 3.0, true)

func _draw_level_03_hatch() -> void:
	var hatch_screen := _world_rect_to_screen(Rect2(LEVEL3_HATCH_GAP.position.x, 565.0, LEVEL3_HATCH_GAP.size.x, 25.0))
	if level3_hatch_open:
		draw_rect(_world_rect_to_screen(LEVEL3_HATCH_GAP), INK)
		draw_line(hatch_screen.position + Vector2(0.0, -8.0), hatch_screen.position + Vector2(-66.0, -92.0), HEMP, 10.0, true)
		return
	draw_rect(hatch_screen, HEMP)
	draw_rect(hatch_screen, INK, false, 4.0)
	for plank_index in range(4):
		var plank_x: float = hatch_screen.position.x + 24.0 + float(plank_index) * 34.0
		draw_line(Vector2(plank_x, hatch_screen.position.y + 2.0), Vector2(plank_x, hatch_screen.end.y - 2.0), Color(INK, 0.5), 2.0)
	var seal_center := hatch_screen.get_center() + Vector2(0.0, -48.0)
	var seal_color: Color = GOLD if level3_hatch_unsealed else PALE
	draw_circle(seal_center, 30.0, Color(PAPER, 0.82))
	draw_circle(seal_center, 30.0, seal_color, false, 4.0, true)
	var node_colors: Array[Color] = [
		FIRE if level3_fire_unlocked else PALE,
		Color("e8efd2") if level3_moon_unlocked else PALE,
		Color("77b8bd") if level3_wind_unlocked else PALE,
	]
	for node_index in range(3):
		var angle: float = -PI * 0.5 + float(node_index) * TAU / 3.0
		draw_circle(seal_center + Vector2(cos(angle), sin(angle)) * 17.0, 4.0, node_colors[node_index])
	if level3_seal_flash_time > 0.0:
		var flash_ratio: float = clampf(level3_seal_flash_time, 0.0, 1.0)
		draw_arc(seal_center, 36.0 + (1.0 - flash_ratio) * 28.0, 0.0, TAU, 32, Color(GOLD, flash_ratio), 4.0, true)
	var help_phase: float = fmod(level3_help_clock, 3.4)
	if help_phase < 1.7 and not level3_hatch_unsealed:
		var help_alpha: float = sin(help_phase / 1.7 * PI)
		draw_string(ui_font, seal_center + Vector2(-28.0, -52.0), "Help…", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(INK, help_alpha * 0.7))
		for ring_index in range(2):
			draw_arc(seal_center, 39.0 + float(ring_index) * 10.0 + help_phase * 7.0, PI * 1.1, PI * 1.9, 18, Color(INK, help_alpha * 0.35), 2.0, true)

func _draw_level_03_seal_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(INK, 0.78))
	var panel := Rect2(250.0, 90.0, 780.0, 540.0)
	draw_rect(panel, Color("202528"))
	draw_rect(panel, PAPER, false, 4.0)
	var title := "三相闭合 · 地窖封印" if not level3_hatch_unsealed else "三相闭合 · 封印解除"
	var title_width: float = ui_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28).x
	draw_string(ui_font, Vector2((SCREEN.x - title_width) * 0.5, 142.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, PAPER)
	var flame_center := Vector2(640.0, 252.0)
	var moon_center := Vector2(485.0, 452.0)
	var wind_center := Vector2(795.0, 452.0)
	var connection_color := GOLD if level3_hatch_unsealed else Color(PAPER, 0.28)
	draw_line(flame_center, moon_center, connection_color, 4.0, true)
	draw_line(moon_center, wind_center, connection_color, 4.0, true)
	draw_line(wind_center, flame_center, connection_color, 4.0, true)
	_draw_level_03_seal_node(flame_center, "fire", level3_fire_unlocked)
	_draw_level_03_seal_node(moon_center, "moon", level3_moon_unlocked)
	_draw_level_03_seal_node(wind_center, "wind", level3_wind_unlocked)
	_draw_level_03_f_prompt(Vector2(640.0, 585.0))
	if level3_seal_flash_time > 0.0:
		draw_rect(panel, Color(GOLD, minf(0.16, level3_seal_flash_time * 0.12)))

func _draw_level_03_seal_node(center: Vector2, kind: String, unlocked: bool) -> void:
	var fill_color := PAPER
	if unlocked and kind == "fire":
		fill_color = FIRE
	elif unlocked and kind == "moon":
		fill_color = Color("e8efd2")
	elif unlocked and kind == "wind":
		fill_color = Color("77b8bd")
	draw_circle(center, 54.0, Color(PAPER, 0.08))
	draw_circle(center, 54.0, PAPER, false, 4.0, true)
	if kind == "fire":
		var flame := PackedVector2Array([center + Vector2(-25.0, 31.0), center + Vector2(-16.0, -5.0), center + Vector2(0.0, -38.0), center + Vector2(14.0, -7.0), center + Vector2(29.0, 31.0)])
		draw_polygon(flame, PackedColorArray([fill_color if unlocked else Color("202528")]))
		draw_polyline(flame, PAPER, 3.0, true)
	elif kind == "moon":
		draw_circle(center, 31.0, fill_color if unlocked else Color("202528"))
		draw_circle(center + Vector2(14.0, -8.0), 29.0, Color("202528"))
		draw_arc(center, 31.0, 0.0, TAU, 30, PAPER, 3.0, true)
	else:
		for line_index in range(3):
			var y_offset: float = -18.0 + float(line_index) * 18.0
			var wave := PackedVector2Array()
			for point_index in range(6):
				wave.append(center + Vector2(-34.0 + float(point_index) * 14.0, y_offset + sin(float(point_index) * 1.4) * 7.0))
			draw_polyline(wave, fill_color if unlocked else PAPER, 5.0 if unlocked else 3.0, true)

func _draw_level_03_cellar_ready() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), CELLAR_BG)
	var fall_ratio: float = clampf(completion_time / 1.35, 0.0, 1.0)
	for wall_index in range(8):
		var wall_y: float = -80.0 + float(wall_index) * 118.0 + fmod(fall_ratio * 420.0, 118.0)
		draw_line(Vector2(180.0, wall_y), Vector2(430.0, wall_y + 45.0), Color(CELLAR_LINE, 0.15), 4.0, true)
		draw_line(Vector2(1100.0, wall_y), Vector2(850.0, wall_y + 45.0), Color(CELLAR_LINE, 0.15), 4.0, true)
	draw_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(420.0, 0.0), Vector2(505.0, 720.0), Vector2(0.0, 720.0)]), PackedColorArray([Color("111517")]))
	draw_polygon(PackedVector2Array([Vector2(1280.0, 0.0), Vector2(860.0, 0.0), Vector2(775.0, 720.0), Vector2(1280.0, 720.0)]), PackedColorArray([Color("111517")]))
	var falling_center := Vector2(640.0, lerpf(130.0, 555.0, smoothstep(0.0, 1.0, fall_ratio)))
	_draw_falling_player_silhouette(falling_center)
	draw_rect(Rect2(0.0, 0.0, SCREEN.x, 48.0), CELLAR_BG)
	draw_rect(Rect2(0.0, SCREEN.y - 48.0, SCREEN.x, 48.0), CELLAR_BG)

func _draw_falling_player_silhouette(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, -22.0), 11.0, PAPER)
	draw_circle(center + Vector2(0.0, -22.0), 11.0, CELLAR_BG, false, 3.0, true)
	var cloak := PackedVector2Array([center + Vector2(0.0, -10.0), center + Vector2(-18.0, 24.0), center + Vector2(18.0, 24.0)])
	draw_polygon(cloak, PackedColorArray([PAPER]))
	draw_polyline(cloak, CELLAR_BG, 3.0, true)
	draw_line(center + Vector2(-22.0, -30.0), center + Vector2(18.0, -30.0), PAPER, 5.0, true)
	draw_polygon(PackedVector2Array([center + Vector2(-12.0, -30.0), center + Vector2(3.0, -61.0), center + Vector2(12.0, -30.0)]), PackedColorArray([PAPER]))

func _draw_level_03_context_prompt() -> void:
	if level3_seal_overlay_open:
		return
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	if room == Stage.HOUSE:
		if player_rect.intersects(LEVEL3_HOUSE_DOOR_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(112.0, 432.0)))
		elif level3_charred_stick_available and level3_held_item == "" and player_rect.intersects(LEVEL3_CHARRED_STICK_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(775.0, 500.0)))
		elif player_rect.intersects(LEVEL3_FIREPLACE_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(610.0, 430.0)))
		elif player_rect.intersects(LEVEL3_WINDOW_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(1610.0, 166.0)))
		elif player_rect.intersects(LEVEL3_HATCH_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(2418.0, 482.0)))
	elif room == Stage.YARD:
		if player_rect.intersects(LEVEL3_YARD_DOOR_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(1200.0, 418.0)))
		elif not level3_axe_picked and player_rect.intersects(LEVEL3_AXE_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(1700.0, 480.0)))
		elif level3_held_item == "axe" and player_rect.intersects(LEVEL3_TREE_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(360.0, 338.0)))
		elif level3_branch_available and level3_held_item == "" and player_rect.intersects(LEVEL3_BRANCH_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(380.0, 500.0)))
		elif level3_held_item == "branch" and player_rect.intersects(LEVEL3_CAMPFIRE_ZONE):
			_draw_level_03_f_prompt(_world_to_screen(Vector2(750.0, 478.0)))

func _draw_level_03_f_prompt(center: Vector2) -> void:
	draw_circle(center, 17.0, PAPER)
	draw_circle(center, 17.0, INK, false, 2.0, true)
	var key_size: Vector2 = ui_font.get_string_size("F", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15)
	draw_string(ui_font, center - key_size * 0.5 + Vector2(0.0, key_size.y * 0.72), "F", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, INK)


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
	if level3_held_item != "" and (room == Stage.HOUSE or room == Stage.YARD):
		var level3_hand := p + Vector2(13.0 + player_facing * 18.0, 31.0)
		draw_line(shoulder, level3_hand, body_ink, 3.0, true)
		_draw_level_03_held_item(level3_hand)
	else:
		draw_line(shoulder, shoulder + Vector2(player_facing * 13.0, 8.0 + walk_phase * 2.0), body_ink, 3.0, true)
		draw_line(shoulder, shoulder + Vector2(-player_facing * 10.0, 7.0 - walk_phase * 2.0), body_ink, 3.0, true)

func _draw_level_03_held_item(hand: Vector2) -> void:
	var direction := Vector2(player_facing, -0.16)
	if level3_swing_time > 0.0:
		var swing_ratio: float = 1.0 - level3_swing_time / 0.32
		var swing_angle: float = lerpf(-1.25, 0.75, clampf(swing_ratio, 0.0, 1.0)) * player_facing
		direction = Vector2(cos(swing_angle), sin(swing_angle))
	if level3_held_item == "axe":
		_draw_shared_axe(hand, direction.angle(), 0.82)
		return
	var item_length: float = 58.0 if level3_held_item == "branch" else 48.0
	var end_point := hand + direction * item_length
	var item_color: Color = HEMP if level3_held_item == "branch" or level3_held_item == "torch" else Color("35383a")
	draw_line(hand, end_point, item_color, 6.0, true)
	draw_line(hand, end_point, INK, 1.5, true)
	if level3_held_item == "torch":
		_draw_scaled_fire(end_point, 0.48)



func _room_name() -> String:
	match room:
		Stage.HOUSE: return "A · 月炉木屋"
		Stage.YARD: return "B · 对岸庭院"
		Stage.CELLAR_READY: return "C · 地窖入口"
		Stage.CELLAR: return "根下旧矿"
		_: return "D · 地牢深处"

func _world_to_screen(world_position: Vector2) -> Vector2:
	return world_position - Vector2(camera_axis, 0.0) if room == Stage.HOUSE or room == Stage.YARD else world_position

func _world_rect_to_screen(world_rect: Rect2) -> Rect2:
	return Rect2(_world_to_screen(world_rect.position), world_rect.size)
