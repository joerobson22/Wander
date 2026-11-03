class_name Synth
extends RefCounted
## Placeholder sounds made in code, so the app has its bong, pops and rustles
## before real recordings exist. Drop a .wav, .ogg or .mp3 named after the
## moment into assets/sounds/ (see the list in assets/sounds/README.md) and
## Audio plays that instead.

const RATE := 22050
const NAMES := ["bong", "pop", "rustle", "chime", "whoosh", "levelup", "wind", "splash", "rain", "thunder", "ding"]

static var _cache: Dictionary = {}
static var _lock := Mutex.new()


## Makes every sound ahead of time; Audio runs this on a worker thread at
## startup so the first tap doesn't stall while a bell is computed.
static func warm() -> void:
	for n in NAMES:
		sound(n)


## The named sound, generated once and cached; null for an unknown name.
static func sound(name: String) -> AudioStreamWAV:
	_lock.lock()
	var cached: AudioStreamWAV = _cache.get(name)
	_lock.unlock()
	if cached:
		return cached
	var samples: PackedFloat32Array
	match name:
		"bong":
			# Two soft bells a fifth apart: the tap on the focus orb.
			samples = _mix([_bell(392.0, 2.2, 1.0), _delay(_bell(587.33, 2.0, 0.55), 0.11)])
		"pop":
			samples = _pop()
		"rustle":
			samples = _rustle(1.1)
		"chime":
			# A rising arpeggio for a gift reveal.
			var notes := [523.25, 659.25, 783.99, 1046.5]
			var parts: Array[PackedFloat32Array] = []
			for i in notes.size():
				parts.append(_delay(_bell(notes[i], 1.4, 0.7 - i * 0.08), i * 0.09))
			samples = _mix(parts)
		"whoosh":
			samples = _whoosh(0.5)
		"levelup":
			# A bright run up a major scale and a held top note.
			var notes := [523.25, 659.25, 783.99, 1046.5, 1318.5]
			var parts: Array[PackedFloat32Array] = []
			for i in notes.size():
				parts.append(_delay(_bell(notes[i], 1.2 if i < notes.size() - 1 else 2.0, 0.6 + i * 0.08), i * 0.07))
			samples = _mix(parts)
		"wind":
			samples = _wind(6.0)
		"splash":
			samples = _splash(0.7)
		"ding":
			# One bright bell with its octave: the walk's first gift is coming.
			samples = _mix([_bell(1046.5, 1.6, 1.0), _bell(2093.0, 0.9, 0.35)])
		"rain":
			samples = _rain(6.0)
		"thunder":
			samples = _thunder(4.0)
		_:
			return null
	var wav := _to_wav(_normalise(samples, 0.6))
	_lock.lock()
	_cache[name] = wav
	_lock.unlock()
	return wav


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## A struck bell: a few slightly inharmonic partials, each fading at its own rate.
static func _bell(freq: float, seconds: float, amp: float) -> PackedFloat32Array:
	var partials := [[1.0, 1.0, 1.6], [2.0, 0.45, 2.6], [2.76, 0.22, 4.0], [5.4, 0.08, 7.0]]
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var attack := minf(1.0, t / 0.006)
		var v := 0.0
		for p in partials:
			v += p[1] * exp(-p[2] * t) * sin(TAU * freq * p[0] * t)
		out[i] = v * attack * amp
	return out


static func _pop() -> PackedFloat32Array:
	var n := int(0.16 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := 380.0 + 900.0 * (1.0 - exp(-t * 60.0))
		phase += TAU * freq / RATE
		out[i] = sin(phase) * exp(-t * 28.0) * minf(1.0, t / 0.003)
	return out


## Leaves being pushed about: filtered noise in uneven bursts.
static func _rustle(seconds: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var lower := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := rng.randf_range(-1.0, 1.0)
		low += 0.45 * (white - low)
		lower += 0.04 * (white - lower)
		var crackle := pow(absf(sin(TAU * 9.0 * t + sin(TAU * 2.3 * t) * 2.0)), 3.0)
		var env := minf(1.0, t / 0.05) * minf(1.0, (seconds - t) / 0.35)
		out[i] = (low - lower) * (0.35 + 0.65 * crackle) * env
	return out


static func _whoosh(seconds: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := 0.02 + 0.25 * sin(PI * t / seconds)
		low += k * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = low * sin(PI * t / seconds)
	return out


## A gusting wind, quiet at both ends so it loops without a click.
static func _wind(seconds: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / RATE
		var gust := 0.55 + 0.3 * sin(TAU * t / seconds * 2.0) + 0.15 * sin(TAU * t / seconds * 5.0)
		low += (0.015 + 0.03 * gust) * (rng.randf_range(-1.0, 1.0) - low)
		out[i] = low * gust * sin(PI * t / seconds)
	return out


## Something dropping into water: a burst of noise with a falling plop.
static func _splash(seconds: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		low += 0.3 * (rng.randf_range(-1.0, 1.0) - low)
		phase += TAU * (520.0 - 300.0 * minf(1.0, t / 0.12)) / RATE
		out[i] = low * exp(-t * 7.0) * 0.8 + sin(phase) * exp(-t * 18.0) * 0.6
	return out


## Steady rain: a soft hiss with drops pattering through it. The end is
## blended into the start, so it loops without a seam.
static func _rain(seconds: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := int(seconds * RATE)
	var blend := int(0.5 * RATE)
	var raw := PackedFloat32Array()
	raw.resize(n + blend)
	var low := 0.0
	for i in raw.size():
		low += 0.18 * (rng.randf_range(-1.0, 1.0) - low)
		raw[i] = low * 0.6
	for d in int(seconds * 40):
		var at := rng.randi_range(0, raw.size() - 200)
		var amp := rng.randf_range(0.15, 0.5)
		var freq := rng.randf_range(1800.0, 4200.0)
		for j in 160:
			raw[at + j] += sin(TAU * freq * j / RATE) * amp * exp(-j / 30.0)
	var out := raw.slice(0, n)
	for i in blend:
		var f := float(i) / blend
		out[i] = raw[n + i] * (1.0 - f) + raw[i] * f
	return out


## Distant thunder: a sharp crack, then a low rumble rolling away.
static func _thunder(seconds: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var lower := 0.0
	for i in n:
		var t := float(i) / RATE
		low += 0.06 * (rng.randf_range(-1.0, 1.0) - low)
		lower += 0.02 * (low - lower)
		var roll := (1.0 - exp(-t * 30.0)) * exp(-t * 1.1) * (0.7 + 0.3 * sin(TAU * t * 1.7))
		out[i] = lower * 4.0 * roll + rng.randf_range(-1.0, 1.0) * exp(-t * 25.0) * 0.5
	return out


static func _delay(samples: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(seconds * RATE))
	pad.append_array(samples)
	return pad


static func _mix(parts: Array[PackedFloat32Array]) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out


static func _normalise(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.0
	for v in samples:
		top = maxf(top, absf(v))
	if top <= 0.0:
		return samples
	var k := peak / top
	for i in samples.size():
		samples[i] *= k
	return samples
