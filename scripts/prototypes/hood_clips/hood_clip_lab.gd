extends Node2D

# Test scene for the Seedance frame clips of the hooded boy. Not connected to level 1.
#   A / D or arrows   run left / right at one constant speed; let go to stop; pressing the other way
#                     turns him and he runs that way at once (same as level 1)
#   W / Up / Space    jump (real physics, same numbers as level 1; hold = higher, let go early = lower)
#   F   trip and fall from the air: tumble -> hits the ground -> lies still -> any key gets him up
#   G   flinch (a scare / a hit): jerks back, then relaxes; moving again cuts it short
#   E   grab the box (walks up to it first), E again lets go. Holding the key toward the box pushes it,
#       away from the box pulls it; the hands stay on the box face the whole time.
#   P   a small item (one hand): tap next to it to pick it up (he walks up first), tap again to put it down,
#       hold to charge a throw and let go to throw it. Carrying changes run and jump to the one-hand clips.
#   Q   with the fan in hand: swing it (left hand joins, the body turns to the screen, winds up, swings; twice in a
#       row alternates the two takes). P next to the fan picks it up, tap P puts it down.
#   H   a rolling boulder comes at him and shoves him back (hands on its face, back leg driving, feet scraping);
#       jump to get out of it, or it lets go after a few seconds
#   V   drop into the pool on the right: plunge, then thrash at the surface; A/D swims, X lets him drown
#   B   (while running) the scared emergency brake: stops dead, freezes, then relaxes (for the C zone rocks)
#   C   show the current knight next to it      +/- scale     R   reset
# Everything follows level 1 (scripts/core/player_controller.gd): speed follows the key at once, on the
# ground and in the air; the jump is a velocity + gravity; the jump buffer (0.13s) and coyote time
# (0.12s) are the same. The animation never holds the controls: it only reads the state, exactly like
# scripts/actors/seedance_frame_actor.gd (takeoff for 0.125s, then rise / apex / fall by vertical speed,
# then a landing that any key press cuts short).
# Turning is a plain mirror. Every clip is native facing left and is mirrored for the right; they all
# share the resting pose as root, so the boy does not shift sideways when he flips.

const CLIPS := [
	"idle_left", "rest_to_run", "run_left", "stop_left", "scared_brake",
	"stand_takeoff", "stand_rise", "stand_apex", "stand_fall", "stand_land",
	"run_takeoff", "run_rise", "run_apex", "run_fall", "run_land",
	"fall_air", "fall_impact", "downed", "get_up", "flinch",
	"grip_engage", "grip_hold", "push", "grip_to_pull", "pull", "grip_release",
	"small_pickup", "small_hold", "small_run", "small_jump_takeoff", "small_jump_rise", "small_jump_apex",
	"small_jump_fall", "small_jump_land", "small_throw_charge", "small_throw_release", "small_throw_recover",
	"big_pickup", "big_hold", "big_walk", "big_throw_charge", "big_throw_release", "big_throw_recover",
	"fan_pickup", "fan_swing_1", "fan_swing_2", "fan_putdown",
	"shoved_in", "shoved", "shoved_out",
	"water_wade", "water_plunge", "water_tread", "water_swim", "water_drown",
]
const ROOT_PATH := "res://assets/art/prototypes/hood_clips"
const OLD_ROOT := "res://assets/art/actors/crooked_tower_seedance"
const GROUND_Y := 560.0
const CANVAS_ROOT := Vector2(128.0, 232.0)
# Level 1 numbers (Palette). The sprite here is drawn bigger than in level 1 (0.62 vs 0.42), so the
# vertical numbers are scaled with it and the jump has the same proportions.
const LEVEL1_SCALE := 0.42
const GRAVITY := 1550.0
const JUMP_SPEED := -590.0
const JUMP_CUT_SPEED := -185.0
const TAKEOFF_TIME := 0.125
const BOX_SIZE := Vector2(96.0, 96.0)
const PUSH_SPEED := 82.0  # the push loop was filmed at about this ground speed (feet do not slide)
const PULL_SPEED := 62.0
const ITEM_R := 10.0
const BIG_SIZE := Vector2(56.0, 50.0)
const ROCK_R := 44.0
const ROCK_SPEED := 86.0  # level 1 (C zone): the boulder slows to about this while it shoves him
const SHOVE_TIME := 2.6
const WATER_Y := 498.0  # the surface (the ground is at 560)
const POOL_X := Vector2(880.0, 1240.0)
const SWIM_SPEED := 80.0
const BIG_SPEED := 59.0  # the heavy walk was retimed (37 frames) to be 1.0x at this ground speed
const THROW_ANGLE := 0.66  # rad, about 38 degrees
const LANDING_CANCEL_TIME := 0.08  # a key press cuts the landing short after the impact frames

var clip_scale := 0.62
var run_speed := 285.0  # level 1: Palette.RUN_SPEED
var ref_speed := 285.0  # the run loop was retimed (rife_upsample --frames 30) to play at exactly 1.0x at this speed
var pos_x := 640.0
var vx := 0.0
var air_y := 0.0  # height above the ground, negative = up
var vy := 0.0
var on_ground := true
var coyote := 0.0
var jump_buffer := 0.0
var jump_held := false
var takeoff_time := 0.0
var air_set := "stand"  # which legs: "stand" or "run"
var facing := 1.0
var state := "idle"
var sprite: AnimatedSprite2D
var frames: SpriteFrames
var info: Label
var factors := {}  # clip -> new frames per original 24fps frame (the clips are interpolated to 60fps)
var roots := {}  # clip -> canvas root (the jump clips use a bigger canvas)
var run_entry: Array = []  # run_left frame -> run_takeoff frame to start from (leg phase)
var run_exit := 0  # run_left frame to continue from after run_land
var launch_exit := 0  # run_left index after the short rest_to_run transition
var rest_entry := 0  # run_left frame to start the run from when leaving the resting pose
var stop_exit: Array = []  # stop_left frame -> run_left frame to continue from
var stop_entry: Array = []  # run_left frame -> stop_left frame to start from
var old_sprite: Sprite2D
var old_travel := 0.0
var forced_dir := NAN  # set by the capture script instead of the keyboard
var forced_jump_held := false
var forced_p_held := false
# The animation clock. The engine's own frame time wobbles (5-11 ms around 8.3 ms at 120Hz); a 60fps
# clip shown on a 120Hz screen needs exactly 2 refreshes per frame, and the wobble turned some into
# 3 + 1 (a visible hitch). So time advances by exactly one refresh per engine frame (see _step), and
# the frame is picked from our own progress counter instead of AnimatedSprite2D's internal timer.
var refresh := 60.0
var anim_progress := 0.0
var anim_playing := false
var anim_speed := 1.0
var _stop_from := 0.0
var _stop_time := 0.0
var _stop_duration := 0.6
var downed_time := 0.0
var carrying := false
var item_mode := "ground"  # ground / hand / flying
var item_pos := Vector2(900.0, 548.0)
var item_vel := Vector2.ZERO
var item_node: Polygon2D
var items: Array = []
var cur_item := 0
var water: Polygon2D
var float_y := 498.0
var sink := 0.0
var rock: Polygon2D
var rock_active := false
var rock_x := 0.0
var rock_travel := 1.0
var rock_immune := 0.0
var shove_time := 0.0
var carry_kind := "small"
var item_half_w := 0.0
var fan_handle: Line2D
var fan_facing := -1.0  # which way the fan lies on the ground
var swing_take := 0
var item_h := 20.0
var item_thrown := false
var approach_kind := "box"
var p_pending := false
var p_time := 0.0
var charge_time := 0.0
var clip_meta := {}  # clip -> manifest fields (hold points, release frame ...)
var box: Polygon2D
var box_center := 380.0
var grip_side := -1.0  # which way the box is from the boy while he holds it
var grip_dist := 64.0  # px from the root to the box face (eased)
var auto_approach := false
var hand_const := {}
var hand_list := {}
var anim_reverse := false
var _hold_dist := 64.0
var fall_anim_speed := 1.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.74, 0.745, 0.75))
	refresh = DisplayServer.screen_get_refresh_rate()
	if refresh <= 1.0:
		refresh = 60.0
	frames = SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	for clip in CLIPS:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/manifest.json" % [ROOT_PATH, clip]))
		frames.add_animation(clip)
		roots[clip] = Vector2(float(manifest.root[0]), float(manifest.root[1]))
		factors[clip] = float(manifest.get("frame_factor", 1.0))
		clip_meta[clip] = manifest
		hand_const[clip] = float(manifest.get("hand_offset", 0.0))
		hand_list[clip] = manifest.get("hand_offsets", [])
		if clip == "run_takeoff":
			run_entry = manifest.get("entry_from_run", [])
		if clip == "rest_to_run":
			launch_exit = int(manifest.get("exit_run_index", 0))
		if clip == "run_left":
			rest_entry = int(manifest.get("entry_from_rest", 0))
		if clip == "stop_left":
			stop_entry = manifest.get("entry_from_run", [])
			stop_exit = manifest.get("exit_to_run", [])
		if clip == "run_land":
			run_exit = int(manifest.get("exit_run_frame", 0))
		frames.set_animation_speed(clip, float(manifest.fps))
		frames.set_animation_loop(clip, bool(manifest.loop))
		var durations: Array = manifest.get("frame_durations", [])
		for i in range(int(manifest.frames)):
			var duration := float(durations[i]) if i < durations.size() else 1.0
			frames.add_frame(clip, load("%s/%s/frame_%03d.png" % [ROOT_PATH, clip, i]), duration)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = -CANVAS_ROOT
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(-200, GROUND_Y), Vector2(1500, GROUND_Y), Vector2(1500, 900), Vector2(-200, 900)])
	ground.color = Color(0.012, 0.013, 0.013)
	ground.z_index = -2
	add_child(ground)
	box = Polygon2D.new()
	box.polygon = PackedVector2Array([Vector2(-BOX_SIZE.x * 0.5, -BOX_SIZE.y), Vector2(BOX_SIZE.x * 0.5, -BOX_SIZE.y), Vector2(BOX_SIZE.x * 0.5, 0), Vector2(-BOX_SIZE.x * 0.5, 0)])
	box.color = Color(0.36, 0.31, 0.26)
	box.z_index = -1
	add_child(box)
	water = Polygon2D.new()
	water.polygon = PackedVector2Array([Vector2(POOL_X.x, WATER_Y), Vector2(POOL_X.y, WATER_Y), Vector2(POOL_X.y, 700), Vector2(POOL_X.x, 700)])
	water.color = Color(0.36, 0.42, 0.46, 0.62)
	water.z_index = 6
	add_child(water)
	rock = Polygon2D.new()
	var rock_points := PackedVector2Array()
	for i in range(18):
		var radius := ROCK_R * (0.9 + 0.1 * sin(float(i) * 2.3))
		rock_points.append(Vector2(cos(TAU * float(i) / 18.0), sin(TAU * float(i) / 18.0)) * radius)
	rock.polygon = rock_points
	rock.color = Color(0.2, 0.18, 0.16)
	rock.z_index = 1
	rock.visible = false
	add_child(rock)
	_make_items()
	old_sprite = Sprite2D.new()
	old_sprite.centered = false
	old_sprite.offset = -CANVAS_ROOT
	old_sprite.visible = false
	old_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(old_sprite)
	info = Label.new()
	info.position = Vector2(24, 18)
	info.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	add_child(info)
	_hold_dist = -float(hand_const["grip_hold"]) * clip_scale
	reset()

func reset() -> void:
	pos_x = 640.0
	vx = 0.0
	air_y = 0.0
	vy = 0.0
	on_ground = true
	jump_buffer = 0.0
	facing = 1.0
	box_center = 380.0
	auto_approach = false
	carrying = false
	_reset_items()
	p_pending = false
	_enter("idle")

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R: reset()
		KEY_W, KEY_UP, KEY_SPACE:
			jump_buffer = 0.13  # level 1: the press is remembered for 0.13s
		KEY_P:
			_on_p_pressed()
		KEY_Q:
			if carrying and carry_kind == "fan" and (state == "idle" or state == "rest"):
				swing_take += 1
				_enter("swing")
		KEY_H:
			_spawn_rock()
		KEY_V:
			if on_ground and not _in_water():
				pos_x = 1060.0
				vx = 0.0
				facing = -1.0
				_enter("plunge")
		KEY_X:
			if state == "tread" or state == "swim":
				sink = 0.0
				_enter("drown")
		KEY_E:
			_toggle_grip()
		KEY_F:
			if state != "fall" and state != "impact" and state != "downed" and state != "get_up":
				_start_fall()
		KEY_G:
			if state in ["idle", "rest", "run", "launch", "stop", "land"]:
				_enter("flinch")
		KEY_B:
			if state == "run" or state == "launch":
				_enter("scared")
		KEY_C: old_sprite.visible = not old_sprite.visible
		KEY_EQUAL, KEY_KP_ADD: clip_scale = minf(1.2, clip_scale + 0.05)
		KEY_MINUS, KEY_KP_SUBTRACT: clip_scale = maxf(0.3, clip_scale - 0.05)

func _process(delta: float) -> void:
	var dir := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if not is_nan(forced_dir):
		dir = forced_dir
	if auto_approach:
		dir = _approach_dir()
		if dir == 0.0:
			if approach_kind == "box":
				_begin_engage()
			else:
				_begin_pickup()
	jump_held = forced_jump_held or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE)
	tick(delta, dir)

func _clip_for(s: String) -> String:
	if s == "putdown" and carry_kind == "fan":
		return "fan_putdown"
	if s == "swing":
		return "fan_swing_%d" % (1 + swing_take % 2)
	if s == "pickup" or s == "putdown":
		return _cn("pickup")
	if s == "charge":
		return _cn("charge")
	if s == "release":
		return _cn("release")
	if s == "recover":
		return _cn("recover")
	if carrying:
		match s:
			"idle", "stop", "launch":
				return _cn("hold")
			"run":
				return _cn("run")
			"land":
				return "small_jump_land"
	return {"idle": "idle_left", "run": "run_left", "launch": "rest_to_run", "fall": "fall_air", "impact": "fall_impact", "downed": "downed", "get_up": "get_up", "flinch": "flinch", "shoved_in": "shoved_in", "shoved": "shoved", "shoved_out": "shoved_out", "plunge": "water_plunge", "tread": "water_tread", "swim": "water_swim", "drown": "water_drown", "engage": "grip_engage", "hold": "grip_hold", "push": "push", "to_pull": "grip_to_pull", "pull": "pull", "from_pull": "grip_to_pull", "release_hold": "grip_engage", "release_pull": "grip_release", "stop": "stop_left", "scared": "scared_brake", "land": "%s_land" % air_set}[s] as String

func _play(clip: String, reverse := false) -> void:
	sprite.offset = -(roots[clip] as Vector2)
	sprite.animation = StringName(clip)
	sprite.pause()
	anim_playing = true
	anim_reverse = reverse
	if reverse:
		_set_frame(frames.get_frame_count(clip) - 1)
		anim_progress = float(frames.get_frame_count(clip)) - 0.001
	else:
		_set_frame(0)

func _enter(s: String) -> void:
	var from_state := state
	var from_frame := sprite.frame
	state = s
	_play(_clip_for(s), s == "from_pull" or s == "release_hold" or (s == "putdown" and carry_kind != "fan"))
	if s == "run":
		# Straight into the run loop (like level 1: no start-up animation), at the stride frame closest
		# to the pose he is leaving.
		var run_frame := rest_entry
		if from_state == "stop":
			var original_stop := int(float(from_frame) / float(factors["stop_left"]))
			if original_stop < stop_exit.size():
				run_frame = int(stop_exit[original_stop])
		_set_frame(_scaled("run_left", run_frame))
	elif s == "stop" and from_state == "run":
		var original := int(float(from_frame) / float(factors["run_left"]))
		if original < stop_entry.size():
			_set_frame(_scaled("stop_left", int(stop_entry[original])))
	if s == "downed":
		downed_time = 0.0
	if s == "stop" or s == "scared":
		_stop_from = vx
		_stop_time = 0.0
	if s == "stop":
		# Entering part-way into the clip (leg phase): the slide lasts as long as what is left of it.
		_stop_duration = float(frames.get_frame_count("stop_left") - sprite.frame) / maxf(1.0, frames.get_animation_speed("stop_left"))

func _scaled(clip: String, original_frame: int) -> int:
	return mini(int(float(original_frame) * float(factors[clip])), frames.get_frame_count(clip) - 1)

func _leaf_polygon() -> PackedVector2Array:
	# A broad leaf with its stalk end at the origin, pointing along +x; drawn rotated onto the rod's tip.
	var points := PackedVector2Array()
	var length := 92.0
	for i in range(0, 13):
		var t := float(i) / 12.0
		points.append(Vector2(t * length, -sin(t * PI) * 30.0 - 4.0 * t))
	for i in range(12, -1, -1):
		var t := float(i) / 12.0
		points.append(Vector2(t * length, sin(t * PI) * 26.0 - 2.0 * t))
	return points

func _set_fan(near: Vector2, tip: Vector2, node: Polygon2D = null) -> void:
	var leaf: Polygon2D = node if node != null else item_node
	fan_handle.clear_points()
	fan_handle.add_point(near)
	fan_handle.add_point(tip)
	leaf.position = tip
	leaf.rotation = (tip - near).angle()

func _rod_pose() -> Array:
	# The fan's handle as [near, tip] in world px, from the rod recorded in the clip (pickup, swing, put down),
	# or from the hand while he carries it (hold stance, handle pointing up and forward).
	var clip := String(sprite.animation)
	var meta: Dictionary = clip_meta.get(clip, {})
	var rod: Array = meta.get("rod", [])
	var s := clip_scale
	if not rod.is_empty() and (state == "pickup" or state == "putdown" or state == "swing"):
		var original := clampi(int(float(sprite.frame) / float(factors[clip])), 0, rod.size() - 1)
		var r: Array = rod[original]
		var near := Vector2(pos_x - facing * float(r[0]) * s, GROUND_Y + air_y + float(r[1]) * s)
		var tip := Vector2(pos_x - facing * float(r[2]) * s, GROUND_Y + air_y + float(r[3]) * s)
		return [near, tip]
	var hand := _hand_point()
	var up := Vector2(-facing * 0.35, -1.0).normalized()
	return [hand, hand + up * 46.0]

func _cn(part: String) -> String:
	# Clip name for the item being carried (small = one hand, big = two hands).
	if carry_kind == "fan":
		match part:
			"pickup": return "fan_pickup"
			"hold": return "small_hold"
			"run": return "small_run"
			"recover": return "small_throw_recover"
			"charge": return "small_throw_charge"
			"release": return "small_throw_release"
	match part:
		"pickup": return "%s_pickup" % carry_kind
		"hold": return "%s_hold" % carry_kind
		"run": return "small_run" if carry_kind == "small" else "big_walk"
		"charge": return "%s_throw_charge" % carry_kind
		"release": return "%s_throw_release" % carry_kind
		"recover": return "%s_throw_recover" % carry_kind
	return part

func _make_items() -> void:
	for kind in ["small", "big", "fan"]:
		var node := Polygon2D.new()
		if kind == "fan":
			node.polygon = _leaf_polygon()
			fan_handle = Line2D.new()
			fan_handle.width = 4.0
			fan_handle.default_color = Color(0.03, 0.03, 0.035)
			fan_handle.z_index = 2
			add_child(fan_handle)
		elif kind == "small":
			var circle := PackedVector2Array()
			for i in range(20):
				circle.append(Vector2(cos(TAU * float(i) / 20.0), sin(TAU * float(i) / 20.0) * 0.85) * ITEM_R)
			node.polygon = circle
		else:
			var h := BIG_SIZE * 0.5
			node.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
		node.color = Color(0.03, 0.03, 0.035) if kind == "small" else (Color(0.1, 0.12, 0.1) if kind == "fan" else Color(0.09, 0.075, 0.06))
		node.z_index = 2
		add_child(node)
		items.append({"kind": kind, "pos": Vector2.ZERO, "mode": "ground", "node": node, "half_w": 0.0 if kind != "big" else BIG_SIZE.x * 0.5, "height": ITEM_R * 2.0 if kind != "big" else BIG_SIZE.y})
	_reset_items()

func _reset_items() -> void:
	items[0]["pos"] = Vector2(900.0, GROUND_Y - ITEM_R)
	items[1]["pos"] = Vector2(430.0, GROUND_Y - BIG_SIZE.y * 0.5)
	items[2]["pos"] = Vector2(1120.0, GROUND_Y - 3.0)
	fan_facing = -1.0
	for it in items:
		it["mode"] = "ground"
	_select_item(0)

func _select_item(k: int) -> void:
	if not items.is_empty() and cur_item < items.size():
		items[cur_item]["pos"] = item_pos
		items[cur_item]["mode"] = item_mode
	cur_item = k
	item_pos = items[k]["pos"]
	item_mode = items[k]["mode"]
	item_node = items[k]["node"]
	item_half_w = items[k]["half_w"]
	item_h = items[k]["height"]
	carry_kind = items[k]["kind"]

func _pick_reach() -> float:
	if carry_kind == "fan":
		var rod: Array = clip_meta["fan_pickup"]["rod"]
		return -float(rod[0][0]) * clip_scale

	# Distance from the root to the hand when it touches the ground (from the clip's tracked hand path).
	var meta: Dictionary = clip_meta[_cn("pickup")]
	var points: Array = meta.get("hold_points", [])
	var grasp := clampi(int(meta.get("grasp_orig_frame", 0)), 0, maxi(0, points.size() - 1))
	return -float(points[grasp][0]) * clip_scale + item_half_w

func _p_down() -> bool:
	return forced_p_held or Input.is_key_pressed(KEY_P)

func _update_item(delta: float) -> void:
	var s := clip_scale / LEVEL1_SCALE
	for k in range(items.size()):
		if k != cur_item:
			if items[k]["kind"] == "fan":
				var lying: Vector2 = items[k]["pos"]
				_set_fan(Vector2(lying.x, GROUND_Y - 3.0), Vector2(lying.x + fan_facing * 56.0, GROUND_Y - 3.0), items[k]["node"])
			else:
				items[k]["node"].position = items[k]["pos"]
	if item_mode == "flying":
		item_vel.y += GRAVITY * s * delta
		item_pos += item_vel * delta
		if item_pos.y >= GROUND_Y - item_h * 0.5:
			item_pos.y = GROUND_Y - item_h * 0.5
			item_mode = "ground"
			item_vel = Vector2.ZERO
	elif carry_kind == "fan":
		if carrying or state == "pickup" or state == "putdown" or state == "swing":
			var pose := _rod_pose()
			_set_fan(pose[0], pose[1])
			item_mode = "hand" if carrying or state == "swing" else item_mode
			if state == "pickup" and int(float(sprite.frame) / float(factors["fan_pickup"])) >= 30:
				item_mode = "hand"
		else:
			var lying_near := Vector2(item_pos.x, GROUND_Y - 3.0)
			_set_fan(lying_near, lying_near + Vector2(fan_facing * 56.0, 0.0))
	else:
		var want_hand := carrying or state == "charge" or (state == "release" and not item_thrown)
		if state == "pickup" or state == "putdown":
			var meta: Dictionary = clip_meta[_cn("pickup")]
			var original := int(float(sprite.frame) / float(factors[_cn("pickup")]))
			want_hand = original >= int(meta.get("grasp_orig_frame", 16))
		if want_hand:
			item_mode = "hand"
			item_pos = _hand_point() + Vector2(-facing * -item_half_w, 0.0) * 1.0
		elif item_mode == "hand":
			item_mode = "ground"
			item_pos = Vector2(item_pos.x, GROUND_Y - item_h * 0.5)
	if carry_kind != "fan":
		item_node.position = item_pos

func _on_p_pressed() -> void:
	if carrying:
		if state == "idle" or state == "rest":
			if carry_kind == "fan":
				_enter("putdown")
			else:
				p_pending = true
				p_time = 0.0
	elif state == "idle" or state == "rest":
		var best := -1
		var best_distance := 400.0
		for k in range(items.size()):
			var at: Vector2 = item_pos if k == cur_item else items[k]["pos"]
			var mode: String = item_mode if k == cur_item else items[k]["mode"]
			if mode == "ground" and absf(at.x - pos_x) < best_distance:
				best = k
				best_distance = absf(at.x - pos_x)
		if best >= 0:
			_select_item(best)
			approach_kind = "item"
			auto_approach = true

func _begin_pickup() -> void:
	auto_approach = false
	var side := signf(item_pos.x - pos_x)
	facing = side
	pos_x = item_pos.x - side * _pick_reach()
	vx = 0.0
	_enter("pickup")

func _hand_point() -> Vector2:
	var clip := String(sprite.animation)
	var meta: Dictionary = clip_meta.get(clip, {})
	var points: Array = meta.get("hold_points", [])
	if points.is_empty():
		return Vector2(pos_x, GROUND_Y + air_y - 60.0)
	var original := clampi(int(float(sprite.frame) / float(factors[clip])), 0, points.size() - 1)
	var point: Array = points[original]
	return Vector2(pos_x - facing * float(point[0]) * clip_scale, GROUND_Y + air_y + float(point[1]) * clip_scale)

func _air_name(phase: String) -> String:
	return "small_jump_%s" % phase if air_set == "small" else "%s_%s" % [air_set, phase]

func _item_busy() -> bool:
	return state in ["pickup", "putdown", "charge", "release", "recover", "swing"]

func _in_water() -> bool:
	return state in ["plunge", "tread", "swim", "drown"]

func _shoved() -> bool:
	return state == "shoved_in" or state == "shoved"

func _spawn_rock() -> void:
	if rock_active or not on_ground:
		return
	rock_travel = 1.0 if pos_x > 640.0 else -1.0
	rock_x = pos_x - rock_travel * 700.0
	rock_active = true
	rock_immune = 0.0
	rock.visible = true

func _update_rock(delta: float) -> void:
	if not rock_active:
		rock.visible = false
		return
	var s := clip_scale / LEVEL1_SCALE
	var speed := ROCK_SPEED * s
	rock_immune = maxf(0.0, rock_immune - delta)
	var hand_dist := -float(hand_const["shoved"]) * clip_scale
	if _shoved():
		rock_x += rock_travel * speed * delta
		shove_time += delta
		pos_x = rock_x + rock_travel * (ROCK_R * 0.9 + hand_dist)
		if shove_time >= SHOVE_TIME:
			rock_active = false
			_enter("shoved_out")
	else:
		rock_x += rock_travel * (speed * 2.2 if absf(pos_x - rock_x) > 360.0 else speed) * delta
		var can_be_hit := on_ground and rock_immune <= 0.0 and state in ["idle", "rest", "run", "launch", "stop", "land", "scared"] and not _item_busy() and not _gripping()
		if can_be_hit and rock_travel * (rock_x - pos_x) + ROCK_R * 0.9 + hand_dist >= 0.0 and rock_travel * (rock_x - pos_x) < ROCK_R * 0.9 + hand_dist + 30.0:
			facing = -rock_travel
			vx = 0.0
			shove_time = 0.0
			_enter("shoved_in")
		elif absf(rock_x - pos_x) > 900.0 and rock_travel * (rock_x - pos_x) > 0.0:
			rock_active = false
	rock.rotation += rock_travel * speed * delta / ROCK_R
	rock.position = Vector2(rock_x, GROUND_Y - ROCK_R)

func _gripping() -> bool:
	return state in ["engage", "hold", "push", "to_pull", "pull", "from_pull", "release_hold", "release_pull"]

func _approach_dir() -> float:
	var target := box_center if approach_kind == "box" else item_pos.x
	var side := signf(target - pos_x)
	var wanted := 0.0
	if approach_kind == "box":
		wanted = (box_center - side * BOX_SIZE.x * 0.5) - side * _hold_dist
	else:
		wanted = item_pos.x - side * _pick_reach()
	if absf(wanted - pos_x) <= 5.0 or signf(wanted - pos_x) != side:
		return 0.0
	return side

func _throw_item() -> void:
	item_thrown = true
	carrying = false
	item_mode = "flying"
	item_pos = _hand_point() + Vector2(facing * item_half_w, 0.0)
	var power := lerpf(620.0, 1240.0, clampf(charge_time / 0.9, 0.0, 1.0)) * (clip_scale / LEVEL1_SCALE) * (1.0 if carry_kind == "small" else 0.7)
	item_vel = Vector2(facing * cos(THROW_ANGLE), -sin(THROW_ANGLE)) * power

func _toggle_grip() -> void:
	if state == "hold" or state == "push":
		_enter("release_hold")
	elif state == "pull" or state == "to_pull":
		_enter("release_pull")
	elif state == "idle" or state == "rest" or state == "run" or state == "stop" or state == "launch":
		var side := signf(box_center - pos_x)
		if absf(box_center - pos_x) < 700.0:
			approach_kind = "box"
			auto_approach = true
			grip_side = side

func _begin_engage() -> void:
	auto_approach = false
	grip_side = signf(box_center - pos_x)
	facing = grip_side
	var face := box_center - grip_side * BOX_SIZE.x * 0.5
	pos_x = face - grip_side * _hold_dist
	vx = 0.0
	grip_dist = _hold_dist
	_enter("engage")

func _hand_distance() -> float:
	# Px from the root to the hand tip, from the clip: constant for the loops, per frame while the grip
	# changes (the hands slide toward the body when he pulls it in).
	var clip := String(sprite.animation)
	var offsets: Array = hand_list.get(clip, [])
	if (state == "to_pull" or state == "from_pull" or state == "release_pull") and offsets.size() > 0:
		var original := clampi(int(float(sprite.frame) / float(factors[clip])), 0, offsets.size() - 1)
		return -float(offsets[original]) * clip_scale
	return -float(hand_const.get(clip, 0.0)) * clip_scale

func _can_jump() -> bool:
	if state == "scared" or state == "fall" or state == "impact" or state == "downed" or _gripping() or _in_water() or (_item_busy() and not (state == "recover" and _clip_ready(_cn("recover"), 0.5))) or (carrying and carry_kind == "big"):
		return false
	if state == "get_up" and not _clip_ready("get_up", 0.72):
		return false
	if state == "flinch" and not _clip_ready("flinch", 0.35):
		return false
	return on_ground or coyote > 0.0

func _clip_ready(clip: String, fraction: float) -> bool:
	# True once the clip has played that far: the controls come back before the animation ends.
	return anim_progress >= fraction * float(frames.get_frame_count(clip))

func _start_fall() -> void:
	var s := clip_scale / LEVEL1_SCALE
	state = "fall"
	on_ground = false
	coyote = 0.0
	jump_buffer = 0.0
	air_y = -250.0
	vy = -500.0
	var g := GRAVITY * s
	var fall_time := (500.0 + sqrt(500.0 * 500.0 + 2.0 * g * 250.0)) / g
	_play("fall_air")
	var duration := float(frames.get_frame_count("fall_air")) / frames.get_animation_speed("fall_air")
	fall_anim_speed = clampf(duration / fall_time, 0.8, 3.0)  # the tumble ends as he lands

func _start_jump() -> void:
	var s := clip_scale / LEVEL1_SCALE
	var moving := absf(vx) > 120.0 and not _shoved()
	# Entering from a run stride: start the takeoff at the matching leg phase.
	var from_run_frame := sprite.frame if state == "run" else -1
	air_set = "small" if carrying else ("run" if moving else "stand")
	if rock_active:
		rock_immune = 1.0  # a jump gets him out from under the boulder; it rolls on beneath for a moment
	state = "air"
	on_ground = false
	coyote = 0.0
	jump_buffer = 0.0
	vy = JUMP_SPEED * s
	takeoff_time = TAKEOFF_TIME
	_play(_air_name("takeoff"))
	if air_set == "run":
		var start_frame := 1
		var original := int(float(from_run_frame) / float(factors["run_left"]))
		if from_run_frame >= 0 and original < run_entry.size():
			start_frame = int(run_entry[original])
		_set_frame(_scaled("run_takeoff", start_frame))

func _air_clip() -> String:
	var s := clip_scale / LEVEL1_SCALE
	if takeoff_time > 0.0:
		return _air_name("takeoff")
	if vy < -85.0 * s:
		return _air_name("rise")
	if vy < 95.0 * s:
		return _air_name("apex")
	return _air_name("fall")

func _land() -> void:
	# Run legs and still moving: the landing is already a stride, continue the run from it.
	# Otherwise the crouch landing; any key press cuts it short.
	if air_set == "small":
		state = "land"
		_play("small_jump_land")
	elif air_set == "run" and absf(vx) > 20.0:
		state = "land"
		_play("run_land")
	else:
		air_set = "stand"
		state = "land"
		_play("stand_land")

func _on_clip_finished() -> void:
	match state:
		"launch":
			state = "run"
			_play("run_left")
			_set_frame(launch_exit)
		"stop": _enter("idle")
		"pickup":
			carrying = true
			_enter("idle")
		"swing":
			_enter("idle")
		"putdown":
			carrying = false
			if carry_kind == "fan":
				var rod_end: Array = clip_meta["fan_putdown"]["rod"][clip_meta["fan_putdown"]["rod"].size() - 1]
				item_pos = Vector2(pos_x - facing * float(rod_end[0]) * clip_scale, GROUND_Y - 3.0)
				fan_facing = facing
			_enter("idle")
		"release":
			_enter("recover")
		"recover":
			_freeze_rest(_cn("recover"))
		"plunge":
			float_y = GROUND_Y - 70.0
			_enter("tread")
		"drown":
			_freeze_rest("water_drown")
			state = "drown"
		"shoved_in":
			_enter("shoved")
		"shoved_out":
			_freeze_rest("shoved_out")
		"engage":
			_enter("hold")
		"to_pull":
			_enter("pull")
		"from_pull":
			_enter("hold")
		"release_hold":
			_enter("idle")
		"release_pull":
			_freeze_rest("grip_release")
		"impact":
			_enter("downed")
		"get_up":
			_freeze_rest("get_up")
		"flinch":
			_freeze_rest("flinch")
		"land":
			if sprite.animation == &"small_jump_land":
				_enter("idle")
			elif sprite.animation == &"run_land":
				if absf(vx) > 20.0:
					state = "run"
					_play("run_left")
					_set_frame(_scaled("run_left", run_exit))
				else:
					_enter("idle")
			else:
				_freeze_rest("stand_land")
		"scared":
			# Freeze on the clip's last frame instead of cutting to the idle loop: its feet differ a
			# little from the idle pose, which showed up as a twitch.
			_freeze_rest("scared_brake")

func _freeze_rest(clip: String) -> void:
	state = "rest"
	sprite.pause()
	anim_playing = false
	_set_frame(frames.get_frame_count(clip) - 1)

func _step(delta: float) -> float:
	# One refresh per engine frame; only a real hitch (frame far from a refresh) uses the measured time.
	var fixed := 1.0 / refresh
	return fixed if absf(delta - fixed) < fixed * 0.5 else delta

func _set_frame(index: int) -> void:
	anim_progress = float(index)
	sprite.frame = index

func _advance_animation(dt: float) -> void:
	if not anim_playing:
		return
	var clip := String(sprite.animation)
	var count := frames.get_frame_count(clip)
	if anim_reverse:
		anim_progress -= frames.get_animation_speed(clip) * anim_speed * dt
		if anim_progress <= 0.0:
			anim_playing = false
			_set_frame(0)
			_on_clip_finished()
		else:
			sprite.frame = int(anim_progress)
		return
	anim_progress += frames.get_animation_speed(clip) * anim_speed * dt
	if frames.get_animation_loop(clip):
		anim_progress = fposmod(anim_progress, float(count))
		sprite.frame = int(anim_progress)
	elif anim_progress >= float(count):
		anim_playing = false
		_set_frame(count - 1)
		_on_clip_finished()
	else:
		sprite.frame = int(anim_progress)

func tick(raw_delta: float, dir: float) -> void:
	var delta := _step(raw_delta)
	# Same rules as level 1 (scripts/core/player_controller.gd): the facing flips the instant a
	# direction is pressed and the boy runs that way straight away; speed follows the key at once,
	# on the ground and in the air.
	var locked := state == "scared" or state == "fall" or state == "impact" or state == "downed" or state == "get_up" or state == "flinch" or _gripping() or _item_busy() or _shoved() or _in_water()
	if dir != 0.0 and not locked:
		facing = dir
	if on_ground:
		coyote = 0.12
	else:
		coyote = maxf(0.0, coyote - delta)
	# Decided before the buffer ages, so a long frame never swallows a press.
	if p_pending:
		if _p_down():
			p_time += delta
			if p_time >= 0.18 and (state == "idle" or state == "rest"):
				p_pending = false
				charge_time = 0.0
				_enter("charge")
		else:
			p_pending = false
			if p_time < 0.18 and (state == "idle" or state == "rest"):
				_enter("putdown")
	if jump_buffer > 0.0 and _can_jump():
		_start_jump()
	jump_buffer = maxf(0.0, jump_buffer - delta)
	var target_speed := dir * (BIG_SPEED if carrying and carry_kind == "big" else run_speed)
	var scared := state == "scared"
	if scared:
		# Stops dead within the first few frames, then stands frozen and relaxes. Input waits.
		_stop_time += delta
		vx = lerpf(_stop_from, 0.0, smoothstep(0.0, 0.3, _stop_time))
	elif state == "tread" or state == "plunge" or state == "drown":
		vx = move_toward(vx, 0.0, 600.0 * delta)
	elif state == "swim":
		vx = move_toward(vx, dir * SWIM_SPEED, 800.0 * delta)
	elif _shoved():
		vx = rock_travel * ROCK_SPEED * (clip_scale / LEVEL1_SCALE)
	elif _item_busy() and not (state == "recover" and _clip_ready(_cn("recover"), 0.5)):
		vx = move_toward(vx, 0.0, 2600.0 * delta)
	elif _gripping():
		var moving := 0.0
		if state == "push" and dir == grip_side:
			moving = grip_side * PUSH_SPEED
		elif state == "pull" and dir == -grip_side:
			moving = -grip_side * PULL_SPEED
		vx = move_toward(vx, moving, 2600.0 * delta)
	elif state == "fall" or state == "impact" or state == "downed" or (state == "get_up" and not _clip_ready("get_up", 0.72)) or (state == "flinch" and not _clip_ready("flinch", 0.35)):
		# No control: a hit or a fall takes the speed away.
		vx = move_toward(vx, 0.0, 2600.0 * delta)
	elif state == "stop" and dir == 0.0:
		_stop_time += delta
		vx = lerpf(_stop_from, 0.0, smoothstep(0.0, 0.8, _stop_time / maxf(0.05, _stop_duration)))
	else:
		vx = move_toward(vx, target_speed, (2300.0 if dir != 0.0 else 3000.0) * delta)
	match state:
		"idle", "rest":
			if dir != 0.0:
				_enter("run" if carrying else "launch")
		"launch":
			if dir == 0.0:
				_enter("stop")
		"run":
			anim_speed = absf(vx) / ref_speed
			if carrying:
				anim_speed = absf(vx) / (BIG_SPEED if carry_kind == "big" else 285.0)  # the carry clips were retimed for these speeds
			if dir == 0.0:
				_enter("idle" if carrying else "stop")
		"stop":
			if dir != 0.0:
				_enter("run")
		"tread":
			if dir != 0.0:
				facing = dir
				_enter("swim")
		"swim":
			if dir == 0.0:
				_enter("tread")
		"hold":
			if dir == grip_side:
				_enter("push")
			elif dir == -grip_side:
				_enter("to_pull")
		"push":
			anim_speed = 1.0 if dir == grip_side else 0.0
			if dir == -grip_side:
				_enter("to_pull")
		"pull":
			anim_speed = 1.0 if dir == -grip_side else 0.0
			if dir == grip_side:
				_enter("from_pull")
		"downed":
			downed_time += delta
			# Lies still for a moment, then any key (or the jump key) gets him up.
			if downed_time > 0.7 and (dir != 0.0 or jump_buffer > 0.0 or downed_time > 3.0):
				jump_buffer = 0.0
				_enter("get_up")
		"get_up":
			if _clip_ready("get_up", 0.72) and dir != 0.0:
				facing = dir
				_enter("launch")
		"flinch":
			if _clip_ready("flinch", 0.35) and dir != 0.0:
				facing = dir
				_enter("launch")
		"land":
			# Never holds the controls: a key press takes over once the impact frames are shown.
			if (sprite.animation == &"stand_land" or sprite.animation == &"small_jump_land") and float(sprite.frame) / frames.get_animation_speed(String(sprite.animation)) >= LANDING_CANCEL_TIME and dir != 0.0:
				_enter("run" if carrying else "launch")
		"charge":
			charge_time += delta
			if not _p_down() and charge_time > 0.05:
				item_thrown = false
				_enter("release")
		"release":
			var meta: Dictionary = clip_meta[_cn("release")]
			if not item_thrown and int(float(sprite.frame) / float(factors[_cn("release")])) >= int(meta.get("release_orig_frame", 9)):
				_throw_item()
		"recover":
			if _clip_ready(_cn("recover"), 0.5) and dir != 0.0:
				facing = dir
				_enter("run")
	if state == "fall":
		anim_speed = fall_anim_speed
	elif state == "shoved":
		anim_speed = 1.5
	elif state != "run" and state != "push" and state != "pull":
		anim_speed = 1.0
	_update_air(delta)
	_advance_animation(delta)
	if _shoved():
		pass
	else:
		pos_x += vx * delta
	_update_rock(delta)
	if _in_water():
		pos_x = clampf(pos_x, POOL_X.x + 40.0, POOL_X.y - 40.0)
	if pos_x < 330.0 or pos_x > 1250.0:
		pos_x = clampf(pos_x, 330.0, 1250.0)
		vx = 0.0
	if state == "tread" or state == "swim":
		float_y = lerpf(float_y, WATER_Y + 16.0, 1.0 - exp(-7.0 * delta))
		sprite.position = Vector2(pos_x, float_y)
	elif state == "drown":
		sink = minf(150.0, sink + 62.0 * delta)
		sprite.position = Vector2(pos_x, WATER_Y - 46.0 + sink)
	else:
		sprite.position = Vector2(pos_x, GROUND_Y + air_y)
	# While he holds the box, the box face stays under his hands; otherwise it stays where it is.
	if state == "hold" or state == "push" or state == "to_pull" or state == "pull" or state == "from_pull":
		grip_dist = lerpf(grip_dist, _hand_distance(), 1.0 - exp(-16.0 * delta))
		box_center = pos_x + grip_side * (grip_dist + BOX_SIZE.x * 0.5)
	box.position = Vector2(box_center, GROUND_Y)
	# The clips face left; facing right is the mirror image.
	sprite.scale = Vector2(clip_scale * (-1.0 if facing > 0.0 else 1.0), clip_scale)
	_update_item(delta)
	_update_old(delta)
	info.text = "A/D 跑（匀速）  松手停  W/空格 跳(按住更高)  B 惊恐急刹(跑动中)  F 跌落  G 受惊  E 抓箱/松手  P 拾取/放下/按住投掷  C 对比旧角色  +/- 大小(%.2f)\n状态 %s   速度 %d   高度 %d" % [clip_scale, state, int(absf(vx)), int(-air_y)]

func _update_air(delta: float) -> void:
	if state == "fall":
		var fs := clip_scale / LEVEL1_SCALE
		vy += GRAVITY * fs * delta
		air_y += vy * delta
		if air_y >= 0.0:
			air_y = 0.0
			vy = 0.0
			on_ground = true
			_enter("impact")
		return
	if state != "air":
		return
	var s := clip_scale / LEVEL1_SCALE
	takeoff_time = maxf(0.0, takeoff_time - delta)
	if not jump_held and vy < JUMP_CUT_SPEED * s:
		vy = JUMP_CUT_SPEED * s
	vy += GRAVITY * s * delta
	air_y += vy * delta
	var clip := _air_clip()
	if sprite.animation != StringName(clip):
		_play(clip)
	if air_y >= 0.0:
		air_y = 0.0
		vy = 0.0
		on_ground = true
		_land()

func _update_old(delta: float) -> void:
	if not old_sprite.visible:
		return
	old_travel += absf(vx) * delta
	var moving := absf(vx) > 25.0
	var index := int(floor(old_travel / (116.0 * clip_scale / 0.9 / 15.0))) % 15
	var path := "%s/run/frame_%02d.png" % [OLD_ROOT, index] if moving else "%s/idle/frame_00.png" % OLD_ROOT
	old_sprite.texture = load(path)
	old_sprite.position = Vector2(pos_x - 260.0, GROUND_Y)
	old_sprite.scale = Vector2(clip_scale * (1.0 if facing > 0.0 else -1.0), clip_scale)
