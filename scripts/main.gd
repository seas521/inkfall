extends Node2D

const GameContext = preload("res://scripts/core/game_context.gd")
const PlayerController = preload("res://scripts/core/player_controller.gd")
const Palette = preload("res://scripts/shared/inkfall_palette.gd")
const LandmarkArt = preload("res://scripts/shared/landmark_art.gd")
const Level01Controller = preload("res://scripts/levels/level_01_controller.gd")
const Level02Controller = preload("res://scripts/levels/level_02_controller.gd")
const Level03Controller = preload("res://scripts/levels/level_03_controller.gd")
const CinematicDepthDemoController = preload("res://scripts/demos/cinematic_depth_demo_controller.gd")
const ACTOR_STYLE_HOST = preload("res://scripts/actors/actor_style_host.gd")
const ENV_FX = preload("res://scripts/inkfall_env_fx.gd")
const CAVERN_FOREGROUND_ART = preload("res://scripts/art/cavern_limbo_foreground_art.gd")
const SCREEN := Palette.SCREEN
const PLAYER_SIZE := Palette.PLAYER_SIZE
const INK := Palette.INK
const PAPER := Palette.PAPER
const MARSH_DEBUG_INDEX := 4
const CLIFF_DEBUG_INDEX := 5
const MAX_DEBUG_INDEX := 5
const DEBUG_RETURN_META := &"inkfall_debug_return"
const RiverTransition = preload("res://scripts/levels/level01_river_transition.gd")
const FilmLook = preload("res://scripts/effects/film_look.gd")

@export_category("DEBUG")
@export_enum("运行时关卡菜单", "1-01 · 墨坠井", "1-02 · 风化绳崖", "1-03 · 月炉木屋与根下旧矿", "原创场景 · 沉钟雾谷", "C区第二幕 · 枯枝瘴沼", "C区第三幕 · 断桥与升降梯")
var debug_start_level: int = 0

var game_context = GameContext.new()
var ui_font: Font
var debug_selector_open := true
var debug_selection := 0
var art_actor: Node2D
var env_fx: Node2D
var cavern_foreground: Node2D
var art_mist_texture: GradientTexture2D
var level_controllers: Array[Node2D] = []
var active_controller: Node2D
var river: Node2D
var river_transition: CanvasLayer

func _ready() -> void:
	ui_font = ThemeDB.fallback_font
	FilmLook.attach(self)
	level_controllers = [Level01Controller.new(), Level02Controller.new(), Level03Controller.new(), CinematicDepthDemoController.new()]
	for controller in level_controllers:
		add_child(controller)
		controller.hide()
	level_controllers[0].completed.connect(func(): _activate_level(1))
	level_controllers[0].river_requested.connect(_begin_river_transition)
	level_controllers[1].completed.connect(func(): _activate_level(2))
	env_fx = ENV_FX.new(); add_child(env_fx)
	art_actor = ACTOR_STYLE_HOST.new(); add_child(art_actor)
	cavern_foreground = CAVERN_FOREGROUND_ART.new(); add_child(cavern_foreground)
	if get_tree().has_meta(DEBUG_RETURN_META):
		debug_selection = clampi(int(get_tree().get_meta(DEBUG_RETURN_META)), 0, MAX_DEBUG_INDEX)
		get_tree().remove_meta(DEBUG_RETURN_META)
	elif debug_start_level > 0:
		debug_selection = debug_start_level - 1
		_start_debug_level()
	queue_redraw()

func _physics_process(delta: float) -> void:
	env_fx.call("begin_frame")
	if debug_selector_open:
		art_actor.hide()
		cavern_foreground.hide()
		if Input.is_action_just_pressed("ui_up"): debug_selection = maxi(0, debug_selection - 1)
		if Input.is_action_just_pressed("ui_down"): debug_selection = mini(MAX_DEBUG_INDEX, debug_selection + 1)
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"): _start_debug_level()
		queue_redraw(); return
	if Input.is_action_just_pressed("ui_cancel"):
		_show_debug_selector(); return
	if river_transition != null:
		_tick_river_transition(delta)
		return
	if river != null:
		if Input.is_action_just_pressed("restart"):
			river.restore_checkpoint()
		return
	if Input.is_action_just_pressed("restart"):
		if active_controller.has_method("restart_current"):
			active_controller.restart_current()
		else:
			active_controller.reset()
	active_controller.physics_tick(delta)
	_present_controller(delta)

func _present_controller(delta: float) -> void:
	active_controller.sync_environment(env_fx)
	var state: Dictionary = active_controller.presentation_state()
	art_actor.z_index = int(state.get("actor_z_index", 0))
	if state.get("active", true):
		art_actor.call("present", delta, state)
	else: art_actor.hide()
	cavern_foreground.call("sync", delta, float(state.get("camera_axis", 0.0)), bool(state.get("cavern_foreground", false)))

func _show_debug_selector() -> void:
	_clear_river()
	debug_selector_open = true
	if active_controller != null: active_controller.leave()
	active_controller = null
	art_actor.hide()
	cavern_foreground.hide()
	queue_redraw()

func _start_debug_level() -> void:
	debug_selector_open = false
	_activate_level(debug_selection)

func _activate_level(index: int) -> void:
	_clear_river()
	if active_controller != null: active_controller.leave()
	var controller_index := index
	if index == 3:
		controller_index = 3
	elif index == MARSH_DEBUG_INDEX or index == CLIFF_DEBUG_INDEX:
		controller_index = 0
	active_controller = level_controllers[controller_index]
	active_controller.enter(game_context, ui_font, self)
	if index == MARSH_DEBUG_INDEX:
		_mount_river(false)
		river.debug_enter_marsh_act()
	elif index == CLIFF_DEBUG_INDEX:
		_mount_river(false)
		river.debug_enter_cliff_act()
	queue_redraw()

func _begin_river_transition() -> void:
	if river_transition != null or river != null:
		return
	active_controller.room_intro_time = 0.0
	river_transition = RiverTransition.new()
	add_child(river_transition)

func _tick_river_transition(delta: float) -> void:
	river_transition.advance(delta)
	var time: float = river_transition.elapsed
	if river == null:
		active_controller.physics_tick(delta)
		_present_controller(delta)
		if time >= RiverTransition.COVER_TIME:
			_mount_river(true)
	if river != null:
		var reveal := smoothstep(RiverTransition.REVEAL_TIME, RiverTransition.DURATION, time)
		river.camera.zoom = Vector2.ONE * lerpf(1.08, 1.0, reveal)
		river.camera.offset = Vector2(-36.0,-20.0)*(1.0-reveal)
		river.sound.volume_db = lerpf(-50.0,-29.0,reveal)
	if time >= RiverTransition.DURATION:
		river.cinematic_entry = false
		river_transition.queue_free()
		river_transition = null

func _mount_river(cinematic: bool) -> void:
	active_controller.leave()
	art_actor.hide()
	cavern_foreground.hide()
	env_fx.hide()
	river = load("res://scenes/debug/c_zone_river.tscn").instantiate()
	river.hosted_in_level = true
	add_child(river)
	queue_redraw()
	if cinematic:
		river.cinematic_entry = true
		river.player.position = Vector2(35.0,river.ground_y(48.0)-54.0)
		river.player.velocity = Vector2(260.0,100.0)
		river.intro_time = 1.15
		river.camera_x = 0.0
		river.camera.position = Vector2(640.0,360.0)
		river._present(0.0)

func _clear_river() -> void:
	if river_transition != null:
		river_transition.queue_free()
		river_transition = null
	if river != null:
		river.camera.enabled = false
		river.process_mode = Node.PROCESS_MODE_DISABLED
		river.sound.stop()
		river.hide()
		river.queue_free()
		river = null
		get_viewport().canvas_transform = Transform2D.IDENTITY
	env_fx.show()

func update_shared_player(context, delta: float, platforms: Array[Rect2], horizontal_bounds: Vector2, allow_input: bool) -> void:
	PlayerController.update_player(context, delta, platforms, horizontal_bounds, allow_input)

func carry_shared_player(context, previous_rects: Array[Rect2], current_rects: Array[Rect2]) -> void:
	PlayerController.carry_player_with_dynamic_platform(context, previous_rects, current_rects)

func _draw() -> void:
	if river != null:
		return
	draw_rect(Rect2(Vector2.ZERO, SCREEN), PAPER)
	if debug_selector_open: _draw_debug_selector()

func _draw_debug_selector() -> void:
	draw_string(ui_font, Vector2(72.0, 92.0), "INKFALL · DEBUG", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, INK)
	draw_string(ui_font, Vector2(74.0, 128.0), "关卡测试入口", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(INK, 0.58))
	var titles := ["DEBUG · 1-01 · 墨坠井", "DEBUG · 1-02 · 风化绳崖", "DEBUG · 1-03 · 月炉木屋与根下旧矿", "DEMO · 原创场景 · 沉钟雾谷", "DEBUG · C区第二幕 · 枯枝瘴沼", "DEBUG · C区第三幕 · 断桥与升降梯"]
	var details := ["悬崖井口 → 火焰竖井 → 雾岸渡水 → 枯枝瘴沼", "双崖上层 → 滚石收绳 → 架绳攀爬 → 盾行山洞 → 对岸木屋", "木屋求救声 → 三相结界 → 坠入旧矿 → 绳索与十字镐 → 营救魔法师", "独立场景 → 多平面视差 → 电影景深 → 自由移动", "高台木箱 → 大树秋千 → 毒气石柱 → 落石与喷火", "投石砸断吊桥绳 → 过桥 → 带石上升降梯 → 砸断配重绳 → 升上悬崖"]
	for index in titles.size():
		var rect := Rect2(72.0, 145.0 + float(index) * 78.0, 1040.0, 68.0)
		var selected := index == debug_selection
		draw_rect(rect, INK if selected else PAPER); draw_rect(rect, INK, false, 3.0)
		draw_string(ui_font, rect.position + Vector2(32.0, 29.0), titles[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, PAPER if selected else INK)
		draw_string(ui_font, rect.position + Vector2(32.0, 55.0), details[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(PAPER, 0.7) if selected else Color(INK, 0.62))
	draw_string(ui_font, Vector2(74.0, 645.0), "↑ ↓ 选择　Enter / F 进入测试", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, INK)
	draw_string(ui_font, Vector2(74.0, 686.0), "游戏中按 Esc 返回 DEBUG", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(INK, 0.55))

func draw_soft_cloud(canvas: Node2D, center: Vector2, size: Vector2, tint: Color) -> void:
	if art_mist_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 0.8, 1.0])
		gradient.colors = PackedColorArray([Color(1,1,1,0.8), Color(1,1,1,0.55), Color(1,1,1,0.24), Color(1,1,1,0.06), Color(1,1,1,0)])
		art_mist_texture = GradientTexture2D.new(); art_mist_texture.width = 128; art_mist_texture.height = 128
		art_mist_texture.gradient = gradient; art_mist_texture.fill = GradientTexture2D.FILL_RADIAL
		art_mist_texture.fill_from = Vector2(0.5, 0.5); art_mist_texture.fill_to = Vector2(1.0, 0.5)
	canvas.draw_texture_rect(art_mist_texture, Rect2(center - size * 0.5, size), false, tint)

func draw_actor_shadow(canvas: Node2D, surfaces: Array[Rect2], actor_position: Vector2, axis: float) -> void:
	var feet := actor_position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y)
	var nearest := 181.0; var landing := Rect2()
	for surface in surfaces:
		var distance := surface.position.y - feet.y
		if feet.x >= surface.position.x and feet.x <= surface.end.x and distance >= -3.0 and distance < nearest: nearest = maxf(0.0, distance); landing = surface
	if nearest > 180.0: return
	var ratio := nearest / 180.0; var width := minf(lerpf(27.0, 43.0, ratio), landing.size.x)
	var x := clampf(feet.x, landing.position.x + width * 0.5, landing.end.x - width * 0.5)
	var center := Vector2(x, landing.position.y + 2.5)
	if active_controller.room == 1: center.y -= axis
	elif active_controller.room >= 2: center.x -= axis
	draw_soft_cloud(canvas, center, Vector2(width, lerpf(7.0, 12.0, ratio)), Color(0.015,0.022,0.03,lerpf(0.92,0.08,ratio)))

func draw_shared_hut_forecourt(canvas: Node2D, base: Vector2, scale_factor: float, tree_hits: int, axe_state: String, clock: float, swing: float) -> void:
	LandmarkArt.draw_hut_forecourt(canvas, base, scale_factor, tree_hits, axe_state, clock, swing)
