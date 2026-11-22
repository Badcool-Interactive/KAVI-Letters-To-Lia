extends RefCounted
## Supporting cast drawn procedurally: Lumi, kind strangers, hover-bikers.
## Each function draws at the origin (feet), facing right; `add` = emissive pass.

const Art = preload("res://scripts/art.gd")
const INK := Color(0.04, 0.06, 0.11)

static func _poly(ci: Node2D, pts: PackedVector2Array, fill: Color) -> void:
	ci.draw_colored_polygon(pts, fill)
	var c = pts.duplicate()
	c.append(pts[0])
	ci.draw_polyline(c, INK, 2.2, Art.AA)

static func _heart(ci: Node2D, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.2), r * 0.55, col)
	ci.draw_circle(c + Vector2(r * 0.5, -r * 0.2), r * 0.55, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r, 0), c + Vector2(0, r)]), col)

# ------------------------------------------------------------------ Lia
## Lia v3 (matches Kavi v3): round, soft shapes against Kavi's boxy ones. A
## round head with an oval screen face (eyes, blush, mouth), a lilac flower
## crown, an A-line body with a Romanian-embroidered shawl, real arms holding
## her sketchbook, chunky little boots.
static func lumi(ci: Node2D, at: Vector2, add: bool, t: float, mood := "normal", facing := -1.0, sc := 1.1) -> void:
	ci.draw_set_transform(at, 0.0, Vector2(facing * sc, sc))
	var lil = Color(0.95, 0.92, 1.0)
	var shade = Color(0.76, 0.68, 0.92)
	var lj = Color(0.66, 0.50, 0.90)
	var shawl = Color(0.40, 0.16, 0.54)
	var screen = Color(0.15, 0.06, 0.24)
	var breath = sin(t * 1.8)
	var bob = breath * 0.8
	var hc = Vector2(2, -84 + bob)
	if not add:
		ci.draw_colored_polygon(Art.ellipse(Vector2(0, 2), Vector2(24, 5), 16), Color(0, 0, 0, 0.35))
		# legs + boots
		for fx in [-6.0, 7.0]:
			ci.draw_colored_polygon(Art.rrect(Rect2(fx - 6, -30, 12, 24), 5), INK)
			ci.draw_colored_polygon(Art.rrect(Rect2(fx - 4, -30, 8, 22), 4), shade if fx < 0 else lil)
			_poly(ci, Art.rrect(Rect2(fx - 8, -10, 18, 10), 5), lj)
			ci.draw_rect(Rect2(fx - 8, -3, 18, 3), lj.lightened(0.45))
		# back arm
		ci.draw_line(Vector2(-12, -56 + bob), Vector2(-15, -38 + bob), INK, 11.0)
		ci.draw_line(Vector2(-12, -56 + bob), Vector2(-15, -38 + bob), shade, 7.5)
		# A-line body
		var body := PackedVector2Array([Vector2(-11, -62 + bob), Vector2(12, -62 + bob), Vector2(19, -28), Vector2(-18, -28)])
		_poly(ci, Art.rrect(Rect2(-13, -64 + bob, 27, 8), 4), lil)
		_poly(ci, body, lil)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-11, -60 + bob), Vector2(-3, -60 + bob), Vector2(-6, -28), Vector2(-18, -28)]), Color(shade, 0.6))
		# embroidered shawl band across the shoulders
		_poly(ci, PackedVector2Array([Vector2(-17, -64 + bob), Vector2(18, -64 + bob), Vector2(15, -50 + bob), Vector2(1, -45 + bob), Vector2(-14, -50 + bob)]), shawl)
		for k in 5:
			var dx = -11.0 + k * 6.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(dx, -58 + bob), Vector2(dx + 2.5, -55 + bob), Vector2(dx, -52 + bob), Vector2(dx - 2.5, -55 + bob)]), Color(0.96, 0.36, 0.32))
		ci.draw_line(Vector2(-16, -48 + bob), Vector2(17, -48 + bob), Color(1.0, 0.78, 0.45), 1.5)
		# hem stripe
		ci.draw_line(Vector2(-17, -32), Vector2(18, -32), lj, 3.0)
		# sketchbook held in front, front arm over it
		_poly(ci, Art.rrect(Rect2(6, -52 + bob, 17, 21), 2), Color(0.17, 0.15, 0.25))
		ci.draw_rect(Rect2(8, -50 + bob, 13, 17), Color(0.97, 0.96, 0.92))
		ci.draw_line(Vector2(10, -45 + bob), Vector2(18, -42 + bob), Color(0.85, 0.5, 0.6), 1.2)
		ci.draw_line(Vector2(7, -58 + bob), Vector2(14, -42 + bob), INK, 11.0)
		ci.draw_line(Vector2(7, -58 + bob), Vector2(14, -42 + bob), lil, 7.5)
		_poly(ci, Art.ellipse(Vector2(15, -41 + bob), Vector2(5.5, 5), 12), lil)
		# head: round shell with side buns, oval screen face
		for bx in [-23.0, 25.0]:
			_poly(ci, Art.ellipse(hc + Vector2(bx, 2), Vector2(7, 9), 14), lj)
		_poly(ci, Art.ellipse(hc, Vector2(26, 24), 30), lil)
		ci.draw_arc(hc, 22.0, PI * 0.15, PI * 0.85, 10, Color(shade, 0.6), 4.0, Art.AA)
		ci.draw_arc(hc + Vector2(-6, -4), 15.0, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.85), 2.4, Art.AA)
		_poly(ci, Art.ellipse(hc + Vector2(3, 3), Vector2(18, 14), 26), lj)
		ci.draw_colored_polygon(Art.ellipse(hc + Vector2(3, 3), Vector2(15.5, 11.5), 26), screen)
		ci.draw_line(hc + Vector2(12, -5), hc + Vector2(16, -1), Color(1, 1, 1, 0.22), 2.0)
		# flower crown
		for k in 5:
			var a = PI * (1.12 + 0.19 * k)
			var fp = hc + Vector2(cos(a) * 23, sin(a) * 21)
			for pi in 5:
				var a2 = TAU * pi / 5.0 + t * 0.2 + k
				ci.draw_circle(fp + Vector2(cos(a2), sin(a2)) * 4.2, 3.4, Color(0.80, 0.64, 1.0) if k % 2 == 0 else Color(1.0, 0.72, 0.82))
			ci.draw_circle(fp, 2.2, Color(1.0, 0.84, 0.32))
		# little stem antenna with a bud
		var st = hc + Vector2(12, -23)
		ci.draw_polyline(PackedVector2Array([st, st + Vector2(5, -7), st + Vector2(2, -13)]), Color(0.45, 0.78, 0.48), 2.2, Art.AA)
		ci.draw_circle(st + Vector2(2, -15), 3.2, Color(0.86, 0.72, 1.0))
	else:
		var ec = Art.hdr(Color(1.0, 0.91, 1.0), 1.9)
		var l = hc + Vector2(-3, 1)
		var r = hc + Vector2(10, 1)
		match mood:
			"heart":
				_heart(ci, l, 4.5, Art.hdr(Color(1.0, 0.5, 0.75), 2.2))
				_heart(ci, r, 4.5, Art.hdr(Color(1.0, 0.5, 0.75), 2.2))
			"happy":
				for c in [l, r]:
					ci.draw_polyline(PackedVector2Array([c + Vector2(-4, 2), c + Vector2(0, -3), c + Vector2(4, 2)]), ec, 2.5, Art.AA)
			_:
				var blink = fmod(t, 4.0) < 0.12
				for c in [l, r]:
					if blink:
						ci.draw_line(c + Vector2(-3, 1), c + Vector2(3, 1), ec, 2.0)
					else:
						ci.draw_colored_polygon(Art.ellipse(c, Vector2(3.4, 5.0), 12), ec)
		ci.draw_arc(hc + Vector2(3.5, 8), 3.0, 0.4, PI - 0.4, 8, Color(ec, 0.85), 1.6, Art.AA)
		ci.draw_circle(hc + Vector2(-9, 7), 2.8, Art.hdr(Color(1.0, 0.56, 0.75, 0.7), 1.2))
		ci.draw_circle(hc + Vector2(16, 7), 2.8, Art.hdr(Color(1.0, 0.56, 0.75, 0.7), 1.2))
		Art.glow(ci, hc + Vector2(0, -22), 30.0, Color(0.8, 0.6, 1.0, 0.3), 3)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ strangers
const NPCS := {
	"yiayia": {"body": Color(0.30, 0.22, 0.38), "head": Color(0.92, 0.88, 0.95), "scarf": Color(0.12, 0.12, 0.18), "eye": Color(1.0, 0.85, 0.5), "item": "koulouri"},
	"shop": {"body": Color(0.20, 0.42, 0.50), "head": Color(0.90, 0.95, 0.97), "scarf": Color(0.95, 0.75, 0.3), "eye": Color(0.5, 1.0, 0.8), "item": "water"},
	"farmer": {"body": Color(0.45, 0.32, 0.20), "head": Color(0.95, 0.93, 0.86), "scarf": Color(0.55, 0.75, 0.3), "eye": Color(1.0, 0.95, 0.6), "item": "fruit"},
	"kid": {"body": Color(0.95, 0.55, 0.30), "head": Color(0.98, 0.98, 1.0), "scarf": Color(0.3, 0.6, 1.0), "eye": Color(0.5, 0.9, 1.0), "item": "flag"},
}

static func npc(ci: Node2D, at: Vector2, add: bool, t: float, kind: String, wave := false, sc := 1.1) -> void:
	var d: Dictionary = NPCS.get(kind, NPCS["shop"])
	var k_small = 0.75 if kind == "kid" else 1.0
	var hop = absf(sin(t * 6.0)) * 6.0 if kind == "kid" else 0.0
	ci.draw_set_transform(at + Vector2(0, -hop), 0.0, Vector2(-sc * k_small, sc * k_small))
	if not add:
		ci.draw_colored_polygon(Art.ellipse(Vector2(0, hop + 2), Vector2(26, 5), 16), Color(0, 0, 0, 0.35))
		_poly(ci, PackedVector2Array([Vector2(-18, 0), Vector2(18, 0), Vector2(13, -50), Vector2(-13, -50)]), d.body)
		_poly(ci, Art.ellipse(Vector2(0, -70), Vector2(21, 19), 24), d.head)
		if kind == "yiayia":
			_poly(ci, PackedVector2Array([Vector2(-24, -66), Vector2(-14, -92), Vector2(14, -92), Vector2(24, -66), Vector2(16, -56), Vector2(-16, -56)]), d.scarf)
			ci.draw_colored_polygon(Art.ellipse(Vector2(4, -68), Vector2(12, 9), 20), Color(0.05, 0.05, 0.1))
		else:
			ci.draw_colored_polygon(Art.ellipse(Vector2(5, -70), Vector2(14, 10), 20), Color(0.05, 0.05, 0.1))
			ci.draw_rect(Rect2(-16, -54, 32, 6), d.scarf)
		var arm_end = Vector2(26, -60 + sin(t * 10.0) * 10.0) if wave else Vector2(26, -36)
		ci.draw_line(Vector2(10, -44), arm_end, INK, 8.0)
		ci.draw_line(Vector2(10, -44), arm_end, d.head, 5.0)
		match d.item:
			"koulouri":
				ci.draw_arc(arm_end + Vector2(8, -2), 8.0, 0, TAU, 18, Color(0.85, 0.55, 0.25), 5.0, Art.AA)
			"water":
				ci.draw_rect(Rect2(arm_end.x + 2, arm_end.y - 16, 9, 18), Color(0.6, 0.85, 1.0, 0.9))
			"fruit":
				ci.draw_circle(arm_end + Vector2(6, -3), 7.0, Color(0.95, 0.3, 0.25))
			"flag":
				ci.draw_line(arm_end, arm_end + Vector2(0, -34), INK, 2.0)
				ci.draw_colored_polygon(PackedVector2Array([arm_end + Vector2(0, -34), arm_end + Vector2(22, -28 + sin(t * 8.0) * 3.0), arm_end + Vector2(0, -20)]), Color(1.0, 0.5, 0.3))
	else:
		var ec = Art.hdr(d.eye, 2.0)
		for ex in [0.0, 10.0]:
			ci.draw_polyline(PackedVector2Array([Vector2(ex - 3, -69), Vector2(ex, -73), Vector2(ex + 3, -69)]), ec, 2.0, Art.AA)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ bikers
const BIKERS := [
	{"name": "Marek", "bike": Color(0.75, 0.12, 0.16), "suit": Color(0.10, 0.10, 0.14), "helm": Color(0.12, 0.12, 0.16), "light": Color(1.0, 0.35, 0.25), "beard": true, "dog": false, "flowers": false},
	{"name": "Nana Vira", "bike": Color(0.55, 0.40, 0.85), "suit": Color(0.35, 0.22, 0.45), "helm": Color(0.92, 0.88, 0.98), "light": Color(1.0, 0.6, 0.95), "beard": false, "dog": false, "flowers": true},
	{"name": "Zip", "bike": Color(0.10, 0.75, 0.70), "suit": Color(0.12, 0.16, 0.22), "helm": Color(0.95, 0.95, 0.98), "light": Color(0.3, 1.0, 0.9), "beard": false, "dog": false, "flowers": false},
	{"name": "Bogdan & Sharo", "bike": Color(0.95, 0.62, 0.15), "suit": Color(0.25, 0.20, 0.16), "helm": Color(0.30, 0.22, 0.15), "light": Color(1.0, 0.8, 0.3), "beard": true, "dog": true, "flowers": false},
]

## Hover-bike with rider. `lean` tilts the bike, `wave` raises the rider's arm.
static func biker(ci: Node2D, at: Vector2, add: bool, t: float, v: int, lean := 0.0, wave := 0.0) -> void:
	var b: Dictionary = BIKERS[v % BIKERS.size()]
	ci.draw_set_transform(at, lean, Vector2(1.15, 1.15))
	var hover = sin(t * 8.0) * 2.0
	var y0 = -34.0 + hover
	if not add:
		ci.draw_colored_polygon(Art.ellipse(Vector2(0, 30 - hover), Vector2(80, 7), 18), Color(0, 0, 0, 0.3))
		if b.dog:
			# sidecar with Sharo
			_poly(ci, Art.rrect(Rect2(-40, y0 - 4, 56, 26), 12), b.bike.darkened(0.35))
			_poly(ci, Art.ellipse(Vector2(-10, y0 - 16), Vector2(14, 11), 18), Color(0.95, 0.88, 0.75))
			_poly(ci, Art.ellipse(Vector2(-22, y0 - 26), Vector2(5, 9), 12, -0.4), Color(0.55, 0.38, 0.25))
			ci.draw_circle(Vector2(-4, y0 - 18), 2.5, INK)
			ci.draw_line(Vector2(0, y0 - 26), Vector2(10, y0 - 32), Color(0.15, 0.1, 0.1), 3.0)
		# bike body
		_poly(ci, PackedVector2Array([Vector2(-78, y0 + 6), Vector2(-60, y0 - 18), Vector2(-10, y0 - 24), Vector2(30, y0 - 34),
			Vector2(72, y0 - 22), Vector2(86, y0 - 8), Vector2(70, y0 + 10), Vector2(-50, y0 + 16)]), b.bike)
		ci.draw_line(Vector2(-60, y0 - 4), Vector2(66, y0 - 10), b.bike.lightened(0.3), 3.0)
		_poly(ci, Art.rrect(Rect2(-70, y0 + 10, 50, 12), 6), b.bike.darkened(0.4))
		_poly(ci, Art.rrect(Rect2(20, y0 + 8, 52, 12), 6), b.bike.darkened(0.4))
		ci.draw_line(Vector2(44, y0 - 30), Vector2(52, y0 - 52), INK, 5.0)
		# rider
		var seat = Vector2(-10, y0 - 24)
		ci.draw_line(seat, seat + Vector2(26, 22), INK, 12.0)
		ci.draw_line(seat, seat + Vector2(26, 22), b.suit, 8.0)
		_poly(ci, Art.rrect(Rect2(seat.x - 14, seat.y - 40, 30, 42), 12), b.suit)
		var sh = seat + Vector2(6, -32)
		var hand = Vector2(52, y0 - 50)
		if wave > 0.0:
			hand = sh + Vector2(10 + sin(t * 14.0) * 8.0, -30).lerp(Vector2(46, -18), 1.0 - wave)
		ci.draw_line(sh, hand, INK, 10.0)
		ci.draw_line(sh, hand, b.suit.lightened(0.1), 6.0)
		var hc = seat + Vector2(8, -56)
		_poly(ci, Art.ellipse(hc, Vector2(20, 18), 24), b.helm)
		ci.draw_colored_polygon(Art.ellipse(hc + Vector2(8, 2), Vector2(12, 8), 18), Color(0.04, 0.04, 0.08))
		if b.beard:
			_poly(ci, Art.ellipse(hc + Vector2(8, 16), Vector2(10, 8), 14), Color(0.35, 0.25, 0.2))
		if b.flowers:
			for k in 3:
				ci.draw_circle(hc + Vector2(-10 + k * 9, -17), 4.0, [Color(1.0, 0.6, 0.8), Color(1.0, 0.9, 0.4), Color(0.7, 0.6, 1.0)][k])
		# flowing scarf
		var sp = PackedVector2Array()
		for k in 6:
			sp.append(hc + Vector2(-10 - k * 12, 16 + sin(t * 12.0 - k) * 4.0 + k * 2))
		ci.draw_polyline(sp, b.light.darkened(0.2), 5.0, Art.AA)
	else:
		ci.draw_line(Vector2(-66, y0 + 22), Vector2(-24, y0 + 22), Art.hdr(b.light, 2.0), 4.0)
		ci.draw_line(Vector2(24, y0 + 20), Vector2(68, y0 + 20), Art.hdr(b.light, 2.0), 4.0)
		Art.glow(ci, Vector2(-45, y0 + 34), 40.0, Color(b.light, 0.5), 4)
		Art.glow(ci, Vector2(46, y0 + 32), 40.0, Color(b.light, 0.5), 4)
		ci.draw_circle(Vector2(84, y0 - 12), 5.0, Art.hdr(Color(1, 1, 0.9), 2.4))
		var beam = Vector2(84, y0 - 12)
		ci.draw_colored_polygon(PackedVector2Array([beam, beam + Vector2(260, -50), beam + Vector2(260, 40)]), Color(1, 1, 0.9, 0.06))
		var hc2 = Vector2(-2, y0 - 80)
		ci.draw_line(hc2 + Vector2(4, 0), hc2 + Vector2(14, 0), Art.hdr(b.light, 2.2), 3.0)
		# exhaust
		for k in 5:
			var ex = -86.0 - k * 18.0 - fmod(t * 300.0, 18.0)
			ci.draw_circle(Vector2(ex, y0 + 4 + sin(t * 20.0 + k) * 3.0), 6.0 - k, Color(b.light, 0.35 - k * 0.06))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
