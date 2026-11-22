extends Node2D
## Kite, drawn procedurally from the v2 character spec (white/teal shell,
## white helmet, dark screen face with cyan eyes, orange scarf, kite antenna,
## maroon thruster pack). One geometry pass is painted twice: once normally
## and once additively for the emissive parts (eyes, lights, thrusters).

const Art = preload("res://scripts/art.gd")
const Painter = preload("res://scripts/painter.gd")

# Wearable colours (Garage). Defaults are the classic courier look.
var SHELL := Color8(254, 240, 216)
var SHADE := Color(0.84, 0.74, 0.58)
var TEAL := Color8(58, 169, 162)
const JOINT := Color(0.32, 0.58, 0.74)
const BOOT := Color(0.14, 0.34, 0.90)
const PACK := Color(0.55, 0.15, 0.20)
var GLOW := Color(0.30, 1.0, 1.0)
var scarf_col := Color8(255, 124, 42)
var scarf_col2 := Color8(255, 124, 42)
var scarf_pattern := "solid"
var tip := "kite"
var helmet := "round"
## Face: where the eyes look (-1..1 each axis), eased towards look_target.
var look := Vector2(1, 0)
## Air state from the sim (main sets these), for wobbly hovers and rough landings.
var grounded := true
var _air_t := 0.0
var _hover_t := 0.0
var _fall_vy := 0.0
var stumble_t := 0.0
const STUMBLE := 0.5
var look_target := Vector2(1, 0)
var _look_next := 0.0

func set_look(l: Dictionary) -> void:
	SHELL = l.shell
	SHADE = l.shade
	TEAL = l.accent
	GLOW = l.eye
	scarf_col = l.scarf
	scarf_col2 = l.scarf2
	scarf_pattern = l.pattern
	tip = l.tip
	helmet = l.helmet
	_push_swap()
const INK := Color(0.04, 0.06, 0.11)
const VISOR := Color(0.03, 0.05, 0.09)
const SCARVES := [Color(1.0, 0.35, 0.14), Color(0.30, 0.65, 1.0), Color(1.0, 0.45, 0.65),
	Color(1.0, 0.80, 0.25), Color(0.35, 0.95, 0.65), Color(0.70, 0.45, 1.0)]
const TIER_COL := [Color(0.3, 1.0, 1.0), Color(0.45, 1.0, 0.6), Color(1.0, 0.75, 0.3), Color(1.0, 0.45, 0.85)]

var pose = "run"
var phase = 0.0
var expr = "normal"
var tier = 1
var scarf = 0
var speed = 520.0
var vy = 0.0
var rim: Color = Color(1.0, 0.8, 0.6)
var t = 0.0
var act_t = 0.0 # time in current pose (for one-shot anims)
var facing = 1.0
var s = 1.15
var reduced_motion = false
var blink_t = 0.0
var trail_on = true

var _scarf_pts: Array = []
var _scarf_prev: Array = []

## Run cycle: a planted foot slides back exactly as fast as the ground moves,
## so feet stick to the ground (the old cycle pushed the planted foot forward,
## which read as running backwards).
const STRIDE := 22.0       # half stride, body units
const CONTACT := 0.36      # fraction of the cycle a foot is planted
const SCARF_N := 12
const SCARF_SEG := 5.6
var _trail: Array = []
var _base: Node2D
var _add: Node2D
var _last_pose = ""

func _ready() -> void:
	_base = Painter.new()
	_base.fn = _paint.bind(false)
	add_child(_base)
	_add = Painter.new()
	_add.fn = _paint.bind(true)
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = m
	add_child(_add)
	_make_art_painter()
	_push_swap()

func tick(dt: float) -> void:
	t += dt
	if pose != _last_pose:
		act_t = 0.0
		_last_pose = pose
	act_t += dt
	match pose:
		"run": phase += dt * speed * TAU / (220.0 * K * s * _run_amp())
		"walk": phase += dt * 6.5
		"slide": phase += dt * 30.0
	blink_t -= dt
	if blink_t < -0.12:
		# sometimes a quick double blink
		blink_t = 0.25 if randf() < 0.18 else randf_range(2.5, 4.5)
	_update_look(dt)
	_update_air(dt)
	_turn = move_toward(_turn, 1.0 if pose in FRONT_POSES else 0.0, dt / 0.3)
	_update_scarf(dt)
	_update_trail()
	_base.queue_redraw()
	_add.queue_redraw()
	if _art:
		_art.queue_redraw()
		var hdr := 1.0 if (get_viewport() and get_viewport().use_hdr_2d and RenderingServer.get_current_rendering_method() != "gl_compatibility") else 0.0
		_swap.set_shader_parameter("encode", hdr)
		if scarf_pattern == "rainbow":
			_swap.set_shader_parameter("time_s", t)

func reset_scarf() -> void:
	_scarf_pts.clear()
	_trail.clear()

func _neck_world() -> Vector2:
	var p = _pose_params()
	return global_position + (Vector2(2, -62) * s).rotated(p.rot) + p.off * s

func _update_air(dt: float) -> void:
	stumble_t = maxf(stumble_t - dt, 0.0)
	if not grounded:
		_air_t += dt
		if pose == "hover":
			_hover_t += dt
		_fall_vy = maxf(_fall_vy, vy)
		return
	if _air_t > 0.0:
		# just landed: after a long wobbly hover or a big drop, sometimes land
		# rough, stumble forward and pop back up (visual only)
		if (_hover_t > 0.7 or _fall_vy > 1100.0) and randf() < 0.6 and not reduced_motion:
			stumble_t = STUMBLE
			expr = "wow"
	_air_t = 0.0
	_hover_t = 0.0
	_fall_vy = 0.0

## 0 at a gentle jog .. 1 at top speed.
func _speed_k() -> float:
	return clampf((speed - 300.0) / 600.0, 0.0, 1.0)

## Stride size: longer strides as speed rises (feet still match the ground).
func _run_amp() -> float:
	return 1.0 + 0.9 * _speed_k()

func _update_scarf(dt: float) -> void:
	var anchor = _neck_world()
	if _scarf_pts.size() != SCARF_N or anchor.distance_to(_scarf_pts[0]) > 220.0:
		_scarf_pts.clear()
		_scarf_prev.clear()
		for k in SCARF_N:
			var q = anchor + Vector2(-k * SCARF_SEG * s, k * 1.5)
			_scarf_pts.append(q)
			_scarf_prev.append(q)
	var shift: Vector2 = anchor - _scarf_pts[0]
	if pose == "run" and speed <= 0.0:
		# frozen moment (tutorial prompt / pause): hold the shape
		for k in SCARF_N:
			_scarf_pts[k] += shift
			_scarf_prev[k] += shift
		return
	dt = minf(dt, 1.0 / 30.0)
	var calm_pose = pose in ["idle", "wave", "sit", "eat", "drink", "map", "photo", "read", "stretch"]
	var spd = clampf(speed / 520.0, 0.25, 1.4) if not calm_pose else 0.18
	var flap = (1.0 if not reduced_motion else 0.35) * spd
	var drag = pow(0.32, dt * 60.0)
	_scarf_pts[0] = anchor
	_scarf_prev[0] = anchor
	for k in range(1, SCARF_N):
		var q: Vector2 = _scarf_pts[k]
		var v: Vector2 = (q - _scarf_prev[k]) * drag  # cloth in still air: strong drag, so it trails
		var f = float(k) / (SCARF_N - 1)
		# a ripple that travels from the neck to the tip
		var wave = sin(t * 17.0 - k * 0.85) * 1500.0 * f * flap + sin(t * 9.0 - k * 0.5) * 500.0 * f * flap
		var acc = Vector2(-140.0 if calm_pose else 0.0, 260.0 + wave)
		_scarf_prev[k] = q
		_scarf_pts[k] = q + v + acc * dt * dt
	var L = SCARF_SEG * s
	for it in 3:
		for k in range(1, SCARF_N):
			var d: Vector2 = _scarf_pts[k] - _scarf_pts[k - 1]
			var dl = d.length()
			if dl > L:
				_scarf_pts[k] = _scarf_pts[k - 1] + d / dl * L

func _update_trail() -> void:
	if not trail_on or tier < 3 or pose in ["idle", "sit", "wave", "walk"]:
		if _trail.size() > 0:
			_trail.pop_front()
		return
	var np = global_position + Vector2(-26, -48) * s
	if _trail.size() > 0 and np.distance_to(_trail[-1]) > 140.0:
		_trail.clear()
	_trail.append(np)
	while _trail.size() > 14:
		_trail.pop_front()

# ------------------------------------------------------------------ pose
func _pose_params() -> Dictionary:
	var p = {"rot": 0.0, "off": Vector2.ZERO, "sq": Vector2.ONE, "ff": Vector2(8, 0), "fb": Vector2(-8, 0),
		"hf": Vector2(10, 18), "hb": Vector2(-8, 18), "thrust": 0.0, "wheels": false, "head": 0.0, "jets": false}
	var ph = phase
	match pose:
		"run", "walk":
			# Calm upper body, busy legs: the faster he runs, the longer the
			# stride and the more lean, while bob and head nod stay tiny.
			var k := _speed_k()
			var amp := _run_amp() if pose == "run" else 0.6
			var u = phase / TAU
			var fa = _leg(u, amp)
			var fbk = _leg(u + 0.5, amp)
			# body: two small bobs per stride, lowest just after each landing
			var bob_ph = TAU * 2.0 * (u - 0.07)
			var bob = cos(bob_ph)
			p.off = Vector2(0, (bob * 1.1 - 0.4) * amp)
			p.rot = (0.05 + 0.06 * k + 0.008 * sin(bob_ph)) * amp
			var land = pow(maxf(0.0, bob), 4.0)
			p.sq = Vector2(1.0 + 0.015 * land * amp, 1.0 - 0.015 * land * amp)
			# the head stays nearly level (counter the lean) so the screen face reads
			p.head = -p.rot * 0.65 - 0.012 * cos(bob_ph - 0.7)
			if stumble_t > 0.0:
				# rough landing: lurch forward, hands out to catch, spring back up
				var e := sin((1.0 - stumble_t / STUMBLE) * PI)
				p.rot += 0.42 * e
				p.off.y += 7.0 * e
				p.sq = Vector2(1.0 + 0.06 * e, 1.0 - 0.06 * e)
				p.hf = p.hf.lerp(Vector2(22, 26), e)
				p.hb = p.hb.lerp(Vector2(12, 28), e)
				p.head -= 0.15 * e
			# keep the feet on the ground through the bob, lean and squash
			var sr = sin(p.rot)
			var cr = cos(p.rot)
			fa.y = (fa.y - p.off.y - fa.x * p.sq.x * sr) / (p.sq.y * cr)
			fbk.y = (fbk.y - p.off.y - fbk.x * p.sq.x * sr) / (p.sq.y * cr)
			p.ff = fa
			p.fb = fbk
			# arms swing against the legs; the forward hand rises (bent elbow)
			var sa = clampf(fa.x / (STRIDE * amp), -1.0, 1.0)
			var sb = clampf(fbk.x / (STRIDE * amp), -1.0, 1.0)
			p.hf = Vector2(-sa * 10.0 * amp + 4.0, 18.0 - maxf(0.0, -sa) * 9.0 * amp)
			p.hb = Vector2(-sb * 10.0 * amp - 2.0, 18.0 - maxf(0.0, -sb) * 9.0 * amp)
		"jump":
			p.ff = Vector2(12, -18)
			p.fb = Vector2(-10, -8)
			p.hf = Vector2(14, -8)
			p.hb = Vector2(-14, 4)
			p.sq = Vector2(0.92, 1.08) if act_t < 0.12 else Vector2.ONE
			p.rot = -0.05
		"fall":
			p.ff = Vector2(8, -4)
			p.fb = Vector2(-6, -2)
			p.hf = Vector2(16, 2)
			p.hb = Vector2(-16, 0)
		"hover":
			# all thrusters on: bag, hands and feet; he wobbles and kicks
			var w1 := sin(t * 7.0)
			var w2 := sin(t * 11.0 + 1.3)
			var wob := 1.0 if not reduced_motion else 0.3
			p.rot = 0.04 + (w1 * 0.10 + w2 * 0.04) * wob
			p.off = Vector2(w2 * 2.0, w1 * 3.0) * wob
			p.ff = Vector2(6 + sin(t * 13.0) * 7.0, 2 + cos(t * 13.0) * 3.0)
			p.fb = Vector2(-8 - sin(t * 13.0) * 7.0, 4)
			p.hf = Vector2(24 + sin(t * 9.0) * 5.0, 4 + cos(t * 9.0) * 9.0)
			p.hb = Vector2(-22 - sin(t * 9.0) * 5.0, 6 - cos(t * 9.0) * 9.0)
			p.thrust = 1.0
			p.jets = true
		"slide":
			p.rot = -0.95
			p.off = Vector2(-6, 18)
			p.ff = Vector2(22, -2)
			p.fb = Vector2(18, 4)
			p.hf = Vector2(-2, 18)
			p.hb = Vector2(-10, 20)
			p.wheels = true
		"dive":
			p.rot = 0.55
			p.ff = Vector2(-12, -6)
			p.fb = Vector2(-18, 2)
			p.hf = Vector2(-12, 10)
			p.hb = Vector2(-16, 6)
			p.thrust = 0.8
			p.sq = Vector2(0.9, 1.12)
		"gust":
			p.ff = Vector2(14, 0)
			p.fb = Vector2(-12, 0)
			p.hf = Vector2(30, -2)
			p.hb = Vector2(-12, 14)
			p.rot = 0.12
		"throw":
			var k = clampf(act_t / 0.18, 0.0, 1.0)
			p.ff = Vector2(10, 0)
			p.fb = Vector2(-10, 0)
			p.hf = Vector2(-18, -22).lerp(Vector2(26, -14), k)
			p.hb = Vector2(-10, 16)
		"fail":
			p.rot = act_t * 7.0
			p.ff = Vector2(10, -10)
			p.fb = Vector2(-10, -10)
			p.hf = Vector2(18, -16)
			p.hb = Vector2(-18, -16)
		"idle":
			# standing tall: straight legs, arms relaxed at the sides, slow breath
			var br := sin(t * 1.8)
			p.off = Vector2(0, -5.0)
			p.ff = Vector2(7, 5)
			p.fb = Vector2(-6, 5)
			p.hf = Vector2(10, 23 + br * 0.6)
			p.hb = Vector2(-10, 23 + br * 0.6)
			p.sq = Vector2(1.0 - 0.006 * br, 1.0 + 0.008 * br)
		"wave":
			p.off = Vector2(0, -5.0)
			p.ff = Vector2(7, 5)
			p.fb = Vector2(-6, 5)
			p.hf = Vector2(38 + sin(t * 10.0) * 5.0, -24)
			p.hb = Vector2(-10, 23)
			p.head = 0.06
		"sit":
			p.off = Vector2(0, 14)
			p.ff = Vector2(20, -8)
			p.fb = Vector2(16, -6)
			p.hf = Vector2(16, 8)
			p.hb = Vector2(12, 10)
		"ride":
			p.off = Vector2(0, 4)
			p.ff = Vector2(18, -14)
			p.fb = Vector2(14, -12)
			p.hf = Vector2(22, 4)
			p.hb = Vector2(18, 6)
			p.rot = 0.1
		"eat", "drink", "map", "photo", "read":
			p.hf = Vector2(16, -16) if pose in ["eat", "drink", "photo"] else Vector2(20, 2)
			p.hb = Vector2(10, 6) if pose != "eat" else Vector2(-6, 18)
			p.off = Vector2(0, sin(t * 2.0) * 1.2)
		"stretch":
			var k2 = 0.5 + 0.5 * sin(t * 2.0)
			p.hf = Vector2(8, -40 * k2 + 10)
			p.hb = Vector2(-8, -40 * k2 + 10)
			p.sq = Vector2(1.0 - 0.04 * k2, 1.0 + 0.05 * k2)
	return p

## Foot position over one stride (u in 0..1): planted, sliding back at
## ground speed; then lifted, tucked up behind and swung forward.
static func _leg(u: float, amp: float) -> Vector2:
	u = fposmod(u, 1.0)
	var S = STRIDE * amp
	if u < CONTACT:
		return Vector2(lerpf(S, -S, u / CONTACT), 0.0)
	var k = (u - CONTACT) / (1.0 - CONTACT)
	var e = k * k * (3.0 - 2.0 * k)
	var lift = sin(pow(k, 0.7) * PI) * 18.0 * amp
	return Vector2(lerpf(-S, S, e), -lift)

static func _ik(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d = b - a
	var L = clampf(d.length(), 0.01, l1 + l2 - 0.01)
	var cos_a = (l1 * l1 + L * L - l2 * l2) / (2.0 * l1 * L)
	var ang = acos(clampf(cos_a, -1.0, 1.0))
	return a + d.normalized().rotated(-ang * bend) * l1

# ------------------------------------------------------------------ paint
func _poly(ci: Node2D, pts: PackedVector2Array, fill: Color, ink := true) -> void:
	ci.draw_colored_polygon(pts, fill)
	if ink and Art.Q >= 1:
		var c = pts.duplicate()
		c.append(pts[0])
		ci.draw_polyline(c, INK, 2.2, Art.AA)

## A limb is one inked capsule: 2 draw calls instead of 6.
func _limb(ci: Node2D, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_colored_polygon(_capsule(a, b, (w + 4.0) * 0.5), INK)
	ci.draw_colored_polygon(_capsule(a, b, w * 0.5), col)

static func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var d := b - a
	var ang := d.angle() if d.length() > 0.01 else 0.0
	var p := PackedVector2Array()
	for i in 7:
		var t := ang + PI * 0.5 + PI * float(i) / 6.0
		p.append(a + Vector2(cos(t), sin(t)) * r)
	for i in 7:
		var t := ang - PI * 0.5 + PI * float(i) / 6.0
		p.append(b + Vector2(cos(t), sin(t)) * r)
	return p

## Kavi E (owner-approved design from Codex, 2026-11-23: "keystone floating").
## A big keystone helmet whose front is a dark screen face, a teal diamond
## antenna, a small cream body with a teal collar, a brown courier satchel
## with an envelope and two jet nozzles, an orange scarf, dark mittens and
## cream boots with teal toes. Two body treatments for the owner's comparison:
## floating hands and boots (default) or jointed limbs.
## Everything is drawn in the reference rig's pixels (origin at the pelvis,
## +y down, floor 73.5 below) and scaled by K into body units.
const K := 0.56
const FLOOR := 73.5
const THIGH := 33.5
const SHIN := 33.0
const UPPER := 24.0
const FORE := 21.0
const BAG := Color(0.55, 0.33, 0.22)
const STRAP := Color(0.36, 0.20, 0.14)
const MITT := Color(0.17, 0.18, 0.21)
const INK4 := Color(0.07, 0.07, 0.09)
static var _stride: Dictionary = {}
var limbs := "jointed"   # or "floating" (Settings: Kavi's limbs)

static func _load_stride() -> void:
	if not _stride.is_empty():
		return
	var f := FileAccess.open("res://assets/kavi/stride.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_stride = d

static func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

## Run/walk pose sampled from Codex's comparison rig (one cycle, 28 frames),
## interpolated by phase. ax stretches the stride horizontally with speed
## (feet stay planted because the phase rate is divided by the same factor).
func _rig_run(u: float, ax: float, calm: float) -> Dictionary:
	_load_stride()
	var R := {"pelvis": Vector2.ZERO, "tilt": deg_to_rad(14.0)}
	if _stride.is_empty():
		return _rig_static({"ff": Vector2(8, 0), "fb": Vector2(-8, 0), "hf": Vector2(10, 18), "hb": Vector2(-8, 18)})
	var fr: Array = _stride.frames
	var n := fr.size()
	var x := fposmod(u, 1.0) * n
	var i0 := int(floor(x)) % n
	var i1 := (i0 + 1) % n
	var w: float = x - floor(x)
	var A: Dictionary = fr[i0]
	var B: Dictionary = fr[i1]
	R.pelvis = _v(A.pelvis).lerp(_v(B.pelvis), w) * calm
	R.tilt = deg_to_rad(lerpf(float(A.chest_tilt_deg), float(B.chest_tilt_deg), w))
	for side in ["near", "far"]:
		var a: Dictionary = A[side]
		var b: Dictionary = B[side]
		var S := {}
		for key in ["hip", "shoulder", "ankle", "wrist"]:
			S[key] = _v(a[key]).lerp(_v(b[key]), w)
		for key in ["boot", "mitten"]:
			S[key] = _v(a[key]).lerp(_v(b[key]), w)
			S[key + "_rot"] = lerp_angle(deg_to_rad(float(a[key][2])), deg_to_rad(float(b[key][2])), w)
		# stretch the stride (legs fully, arms a little)
		S.ankle.x *= ax
		S.boot.x *= ax
		var axa := 1.0 + (ax - 1.0) * 0.5
		S.wrist.x = S.shoulder.x + (S.wrist.x - S.shoulder.x) * axa
		S.mitten.x = S.shoulder.x + (S.mitten.x - S.shoulder.x) * axa
		R[side] = S
	return R

## Any other pose: from the old pose targets (body units, feet at 0).
func _rig_static(p: Dictionary) -> Dictionary:
	var R := {"pelvis": Vector2.ZERO, "tilt": 0.08}
	var sh := Vector2(8, -43)
	for side in ["near", "far"]:
		var f: Vector2 = p.ff if side == "near" else p.fb
		var h: Vector2 = p.hf if side == "near" else p.hb
		var S := {"hip": Vector2(4, -1) if side == "near" else Vector2(-5, -3), "shoulder": sh if side == "near" else sh + Vector2(0, -2)}
		S.boot = Vector2(f.x / K, f.y / K + FLOOR - 13.0)
		S.ankle = S.boot + Vector2(-8, -6)
		S.boot_rot = clampf(f.y * -0.04, -0.6, 0.6)
		S.mitten = S.shoulder + h / K * 0.62
		S.wrist = S.mitten + (S.shoulder - S.mitten).normalized() * 6.0
		S.mitten_rot = (S.mitten - S.shoulder).angle()
		R[side] = S
	return R

func _rig(p: Dictionary) -> Dictionary:
	if pose in ["run", "walk"] and stumble_t <= 0.0:
		var ax := _run_amp() if pose == "run" else 0.75
		return _rig_run(phase / TAU, ax, 0.6 if not reduced_motion else 0.3)
	return _rig_static(p)

static func _smooth_closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for k in 3:
			var u := k / 3.0
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u))
	return out

static func _knee(a: Vector2, b: Vector2, l1: float, l2: float, fwd: float) -> Vector2:
	var d := b - a
	var L := clampf(d.length(), 0.01, l1 + l2 - 0.01)
	var ca := (l1 * l1 + L * L - l2 * l2) / (2.0 * l1 * L)
	var ang := acos(clampf(ca, -1.0, 1.0))
	var k1 := a + d.normalized().rotated(ang) * l1
	var k2 := a + d.normalized().rotated(-ang) * l1
	return k1 if (k1.x - k2.x) * fwd > 0.0 else k2

func _poly4(ci: Node2D, pts: PackedVector2Array, fill: Color, w := 4.5) -> void:
	ci.draw_colored_polygon(pts, fill)
	if Art.Q >= 1 or w > 0.0:
		var c := pts.duplicate()
		c.append(pts[0])
		ci.draw_polyline(c, INK4, w, Art.AA)

static func _xf(pts: Array, at: Vector2, rot: float, sc := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(at + (q * sc).rotated(rot))
	return out

func _boot4(ci: Node2D, at: Vector2, rot: float, dark := 0.0) -> void:
	# chunky boot with cel shading: lit top, shaded heel, teal toe cap, thick sole
	var sc := 1.3
	var upper := _xf([Vector2(-15, -10), Vector2(3, -13), Vector2(11, -8), Vector2(19, 0), Vector2(19, 7), Vector2(-16, 7), Vector2(-18, 0)], at, rot, sc)
	_poly4(ci, upper, SHELL.darkened(dark))
	ci.draw_colored_polygon(_xf([Vector2(-16, -2), Vector2(-4, -3), Vector2(-4, 6), Vector2(-16, 6)], at, rot, sc), SHADE.darkened(dark))
	ci.draw_colored_polygon(_xf([Vector2(6, -7), Vector2(11, -8), Vector2(19, 0), Vector2(19, 5), Vector2(4, 5)], at, rot, sc), TEAL.darkened(dark))
	ci.draw_line(at + (Vector2(8, -6) * sc).rotated(rot), at + (Vector2(15, -1) * sc).rotated(rot), Color(1, 1, 1, 0.55 * (1.0 - dark)), 2.5, true)
	ci.draw_line(at + (Vector2(-12, -9) * sc).rotated(rot), at + (Vector2(2, -11) * sc).rotated(rot), Color(1, 1, 1, 0.6 * (1.0 - dark)), 3.0, true)
	ci.draw_colored_polygon(_xf([Vector2(-16, 5), Vector2(19, 5), Vector2(19, 10), Vector2(-16, 10)], at, rot, sc), INK4)

func _mitten4(ci: Node2D, at: Vector2, rot: float, dark := 0.0) -> void:
	# a big fist: cuff, round mitten with a shaded underside and a gloss spot
	var cuff := _xf([Vector2(-17, -8), Vector2(-5, -8), Vector2(-5, 8), Vector2(-17, 8)], at, rot)
	_poly4(ci, cuff, SHELL.darkened(dark), 4.0)
	ci.draw_line(at + Vector2(-15, -5).rotated(rot), at + Vector2(-7, -5).rotated(rot), Color(1, 1, 1, 0.5), 2.0)
	ci.draw_circle(at, 14.0, INK4)
	ci.draw_circle(at, 11.5, MITT.lightened(dark * 0.2))
	ci.draw_circle(at + Vector2(2.5, 3.0), 8.0, MITT.darkened(0.25))
	ci.draw_circle(at + Vector2(-1, -1), 8.0, MITT.lightened(dark * 0.2))
	ci.draw_circle(at + Vector2(-4, -5), 3.2, Color(1, 1, 1, 0.28))
	ci.draw_circle(at + Vector2(0, -8).rotated(rot), 4.5, MITT.lightened(0.1))

## A dark ball joint with a gloss highlight.
func _ball(ci: Node2D, c: Vector2, r: float, dark := 0.0) -> void:
	ci.draw_circle(c, r + 2.5, INK4)
	ci.draw_circle(c, r, MITT.lightened(0.12 - dark * 0.1))
	ci.draw_circle(c + Vector2(r * 0.15, r * 0.2), r * 0.7, MITT.darkened(0.15))
	ci.draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.35))

## A cylinder limb segment: ink outline, base colour, a shadow band along
## the underside and a highlight along the top (reads as round, "3D").
func _seg(ci: Node2D, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var n := d.normalized().orthogonal()
	if n.y > 0.0:
		n = -n  # n points up: the lit side
	ci.draw_line(a, b, INK4, w + 5.0, true)
	ci.draw_circle(a, (w + 5.0) * 0.5, INK4)
	ci.draw_circle(b, (w + 5.0) * 0.5, INK4)
	ci.draw_line(a, b, col, w, true)
	ci.draw_line(a - n * w * 0.28, b - n * w * 0.28, col.darkened(0.22), w * 0.42, true)
	ci.draw_line(a + n * w * 0.30, b + n * w * 0.30, col.lightened(0.35), w * 0.18, true)

## Head in its own space (centre at origin, facing right).
# measured from codex-r1/kavi-e-keystone-floating.png (side view, 96 wide)
const HEAD_SIDE := [Vector2(-24, -35), Vector2(35, -31), Vector2(44, -25), Vector2(47, -16), Vector2(47, 29), Vector2(39, 35), Vector2(-27, 35), Vector2(-44, 6), Vector2(-48, -10)]
const SCREEN_SIDE := [Vector2(-2, -24), Vector2(37, -27), Vector2(44, -21), Vector2(45, 28), Vector2(39, 33), Vector2(11, 33)]
const PANEL_SIDE := [Vector2(-39, 3), Vector2(-14, 0), Vector2(-7, 20), Vector2(-31, 27)]

# ------------------------------------------------------------------ Kavi art (0.8.8)
## Kavi is now the approved concept art itself (codex-r1/kavi-e-keystone-floating.png),
## cut into floating parts by tools/art/kavi_parts.py and animated here: the
## run uses Codex's stride rig; idle/waves face the camera; a quick squash
## turns him between the two. The face is drawn live on his screen, the antenna
## is drawn live (so it can wobble and be swapped), and Garage colours go
## through a palette-swap shader that keeps the art's own shading.
const G := 0.40   # concept-sheet pixels -> rig units
const TEX_FRONT := preload("res://assets/kavi/front_upper.png")
const TEX_SIDE := preload("res://assets/kavi/side_upper.png")
const TEX_MITT := preload("res://assets/kavi/side_mitten_near.png")
const TEX_BOOT := preload("res://assets/kavi/side_boot.png")
const TEX_FMITT_L := preload("res://assets/kavi/front_mitten_l.png")
const TEX_FMITT_R := preload("res://assets/kavi/front_mitten_r.png")
const TEX_FBOOT_L := preload("res://assets/kavi/front_boot_l.png")
const TEX_FBOOT_R := preload("res://assets/kavi/front_boot_r.png")
# anchors in each sprite's own pixels (measured on the sheet)
const SIDE_PIVOT := Vector2(493, 466)    # pelvis
const SIDE_EYE := Vector2(661, 196)
const SIDE_MOUTH := Vector2(653, 258)
const SIDE_ANT := Vector2(568, 100)
const SIDE_HEAD := Vector2(553, 211)
const SIDE_NOZ := [Vector2(493, 518), Vector2(535, 520)]
const FRONT_PIVOT := Vector2(283, 647)   # floor centre between the boots
const FRONT_EYES := [Vector2(235, 201), Vector2(345, 201)]
const FRONT_MOUTH := Vector2(288, 250)
const FRONT_ANT := Vector2(288, 95)
const FRONT_HEAD := Vector2(288, 196)
# front-view floating parts: sheet pixels from the floor centre
const F_MITT_L := Vector2(-184, -198)
const F_MITT_R := Vector2(186, -201)
const F_BOOT_L := Vector2(-103, -52)
const F_BOOT_R := Vector2(103, -52)
const FRONT_POSES := ["idle", "wave", "front", "front_wave", "stretch"]
var _turn := 0.0
var _art: Node2D
var _swap: ShaderMaterial
var _pat := 0.0

const SWAP_SHADER := """
shader_type canvas_item;
uniform vec4 key_shell : source_color = vec4(0.996, 0.941, 0.847, 1.0);
uniform vec4 key_teal : source_color = vec4(0.227, 0.663, 0.635, 1.0);
uniform vec4 key_orange : source_color = vec4(1.0, 0.486, 0.165, 1.0);
uniform vec4 to_shell : source_color = vec4(0.996, 0.941, 0.847, 1.0);
uniform vec4 to_teal : source_color = vec4(0.227, 0.663, 0.635, 1.0);
uniform vec4 to_orange : source_color = vec4(1.0, 0.486, 0.165, 1.0);
uniform vec4 to_orange2 : source_color = vec4(1.0, 0.486, 0.165, 1.0);
uniform float pattern = 0.0;
uniform float time_s = 0.0;
uniform float encode = 0.0; // HDR 2D: texture comes in linear; re-encode to match drawn colours
varying vec4 vcol;
void vertex() { vcol = COLOR; }
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 hsv(float h) { return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0); }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = tex.rgb;
	float ws = 1.0 - smoothstep(0.10, 0.24, distance(c, key_shell.rgb));
	float wt = 1.0 - smoothstep(0.08, 0.20, distance(c, key_teal.rgb));
	float wo = 1.0 - smoothstep(0.12, 0.32, distance(c, key_orange.rgb));
	vec3 tor = to_orange.rgb;
	if (pattern > 0.5 && pattern < 1.5) {
		tor = mod(floor(UV.x * 26.0 + UV.y * 10.0), 2.0) < 1.0 ? to_orange.rgb : to_orange2.rgb;
	} else if (pattern > 1.5) {
		tor = mix(vec3(1.0), hsv(fract(UV.x * 2.0 - time_s * 0.15)), 0.65);
	}
	vec3 o = c;
	o = mix(o, to_shell.rgb * (lum(c) / max(lum(key_shell.rgb), 0.01)), ws);
	o = mix(o, to_teal.rgb * (lum(c) / max(lum(key_teal.rgb), 0.01)), wt);
	o = mix(o, tor * (lum(c) / max(lum(key_orange.rgb), 0.01)), wo);
	vec3 enc = mix(o * 12.92, 1.055 * pow(max(o, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), o));
	o = mix(o, enc, encode);
	COLOR = vec4(o, tex.a) * vcol;
}
"""

func _make_art_painter() -> void:
	_art = Painter.new()
	_art.fn = _paint_art
	_swap = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SWAP_SHADER
	_swap.shader = sh
	_art.material = _swap
	add_child(_art)
	move_child(_art, 0)

func _push_swap() -> void:
	if _swap == null:
		return
	_swap.set_shader_parameter("to_shell", SHELL)
	_swap.set_shader_parameter("to_teal", TEAL)
	_swap.set_shader_parameter("to_orange", scarf_col)
	_swap.set_shader_parameter("to_orange2", scarf_col2)
	_swap.set_shader_parameter("pattern", {"stripes": 1.0, "rainbow": 2.0}.get(scarf_pattern, 0.0))

## Where everything goes this frame (node-local coordinates), shared by the
## sprite, line and glow passes.
func _frame() -> Dictionary:
	var p = _pose_params()
	var front := _turn >= 0.5
	var sqx: float = ((_turn - 0.5) * 2.0) if front else (1.0 - _turn * 2.0)
	var sc: float = K * s
	var F := {"front": front, "sc": sc, "u": G * sc, "p": p}
	if front:
		var br := sin(t * 1.8)
		var base: Vector2 = p.off * s
		var sq := Vector2(sqx * maxf(p.sq.x, 0.01), p.sq.y)
		F.sq = sq
		var at := func(sheet_px: Vector2, lift := 0.0) -> Vector2:
			return base + Vector2(sheet_px.x * G * sc * sq.x, (sheet_px.y * (1.0 + 0.012 * br * lift)) * G * sc * sq.y)
		F.upper = at.call(Vector2.ZERO)
		F.upper_sq = Vector2(sq.x, sq.y * (1.0 + 0.012 * br))
		F.boot_l = at.call(F_BOOT_L)
		F.boot_r = at.call(F_BOOT_R)
		F.mitt_l = at.call(F_MITT_L + Vector2(0, sin(t * 1.8) * 6.0), 1.0)
		var mr := F_MITT_R + Vector2(0, sin(t * 1.8 + 1.0) * 6.0)
		if pose in ["wave", "front_wave"]:
			mr = Vector2(225 + sin(t * 9.0) * 20.0, -420)
		elif pose == "stretch":
			mr = Vector2(200, -420 - 60 * (0.5 + 0.5 * sin(t * 2.0)))
		F.mitt_r = at.call(mr, 1.0)
		F.eyes = [at.call(FRONT_EYES[0] - FRONT_PIVOT, 1.0), at.call(FRONT_EYES[1] - FRONT_PIVOT, 1.0)]
		F.mouth = at.call(FRONT_MOUTH - FRONT_PIVOT, 1.0)
		F.ant = at.call(FRONT_ANT - FRONT_PIVOT, 1.0)
		F.head = at.call(FRONT_HEAD - FRONT_PIVOT, 1.0)
		F.rot = 0.0
		F.noz = []
		return F
	var R := _rig(p)
	if pose in ["run", "walk"] and stumble_t <= 0.0:
		p.rot = 0.0
		p.off = Vector2.ZERO
		p.sq = Vector2.ONE
	var sq := Vector2(sqx * p.sq.x, p.sq.y)
	F.sq = sq
	var base: Vector2 = p.off * s + Vector2(0, -FLOOR * sc)
	var prot: float = p.rot
	var place := func(ref: Vector2) -> Vector2:
		return base + Vector2(ref.x * sc * sq.x, ref.y * sc * sq.y).rotated(prot)
	var pel: Vector2 = R.pelvis
	var trot: float = (R.tilt - deg_to_rad(14.0)) * 0.8 + 0.03 + p.head * 0.5
	var local := func(px: Vector2) -> Vector2:
		return place.call(pel + ((px - SIDE_PIVOT) * G).rotated(trot))
	F.rot = prot
	F.upper = place.call(pel)
	F.upper_rot = prot + trot
	F.eye = local.call(SIDE_EYE)
	F.mouth = local.call(SIDE_MOUTH)
	F.ant = local.call(SIDE_ANT)
	F.head = local.call(SIDE_HEAD)
	F.noz = [local.call(SIDE_NOZ[0]), local.call(SIDE_NOZ[1])]
	for side in ["near", "far"]:
		var S: Dictionary = R[side]
		var arm: Vector2 = S.mitten - (pel + S.shoulder)
		F[side + "_mitt"] = place.call(S.mitten)
		F[side + "_mitt_rot"] = prot + arm.angle()
		F[side + "_boot"] = place.call(S.boot + Vector2(0, -6))
		F[side + "_boot_rot"] = prot + float(S.boot_rot)
	return F

func _spr(ci: Node2D, tex: Texture2D, pivot: Vector2, at: Vector2, rot: float, sc: Vector2, mod := Color(1, 1, 1)) -> void:
	ci.draw_set_transform(at, rot, sc)
	ci.draw_texture(tex, -pivot, mod)

## Sprite pass (palette-swap shader).
func _paint_art(ci: Node2D) -> void:
	var F := _frame()
	var p: Dictionary = F.p
	if pose in ["run", "walk", "idle", "slide", "gust", "throw", "wave", "eat", "drink", "map", "photo", "read", "stretch", "front", "front_wave"]:
		ci.draw_colored_polygon(Art.ellipse(Vector2(0, 2), Vector2(30 * s, 5 * s), 16), Color(0, 0, 0, 0.35))
	var u: float = F.u
	var sq: Vector2 = F.sq
	var us := Vector2(u * sq.x, u * sq.y)
	if F.front:
		_spr(ci, TEX_FBOOT_L, Vector2(72, 52), F.boot_l, 0.0, us)
		_spr(ci, TEX_FBOOT_R, Vector2(72, 52), F.boot_r, 0.0, us)
		_spr(ci, TEX_FRONT, FRONT_PIVOT, F.upper, 0.0, Vector2(u * F.upper_sq.x, u * F.upper_sq.y))
		_spr(ci, TEX_FMITT_L, Vector2(48, 52), F.mitt_l, 0.0, us)
		_spr(ci, TEX_FMITT_R, Vector2(48, 52), F.mitt_r, 0.0, us)
	else:
		var far_c := Color(0.86, 0.86, 0.90)
		_spr(ci, TEX_BOOT, Vector2(107, 98), F.far_boot, F.far_boot_rot, us, far_c)
		_spr(ci, TEX_MITT, Vector2(53, 47), F.far_mitt, F.far_mitt_rot, us, far_c)
		_spr(ci, TEX_SIDE, SIDE_PIVOT, F.upper, F.upper_rot, us)
		_spr(ci, TEX_BOOT, Vector2(107, 98), F.near_boot, F.near_boot_rot, us)
		_spr(ci, TEX_MITT, Vector2(53, 47), F.near_mitt, F.near_mitt_rot, us)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Line pass (antenna, helmet extras, props) and glow pass (face, jets, trail).
func _paint(ci: Node2D, add: bool) -> void:
	var F := _frame()
	var p: Dictionary = F.p
	var sc: float = F.sc
	var sq: Vector2 = F.sq
	var tc: Color = TIER_COL[clampi(tier - 1, 0, 3)]
	var rs := Vector2(sc * absf(sq.x), sc * sq.y)
	if add and _trail.size() > 2:
		for k in range(1, _trail.size()):
			var a = float(k) / _trail.size()
			var w = 1.5 + a * 2.5 * (tier - 1)
			ci.draw_line(ci.to_local(_trail[k - 1]), ci.to_local(_trail[k]), Art.hdr(Color(tc, a * 0.35), 1.3), w, Art.AA)
	var hrot: float = 0.0 if F.front else F.upper_rot
	if not add:
		# antenna and helmet extras on the head
		ci.draw_set_transform(F.ant, hrot, rs * 1.15)
		_antenna4(ci, Vector2.ZERO, 0.0)
		ci.draw_set_transform(F.head, hrot, rs * (1.3 if F.front else 1.2))
		_helmet_extras4(ci, Vector2.ZERO, 0.0, F.front)
		if not F.front:
			ci.draw_set_transform(F.near_mitt, 0.0, Vector2(s, s))
			_props(ci, Vector2.ZERO, false)
	else:
		# live face on the screen
		if F.front:
			for e in F.eyes:
				ci.draw_set_transform(e + Vector2(look.x * 2.0, look.y * 2.0) * sc, 0.0, rs)
				_eye(ci)
			ci.draw_set_transform(F.mouth, 0.0, rs)
			_mouth(ci)
		else:
			ci.draw_set_transform(F.eye + Vector2(look.x * 2.0, look.y * 3.0) * sc, hrot, rs)
			_eye(ci)
			ci.draw_set_transform(F.mouth, hrot, rs)
			_mouth(ci)
		if helmet == "explorer":
			ci.draw_set_transform(F.head, hrot, rs * 1.2)
			ci.draw_circle(Vector2(30, -38) if not F.front else Vector2(0, -40), 5.0, Art.hdr(Color(1.0, 0.92, 0.7), 2.2))
		# satchel thrusters
		var th: float = p.thrust
		for q in F.noz:
			ci.draw_set_transform(q, F.rot, rs)
			ci.draw_circle(Vector2.ZERO, 3.5, Art.hdr(tc, 0.5 + th * 1.5))
			if th > 0.01:
				var fl := (40.0 + sin(t * 40.0 + q.x) * 8.0) * th
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(0, fl)]), Art.hdr(Color(tc, 0.9), 1.6))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, fl * 0.55)]), Art.hdr(Color(1, 1, 1), 2.5))
		if not F.front:
			if tier >= 2 and F.noz.size() > 0:
				ci.draw_set_transform(F.noz[0], 0.0, rs)
				Art.glow(ci, Vector2(10, 6), (14.0 + tier * 4.0) / K, Color(tc, 0.35), 3)
			if p.jets:
				for q in [F.near_mitt, F.far_mitt, F.near_boot, F.far_boot]:
					ci.draw_set_transform(q + Vector2(0, 10) * sc, 0.0, rs)
					var fl2: float = 18.0 + sin(t * 37.0 + q.x) * 6.0
					ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, fl2)]), Art.hdr(Color(tc, 0.9), 1.5))
			if pose == "gust":
				ci.draw_set_transform(F.near_mitt, 0.0, rs)
				Art.glow(ci, Vector2(10, 0), 50.0, Color(0.6, 1.0, 0.8, 0.6), 4)
			ci.draw_set_transform(F.near_mitt, 0.0, Vector2(s, s))
			_props(ci, Vector2.ZERO, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## One glowing eye for the current expression (rig units, centred).
func _eye(ci: Node2D) -> void:
	var col := Art.hdr(GLOW, 1.8)
	var e: String = expr
	if e == "normal" and blink_t < 0.0:
		e = "blink"
	match e:
		"blink":
			ci.draw_line(Vector2(-6, 2), Vector2(6, 2), col, 4.0)
		"happy", "calm":
			ci.draw_polyline(PackedVector2Array([Vector2(-8, 5), Vector2(0, -6), Vector2(8, 5)]), col, 4.5, Art.AA)
		"wow", "scared":
			ci.draw_arc(Vector2.ZERO, 8.0, 0, TAU, 16, col, 4.0, Art.AA)
		"heart":
			_heart(ci, Vector2.ZERO, 10.0, Art.hdr(Color(1.0, 0.45, 0.7), 2.0))
		"dizzy":
			ci.draw_line(Vector2(-6, -6), Vector2(6, 6), col, 4.0)
			ci.draw_line(Vector2(-6, 6), Vector2(6, -6), col, 4.0)
		"focus":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, -6), Vector2(6, -11), Vector2(6, 12), Vector2(-5, 12)]), col)
		_:
			ci.draw_colored_polygon(Art.rrect(Rect2(-5, -12, 10, 24), 5.0), col)

func _mouth(ci: Node2D) -> void:
	var col := Art.hdr(GLOW, 1.8)
	match expr:
		"wow", "scared":
			ci.draw_arc(Vector2.ZERO, 3.5, 0, TAU, 10, col, 3.0, Art.AA)
		"focus", "dizzy":
			ci.draw_line(Vector2(-5, 0), Vector2(5, 0), col, 3.0)
		_:
			var bowl := PackedVector2Array([Vector2(-7, -2)])
			for k in 7:
				var a := PI * k / 6.0
				bowl.append(Vector2(-cos(a) * 7.0, -2.0 + sin(a) * 6.0))
			ci.draw_colored_polygon(bowl, col)

func _antenna4(ci: Node2D, top: Vector2, rot: float) -> void:
	var a1 := top + Vector2(0, -16).rotated(rot) + Vector2(sin(t * 5.0) * 1.5, 0)
	ci.draw_line(top, a1, INK4, 6.0, true)
	var kd := a1 + Vector2(0, -12)
	match tip:
		"star":
			var st := PackedVector2Array()
			for k in 10:
				var a = -PI * 0.5 + k * PI / 5.0 + sin(t * 2.0) * 0.15
				st.append(kd + Vector2(cos(a), sin(a)) * (15.0 if k % 2 == 0 else 6.5))
			_poly4(ci, st, Color(1.0, 0.82, 0.30), 3.5)
		"heart":
			var hbt := 1.0 + 0.12 * maxf(0.0, sin(t * 7.0))
			_heart(ci, kd, 13.0 * hbt, INK4)
			_heart(ci, kd, 10.5 * hbt, Color(1.0, 0.42, 0.62))
		"leaf":
			var la := -0.5 + sin(t * 3.0) * 0.2
			_poly4(ci, Art.ellipse(kd + Vector2(3, -2), Vector2(16, 8), 14, la), Color(0.40, 0.85, 0.45), 3.5)
		_:
			# the teal diamond
			_poly4(ci, PackedVector2Array([kd + Vector2(0, -13), kd + Vector2(12, 0), kd + Vector2(0, 13), kd + Vector2(-12, 0)]), TEAL, 4.0)
			ci.draw_line(kd + Vector2(-4, -5), kd + Vector2(0, -9), Color(1, 1, 1, 0.55), 2.5)

func _helmet_extras4(ci: Node2D, hc: Vector2, rot: float, front: bool) -> void:
	match helmet:
		"cat":
			for e in [[Vector2(-30, -34), -0.25], [Vector2(18, -36), 0.25]] if not front else [[Vector2(-40, -36), -0.3], [Vector2(40, -36), 0.3]]:
				var b: Vector2 = hc + (e[0] as Vector2).rotated(rot)
				_poly4(ci, _xf([Vector2(-14, 6), Vector2(0, -22), Vector2(14, 6)], b, rot + e[1]), SHELL, 4.0)
				ci.draw_colored_polygon(_xf([Vector2(-7, 3), Vector2(0, -12), Vector2(7, 3)], b, rot + e[1]), TEAL)
		"explorer":
			var bx := Vector2(-44, -24) if not front else Vector2(-54, -26)
			ci.draw_colored_polygon(_xf([bx, bx + Vector2(88 if not front else 108, -2), bx + Vector2(88 if not front else 108, 8), bx + Vector2(0, 10)], hc, rot), TEAL.darkened(0.15))
			_poly4(ci, Art.ellipse(hc + (Vector2(30, -38) if not front else Vector2(0, -40)).rotated(rot), Vector2(10, 8), 12), SHADE.darkened(0.2), 3.0)

## Scarf tails behind the body: smooth tapered cloth strips (pattern aware).
func _draw_scarf(ci: Node2D, p: Dictionary) -> void:
	# scarf tails (behind body): smooth tapered cloth strips
	if _scarf_pts.size() == SCARF_N:
		var sc: Color = scarf_col
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var raw = PackedVector2Array()
		for q in _scarf_pts:
			raw.append(ci.to_local(q))
		var main_tail = _smooth(raw)
		# second, shorter tail hangs a little lower and lags the first
		var raw2 = PackedVector2Array()
		for k in range(0, SCARF_N - 3):
			var f = float(k) / (SCARF_N - 4)
			raw2.append(raw[k] + Vector2(1.5 * f, (3.0 + 9.0 * f) * s + sin(t * 13.0 - k * 0.9) * 2.5 * f * s))
		var tail2 = _smooth(raw2)
		_strip(ci, tail2, 6.2 * s, 4.0 * s, INK)
		var pc2 := _scarf_colors(tail2.size())
		for k in pc2.size():
			pc2[k] = pc2[k].darkened(0.22)  # (empty for solid scarves)
		_strip(ci, tail2, 4.6 * s, 2.6 * s, sc.darkened(0.22), pc2)
		_strip(ci, main_tail, 7.6 * s, 4.8 * s, INK)
		_strip(ci, main_tail, 6.0 * s, 3.4 * s, sc, _scarf_colors(main_tail.size()))
		if Art.Q >= 1:
			# soft sheen along the upper edge of the cloth
			var sheen = PackedVector2Array()
			for k in main_tail.size() - 2:
				var d = main_tail[k + 1] - main_tail[k]
				var nrm = d.orthogonal().normalized() if d.length() > 0.01 else Vector2(0, -1)
				if nrm.y > 0.0:
					nrm = -nrm
				sheen.append(main_tail[k] + nrm * 3.4 * s * (1.0 - 0.5 * float(k) / main_tail.size()))
			ci.draw_polyline(sheen, Color(sc.lightened(0.45), 0.75), 1.6 * s, Art.AA)
		ci.draw_set_transform(p.off * s, p.rot, p.sq * s)

## Catmull-Rom smoothing: 2 extra points per segment.
static func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var out = PackedVector2Array()
	var n = pts.size()
	for i in n - 1:
		var p0 = pts[maxi(i - 1, 0)]
		var p1 = pts[i]
		var p2 = pts[i + 1]
		var p3 = pts[mini(i + 2, n - 1)]
		for j in 3:
			var u = j / 3.0
			var u2 = u * u
			var u3 = u2 * u
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u3))
	out.append(pts[n - 1])
	return out

## A tapered ribbon as one triangle strip (one draw call, never fails to
## triangulate even when the cloth folds over itself).
static func _strip(ci: Node2D, pts: PackedVector2Array, w0: float, w1: float, col: Color, pcols := PackedColorArray()) -> void:
	var n = pts.size()
	if n < 2:
		return
	var verts = PackedVector2Array()
	var cols = PackedColorArray()
	var idx = PackedInt32Array()
	var nrm = Vector2(0, 1)
	for i in n:
		var d = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		if d.length() > 0.001:
			nrm = d.orthogonal().normalized()
		var w = lerpf(w0, w1, float(i) / (n - 1))
		verts.append(pts[i] + nrm * w)
		verts.append(pts[i] - nrm * w)
		var c: Color = pcols[i] if pcols.size() == n else col
		cols.append(c)
		cols.append(c)
	for i in n - 1:
		var a = i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, verts, cols)

func _props(ci: Node2D, hand: Vector2, add: bool) -> void:
	match pose:
		"eat":
			if not add:
				_poly(ci, Art.ellipse(hand + Vector2(4, -2), Vector2(9, 7), 14), Color(0.85, 0.6, 0.3))
				ci.draw_circle(hand + Vector2(4, -2), 3, Color(0.5, 0.3, 0.15))
		"drink":
			if not add:
				_poly(ci, Art.rrect(Rect2(hand.x - 1, hand.y - 16, 9, 18), 3), Color(0.7, 0.9, 1.0, 0.9))
		"map", "read":
			if add:
				var r = Rect2(hand.x + 2, hand.y - 30, 44, 30)
				ci.draw_rect(r, Color(GLOW, 0.18))
				ci.draw_rect(r, Art.hdr(Color(GLOW, 0.8), 1.3), false, 1.5)
				if pose == "map":
					ci.draw_polyline(PackedVector2Array([r.position + Vector2(5, 24), r.position + Vector2(16, 12), r.position + Vector2(28, 18), r.position + Vector2(40, 6)]), Art.hdr(Color(1, 0.7, 0.4), 1.6), 2.0)
				else:
					_heart(ci, r.get_center(), 6.0, Art.hdr(Color(1.0, 0.5, 0.8), 1.8))
		"photo":
			if not add:
				_poly(ci, Art.rrect(Rect2(hand.x - 2, hand.y - 12, 18, 12), 2), Color(0.2, 0.22, 0.3))
			elif fmod(act_t, 2.0) < 0.12:
				Art.glow(ci, hand + Vector2(12, -8), 90.0, Color(1, 1, 1, 0.9), 5)

func _eyes(ci: Node2D, vc: Vector2) -> void:
	var col = Art.hdr(GLOW, 1.8)
	var l = vc + Vector2(-6, -1)
	var r = vc + Vector2(7, -1)
	var e = expr
	if e == "normal" and blink_t < 0.0:
		e = "blink"
	match e:
		"normal", "focus":
			for c in [l, r]:
				ci.draw_colored_polygon(Art.rrect(Rect2(c.x - 3, c.y - 5.5, 6, 11), 3), col)
			if e == "focus":
				ci.draw_line(l + Vector2(-5, -8), l + Vector2(4, -5), VISOR, 3.0)
				ci.draw_line(r + Vector2(-4, -5), r + Vector2(5, -8), VISOR, 3.0)
		"blink":
			for c in [l, r]:
				ci.draw_line(c + Vector2(-3, 1), c + Vector2(3, 1), col, 2.0)
		"happy":
			for c in [l, r]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(-4, 2), c + Vector2(0, -3), c + Vector2(4, 2)]), col, 2.5, Art.AA)
		"wow":
			for c in [l, r]:
				ci.draw_arc(c, 4.5, 0, TAU, 16, col, 2.5, Art.AA)
		"heart":
			for c in [l, r]:
				_heart(ci, c, 4.5, Art.hdr(Color(1.0, 0.45, 0.7), 2.4))
			ci.draw_circle(vc + Vector2(-12, 6), 3.0, Color(1.0, 0.45, 0.65, 0.7))
			ci.draw_circle(vc + Vector2(12, 6), 3.0, Color(1.0, 0.45, 0.65, 0.7))
		"dizzy":
			for c in [l, r]:
				ci.draw_line(c + Vector2(-3, -3), c + Vector2(3, 3), col, 2.0)
				ci.draw_line(c + Vector2(-3, 3), c + Vector2(3, -3), col, 2.0)
		"scared":
			for c in [l, r]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(-4, -3), c + Vector2(2, 0), c + Vector2(-4, 3)]) if c == l else PackedVector2Array([c + Vector2(4, -3), c + Vector2(-2, 0), c + Vector2(4, 3)]), col, 2.5, Art.AA)
		"calm":
			for c in [l, r]:
				ci.draw_arc(c + Vector2(0, -1), 3.5, 0.2, PI - 0.2, 8, col, 2.0, Art.AA)
	# little screen mouth: a smile when happy, an "o" when amazed
	match e:
		"happy", "heart", "calm":
			ci.draw_arc(vc + Vector2(0.5, 6.5), 3.5, 0.35, PI - 0.35, 8, Color(col, 0.85), 1.8, Art.AA)
		"wow", "scared":
			ci.draw_arc(vc + Vector2(0.5, 8.0), 1.8, 0.0, TAU, 10, Color(col, 0.85), 1.6, Art.AA)

## Eyes follow what Kavi is doing: forward when running, up on a jump, down
## when falling, and they wander around (sky, camera, ahead) when he is idle.
func _update_look(dt: float) -> void:
	if pose in ["idle", "wave", "sit", "read", "map", "stretch"]:
		_look_next -= dt
		if _look_next <= 0.0:
			_look_next = randf_range(1.2, 3.0)
			look_target = [Vector2(1, 0), Vector2(0.6, -0.9), Vector2(-0.4, -0.6), Vector2(0, 0.2), Vector2(1, -0.4)].pick_random()
	elif pose in ["run", "walk", "slide", "gust", "throw"]:
		look_target = Vector2(1, clampf(vy / 900.0, -0.8, 0.8))
	elif pose in ["hover", "dive"]:
		look_target = Vector2(0.8, 0.8 if pose == "dive" else -0.3)
	look = look.lerp(look_target, 1.0 - exp(-dt * 10.0))

func _scarf_colors(n: int, dark := 0.0) -> PackedColorArray:
	var cols := PackedColorArray()
	if scarf_pattern == "solid":
		return cols  # empty: _strip uses the single colour (cheapest)
	for i in n:
		match scarf_pattern:
			"stripes":
				cols.append(scarf_col if (i / 3) % 2 == 0 else scarf_col2)
			"rainbow":
				cols.append(Color.from_hsv(fposmod(float(i) / n - t * 0.15, 1.0), 0.62, 1.0))
			_:
				cols.append(scarf_col)
	return cols

static func _heart(ci: Node2D, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.55, col)
	ci.draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.55, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, 0), c + Vector2(0, r)]), col)
