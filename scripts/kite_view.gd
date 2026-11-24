extends Node2D
## Kite, drawn procedurally from the v2 character spec (white/teal shell,
## white helmet, dark screen face with cyan eyes, orange scarf, kite antenna,
## maroon thruster pack). One geometry pass is painted twice: once normally
## and once additively for the emissive parts (eyes, lights, thrusters).

const Art = preload("res://scripts/art.gd")
const Painter = preload("res://scripts/painter.gd")

# Wearable colours (Garage). Defaults are the classic courier look.
var SHELL := Color(0.965, 0.973, 0.988)
var SHADE := Color(0.62, 0.74, 0.88)
var TEAL := Color(0.15, 0.79, 0.80)
const JOINT := Color(0.32, 0.58, 0.74)
const BOOT := Color(0.14, 0.34, 0.90)
const PACK := Color(0.55, 0.15, 0.20)
var GLOW := Color(0.30, 1.0, 1.0)
var scarf_col := Color(1.0, 0.35, 0.14)
var scarf_col2 := Color(1.0, 0.35, 0.14)
var scarf_pattern := "solid"
var tip := "kite"
var helmet := "round"
## Face: where the eyes look (-1..1 each axis), eased towards look_target.
var look := Vector2(1, 0)
## Air state from the sim (main sets these), for wobbly hovers and rough landings.
var grounded := true
var limbs := "jointed"  # unused since 0.8.9 (kept so main.gd can still set it)
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
	_base.tag = "kavi"
	_base.fn = _paint.bind(false)
	add_child(_base)
	_add = Painter.new()
	_add.tag = "kavi_add"
	_add.fn = _paint.bind(true)
	_add.material = Art.grade_material(true)
	add_child(_add)

func tick(dt: float) -> void:
	t += dt
	if pose != _last_pose:
		act_t = 0.0
		_last_pose = pose
	act_t += dt
	match pose:
		"run": phase += dt * speed * CONTACT * TAU / (2.0 * STRIDE * _run_amp() * s)
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

func reset_scarf() -> void:
	_scarf_pts.clear()
	_trail.clear()

func _neck_world() -> Vector2:
	var p = _pose_params()
	return global_position + (Vector2(-4, -63) * s).rotated(p.rot) + p.off * s

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
	return 0.8 + 0.35 * _speed_k()

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
## 0.8.19: Kavi's shapes have no black outline at any quality (owner: the
## outline-free look of Low is cuter). `_ink` is kept for call compatibility.
func _poly(ci: Node2D, pts: PackedVector2Array, fill: Color, _ink := true) -> void:
	ci.draw_colored_polygon(pts, fill)

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

## Kavi v3 (owner request 2026-11-22: memorable, cute but strong, better limbs).
## Silhouette: a wide rounded TV-head whose whole front is a screen face, a
## kite antenna, a broad chest with a glowing envelope badge, a courier's
## messenger bag, a long scarf, thick tapered limbs, mitten hands, chunky boots.
## Body units: feet at y=0, hip y=-31, shoulders y=-58, head centre y=-86.
const HIP := Vector2(0, -31)
const SHOULDER := Vector2(2, -58)
const HEAD_C := Vector2(5, -86)
const BAG := Color(0.66, 0.38, 0.24)
# smoothed outlines computed once (not every frame)
static var _TORSO := _smooth_closed(PackedVector2Array([Vector2(-14, -30), Vector2(-19, -50), Vector2(-18, -61), Vector2(-8, -67),
	Vector2(12, -67), Vector2(22, -61), Vector2(23, -50), Vector2(15, -30)]))
static var _TORSO_SHADE := _smooth_closed(PackedVector2Array([Vector2(-12, -33), Vector2(-15.5, -50), Vector2(-13.5, -60), Vector2(-6, -64), Vector2(-2, -63), Vector2(-4, -33)]))
static var _BOOT := _smooth_closed(PackedVector2Array([Vector2(-10, -12), Vector2(4, -12), Vector2(9, -7), Vector2(15, -4), Vector2(15, 1), Vector2(-11, 1)]))
const STRAP := Color(0.36, 0.20, 0.14)

func _paint(ci: Node2D, add: bool) -> void:
	var p = _pose_params()
	var tc: Color = TIER_COL[clampi(tier - 1, 0, 3)]
	# trail ribbon (world-space history)
	if add and _trail.size() > 2:
		for k in range(1, _trail.size()):
			var a = float(k) / _trail.size()
			var w = 1.5 + a * 2.5 * (tier - 1)
			ci.draw_line(ci.to_local(_trail[k - 1]), ci.to_local(_trail[k]), Art.hdr(Color(tc, a * 0.35), 1.3), w, Art.AA)
	# ground contact shadow
	if not add and pose in ["run", "walk", "idle", "slide", "gust", "throw", "wave", "eat", "drink", "map", "photo", "read", "stretch"]:
		ci.draw_colored_polygon(Art.ellipse(Vector2(0, 2), Vector2(28 * s, 5 * s), 16), Color(0, 0, 0, 0.35))
	if _turn > 0.0:
		if _turn >= 0.5:
			_paint_front(ci, add, (_turn - 0.5) * 2.0)
			return
		# first half of the turn: the side view squashes towards the camera
		p.sq.x *= 1.0 - _turn * 2.0
	ci.draw_set_transform(p.off * s, p.rot, p.sq * s)
	var hf: Vector2 = SHOULDER + p.hf
	var hb: Vector2 = SHOULDER + p.hb
	var ff: Vector2 = Vector2(p.ff.x, p.ff.y)
	var fb: Vector2 = Vector2(p.fb.x, p.fb.y)

	if not add:
		# --- back arm + back leg (shaded, behind the body)
		var sb := SHOULDER + Vector2(-5, 2)
		var eb = _ik(sb, hb, 13, 13, -1.0)
		_limb2(ci, sb, eb, 12.0, 10.5, SHADE)
		_limb2(ci, eb, hb, 10.5, 9.5, SHADE)
		_hand(ci, hb, SHADE.darkened(0.1), hb - eb)
		var hpb := HIP + Vector2(-4, 0)
		var kb = _ik(hpb, fb + Vector2(0, -7), 15, 15, 1.0)
		_limb2(ci, hpb, kb, 15.0, 12.5, SHADE)
		_limb2(ci, kb, fb + Vector2(0, -7), 12.5, 11.0, SHADE)
		_boot(ci, fb, BOOT.darkened(0.3))
		# --- scarf tails (behind body)
		_draw_scarf(ci, p)
		# --- messenger bag on the back, nozzles underneath (hover thrust)
		_poly(ci, Art.rrect(Rect2(-31, -63, 18, 27), 6), BAG)
		ci.draw_line(Vector2(-30, -55), Vector2(-14, -55), BAG.darkened(0.35), 2.0)
		ci.draw_circle(Vector2(-22, -51), 2.2, Color(1.0, 0.82, 0.45))
		_poly(ci, Art.ellipse(Vector2(-25, -35), Vector2(4.5, 3.5), 10), JOINT)
		_poly(ci, Art.ellipse(Vector2(-17, -35), Vector2(4.5, 3.5), 10), JOINT)
		# --- torso: broad chest tapering to the hips (strong but round)
		_poly(ci, _TORSO, SHELL)
		if Art.Q >= 1:
			# soft shading on the back half and a highlight on the chest
			ci.draw_colored_polygon(_TORSO_SHADE, Color(SHADE, 0.55))
			ci.draw_arc(Vector2(8, -53), 9.0, PI * 1.2, PI * 1.62, 8, Color(1, 1, 1, 0.75), 2.2, Art.AA)
		# belt in the accent colour
		ci.draw_colored_polygon(Art.rrect(Rect2(-14, -37, 29, 6), 3), TEAL)
		# envelope badge on the chest: drawn here (not in the glow pass) so the
		# front arm covers it when it swings across the chest
		_poly(ci, Art.rrect(Rect2(3, -54, 13, 9), 2), VISOR)
		var er := Rect2(4.5, -52.5, 10, 6)
		ci.draw_rect(er, Art.hdr(GLOW, 1.4), false, 1.2)
		ci.draw_polyline(PackedVector2Array([er.position, er.position + Vector2(5, 3.5), er.position + Vector2(10, 0)]), Art.hdr(GLOW, 1.4), 1.2)
		# strap across the chest to the bag
		ci.draw_line(Vector2(-12, -63), Vector2(15, -38), INK, 6.0, Art.AA)
		ci.draw_line(Vector2(-12, -63), Vector2(15, -38), STRAP, 3.6, Art.AA)
		# --- front leg
		var hpf := HIP + Vector2(4, 0)
		var kf = _ik(hpf, ff + Vector2(0, -7), 15, 15, 1.0)
		_limb2(ci, hpf, kf, 15.0, 12.5, SHELL)
		_limb2(ci, kf, ff + Vector2(0, -7), 12.5, 11.0, SHELL)
		ci.draw_circle(kf, 3.6, TEAL)
		_boot(ci, ff, BOOT)
	else:
		# emissive: thruster cores and flames, wheels
		var th: float = p.thrust
		for tx in [-25.0, -17.0]:
			ci.draw_circle(Vector2(tx, -34), 2.4, Art.hdr(tc, 0.5 + th * 1.5))
			if th > 0.01:
				var fl = (24.0 + sin(t * 40.0 + tx) * 5.0) * th
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 4, -32), Vector2(tx + 4, -32), Vector2(tx, -32 + fl)]), Art.hdr(Color(tc, 0.9), 1.6))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 2, -32), Vector2(tx + 2, -32), Vector2(tx, -32 + fl * 0.55)]), Art.hdr(Color(1, 1, 1), 2.5))
				Art.glow(ci, Vector2(tx, -26), 16.0 * th, Color(tc, 0.5), 3)
		if tier >= 2:
			Art.glow(ci, Vector2(-21, -38), 14.0 + tier * 4.0, Color(tc, 0.35), 3)
		if p.jets:
			# little jets under both hands and both boots (flicker)
			for j in [[hf, 0.7], [hb, 0.6], [ff, 1.0], [fb, 0.9]]:
				var q: Vector2 = j[0] + Vector2(0, 4)
				var fl: float = (10.0 + sin(t * 37.0 + q.x) * 4.0) * j[1]
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-3, 0), q + Vector2(3, 0), q + Vector2(0, fl)]), Art.hdr(Color(tc, 0.9), 1.5))
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-1.4, 0), q + Vector2(1.4, 0), q + Vector2(0, fl * 0.5)]), Art.hdr(Color(1, 1, 1), 2.2))
		if p.wheels:
			for w in [ff, fb]:
				ci.draw_circle(w + Vector2(-6, -1), 3.5, Art.hdr(Color(1.0, 0.75, 0.35), 2.0))

	# --- head: steadied against the body lean so it doesn't wobble
	ci.draw_set_transform(p.off * s, p.rot + p.head, p.sq * s)
	var hc := HEAD_C
	var head_r := Rect2(hc.x - 26, hc.y - 21, 52, 42)
	var scr := Rect2(hc.x - 15, hc.y - 14, 36, 28)
	if not add:
		# neck
		ci.draw_colored_polygon(Art.rrect(Rect2(-4, -68, 12, 8), 3), JOINT.darkened(0.2))
		# ear dial on the back side
		_poly(ci, Art.ellipse(hc + Vector2(-25, 3), Vector2(6, 8), 14), SHELL)
		ci.draw_arc(hc + Vector2(-25, 3), 4.0, 0, TAU, 14, TEAL, 2.5, Art.AA)
		# head shell: a soft rounded rectangle (TV head); suits reshape it
		_helmet_back(ci, hc, head_r)
		_head_shell(ci, head_r)
		if Art.Q >= 1:
			ci.draw_colored_polygon(Art.rrect(Rect2(head_r.position.x + 2, head_r.end.y - 11, head_r.size.x - 4, 9), 6), Color(SHADE, 0.5))
			ci.draw_arc(hc + Vector2(-8, -6), 14.0, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.8), 2.5, Art.AA)
		# accent crest along the top
		ci.draw_line(Vector2(head_r.position.x + 10, head_r.position.y + 1.5), Vector2(head_r.end.x - 14, head_r.position.y + 1.5), TEAL, 4.0, Art.AA)
		_helmet_extras(ci, hc, head_r)
		# screen face: accent bezel, dark glass, a glassy reflection
		_poly(ci, Art.rrect(scr.grow(3), 11), TEAL)
		ci.draw_colored_polygon(Art.rrect(scr, 9), VISOR)
		ci.draw_colored_polygon(Art.rrect(Rect2(scr.position.x + 3, scr.position.y + 2, scr.size.x - 6, 6), 3), Color(1, 1, 1, 0.08))
		ci.draw_line(scr.position + Vector2(scr.size.x - 9, 4), scr.position + Vector2(scr.size.x - 4, 10), Color(1, 1, 1, 0.22), 2.0)
		_antenna(ci, Vector2(hc.x + 10, head_r.position.y - (4.0 if helmet == "teapot" else 0.0)))
		_helmet_front(ci, hc, head_r)
		# scarf wrap at the neck
		ci.draw_set_transform(p.off * s, p.rot, p.sq * s)
		_poly(ci, Art.rrect(Rect2(-12, -68, 28, 9), 4.5), scarf_col)
		ci.draw_circle(Vector2(14, -62), 4.2, scarf_col.darkened(0.15))
		# --- front arm on top
		var sf := SHOULDER + Vector2(4, 2)
		var ef = _ik(sf, hf, 13, 13, -1.0)
		_limb2(ci, sf, ef, 12.0, 10.5, SHELL)
		_limb2(ci, ef, hf, 10.5, 9.5, SHELL)
		# rounded shoulder pad: reads as strong
		_poly(ci, Art.ellipse(sf + Vector2(0, -1), Vector2(8.5, 7.5), 16), TEAL)
		ci.draw_arc(sf + Vector2(-1, -2), 5.0, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.5), 1.6, Art.AA)
		_hand(ci, hf, SHELL, hf - ef)
		_props(ci, hf, false)
	else:
		# faint screen glow, then the face
		ci.draw_colored_polygon(Art.rrect(scr, 9), Color(GLOW, 0.06))
		_eyes(ci, scr.get_center() + Vector2(1 + look.x * 3.0, -1 + look.y * 2.5))
		ci.draw_circle(hc + Vector2(-25, 3), 2.2, Art.hdr(GLOW, 1.6))
		if helmet == "explorer":
			ci.draw_circle(hc + Vector2(14, -22), 3.0, Art.hdr(Color(1.0, 0.92, 0.7), 2.2))
			Art.glow(ci, hc + Vector2(16, -22), 22.0, Color(1.0, 0.9, 0.6, 0.35), 3)
		ci.draw_set_transform(p.off * s, p.rot, p.sq * s)
		if pose == "gust":
			Art.glow(ci, hf + Vector2(6, 0), 26.0, Color(0.6, 1.0, 0.8, 0.6), 4)
		_props(ci, hf, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Tapered inked limb (wider at the root).
func _limb2(ci: Node2D, a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	ci.draw_colored_polygon(_taper(a, b, w0 * 0.5 + 2.0, w1 * 0.5 + 2.0), INK)
	ci.draw_colored_polygon(_taper(a, b, w0 * 0.5, w1 * 0.5), col)

static func _taper(a: Vector2, b: Vector2, r0: float, r1: float) -> PackedVector2Array:
	var d := b - a
	var ang := d.angle() if d.length() > 0.01 else 0.0
	var p := PackedVector2Array()
	for i in 7:
		var u := ang + PI * 0.5 + PI * float(i) / 6.0
		p.append(a + Vector2(cos(u), sin(u)) * r0)
	for i in 7:
		var u := ang - PI * 0.5 + PI * float(i) / 6.0
		p.append(b + Vector2(cos(u), sin(u)) * r1)
	return p

## Mitten hand with a thumb, oriented along the forearm.
func _hand(ci: Node2D, c: Vector2, col: Color, dir: Vector2) -> void:
	var a := dir.angle() if dir.length() > 0.01 else PI * 0.5
	_poly(ci, Art.ellipse(c + Vector2(3, 0).rotated(a), Vector2(7.5, 6.5), 14, a), col)
	_poly(ci, Art.ellipse(c + Vector2(0.5, -5.5).rotated(a), Vector2(3.2, 2.6), 8, a), col)

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

## Suits that change Kavi's silhouette (0.8.15). His face screen and scarf
## always stay, so he is still Kavi in any suit.
func _head_shell(ci: Node2D, hr: Rect2) -> void:
	match helmet:
		"astro":
			_poly(ci, Art.rrect(hr, 20, 8), SHELL)
		"teapot":
			_poly(ci, Art.rrect(Rect2(hr.position.x - 3, hr.position.y - 1, hr.size.x + 6, hr.size.y + 3), 22, 8), SHELL)
		"block":
			_poly(ci, Art.rrect(hr.grow(3), 4, 2), SHELL)
		"sprout":
			_poly(ci, Art.rrect(hr, 19, 7), SHELL)
		_:
			_poly(ci, Art.rrect(hr, 15, 6), SHELL)

## Parts that sit behind the head shell.
func _helmet_back(ci: Node2D, hc: Vector2, hr: Rect2) -> void:
	match helmet:
		"teapot":
			# handle on the left, spout on the right
			ci.draw_arc(Vector2(hr.position.x - 4, hc.y + 1), 11.0, PI * 0.5, PI * 1.5, 14, INK, 9.0, Art.AA)
			ci.draw_arc(Vector2(hr.position.x - 4, hc.y + 1), 11.0, PI * 0.5, PI * 1.5, 14, SHELL, 5.0, Art.AA)
			var sp := Vector2(hr.end.x + 1, hc.y + 9)
			_poly(ci, PackedVector2Array([sp + Vector2(-6, -6), sp + Vector2(-6, 7), sp + Vector2(9, -6), sp + Vector2(17, -16), sp + Vector2(19, -12), sp + Vector2(10, 2)]), SHELL)
			ci.draw_circle(sp + Vector2(18, -14), 2.2, TEAL)
		"bunny":
			var wob := sin(t * 3.0) * 0.12
			for e in [[Vector2(hc.x - 10, hr.position.y + 4), -0.18, 0.0], [Vector2(hc.x + 10, hr.position.y + 4), 0.25, 1.0]]:
				var b: Vector2 = e[0]
				var flop: float = e[2]
				var ang: float = e[1] + wob * (1.0 + flop) + flop * (0.75 + sin(t * 2.2) * 0.15)
				var c := b + Vector2(0, -17).rotated(ang)
				_poly(ci, Art.ellipse(c, Vector2(7.5, 18), 16, ang), SHELL)
				ci.draw_colored_polygon(Art.ellipse(c + Vector2(0, 2).rotated(ang), Vector2(3.6, 12), 12, ang), Color(1.0, 0.62, 0.72))

func _helmet_front(ci: Node2D, hc: Vector2, hr: Rect2) -> void:
	match helmet:
		"astro":
			# fishbowl glass dome with a collar ring
			ci.draw_colored_polygon(Art.rrect(Rect2(hc.x - 22, hr.end.y - 3, 44, 7), 3.5), TEAL)
			ci.draw_colored_polygon(Art.ellipse(hc + Vector2(0, -2), Vector2(34, 31), 28), Color(0.75, 0.92, 1.0, 0.12))
			ci.draw_arc(hc + Vector2(0, -2), 33.0, 0.0, TAU, 32, Color(0.9, 0.97, 1.0, 0.55), 2.2, Art.AA)
			ci.draw_arc(hc + Vector2(-4, -6), 26.0, PI * 1.08, PI * 1.42, 10, Color(1, 1, 1, 0.85), 3.0, Art.AA)
			ci.draw_arc(hc + Vector2(4, 2), 28.0, PI * 0.12, PI * 0.3, 6, Color(1, 1, 1, 0.45), 2.0, Art.AA)
		"teapot":
			# lid with a knob
			_poly(ci, Art.ellipse(Vector2(hc.x - 4, hr.position.y - 1), Vector2(15, 5), 16), SHELL)
			_poly(ci, Art.ellipse(Vector2(hc.x - 4, hr.position.y - 7), Vector2(4.5, 4), 12), TEAL)
		"block":
			for bx in [hr.position.x - 2.0, hr.end.x + 2.0]:
				ci.draw_circle(Vector2(bx, hc.y + 2), 4.2, INK)
				ci.draw_circle(Vector2(bx, hc.y + 2), 2.8, TEAL)
		"sprout":
			var sw := sin(t * 2.4) * 0.2
			var base := Vector2(hc.x - 6, hr.position.y + 1)
			var top := base + Vector2(0, -13).rotated(sw)
			ci.draw_line(base, top, INK, 4.0, Art.AA)
			ci.draw_line(base, top, Color(0.35, 0.7, 0.35), 2.2, Art.AA)
			for e in [[-1.0, 0.7], [1.0, -0.7]]:
				var a: float = e[1] + sw
				_poly(ci, Art.ellipse(top + Vector2(e[0] * 7, 1).rotated(sw), Vector2(8, 4), 12, a), Color(0.45, 0.85, 0.45))
			var fl := top + Vector2(0, -4).rotated(sw)
			for k in 5:
				ci.draw_circle(fl + Vector2.from_angle(k * TAU / 5.0 + t) * 3.6, 2.6, Color(1.0, 0.62, 0.75))
			ci.draw_circle(fl, 2.2, Color(1.0, 0.85, 0.35))

func _helmet_extras(ci: Node2D, hc: Vector2, hr: Rect2) -> void:
	match helmet:
		"cat":
			for e in [[Vector2(hr.position.x + 10, hr.position.y + 3), -0.3], [Vector2(hr.end.x - 12, hr.position.y + 3), 0.3]]:
				var b: Vector2 = e[0]
				_poly(ci, PackedVector2Array([b + Vector2(-9, 4).rotated(e[1]), b + Vector2(0, -14).rotated(e[1]), b + Vector2(9, 4).rotated(e[1])]), SHELL)
				ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-4.5, 2).rotated(e[1]), b + Vector2(0, -8).rotated(e[1]), b + Vector2(4.5, 2).rotated(e[1])]), TEAL)
		"explorer":
			ci.draw_colored_polygon(Art.rrect(Rect2(hr.position.x - 2, hr.position.y + 4, hr.size.x + 4, 7), 3), TEAL.darkened(0.15))
			_poly(ci, Art.ellipse(hc + Vector2(14, -22), Vector2(6, 5), 12), SHADE.darkened(0.2))

func _antenna(ci: Node2D, a0: Vector2) -> void:
	var a1 = a0 + Vector2(5, -14) + Vector2(sin(t * 5.0) * 1.2, 0)
	ci.draw_line(a0, a1, INK, 4.0, Art.AA)
	ci.draw_line(a0, a1, TEAL, 2.4, Art.AA)
	var kd = a1 + Vector2(0, -6)
	match tip:
		"star":
			var st := PackedVector2Array()
			for k in 10:
				var a = -PI * 0.5 + k * PI / 5.0 + sin(t * 2.0) * 0.15
				st.append(kd + Vector2(cos(a), sin(a)) * (8.0 if k % 2 == 0 else 3.6))
			_poly(ci, st, Color(1.0, 0.82, 0.30))
		"heart":
			var hbt := 1.0 + 0.12 * maxf(0.0, sin(t * 7.0))
			_heart(ci, kd + Vector2(0, -1), 7.0 * hbt, INK)
			_heart(ci, kd + Vector2(0, -1), 5.8 * hbt, Color(1.0, 0.42, 0.62))
		"leaf":
			var la := -0.5 + sin(t * 3.0) * 0.2
			_poly(ci, Art.ellipse(kd + Vector2(2, -2), Vector2(9, 4.5), 14, la), Color(0.40, 0.85, 0.45))
			ci.draw_line(kd + Vector2(-5, 3), kd + Vector2(8, -6), Color(0.2, 0.5, 0.25), 1.2)
		_:
			_poly(ci, PackedVector2Array([kd + Vector2(0, -7), kd + Vector2(5, 0), kd + Vector2(-5, 0)]), Color(1.0, 0.55, 0.35))
			_poly(ci, PackedVector2Array([kd + Vector2(-5, 0), kd + Vector2(5, 0), kd + Vector2(0, 9)]), Color(0.35, 0.55, 1.0))
			var tail = PackedVector2Array()
			for k in 5:
				tail.append(kd + Vector2(-k * 4.0, 9 + k * 2.0 + sin(t * 10.0 + k) * 2.0))
			ci.draw_polyline(tail, Color(1.0, 0.55, 0.35), 1.5, Art.AA)

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

func _boot(ci: Node2D, f: Vector2, col: Color) -> void:
	# chunky boot: tall cuff, rounded toe, thick light sole
	var bp := PackedVector2Array()
	for q in _BOOT:
		bp.append(f + q)
	_poly(ci, bp, col)
	if Art.Q >= 1:
		ci.draw_rect(Rect2(f.x - 10, f.y - 3.5, 25, 4), col.lightened(0.6))
		ci.draw_line(f + Vector2(-6, -9), f + Vector2(2, -9), Color(1, 1, 1, 0.45), 1.6)
	ci.draw_line(f + Vector2(-11, 0.5), f + Vector2(15, 0.5), INK, 2.2)

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

## Front view (owner: when Kavi meets Lia he turns to face us, both arms
## showing). The turn is a quick squash through the side view.
const FRONT_POSES := ["front", "front_wave"]
var _turn := 0.0

func _paint_front(ci: Node2D, add: bool, sx: float) -> void:
	var br := sin(t * 1.8)
	ci.draw_set_transform(Vector2(0, -5.0 * s + br * 0.5), 0.0, Vector2(sx * s, s))
	var hc := Vector2(0, -86)
	var hr := Rect2(-26, -107, 52, 42)
	var scr := Rect2(-18, -100, 36, 28)
	var waving: bool = pose == "front_wave"
	var hand_r: Vector2 = Vector2(38 + sin(t * 9.0) * 5.0, -92) if waving else Vector2(27, -32)
	var hand_l := Vector2(-27, -32)
	if not add:
		# legs + boots
		for lx in [-8.0, 8.0]:
			_limb2(ci, Vector2(lx, -31), Vector2(lx * 1.1, -8), 15.0, 12.0, SHELL if lx > 0 else SHELL.lerp(SHADE, 0.35))
			_poly(ci, Art.rrect(Rect2(lx * 1.1 - 10, -12, 20, 13), 6), BOOT)
			ci.draw_rect(Rect2(lx * 1.1 - 10, -3.5, 20, 4), BOOT.lightened(0.6))
		# scarf tails hanging down on one side, fluttering
		var tl := PackedVector2Array()
		for k in 8:
			tl.append(Vector2(-12 - k * 1.2 + sin(t * 3.0 + k * 0.8) * 2.0 * k / 7.0, -62 + k * 6.0))
		_strip(ci, tl, 6.6, 4.4, INK)
		_strip(ci, tl, 5.0, 3.0, scarf_col, _scarf_colors(tl.size()))
		# bag peeking out behind
		_poly(ci, Art.rrect(Rect2(-29, -62, 9, 24), 4), BAG)
		# torso
		var torso := PackedVector2Array([Vector2(-15, -30), Vector2(-21, -50), Vector2(-20, -61), Vector2(-10, -67),
			Vector2(10, -67), Vector2(20, -61), Vector2(21, -50), Vector2(15, -30)])
		_poly(ci, _smooth_closed(torso), SHELL)
		if Art.Q >= 1:
			ci.draw_colored_polygon(Art.rrect(Rect2(-14, -45, 28, 10), 5), Color(SHADE, 0.45))
			ci.draw_arc(Vector2(-6, -55), 9.0, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.75), 2.2, Art.AA)
		ci.draw_colored_polygon(Art.rrect(Rect2(-15, -37, 30, 6), 3), TEAL)
		_poly(ci, Art.rrect(Rect2(-6.5, -55, 13, 9), 2), VISOR)
		var er := Rect2(-5, -53.5, 10, 6)
		ci.draw_rect(er, Art.hdr(GLOW, 1.4), false, 1.2)
		ci.draw_polyline(PackedVector2Array([er.position, er.position + Vector2(5, 3.5), er.position + Vector2(10, 0)]), Art.hdr(GLOW, 1.4), 1.2)
		ci.draw_line(Vector2(-15, -62), Vector2(15, -36), INK, 6.0, Art.AA)
		ci.draw_line(Vector2(-15, -62), Vector2(15, -36), STRAP, 3.6, Art.AA)
		# arms (both visible)
		for side in [[-1.0, hand_l], [1.0, hand_r]]:
			var sh := Vector2(21.0 * side[0], -58)
			var el = _ik(sh, side[1], 13, 13, -side[0])
			_limb2(ci, sh, el, 12.0, 10.5, SHELL)
			_limb2(ci, el, side[1], 10.5, 9.5, SHELL)
			_hand(ci, side[1], SHELL, side[1] - el)
			_poly(ci, Art.ellipse(sh + Vector2(0, -1), Vector2(8.5, 7.5), 16), TEAL)
		# head
		ci.draw_colored_polygon(Art.rrect(Rect2(-6, -68, 12, 6), 3), JOINT.darkened(0.2))
		for ex in [-27.0, 27.0]:
			_poly(ci, Art.ellipse(Vector2(ex, -84), Vector2(5, 8), 14), SHELL)
			ci.draw_arc(Vector2(ex, -84), 3.4, 0, TAU, 12, TEAL, 2.2, Art.AA)
		_helmet_back(ci, hc, hr)
		_head_shell(ci, hr)
		if Art.Q >= 1:
			ci.draw_colored_polygon(Art.rrect(Rect2(hr.position.x + 2, hr.end.y - 11, hr.size.x - 4, 9), 6), Color(SHADE, 0.5))
			ci.draw_arc(hc + Vector2(-12, -6), 14.0, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.8), 2.5, Art.AA)
		ci.draw_line(Vector2(hr.position.x + 12, hr.position.y + 1.5), Vector2(hr.end.x - 12, hr.position.y + 1.5), TEAL, 4.0, Art.AA)
		_helmet_extras(ci, hc, hr)
		_poly(ci, Art.rrect(scr.grow(3), 11), TEAL)
		ci.draw_colored_polygon(Art.rrect(scr, 9), VISOR)
		ci.draw_colored_polygon(Art.rrect(Rect2(scr.position.x + 3, scr.position.y + 2, scr.size.x - 6, 6), 3), Color(1, 1, 1, 0.08))
		_antenna(ci, Vector2(0, hr.position.y - (4.0 if helmet == "teapot" else 0.0)))
		_helmet_front(ci, hc, hr)
		_poly(ci, Art.rrect(Rect2(-15, -68, 30, 9), 4.5), scarf_col)
	else:
		ci.draw_colored_polygon(Art.rrect(scr, 9), Color(GLOW, 0.06))
		_eyes(ci, scr.get_center() + Vector2(-0.5 + look.x * 1.5, -1 + look.y * 2.0))
		if helmet == "explorer":
			ci.draw_circle(hc + Vector2(14, -22), 3.0, Art.hdr(Color(1.0, 0.92, 0.7), 2.2))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
