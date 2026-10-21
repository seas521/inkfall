extends Node2D

const Rope = preload("res://scripts/demos/c_zone_debug/forest_rope.gd")

# Act four of the C zone: what comes after the cliff lift. The boy climbs on up the hillside (a big tree, a boulder), then the
# forest (traps, a snare, a spike pit). Design: docs/chapters/chapter-01-forest.md. This file holds the ground, the ropes and,
# later, the set pieces; the controller (river_controller.gd) calls tick / try_grab / update_hold / reset.
#
# Step 1 (this): the ground above the lift, a practice rope on the flat and the rope system itself.

const START_X := 7440.0  # where the cliff's ramp ends
const FLOOR_Y := -500.0  # the level of the top of the ramp (world y: up is negative)
const SLOPE_FROM := 7780.0
const SLOPE_TO := 9020.0
const SLOPE_RISE := 330.0
const CREST_Y := FLOOR_Y - SLOPE_RISE
const WORLD_END := 15000.0

const PRACTICE_PIVOT := Vector2(7662.0, FLOOR_Y - 250.0)
const PRACTICE_LENGTH := 175.0
const PLAYER_SIZE := Vector2(26.0, 54.0)
const HANDS_FROM_TOP := -6.0  # his raised hands, relative to the top of the body

var level: Node2D
var clock := 0.0
var ropes: Array = []
var held := -1
var body: StaticBody2D
var art_ground: Node2D
var art_ropes: Node2D
var backdrop: Control

# The hillside: flat, then up, then the crest (the forest is level up there).
static func ground_y(x: float) -> float:
	if x <= SLOPE_FROM:
		return FLOOR_Y
	if x >= SLOPE_TO:
		return CREST_Y
	var t := (x - SLOPE_FROM) / (SLOPE_TO - SLOPE_FROM)
	return FLOOR_Y - SLOPE_RISE * (0.6 * t + 0.4 * smoothstep(0.0, 1.0, t))

func _ready() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionPolygon2D.new()
	var outline := PackedVector2Array([Vector2(START_X - 60.0, 600.0)])
	var x := START_X - 60.0
	while x <= WORLD_END:
		outline.append(Vector2(x, ground_y(x)))
		x += 16.0
	outline.append(Vector2(WORLD_END, 600.0))
	shape.polygon = outline
	body.add_child(shape)
	add_child(body)
	art_ground = Node2D.new()
	art_ground.z_index = 1
	art_ground.draw.connect(_draw_ground)
	add_child(art_ground)
	var back_layer := CanvasLayer.new()
	back_layer.layer = -9
	add_child(back_layer)
	backdrop = Control.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.draw.connect(_draw_backdrop)
	back_layer.add_child(backdrop)
	art_ropes = Node2D.new()
	art_ropes.z_index = 4
	art_ropes.draw.connect(_draw_ropes)
	add_child(art_ropes)
	_build_ropes()

func _build_ropes() -> void:
	ropes.clear()
	var practice = Rope.new()
	practice.setup(PRACTICE_PIVOT, PRACTICE_LENGTH)
	ropes.append(practice)

func reset() -> void:
	held = -1
	_build_ropes()

func rope_attached() -> bool:
	return held >= 0

# Where his body hangs while he holds a rope (for the actor): angle and the point his hands are at.
func hang_info() -> Dictionary:
	if held < 0:
		return {}
	var rope = ropes[held]
	return {"angle": rope.angle, "hands": rope.hands(), "direction": rope.direction()}

func tick(delta: float) -> void:
	clock += delta
	for index in ropes.size():
		if index != held:
			ropes[index].step(delta, 0.0, 0.0)
	if art_ropes != null:
		art_ropes.queue_redraw()
	if backdrop != null:
		backdrop.visible = level.camera_x + 1280.0 > START_X - 400.0
		backdrop.queue_redraw()

func _climb_input() -> float:
	var up := Input.get_action_strength("aim_up")
	var down := Input.get_action_strength("aim_down") + (1.0 if Input.is_physical_key_pressed(KEY_S) else 0.0)
	return clampf(up - down, -1.0, 1.0)

# In the air with his hands at a rope's line: take hold.
func try_grab(player: CharacterBody2D) -> bool:
	if held >= 0 or player.is_on_floor():
		return false
	var hand := player.position + Vector2(PLAYER_SIZE.x * 0.5, HANDS_FROM_TOP)
	for index in ropes.size():
		if ropes[index].grab(hand, player.velocity):
			held = index
			player.velocity = Vector2.ZERO
			return true
	return false

# Every physics frame while he holds a rope: the arrows swing and climb, the jump key lets go.
func update_hold(delta: float, player: CharacterBody2D) -> void:
	if held < 0:
		return
	var rope = ropes[held]
	rope.step(delta, Input.get_axis("move_left", "move_right"), _climb_input())
	player.position = rope.body_centre() - PLAYER_SIZE * 0.5
	player.velocity = Vector2.ZERO
	if absf(rope.omega) > 0.15:
		level.facing = signf(rope.omega)
	var feet := player.position + Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y)
	var landed := feet.y >= ground_y(feet.x) - 1.0
	if Input.is_action_just_pressed("jump") or landed:
		var speed: Vector2 = rope.release()
		if not landed:
			speed.y -= 70.0  # the push off
		player.velocity = speed
		held = -1
		level.jump_buffer = 0.0
		level.coyote = 0.0

# ---- drawing (graybox) -------------------------------------------------------------------------

func _draw_ground() -> void:
	var points := PackedVector2Array()
	var x := START_X - 60.0
	while x <= WORLD_END:
		points.append(Vector2(x, ground_y(x)))
		x += 16.0
	points.append(Vector2(WORLD_END, 700.0))
	points.append(Vector2(START_X - 60.0, 700.0))
	art_ground.draw_colored_polygon(points, Color("050606"))
	art_ground.draw_polyline(points.slice(0, points.size() - 2), Color(0.30, 0.30, 0.30, 0.8), 2.0, true)
	# the practice tree: a dead tree with one branch over the flat, the rope hanging from its end
	_tree(art_ground, 7600.0, 330.0, PRACTICE_PIVOT)

func _tree(canvas: Node2D, base_x: float, height: float, branch_end: Vector2) -> void:
	var base_y := ground_y(base_x)
	var trunk := PackedVector2Array([
		Vector2(base_x - 22.0, base_y + 6.0), Vector2(base_x - 12.0, base_y - height * 0.5), Vector2(base_x - 8.0, base_y - height),
		Vector2(base_x + 8.0, base_y - height), Vector2(base_x + 12.0, base_y - height * 0.5), Vector2(base_x + 22.0, base_y + 6.0)])
	canvas.draw_colored_polygon(trunk, Color("050606"))
	var branch_start := Vector2(base_x + 4.0, base_y - height + 40.0)
	canvas.draw_line(branch_start, branch_end + Vector2(0.0, -6.0), Color("050606"), 11.0, true)

func _draw_ropes() -> void:
	for rope in ropes:
		var colour := Color(0.52, 0.45, 0.33)
		art_ropes.draw_line(rope.pivot, rope.end_point(), Color(0.02, 0.02, 0.02), 4.5, true)
		art_ropes.draw_line(rope.pivot, rope.end_point(), colour, 2.2, true)

# A flat misty backdrop while the real art is not made: a grey gradient and a few far trunks that move slower than the camera.
func _draw_backdrop() -> void:
	var fade := smoothstep(START_X - 400.0, START_X + 200.0, level.camera_x + 640.0)
	var size := Vector2(1280.0, 720.0)
	var steps := 24
	for i in steps:
		var t := float(i) / float(steps - 1)
		var grey := lerpf(0.34, 0.15, t)
		backdrop.draw_rect(Rect2(0.0, size.y * float(i) / float(steps), size.x, size.y / float(steps) + 1.0), Color(grey, grey, grey, fade))
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	for i in 18:
		var world_x := rng.randf_range(START_X - 600.0, WORLD_END)
		var depth := rng.randf_range(0.25, 0.6)
		var x: float = world_x - float(level.camera_x) * depth - (START_X - 600.0) * (1.0 - depth) + 700.0 * depth
		x = fposmod(x + 300.0, 2200.0) - 400.0
		var width := rng.randf_range(34.0, 110.0) * (0.6 + depth)
		var grey2 := lerpf(0.26, 0.10, depth)
		backdrop.draw_rect(Rect2(x - width * 0.5, 0.0, width, size.y), Color(grey2, grey2, grey2, fade * 0.8))
