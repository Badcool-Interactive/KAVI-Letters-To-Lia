extends Node
## Procedural audio: sound effects pre-rendered at startup and per-biome
## music loops (calm pad + drive layer) rendered on a worker thread.
## Tailwind "perfect" notes play in the biome's key and climb with the tier.

const Save = preload("res://scripts/save.gd")
const GAME_BUS := &"Game"
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
var world_vol := Save.DEFAULT_WORLD_VOLUME
var world_level := 0.6  # target presence in the current scene
var _world_presence := 0.6
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
var _lead: AudioStreamPlayer
var lead := 0.0
var _lead_target := 0.0
var _evt_t := 20.0   # first world moment well after the menu appears
var style := "modern"  # "modern" (0.8.40 songs + world moments) or "og" (original loops)
var _pool: Array = []
var _cache := {}
var _task := -1
var _pending_biome := -1
var _note_step := 0

func _new_game_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = GAME_BUS
	add_child(player)
	return player

func _ready() -> void:
	_pad = _new_game_player()
	_drv = _new_game_player()
	_lead = _new_game_player()
	for i in 10:
		_pool.append(_new_game_player())
	_build_sfx()
	for i in 2:
		var a := _new_game_player()
		a.volume_db = -80.0
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

## Stamp pickups climb the country's scale while you keep collecting (a
## streak), so a clean line of stamps plays a little melody (0.8.29).
var _pick_step := 0
var _pick_t := -10.0

func pickup_note(now: float) -> void:
	if now - _pick_t > 0.7:
		_pick_step = 0
	_pick_t = now
	var k: Dictionary = KEYS[maxi(biome, 0) % KEYS.size()]
	var sc: Array = k.scale
	var i: int = mini(_pick_step, 11)
	_pick_step += 1
	var semis: int = k.root + sc[i % sc.size()] + 12 * (i / sc.size()) - 69 + 24
	play("mote", pow(2.0, semis / 12.0), -7.0 + minf(i * 0.4, 3.0))

## A short rising "sparkle" for big moments (new best, milestones).
func fanfare(big := false) -> void:
	var k: Dictionary = KEYS[maxi(biome, 0) % KEYS.size()]
	var notes := [0, 4, 7, 12] if big else [7, 12]
	for n in notes.size():
		get_tree().create_timer(0.07 * n).timeout.connect(func():
			play("bell", pow(2.0, (k.root - 69 + 12 + int(notes[n])) / 12.0), -3.0 if big else -6.0))

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
	_world_presence = lerpf(_world_presence, world_level, 1.0 - exp(-dt * 3.0))
	var base := maxf(world_vol * _world_presence, 0.0)
	var cur: AudioStreamPlayer = _amb[_amb_cur]
	var old: AudioStreamPlayer = _amb[1 - _amb_cur]
	cur.volume_db = linear_to_db(maxf(base * sin(_amb_mix * PI * 0.5), 0.0001))
	old.volume_db = linear_to_db(maxf(base * cos(_amb_mix * PI * 0.5), 0.0001))
	if _amb_mix >= 1.0 and old.playing:
		old.stop()
	# 0.8.40: little live moments on top of the loop (owner: the world sounds
	# were "meh"): a gull, a woodpecker, a church bell... each country has its
	# own, at random times, pitches and volumes, so the world never repeats.
	_evt_t -= dt
	if _evt_t <= 0.0:
		_evt_t = randf_range(5.0, 12.0)
		if base > 0.05 and _amb_b >= 0 and style != "og":
			var pool: Array = [["gull", "gull", "wave"], ["woodpecker", "cuckoo"], ["splash", "churchbell", "splash"], ["cowbell", "eagle", "cowbell"]][_amb_b % 4]
			var name: String = pool[randi() % pool.size()]
			for p in _pool:
				if not p.playing:
					p.stream = sfx[name]
					p.pitch_scale = randf_range(0.9, 1.1)
					p.volume_db = linear_to_db(maxf(base * randf_range(0.25, 0.55), 0.0001))
					p.play()
					break

func preload_all() -> void:
	for b in KEYS.size():
		for kind in ["pad", "drive", "lead", "world"]:
			if kind != "world" and _cache.has(b):
				continue   # music already loaded (requesting it again left an unused token)
			var path := ("res://assets/ambience/b%d_world.ogg" % b) if kind == "world" else ("res://assets/music/b%d_%s.ogg" % [b, kind])
			if ResourceLoader.exists(path) and not _threaded.has(path):
				ResourceLoader.load_threaded_request(path)
				_threaded.append(path)

## Clean shutdown (0.8.22): stop every player, drop the streams and finish any
## background loads, so nothing is left for Godot to report at exit.
func shutdown() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	for p in [_pad, _drv, _lead] + _pool + _amb:
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

## Sound style (0.8.41, owner): switch between the 0.8.40 songs and the
## original loops; restarts the current country's music in the new style.
func set_style(s: String) -> void:
	if s == style:
		return
	style = s
	_cache.clear()
	if biome >= 0:
		var b := biome
		biome = -1
		set_biome(b)

## 0..1: how much of the melody layer plays (main maps Tailwind to this).
func set_lead(level: float) -> void:
	_lead_target = clampf(level, 0.0, 1.0)

func _process(dt: float) -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _pending_biome >= 0 and _pending_biome != biome:
			set_biome(_pending_biome)
		elif _cache.has(biome):
			_start_music(biome)
	drive = move_toward(drive, _drive_target, dt * 0.7)
	lead = move_toward(lead, _lead_target * drive, dt * 0.5)
	_update_world(dt)
	var mv := maxf(music_vol, 0.0001)
	_pad.volume_db = linear_to_db(mv * 0.85)
	_drv.volume_db = linear_to_db(maxf(mv * drive * 0.9, 0.0001))
	_lead.volume_db = linear_to_db(maxf(mv * lead * 0.7, 0.0001))

func _start_music(b: int) -> void:
	var layers: Array = _cache[b]
	_pad.stream = layers[0]
	_drv.stream = layers[1]
	_lead.stream = layers[2] if layers.size() > 2 else null
	_pad.play()
	_drv.play()
	if _lead.stream != null:
		_lead.play()
	else:
		_lead.stop()

## Loads the loops pre-rendered by tools/render_music.gd (instant, no hitch
## on phones or in browsers). Falls back to runtime synthesis if missing.
func _load_prerendered(b: int) -> void:
	var paths: Array = []
	var og := style == "og"
	for kind in (["pad", "drive"] if og else ["pad", "drive", "lead"]):
		var path := ("res://assets/music/og/b%d_%s.ogg" if og else "res://assets/music/b%d_%s.ogg") % [b % KEYS.size(), kind]
		if not ResourceLoader.exists(path):
			return
		paths.append(path)
	var layers := []
	for path in paths:
		var st: AudioStream
		if _threaded.has(path):
			# finished in the background (or wait for it here as a fallback)
			st = ResourceLoader.load_threaded_get(path)
			_threaded.erase(path)
		else:
			st = load(path)
		if st is AudioStreamOggVorbis:
			st.loop = true
		layers.append(st)
	_cache[b] = layers

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
	# 0.8.40: new obstacles, and little world moments per country
	sfx.cart = _wav(_cart_rumble(1.1))
	sfx.flap = _wav(_flap(0.7))
	sfx.gull = _wav(_cries(1500.0, 1000.0, 3, 0.22, 0.26))
	sfx.wave = _wav(_swell(2.6, 0.30))
	sfx.woodpecker = _wav(_knocks(820.0, 7, 1.0 / 14.0, 0.13))
	sfx.cuckoo = _wav(_two_note(660.0, 550.0, 0.26, 0.22))
	sfx.splash = _wav(_splash(0.6))
	sfx.churchbell = _wav(_bell_tone(294.0, 3.0, 0.35))
	sfx.cowbell = _wav(_cowbell(1.6))
	sfx.eagle = _wav(_cries(2500.0, 1500.0, 1, 0.7, 0.18))

static func _cart_rumble(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.06
		var fade := minf(t / 0.08, 1.0) * clampf((dur - t) / 0.4, 0.0, 1.0)
		var clack_t := fmod(t, 0.115)
		var clack := sin(TAU * 520.0 * clack_t) * exp(-clack_t * 60.0) * 0.5
		b[i] = (lp * (0.7 + 0.3 * sin(TAU * 11.0 * t)) * 2.2 + clack) * fade * 0.45
	return b

static func _flap(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.35
		var beat := pow(absf(sin(TAU * 7.5 * t)), 3.0)
		var flap := lp * beat * exp(-t * 2.8) * 0.9
		# a soft "coo" near the end
		var ct := t - 0.32
		var coo := 0.0
		if ct > 0.0 and ct < 0.3:
			ph += TAU * lerpf(420.0, 330.0, ct / 0.3) / RATE
			coo = sin(ph) * sin(ct / 0.3 * PI) * 0.25 * (1.0 + 0.3 * sin(TAU * 30.0 * ct))
		b[i] = (flap + coo) * 0.6
	return b

static func _cries(f0: float, f1: float, count: int, dur: float, amp: float) -> PackedFloat32Array:
	var gap := dur * 1.35
	var n := int((gap * count + 0.1) * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for c in count:
		var ph := 0.0
		var off := int(c * gap * RATE)
		var cf := 1.0 - c * 0.04
		for i in int(dur * RATE):
			var u := float(i) / (dur * RATE)
			ph += TAU * lerpf(f0, f1, sqrt(u)) * cf / RATE
			var env := sin(u * PI) * (1.0 - u * 0.4)
			b[off + i] += (sin(ph) + 0.35 * sin(ph * 2.0) + 0.2 * sin(ph * 3.0) + randf_range(-0.12, 0.12)) * env * amp
	return b

static func _swell(dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	for i in n:
		var u := float(i) / n
		var k := 0.02 + 0.25 * pow(sin(u * PI), 2.0)
		lp += (randf_range(-1, 1) - lp) * k
		b[i] = lp * pow(sin(u * PI), 1.5) * amp * 2.5
	return b

static func _knocks(f: float, count: int, step: float, amp: float) -> PackedFloat32Array:
	var n := int((step * count + 0.1) * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for c in count:
		var off := int(c * step * RATE)
		var g := 1.0 - c * 0.06
		for i in int(0.04 * RATE):
			var t := float(i) / RATE
			# woody "tok": a soft attack, mostly tone, very little noise (0.8.41)
			b[off + i] += (sin(TAU * f * t) * 0.9 + sin(TAU * f * 1.6 * t) * 0.25 + randf_range(-1, 1) * 0.06) * minf(t / 0.002, 1.0) * exp(-t * 75.0) * amp * g
	return b

static func _two_note(f0: float, f1: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int((dur * 2.2) * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for k in 2:
		var f := f0 if k == 0 else f1
		var off := int(k * dur * 1.15 * RATE)
		for i in int(dur * RATE):
			var t := float(i) / RATE
			var env := minf(t / 0.02, 1.0) * exp(-t * 5.0)
			b[off + i] += (sin(TAU * f * t) + 0.2 * sin(TAU * f * 2.0 * t)) * env * amp
	return b

static func _splash(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.5
		var plink := sin(TAU * lerpf(900.0, 1500.0, minf(t / 0.05, 1.0)) * t) * exp(-t * 25.0) * 0.4
		b[i] = (lp * exp(-t * 9.0) * 0.5 + plink) * 0.5
	return b

static func _cowbell(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for hit in [0.0, 0.38, 0.62, 1.05]:
		var off := int(hit * RATE)
		var g: float = randf_range(0.5, 1.0)
		for i in int(0.45 * RATE):
			if off + i >= n:
				break
			var t := float(i) / RATE
			var v := sin(TAU * 610.0 * t) + 0.6 * sin(TAU * 913.0 * t) + 0.35 * sin(TAU * 1302.0 * t)
			b[off + i] += v * exp(-t * 9.0) * 0.16 * g
	return b

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
	# fallback only: the shipped game loads the pre-rendered OGG loops
	var layers := compose(b)
	var out := []
	for buf in layers:
		out.append(_wav_rate(buf, MRATE, true))
	_cache[b] = out

# ------------------------------------------------------------------ music v2
# 0.8.40 (owner: "without sound it gets boring; the sounds are meh"): a real
# 16-bar song per country instead of a 10 s loop of sine tones. Three layers
# that always play in sync:
#   pad   soft chords (menus and runs)
#   drive drums, bass and a plucked arpeggio (fades in when you run)
#   lead  a melody with echo + a shaker (fades in as your Tailwind climbs,
#         so playing well literally makes the music bigger)
# Form: A A B A' (8 + 4 + 4 bars), 100 BPM, ~38 s. Rendered offline by
# tools/render_music.gd, then encoded to OGG.
const MRATE := 32000
const MBPM := 100.0
const BARS := 16

static func _wav_rate(buf: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var w := _wav(buf, loop)
	w.mix_rate = rate
	return w

static func _put(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, gain: float) -> void:
	var n := dst.size()
	for i in src.size():
		var j := (at + i) % n
		dst[j] += src[i] * gain

static func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for v in buf:
		m = maxf(m, absf(v))
	var g := peak / m
	for i in buf.size():
		buf[i] = tanh(buf[i] * g * 1.1) / 1.1

static func _env_ar(t: float, dur: float, a: float, r: float) -> float:
	return minf(t / a, 1.0) * clampf((dur - t) / r, 0.0, 1.0)

static func _pad_note(f: float, dur: float, seed: float) -> PackedFloat32Array:
	var n := int(dur * MRATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / MRATE
		var env := _env_ar(t, dur, 0.45, 0.6) * (0.85 + 0.15 * sin(t * 1.7 + seed * 6.0))
		var v := 0.0
		for det in [0.997, 1.003]:
			var ph: float = TAU * f * det * t
			v += sin(ph) + 0.45 * sin(ph * 2.0) + 0.22 * sin(ph * 3.0) + 0.10 * sin(ph * 4.0)
		b[i] = v * env * 0.5
	return b

static func _pluck(f: float, dur: float, bright: float) -> PackedFloat32Array:
	var n := int(dur * MRATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / MRATE
		var v := 0.0
		for h in range(1, 6):
			v += sin(TAU * f * h * 1.0008 * t) * pow(h, -1.25) * exp(-t * (2.5 + h * (3.0 - bright * 1.5)))
		b[i] = v * minf(t * 900.0, 1.0)
	return b

static func _bass_note(f: float, dur: float) -> PackedFloat32Array:
	var n := int(dur * MRATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / MRATE
		var v := 0.0
		for h in range(1, 6):
			v += sin(TAU * f * h * t) * pow(h, -1.6)
		b[i] = tanh(v * 1.4) * _env_ar(t, dur, 0.006, 0.04) * exp(-t * 2.2)
	return b

static func _lead_note(f: float, dur: float) -> PackedFloat32Array:
	var n := int((dur + 0.12) * MRATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / MRATE
		var vib := 1.0 + 0.004 * sin(TAU * 5.5 * t) * clampf((t - 0.12) / 0.15, 0.0, 1.0)
		ph += TAU * f * vib / MRATE
		var v := sin(ph) + sin(ph * 3.0) / 9.0 + 0.18 * sin(ph * 2.0) + sin(ph * 5.0) / 25.0
		var env := minf(t / 0.015, 1.0) * (0.75 + 0.25 * exp(-t * 8.0)) * clampf((dur + 0.1 - t) / 0.1, 0.0, 1.0)
		b[i] = v * env
	return b

static func _kick() -> PackedFloat32Array:
	var n := int(0.35 * MRATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		var t := float(i) / MRATE
		ph += TAU * lerpf(150.0, 46.0, minf(t / 0.09, 1.0)) / MRATE
		b[i] = sin(ph) * exp(-t * 11.0) + (rng.randf_range(-1, 1) * 0.35 if t < 0.003 else 0.0)
	return b

static func _snare() -> PackedFloat32Array:
	var n := int(0.25 * MRATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var prev := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / MRATE
		var x := rng.randf_range(-1, 1)
		var hp := x - prev
		prev = x
		lp += (hp - lp) * 0.55
		b[i] = lp * exp(-t * 18.0) * 0.9 + sin(TAU * 190.0 * t) * exp(-t * 32.0) * 0.6
	return b

static func _hat(open: bool) -> PackedFloat32Array:
	var dur := 0.22 if open else 0.05
	var n := int(dur * MRATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13 if open else 14
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var t := float(i) / MRATE
		var x := rng.randf_range(-1, 1)
		var h1 := x - p1
		p1 = x
		var h2 := h1 - p2
		p2 = h1
		b[i] = h2 * 0.5 * exp(-t * (11.0 if open else 70.0))
	return b

static func _shaker() -> PackedFloat32Array:
	var n := int(0.08 * MRATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	var p := 0.0
	for i in n:
		var t := float(i) / MRATE
		var x := rng.randf_range(-1, 1)
		b[i] = (x - p) * minf(t / 0.008, 1.0) * exp(-t * 40.0) * 0.6
		p = x
	return b

## Renders one country's song: returns [pad, drive, lead] sample buffers.
static func compose(b: int) -> Array:
	var k: Dictionary = KEYS[b % KEYS.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + b * 97
	var beat := 60.0 / MBPM
	var bar := beat * 4.0
	var e8 := beat * 0.5
	var n := int(round(bar * BARS * MRATE))
	var pad := PackedFloat32Array()
	pad.resize(n)
	var drv := PackedFloat32Array()
	drv.resize(n)
	var lead := PackedFloat32Array()
	lead.resize(n)
	var root: int = k.root
	var sc: Array = k.scale
	var prog: Array = k.prog
	var plan: Array = []
	for i in 8:
		plan.append(prog[i % 4])
	for c in [1, 2, 0, 3]:
		plan.append(prog[c])
	for i in 4:
		plan.append(prog[i])
	var at := func(sec: float) -> int: return int(sec * MRATE)
	# ---- pad: chords with a soft low root
	for i in BARS:
		var ch: Array = plan[i]
		for v in ch.size():
			_put(pad, _pad_note(_midi(root - 12 + ch[v]), bar * 1.15, float(i * 3 + v)), at.call(i * bar), 0.16)
		_put(pad, _pad_note(_midi(root - 24 + ch[0]), bar * 1.1, float(i)), at.call(i * bar), 0.10)
	# ---- drums
	var kick := _kick()
	var snare := _snare()
	var hat := _hat(false)
	var ohat := _hat(true)
	for i in BARS:
		var s0 := i * bar
		var fill := i % 8 == 7
		for bt in 4:
			var tb := s0 + bt * beat
			if bt == 0 or bt == 2:
				_put(drv, kick, at.call(tb), 0.85)
			if i % 2 == 1 and bt == 2:
				_put(drv, kick, at.call(tb + e8), 0.45)
			if (bt == 1 or bt == 3) and not (fill and bt == 3):
				_put(drv, snare, at.call(tb), 0.42)
			for e in 2:
				var te := tb + e * e8 + (beat * 0.035 if e == 1 else 0.0)
				var op := bt == 3 and e == 1 and not fill
				_put(drv, ohat if op else hat, at.call(te), (0.22 if e == 0 else 0.15) * rng.randf_range(0.85, 1.1))
		if fill:
			for q in 4:
				_put(drv, snare, at.call(s0 + 3.0 * beat + q * beat * 0.25), 0.22 + q * 0.08)
	# ---- bass: a groove on the chord's root and fifth
	var pats := [["r", "", "r", "f", "", "r", "o", "f"], ["r", "", "", "r", "f", "", "o", ""], ["r", "r", "", "f", "r", "", "f", "o"]]
	var pat: Array = pats[b % pats.size()]
	for i in BARS:
		var ch: Array = plan[i]
		for e in 8:
			var tok: String = pat[e]
			if tok == "":
				continue
			var note: int = root - 24 + ch[0] + (12 if tok == "o" else 0) + ((ch[2] - ch[0]) if tok == "f" else 0)
			var ln := e8 * (1.8 if e + 1 < 8 and pat[e + 1] == "" else 0.9)
			_put(drv, _bass_note(_midi(note), ln), at.call(i * bar + e * e8), 0.34)
	# ---- plucked arpeggio
	var arp := [0, 1, 2, 1, 2, 0, 1, 2] if b % 2 == 0 else [0, 2, 1, 2, 0, 2, 1, 2]
	for i in BARS:
		var ch: Array = plan[i]
		for e in 8:
			if rng.randf() < 0.12 and e % 2 == 1:
				continue
			var note: int = root + ch[arp[e]] + (12 if (i % 4 == 3 and e >= 4) else 0)
			_put(drv, _pluck(_midi(note), 0.55, 0.6), at.call(i * bar + e * e8), 0.15 if e % 2 == 0 else 0.11)
	# ---- lead melody: a 2-bar motif, answered, varied, then a cadence
	var rhythms := [
		[[0, 2], [2, 1], [3, 1], [4, 2], [6, 2], [8, 3], [11, 1], [12, 4]],
		[[0, 1], [1, 1], [2, 2], [4, 1], [5, 1], [6, 2], [8, 2], [10, 2], [12, 4]],
		[[0, 3], [3, 1], [4, 2], [6, 2], [8, 1], [9, 1], [10, 2], [12, 2], [14, 2]],
	]
	var motif_a := _motif(rng, rhythms[b % 3], sc, 0)
	var motif_b := _motif(rng, rhythms[(b + 1) % 3], sc, 2)
	var phrases := [motif_a, _shift_motif(motif_a, 1), motif_a, _cadence(motif_a, sc),
		motif_b, _shift_motif(motif_b, -1), motif_a, _cadence(motif_a, sc)]
	var echo := beat * 0.75
	for ph_i in phrases.size():
		var s0 := ph_i * 2.0 * bar
		for nt in phrases[ph_i]:
			var deg: int = nt[2]
			var midi: int = root + 12 + sc[posmod(deg, sc.size())] + 12 * floori(float(deg) / sc.size())
			var tone := _lead_note(_midi(midi), nt[1] * e8 * 0.92)
			_put(lead, tone, at.call(s0 + nt[0] * e8), 0.30)
			_put(lead, tone, at.call(s0 + nt[0] * e8 + echo), 0.10)
	# shaker 16ths in the lead layer: more energy at high Tailwind
	var shk := _shaker()
	for q in BARS * 16:
		_put(lead, shk, at.call(q * beat * 0.25), 0.09 if q % 2 == 0 else 0.05)
	_normalize(pad, 0.42)
	_normalize(drv, 0.62)
	_normalize(lead, 0.45)
	return [pad, drv, lead]

## A motif: list of [start_eighth, length_eighths, scale_degree] over 2 bars.
## Strong beats land on chord-friendly degrees (0, 2, 4 of the pentatonic).
static func _motif(rng: RandomNumberGenerator, rhythm: Array, sc: Array, lift: int) -> Array:
	var out: Array = []
	var d: int = lift + [0, 2, 4][rng.randi() % 3]
	for r in rhythm:
		if r[0] % 4 == 0:
			d = clampi(d + rng.randi_range(-2, 2), lift - 1, lift + 7)
			d = d - posmod(d, 2)  # even degrees: root/third/fifth-ish
		else:
			d = clampi(d + [-1, 1, 1, 2, -2][rng.randi() % 5], lift - 2, lift + 8)
		out.append([r[0], r[1], d])
	return out

static func _shift_motif(m: Array, by: int) -> Array:
	var out: Array = []
	for nt in m:
		out.append([nt[0], nt[1], nt[2] + by])
	return out

static func _cadence(m: Array, sc: Array) -> Array:
	var out: Array = []
	for i in m.size():
		var nt: Array = m[i]
		if i == m.size() - 1:
			out.append([nt[0], 16 - nt[0], 0])   # land on the root, held
		elif i == m.size() - 2:
			out.append([nt[0], nt[1], 1])
		else:
			out.append(nt.duplicate())
	return out
