extends Control
## Ergonomic touch layout "Rocker + Action": left thumb rocker (top = Hop /
## hold to Hover, bottom = Scoot / Dive), right thumb Gust (big) and Letter.
## Acts on touch-down, supports drag-enter between zones and multi-touch.
## Left-handed mode mirrors it. Keyboard/gamepad handled in main.gd.

const Art = preload("res://scripts/art.gd")

var left_handed = false
var scale_k = 1.0
var letters = 3
var visible_controls = true
var highlight = "" # tutorial: pulse the zone to press
var state = {"jump": false, "down": false, "gust": false, "letter": false}
var pressed = {"jump": false, "down": false, "gust": false, "letter": false}
var _touch_zone = {}
var _flash = {"jump": 0.0, "down": 0.0, "gust": 0.0, "letter": 0.0}
## Portrait deck (0.8.35, scripts/shell.gd): its buttons press these zones; the
## on-screen overlay hides while the deck is showing.
var deck_mode := false
var _deck_held := {}

func deck_press(zn: String) -> void:
	_deck_held[zn] = true
	_press(zn)

func deck_release(zn: String) -> void:
	_deck_held.erase(zn)
	_recount()

func flash(zn: String) -> float:
	return _flash.get(zn, 0.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _zones() -> Dictionary:
	var sz = get_viewport_rect().size
	var k = scale_k * clampf(sz.y / 1080.0, 0.6, 1.4)
	var rocker = Vector2(190 * k, sz.y - 250 * k)
	var gust = Vector2(sz.x - 200 * k, sz.y - 190 * k)
	var letter = Vector2(sz.x - 360 * k, sz.y - 330 * k)
	if left_handed:
		rocker.x = sz.x - rocker.x
		gust.x = sz.x - gust.x
		letter.x = sz.x - letter.x
	return {"rocker": rocker, "gust": gust, "letter": letter, "k": k}

func zone_at(p: Vector2) -> String:
	var z = _zones()
	var k: float = z.k
	var sz = get_viewport_rect().size
	# generous: whole thumb half of the screen
	var on_left = p.x < sz.x * 0.42
	var on_right = p.x > sz.x * 0.58
	if left_handed:
		var tmp = on_left
		on_left = on_right
		on_right = tmp
	if on_left and p.y > sz.y * 0.35:
		return "jump" if p.y < z.rocker.y else "down"
	if on_right and p.y > sz.y * 0.35:
		if p.distance_to(z.letter) < 120 * k:
			return "letter"
		return "gust"
	return ""

func handle(event: InputEvent) -> bool:
	if not visible_controls or deck_mode:
		return false
	if event is InputEventScreenTouch:
		if event.pressed:
			var zn = zone_at(event.position)
			if zn != "":
				_touch_zone[event.index] = zn
				_press(zn)
				return true
		else:
			if _touch_zone.has(event.index):
				_touch_zone.erase(event.index)
				_recount()
				return true
	elif event is InputEventScreenDrag:
		if _touch_zone.has(event.index):
			var zn2 = zone_at(event.position)
			if zn2 != "" and zn2 != _touch_zone[event.index]:
				# drag-enter: slide thumb from Hop to Scoot without lifting
				_touch_zone[event.index] = zn2
				_press(zn2)
				_recount()
			return true
	return false

func _press(zn: String) -> void:
	pressed[zn] = true
	state[zn] = true
	_flash[zn] = 1.0

func _recount() -> void:
	for k in state:
		state[k] = false
	for i in _touch_zone:
		state[_touch_zone[i]] = true
	for zn in _deck_held:
		state[zn] = true

func consume() -> Dictionary:
	var p = pressed.duplicate()
	for k in pressed:
		pressed[k] = false
	return p

func release_all() -> void:
	_touch_zone.clear()
	_deck_held.clear()
	_recount()

func _process(dt: float) -> void:
	for k in _flash:
		_flash[k] = maxf(_flash[k] - dt * 4.0, 0.0)
	queue_redraw()

func _draw() -> void:
	if not visible_controls or deck_mode:
		return
	var z = _zones()
	var k: float = z.k
	var r: Vector2 = z.rocker
	var base = Color(1, 1, 1, 0.10)
	var line = Color(1, 1, 1, 0.35)
	# rocker pill
	var pill = Art.rrect(Rect2(r.x - 80 * k, r.y - 170 * k, 160 * k, 340 * k), 80 * k)
	draw_colored_polygon(pill, base)
	var up_a = 0.25 + (0.5 if state.jump else 0.0) + _flash.jump * 0.3
	var dn_a = 0.25 + (0.5 if state.down else 0.0) + _flash.down * 0.3
	draw_colored_polygon(Art.ellipse(r + Vector2(0, -88 * k), Vector2(70, 70) * k, 28), Color(0.3, 1.0, 1.0, up_a * 0.4))
	draw_colored_polygon(Art.ellipse(r + Vector2(0, 88 * k), Vector2(70, 70) * k, 28), Color(1.0, 0.4, 0.8, dn_a * 0.4))
	_arrow(r + Vector2(0, -88 * k), -1.0, k, line)
	_arrow(r + Vector2(0, 88 * k), 1.0, k, line)
	match highlight:
		"jump": _pulse(r + Vector2(0, -88 * k), 70 * k)
		"down": _pulse(r + Vector2(0, 88 * k), 70 * k)
		"gust": _pulse(z.gust, 105 * k)
		"letter": _pulse(z.letter, 70 * k)
	# gust
	var g: Vector2 = z.gust
	draw_colored_polygon(Art.ellipse(g, Vector2(105, 105) * k, 32), Color(0.45, 1.0, 0.6, 0.12 + (0.3 if state.gust else 0.0) + _flash.gust * 0.3))
	draw_arc(g, 105 * k, 0, TAU, 40, line, 3.0, Art.AA)
	for i in 3:
		draw_arc(g + Vector2(-20 * k + i * 16 * k, 0), (26 + i * 10) * k, -0.8, 0.8, 10, line, 4.0, Art.AA)
	# letter
	var l: Vector2 = z.letter
	draw_colored_polygon(Art.ellipse(l, Vector2(70, 70) * k, 28), Color(1.0, 0.85, 0.4, 0.10 + (0.3 if state.letter else 0.0) + _flash.letter * 0.3))
	draw_arc(l, 70 * k, 0, TAU, 32, line, 3.0, Art.AA)
	var pl = PackedVector2Array([l + Vector2(26, 0) * k, l + Vector2(-20, -16) * k, l + Vector2(-10, 0) * k, l + Vector2(-20, 16) * k])
	draw_colored_polygon(pl, Color(1, 1, 1, 0.6))
	for i in 3:
		var c = Color(1.0, 0.85, 0.4, 0.9 if i < letters else 0.15)
		draw_circle(l + Vector2((-22 + i * 22) * k, 92 * k), 7 * k, c)

func _pulse(c: Vector2, r: float) -> void:
	var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0)
	draw_arc(c, r * (1.05 + 0.12 * k), 0, TAU, 48, Color(0.7, 1.0, 0.95, 0.5 + 0.5 * k), 6.0, Art.AA)
	draw_arc(c, r * (1.25 + 0.2 * k), 0, TAU, 48, Color(0.7, 1.0, 0.95, 0.3 * (1.0 - k)), 4.0, Art.AA)

func _arrow(c: Vector2, dir: float, k: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-24, -12 * dir) * k, c + Vector2(0, 12 * dir) * k, c + Vector2(24, -12 * dir) * k]), col, 6.0, Art.AA)
