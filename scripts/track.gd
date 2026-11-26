extends RefCounted
## Course data, phrase-based generator and fairness validation.
## Every generated segment is replayed by the solver bot on the real
## simulation; obstacles the bot cannot clear are pushed back or removed.

const Sim = preload("res://scripts/sim.gd")

enum { HURDLE, BEAM, GAP, WIDE_GAP, GATE, BELL, BLOOM, RESCUE, CART, FLOCK, TOWER }
const NAMES := ["hurdle", "beam", "gap", "wide_gap", "gate", "bell", "bloom", "rescue", "cart", "flock", "tower"]

var obs: Array = []      # Dictionaries sorted by x
var motes: Array = []    # {x, y, taken}
var end_x := 0.0
var validation_fixes := 0
var validation_drops := 0

# ---------------------------------------------------------------- queries
func hole_at(px: float, kind_mode := false) -> bool:
	for o in obs:
		if o.x > px:
			break
		if px >= o.x and px <= o.x + o.w:
			match o.t:
				GAP, WIDE_GAP, RESCUE:
					return not kind_mode
				BELL:
					return not o.open and not kind_mode
	return false

func first_index_after(px: float) -> int:
	# Binary search: first obstacle whose end is past px.
	var lo := 0
	var hi := obs.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if obs[mid].x + obstacle_extent(obs[mid]) < px:
			lo = mid + 1
		else:
			hi = mid
	return lo

static func obstacle_extent(o: Dictionary) -> float:
	if o.t == BLOOM:
		return o.wall_x + o.wall_w - o.x
	return o.w

func clone() -> RefCounted:
	var t = get_script().new()
	t.obs = obs.duplicate(true)
	t.motes = motes.duplicate(true)
	t.end_x = end_x
	return t

func trim_before(px: float) -> void:
	# Drop far-behind data so endless runs stay light.
	while obs.size() > 0 and obs[0].x + obstacle_extent(obs[0]) < px:
		obs.pop_front()
	while motes.size() > 0 and motes[0].x < px:
		motes.pop_front()

# ---------------------------------------------------------------- building
static func make(t: int, x: float, sp: float, rng: RandomNumberGenerator) -> Dictionary:
	var o := {"t": t, "x": x, "w": 60.0, "h": 70.0, "passed": false, "perf": false,
		"open": false, "open_t": 0.0, "hinted": false, "seed": rng.randi() % 100000}
	match t:
		HURDLE:
			o.w = rng.randf_range(52, 74)
			o.h = rng.randf_range(62, 80)
		BEAM:
			o.w = rng.randf_range(sp * 0.25, sp * 0.45)
			o.h = 64.0 # clearance above ground
		GAP:
			o.w = sp * rng.randf_range(0.30, 0.44)
		WIDE_GAP:
			o.w = sp * rng.randf_range(0.86, 1.0)
		GATE:
			o.w = 46.0
			o.h = 420.0
		BELL:
			o.w = sp * 1.75
			o.bell_x = x - sp * 0.25
			o.bell_y = -330.0
		BLOOM:
			o.w = 150.0 # pad width
			o.wall_x = x + o.w + sp * 0.30 + 30.0
			o.wall_w = 54.0
			o.wall_h = 300.0
		RESCUE:
			o.w = sp * 2.6
		CART:
			# a runaway fruit cart (0.8.40): rolls toward Kavi once it's next
			o.w = rng.randf_range(78, 92)
			o.h = rng.randf_range(62, 72)
			o.cv = rng.randf_range(150, 230)
			o.x0 = x
			o.roll = 0.0
		FLOCK:
			# pigeons on the path: scoot under, or Gust them away
			o.w = rng.randf_range(120, 170)
			o.h = 64.0 # clearance, like a sign
		TOWER:
			# a tall parcel tower: hold Hop to clear it
			o.w = rng.randf_range(54, 66)
			o.h = rng.randf_range(118, 136)
	return o

## Generates one segment of `secs` seconds at speed `sp` starting at `x0`.
## Returns the end x. `types` lists allowed obstacle types; `diff` is 0..1.
func gen_segment(x0: float, secs: float, sp: float, diff: float, types: Array,
		seed_val: int, rescue := false, combos := false, lead_in := 3.0) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var t := lead_in # free running before the first obstacle
	var easy: Array = types.filter(func(x): return x in [HURDLE, BEAM, GAP])
	if easy.is_empty():
		easy = types
	var placed: Array = []
	var hist: Array = []
	var rescue_at := secs * rng.randf_range(0.45, 0.7) if rescue else -1.0
	while t < secs - 0.6:
		if rescue_at > 0.0 and t >= rescue_at:
			var r := make(RESCUE, x0 + t * sp, sp, rng)
			placed.append(r)
			t += r.w / sp + 1.6
			rescue_at = -1.0
			continue
		# Smooth ramp: gentle, well-spaced, easy obstacles first; full
		# difficulty only after ~45% of the stretch.
		var ramp := clampf((t - lead_in) / maxf(secs * 0.45, 1.0), 0.0, 1.0)
		var ld := diff * lerpf(0.2, 1.0, ramp)
		var pool: Array = easy if ramp < 0.3 else types
		var phrase := _pick_phrase(rng, pool, ld, combos and ramp > 0.6)
		# variety (0.8.18): never the same single obstacle three times running
		var tries := 0
		while tries < 4 and phrase.size() == 1 and hist.size() >= 2 and phrase[0] == hist[-1] and phrase[0] == hist[-2] and pool.size() > 1:
			phrase = _pick_phrase(rng, pool, ld, false)
			tries += 1
		for step in phrase:
			if step is float:
				t += step
				continue
			if step == CART:
				t += 0.55
			elif step == TOWER:
				t += 0.25
			var o := make(step, x0 + t * sp, sp, rng)
			placed.append(o)
			hist.append(step)
			t += obstacle_extent(o) / sp
		t += lerpf(1.45, 0.62, ld) + rng.randf_range(0.0, lerpf(0.5, 0.25, ld)) + (1.0 - ramp) * 0.8
	var seg_end := x0 + secs * sp
	_validate(placed, x0, seg_end, sp)
	for o in placed:
		obs.append(o)
	_place_motes(placed, x0, seg_end, sp, rng)
	end_x = max(end_x, seg_end)
	return seg_end

func _pick_phrase(rng: RandomNumberGenerator, types: Array, diff: float, combos: bool) -> Array:
	if combos and diff > 0.35 and rng.randf() < 0.18 + diff * 0.3:
		var c: Array = []
		if types.has(BEAM):
			c.append([HURDLE, 0.42, BEAM])      # hop, dive, scoot: Swoop line
			c.append([BEAM, 0.5, HURDLE])
		if types.has(GAP):
			c.append([GAP, 0.48, HURDLE])
			c.append([HURDLE, 0.62, GAP])
		if types.has(GATE):
			c.append([GATE, 0.5, GAP])
			c.append([BEAM, 0.45, GATE])
		if types.has(BLOOM):
			c.append([GAP, 0.7, BLOOM])
		if types.has(FLOCK):
			c.append([FLOCK, 0.55, HURDLE])
			c.append([HURDLE, 0.6, FLOCK])
		if types.has(TOWER):
			c.append([BEAM, 0.6, TOWER])
		if types.has(CART):
			c.append([CART, 0.6, BEAM])
		c.append([HURDLE, 0.6, HURDLE])
		return c[rng.randi() % c.size()]
	return [types[rng.randi() % types.size()]]

# ---------------------------------------------------------------- fairness
func _validate(placed: Array, x0: float, seg_end: float, sp: float) -> void:
	var guard := 0
	while guard < 60:
		guard += 1
		var fail_i := bot_run(placed, x0, seg_end, sp)
		if fail_i < 0:
			return
		var o: Dictionary = placed[fail_i]
		o.tries = o.get("tries", 0) + 1
		if o.tries > 5:
			placed.remove_at(fail_i)
			validation_drops += 1
		else:
			var shift := sp * 0.3
			for k in range(fail_i, placed.size()):
				_shift(placed[k], shift)
			validation_fixes += 1
		# keep inside segment
		while placed.size() > 0 and placed[-1].x + obstacle_extent(placed[-1]) > seg_end - sp * 0.4:
			placed.pop_back()

static func _shift(o: Dictionary, dx: float) -> void:
	o.x += dx
	if o.has("bell_x"):
		o.bell_x += dx
	if o.has("wall_x"):
		o.wall_x += dx
	if o.has("x0"):
		o.x0 += dx

## Replays the segment with the solver bot. Returns the index of the first
## obstacle that caused a failure, or -1 when the whole segment is clear.
func bot_run(placed: Array, x0: float, seg_end: float, sp: float) -> int:
	var tr = get_script().new()
	tr.obs = placed.duplicate(true)
	var s = Sim.new()
	s.track = tr
	s.v = sp
	s.x = x0
	s.bot_mode = true
	var steps := int((seg_end - x0) / sp * 120.0) + 240
	for i in steps:
		if s.x >= seg_end:
			break
		var inp := bot_input(s)
		s.step(1.0 / 120.0, inp)
		for e in s.events:
			if e.type == "rescue":
				# Scripted: the stranger carries Kavi past it.
				var r: Dictionary = e.o
				r.passed = true
				s.x = r.x + r.w + 40.0
				s.y = 0.0
				s.vy = 0.0
				s.on_ground = true
		if s.dead:
			var idx: int = tr.first_index_after(s.x - Sim.HALF_W - 4.0)
			return clampi(idx, 0, placed.size() - 1) if placed.size() > 0 else -1
	return -1

## Solver bot: reacts to the next obstacle the way a careful player would.
static func bot_input(s) -> Dictionary:
	var inp := {"jump_pressed": false, "jump_held": false, "down_pressed": false,
		"down_held": false, "gust_pressed": false, "letter_pressed": false}
	var tr = s.track
	var i: int = tr.first_index_after(s.x - Sim.HALF_W)
	if i >= tr.obs.size():
		return inp
	var o: Dictionary = tr.obs[i]
	var sp: float = s.cur_speed()
	var d: float = o.x - (s.x + Sim.HALF_W)
	# Airborne: hold while rising; hover only when the plain landing is in a hole.
	inp.jump_held = not s.on_ground and (s.vy < 0.0 or _landing_in_hole(s, sp))
	match o.t:
		HURDLE:
			if s.on_ground and d <= sp * 0.12 and d > -30.0:
				inp.jump_pressed = true
				inp.jump_held = true
		CART:
			var closing: float = sp + (o.cv if o.get("rolling", false) else 0.0)
			if s.on_ground and d <= closing * 0.11 and d > -30.0:
				inp.jump_pressed = true
				inp.jump_held = true
		TOWER:
			if s.on_ground and d <= sp * 0.22 and d > -30.0:
				inp.jump_pressed = true
			# hold through the top so the hover carries Kavi over
			if (s.on_ground and inp.jump_pressed) or (not s.on_ground and s.x - Sim.HALF_W < o.x + o.w + 10.0):
				inp.jump_held = true
		FLOCK:
			if not o.open and d < 200.0 and s.gust_cd <= 0.0:
				inp.gust_pressed = true
			elif not o.open and s.on_ground and d < sp * 0.14:
				inp.down_held = true
				inp.down_pressed = not s.sliding
		BEAM:
			if s.on_ground and d < sp * 0.14:
				inp.down_held = true
				inp.down_pressed = not s.sliding
			elif not s.on_ground and d < sp * 0.6:
				inp.down_pressed = not s.diving
				inp.down_held = true
			if d < 0.0:
				inp.down_held = true
		GAP, WIDE_GAP:
			if s.on_ground and d <= 2.0:
				inp.jump_pressed = true
			inp.jump_held = inp.jump_held or inp.jump_pressed
		GATE:
			if not o.open and d < 200.0:
				inp.gust_pressed = true
		BELL:
			var bd: float = o.bell_x - s.x
			if not o.open and bd < 1000.0 and s.planes.size() == 0 and s.letter_cd <= 0.0:
				inp.letter_pressed = true
		BLOOM:
			var pc: float = o.x + o.w * 0.5
			if s.on_ground and d <= sp * 0.40 and d > 0.0:
				inp.jump_pressed = true
				inp.jump_held = true
			elif not s.on_ground and not s.diving and s.x < o.x + o.w:
				var a := Sim.G * 0.5
				var b := Sim.DIVE_V
				var c: float = s.y
				var tf := (-b + sqrt(maxf(b * b - 4.0 * a * c, 0.0))) / (2.0 * a)
				var land_x: float = s.x + sp * tf
				if land_x >= pc - 25.0:
					inp.down_pressed = true
		RESCUE:
			pass
	return inp

static func _landing_in_hole(s, sp: float) -> bool:
	var a := Sim.G * 0.5
	var tf: float = (-s.vy + sqrt(maxf(s.vy * s.vy - 4.0 * a * s.y, 0.0))) / (2.0 * a)
	var lx: float = s.x + sp * tf
	return s.track.hole_at(lx) or s.track.hole_at(lx - 30.0) or s.track.hole_at(s.x)

# ---------------------------------------------------------------- collectibles
func _place_motes(placed: Array, x0: float, seg_end: float, sp: float, rng: RandomNumberGenerator) -> void:
	for o in placed:
		match o.t:
			TOWER:
				for k in 5:
					var f := float(k) / 4.0
					motes.append({"x": o.x - 90.0 + (o.w + 200.0) * f, "y": -90.0 - sin(f * PI) * 190.0, "taken": false})
			FLOCK:
				for k in 3:
					motes.append({"x": o.x + o.w * (0.2 + 0.3 * k), "y": -26.0, "taken": false})
			HURDLE, GAP, WIDE_GAP:
				# arc along an ideal jump
				var n := 5
				var span: float = maxf(o.w + 120.0, sp * 0.6)
				for k in n:
					var f := float(k) / float(n - 1)
					motes.append({"x": o.x - 60.0 + span * f, "y": -60.0 - sin(f * PI) * 150.0, "taken": false})
			BEAM:
				for k in 4:
					motes.append({"x": o.x + o.w * (0.15 + 0.23 * k), "y": -26.0, "taken": false})
			BLOOM:
				for k in 4:
					motes.append({"x": o.wall_x - 40.0 + k * 50.0, "y": -360.0 - sin(k * 0.9) * 40.0, "taken": false})
	# a few ground trails in calm stretches
	var x := x0 + sp * 0.5
	while x < seg_end:
		if rng.randf() < 0.35 and not _near_obstacle(placed, x, 260.0):
			for k in 3:
				motes.append({"x": x + k * 46.0, "y": -40.0, "taken": false})
		x += sp * 0.9
	motes.sort_custom(func(a, b): return a.x < b.x)

static func _near_obstacle(placed: Array, x: float, r: float) -> bool:
	for o in placed:
		if x > o.x - r and x < o.x + obstacle_extent(o) + r:
			return true
	return false
