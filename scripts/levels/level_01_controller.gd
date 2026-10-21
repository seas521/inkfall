extends Node2D

signal completed
signal river_requested

const Palette = preload("res://scripts/shared/inkfall_palette.gd")
const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const ActorStyleHost = preload("res://scripts/actors/actor_style_host.gd")
const ScreenIris = preload("res://scripts/shared/screen_iris.gd")
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
const SurfaceLayeredArt = preload("res://scripts/art/surface_layered_art.gd")
const InkFlame = preload("res://scripts/effects/ink_flame.gd")
const SurfaceBatFlock = preload("res://scripts/art/surface_bat_flock.gd")
const Level01ShaftDepthArt = preload("res://scripts/art/level01_shaft_depth_art.gd")
const Level01ShaftLightArt = preload("res://scripts/art/level01_shaft_light_art.gd")
const Level01ShaftForegroundArt = preload("res://scripts/art/level01_shaft_foreground_art.gd")
const CavernDepthArt = preload("res://scripts/art/cavern_limbo_plate_art.gd")
const Level01SurfaceAudio = preload("res://scripts/audio/level01_surface_audio.gd")

const SURFACE_PLATFORMS: Array[Rect2] = [
	# Match the v2 gameplay plate: the keyed source edges are x=642 and
	# x=917, which render at roughly x=492 and x=702.
	Rect2(-80.0, 425.0, 562.0, 335.0),
	Rect2(712.0, 383.0, 648.0, 377.0),
]
const SURFACE_BAT_TRIGGER_DISTANCE := 105.0
const SURFACE_BAT_IMPACT_TIME := 0.82
const SURFACE_BAT_VISUAL_DURATION := 2.35

const SHAFT_PLATFORMS: Array[Rect2] = [
	# Independent wide-gorge composition. Only these short caps are walkable;
	# the large cliff tongues beneath them are visual mass.
	Rect2(470.0, 620.0, 190.0, 26.0),
	Rect2(680.0, 835.0, 90.0, 22.0),
	Rect2(520.0, 1030.0, 90.0, 22.0),
	Rect2(710.0, 1270.0, 90.0, 22.0),
	Rect2(550.0, 1460.0, 90.0, 22.0),
	Rect2(660.0, 1695.0, 90.0, 22.0),
	Rect2(490.0, 1905.0, 90.0, 22.0),
	Rect2(700.0, 2140.0, 90.0, 22.0),
	Rect2(530.0, 2350.0, 90.0, 22.0),
]
const SHAFT_HORIZONTAL_BOUNDS := Vector2(410.0, 870.0)

const SHAFT_FLAMES: Array[Rect2] = [
	# Flames occupy the inner 62px; the outer 28px is a precise landing lip.
	Rect2(680.0, 807.0, 62.0, 28.0),
	Rect2(548.0, 1002.0, 62.0, 28.0),
	Rect2(710.0, 1242.0, 62.0, 28.0),
	Rect2(578.0, 1432.0, 62.0, 28.0),
	Rect2(660.0, 1667.0, 62.0, 28.0),
	Rect2(518.0, 1877.0, 62.0, 28.0),
	Rect2(700.0, 2112.0, 62.0, 28.0),
	Rect2(558.0, 2322.0, 62.0, 28.0),
]

const CAVERN_FIXED_PLATFORMS: Array[Rect2] = [
	Rect2(60.0, 560.0, 520.0, 80.0),
	Rect2(870.0, 535.0, 130.0, 22.0),
	Rect2(1080.0, 465.0, 64.0, 18.0),
	Rect2(1215.0, 535.0, 130.0, 22.0),
	Rect2(1425.0, 455.0, 62.0, 18.0),
	Rect2(1690.0, 415.0, 88.0, 20.0),
	Rect2(1850.0, 485.0, 104.0, 22.0),
	Rect2(2030.0, 420.0, 52.0, 18.0),
	Rect2(2280.0, 335.0, 54.0, 18.0),
	Rect2(2400.0, 405.0, 100.0, 22.0),
	Rect2(2560.0, 335.0, 54.0, 18.0),
	Rect2(2680.0, 425.0, 90.0, 20.0),
	Rect2(2825.0, 355.0, 70.0, 18.0),
	Rect2(2970.0, 430.0, 150.0, 90.0),
]

const CAVERN_SPIKES: Array[Rect2] = [
	Rect2(1080.0, 437.0, 42.0, 28.0),
	Rect2(1447.0, 427.0, 40.0, 28.0),
	Rect2(2030.0, 392.0, 32.0, 28.0),
	Rect2(2560.0, 307.0, 34.0, 28.0),
	Rect2(2848.0, 327.0, 47.0, 28.0),
]

const SPOUT_VISUAL := Rect2(650.0, 175.0, 132.0, 92.0)
# Keep the gameplay target inside the visible circular socket. The previous
# oversized target accepted throws that visibly passed below the outlet.
const SPOUT_TARGET := Rect2(681.0, 204.0, 70.0, 70.0)
const WATER_CURTAIN := Rect2(636.0, 255.0, 160.0, 385.0)
const CAVERN_MID_CHECKPOINT_ZONE := Rect2(1688.0, 345.0, 92.0, 76.0)
const CAVERN_MID_CHECKPOINT_POSITION := Vector2(1721.0, 361.0)
const LIFT_PLATFORM := Rect2(3130.0, 430.0, 120.0, 20.0)
const LIFT_INTERACTION := Rect2(3114.0, 340.0, 152.0, 145.0)

enum Room { SURFACE, SHAFT, CAVERN, LEVEL_01_LIFT }
enum ShaftEntryPhase { NONE, FALLING, IMPACT, DOWNED, GET_UP, DONE }


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
var room := Room.SURFACE
var elapsed := 0.0
var room_intro_time := 4.2
var entry_fall_lock := 0.0
var shaft_entry_phase := ShaftEntryPhase.NONE
var shaft_catch_impact := 0.0
var shaft_dust: Array[Dictionary] = []
var shaft_flames: Array[Node2D] = []
var shaft_exit_armed := false
var river_exit_pending := false
var shaft_jump_grace := 0.0
var checkpoint_position := Vector2(170.0, 371.0)
var shaft_checkpoint_depth := 0.0
var pickup_items: Array[Dictionary] = []
var held_item_index := -1
var throw_preparing := false
var throw_hold_time := 0.0
var throw_angle := -0.82
var water_blocked := false
var lodged_item_index := -1
var lift_time := 0.0
var completion_time := 0.0
var ui_font: Font
var shaft_failure_kind := ""
var shaft_failure_time := 0.0
# The hooded boy's failures fade to black once the fall has played, then the checkpoint fades in.
const CURTAIN_CLOSE := 0.55
const CURTAIN_OPEN := 0.80
var curtain_phase := 0  # 0 none, 1 closing, 2 opening
var curtain_time := 0.0
var iris: CanvasLayer
var shaft_failure_origin := Vector2.ZERO
var cavern_failure_kind := ""
var cavern_failure_time := 0.0
var cavern_failure_origin := Vector2.ZERO
var cavern_mid_checkpoint_active := false
var cavern_checkpoint_flash_time := 0.0
var spout_reject_time := 0.0
var spout_reject_origin := Vector2.ZERO
var completion_sent := false
var surface_art: Node2D
var surface_bat_flock: Node2D
var surface_audio: Node
var shaft_depth_art: Node2D
var shaft_light_art: Node2D
var shaft_foreground_art: Node2D
var cavern_art: Node2D
var surface_camera_y := 0.0
var actor_action: StringName = ActorPoseState.ACTION_NONE
var actor_action_elapsed := 0.0
var actor_action_duration := 0.0
var actor_action_item_kind: StringName = &""
var actor_action_item_radius := 13.0
var surface_bat_triggered := false
var surface_bat_impact_started := false
var surface_bat_recovery_complete := false
var surface_bat_event_time := 0.0
var surface_bat_target := Vector2.ZERO

func _ready() -> void:
	surface_art = SurfaceLayeredArt.new()
	surface_art.show_behind_parent = true
	add_child(surface_art)
	surface_bat_flock = SurfaceBatFlock.new()
	add_child(surface_bat_flock)
	surface_audio = Level01SurfaceAudio.new()
	add_child(surface_audio)
	shaft_depth_art = Level01ShaftDepthArt.new()
	shaft_depth_art.show_behind_parent = true
	add_child(shaft_depth_art)
	shaft_light_art = Level01ShaftLightArt.new()
	shaft_light_art.show_behind_parent = true
	add_child(shaft_light_art)
	# The ledge flames: one living flame per hazard, standing on the ledge top, a little wider than the
	# hazard and licking above it. They are positioned each frame in sync_environment.
	for flame_index in range(SHAFT_FLAMES.size()):
		var flame := InkFlame.new() as Node2D
		flame.width = SHAFT_FLAMES[flame_index].size.x - 6.0
		flame.height = SHAFT_FLAMES[flame_index].size.y * 1.95
		flame.seed_value = flame_index + 3
		flame.monochrome = true
		flame.glow_scale = 0.5
		flame.strength = 0.0
		flame.visible = false
		add_child(flame)
		shaft_flames.append(flame)
	shaft_foreground_art = Level01ShaftForegroundArt.new()
	add_child(shaft_foreground_art)
	cavern_art = CavernDepthArt.new()
	cavern_art.show_behind_parent = true
	add_child(cavern_art)
	cavern_art.hide()

func enter(context, font: Font, game_host) -> void:
	game_context = context
	ui_font = font
	host = game_host
	visible = true
	reset()

func debug_enter_cavern_demo() -> void:
	_enter_cavern()
	room_intro_time = 4.8

func leave() -> void:
	game_context.run_speed_scale = 1.0
	game_context.ground_accel = 2300.0
	game_context.air_speed_scale = 1.0
	game_context.jump_speed_scale = 1.0
	game_context.jump_windup_total = 0.0
	game_context.jump_windup_left = 0.0
	surface_audio.deactivate()
	visible = false

func reset() -> void:
	river_exit_pending = false
	room = Room.SURFACE
	player_position = Vector2(170.0, 371.0)
	player_velocity = Vector2.ZERO
	checkpoint_position = player_position
	shaft_checkpoint_depth = 0.0
	camera_axis = 0.0
	room_intro_time = 4.2
	entry_fall_lock = 0.0
	shaft_entry_phase = ShaftEntryPhase.NONE
	shaft_catch_impact = 0.0
	shaft_exit_armed = false
	shaft_jump_grace = 0.0
	failure_flash = 0.0
	water_blocked = false
	lift_time = 0.0
	completion_time = 0.0
	shaft_failure_kind = ""
	shaft_failure_time = 0.0
	cavern_failure_kind = ""
	cavern_failure_time = 0.0
	cavern_mid_checkpoint_active = false
	cavern_checkpoint_flash_time = 0.0
	spout_reject_time = 0.0
	on_ground = false
	regular_jump_active = false
	completion_sent = false
	surface_camera_y = 0.0
	actor_action = ActorPoseState.ACTION_NONE
	actor_action_elapsed = 0.0
	actor_action_duration = 0.0
	actor_action_item_kind = &""
	_reset_surface_bat_event()
	surface_audio.reset_state()
	_reset_pickup_items()
	queue_redraw()

func restart_current() -> void:
	river_exit_pending = false
	match room:
		Room.SURFACE:
			player_position = Vector2(170.0, 371.0)
			checkpoint_position = player_position
			surface_camera_y = 0.0
			_reset_surface_bat_event()
		Room.SHAFT:
			player_position = Vector2(500.0, 566.0)
			checkpoint_position = player_position
			shaft_checkpoint_depth = 620.0
			camera_axis = clampf(player_position.y - 245.0, 0.0, 2050.0)
			shaft_entry_phase = ShaftEntryPhase.DONE
			shaft_catch_impact = 0.0
			shaft_exit_armed = false
			shaft_jump_grace = 0.0
		Room.CAVERN, Room.LEVEL_01_LIFT:
			room = Room.CAVERN
			player_position = Vector2(150.0, 506.0)
			checkpoint_position = player_position
			camera_axis = 0.0
			water_blocked = false
			cavern_mid_checkpoint_active = false
			cavern_checkpoint_flash_time = 0.0
			_reset_pickup_items()
	player_velocity = Vector2.ZERO
	on_ground = false
	regular_jump_active = false
	shaft_failure_kind = ""
	shaft_failure_time = 0.0
	cavern_failure_kind = ""
	cavern_failure_time = 0.0
	spout_reject_time = 0.0
	failure_flash = 0.18
	actor_action = ActorPoseState.ACTION_NONE
	actor_action_elapsed = 0.0
	actor_action_duration = 0.0
	actor_action_item_kind = &""
	queue_redraw()

func physics_tick(delta: float) -> void:
	elapsed += delta
	var hood_speed := ActorStyleHost.style_override == ActorPoseState.STYLE_HOOD
	game_context.run_speed_scale = ActorPoseState.HOOD_RUN_SPEED_SCALE if hood_speed else 1.0
	game_context.ground_accel = ActorPoseState.HOOD_START_ACCEL if hood_speed else 2300.0
	game_context.air_speed_scale = ActorPoseState.HOOD_AIR_SPEED_SCALE if hood_speed else 1.0
	game_context.jump_speed_scale = ActorPoseState.HOOD_JUMP_SCALE if hood_speed else 1.0
	game_context.jump_windup_total = ActorPoseState.HOOD_JUMP_WINDUP if hood_speed else 0.0
	_update_curtain(delta)
	_advance_actor_action(delta)
	room_intro_time = maxf(0.0, room_intro_time - delta)
	entry_fall_lock = maxf(0.0, entry_fall_lock - delta)
	shaft_catch_impact = maxf(0.0, shaft_catch_impact - delta)
	shaft_jump_grace = maxf(0.0, shaft_jump_grace - delta)
	failure_flash = maxf(0.0, failure_flash - delta)
	spout_reject_time = maxf(0.0, spout_reject_time - delta)
	cavern_checkpoint_flash_time = maxf(0.0, cavern_checkpoint_flash_time - delta)
	match room:
		Room.SURFACE: _update_surface(delta)
		Room.SHAFT: _update_shaft(delta)
		Room.CAVERN: _update_cavern(delta)
		Room.LEVEL_01_LIFT: _update_level_01_lift(delta)
	var surface_render_camera_y := _surface_render_camera_y()
	surface_art.sync(
		delta,
		player_position.x,
		surface_render_camera_y,
		room == Room.SURFACE,
		_surface_bat_gust_strength()
	)
	surface_bat_flock.sync(
		delta,
		surface_bat_event_time,
		surface_bat_target,
		surface_render_camera_y,
		room == Room.SURFACE
			and surface_bat_triggered
			and surface_bat_event_time < SURFACE_BAT_VISUAL_DURATION
	)
	surface_audio.sync(
		delta,
		room == Room.SURFACE,
		player_position,
		player_velocity,
		on_ground,
		actor_action,
		surface_bat_triggered,
		surface_bat_impact_started,
		surface_bat_event_time
	)
	shaft_depth_art.sync(delta, camera_axis, room == Room.SHAFT)
	shaft_light_art.sync(delta, camera_axis, room == Room.SHAFT)
	shaft_foreground_art.sync(delta, camera_axis, room == Room.SHAFT)
	cavern_art.sync(delta, camera_axis, room == Room.CAVERN or room == Room.LEVEL_01_LIFT, water_blocked)
	queue_redraw()

func presentation_state() -> Dictionary:
	var failure_time: float = shaft_failure_time if room == Room.SHAFT else (cavern_failure_time if room == Room.CAVERN else 0.0)
	if room == Room.SHAFT:
		# Shaft failures use the approved semantic hit / uncontrolled-fall clips.
		# Keeping the legacy failure timer here would override those clips.
		failure_time = 0.0
	var failure_duration: float = (0.82 if shaft_failure_kind == "fire" else 0.46) if room == Room.SHAFT else 0.76
	var visual_grounding_offset := Vector2(0.0, 4.0) if room == Room.SURFACE else Vector2.ZERO
	var item_kind := actor_action_item_kind
	var item_radius := actor_action_item_radius
	if held_item_index >= 0:
		var held_item: Dictionary = pickup_items[held_item_index]
		item_kind = StringName(held_item["kind"])
		item_radius = float(held_item["radius"])
	var has_throwable := (
		held_item_index >= 0
		or actor_action == ActorPoseState.ACTION_PICKUP
		or actor_action == ActorPoseState.ACTION_PUT_DOWN
		or actor_action == ActorPoseState.ACTION_THROW_RELEASE
	)
	return {
		"style_id": ActorPoseState.STYLE_CROOKED_TOWER,
		"feet": _world_to_screen(player_position + Vector2(13.0, 54.0)) + visual_grounding_offset,
		"velocity": player_velocity, "grounded": on_ground, "facing": player_facing,
		"held": held_item_index, "aiming": throw_preparing, "room": int(room),
		"failure_time": failure_time, "failure_duration": failure_duration,
		"equipment": ActorPoseState.EQUIPMENT_THROWABLE if has_throwable else ActorPoseState.EQUIPMENT_NONE,
		"action": actor_action,
		"action_progress": _actor_action_progress(),
		"jump_windup": (1.0 - game_context.jump_windup_left / game_context.jump_windup_total) if (game_context.jump_windup_left > 0.0 and game_context.jump_windup_total > 0.0) else -1.0,
		"aim_angle": throw_angle,
		"effort": clampf(throw_hold_time, 0.0, 1.0),
		"light_exposure": 0.38 if room == Room.SURFACE else 0.18,
		"small_item_kind": item_kind,
		"small_item_radius": item_radius,
		"visual_scale": 0.78 if room == Room.SURFACE else 1.0,
		"fog_blur": _surface_actor_fog_blur() if room == Room.SURFACE else 0.0,
		"monochrome": room == Room.CAVERN or room == Room.LEVEL_01_LIFT,
		"clip_flip_h": _shaft_entry_clip_flip(),
		"frame_root_offset": _shaft_entry_frame_root_offset(),
		"camera_axis": camera_axis + (_shaft_shake_y() if room == Room.SHAFT else 0.0),
		"cavern_foreground": room == Room.CAVERN or room == Room.LEVEL_01_LIFT,
		"actor_z_index": 10 if room == Room.SURFACE else 0,
	}

func _shaft_entry_clip_flip() -> bool:
	if room != Room.SHAFT:
		return false
	# The whole drop, the landing, the lying and the getting up face the same way (left).
	return shaft_entry_phase in [
		ShaftEntryPhase.FALLING,
		ShaftEntryPhase.IMPACT,
		ShaftEntryPhase.DOWNED,
		ShaftEntryPhase.GET_UP,
	]

func _shaft_entry_frame_root_offset() -> Vector2:
	if room != Room.SHAFT:
		return Vector2.ZERO
	if shaft_entry_phase == ShaftEntryPhase.DOWNED:
		return Vector2(10.3, 0.0)
	if shaft_entry_phase == ShaftEntryPhase.GET_UP:
		# The mirrored get-up clip starts lying where the downed clip lay (+36) and stands up with its
		# feet on the root (+90), so the body slides across as it rises instead of snapping at the end.
		var progress := clampf(actor_action_elapsed / 2.375, 0.0, 1.0)
		return Vector2(lerpf(36.5, 89.6, smoothstep(0.0, 1.0, progress)), 0.0)
	return Vector2.ZERO

func _set_actor_action(next_action: StringName, duration: float = 0.0) -> void:
	actor_action = next_action
	actor_action_elapsed = 0.0
	actor_action_duration = duration

func _advance_actor_action(delta: float) -> void:
	if actor_action_duration <= 0.0:
		return
	actor_action_elapsed += delta
	if actor_action_elapsed < actor_action_duration:
		return
	var finished_action := actor_action
	actor_action_elapsed = actor_action_duration
	actor_action_duration = 0.0
	if (
		finished_action == ActorPoseState.ACTION_FALL_IMPACT
		and room == Room.SHAFT
		and shaft_entry_phase == ShaftEntryPhase.IMPACT
	):
		shaft_entry_phase = ShaftEntryPhase.DOWNED
		_set_actor_action(ActorPoseState.ACTION_FALL_DOWNED, 0.68)
	elif (
		finished_action == ActorPoseState.ACTION_FALL_DOWNED
		and room == Room.SHAFT
		and shaft_entry_phase == ShaftEntryPhase.DOWNED
	):
		shaft_entry_phase = ShaftEntryPhase.GET_UP
		_spawn_shaft_impact_dust(player_position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y), 0.45)
		_set_actor_action(ActorPoseState.ACTION_GET_UP, 2.375)
	elif (
		finished_action == ActorPoseState.ACTION_GET_UP
		and room == Room.SHAFT
		and shaft_entry_phase == ShaftEntryPhase.GET_UP
	):
		shaft_entry_phase = ShaftEntryPhase.DONE
		# He stands up facing the way he fell (the hooded boy stands facing right, where the shaft goes on).
		player_facing = 1.0 if ActorStyleHost.style_override == ActorPoseState.STYLE_HOOD else -1.0
		checkpoint_position = Vector2(500.0, 566.0)
		shaft_checkpoint_depth = 620.0
		_set_actor_action(ActorPoseState.ACTION_NONE)
	elif finished_action == ActorPoseState.ACTION_KNOCKDOWN:
		_set_actor_action(ActorPoseState.ACTION_DOWNED, 1.25)
	elif finished_action == ActorPoseState.ACTION_DOWNED:
		_set_actor_action(ActorPoseState.ACTION_GET_UP, 2.375)
	elif (
		finished_action == ActorPoseState.ACTION_HIT
		and room == Room.SHAFT
		and shaft_failure_kind == "fire"
	):
		_set_actor_action(ActorPoseState.ACTION_UNCONTROLLED_FALL, 1.708)
	else:
		actor_action = ActorPoseState.ACTION_NONE
		actor_action_elapsed = 0.0
		actor_action_item_kind = &""
		if finished_action == ActorPoseState.ACTION_GET_UP:
			surface_bat_recovery_complete = true

func _actor_action_progress() -> float:
	if actor_action_duration > 0.0:
		return clampf(actor_action_elapsed / actor_action_duration, 0.0, 1.0)
	if actor_action == ActorPoseState.ACTION_THROW_CHARGE:
		return clampf(throw_hold_time, 0.0, 1.0)
	return 0.0

func sync_environment(env_fx: Node2D) -> void:
	for flame_index in range(shaft_flames.size()):
		var flame := shaft_flames[flame_index]
		flame.visible = room == Room.SHAFT
		if room == Room.SHAFT:
			var hazard: Rect2 = SHAFT_FLAMES[flame_index]
			flame.position = _world_to_screen(Vector2(hazard.get_center().x, hazard.end.y - 2.0))
			flame.set("strength", _shaft_flame_strength(flame_index))
	if room == Room.CAVERN or room == Room.LEVEL_01_LIFT:
		var river: Rect2 = _world_rect_to_screen(Rect2(-320, 605, 4100, 150))
		var cropped: Rect2 = river.intersection(Rect2(0, 0, SCREEN.x, SCREEN.y))
		env_fx.call("present", "river", cropped, "river", elapsed, 1.0, 0.0, -320.0 + cropped.position.x - river.position.x, not water_blocked, true)
		if not water_blocked:
			env_fx.call("present", "waterfall", _world_rect_to_screen(WATER_CURTAIN), "waterfall", elapsed, 1.0, 0.0, 0.0, true, true)
		var columns: Array[Dictionary] = _cavern_gas_columns()
		for i in range(columns.size()):
			var column: Dictionary = columns[i]
			if _gas_active(float(column["phase"])):
				env_fx.call("present", "gas_%d" % i, _world_rect_to_screen(column["rect"]), "gas", elapsed, 1.0, float(i) * 1.31, 0.0, true, true)

func _draw() -> void:
	draw_world()
	if room != Room.SURFACE:
		host.draw_actor_shadow(self, _shadow_surfaces(), player_position, camera_axis)
	if room == Room.SHAFT and shaft_failure_kind != "": _draw_shaft_failure_effect()
	if room == Room.CAVERN and cavern_failure_kind != "": _draw_cavern_failure_effect()
	if room == Room.CAVERN and spout_reject_time > 0.0: _draw_spout_reject_effect()
	draw_ui()
	# the hooded boy's failures use the iris instead of the grey flash
	if failure_flash > 0.0 and ActorStyleHost.style_override != ActorPoseState.STYLE_HOOD:
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(INK, failure_flash * 0.7))
	_sync_iris()

func draw_world() -> void:
	match room:
		Room.SURFACE: _draw_surface()
		Room.SHAFT: _draw_shaft()
		Room.CAVERN, Room.LEVEL_01_LIFT: _draw_cavern()

func draw_ui() -> void:
	var base_color: Color = PAPER
	if room == Room.CAVERN or room == Room.LEVEL_01_LIFT:
		draw_rect(Rect2(998.0, 14.0, 224.0, 42.0), Color(INK, 0.48))
	if room == Room.CAVERN and not water_blocked:
		draw_string(ui_font, Vector2(1015.0, 42.0), "水路：未截断", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.78, 0.78, 0.76))
	elif room == Room.CAVERN or room == Room.LEVEL_01_LIFT:
		draw_string(ui_font, Vector2(1015.0, 42.0), "水路：已截断", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, base_color)
	if room == Room.CAVERN and cavern_checkpoint_flash_time > 0.0:
		var text := "中段检查点已记录"
		var width := ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
		draw_string(ui_font, Vector2((SCREEN.x - width) * 0.5, 104.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color(base_color, clampf(cavern_checkpoint_flash_time, 0.0, 1.0)))
	if room_intro_time > 0.0:
		var text := _room_intro_text()
		var width := ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22).x
		if room == Room.CAVERN or room == Room.LEVEL_01_LIFT:
			draw_rect(Rect2((SCREEN.x - width) * 0.5 - 18.0, 86.0, width + 36.0, 43.0), Color(INK, 0.42))
		draw_string(ui_font, Vector2((SCREEN.x - width) * 0.5, 118.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(base_color, clampf(room_intro_time, 0.0, 1.0) * 0.85))
	if room == Room.LEVEL_01_LIFT and completion_time > 0.28:
		var alpha := sin(clampf((completion_time - 0.28) / 1.25, 0.0, 1.0) * PI)
		draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(INK, alpha * 0.32))
		var text := "升降梯通往下一处断崖"
		var width := ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25).x
		draw_string(ui_font, Vector2((SCREEN.x - width) * 0.5, 336.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 25, Color(PAPER, alpha))

func _shadow_surfaces() -> Array[Rect2]:
	var surfaces: Array[Rect2] = []
	if room == Room.SURFACE: surfaces.append_array(SURFACE_PLATFORMS)
	elif room == Room.SHAFT: surfaces.append_array(_shaft_collision_platforms())
	else:
		surfaces.append_array(CAVERN_FIXED_PLATFORMS)
		surfaces.append_array(_cavern_dynamic_platforms(elapsed))
		var lift_surface := LIFT_PLATFORM
		lift_surface.position.y -= lift_time * 238.0
		surfaces.append(lift_surface)
	return surfaces

func _shaft_collision_platforms() -> Array[Rect2]:
	var result: Array[Rect2] = []
	result.append_array(SHAFT_PLATFORMS)
	for platform_index in range(SHAFT_PLATFORMS.size()):
		var platform := SHAFT_PLATFORMS[platform_index]
		if platform_index == 0:
			result.append(Rect2(
				Vector2(SHAFT_HORIZONTAL_BOUNDS.x, platform.position.y),
				Vector2(platform.position.x - SHAFT_HORIZONTAL_BOUNDS.x, 18.0)
			))
			continue
		_append_shaft_wall_collision(result, platform, platform.get_center().x < 640.0)
	return result

func _append_shaft_wall_collision(result: Array[Rect2], platform: Rect2, from_left: bool) -> void:
	var start_x := SHAFT_HORIZONTAL_BOUNDS.x if from_left else platform.end.x
	var end_x := platform.position.x if from_left else SHAFT_HORIZONTAL_BOUNDS.y
	var start_y := platform.position.y - 18.0 if from_left else platform.position.y
	var end_y := platform.position.y if from_left else platform.position.y - 18.0
	var step_count := 9
	for step_index in range(step_count):
		var ratio_start := float(step_index) / float(step_count)
		var ratio_end := float(step_index + 1) / float(step_count)
		var x0 := lerpf(start_x, end_x, ratio_start)
		var x1 := lerpf(start_x, end_x, ratio_end)
		var top_y := lerpf(start_y, end_y, (ratio_start + ratio_end) * 0.5)
		result.append(Rect2(Vector2(x0, top_y), Vector2(maxf(7.0, x1 - x0), 18.0)))

func _room_name() -> String:
	match room:
		Room.SURFACE: return "A · 悬崖井口"
		Room.SHAFT: return "B · 雨根竖井"
		_: return "C · 井底根穴"

func _room_intro_text() -> String:
	match room:
		Room.SURFACE: return ""
		Room.SHAFT: return ""
		_: return "冷光沿井壁落进根穴；长按 F 蓄力，用石块截断水路。"

func _world_to_screen(world_position: Vector2) -> Vector2:
	if room == Room.SURFACE: return world_position - Vector2(0.0, _surface_render_camera_y())
	if room == Room.SHAFT: return world_position - Vector2(0.0, camera_axis + _shaft_shake_y())
	if room == Room.CAVERN or room == Room.LEVEL_01_LIFT: return world_position - Vector2(camera_axis, 0.0)
	return world_position

func _world_rect_to_screen(world_rect: Rect2) -> Rect2:
	return Rect2(_world_to_screen(world_rect.position), world_rect.size)

func _art_soft_cloud(center: Vector2, size: Vector2, tint: Color) -> void:
	host.draw_soft_cloud(self, center, size, tint)

func _update_surface(delta: float) -> void:
	var sequence_locked := _surface_bat_sequence_locks_movement()
	if sequence_locked:
		player_velocity.x = 0.0
	_update_player(
		delta,
		SURFACE_PLATFORMS,
		Vector2(-20.0, 1274.0),
		not sequence_locked
	)
	if sequence_locked:
		player_velocity.x = 0.0
	_update_surface_bat_event(delta)
	camera_axis = 0.0
	var camera_target_y: float = clampf(
		(player_position.y - 371.0) * 0.28 + player_velocity.y * 0.022,
		-38.0,
		44.0
	)
	if on_ground:
		camera_target_y = 0.0
	var camera_follow_weight: float = 1.0 - exp(-5.2 * delta)
	surface_camera_y = lerpf(surface_camera_y, camera_target_y, camera_follow_weight)
	if player_position.y > SCREEN.y + 36.0:
		if player_position.x > 390.0 and player_position.x < 812.0:
			_enter_shaft()
		else:
			_fail_and_respawn()

func _surface_bat_sequence_locks_movement() -> bool:
	return (
		surface_bat_triggered
		and not surface_bat_recovery_complete
	)

func _surface_bat_gust_strength() -> float:
	if not surface_bat_triggered:
		return 0.0
	var rise := smoothstep(0.12, 0.42, surface_bat_event_time)
	var fall := 1.0 - smoothstep(0.92, 1.72, surface_bat_event_time)
	return clampf(rise * fall, 0.0, 1.0)

func _surface_render_camera_y() -> float:
	if room != Room.SURFACE or not surface_bat_triggered:
		return surface_camera_y
	var emergence := (
		smoothstep(0.06, 0.20, surface_bat_event_time)
		* (1.0 - smoothstep(0.66, SURFACE_BAT_IMPACT_TIME, surface_bat_event_time))
	)
	var impact_age := maxf(0.0, surface_bat_event_time - SURFACE_BAT_IMPACT_TIME)
	var impact := (
		exp(-7.5 * impact_age)
		* (1.0 - smoothstep(0.0, 0.56, impact_age))
		if surface_bat_event_time >= SURFACE_BAT_IMPACT_TIME
		else 0.0
	)
	var shake := (
		sin(elapsed * 31.0) * 0.75 * emergence
		+ sin(elapsed * 43.0 + 0.6) * 2.85 * impact
	)
	return surface_camera_y + shake

func _surface_actor_fog_blur() -> float:
	return 2.15

func _update_surface_bat_event(delta: float) -> void:
	if not surface_bat_triggered:
		var player_front := player_position.x + PLAYER_SIZE.x
		var trigger_x := SURFACE_PLATFORMS[0].end.x - SURFACE_BAT_TRIGGER_DISTANCE
		if player_front >= trigger_x:
			surface_bat_triggered = true
			surface_bat_event_time = 0.0
			surface_bat_target = player_position + PLAYER_SIZE * 0.5
			player_velocity.x = 0.0
		return

	if not surface_bat_impact_started:
		surface_bat_target = player_position + PLAYER_SIZE * 0.5
	surface_bat_event_time += delta
	if surface_bat_impact_started or surface_bat_event_time < SURFACE_BAT_IMPACT_TIME:
		return
	if not on_ground:
		surface_bat_event_time = SURFACE_BAT_IMPACT_TIME - 0.035
		return

	surface_bat_impact_started = true
	surface_bat_target = player_position + PLAYER_SIZE * 0.5
	player_velocity = Vector2.ZERO
	regular_jump_active = false
	_set_actor_action(ActorPoseState.ACTION_KNOCKDOWN, 1.417)

func _reset_surface_bat_event() -> void:
	surface_bat_triggered = false
	surface_bat_impact_started = false
	surface_bat_recovery_complete = false
	surface_bat_event_time = 0.0
	surface_bat_target = player_position + PLAYER_SIZE * 0.5
	if surface_bat_flock != null:
		surface_bat_flock.hide()

func _enter_shaft() -> void:
	room = Room.SHAFT
	player_position = Vector2(520.0, -170.0)
	player_velocity = Vector2(18.0, 210.0)
	checkpoint_position = Vector2(500.0, 566.0)
	shaft_checkpoint_depth = 0.0
	camera_axis = 0.0
	entry_fall_lock = 2.2
	shaft_entry_phase = ShaftEntryPhase.FALLING
	shaft_catch_impact = 0.0
	shaft_dust.clear()
	shaft_exit_armed = false
	shaft_jump_grace = 0.0
	room_intro_time = 3.4
	on_ground = false
	regular_jump_active = false
	shaft_failure_kind = ""
	shaft_failure_time = 0.0
	_set_actor_action(ActorPoseState.ACTION_UNCONTROLLED_FALL)
	surface_bat_flock.hide()

func _update_shaft(delta: float) -> void:
	_update_shaft_dust(delta)
	if river_exit_pending:
		player_velocity = Vector2(0.0, 180.0)
		player_position += player_velocity * delta
		camera_axis += 115.0 * delta
		return
	if shaft_failure_kind != "":
		_update_shaft_failure(delta)
		return

	var entry_locked := (
		shaft_entry_phase != ShaftEntryPhase.NONE
		and shaft_entry_phase != ShaftEntryPhase.DONE
	)
	if (
		shaft_entry_phase == ShaftEntryPhase.DONE
		and on_ground
		and Input.is_action_just_pressed("jump")
	):
		shaft_jump_grace = 1.35
	if shaft_entry_phase == ShaftEntryPhase.FALLING:
		player_velocity.y = minf(player_velocity.y, 540.0)
	_update_player(delta, _shaft_collision_platforms(), SHAFT_HORIZONTAL_BOUNDS, not entry_locked)
	if on_ground:
		shaft_jump_grace = 0.0
	if shaft_entry_phase == ShaftEntryPhase.FALLING:
		player_velocity.y = minf(player_velocity.y, 540.0)
		var catch_top := SHAFT_PLATFORMS[0].position.y
		var player_feet := player_position.y + PLAYER_SIZE.y
		if on_ground and absf(player_feet - catch_top) <= 6.0:
			shaft_entry_phase = ShaftEntryPhase.IMPACT
			shaft_catch_impact = 0.65
			_spawn_shaft_impact_dust(player_position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y), 1.0)
			entry_fall_lock = 0.0
			player_velocity = Vector2.ZERO
			checkpoint_position = player_position
			shaft_checkpoint_depth = 620.0
			_set_actor_action(ActorPoseState.ACTION_FALL_IMPACT, 0.542)
	camera_axis = clampf(player_position.y - 245.0, 0.0, 2050.0)
	_update_shaft_checkpoint()

	var player_rect := Rect2(player_position, PLAYER_SIZE)
	for index in range(SHAFT_FLAMES.size()):
		if _shaft_flame_is_dangerous(index) and player_rect.intersects(SHAFT_FLAMES[index]):
			_start_shaft_failure("fire", SHAFT_FLAMES[index].get_center())
			return

	var final_platform := SHAFT_PLATFORMS[SHAFT_PLATFORMS.size() - 1]
	var standing_on_final_platform := (
		on_ground
		and absf(player_position.y + PLAYER_SIZE.y - final_platform.position.y) <= 6.0
	)
	if standing_on_final_platform:
		shaft_exit_armed = true
	if shaft_exit_armed and not on_ground and player_position.y > 2450.0:
		river_exit_pending = true
		river_requested.emit()
		return

	# A step-off between adjacent shelves stays below this speed. Missing one
	# shelf or trying to jump over it crosses the limit before a later landing.
	if (
		shaft_entry_phase != ShaftEntryPhase.FALLING
		and entry_fall_lock <= 0.0
		and shaft_jump_grace <= 0.0
		and not on_ground
		and player_velocity.y > SHAFT_FATAL_FALL_SPEED
	):
		_start_shaft_failure("fall", player_position + PLAYER_SIZE * 0.5)
		return

	if player_position.y > 2650.0:
		_fail_and_respawn()
		return

func _start_shaft_failure(kind: String, source: Vector2) -> void:
	shaft_failure_kind = kind
	shaft_failure_time = 0.001
	shaft_failure_origin = source
	on_ground = false
	regular_jump_active = false
	if kind == "fire":
		_set_actor_action(ActorPoseState.ACTION_HIT, 0.26)
		var player_center := player_position + PLAYER_SIZE * 0.5
		var recoil_direction := signf(player_center.x - source.x)
		if is_zero_approx(recoil_direction):
			recoil_direction = -player_facing
		player_velocity = Vector2(recoil_direction * 185.0, -225.0)
	else:
		_set_actor_action(ActorPoseState.ACTION_UNCONTROLLED_FALL, 1.708)

func _sync_iris() -> void:
	if iris == null:
		iris = ScreenIris.new()
		add_child(iris)
	var centre := _world_to_screen(player_position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y * 0.5))
	iris.call("set_state", _curtain_alpha() if curtain_phase != 0 else 0.0, centre)

func _begin_curtain() -> bool:
	if ActorStyleHost.style_override != ActorPoseState.STYLE_HOOD:
		return false
	if curtain_phase == 0:
		curtain_phase = 1
		curtain_time = 0.0
	return true

func _update_curtain(delta: float) -> void:
	if curtain_phase == 1:
		curtain_time += delta
		if curtain_time >= CURTAIN_CLOSE:
			curtain_phase = 2
			curtain_time = 0.0
			shaft_failure_kind = ""
			shaft_failure_time = 0.0
			cavern_failure_kind = ""
			cavern_failure_time = 0.0
			_fail_and_respawn()
	elif curtain_phase == 2:
		curtain_time += delta
		if curtain_time >= CURTAIN_OPEN:
			curtain_phase = 0

func _curtain_alpha() -> float:
	if curtain_phase == 1:
		return smoothstep(0.0, CURTAIN_CLOSE, curtain_time)
	if curtain_phase == 2:
		return 1.0 - smoothstep(0.0, CURTAIN_OPEN, curtain_time)
	return 0.0

func _update_shaft_failure(delta: float) -> void:
	shaft_failure_time += delta
	player_velocity.x = move_toward(player_velocity.x, 0.0, 210.0 * delta)
	player_velocity.y += GRAVITY * delta
	player_position += player_velocity * delta
	player_position.x = clampf(player_position.x, SHAFT_HORIZONTAL_BOUNDS.x, SHAFT_HORIZONTAL_BOUNDS.y - PLAYER_SIZE.x)
	camera_axis = clampf(player_position.y - 245.0, 0.0, 2050.0)

	var duration := 0.82 if shaft_failure_kind == "fire" else 0.46
	if shaft_failure_time >= duration:
		if _begin_curtain():
			return
		shaft_failure_kind = ""
		shaft_failure_time = 0.0
		_fail_and_respawn()

func _update_shaft_checkpoint() -> void:
	if not on_ground:
		return
	if player_position.y > 1350.0 and shaft_checkpoint_depth < 1350.0:
		checkpoint_position = Vector2(551.0, 1406.0)
		shaft_checkpoint_depth = 1350.0
	elif player_position.y > 2000.0 and shaft_checkpoint_depth < 2000.0:
		checkpoint_position = Vector2(764.0, 2086.0)
		shaft_checkpoint_depth = 2000.0

func _enter_cavern() -> void:
	room = Room.CAVERN
	shaft_entry_phase = ShaftEntryPhase.NONE
	shaft_catch_impact = 0.0
	shaft_exit_armed = false
	shaft_jump_grace = 0.0
	player_position = Vector2(150.0, 506.0)
	player_velocity = Vector2.ZERO
	checkpoint_position = player_position
	camera_axis = 0.0
	room_intro_time = 3.2
	entry_fall_lock = 0.28
	on_ground = false
	regular_jump_active = false
	shaft_failure_kind = ""
	shaft_failure_time = 0.0
	cavern_failure_kind = ""
	cavern_failure_time = 0.0
	cavern_mid_checkpoint_active = false
	cavern_checkpoint_flash_time = 0.0
	spout_reject_time = 0.0
	_reset_pickup_items()

func _update_cavern(delta: float) -> void:
	if cavern_failure_kind != "":
		_update_cavern_failure(delta)
		return

	var previous_dynamic_rects: Array[Rect2] = _cavern_dynamic_platforms(elapsed - delta)
	var dynamic_rects: Array[Rect2] = _cavern_dynamic_platforms(elapsed)
	_carry_player_with_dynamic_platform(previous_dynamic_rects, dynamic_rects)

	var all_platforms: Array[Rect2] = []
	all_platforms.append_array(CAVERN_FIXED_PLATFORMS)
	all_platforms.append(LIFT_PLATFORM)
	all_platforms.append_array(dynamic_rects)
	_update_player(delta, all_platforms, Vector2(20.0, 3340.0), entry_fall_lock <= 0.0)
	_update_pickup_interaction(delta, all_platforms)
	_update_pickup_items(delta, all_platforms)

	camera_axis = clampf(player_position.x - 370.0, 0.0, 2060.0)

	if not water_blocked and Rect2(player_position, PLAYER_SIZE).intersects(WATER_CURTAIN):
		player_velocity.x = -430.0
		player_velocity.y = -190.0
		player_position.x = minf(player_position.x, WATER_CURTAIN.position.x - PLAYER_SIZE.x - 4.0)
		failure_flash = maxf(failure_flash, 0.12)

	var player_rect := Rect2(player_position, PLAYER_SIZE)
	for index in range(CAVERN_SPIKES.size()):
		var spike_hit_rect: Rect2 = _cavern_spike_hit_rect(index)
		if _cavern_spike_is_dangerous(index) and player_rect.intersects(spike_hit_rect):
			_start_cavern_failure("spike", spike_hit_rect.get_center())
			return

	if _player_in_active_gas():
		_start_cavern_failure("gas", player_position + PLAYER_SIZE * 0.5)
		return

	_update_cavern_mid_checkpoint(player_rect)

	if player_position.y > SCREEN.y + 90.0:
		_fail_and_respawn()
		return

	if water_blocked and held_item_index < 0 and Rect2(player_position, PLAYER_SIZE).intersects(LIFT_INTERACTION):
		if Input.is_action_just_pressed("interact"):
			room = Room.LEVEL_01_LIFT
			lift_time = 0.0
			completion_time = 0.0
			player_position = Vector2(3174.0, LIFT_PLATFORM.position.y - PLAYER_SIZE.y)
			player_velocity = Vector2.ZERO
			on_ground = true

func _update_cavern_mid_checkpoint(player_rect: Rect2) -> void:
	if cavern_mid_checkpoint_active or not water_blocked or not on_ground:
		return
	if not player_rect.intersects(CAVERN_MID_CHECKPOINT_ZONE):
		return
	cavern_mid_checkpoint_active = true
	cavern_checkpoint_flash_time = 1.8
	checkpoint_position = CAVERN_MID_CHECKPOINT_POSITION

func _start_cavern_failure(kind: String, source: Vector2) -> void:
	cavern_failure_kind = kind
	cavern_failure_time = 0.001
	cavern_failure_origin = source
	on_ground = false
	regular_jump_active = false
	var player_center := player_position + PLAYER_SIZE * 0.5
	var recoil_direction := signf(player_center.x - source.x)
	if is_zero_approx(recoil_direction):
		recoil_direction = -player_facing
	player_velocity = Vector2(recoil_direction * 170.0, -210.0)

func _update_cavern_failure(delta: float) -> void:
	cavern_failure_time += delta
	player_velocity.x = move_toward(player_velocity.x, 0.0, 190.0 * delta)
	player_velocity.y += GRAVITY * delta
	player_position += player_velocity * delta
	player_position.x = clampf(player_position.x, 20.0, 3340.0 - PLAYER_SIZE.x)
	camera_axis = clampf(player_position.x - 370.0, 0.0, 2060.0)
	if cavern_failure_time >= 0.76:
		if _begin_curtain():
			return
		cavern_failure_kind = ""
		cavern_failure_time = 0.0
		_fail_and_respawn()

func _update_level_01_lift(delta: float) -> void:
	lift_time = minf(1.0, lift_time + delta / 1.35)
	completion_time += delta
	player_velocity = Vector2.ZERO
	player_position.y = LIFT_PLATFORM.position.y - PLAYER_SIZE.y - lift_time * 238.0
	if completion_time >= 1.65:
		if not completion_sent:
			completion_sent = true
			completed.emit()

func _update_player(delta: float, platform_list: Array[Rect2], horizontal_bounds: Vector2, allow_input: bool) -> void:
	host.update_shared_player(game_context, delta, platform_list, horizontal_bounds, allow_input)

func _carry_player_with_dynamic_platform(previous_rects: Array[Rect2], current_rects: Array[Rect2]) -> void:
	host.carry_shared_player(game_context, previous_rects, current_rects)

func _cavern_dynamic_platforms(sample_time: float) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if not water_blocked:
		return result
	result.append(Rect2(690.0 + sin(sample_time * 1.25) * 70.0, 515.0, 110.0, 20.0))
	result.append(Rect2(1530.0 + sin(sample_time * 0.92 + 1.4) * 75.0, 510.0, 72.0, 18.0))
	result.append(Rect2(2160.0, 350.0 + sin(sample_time * 0.78 + 0.8) * 70.0, 68.0, 18.0))
	var cable_ratio := (sin(sample_time * 0.72) + 1.0) * 0.5
	var cable_position := Vector2(2480.0, 285.0).lerp(Vector2(2870.0, 235.0), cable_ratio)
	result.append(Rect2(cable_position, Vector2(104.0, 18.0)))
	return result

func _reset_pickup_items() -> void:
	pickup_items = [
		_make_pickup("stone", Vector2(340.0, 532.0), 14.0),
		_make_pickup("wood", Vector2(430.0, 530.0), 16.0),
		_make_pickup("scrap", Vector2(520.0, 532.0), 13.0),
	]
	held_item_index = -1
	throw_preparing = false
	throw_hold_time = 0.0
	lodged_item_index = -1

func _make_pickup(kind: String, spawn_position: Vector2, radius: float) -> Dictionary:
	return {
		"kind": kind,
		"position": spawn_position,
		"spawn": spawn_position,
		"velocity": Vector2.ZERO,
		"radius": radius,
		"state": "waiting",
		"spout_cooldown": 0.0,
	}

func _update_pickup_interaction(delta: float, platform_list: Array[Rect2]) -> void:
	if held_item_index >= 0:
		throw_angle = clampf(
			throw_angle + Input.get_axis("aim_up", "aim_down") * 1.55 * delta,
			-1.38,
			-0.18
		)

	if Input.is_action_just_pressed("interact"):
		if held_item_index >= 0:
			throw_preparing = true
			throw_hold_time = 0.0
			_set_actor_action(ActorPoseState.ACTION_THROW_CHARGE)
		else:
			_try_pick_up_item()

	if not throw_preparing:
		return
	if Input.is_action_pressed("interact"):
		throw_hold_time = minf(1.0, throw_hold_time + delta)
		return
	_release_held_item(platform_list)

func _try_pick_up_item() -> void:
	var nearest_index := -1
	var nearest_distance := 68.0
	var player_center := player_position + PLAYER_SIZE * 0.5
	for index in range(pickup_items.size()):
		var item: Dictionary = pickup_items[index]
		if item["state"] != "waiting":
			continue
		var distance: float = player_center.distance_to(item["position"])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_index = index
	if nearest_index < 0:
		return
	held_item_index = nearest_index
	pickup_items[nearest_index]["state"] = "carried"
	pickup_items[nearest_index]["velocity"] = Vector2.ZERO
	actor_action_item_kind = StringName(pickup_items[nearest_index]["kind"])
	actor_action_item_radius = float(pickup_items[nearest_index]["radius"])
	_set_actor_action(ActorPoseState.ACTION_PICKUP, 0.30)

func _release_held_item(_platform_list: Array[Rect2]) -> void:
	if held_item_index < 0:
		throw_preparing = false
		return
	var item: Dictionary = pickup_items[held_item_index]
	actor_action_item_kind = StringName(item["kind"])
	actor_action_item_radius = float(item["radius"])
	var ratio := clampf((throw_hold_time - THROW_HOLD_THRESHOLD) / 0.82, 0.0, 1.0)
	if throw_hold_time < THROW_HOLD_THRESHOLD:
		item["state"] = "waiting"
		item["position"] = player_position + Vector2(PLAYER_SIZE.x * 0.5 + player_facing * 28.0, PLAYER_SIZE.y - item["radius"])
		item["velocity"] = Vector2.ZERO
	else:
		var strength := lerpf(THROW_MIN_SPEED, THROW_MAX_SPEED, ratio)
		var direction := Vector2(player_facing * cos(throw_angle), sin(throw_angle)).normalized()
		item["state"] = "thrown"
		item["position"] = _held_item_position()
		item["velocity"] = direction * strength
	_set_actor_action(
		ActorPoseState.ACTION_PUT_DOWN if throw_hold_time < THROW_HOLD_THRESHOLD else ActorPoseState.ACTION_THROW_RELEASE,
		0.28 if throw_hold_time < THROW_HOLD_THRESHOLD else 0.34
	)
	pickup_items[held_item_index] = item
	held_item_index = -1
	throw_preparing = false
	throw_hold_time = 0.0

func _update_pickup_items(delta: float, platform_list: Array[Rect2]) -> void:
	for index in range(pickup_items.size()):
		var item: Dictionary = pickup_items[index]
		var spout_cooldown: float = maxf(0.0, float(item["spout_cooldown"]) - delta)
		item["spout_cooldown"] = spout_cooldown
		if index == held_item_index:
			item["position"] = _held_item_position()
			item["velocity"] = Vector2.ZERO
			pickup_items[index] = item
			continue
		if item["state"] == "lodged":
			continue
		if item["state"] != "thrown":
			pickup_items[index] = item
			continue

		var velocity_value: Vector2 = item["velocity"]
		var position_value: Vector2 = item["position"]
		velocity_value.y += GRAVITY * delta
		position_value += velocity_value * delta
		item["velocity"] = velocity_value
		item["position"] = position_value

		if spout_cooldown <= 0.0 and SPOUT_TARGET.has_point(position_value):
			if item["kind"] == "stone":
				item["state"] = "lodged"
				item["position"] = SPOUT_VISUAL.get_center() + Vector2(0.0, 12.0)
				item["velocity"] = Vector2.ZERO
				water_blocked = true
				lodged_item_index = index
				failure_flash = 0.16
				pickup_items[index] = item
				continue
			var reject_direction: float = -signf(velocity_value.x)
			if is_zero_approx(reject_direction):
				reject_direction = -1.0
			velocity_value = Vector2(reject_direction * 390.0, 175.0)
			item["velocity"] = velocity_value
			item["spout_cooldown"] = 0.42
			spout_reject_time = 0.86
			spout_reject_origin = position_value
			failure_flash = maxf(failure_flash, 0.1)

		var radius: float = item["radius"]
		if velocity_value.y >= 0.0:
			for platform_rect in platform_list:
				var inside_x: bool = (
					position_value.x + radius > platform_rect.position.x
					and position_value.x - radius < platform_rect.end.x
				)
				var crossed_top: bool = (
					position_value.y + radius >= platform_rect.position.y
					and position_value.y + radius - velocity_value.y * delta <= platform_rect.position.y + 4.0
				)
				if inside_x and crossed_top:
					item["position"] = Vector2(position_value.x, platform_rect.position.y - radius)
					item["velocity"] = Vector2(velocity_value.x * 0.34, -absf(velocity_value.y) * 0.18)
					if absf(velocity_value.y) < 130.0:
						item["velocity"] = Vector2.ZERO
						item["state"] = "waiting"
					break

		if item["position"].y > 760.0 or item["position"].x < -80.0 or item["position"].x > 3400.0:
			item["position"] = item["spawn"]
			item["velocity"] = Vector2.ZERO
			item["state"] = "waiting"
		pickup_items[index] = item

func _held_item_position() -> Vector2:
	return player_position + Vector2(PLAYER_SIZE.x * 0.5 + player_facing * 27.0, 24.0)

func _player_in_active_gas() -> bool:
	var player_rect := Rect2(player_position, PLAYER_SIZE)
	for gas_column in _cavern_gas_columns():
		var gas_rect: Rect2 = gas_column["rect"]
		if _gas_active(float(gas_column["phase"])) and player_rect.intersects(gas_rect):
			return true
	return false

func _cavern_gas_columns() -> Array[Dictionary]:
	return [
		{"rect": Rect2(1160.0, 375.0, 48.0, 160.0), "phase": 0.0},
		{"rect": Rect2(1360.0, 365.0, 48.0, 170.0), "phase": 1.35},
		{"rect": Rect2(1510.0, 350.0, 48.0, 160.0), "phase": 2.20},
		{"rect": Rect2(1792.0, 325.0, 48.0, 160.0), "phase": 0.65},
		{"rect": Rect2(1970.0, 325.0, 48.0, 160.0), "phase": 1.85},
		{"rect": Rect2(2110.0, 260.0, 48.0, 160.0), "phase": 2.75},
		{"rect": Rect2(2510.0, 245.0, 48.0, 160.0), "phase": 0.95},
		{"rect": Rect2(2780.0, 265.0, 48.0, 160.0), "phase": 2.05},
	]

func _gas_active(phase: float) -> bool:
	return fmod(elapsed + phase, 3.2) < 0.92

func _gas_warning(phase: float) -> bool:
	var cycle := fmod(elapsed + phase, 3.2)
	return cycle > 2.5

func _shaft_flame_strength(index: int) -> float:
	var cycle := fmod(elapsed + float(index) * 0.47, 3.1)
	if cycle < 1.05:
		return 0.0
	if cycle < 1.45:
		return smoothstep(1.05, 1.45, cycle)
	if cycle < 2.55:
		return 0.86 + sin(elapsed * 9.0 + float(index)) * 0.14
	return 1.0 - smoothstep(2.55, 3.1, cycle)

func _shaft_flame_is_dangerous(index: int) -> bool:
	return _shaft_flame_strength(index) > 0.48

func _cavern_spike_strength(index: int) -> float:
	var cycle := fmod(elapsed + float(index) * 0.71, 3.0)
	if cycle < 0.92:
		return 0.0
	if cycle < 1.28:
		return smoothstep(0.92, 1.28, cycle)
	if cycle < 2.18:
		return 1.0
	return 1.0 - smoothstep(2.18, 2.72, cycle)

func _cavern_spike_is_dangerous(index: int) -> bool:
	return _cavern_spike_strength(index) > 0.5

func _cavern_spike_hit_rect(index: int) -> Rect2:
	var source: Rect2 = CAVERN_SPIKES[index]
	var visible_height: float = source.size.y * _cavern_spike_strength(index)
	return Rect2(
		Vector2(source.position.x, source.end.y - visible_height),
		Vector2(source.size.x, visible_height)
	)

func _fail_and_respawn() -> void:
	player_position = checkpoint_position
	player_velocity = Vector2.ZERO
	on_ground = false
	regular_jump_active = false
	shaft_failure_kind = ""
	shaft_failure_time = 0.0
	cavern_failure_kind = ""
	cavern_failure_time = 0.0
	spout_reject_time = 0.0
	throw_preparing = false
	_set_actor_action(ActorPoseState.ACTION_NONE)
	if room == Room.SURFACE:
		_reset_surface_bat_event()
	if room == Room.SHAFT:
		shaft_entry_phase = ShaftEntryPhase.DONE
		shaft_catch_impact = 0.0
		shaft_exit_armed = false
		shaft_jump_grace = 0.0
		camera_axis = clampf(checkpoint_position.y - 245.0, 0.0, 2050.0)
	if room == Room.CAVERN:
		camera_axis = clampf(checkpoint_position.x - 370.0, 0.0, 2060.0)
	if held_item_index >= 0:
		pickup_items[held_item_index]["state"] = "waiting"
		pickup_items[held_item_index]["position"] = pickup_items[held_item_index]["spawn"]
		held_item_index = -1
	failure_flash = 0.32

func _draw_surface() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.035, 0.038, 0.037, 0.08))
	_draw_surface_weather()
	draw_set_transform(Vector2(0.0, -_surface_render_camera_y()))
	var actor_center := player_position + PLAYER_SIZE * 0.5
	host.draw_soft_cloud(
		self,
		actor_center,
		Vector2(132.0, 156.0),
		Color(0.82, 0.84, 0.83, 0.038)
	)
	_draw_surface_living_silhouettes()
	if on_ground:
		var feet := player_position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y + 2.0)
		var spill_strength := (
			0.048
			+ clampf(absf(player_velocity.x) / 285.0, 0.0, 1.0) * 0.012
		)
		host.draw_soft_cloud(
			self,
			feet,
			Vector2(98.0, 17.0),
			Color(0.68, 0.70, 0.69, spill_strength)
		)
	_draw_surface_player_shadow()
	_draw_surface_campfire(Vector2(1017.0 + float(surface_art.right_shift_x), 375.0))
	draw_set_transform(Vector2.ZERO)

func _draw_surface_distant_atmosphere() -> void:
	var moon_pulse: float = 0.88 + sin(elapsed * 0.42) * 0.08
	_art_soft_cloud(Vector2(278.0, 92.0), Vector2(390.0, 310.0), Color(0.70, 0.82, 1.0, 0.11 * moon_pulse))
	var star_parallax: float = -(player_position.x - 170.0) * 0.012
	for star_index in range(34):
		var star_x: float = fposmod(37.0 + float(star_index) * 91.73 + star_parallax, SCREEN.x - 44.0)
		var star_y: float = 20.0 + fposmod(float(star_index) * 47.19, 205.0)
		if Rect2(995.0, 75.0, 285.0, 360.0).has_point(Vector2(star_x, star_y)):
			continue
		var twinkle: float = 0.38 + 0.34 * pow(sin(elapsed * (0.9 + float(star_index % 5) * 0.17) + float(star_index)), 2.0)
		var radius: float = 0.7 + float(star_index % 3) * 0.45
		draw_circle(Vector2(star_x, star_y), radius, Color(0.83, 0.91, 1.0, twinkle))
	for haze_index in range(8):
		var drift: float = fposmod(float(haze_index) * 245.0 + elapsed * (4.0 + float(haze_index % 3)), 1750.0) - 260.0
		var y: float = 210.0 + float(haze_index % 4) * 92.0 + sin(elapsed * 0.25 + float(haze_index)) * 18.0
		_art_soft_cloud(Vector2(drift, y), Vector2(520.0, 145.0), Color(0.70, 0.76, 0.77, 0.055))
	for tower_light_index in range(4):
		var light_center := Vector2(430.0 + float(tower_light_index) * 155.0, 315.0 + sin(float(tower_light_index) * 2.1) * 42.0)
		var light_alpha: float = 0.07 + sin(elapsed * 1.3 + float(tower_light_index)) * 0.025
		_art_soft_cloud(light_center, Vector2(95.0, 130.0), Color(0.74, 0.79, 0.78, light_alpha))

func _draw_surface_weather() -> void:
	for rain_index in range(72):
		var speed: float = 285.0 + float(rain_index % 5) * 34.0
		var x: float = fposmod(float(rain_index) * 79.37 - elapsed * (48.0 + float(rain_index % 4) * 12.0), SCREEN.x + 120.0) - 60.0
		var y: float = fposmod(float(rain_index) * 137.11 + elapsed * speed, SCREEN.y + 120.0) - 80.0
		var length: float = 13.0 + float(rain_index % 4) * 5.0
		draw_line(Vector2(x, y), Vector2(x - length * 0.22, y + length), Color(0.68, 0.70, 0.69, 0.075 + float(rain_index % 3) * 0.020), 1.0, true)
	for leaf_index in range(15):
		var leaf_age: float = fposmod(elapsed * (0.10 + float(leaf_index % 4) * 0.018) + float(leaf_index) * 0.137, 1.0)
		var leaf_x: float = 1350.0 - leaf_age * 1510.0 + sin(leaf_age * TAU * 2.0 + float(leaf_index)) * 45.0
		var leaf_y: float = 85.0 + float(leaf_index % 5) * 86.0 + sin(leaf_age * TAU + float(leaf_index)) * 34.0
		var leaf_angle: float = elapsed * 2.0 + float(leaf_index)
		var direction := Vector2(cos(leaf_angle), sin(leaf_angle))
		draw_line(Vector2(leaf_x, leaf_y) - direction * 5.0, Vector2(leaf_x, leaf_y) + direction * 5.0, Color(0.018, 0.020, 0.019, 0.58), 3.0, true)

func _draw_surface_living_silhouettes() -> void:
	for moth_index in range(5):
		var phase: float = elapsed * (0.55 + float(moth_index % 3) * 0.13) + float(moth_index) * 1.7
		var center := Vector2(1017.0 + float(surface_art.right_shift_x), 360.0) + Vector2(cos(phase * 1.3) * (38.0 + moth_index * 4.0), sin(phase * 1.9) * (22.0 + moth_index * 2.0))
		var glow: float = 0.45 + sin(phase * 3.0) * 0.25
		_art_soft_cloud(center, Vector2(22.0, 22.0), Color(0.82, 0.83, 0.80, glow * 0.09))
		draw_circle(center, 1.25, Color(0.88, 0.89, 0.86, glow * 0.72))

func _draw_surface_chasm_mist() -> void:
	for fog_layer in range(5):
		var fog_center := Vector2(562.0 + float(fog_layer) * 28.0 + sin(elapsed * 0.22 + fog_layer) * 18.0, 455.0 + float(fog_layer) * 62.0)
		_art_soft_cloud(fog_center, Vector2(285.0 + fog_layer * 35.0, 150.0 + fog_layer * 28.0), Color(0.63, 0.65, 0.64, 0.095 + float(fog_layer) * 0.016))
	for breath_index in range(18):
		var age: float = fposmod(elapsed * (0.08 + float(breath_index % 4) * 0.014) + float(breath_index) * 0.093, 1.0)
		var center := Vector2(
			618.0 + sin(float(breath_index) * 2.7 + elapsed * 0.4) * (18.0 + age * 72.0),
			690.0 - age * 345.0
		)
		var radius: float = 0.8 + age * 2.4
		draw_circle(center, radius, Color(0.66, 0.68, 0.67, sin(age * PI) * 0.075))

func _draw_surface_player_shadow() -> void:
	var ground_y: float = SURFACE_PLATFORMS[0].position.y + 2.0
	var actor_bottom: float = player_position.y + PLAYER_SIZE.y
	var air_height: float = maxf(0.0, ground_y - actor_bottom)
	var proximity: float = 1.0 - clampf(air_height / 170.0, 0.0, 1.0)
	var motion_stretch: float = clampf(absf(player_velocity.x) / 285.0, 0.0, 1.0)
	var shadow_width: float = lerpf(15.0, 46.0 + motion_stretch * 12.0, proximity)
	var desired_x: float = player_position.x + PLAYER_SIZE.x * 0.5 + player_velocity.x * 0.018 + 5.0
	var half_width: float = shadow_width * 0.5
	var shadow_x: float = clampf(desired_x, SURFACE_PLATFORMS[0].position.x + half_width, SURFACE_PLATFORMS[0].end.x - half_width)
	var shadow_center := Vector2(shadow_x, ground_y)
	var shadow_alpha: float = lerpf(0.10, 0.68, proximity)
	_art_soft_cloud(shadow_center, Vector2(shadow_width, lerpf(5.0, 12.0, proximity)), Color(0.0, 0.004, 0.015, shadow_alpha))
	if proximity > 0.72:
		var contact_alpha: float = inverse_lerp(0.72, 1.0, proximity) * 0.62
		_art_soft_cloud(shadow_center - Vector2(3.0, 1.0), Vector2(20.0 + motion_stretch * 5.0, 4.5), Color(0.0, 0.002, 0.008, contact_alpha))

func _draw_surface_campfire(origin: Vector2) -> void:
	var pulse: float = float(surface_art.fire_intensity)
	var flame_drift := Vector2(
		sin(elapsed * 1.85) * 5.0 + sin(elapsed * 4.2 + 0.8) * 1.8,
		sin(elapsed * 2.7 + 1.1) * 2.5
	)
	var breath := 1.0 + sin(elapsed * 2.35 + 0.4) * 0.045
	_art_soft_cloud(
		origin + Vector2(0.0, -30.0) + flame_drift * 0.55,
		Vector2(110.0, 80.0 * breath),
		Color(0.70, 0.71, 0.68, 0.034 * pulse)
	)
	_art_soft_cloud(
		origin + Vector2(0.0, -19.0) + flame_drift * 0.82,
		Vector2(70.0, 54.0 * breath),
		Color(0.82, 0.83, 0.80, 0.055 * pulse)
	)
	_art_soft_cloud(
		origin + Vector2(0.0, -10.0) + flame_drift,
		Vector2(46.0, 40.0 * breath),
		Color(0.95, 0.95, 0.91, 0.060 * pulse)
	)
	_art_soft_cloud(origin + Vector2(0.0, 3.0), Vector2(96.0, 20.0), Color(0.67, 0.68, 0.66, 0.050 * pulse))

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

func _draw_dead_tree(origin: Vector2, scale_factor: float) -> void:
	draw_line(origin, origin + Vector2(8.0, -155.0) * scale_factor, INK, 7.0 * scale_factor, true)
	draw_line(origin + Vector2(5.0, -95.0) * scale_factor, origin + Vector2(-48.0, -137.0) * scale_factor, INK, 5.0 * scale_factor, true)
	draw_line(origin + Vector2(7.0, -126.0) * scale_factor, origin + Vector2(58.0, -166.0) * scale_factor, INK, 5.0 * scale_factor, true)

# The landing on the branch pile: the whole picture jolts, and grit and dust jump off the pile.
func _shaft_shake_y() -> float:
	if shaft_catch_impact <= 0.0:
		return 0.0
	var k := clampf(shaft_catch_impact / 0.65, 0.0, 1.0)
	return sin(elapsed * 72.0) * 9.0 * k * k

# The hooded boy lands as a small figure: a few small puffs off the pile, not big grey clouds around him.
func _dust_scale() -> float:
	return 0.3 if ActorStyleHost.style_override == ActorPoseState.STYLE_HOOD else 1.0

func _spawn_shaft_impact_dust(at: Vector2, power: float) -> void:
	power *= _dust_scale()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 7.0) + int(power * 100.0) + shaft_dust.size()
	for n in range(int(20.0 * power)):
		var side := -1.0 if n % 2 == 0 else 1.0
		shaft_dust.append({
			"pos": at + Vector2(rng.randf_range(-34.0, 34.0) * power, rng.randf_range(-4.0, 2.0)),
			"vel": Vector2(side * rng.randf_range(30.0, 150.0) * power, -rng.randf_range(10.0, 70.0) * power),
			"age": 0.0, "life": rng.randf_range(0.8, 1.5), "size": rng.randf_range(15.0, 34.0) * (0.6 + 0.4 * power),
			"chip": false,
		})
	for n in range(int(12.0 * power)):
		var side2 := -1.0 if n % 2 == 0 else 1.0
		shaft_dust.append({
			"pos": at + Vector2(rng.randf_range(-24.0, 24.0), -2.0),
			"vel": Vector2(side2 * rng.randf_range(20.0, 120.0), -rng.randf_range(90.0, 260.0) * power),
			"age": 0.0, "life": rng.randf_range(0.5, 0.95), "size": rng.randf_range(1.6, 3.4),
			"chip": true,
		})

func _update_shaft_dust(delta: float) -> void:
	var k := shaft_dust.size() - 1
	while k >= 0:
		var d: Dictionary = shaft_dust[k]
		d.age = float(d.age) + delta
		var v: Vector2 = d.vel
		if bool(d.chip):
			v.y += 520.0 * delta
		else:
			v = v.move_toward(Vector2(v.x * 0.4, -14.0), 140.0 * delta)
		d.vel = v
		d.pos = Vector2(d.pos) + v * delta
		if float(d.age) >= float(d.life):
			shaft_dust.remove_at(k)
		k -= 1

func _draw_shaft_dust() -> void:
	for d in shaft_dust:
		var t: float = float(d.age) / float(d.life)
		var at := _world_to_screen(Vector2(d.pos))
		if bool(d.chip):
			draw_circle(at, float(d.size), Color(0.58, 0.58, 0.55, (1.0 - t) * 0.8), true, -1.0, true)
		else:
			var grow := 1.0 + t * 1.3
			var size: float = d.size
			var haze := 1.0 if _dust_scale() >= 1.0 else 0.3
			_art_soft_cloud(at, Vector2(size * 2.0 * grow, size * 1.3 * grow), Color(0.66, 0.67, 0.65, (1.0 - t) * minf(1.0, t * 9.0 + 0.4) * 0.5 * haze))

func _draw_shaft() -> void:
	for platform_index in range(SHAFT_PLATFORMS.size()):
		_draw_shaft_platform(_world_rect_to_screen(SHAFT_PLATFORMS[platform_index]), platform_index)
	for index in range(SHAFT_FLAMES.size()):
		_draw_flame_strip(
			_world_rect_to_screen(SHAFT_FLAMES[index]),
			_shaft_flame_strength(index),
			false
		)
	_draw_shaft_dust()

func _draw_shaft_platform(screen_rect: Rect2, platform_index: int) -> void:
	if screen_rect.end.x < -50.0 or screen_rect.position.x > SCREEN.x + 50.0:
		return
	if screen_rect.end.y < -70.0 or screen_rect.position.y > SCREEN.y + 70.0:
		return
	if platform_index == 0:
		_draw_shaft_catch_branches(screen_rect)
		return
	_draw_shaft_rock_tongue(screen_rect, platform_index)

func _draw_shaft_rock_tongue(rect: Rect2, platform_index: int) -> void:
	var from_left := rect.get_center().x < 640.0
	var variant := float(platform_index % 3)
	var root_lift := 42.0 + variant * 17.0
	var belly_depth := 126.0 + variant * 24.0
	var shoulder_reach := 34.0 + variant * 13.0
	_art_soft_cloud(
		Vector2(rect.get_center().x, rect.position.y - 25.0),
		Vector2(225.0, 155.0),
		Color(0.68, 0.68, 0.68, 0.034)
	)
	var top_points := PackedVector2Array()
	var samples := maxi(4, int(rect.size.x / 20.0))
	for sample_index in range(samples + 1):
		var ratio := float(sample_index) / float(samples)
		var x := lerpf(rect.position.x, rect.end.x, ratio)
		var uneven := sin(float(sample_index) * 2.17 + float(platform_index) * 1.31) * 0.65
		top_points.append(Vector2(x, rect.position.y + uneven))
	var tongue := PackedVector2Array()
	if from_left:
		var root_x := 238.0 + variant * 29.0
		tongue.append(Vector2(root_x, rect.position.y - root_lift))
		tongue.append(Vector2(rect.position.x - shoulder_reach, rect.position.y - 7.0 - variant * 2.0))
		tongue.append_array(top_points)
		tongue.append(Vector2(rect.end.x - 3.0, rect.end.y + 4.0))
		tongue.append(Vector2(rect.position.x + 30.0 - variant * 8.0, rect.end.y + 33.0 + variant * 6.0))
		tongue.append(Vector2(rect.position.x - 52.0 - variant * 15.0, rect.end.y + 82.0 + variant * 15.0))
		tongue.append(Vector2(root_x, rect.end.y + belly_depth))
	else:
		var root_x := 1042.0 - variant * 31.0
		tongue.append_array(top_points)
		tongue.append(Vector2(rect.end.x + shoulder_reach, rect.position.y - 7.0 - variant * 2.0))
		tongue.append(Vector2(root_x, rect.position.y - root_lift))
		tongue.append(Vector2(root_x, rect.end.y + belly_depth))
		tongue.append(Vector2(rect.end.x + 52.0 + variant * 15.0, rect.end.y + 82.0 + variant * 15.0))
		tongue.append(Vector2(rect.position.x + rect.size.x * 0.66 + variant * 8.0, rect.end.y + 33.0 + variant * 6.0))
		tongue.append(Vector2(rect.position.x + 3.0, rect.end.y + 4.0))
	_art_soft_cloud(
		Vector2(rect.get_center().x + (-46.0 if from_left else 46.0), rect.position.y + 55.0),
		Vector2(290.0, 170.0),
		Color(0.0, 0.0, 0.0, 0.48)
	)
	_draw_feathered_ink_shape(tongue, 5.5)

func _draw_shaft_catch_branches(rect: Rect2) -> void:
	var impact_ratio := clampf(shaft_catch_impact / 0.65, 0.0, 1.0)
	var flex := sin((1.0 - impact_ratio) * PI) * 4.0 if shaft_catch_impact > 0.0 else 0.0
	var wall_x := 300.0
	_art_soft_cloud(
		Vector2(rect.get_center().x, rect.position.y - 31.0),
		Vector2(275.0, 175.0),
		Color(0.68, 0.68, 0.68, 0.038)
	)
	var trunk := PackedVector2Array([
		Vector2(wall_x, rect.position.y + 23.0),
		Vector2(rect.position.x + 31.0, rect.position.y + 16.0 + flex),
		Vector2(rect.position.x + 88.0, rect.position.y + 20.0 + flex * 0.7),
		Vector2(rect.end.x - 7.0, rect.position.y + 10.0 + flex * 0.4),
	])
	draw_polyline(trunk, Color(0.0, 0.0, 0.0, 0.16), 31.0, true)
	draw_polyline(trunk, Color("010202"), 20.0, true)

	var mound := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - 7.0, rect.end.y - 4.0 + flex * 0.4),
		Vector2(rect.position.x + 104.0, rect.end.y + 7.0 + flex * 0.7),
		Vector2(rect.position.x + 58.0, rect.end.y + 3.0 + flex),
		Vector2(rect.position.x + 8.0, rect.end.y - 2.0 + flex * 0.6),
	])
	_draw_feathered_ink_shape(mound, 3.6)

	var forks: Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(rect.position.x + 34.0, rect.position.y + 13.0),
			Vector2(rect.position.x + 15.0, rect.position.y - 17.0 - flex),
			Vector2(rect.position.x - 2.0, rect.position.y - 25.0 - flex),
		]),
		PackedVector2Array([
			Vector2(rect.position.x + 91.0, rect.position.y + 14.0),
			Vector2(rect.position.x + 111.0, rect.position.y - 14.0 - flex * 0.6),
			Vector2(rect.position.x + 135.0, rect.position.y - 20.0 - flex * 0.6),
		]),
	]
	for fork in forks:
		draw_polyline(fork, Color(0.0, 0.0, 0.0, 0.18), 11.0, true)
		draw_polyline(fork, Color("010202"), 6.0, true)

func _draw_feathered_ink_shape(points: PackedVector2Array, radius: float) -> void:
	for ring_index in range(3, 0, -1):
		var ring_radius := radius * float(ring_index) / 3.0
		var alpha := 0.020 + float(3 - ring_index) * 0.012
		for sample_index in range(8):
			var angle := float(sample_index) * TAU / 8.0
			var offset := Vector2(cos(angle), sin(angle)) * ring_radius
			var shifted := PackedVector2Array()
			for point in points:
				shifted.append(point + offset)
			draw_colored_polygon(shifted, Color(0.0, 0.0, 0.0, alpha))
	draw_colored_polygon(points, Color("010202"))

func _draw_cavern() -> void:
	_draw_cavern_socket_state()
	for platform_rect in CAVERN_FIXED_PLATFORMS:
		_draw_fixed_cavern_contact(_world_rect_to_screen(platform_rect))
	for dynamic_rect in _cavern_dynamic_platforms(elapsed):
		_draw_moving_platform(_world_rect_to_screen(dynamic_rect))
	for index in range(CAVERN_SPIKES.size()):
		_draw_spike_strip(
			_world_rect_to_screen(CAVERN_SPIKES[index]),
			_cavern_spike_strength(index)
		)
	_draw_water_system()
	_draw_gas_system()
	_draw_cavern_mid_checkpoint()
	_draw_cable()
	_draw_lift()
	_draw_pickup_items()

func _draw_cavern_socket_state() -> void:
	var mouth := _world_rect_to_screen(SPOUT_TARGET).get_center()
	if mouth.x < -80.0 or mouth.x > SCREEN.x + 80.0:
		return
	_art_soft_cloud(mouth, Vector2(138.0, 126.0), Color(0.62, 0.62, 0.60, 0.065))
	draw_circle(mouth, 46.0, Color(0.20, 0.20, 0.195, 0.72))
	draw_circle(mouth, 35.0, Color("08090a"))
	if water_blocked:
		draw_circle(mouth, 28.0, Color("020303"))


func _draw_fixed_cavern_contact(screen_rect: Rect2) -> void:
	if screen_rect.end.x < -20.0 or screen_rect.position.x > SCREEN.x + 20.0:
		return
	# Generated art supplies all visible platform mass. This narrow contact band
	# only guarantees that the authored image meets the unchanged collision top.
	_art_soft_cloud(
		Vector2(screen_rect.get_center().x, screen_rect.position.y + 4.0),
		Vector2(screen_rect.size.x + 18.0, 20.0),
		Color(0.0, 0.0, 0.0, 0.34)
	)
	var contact := PackedVector2Array([
		screen_rect.position + Vector2(-1.0, 0.0),
		Vector2(screen_rect.end.x + 1.0, screen_rect.position.y),
		Vector2(screen_rect.end.x - 3.0, screen_rect.position.y + 9.0),
		Vector2(screen_rect.position.x + screen_rect.size.x * 0.62, screen_rect.position.y + 15.0),
		Vector2(screen_rect.position.x + screen_rect.size.x * 0.37, screen_rect.position.y + 12.0),
		Vector2(screen_rect.position.x + 3.0, screen_rect.position.y + 8.0),
	])
	draw_colored_polygon(contact, Color("010202"))


func _draw_cavern_mid_checkpoint() -> void:
	var center := _world_to_screen(Vector2(1734.0, 382.0))
	var platform_top := _world_to_screen(Vector2(1734.0, 415.0))
	draw_line(center + Vector2(0.0, 12.0), platform_top, Color("050607"), 4.0, true)
	draw_rect(Rect2(center + Vector2(-7.0, -9.0), Vector2(14.0, 20.0)), Color("050607"))
	if cavern_mid_checkpoint_active:
		var flicker := 0.88 + sin(elapsed * 2.2) * 0.045
		_art_soft_cloud(center, Vector2(88.0, 76.0), Color(0.72, 0.72, 0.69, 0.09 * flicker))
		draw_circle(center + Vector2(0.0, 1.0), 3.6, Color(0.82, 0.82, 0.79, flicker))
	else:
		draw_circle(center + Vector2(0.0, 1.0), 3.0, Color("2d2e2f"))

func _draw_water_system() -> void:
	if water_blocked:
		return
	var curtain: Rect2 = _world_rect_to_screen(WATER_CURTAIN)
	_art_soft_cloud(curtain.get_center(), Vector2(curtain.size.x * 1.34, curtain.size.y * 1.08), Color(0.62, 0.62, 0.60, 0.075))
	_art_soft_cloud(curtain.get_center() + Vector2(-8.0, 12.0), Vector2(curtain.size.x * 0.92, curtain.size.y), Color(0.70, 0.70, 0.68, 0.055))
	for drop in range(28):
		var age: float = fposmod(elapsed*1.55+drop*0.147,1.0)
		var start: Vector2 = Vector2(curtain.get_center().x+sin(drop*4.3)*45.0,607.0)
		var velocity: Vector2 = Vector2(sin(drop*3.4)*43.0,-27.0-fposmod(drop*19.0,44.0))
		var point: Vector2 = start+velocity*age+Vector2(0,58.0*age*age)
		draw_line(point,point-Vector2(0,1.8),Color(0.66,0.66,0.64,(1.0-age)*0.26),0.8,true)
	for i in range(16):
		var age: float = fposmod(elapsed*0.7+i*0.173,1.0)
		var side: float = -1.0 if i%2 == 0 else 1.0
		var center: Vector2 = Vector2(curtain.get_center().x+side*(12.0+age*87.0),609.0+sin(i*3.1)*3.0+age*7.0)
		draw_line(center-Vector2(2+age*4,0),center+Vector2(2+age*4,0),Color(0.62,0.62,0.60,(1-age)*0.18),1.0,true)
	_draw_waterfall_mist(curtain)

func _draw_waterfall_mist(curtain: Rect2) -> void:
	var impact: Vector2 = Vector2(curtain.get_center().x,608.0)
	# Several soft moving volumes connect the falling water to the river.
	for i in range(9):
		var age: float = fposmod(elapsed*0.18+i*0.117,1.0)
		var side: float = -1.0 if i%2 == 0 else 1.0
		var point: Vector2 = impact+Vector2(side*(16.0+age*86.0),-8.0-age*(22.0+i%3*7.0))
		var opacity: float = sin(age*PI)*0.085
		_art_soft_cloud(point,Vector2(55,29)*(0.65+age),Color(0.64,0.64,0.62,opacity))
	for i in range(4):
		var phase: float = fposmod(elapsed*0.42+i*0.25,1.0)
		var ring: PackedVector2Array = PackedVector2Array()
		for sample_index in range(19):
			var angle: float = float(sample_index)*PI/18.0
			ring.append(impact+Vector2(cos(angle)*(15.0+phase*92.0),sin(angle)*(2.0+phase*7.0)+phase*7.0))
		draw_polyline(ring,Color(0.64,0.64,0.62,(1.0-phase)*0.14),1.0,true)
	_art_soft_cloud(impact+Vector2(0,-9),Vector2(170,54),Color(0.66,0.66,0.64,0.11))

func _draw_spout_reject_effect() -> void:
	var progress: float = 1.0 - spout_reject_time / 0.86
	var origin: Vector2 = _world_to_screen(spout_reject_origin)
	var alpha: float = clampf(1.0 - progress, 0.0, 1.0)
	var ring_radius: float = lerpf(12.0, 58.0, progress)
	draw_arc(origin, ring_radius, 0.0, TAU, 28, Color(0.74, 0.74, 0.72, alpha), 4.0, true)
	for drop_index in range(8):
		var angle: float = -PI * 0.82 + float(drop_index) * PI * 0.23
		var distance: float = 18.0 + progress * (24.0 + float(drop_index % 3) * 7.0)
		var drop_end: Vector2 = origin + Vector2(cos(angle), sin(angle)) * distance
		draw_line(origin, drop_end, Color(0.62, 0.62, 0.60, alpha), 3.0, true)
	draw_line(origin + Vector2(-10.0, -10.0), origin + Vector2(10.0, 10.0), Color(INK, alpha), 3.0, true)
	draw_line(origin + Vector2(10.0, -10.0), origin + Vector2(-10.0, 10.0), Color(INK, alpha), 3.0, true)
	draw_string(
		ui_font,
		origin + Vector2(-29.0, -52.0),
		"卡不住",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color(INK, alpha)
	)

func _draw_gas_system() -> void:
	for gas_column in _cavern_gas_columns():
		var world_rect: Rect2 = gas_column["rect"]
		var vent_center := _world_to_screen(Vector2(world_rect.get_center().x, world_rect.end.y))
		var crack := PackedVector2Array([
			vent_center + Vector2(-18.0, 1.0),
			vent_center + Vector2(-7.0, -5.0),
			vent_center + Vector2(2.0, -1.0),
			vent_center + Vector2(16.0, -7.0),
		])
		draw_polyline(crack, Color("020303"), 5.0, true)
		if _gas_active(float(gas_column["phase"])):
			var gas_rect := _world_rect_to_screen(world_rect)
			if gas_rect.end.x < -60.0 or gas_rect.position.x > SCREEN.x + 60.0:
				continue
			_art_soft_cloud(vent_center + Vector2(0.0, -6.0), Vector2(58.0, 22.0), Color(0.60, 0.60, 0.58, 0.10))
		elif _gas_warning(float(gas_column["phase"])):
			_art_soft_cloud(vent_center + Vector2(0.0, -8.0), Vector2(22.0, 13.0), Color(0.54, 0.54, 0.52, 0.08))

func _draw_cable() -> void:
	var cable_start := _world_to_screen(Vector2(2450.0, 305.0))
	var cable_end := _world_to_screen(Vector2(3020.0, 215.0))
	var cable := PackedVector2Array()
	for sample_index in range(17):
		var ratio := float(sample_index) / 16.0
		var point := cable_start.lerp(cable_end, ratio)
		point.y += sin(ratio * PI) * 34.0
		cable.append(point)
	draw_polyline(cable, Color("050607"), 3.0, true)

func _draw_lift() -> void:
	var lift_offset := Vector2(0.0, -lift_time * 238.0)
	var left_rail_top := _world_to_screen(Vector2(3148.0, 88.0))
	var left_rail_bottom := _world_to_screen(Vector2(3148.0, 430.0))
	var right_rail_top := _world_to_screen(Vector2(3232.0, 88.0))
	var right_rail_bottom := _world_to_screen(Vector2(3232.0, 430.0))
	draw_line(left_rail_top, left_rail_bottom, Color("050607"), 4.0, true)
	draw_line(right_rail_top, right_rail_bottom, Color("050607"), 4.0, true)

	var lift_rect := _world_rect_to_screen(LIFT_PLATFORM)
	lift_rect.position += lift_offset
	_art_soft_cloud(lift_rect.get_center() + Vector2(0.0, 8.0), Vector2(lift_rect.size.x + 24.0, 38.0), Color(0.0, 0.0, 0.0, 0.44))
	var lift_body := PackedVector2Array([
		lift_rect.position,
		Vector2(lift_rect.end.x, lift_rect.position.y),
		Vector2(lift_rect.end.x - 5.0, lift_rect.end.y + 7.0),
		Vector2(lift_rect.get_center().x + 19.0, lift_rect.end.y + 13.0),
		Vector2(lift_rect.position.x + 6.0, lift_rect.end.y + 6.0),
	])
	draw_colored_polygon(lift_body, Color("010202"))
	draw_line(lift_rect.position + Vector2(14.0, 0.0), left_rail_top, Color("050607"), 2.0, true)
	draw_line(lift_rect.end - Vector2(14.0, lift_rect.size.y), right_rail_top, Color("050607"), 2.0, true)

	var lever_base := lift_rect.position + Vector2(23.0, -2.0)
	draw_rect(Rect2(lever_base + Vector2(-11.0, -8.0), Vector2(22.0, 8.0)), Color("040505"))
	var lever_tip := lever_base + (Vector2(18.0, -30.0) if room == Room.CAVERN else Vector2(-4.0, -34.0))
	draw_line(lever_base, lever_tip, Color("040505"), 4.0, true)
	draw_circle(lever_tip, 5.0, Color("040505"))
	var lantern_center := lift_rect.get_center() + Vector2(33.0, -48.0)
	var lantern_pulse := 0.88 + sin(elapsed * 1.7) * 0.035
	draw_line(lantern_center - Vector2(0.0, 24.0), lantern_center - Vector2(0.0, 7.0), Color("050607"), 2.0, true)
	_art_soft_cloud(lantern_center, Vector2(82.0, 82.0), Color(0.70, 0.70, 0.67, 0.09 * lantern_pulse))
	draw_circle(lantern_center, 3.5, Color(0.82, 0.82, 0.78, lantern_pulse))
	if water_blocked and room == Room.CAVERN:
		_draw_key_prompt(lift_rect.get_center() + Vector2(0.0, -70.0), "F", "拉动摇杆")

func _draw_pickup_items() -> void:
	for index in range(pickup_items.size()):
		if index == held_item_index:
			continue
		var item: Dictionary = pickup_items[index]
		var position_value: Vector2 = _world_to_screen(item["position"])
		_draw_pickup(position_value, item["kind"], item["radius"])
	if held_item_index >= 0:
		var held_item: Dictionary = pickup_items[held_item_index]
		if throw_preparing:
			_draw_throw_preview()
	else:
		var nearest := _nearest_pickup_index()
		if nearest >= 0:
			var prompt_position: Vector2 = _world_to_screen(pickup_items[nearest]["position"]) + Vector2(0.0, -42.0)
			_draw_key_prompt(prompt_position, "F", "拾取")

func _draw_pickup(center: Vector2, kind: String, radius: float) -> void:
	match kind:
		"stone":
			var points := PackedVector2Array([
				center + Vector2(-radius, 4.0), center + Vector2(-8.0, -radius),
				center + Vector2(9.0, -radius + 3.0), center + Vector2(radius, 6.0),
				center + Vector2(5.0, radius), center + Vector2(-10.0, radius - 2.0),
			])
			draw_polygon(points, PackedColorArray([Color("111214")]))
		"wood":
			draw_line(center + Vector2(-radius, 7.0), center + Vector2(radius, -7.0), Color("0a0b0c"), 7.0, true)
		_:
			var scrap := PackedVector2Array([
				center + Vector2(-radius, radius * 0.55),
				center + Vector2(-radius * 0.72, -radius * 0.55),
				center + Vector2(radius * 0.86, -radius * 0.35),
				center + Vector2(radius, radius * 0.62),
			])
			draw_colored_polygon(scrap, Color("151618"))

func _nearest_pickup_index() -> int:
	var nearest := -1
	var nearest_distance := 68.0
	var center := player_position + PLAYER_SIZE * 0.5
	for index in range(pickup_items.size()):
		var item: Dictionary = pickup_items[index]
		if item["state"] != "waiting":
			continue
		var distance: float = center.distance_to(item["position"])
		if distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	return nearest

func _draw_throw_preview() -> void:
	var ratio: float = clampf((throw_hold_time - THROW_HOLD_THRESHOLD) / 0.82, 0.0, 1.0)
	var strength: float = lerpf(THROW_MIN_SPEED, THROW_MAX_SPEED, ratio)
	var direction: Vector2 = Vector2(player_facing * cos(throw_angle), sin(throw_angle)).normalized()
	var start: Vector2 = _held_item_position()
	var preview_points := PackedVector2Array()
	var hits_visible_socket := false
	for sample_index in range(1, 73):
		var sample_time: float = float(sample_index) / 60.0
		var world_point: Vector2 = start + direction * strength * sample_time + Vector2(0.0, GRAVITY * sample_time * sample_time * 0.5)
		preview_points.append(_world_to_screen(world_point))
		if SPOUT_TARGET.has_point(world_point):
			hits_visible_socket = true
			break
		if world_point.y > 735.0 or world_point.x < -40.0 or world_point.x > 3420.0:
			break
	if preview_points.size() < 2:
		return
	draw_polyline(preview_points, Color(INK, 0.2 + ratio * 0.26), 1.5, true)
	for dot_index in range(3, preview_points.size(), 4):
		draw_circle(preview_points[dot_index], 2.5, Color(INK, 0.5 + ratio * 0.4))
	if hits_visible_socket:
		var hit_point: Vector2 = preview_points[preview_points.size() - 1]
		draw_circle(hit_point, 7.0, Color(0.72, 0.72, 0.70, 0.86), false, 2.0, true)

func _draw_moving_platform(screen_rect: Rect2) -> void:
	if room == Room.CAVERN or room == Room.LEVEL_01_LIFT:
		var world_center_x := screen_rect.get_center().x + camera_axis
		_art_soft_cloud(
			screen_rect.get_center() + Vector2(0.0, 8.0),
			Vector2(screen_rect.size.x + 24.0, 38.0),
			Color(0.0, 0.0, 0.0, 0.42)
		)
		var body := PackedVector2Array([
			screen_rect.position,
			Vector2(screen_rect.end.x, screen_rect.position.y),
		])
		if world_center_x > 2400.0:
			var hanger_top := screen_rect.get_center() + Vector2(0.0, -48.0)
			draw_line(hanger_top, screen_rect.get_center() - Vector2(0.0, screen_rect.size.y * 0.5), Color("050607"), 3.0, true)
			draw_circle(hanger_top, 4.0, Color("050607"))
			body.append(Vector2(screen_rect.end.x - 8.0, screen_rect.end.y + 7.0))
			body.append(Vector2(screen_rect.get_center().x + 15.0, screen_rect.end.y + 13.0))
			body.append(Vector2(screen_rect.position.x + 8.0, screen_rect.end.y + 5.0))
		elif world_center_x < 900.0:
			body.append(Vector2(screen_rect.end.x - 5.0, screen_rect.end.y + 8.0))
			body.append(Vector2(screen_rect.get_center().x + 18.0, screen_rect.end.y + 25.0))
			body.append(Vector2(screen_rect.get_center().x - 27.0, screen_rect.end.y + 19.0))
			body.append(Vector2(screen_rect.position.x + 4.0, screen_rect.end.y + 6.0))
		elif world_center_x < 1900.0:
			body.append(Vector2(screen_rect.end.x - 3.0, screen_rect.end.y + 5.0))
			body.append(Vector2(screen_rect.get_center().x + 5.0, screen_rect.end.y + 31.0))
			body.append(Vector2(screen_rect.position.x + 4.0, screen_rect.end.y + 9.0))
		else:
			body.append(Vector2(screen_rect.end.x - 4.0, screen_rect.end.y + 14.0))
			body.append(Vector2(screen_rect.get_center().x + 7.0, screen_rect.end.y + 39.0))
			body.append(Vector2(screen_rect.get_center().x - 13.0, screen_rect.end.y + 29.0))
			body.append(Vector2(screen_rect.position.x + 3.0, screen_rect.end.y + 10.0))
		draw_colored_polygon(body, Color("010202"))
		return

func _draw_flame_strip(screen_rect: Rect2, strength: float, always_hot: bool) -> void:
	if screen_rect.end.y < -40.0 or screen_rect.position.y > SCREEN.y + 40.0:
		return
	var base: Vector2 = Vector2(screen_rect.position.x, screen_rect.end.y)
	var basin := PackedVector2Array([
		base + Vector2(4.0, -1.0),
		Vector2(screen_rect.end.x - 4.0, screen_rect.end.y - 1.0),
		Vector2(screen_rect.end.x - 10.0, screen_rect.end.y + 8.0),
		base + Vector2(10.0, 8.0),
	])
	draw_colored_polygon(basin, Color("010202"))
	var visible_strength: float = clampf(maxf(0.1 if always_hot else 0.0, strength), 0.0, 1.0)
	if visible_strength <= 0.02:
		return
	# The flame itself is an InkFlame node; here the bed it burns on: a few live coals.
	var pulse: float = visible_strength * (0.9 + 0.1 * sin(elapsed * 13.0))
	for coal_index in range(3):
		var coal_x := lerpf(screen_rect.position.x + 13.0, screen_rect.end.x - 13.0, float(coal_index) / 2.0)
		draw_circle(Vector2(coal_x, screen_rect.end.y + 1.0), 1.7, Color(0.80, 0.80, 0.78, 0.50 * pulse), true, -1.0, true)

func _draw_spike_strip(screen_rect: Rect2, strength: float) -> void:
	var visible_strength: float = clampf(strength,0.0,1.0)
	var count: int = maxi(2,int(screen_rect.size.x/13.0))
	var width: float = screen_rect.size.x/float(count)
	var base_y: float = screen_rect.end.y
	draw_line(Vector2(screen_rect.position.x,base_y+1),screen_rect.end+Vector2(0,1),Color("020303"),5.0,true)
	for i in range(count):
		var left: float = screen_rect.position.x+i*width
		var height: float = screen_rect.size.y*visible_strength
		var tip: Vector2 = Vector2(left+width*(0.48+0.06*sin(i*2.4)),base_y-height)
		var base_left: Vector2 = Vector2(left+0.6,base_y)
		var base_right: Vector2 = Vector2(left+width-0.6,base_y)
		if visible_strength < 0.02:
			continue
		draw_colored_polygon(PackedVector2Array([base_left, tip, base_right]), Color("020303"))

func _draw_shaft_failure_effect() -> void:
	var player_center := _world_to_screen(player_position + PLAYER_SIZE * 0.5)
	if shaft_failure_kind == "fire":
		var t: float = shaft_failure_time
		var source: Vector2 = _world_to_screen(shaft_failure_origin)
		_art_soft_cloud(source, Vector2(54,35), Color(1.0,0.70,0.28, maxf(0.0,1.0-t/0.13)*0.85))
		for spark_index in range(17):
			var speed: Vector2 = Vector2(sin(spark_index * 7.19) * 130.0, -65.0 - fposmod(spark_index * 37.0,145.0))
			var point: Vector2 = source + speed * t + Vector2(0,160.0*t*t)
			var alpha: float = maxf(0.0,1.0-t/(0.30+spark_index*0.021))
			draw_line(point, point - (speed + Vector2(0,320*t)).normalized()*3.4, Color(1.0,0.61,0.16,alpha),1.5,true)
		for puff in range(4):
			var soot: Vector2 = player_center + Vector2(sin(puff*4.1+t*3.0)*12.0,-t*35.0-puff*6.0)
			_art_soft_cloud(soot, Vector2(12,19)*(1.0+t), Color(0.18,0.17,0.15,maxf(0.0,0.3-t*0.3)))
	# A fall has no effect of its own: no panic lines, only the actor's fall frames.

func _draw_cavern_failure_effect() -> void:
	var player_center: Vector2 = _world_to_screen(player_position + PLAYER_SIZE * 0.5)
	var progress: float = clampf(cavern_failure_time / 0.76, 0.0, 1.0)
	var alpha: float = clampf(1.0 - progress, 0.0, 1.0)
	if cavern_failure_kind == "gas":
		for puff_index in range(9):
			var angle: float = float(puff_index) * TAU / 9.0 + elapsed * 1.2
			var radius: float = 19.0 + progress * 24.0 + float(puff_index % 3) * 5.0
			var puff_center: Vector2 = player_center + Vector2(cos(angle), sin(angle)) * radius
			var puff_size: float = 7.0 + float(puff_index % 2) * 3.0
			draw_circle(puff_center, puff_size, Color(0.52, 0.52, 0.50, alpha * 0.34))
			draw_circle(puff_center, puff_size, Color(0.68, 0.68, 0.66, alpha), false, 2.0, true)
		draw_circle(player_center, 27.0 + sin(elapsed * 17.0) * 3.0, Color(0.68, 0.68, 0.66, alpha), false, 4.0, true)
		draw_string(
			ui_font,
			player_center + Vector2(-43.0, -53.0),
			"中毒 · 失衡",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			15,
			Color(0.72, 0.72, 0.70, alpha)
		)
		return

	var source: Vector2 = _world_to_screen(cavern_failure_origin)
	var ring_radius: float = lerpf(9.0, 54.0, minf(progress * 1.8, 1.0))
	draw_arc(source, ring_radius, 0.0, TAU, 28, Color(INK, alpha), 4.0, true)
	for slash_index in range(6):
		var slash_angle: float = -0.9 + float(slash_index) * 0.36
		var slash_start: Vector2 = player_center + Vector2(cos(slash_angle), sin(slash_angle)) * 13.0
		var slash_end: Vector2 = player_center + Vector2(cos(slash_angle), sin(slash_angle)) * (32.0 + progress * 18.0)
		draw_line(slash_start, slash_end, Color(INK, alpha), 3.0, true)
	draw_string(
		ui_font,
		player_center + Vector2(-43.0, -53.0),
		"刺伤 · 失衡",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		15,
		Color(INK, alpha)
	)

func _draw_key_prompt(center: Vector2, key: String, label: String) -> void:
	draw_circle(center, 17.0, PAPER)
	draw_circle(center, 17.0, INK, false, 2.0, true)
	var key_size := ui_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15)
	draw_string(ui_font, center - key_size * 0.5 + Vector2(0.0, key_size.y * 0.72), key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, INK)
	var label_size := ui_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13)
	draw_string(ui_font, center + Vector2(-label_size.x * 0.5, 37.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(INK, 0.7))

func _draw_label(position_value: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(ui_font, position_value, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
