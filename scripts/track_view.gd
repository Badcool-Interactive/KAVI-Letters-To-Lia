extends Node2D
## World-space course rendering: ground, holes, obstacles, motes, letters.

const Art = preload("res://scripts/art.gd")
const Painter = preload("res://scripts/painter.gd")
enum { HURDLE, BEAM, GAP, WIDE_GAP, GATE, BELL, BLOOM, RESCUE, CART, FLOCK, TOWER }

var track
var sim
var pal: Dictionary = Art.biome(0)
var t = 0.0
var view_l = 0.0
var view_r = 1920.0
var kind_mode = false
var letter_col := Color(0.96, 0.97, 1.0)   # Garage letter colour (0.8.25)
var sun_world_x := 1.0e9   # set by main each frame: obstacles light the side facing the sun
var sun_k := 0.5

var _base: Node2D
var _add: Node2D

const AMBER := Color(1.0, 0.72, 0.25)
const ROSE := Color(1.0, 0.35, 0.75)
const CYAN := Color(0.3, 1.0, 1.0)
const LEAF := Color(0.45, 1.0, 0.55)
const GOLD := Color(1.0, 0.85, 0.35)

func _ready() -> void:
	_base = Painter.new()
	_base.tag = "track"
	_base.fn = _draw_base
	_base.material = Art.grade_material(false)
	add_child(_base)
	_add = Painter.new()
	_add.tag = "track_add"
	_add.fn = _draw_add
	_add.material = Art.grade_material(true)
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
	# 0.8.15: the ground is the nearest hill, so it takes the world's colours
	# (lit near the top, deepening below) instead of a flat near-black slab
	var band_top: Color = pal.layers[1].lerp(pal.rim, 0.16).lerp(pal.fog, 0.12)
	var band_mid: Color = pal.layers[2].lerp(pal.layers[1], 0.55)
	var body: Color = pal.layers[2].lerp(pal.layers[1], 0.12)
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
		# depth: the ground body darkens as it goes down (0.8.15)
		var deep_c: Color = body.darkened(0.45)
		ci.draw_polygon(PackedVector2Array([Vector2(a, 300), Vector2(b, 300), Vector2(b, 1000), Vector2(a, 1000)]),
			PackedColorArray([body, body, deep_c, deep_c]))
		if Art.Q >= 1:
			# soft soil strata catching a little light
			var lit: Color = band_top
			for k in 2:
				var yy := 96.0 + k * 74.0
				var pts := PackedVector2Array()
				var x := maxf(a, view_l - 60.0)
				var xe := minf(b, view_r + 60.0)
				while x <= xe:
					pts.append(Vector2(x, yy + sin(x * 0.006 + k * 1.7) * 9.0 + sin(x * 0.017 + k) * 3.0))
					x += 48.0
				if pts.size() > 1:
					ci.draw_polyline(pts, Color(lit, 0.10 - k * 0.025), 3.0 - k * 0.6, Art.AA)
		if Art.Q >= 1:
			_ground_detail(ci, a, b, body)
		if Art.Q >= 1 and pal.get("surface", "") in ["moss", "pavers"]:
			_strata(ci, a, b, gcol)
		_surface(ci, a, b, band_top)
		# soft contact shadow under the walking surface
		var cs := Color(0.0, 0.01, 0.03)
		ci.draw_polygon(PackedVector2Array([Vector2(a, 12), Vector2(b, 12), Vector2(b, 74), Vector2(a, 74)]),
			PackedColorArray([Color(cs, 0.28), Color(cs, 0.28), Color(cs, 0.0), Color(cs, 0.0)]))
		_grass(ci, a, b, gcol)
	# holes (0.8.18): each country's own depth instead of a black box: sea
	# below the Greek path, a fern ravine, the river, an icy crevasse; with
	# rocky lips at both edges
	for h in holes:
		_hole(ci, h[0], h[1], band_mid)
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
			CART: _cart(ci, o)
			FLOCK: _flock(ci, o)
			TOWER: _tower(ci, o)
	if sim != null:
		for p in sim.planes:
			_plane(ci, Vector2(p.x, p.y), Vector2(p.vx, p.vy))

func _strata(ci: Node2D, a: float, b: float, gcol: Color) -> void:
	# soft stones, pebbles and roots in the ground body: tinted from the body
	# colour (never near-black, which read as holes) and varied per cell
	var c0 := int(maxf(a, view_l - 80.0) / 130.0)
	var c1 := int(minf(b, view_r + 80.0) / 130.0)
	var body: Color = gcol.lerp(pal.layers[2], 0.75)
	var stone: Color = body.lerp(pal.layers[1], 0.30)
	var root: Color = body.darkened(0.16)
	var lit: Color = pal.layers[2].lerp(pal.fog, 0.25)
	for c in range(c0, c1 + 1):
		var x: float = c * 130.0 + Art.hash01(c, 31) * 100.0
		if x < a + 30.0 or x > b - 30.0:
			continue
		var y: float = 60.0 + Art.hash01(c, 32) * 140.0
		var kind := Art.hash01(c, 37)
		if kind < 0.40:
			var r := Vector2(16.0 + Art.hash01(c, 33) * 34.0, 9.0 + Art.hash01(c, 34) * 12.0)
			ci.draw_colored_polygon(Art.ellipse(Vector2(x, y), r, 14, Art.hash01(c, 35) * 0.5 - 0.25), Color(stone, 0.75))
			ci.draw_arc(Vector2(x, y), r.x * 0.8, PI * 1.2, PI * 1.8, 8, Color(lit, 0.35), 2.0, Art.AA)
		elif kind < 0.70:
			for k in 3 + int(Art.hash01(c, 38) * 3.0):
				var pp := Vector2(x + (Art.hash01(c, 50 + k) - 0.5) * 70.0, y + (Art.hash01(c, 60 + k) - 0.5) * 30.0)
				ci.draw_circle(pp, 3.0 + Art.hash01(c, 70 + k) * 6.0, Color(stone, 0.6))
		elif kind < 0.88:
			var pts := PackedVector2Array()
			var dir := 1.0 if Art.hash01(c, 39) < 0.5 else -1.0
			for k in 6:
				pts.append(Vector2(x + dir * k * (12.0 + Art.hash01(c, 80 + k) * 8.0), 10.0 + k * 13.0 + sin(k * 1.3 + c) * 5.0))
			ci.draw_polyline(pts, Color(root, 0.7), 4.0 - Art.hash01(c, 40) * 1.5, Art.AA)
			ci.draw_line(pts[3], pts[3] + Vector2(-dir * 16.0, 14.0), Color(root, 0.6), 2.5, Art.AA)

## What is under the road differs by country: a Greek stone retaining wall,
## dark river water below the Danube boardwalk, roots and glowing mushrooms in
## the Bulgarian forest, layered snow and ice in the Carpathians.
func _ground_detail(ci: Node2D, a: float, b: float, body: Color) -> void:
	var x0 := maxf(a, view_l - 80.0)
	var x1 := minf(b, view_r + 80.0)
	if x1 - x0 < 8.0:
		return
	var kind: String = pal.get("surface", "")
	if surf_seam < INF and x0 < surf_seam:
		kind = surf_from if x1 <= surf_seam else kind
	match kind:
		"pavers":
			# big dressed stones with mortar lines, a little lighter at the top
			var stone: Color = body.lerp(pal.layers[1], 0.35)
			for row in 4:
				var y := 40.0 + row * 46.0
				var bw := 150.0 - row * 12.0
				var shift := (row % 2) * bw * 0.5
				var c0 := int(floor((x0 - shift) / bw))
				var c1 := int(ceil((x1 - shift) / bw))
				for c in range(c0, c1 + 1):
					var bx := c * bw + shift
					var l := maxf(bx + 3.0, x0)
					var r := minf(bx + bw - 3.0, x1)
					if r - l < 6.0:
						continue
					var shade := Art.hash01(c, 300 + row) * 0.12
					ci.draw_colored_polygon(Art.rrect(Rect2(l, y, r - l, 40.0), 6.0), Color(stone.darkened(shade + row * 0.08), 0.85 - row * 0.15))
		"boards":
			# river water under the boardwalk: dark, with drifting ripples
			var wtop: Color = pal.sky[2].lerp(pal.layers[2], 0.7)
			var wbot: Color = pal.layers[2].darkened(0.5)
			ci.draw_polygon(PackedVector2Array([Vector2(x0, 34), Vector2(x1, 34), Vector2(x1, 320), Vector2(x0, 320)]),
				PackedColorArray([wtop, wtop, wbot, wbot]))
			for k in 6:
				var y := 50.0 + k * 34.0
				var step := 220.0 + k * 40.0
				var off: float = fposmod(t * (18.0 + k * 6.0) + k * 97.0, step)
				var x: float = floor(x0 / step) * step - off
				while x < x1:
					if x + 60.0 > x0:
						ci.draw_line(Vector2(maxf(x, x0), y), Vector2(minf(x + 50.0 + k * 8.0, x1), y), Color(pal.rim, 0.10 - k * 0.012), 2.0)
					x += step
		"moss":
			# roots and a few glowing mushrooms
			var root: Color = body.darkened(0.2)
			var c0 := int(floor(x0 / 260.0))
			var c1 := int(ceil(x1 / 260.0))
			for c in range(c0, c1 + 1):
				var x: float = c * 260.0 + Art.hash01(c, 401) * 140.0
				if x < x0 + 20.0 or x > x1 - 20.0:
					continue
				var pts := PackedVector2Array()
				for k in 7:
					pts.append(Vector2(x + sin(k * 1.1 + c) * 16.0 + k * 6.0, 8.0 + k * 22.0))
				ci.draw_polyline(pts, Color(root, 0.8), 6.0 - Art.hash01(c, 402) * 2.0, Art.AA)
				if Art.hash01(c, 403) < 0.45:
					var m := Vector2(x + 26.0, 58.0 + Art.hash01(c, 404) * 50.0)
					ci.draw_line(m, m + Vector2(0, 12), Color(body.lightened(0.15), 0.9), 3.0)
					ci.draw_colored_polygon(Art.ellipse(m, Vector2(9, 5), 12), Art.hdr(Color(pal.mote, 0.85), 1.15))
		"snow":
			# packed snow layers with icy blue streaks
			var sn := Color(0.86, 0.90, 1.0).lerp(pal.layers[1], 0.55)
			for k in 3:
				var y := 30.0 + k * 40.0
				var pts := PackedVector2Array()
				var x := x0
				while x <= x1:
					pts.append(Vector2(x, y + sin(x * 0.01 + k * 2.0) * 6.0))
					x += 40.0
				pts.append(Vector2(x1, y + sin(x1 * 0.01 + k * 2.0) * 6.0))
				ci.draw_polyline(pts, Color(sn, 0.35 - k * 0.09), 6.0 - k, Art.AA)

## Each country has its own walking surface along the top of the ground:
## Greek stone paving, Bulgarian moss, a Danube boardwalk, Carpathian snow.
## World transitions: the old country's walking surface continues up to a
## seam in world space placed just off-screen right; the new one starts there.
var surf_from := ""
var surf_to := ""
var surf_seam := INF

func begin_transition(from_kind: String, to_kind: String, seam_x: float) -> void:
	surf_from = from_kind
	surf_to = to_kind
	surf_seam = seam_x

func end_transition() -> void:
	surf_from = ""
	surf_seam = INF

func _surface(ci: Node2D, a: float, b: float, band_top: Color) -> void:
	if surf_seam < INF:
		if surf_seam < view_l - 400.0:
			end_transition()
		else:
			if a < surf_seam:
				_surface_kind(ci, a, minf(b, surf_seam), band_top, surf_from)
			if b > surf_seam:
				_surface_kind(ci, maxf(a, surf_seam), b, band_top, surf_to)
			return
	_surface_kind(ci, a, b, band_top, pal.get("surface", ""))

func _surface_kind(ci: Node2D, a: float, b: float, band_top: Color, kind: String) -> void:
	var x0 := maxf(a, view_l - 80.0)
	var x1 := minf(b, view_r + 80.0)
	if x1 - x0 < 4.0:
		return
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

## Layered grass (0.8.15): a darker back row and a sunlit front row, each ONE
## polygon, leaning together in the breeze, plus small wildflowers that
## belong to each country (Greek poppies, forest bluebells, Danube buttercups;
## frost glints on the Carpathian snow).
const FLOWERS := {"pavers": [Color(0.92, 0.26, 0.22), Color(1.0, 0.95, 0.88)], "moss": [Color(0.55, 0.62, 1.0), Color(0.95, 0.92, 1.0)],
	"boards": [Color(1.0, 0.86, 0.30), Color(1.0, 1.0, 0.95)], "snow": []}

## Grass as separate blade triangles plus a thin base strip, one draw call.
## (0.8.23: it was one zigzag outline; when blades leaned past each other the
## outline couldn't be triangulated and the whole row vanished for a frame.)
func _grass_row(ci: Node2D, x0: float, x1: float, period: float, hmin: float, hmax: float, col: Color, seed: int) -> void:
	var v := PackedVector2Array([Vector2(x0, 1.0), Vector2(x1, 1.0), Vector2(x1, 5.0), Vector2(x0, 5.0)])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var c0 := int(x0 / period) + 1
	var c1 := int(x1 / period)
	for c in range(c0, c1 + 1):
		var x := c * period + Art.hash01(c, seed) * period * 0.4
		if x - period * 0.42 < x0 or x >= x1:
			continue
		var h := hmin + Art.hash01(c, seed + 1) * (hmax - hmin)
		var lean := sin(t * 1.7 + x * 0.012) * h * 0.28 + (Art.hash01(c, seed + 2) - 0.5) * h * 0.4
		var i := v.size()
		v.append_array([Vector2(x - period * 0.42, 2.0), Vector2(x + period * 0.12, 2.0), Vector2(x + lean, -h)])
		idx.append_array([i, i + 1, i + 2])
	# drawn as batched primitives (0.8.27; see world_view._b_flush)
	var pc := PackedColorArray([col])
	var none := PackedVector2Array()
	ci.draw_primitive(PackedVector2Array([v[0], v[1], v[2], v[3]]), pc, none)
	var p3 := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var i := 6
	while i < idx.size():
		p3[0] = v[idx[i]]
		p3[1] = v[idx[i + 1]]
		p3[2] = v[idx[i + 2]]
		ci.draw_primitive(p3, pc, none)
		i += 3

func _grass(ci: Node2D, a: float, b: float, gcol: Color) -> void:
	var x0 := maxf(a + 6.0, view_l - 50.0)
	var x1 := minf(b - 6.0, view_r + 50.0)
	if x1 - x0 < 20.0:
		return
	var kind: String = pal.get("surface", "")
	var back_g: Color = pal.layers[2].lerp(pal.layers[1], 0.35)
	var front_g: Color = pal.layers[1].lerp(pal.rim, 0.30)
	if kind == "snow":
		back_g = back_g.lerp(Color(0.85, 0.9, 1.0), 0.25)
		front_g = front_g.lerp(Color(0.92, 0.95, 1.0), 0.35)
	_grass_row(ci, x0, x1, 12.0, 7.0, 21.0, back_g, 4)
	_grass_row(ci, x0, x1, 16.0, 4.0, 13.0, front_g, 14)
	var cols: Array = FLOWERS.get(kind, [])
	var stems := PackedVector2Array()
	var step := 84.0
	var c0 := int(x0 / step) + 1
	var c1 := int(x1 / step)
	for c in range(c0, c1 + 1):
		if Art.hash01(c, 91) > [0.14, 0.28, 0.34][Art.Q]:
			continue
		var x := c * step + Art.hash01(c, 92) * step * 0.7
		if x < x0 + 8.0 or x > x1 - 8.0:
			continue
		var h := 10.0 + Art.hash01(c, 93) * 12.0
		var tip := Vector2(x + sin(t * 1.7 + x * 0.012) * h * 0.25, -h)
		if cols.is_empty():
			# frost glint on snow
			var gl := 0.5 + 0.5 * sin(t * 3.0 + c * 1.7)
			ci.draw_line(Vector2(x - 3, -4), Vector2(x + 3, -4), Color(1, 1, 1, 0.6 * gl), 1.5)
			ci.draw_line(Vector2(x, -7), Vector2(x, -1), Color(1, 1, 1, 0.6 * gl), 1.5)
			continue
		stems.append(Vector2(x, 2))
		stems.append(tip)
		var fc: Color = cols[int(Art.hash01(c, 94) * cols.size()) % cols.size()]
		var star := PackedVector2Array()
		var r := 4.2 + Art.hash01(c, 95) * 1.6
		for k in 10:
			var ang := k * PI / 5.0 + c
			star.append(tip + Vector2.from_angle(ang) * (r if k % 2 == 0 else r * 0.5))
		ci.draw_colored_polygon(star, fc)
	if stems.size() > 0:
		ci.draw_multiline(stems, pal.layers[2].lerp(pal.layers[1], 0.5), 1.6)

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

func _hole(ci: Node2D, a: float, b: float, lip: Color) -> void:
	var kind := _country()
	var top_c: Color
	var deep: Color
	match kind:
		"pavers":
			top_c = pal.sky[2].lerp(pal.layers[1], 0.55)
			deep = Color(0.03, 0.10, 0.20)
		"moss":
			top_c = pal.layers[2].lerp(Color(0.10, 0.25, 0.16), 0.5)
			deep = Color(0.01, 0.04, 0.03)
		"boards":
			top_c = pal.sky[2].lerp(pal.layers[2], 0.6)
			deep = Color(0.04, 0.03, 0.08)
		"snow":
			top_c = Color(0.55, 0.78, 0.98).lerp(pal.layers[1], 0.35)
			deep = Color(0.03, 0.06, 0.16)
		_:
			top_c = pal.layers[2]
			deep = Color(0.0, 0.0, 0.01)
	ci.draw_polygon(PackedVector2Array([Vector2(a, -2), Vector2(b, -2), Vector2(b, 300), Vector2(a, 300)]),
		PackedColorArray([top_c, top_c, deep, deep]))
	ci.draw_rect(Rect2(a, 300, b - a, 1100), deep)
	match kind:
		"pavers", "boards":
			# water far below with drifting glints
			var wy := 120.0
			ci.draw_rect(Rect2(a, wy, b - a, 300), Color(top_c.lerp(pal.sky[1], 0.4), 0.55))
			for k in 4:
				var gx: float = a + fposmod(t * (20.0 + k * 7.0) + k * 61.0, maxf(b - a - 30.0, 1.0)) + 10.0
				ci.draw_line(Vector2(gx, wy + 12 + k * 18), Vector2(gx + 18, wy + 12 + k * 18), Color(pal.rim, 0.35), 2.0)
		"moss":
			# ferns leaning in from the ravine walls
			for sd in [[a, 1.0], [b, -1.0]]:
				for k in 3:
					var base := Vector2(sd[0], 40.0 + k * 50.0)
					_tri_leaf(ci, base, base + Vector2(sd[1] * (40.0 + k * 10.0), -20.0), Color(0.12, 0.30, 0.18))
		"snow":
			# icy walls with a cold glow
			for sd in [[a, 1.0], [b, -1.0]]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(sd[0], 0), Vector2(sd[0] + sd[1] * 18.0, 60), Vector2(sd[0] + sd[1] * 6.0, 160), Vector2(sd[0], 220)]), Color(0.75, 0.90, 1.0, 0.55))
	# rocky lips at both edges
	for sd in [[a, 1.0], [b, -1.0]]:
		var x0: float = sd[0]
		var dir: float = sd[1]
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 - dir * 4, -3), Vector2(x0 + dir * 10, 2), Vector2(x0 + dir * 6, 26), Vector2(x0 - dir * 2, 44), Vector2(x0 - dir * 6, 20)]), lip.darkened(0.1))

func _tri_leaf(ci: Node2D, base: Vector2, tip: Vector2, col: Color) -> void:
	var n := (tip - base).orthogonal().normalized() * 7.0
	ci.draw_colored_polygon(PackedVector2Array([base + n, tip, base - n]), col)

# Obstacles are solid, light "ceramic" shapes with an ink outline and a
# colour-coded band, so they read on any screen without relying on glow.
const INK := Color(0.04, 0.05, 0.09)

func _mat() -> Color:
	return pal.get("obstacle", Color(0.85, 0.82, 0.76))

func _solid(ci: Node2D, pts: PackedVector2Array, fill: Color, ink_w := 3.0, sunlit := false) -> void:
	if sunlit and sun_k > 0.01:
		var left := INF
		var right := -INF
		for pt in pts:
			left = minf(left, pt.x)
			right = maxf(right, pt.x)
		# smooth: the lit side cross-fades as the sun passes (0.8.31)
		var sd := _sun_side((left + right) * 0.5)
		var shine: Color = fill.lightened(0.25).lerp(pal.rim, 0.35)
		var colors := PackedColorArray()
		for pt in pts:
			var side := inverse_lerp(left, right, pt.x)
			var lit := side * maxf(sd, 0.0) + (1.0 - side) * maxf(-sd, 0.0)
			colors.append(fill.lerp(shine, lit * sun_k))
		ci.draw_polygon(pts, colors)
	else:
		ci.draw_colored_polygon(pts, fill)
	var c := pts.duplicate()
	c.append(pts[0])
	ci.draw_polyline(c, INK, ink_w, Art.AA)

## Obstacles belong to a courier's journey (owner, 0.8.4): parcels to hop,
## a shop sign with bunting to scoot under, a wooden garden gate with a
## pinwheel, a village bell and drawbridge, a garden wall, old planks.
## Light warm materials with an ink outline keep them readable on any sky.
func _wood() -> Color:
	return Color(0.80, 0.58, 0.38).lerp(pal.rim, 0.12)

func _kraft() -> Color:
	return Color(0.90, 0.72, 0.50).lerp(pal.rim, 0.10)

func _parcel(ci: Node2D, r: Rect2, seed: int) -> void:
	var kc := _kraft().darkened(Art.hash01(seed, 1) * 0.08)
	_solid(ci, Art.rrect(r, 6.0), kc, 3.0, true)
	# shading on the lower part and the flap line
	ci.draw_colored_polygon(Art.rrect(Rect2(r.position.x + 3, r.end.y - r.size.y * 0.3, r.size.x - 6, r.size.y * 0.3 - 3), 4.0), kc.darkened(0.12))
	ci.draw_line(Vector2(r.position.x + 4, r.position.y + 10), Vector2(r.end.x - 4, r.position.y + 10), kc.darkened(0.22), 2.0)
	# string tied round it
	ci.draw_line(Vector2(r.get_center().x, r.position.y + 2), Vector2(r.get_center().x, r.end.y - 2), Color(0.55, 0.30, 0.22), 3.0)
	ci.draw_line(Vector2(r.position.x + 2, r.get_center().y), Vector2(r.end.x - 2, r.get_center().y), Color(0.55, 0.30, 0.22), 3.0)

## Country flavour for obstacles (0.8.18). Same hitboxes everywhere.
func _country() -> String:
	return str(pal.get("surface", "pavers"))

## Wobble an obstacle after Kavi clears it (springy, dies out in ~0.6 s).
func _wobble_begin(ci: Node2D, o: Dictionary, pivot: Vector2, amt := 0.12) -> void:
	var ct: float = o.get("clear_t", -99.0)
	var a: float = t - ct
	if a < 0.0 or a > 0.9:
		return
	var ang := sin(a * 20.0) * exp(-a * 6.0) * amt * (1.6 if o.get("perf", false) else 1.0)
	ci.draw_set_transform_matrix(Transform2D(ang, pivot) * Transform2D(0.0, -pivot))

func _wobble_end(ci: Node2D) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _sun_circle(ci: Node2D, center: Vector2, radius: float) -> void:
	if sun_k <= 0.01:
		return
	var sd := _sun_side(center.x)
	var angle := lerp_angle(PI + 0.55, -0.55, (sd + 1.0) * 0.5)
	ci.draw_arc(center, radius - 1.0, angle - 0.6, angle + 0.6, 8, Color(pal.rim, 0.55 * sun_k * (0.4 + 0.6 * absf(sd))), 2.0, Art.AA)

func _sun_side(x: float) -> float:
	var v := clampf((sun_world_x - x) / 320.0, -1.0, 1.0)
	return v * (1.5 - 0.5 * v * v)

func _hurdle(ci: Node2D, o: Dictionary) -> void:
	_wobble_begin(ci, o, Vector2(o.x + o.w * 0.5, 0.0))
	if Art.hash01(int(o.seed), 3) < 0.6:
		match _country():
			"pavers":
				if Art.hash01(int(o.seed), 4) < 0.5:
					_amphora(ci, o)
				else:
					_orange_crate(ci, o)
			"moss":
				_log_stack(ci, o)
			"boards":
				_barrel(ci, o)
			"snow":
				_snowman(ci, o)
			_:
				_hurdle_parcels(ci, o)
	else:
		_hurdle_parcels(ci, o)
	_wobble_end(ci)

func _amphora(ci: Node2D, o: Dictionary) -> void:
	var cx: float = o.x + o.w * 0.5
	var h: float = o.h + 4.0
	var w: float = o.w * 0.5
	var clay := Color(0.86, 0.48, 0.30).lerp(pal.rim, 0.12)
	var body := PackedVector2Array()
	for k in 13:
		var u := k / 12.0
		var y := -h + 22.0 + u * (h - 22.0)
		var bulge := sin(u * PI * 0.95 + 0.1) * w
		body.append(Vector2(cx - maxf(bulge, 9.0), y))
	for k in range(12, -1, -1):
		var u := k / 12.0
		var y := -h + 22.0 + u * (h - 22.0)
		var bulge := sin(u * PI * 0.95 + 0.1) * w
		body.append(Vector2(cx + maxf(bulge, 9.0), y))
	_solid(ci, body, clay, 3.0, true)
	_solid(ci, Art.rrect(Rect2(cx - 11, -h + 6, 22, 18), 3.0), clay.darkened(0.05))
	_solid(ci, Art.rrect(Rect2(cx - 15, -h + 2, 30, 7), 3.0), clay.lightened(0.08), 2.5)
	for sd in [-1.0, 1.0]:
		ci.draw_arc(Vector2(cx + sd * 13.0, -h + 22.0), 8.0, -PI * 0.5 + sd * PI * 0.5 - 1.2, -PI * 0.5 + sd * PI * 0.5 + 1.2, 8, INK, 5.0, Art.AA)
		ci.draw_arc(Vector2(cx + sd * 13.0, -h + 22.0), 8.0, -PI * 0.5 + sd * PI * 0.5 - 1.2, -PI * 0.5 + sd * PI * 0.5 + 1.2, 8, clay, 2.5, Art.AA)
	# black-figure band with the hop chevron
	var by := -h * 0.48
	ci.draw_rect(Rect2(cx - w * 0.82, by - 9, w * 1.64, 18), Color(0.12, 0.08, 0.08, 0.85))
	ci.draw_polyline(PackedVector2Array([Vector2(cx - 9, by + 5), Vector2(cx, by - 5), Vector2(cx + 9, by + 5)]), clay.lightened(0.2), 3.0, Art.AA)

func _orange_crate(ci: Node2D, o: Dictionary) -> void:
	var h: float = o.h * 0.62
	var r := Rect2(o.x, -h, o.w, h + 4)
	var wood := _wood()
	_solid(ci, Art.rrect(r, 4.0), wood, 3.0, true)
	for k in 3:
		var yy: float = r.position.y + 8 + k * (h - 10) / 3.0
		ci.draw_line(Vector2(r.position.x + 4, yy), Vector2(r.end.x - 4, yy), wood.darkened(0.25), 2.0)
	# a heap of oranges (and one leaf) on top, up to the full hop height
	var oc := Color(1.0, 0.58, 0.16)
	var n := int(o.w / 18.0)
	for k in n:
		var px: float = o.x + 10.0 + k * (o.w - 20.0) / float(maxi(n - 1, 1))
		ci.draw_circle(Vector2(px, -h - 6), 10.5, INK)
		ci.draw_circle(Vector2(px, -h - 6), 8.5, oc)
		_sun_circle(ci, Vector2(px, -h - 6), 8.5)
	for k in maxi(n - 1, 1):
		var px2: float = o.x + 19.0 + k * (o.w - 38.0) / float(maxi(n - 2, 1))
		ci.draw_circle(Vector2(px2, -o.h + 10), 10.5, INK)
		ci.draw_circle(Vector2(px2, -o.h + 10), 8.5, oc.lightened(0.06))
		_sun_circle(ci, Vector2(px2, -o.h + 10), 8.5)
	ci.draw_colored_polygon(Art.ellipse(Vector2(o.x + o.w * 0.5 + 6, -o.h + 1), Vector2(7, 3), 10, -0.5), LEAF.darkened(0.3))

func _log_stack(ci: Node2D, o: Dictionary) -> void:
	var bark := Color(0.48, 0.32, 0.22).lerp(pal.rim, 0.10)
	var cut := Color(0.90, 0.74, 0.50)
	var rr: float = minf(o.w * 0.30, o.h * 0.27)
	var cs := [Vector2(o.x + rr + 2, -rr), Vector2(o.x + o.w - rr - 2, -rr), Vector2(o.x + o.w * 0.5, -rr * 2.6)]
	for c in cs:
		ci.draw_circle(c, rr + 3.0, INK)
		ci.draw_circle(c, rr, bark)
		_sun_circle(ci, c, rr)
		ci.draw_circle(c, rr * 0.78, cut)
		ci.draw_arc(c, rr * 0.5, 0, TAU, 16, cut.darkened(0.2), 1.6)
		ci.draw_arc(c, rr * 0.22, 0, TAU, 10, cut.darkened(0.25), 1.6)
	# a little glowing mushroom on top
	var m := Vector2(o.x + o.w * 0.5 + rr * 0.4, -rr * 2.6 - rr - 2)
	ci.draw_line(m, m + Vector2(0, 10), Color(0.95, 0.92, 0.85), 4.0)
	_solid(ci, Art.ellipse(m, Vector2(10, 6), 12), Color(0.95, 0.35, 0.35), 2.0)
	ci.draw_circle(m + Vector2(-3, -2), 1.8, Color(1, 1, 1))
	ci.draw_circle(m + Vector2(4, -1), 1.5, Color(1, 1, 1))

func _barrel(ci: Node2D, o: Dictionary) -> void:
	var wood := _wood().darkened(0.05)
	var h: float = o.h + 4.0
	var r := Rect2(o.x + 2, -h + 4, o.w - 4, h)
	var pts := PackedVector2Array()
	for k in 9:
		var u := k / 8.0
		pts.append(Vector2(r.position.x + sin(u * PI) * -5.0, r.position.y + u * r.size.y))
	for k in range(8, -1, -1):
		var u := k / 8.0
		pts.append(Vector2(r.end.x + sin(u * PI) * 5.0, r.position.y + u * r.size.y))
	_solid(ci, pts, wood, 3.0, true)
	for k in 3:
		var sx: float = r.position.x + r.size.x * (0.28 + k * 0.22)
		ci.draw_line(Vector2(sx, r.position.y + 3), Vector2(sx, r.end.y - 3), wood.darkened(0.22), 2.0)
	for yy in [r.position.y + h * 0.18, r.end.y - h * 0.2]:
		ci.draw_line(Vector2(r.position.x - 3, yy), Vector2(r.end.x + 3, yy), INK, 6.0)
		ci.draw_line(Vector2(r.position.x - 3, yy), Vector2(r.end.x + 3, yy), Color(0.55, 0.58, 0.62), 3.0)
	# rope coil on top
	ci.draw_arc(Vector2(r.get_center().x, r.position.y - 2), 12.0, PI, TAU, 10, Color(0.80, 0.66, 0.42), 4.0, Art.AA)

func _snowman(ci: Node2D, o: Dictionary) -> void:
	var snow := Color(0.94, 0.96, 1.0).lerp(pal.layers[0], 0.08)
	var cx: float = o.x + o.w * 0.5
	var r1: float = minf(o.w * 0.5, o.h * 0.30)
	var r2: float = r1 * 0.72
	var r3: float = r1 * 0.52
	var c1 := Vector2(cx, -r1 + 2)
	var c2 := Vector2(cx, c1.y - r1 - r2 * 0.7)
	var c3 := Vector2(cx, c2.y - r2 - r3 * 0.6)
	for c in [[c1, r1], [c2, r2], [c3, r3]]:
		ci.draw_circle(c[0], c[1] + 3.0, INK)
		ci.draw_circle(c[0], c[1], snow)
		_sun_circle(ci, c[0], c[1])
	ci.draw_arc(c1 + Vector2(-r1 * 0.3, -r1 * 0.3), r1 * 0.6, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.9), 2.0)
	# face, carrot nose, scarf and coal buttons
	ci.draw_circle(c3 + Vector2(-r3 * 0.35, -r3 * 0.15), 2.4, INK)
	ci.draw_circle(c3 + Vector2(r3 * 0.35, -r3 * 0.15), 2.4, INK)
	ci.draw_colored_polygon(PackedVector2Array([c3 + Vector2(0, 0), c3 + Vector2(0, 5), c3 + Vector2(-14, 3)]), Color(1.0, 0.55, 0.2))
	ci.draw_line(c2 + Vector2(-r2, -r2 * 0.75), c2 + Vector2(r2, -r2 * 0.75), Color(0.85, 0.25, 0.3), 6.0)
	ci.draw_line(c2 + Vector2(r2 * 0.5, -r2 * 0.75), c2 + Vector2(r2 * 0.7, -r2 * 0.1), Color(0.85, 0.25, 0.3), 5.0)
	for k in 2:
		ci.draw_circle(c2 + Vector2(0, -r2 * 0.1 + k * r2 * 0.45), 2.6, INK)

## Runaway fruit cart (0.8.40): rolls toward Kavi, wheels turning, fruit
## jiggling, a little dust behind. Handles at the back (right).
func _cart(ci: Node2D, o: Dictionary) -> void:
	var wood := _wood()
	var roll: float = o.get("roll", 0.0)
	var rolling: bool = o.get("rolling", false)
	var jig := sin(roll * 0.09) * 2.0 if rolling else 0.0
	var top: float = -o.h + 18.0
	var body := Rect2(o.x, top + jig * 0.3, o.w, o.h - 40.0)
	# fruit heap first so the box rim covers its base
	var fruit: Array = [Color(1.0, 0.55, 0.12), Color(0.95, 0.25, 0.22), Color(0.98, 0.80, 0.20)]
	var fc: Color = fruit[int(Art.hash01(int(o.seed), 5) * 3.0) % 3]
	var n := int(o.w / 15.0)
	for row in 2:
		for k in n - row:
			var fx: float = o.x + 9.0 + (k + row * 0.5) * ((o.w - 18.0) / maxf(n - 1, 1))
			var fy: float = top - 4.0 - row * 11.0 + jig + sin(k * 1.7 + roll * 0.05) * (1.5 if rolling else 0.0)
			ci.draw_circle(Vector2(fx, fy), 8.0, INK)
			ci.draw_circle(Vector2(fx, fy), 6.5, fc.darkened(Art.hash01(k + row * 9, int(o.seed)) * 0.15))
			ci.draw_circle(Vector2(fx - 2.0, fy - 2.5), 2.0, Color(1, 1, 1, 0.45))
	_solid(ci, Art.rrect(body, 5.0), wood, 3.0, true)
	for k in 3:
		var py: float = body.position.y + 8.0 + k * (body.size.y - 16.0) / 2.0
		ci.draw_line(Vector2(o.x + 5, py), Vector2(o.x + o.w - 5, py), wood.darkened(0.25), 2.0, Art.AA)
	# handles sticking out at the back
	ci.draw_line(Vector2(o.x + o.w - 4, body.position.y + 10), Vector2(o.x + o.w + 26, body.position.y - 8), INK, 6.0, Art.AA)
	ci.draw_line(Vector2(o.x + o.w - 4, body.position.y + 10), Vector2(o.x + o.w + 26, body.position.y - 8), wood, 3.0, Art.AA)
	# wheels with turning spokes
	for wx in [o.x + 17.0, o.x + o.w - 17.0]:
		var c := Vector2(wx, -13.0)
		ci.draw_circle(c, 14.5, INK)
		ci.draw_circle(c, 11.5, wood.darkened(0.15))
		var a := -roll / 13.0
		for sp in 3:
			var d := Vector2(cos(a + sp * PI / 3.0), sin(a + sp * PI / 3.0)) * 10.0
			ci.draw_line(c - d, c + d, INK, 2.0, Art.AA)
		ci.draw_circle(c, 3.0, INK)
	if rolling:
		# dust puffs kicked up behind
		for k in 3:
			var ph := fposmod(t * 2.2 + k * 0.33, 1.0)
			ci.draw_circle(Vector2(o.x + o.w + 4.0 + ph * 40.0, -6.0 - ph * 14.0), 4.0 + ph * 8.0, Color(pal.fog, 0.35 * (1.0 - ph)))

## Pigeons fluttering on the path at head height (0.8.40). They lift as Kavi
## scoots underneath, and burst away if he Gusts them.
func _flock(ci: Node2D, o: Dictionary) -> void:
	var n := maxi(int(o.w / 34.0), 3)
	var under: float = clampf(((sim.x if sim != null else -1e9) - (o.x + 10.0)) / 260.0, 0.0, 1.0)
	var gone: float = clampf(o.open_t / 0.9, 0.0, 1.0) if o.open else 0.0
	var grey := Color(0.70, 0.72, 0.82).lerp(pal.rim, 0.12)
	var S := 1.75
	for k in n:
		var hx := Art.hash01(int(o.seed) + k, 11)
		var hy := Art.hash01(int(o.seed) + k, 12)
		var base := Vector2(o.x + 18.0 + (o.w - 36.0) * (float(k) + hx * 0.5) / maxf(n - 0.5, 1.0), -o.h - 18.0 - hy * 40.0)
		var lift := under * (70.0 + hy * 40.0) + gone * (260.0 + hy * 120.0)
		var p := base + Vector2(gone * (120.0 + hx * 160.0) + sin(t * 3.0 + k) * 3.0, -lift + sin(t * 7.0 + k * 1.3) * 4.0)
		var flap := 0.5 + 0.5 * sin(t * (16.0 + hx * 6.0) + k * 2.0)
		var a := 1.0 - gone * 0.9
		var col := Color(grey.darkened(hy * 0.18), a)
		var ink := Color(INK, a)
		# body, tail, head, beak, eye, iridescent neck, flapping wing
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(8, -2) * S, p + Vector2(17, -5) * S, p + Vector2(17, 1) * S]), ink)
		ci.draw_colored_polygon(Art.ellipse(p, Vector2(12, 8) * S, 12), ink)
		ci.draw_colored_polygon(Art.ellipse(p, Vector2(10.5, 6.5) * S, 12), col)
		ci.draw_circle(p + Vector2(-10, -5) * S, 5.5 * S, ink)
		ci.draw_circle(p + Vector2(-10, -5) * S, 4.3 * S, col.lightened(0.12))
		ci.draw_circle(p + Vector2(-11, -6) * S, 1.4 * S, ink)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-14.5, -5) * S, p + Vector2(-19, -3.5) * S, p + Vector2(-14.5, -2.5) * S]), Color(1.0, 0.72, 0.3, a))
		ci.draw_arc(p + Vector2(-7, -1) * S, 4.0 * S, PI * 0.15, PI * 0.95, 8, Color(0.45, 0.85, 0.72, 0.8 * a), 2.0 * S, Art.AA)
		var tip := p + Vector2(3.0, -6.0 - 14.0 * flap) * S
		var wing := PackedVector2Array([p + Vector2(-3, -2) * S, p + Vector2(9, -1) * S, tip])
		ci.draw_colored_polygon(wing, col.darkened(0.2))
		ci.draw_polyline(PackedVector2Array([wing[0], wing[2], wing[1]]), ink, 2.5, Art.AA)

## A tall, wobbly parcel tower with a cat napping on top (0.8.40): hold Hop.
func _tower(ci: Node2D, o: Dictionary) -> void:
	_wobble_begin(ci, o, Vector2(o.x + o.w * 0.5, 0.0), 0.08)
	var seed := int(o.seed)
	var h: float = o.h
	var y := 4.0
	var sizes := [0.40, 0.33, 0.27]
	for k in 3:
		var ph: float = h * sizes[k]
		var inset: float = o.w * (0.04 * k) + (Art.hash01(seed, 20 + k) - 0.5) * 6.0
		_parcel(ci, Rect2(o.x + inset, y - ph, o.w - inset * 2.0, ph), seed + k * 5)
		y -= ph
	# striped "this way up" tape on the middle parcel
	var my := -h * 0.55
	ci.draw_line(Vector2(o.x + 6, my), Vector2(o.x + o.w - 6, my), Color(0.92, 0.32, 0.30, 0.85), 4.0, Art.AA)
	# a little cat napping on top, tail swishing
	var c := Vector2(o.x + o.w * 0.5, -h - 7.0)
	var fur := Color(0.95, 0.62, 0.32).lerp(pal.rim, 0.12)
	ci.draw_colored_polygon(Art.ellipse(c, Vector2(16, 9), 12), INK)
	ci.draw_colored_polygon(Art.ellipse(c, Vector2(14, 7.5), 12), fur)
	var hd := c + Vector2(-12, -5)
	ci.draw_circle(hd, 7.5, INK)
	ci.draw_circle(hd, 6.0, fur)
	for e in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(e * 2.0 - 3.0, -4), hd + Vector2(e * 4.0, -11), hd + Vector2(e * 6.0 - 0.5, -3)]), fur.darkened(0.1))
	ci.draw_line(hd + Vector2(-4, 0), hd + Vector2(-1, 0.5), INK, 1.5, Art.AA)
	ci.draw_line(hd + Vector2(1, 0.5), hd + Vector2(4, 0), INK, 1.5, Art.AA)
	var sw := sin(t * 2.4 + seed) * 0.5
	ci.draw_polyline(PackedVector2Array([c + Vector2(13, 2), c + Vector2(20, -2 + sw * 6.0), c + Vector2(24, -9 + sw * 10.0)]), INK, 4.5, Art.AA)
	ci.draw_polyline(PackedVector2Array([c + Vector2(13, 2), c + Vector2(20, -2 + sw * 6.0), c + Vector2(24, -9 + sw * 10.0)]), fur, 2.5, Art.AA)
	_wobble_end(ci)

func _hurdle_parcels(ci: Node2D, o: Dictionary) -> void:
	var seed := int(o.x)
	if o.h > 95.0:
		# two parcels: a big one with a smaller one on top
		_parcel(ci, Rect2(o.x, -o.h * 0.55, o.w, o.h * 0.55 + 4), seed)
		_parcel(ci, Rect2(o.x + o.w * 0.12, -o.h, o.w * 0.76, o.h * 0.45 + 2), seed + 7)
	else:
		_parcel(ci, Rect2(o.x, -o.h, o.w, o.h + 4), seed)
	# shipping label with the hop chevron, and a red stamp
	var lc := Vector2(o.x + o.w * 0.5, -o.h * 0.30)
	ci.draw_colored_polygon(Art.rrect(Rect2(lc.x - 16, lc.y - 11, 32, 22), 3.0), Color(0.98, 0.95, 0.88))
	ci.draw_polyline(PackedVector2Array([lc + Vector2(-9, 5), lc + Vector2(0, -5), lc + Vector2(9, 5)]), INK, 3.5, Art.AA)
	ci.draw_circle(Vector2(o.x + o.w - 14, -o.h + 16), 6.0, Color(0.92, 0.32, 0.30))

const BEAM_AIR := 16.0

func _beam(ci: Node2D, o: Dictionary) -> void:
	# 0.8.18: a gateway (stone in Greece, logs in the forest, rope-and-lantern
	# poles by the Danube, icy timber in the mountains) stands on the ground,
	# and the sign hangs from its crossbar on two ropes, swinging when Kavi
	# scoots under it. (The old posts ran up off the top of the screen.)
	# 0.8.34: drawn 16 px above the hit line, so the taller Kavi (0.8.31) slides
	# under with a little air instead of his antenna grazing the board
	var bottom: float = -o.h - BEAM_AIR
	var wood := _wood()
	var kind := _country()
	var leg := wood.darkened(0.45)
	if kind == "pavers":
		leg = Color(0.86, 0.80, 0.70).lerp(pal.layers[1], 0.35)
	elif kind == "snow":
		leg = Color(0.62, 0.66, 0.78).lerp(pal.layers[1], 0.3)
	var top := bottom - 190.0
	var l0: float = o.x - 26.0
	var l1: float = o.x + o.w + 4.0
	for lx in [l0, l1]:
		_solid(ci, Art.rrect(Rect2(lx, top, 22, -top + 4), 5.0), leg, 2.5, true)
	_solid(ci, Art.rrect(Rect2(l0 - 14, top - 18, l1 - l0 + 50, 24), 8.0), leg.lightened(0.06), 2.5)
	match kind:
		"pavers":
			for k in 7:
				ci.draw_circle(Vector2(l0 + 10 + k * (l1 - l0) / 6.0, top - 18 + sin(k * 1.7) * 4.0), 8.0, LEAF.darkened(0.35))
		"boards":
			for lx in [l0 + 11.0, l1 + 11.0]:
				var lp := Vector2(lx, top - 34)
				ci.draw_line(lp + Vector2(0, 16), lp, INK, 2.0)
				_solid(ci, Art.rrect(Rect2(lp.x - 8, lp.y - 18, 16, 20), 5.0), Color(1.0, 0.78, 0.4), 2.0)
		"snow":
			for k in 8:
				var ix: float = l0 + 4 + k * (l1 - l0 + 30) / 7.0
				ci.draw_colored_polygon(PackedVector2Array([Vector2(ix - 4, top + 5), Vector2(ix + 4, top + 5), Vector2(ix, top + 14 + Art.hash01(k, int(o.seed)) * 14.0)]), Color(0.85, 0.94, 1.0, 0.9))
			ci.draw_rect(Rect2(l0 - 12, top - 22, l1 - l0 + 46, 7), Color(0.95, 0.97, 1.0))
	# the sign swings from the crossbar after Kavi passes under it
	var ct: float = o.get("clear_t", -99.0)
	var a: float = t - ct
	var swing := sin(a * 9.0) * exp(-a * 3.0) * (0.10 if o.get("perf", false) else 0.06) if a >= 0.0 and a < 2.0 else sin(t * 1.3 + o.x * 0.01) * 0.01
	var hang := Vector2(o.x + o.w * 0.5, top + 6)
	ci.draw_line(Vector2(o.x + 24, top + 6), Vector2(o.x + 24, bottom - 92), INK, 3.0)
	ci.draw_line(Vector2(o.x + o.w - 24, top + 6), Vector2(o.x + o.w - 24, bottom - 92), INK, 3.0)
	ci.draw_set_transform_matrix(Transform2D(swing, hang) * Transform2D(0.0, -hang))
	_solid(ci, Art.rrect(Rect2(o.x, bottom - 72, o.w, 72), 12.0), wood, 3.0, true)
	# planks
	ci.draw_line(Vector2(o.x + 6, bottom - 48), Vector2(o.x + o.w - 6, bottom - 48), wood.darkened(0.22), 2.0)
	ci.draw_line(Vector2(o.x + 6, bottom - 24), Vector2(o.x + o.w - 6, bottom - 24), wood.darkened(0.22), 2.0)
	# bunting on top (never below the sign, so the gap underneath stays clear)
	var flags := [Color(1.0, 0.45, 0.45), Color(1.0, 0.85, 0.40), pal.accent, Color(0.98, 0.95, 0.88)]
	var nfl := int(o.w / 34.0)
	for k in nfl:
		var fx: float = o.x + 10.0 + k * (o.w - 20.0) / float(maxi(nfl - 1, 1))
		var sw := sin(t * 2.4 + k) * 3.0
		_solid(ci, PackedVector2Array([Vector2(fx - 11, bottom - 92), Vector2(fx + 11, bottom - 92), Vector2(fx + sw, bottom - 72)]), flags[k % flags.size()], 2.0)
	ci.draw_line(Vector2(o.x, bottom - 92), Vector2(o.x + o.w, bottom - 92), INK, 2.0)
	# painted "scoot" chevrons
	for k in maxi(1, int(o.w / 120.0)):
		var c := Vector2(o.x + 60.0 + k * 120.0, bottom - 36)
		if c.x > o.x + o.w - 30.0:
			break
		ci.draw_polyline(PackedVector2Array([c + Vector2(-12, -6), c + Vector2(0, 6), c + Vector2(12, -6)]), Color(0.98, 0.95, 0.88), 5.0, Art.AA)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _gate(ci: Node2D, o: Dictionary) -> void:
	var body := _mat()
	var x: float = o.x
	_solid(ci, Art.rrect(Rect2(x - 10, -o.h, 14, o.h), 6.0), _wood().darkened(0.35))
	_solid(ci, Art.rrect(Rect2(x + o.w - 4, -o.h, 14, o.h), 6.0), _wood().darkened(0.35))
	var f = clampf(o.open_t / 0.45, 0.0, 1.0)
	var swing = ease(f, 0.4) * 1.45
	var hinge = Vector2(x + o.w * 0.5, -o.h)
	ci.draw_set_transform(hinge, -swing, Vector2.ONE)
	var wood := _wood()
	_solid(ci, Art.rrect(Rect2(-o.w * 0.5 + 4, 4, o.w - 8, o.h - 10), 8.0), wood)
	var np := maxi(2, int((o.w - 8) / 22.0))
	for k in range(1, np):
		var px: float = -o.w * 0.5 + 4 + k * (o.w - 8) / float(np)
		ci.draw_line(Vector2(px, 8), Vector2(px, o.h - 10), wood.darkened(0.25), 2.0)
	ci.draw_line(Vector2(-o.w * 0.5 + 8, o.h * 0.25), Vector2(o.w * 0.5 - 8, o.h * 0.25), wood.darkened(0.3), 5.0)
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
	ci.draw_line(Vector2(o.bell_x, 0), bp + Vector2(0, -40), _wood().darkened(0.3), 9.0)
	ci.draw_line(bp + Vector2(-52, -40), bp + Vector2(32, -40), INK, 12.0)
	ci.draw_line(bp + Vector2(-50, -40), bp + Vector2(30, -40), _wood().darkened(0.3), 7.0)
	var swing = sin(o.open_t * 18.0) * exp(-o.open_t * 2.5) * 0.6 if o.open else sin(t * 1.6) * 0.06
	ci.draw_set_transform(bp + Vector2(-20, -40), swing, Vector2.ONE)
	_solid(ci, PackedVector2Array([Vector2(-14, 4), Vector2(14, 4), Vector2(28, 48), Vector2(-28, 48)]), GOLD.darkened(0.08))
	ci.draw_circle(Vector2(0, 52), 7, INK)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var f = clampf(o.open_t / 0.6, 0.0, 1.0) if o.open else 0.0
	var ang = lerpf(1.35, 0.0, ease(f, 0.35))
	var half: float = o.w * 0.5 + 4.0
	ci.draw_set_transform(Vector2(o.x, 0), -ang, Vector2.ONE)
	_solid(ci, PackedVector2Array([Vector2(0, -6), Vector2(half, -6), Vector2(half, 12), Vector2(0, 12)]), _wood())
	for k in int(half / 36.0):
		ci.draw_line(Vector2(k * 36.0 + 18, -6), Vector2(k * 36.0 + 18, 12), INK, 2.0)
	ci.draw_set_transform(Vector2(o.x + o.w, 0), ang, Vector2.ONE)
	_solid(ci, PackedVector2Array([Vector2(-half, -6), Vector2(0, -6), Vector2(0, 12), Vector2(-half, 12)]), _wood())
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
		Vector2(wx + o.wall_w - 4, -o.wall_h + 40), Vector2(wx + o.wall_w, 2)]), body.lerp(Color(0.72, 0.68, 0.62), 0.5))
	# stone courses and a trail of ivy
	for k in int(o.wall_h / 34.0):
		var yy: float = -12.0 - k * 34.0
		ci.draw_line(Vector2(wx + 6, yy), Vector2(wx + o.wall_w - 6, yy), body.darkened(0.25), 2.0)
	for k in 6:
		ci.draw_circle(Vector2(wx + o.wall_w * (0.2 + 0.12 * k), -o.wall_h * (0.2 + 0.11 * k)), 7.0, LEAF.darkened(0.35))

func _rescue(ci: Node2D, o: Dictionary) -> void:
	var body := _wood().darkened(0.1)
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
	ci.draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(-12, -9), Vector2(-6, 0), Vector2(-12, 9)]), letter_col)
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
		# sunlight washing down the front of the ground (0.8.15)
		ci.draw_polygon(PackedVector2Array([Vector2(e[0], 6), Vector2(e[1], 6), Vector2(e[1], 170), Vector2(e[0], 170)]),
			PackedColorArray([Color(rim, 0.16), Color(rim, 0.16), Color(rim, 0.0), Color(rim, 0.0)]))
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
				var br := Art.rrect(Rect2(o.x, -o.h - BEAM_AIR - 70, o.w, 70), 16.0)
				br.append(br[0])
				ci.draw_polyline(br, Color(ROSE, 0.4), 2.0, Art.AA)
				ci.draw_polygon(PackedVector2Array([Vector2(o.x + 10, -o.h - BEAM_AIR - 4), Vector2(o.x + o.w - 10, -o.h - BEAM_AIR - 4), Vector2(o.x + o.w - 10, -o.h - BEAM_AIR + 40), Vector2(o.x + 10, -o.h - BEAM_AIR + 40)]),
					PackedColorArray([Color(ROSE, 0.16), Color(ROSE, 0.16), Color(ROSE, 0.0), Color(ROSE, 0.0)]))
				ci.draw_line(Vector2(o.x + 14, -o.h - BEAM_AIR - 3), Vector2(o.x + o.w - 14, -o.h - BEAM_AIR - 3), Art.hdr(ROSE, 1.6), 4.0)
				for k in maxi(1, int(o.w / 160.0)):
					_chevron(ci, Vector2(o.x + 80 + k * 160.0, -o.h - 34), 1.0, ROSE)
			GAP:
				pass
			CART:
				_chevron(ci, Vector2(o.x + o.w * 0.5, -o.h - 52), -1.0, AMBER)
				if o.get("rolling", false):
					# speed lines trailing behind the rolling cart
					for k in 3:
						var ly: float = -o.h * (0.3 + 0.25 * k)
						var lx: float = o.x + o.w + 10.0 + fposmod(t * 300.0 + k * 40.0, 60.0)
						ci.draw_line(Vector2(lx, ly), Vector2(lx + 34.0, ly), Color(AMBER, 0.35), 3.0, Art.AA)
			FLOCK:
				if not o.open:
					_chevron(ci, Vector2(o.x + o.w * 0.5, -o.h - 150), 1.0, ROSE)
					Art.glow(ci, Vector2(o.x + o.w * 0.5, -o.h - 40), 60.0, Color(LEAF, 0.12), 3)
			TOWER:
				_chevron(ci, Vector2(o.x + o.w * 0.5, -o.h - 40), -1.0, AMBER)
				_chevron(ci, Vector2(o.x + o.w * 0.5, -o.h - 62), -1.0, AMBER)
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
