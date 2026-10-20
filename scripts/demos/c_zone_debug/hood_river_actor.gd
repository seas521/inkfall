extends "res://scripts/actors/hood_frame_actor.gd"

# The hooded boy for the C zone (river, marsh, cliff). The same interface as river_actor.gd, so river_controller.gd
# can use either: it owns the physics, he only draws the pose it hands over.
#
# On top of HoodFrameActor:
# - grip (push / pull the raft and the box): the clips are drawn so his hands rest on the object's side;
#   the push / pull loops are driven by the distance the object travelled, like the previous actor's.
# - a rolling boulder walking him back (`pose.shoved`): shoved_in -> shoved, then shoved_out when it lets go.
# - frozen in fright (`pose.alarm`): the scared pose, held.
# - the water death: plunge, thrash at the surface, sink (the controller moves him; the clips follow its clock).

# px the hands press INTO the object beyond its visible face (the controller sets it): both are black, so a little overlap reads as contact and a gap does not; much more and the hand comes out the other side of a thin post
const GRIP_HAND_HEIGHT := 117.0  # clip px above the feet where the hands are in the grip clips (measured)
const OFFSET_SPEED := 260.0  # px/s: the contact alignment never snaps, a pop reads as a twitch
const ROPE_PICK_SECONDS := 1.10  # the controller's rope_pick_time
const ROPE_LET_GO_SECONDS := 0.40
const FOOT_SINK := 3.0  # px below the contact line
const GRIP_CYCLE_DISTANCE := 73.0  # px of travel per loop (the previous art used 73.5): feet do not slide much
const GRIP_ACTIONS := [&"grip_engage", &"grip_hold", &"push", &"pull", &"grip_release"]
# The fan: the controller locks him for FAN_LOCK_TIME while the clip plays up to FAN_LOCK_FRAMES, then the rest of the
# clip carries on in real time until he moves. The swing plays in full (the wind comes at the power stroke).
const FAN_LOCK_FRAMES := 60.0
const FAN_SWING_FRAMES := 97.0
# Carried, he holds the handle low and the blade rests back over his shoulder, behind him (held straight up in front of
# the chest it looks like a bottle). The angle follows smoothly from where the pick-up clip left it.
const FAN_CARRY_ANGLE := 0.95  # rad back from vertical: clearly slanted
const FAN_CARRY_SWAY := 0.07
const FAN_TURN_RATE := 9.0
const FAN_SWING_TURN_BACK_FRAME := 88  # the blade starts back to the shoulder when the hand has come to rest
const FAN_SWING_ROD_LAST_FRAME := 78  # of fan_swing_2: the end of the lift (60 fps frames)
const FAN_LIE_LIFT := 3.0  # px: the rod runs along the ground, so a flat blade centred on it would sink into the soil; its underside rests on it instead
const FAN_BEND_LAG := 2.9  # px of lag per rad/s of the handle turning
const FAN_BEND_LIMIT := 34.0
const FAN_FLAT_MIN := 0.17  # share of its width the blade shows lying flat (the same as the one on the ground)
const DROWN_ACTION: StringName = &"water_drown"
const DROWN_DURATION := 2.70  # the controller's drown clock (drown_manifest.gd)
const DROWN_STRUGGLE := 1.70
# The controller places the drowning actor for the previous 8-frame clip; the hooded boy's clips are rooted
# differently, so the body is moved by these (px):
const TREAD_RAISE := 10.0
const DROWN_RAISE := 72.0

var grip_distance := 0.0
var locomotion_hold_time := 0.0  # unused: kept for the controller's interface
var support_offset := 0.0
var support_valid := false
var contact_sink := 4.0
var contact_reach := 22.5  # px from his centre to the side of the object his hands rest on
var held_clip: StringName = &"grip_hold"
var held_frame := 0
var movement_clip: StringName = &""
var movement_start_distance := 0.0
var was_shoved := false
var grip_offset_x := 0.0
var rope_allowed := false  # the boat has a rope; the broken box does not
var rope_hold := 0.0  # set by the controller: how much of the rope is in his hand
var release_from_pull := false
var fan_tail_clip: StringName = &""
var fan_angle := 0.0
var fan_position := Vector2.ZERO
var fan_local_last := Vector2.ZERO  # the handle in the body's space, last frame
var fan_residual := Vector2.ZERO
var fan_was_rod_driven := false
var fan_flat := 1.0
var fan_bend := 0.0  # px the tip of the blade lags to the side
var fan_bend_speed := 0.0
var fan_previous_angle := 0.0
var fan_ground_target := Vector2.ZERO  # set by the controller: where the blade lies (or will lie) on the ground

func _ready() -> void:
	super._ready()
	load_zone("river")
	load_group("shove")

func reset_grip_animation() -> void:
	held_clip = &"grip_hold"
	held_frame = 0
	movement_clip = &""
	movement_start_distance = grip_distance

# The player's capsule is round at the bottom, so on slopes, planks and the raft his feet would hover above the surface.
# Rays from the visible sole down to what he stands on give the small drop that puts them on it (the previous actor
# does the same with surface_contact.gd).
func apply_surface_contact(delta: float, body: CharacterBody2D, grounded: bool) -> void:
	var target := 0.0
	support_valid = false
	# Climbing: once he is over the ledge (knees, hands, then feet on it) the picture is sunk onto the surface by the same few pixels
	# a standing figure is, so that by the last frame it is exactly where the idle will draw him: no gap while he kneels on the
	# ledge and no drop of a few pixels when the idle takes over.
	if pose.action == ActorPoseState.ACTION_CLIMB:
		# (a fixed sink: the rays under a kneeling or dangling body find different things from frame to frame)
		var progress := float(pose.action_progress)
		# Sunk onto the surface from the moment his hands are on the ledge (the lead-in ends at about 0.2): hands that rest on the
		# top edge float above it by a bright sliver otherwise. A pixel deeper while he kneels on it, then back to the idle's
		# FOOT_SINK by the end.
		var kneel := smoothstep(0.56, 0.62, progress) * (1.0 - smoothstep(0.76, 0.88, progress))
		support_offset = FOOT_SINK * smoothstep(0.12, 0.27, progress) + 1.0 * kneel
		support_valid = false
		position.y += support_offset
		return
	if grounded and sprite.visible and sprite.texture != null:
		var best := INF
		var space := body.get_world_2d().direct_space_state
		for pixel in _sole_points_of_frame():
			var foot := sprite.to_global(pixel)
			var query := PhysicsRayQueryParameters2D.create(foot - Vector2(0, 12), foot + Vector2(0, 18), body.collision_mask, [body.get_rid()])
			var hit := space.intersect_ray(query)
			if hit.is_empty() or Vector2(hit.normal).dot(Vector2.UP) < cos(body.floor_max_angle):
				continue
			best = minf(best, float(hit.position.y) - foot.y)
		if best != INF:
			support_valid = true
			target = clampf(best, -8.0, 12.0)
	if grounded:
		# The ink around every step, plank and floor is soft: its visible edge lies a little under the collision line, and
		# the silhouette's own edge is softened too, so a foot exactly on the line reads as hovering. Down a little more.
		target += FOOT_SINK
	# a sub-pixel change of the surface under the sole must not make a still figure shiver
	if support_valid and absf(target - support_offset) < 0.6:
		target = support_offset
	support_offset = move_toward(support_offset, target, delta * 100.0) if delta > 0.0 else target
	position.y += support_offset

const Soles = preload("res://scripts/actors/hood_actor_soles.gd")
var sole_cache := {}

# The sole points of the frame being shown. They are precomputed (build_hood_soles.py): reading them off the texture
# stalls the first time each frame is shown (a hitch when an animation plays for the first time).
func _sole_points_of_frame() -> PackedVector2Array:
	var key := "%s/%d" % [String(current_clip), current_frame_index]
	if sole_cache.has(key):
		return sole_cache[key]
	var frames: Array = Soles.SOLES.get(String(current_clip), [])
	if current_frame_index >= frames.size():
		return _sole_points(sprite.texture)
	var flat: Array = frames[current_frame_index]
	var points := PackedVector2Array()
	for k in range(0, flat.size() - 1, 2):
		points.append(Vector2(float(flat[k]), float(flat[k + 1])))
	sole_cache[key] = points
	return points

func _sole_points(texture: Texture2D) -> PackedVector2Array:
	var key := texture.get_instance_id()
	if sole_cache.has(key):
		return sole_cache[key]
	var points := PackedVector2Array()
	var image := texture.get_image()
	if image != null and image.is_compressed():
		if image.decompress() != OK:
			image = null
	if image == null:
		# fall back to the bottom edge of the cropped frame (minus the 5 px margin the packer adds)
		var size := texture.get_size()
		for fraction in [0.3, 0.5, 0.7]:
			points.append(Vector2(size.x * fraction, size.y - 5.0))
	else:
		var bounds := image.get_used_rect()
		var bottom := bounds.end.y - 1
		for x in range(bounds.position.x, bounds.end.x, 3):
			for y in range(bottom, maxi(bounds.position.y, bottom - 12) - 1, -1):
				if image.get_pixel(x, y).a > 0.6:
					points.append(Vector2(x + 0.5, y + 1.0))
					break
	sole_cache[key] = points
	return points

func is_swinging() -> bool:
	return current_clip == &"fan_swing_2"

func fan_hand_position() -> Vector2:
	var hand = hand_local()
	if hand == null:
		return to_global(Vector2(float(pose.facing) * 14.0, -32.0))
	return body.to_global(hand)

func fan_swing_angle() -> float:
	return 0.9

# Places and turns the fan node: from the rod recorded in the clip while he picks it up, swings it and puts it down,
# from his hand while he carries it. (The leaf is drawn by the controller's fan node.)
func drive_fan(fan: Node2D, fan_scale: float) -> void:
	var facing := float(pose.facing)
	var carry_angle := -facing * FAN_CARRY_ANGLE
	if current_clip == &"small_run_l1":
		carry_angle += facing * sin(float(current_frame_index) / 26.0 * TAU) * FAN_CARRY_SWAY
	var angle := carry_angle
	var behind := true  # carried, the blade is behind his shoulder
	var rod_driven := false
	# Where the handle is held, in the body's own space, so it goes wherever the body goes: walking, jumping, turning.
	# (An earlier version smoothed the position in the world: the faster he moved, the further the fan lagged behind him.)
	var hand = hand_local()
	var target_local: Vector2 = hand if hand != null else body.to_local(to_global(Vector2(facing * 14.0, -32.0)))
	var data = Manifest.CLIPS.get(String(current_clip))
	var clip_name := String(current_clip)
	if data != null and data.has("rod") and clip_name.begins_with("fan_"):
		var rod: Array = data["rod"]
		# The hand (the rod's near end) is tracked all the way, but the swing clip's rod DIRECTION is only good up to the end
		# of the lift: after that the rod is hidden behind the body and points at the floor. So the handle goes on following
		# the hand, which stays at his chest while the arm settles, and the blade only turns back to the shoulder once the
		# hand has it (it used to go to the shoulder first, with the hand still on its way).
		var last_good := FAN_SWING_ROD_LAST_FRAME if current_clip == &"fan_swing_2" else int(data["frames"]) - 1
		var at := clampf(float(current_frame_index) * float(rod.size()) / float(data["frames"]), 0.0, float(rod.size() - 1))
		var i := int(at)
		var j := mini(i + 1, rod.size() - 1)
		var blend := at - float(i)
		var near_local := Vector2(lerpf(float(rod[i][0]), float(rod[j][0]), blend), lerpf(float(rod[i][1]), float(rod[j][1]), blend))
		var good_at := clampf(float(mini(current_frame_index, last_good)) * float(rod.size()) / float(data["frames"]), 0.0, float(rod.size() - 1))
		var gi := int(good_at)
		var gj := mini(gi + 1, rod.size() - 1)
		var gblend := good_at - float(gi)
		var good_near := Vector2(lerpf(float(rod[gi][0]), float(rod[gj][0]), gblend), lerpf(float(rod[gi][1]), float(rod[gj][1]), gblend))
		var good_tip := Vector2(lerpf(float(rod[gi][2]), float(rod[gj][2]), gblend), lerpf(float(rod[gi][3]), float(rod[gj][3]), gblend))
		# at the very end the handle comes to where the carry pose holds it
		var to_hold := 0.0
		if current_clip == &"fan_swing_2":
			to_hold = smoothstep(76.0, 86.0, float(current_frame_index))
		elif current_clip == &"fan_pickup":
			to_hold = smoothstep(90.0, 100.0, float(current_frame_index))
		if to_hold > 0.0 and has_clip(&"small_hold"):
			var hold_point: Array = Manifest.CLIPS["small_hold"]["hold_points"][0]
			near_local = near_local.lerp(Vector2(float(hold_point[0]), float(hold_point[1])), to_hold)
		target_local = near_local
		if current_clip == &"fan_pickup":
			# the blade starts where it lay on the ground and only then goes with the rod
			target_local = near_local.lerp(body.to_local(fan_ground_target), 1.0 - smoothstep(0.0, 14.0, float(current_frame_index)))
		elif current_clip == &"fan_putdown":
			target_local = near_local.lerp(body.to_local(fan_ground_target), smoothstep(30.0, 59.0, float(current_frame_index)))
		var good_near_world := body.to_global(good_near)
		var good_tip_world := body.to_global(good_tip)
		var rod_angle := atan2(good_tip_world.x - good_near_world.x, -(good_tip_world.y - good_near_world.y))
		if current_frame_index <= last_good:
			angle = rod_angle
			behind = (i in data["hidden_rod_frames"]) or (j in data["hidden_rod_frames"] and blend > 0.5)
			rod_driven = true
		else:
			# the hand holds it up as it was; only near the end of the clip does the blade turn back to the shoulder
			behind = true
			if current_frame_index < FAN_SWING_TURN_BACK_FRAME:
				angle = rod_angle
			rod_driven = false
	# Changing from the rod to the hand (or back) may leave a small gap: it closes in a few frames, in the body's space
	if rod_driven != fan_was_rod_driven:
		fan_residual = fan_local_last - target_local
		if fan_residual.length() > 60.0:
			fan_residual = Vector2.ZERO
	fan_was_rod_driven = rod_driven
	fan_residual = Vector2.ZERO if rod_driven else fan_residual * exp(-16.0 * maxf(last_dt, 0.016))
	fan_local_last = target_local + fan_residual
	fan_position = body.to_global(fan_local_last)
	if rod_driven:
		fan_angle = angle
	else:
		fan_angle = lerp_angle(fan_angle, angle, 1.0 - exp(-FAN_TURN_RATE * maxf(last_dt, 0.016)))
	# A flat blade seen from the side: lying or half-raised it is nearly edge-on, and it turns to face the viewer as it
	# comes upright (picking it up or putting it down no longer shows the whole face of the blade lying on the ground).
	# The swing keeps the face-on blade.
	var flat_target := 1.0
	if current_clip != &"fan_swing_2":
		flat_target = lerpf(1.0, FAN_FLAT_MIN, smoothstep(0.70, 1.48, absf(fan_angle)))
	fan_flat = flat_target if rod_driven else lerpf(fan_flat, flat_target, 1.0 - exp(-FAN_TURN_RATE * maxf(last_dt, 0.016)))
	# lying (nearly horizontal) the blade rests ON the ground instead of being pressed into it
	var lying := smoothstep(0.70, 1.48, absf(fan_angle)) if current_clip != &"fan_swing_2" else 0.0
	var lift := FAN_LIE_LIFT * lying
	if current_clip == &"fan_pickup":
		lift *= smoothstep(0.0, 14.0, float(current_frame_index))  # the resting blade on the ground already sits right
	elif current_clip == &"fan_putdown":
		lift *= 1.0 - smoothstep(30.0, 59.0, float(current_frame_index))
	fan.global_position = fan_position + Vector2(0.0, -lift)
	fan.rotation = fan_angle
	# The blade is not stiff: its tip lags behind the turning handle and springs back, past the middle and back again.
	var step := maxf(last_dt, 0.008)
	var omega := clampf(angle_difference(fan_previous_angle, fan_angle) / step, -14.0, 14.0)
	fan_previous_angle = fan_angle
	var bend_target := clampf(-omega * FAN_BEND_LAG * facing, -FAN_BEND_LIMIT, FAN_BEND_LIMIT)
	fan_bend_speed += ((bend_target - fan_bend) * 340.0 - fan_bend_speed * 15.0) * step
	fan_bend = clampf(fan_bend + fan_bend_speed * step, -FAN_BEND_LIMIT, FAN_BEND_LIMIT)
	fan.call("set_bend", fan_bend)
	fan.scale = Vector2(facing * fan_flat, 1.0) * fan_scale
	if rod_driven:
		fan.call("set_grip", false, false)
		fan.z_index = z_index - 1 if behind else z_index + 1
	else:
		# carried: the stalk across his body, open where his fist is, the blade behind his head; the gap is only made where
		# the hand is really known (the carry clips), never while the handle is still on its way to the hand
		fan.call("set_grip", true, hand != null)
		fan.z_index = z_index + 1

func _fan_action_frame() -> Dictionary:
	var progress_now := float(pose.action_progress)
	match pose.action:
		ActorPoseState.ACTION_PICKUP:
			if has_clip(&"fan_pickup"):
				fan_tail_clip = &"fan_pickup"
				return {"clip": &"fan_pickup", "frame": progress_now * FAN_LOCK_FRAMES}
		ActorPoseState.ACTION_PUT_DOWN:
			if has_clip(&"fan_putdown"):
				fan_tail_clip = &"fan_putdown"
				return {"clip": &"fan_putdown", "frame": progress_now * FAN_LOCK_FRAMES}
		ActorPoseState.ACTION_THROW_RELEASE:
			# only standing: swinging on the run keeps the carry legs
			if has_clip(&"fan_swing_2") and pose.grounded and absf(pose.velocity.x) <= 25.0:
				fan_tail_clip = &"fan_swing_2"
				return {"clip": &"fan_swing_2", "frame": progress_now * FAN_SWING_FRAMES}
	return {}

func _tail_after(finished: StringName) -> Array:
	if fan_tail_clip == &"fan_swing_2":
		fan_tail_clip = &""
		return []  # the swing clip already ends in a standing pose
	if (finished == ActorPoseState.ACTION_PICKUP or finished == ActorPoseState.ACTION_PUT_DOWN) and fan_tail_clip != &"":
		var clip := fan_tail_clip
		fan_tail_clip = &""
		return [{"clip": clip, "from": int(FAN_LOCK_FRAMES), "to": -1}]
	return super._tail_after(finished)

func _action_frame() -> Dictionary:
	if pose.action == DROWN_ACTION:
		return _drown_frame()
	if pose.alarm and has_clip(&"scared_brake"):
		return {"clip": &"scared_brake"}  # plays once and holds the last frame
	if pose.shoved and has_clip(&"shoved"):
		was_shoved = true
		movement_clip = &""
		if current_clip == &"shoved" or (current_clip == &"shoved_in" and not playing):
			return {"clip": &"shoved"}
		return {"clip": &"shoved_in"}
	if was_shoved:
		# the boulder let go: he straightens up (a jump or a step cancels it)
		was_shoved = false
		if has_clip(&"shoved_out") and pose.action == ActorPoseState.ACTION_NONE:
			tail = [{"clip": &"shoved_out", "from": 0, "to": -1}]
	if pose.action == &"lever" and has_clip(&"grip_to_pull"):
		# working the stick: the stroke from the pushing stance to the pulling stance follows the lever
		return {"clip": &"grip_to_pull", "frame": clampf(float(pose.action_progress), 0.0, 1.0) * 47.0}
	if pose.action == &"rope_pickup" and has_clip(&"small_pickup") and has_clip(&"grip_release"):
		return _rope_pickup_frame()
	if pose.action in GRIP_ACTIONS and has_clip(&"grip_hold"):
		return _grip_frame()
	if pose.small_item_kind == &"fan" and pose.action in [ActorPoseState.ACTION_PICKUP, ActorPoseState.ACTION_PUT_DOWN, ActorPoseState.ACTION_THROW_RELEASE]:
		return _fan_action_frame()
	return super._action_frame()

# Taking the rope up: the hands leave the hull (the start of the release clip), then he crouches to the rope's end and
# stands up with it (the pick-up clip from where the knees start to bend).
func _rope_pickup_frame() -> Dictionary:
	var time := float(pose.action_progress) * ROPE_PICK_SECONDS
	movement_clip = &""
	if time < ROPE_LET_GO_SECONDS:
		return {"clip": &"grip_release", "frame": time / ROPE_LET_GO_SECONDS * 24.0}
	var crouch := (time - ROPE_LET_GO_SECONDS) / (ROPE_PICK_SECONDS - ROPE_LET_GO_SECONDS)
	held_clip = &"pull"
	held_frame = 0
	return {"clip": &"small_pickup", "frame": lerpf(12.0, 54.0, crouch)}

func _grip_frame() -> Dictionary:
	var progress_now := float(pose.action_progress)
	match pose.action:
		&"grip_engage":
			reset_grip_animation()
			return {"clip": &"grip_engage", "progress": progress_now}
		&"grip_release":
			return {"clip": &"grip_release", "progress": progress_now}
		&"grip_hold":
			# the actual last effort pose, as before
			return {"clip": held_clip, "frame": float(held_frame)}
	# push / pull: the frame follows the distance travelled
	if movement_clip != pose.action:
		movement_clip = pose.action
		movement_start_distance = grip_distance
	var loop_frames := int(Manifest.CLIPS["push"]["frames"])
	var step := int(floor(maxf(0.0, grip_distance - movement_start_distance) / GRIP_CYCLE_DISTANCE * float(loop_frames)))
	var clip: StringName = &"push"
	var index := step % loop_frames
	if pose.action == &"pull":
		var lead := 0 if (rope_allowed and rope_hold > 0.9) else int(Manifest.CLIPS["grip_to_pull"]["frames"])
		if step < lead:
			clip = &"grip_to_pull"
			index = step
		else:
			clip = &"pull"
			index = (step - lead) % int(Manifest.CLIPS["pull"]["frames"])
	held_clip = clip
	held_frame = index
	return {"clip": clip, "frame": float(index)}

func _drown_frame() -> Dictionary:
	var time := float(pose.action_progress) * DROWN_DURATION
	if time < 0.55 and has_clip(&"water_plunge"):
		return {"clip": &"water_plunge", "frame": time / 0.55 * 33.0}
	if time < DROWN_STRUGGLE and has_clip(&"water_tread"):
		return {"clip": &"water_tread"}
	var sink := (time - DROWN_STRUGGLE) / (DROWN_DURATION - DROWN_STRUGGLE)
	var count := int(Manifest.CLIPS["water_drown"]["frames"])
	return {"clip": &"water_drown", "frame": clampf(sink, 0.0, 1.0) * float(count - 1)}

# 0: hands on the hull; 1: holding the boat's rope (pulling). grip_to_pull is where the rope is taken up.
func rope_blend() -> float:
	if not rope_allowed or not (pose.action in GRIP_ACTIONS):
		return 0.0
	return rope_hold

# Where his hand is in the world while he grips (the rope runs to it).
func grip_hand_world() -> Vector2:
	var data = Manifest.CLIPS.get(String(current_clip))
	var distance := 51.0
	var crouch_hand = hand_local() if current_clip == &"small_pickup" else null
	if crouch_hand != null:
		return body.to_global(crouch_hand)
	if data != null and data.has("hand_offset"):
		distance = _hand_distance(data)
	return body.to_global(Vector2(-distance, -GRIP_HAND_HEIGHT))

func _alignment_target(data: Dictionary, scale_value: float) -> float:
	var face := float(pose.facing)
	if pose.action == &"lever":
		return 0.0  # he stands at the stick: it is drawn through his hands, he does not slide to meet it
	if pose.action == &"rope_pickup":
		# the hands leave the hull: the alignment fades with the let-go part, then he is just standing
		if current_clip == &"grip_release" and data.has("hand_offset"):
			var offsets: Array = data.get("hand_offsets", [])
			var first := absf(float(offsets[0])) if not offsets.is_empty() else absf(float(data["hand_offset"]))
			return face * (contact_reach + contact_sink - scale_value * first) * (1.0 - float(current_frame_index) / 24.0)
		return 0.0
	if pose.action in GRIP_ACTIONS and data.has("hand_offset"):
		if pose.action == &"grip_release":
			# let go: the hands leave the object as the body settles, not tracking it frame by frame
			var offsets: Array = data.get("hand_offsets", [])
			var first := absf(float(offsets[0])) if not offsets.is_empty() else absf(float(data["hand_offset"]))
			var held := face * (contact_reach + contact_sink - scale_value * first)
			return 0.0 if release_from_pull else held * (1.0 - smoothstep(0.0, 1.0, float(pose.action_progress)))
		# his hands on the object's side: the body slides so that the hand sits `contact_reach` in front of his centre;
		# holding the rope he stands as the clip was filmed
		return face * (contact_reach + contact_sink - scale_value * _hand_distance(data)) * (1.0 - rope_blend())
	if pose.shoved and data.has("hand_offset"):
		return face * (10.0 - scale_value * _hand_distance(data))
	return 0.0

func _apply() -> void:
	var scale_value: float = DISPLAY_SCALE * float(pose.visual_scale)
	var data = Manifest.CLIPS.get(String(current_clip))
	if pose.action == &"grip_release":
		release_from_pull = held_clip in [&"pull", &"grip_to_pull"]
	var target := _alignment_target(data, scale_value) if data != null else 0.0
	grip_offset_x = move_toward(grip_offset_x, target, OFFSET_SPEED * last_dt) if last_dt > 0.0 else target
	body_offset = Vector2(grip_offset_x, 0.0)
	super._apply()
	if current_clip in [&"water_tread", &"water_swim"]:
		body.position.y -= TREAD_RAISE
	elif current_clip == &"water_drown":
		body.position.y -= DROWN_RAISE

func _hand_distance(data: Dictionary) -> float:
	var offsets: Array = data.get("hand_offsets", [])
	if offsets.is_empty():
		return absf(float(data["hand_offset"]))
	# tracked on the original (24 fps) frames: interpolate between them
	var position_in_list := clampf(float(current_frame_index) * float(offsets.size()) / float(data["frames"]), 0.0, float(offsets.size() - 1))
	var index := int(position_in_list)
	var next_index := mini(index + 1, offsets.size() - 1)
	return absf(lerpf(float(offsets[index]), float(offsets[next_index]), position_in_list - float(index)))
