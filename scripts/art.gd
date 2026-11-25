extends RefCounted
## Procedural drawing helpers and biome palettes. All art is code-drawn
## (original, no external assets). HDR colours (>1) feed the bloom pass.

## Shape caches (0.8.17): the same ellipses and rounded rects are rebuilt every
## frame (Kavi's parts use fixed local coordinates; ground stones repeat while
## on screen). A hit is ~12x cheaper than rebuilding. Packed arrays are
## copy-on-write, so callers can still modify what they get back.
static var _shape_cache := {}

static func _cache_put(key: Array, v: PackedVector2Array) -> void:
	if _shape_cache.size() > 6000:
		_shape_cache.clear()
	_shape_cache[key] = v

static func ellipse(c: Vector2, r: Vector2, n := 28, rot := 0.0) -> PackedVector2Array:
	var key := [0, c, r, n, rot]
	var hit = _shape_cache.get(key)
	if hit != null:
		return hit
	var v := _ellipse_raw(c, r, n, rot)
	_cache_put(key, v)
	return v

static func _ellipse_raw(c: Vector2, r: Vector2, n: int, rot: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	p.resize(n)
	for i in n:
		var a := TAU * float(i) / float(n)
		p[i] = c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot)
	return p

static func rrect(r: Rect2, rad: float, seg := 5) -> PackedVector2Array:
	var key := [1, r, rad, seg]
	var hit = _shape_cache.get(key)
	if hit != null:
		return hit
	var v := _rrect_raw(r, rad, seg)
	_cache_put(key, v)
	return v

static func _rrect_raw(r: Rect2, rad: float, seg: int) -> PackedVector2Array:
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

## World colour grade (0.8.19). HDR 2D rendered differently per platform:
## darker and moodier on PC, pale and washed out on Android (owner's phone
## recording). So HDR is off everywhere and the moody look is applied on
## purpose: world painters convert their sRGB colours to linear (the darker,
## richer curve the game was tuned with on PC). Characters, HUD and menus are
## not graded, so they keep their true colours. Same result on every platform.
const GRADE_CODE := """
uniform float grade = 1.0;
vec3 to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void fragment() {
	COLOR.rgb = mix(COLOR.rgb, to_linear(COLOR.rgb), grade);
	// a little dither so deep, dark gradients don't band in 8-bit colour
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR.rgb += (n - 0.5) / 255.0;
}
"""
## Clean shutdown: release the shared textures, materials and shape cache that
## live in static variables (otherwise Godot reports them at exit).
static func release_statics() -> void:
	_dot = null
	_grade_mix = null
	_grade_add = null
	_shape_cache.clear()

static var _grade_mix: ShaderMaterial
static var _grade_add: ShaderMaterial

## Shared grade materials: one for normal layers, one for additive light layers.
static func grade_material(additive := false) -> ShaderMaterial:
	if additive:
		if _grade_add == null:
			var sh := Shader.new()
			sh.code = "shader_type canvas_item;\nrender_mode blend_add;\n" + GRADE_CODE
			_grade_add = ShaderMaterial.new()
			_grade_add.shader = sh
		return _grade_add
	if _grade_mix == null:
		var sh2 := Shader.new()
		sh2.code = "shader_type canvas_item;\n" + GRADE_CODE
		_grade_mix = ShaderMaterial.new()
		_grade_mix.shader = sh2
	return _grade_mix

## Global render quality: 0 low, 1 medium, 2 high. AA = antialiased lines.
static var Q := 2
static var AA := true
static var _dot: Texture2D

## Soft radial dot shared by every glow: one textured quad per glow, which
## batches into a single draw call (was 5-6 stacked circles each).
static func dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot

static func glow(ci: CanvasItem, p: Vector2, r: float, col: Color, _steps := 6) -> void:
	ci.draw_texture_rect(dot(), Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false, Color(col.r, col.g, col.b, col.a * 0.8))

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
		"name": "The Amber Shore", "surface": "pavers", "country": "Greece",
		"sky": [Color(0.10, 0.17, 0.27), Color(0.30, 0.42, 0.52), Color(0.96, 0.76, 0.58)],
		"sun": Color(1.0, 0.84, 0.64), "sun_pos": Vector2(0.72, 0.56), "sun_r": 150.0,
		"fog": Color(0.70, 0.66, 0.68),
		"layers": [Color(0.36, 0.43, 0.53), Color(0.21, 0.28, 0.37), Color(0.10, 0.14, 0.21)],
		"ground": Color(0.05, 0.07, 0.10), "rim": Color(1.0, 0.86, 0.66),
		"accent": Color(0.55, 0.92, 0.90), "mote": Color(1.0, 0.88, 0.68),
		"obstacle": Color(0.93, 0.88, 0.80),
		"kinds": [["temple", "lighthouse", "windmill", "temple"], ["temple", "column", "windmill", "house", "cypress"], ["olive", "column", "cypress", "bush", "rock", "olive"]],
		"stars": 0.15, "aurora": 0.0, "water": 1.0,
		"town": "village", "life": ["cafe", "kite_kid", "bench", "waver", "fisher"], "ships": ["sail", "ferry", "sail"], "air": ["plane", "balloon"],
	},
	{
		"name": "Lanternwood", "surface": "moss", "country": "Bulgaria",
		"sky": [Color(0.07, 0.13, 0.20), Color(0.17, 0.30, 0.35), Color(0.48, 0.64, 0.60)],
		"sun": Color(0.86, 1.0, 0.94), "sun_pos": Vector2(0.30, 0.32), "sun_r": 70.0,
		"fog": Color(0.42, 0.58, 0.56),
		"layers": [Color(0.22, 0.35, 0.38), Color(0.13, 0.23, 0.26), Color(0.06, 0.12, 0.14)],
		"ground": Color(0.03, 0.06, 0.07), "rim": Color(0.70, 1.0, 0.86),
		"accent": Color(1.0, 0.78, 0.45), "mote": Color(0.85, 1.0, 0.65),
		"obstacle": Color(0.88, 0.93, 0.88),
		"kinds": [["pine", "pine", "peak", "birch"], ["pine", "lantern", "pine", "house", "birch"], ["fern", "pine", "lantern", "bush", "rock"]],
		"stars": 0.7, "aurora": 0.0, "water": 0.0,
		"town": "village", "life": ["cart", "kite_kid", "waver", "dog"], "ships": [], "air": ["plane", "balloon"],
	},
	{
		"name": "Mirrorwater", "surface": "boards", "country": "Danube · Bulgaria and Romania",
		"sky": [Color(0.14, 0.11, 0.22), Color(0.38, 0.28, 0.42), Color(0.94, 0.68, 0.62)],
		"sun": Color(1.0, 0.72, 0.66), "sun_pos": Vector2(0.50, 0.62), "sun_r": 130.0,
		"fog": Color(0.70, 0.56, 0.62),
		"layers": [Color(0.38, 0.30, 0.42), Color(0.23, 0.17, 0.29), Color(0.11, 0.08, 0.15)],
		"ground": Color(0.06, 0.04, 0.08), "rim": Color(1.0, 0.76, 0.82),
		"accent": Color(0.66, 0.86, 1.0), "mote": Color(1.0, 0.80, 0.88),
		"obstacle": Color(0.95, 0.88, 0.88),
		"kinds": [["bridge", "turbine", "birch", "house"], ["turbine", "reed", "lily", "house", "bush"], ["reed", "lily", "reed", "bush", "rock"]],
		"stars": 0.3, "aurora": 0.0, "water": 1.0,
		"town": "city", "life": ["fisher", "bench", "kite_kid", "dog", "waver"], "ships": ["barge", "steamer", "sail"], "air": ["plane", "birds"],
	},
	{
		"name": "Starfall Heights", "surface": "snow", "country": "Romania",
		"sky": [Color(0.06, 0.06, 0.14), Color(0.16, 0.15, 0.30), Color(0.38, 0.50, 0.66)],
		"sun": Color(0.88, 0.84, 1.0), "sun_pos": Vector2(0.62, 0.24), "sun_r": 60.0,
		"fog": Color(0.44, 0.48, 0.66),
		"layers": [Color(0.24, 0.24, 0.40), Color(0.14, 0.14, 0.27), Color(0.07, 0.06, 0.14)],
		"ground": Color(0.04, 0.03, 0.07), "rim": Color(0.78, 0.86, 1.0),
		"accent": Color(0.86, 0.68, 1.0), "mote": Color(0.70, 0.95, 1.0),
		"obstacle": Color(0.88, 0.88, 0.96),
		"kinds": [["peak", "castle", "peak", "pine"], ["castle", "pine", "pine", "house", "birch"], ["pine", "fern", "pine", "rock", "bush"]],
		"stars": 0.8, "aurora": 0.7, "water": 0.0,
		"town": "village", "life": ["cart", "waver", "dog", "kite_kid"], "ships": [], "air": ["plane", "balloon"],
	},
]

## Day (0.8.27, owner: the menu only ever showed evening). Each country gets a
## bright daytime palette: blue sky, high sun, light haze, no stars. These
## colours are chosen for the lighter day grade (see set_day).
static var day := false
const DAY := [
	{"sky": [Color(0.42, 0.66, 0.94), Color(0.66, 0.83, 0.97), Color(0.97, 0.94, 0.86)], "sun": Color(1.0, 0.97, 0.86), "sun_pos": Vector2(0.72, 0.17), "sun_r": 95.0,
		"fog": Color(0.86, 0.91, 0.96), "layers": [Color(0.66, 0.75, 0.86), Color(0.50, 0.61, 0.72), Color(0.36, 0.46, 0.55)], "ground": Color(0.22, 0.26, 0.30),
		"rim": Color(1.0, 0.95, 0.84), "stars": 0.0, "aurora": 0.0},
	{"sky": [Color(0.40, 0.66, 0.86), Color(0.64, 0.84, 0.88), Color(0.90, 0.96, 0.88)], "sun": Color(1.0, 0.98, 0.88), "sun_pos": Vector2(0.30, 0.16), "sun_r": 85.0,
		"fog": Color(0.78, 0.90, 0.86), "layers": [Color(0.52, 0.70, 0.62), Color(0.36, 0.55, 0.47), Color(0.22, 0.40, 0.33)], "ground": Color(0.14, 0.24, 0.18),
		"rim": Color(1.0, 0.98, 0.84), "stars": 0.0, "aurora": 0.0},
	{"sky": [Color(0.46, 0.64, 0.92), Color(0.70, 0.80, 0.96), Color(0.98, 0.90, 0.86)], "sun": Color(1.0, 0.96, 0.88), "sun_pos": Vector2(0.50, 0.18), "sun_r": 95.0,
		"fog": Color(0.88, 0.88, 0.94), "layers": [Color(0.66, 0.68, 0.84), Color(0.50, 0.52, 0.70), Color(0.36, 0.36, 0.54)], "ground": Color(0.22, 0.20, 0.28),
		"rim": Color(1.0, 0.94, 0.90), "stars": 0.0, "aurora": 0.0},
	{"sky": [Color(0.36, 0.58, 0.92), Color(0.62, 0.78, 0.98), Color(0.92, 0.95, 1.0)], "sun": Color(1.0, 1.0, 0.94), "sun_pos": Vector2(0.62, 0.15), "sun_r": 80.0,
		"fog": Color(0.86, 0.90, 0.98), "layers": [Color(0.70, 0.76, 0.90), Color(0.52, 0.58, 0.76), Color(0.36, 0.42, 0.58)], "ground": Color(0.24, 0.26, 0.34),
		"rim": Color(0.96, 0.98, 1.0), "stars": 0.0, "aurora": 0.0},
]
static var _day_cache := {}

static func biome(i: int) -> Dictionary:
	var k := posmod(i, BIOMES.size())
	if not day:
		return BIOMES[k]
	if not _day_cache.has(k):
		var b: Dictionary = BIOMES[k].duplicate()
		for key in DAY[k]:
			b[key] = DAY[k][key]
		b.day = true
		_day_cache[k] = b
	return _day_cache[k]

## Switch Day on or off; the world grade is lighter in daylight.
static func set_day(on: bool) -> void:
	day = on
	for m in [_grade_mix, _grade_add]:
		if m != null:
			m.set_shader_parameter("grade", 0.45 if on else 1.0)

## Blend two palettes (biome transitions).
static func blend_biome(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	if t <= 0.0:
		return a
	if t >= 1.0:
		return b
	var o := a.duplicate()
	o.sky = [a.sky[0].lerp(b.sky[0], t), a.sky[1].lerp(b.sky[1], t), a.sky[2].lerp(b.sky[2], t)]
	o.layers = [a.layers[0].lerp(b.layers[0], t), a.layers[1].lerp(b.layers[1], t), a.layers[2].lerp(b.layers[2], t)]
	for k in ["sun", "fog", "ground", "rim", "accent", "mote", "obstacle"]:
		o[k] = a[k].lerp(b[k], t)
	o.sun_pos = a.sun_pos.lerp(b.sun_pos, t)
	o.sun_r = lerpf(a.sun_r, b.sun_r, t)
	o.stars = lerpf(a.stars, b.stars, t)
	o.aurora = lerpf(a.aurora, b.aurora, t)
	o.water = lerpf(a.water, b.water, t)
	o.kinds = a.kinds if t < 0.5 else b.kinds
	o.surface = a.get("surface", "") if t < 0.5 else b.get("surface", "")
	for k in ["town", "life", "ships", "air"]:
		o[k] = a.get(k) if t < 0.5 else b.get(k)
	return o
