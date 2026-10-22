extends Node2D

const Rope = preload("res://scripts/demos/c_zone_debug/forest_rope.gd")

# Act four of the C zone: what comes after the cliff lift, the forest. Design: docs/chapters/chapter-01-forest.md.
# This file holds the ground, the platforms and the ropes of the first room; the drawing is in forest_ink.gd (it draws into
# marsh_art's ink stage, like the cliff does); the controller (river_controller.gd) calls tick / try_grab / update_hold / reset.
#
# Room 1, "the deadfall yard" (see docs/chapters/img/forest-room1-layout-v2.png): art and the rope only so far; the balance
# beam, the gate and the stones are drawn but do nothing yet.
#
# The room is laid out in "room" coordinates (x to the right from the entry, y UP from the ground) and placed in the world by wx / wy.

const START_X := 7440.0  # where the cliff's ramp ends
const FLOOR_Y := -500.0  # the level of the top of the ramp (world y: up is negative)
const ROOM_X := 7700.0  # world x of the room's x = 0
const WORLD_END := 10700.0
const PLAYER_SIZE := Vector2(26.0, 54.0)
const HANDS_FROM_TOP := -6.0  # his raised hands, relative to the top of the body

# The vine: it hangs from a branch of the tree beside the high shelf; the log is where he jumps for it from.
const VINE_PIVOT := Vector2(ROOM_X + 930.0, FLOOR_Y - 345.0)
const VINE_LENGTH := 250.0

# Solid platforms in room coordinates: Rect2(x, top height, width, thickness down from the top; 0 = down to the ground)
const PLATFORMS := [
	Rect2(610.0, 50.0, 60.0, 0.0),  # stump
	Rect2(690.0, 120.0, 200.0, 0.0),  # fallen log
	Rect2(1100.0, 210.0, 140.0, 0.0),  # the high shelf
	Rect2(1250.0, 262.0, 200.0, 14.0),  # the branch walk over the beam
	Rect2(1500.0, 262.0, 200.0, 14.0),
	Rect2(1750.0, 262.0, 210.0, 14.0),
]

var level: Node2D
var clock := 0.0
var ropes: Array = []
var held := -1
var body: StaticBody2D
var art_ropes: Node2D

static func wx(x: float) -> float:
	return ROOM_X + x

static func wy(y: float) -> float:
	return FLOOR_Y - y

static func world(x: float, y: float) -> Vector2:
	return Vector2(ROOM_X + x, FLOOR_Y - y)

# The ground is level from the ramp on.
static func ground_y(_x: float) -> float:
	return FLOOR_Y

func _ready() -> void:
	body = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var ground := CollisionPolygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(START_X - 60.0, 600.0), Vector2(START_X - 60.0, FLOOR_Y), Vector2(WORLD_END, FLOOR_Y), Vector2(WORLD_END, 600.0)])
	body.add_child(ground)
	for plat: Rect2 in PLATFORMS:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var thickness: float = plat.size.y if plat.size.y > 0.0 else plat.position.y
		rect.size = Vector2(plat.size.x, thickness)
		shape.shape = rect
		shape.position = world(plat.position.x + plat.size.x * 0.5, plat.position.y - thickness * 0.5)
		body.add_child(shape)
	add_child(body)
	art_ropes = Node2D.new()
	art_ropes.z_index = 4
	art_ropes.draw.connect(_draw_ropes)
	add_child(art_ropes)
	_build_ropes()

func _build_ropes() -> void:
	ropes.clear()
	var vine = Rope.new()
	vine.setup(VINE_PIVOT, VINE_LENGTH)
	ropes.append(vine)

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
	var landed := feet.y >= FLOOR_Y - 1.0
	if Input.is_action_just_pressed("jump") or landed:
		var speed: Vector2 = rope.release()
		if not landed:
			speed.y -= 70.0  # the push off
		player.velocity = speed
		held = -1
		level.jump_buffer = 0.0
		level.coyote = 0.0

# The rope itself, drawn like the other ropes of the zone: a thin ink line.
func _draw_ropes() -> void:
	for rope in ropes:
		art_ropes.draw_line(rope.pivot, rope.end_point(), Color("050606"), 3.0, true)
