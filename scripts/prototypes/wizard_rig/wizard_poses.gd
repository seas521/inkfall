extends RefCounted

# Pose library for the wizard rig. Angles are degrees in the rig's "forward" convention.
# dy is pelvis height change in screen pixels (negative = up).

const Z := {}

static func zero() -> Dictionary:
	return {}

static func idle(t: float) -> Dictionary:
	var breath := sin(t * 1.9)
	return {
		&"spine": 1.5 + breath * 0.9,
		&"head": -1.0 + sin(t * 1.9 - 0.7) * 1.2 + sin(t * 0.55) * 1.6,
		&"arm_near_up": 7.0 + breath * 1.6, &"arm_near_fore": 8.0,
		&"arm_far_up": -6.0 - breath * 1.2, &"arm_far_fore": 6.0,
		&"thigh_far": -2.0, &"thigh_near": 2.0,
		&"shin_far": 2.0, &"shin_near": 2.0,
		&"pelvis_dy": breath * 0.5,
	}

# r: 0 = walk, 1 = full run. p: gait phase in radians. leg_px: length of the leg in screen pixels.
static func locomotion(p: float, r: float, leg_px: float) -> Dictionary:
	var thigh := lerpf(26.0, 46.0, r)
	var bend := lerpf(40.0, 82.0, r)
	var swing := lerpf(24.0, 58.0, r)
	var elbow := lerpf(12.0, 74.0, r)
	var lean := lerpf(4.0, 17.0, r)
	var pose := {}
	for side in ["far", "near"]:
		var phase := p if side == "far" else p + PI
		pose[StringName("thigh_" + side)] = thigh * sin(phase)
		pose[StringName("shin_" + side)] = 5.0 + bend * pow(maxf(0.0, cos(phase + 0.15)), 1.3)
		pose[StringName("foot_" + side)] = -9.0 * sin(phase) + 8.0 * maxf(0.0, cos(phase))
	# Arms swing against the legs: the near arm goes with the far leg.
	var near_swing := sin(p)
	pose[&"arm_near_up"] = 8.0 + swing * near_swing * 1.0
	pose[&"arm_far_up"] = -6.0 - swing * near_swing * 0.85
	pose[&"arm_near_fore"] = elbow + maxf(0.0, near_swing) * 26.0 * (0.4 + r)
	pose[&"arm_far_fore"] = elbow * 0.9 + maxf(0.0, -near_swing) * 26.0 * (0.4 + r)
	pose[&"spine"] = lean + 1.4 * sin(2.0 * p)
	pose[&"head"] = -lean * 0.55 + 1.6 * sin(2.0 * p + 0.8)
	# The planted leg is shorter than the body is tall when it is angled: lower the pelvis by exactly
	# that amount so the foot stays on the ground, and lift it in the passing pose.
	var spread := thigh * absf(sin(p))
	pose[&"pelvis_dy"] = leg_px * (1.0 - cos(deg_to_rad(spread))) + lerpf(1.0, 4.0, r)
	pose[&"pelvis_rot"] = 0.0
	return pose

static func air(vy: float, landing := 0.0) -> Dictionary:
	# vy: -1 rising ... +1 falling.
	var rise := clampf(-vy, 0.0, 1.0)
	var fall := clampf(vy, 0.0, 1.0)
	var pose := {
		&"spine": lerpf(8.0, 4.0, fall) - landing * 14.0,
		&"head": -4.0 - rise * 4.0 + landing * 6.0,
		&"arm_near_up": 28.0 + rise * 92.0 + fall * 62.0 - landing * 16.0,
		&"arm_near_fore": 22.0 + rise * 8.0,
		&"arm_far_up": 18.0 + rise * 72.0 + fall * 70.0 - landing * 22.0,
		&"arm_far_fore": 18.0,
		&"thigh_near": 22.0 + rise * 28.0 - fall * 4.0 + landing * 32.0,
		&"shin_near": 28.0 + rise * 48.0 - fall * 20.0 + landing * 52.0,
		&"thigh_far": -14.0 + rise * 6.0 + fall * 4.0 + landing * 18.0,
		&"shin_far": 20.0 + rise * 34.0 - fall * 12.0 + landing * 62.0,
		&"foot_near": 12.0, &"foot_far": 10.0,
		&"pelvis_dy": landing * 11.0,
	}
	return pose

# ---------------------------------------------------------------------------------------------
# Keyframed sequences. Each key is [time, easing, pose]; missing joints keep the previous key's value.
# Extra channel: rx = horizontal displacement of the whole body (screen px, forward positive).

static func _key(t: float, pose: Dictionary, easing := "smooth") -> Array:
	return [t, easing, pose]

static func scared_keys() -> Array:
	return [
		_key(0.0, {&"spine": 1.5, &"arm_near_up": 7.0, &"arm_far_up": -6.0, &"arm_near_fore": 8.0, &"arm_far_fore": 6.0, &"rx": 0.0}),
		# 1. flinch: everything pulls back and the hands snap up
		_key(0.10, {&"spine": -13.0, &"head": -12.0, &"arm_near_up": 62.0, &"arm_near_fore": 78.0,
			&"arm_far_up": 44.0, &"arm_far_fore": 66.0, &"thigh_near": 16.0, &"shin_near": 30.0,
			&"thigh_far": -8.0, &"shin_far": 18.0, &"pelvis_dy": 6.0, &"rx": -4.0}, "out"),
		# 2. stagger back: the near foot is pulled off the ground, the other one slides away
		_key(0.32, {&"spine": -19.0, &"head": -10.0, &"arm_near_up": 92.0, &"arm_near_fore": 28.0,
			&"arm_far_up": 70.0, &"arm_far_fore": 22.0, &"thigh_near": 14.0, &"shin_near": 62.0,
			&"thigh_far": -26.0, &"shin_far": 12.0, &"foot_far": 8.0, &"pelvis_dy": 2.0, &"rx": -26.0}),
		_key(0.54, {&"spine": -15.0, &"head": -9.0, &"arm_near_up": 80.0, &"arm_near_fore": 40.0,
			&"arm_far_up": 62.0, &"arm_far_fore": 36.0, &"thigh_near": -20.0, &"shin_near": 8.0,
			&"thigh_far": 12.0, &"shin_far": 16.0, &"pelvis_dy": 4.0, &"rx": -46.0}),
		# 3. frozen with fear, trembling is added on top of this
		_key(1.15, {&"spine": -11.0, &"head": -7.0, &"arm_near_up": 66.0, &"arm_near_fore": 56.0,
			&"arm_far_up": 52.0, &"arm_far_fore": 50.0, &"thigh_near": -14.0, &"shin_near": 14.0,
			&"thigh_far": 8.0, &"shin_far": 16.0, &"pelvis_dy": 5.0, &"rx": -48.0}, "lin"),
		# 4. let go slowly
		_key(1.75, {&"spine": -3.0, &"head": -2.0, &"arm_near_up": 20.0, &"arm_near_fore": 20.0,
			&"arm_far_up": 8.0, &"arm_far_fore": 14.0, &"thigh_near": -4.0, &"shin_near": 4.0,
			&"thigh_far": 3.0, &"shin_far": 4.0, &"pelvis_dy": 1.0, &"rx": -48.0}),
		_key(2.05, {&"spine": 1.5, &"head": -1.0, &"arm_near_up": 7.0, &"arm_near_fore": 8.0,
			&"arm_far_up": -6.0, &"arm_far_fore": 6.0, &"thigh_near": 2.0, &"shin_near": 2.0,
			&"thigh_far": -2.0, &"shin_far": 2.0, &"foot_far": 0.0, &"pelvis_dy": 0.0, &"rx": -48.0}),
	]

const FALL_HEIGHT := 170.0
const FALL_GRAVITY := 1500.0

static func fall_time() -> float:
	return sqrt(2.0 * FALL_HEIGHT / FALL_GRAVITY)

# Keys that start at the moment of impact (t = 0 is touching the ground).
static func impact_keys() -> Array:
	return [
		_key(0.0, {&"spine": 6.0, &"head": 6.0, &"arm_near_up": 120.0, &"arm_near_fore": 30.0,
			&"arm_far_up": 105.0, &"arm_far_fore": 36.0, &"thigh_near": 24.0, &"shin_near": 40.0,
			&"thigh_far": -14.0, &"shin_far": 26.0, &"pelvis_dy": 0.0, &"pelvis_rot": 0.0, &"rx": 0.0}, "lin"),
		# the legs give way
		_key(0.09, {&"spine": 30.0, &"head": 14.0, &"arm_near_up": 50.0, &"arm_near_fore": 14.0,
			&"arm_far_up": 40.0, &"arm_far_fore": 18.0, &"thigh_near": 62.0, &"shin_near": 98.0,
			&"thigh_far": 40.0, &"shin_far": 92.0, &"pelvis_dy": 17.0, &"pelvis_rot": 8.0, &"rx": 3.0}, "out"),
		# pitched forward onto the ground
		_key(0.30, {&"spine": 14.0, &"head": -24.0, &"arm_near_up": 78.0, &"arm_near_fore": 18.0,
			&"arm_far_up": 96.0, &"arm_far_fore": 12.0, &"thigh_near": 14.0, &"shin_near": 62.0,
			&"thigh_far": 6.0, &"shin_far": 40.0, &"pelvis_dy": 30.0, &"pelvis_rot": 58.0, &"rx": 16.0}, "in"),
		_key(0.46, {&"spine": 6.0, &"head": -22.0, &"arm_near_up": 168.0, &"arm_near_fore": 6.0,
			&"arm_far_up": 152.0, &"arm_far_fore": 10.0, &"thigh_near": 6.0, &"shin_near": 14.0,
			&"thigh_far": 2.0, &"shin_far": 8.0, &"foot_near": 20.0, &"foot_far": 20.0, &"pelvis_dy": 34.0, &"pelvis_rot": 88.0, &"rx": 30.0}, "out"),
		# settles, then lies there breathing hard
		_key(0.80, {&"spine": 4.0, &"head": -30.0, &"arm_near_up": 172.0, &"arm_far_up": 156.0,
			&"pelvis_dy": 35.0, &"pelvis_rot": 89.0, &"rx": 30.0}),
		_key(1.60, {&"pelvis_dy": 35.0, &"pelvis_rot": 89.0, &"rx": 30.0}, "lin"),
		# gets the arms under the shoulders
		_key(2.05, {&"spine": 6.0, &"head": -34.0, &"arm_near_up": 118.0, &"arm_near_fore": 78.0,
			&"arm_far_up": 108.0, &"arm_far_fore": 84.0, &"thigh_near": 8.0, &"shin_near": 30.0,
			&"thigh_far": 4.0, &"shin_far": 24.0, &"pelvis_dy": 35.0, &"pelvis_rot": 88.0, &"rx": 30.0}, "in"),
		# presses up, one knee at a time comes forward
		_key(2.55, {&"spine": 10.0, &"head": -28.0, &"arm_near_up": 96.0, &"arm_near_fore": 12.0,
			&"arm_far_up": 92.0, &"arm_far_fore": 14.0, &"thigh_near": 66.0, &"shin_near": 118.0,
			&"thigh_far": 38.0, &"shin_far": 110.0, &"pelvis_dy": 30.0, &"pelvis_rot": 66.0, &"rx": 26.0}, "smooth"),
		# kneeling upright
		_key(3.10, {&"spine": 10.0, &"head": -14.0, &"arm_near_up": 40.0, &"arm_near_fore": 40.0,
			&"arm_far_up": 36.0, &"arm_far_fore": 36.0, &"thigh_near": 82.0, &"shin_near": 112.0,
			&"thigh_far": 30.0, &"shin_far": 120.0, &"pelvis_dy": 22.0, &"pelvis_rot": 16.0, &"rx": 22.0}),
		# stands up, a little hunched, hands wipe the dust
		_key(3.60, {&"spine": 14.0, &"head": -2.0, &"arm_near_up": 24.0, &"arm_near_fore": 46.0,
			&"arm_far_up": 18.0, &"arm_far_fore": 42.0, &"thigh_near": 14.0, &"shin_near": 28.0,
			&"thigh_far": -6.0, &"shin_far": 24.0, &"pelvis_dy": 6.0, &"pelvis_rot": 0.0, &"rx": 22.0}),
		_key(4.10, {&"spine": 1.5, &"head": -1.0, &"arm_near_up": 7.0, &"arm_near_fore": 8.0,
			&"arm_far_up": -6.0, &"arm_far_fore": 6.0, &"thigh_near": 2.0, &"shin_near": 2.0,
			&"thigh_far": -2.0, &"shin_far": 2.0, &"foot_near": 0.0, &"foot_far": 0.0, &"pelvis_dy": 0.0, &"rx": 22.0}),
	]

# Samples a key list at time t. Returns the pose with an extra `rx`.
static func sample(keys: Array, t: float) -> Dictionary:
	var count := keys.size()
	if t <= float(keys[0][0]):
		return _resolved(keys, 0)
	if t >= float(keys[count - 1][0]):
		return _resolved(keys, count - 1)
	for i in range(count - 1):
		var t0 := float(keys[i][0])
		var t1 := float(keys[i + 1][0])
		if t >= t0 and t <= t1:
			var a := _resolved(keys, i)
			var b := _resolved(keys, i + 1)
			var u := (t - t0) / maxf(0.0001, t1 - t0)
			match String(keys[i + 1][1]):
				"in": u = u * u
				"out": u = 1.0 - (1.0 - u) * (1.0 - u)
				"lin": pass
				_: u = u * u * (3.0 - 2.0 * u)
			var out := {}
			for k in b.keys():
				out[k] = lerpf(float(a.get(k, 0.0)), float(b[k]), u)
			return out
	return _resolved(keys, count - 1)

# Every joint of key i, inheriting from earlier keys.
static func _resolved(keys: Array, i: int) -> Dictionary:
	var out := {}
	for j in range(i + 1):
		for k in (keys[j][2] as Dictionary).keys():
			out[k] = (keys[j][2] as Dictionary)[k]
	return out

static func scared_tremble(t: float, strength: float) -> Dictionary:
	var s := strength
	return {
		&"head": sin(t * 52.0) * 1.8 * s,
		&"arm_near_up": sin(t * 47.0 + 1.0) * 3.0 * s,
		&"arm_far_up": sin(t * 49.0 + 2.0) * 3.0 * s,
		&"spine": sin(t * 41.0) * 0.9 * s,
		&"pelvis_dy": absf(sin(t * 44.0)) * 0.9 * s,
	}
