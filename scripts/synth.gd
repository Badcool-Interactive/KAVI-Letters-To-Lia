extends Node
## Procedural audio: sound effects pre-rendered at startup and per-biome
## music loops (calm pad + drive layer) rendered on a worker thread.
## Tailwind "perfect" notes play in the biome's key and climb with the tier.

const RATE := 22050
const BPM := 96.0

const KEYS := [
	{"root": 62, "prog": [[0, 4, 7], [-3, 0, 4], [-5, -1, 2], [-3, 2, 5]], "scale": [0, 2, 4, 7, 9]},   # D
	{"root": 57, "prog": [[0, 3, 7], [-4, 0, 3], [-9, -5, -2], [-2, 2, 5]], "scale": [0, 3, 5, 7, 10]}, # A minor
	{"root": 53, "prog": [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]], "scale": [0, 2, 4, 7, 9]},  # F
	{"root": 52, "prog": [[0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5]], "scale": [0, 3, 5, 7, 10]},   # E minor
]

var sfx := {}
var music_vol := 0.8
var sfx_vol := 0.9
var world_vol := 0.7   # ambient world sounds (0.8.25)
var world_level := 0.6 # how present the world sounds are in the current scene (main sets it)
var _amb: Array = []   # two players for crossfading between countries
var _amb_cur := 0
var _amb_b := -1
var _amb_mix := 1.0
var _amb_streams := {}
var biome := -1
var drive := 1.0
var _drive_target := 1.0
var _pad: AudioStreamPlayer
var _drv: AudioStreamPlayer
var _pool: Array = []
var _cache := {}
var _task := -1
var _pending_biome := -1
var _note_step := 0

func _ready() -> void:
	_pad = AudioStreamPlayer.new()
	_drv = AudioStreamPlayer.new()
	add_child(_pad)
	add_child(_drv)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_build_sfx()
	for i in 2:
		var a := AudioStreamPlayer.new()
		a.volume_db = -80.0
		add_child(a)
		_amb.append(a)

# ------------------------------------------------------------------ playback
func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not sfx.has(name) or sfx_vol <= 0.01:
		return
	for p in _pool:
		if not p.playing:
			p.stream = sfx[name]
			p.pitch_scale = pitch
			p.volume_db = vol_db + linear_to_db(sfx_vol)
			p.play()
			return

## Plays the next note of the biome's scale; higher tiers climb higher.
func perfect_note(tier: int) -> void:
	var k: Dictionary = KEYS[maxi(biome, 0) % KEYS.size()]
	var sc: Array = k.scale
	var idx := _note_step % sc.size()
	_note_step += 1
	var semis: int = k.root + sc[idx] + 12 * (tier - 1) / 2 - 69 + 12
	play("bell", pow(2.0, semis / 12.0), -4.0)

## Load every country's pre-rendered music up front, on background threads
## (0.8.19; 0.8.17 loaded them on the main thread as the menu appeared, which
## stuttered on phones). A country change then never touches the disk.
var _threaded: Array = []   # paths requested with ResourceLoader.load_threaded_request

## World sounds: each country's loop (waves, forest birds, river, mountain
## wind) crossfades in over 2.5 s when the country changes.
func set_world(b: int) -> void:
	b = b % KEYS.size()
	if b == _amb_b:
		return
	var path := "res://assets/ambience/b%d_world.ogg" % b
	if not _amb_streams.has(b):
		if not ResourceLoader.exists(path):
			return
		var st: AudioStream = ResourceLoader.load_threaded_get(path) if _threaded.has(path) else load(path)
		_threaded.erase(path)
		if st is AudioStreamOggVorbis:
			st.loop = true
		_amb_streams[b] = st
	_amb_b = b
	_amb_cur = 1 - _amb_cur
	var p: AudioStreamPlayer = _amb[_amb_cur]
	p.stream = _amb_streams[b]
	p.volume_db = -80.0
	p.play(randf() * 20.0)
	_amb_mix = 0.0

func _update_world(dt: float) -> void:
	if _amb.is_empty():
		return
	_amb_mix = minf(_amb_mix + dt / 2.5, 1.0)
	var base := maxf(world_vol * world_level, 0.0)
	var cur: AudioStreamPlayer = _amb[_amb_cur]
	var old: AudioStreamPlayer = _amb[1 - _amb_cur]
	cur.volume_db = linear_to_db(maxf(base * sin(_amb_mix * PI * 0.5), 0.0001))
	old.volume_db = linear_to_db(maxf(base * cos(_amb_mix * PI * 0.5), 0.0001))
	if _amb_mix >= 1.0 and old.playing:
		old.stop()

func preload_all() -> void:
	for b in KEYS.size():
		for kind in ["pad", "drive", "world"]:
			if kind != "world" and _cache.has(b):
				continue   # music already loaded (requesting it again left an unused token)
			var path := ("res://assets/ambience/b%d_world.ogg" % b) if kind == "world" else ("res://assets/music/b%d_%s.wav" % [b, kind])
			if ResourceLoader.exists(path) and not _threaded.has(path):
				ResourceLoader.load_threaded_request(path)
				_threaded.append(path)

## Clean shutdown (0.8.22): stop every player, drop the streams and finish any
## background loads, so nothing is left for Godot to report at exit.
func shutdown() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for p in [_pad, _drv] + _pool + _amb:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for path in _threaded.duplicate():
		ResourceLoader.load_threaded_get(path)
	_threaded.clear()
	_cache.clear()
	_amb_streams.clear()

## True once every threaded music load has finished (used by the loading screen).
func preload_done() -> bool:
	for path in _threaded:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false
	return true

func set_biome(b: int) -> void:
	if b == biome and _task == -1:
		return
	biome = b
	if not _cache.has(b):
		_load_prerendered(b)
	if _cache.has(b):
		_start_music(b)
		return
	if _task != -1:
		_pending_biome = b
		return
	_pending_biome = -1
	_task = WorkerThreadPool.add_task(_render_music.bind(b))

func set_drive(on: float) -> void:
	_drive_target = on

func _process(dt: float) -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _pending_biome >= 0 and _pending_biome != biome:
			set_biome(_pending_biome)
		elif _cache.has(biome):
			_start_music(biome)
	drive = move_toward(drive, _drive_target, dt * 0.7)
	_update_world(dt)
	var mv := maxf(music_vol, 0.0001)
	_pad.volume_db = linear_to_db(mv * 0.85)
	_drv.volume_db = linear_to_db(maxf(mv * drive * 0.9, 0.0001))

func _start_music(b: int) -> void:
	var pair: Array = _cache[b]
	_pad.stream = pair[0]
	_drv.stream = pair[1]
	_pad.play()
	_drv.play()

## Loads the loops pre-rendered by tools/render_music.gd (instant, no hitch
## on phones or in browsers). Falls back to runtime synthesis if missing.
func _load_prerendered(b: int) -> void:
	var pad_path := "res://assets/music/b%d_pad.wav" % (b % KEYS.size())
	var drv_path := "res://assets/music/b%d_drive.wav" % (b % KEYS.size())
	if not (ResourceLoader.exists(pad_path) and ResourceLoader.exists(drv_path)):
		return
	var pair := []
	for path in [pad_path, drv_path]:
		var w: AudioStreamWAV
		if _threaded.has(path):
			# finished in the background (or wait for it here as a fallback)
			w = ResourceLoader.load_threaded_get(path)
			_threaded.erase(path)
		else:
			w = load(path)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		pair.append(w)
	_cache[b] = pair

# ------------------------------------------------------------------ rendering
static func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

static func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)

func _build_sfx() -> void:
	sfx.jump = _wav(_chirp(0.14, 380.0, 820.0, 0.35, 0.0))
	sfx.land = _wav(_chirp(0.09, 160.0, 70.0, 0.4, 0.2))
	sfx.dive = _wav(_chirp(0.16, 900.0, 260.0, 0.3, 0.15))
	sfx.slide = _wav(_noise(0.28, 0.22, 0.25))
	sfx.gust = _wav(_noise(0.35, 0.35, 0.6))
	sfx.letter = _wav(_chirp(0.12, 1200.0, 1900.0, 0.22, 0.05))
	sfx.mote = _wav(_bell_tone(1760.0, 0.25, 0.18))
	sfx.bell = _wav(_bell_tone(440.0, 1.1, 0.45))
	sfx.fail = _wav(_chirp(0.45, 520.0, 180.0, 0.35, 0.0))
	sfx.ui = _wav(_bell_tone(880.0, 0.12, 0.25))
	sfx.hover = _wav(_noise(0.4, 0.12, 0.05))
	sfx.engine = _wav(_engine(1.6))
	# 0.8.13 sky toys: a ship's horn and a little bird tweet
	var toot := _chirp(0.55, 196.0, 188.0, 0.30, 0.0)
	var toot2 := _chirp(0.55, 247.0, 238.0, 0.20, 0.0)
	for i in toot.size():
		toot[i] += toot2[i]
	sfx.toot = _wav(toot)
	sfx.tweet = _wav(_chirp(0.09, 2600.0, 3600.0, 0.16, 0.0))
	sfx.whoosh = _wav(_noise(0.7, 0.20, 0.5))
	var tier := PackedFloat32Array()
	tier.resize(int(RATE * 0.9))
	for n in 4:
		var tone := _bell_tone(_midi(74 + [0, 4, 7, 12][n]), 0.6, 0.25)
		var off := int(n * 0.08 * RATE)
		for i in tone.size():
			if off + i < tier.size():
				tier[off + i] += tone[i]
	sfx.tier = _wav(tier)

static func _chirp(dur: float, f0: float, f1: float, amp: float, noise: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		ph += TAU * f / RATE
		var env := (1.0 - t) * minf(t * 40.0, 1.0)
		b[i] = (sin(ph) * 0.8 + sin(ph * 2.0) * 0.2 + randf_range(-1, 1) * noise) * env * amp
	return b

static func _noise(dur: float, amp: float, bright: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var k := 0.05 + bright * sin(t * PI) * 0.6
		lp += (randf_range(-1, 1) - lp) * k
		b[i] = lp * sin(t * PI) * amp * 2.0
	return b

static func _bell_tone(f: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 5.0 / dur) * minf(t * 300.0, 1.0)
		b[i] = (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.01 * t) + 0.15 * sin(TAU * f * 3.98 * t)) * env * amp
	return b

static func _engine(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(70.0, 140.0, t) + sin(t * 60.0) * 6.0
		ph += f / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		b[i] = saw * 0.25 * sin(t * PI)
	return b

func _render_music(b: int) -> void:
	var k: Dictionary = KEYS[b % KEYS.size()]
	var beat := 60.0 / BPM
	var bar := beat * 4.0
	var n := int(bar * 4.0 * RATE)
	var pad := PackedFloat32Array()
	pad.resize(n)
	var drv := PackedFloat32Array()
	drv.resize(n)
	var root: int = k.root
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + b
	# pad: soft chords, one per bar, with overlap
	for c in 4:
		var chord: Array = k.prog[c]
		var s0 := int(c * bar * RATE)
		var len := int(bar * 1.25 * RATE)
		for v in chord.size() + 1:
			var note: float = root - 12 + (chord[v] if v < chord.size() else chord[0] - 12)
			var f := _midi(note)
			var det := 1.0 + (v - 1) * 0.0025
			for i in len:
				var idx := (s0 + i) % n
				var t := float(i) / RATE
				var env := minf(t / 0.6, 1.0) * clampf((bar * 1.25 - t) / 0.6, 0.0, 1.0)
				var ph := TAU * f * det * t
				pad[idx] += (sin(ph) + 0.25 * sin(ph * 2.0) + 0.1 * sin(ph * 3.0)) * env * 0.07
	# drive: arpeggio + soft kick + shaker
	var steps := 32
	for st in steps * 4 / 4:
		pass
	var eighth := beat * 0.5
	var total_eighths := int(bar * 4.0 / eighth)
	for e in total_eighths:
		var c := int(e * eighth / bar) % 4
		var chord: Array = k.prog[c]
		var pat := [0, 1, 2, 1, 2, 0, 1, 2]
		var note: float = root + chord[pat[e % 8]] + (12 if e % 16 >= 8 else 0)
		var f := _midi(note)
		var s0 := int(e * eighth * RATE)
		var len := int(0.4 * RATE)
		for i in len:
			var idx := (s0 + i) % n
			var t := float(i) / RATE
			var env := exp(-t * 9.0) * minf(t * 500.0, 1.0)
			drv[idx] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env * 0.09
		# kick on beats
		if e % 2 == 0:
			var kl := int(0.18 * RATE)
			var kp := 0.0
			for i in kl:
				var idx2 := (s0 + i) % n
				var t2 := float(i) / RATE
				kp += TAU * lerpf(120.0, 45.0, minf(t2 / 0.12, 1.0)) / RATE
				drv[idx2] += sin(kp) * exp(-t2 * 22.0) * (0.22 if e % 4 == 0 else 0.12)
		else:
			var hl := int(0.05 * RATE)
			for i in hl:
				var idx3 := (s0 + i) % n
				drv[idx3] += rng.randf_range(-1, 1) * exp(-float(i) / RATE * 70.0) * 0.035
	# bass under the drive layer
	for c in 4:
		var f := _midi(root - 24 + k.prog[c][0])
		var s0 := int(c * bar * RATE)
		for i in int(bar * RATE):
			var t := float(i) / RATE
			var beat_ph := fmod(t, beat) / beat
			drv[(s0 + i) % n] += sin(TAU * f * t) * (1.0 - beat_ph) * 0.08
	_cache[b] = [_wav(pad, true), _wav(drv, true)]
