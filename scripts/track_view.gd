extends Node2D
## World-space course rendering: ground, holes, obstacles, motes, letters.

const Art = preload("res://scripts/art.gd")
const Painter = preload("res://scripts/painter.gd")
enum { HURDLE, BEAM, GAP, WIDE_GAP, GATE, BELL, BLOOM, RESCUE }

var track
var sim
var pal: Dictionary = Art.biome(0)
var t = 0.0
var view_l = 0.0
var view_r = 1920.0
var kind_mode = false

var _base: Node2D
var _add: Node2D

const AMBER := Color(1.0, 0.72, 0.25)
const ROSE := Color(1.0, 0.35, 0.75)
const CYAN := Color(0.3, 1.0, 1.0)
const LEAF := Color(0.45, 1.0, 0.55)
const GOLD := Color(1.0, 0.85, 0.35)

func _ready() -> void:
	_base = Painter.new()
	_base.fn = _draw_base
	add_child(_base)
	_add = Painter.new()
	_add.fn = _draw_add
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = m
	_add.modulate = Color(1, 1, 1, 0.5)
	add_child(_add)

func refresh() -> void:
	_base.queue_redraw()
	_add.queue_redraw()

func _holes() -> Array:
	var hs: Array = []
	if track == null:
		return hs
	for o in track.obs:
		if o.x > view_r + 200.0:
			break
		if o.x + o.w < view_l - 200.0:
			continue
		if o.t in [GAP, WIDE_GAP, BELL, RESCUE] and not kind_mode:
			hs.append([o.x, o.x + o.w, o])
	return hs

# ------------------------------------------------------------------ base pass
func _draw_base(ci: Node2D) -> void:
	var gcol: Color = pal.ground
	var holes = _holes()
	var segs: Array = []
	var cur = view_l - 300.0
	for h in holes:
		if h[0] > cur:
			segs.append([cur, h[0]])
		cur = maxf(cur, h[1])
	segs.append([cur, view_r + 300.0])
	var band_top: Color = pal.layers[1].lerp(pal.fog, 0.30)
	var band_mid: Color = pal.layers[2].lerp(pal.layers[1], 0.35)
	var body: Color = gcol.lerp(pal.layers[2], 0.75)
	for s in segs:
		var a: float = s[0]
		var b: float = s[1]
		if b - a < 2.0:
			continue
		ci.draw_rect(Rect2(a, 0, b - a, 1400), body)
		ci.draw_polygon(PackedVector2Array([Vector2(a, 0), Vector2(b, 0), Vector2(b, 60), Vector2(a, 60)]),
			PackedColorArray([band_top, band_top, band_mid, band_mid]))
		ci.draw_polygon(PackedVector2Array([Vector2(a, 60), Vector2(b, 60), Vector2(b, 300), Vector2(a, 300)]),
			PackedColorArray([band_mid, band_mid, body, body]))
		if Art.Q >= 2:
			_strata(ci, a, b, gcol)
		_surface(ci, a, b, band_top)
		_tufts(ci, a, b, gcol)
	# holes: dark depth
	for h in holes:
		var a: float = h[0]
		var b: float = h[1]
		var deep := Color(0.0, 0.0, 0.01)
		ci.draw_polygon(PackedVector2Array([Vector2(a, -2), Vector2(b, -2), Vector2(b, 260), Vector2(a, 260)]),
			PackedColorArray([Color(deep, 0.35), Color(deep, 0.35), Color(deep, 1.0), Color(deep, 1.0)]))
		ci.draw_rect(Rect2(a, 260, b - a, 1200), deep)
	if track == null:
		return
	for o in track.obs:
		if o.x > view_r + 400.0:
			break
		var ext: float = (o.wall_x + o.wall_w - o.x) if o.t == BLOOM else o.w
		if o.x + ext < view_l - 600.0:
			continue
		match o.t:
			HURDLE: _hurdle(ci, o)
			BEAM: _beam(ci, o)
			GATE: _gate(ci, o)
			BELL: _bell(ci, o)
			BLOOM: _bloom(ci, o)
			RESCUE: _rescue(ci, o)
	if sim != null:
		for p in sim.planes:
			_plane(ci, Vector2(p.x, p.y), Vector2(p.vx, p.vy))

func _strata(ci: Node2D, a: float, b: float, gcol: Color) -> void:
	# embedded stones and roots give the ground body depth
	var c0 := int(maxf(a, view_l - 80.0) / 150.0)
	var c1 := int(minf(b, view_r + 80.0) / 150.0)
	var dark: Color = gcol.darkened(0.35)
	var lit: Color = pal.layers[2].lerp(pal.fog, 0.1)
	for c in range(c0, c1 + 1):
		var x: float = c * 150.0 + Art.hash01(c, 31) * 90.0
		if x < a + 30.0 or x > b - 30.0:
			continue
		var y: float = 50.0 + Art.hash01(c, 32) * 120.0
		var r := Vector2(26.0 + Art.hash01(c, 33) * 40.0, 12.0 + Art.hash01(c, 34) * 14.0)
		ci.draw_colored_polygon(Art.ellipse(Vector2(x, y), r, 16, Art.hash01(c, 35) * 0.4 - 0.2), dark)
		ci.draw_arc(Vector2(x, y), r.x * 0.9, PI * 1.15, PI * 1.85, 8, Color(lit, 0.5), 2.0, Art.AA)
		if Art.hash01(c, 36) < 0.45:
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(Vector2(x + k * 18.0, 16.0 + k * 14.0 + sin(k + c) * 6.0))
			ci.draw_polyline(pts, dark, 5.0, Art.AA)

## Each country has its own walking surface along the top of the ground:
## Greek stone paving, Bulgarian moss, a Danube boardwalk, Carpathian snow.
func _surface(ci: Node2D, a: float, b: float, band_top: Color) -> void:
	var x0 := maxf(a, view_l - 80.0)
	var x1 := minf(b, view_r + 80.0)
	if x1 - x0 < 4.0:
		return
	var kind: String = pal.get("surface", "")
	var rim: Color = pal.rim
	match kind:
		"pavers":
			var stone: Color = pal.layers[0].lerp(rim, 0.38)
			ci.draw_rect(Rect2(x0, -2, x1 - x0, 9), stone.lightened(0.1))
			var c0 := int(floor(x0 / 74.0))
			var c1 := int(ceil(x1 / 74.0))
			for c in range(c0, c1 + 1):
				var bx := maxf(c * 74.0 + 2.0, x0)
				var ex := minf(c * 74.0 + 72.0, x1)
				if ex - bx < 2.0:
					continue
				var sh := Art.hash01(c, 61) * 0.12
				ci.draw_rect(Rect2(bx, 8, ex - bx, 20), stone.darkened(0.05 + sh))
				if Art.Q >= 1:
					var off := 37.0 if c % 2 == 0 else 0.0
					var bx2 := maxf(c * 74.0 + 2.0 + off - 37.0, x0)
					var ex2 := minf(bx2 + 70.0, x1)
					if ex2 > bx2 + 2.0:
						ci.draw_rect(Rect2(bx2, 30, ex2 - bx2, 18), stone.darkened(0.22 + sh))
		"moss":
			var moss: Color = pal.layers[0].lerp(Color(0.40, 0.70, 0.46), 0.55)
			var pts := PackedVector2Array([Vector2(x0, -2), Vector2(x1, -2)])
			var c1 := int(x1 / 23.0)
			var c0 := int(x0 / 23.0) + 1
			pts.append(Vector2(x1, 6))
			for c in range(c1, c0 - 1, -1):
				var x := c * 23.0
				if x < x0 or x + 7.0 > x1:
					continue
				var d := 6.0 + Art.hash01(c, 71) * 16.0
				pts.append(Vector2(x + 7.0, 6.0))
				pts.append(Vector2(x, d))
			pts.append(Vector2(x0, 6))
			ci.draw_colored_polygon(pts, moss)
		"boards":
			var wood: Color = pal.layers[0].lerp(Color(0.72, 0.50, 0.42), 0.55)
			ci.draw_rect(Rect2(x0, -2, x1 - x0, 12), wood)
			ci.draw_rect(Rect2(x0, 10, x1 - x0, 6), wood.darkened(0.35))
			var c0 := int(floor(x0 / 34.0))
			var c1 := int(ceil(x1 / 34.0))
			if Art.Q >= 1:
				for c in range(c0, c1 + 1):
					var x := c * 34.0
					if x > x0 and x < x1:
						ci.draw_line(Vector2(x, -1), Vector2(x, 9), wood.darkened(0.3), 2.0)
			var p0 := int(floor(x0 / 170.0))
			var p1 := int(ceil(x1 / 170.0))
			for c in range(p0, p1 + 1):
				var x := c * 170.0 + 60.0
				if x > x0 + 10.0 and x < x1 - 10.0:
					ci.draw_rect(Rect2(x - 7, 16, 14, 150), wood.darkened(0.5))
		"snow":
			var snow := Color(0.90, 0.93, 1.0).lerp(pal.layers[0], 0.12)
			var pts := PackedVector2Array([Vector2(x0, -5), Vector2(x1, -5), Vector2(x1, 10)])
			var c1 := int(x1 / 29.0)
			var c0 := int(x0 / 29.0) + 1
			for c in range(c1, c0 - 1, -1):
				var x := c * 29.0
				if x < x0 or x + 10.0 > x1:
					continue
				var d := 13.0 + Art.hash01(c, 81) * 14.0
				pts.append(Vector2(x + 10.0, 10.0))
				pts.append(Vector2(x + 5.0, d))
				pts.append(Vector2(x, 10.0))
			pts.append(Vector2(x0, 10))
			ci.draw_colored_polygon(pts, snow)

## Grass along a ground segment as ONE zigzag polygon (was ~60 triangles).
func _tufts(ci: Node2D, a: float, b: float, gcol: Color) -> void:
	var x0 := maxf(a + 6.0, view_l - 50.0)
	var x1 := minf(b - 6.0, view_r + 50.0)
	if x1 - x0 < 20.0:
		return
	var pts := PackedVector2Array([Vector2(x0, 4)])
	var c0 := int(x0 / 17.0) + 1
	var c1 := int(x1 / 17.0)
	for c in range(c0, c1 + 1):
		var x := c * 17.0
		var h := 3.0 + Art.hash01(c, 4) * 15.0
		var sway := sin(t * 2.0 + c * 0.7) * 3.0
		pts.append(Vector2(x - 6.0, 1.0))
		pts.append(Vector2(x + sway, -h))
	pts.append(Vector2(x1, 1.0))
	pts.append(Vector2(x1, 4.0))
	ci.draw_colored_polygon(pts, gcol)

# Obstacles are solid, light "ceramic" shapes with an ink outline and a
# colour-coded band, so they read on any screen without relying on glow.
const INK := Color(0.04, 0.05, 0.09)

func _mat() -> Color:
	return pal.get("obstacle", Color(0.85, 0.82, 0.76))

func _solid(ci: Node2D, pts: PackedVector2Array, fill: Color, ink_w := 3.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var c := pts.duplicate()
	c.append(pts[0])
	ci.draw_polyline(c, INK, ink_w, Art.AA)

func _hurdle(ci: Node2D, o: Dictionary) -> void:
	var body := _mat()
	_solid(ci, Art.rrect(Rect2(o.x, -o.h, o.w, o.h + 4), 14.0), body)
	ci.draw_colored_polygon(Art.rrect(Rect2(o.x + 5, -o.h * 0.45, o.w - 10, o.h * 0.45 - 2), 8.0), body.darkened(0.18))
	ci.draw_colored_polygon(Art.rrect(Rect2(o.x + 6, -o.h + 6, o.w - 12, 10), 5.0), AMBER.darkened(0.05))
	var c := Vector2(o.x + o.w * 0.5, -o.h * 0.5)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-11, 6), c + Vector2(0, -6), c + Vector2(11, 6)]), INK, 4.0, Art.AA)

func _beam(ci: Node2D, o: Dictionary) -> void:
	var body := _mat()
	var bottom: float = -o.h
	var pillar := body.darkened(0.45)
	ci.draw_rect(Rect2(o.x + 18, bottom - 1400, 24, 1340), pillar)
	ci.draw_rect(Rect2(o.x + o.w - 42, bottom - 1400, 24, 1340), pillar)
	_solid(ci, Art.rrect(Rect2(o.x, bottom - 72, o.w, 72), 16.0), body)
	ci.draw_colored_polygon(Art.rrect(Rect2(o.x + 6, bottom - 18, o.w - 12, 12), 6.0), ROSE.darkened(0.1))
	for k in maxi(1, int(o.w / 120.0)):
		var c := Vector2(o.x + 60.0 + k * 120.0, bottom - 42)
		if c.x > o.x + o.w - 30.0:
			break
		ci.draw_polyline(PackedVector2Array([c + Vector2(-11, -6), c + Vector2(0, 6), c + Vector2(11, -6)]), INK, 4.0, Art.AA)

func _gate(ci: Node2D, o: Dictionary) -> void:
	var body := _mat()
	var x: float = o.x
	_solid(ci, Art.rrect(Rect2(x - 10, -o.h, 14, o.h), 6.0), body.darkened(0.1))
	_solid(ci, Art.rrect(Rect2(x + o.w - 4, -o.h, 14, o.h), 6.0), body.darkened(0.1))
	var f = clampf(o.open_t / 0.45, 0.0, 1.0)
	var swing = ease(f, 0.4) * 1.45
	var hinge = Vector2(x + o.w * 0.5, -o.h)
	ci.draw_set_transform(hinge, -swing, Vector2.ONE)
	_solid(ci, Art.rrect(Rect2(-o.w * 0.5 + 4, 4, o.w - 8, o.h - 10), 8.0), body)
	var hub = Vector2(0, o.h * 0.55)
	var spin = t * (0.8 + f * 14.0)
	for k in 4:
		var a = spin + TAU * k / 4.0
		var tip = hub + Vector2(cos(a), sin(a)) * 19.0
		_solid(ci, PackedVector2Array([hub, tip, hub + Vector2(cos(a + 0.9), sin(a + 0.9)) * 14.0]), LEAF.darkened(0.15), 2.0)
	ci.draw_circle(hub, 4.0, INK)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _bell(ci: Node2D, o: Dictionary) -> void:
	var body := _mat()
	var bp = Vector2(o.bell_x, o.bell_y)
	ci.draw_line(Vector2(o.bell_x, 0), bp + Vector2(0, -40), INK, 14.0)
	ci.draw_line(Vector2(o.bell_x, 0), bp + Vector2(0, -40), body.darkened(0.2), 9.0)
	ci.draw_line(bp + Vector2(-52, -40), bp + Vector2(32, -40), INK, 12.0)
	ci.draw_line(bp + Vector2(-50, -40), bp + Vector2(30, -40), body.darkened(0.2), 7.0)
	var swing = sin(o.open_t * 18.0) * exp(-o.open_t * 2.5) * 0.6 if o.open else sin(t * 1.6) * 0.06
	ci.draw_set_transform(bp + Vector2(-20, -40), swing, Vector2.ONE)
	_solid(ci, PackedVector2Array([Vector2(-14, 4), Vector2(14, 4), Vector2(28, 48), Vector2(-28, 48)]), GOLD.darkened(0.08))
	ci.draw_circle(Vector2(0, 52), 7, INK)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var f = clampf(o.open_t / 0.6, 0.0, 1.0) if o.open else 0.0
	var ang = lerpf(1.35, 0.0, ease(f, 0.35))
	var half: float = o.w * 0.5 + 4.0
	ci.draw_set_transform(Vector2(o.x, 0), -ang, Vector2.ONE)
	_solid(ci, PackedVector2Array([Vector2(0, -6), Vector2(half, -6), Vector2(half, 12), Vector2(0, 12)]), body)
	for k in int(half / 36.0):
		ci.draw_line(Vector2(k * 36.0 + 18, -6), Vector2(k * 36.0 + 18, 12), INK, 2.0)
	ci.draw_set_transform(Vector2(o.x + o.w, 0), ang, Vector2.ONE)
	_solid(ci, PackedVector2Array([Vector2(-half, -6), Vector2(0, -6), Vector2(0, 12), Vector2(-half, 12)]), body)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _bloom(ci: Node2D, o: Dictionary) -> void:
	var body := _mat()
	var c = Vector2(o.x + o.w * 0.5, -6)
	for k in 6:
		var a := PI + PI * (float(k) + 0.5) / 6.0
		_solid(ci, Art.ellipse(c + Vector2(cos(a) * 44, sin(a) * 10 + 2), Vector2(30, 11), 14, a), ROSE.lerp(Color(1, 1, 1), 0.25), 2.0)
	_solid(ci, Art.ellipse(c, Vector2(16, 8), 14), GOLD, 2.0)
	var wx: float = o.wall_x
	_solid(ci, PackedVector2Array([Vector2(wx, 2), Vector2(wx + 6, -o.wall_h + 30), Vector2(wx + o.wall_w * 0.5, -o.wall_h),
		Vector2(wx + o.wall_w - 4, -o.wall_h + 40), Vector2(wx + o.wall_w, 2)]), body.lerp(pal.accent, 0.25))
	ci.draw_line(Vector2(wx + o.wall_w * 0.5, -o.wall_h + 8), Vector2(wx + o.wall_w * 0.5, -10), body.darkened(0.2), 3.0)

func _rescue(ci: Node2D, o: Dictionary) -> void:
	var body := _mat().darkened(0.15)
	var ft: float = o.get("fall_t", -1.0)
	var n = int(o.w / 60.0)
	for k in n:
		var px: float = o.x + k * 60.0
		var drop = 0.0
		var rot = 0.0
		if ft >= 0.0:
			var tk = maxf(ft - k * 0.035, 0.0)
			drop = 900.0 * tk * tk
			rot = tk * (2.0 if k % 2 == 0 else -2.4)
		ci.draw_set_transform(Vector2(px + 28, 4 + drop), rot, Vector2.ONE)
		_solid(ci, PackedVector2Array([Vector2(-28, -8), Vector2(26, -8), Vector2(26, 8), Vector2(-28, 8)]), body, 2.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ft >= 0.0:
		for k in 7:
			var tk = ft * 1.6 - k * 0.12
			if tk < 0.0:
				continue
			var cx: float = o.x + 200.0 + k * (o.w / 8.0)
			var cy = -900.0 + tk * tk * 1100.0
			ci.draw_set_transform(Vector2(cx, cy), tk * 3.0 + k, Vector2.ONE)
			_solid(ci, Art.rrect(Rect2(-40, -40, 80, 80), 14.0), body.lightened(0.1))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _plane(ci: Node2D, p: Vector2, v: Vector2) -> void:
	var a = v.angle()
	ci.draw_set_transform(p, a, Vector2.ONE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(-12, -9), Vector2(-6, 0), Vector2(-12, 9)]), Color(0.96, 0.97, 1.0))
	ci.draw_line(Vector2(16, 0), Vector2(-6, 0), Color(0.6, 0.7, 0.85), 1.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ------------------------------------------------------------------ light pass
func _draw_add(ci: Node2D) -> void:
	var rim: Color = pal.rim
	var holes = _holes()
	# ground rim light
	var cur = view_l - 300.0
	var edges: Array = []
	for h in holes:
		if h[0] > cur:
			edges.append([cur, h[0]])
		cur = maxf(cur, h[1])
	edges.append([cur, view_r + 300.0])
	for e in edges:
		if e[1] - e[0] < 2.0:
			continue
		ci.draw_line(Vector2(e[0], 0), Vector2(e[1], 0), Art.hdr(Color(rim, 0.9), 1.25), 3.0)
		ci.draw_polygon(PackedVector2Array([Vector2(e[0], -26), Vector2(e[1], -26), Vector2(e[1], 2), Vector2(e[0], 2)]),
			PackedColorArray([Color(rim, 0.0), Color(rim, 0.0), Color(rim, 0.12), Color(rim, 0.12)]))
		# glow flowers
		var c0 = int(maxf(e[0], view_l) / 90.0)
		var c1 = int(minf(e[1], view_r) / 90.0)
		for c in range(c0, c1 + 1):
			if Art.hash01(c, 77) < 0.35:
				var x = c * 90.0 + Art.hash01(c, 78) * 60.0
				if x > e[0] + 10.0 and x < e[1] - 10.0:
					var pulse = 0.6 + 0.4 * sin(t * 2.2 + c)
					var fc: Color = pal.mote
					Art.glow(ci, Vector2(x, -10), 16.0, Color(fc, 0.45 * pulse), 3)
					ci.draw_circle(Vector2(x, -10), 2.2, Art.hdr(fc, 2.0 * pulse))
	for e in (edges if Art.Q >= 1 else []):
		var c0b := int(maxf(e[0], view_l) / 210.0)
		var c1b := int(minf(e[1], view_r) / 210.0)
		for c in range(c0b, c1b + 1):
			var gx: float = c * 210.0 + Art.hash01(c, 61) * 120.0
			if gx < e[0] + 30.0 or gx > e[1] - 30.0 or Art.hash01(c, 62) > 0.5:
				continue
			var gy: float = 70.0 + Art.hash01(c, 63) * 140.0
			var pulse2: float = 0.6 + 0.4 * sin(t * 1.5 + c * 2.0)
			var gc: Color = pal.accent if Art.hash01(c, 64) < 0.5 else pal.mote
			Art.glow(ci, Vector2(gx, gy), 34.0, Color(gc, 0.22 * pulse2), 3)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(gx - 5, gy + 6), Vector2(gx, gy - 12), Vector2(gx + 5, gy + 6)]), Art.hdr(Color(gc, 0.8 * pulse2), 1.3))
	for h in holes:
		ci.draw_circle(Vector2(h[0], 0), 4.0, Art.hdr(rim, 1.6))
		ci.draw_circle(Vector2(h[1], 0), 4.0, Art.hdr(rim, 1.6))
		for ex in [h[0] - 2.0, h[1] + 2.0]:
			ci.draw_polygon(PackedVector2Array([Vector2(ex - 2, 0), Vector2(ex + 2, 0), Vector2(ex + 2, 160), Vector2(ex - 2, 160)]),
				PackedColorArray([Color(rim, 0.6), Color(rim, 0.6), Color(rim, 0.0), Color(rim, 0.0)]))
		# mist rising out of the depth
		var o: Dictionary = h[2]
		for k in [2, 4, 8][Art.Q]:
			var mx: float = h[0] + Art.hash01(o.seed, k) * (h[1] - h[0])
			var my = 260.0 - fposmod(t * 40.0 + k * 50.0, 260.0)
			Art.glow(ci, Vector2(mx, my), 40.0, Color(pal.fog, 0.10), 3)
		if o.t == WIDE_GAP:
			_updraft(ci, o)
	if track == null:
		return
	for o in track.obs:
		if o.x > view_r + 400.0:
			break
		var ext: float = (o.wall_x + o.wall_w - o.x) if o.t == BLOOM else o.w
		if o.x + ext < view_l - 600.0:
			continue
		match o.t:
			HURDLE:
				var c = AMBER
				var rr := Art.rrect(Rect2(o.x, -o.h, o.w, o.h + 4), 14.0)
				rr.append(rr[0])
				ci.draw_polyline(rr, Color(c, 0.45), 2.0, Art.AA)
				ci.draw_polygon(PackedVector2Array([Vector2(o.x + 6, -o.h + 6), Vector2(o.x + o.w - 6, -o.h + 6), Vector2(o.x + o.w - 6, 0), Vector2(o.x + 6, 0)]),
					PackedColorArray([Color(c, 0.22), Color(c, 0.22), Color(c, 0.0), Color(c, 0.0)]))
				ci.draw_line(Vector2(o.x + 10, -o.h + 3), Vector2(o.x + o.w - 10, -o.h + 3), Art.hdr(c, 1.7), 4.0)
				_chevron(ci, Vector2(o.x + o.w * 0.5, -o.h - 28), -1.0, c)
			BEAM:
				var br := Art.rrect(Rect2(o.x, -o.h - 70, o.w, 70), 16.0)
				br.append(br[0])
				ci.draw_polyline(br, Color(ROSE, 0.4), 2.0, Art.AA)
				ci.draw_polygon(PackedVector2Array([Vector2(o.x + 10, -o.h - 4), Vector2(o.x + o.w - 10, -o.h - 4), Vector2(o.x + o.w - 10, -o.h + 40), Vector2(o.x + 10, -o.h + 40)]),
					PackedColorArray([Color(ROSE, 0.16), Color(ROSE, 0.16), Color(ROSE, 0.0), Color(ROSE, 0.0)]))
				ci.draw_line(Vector2(o.x + 14, -o.h - 3), Vector2(o.x + o.w - 14, -o.h - 3), Art.hdr(ROSE, 1.6), 4.0)
				for k in maxi(1, int(o.w / 160.0)):
					_chevron(ci, Vector2(o.x + 80 + k * 160.0, -o.h - 34), 1.0, ROSE)
			GAP:
				pass
			GATE:
				if not o.open:
					var hub = Vector2(o.x + o.w * 0.5, -o.h * 0.45)
					Art.glow(ci, hub, 70.0, Color(LEAF, 0.35), 4)
					_spiral(ci, hub + Vector2(-80, 0), LEAF)
				ci.draw_line(Vector2(o.x - 6, -o.h), Vector2(o.x - 6, 0), Color(LEAF, 0.35), 2.0)
				ci.draw_line(Vector2(o.x + o.w + 6, -o.h), Vector2(o.x + o.w + 6, 0), Color(LEAF, 0.35), 2.0)
				if not o.open:
					ci.draw_rect(Rect2(o.x, -o.h + 6, o.w, o.h - 6), Color(LEAF, 0.08))
			BELL:
				var bp = Vector2(o.bell_x - 20, o.bell_y + 26)
				var pulse = 0.6 + 0.4 * sin(t * 4.0)
				if not o.open:
					ci.draw_arc(bp, 54.0 + pulse * 8.0, 0.0, TAU, 40, Art.hdr(Color(GOLD, 0.8), 1.5), 3.0, Art.AA)
					ci.draw_arc(bp, 34.0, 0.0, TAU, 32, Color(GOLD, 0.35), 2.0, Art.AA)
					Art.glow(ci, bp, 60.0, Color(GOLD, 0.3), 4)
				else:
					for k in 3:
						var rr: float = fposmod(o.open_t * 260.0 + k * 90.0, 270.0)
						ci.draw_arc(bp, rr, 0.0, TAU, 48, Color(GOLD, 0.6 * (1.0 - rr / 270.0)), 4.0, Art.AA)
			BLOOM:
				var c2 = Vector2(o.x + o.w * 0.5, -10)
				var pulse2 = 0.7 + 0.3 * sin(t * 3.0)
				for k in 6:
					var a = TAU * k / 6.0 + t * 0.3
					ci.draw_colored_polygon(Art.ellipse(c2 + Vector2(cos(a) * 36, sin(a) * 9 - 8), Vector2(30, 9), 14, a), Color(ROSE, 0.35 * pulse2))
				Art.glow(ci, c2 + Vector2(0, -10), 80.0, Color(ROSE, 0.4), 4)
				ci.draw_circle(c2 + Vector2(0, -12), 7.0, Art.hdr(GOLD, 2.0))
				_chevron(ci, c2 + Vector2(0, -130), 1.0, ROSE)
				_chevron(ci, c2 + Vector2(0, -100), 1.0, ROSE)
				ci.draw_line(Vector2(o.wall_x + o.wall_w * 0.5, -o.wall_h), Vector2(o.wall_x + 6, -o.wall_h + 30), Art.hdr(Color(pal.accent, 0.8), 1.3), 3.0)
			RESCUE:
				if o.get("fall_t", -1.0) < 0.0:
					for k in int(o.w / 120.0):
						var blink = 1.0 if int(t * 3.0 + k) % 2 == 0 else 0.25
						ci.draw_circle(Vector2(o.x + 30 + k * 120.0, -16), 4.0, Art.hdr(Color(1.0, 0.4, 0.3, blink), 1.6))
	# motes
	for m in track.motes:
		if m.x > view_r + 50.0:
			break
		if m.taken or m.x < view_l - 50.0:
			continue
		var bob = sin(t * 3.0 + m.x * 0.01) * 5.0
		var p = Vector2(m.x, m.y + bob)
		Art.glow(ci, p, 26.0, Color(pal.mote, 0.5), 4)
		ci.draw_circle(p, 5.0, Art.hdr(pal.mote, 2.2))
	if sim != null:
		for p in sim.planes:
			var pv = Vector2(p.vx, p.vy).normalized()
			ci.draw_line(Vector2(p.x, p.y), Vector2(p.x, p.y) - pv * 70.0, Color(1, 1, 1, 0.25), 3.0)

func _chevron(ci: Node2D, p: Vector2, dir: float, c: Color) -> void:
	var pts = PackedVector2Array([p + Vector2(-14, 8 * -dir * -1.0), p + Vector2(0, -8 * -dir), p + Vector2(14, 8 * dir * -1.0 * -1.0)])
	pts = PackedVector2Array([p + Vector2(-14, -7 * dir), p + Vector2(0, 7 * dir), p + Vector2(14, -7 * dir)])
	var bob = sin(t * 5.0) * 3.0 * dir
	for k in pts.size():
		pts[k] += Vector2(0, bob)
	ci.draw_polyline(pts, Art.hdr(c, 1.8), 4.0, Art.AA)

func _spiral(ci: Node2D, p: Vector2, c: Color) -> void:
	var pts = PackedVector2Array()
	for k in 18:
		var a = k * 0.55 - t * 3.0
		pts.append(p + Vector2(cos(a), sin(a)) * (3.0 + k * 1.3))
	ci.draw_polyline(pts, Art.hdr(Color(c, 0.9), 1.5), 3.0, Art.AA)

func _updraft(ci: Node2D, o: Dictionary) -> void:
	for k in 7:
		var x: float = o.x + o.w * (0.12 + 0.13 * k)
		var y = -fposmod(t * 160.0 + k * 70.0, 320.0) + 40.0
		var a = 1.0 - (-y + 40.0) / 360.0
		ci.draw_arc(Vector2(x, y), 14.0, PI * 1.1, PI * 1.9, 10, Art.hdr(Color(CYAN, 0.55 * a), 1.3), 3.0, Art.AA)
