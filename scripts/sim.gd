extends RefCounted
## Deterministic Kite simulation (120 Hz). Shared by the game and the
## fairness bot so "the bot can clear it" means "a player can clear it".

const G := 3000.0
const JUMP_V := 1050.0
const CUT := 0.45
const HOVER_FALL := 150.0
const HOVER_FUEL := 0.9
const DIVE_V := 1900.0
const BLOOM_V := 1560.0
const STAND_H := 100.0
const SLIDE_H := 46.0
const HALF_W := 22.0
const GUST_RANGE := 270.0
const LETTER_MAX := 3
const LETTER_RECHARGE := 3.2
const SWOOP_T := 0.75
const SWOOP_MULT := 1.32
const COYOTE := 0.09
const BUFFER := 0.13

enum { HURDLE, BEAM, GAP, WIDE_GAP, GATE, BELL, BLOOM, RESCUE }

var track
var x := 0.0
var y := 0.0
var vy := 0.0
var v := 520.0
var on_ground := true
var sliding := false
var diving := false
var hovering := false
var hover_fuel := HOVER_FUEL
var swoop_t := 0.0
var jump_cut := false
var dead := false
var fail_reason := ""
var letters := LETTER_MAX
var letter_t := 0.0
var letter_cd := 0.0
var gust_t := 0.0
var gust_cd := 0.0
var throw_t := 0.0
var coyote := 0.0
var jump_buf := 0.0
var air_t := 0.0
var land_t := 0.0
var planes: Array = []
var events: Array = []
var kind_mode := false
var assist_hover := false
var bot_mode := false
var frozen := false
var speed_scale := 1.0

func cur_speed() -> float:
	return v * speed_scale * (SWOOP_MULT if swoop_t > 0.0 else 1.0)

func height() -> float:
	return SLIDE_H if sliding else STAND_H

func _emit(type: String, extra := {}) -> void:
	var e := {"type": type}
	e.merge(extra)
	events.append(e)

func step(dt: float, inp: Dictionary) -> void:
	events.clear()
	if dead or frozen:
		return
	var sp := cur_speed()
	x += sp * dt
	swoop_t = maxf(swoop_t - dt, 0.0)
	gust_t = maxf(gust_t - dt, 0.0)
	gust_cd = maxf(gust_cd - dt, 0.0)
	throw_t = maxf(throw_t - dt, 0.0)
	letter_cd = maxf(letter_cd - dt, 0.0)
	coyote = maxf(coyote - dt, 0.0)
	jump_buf = maxf(jump_buf - dt, 0.0)
	land_t += dt
	if letters < LETTER_MAX:
		letter_t += dt
		if letter_t >= LETTER_RECHARGE:
			letter_t = 0.0
			letters += 1
	if inp.jump_pressed:
		jump_buf = BUFFER

	# ---- jump
	if jump_buf > 0.0 and (on_ground or coyote > 0.0) and not _under_beam():
		_jump(sp)

	# ---- ground / air
	if on_ground:
		if track.hole_at(x, kind_mode):
			on_ground = false
			coyote = COYOTE
			sliding = false
		else:
			var want_slide: bool = inp.down_held or _under_beam()
			if want_slide and not sliding:
				_slide_start(sp)
			sliding = want_slide
	if not on_ground:
		air_t += dt
		if inp.down_pressed and not diving and coyote <= 0.0:
			diving = true
			hovering = false
			vy = maxf(vy, DIVE_V)
			_emit("dive")
		# variable jump height
		if not inp.jump_held and vy < -350.0 and not jump_cut:
			vy *= CUT
			jump_cut = true
		var want_hover: bool = (inp.jump_held or (assist_hover and track.hole_at(x + sp * 0.15))) and vy > -60.0
		if want_hover and not diving and hover_fuel > 0.0:
			if not hovering:
				_emit("hover")
			hovering = true
			hover_fuel -= dt
			vy = minf(vy + G * dt, HOVER_FALL)
		else:
			hovering = false
			vy += G * dt
		var prev_y := y
		y += vy * dt
		if y >= 0.0 and prev_y <= 2.0 and not track.hole_at(x, kind_mode):
			_land(inp, sp)
		elif y > 340.0:
			_fail("fall")
			return

	# ---- abilities
	if inp.gust_pressed and gust_cd <= 0.0:
		_gust()
	if inp.letter_pressed and letters > 0 and letter_cd <= 0.0:
		_letter(sp)
	_update_planes(dt, sp)

	# ---- collisions and clears
	_collide()

func _jump(sp: float) -> void:
	var o = _next_of([HURDLE, GAP, WIDE_GAP, BLOOM])
	if o != null and not o.perf:
		var d: float = o.x - (x + HALF_W)
		match o.t:
			HURDLE:
				o.perf = d >= sp * 0.05 and d <= sp * 0.17
			GAP, WIDE_GAP:
				o.perf = d >= -HALF_W - 6.0 and d <= sp * 0.09
	on_ground = false
	sliding = false
	diving = false
	hovering = false
	jump_cut = false
	coyote = 0.0
	jump_buf = 0.0
	air_t = 0.0
	vy = -JUMP_V
	_emit("jump")

func _slide_start(sp: float) -> void:
	var o = _next_of([BEAM])
	if o != null and not o.perf:
		var d: float = o.x - (x + HALF_W)
		o.perf = d >= -4.0 and d <= sp * 0.18
	_emit("slide")

func _land(inp: Dictionary, sp: float) -> void:
	y = 0.0
	var impact := vy
	var pad = _pad_under()
	if pad != null:
		var strong := impact > 1300.0
		vy = -BLOOM_V if strong else -720.0
		if strong and absf(x - (pad.x + pad.w * 0.5)) < 38.0:
			pad.perf = true
		diving = false
		hovering = false
		jump_cut = true
		hover_fuel = HOVER_FUEL
		_emit("bloom", {"strong": strong, "o": pad})
		return
	on_ground = true
	hover_fuel = HOVER_FUEL
	land_t = 0.0
	if diving and inp.down_held:
		swoop_t = SWOOP_T
		sliding = true
		_emit("swoop")
	elif inp.down_held:
		sliding = true
	diving = false
	hovering = false
	vy = 0.0
	_emit("land", {"impact": impact})

func _gust() -> void:
	gust_t = 0.35
	gust_cd = 0.42
	_emit("gust")
	var i: int = track.first_index_after(x - HALF_W)
	for k in range(i, mini(i + 4, track.obs.size())):
		var o: Dictionary = track.obs[k]
		if o.t != GATE or o.open:
			continue
		var d: float = o.x - (x + HALF_W)
		if d >= -12.0 and d <= GUST_RANGE:
			o.open = true
			o.perf = d <= 130.0
			_emit("gate_open", {"o": o, "perfect": o.perf})

func _letter(sp: float) -> void:
	letters -= 1
	letter_cd = 0.35
	throw_t = 0.3
	var target = null
	var i: int = track.first_index_after(x - HALF_W)
	for k in range(i, mini(i + 6, track.obs.size())):
		var o: Dictionary = track.obs[k]
		if o.t == BELL and not o.open and o.bell_x - x < 1500.0 and o.bell_x > x - 40.0:
			target = o
			break
	planes.append({"x": x + 18.0, "y": y - 70.0, "vx": sp + 900.0, "vy": -260.0,
		"t": 0.0, "target": target, "from_x": x})
	_emit("letter")

func _update_planes(dt: float, sp: float) -> void:
	for p in planes:
		p.t += dt
		if p.target != null and not p.target.open:
			var to := Vector2(p.target.bell_x - p.x, p.target.bell_y - p.y)
			var spd := maxf(sp + 1100.0, 1500.0)
			var want := to.normalized() * spd
			var vel := Vector2(p.vx, p.vy).lerp(want, minf(dt * 9.0, 1.0))
			p.vx = vel.x
			p.vy = vel.y
			if to.length() < 46.0:
				p.target.open = true
				p.target.perf = p.x - p.from_x > 560.0
				_emit("bell", {"o": p.target, "perfect": p.target.perf})
				p.t = 99.0
		else:
			p.vy += 300.0 * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
	planes = planes.filter(func(p): return p.t < 1.6)

func _collide() -> void:
	var h := height()
	var top := y - h
	var l := x - HALF_W
	var r := x + HALF_W
	var i: int = track.first_index_after(l - 10.0)
	for k in range(i, mini(i + 5, track.obs.size())):
		var o: Dictionary = track.obs[k]
		if o.x > r + 2.0:
			break
		var hit := false
		match o.t:
			HURDLE:
				hit = r > o.x and l < o.x + o.w and y > -o.h
			BEAM:
				hit = r > o.x and l < o.x + o.w and top < -o.h
			GATE:
				hit = not o.open and r > o.x and l < o.x + o.w
			BLOOM:
				hit = r > o.wall_x and l < o.wall_x + o.wall_w and y > -o.wall_h
			RESCUE:
				if not o.passed and x > o.x - cur_speed() * 0.32:
					o.passed = true
					_emit("rescue", {"o": o})
		if hit:
			if kind_mode:
				if not o.get("bonked", false):
					o.bonked = true
					_emit("bonk", {"o": o})
				continue
			_fail(Sim_name(o.t))
			return
	# clears
	for k in range(maxi(i - 2, 0), mini(i + 3, track.obs.size())):
		var o: Dictionary = track.obs[k]
		if not o.passed and l > o.x + _extent(o):
			o.passed = true
			if o.t != RESCUE:
				_emit("clear", {"o": o, "perfect": o.perf and not o.get("bonked", false)})

static func Sim_name(t: int) -> String:
	return ["hurdle", "beam", "gap", "wide_gap", "gate", "bell", "bloom", "rescue"][t]

static func _extent(o: Dictionary) -> float:
	if o.t == BLOOM:
		return o.wall_x + o.wall_w - o.x
	return o.w

func _fail(reason: String) -> void:
	dead = true
	fail_reason = reason
	_emit("fail", {"reason": reason})

func _under_beam() -> bool:
	var i: int = track.first_index_after(x - HALF_W - 4.0)
	for k in range(i, mini(i + 3, track.obs.size())):
		var o: Dictionary = track.obs[k]
		if o.t == BEAM and x + HALF_W > o.x and x - HALF_W < o.x + o.w:
			return true
	return false

func _pad_under() -> Variant:
	var i: int = track.first_index_after(x - HALF_W - 4.0)
	for k in range(i, mini(i + 3, track.obs.size())):
		var o: Dictionary = track.obs[k]
		if o.t == BLOOM and x >= o.x - 6.0 and x <= o.x + o.w + 6.0:
			return o
	return null

func _next_of(types: Array) -> Variant:
	var i: int = track.first_index_after(x - HALF_W)
	for k in range(i, mini(i + 4, track.obs.size())):
		var o: Dictionary = track.obs[k]
		if types.has(o.t) and o.x + _extent(o) > x - HALF_W:
			return o
	return null

## Put Kite back on solid ground before `px` (story checkpoints).
func respawn(px: float) -> void:
	x = px
	y = 0.0
	vy = 0.0
	on_ground = true
	sliding = false
	diving = false
	hovering = false
	dead = false
	swoop_t = 0.0
	planes.clear()
	for o in track.obs:
		if o.x > px - 10.0:
			o.passed = false
			o.perf = false
			if o.t == GATE or o.t == BELL:
				o.open = false
