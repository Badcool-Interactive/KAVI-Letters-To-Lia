extends RefCounted
## Procedural drawing helpers and biome palettes. All art is code-drawn
## (original, no external assets). HDR colours (>1) feed the bloom pass.

static func ellipse(c: Vector2, r: Vector2, n := 28, rot := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		p[i] = c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot)
	return p

static func rrect(r: Rect2, rad: float, seg := 5) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5 - 0.5)
	if rad < 1.0:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var p := PackedVector2Array()
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var start := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for k in 4:
		for i in seg + 1:
			var a: float = start[k] + PI * 0.5 * float(i) / float(seg)
			p.append(cs[k] + Vector2(cos(a), sin(a)) * rad)
	return p

static func glow(ci: CanvasItem, p: Vector2, r: float, col: Color, steps := 6) -> void:
	for i in steps:
		var f := 1.0 - float(i) / float(steps)
		var c := col
		c.a = col.a * (0.12 + 0.88 * (1.0 - f)) / float(steps) * 2.2
		ci.draw_circle(p, r * f, c)

static func hash01(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 100000) / 100000.0

static func ridge(x: float, seed_f: float, amp: float, freq: float) -> float:
	return (sin(x * freq + seed_f) * 0.55 + sin(x * freq * 2.13 + seed_f * 1.7) * 0.28
		+ sin(x * freq * 4.71 + seed_f * 2.3) * 0.12 + sin(x * freq * 9.3 + seed_f * 0.4) * 0.05) * amp

static func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)

static func mixc(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))

## Biome palettes. "Luminous future": dark layered silhouettes, one strong
## light source, glowing life. Original locations inspired by the route.
const BIOMES := [
	{
		"name": "Kalymera Bay", "country": "Greece",
		"sky": [Color(0.03, 0.10, 0.20), Color(0.16, 0.34, 0.48), Color(1.0, 0.72, 0.45)],
		"sun": Color(1.0, 0.78, 0.48), "sun_pos": Vector2(0.72, 0.56), "sun_r": 180.0,
		"fog": Color(0.55, 0.55, 0.62),
		"layers": [Color(0.24, 0.33, 0.45), Color(0.13, 0.20, 0.30), Color(0.06, 0.10, 0.17)],
		"ground": Color(0.025, 0.045, 0.075), "rim": Color(1.0, 0.82, 0.55),
		"accent": Color(0.30, 1.0, 0.95), "mote": Color(1.0, 0.85, 0.55),
		"kinds": [["ring", "spire", "dome"], ["dome", "column", "spire"], ["olive", "column", "cypress"]],
		"stars": 0.2, "aurora": 0.0, "water": 1.0,
	},
	{
		"name": "Rhodope Lanterns", "country": "Bulgaria",
		"sky": [Color(0.01, 0.03, 0.08), Color(0.03, 0.12, 0.16), Color(0.20, 0.42, 0.40)],
		"sun": Color(0.75, 1.0, 0.9), "sun_pos": Vector2(0.30, 0.30), "sun_r": 70.0,
		"fog": Color(0.20, 0.42, 0.40),
		"layers": [Color(0.07, 0.19, 0.22), Color(0.04, 0.11, 0.14), Color(0.02, 0.05, 0.07)],
		"ground": Color(0.01, 0.025, 0.03), "rim": Color(0.55, 1.0, 0.75),
		"accent": Color(1.0, 0.70, 0.30), "mote": Color(0.75, 1.0, 0.45),
		"kinds": [["pine", "pine", "peak"], ["pine", "lantern", "pine"], ["fern", "pine", "lantern"]],
		"stars": 1.0, "aurora": 0.0, "water": 0.0,
	},
	{
		"name": "Danube Mirror", "country": "Bulgaria · Romania",
		"sky": [Color(0.09, 0.04, 0.16), Color(0.36, 0.16, 0.36), Color(1.0, 0.52, 0.52)],
		"sun": Color(1.0, 0.55, 0.60), "sun_pos": Vector2(0.50, 0.62), "sun_r": 150.0,
		"fog": Color(0.65, 0.40, 0.55),
		"layers": [Color(0.33, 0.20, 0.38), Color(0.18, 0.10, 0.24), Color(0.08, 0.04, 0.12)],
		"ground": Color(0.04, 0.02, 0.06), "rim": Color(1.0, 0.62, 0.78),
		"accent": Color(0.55, 0.85, 1.0), "mote": Color(1.0, 0.65, 0.85),
		"kinds": [["bridge", "turbine", "ring"], ["turbine", "reed", "lily"], ["reed", "lily", "reed"]],
		"stars": 0.4, "aurora": 0.0, "water": 1.0,
	},
	{
		"name": "Carpathian Aurora", "country": "Romania",
		"sky": [Color(0.02, 0.01, 0.07), Color(0.10, 0.06, 0.22), Color(0.25, 0.42, 0.60)],
		"sun": Color(0.80, 0.70, 1.0), "sun_pos": Vector2(0.62, 0.24), "sun_r": 60.0,
		"fog": Color(0.30, 0.36, 0.60),
		"layers": [Color(0.16, 0.15, 0.32), Color(0.08, 0.07, 0.19), Color(0.03, 0.02, 0.08)],
		"ground": Color(0.015, 0.01, 0.035), "rim": Color(0.65, 0.80, 1.0),
		"accent": Color(0.85, 0.50, 1.0), "mote": Color(0.55, 0.95, 1.0),
		"kinds": [["peak", "castle", "peak"], ["castle", "pine", "pine"], ["pine", "fern", "pine"]],
		"stars": 1.0, "aurora": 1.0, "water": 0.0,
	},
]

static func biome(i: int) -> Dictionary:
	return BIOMES[posmod(i, BIOMES.size())]

## Blend two palettes (biome transitions).
static func blend_biome(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	var o := a.duplicate()
	o.sky = [a.sky[0].lerp(b.sky[0], t), a.sky[1].lerp(b.sky[1], t), a.sky[2].lerp(b.sky[2], t)]
	o.layers = [a.layers[0].lerp(b.layers[0], t), a.layers[1].lerp(b.layers[1], t), a.layers[2].lerp(b.layers[2], t)]
	for k in ["sun", "fog", "ground", "rim", "accent", "mote"]:
		o[k] = a[k].lerp(b[k], t)
	o.sun_pos = a.sun_pos.lerp(b.sun_pos, t)
	o.sun_r = lerpf(a.sun_r, b.sun_r, t)
	o.stars = lerpf(a.stars, b.stars, t)
	o.aurora = lerpf(a.aurora, b.aurora, t)
	o.water = lerpf(a.water, b.water, t)
	o.kinds = a.kinds if t < 0.5 else b.kinds
	return o
