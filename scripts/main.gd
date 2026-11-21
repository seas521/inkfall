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
# Stable internal IDs retained for existing test tools; public entries are listed below.
const MARSH_DEBUG_INDEX := 1
const CLIFF_DEBUG_INDEX := 2
const FOREST_DEBUG_INDEX := 3
const SCENE1_DEBUG_INDEX := 4
const DESCENT_DEBUG_INDEX := 5
const LOG_BRIDGE_DEBUG_INDEX := 6
const ROPE_LADDER_DEBUG_INDEX := 7
const CLIFF_ENTRY_DEBUG_INDEX := 8
const STATION_DEBUG_INDEX := 9
const SCREE_DEBUG_INDEX := 10
const ROOT_CLIFF_DEBUG_INDEX := 11
const VALLEY_ENTRY_DEBUG_INDEX := 17
const FOG_BAY_DEBUG_INDEX := 18
const MAX_DEBUG_INDEX := 18
# Keep stable launch IDs for stored scenes and old standalone test tools.
# Only these three gameplay entries are exposed in either menu.
const DEBUG_ENTRIES := [
	{"id":SCENE1_DEBUG_INDEX,"title":"第一章 · 完整版","detail":"上方森林 → 悬崖绳梯 → 崖间树枝 → 矿洞 → 谷底森林"},
	{"id":ROPE_LADDER_DEBUG_INDEX,"title":"测试 · 悬崖绳梯","detail":"从绳梯顶部进入；可沿第一章路线继续向下游玩"},
	{"id":VALLEY_ENTRY_DEBUG_INDEX,"title":"测试 · 谷底森林入口","detail":"从矿洞出口进入谷底森林；保留矿洞与森林的往返衔接"},
	{"id":FOG_BAY_DEBUG_INDEX,"title":"测试 · 雾湾行船与绳梯","detail":"浅滩上船 → 挥扇渡水 → 跳抓旧绳梯上岸；Esc 返回菜单"},
]
const CHAPTER_ROUTE := "res://scenes/chapters/chapter_01_route.tscn"
const DEBUG_RETURN_META := &"inkfall_debug_return"
const RiverTransition = preload("res://scripts/levels/level01_river_transition.gd")
const FilmLook = preload("res://scripts/effects/film_look.gd")

@export_category("DEBUG")
@export_enum("运行时关卡菜单:0", "第一章 · 完整版:5", "测试 · 悬崖绳梯:8", "测试 · 谷底森林入口:18", "测试 · 雾湾行船与绳梯:19")
var debug_start_level: int = 0

var game_context = GameContext.new()
var ui_font: Font
var debug_selector_open := true
var debug_selection := SCENE1_DEBUG_INDEX
var menu_layer:CanvasLayer
var menu_canvas:Node2D
var art_actor: Node2D
var env_fx: Node2D
var cavern_foreground: Node2D
var art_mist_texture: GradientTexture2D
var level_controllers: Array[Node2D] = []
var active_controller: Node2D
var river: Node2D
var river_transition: CanvasLayer
var last_window_size := Vector2i.ZERO
var resize_revision := 0

func _ready() -> void:
	ui_font = ThemeDB.fallback_font
	FilmLook.attach(self)
	last_window_size = get_window().size
	get_window().size_changed.connect(_on_window_size_changed)
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
	# Menu labels live above the film pass: gameplay keeps its approved blur,
	# while the launcher stays readable during repeated test launches.
	menu_layer=CanvasLayer.new();menu_layer.layer=101;add_child(menu_layer)
	menu_canvas=Node2D.new();menu_canvas.draw.connect(func():_draw_debug_selector(menu_canvas))
	menu_layer.add_child(menu_canvas)
	if get_tree().has_meta(DEBUG_RETURN_META):
		debug_selection = _menu_selection(int(get_tree().get_meta(DEBUG_RETURN_META)))
		get_tree().remove_meta(DEBUG_RETURN_META)
	elif debug_start_level > 0:
		debug_selection = _menu_selection(debug_start_level - 1)
		_start_debug_level()
	queue_redraw()

func _on_window_size_changed() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	resize_revision += 1
	var revision := resize_revision
	get_tree().create_timer(0.16).timeout.connect(func() -> void:
		if revision == resize_revision:
			_keep_window_aspect()
	)

func _keep_window_aspect() -> void:
	var current := DisplayServer.window_get_size()
	if current.y <= 0 or absf(float(current.x) / float(current.y) - 16.0 / 9.0) < 0.01:
		last_window_size = current
		return
	var target := current
	if absi(current.x - last_window_size.x) >= absi(current.y - last_window_size.y):
		target.y = roundi(float(current.x) * 9.0 / 16.0)
	else:
		target.x = roundi(float(current.y) * 16.0 / 9.0)
	last_window_size = target
	DisplayServer.window_set_size(target)

func _physics_process(delta: float) -> void:
	env_fx.call("begin_frame")
	if debug_selector_open:
		art_actor.hide()
		cavern_foreground.hide()
		if Input.is_action_just_pressed("ui_up"): _move_menu_selection(-1)
		if Input.is_action_just_pressed("ui_down"): _move_menu_selection(1)
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"): _start_debug_level()
		menu_canvas.queue_redraw();queue_redraw(); return
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

func _menu_selection(value:int)->int:
	for entry in DEBUG_ENTRIES:
		if entry.id==value:return value
	return SCENE1_DEBUG_INDEX

func _move_menu_selection(direction:int)->void:
	var row:=0
	for i in DEBUG_ENTRIES.size():
		if DEBUG_ENTRIES[i].id==debug_selection:row=i;break
	row=clampi(row+direction,0,DEBUG_ENTRIES.size()-1)
	debug_selection=DEBUG_ENTRIES[row].id

func _show_debug_selector() -> void:
	debug_selection=_menu_selection(debug_selection)
	_clear_river()
	debug_selector_open = true
	menu_layer.show();menu_canvas.queue_redraw()
	if active_controller != null: active_controller.leave()
	active_controller = null
	art_actor.hide()
	cavern_foreground.hide()
	queue_redraw()

func _start_debug_level() -> void:
	if debug_selection==FOG_BAY_DEBUG_INDEX:
		get_tree().change_scene_to_file("res://scenes/debug/fog_bay_playable_v91.tscn")
		return
	if debug_selection==12:
		get_tree().change_scene_to_file("res://scenes/demos/mine_art_gallery.tscn")
		return
	debug_selector_open = false
	menu_layer.hide()
	# the menu entries start level 0 (1-01) normally, or level 0's C zone directly at a later act
	_activate_level(0)
	match debug_selection:
		MARSH_DEBUG_INDEX:
			_mount_river(false)
			river.debug_enter_marsh_act()
		CLIFF_DEBUG_INDEX:
			_mount_river(false)
			river.debug_enter_cliff_act()
		FOREST_DEBUG_INDEX:
			_mount_river(false)
			river.debug_enter_forest_act()
		SCENE1_DEBUG_INDEX:
			_mount_river(false,CHAPTER_ROUTE)
		DESCENT_DEBUG_INDEX:
			_mount_river(false)
			river.debug_enter_descent()
		LOG_BRIDGE_DEBUG_INDEX:
			_mount_river(false)
			river.debug_enter_log_bridge()
		ROPE_LADDER_DEBUG_INDEX:
			_mount_river(false,CHAPTER_ROUTE)
			river.debug_enter_rope_ladder(false)
		VALLEY_ENTRY_DEBUG_INDEX:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_valley_test()
		CLIFF_ENTRY_DEBUG_INDEX:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_cliff_test()
		STATION_DEBUG_INDEX:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_station_test()
		SCREE_DEBUG_INDEX:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_scree_test()
		16:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_mine_cart_pair_test()
		15:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_mine_cart_gap_test()
		14:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_mine_shaft_test()
		13:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_root_cliff_test()
			river.bridge_to_c.checkpoint_step=3
			river.bridge_to_c.restore_checkpoint()
		ROOT_CLIFF_DEBUG_INDEX:
			_mount_river(false,CHAPTER_ROUTE)
			river.enter_root_cliff_test()
	queue_redraw()

# `index` is the level controller (0 = 1-01; the others are the earlier prototypes the old progression still reaches)
func _activate_level(index: int) -> void:
	_clear_river()
	if active_controller != null: active_controller.leave()
	active_controller = level_controllers[index]
	active_controller.enter(game_context, ui_font, self)
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
		# Keep the same on-screen player size during the scene transition too.
		river.camera.zoom = Vector2.ONE
		river.camera.offset = Vector2(-36.0,-20.0)*(1.0-reveal)
		river.sound.volume_db = lerpf(-50.0,-29.0,reveal)
	if time >= RiverTransition.DURATION:
		river.cinematic_entry = false
		river_transition.queue_free()
		river_transition = null

func _mount_river(cinematic: bool,scene_path: String = "res://scenes/debug/c_zone_river.tscn") -> void:
	active_controller.leave()
	art_actor.hide()
	cavern_foreground.hide()
	env_fx.hide()
	river = load(scene_path).instantiate()
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


func _draw_debug_selector(canvas:Node2D) -> void:
	canvas.draw_string(ui_font, Vector2(72.0, 92.0), "INKFALL · 关卡菜单", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, INK)
	canvas.draw_string(ui_font, Vector2(74.0, 128.0), "第一章与测试入口", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(INK, 0.58))
	for row in DEBUG_ENTRIES.size():
		var entry:Dictionary=DEBUG_ENTRIES[row]
		var rect := Rect2(72.0, 160.0 + float(row) * 72.0, 1040.0, 60.0)
		var selected:bool = entry.id == debug_selection
		canvas.draw_rect(rect, INK if selected else Color(PAPER,0.28)); canvas.draw_rect(rect, INK, false, 3.0)
		canvas.draw_string(ui_font, rect.position + Vector2(32.0, 25.0), entry.title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, PAPER if selected else INK)
		canvas.draw_string(ui_font, rect.position + Vector2(32.0, 47.0), entry.detail, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(PAPER, 0.7) if selected else Color(INK, 0.62))
	canvas.draw_string(ui_font, Vector2(74.0, 645.0), "↑ ↓ 选择　Enter / F 进入关卡", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, INK)
	canvas.draw_string(ui_font, Vector2(74.0, 686.0), "游戏中按 Esc 返回关卡菜单", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(INK, 0.55))

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
