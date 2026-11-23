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
var hero_x = -9999.0 # Kavi on screen: background people fade out behind him

const PAR := [0.06, 0.16, 0.36]
const BASE := [0.62, 0.71, 0.80]
const CELL := [560.0, 400.0, 300.0]
const DENS := [0.55, 0.65, 0.7]
const SCALE := [0.75, 0.9, 1.05]

const LANDMARKS := ["bridge", "castle", "ring", "spire", "lighthouse"]
const CLUSTER := ["pine", "cypress", "olive", "reed", "lily", "bush", "fern", "column", "rock", "birch", "windmill"]

var _lights: Array = [[], [], []]
var _beams: Array = [[], [], []]  # lighthouse lamps: slow sweeping beams
var _painters: Array = []

func _ready() -> void:
	var order = [
		[_draw_sky, false, "sky"], [_draw_sky_light, true, "sky_light"],
		[_draw_layer.bind(0), false, "layer0"], [_draw_lights.bind(0), true, "lights0"], [_draw_haze.bind(0), false, "haze0"],
		[_draw_layer.bind(1), false, "layer1"], [_draw_lights.bind(1), true, "lights1"], [_draw_shafts, true, "shafts"], [_draw_haze.bind(1), false, "haze1"],
		[_draw_layer.bind(2), false, "layer2"], [_draw_lights.bind(2), true, "lights2"], [_draw_motes, true, "motes"],
	]
	for o in order:
		var p = Painter.new()
		p.fn = o[0]
		p.tag = o[2]
		if o[1]:
			var m = CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			p.material = m
			p.modulate = Color(1, 1, 1, 0.6)
		add_child(p)
		_painters.append(p)

# ------------------------------------------------------------------ world transitions
## A new country sweeps in from the right: each layer has a seam that moves left
## with its parallax (at least SWEEP px/s). Right of the seam is the new world,
## left the old; props dissolve in a soft band around it, colours blend across it.
var tr_from: Dictionary = {}
var tr_to: Dictionary = {}
var tr_t0 := 0.0
var tr_c0 := 0.0
const SWEEP := 170.0
const BAND := 280.0

func begin_transition(from: Dictionary, to: Dictionary) -> void:
	tr_from = from
	tr_to = to
	tr_t0 = t
	tr_c0 = cam_x

func end_transition() -> void:
	tr_from = {}

func _seam(par: float) -> float:
	return size.x + BAND + 40.0 - maxf((cam_x - tr_c0) * par, (t - tr_t0) * SWEEP)

## 0 = old world, 1 = new world at screen x for a layer with this parallax.
func _mix(par: float, sx: float) -> float:
	if tr_from.is_empty():
		return 1.0
	return smoothstep(_seam(par) - BAND, _seam(par) + BAND, sx)

func _side(w: float) -> Dictionary:
	if tr_from.is_empty():
		return pal
	return tr_to if w >= 0.5 else tr_from

func _update_transition() -> void:
	if not tr_from.is_empty() and _seam(0.04) < -BAND - 300.0:
		tr_from = {}

## How much of the sun/moon disc is above the hills (0 hidden .. 1 clear).
## Light shafts, the water reflection and the rim glow all follow it.
var sun_vis := 1.0
var _peaks: Array = [] # screen-space mountain triangles that can hide the sun

func _peak_y(x: float) -> float:
	var y := INF
	for pk in _peaks:
		var l: float = pk[0]
		var tx: float = pk[1]
		var r: float = pk[3]
		if x > l and x < r:
			var f := (x - l) / (tx - l) if x <= tx else (r - x) / (r - tx)
			y = minf(y, lerpf(pk[4], pk[2], f))
	return y

## The dominant sun/moon (during a transition: whichever is brighter).
func _sun_screen() -> Vector2:
	if tr_from.is_empty():
		return _sun_at(pal, 0.0)
	var k := _sky_k()
	var e := k * k * (3.0 - 2.0 * k)
	return _sun_at(tr_from, e * 120.0) if e < 0.5 else _sun_at(tr_to, (1.0 - e) * 120.0)

func _update_sun_vis() -> void:
	var sp := _sun_screen()
	var r: float = pal.sun_r * 0.45
	var v := 0.0
	# sample three points across the disc; each counts for a third
	for dx in [-0.6, 0.0, 0.6]:
		var top := INF
		for i in 2:
			top = minf(top, _ridge_y(i, sp.x + dx * r + cam_x * PAR[i]))
		top = minf(top, _peak_y(sp.x + dx * r))
		v += clampf((top - (sp.y - r)) / (2.0 * r), 0.0, 1.0) / 3.0
	sun_vis = lerpf(sun_vis, v, 0.25)

func refresh() -> void:
	size = get_viewport_rect().size
	_update_transition()
	_update_sun_vis()
	for p in _painters:
		p.queue_redraw()

# ------------------------------------------------------------------ batching
## Many tiny leaves as ONE draw call: collect triangles, then flush.
var _bv := PackedVector2Array()
var _bi := PackedInt32Array()

func _b_quad(a: Vector2, b: Vector2, w0: float, w1: float) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var n := d.normalized().orthogonal()
	var i := _bv.size()
	_bv.append_array([a + n * w0, a - n * w0, b - n * w1, b + n * w1])
	_bi.append_array([i, i + 1, i + 2, i, i + 2, i + 3])

func _b_leaf(c: Vector2, rx: float, ry: float, rot: float) -> void:
	# a 6-point leaf (diamond-ish ellipse) as 4 triangles
	var i := _bv.size()
	var ax := Vector2(cos(rot), sin(rot))
	var ay := ax.orthogonal()
	_bv.append_array([c + ax * rx, c + ax * rx * 0.4 + ay * ry, c - ax * rx * 0.4 + ay * ry, c - ax * rx, c - ax * rx * 0.4 - ay * ry, c + ax * rx * 0.4 - ay * ry])
	_bi.append_array([i, i + 1, i + 2, i, i + 2, i + 3, i, i + 3, i + 4, i, i + 4, i + 5])

func _b_flush(ci: Node2D, col: Color) -> void:
	if _bi.size() > 0:
		var cols := PackedColorArray()
		cols.resize(_bv.size())
		cols.fill(col)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _bi, _bv, cols)
	_bv.clear()
	_bi.clear()

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
	_draw_air(ci)

## 0..1 progress of the sky part of a world transition (old sun sets, new rises).
func _sky_k() -> float:
	return 1.0 if tr_from.is_empty() else clampf((t - tr_t0) / 7.0, 0.0, 1.0)

## Clickable sky and sea (0.8.13): balloons hop and wave, the plane draws a
## smoke heart, ships toot, birds scatter. Hit rects are rebuilt every draw in
## screen space; reactions are keyed by object and read back while drawing.
var interactive := false
var _hits_air: Array = []
var _hits_sea: Array = []
var pokes: Dictionary = {}
var sky_fx: Array = []   # {kind, p, v, t0, life, layer}

func poke(pos: Vector2, quiet := false) -> String:
	if not interactive:
		return ""
	for list in [_hits_air, _hits_sea]:
		for i in range(list.size() - 1, -1, -1):
			var h: Dictionary = list[i]
			if not (h.rect as Rect2).grow(16.0).has_point(pos):
				continue
			var key: String = h.key
			var pk: Dictionary = pokes.get(key, {})
			if quiet and pk.has("t0") and t - float(pk.t0) < 1.6:
				return ""
			if h.kind == "plane" and pk.has("t0") and t - float(pk.t0) < 3.2:
				return ""
			var n := 1
			if pk.has("last") and t - float(pk.last) < 1.2:
				n = int(pk.n) + 1
			pk = {"t0": t, "last": t, "n": n, "rocket": pk.get("rocket", -99.0)}
			var kind: String = h.kind
			if kind == "balloon":
				var bot: Vector2 = h.basket
				sky_fx.append({"kind": "heart", "p": bot + Vector2(0, -6), "v": Vector2(randf_range(-12, 12), -70), "t0": t, "life": 1.6, "layer": "air"})
				if n >= 3 and t - float(pk.rocket) > 12.0:
					pk.rocket = t
					kind = "balloon_rocket"
			elif kind == "ship":
				var top: Vector2 = h.top
				for q in 3:
					sky_fx.append({"kind": "puff", "p": top + Vector2(0, -q * 6), "v": Vector2(-14, -34 - q * 12), "t0": t + q * 0.18, "life": 1.8, "layer": "sea"})
				sky_fx.append({"kind": "note", "p": top + Vector2(14, -10), "v": Vector2(18, -46), "t0": t, "life": 2.0, "layer": "sea"})
			elif kind == "plane":
				pk.emit = 0.0
			pokes[key] = pk
			return kind
	return ""

static func _heart(u: float) -> Vector2:
	return Vector2(16.0 * pow(sin(u), 3.0), -(13.0 * cos(u) - 5.0 * cos(2.0 * u) - 2.0 * cos(3.0 * u) - cos(4.0 * u)))

func hover_hit(pos: Vector2) -> bool:
	if not interactive:
		return false
	for list in [_hits_air, _hits_sea]:
		for h in list:
			if (h.rect as Rect2).grow(16.0).has_point(pos):
				return true
	return false

func _age(key: String) -> float:
	var pk: Dictionary = pokes.get(key, {})
	return t - float(pk.t0) if pk.has("t0") else 999.0

func _draw_sky_fx(ci: Node2D, layer: String) -> void:
	var keep: Array = []
	for f in sky_fx:
		var a: float = t - float(f.t0)
		if a > float(f.life):
			continue
		keep.append(f)
		if f.layer != layer or a < 0.0:
			continue
		var k: float = a / float(f.life)
		var p: Vector2 = f.p + f.v * a
		match f.kind:
			"heart":
				p.x += sin(a * 5.0) * 6.0
				var hc := Color(1.0, 0.55, 0.72, (1.0 - k) * 0.95)
				var r := 6.0 + 3.0 * minf(a * 4.0, 1.0)
				ci.draw_circle(p + Vector2(-r * 0.5, 0), r * 0.62, hc)
				ci.draw_circle(p + Vector2(r * 0.5, 0), r * 0.62, hc)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.08, r * 0.2), p + Vector2(r * 1.08, r * 0.2), p + Vector2(0, r * 1.3)]), hc)
			"puff":
				ci.draw_circle(p, 7.0 + 16.0 * k, Color(1, 1, 1, 0.42 * (1.0 - k)))
			"smoke":
				ci.draw_circle(p, 4.0 + 5.0 * k, Color(1, 0.97, 0.95, 0.75 * (1.0 - k * k)))
			"note":
				p.x += sin(a * 6.0) * 5.0
				var nc := Color(1.0, 0.92, 0.7, 1.0 - k)
				ci.draw_circle(p, 4.5, nc)
				ci.draw_line(p + Vector2(4, 0), p + Vector2(4, -16), nc, 2.0)
				ci.draw_line(p + Vector2(4, -16), p + Vector2(11, -11), nc, 2.0)
	sky_fx = keep

var sun_shift := 0.0 # title screen: the sun sets behind Kavi, away from the menu

func _sun_at(P: Dictionary, sink: float) -> Vector2:
	return Vector2(P.sun_pos.x * size.x - cam_x * 0.004 + sun_shift, P.sun_pos.y * size.y - cam_y * 0.02 + sink)

func _draw_sun(ci: Node2D, sp: Vector2, sc: Color, r: float, a: float) -> void:
	if a < 0.01:
		return
	# wide atmospheric halo
	Art.glow(ci, sp, r * 6.0, Color(sc, 0.30 * a))
	Art.glow(ci, sp, r * 2.6, Color(sc, 0.30 * a))
	ci.draw_circle(sp, r * 0.62, Color(sc, 0.35 * a))
	ci.draw_circle(sp, r * 0.44, Color(Art.hdr(sc, 1.05), a))
	ci.draw_circle(sp, r * 0.30, Color(Art.hdr(sc.lerp(Color(1, 1, 1), 0.6), 1.25), a))

func _draw_sky_light(ci: Node2D) -> void:
	var w = size.x
	var h = size.y
	var sp: Vector2 = _sun_screen()
	var sc: Color = pal.sun
	var r: float = pal.sun_r
	if tr_from.is_empty():
		_draw_sun(ci, sp, sc, r, 1.0)
	else:
		# the old sun/moon sinks and fades, the new one rises into place
		var k := _sky_k()
		var e := k * k * (3.0 - 2.0 * k)
		_draw_sun(ci, _sun_at(tr_from, e * 120.0), tr_from.sun, tr_from.sun_r, 1.0 - e)
		_draw_sun(ci, _sun_at(tr_to, (1.0 - e) * 120.0), tr_to.sun, tr_to.sun_r, e)
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
	if i == 0:
		var w := _mix(PAR[0], lx - cam_x * PAR[0])
		var a_new: float = 150.0 if _side(1.0).kinds[0].has("peak") else amp
		var a_old: float = 150.0 if _side(0.0).kinds[0].has("peak") else amp
		amp = lerpf(a_old, a_new, w)
	return _layer_base(i) - Art.ridge(lx, 3.1 + i * 7.7, amp, fr) - amp * 0.6

func _draw_layer(ci: Node2D, i: int) -> void:
	_lights[i] = []
	_beams[i] = []
	if i == 0:
		_peaks = []
	var col: Color = pal.layers[i]
	var par: float = PAR[i]
	var off = cam_x * par
	var pts = PackedVector2Array()
	var x = -60.0
	while x <= size.x + 60.0:
		pts.append(Vector2(x, _ridge_y(i, x + off)))
		x += 24.0
	# features behind the ridge fill so their bases are hidden
	var cw: float = CELL[i]
	var c0 = int(floor((off - 700.0) / cw))
	var c1 = int(floor((off + size.x + 700.0) / cw))
	for c in range(c0, c1 + 1):
		var r = Art.hash01(c, 101 + i * 31)
		if r > DENS[i] * [0.55, 0.8, 1.0][Art.Q]:
			continue
		var lx = c * cw + Art.hash01(c, 13 + i) * cw * 0.7
		var w := _mix(par, lx - off)
		var side := _side(w)
		var fade := 1.0 if tr_from.is_empty() else absf(w - 0.5) * 2.0
		if fade < 0.03:
			continue
		var kinds: Array = side.kinds[i]
		var lcol: Color = _side(0.0).layers[i].lerp(_side(1.0).layers[i], w)
		var kind: String = kinds[int(Art.hash01(c, 7 + i) * kinds.size()) % kinds.size()]
		# landmarks (bridge, castle, ring, spire) are rare so they never look tiled
		if LANDMARKS.has(kind) and Art.hash01(c, 211 + i) > 0.38:
			var alt: Array = kinds.filter(func(k): return not LANDMARKS.has(k))
			if alt.is_empty():
				continue
			kind = alt[int(Art.hash01(c, 223 + i) * alt.size()) % alt.size()]
		# small groves: trees and props often come in twos and threes
		var n := 1
		if CLUSTER.has(kind) and Art.Q >= 1:
			n += int(Art.hash01(c, 29 + i) < 0.45) + int(Art.hash01(c, 31 + i) < 0.18)
		var nl: int = _lights[i].size()
		for m in n:
			var seed: int = c * 7 + m * 131
			var mx = lx + (m * (46.0 + Art.hash01(seed, 37) * 60.0) * (1.0 if Art.hash01(c, 41) < 0.5 else -1.0)) * SCALE[i]
			var s: float = SCALE[i] * (0.62 + Art.hash01(seed, 19 + i) * 0.6) * (1.0 - m * 0.16)
			# per-instance depth tint: some props sit a little further back in the haze
			var fc: Color = lcol.lerp(pal.fog, Art.hash01(seed, 43) * 0.12)
			fc.a = fade
			_feature(ci, i, kind, Vector2(mx - off, _ridge_y(i, mx) + 14.0), s, fc, seed)
		for li in range(nl, _lights[i].size()):
			_lights[i][li][2] = Color(_lights[i][li][2], _lights[i][li][2].a * fade)
	if i == 0:
		_draw_town(ci, off, col)
	elif i == 2 and Art.Q >= 1:
		_draw_life(ci, off, col)
	# aerial perspective: lighter, hazier at the ridge, deeper towards the bottom.
	# Drawn as a strip so the colour can change across a world transition.
	var lift: float = [0.20, 0.12, 0.06][i]
	var deep: float = [0.12, 0.18, 0.22][i]
	if tr_from.is_empty():
		# fast path (no transition): one polygon, as before
		var poly := pts.duplicate()
		poly.append(Vector2(size.x + 60.0, size.y + 10.0))
		poly.append(Vector2(-60.0, size.y + 10.0))
		var pc := PackedColorArray()
		pc.resize(poly.size())
		pc.fill(col.lerp(pal.fog, lift))
		pc[poly.size() - 1] = col.darkened(deep)
		pc[poly.size() - 2] = col.darkened(deep)
		ci.draw_polygon(poly, pc)
		_draw_rims(ci, i, pts)
		return
	var verts := PackedVector2Array()
	var vcols := PackedColorArray()
	var idx := PackedInt32Array()
	var c_old: Color = _side(0.0).layers[i]
	var c_new: Color = _side(1.0).layers[i]
	for k in pts.size():
		var q: Vector2 = pts[k]
		var lc: Color = c_old.lerp(c_new, _mix(par, q.x))
		verts.append(q)
		verts.append(Vector2(q.x, size.y + 10.0))
		vcols.append(lc.lerp(pal.fog, lift))
		vcols.append(lc.darkened(deep))
		if k > 0:
			var b0 := (k - 1) * 2
			idx.append_array([b0, b0 + 1, b0 + 2, b0 + 1, b0 + 3, b0 + 2])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), idx, verts, vcols)
	_draw_rims(ci, i, pts)

func _draw_rims(ci: Node2D, i: int, rim_pts: PackedVector2Array) -> void:
	# rim light along the ridge, facing the sun
	var rim: Color = pal.rim
	ci.draw_polyline(rim_pts, Color(rim, 0.05 + 0.05 * i), 1.5 + i * 0.5, Art.AA)
	# silver lining: the ridge right in front of a low sun/moon catches its light
	if i < 2:
		var sp := _sun_screen()
		var reach: float = pal.sun_r * 2.6
		var seg := PackedVector2Array()
		var segc := PackedColorArray()
		for q in rim_pts:
			var dxs = absf(q.x - sp.x)
			var dys = q.y - sp.y
			if dxs < reach and dys > -pal.sun_r * 1.2 and dys < pal.sun_r * 1.6:
				seg.append(q)
				var k = (1.0 - dxs / reach) * (1.0 - clampf(absf(dys) / (pal.sun_r * 1.6), 0.0, 1.0))
				segc.append(Color(Art.hdr(pal.sun, 1.4), k * (1.0 - sun_vis * 0.6) * (0.9 if i == 0 else 0.6)))
		if seg.size() >= 2:
			ci.draw_polyline_colors(seg, segc, 2.5, Art.AA)

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
		"temple":
			# Greek temple: stepped base, columns, beam and pediment
			var tw = (150.0 + Art.hash01(seed, 2) * 70.0) * s
			var th = (80.0 + Art.hash01(seed, 3) * 30.0) * s
			var nc := 5 + int(Art.hash01(seed, 4) * 3.0)
			var x0 = p.x - tw * 0.5
			ci.draw_rect(Rect2(x0 - 10 * s, p.y - 8 * s, tw + 20 * s, 30 * s), col)
			ci.draw_rect(Rect2(x0 - 4 * s, p.y - 15 * s, tw + 8 * s, 8 * s), col)
			var cw2 = tw / (nc * 1.9)
			for k in nc:
				var cx = x0 + cw2 * 0.5 + k * (tw - cw2) / float(nc - 1)
				ci.draw_rect(Rect2(cx - cw2 * 0.5, p.y - 15 * s - th, cw2, th), col)
				ci.draw_rect(Rect2(cx - cw2 * 0.75, p.y - 15 * s - th - 5 * s, cw2 * 1.5, 6 * s), col)
			var top = p.y - 20 * s - th
			ci.draw_rect(Rect2(x0 - 4 * s, top - 14 * s, tw + 8 * s, 15 * s), col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 - 8 * s, top - 13 * s), Vector2(p.x, top - 13 * s - tw * 0.2), Vector2(x0 + tw + 8 * s, top - 13 * s)]), col)
			ci.draw_line(Vector2(x0 - 8 * s, top - 13 * s), Vector2(p.x, top - 13 * s - tw * 0.2), Color(pal.rim, 0.35), 2.0, Art.AA)
			if Art.hash01(seed, 9) < 0.5:
				L.append([Vector2(p.x, top - 22 * s), 4.0 * s, Art.hdr(pal.mote, 1.0)])
		"lighthouse":
			var lh = (300.0 + Art.hash01(seed, 2) * 80.0) * s
			var b0 = 34.0 * s
			var b1 = 20.0 * s
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-b0, 20), p + Vector2(-b1, -lh), p + Vector2(b1, -lh), p + Vector2(b0, 20)]), col)
			for k in 3:
				var yy = -lh * (0.25 + k * 0.25)
				var ww = lerpf(b0, b1, (0.25 + k * 0.25)) + 1.0
				ci.draw_rect(Rect2(p.x - ww, p.y + yy, ww * 2.0, 14 * s), col.lightened(0.10))
			ci.draw_rect(Rect2(p.x - b1 - 8 * s, p.y - lh - 6 * s, (b1 + 8 * s) * 2.0, 7 * s), col)
			ci.draw_rect(Rect2(p.x - 12 * s, p.y - lh - 30 * s, 24 * s, 24 * s), col.lightened(0.05))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-16 * s, -lh - 30 * s), p + Vector2(0, -lh - 50 * s), p + Vector2(16 * s, -lh - 30 * s)]), col)
			var lamp = p + Vector2(0, -lh - 18 * s)
			L.append([lamp, 9.0 * s, Art.hdr(Color(1.0, 0.92, 0.7), 1.6)])
			_beams[layer].append([lamp, s])
		"windmill":
			var mh = (110.0 + Art.hash01(seed, 2) * 40.0) * s
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-26 * s, 20), p + Vector2(-20 * s, -mh), p + Vector2(20 * s, -mh), p + Vector2(26 * s, 20)]), col)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-24 * s, -mh), p + Vector2(0, -mh - 30 * s), p + Vector2(24 * s, -mh)]), col)
			var hub = p + Vector2(0, -mh - 6 * s)
			var rot = t * (0.35 + Art.hash01(seed, 5) * 0.3) + seed
			for k in 6:
				var a = rot + TAU * k / 6.0
				var tip = hub + Vector2(cos(a), sin(a)) * 70.0 * s
				var side = Vector2(cos(a + PI * 0.5), sin(a + PI * 0.5)) * 9.0 * s
				ci.draw_line(hub, tip, col, 2.5 * s)
				ci.draw_colored_polygon(PackedVector2Array([hub.lerp(tip, 0.3), tip, tip + side, hub.lerp(tip, 0.3) + side]), Color(col.lightened(0.18), col.a * 0.9))
			if Art.hash01(seed, 7) < 0.6:
				L.append([p + Vector2(0, -mh * 0.45), 4.0 * s, Art.hdr(pal.mote, 1.0)])
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
			if layer < 2:
				_peaks.append([p.x - pw, top.x, top.y, p.x + pw, p.y + 60.0])
			ci.draw_line(top, top.lerp(p + Vector2(pw, 60), 0.35), Color(pal.rim, 0.45), 3.0)
		"lantern":
			var bob = sin(t * 1.3 + seed) * 12.0
			var lp = p + Vector2(0, -(120.0 + Art.hash01(seed, 2) * 160.0) * s + bob)
			ci.draw_circle(lp, 7.0 * s, col.lightened(0.2))
			L.append([lp, 10.0 * s, Art.hdr(acc, 1.3)])
		"fern":
			# arching fronds with paired leaflets that shrink towards the tip
			var nf := 5 + int(Art.hash01(seed, 3) * 3.0)
			for k in nf:
				var f = (float(k) / float(nf - 1)) - 0.5
				var a = -PI * 0.5 + f * 1.9
				var dir = Vector2(cos(a), sin(a))
				var L0 = (70.0 + Art.hash01(seed, 10 + k) * 40.0) * s * (1.0 - absf(f) * 0.35)
				var bend = Vector2(f * 46.0 * s, 0) + Vector2(0, 28.0 * s * absf(f))
				var sway = Vector2(sin(t * 0.9 + seed + k) * 3.0 * s, 0)
				var prev = p
				var steps := 8 if Art.Q >= 2 else 5
				for j in range(1, steps + 1):
					var u = float(j) / steps
					var q = p + dir * L0 * u + bend * u * u + sway * u
					var d = (q - prev).normalized()
					var nrm = d.orthogonal()
					var lw = (1.0 - u) * 10.0 * s + 2.0 * s
					_b_quad(prev, q, maxf(1.5 * s * (1.0 - u), 0.6), maxf(1.5 * s * (1.0 - u), 0.6))
					_b_leaf(q + nrm * lw * 0.7, lw, lw * 0.38, nrm.angle() - 0.4)
					_b_leaf(q - nrm * lw * 0.7, lw, lw * 0.38, nrm.angle() + PI + 0.4)
					prev = q
			_b_flush(ci, col)
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
	for b in _beams[i]:
		# a lighthouse beam slowly sweeping round (two opposite beams)
		var lp: Vector2 = b[0]
		var bs: float = b[1]
		var a0: float = t * 0.6
		for side in [0.0, PI]:
			var a: float = a0 + side
			var dir := Vector2(cos(a), sin(a) * 0.35)
			var w := 0.5 + 0.5 * absf(cos(a))  # longer when pointing sideways
			var e := lp + dir * 900.0 * bs * w
			var n := Vector2(-dir.y, dir.x)
			ci.draw_polygon(PackedVector2Array([lp + n * 4.0, lp - n * 4.0, e - n * 70.0 * bs, e + n * 70.0 * bs]),
				PackedColorArray([Color(1.0, 0.92, 0.7, 0.22 * fade), Color(1.0, 0.92, 0.7, 0.22 * fade), Color(1.0, 0.92, 0.7, 0.0), Color(1.0, 0.92, 0.7, 0.0)]))
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
	var sx: float = _sun_screen().x
	var a: float = 0.55 * pal.water * (0.25 + 0.75 * sun_vis)
	ci.draw_polygon(PackedVector2Array([Vector2(sx - 70, y0), Vector2(sx + 70, y0), Vector2(sx + 150, y0 + 140), Vector2(sx - 150, y0 + 140)]),
		PackedColorArray([Color(sc, a), Color(sc, a), Color(sc, 0.0), Color(sc, 0.0)]))
	for i in [10, 22, 40][Art.Q]:
		var yy = y0 + 4.0 + pow(Art.hash01(i, 3), 1.5) * 120.0
		var spread = 30.0 + (yy - y0) * 1.8
		var cx = sx + (Art.hash01(i, 9) - 0.5) * spread * 2.0 + sin(t * 1.3 + i) * 8.0
		var ln = 8.0 + Art.hash01(i, 4) * 46.0 * (0.4 + (yy - y0) / 120.0)
		var al = (0.35 + 0.35 * sin(t * 2.2 + i * 1.7)) * pal.water * (0.3 + 0.7 * sun_vis)
		ci.draw_line(Vector2(cx - ln, yy), Vector2(cx + ln, yy), Color(sc.lightened(0.4), al), 2.0)
	# slow ripple lines across the whole surface
	for k in 4:
		var yy = y0 + 18.0 + k * 26.0
		var off = fposmod(-cam_x * (0.08 + k * 0.03) + k * 211.0, 260.0)
		var x = off - 260.0
		while x < w:
			ci.draw_line(Vector2(x, yy), Vector2(x + 60.0 + k * 20.0, yy), Color(hor.lightened(0.2), 0.10), 1.5)
			x += 260.0
	_draw_ships(ci, y0)

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
	if Art.Q == 0 or sun_vis < 0.02:
		return
	# rays start at the sun/moon disc itself (same position as _draw_sky_light)
	var c0 = _sun_screen()
	var sc: Color = pal.sun
	var swap := 1.0 if tr_from.is_empty() else absf(_sky_k() - 0.5) * 2.0
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
		var al = (0.025 + 0.015 * sin(t * 0.4 + k * 2.1)) * (1.0 + calm * 0.5) * sun_vis * swap
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
## Close foreground plants framing the bottom of the screen (in front of the
## gameplay, below the ground line). Each country has its own plants, tinted
## with its colours and caught by a thin rim of light, so they read as plants
## rather than black spikes.
func draw_foreground(ci: Node2D, gy: float) -> void:
	var off = cam_x * 1.55
	# 0.8.15: the near plants carry the scene's colour (not near-black), with a
	# stronger sunlit rim, little grass clumps between them, and soft
	# out-of-focus light specks drifting in front of the lens.
	var col: Color = pal.layers[2].darkened(0.35).lerp(pal.ground, 0.2).lerp(pal.sky[0], 0.15)
	col.a = 0.97
	var rim: Color = Color(pal.rim.lightened(0.15), 0.55)
	if Art.Q >= 1:
		_draw_fg_clumps(ci, off * 0.9, col.lightened(0.04))
	var kind: String = pal.get("surface", "pavers")
	var cw = 820.0
	var c0 = int(floor((off - 400.0) / cw))
	var c1 = int(floor((off + size.x + 400.0) / cw))
	for c in range(c0, c1 + 1):
		var r = Art.hash01(c, 501)
		if r > 0.6:
			continue
		var sx = c * cw + r * 420.0 - off
		var base = Vector2(sx, size.y + 30.0)
		var sway = sin(t * 0.8 + c) * 0.04
		var tall = 0.75 + Art.hash01(c, 504) * 0.5
		match kind:
			"moss":
				# a big fern: arching fronds with leaflets
				var nf: int = 6 if Art.Q >= 1 else 4
				for k in nf:
					var f = k / float(nf - 1) - 0.5
					var tip = base + Vector2(f * 300.0, -230.0 * tall * (1.0 - absf(f) * 0.5)).rotated(sway)
					_frond(ci, base, tip, Vector2(f * 120.0, 60.0), 14.0, col, rim)
				_b_flush(ci, col)
			"boards":
				# reeds and cattails by the water
				for k in 7:
					var bx = base + Vector2((k - 3) * 22.0, 0)
					var h = (200.0 + Art.hash01(c, 520 + k) * 140.0) * tall
					var tip = bx + Vector2(sin(t * 1.1 + k + c) * 10.0 + (k - 3) * 8.0, -h)
					_leaf(ci, bx, tip, Vector2((k - 3) * 10.0, 0), 7.0, col, rim)
					if k % 2 == 0:
						ci.draw_colored_polygon(Art.ellipse(tip + Vector2(0, 26), Vector2(7, 22), 12), col)
			"snow":
				# a snowy pine bough sweeping in from below
				var tip = base + Vector2(320.0, -200.0 * tall).rotated(sway)
				_leaf(ci, base, tip, Vector2(80, 40), 10.0, col, rim)
				var snowy := PackedVector2Array()
				for k in range(1, 9):
					var u = k / 9.0
					var q = base.lerp(tip, u) + Vector2(80, 40) * (u - u * u) * 4.0
					for sd in [-1.0, 1.0]:
						var nt = q + Vector2(30.0 * (1.0 - u) + 10.0, sd * (40.0 * (1.0 - u) + 12.0)).rotated(-0.5)
						_b_quad(q, nt, 6.0 * (1.0 - u * 0.5), 1.0)
						snowy.append(q.lerp(nt, 0.3))
						snowy.append(nt)
				_b_flush(ci, col)
				ci.draw_multiline(snowy, Color(0.92, 0.95, 1.0, 0.55), 2.0)
			_:
				# Greece: an agave / wild lily clump with broad curved leaves
				var nl := 5 + int(Art.hash01(c, 502) * 3.0)
				for k in nl:
					var f = (float(k) / float(nl - 1)) - 0.5
					var tip = base + Vector2(f * 340.0, -(170.0 + Art.hash01(c, 530 + k) * 110.0) * tall * (1.0 - absf(f) * 0.4)).rotated(sway)
					_leaf(ci, base + Vector2(f * 40.0, 0), tip, Vector2(f * 70.0, -20.0), 26.0, col, rim)

func _draw_fg_clumps(ci: Node2D, off: float, col: Color) -> void:
	var cw := 300.0
	var c0 := int(floor((off - 200.0) / cw))
	var c1 := int(floor((off + size.x + 200.0) / cw))
	for c in range(c0, c1 + 1):
		if Art.hash01(c, 541) > 0.55:
			continue
		var bx: float = c * cw + Art.hash01(c, 542) * 180.0 - off
		var pts := PackedVector2Array([Vector2(bx - 60, size.y + 10)])
		var n := 7
		for k in n:
			var u := float(k) / (n - 1)
			var h := (50.0 + Art.hash01(c, 550 + k) * 70.0) * (1.0 - absf(u - 0.5) * 0.9)
			var x := bx - 50.0 + u * 100.0
			var lean := sin(t * 1.1 + c + k * 0.4) * 10.0 + (u - 0.5) * 30.0
			pts.append(Vector2(x - 6.0, size.y))
			pts.append(Vector2(x + lean, size.y - h))
		pts.append(Vector2(bx + 60, size.y + 10))
		ci.draw_colored_polygon(pts, col)

## Out-of-focus light specks (bokeh) close to the camera: big, soft, slow.
func draw_bokeh(ci: Node2D) -> void:
	if Art.Q < 1:
		return
	var n: int = [0, 6, 10][Art.Q]
	var warm: Color = pal.rim.lerp(pal.mote, 0.5)
	for i in n:
		var h1 := Art.hash01(i, 701)
		var h2 := Art.hash01(i, 702)
		var depth := 0.5 + Art.hash01(i, 703) * 0.5
		var x: float = fposmod(h1 * size.x * 1.4 - cam_x * 1.2 * depth - t * 6.0, size.x * 1.4) - size.x * 0.2
		var y: float = size.y * (0.15 + h2 * 0.8) + sin(t * 0.4 + i * 1.7) * 18.0
		var r: float = 18.0 + depth * 34.0
		var a: float = (0.035 + 0.05 * pal.stars) * (0.6 + 0.4 * sin(t * 0.7 + i * 2.3))
		ci.draw_circle(Vector2(x, y), r, Color(warm, a * 1.6))
		ci.draw_arc(Vector2(x, y), r * 0.92, 0.0, TAU, 20, Color(warm.lightened(0.3), a * 1.4), 2.0)

## A curved, tapering leaf from base to tip (bend pushes the middle sideways).
func _leaf(ci: Node2D, base: Vector2, tip: Vector2, bend: Vector2, w: float, col: Color, rim: Color) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 9
	for k in n + 1:
		var u := float(k) / n
		var q := base.lerp(tip, u) + bend * (u - u * u) * 4.0
		var q2 := base.lerp(tip, minf(u + 0.05, 1.0)) + bend * ((u + 0.05) - (u + 0.05) * (u + 0.05)) * 4.0
		var nrm := (q2 - q).normalized().orthogonal() if k < n else Vector2.ZERO
		var ww := w * sin(PI * minf(u * 0.9 + 0.1, 1.0)) * (1.0 - u * 0.4)
		left.append(q + nrm * ww)
		right.append(q - nrm * ww)
	right.reverse()
	var poly := left + right
	ci.draw_colored_polygon(poly, col)
	ci.draw_polyline(left, rim, 1.5, Art.AA)

## A fern frond: a curved stem with paired leaflets shrinking to the tip.
func _frond(ci: Node2D, base: Vector2, tip: Vector2, bend: Vector2, w: float, col: Color, rim: Color) -> void:
	# batched: the caller flushes once per plant
	var prev := base
	for k in range(1, 11):
		var u := k / 10.0
		var q := base.lerp(tip, u) + bend * (u - u * u) * 4.0
		_b_quad(prev, q, maxf(2.5 * (1.0 - u), 0.8), maxf(2.5 * (1.0 - u), 0.8))
		var d := (q - prev).normalized()
		var lw := w * (1.1 - u)
		for sd in [-1.0, 1.0]:
			var dir2: Vector2 = (d.orthogonal() * sd * 1.6 + d * 0.6).normalized()
			_b_leaf(q + dir2 * lw * 1.1, lw * 1.15, lw * 0.42, dir2.angle())
		prev = q

# ------------------------------------------------------------------ living world
## Distant towns, little people doing things, ships and things in the sky.
## All are silhouettes in the layer colour with a few warm lights. They are
## rare and slow, so they stay special, and they never reach the play line.
const TOWN_CELL := 1700.0
const LIFE_CELL := 950.0
const SHIP_CELL := 1500.0
const WARM := Color(1.0, 0.80, 0.50)

func _warm(k := 1.15) -> Color:
	return Art.hdr(WARM, k)

## Far-layer skyline: city blocks (Greece, Danube) or villages (Bulgaria,
## Carpathians), with windows that slowly switch on and off.
func _draw_town(ci: Node2D, off: float, col: Color) -> void:
	var c0 = int(floor((off - 900.0) / TOWN_CELL))
	var c1 = int(floor((off + size.x + 300.0) / TOWN_CELL))
	var win0 := _warm(1.1)
	for c in range(c0, c1 + 1):
		if Art.hash01(c, 601) > [0.25, 0.40, 0.55][Art.Q]:
			continue
		var x = c * TOWN_CELL + Art.hash01(c, 602) * TOWN_CELL * 0.4
		var w := _mix(PAR[0], x - off)
		var fade := 1.0 if tr_from.is_empty() else absf(w - 0.5) * 2.0
		if fade < 0.03:
			continue
		var village: bool = _side(w).get("town", "city") == "village"
		var tc: Color = _side(0.0).layers[0].lerp(_side(1.0).layers[0], w).lerp(pal.fog, 0.10)
		tc.a = fade
		var win := Color(win0, fade)
		var n := (4 if village else 6) + int(Art.hash01(c, 603) * (5.0 if village else 9.0))
		for b in n:
			var sd := c * 97 + b
			var bw = (30.0 if village else 24.0) + Art.hash01(sd, 1) * 34.0
			var bh: float
			if village:
				bh = 22.0 + Art.hash01(sd, 2) * 26.0
			else:
				# taller in the middle of the skyline
				var mid = 1.0 - absf(float(b) / float(n - 1) - 0.5) * 1.4
				bh = 40.0 + Art.hash01(sd, 2) * 90.0 * maxf(mid, 0.25)
			var sx = x - off
			var by = _ridge_y(0, x + bw * 0.5) + 18.0
			ci.draw_rect(Rect2(sx, by - bh, bw, bh + 40.0), tc)
			var r = Art.hash01(sd, 3)
			if village:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 5, by - bh), Vector2(sx + bw * 0.5, by - bh - bw * 0.5), Vector2(sx + bw + 5, by - bh)]), tc)
				if r < 0.15:
					# little church tower
					ci.draw_rect(Rect2(sx + bw * 0.35, by - bh - bw * 0.5 - 40.0, bw * 0.3, 40.0), tc)
					ci.draw_colored_polygon(PackedVector2Array([Vector2(sx + bw * 0.3, by - bh - bw * 0.5 - 40.0), Vector2(sx + bw * 0.5, by - bh - bw * 0.5 - 62.0), Vector2(sx + bw * 0.7, by - bh - bw * 0.5 - 40.0)]), tc)
			elif r < 0.18:
				ci.draw_colored_polygon(Art.ellipse(Vector2(sx + bw * 0.5, by - bh), Vector2(bw * 0.45, bw * 0.4), 14), tc)
			elif r < 0.32:
				ci.draw_line(Vector2(sx + bw * 0.5, by - bh), Vector2(sx + bw * 0.5, by - bh - 34.0), tc, 2.0)
				if fmod(t + sd, 2.0) < 1.0:
					ci.draw_rect(Rect2(sx + bw * 0.5 - 1.5, by - bh - 36.0, 3, 3), Color(Art.hdr(Color(1.0, 0.35, 0.3), 1.4), fade))
			if Art.Q == 0:
				continue
			# windows: a handful per building, a few slowly blink on/off
			var nw := int(bw * bh / (260.0 if village else 420.0) / (1.0 if Art.Q >= 2 else 1.8))
			for k in nw:
				var on = sin(t * 0.25 + Art.hash01(sd, 40 + k) * 40.0) > -0.75
				if not on:
					continue
				var wx = sx + 4.0 + floor(Art.hash01(sd, 60 + k) * (bw - 10.0) / 7.0) * 7.0
				var wy = by - bh + 6.0 + floor(Art.hash01(sd, 80 + k) * maxf(bh - 22.0, 1.0) / 10.0) * 10.0
				ci.draw_rect(Rect2(wx, wy, 3.0, 4.0), Color(win, (0.55 + 0.45 * Art.hash01(sd, 90 + k)) * fade))
			x += bw + 2.0 + Art.hash01(sd, 4) * (14.0 if village else 6.0)

## A stick-figure silhouette. p = feet. Returns the right hand position.
## A soft silhouette person (rounded body, tapered limbs, round hands and
## feet). p = feet. Returns the right hand position.
func _person(ci: Node2D, p: Vector2, s: float, col: Color, arm_l: float, arm_r: float, sit := false, kid := false) -> Vector2:
	var k = s * (0.74 if kid else 1.0)
	var hip = p + Vector2(0, -(15.0 if sit else 25.0) * k)
	var chest = hip + Vector2(0, -16.0 * k)
	var neck = hip + Vector2(0, -21.0 * k)
	if sit:
		_limb_s(ci, hip, hip + Vector2(12 * k, 0), 5.0 * k, 4.2 * k, col)
		_limb_s(ci, hip + Vector2(12 * k, 0), p + Vector2(12 * k, -2 * k), 4.2 * k, 3.4 * k, col)
		ci.draw_colored_polygon(Art.ellipse(p + Vector2(15 * k, -1.5 * k), Vector2(4.5 * k, 2.2 * k), 10), col)
	else:
		for fx in [-4.5, 4.5]:
			_limb_s(ci, hip + Vector2(fx * 0.4 * k, 0), p + Vector2(fx * k, -2 * k), 4.6 * k, 3.4 * k, col)
			ci.draw_colored_polygon(Art.ellipse(p + Vector2(fx * k + 2 * k, -1.5 * k), Vector2(4.2 * k, 2.2 * k), 10), col)
	# torso: a soft rounded body, wider at the shoulders
	ci.draw_colored_polygon(Art.ellipse((hip + neck) * 0.5 + Vector2(0, 1.5 * k), Vector2(6.2 * k, 12.5 * k), 14), col)
	ci.draw_colored_polygon(Art.ellipse(chest, Vector2(7.2 * k, 5.5 * k), 12), col)
	# head + neck
	ci.draw_line(neck, neck + Vector2(0, -4 * k), col, 3.5 * k)
	ci.draw_circle(neck + Vector2(0.5 * k, -9.0 * k), 6.8 * k, col)
	var sh = neck + Vector2(0, 3.5 * k)
	var hl = sh + Vector2(cos(arm_l), sin(arm_l)) * 15.0 * k
	var hr = sh + Vector2(cos(arm_r), sin(arm_r)) * 15.0 * k
	_limb_s(ci, sh, hl, 3.4 * k, 2.6 * k, col)
	_limb_s(ci, sh, hr, 3.4 * k, 2.6 * k, col)
	ci.draw_circle(hl, 2.6 * k, col)
	ci.draw_circle(hr, 2.6 * k, col)
	return hr

## Tapered limb with rounded ends.
func _limb_s(ci: Node2D, a: Vector2, b: Vector2, w0: float, w1: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var n := d.normalized().orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([a + n * w0 * 0.5, b + n * w1 * 0.5, b - n * w1 * 0.5, a - n * w0 * 0.5]), col)
	ci.draw_circle(a, w0 * 0.5, col)
	ci.draw_circle(b, w1 * 0.5, col)

func _draw_life(ci: Node2D, off: float, col: Color) -> void:
	var c0 = int(floor((off - 500.0) / LIFE_CELL))
	var c1 = int(floor((off + size.x + 300.0) / LIFE_CELL))
	var s: float = SCALE[2] * 1.75
	var base_col: Color = col
	for c in range(c0, c1 + 1):
		if Art.hash01(c, 701) > [0.25, 0.40, 0.60][Art.Q]:
			continue
		var lx = c * LIFE_CELL + 80.0 + Art.hash01(c, 703) * LIFE_CELL * 0.6
		var p = Vector2(lx - off, _ridge_y(2, lx) + 3.0)
		var w := _mix(PAR[2], p.x)
		var fade := 1.0 if tr_from.is_empty() else absf(w - 0.5) * 2.0
		var life: Array = _side(w).get("life", [])
		if life.is_empty() or fade < 0.03:
			continue
		var kind: String = life[int(Art.hash01(c, 702) * life.size()) % life.size()]
		# fade out while passing behind Kavi, so nothing reads as part of him
		var near = 1.0 - clampf((absf(p.x - hero_x) - 110.0) / 170.0, 0.0, 1.0)
		col = Color(base_col, (1.0 - near * 0.95) * fade)
		var lamps: bool = near < 0.5 and fade > 0.5
		var flip = 1.0 if Art.hash01(c, 704) < 0.5 else -1.0
		var ph = Art.hash01(c, 705) * TAU
		match kind:
			"waver":
				_person(ci, p, s, col, PI * 0.55, -PI * 0.5 + sin(t * 7.0 + ph) * 0.55)
			"kite_kid":
				var hand = _person(ci, p, s, col, PI * 0.6, -PI * 0.25 * (1.0 + 0.5 * flip) - 0.3, false, true)
				var kp = hand + Vector2(70.0 * flip + sin(t * 1.3 + ph) * 14.0, -150.0 + cos(t * 1.1 + ph) * 10.0) * s
				var mid = (hand + kp) * 0.5 + Vector2(0, 18.0 * s)
				ci.draw_polyline(PackedVector2Array([hand, mid, kp]), Color(col.lightened(0.25), 0.8 * col.a), 1.2, Art.AA)
				var rot = sin(t * 1.7 + ph) * 0.25
				var d = Vector2(0, -16.0 * s).rotated(rot)
				var e = Vector2(11.0 * s, 0).rotated(rot)
				ci.draw_colored_polygon(PackedVector2Array([kp + d, kp + e, kp - d * 1.3, kp - e]), Color(pal.accent.lerp(Color(1, 0.5, 0.45), Art.hash01(c, 706)), col.a))
				var tail := PackedVector2Array()
				for q in 6:
					tail.append(kp - d * 1.3 + Vector2(-q * 7.0 * flip * s, q * 7.0 * s + sin(t * 4.0 + q) * 4.0 * s))
				ci.draw_polyline(tail, Color(pal.accent, 0.8 * col.a), 1.5, Art.AA)
			"fisher":
				# sitting on the end of a little wooden jetty, sun hat on, a bucket
				# beside him; the rod bends and the float bobs on the water
				var fl: float = flip
				var jx = p.x - 30 * s * fl
				ci.draw_colored_polygon(Art.rrect(Rect2(minf(jx, p.x + 16 * s * fl) - 4 * s, p.y - 14 * s, absf(p.x + 16 * s * fl - jx) + 8 * s, 6 * s), 2.0 * s), col)
				for px in [jx, p.x + 10 * s * fl]:
					ci.draw_rect(Rect2(px - 2.5 * s, p.y - 10 * s, 5 * s, 40 * s), col)
				var seat = p + Vector2(4 * s * fl, -13 * s)
				var hand = _person(ci, seat, s, col, PI * 0.5, (-0.35 if fl > 0 else PI + 0.35), true)
				# sun hat: brim + crown
				var hd = seat + Vector2(0.5 * s, -30 * s)
				ci.draw_colored_polygon(Art.ellipse(hd + Vector2(0, -4 * s), Vector2(11 * s, 2.6 * s), 12), col)
				ci.draw_colored_polygon(Art.ellipse(hd + Vector2(0, -7 * s), Vector2(6 * s, 4.5 * s), 12), col)
				# bucket
				var bk = p + Vector2(-16 * s * fl, -14 * s)
				ci.draw_colored_polygon(PackedVector2Array([bk + Vector2(-5 * s, -9 * s), bk + Vector2(5 * s, -9 * s), bk + Vector2(4 * s, 0), bk + Vector2(-4 * s, 0)]), col)
				ci.draw_arc(bk + Vector2(0, -9 * s), 5 * s, PI, TAU, 8, col, 1.2)
				# rod: a gentle curve, then the line down to a bobbing float
				var rod := PackedVector2Array()
				for k in 7:
					var u = k / 6.0
					rod.append(hand + Vector2(70.0 * fl * u, -40.0 * u + 18.0 * u * u) * s)
				ci.draw_polyline(rod, col, 2.2, Art.AA)
				var tip: Vector2 = rod[6]
				var bob = sin(t * 2.0 + ph) * 2.5
				var fpos = tip + Vector2(10.0 * fl * s, 64.0 * s + bob)
				ci.draw_line(tip, fpos, Color(col.lightened(0.35), 0.55 * col.a), 1.0)
				ci.draw_circle(fpos, 3.0 * s, Color(1.0, 0.45, 0.4, col.a))
				ci.draw_arc(fpos + Vector2(0, 3 * s), 8 * s + absf(bob), PI * 0.1, PI * 0.9, 8, Color(col.lightened(0.4), 0.35 * col.a), 1.0)
			"bench":
				ci.draw_rect(Rect2(p.x - 30 * s, p.y - 16 * s, 60 * s, 4 * s), col)
				ci.draw_rect(Rect2(p.x - 30 * s, p.y - 30 * s, 60 * s, 3 * s), col)
				ci.draw_line(p + Vector2(-26 * s, -14 * s), p + Vector2(-26 * s, 0), col, 3.0 * s)
				ci.draw_line(p + Vector2(26 * s, -14 * s), p + Vector2(26 * s, 0), col, 3.0 * s)
				_person(ci, p + Vector2(-14 * s, -2 * s), s, col, PI * 0.6, PI * 0.25, true)
				_person(ci, p + Vector2(8 * s, -2 * s), s * 0.92, col, PI * 0.7, PI * 0.4, true)
				var lamp = p + Vector2(52 * s * flip, 0)
				ci.draw_line(lamp, lamp + Vector2(0, -92 * s), col, 3.0 * s)
				if lamps:
					_lights[2].append([lamp + Vector2(0, -96 * s), 5.0 * s, _warm(1.0)])
			"cafe":
				ci.draw_line(p + Vector2(0, -36 * s), p, col, 3.0 * s)
				ci.draw_rect(Rect2(p.x - 18 * s, p.y - 36 * s, 36 * s, 4 * s), col)
				ci.draw_line(p + Vector2(0, -36 * s), p + Vector2(0, -88 * s), col, 2.0 * s)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-46 * s, -78 * s), p + Vector2(0, -96 * s), p + Vector2(46 * s, -78 * s)]), Color(pal.accent.lerp(base_col, 0.55), col.a))
				_person(ci, p + Vector2(-30 * s, 0), s, col, -0.2, PI * 0.3 + sin(t * 1.5 + ph) * 0.2, true)
				_person(ci, p + Vector2(30 * s, 0), s, col, PI + 0.2, PI * 0.6, true)
				if lamps:
					_lights[2].append([p + Vector2(0, -42 * s), 3.5 * s, _warm(1.2)])
			"cart":
				# donkey grazing beside a cart, farmer resting on the wheel
				var dp = p + Vector2(-50 * s * flip, 0)
				ci.draw_colored_polygon(Art.ellipse(dp + Vector2(0, -26 * s), Vector2(24 * s, 11 * s), 14), col)
				for lxo in [-16, -8, 10, 17]:
					ci.draw_line(dp + Vector2(lxo * s, -20 * s), dp + Vector2(lxo * s, 0), col, 3.5 * s)
				var nib = sin(t * 1.6 + ph) * 4.0 * s
				var hd = dp + Vector2(-30 * s * flip, -8 * s + nib)
				ci.draw_line(dp + Vector2(-18 * s * flip, -30 * s), hd, col, 7.0 * s)
				ci.draw_line(hd, hd + Vector2(-4 * s * flip, -12 * s), col, 2.5 * s)
				ci.draw_rect(Rect2(p.x - 10 * s, p.y - 40 * s, 52 * s, 16 * s), col)
				var wc = p + Vector2(16 * s, -14 * s)
				ci.draw_arc(wc, 14 * s, 0.0, TAU, 16, col, 3.0 * s, Art.AA)
				for q in 3:
					var a = q * PI / 3.0
					ci.draw_line(wc - Vector2(cos(a), sin(a)) * 13 * s, wc + Vector2(cos(a), sin(a)) * 13 * s, col, 1.5 * s)
				_person(ci, p + Vector2(48 * s, 0), s, col, PI * 0.9, PI * 0.5)
			"dog":
				_person(ci, p, s, col, PI * 0.5, PI * 0.25 * (1 if flip > 0 else 3))
				var dg = p + Vector2(30 * s * flip, 0)
				ci.draw_colored_polygon(Art.ellipse(dg + Vector2(0, -12 * s), Vector2(12 * s, 6 * s), 12), col)
				for lxo in [-8, 8]:
					ci.draw_line(dg + Vector2(lxo * s, -10 * s), dg + Vector2(lxo * s, 0), col, 2.5 * s)
				ci.draw_circle(dg + Vector2(13 * s * flip, -18 * s), 5.5 * s, col)
				var wag = sin(t * 12.0 + ph) * 0.6
				ci.draw_line(dg + Vector2(-11 * s * flip, -14 * s), dg + Vector2(-11 * s * flip, -14 * s) + Vector2(-flip * 8 * s, -6 * s).rotated(wag), col, 2.5 * s)
				ci.draw_line(p + Vector2(10 * s * flip, -34 * s), dg + Vector2(10 * s * flip, -16 * s), Color(col, 0.7 * col.a), 1.0)

## Ships on the Greek sea and the Danube: they drift slowly on their own and
## with the camera; lights reflect in the water.
func _draw_ships(ci: Node2D, y0: float) -> void:
	_hits_sea.clear()
	var off = cam_x * 0.11 + t * 9.0
	var c0 = int(floor((off - 500.0) / SHIP_CELL))
	var c1 = int(floor((off + size.x + 500.0) / SHIP_CELL))
	var sc: Color = pal.layers[1].darkened(0.15)
	sc.a = pal.water
	for c in range(c0, c1 + 1):
		if Art.hash01(c, 801) > 0.6:
			continue
		var wsh := _mix(0.11, c * SHIP_CELL + 350.0 - off)
		var ships: Array = _side(wsh).get("ships", [])
		if ships.is_empty():
			continue
		var kind: String = ships[int(Art.hash01(c, 802) * ships.size()) % ships.size()]
		var s = 0.55 + Art.hash01(c, 803) * 0.35
		var p = Vector2(c * SHIP_CELL + Art.hash01(c, 804) * 700.0 - off, y0 + 14.0 + Art.hash01(c, 805) * 22.0 * s)
		p.y += sin(t * 1.2 + c) * 1.2
		var skey := "ship:%d" % c
		var sa := _age(skey)
		if sa < 2.0:
			p.y += sin(sa * 9.0) * 4.0 * exp(-sa * 2.0)
		var top_h := {"sail": 80.0, "ferry": 62.0, "barge": 34.0, "steamer": 62.0}
		var half_w := {"sail": 34.0, "ferry": 92.0, "barge": 110.0, "steamer": 72.0}
		var hh: float = top_h.get(kind, 50.0) * s
		var hw: float = half_w.get(kind, 60.0) * s
		_hits_sea.append({"kind": "ship", "key": skey, "rect": Rect2(p.x - hw, p.y - hh, hw * 2.0, hh + 6.0),
			"top": p + Vector2((10.0 * s) if kind == "steamer" else 0.0, -hh)})
		var lights: Array = []
		match kind:
			"sail":
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-34 * s, -8 * s), p + Vector2(34 * s, -8 * s), p + Vector2(24 * s, 0), p + Vector2(-26 * s, 0)]), sc)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2 * s, -12 * s), p + Vector2(-2 * s, -78 * s), p + Vector2(28 * s, -12 * s)]), sc)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6 * s, -14 * s), p + Vector2(-6 * s, -62 * s), p + Vector2(-26 * s, -14 * s)]), sc)
				lights.append(p + Vector2(-2 * s, -80 * s))
			"ferry":
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-90 * s, -18 * s), p + Vector2(96 * s, -18 * s), p + Vector2(80 * s, 0), p + Vector2(-84 * s, 0)]), sc)
				ci.draw_rect(Rect2(p.x - 60 * s, p.y - 32 * s, 110 * s, 14 * s), sc)
				ci.draw_rect(Rect2(p.x - 40 * s, p.y - 44 * s, 64 * s, 12 * s), sc)
				ci.draw_rect(Rect2(p.x + 6 * s, p.y - 62 * s, 12 * s, 18 * s), sc)
				for k in 9:
					lights.append(p + Vector2((-54 + k * 12) * s, -26 * s))
			"barge":
				ci.draw_rect(Rect2(p.x - 110 * s, p.y - 9 * s, 220 * s, 9 * s), sc)
				ci.draw_rect(Rect2(p.x - 100 * s, p.y - 16 * s, 150 * s, 7 * s), sc)
				ci.draw_rect(Rect2(p.x + 70 * s, p.y - 34 * s, 28 * s, 25 * s), sc)
				lights.append(p + Vector2(84 * s, -26 * s))
				lights.append(p + Vector2(-108 * s, -12 * s))
			"steamer":
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-70 * s, -14 * s), p + Vector2(74 * s, -14 * s), p + Vector2(62 * s, 0), p + Vector2(-64 * s, 0)]), sc)
				ci.draw_rect(Rect2(p.x - 50 * s, p.y - 28 * s, 90 * s, 14 * s), sc)
				ci.draw_rect(Rect2(p.x - 8 * s, p.y - 58 * s, 10 * s, 30 * s), sc)
				var wc = p + Vector2(-38 * s, -14 * s)
				ci.draw_arc(wc, 15 * s, PI, TAU, 10, sc, 4.0 * s)
				for q in 6:
					var pf = fmod(t * 0.4 + q / 6.0, 1.0)
					var sp = p + Vector2(-3 * s - pf * 60.0 * s, -62 * s - pf * 50.0 * s)
					ci.draw_circle(sp, (5.0 + pf * 12.0) * s, Color(pal.fog, 0.22 * (1.0 - pf) * pal.water))
				for k in 6:
					lights.append(p + Vector2((-44 + k * 14) * s, -21 * s))
		for lp in lights:
			ci.draw_rect(Rect2(lp.x - 1.5, lp.y - 1.5, 3.0, 3.0), Color(_warm(1.3), pal.water))
			# reflection streak
			var ry = p.y + (p.y - lp.y) * 0.25 + 4.0
			ci.draw_line(Vector2(lp.x, ry), Vector2(lp.x, ry + 6.0 + sin(t * 3.0 + lp.x) * 2.0), Color(WARM, 0.35 * pal.water), 1.5)
	_draw_sky_fx(ci, "sea")

## Sky traffic: one plane at a time with blinking lights, hot-air balloons
## drifting with the wind, or a flock of birds.
func _draw_air(ci: Node2D) -> void:
	_hits_air.clear()
	if tr_from.is_empty():
		_draw_air_set(ci, pal.get("air", []), 1.0)
	else:
		var k := clampf((t - tr_t0) / 6.0, 0.0, 1.0)
		_draw_air_set(ci, tr_from.get("air", []), 1.0 - k)
		_draw_air_set(ci, tr_to.get("air", []), k)
	_draw_sky_fx(ci, "air")

func _draw_air_set(ci: Node2D, air: Array, alpha: float) -> void:
	if air.is_empty() or alpha < 0.02:
		return
	var w = size.x
	var h = size.y
	var sil: Color = Color(pal.sky[0].darkened(0.35), alpha)
	# plane: crosses every 24 s, skips some cycles
	var P := 24.0
	var n := int(floor((t + 5.0) / P))
	var ph := fmod(t + 5.0, P) / P
	if air.has("plane") and Art.hash01(n, 901) < 0.7:
		var dir = 1.0 if Art.hash01(n, 902) < 0.5 else -1.0
		var x = lerpf(-120.0, w + 120.0, ph) if dir > 0 else lerpf(w + 120.0, -120.0, ph)
		var y = h * (0.08 + Art.hash01(n, 903) * 0.16) - ph * 30.0
		var p = Vector2(x, y)
		var pkey := "plane:%d" % n
		var pa := _age(pkey)
		var vb := Vector2(dir * (w + 240.0) / P, -30.0 / P)   # cruise velocity
		var vel := vb
		if pa < 3.0:
			# fly a heart: the plane's own path, nose along its velocity, and the
			# smoke comes out of its tail (so the heart is drawn behind it)
			var u := pa / 3.0 * TAU
			p += (_heart(u) - _heart(0.0)) * 4.2
			vel = vb + (_heart(u + 0.01) - _heart(u)) / 0.01 * (TAU / 3.0) * 4.2
		var ang := vel.angle()
		var fwd := Vector2.from_angle(ang)
		if pa < 3.0:
			var pk: Dictionary = pokes[pkey]
			if t - float(pk.get("emit", 0.0)) > 0.03:
				pk.emit = t
				sky_fx.append({"kind": "smoke", "p": p - fwd * 18.0, "v": vb, "t0": t, "life": 3.6, "layer": "air"})
		if alpha > 0.5:
			_hits_air.append({"kind": "plane", "key": pkey, "rect": Rect2(p - Vector2(24, 18), Vector2(48, 36))})
		if pal.stars < 0.35 and pa >= 3.0:
			ci.draw_line(p - fwd * 18.0, p - fwd * 260.0 + Vector2(0, 6), Color(1, 1, 1, 0.10 * alpha), 2.0)
		# draw in the plane's own frame: +x is the nose. Planes flying left are
		# mirrored once (not per frame), so they roll through the loop properly.
		var rot := vb.angle() if pa >= 3.0 else ang
		ci.draw_set_transform(p, rot, Vector2(1, -1) if dir < 0 else Vector2.ONE)
		ci.draw_line(Vector2(-16, 0), Vector2(16, 0), sil, 3.0)
		ci.draw_line(Vector2(2, 0), Vector2(-6, 7), sil, 2.0)
		ci.draw_line(Vector2(-14, 0), Vector2(-18, -6), sil, 2.0)
		ci.draw_rect(Rect2(-8.5, 6, 3, 3), Color(Art.hdr(Color(1.0, 0.3, 0.3), 1.5), alpha))
		if fmod(t, 1.1) < 0.12:
			ci.draw_rect(Rect2(13, -2, 4, 4), Color(Art.hdr(Color(1, 1, 1), 2.0), alpha))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if air.has("balloon") and Art.Q >= 1:
		for b in 2:
			if Art.hash01(b, 910 + int(n / 3.0)) > 0.55:
				continue
			var bx = fposmod(Art.hash01(b, 911) * w * 1.6 - cam_x * 0.025 - t * 7.0, w * 1.6) - w * 0.3
			var by = h * (0.18 + Art.hash01(b, 912) * 0.14) + sin(t * 0.5 + b * 2.0) * 8.0
			var hues := [Color(0.95, 0.42, 0.35), Color(1.0, 0.72, 0.30), Color(0.35, 0.75, 0.80)]
			var bc: Color = hues[int(Art.hash01(b, 913) * 3.0) % 3].lerp(pal.sky[1], 0.35)
			bc.a = alpha
			var bkey := "balloon:%d" % b
			var ba := _age(bkey)
			if ba < 1.3:
				by -= sin(ba / 1.3 * PI) * 46.0
			var rk: float = t - float(pokes.get(bkey, {}).get("rocket", -99.0))
			if rk < 13.0:
				# whoosh! up and away, then a slow float back down
				by -= 620.0 * smoothstep(0.0, 2.2, rk) * (1.0 - smoothstep(6.0, 13.0, rk))
			var bp = Vector2(bx, by)
			var r = 24.0 + Art.hash01(b, 914) * 10.0
			var squash: float = exp(-ba * 4.0) * sin(ba * 22.0) * 0.12 if ba < 1.5 else 0.0
			r *= 1.0 + squash
			# teardrop envelope: round crown narrowing to the throat
			var env := PackedVector2Array()
			for k in 17:
				var u = lerpf(-PI * 1.18, PI * 0.18, k / 16.0)
				env.append(bp + Vector2(cos(u), sin(u)) * r)
			env.append(bp + Vector2(r * 0.28, r * 1.35))
			env.append(bp + Vector2(-r * 0.28, r * 1.35))
			ci.draw_colored_polygon(env, bc)
			# vertical gores in a lighter colour
			ci.draw_colored_polygon(Art.ellipse(bp + Vector2(0, r * 0.1), Vector2(r * 0.32, r * 1.05), 14), Color(bc.lightened(0.22), alpha))
			ci.draw_arc(bp, r * 0.78, PI * 1.15, PI * 1.55, 8, Color(1, 1, 1, 0.22 * alpha), 2.0)
			var thr = bp + Vector2(0, r * 1.35)
			var bk = thr + Vector2(0, 14)
			ci.draw_line(thr + Vector2(-r * 0.26, 0), bk + Vector2(-5, 0), sil, 1.0)
			ci.draw_line(thr + Vector2(r * 0.26, 0), bk + Vector2(5, 0), sil, 1.0)
			# a tiny passenger peeking over the basket; waves when poked
			var head: Vector2 = bk + Vector2(2, -3)
			ci.draw_circle(head, 3.2, sil)
			if ba < 2.4 or rk < 13.0:
				var wv := sin(t * 14.0) * 0.6
				ci.draw_line(head + Vector2(2, 1), head + Vector2(2, 1) + Vector2.from_angle(-PI * 0.5 + wv) * 7.0, sil, 1.6)
			ci.draw_rect(Rect2(bk.x - 6, bk.y, 12, 9), sil)
			if fmod(t * 0.7 + b, 3.0) < 0.6 or ba < 0.6 or rk < 2.5:
				var fl: float = 3.5 + (6.0 if (ba < 0.6 or rk < 2.5) else 0.0) * (0.7 + 0.3 * sin(t * 30.0))
				ci.draw_circle(thr + Vector2(0, 3), fl, Color(_warm(1.8), alpha))
			if alpha > 0.5:
				_hits_air.append({"kind": "balloon", "key": bkey, "rect": Rect2(bp - Vector2(r, r), Vector2(r * 2.0, r * 2.35 + 23.0)), "basket": bk})
	if air.has("birds"):
		var fx = fposmod(-t * 40.0 + 300.0, w + 600.0) - 300.0
		var fy = h * 0.22 + sin(t * 0.3) * 20.0
		var sa := _age("birds")
		var scat := sin(clampf(sa / 3.2, 0.0, 1.0) * PI) if sa < 3.2 else 0.0
		if alpha > 0.5:
			_hits_air.append({"kind": "birds", "key": "birds", "rect": Rect2(Vector2(w - fx - 12.0, fy - 14.0), Vector2(90, 56))})
		for k in 7:
			var row = absi(k - 3)
			var bp = Vector2(w - fx + row * 22.0, fy + row * 12.0 + (k - 3) * 2.0)
			if scat > 0.0:
				var ang := -PI * 0.5 + (k - 3) * 0.42 + sin(k * 3.1) * 0.2
				bp += Vector2.from_angle(ang) * 240.0 * scat
			var flap = sin(t * (8.0 + 14.0 * scat) + k) * 5.0
			ci.draw_polyline(PackedVector2Array([bp + Vector2(-8, -flap), bp, bp + Vector2(8, -flap)]), sil, 2.0, Art.AA)
