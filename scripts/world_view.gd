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

const LANDMARKS := ["bridge", "castle", "ring", "spire"]
const CLUSTER := ["pine", "cypress", "olive", "reed", "lily", "bush", "fern", "column", "rock", "birch"]

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
		for i in [30, 70, 120][Art.Q]:
			var sx = fmod(Art.hash01(i, 11) * w * 1.3 - cam_x * 0.01, w * 1.3) - w * 0.15
			if sx < 0.0: sx += w * 1.3
			var sy = Art.hash01(i, 23) * h * 0.55
			var tw = 0.55 + 0.45 * sin(t * (1.0 + Art.hash01(i, 5) * 2.0) + i)
			var a: float = pal.stars * tw * (1.0 - sy / (h * 0.6)) * 0.85
			var sr = 1.0 + Art.hash01(i, 7) * 1.8
			ci.draw_rect(Rect2(sx - sr * 0.5, sy - sr * 0.5, sr, sr), Color(0.9, 0.95, 1.0, a))

func _draw_sky_light(ci: Node2D) -> void:
	var w = size.x
	var h = size.y
	var sp: Vector2 = Vector2(pal.sun_pos.x * w - cam_x * 0.004, pal.sun_pos.y * h - cam_y * 0.02)
	var sc: Color = pal.sun
	var r: float = pal.sun_r
	# wide atmospheric halo
	Art.glow(ci, sp, r * 6.0, Color(sc, 0.30))
	Art.glow(ci, sp, r * 2.6, Color(sc, 0.30))
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
			var na = [10, 20, 40][Art.Q]
			for k in na + 1:
				var x = -40.0 + (w + 80.0) * k / float(na)
				var lx = x + cam_x * 0.02
				var y = base_y + sin(lx * 0.004 + t * 0.35 + band) * 50.0 + sin(lx * 0.011 - t * 0.6) * 18.0
				pts.append(Vector2(x, y))
			var ac = Color(0.3, 1.0, 0.75) if band != 1 else Color(0.75, 0.45, 1.0)
			for k in pts.size():
				var a = 0.5 + 0.5 * sin(k * 0.5 + t * 0.8 + band * 2.0)
				var p = pts[k]
				ci.draw_line(p, p + Vector2(0, 160 + band * 40), Color(ac, 0.045 * a * pal.aurora), 30.0)
				ci.draw_line(p, p + Vector2(0, 70), Color(ac, 0.06 * a * pal.aurora), 18.0)
			ci.draw_polyline(pts, Color(ac, 0.22 * pal.aurora), 2.0, Art.AA)
	# water shimmer under the horizon
	if pal.water > 0.01:
		var wy = size.y * BASE[0] + 6.0 - cam_y * 0.01
		for i in [12, 26, 46][Art.Q]:
			var yy = wy + pow(Art.hash01(i, 3), 1.6) * (h * 0.12)
			var spread = 40.0 + (yy - wy) * 2.2
			var cx = sp.x + (Art.hash01(i, 9) - 0.5) * spread * 2.0 + sin(t * 1.5 + i) * 10.0
			var ln = 10.0 + Art.hash01(i, 4) * 60.0
			ci.draw_line(Vector2(cx - ln, yy), Vector2(cx + ln, yy), Color(sc, 0.35 * pal.water * (0.5 + 0.5 * sin(t * 2.0 + i))), 2.0)

# ------------------------------------------------------------------ layers
func _layer_base(i: int) -> float:
	var drop = size.y * 0.06 * pal.water if i == 1 else 0.0  # opens a band of sea/river
	return size.y * BASE[i] - cam_y * PAR[i] * 0.25 + drop

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
		if r > DENS[i] * [0.55, 0.8, 1.0][Art.Q]:
			continue
		var kind: String = kinds[int(Art.hash01(c, 7 + i) * kinds.size()) % kinds.size()]
		# landmarks (bridge, castle, ring, spire) are rare so they never look tiled
		if LANDMARKS.has(kind) and Art.hash01(c, 211 + i) > 0.38:
			var alt: Array = kinds.filter(func(k): return not LANDMARKS.has(k))
			if alt.is_empty():
				continue
			kind = alt[int(Art.hash01(c, 223 + i) * alt.size()) % alt.size()]
		var lx = c * cw + Art.hash01(c, 13 + i) * cw * 0.7
		# small groves: trees and props often come in twos and threes
		var n := 1
		if CLUSTER.has(kind) and Art.Q >= 1:
			n += int(Art.hash01(c, 29 + i) < 0.45) + int(Art.hash01(c, 31 + i) < 0.18)
		for m in n:
			var seed: int = c * 7 + m * 131
			var mx = lx + (m * (46.0 + Art.hash01(seed, 37) * 60.0) * (1.0 if Art.hash01(c, 41) < 0.5 else -1.0)) * SCALE[i]
			var s: float = SCALE[i] * (0.62 + Art.hash01(seed, 19 + i) * 0.6) * (1.0 - m * 0.16)
			# per-instance depth tint: some props sit a little further back in the haze
			var fc: Color = col.lerp(pal.fog, Art.hash01(seed, 43) * 0.12)
			_feature(ci, i, kind, Vector2(mx - off, _ridge_y(i, mx) + 14.0), s, fc, seed)
	# aerial perspective: lighter, hazier at the ridge, deeper towards the bottom
	var top_c: Color = col.lerp(pal.fog, [0.20, 0.12, 0.06][i])
	var bot_c: Color = col.darkened([0.12, 0.18, 0.22][i])
	var cols = PackedColorArray()
	cols.resize(pts.size())
	cols.fill(top_c)
	cols[pts.size() - 1] = bot_c
	cols[pts.size() - 2] = bot_c
	ci.draw_polygon(pts, cols)
	# rim light along the ridge, facing the sun
	var rim: Color = pal.rim
	var rim_pts = pts.slice(0, pts.size() - 2)
	ci.draw_polyline(rim_pts, Color(rim, 0.05 + 0.05 * i), 1.5 + i * 0.5, Art.AA)

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
			ci.draw_polyline(ring, col.lightened(0.15), 4.0 * s, Art.AA)
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
			ci.draw_arc(c, R, 0.0, TAU, 48, col, 14.0 * s, Art.AA)
			ci.draw_arc(c, R - 9.0 * s, PI * 1.1, PI * 1.9, 20, Color(pal.rim, 0.35), 3.0 * s, Art.AA)
			L.append([c + Vector2(0, -R), 6.0 * s, acc])
			L.append([c, 3.0 * s, Color(acc, 0.5)])
		"column":
			var hh = (150.0 + Art.hash01(seed, 6) * 110.0) * s
			if Art.hash01(seed, 7) < 0.35:
				# broken column: shorter, slanted top, no capital
				hh *= 0.55
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-15 * s, 0), p + Vector2(-15 * s, -hh), p + Vector2(15 * s, -hh * 0.82), p + Vector2(15 * s, 0)]), col)
			else:
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
			var cyh = (100.0 + Art.hash01(seed, 2) * 80.0) * s
			var cyw = (20.0 + Art.hash01(seed, 3) * 12.0) * s
			ci.draw_colored_polygon(Art.ellipse(p + Vector2(0, -cyh), Vector2(cyw, cyh), 20), col)
		"pine":
			var ph = (220.0 + Art.hash01(seed, 2) * 230.0) * s
			var tiers := 4 + int(Art.hash01(seed, 8) * 3.0)
			var wf = 0.75 + Art.hash01(seed, 9) * 0.55
			var lean = (Art.hash01(seed, 10) - 0.5) * 0.12
			ci.draw_line(p, p + Vector2(lean * ph, -ph), col, 8.0 * s)
			for k in tiers:
				var f = float(k) / float(tiers)
				var yy = p.y - ph * (0.18 + 0.8 * f)
				var cx = p.x + lean * ph * (0.18 + 0.8 * f)
				var ww = (84.0 - 62.0 * f) * s * wf * (0.9 + Art.hash01(seed, 50 + k) * 0.25)
				var dip = (10.0 + Art.hash01(seed, 60 + k) * 18.0) * s
				ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - ww, yy + 26 * s + dip), Vector2(cx - ww * 0.45, yy + 22 * s), Vector2(cx, yy - ph * 0.24), Vector2(cx + ww * 0.45, yy + 22 * s), Vector2(cx + ww, yy + 26 * s + dip * 0.6)]), col)
		"birch":
			var bh = (200.0 + Art.hash01(seed, 2) * 140.0) * s
			ci.draw_line(p, p + Vector2(6 * s, -bh), col, 6.0 * s)
			for k in 5:
				var a = float(k) / 5.0 * TAU + Art.hash01(seed, 3)
				ci.draw_circle(p + Vector2(6 * s + cos(a) * 34 * s, -bh + sin(a) * 30 * s), (24.0 + Art.hash01(seed, 20 + k) * 14.0) * s, col)
		"bush":
			var bw = (50.0 + Art.hash01(seed, 2) * 50.0) * s
			var nb := 3 + int(Art.hash01(seed, 3) * 3.0)
			for k in nb:
				var f = (float(k) / float(nb - 1)) - 0.5
				var rr = bw * (0.42 + Art.hash01(seed, 10 + k) * 0.3) * (1.0 - absf(f) * 0.6)
				ci.draw_circle(p + Vector2(f * bw * 1.6, -rr * 0.7), rr, col)
			if Art.hash01(seed, 9) < 0.35:
				L.append([p + Vector2((Art.hash01(seed, 11) - 0.5) * bw, -bw * 0.5), 3.0 * s, Art.hdr(pal.mote, 1.0)])
		"rock":
			var rw = (40.0 + Art.hash01(seed, 2) * 70.0) * s
			var rh = rw * (0.45 + Art.hash01(seed, 3) * 0.5)
			var pts := PackedVector2Array()
			for k in 7:
				var a = PI + PI * float(k) / 6.0
				pts.append(p + Vector2(cos(a) * rw, sin(a) * rh * (0.75 + Art.hash01(seed, 20 + k) * 0.4) + 10 * s))
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(pts.slice(1, 4), Color(pal.rim, 0.25), 2.0, Art.AA)
		"house":
			var hw = (60.0 + Art.hash01(seed, 2) * 40.0) * s
			var hh = (50.0 + Art.hash01(seed, 3) * 40.0) * s
			var flip = 1.0 if Art.hash01(seed, 4) < 0.5 else -1.0
			ci.draw_rect(Rect2(p.x - hw * 0.5, p.y - hh, hw, hh + 20 * s), col)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-hw * 0.65, -hh), p + Vector2(0, -hh - hw * 0.55), p + Vector2(hw * 0.65, -hh)]), col)
			ci.draw_rect(Rect2(p.x + flip * hw * 0.18 - 5 * s, p.y - hh - hw * 0.5, 10 * s, 26 * s), col)
			if Art.hash01(seed, 5) < 0.7:
				L.append([p + Vector2(-flip * hw * 0.18, -hh * 0.55), 5.0 * s, Art.hdr(pal.mote, 1.1)])
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
			# Tied-arch bridge: the arch springs from the deck, hangers hold the
			# deck, and piers/towers go down into the hill (bases hidden by the
			# ridge fill drawn after features), so nothing floats.
			var bl = 700.0 * s
			var deck = p.y - 150.0 * s
			var rise = 190.0 * s
			var x0 = p.x - bl * 0.5
			var arc = PackedVector2Array()
			for k in 25:
				var f = float(k) / 24.0
				arc.append(Vector2(x0 + bl * f, deck - sin(f * PI) * rise))
			for px in [x0, x0 + bl * 0.34, x0 + bl * 0.66, x0 + bl]:
				ci.draw_rect(Rect2(px - 11.0 * s, deck, 22.0 * s, 420.0 * s), col)
				ci.draw_rect(Rect2(px - 16.0 * s, deck + 4.0 * s, 32.0 * s, 10.0 * s), col)
			for ex in [x0, x0 + bl]:
				ci.draw_rect(Rect2(ex - 15.0 * s, deck - 70.0 * s, 30.0 * s, 70.0 * s), col)
				L.append([Vector2(ex, deck - 78.0 * s), 4.0 * s, acc])
			ci.draw_line(Vector2(x0 - 30.0 * s, deck), Vector2(x0 + bl + 30.0 * s, deck), col, 14.0 * s)
			ci.draw_polyline(arc, col, 9.0 * s, Art.AA)
			for k in range(2, 23, 2):
				var q: Vector2 = arc[k]
				ci.draw_line(q, Vector2(q.x, deck), col, 2.0)
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
			var nr := 3 + int(Art.hash01(seed, 21) * 6.0)
			var lean = (Art.hash01(seed, 22) - 0.5) * 14.0
			for k in nr:
				var bx = p.x + (k - nr * 0.5) * (6.0 + Art.hash01(seed, 30 + k) * 8.0) * s
				var hh = (50.0 + Art.hash01(seed, k) * 90.0) * s
				var sway = sin(t * 1.2 + k + seed) * 6.0 + lean
				ci.draw_line(Vector2(bx, p.y), Vector2(bx + sway, p.y - hh), col, 3.0 * s)
				if Art.hash01(seed, 40 + k) < 0.6:
					ci.draw_colored_polygon(Art.ellipse(Vector2(bx + sway, p.y - hh), Vector2(4 * s, 13 * s), 10), col)
				else:
					ci.draw_line(Vector2(bx + sway, p.y - hh), Vector2(bx + sway * 1.8 + 14 * s, p.y - hh * 0.7), col, 2.0 * s)
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

## Sea (Greece) / river (Danube) between the far hills and the middle layer,
## with the sun's reflection column and drifting glints.
func _draw_water(ci: Node2D) -> void:
	var w = size.x
	var y0 = _layer_base(0) - 6.0
	var y1 = size.y
	var hor: Color = pal.sky[2]
	var sc: Color = pal.sun
	var near: Color = pal.layers[1].lerp(pal.sky[1], 0.35)
	var top_c: Color = hor.lerp(sc, 0.25)
	var mid_c: Color = hor.lerp(near, 0.55)
	ci.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w, y0 + 90.0), Vector2(0, y0 + 90.0)]),
		PackedColorArray([top_c, top_c, mid_c, mid_c]))
	ci.draw_rect(Rect2(0, y0 + 90.0, w, y1 - y0), mid_c)
	ci.draw_line(Vector2(0, y0 + 1.0), Vector2(w, y0 + 1.0), Color(sc.lightened(0.3), 0.55), 2.0)
	var sx: float = pal.sun_pos.x * w - cam_x * 0.004
	var a: float = 0.55 * pal.water
	ci.draw_polygon(PackedVector2Array([Vector2(sx - 70, y0), Vector2(sx + 70, y0), Vector2(sx + 150, y0 + 140), Vector2(sx - 150, y0 + 140)]),
		PackedColorArray([Color(sc, a), Color(sc, a), Color(sc, 0.0), Color(sc, 0.0)]))
	for i in [10, 22, 40][Art.Q]:
		var yy = y0 + 4.0 + pow(Art.hash01(i, 3), 1.5) * 120.0
		var spread = 30.0 + (yy - y0) * 1.8
		var cx = sx + (Art.hash01(i, 9) - 0.5) * spread * 2.0 + sin(t * 1.3 + i) * 8.0
		var ln = 8.0 + Art.hash01(i, 4) * 46.0 * (0.4 + (yy - y0) / 120.0)
		var al = (0.35 + 0.35 * sin(t * 2.2 + i * 1.7)) * pal.water
		ci.draw_line(Vector2(cx - ln, yy), Vector2(cx + ln, yy), Color(sc.lightened(0.4), al), 2.0)
	# slow ripple lines across the whole surface
	for k in 4:
		var yy = y0 + 18.0 + k * 26.0
		var off = fposmod(-cam_x * (0.08 + k * 0.03) + k * 211.0, 260.0)
		var x = off - 260.0
		while x < w:
			ci.draw_line(Vector2(x, yy), Vector2(x + 60.0 + k * 20.0, yy), Color(hor.lightened(0.2), 0.10), 1.5)
			x += 260.0

func _draw_haze(ci: Node2D, i: int) -> void:
	if i == 0 and pal.water > 0.01:
		_draw_water(ci)
	var fog: Color = pal.fog
	var y = _layer_base(i) - 80.0
	var h = 220.0
	ci.draw_polygon(PackedVector2Array([Vector2(0, y), Vector2(size.x, y), Vector2(size.x, y + h), Vector2(0, y + h)]),
		PackedColorArray([Color(fog, 0.0), Color(fog, 0.0), Color(fog, 0.30 - i * 0.08), Color(fog, 0.30 - i * 0.08)]))
	ci.draw_rect(Rect2(0, y + h, size.x, size.y), Color(fog, 0.30 - i * 0.08))

func _draw_shafts(ci: Node2D) -> void:
	if Art.Q == 0:
		return
	# rays start at the sun/moon disc itself (same position as _draw_sky_light)
	var c0 = Vector2(pal.sun_pos.x * size.x - cam_x * 0.004, pal.sun_pos.y * size.y - cam_y * 0.02)
	var sc: Color = pal.sun
	var r0: float = pal.sun_r * 0.35
	for k in 7:
		var a = 1.80 + (k - 3) * 0.20 + sin(t * 0.13 + k * 1.7) * 0.03
		var len = size.y * 1.4
		var w0 = 6.0 + Art.hash01(k, 3) * 14.0
		var w1 = 180.0 + Art.hash01(k, 4) * 220.0
		var dir = Vector2(cos(a), sin(a))
		var nrm = Vector2(-dir.y, dir.x)
		var sp = c0 + dir * r0
		var e = sp + dir * len
		var al = (0.025 + 0.015 * sin(t * 0.4 + k * 2.1)) * (1.0 + calm * 0.5)
		ci.draw_polygon(PackedVector2Array([sp + nrm * w0, sp - nrm * w0, e - nrm * w1, e + nrm * w1]),
			PackedColorArray([Color(sc, al), Color(sc, al), Color(sc, 0.0), Color(sc, 0.0)]))

func _draw_motes(ci: Node2D) -> void:
	var n = [8, 18, 30][Art.Q]
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
			# leafy clump rising from below: leaf count, fan, length and width vary per clump
			var nl := 3 + int(Art.hash01(c, 502) * 5.0)
			var fan = 0.18 + Art.hash01(c, 503) * 0.2
			var tall = 0.6 + Art.hash01(c, 504) * 0.7
			var lw = 14.0 + Art.hash01(c, 505) * 14.0
			var sway = sin(t * 0.9 + c) * 0.03
			for k in nl:
				var a = -PI * 0.5 + (k - (nl - 1) * 0.5) * fan + sway + (Art.hash01(c, 520 + k) - 0.5) * 0.15
				var base = Vector2(sx + k * 14.0, size.y + 40.0)
				var tip = base + Vector2(cos(a), sin(a)) * (110.0 + Art.hash01(c, k) * 150.0) * tall
				var nrm = (tip - base).normalized().orthogonal() * lw
				ci.draw_colored_polygon(PackedVector2Array([base - nrm, (base + tip) * 0.5 - nrm * 1.6, tip, (base + tip) * 0.5 + nrm * 1.6, base + nrm]), col)
		elif false:
			# (disabled) hanging vine
			var x0 = sx
			var pts = PackedVector2Array()
			for k in 12:
				pts.append(Vector2(x0 + sin(k * 0.6 + t * 0.6 + c) * 12.0, -20.0 + k * 22.0))
			ci.draw_polyline(pts, col, 7.0, Art.AA)
			for k in range(2, 12, 2):
				ci.draw_colored_polygon(Art.ellipse(pts[k] + Vector2(10, 0), Vector2(18, 8), 10, 0.5), col)
