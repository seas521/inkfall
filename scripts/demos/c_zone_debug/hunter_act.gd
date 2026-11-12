extends Node2D

# The hunter of scene 1 (docs/chapters/scenes/scene-01-chase.md). He is never seen whole: a lantern swinging in the trees behind, a foot that
# comes down in front, an arm that sweeps through the fog. He is not an AI: everything here is a script that follows how far the boy has
# got (his feet's x), so that there is always a way through and the pressure is the same every time.
#
#   the bell      starts at the pond, a long way off; rings faster and louder the closer he is
#   the line      from CHASE_X on an invisible line comes after the boy (the "reach"): if he is slow it catches up and he is taken
#   the foot      a dark column (the shadow of something huge) falls over a stretch of ground and darkens for FOOT_OMEN s, then a foot
#                 stamps it flat: be across the column, or stand clear and wait for it to lift
#   the arm       a dark band comes sweeping out of the left through the fog: jump it
#   the cliff     (scene1_act.gd) when he is out of breath the lantern is close; after the flock the hand breaks the edge
#
# This file is the script and the sounds; the drawing is in hunter_art.gd.
enum Part { IDLE, OMEN, STRIKE, REST, GONE }

const CHASE_X := -5240.0  # his feet: the chase begins
const BELL_X := -5700.0  # the first bell, far off
const GAP_START := 560.0  # px between the line and him when it begins
const GAP_RESPAWN := 460.0  # after he has been taken: closer
const REACH_SPEED := 110.0  # the line's speed (he runs 151)
# the foot
const FOOT_X0 := -5200.0  # the stretch of ground it comes down on
const FOOT_X1 := -5010.0
const FOOT_TRIGGER := -5240.0
const FOOT_OMEN := 2.0  # from the shadow to the strike
const FOOT_FALL := 0.30  # it is seen coming down for this long
const FOOT_REST := 1.0  # then it stays down, a wall, then lifts
const FOOT_LIFT := 0.8
# the arm
const ARM_TRIGGER := -4690.0
const ARM_START_OFFSET := -900.0
const ARM_SPEED := 880.0
const ARM_WIDTH := 120.0  # the band
const ARM_JUMP := 30.0  # feet higher than this above the ground are over it
const ARM_END := 1700.0  # px from the trigger: the band is gone

var level: Node2D
var scene1: Node2D
var clock := 0.0
var started := false
var reach_x := -1.0e9
var gap := 9999.0
var foot_phase: int = Part.IDLE
var foot_time := 0.0
var arm_phase: int = Part.IDLE
var arm_time := 0.0
var bell_timer := 0.0
var step_timer := 0.0
var pressure := 0.0  # 0 far .. 1 on top of him
var tremor := 0.0  # camera shake from his steps
var impact_time := 99.0  # since the foot came down
var wall: StaticBody2D
var wall_shape: CollisionShape2D
var sounds := {}
var taken := false
var enabled := true  # (the tests of the route switch him off)

func setup(level_node: Node2D, scene_node: Node2D) -> void:
	level = level_node
	scene1 = scene_node
	wall = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(FOOT_X1 - FOOT_X0 + 30.0, 520.0)
	wall_shape.shape = rect
	wall_shape.position = Vector2((FOOT_X0 + FOOT_X1) * 0.5, -4300.0 - 240.0)
	wall_shape.disabled = true
	wall.add_child(wall_shape)
	add_child(wall)
	for entry in [["bell", -14.0], ["step", -10.0], ["strike", -2.0], ["sweep", -7.0], ["crack", -6.0]]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/hunter/%s.wav" % entry[0]) as AudioStream
		player.volume_db = entry[1]
		player.bus = &"Event" if AudioServer.get_bus_index(&"Event") >= 0 else &"Master"
		add_child(player)
		sounds[entry[0]] = player

# `checkpoint`: 0..3, what he has already got past (a foot he has crossed does not come down again)
func reset(checkpoint: int, feet_x: float) -> void:
	taken = false
	foot_phase = Part.GONE if checkpoint >= 2 else Part.IDLE
	arm_phase = Part.GONE if checkpoint >= 3 else Part.IDLE
	foot_time = 0.0
	arm_time = 0.0
	started = checkpoint >= 2
	reach_x = feet_x - GAP_RESPAWN if started else -1.0e9
	gap = GAP_RESPAWN if started else 9999.0
	bell_timer = 1.0
	step_timer = 1.5
	impact_time = 99.0
	tremor = 0.0
	wall_shape.set_deferred("disabled", true)

func _play(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var player: AudioStreamPlayer = sounds[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

# The boy is gone from the wall's way and the world goes dark: used by the controller after a death
func _kill(kind: String, at: Vector2) -> void:
	if taken or level.marsh_hit_time > 0.0 or level.death_time > 0.0 or level.curtain_phase != 0:
		return
	taken = true
	level._start_marsh_hit(kind, at)

func is_dead() -> bool:
	return level.marsh_hit_time > 0.0 or level.death_time > 0.0 or level.curtain_phase != 0

# The column of the foot's shadow: how dark, 0..1 (0 before, 1 as it comes down)
func foot_shadow() -> float:
	match foot_phase:
		Part.OMEN:
			return smoothstep(0.0, FOOT_OMEN * 0.85, foot_time)
		Part.STRIKE, Part.REST:
			return 1.0
		_:
			return 0.0

# 0..1: how far down the foot is (0 raised out of sight, 1 on the ground)
func foot_down() -> float:
	match foot_phase:
		Part.OMEN:
			var u := clampf((foot_time - (FOOT_OMEN - FOOT_FALL)) / FOOT_FALL, 0.0, 1.0)
			return u * u
		Part.STRIKE, Part.REST:
			return 1.0
		_:
			return 0.0

# 0..1 of the foot lifting away again after the rest (1 = gone)
func foot_lift() -> float:
	if foot_phase == Part.REST:
		return smoothstep(FOOT_REST, FOOT_REST + FOOT_LIFT, foot_time)
	if foot_phase == Part.GONE:
		return 1.0
	return 0.0

# The band the arm throws on the ground (world x of its centre), or null
func arm_x() -> Variant:
	if arm_phase == Part.OMEN or arm_phase == Part.STRIKE:
		return ARM_TRIGGER + ARM_START_OFFSET + ARM_SPEED * arm_time
	return null

# the hand coming down at the cliff: the same strike sound and a crack
func hand_impact() -> void:
	_play("strike", -1.0, 0.9)
	_play("crack", -3.0, 0.7)
	tremor = 0.0

func shake() -> float:
	var s := tremor
	if impact_time < 0.9:
		s = maxf(s, 4.4 * exp(-impact_time * 4.5))
	if foot_phase == Part.OMEN:
		s = maxf(s, 0.5 * smoothstep(0.2, FOOT_OMEN, foot_time))
	return s

func tick(delta: float, feet: Vector2, grounded: bool) -> void:
	if not enabled:
		return
	clock += delta
	impact_time += delta
	tremor = maxf(0.0, tremor - delta * 3.0)
	var dead := is_dead()
	if not dead:
		taken = false
	var cut: int = scene1.cut
	# --- the line ---
	if not started and feet.x >= CHASE_X and cut == 0:
		started = true
		reach_x = feet.x - GAP_START
	if started and not dead:
		if cut == 0:
			reach_x += REACH_SPEED * delta
			gap = feet.x - reach_x
			if gap <= 0.0:
				_kill("rock", Vector2(reach_x, feet.y - 20.0))
		else:
			# at the cliff the script holds him: the lantern comes closer as he gives out, then stays
			var want := 300.0
			if cut >= 2:
				want = 240.0
			if cut >= 4:
				want = 205.0
			if cut >= 8:
				want = 175.0
			gap = lerpf(gap, want, 1.0 - exp(-delta * 1.1))
			reach_x = feet.x - gap
	# how near he feels: the line itself, and (whatever the line does) the further he gets the closer he looms
	var progress := clampf((feet.x - CHASE_X) / (scene1.PANT_X - CHASE_X), 0.0, 1.0)
	pressure = clampf(maxf(1.0 - gap / 760.0, 0.28 + 0.5 * progress), 0.0, 1.0) if started else clampf((feet.x - BELL_X) / 900.0, 0.0, 0.2)
	# --- the foot ---
	match foot_phase:
		Part.IDLE:
			if feet.x >= FOOT_TRIGGER and started and not dead:
				foot_phase = Part.OMEN
				foot_time = 0.0
				_play("strike", -30.0, 1.35)  # a low groan before it comes
		Part.OMEN:
			foot_time += delta
			if foot_time >= FOOT_OMEN:
				foot_phase = Part.REST
				foot_time = 0.0
				impact_time = 0.0
				wall_shape.set_deferred("disabled", false)
				_play("strike", -1.0)
				_play("crack", -5.0, 0.8)
				if not dead and feet.x > FOOT_X0 - 6.0 and feet.x < FOOT_X1 + 6.0 and feet.y > scene1.ground_top(feet.x) - 90.0:
					_kill("crush", feet)
				level.art.call("emit_drag_dust", [Vector2(FOOT_X0, -4300.0), Vector2((FOOT_X0 + FOOT_X1) * 0.5, -4300.0), Vector2(FOOT_X1, -4300.0)], 40.0)
		Part.REST:
			foot_time += delta
			if foot_time >= FOOT_REST + FOOT_LIFT * 0.5:
				wall_shape.set_deferred("disabled", true)
			if foot_time >= FOOT_REST + FOOT_LIFT:
				foot_phase = Part.GONE
	# --- the arm ---
	match arm_phase:
		Part.IDLE:
			if feet.x >= ARM_TRIGGER and started and not dead:
				arm_phase = Part.OMEN
				arm_time = 0.0
				_play("sweep", -9.0)
		Part.OMEN, Part.STRIKE:
			arm_time += delta
			var band_x: float = ARM_TRIGGER + ARM_START_OFFSET + ARM_SPEED * arm_time
			if not dead and absf(feet.x - band_x) < ARM_WIDTH * 0.5 + 6.0 and feet.y > scene1.ground_top(feet.x) - ARM_JUMP:
				_kill("rock", Vector2(band_x, feet.y))
			if band_x > ARM_TRIGGER + ARM_END:
				arm_phase = Part.GONE
	# --- the sounds that go with how near he is ---
	if feet.x >= BELL_X and cut < 10 and not dead:
		bell_timer -= delta
		if bell_timer <= 0.0:
			bell_timer = lerpf(3.8, 1.05, pressure)
			_play("bell", lerpf(-30.0, -9.0, pressure), lerpf(0.94, 1.04, pressure))
	if started and cut < 10 and not dead:
		step_timer -= delta
		if step_timer <= 0.0:
			step_timer = lerpf(1.9, 1.15, pressure)
			_play("step", lerpf(-34.0, -9.0, pressure), lerpf(1.1, 0.85, pressure))
			tremor = maxf(tremor, 0.5 + 1.3 * pressure)
