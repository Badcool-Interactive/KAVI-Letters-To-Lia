extends Node2D
## Kite, drawn procedurally from the v2 character spec (white/teal shell,
## white helmet, dark screen face with cyan eyes, orange scarf, kite antenna,
## maroon thruster pack). One geometry pass is painted twice: once normally
## and once additively for the emissive parts (eyes, lights, thrusters).

const Art = preload("res://scripts/art.gd")
const Painter = preload("res://scripts/painter.gd")

const SHELL := Color(0.965, 0.973, 0.988)
const SHADE := Color(0.62, 0.74, 0.88)
const TEAL := Color(0.15, 0.79, 0.80)
const JOINT := Color(0.32, 0.58, 0.74)
const BOOT := Color(0.14, 0.34, 0.90)
const PACK := Color(0.55, 0.15, 0.20)
const GLOW := Color(0.30, 1.0, 1.0)
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

func tick(dt: float) -> void:
	t += dt
	if pose != _last_pose:
		act_t = 0.0
		_last_pose = pose
	act_t += dt
	match pose:
		"run": phase += dt * speed / 520.0 * 15.0
		"walk": phase += dt * 6.5
		"slide": phase += dt * 30.0
	blink_t -= dt
	if blink_t < -0.12:
		blink_t = randf_range(2.5, 4.5)
	_update_scarf(dt)
	_update_trail()
	_base.queue_redraw()
	_add.queue_redraw()

func reset_scarf() -> void:
	_scarf_pts.clear()
	_trail.clear()

func _neck_world() -> Vector2:
	var p = _pose_params()
	return global_position + (Vector2(-2, -60) * s).rotated(p.rot) + p.off * s

func _update_scarf(dt: float) -> void:
	var anchor = _neck_world()
	if _scarf_pts.size() != 7:
		_scarf_pts.clear()
		for k in 7:
			_scarf_pts.append(anchor + Vector2(-k * 9.0 * s, 0))
	_scarf_pts[0] = anchor
	var wind = -speed * 0.9 if pose != "idle" and pose != "wave" and pose != "sit" else -30.0
	for k in range(1, 7):
		var p: Vector2 = _scarf_pts[k]
		var flutter = sin(t * 14.0 - k * 0.9) * (3.0 + k * 1.2) * (1.0 if not reduced_motion else 0.4)
		p += Vector2(wind * dt * 0.5, (40.0 + flutter * 8.0) * dt)
		var prev: Vector2 = _scarf_pts[k - 1]
		var d = p - prev
		var L = 9.0 * s
		if d.length() > L:
			p = prev + d.normalized() * L
		_scarf_pts[k] = p

func _update_trail() -> void:
	if not trail_on or tier < 2 or pose in ["idle", "sit", "wave", "walk"]:
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
		"hf": Vector2(10, 18), "hb": Vector2(-8, 18), "thrust": 0.0, "wheels": false, "head": 0.0}
	var ph = phase
	match pose:
		"run", "walk":
			var amp = 1.0 if pose == "run" else 0.6
			p.ff = Vector2(sin(ph) * 20.0 * amp, -maxf(0.0, -cos(ph)) * 15.0 * amp)
			p.fb = Vector2(sin(ph + PI) * 20.0 * amp, -maxf(0.0, -cos(ph + PI)) * 15.0 * amp)
			p.hf = Vector2(-sin(ph) * 13.0 * amp + 4.0, 16.0)
			p.hb = Vector2(-sin(ph + PI) * 13.0 * amp - 2.0, 16.0)
			p.off = Vector2(0, -absf(cos(ph)) * 4.0 * amp)
			p.rot = 0.08 * amp
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
			var sw = sin(t * 9.0) * 2.0
			p.ff = Vector2(4 + sw, 2)
			p.fb = Vector2(-6 - sw, 4)
			p.hf = Vector2(18, -4)
			p.hb = Vector2(-18, -2)
			p.thrust = 1.0
			p.rot = 0.04
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
			p.off = Vector2(0, sin(t * 2.0) * 1.5)
			p.hf = Vector2(6, 18)
			p.hb = Vector2(-6, 18)
		"wave":
			p.hf = Vector2(14 + sin(t * 12.0) * 8.0, -30)
			p.hb = Vector2(-6, 18)
			p.head = 0.08
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

static func _ik(a: Vector2, b: Vector2, l1: float, l2: float, bend: float) -> Vector2:
	var d = b - a
	var L = clampf(d.length(), 0.01, l1 + l2 - 0.01)
	var cos_a = (l1 * l1 + L * L - l2 * l2) / (2.0 * l1 * L)
	var ang = acos(clampf(cos_a, -1.0, 1.0))
	return a + d.normalized().rotated(-ang * bend) * l1

# ------------------------------------------------------------------ paint
func _poly(ci: Node2D, pts: PackedVector2Array, fill: Color, ink := true) -> void:
	ci.draw_colored_polygon(pts, fill)
	if ink:
		var c = pts.duplicate()
		c.append(pts[0])
		ci.draw_polyline(c, INK, 2.2, true)

func _limb(ci: Node2D, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, INK, w + 4.0, true)
	ci.draw_circle(a, (w + 4.0) * 0.5, INK)
	ci.draw_circle(b, (w + 4.0) * 0.5, INK)
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)

func _paint(ci: Node2D, add: bool) -> void:
	var p = _pose_params()
	var tc: Color = TIER_COL[clampi(tier - 1, 0, 3)]
	# trail ribbon (world-space history)
	if add and _trail.size() > 2:
		for k in range(1, _trail.size()):
			var a = float(k) / _trail.size()
			var w = 1.5 + a * 2.5 * (tier - 1)
			ci.draw_line(ci.to_local(_trail[k - 1]), ci.to_local(_trail[k]), Art.hdr(Color(tc, a * 0.35), 1.3), w, true)
	# ground contact shadow
	if not add and pose in ["run", "walk", "idle", "slide", "gust", "throw", "wave", "eat", "drink", "map", "photo", "read", "stretch"]:
		ci.draw_colored_polygon(Art.ellipse(Vector2(0, 2), Vector2(30 * s, 5 * s), 16), Color(0, 0, 0, 0.35))
	ci.draw_set_transform(p.off * s, p.rot, p.sq * s)
	var hip = Vector2(0, -34)
	var sh = Vector2(2, -56)
	var hf: Vector2 = sh + p.hf
	var hb: Vector2 = sh + p.hb
	var ff: Vector2 = Vector2(p.ff.x, -2.0 + p.ff.y)
	var fb: Vector2 = Vector2(p.fb.x, -2.0 + p.fb.y)

	if not add:
		# back arm + leg (darker, behind)
		var eb = _ik(sh + Vector2(-2, 0), hb, 12, 12, -1.0)
		_limb(ci, sh + Vector2(-2, 0), eb, 7, SHADE)
		_limb(ci, eb, hb, 7, SHADE)
		ci.draw_circle(hb, 5, JOINT.darkened(0.2))
		var kb = _ik(hip + Vector2(-3, 0), fb + Vector2(0, -6), 16, 16, 1.0)
		_limb(ci, hip + Vector2(-3, 0), kb, 9, SHADE)
		_limb(ci, kb, fb + Vector2(0, -6), 8, SHADE)
		_boot(ci, fb, BOOT.darkened(0.25))
		# scarf tails (behind body)
		if _scarf_pts.size() == 7:
			var sc: Color = SCARVES[scarf % SCARVES.size()]
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var pts = PackedVector2Array()
			for q in _scarf_pts:
				pts.append(ci.to_local(q))
			ci.draw_polyline(pts, INK, 11.0 * s, true)
			ci.draw_polyline(pts, sc, 7.5 * s, true)
			var tail2 = PackedVector2Array()
			for k in range(1, pts.size()):
				tail2.append(pts[k] + Vector2(2, 7 + sin(t * 12.0 + k) * 2.0) * s)
			ci.draw_polyline(tail2, INK, 9.0 * s, true)
			ci.draw_polyline(tail2, sc.darkened(0.15), 5.5 * s, true)
			ci.draw_set_transform(p.off * s, p.rot, p.sq * s)
		# backpack + thrusters
		_poly(ci, Art.rrect(Rect2(-27, -66, 18, 30), 6), PACK)
		ci.draw_rect(Rect2(-24, -62, 10, 12), PACK.lightened(0.15))
		_poly(ci, Art.ellipse(Vector2(-22, -34), Vector2(5, 4), 10), TEAL)
		_poly(ci, Art.ellipse(Vector2(-13, -34), Vector2(5, 4), 10), TEAL)
		# torso
		_poly(ci, Art.rrect(Rect2(-14, -64, 30, 30), 11), SHADE)
		ci.draw_colored_polygon(Art.rrect(Rect2(-10, -63, 25, 25), 10), SHELL)
		ci.draw_rect(Rect2(-12, -40, 26, 5), TEAL)
		ci.draw_colored_polygon(Art.rrect(Rect2(3, -56, 9, 7), 3), VISOR)
		# front leg
		var kf = _ik(hip + Vector2(3, 0), ff + Vector2(0, -6), 16, 16, 1.0)
		_limb(ci, hip + Vector2(3, 0), kf, 9, SHELL)
		ci.draw_circle(kf, 5, JOINT)
		_limb(ci, kf, ff + Vector2(0, -6), 8, SHELL)
		ci.draw_circle(hip + Vector2(3, 0), 6, TEAL)
		_boot(ci, ff, BOOT)
	else:
		# emissive: chest light, thruster cores, flames, wheels
		ci.draw_colored_polygon(Art.rrect(Rect2(4, -55, 7, 5), 2), Art.hdr(GLOW, 2.2))
		ci.draw_rect(Rect2(-23, -61, 8, 2), Art.hdr(Color(GLOW, 0.6), 1.5))
		ci.draw_rect(Rect2(-23, -57, 8, 2), Art.hdr(Color(GLOW, 0.6), 1.5))
		var th: float = p.thrust
		var base_core = 0.5 + th * 1.5
		for tx in [-22.0, -13.0]:
			ci.draw_circle(Vector2(tx, -33), 3.0, Art.hdr(tc, base_core))
			if th > 0.01:
				var fl = (26.0 + sin(t * 40.0 + tx) * 6.0) * th
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 5, -31), Vector2(tx + 5, -31), Vector2(tx, -31 + fl)]), Art.hdr(Color(tc, 0.9), 1.6))
				ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - 2.5, -31), Vector2(tx + 2.5, -31), Vector2(tx, -31 + fl * 0.55)]), Art.hdr(Color(1, 1, 1), 2.5))
				Art.glow(ci, Vector2(tx, -24), 18.0 * th, Color(tc, 0.5), 3)
		if tier >= 2:
			Art.glow(ci, Vector2(-17, -36), 14.0 + tier * 4.0, Color(tc, 0.35), 3)
		if p.wheels:
			for w in [ff, fb]:
				ci.draw_circle(w + Vector2(-6, -1), 3.5, Art.hdr(Color(1.0, 0.75, 0.35), 2.0))
		# rim light on the back edge

	# head
	ci.draw_set_transform(p.off * s, p.rot + p.head, p.sq * s)
	var hc = Vector2(2, -82)
	if not add:
		# ear pod (back side)
		_poly(ci, Art.ellipse(hc + Vector2(-17, 2), Vector2(8, 9), 16), SHELL)
		ci.draw_arc(hc + Vector2(-17, 2), 5.5, 0, TAU, 16, TEAL, 2.5, true)
		_poly(ci, Art.ellipse(hc, Vector2(29, 26), 30), SHADE)
		ci.draw_colored_polygon(Art.ellipse(hc + Vector2(2, -2), Vector2(26, 23), 30), SHELL)
		# teal crest stripe over the top
		var crest = PackedVector2Array()
		for k in 9:
			var a = lerpf(PI * 1.18, PI * 1.62, float(k) / 8.0)
			crest.append(hc + Vector2(cos(a) * 26.5, sin(a) * 23.5))
		ci.draw_polyline(crest, TEAL, 6.0, true)
		# visor
		var vc = hc + Vector2(9, 2)
		_poly(ci, Art.ellipse(vc, Vector2(19, 15), 26), TEAL)
		ci.draw_colored_polygon(Art.ellipse(vc, Vector2(16.5, 12.5), 26), VISOR)
		ci.draw_colored_polygon(Art.ellipse(vc + Vector2(6, -6), Vector2(5, 2.5), 10, -0.4), Color(1, 1, 1, 0.22))
		# antenna + kite
		var a0 = hc + Vector2(12, -22)
		var a1 = a0 + Vector2(7, -15) + Vector2(sin(t * 6.0) * 1.5, 0)
		ci.draw_line(a0, a1, TEAL, 2.5, true)
		var kd = a1 + Vector2(0, -6)
		_poly(ci, PackedVector2Array([kd + Vector2(0, -7), kd + Vector2(5, 0), kd + Vector2(-5, 0)]), Color(1.0, 0.55, 0.35))
		_poly(ci, PackedVector2Array([kd + Vector2(-5, 0), kd + Vector2(5, 0), kd + Vector2(0, 9)]), Color(0.35, 0.55, 1.0))
		var tail = PackedVector2Array()
		for k in 5:
			tail.append(kd + Vector2(-k * 4.0, 9 + k * 2.0 + sin(t * 10.0 + k) * 2.0))
		ci.draw_polyline(tail, Color(1.0, 0.55, 0.35), 1.5, true)
		# scarf wrap at the neck
		var sc2: Color = SCARVES[scarf % SCARVES.size()]
		ci.draw_set_transform(p.off * s, p.rot, p.sq * s)
		_poly(ci, Art.rrect(Rect2(-14, -66, 30, 10), 5), sc2)
		ci.draw_circle(Vector2(12, -60), 4.5, sc2.darkened(0.12))
		# front arm on top
		var ef = _ik(sh + Vector2(2, 0), hf, 12, 12, -1.0)
		_limb(ci, sh + Vector2(2, 0), ef, 7, SHELL)
		ci.draw_circle(ef, 4, JOINT)
		_limb(ci, ef, hf, 7, SHELL)
		ci.draw_circle(sh + Vector2(2, 0), 5.5, TEAL)
		_poly(ci, Art.ellipse(hf, Vector2(5.5, 5), 12), TEAL)
		_props(ci, hf, false)
	else:
		_eyes(ci, hc + Vector2(9, 2))
		ci.draw_circle(hc + Vector2(-17, 2), 2.5, Art.hdr(GLOW, 1.8))
		ci.draw_circle(hc + Vector2(4, -20), 2.0, Art.hdr(GLOW, 1.6))
		ci.draw_set_transform(p.off * s, p.rot, p.sq * s)
		if pose == "gust":
			Art.glow(ci, hf + Vector2(6, 0), 26.0, Color(0.6, 1.0, 0.8, 0.6), 4)
		_props(ci, hf, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _boot(ci: Node2D, f: Vector2, col: Color) -> void:
	_poly(ci, PackedVector2Array([f + Vector2(-8, -9), f + Vector2(4, -9), f + Vector2(12, -3), f + Vector2(13, 1), f + Vector2(-9, 1)]), col)
	ci.draw_line(f + Vector2(-9, 0), f + Vector2(13, 0), INK, 2.0)

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
	var col = Art.hdr(GLOW, 2.4)
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
				ci.draw_polyline(PackedVector2Array([c + Vector2(-4, 2), c + Vector2(0, -3), c + Vector2(4, 2)]), col, 2.5, true)
		"wow":
			for c in [l, r]:
				ci.draw_arc(c, 4.5, 0, TAU, 16, col, 2.5, true)
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
				ci.draw_polyline(PackedVector2Array([c + Vector2(-4, -3), c + Vector2(2, 0), c + Vector2(-4, 3)]) if c == l else PackedVector2Array([c + Vector2(4, -3), c + Vector2(-2, 0), c + Vector2(4, 3)]), col, 2.5, true)
		"calm":
			for c in [l, r]:
				ci.draw_arc(c + Vector2(0, -1), 3.5, 0.2, PI - 0.2, 8, col, 2.0, true)

static func _heart(ci: Node2D, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.55, col)
	ci.draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.55, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, 0), c + Vector2(0, r)]), col)
