extends Node2D
## Lightweight additive particle system (world space): sparks, dust, wind,
## mote bursts, ring pulses and speed streaks.

const Art = preload("res://scripts/art.gd")

var parts: Array = []
var rings: Array = []
var winds: Array = []
var max_parts = 600
var density = 1.0

func _ready() -> void:
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m

func burst(p: Vector2, col: Color, n: int, spd := 300.0, life := 0.6, size := 4.0, grav := 0.0, spread := TAU, dir := 0.0) -> void:
	n = int(n * density)
	for i in n:
		if parts.size() >= max_parts:
			parts.pop_front()
		var a = dir + randf_range(-spread * 0.5, spread * 0.5)
		var v = Vector2(cos(a), sin(a)) * spd * randf_range(0.3, 1.0)
		parts.append({"p": p, "v": v, "l": life * randf_range(0.6, 1.0), "m": life, "s": size * randf_range(0.6, 1.2), "c": col, "g": grav})

func ring(p: Vector2, col: Color, r1 := 120.0, life := 0.45, w := 5.0) -> void:
	rings.append({"p": p, "c": col, "r": r1, "l": life, "m": life, "w": w})

func gust(p: Vector2) -> void:
	for k in 4:
		winds.append({"p": p + Vector2(10, -10 * k + 10), "l": 0.35, "m": 0.35, "k": k})

func tick(dt: float) -> void:
	for q in parts:
		q.l -= dt
		q.v.y += q.g * dt
		q.v *= 1.0 - 1.8 * dt
		q.p += q.v * dt
	parts = parts.filter(func(q): return q.l > 0.0)
	for r in rings:
		r.l -= dt
	rings = rings.filter(func(r): return r.l > 0.0)
	for w in winds:
		w.l -= dt
		w.p.x += 900.0 * dt
	winds = winds.filter(func(w): return w.l > 0.0)
	queue_redraw()

func _draw() -> void:
	for q in parts:
		var f: float = q.l / q.m
		var c: Color = q.c
		draw_circle(q.p, q.s * (0.4 + f * 0.6), Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, f))
	for r in rings:
		var f2: float = 1.0 - r.l / r.m
		draw_arc(r.p, r.r * ease(f2, 0.4), 0.0, TAU, 40, Color(r.c, (1.0 - f2) * 0.9), r.w * (1.0 - f2) + 1.0, true)
	for w in winds:
		var f3: float = w.l / w.m
		var c3 = Color(0.6, 1.0, 0.85, f3 * 0.8)
		draw_arc(w.p, 26.0 + (1.0 - f3) * 40.0, -0.9, 0.9, 12, c3, 3.0, true)
