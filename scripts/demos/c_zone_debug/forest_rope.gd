extends RefCounted

# A rope that hangs from a branch and that the hooded boy can hold: a pendulum.
#
#   angle   rope angle from straight down, positive towards +x (radians)
#   omega   angular speed
#   hold    how far from the pivot his hands are (he climbs by changing it)
#
# Held, the pendulum is as long as the hands plus the body below them (BODY_OFFSET); the arrows push it (left / right), up and
# down climb. Free, it is a short pendulum that settles by itself. Letting go gives him the speed of the point he held.
# Pure numbers: no scene nodes, so it is tested on its own (forest_rope_smoke.gd).

const GRAVITY := 1500.0  # px/s^2, the game's
const BODY_OFFSET := 40.0  # hands to the centre of mass
const CLIMB_SPEED := 70.0
const HELD_DAMP := 0.10  # 1/s
const FREE_DAMP := 0.7
const MAX_ANGLE := 1.25  # about 72 degrees: the rope does not swing flatter than this
const GRAB_RADIUS := 22.0  # from his hands to the rope's line
const MIN_HOLD := 36.0  # the highest he climbs: his hands this far under the pivot
const FREE_LENGTH_SCALE := 0.7

var pivot := Vector2.ZERO
var length := 210.0
var angle := 0.0
var omega := 0.0
var hold := 0.0
var attached := false
var grab_cooldown := 0.0
var pump := 1.5  # rad/s^2 added by the arrow keys

func setup(new_pivot: Vector2, new_length: float) -> void:
	pivot = new_pivot
	length = new_length
	angle = 0.0
	omega = 0.0
	hold = 0.0
	attached = false
	grab_cooldown = 0.0

func direction() -> Vector2:
	return Vector2(sin(angle), cos(angle))

func point_at(distance: float) -> Vector2:
	return pivot + direction() * distance

func end_point() -> Vector2:
	return point_at(length)

# where his hands are while he holds it
func hands() -> Vector2:
	return point_at(hold)

# the centre of his body: below the hands, along the rope
func body_centre() -> Vector2:
	return point_at(hold + BODY_OFFSET)

func swing_length() -> float:
	return (hold + BODY_OFFSET) if attached else length * FREE_LENGTH_SCALE

# Is a pair of hands at `hand` close enough to the rope's line to take hold? Returns the distance from the pivot, or -1.
func grab_distance(hand: Vector2) -> float:
	var along := direction()
	var rel := hand - pivot
	var d := rel.dot(along)
	if d < MIN_HOLD or d > length:
		return -1.0
	var off := (rel - along * d).length()
	return d if off <= GRAB_RADIUS else -1.0

# Take hold at `hand` while moving with `velocity`: the rope takes the part of the speed that is across it.
func grab(hand: Vector2, velocity: Vector2) -> bool:
	if attached or grab_cooldown > 0.0:
		return false
	var d := grab_distance(hand)
	if d < 0.0:
		return false
	hold = d
	attached = true
	var tangent := Vector2(cos(angle), -sin(angle))
	omega = clampf(velocity.dot(tangent) / swing_length(), -3.0, 3.0)
	return true

# `push` is -1 / 0 / 1 (left / right arrows), `climb` is -1 down, 0, 1 up.
func step(delta: float, push: float, climb: float) -> void:
	grab_cooldown = maxf(0.0, grab_cooldown - delta)
	if attached:
		var old_length := swing_length()
		hold = clampf(hold - climb * CLIMB_SPEED * delta, MIN_HOLD, length)
		# a shorter pendulum swings faster (angular momentum is kept)
		omega *= old_length / swing_length()
	var l := swing_length()
	var accel := -(GRAVITY / l) * sin(angle)
	accel -= (HELD_DAMP if attached else FREE_DAMP) * omega
	if attached:
		accel += push * pump
	omega += accel * delta
	angle += omega * delta
	if absf(angle) > MAX_ANGLE:
		angle = signf(angle) * MAX_ANGLE
		if omega * angle > 0.0:
			omega = -omega * 0.2

# Let go: the speed of the point of the body he hangs by.
func release() -> Vector2:
	if not attached:
		return Vector2.ZERO
	var tangent := Vector2(cos(angle), -sin(angle))
	var speed := omega * swing_length()
	attached = false
	grab_cooldown = 0.35
	return tangent * speed
