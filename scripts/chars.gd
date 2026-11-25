extends RefCounted
## Supporting cast drawn procedurally: Lia, kind strangers, hover-bikers.
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
## Lia v4 (0.8.35, owner: "Lia still uses her early look"). Same identity as
## the approved references and CHARACTER-SPEC (lilac-white helmet, a fluffy
## white cap with four big lilac flowers and one on a curled stem, a deep plum
## screen with tall soft eyes and pink blush, a deep purple shawl with
## Romanian stepped-diamond embroidery and a lilac fringe, white limbs with
## lilac joints, mitten hands, lilac boots, her sketchbook), redrawn to match
## Kavi's current style: the same thin soft outline, jointed legs and arms,
## a bob-shaped helmet, a swaying shawl, and a wave when she's happy.
const L_SHELL := Color(0.97, 0.95, 1.0)
const L_SHADE := Color(0.80, 0.74, 0.93)
const L_JOINT := Color(0.66, 0.52, 0.90)
const L_SHAWL := Color(0.36, 0.14, 0.50)
const L_SCREEN := Color(0.165, 0.06, 0.25)
const L_PETAL_A := Color(0.80, 0.64, 1.0)
const L_PETAL_B := Color(0.93, 0.74, 1.0)
const L_GOLD := Color(1.0, 0.84, 0.32)
const L_RED := Color(0.93, 0.30, 0.30)
const L_ORANGE := Color(1.0, 0.62, 0.25)
const L_CREAM := Color(1.0, 0.95, 0.84)

static func _lp(ci: Node2D, pts: PackedVector2Array, fill: Color) -> void:
	# fill plus Kavi's thin soft outline
	ci.draw_colored_polygon(pts, fill)
	var c := pts.duplicate()
	c.append(pts[0])
	ci.draw_polyline(c, Color(INK, 0.7), 1.3, Art.AA)

static func _lcap(ci: Node2D, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, Color(INK, 0.75), w + 2.2, Art.AA)
	ci.draw_circle(a, (w + 2.2) * 0.5, Color(INK, 0.75))
	ci.draw_circle(b, (w + 2.2) * 0.5, Color(INK, 0.75))
	ci.draw_line(a, b, col, w, Art.AA)
	ci.draw_circle(a, w * 0.5, col)
	ci.draw_circle(b, w * 0.5, col)

static func _flower(ci: Node2D, c: Vector2, r: float, rot: float, petal: Color) -> void:
	for k in 5:
		var a := rot + TAU * k / 5.0
		var pc := c + Vector2.from_angle(a) * r * 0.62
		ci.draw_colored_polygon(Art.ellipse(pc, Vector2(r * 0.62, r * 0.42), 12, a), Color(INK, 0.55))
		ci.draw_colored_polygon(Art.ellipse(pc, Vector2(r * 0.55, r * 0.36), 12, a), petal)
	ci.draw_circle(c, r * 0.3, L_GOLD)

static func _mitten(ci: Node2D, c: Vector2, col: Color) -> void:
	_lp(ci, Art.ellipse(c, Vector2(4.6, 4.2), 12), col)
	_lp(ci, Art.ellipse(c + Vector2(2.6, -3.0), Vector2(1.9, 2.4), 8, 0.5), col)

static func lia(ci: Node2D, at: Vector2, add: bool, t: float, mood := "normal", facing := -1.0, sc := 1.1) -> void:
	ci.draw_set_transform(at, 0.0, Vector2(facing * sc, sc))
	var breath := sin(t * 1.8)
	var happy := mood in ["happy", "heart"]
	var hop := absf(sin(t * 5.0)) * 2.5 if mood == "heart" else 0.0
	var bob := breath * 0.8 - hop
	var hc := Vector2(3, -84 + bob)
	var sway := sin(t * 1.6) * 1.5
	if not add:
		ci.draw_colored_polygon(Art.ellipse(Vector2(0, 2), Vector2(24, 5), 16), Color(0, 0, 0, 0.35))
		# --- legs: white shells, lilac knees, lilac boots (back leg shaded)
		for e in [[-5.0, L_SHADE, L_JOINT.darkened(0.15)], [6.0, L_SHELL, L_JOINT]]:
			var lx: float = e[0]
			var hip := Vector2(lx, -36 - hop)
			var knee := Vector2(lx + 1.5, -20 - hop * 0.5)
			var ankle := Vector2(lx, -7)
			_lcap(ci, hip, knee, 8.5, e[1])
			_lcap(ci, knee, ankle, 7.5, e[1])
			ci.draw_circle(knee, 3.2, e[2])
			_lp(ci, Art.rrect(Rect2(lx - 6, -11, 15, 11), 5), e[2])
			ci.draw_rect(Rect2(lx - 6, -3, 15, 2.5), Color(1, 1, 1, 0.35))
		# --- back arm, holding the sketchbook from below
		_lcap(ci, Vector2(-6, -58 + bob), Vector2(-4, -46 + bob), 7.0, L_SHADE)
		_lcap(ci, Vector2(-4, -46 + bob), Vector2(6, -40 + bob), 6.5, L_SHADE)
		# --- shawl, back panel (hangs behind, sways, fringe)
		var bp := PackedVector2Array([Vector2(-10, -64 + bob), Vector2(-3, -60 + bob), Vector2(-6 + sway, -30), Vector2(-20 + sway, -27), Vector2(-17, -50 + bob)])
		_lp(ci, bp, L_SHAWL)
		for k in 6:
			var fx := lerpf(-20.0, -6.0, k / 5.0) + sway
			var fy := lerpf(-27.0, -30.0, k / 5.0)
			ci.draw_line(Vector2(fx, fy), Vector2(fx + sway * 0.5, fy + 5.0), L_PETAL_A, 1.6, Art.AA)
		# stepped diamonds down the back panel
		for k in 3:
			var dc := Vector2(-11.5 + sway * (0.3 + k * 0.25), -52 + bob * 0.5 + k * 8.0)
			ci.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -3.2), dc + Vector2(3.2, 0), dc + Vector2(0, 3.2), dc + Vector2(-3.2, 0)]), L_RED)
			ci.draw_colored_polygon(PackedVector2Array([dc + Vector2(0, -1.5), dc + Vector2(1.5, 0), dc + Vector2(0, 1.5), dc + Vector2(-1.5, 0)]), L_CREAM)
		# --- A-line blouse dress with an embroidered hem
		var body := PackedVector2Array([Vector2(-9, -64 + bob), Vector2(11, -64 + bob), Vector2(13, -56 + bob), Vector2(19, -31), Vector2(16, -28), Vector2(-15, -28), Vector2(-17, -31)])
		_lp(ci, body, L_SHELL)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, -63 + bob), Vector2(-1, -63 + bob), Vector2(-5, -29), Vector2(-16, -30)]), Color(L_SHADE, 0.55))
		ci.draw_line(Vector2(-16, -34), Vector2(18, -34), L_SHAWL, 4.0)
		for k in 6:
			var hx := -13.0 + k * 6.0
			ci.draw_colored_polygon(PackedVector2Array([Vector2(hx, -36.5), Vector2(hx + 2.4, -34), Vector2(hx, -31.5), Vector2(hx - 2.4, -34)]), L_ORANGE if k % 2 == 0 else L_RED)
		# --- shawl front: over the shoulder, tied with a rosette brooch
		var fp := PackedVector2Array([Vector2(-4, -66 + bob), Vector2(13, -65 + bob), Vector2(16, -52 + bob), Vector2(11, -44 + bob), Vector2(6, -55 + bob)])
		_lp(ci, fp, L_SHAWL)
		ci.draw_line(Vector2(-2, -62 + bob), Vector2(13, -61 + bob), L_ORANGE, 1.4, Art.AA)
		for k in 4:
			ci.draw_circle(Vector2(14, -49 + bob) + Vector2.from_angle(k * TAU / 4.0 + 0.4) * 2.6, 1.9, L_RED)
		ci.draw_circle(Vector2(14, -49 + bob), 1.6, L_GOLD)
		# --- sketchbook: dark cover, white pages, spiral binding
		var book := Rect2(5, -55 + bob, 16, 20)
		_lp(ci, Art.rrect(book, 2), Color(0.20, 0.16, 0.30))
		ci.draw_rect(Rect2(book.position.x + 2, book.position.y + 2, 12, 16), Color(0.98, 0.97, 0.93))
		_heart(ci, Vector2(book.position.x + 8, book.position.y + 9), 3.0, Color(1.0, 0.5, 0.65))
		for k in 4:
			ci.draw_circle(Vector2(book.position.x + 3 + k * 3.5, book.position.y), 1.1, Color(0.75, 0.75, 0.82))
		# --- front arm: holds the book, or waves when she's happy
		var sh := Vector2(7, -60 + bob)
		if happy:
			pass   # the waving arm is drawn after the head, so the helmet can't hide it
		else:
			var el2 := sh + Vector2(5, 10)
			var hand2 := Vector2(17, -44 + bob)
			_lcap(ci, sh, el2, 7.0, L_SHELL)
			_lcap(ci, el2, hand2, 6.5, L_SHELL)
			ci.draw_circle(el2, 2.6, L_JOINT)
			_mitten(ci, hand2, L_SHELL)
		_lp(ci, Art.ellipse(sh, Vector2(5.5, 5), 12), L_JOINT)
		# --- neck
		ci.draw_colored_polygon(Art.rrect(Rect2(-1, -68 + bob, 9, 6), 3), L_JOINT.darkened(0.2))
		# --- head: bob-shaped helmet (sides reach down around the face)
		for bx in [-19.0, 22.0]:
			_lp(ci, Art.ellipse(hc + Vector2(bx, 9), Vector2(8, 12), 16), L_SHELL if bx > 0 else L_SHADE)
		_lp(ci, Art.ellipse(hc, Vector2(25, 23), 32), L_SHELL)
		ci.draw_arc(hc, 21.0, PI * 0.12, PI * 0.88, 12, Color(L_SHADE, 0.7), 4.0, Art.AA)
		ci.draw_arc(hc + Vector2(-6, -5), 15.0, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.9), 2.4, Art.AA)
		# screen
		_lp(ci, Art.ellipse(hc + Vector2(4, 4), Vector2(18, 14.5), 28), L_JOINT)
		ci.draw_colored_polygon(Art.ellipse(hc + Vector2(4, 4), Vector2(15.5, 12), 28), L_SCREEN)
		ci.draw_line(hc + Vector2(13, -4), hc + Vector2(17, 0), Color(1, 1, 1, 0.22), 2.0)
		# fluffy white cap: five puffs over the top of the helmet
		for k in 5:
			var a := PI * (1.08 + 0.21 * k)
			_lp(ci, Art.ellipse(hc + Vector2(0, -4) + Vector2(cos(a) * 20.0, sin(a) * 17.0), Vector2(9.5, 8.5), 16), Color(1.0, 1.0, 1.0))
		# four big five-petal lilac flowers with gold centres
		for k in 4:
			var a2 := PI * (1.2 + 0.2 * k)
			var fc := hc + Vector2(0, -6) + Vector2(cos(a2) * 21.0, sin(a2) * 20.0)
			_flower(ci, fc, 8.0, t * 0.15 + k * 0.9, L_PETAL_A if k % 2 == 0 else L_PETAL_B)
		# curled stem antenna with one more flower, swaying
		var st := hc + Vector2(11, -24)
		var tip := st + Vector2(6 + sway, -16)
		ci.draw_polyline(PackedVector2Array([st, st + Vector2(7, -5), st + Vector2(3 + sway * 0.5, -11), tip]), Color(0.40, 0.72, 0.44), 2.4, Art.AA)
		_flower(ci, tip + Vector2(0, -3), 5.5, -t * 0.3, L_PETAL_B)
		if happy:
			var w := sin(t * 9.0)
			var el := sh + Vector2(14, -2)
			var hand := el + Vector2(9 + w * 3.0, -15)
			_lcap(ci, sh, el, 7.0, L_SHELL)
			_lcap(ci, el, hand, 6.5, L_SHELL)
			ci.draw_circle(el, 2.6, L_JOINT)
			_mitten(ci, hand, L_SHELL)
	else:
		var ec := Art.hdr(Color(1.0, 0.91, 1.0), 1.9)
		var l := hc + Vector2(-2, 3)
		var r := hc + Vector2(11, 3)
		match mood:
			"heart":
				_heart(ci, l, 4.8, Art.hdr(Color(1.0, 0.5, 0.75), 2.2))
				_heart(ci, r, 4.8, Art.hdr(Color(1.0, 0.5, 0.75), 2.2))
			"happy":
				for c in [l, r]:
					ci.draw_polyline(PackedVector2Array([c + Vector2(-4, 2), c + Vector2(0, -3), c + Vector2(4, 2)]), ec, 2.5, Art.AA)
			_:
				var blink := fmod(t, 4.0) < 0.12
				for c in [l, r]:
					if blink:
						ci.draw_line(c + Vector2(-3, 1), c + Vector2(3, 1), ec, 2.0)
					else:
						# tall soft ovals (aspect 1.45) with a tiny sparkle
						ci.draw_colored_polygon(Art.ellipse(c, Vector2(3.5, 5.1), 14), ec)
						ci.draw_circle(c + Vector2(1.0, -2.0), 1.1, Color(1, 1, 1, 0.9))
		ci.draw_arc(hc + Vector2(4.5, 10), 3.0, 0.4, PI - 0.4, 8, Color(ec, 0.85), 1.6, Art.AA)
		var blush := Art.hdr(Color(1.0, 0.56, 0.75, 0.8 if happy else 0.6), 1.2)
		ci.draw_circle(hc + Vector2(-8, 8), 2.8, blush)
		ci.draw_circle(hc + Vector2(17, 8), 2.8, blush)
		Art.glow(ci, hc + Vector2(0, -26), 30.0, Color(0.8, 0.6, 1.0, 0.3), 3)
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
