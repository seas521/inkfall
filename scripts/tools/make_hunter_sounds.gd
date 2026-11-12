extends SceneTree

# Renders the hunter's placeholder sounds (a bell, a distant step, the foot's strike, the arm's sweep, a tree cracking) into
# assets/audio/hunter/*.wav. Placeholders made of sines and filtered noise: replace the files with real recordings any time.
#
#   Godot --headless --path . --script res://scripts/tools/make_hunter_sounds.gd
const RATE := 22050
const OUT := "res://assets/audio/hunter/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_save("bell", _bell())
	_save("step", _step())
	_save("strike", _strike())
	_save("sweep", _sweep())
	_save("crack", _crack())
	print("hunter sounds written")
	quit()

func _save(sound_name: String, samples: PackedFloat32Array) -> void:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.92, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.save_to_wav(OUT + sound_name + ".wav")

func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples

# A dull hand bell: a few inharmonic partials, a click, a long ring
func _bell() -> PackedFloat32Array:
	var samples := _buffer(3.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var partials := [[1.0, 1.0, 1.1], [2.01, 0.55, 1.5], [2.76, 0.62, 2.0], [4.07, 0.28, 2.8], [5.4, 0.3, 3.4], [8.93, 0.12, 5.5]]
	var base := 356.0
	for i in samples.size():
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += float(p[1]) * sin(TAU * base * float(p[0]) * t) * exp(-t * float(p[2]))
		# the beating of a cracked bell
		v += 0.35 * sin(TAU * (base + 3.0) * t) * exp(-t * 1.3)
		v += (rng.randf() * 2.0 - 1.0) * 0.5 * exp(-t * 380.0)
		samples[i] = v * minf(t * 900.0, 1.0)
	return samples

# A heavy, far-off footstep: a low thud, a rumble
func _step() -> PackedFloat32Array:
	var samples := _buffer(0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var low := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		low += (rng.randf() * 2.0 - 1.0 - low) * 0.035
		var v := sin(TAU * (52.0 - 14.0 * t) * t) * exp(-t * 7.0) + low * 3.2 * exp(-t * 5.0)
		samples[i] = v * minf(t * 400.0, 1.0)
	return samples

# The foot coming down: a deep boom, a low roar, the ground cracking
func _strike() -> PackedFloat32Array:
	var samples := _buffer(2.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var low := 0.0
	var mid := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var n := rng.randf() * 2.0 - 1.0
		low += (n - low) * 0.025
		mid += (n - mid) * 0.18
		var v := sin(TAU * (44.0 - 9.0 * minf(t, 1.0)) * t) * exp(-t * 2.4) * 1.3
		v += low * 4.0 * exp(-t * 3.2)
		v += (mid - low) * 1.6 * exp(-t * 11.0)
		v += n * 0.7 * exp(-t * 60.0)
		samples[i] = v * minf(t * 500.0, 1.0)
	return samples

# The arm sweeping through the air: a breath of filtered noise that swells and falls
func _sweep() -> PackedFloat32Array:
	var samples := _buffer(2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var state := 0.0
	var state2 := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var u := t / 2.0
		var swell := sin(PI * pow(u, 0.8))
		var cutoff := 0.015 + 0.16 * swell
		var n := rng.randf() * 2.0 - 1.0
		state += (n - state) * cutoff
		state2 += (state - state2) * cutoff
		samples[i] = state2 * swell * 5.0
	return samples

# A big tree splitting: sharp noise cracks with a wooden ring
func _crack() -> PackedFloat32Array:
	var samples := _buffer(0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	var state := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var n := rng.randf() * 2.0 - 1.0
		state += (n - state) * 0.35
		var v := (n - state) * exp(-t * 45.0) * 1.2
		v += sin(TAU * 170.0 * t) * exp(-t * 14.0) * 0.8
		v += sin(TAU * 740.0 * t) * exp(-t * 30.0) * 0.4
		# a second, smaller splinter
		var t2 := t - 0.16
		if t2 > 0.0:
			v += (n - state) * exp(-t2 * 70.0) * 0.6
		samples[i] = v
	return samples
