extends Node2D
## Screen-space layered background: sky, light, parallax silhouettes, haze.
## Lives on a CanvasLayer behind the world. Fed camera state by main.gd.

const Art = preload("res://scripts/art.gd")
const Painter = preload("res://scripts/painter.gd")

var pal: Dictionary = Art.biome(0)
var cam_x = 0.0
var cam_y = 0.0
var t = 0.0
var quality = 2 # 0 low, 1 medium, 2 high
var size = Vector2(1920, 1080)
var calm = 0.0 # 0 running, 1 recovery (warmer, softer)

const PAR := [0.06, 0.16, 0.36]
const BASE := [0.62, 0.71, 0.80]
const CELL := [560.0, 400.0, 300.0]
const DENS := [0.55, 0.65, 0.7]
const SCALE := [0.75, 0.9, 1.05]

var _lights: Array = [[], [], []]
var _painters: Array = []

func _ready() -> void:
	var order = [
		[_draw_sky, false], [_draw_sky_light, true],
		[_draw_layer.bind(0), false], [_draw_lights.bind(0), true], [_draw_haze.bind(0), false],
		[_draw_layer.bind(1), false], [_draw_lights.bind(1), true], [_draw_shafts, true], [_draw_haze.bind(1), false],
		[_draw_layer.bind(2), false], [_draw_lights.bind(2), true], [_draw_motes, true],
	]
	for o in order:
		var p = Painter.new()
		p.fn = o[0]
		if o[1]:
			var m = CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			p.material = m
			p.modulate = Color(1, 1, 1, 0.6)
		add_child(p)
		_painters.append(p)

func refresh() -> void:
	size = get_viewport_rect().size
	for p in _painters:
		p.queue_redraw()

func _ground_y() -> float:
	return size.y * BASE[2] - cam_y * 0.05

# ------------------------------------------------------------------ sky
func _draw_sky(ci: Node2D) -> void:
	var w = size.x
	var h = size.y
	var top: Color = pal.sky[0]
	var mid: Color = pal.sky[1]
	var hor: Color = pal.sky[2].lerp(Color(1.0, 0.8, 0.6), calm * 0.15)
	var hy = h * 0.66
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.38), Vector2(0, h * 0.38)]),
		PackedColorArray([top, top, mid, mid]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, h * 0.38), Vector2(w, h * 0.38), Vector2(w, hy), Vector2(0, hy)]),
		PackedColorArray([mid, mid, hor, hor]))
	ci.draw_rect(Rect2(0, hy, w, h - hy), hor)
	# stars
	if pal.stars > 0.01:
		for i in 140:
			var sx = fmod(Art.hash01(i, 11) * w * 1.3 - cam_x * 0.01, w * 1.3) - w * 0.15
			if sx < 0.0: sx += w * 1.3
			var sy = Art.hash01(i, 23) * h * 0.55
			var tw = 0.55 + 0.45 * sin(t * (1.0 + Art.hash01(i, 5) * 2.0) + i)
			var a: float = pal.stars * tw * (1.0 - sy / (h * 0.6)) * 0.85
			ci.draw_circle(Vector2(sx, sy), 0.8 + Art.hash01(i, 7) * 1.6, Color(0.9, 0.95, 1.0, a))

func _draw_sky_light(ci: Node2D) -> void:
	var w = size.x
	var h = size.y
	var sp: Vector2 = Vector2(pal.sun_pos.x * w - cam_x * 0.004, pal.sun_pos.y * h - cam_y * 0.02)
	var sc: Color = pal.sun
	var r: float = pal.sun_r
	# wide atmospheric halo
	for i in 10:
		var f = float(i) / 10.0
		ci.draw_circle(sp, r * (6.0 - f * 5.0), Color(sc.r, sc.g, sc.b, 0.025 + f * 0.02))
	ci.draw_circle(sp, r * 0.62, Color(sc, 0.35))
	ci.draw_circle(sp, r * 0.44, Art.hdr(sc, 1.05))
	ci.draw_circle(sp, r * 0.30, Art.hdr(sc.lerp(Color(1, 1, 1), 0.6), 1.25))
	# horizon glow line
	ci.draw_polygon(PackedVector2Array([Vector2(0, h * 0.52), Vector2(w, h * 0.52), Vector2(w, h * 0.70), Vector2(0, h * 0.70)]),
		PackedColorArray([Color(sc, 0.0), Color(sc, 0.0), Color(sc, 0.22), Color(sc, 0.22)]))
	# aurora ribbons
	if pal.aurora > 0.01:
		for band in 3:
			var pts = PackedVector2Array()
			var cols = PackedColorArray()
			var base_y = h * (0.16 + band * 0.07)
			for k in 41:
				var x = -40.0 + (w + 80.0) * k / 40.0
				var lx = x + cam_x * 0.02
				var y = base_y + sin(lx * 0.004 + t * 0.35 + band) * 50.0 + sin(lx * 0.011 - t * 0.6) * 18.0
				pts.append(Vector2(x, y))
			var ac = Color(0.3, 1.0, 0.75) if band != 1 else Color(0.75, 0.45, 1.0)
			for k in pts.size():
				var a = 0.5 + 0.5 * sin(k * 0.5 + t * 0.8 + band * 2.0)
				var p = pts[k]
				ci.draw_line(p, p + Vector2(0, 160 + band * 40), Color(ac, 0.045 * a * pal.aurora), 30.0)
				ci.draw_line(p, p + Vector2(0, 70), Color(ac, 0.06 * a * pal.aurora), 18.0)
			ci.draw_polyline(pts, Color(ac, 0.22 * pal.aurora), 2.0, true)
	# water shimmer under the horizon
	if pal.water > 0.01:
		var wy = size.y * BASE[0] + 6.0 - cam_y * 0.01
		for i in 46:
			var yy = wy + pow(Art.hash01(i, 3), 1.6) * (h * 0.12)
			var spread = 40.0 + (yy - wy) * 2.2
			var cx = sp.x + (Art.hash01(i, 9) - 0.5) * spread * 2.0 + sin(t * 1.5 + i) * 10.0
			var ln = 10.0 + Art.hash01(i, 4) * 60.0
			ci.draw_line(Vector2(cx - ln, yy), Vector2(cx + ln, yy), Color(sc, 0.35 * pal.water * (0.5 + 0.5 * sin(t * 2.0 + i))), 2.0)

# ------------------------------------------------------------------ layers
func _layer_base(i: int) -> float:
	return size.y * BASE[i] - cam_y * PAR[i] * 0.25 + (1.0 - calm) * 0.0

func _ridge_y(i: int, lx: float) -> float:
	var amp = [70.0, 46.0, 26.0][i]
	var fr = [0.0016, 0.0026, 0.004][i]
	if i == 0 and pal.kinds[0].has("peak"):
		amp = 150.0
	return _layer_base(i) - Art.ridge(lx, 3.1 + i * 7.7, amp, fr) - amp * 0.6

func _draw_layer(ci: Node2D, i: int) -> void:
	_lights[i] = []
	var col: Color = pal.layers[i]
	var par: float = PAR[i]
	var off = cam_x * par
	var pts = PackedVector2Array()
	var x = -60.0
	while x <= size.x + 60.0:
		pts.append(Vector2(x, _ridge_y(i, x + off)))
		x += 24.0
	pts.append(Vector2(size.x + 60.0, size.y + 10.0))
	pts.append(Vector2(-60.0, size.y + 10.0))
	# features behind the ridge fill so their bases are hidden
	var cw: float = CELL[i]
	var c0 = int(floor((off - 700.0) / cw))
	var c1 = int(floor((off + size.x + 700.0) / cw))
	var kinds: Array = pal.kinds[i]
	for c in range(c0, c1 + 1):
		var r = Art.hash01(c, 101 + i * 31)
		if r > DENS[i] * (0.6 if quality == 0 else 1.0):
			continue
		var kind: String = kinds[int(Art.hash01(c, 7 + i) * kinds.size()) % kinds.size()]
		var lx = c * cw + Art.hash01(c, 13 + i) * cw * 0.7
		var sx = lx - off
		var s: float = SCALE[i] * (0.7 + Art.hash01(c, 19 + i) * 0.5)
		_feature(ci, i, kind, Vector2(sx, _ridge_y(i, lx) + 14.0), s, col, c)
	ci.draw_colored_polygon(pts, col)
	# rim light along the ridge, facing the sun
	var rim: Color = pal.rim
	var rim_pts = pts.slice(0, pts.size() - 2)
	ci.draw_polyline(rim_pts, Color(rim, 0.05 + 0.05 * i), 1.5 + i * 0.5, true)

func _feature(ci: Node2D, layer: int, kind: String, p: Vector2, s: float, col: Color, seed: int) -> void:
	var acc: Color = pal.accent
	var L: Array = _lights[layer]
	var lt = Art.hdr(pal.mote, 1.0)
	match kind:
		"spire":
			var hgt = (380.0 + Art.hash01(seed, 3) * 260.0) * s
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-22 * s, 0), p + Vector2(-7 * s, -hgt * 0.8), p + Vector2(0, -hgt), p + Vector2(7 * s, -hgt * 0.8), p + Vector2(22 * s, 0)]), col)
			var ring = Art.ellipse(p + Vector2(0, -hgt * 0.55), Vector2(48 * s, 12 * s), 24)
			ring.append(ring[0])
			ci.draw_polyline(ring, col.lightened(0.15), 4.0 * s, true)
			L.append([p + Vector2(0, -hgt), 7.0 * s, acc])
			L.append([p + Vector2(0, -hgt * 0.55), 4.0 * s, acc])
		"dome":
			var bw = (110.0 + Art.hash01(seed, 4) * 70.0) * s
			var bh = (80.0 + Art.hash01(seed, 5) * 80.0) * s
			ci.draw_rect(Rect2(p.x - bw * 0.5, p.y - bh, bw, bh), col)
			ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, -bh), Vector2(bw * 0.34, bw * 0.3), 20), col)
			ci.draw_line(p + Vector2(0, -bh - bw * 0.3), p + Vector2(0, -bh - bw * 0.55), col, 3.0 * s)
			for k in 3:
				if Art.hash01(seed, 40 + k) < 0.6:
					L.append([p + Vector2(-bw * 0.3 + k * bw * 0.3, -bh * 0.55), 6.0 * s, lt])
			L.append([p + Vector2(0, -bh - bw * 0.55), 3.5 * s, acc])
		"ring":
			var c = p + Vector2(0, -(330.0 + Art.hash01(seed, 8) * 120.0) * s)
			var R = (120.0 + Art.hash01(seed, 9) * 70.0) * s
			ci.draw_line(p, c + Vector2(0, R), col, 10.0 * s)
			ci.draw_arc(c, R, 0.0, TAU, 48, col, 14.0 * s, true)
			ci.draw_arc(c, R - 9.0 * s, PI * 1.1, PI * 1.9, 20, Color(pal.rim, 0.35), 3.0 * s, true)
			L.append([c + Vector2(0, -R), 6.0 * s, acc])
			L.append([c, 3.0 * s, Color(acc, 0.5)])
		"column":
			var hh = (150.0 + Art.hash01(seed, 6) * 110.0) * s
			ci.draw_rect(Rect2(p.x - 15 * s, p.y - hh, 30 * s, hh), col)
			ci.draw_rect(Rect2(p.x - 26 * s, p.y - hh - 14 * s, 52 * s, 14 * s), col)
			if Art.hash01(seed, 66) < 0.5:
				L.append([p + Vector2(0, -hh - 30 * s), 5.0 * s, acc])
		"olive":
			ci.draw_line(p, p + Vector2(6 * s, -70 * s), col, 12.0 * s)
			ci.draw_line(p + Vector2(4 * s, -50 * s), p + Vector2(-30 * s, -90 * s), col, 7.0 * s)
			for k in 7:
				var a = float(k) / 7.0 * TAU
				ci.draw_circle(p + Vector2(cos(a) * 52 * s, -110 * s + sin(a) * 28 * s), (30.0 + Art.hash01(seed, k) * 16.0) * s, col)
			ci.draw_circle(p + Vector2(0, -112 * s), 46 * s, col)
		"cypress":
			ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, -130 * s), Vector2(26 * s, 135 * s), 20), col)
		"pine":
			var ph = (240.0 + Art.hash01(seed, 2) * 200.0) * s
			ci.draw_line(p, p + Vector2(0, -ph), col, 8.0 * s)
			for k in 5:
				var yy = p.y - ph * (0.2 + 0.18 * k)
				var ww = (78.0 - k * 13.0) * s
				ci.draw_colored_polygon(PackedVector2Array([Vector2(p.x - ww, yy + 30 * s), Vector2(p.x, yy - ph * 0.26), Vector2(p.x + ww, yy + 30 * s)]), col)
		"peak":
			var pw = (380.0 + Art.hash01(seed, 2) * 300.0) * s
			var phh = (300.0 + Art.hash01(seed, 3) * 260.0) * s
			var top = p + Vector2(Art.hash01(seed, 4) * 60.0 - 30.0, -phh)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-pw, 60), top, p + Vector2(pw, 60)]), col)
			ci.draw_line(top, top.lerp(p + Vector2(pw, 60), 0.35), Color(pal.rim, 0.45), 3.0)
		"lantern":
			var bob = sin(t * 1.3 + seed) * 12.0
			var lp = p + Vector2(0, -(120.0 + Art.hash01(seed, 2) * 160.0) * s + bob)
			ci.draw_circle(lp, 7.0 * s, col.lightened(0.2))
			L.append([lp, 10.0 * s, Art.hdr(acc, 1.3)])
		"fern":
			for k in 5:
				var a = -PI * 0.5 + (k - 2) * 0.35
				var tip = p + Vector2(cos(a), sin(a)) * 90.0 * s
				ci.draw_line(p, tip, col, 5.0 * s)
				ci.draw_line(tip, tip + Vector2(18 * s * (k - 2), 10 * s), col, 4.0 * s)
		"bridge":
			var bl = 700.0 * s
			var top = -260.0 * s
			var arc = PackedVector2Array()
			for k in 25:
				var f = float(k) / 24.0
				arc.append(p + Vector2(-bl * 0.5 + bl * f, top + sin(f * PI) * -90.0 * s))
			ci.draw_polyline(arc, col, 9.0 * s, true)
			ci.draw_line(p + Vector2(-bl * 0.5, -120 * s), p + Vector2(bl * 0.5, -120 * s), col, 12.0 * s)
			for k in 12:
				var q: Vector2 = arc[k * 2]
				ci.draw_line(q, Vector2(q.x, p.y - 120 * s), col, 2.0)
				L.append([q, 3.5 * s, Art.hdr(pal.mote, 1.2)])
		"turbine":
			var th = (300.0 + Art.hash01(seed, 3) * 140.0) * s
			var hub = p + Vector2(0, -th)
			ci.draw_line(p, hub, col, 7.0 * s)
			var rot = t * (0.4 + Art.hash01(seed, 5) * 0.5) + seed
			for k in 3:
				var a = rot + TAU * k / 3.0
				ci.draw_line(hub, hub + Vector2(cos(a), sin(a)) * 110.0 * s, col, 6.0 * s)
			L.append([hub, 6.0 * s, acc])
		"reed":
			for k in 6:
				var bx = p.x + (k - 3) * 9.0 * s
				var hh = (70.0 + Art.hash01(seed, k) * 70.0) * s
				var sway = sin(t * 1.2 + k + seed) * 6.0
				ci.draw_line(Vector2(bx, p.y), Vector2(bx + sway, p.y - hh), col, 3.0 * s)
				ci.draw_colored_polygon(Art.ellipse(Vector2(bx + sway, p.y - hh), Vector2(4 * s, 13 * s), 10), col)
		"lily":
			var lh = (120.0 + Art.hash01(seed, 2) * 140.0) * s
			var tip = p + Vector2(sin(t * 0.8 + seed) * 8.0, -lh)
			ci.draw_line(p, tip, col, 4.0 * s)
			ci.draw_colored_polygon(Art.ellipse(tip, Vector2(14 * s, 20 * s), 14), col)
			L.append([tip, 9.0 * s, Art.hdr(pal.mote, 1.4)])
		"castle":
			var ch = (240.0 + Art.hash01(seed, 2) * 160.0) * s
			ci.draw_rect(Rect2(p.x - 36 * s, p.y - ch, 72 * s, ch), col)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-46 * s, -ch), p + Vector2(0, -ch - 120 * s), p + Vector2(46 * s, -ch)]), col)
			ci.draw_rect(Rect2(p.x + 50 * s, p.y - ch * 0.6, 50 * s, ch * 0.6), col)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(44 * s, -ch * 0.6), p + Vector2(75 * s, -ch * 0.6 - 70 * s), p + Vector2(106 * s, -ch * 0.6)]), col)
			L.append([p + Vector2(0, -ch * 0.62), 6.0 * s, Art.hdr(pal.mote, 1.1)])
			L.append([p + Vector2(0, -ch - 120 * s), 5.0 * s, acc])
			var fl = p + Vector2(0, -ch - 120 * s)
			ci.draw_line(fl, fl + Vector2(0, -40 * s), col, 3.0)
			var wv = sin(t * 3.0 + seed) * 6.0 * s
			ci.draw_colored_polygon(PackedVector2Array([fl + Vector2(0, -40 * s), fl + Vector2(40 * s, -32 * s + wv), fl + Vector2(0, -22 * s)]), Color(acc, 0.8))

func _draw_lights(ci: Node2D, i: int) -> void:
	var fade = [0.55, 0.8, 1.0][i]
	for L in _lights[i]:
		var c: Color = L[2]
		Art.glow(ci, L[0], L[1] * 4.0, Color(c, 0.6 * fade), 5)
		ci.draw_circle(L[0], L[1] * 0.6, Art.hdr(c, 1.6 * fade))

func _draw_haze(ci: Node2D, i: int) -> void:
	var fog: Color = pal.fog
	var y = _layer_base(i) - 80.0
	var h = 220.0
	ci.draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(size.x, y), Vector2(size.x, y + h), Vector2(0, y + h)]),
		PackedColorArray([Color(fog, 0.0), Color(fog, 0.0), Color(fog, 0.30 - i * 0.08), Color(fog, 0.30 - i * 0.08)]))
	ci.draw_rect(Rect2(0, y + h, size.x, size.y), Color(fog, 0.30 - i * 0.08))

func _draw_shafts(ci: Node2D) -> void:
	if quality == 0:
		return
	var sp = Vector2(pal.sun_pos.x * size.x - cam_x * 0.004, pal.sun_pos.y * size.y - 200.0)
	var sc: Color = pal.sun
	for k in 7:
		var a = 1.85 + (k - 3) * 0.16 + sin(t * 0.13 + k * 1.7) * 0.03
		var len = size.y * 1.4
		var w0 = 20.0 + Art.hash01(k, 3) * 40.0
		var w1 = 180.0 + Art.hash01(k, 4) * 220.0
		var dir = Vector2(cos(a), sin(a))
		var nrm = Vector2(-dir.y, dir.x)
		var e = sp + dir * len
		var al = (0.025 + 0.015 * sin(t * 0.4 + k * 2.1)) * (1.0 + calm * 0.5)
		ci.draw_polygon(PackedVector2Array([sp + nrm * w0, sp - nrm * w0, e - nrm * w1, e + nrm * w1]),
			PackedColorArray([Color(sc, al), Color(sc, al), Color(sc, 0.0), Color(sc, 0.0)]))

func _draw_motes(ci: Node2D) -> void:
	var n = [10, 22, 32][quality]
	var mc: Color = pal.mote
	for i in n:
		var par = 0.25 + Art.hash01(i, 1) * 0.9
		var sx = fposmod(Art.hash01(i, 2) * size.x * 1.5 - cam_x * par + sin(t * 0.3 + i) * 30.0, size.x * 1.5) - size.x * 0.25
		var sy = fposmod(Art.hash01(i, 3) * size.y - t * (8.0 + Art.hash01(i, 4) * 20.0) + sin(t * 0.7 + i) * 20.0, size.y * 0.9)
		var r = 1.2 + Art.hash01(i, 5) * 3.0 * par
		var a = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 2.0 + i * 1.3))
		Art.glow(ci, Vector2(sx, sy), r * 5.0, Color(mc, 0.35 * a), 3)
		ci.draw_circle(Vector2(sx, sy), r * 0.6, Art.hdr(Color(mc, a), 1.8))

# ------------------------------------------------------------------ foreground
## Dark framing silhouettes drawn in front of gameplay (below the ground line
## and in the top corners only, so readability is never hurt).
func draw_foreground(ci: Node2D, gy: float) -> void:
	var off = cam_x * 1.55
	var col: Color = pal.ground.darkened(0.6)
	col.a = 0.96
	var cw = 900.0
	var c0 = int(floor((off - 400.0) / cw))
	var c1 = int(floor((off + size.x + 400.0) / cw))
	for c in range(c0, c1 + 1):
		var r = Art.hash01(c, 501)
		var sx = c * cw + r * 500.0 - off
		if r < 0.55:
			# leafy clump rising from below
			for k in 6:
				var a = -PI * 0.5 + (k - 2.5) * 0.28
				var base = Vector2(sx + k * 16.0, size.y + 40.0)
				var tip = base + Vector2(cos(a), sin(a)) * (150.0 + Art.hash01(c, k) * 140.0)
				var nrm = (tip - base).normalized().orthogonal() * 22.0
				ci.draw_colored_polygon(PackedVector2Array([base - nrm, (base + tip) * 0.5 - nrm * 1.6, tip, (base + tip) * 0.5 + nrm * 1.6, base + nrm]), col)
		elif false:
			# (disabled) hanging vine
			var x0 = sx
			var pts = PackedVector2Array()
			for k in 12:
				pts.append(Vector2(x0 + sin(k * 0.6 + t * 0.6 + c) * 12.0, -20.0 + k * 22.0))
			ci.draw_polyline(pts, col, 7.0, true)
			for k in range(2, 12, 2):
				ci.draw_colored_polygon(Art.ellipse(pts[k] + Vector2(10, 0), Vector2(18, 8), 10, 0.5), col)
