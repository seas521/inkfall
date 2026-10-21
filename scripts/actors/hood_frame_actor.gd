extends Node2D

# The hooded boy as an actor style (ActorPoseState.STYLE_HOOD). It only READS the pose the controller
# gives every frame (feet, velocity, grounded, facing, ...): the physics stay in the controller.
#
# - The clips are cropped frames, grouped (hood_actor_manifest.gd); a zone loads the groups it uses.
# - Every clip is drawn facing left; facing right is the mirror image about the root point.
# - The animation clock advances by exactly one display refresh per engine frame (like the test scene), so a
#   60fps clip is shown for 2 refreshes per frame on a 120Hz screen instead of a jittery 1-3.
# - The run loop was retimed (run_l1: 20 frames) to be 1.0x at RUN_SPEED at this display scale.

const ActorPoseState = preload("res://scripts/actors/actor_pose_state.gd")
const SmallItemRenderer = preload("res://scripts/actors/small_item_renderer.gd")
const Manifest = preload("res://scripts/actors/hood_actor_manifest.gd")

const DISPLAY_SCALE := 0.42  # the same as the previous actor (a 200 px standing figure -> 84 px)
# The run (Seedance 1427, an upright, weak jog): a 45 frame loop of two steps; as recorded (2.7 steps/s) its feet move at about 78 px/s. He runs
# at HOOD_RUN_SPEED (135 px/s: 78, 100 and 115 were both too slow) and the loop plays 1.25x (HOOD_RUN_ANIM_SPEED is the speed at which it
# plays 1.0x): 3.4 steps/s, the feet slide about 18%. The carrying run (small_run_l1) was cut for 285 px/s.
const START_SKIP := 8  # frames of the start clip left out (60 fps): with the slower build-up (HOOD_START_ACCEL) the first foot plants when the speed is there
const HOOD_RUN_SPEED := 135.0
const HOOD_RUN_ANIM_SPEED := 108.0
const CARRY_RUN_SPEED := 285.0
# (There is no panting / bent-over rest any more: stopping from a run is just stopping. The stagger, panting and straightening-up
# clips were cut: no stand-up could be joined to the idle without a jump.)
# Above this speed a jump is a running jump (the run-up and landing clips of the run); his run is 78 px/s, so the old 120 never
# applied: every jump on the move used the standing set.
const RUN_AIR_SPEED := 45.0
const BREATH_RAMP_TIME := 0.8
const RUNNING_CLIPS := [&"tired_start", &"tired_run", &"small_run_l1"]
const TAKEOFF_TIME := 0.125
const LANDING_CANCEL_TIME := 0.08
const LANDING_CANCEL_TIME_RUN := 0.12
const FALL_CENTRE := 30.0  # px above the feet: the body centre of the 54 px tall physics box
# Frames (of the 60 fps clips) where the action's controller timing meets the clip:
const PICKUP_ACTION_FRAMES := 52.0  # small_pickup 0 -> 52 while the controller locks him (0.87 s), then 52 -> 65 as a tail
const PUT_DOWN_FROM := 65.0  # the pick-up clip backwards 65 -> 30 (0.60 s), then 30 -> 0 as a tail
const PUT_DOWN_TO := 30.0
const PUT_DOWN_HAND_OVER_FRAME := 38  # the stone touches the ground
const THROW_FROM := 8.0  # small_throw_release 8 -> 28 (0.34 s; the wind-up came from the charge clip), then 28 -> 34, then the recover clip
const THROW_TO := 28.0
const THROW_HAND_OVER_FRAME := 17  # the stone leaves the hand (the clip's own release frame)
# Frames of the run loops where a foot comes down (read from the silhouettes' lowest point): the audio steps on these.
const FOOT_CONTACTS := {&"tired_start": [29, 50], &"tired_run": [16, 38], &"small_run_l1": [3, 15]}
static var footstep_serial := 0  # grows by one on every foot-down while running; the surface audio follows it
const KNOCKDOWN_STAGGER_SHARE := 0.6  # of the knock-down action: the stagger, then straight down onto the ground
const KNOCKDOWN_STAGGER_FRAMES := 42  # fall_air after this turns into a flying dive, which is too airborne for a bat hit

var pose
var body: Node2D
var sprite: Sprite2D
var refresh := 60.0
var textures := {}  # clip -> Array[Texture2D]
var loaded_groups := {}
var current_clip: StringName = &"idle_left"
var current_frame_index := 0
var progress := 0.0
var playing := true
var reverse := false
var anim_speed := 1.0
var air_set := "stand"
var takeoff_time := 0.0
var landing_time := 0.0
var previous_grounded := true
var previous_vertical_speed := 0.0
var land_clip: StringName = &"clumsy_stand_land"
# Walking about: idle -> start -> run -> stop -> tired idle -> idle. The clips follow what the player does and never hold the
# controls up: movement, turning and jumping are the controller's, at once; every clip below can be cut short at any frame
# (the table-picked frame of the next clip, and a short cross-fade, hide the change).
var loco: StringName = &"idle"
var run_time := 0.0
var breath_ramp := 1.0
var prev_windup := -1.0  # the gathering for a jump of the last frame (pose.jump_windup)
var windup_set := "stand"
var windup_from := 0
var pending_from := 0
var ghost: Sprite2D
var ghost_time := 0.0
var ghost_total := 0.1
var action_driven := false  # the controller decides how far into the clip he is (action_progress)
var item_node: Node2D
var previous_action: StringName = &"none"
var climb_exit := 0.0
var tail: Array = []  # clips that carry on in real time after a controller action ended (cancelled by moving)
var last_dt := 0.0
var squash := 1.0  # 1 = as he is; smaller = flattened under something heavy (set by the controller)
# Running: he leans into it, head forward, like someone who has been running too long (the clip itself is a clean sprint).
const RUN_LEAN := 0.13  # rad
var run_lean := 0.0
const BREATH_DEPTH := 0.011  # share of his height: about a pixel
const BREATH_RATE := 2.3  # rad/s: a breath every 2.7 s
var breath_time := 0.0
# A collision can flip his speed between 0 and walking speed every frame (the boat sliding away under a held key): the
# run clip is kept for this long after the last real movement instead of flickering with the idle.
const RUN_HOLD_TIME := 0.12
# A moment of "not on the floor" (a step of a slope, a platform that moves, a physics hiccup) is not a fall: the air clips
# need this long off the ground, or a rising jump, before they replace the standing / running clip.
const AIR_GRACE := 0.07
var ungrounded_time := 0.0
var on_ground := true
var run_hold := 0.0
var body_offset := Vector2.ZERO  # px, added to the body (contact alignment in the C zone)
var body_lift := 0.0  # px above the feet the clip root sits (the fall loop is rooted at his centre)

func _ready() -> void:
	refresh = DisplayServer.screen_get_refresh_rate()
	if refresh <= 1.0:
		refresh = 60.0
	body = Node2D.new()
	add_child(body)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # shrunk 2.6x: without mipmaps the edges shimmer as he moves by a fraction of a pixel
	sprite.material = _build_material()
	body.add_child(sprite)
	ghost = Sprite2D.new()
	ghost.centered = false
	ghost.texture_filter = sprite.texture_filter
	ghost.material = sprite.material
	ghost.hide()
	body.add_child(ghost)
	body.move_child(ghost, 0)  # behind the sprite
	item_node = SmallItemRenderer.new()
	item_node.hide()
	body.add_child(item_node)
	hide()

func _build_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float fog_blur = 0.0;  // texels, from the scene's mist
uniform bool monochrome = false;
uniform float texel_scale = 2.6;  // texels per screen pixel (the frames are shrunk about 2.6x on screen)
uniform float soften = 0.8;  // screen pixels of softness every silhouette gets, so its edge is as soft as the ink around it
uniform vec3 ink = vec3(0.022, 0.025, 0.025);  // the scene's black is not (0, 0, 0)

void fragment() {
	// a ring of 8 taps plus the centre: the edge is a soft, even falloff, not a hard cut-out
	vec2 px = TEXTURE_PIXEL_SIZE * (fog_blur + soften * texel_scale);
	vec4 color = texture(TEXTURE, UV) * 0.28;
	color += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.09;
	color += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.09;
	color += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.09;
	color += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.09;
	color += texture(TEXTURE, UV + px * 0.7071) * 0.09;
	color += texture(TEXTURE, UV - px * 0.7071) * 0.09;
	color += texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.7071) * 0.09;
	color += texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.7071) * 0.09;
	if (monochrome) {
		float value = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		color.rgb = vec3(value);
	}
	// black becomes the scene's ink (the orange of the eye stays as it is)
	color.rgb += ink * (1.0 - clamp(dot(color.rgb, vec3(0.333)) * 3.0, 0.0, 1.0));
	COLOR = color * COLOR;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

# --- clip library -------------------------------------------------------------------------------------

func load_zone(zone: String) -> void:
	for group in Manifest.ZONES[zone]:
		load_group(String(group))

func load_group(group: String) -> void:
	if loaded_groups.has(group):
		return
	for clip in Manifest.GROUPS[group]:
		var frames: Array = []
		for index in range(int(Manifest.CLIPS[clip]["frames"])):
			frames.append(load(Manifest.frame_path(clip, index)) as Texture2D)
		textures[clip] = frames
	loaded_groups[group] = true

func unload_group(group: String) -> void:
	if not loaded_groups.has(group):
		return
	for clip in Manifest.GROUPS[group]:
		textures.erase(clip)
	loaded_groups.erase(group)

func has_clip(clip: StringName) -> bool:
	return textures.has(String(clip))

func clip_duration(clip: StringName) -> float:
	var data: Dictionary = Manifest.CLIPS[String(clip)]
	return float(data["frames"]) / float(data["fps"])

# --- playback -----------------------------------------------------------------------------------------

func play(clip: StringName, from_frame := 0, backwards := false) -> void:
	current_clip = clip
	reverse = backwards
	playing = true
	var count := int(Manifest.CLIPS[String(clip)]["frames"])
	progress = float(from_frame) if (not backwards or from_frame > 0) else float(count) - 0.001
	current_frame_index = clampi(int(progress), 0, count - 1)

func _step(delta: float) -> float:
	# One refresh per engine frame; only a real hitch (a frame far from a refresh) uses the measured time.
	var fixed := 1.0 / refresh
	return fixed if absf(delta - fixed) < fixed * 0.5 else delta

func _advance(dt: float) -> void:
	if not playing:
		return
	var data: Dictionary = Manifest.CLIPS[String(current_clip)]
	var count := int(data["frames"])
	var step := float(data["fps"]) * anim_speed * dt
	if reverse:
		progress -= step
		if progress <= 0.0:
			progress = 0.0
			playing = false
	else:
		progress += step
		if progress >= float(count):
			if bool(data["loop"]):
				progress = fposmod(progress, float(count))
			else:
				progress = float(count) - 0.001
				playing = false
	current_frame_index = clampi(int(progress), 0, count - 1)

func is_finished() -> bool:
	return not playing

# --- pose -> clip (P0: idle, run and the jump phases; the actions come in the next phases) -------------

func sync_pose(delta: float, next_pose) -> void:
	pose = next_pose
	show()
	var dt := _step(delta)
	last_dt = dt
	ungrounded_time = 0.0 if pose.grounded else ungrounded_time + dt
	on_ground = pose.grounded or (ungrounded_time < AIR_GRACE and pose.velocity.y > -90.0)
	# the climb ends on the ledge: for a moment the body may not have found the floor yet, which is not a fall and a landing
	climb_exit = 0.3 if pose.action == ActorPoseState.ACTION_CLIMB else maxf(0.0, climb_exit - dt)
	if climb_exit > 0.0:
		on_ground = true
	if pose.grounded and absf(pose.velocity.x) > 25.0:
		run_hold = RUN_HOLD_TIME
	else:
		run_hold = maxf(0.0, run_hold - dt)
	# gathering for a jump on the ground (the controller's jump_windup runs 0 -> 1, then launches him): the takeoff clip is played by
	# that progress, from the frame that looks most like the stride he is in; the rise clip follows at once when he leaves the ground
	if pose.jump_windup >= 0.0 and pose.grounded and prev_windup < 0.0:
		windup_set = "run" if absf(pose.velocity.x) > RUN_AIR_SPEED else "stand"
		windup_from = 0
		if windup_set == "run" and current_clip in [&"tired_run", &"tired_start"] and has_clip(&"clumsy_run_takeoff"):
			var windup_entry: Array = Manifest.CLIPS["clumsy_run_takeoff"].get("entry_from_run", [])
			if not windup_entry.is_empty() and current_clip == &"tired_run":
				windup_from = int(windup_entry[clampi(current_frame_index, 0, windup_entry.size() - 1)])
	if not on_ground and previous_grounded:
		if prev_windup >= 0.0:
			air_set = windup_set
			takeoff_time = 0.0
		else:
			air_set = "run" if absf(pose.velocity.x) > RUN_AIR_SPEED else "stand"
			# a running jump starts from the frame of the run-up that looks most like the stride he is in (table from the build)
			if air_set == "run" and current_clip == &"tired_run" and has_clip(&"clumsy_run_takeoff"):
				var entry: Array = Manifest.CLIPS["clumsy_run_takeoff"].get("entry_from_run", [])
				if not entry.is_empty():
					pending_from = int(entry[clampi(current_frame_index, 0, entry.size() - 1)])
			takeoff_time = TAKEOFF_TIME
		loco = &"idle"
		landing_time = 0.0
	if on_ground and not previous_grounded:
		# Run legs only if he is still running: otherwise the run-landing would run on the spot.
		if _carrying() and has_clip(&"small_jump_land"):
			land_clip = &"small_jump_land"
		else:
			land_clip = &"clumsy_run_land" if (air_set == "run" and absf(pose.velocity.x) > RUN_AIR_SPEED) else &"clumsy_stand_land"
		landing_time = clip_duration(land_clip)
		loco = &"run" if absf(pose.velocity.x) > 25.0 else &"idle"
	takeoff_time = maxf(0.0, takeoff_time - dt)
	if landing_time > 0.0:
		landing_time = maxf(0.0, landing_time - dt)
		var elapsed_landing := clip_duration(land_clip) - landing_time
		# Still on the key: the landing is over as soon as the impact has been shown (a stumble that lasted while he runs on at
		# full speed would hold the picture up); on the key released he stumbles to a stop in full.
		var cancel_after := LANDING_CANCEL_TIME_RUN if land_clip == &"clumsy_run_land" else LANDING_CANCEL_TIME
		if absf(pose.velocity.x) > 25.0 and elapsed_landing >= cancel_after:
			landing_time = 0.0
			pending_from = _run_frame_after_landing()
		elif land_clip == &"clumsy_run_land" and absf(pose.velocity.x) <= 25.0 and elapsed_landing >= 0.04:
			# the key came up (or he ran out of speed): he stops where he is, he does not stumble on with running legs
			land_clip = &"clumsy_stand_land"
			pending_from = mini(int(elapsed_landing * 60.0), 24)
			landing_time = maxf(0.0, clip_duration(land_clip) - float(pending_from) / 60.0)
	var action := _action_frame()
	if action.is_empty() and previous_action != pose.action and tail.is_empty():
		tail = _tail_after(previous_action)
	if not action.is_empty():
		tail.clear()
	if action.is_empty() and _tail_step(dt):
		action_driven = true
	elif action.is_empty():
		action_driven = false
		var wanted := _choose_clip()
		if wanted != current_clip or (not playing and bool(Manifest.CLIPS[String(wanted)]["loop"])):
			if wanted != current_clip:
				_begin_ghost(_blend_time(current_clip, wanted), current_clip == &"climb")
				if (current_clip == &"climb" or current_clip == &"run_stop") and wanted == &"idle_left":
					breath_ramp = 0.0  # the idle's breathing comes in gently, not at full depth on the first frame
			play(wanted, pending_from)
			pending_from = 0
		if wanted == &"tired_run":
			anim_speed = clampf(absf(pose.velocity.x) / HOOD_RUN_ANIM_SPEED, 0.0, 1.5)
		elif wanted == &"small_run_l1":
			anim_speed = absf(pose.velocity.x) / CARRY_RUN_SPEED
		else:
			anim_speed = 1.0
		var before_index := current_frame_index
		_advance(dt)
		if current_clip == &"idle_left":
			# The recorded idle is still for most of its length and then twitches (the hood tip): on a still picture that
			# reads as the figure jerking every second. He stands still and breathes instead (see _apply).
			progress = 0.0
			current_frame_index = 0
		if pose.grounded and FOOT_CONTACTS.has(current_clip):
			_count_footsteps(before_index, current_frame_index)
	else:
		# the end of the climb is a tired, hunched stance: he stays there (bent over, panting) until he moves
		# (the climb ends ON the idle picture: the clip morphs into it, so the idle takes over without a change on the screen)
		loco = &"idle"
		var wanted_clip: StringName = action["clip"]
		if wanted_clip != current_clip:
			if wanted_clip == &"climb" or current_clip == &"climb":
				_begin_ghost(_blend_time(current_clip, wanted_clip), true)
			play(wanted_clip)
		if action.has("frame"):
			var frame_count := int(Manifest.CLIPS[String(wanted_clip)]["frames"])
			progress = clampf(float(action["frame"]), 0.0, float(frame_count - 1))
			current_frame_index = int(progress)
			playing = false
		elif action.has("progress"):
			# the controller's action clock decides how far into the clip he is
			var count := int(Manifest.CLIPS[String(wanted_clip)]["frames"])
			progress = clampf(float(action["progress"]), 0.0, 1.0) * float(count - 1)
			current_frame_index = clampi(int(progress), 0, count - 1)
			playing = false
		else:
			anim_speed = 1.0
			_advance(dt)
		action_driven = true
	body_lift = FALL_CENTRE if current_clip == &"fall_loop" else 0.0
	_apply()
	previous_action = pose.action
	prev_windup = pose.jump_windup if pose.grounded else -1.0
	previous_grounded = on_ground
	previous_vertical_speed = pose.velocity.y

func _action_frame() -> Dictionary:
	# Gathering for a jump: the takeoff clip, by the controller's progress
	if pose.jump_windup >= 0.0 and pose.grounded and pose.action == ActorPoseState.ACTION_NONE:
		var gather_clip := StringName("clumsy_%s_takeoff" % windup_set)
		if has_clip(gather_clip):
			var gather_last := float(int(Manifest.CLIPS[String(gather_clip)]["frames"]) - 1)
			return {"clip": gather_clip, "frame": lerpf(float(windup_from), gather_last, clampf(pose.jump_windup, 0.0, 1.0))}
	# What the controller is doing to him (knock-down, getting up, a fall, a hit) decides the clip.
	var progress_now := float(pose.action_progress)
	match pose.action:
		ActorPoseState.ACTION_KNOCKDOWN:
			if progress_now < KNOCKDOWN_STAGGER_SHARE:
				var stagger := progress_now / KNOCKDOWN_STAGGER_SHARE
				return {"clip": &"fall_air", "progress": stagger * float(KNOCKDOWN_STAGGER_FRAMES) / float(int(Manifest.CLIPS["fall_air"]["frames"]) - 1)}
			return {"clip": &"fall_impact", "progress": (progress_now - KNOCKDOWN_STAGGER_SHARE) / (1.0 - KNOCKDOWN_STAGGER_SHARE)}
		ActorPoseState.ACTION_DOWNED:
			return {"clip": &"downed"}
		ActorPoseState.ACTION_FALL_IMPACT:
			return {"clip": &"fall_impact", "progress": progress_now}
		ActorPoseState.ACTION_FALL_DOWNED:
			return {"clip": &"downed"}
		ActorPoseState.ACTION_GET_UP:
			return {"clip": &"get_up", "progress": progress_now}
		ActorPoseState.ACTION_UNCONTROLLED_FALL:
			return {"clip": &"fall_loop"}
		ActorPoseState.ACTION_HIT:
			return {"clip": &"flinch", "progress": progress_now * 0.4}
		ActorPoseState.ACTION_CLIMB:
			if pose.grab_frame >= 0 and has_clip(&"grab_bridge"):
				return {"clip": &"grab_bridge", "frame": float(pose.grab_frame)}
			if has_clip(&"climb"):
				return {"clip": &"climb", "progress": progress_now}
		ActorPoseState.ACTION_PICKUP:
			if has_clip(&"small_pickup"):
				return {"clip": &"small_pickup", "frame": progress_now * PICKUP_ACTION_FRAMES}
		ActorPoseState.ACTION_PUT_DOWN:
			if has_clip(&"small_pickup"):
				return {"clip": &"small_pickup", "frame": lerpf(PUT_DOWN_FROM, PUT_DOWN_TO, progress_now)}
		ActorPoseState.ACTION_THROW_RELEASE:
			if has_clip(&"small_throw_release"):
				return {"clip": &"small_throw_release", "frame": lerpf(THROW_FROM, THROW_TO, progress_now)}
		ActorPoseState.ACTION_THROW_CHARGE:
			# the wind-up plays in real time while he stands; walking with a stone in hand keeps the carry clips
			if has_clip(&"small_throw_charge") and pose.grounded and absf(pose.velocity.x) <= 25.0:
				return {"clip": &"small_throw_charge"}
	return {}

func _tail_after(finished: StringName) -> Array:
	match finished:
		ActorPoseState.ACTION_PICKUP:
			return [{"clip": &"small_pickup", "from": int(PICKUP_ACTION_FRAMES), "to": -1}]
		ActorPoseState.ACTION_PUT_DOWN:
			return [{"clip": &"small_pickup", "from": int(PUT_DOWN_TO), "to": 0, "backwards": true}]
		ActorPoseState.ACTION_THROW_RELEASE:
			return [
				{"clip": &"small_throw_release", "from": int(THROW_TO), "to": 34},
				{"clip": &"small_throw_recover", "from": 0, "to": -1},
			]
	return []

func _tail_step(dt: float) -> bool:
	if tail.is_empty():
		return false
	if not pose.grounded or absf(pose.velocity.x) > 25.0:
		tail.clear()
		return false
	var part: Dictionary = tail[0]
	var clip: StringName = part["clip"]
	if not has_clip(clip):
		tail.clear()
		return false
	if not part.has("started"):
		part["started"] = true
		play(clip, int(part["from"]), bool(part.get("backwards", false)))
	anim_speed = 1.0
	_advance(dt)
	var done := not playing
	var stop_at := int(part["to"])
	if stop_at >= 0:
		done = done or (current_frame_index <= stop_at if reverse else current_frame_index >= stop_at)
	if done:
		tail.pop_front()
		if tail.is_empty():
			return false
	return true

func _choose_clip() -> StringName:
	if _carrying() and has_clip(&"small_hold"):
		if not on_ground:
			var carry_phase := "fall"
			if takeoff_time > 0.0:
				carry_phase = "takeoff"
			elif pose.velocity.y < -85.0:
				carry_phase = "rise"
			elif pose.velocity.y < 95.0:
				carry_phase = "apex"
			return StringName("small_jump_%s" % carry_phase)
		if landing_time > 0.0:
			return land_clip
		loco = &"idle"
		return &"small_run_l1" if _moving_now() else &"small_hold"
	if not on_ground:
		var phase := "fall"
		if takeoff_time > 0.0:
			phase = "takeoff"
		elif pose.velocity.y < -85.0:
			phase = "rise"
		elif pose.velocity.y < 95.0:
			phase = "apex"
		return StringName("clumsy_%s_%s" % [air_set, phase])
	if landing_time > 0.0:
		return land_clip
	return _locomotion_clip()

func _apply() -> void:
	var clip := String(current_clip)
	if not textures.has(clip):
		sprite.hide()
		return
	var data: Dictionary = Manifest.CLIPS[clip]
	var rect: Array = data["rects"][current_frame_index]
	var root: Array = data["root"]
	sprite.show()
	sprite.texture = textures[clip][current_frame_index]
	sprite.position = Vector2(float(rect[0]) - float(root[0]), float(rect[1]) - float(root[1]))
	var scale_value: float = DISPLAY_SCALE * float(pose.visual_scale)
	# The clips face left; facing right is the mirror image.
	# The shaft entry (drop, landing, lying, getting up) is played facing right, which is where he walks on to; the
	# controller marks those phases with clip_flip_h (the previous actor's clips faced the other way).
	var face: float = 1.0 if pose.clip_flip_h else float(pose.facing)
	body.scale = Vector2(-face * scale_value, scale_value)
	breath_time += last_dt
	var lean_target := RUN_LEAN if current_clip == &"small_run_l1" else 0.0
	run_lean = move_toward(run_lean, lean_target, 0.9 * maxf(last_dt, 0.0))
	body.rotation = face * run_lean
	if current_clip == &"idle_left" or current_clip == &"small_hold":
		breath_ramp = minf(1.0, breath_ramp + last_dt / BREATH_RAMP_TIME)
		body.scale.y *= 1.0 + BREATH_DEPTH * breath_ramp * sin(breath_time * BREATH_RATE)
	if squash < 0.999:
		body.scale = Vector2(body.scale.x * (1.0 + (1.0 - squash) * 0.5), body.scale.y * squash)
	if ghost_time > 0.0:
		ghost_time = maxf(0.0, ghost_time - last_dt)
		ghost.modulate.a = smoothstep(0.0, 1.0, ghost_time / maxf(ghost_total, 0.001)) * 0.85
		if ghost_time <= 0.0:
			ghost.hide()
	body.position = Vector2(0.0, -body_lift * scale_value) + body_offset
	position = pose.feet
	var fade := 1.0
	if pose.failure_time > 0.0:
		fade = 1.0 - smoothstep(0.80, 1.0, pose.failure_time / maxf(0.01, pose.failure_duration))
	modulate.a = fade
	var material := sprite.material as ShaderMaterial
	material.set_shader_parameter("fog_blur", pose.fog_blur)
	material.set_shader_parameter("monochrome", pose.monochrome)
	material.set_shader_parameter("texel_scale", 1.0 / maxf(scale_value, 0.05))
	_update_item(scale_value)

# --- the item in his hand ---------------------------------------------------------------------------

func _update_item(scale_value: float) -> void:
	var kind: StringName = pose.small_item_kind
	if kind == &"fan":
		item_node.hide()  # the controller draws the fan, from hand_local() / the rod
		return
	var clip := String(current_clip)
	var data = Manifest.CLIPS.get(clip)
	var wanted_local = null
	if kind != &"" and data != null and data.has("hold_points") and textures.has(clip):
		var points: Array = data["hold_points"]
		# the hand points were tracked on the original (24 fps) frames: interpolate between them
		var position_in_points := clampf(float(current_frame_index) * float(points.size()) / float(data["frames"]), 0.0, float(points.size() - 1))
		var index := int(position_in_points)
		var next_index := mini(index + 1, points.size() - 1)
		var hand := Vector2(float(points[index][0]), float(points[index][1])).lerp(
			Vector2(float(points[next_index][0]), float(points[next_index][1])), position_in_points - float(index))
		match pose.action:
			ActorPoseState.ACTION_PICKUP:
				if current_clip == &"small_pickup" and current_frame_index < _grasp_frame():
					# still reaching down: the stone lies where it was
					if pose.small_item_origin.x > -9000.0:
						wanted_local = body.to_local(pose.small_item_origin)
				else:
					wanted_local = hand
			ActorPoseState.ACTION_PUT_DOWN:
				if current_frame_index > PUT_DOWN_HAND_OVER_FRAME:
					wanted_local = hand
			ActorPoseState.ACTION_THROW_RELEASE:
				if current_frame_index < THROW_HAND_OVER_FRAME:
					wanted_local = hand
			ActorPoseState.ACTION_THROW_CHARGE:
				wanted_local = hand
			_:
				if pose.held >= 0:
					wanted_local = hand
	if wanted_local == null:
		item_node.hide()
		return
	item_node.call("configure", kind, float(pose.small_item_radius) / scale_value)
	item_node.position = wanted_local
	item_node.show()

func _moving_now() -> bool:
	return absf(pose.velocity.x) > 25.0 or (run_hold > 0.0 and current_clip in RUNNING_CLIPS)

# What he does on the ground, from what the player does: the controller has already moved him (instantly); this only picks
# the picture, and the picture never holds the controls up.
func _locomotion_clip() -> StringName:
	var moving := _moving_now()
	match loco:
		&"idle":
			run_time = 0.0
			if moving:
				loco = &"start"
				pending_from = START_SKIP  # the first frames are only the weight shifting; the body is moving already
				return &"tired_start"
			return &"idle_left"
		&"start":
			run_time += last_dt
			if not moving:
				loco = &"idle"
				return &"idle_left"
			if current_clip == &"tired_start" and not playing:
				loco = &"run"  # the start ends on the frame the loop begins with
				return &"tired_run"
			return &"tired_start"
		&"run":
			run_time += last_dt
			if not moving:
				# The run-to-stand clip (it starts from the run, steps once more, straightens and ends ON the idle picture). It
				# starts at the frame that looks most like the stride he is in; the body has stopped already.
				loco = &"stop"
				pending_from = _stop_table("entry_from_run", current_frame_index) if has_clip(&"run_stop") else 0
				return &"run_stop" if has_clip(&"run_stop") else &"idle_left"
			return &"tired_run"
		&"stop":
			if moving:
				loco = &"run"  # off again at once, from the stride that looks like where the stop is
				pending_from = _stop_table("exit_to_run", current_frame_index)
				return &"tired_run"
			if current_clip == &"run_stop" and not playing:
				loco = &"idle"
				return &"idle_left"
			return &"run_stop"
	return &"idle_left"

# A table of the run_stop clip: entry_from_run (a tired_run frame -> where in the stop to start) or exit_to_run (a stop frame -> the
# tired_run frame to continue from).
func _stop_table(table: String, index: int) -> int:
	var data: Dictionary = Manifest.CLIPS["run_stop"]
	if not data.has(table):
		return 0
	var values: Array = data[table]
	if table == "exit_to_run" and current_clip != &"run_stop":
		return 0
	if table == "entry_from_run" and current_clip != &"tired_run":
		return 0
	return int(values[clampi(index, 0, values.size() - 1)])

# The run-landing carries on running: the frame of tired_run that looks like the landing frame he is on.
func _run_frame_after_landing() -> int:
	if land_clip != &"clumsy_run_land":
		return 0
	var table: Array = Manifest.CLIPS["clumsy_run_land"].get("exit_to_run", [])
	if table.is_empty():
		return 0
	return int(table[clampi(current_frame_index, 0, table.size() - 1)])

# How long to cross-fade from one clip into the next: none where the next clip begins on the frame the last one ends
# on, a little where two poses are merely close, longer from the bent-over panting back to standing.
func _blend_time(from_clip: StringName, to_clip: StringName) -> float:
	if from_clip == &"tired_start" and to_clip == &"tired_run":
		return 0.0
	if from_clip == &"idle_left" and to_clip == &"tired_start":
		return 0.06  # the start begins a few frames in
	if from_clip == &"grab_bridge" or to_clip == &"grab_bridge":
		return 0.0  # the bridge is made of in-between frames: nothing to hide
	if (from_clip == &"climb" or from_clip == &"run_stop") and to_clip == &"idle_left":
		return 0.0  # these clips end on the idle picture itself
	if from_clip == &"tired_run" and to_clip == &"run_stop" or from_clip == &"run_stop" and to_clip == &"tired_run":
		return 0.05
	if from_clip == &"climb" or to_clip == &"climb":
		return 0.15
	if String(from_clip).begins_with("clumsy_") or String(to_clip).begins_with("clumsy_"):
		return 0.05
	if from_clip in [&"tired_run", &"tired_start"] or to_clip in [&"tired_run", &"idle_left"]:
		return 0.08
	return 0.0

func _begin_ghost(duration: float, root_moved := false) -> void:
	if duration <= 0.0 or sprite.texture == null or not sprite.visible:
		return
	ghost.texture = sprite.texture
	# the old picture stays where it was drawn, even if the new clip is rooted somewhere else (the climb is rooted at the ledge)
	var scale_value: float = DISPLAY_SCALE * float(pose.visual_scale)
	var face: float = 1.0 if pose.clip_flip_h else float(pose.facing)
	var shift: Vector2 = (position - pose.feet) if root_moved else Vector2.ZERO
	ghost.position = sprite.position + Vector2(shift.x / (-face * scale_value), shift.y / scale_value)
	ghost_total = duration
	ghost_time = duration
	ghost.show()

func _carrying() -> bool:
	# a stone in the lab's levels (held index) or anything the controller says he carries (the C zone's fan)
	return pose.held >= 0 or (pose.equipment == ActorPoseState.EQUIPMENT_THROWABLE and pose.action == ActorPoseState.ACTION_NONE)

# Where the hand is in body space for the current frame (null: the clip has no hand data). The hand points were
# tracked on the original (24 fps) frames, so the point is interpolated.
func hand_local():
	var data = Manifest.CLIPS.get(String(current_clip))
	if data == null or not data.has("hold_points"):
		return null
	var points: Array = data["hold_points"]
	var position_in_points := clampf(float(current_frame_index) * float(points.size()) / float(data["frames"]), 0.0, float(points.size() - 1))
	var index := int(position_in_points)
	var next_index := mini(index + 1, points.size() - 1)
	return Vector2(float(points[index][0]), float(points[index][1])).lerp(
		Vector2(float(points[next_index][0]), float(points[next_index][1])), position_in_points - float(index))

func _grasp_frame() -> int:
	var data: Dictionary = Manifest.CLIPS["small_pickup"]
	return int(round(float(data["grasp_orig_frame"]) * float(data["frame_factor"])))

func _count_footsteps(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return
	var count := int(Manifest.CLIPS[String(current_clip)]["frames"])
	var index := from_index
	var guard := 0
	while index != to_index and guard < count:
		index = (index + 1) % count
		guard += 1
		if index in FOOT_CONTACTS[current_clip]:
			footstep_serial += 1
