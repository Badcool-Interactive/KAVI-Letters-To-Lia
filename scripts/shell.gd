extends Control
## Display shell (0.8.35): the game renders into a SubViewport shown here.
## Landscape: the game fills the window exactly as before (rendered at the
## window's real pixel size, so nothing gets blurrier).
## Portrait (owner: "Game Boy style"): a tall window or a phone held upright
## shows the game on a little console: a screen with a bezel at the top and a
## controller below. Hide tucks the controller away (remembered); a pill brings
## it back. Works on PC too.
##
## 0.8.36 (owner: "on menus give normal arrows, Enter and Back so players don't
## reach for the screen; swap to game controls when you enter"): one controller
## with two modes that swap with a little animation:
##   menus: D-pad = arrow keys, A = Enter, B = Back, Hide
##   game:  D-pad up = Hop, down = Scoot, A = Gust, B = Letter, Pause, Hide
## While the controller shows, the on-screen pause button and touch overlay hide.

const MAIN := preload("res://main.tscn")
const Art = preload("res://scripts/art.gd")

const INK := Color(0.03, 0.03, 0.07)
const BODY_TOP := Color(0.16, 0.15, 0.27)
const BODY_BOT := Color(0.10, 0.10, 0.19)
const PLASTIC := Color(0.21, 0.21, 0.33)
const ORANGE := Color(1.0, 0.48, 0.22)
const TEAL := Color(0.30, 0.86, 0.82)
const PINK := Color(1.0, 0.45, 0.70)
const GREEN := Color(0.36, 0.88, 0.60)
const LILAC := Color(0.70, 0.58, 1.0)
const GAME_STATES := ["run", "recovery", "rescue", "fail"]

var sub: SubViewport
var view: TextureRect
var game: Node
var portrait := false
var game_rect := Rect2()
var deck_rect := Rect2()
var _held := {}          # pointer id -> zone
var _pill_rect := Rect2()
var _mode_k := 0.0       # 0 = menu controls, 1 = game controls (animated)
var _mode := "menu"
var _swap_t := 9.0       # time since the last swap (button bounce)
var _repeat := {}        # zone -> [next repeat time, keycode]
var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	sub = SubViewport.new()
	sub.size_2d_override_stretch = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.physics_object_picking = false
	add_child(sub)
	view = TextureRect.new()
	view.texture = sub.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_layout()
	game = MAIN.instantiate()
	sub.add_child(game)

func _deck_hidden() -> bool:
	if game == null or not ("save" in game) or game.save == null:
		return false
	return bool(game.save.data.settings.get("deck_hidden", false))

func _deck_on() -> bool:
	return portrait and not _deck_hidden()

func _layout() -> void:
	var S := get_viewport_rect().size
	var win := Vector2(get_window().size)
	var f := win / S if get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS else Vector2.ONE
	portrait = S.y > S.x * 1.05
	var r := Rect2(Vector2.ZERO, S)
	if portrait:
		# the screen sits inside a bezel, a little in from the console's edges
		var gw := S.x * 0.90
		var gh := gw * 9.0 / 16.0
		var gx := (S.x - gw) * 0.5
		r = Rect2(gx, (S.y - gh) * 0.42, gw, gh) if _deck_hidden() else Rect2(gx, S.x * 0.08, gw, gh)
	game_rect = r
	deck_rect = Rect2(0, r.end.y + S.x * 0.09, S.x, S.y - r.end.y - S.x * 0.09) if portrait else Rect2()
	view.position = r.position
	view.size = r.size
	var logical := Vector2i(r.size.round())
	var px := Vector2i((r.size * f).round())
	if sub.size_2d_override != logical:
		sub.size_2d_override = logical
	if sub.size != px:
		sub.size = px

func _process(dt: float) -> void:
	_t += dt
	_layout()
	if game == null or not ("touch" in game) or game.touch == null:
		return
	var on := _deck_on()
	game.touch.deck_mode = on
	game.set_meta("deck_active", on)
	# which controls: game controls only while actually running
	var want := "game" if (str(game.state) in GAME_STATES and not game.loading) else "menu"
	if want != _mode:
		_mode = want
		_swap_t = 0.0
		_release_all()
	_swap_t += dt
	_mode_k = move_toward(_mode_k, 1.0 if _mode == "game" else 0.0, dt / 0.28)
	# held arrows repeat like a keyboard
	for zn in _repeat.keys():
		if _t >= float(_repeat[zn][0]):
			_repeat[zn][0] = _t + 0.11
			_key(int(_repeat[zn][1]), true, true)
	queue_redraw()

# ------------------------------------------------------------------ input
func _to_game(ev: InputEvent) -> InputEvent:
	var k := Vector2(sub.size) / game_rect.size
	return ev.xformed_by(Transform2D.IDENTITY.translated(-game_rect.position).scaled(k))

func _gui_input(ev: InputEvent) -> void:
	# controller buttons first (portrait), everything else goes to the game
	if portrait and _deck_event(ev):
		accept_event()
		return
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		if not game_rect.has_point(ev.position) and ev.is_pressed():
			return
	sub.push_input(_to_game(ev), false)

func _unhandled_input(ev: InputEvent) -> void:
	# keys, gamepad and anything else not positional
	if not (ev is InputEventMouse or ev is InputEventScreenTouch or ev is InputEventScreenDrag or ev is InputEventGesture):
		sub.push_input(ev, false)
		get_viewport().set_input_as_handled()

func _key(code: int, pressed: bool, echo := false) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = pressed
	k.echo = echo
	# through Input, exactly like a real key (menus also read Input's key
	# state); it then reaches the game via _unhandled_input below
	Input.parse_input_event(k)

func _zones() -> Dictionary:
	var d := deck_rect
	var u: float = minf(d.size.y * 0.13, d.size.x * 0.095)
	var cy := d.position.y + d.size.y * 0.36
	return {
		"u": u,
		"dpad": Vector2(d.position.x + d.size.x * 0.26, cy),
		"b": Vector2(d.position.x + d.size.x * 0.64, cy + u * 0.55),
		"a": Vector2(d.position.x + d.size.x * 0.82, cy - u * 0.55),
		"hide": Rect2(d.position.x + d.size.x * 0.5 - u * 1.85, d.position.y + d.size.y * 0.70, u * 1.6, u * 0.55),
		"pause": Rect2(d.position.x + d.size.x * 0.5 + u * 0.25, d.position.y + d.size.y * 0.70, u * 1.6, u * 0.55),
	}

func _zone_at(p: Vector2) -> String:
	if _deck_hidden():
		return "show" if _pill_rect.grow(20).has_point(p) else ""
	if not deck_rect.has_point(p):
		return ""
	var z := _zones()
	var u: float = z.u
	if (z.hide as Rect2).grow(18).has_point(p):
		return "hide"
	if (z.pause as Rect2).grow(18).has_point(p):
		return "pause" if _mode == "game" else ""
	if p.distance_to(z.a) < u * 0.95:
		return "a"
	if p.distance_to(z.b) < u * 0.95:
		return "b"
	var v: Vector2 = p - z.dpad
	if v.length() < u * 2.1:
		if absf(v.x) > absf(v.y):
			return "right" if v.x > 0 else "left"
		return "down" if v.y > 0 else "up"
	return ""

func _deck_event(ev: InputEvent) -> bool:
	var id := -1
	var pos := Vector2.ZERO
	var down := false
	var drag := false
	if ev is InputEventScreenTouch:
		id = ev.index
		pos = ev.position
		down = ev.pressed
	elif ev is InputEventScreenDrag:
		id = ev.index
		pos = ev.position
		drag = true
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.device != InputEvent.DEVICE_ID_EMULATION:
		id = 1000
		pos = ev.position
		down = ev.pressed
	elif ev is InputEventMouseMotion and ev.device != InputEvent.DEVICE_ID_EMULATION and _held.has(1000):
		id = 1000
		pos = ev.position
		drag = true
	else:
		return false
	if drag:
		if not _held.has(id):
			return false
		# slide a thumb around the D-pad without lifting it
		var zn2 := _zone_at(pos)
		if zn2 in ["up", "down", "left", "right"] and zn2 != _held[id] and _held[id] in ["up", "down", "left", "right"]:
			_up(_held[id])
			_held[id] = zn2
			_down(zn2)
		return true
	if down:
		var zn := _zone_at(pos)
		if zn == "":
			return false
		_held[id] = zn
		_down(zn)
		return true
	if _held.has(id):
		_up(_held[id])
		_held.erase(id)
		return true
	return false

const KEYS := {"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "a": KEY_ENTER, "b": KEY_ESCAPE}
const GAME_ZONES := {"up": "jump", "down": "down", "a": "gust", "b": "letter"}

func _down(zn: String) -> void:
	match zn:
		"hide":
			_set_hidden(true)
			return
		"show":
			_set_hidden(false)
			return
		"pause":
			game.toggle_pause()
			return
	if _mode == "game":
		if GAME_ZONES.has(zn):
			game.touch.deck_press(GAME_ZONES[zn])
		return
	if KEYS.has(zn):
		_key(KEYS[zn], true)
		if zn in ["up", "down", "left", "right"]:
			_repeat[zn] = [_t + 0.4, KEYS[zn]]

func _up(zn: String) -> void:
	_repeat.erase(zn)
	if _mode == "game":
		if GAME_ZONES.has(zn):
			game.touch.deck_release(GAME_ZONES[zn])
		return
	if KEYS.has(zn):
		_key(KEYS[zn], false)

func _release_all() -> void:
	for id in _held.keys():
		_up(_held[id])
	_held.clear()
	_repeat.clear()
	if game != null and game.touch != null:
		game.touch.release_all()

func _set_hidden(h: bool) -> void:
	game.save.data.settings.deck_hidden = h
	game.save.save()
	_release_all()

func _pressed(zn: String) -> bool:
	for id in _held:
		if _held[id] == zn:
			return true
	return false

# ------------------------------------------------------------------ console art
func _draw() -> void:
	if not portrait:
		return
	var S := get_viewport_rect().size
	# console body: soft vertical gradient, rounded, with the big bottom-right
	# corner of a classic handheld
	draw_rect(Rect2(Vector2.ZERO, S), Color(0.04, 0.04, 0.08))
	var body := _shape_rect(Rect2(Vector2(8, 8), S - Vector2(16, 16)), 56.0, S.x * 0.16)
	var cols := PackedColorArray()
	for p in body:
		cols.append(BODY_TOP.lerp(BODY_BOT, clampf(p.y / S.y, 0.0, 1.0)))
	draw_polygon(body, cols)
	draw_polyline(_closed(body), Color(1, 1, 1, 0.06), 3.0, true)
	# screen bezel with a power light and the name plate
	var b := Rect2(game_rect.position - Vector2(S.x * 0.03, S.x * 0.03), game_rect.size + Vector2(S.x * 0.06, S.x * 0.085))
	draw_colored_polygon(Art.rrect(b.grow(4), 30), Color(0, 0, 0, 0.35))
	draw_colored_polygon(Art.rrect(b, 28), Color(0.07, 0.07, 0.13))
	draw_colored_polygon(Art.rrect(game_rect.grow(5), 8), INK)
	var font: Font = game.font if game != null and "font" in game and game.font != null else ThemeDB.fallback_font
	var fs := int(S.x * 0.022)
	var led := Vector2(b.position.x + S.x * 0.05, b.end.y - S.x * 0.03)
	var glow := 0.75 + 0.25 * sin(_t * 2.0)
	draw_circle(led, S.x * 0.012, Color(TEAL, 0.25 * glow))
	draw_circle(led, S.x * 0.006, Color(TEAL, glow))
	draw_string(font, led + Vector2(S.x * 0.02, fs * 0.36), "POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.7), Color(1, 1, 1, 0.35))
	draw_string(font, Vector2(b.position.x, b.end.y - S.x * 0.03 + fs * 0.36), "KAVI  ·  Letters to Lia", HORIZONTAL_ALIGNMENT_RIGHT, b.size.x - S.x * 0.05, fs, Color(1.0, 0.9, 0.78, 0.55))
	# the scarf stripe
	draw_line(Vector2(b.position.x + S.x * 0.05, b.end.y + S.x * 0.025), Vector2(b.end.x - S.x * 0.05, b.end.y + S.x * 0.025), ORANGE, 5.0, true)
	if game == null or game.loading:
		return
	if _deck_hidden():
		_pill_rect = Rect2(S.x * 0.5 - 190, game_rect.end.y + S.x * 0.13, 380, 70)
		draw_colored_polygon(Art.rrect(_pill_rect, 35), PLASTIC)
		draw_string(font, _pill_rect.position + Vector2(0, 46), "Show controls", HORIZONTAL_ALIGNMENT_CENTER, _pill_rect.size.x, 30, Color(1, 1, 1, 0.8))
		return
	var z := _zones()
	var u: float = z.u
	var k := ease(_mode_k, -2.0)   # 0 menu .. 1 game, eased
	var bounce := 1.0 + 0.08 * sin(clampf(_swap_t / 0.3, 0.0, 1.0) * PI)
	# mode chip
	var chip := "GAME CONTROLS" if _mode == "game" else "MENU CONTROLS"
	var chip_c := GREEN if _mode == "game" else ORANGE
	draw_string(font, Vector2(deck_rect.position.x, deck_rect.position.y + u * 0.35), chip, HORIZONTAL_ALIGNMENT_CENTER, deck_rect.size.x, int(u * 0.2), Color(chip_c, 0.75))
	_draw_dpad(z.dpad, u * bounce, k, font)
	_draw_ab(z, u, k, bounce, font)
	# Hide and Pause pills, tilted like a handheld's Select / Start
	_pill(z.hide, "HIDE", 1.0, _pressed("hide"), font, u)
	_pill(z.pause, "PAUSE", k, _pressed("pause"), font, u)
	# speaker grille
	var g := Vector2(deck_rect.end.x - u * 1.7, deck_rect.end.y - u * 1.3)
	for i in 6:
		var o := Vector2(i * u * 0.2, 0).rotated(-0.5)
		draw_line(g + o + Vector2(0, -u * 0.45).rotated(-0.5), g + o + Vector2(0, u * 0.45).rotated(-0.5), Color(0, 0, 0, 0.45), u * 0.07, true)

func _draw_dpad(c: Vector2, u: float, k: float, font: Font) -> void:
	var L := u * 1.35
	var w := u * 0.95
	var shadow := Vector2(0, u * 0.12)
	for r in [Rect2(c.x - w * 0.5, c.y - L, w, L * 2.0), Rect2(c.x - L, c.y - w * 0.5, L * 2.0, w)]:
		draw_colored_polygon(Art.rrect(r.grow(u * 0.1), u * 0.25), Color(0, 0, 0, 0.5))
	for r in [Rect2(c.x - w * 0.5, c.y - L, w, L * 2.0), Rect2(c.x - L, c.y - w * 0.5, L * 2.0, w)]:
		draw_colored_polygon(Art.rrect(Rect2(r.position + shadow, r.size), u * 0.18), INK)
		draw_colored_polygon(Art.rrect(r, u * 0.18), PLASTIC)
	draw_circle(c, u * 0.26, PLASTIC.darkened(0.25))
	# arms: arrows (menus) or Hop / Scoot (game)
	for e in [["up", Vector2(0, -1)], ["down", Vector2(0, 1)], ["left", Vector2(-1, 0)], ["right", Vector2(1, 0)]]:
		var dir: Vector2 = e[1]
		var arm := c + dir * L * 0.62
		var on: bool = _pressed(e[0])
		var col := Color(1, 1, 1, 0.85)
		if e[0] == "up":
			col = Color(1, 1, 1, 0.85).lerp(TEAL, k)
		elif e[0] == "down":
			col = Color(1, 1, 1, 0.85).lerp(PINK, k)
		else:
			col.a = lerpf(0.85, 0.25, k)   # left / right do nothing in a run
		if on:
			draw_colored_polygon(Art.rrect(Rect2(arm - Vector2(w, w) * 0.42, Vector2(w, w) * 0.84), u * 0.15), Color(col, 0.35))
		var tip := arm + dir * u * 0.22
		var side := Vector2(-dir.y, dir.x) * u * 0.22
		draw_colored_polygon(PackedVector2Array([tip, arm - dir * u * 0.12 + side, arm - dir * u * 0.12 - side]), col)
	var fs := int(u * 0.22)
	if k > 0.01:
		draw_string(font, Vector2(c.x - u * 1.5, c.y - L - u * 0.25), "HOP", HORIZONTAL_ALIGNMENT_CENTER, u * 3.0, fs, Color(TEAL, k))
		draw_string(font, Vector2(c.x - u * 1.5, c.y + L + u * 0.5), "SCOOT", HORIZONTAL_ALIGNMENT_CENTER, u * 3.0, fs, Color(PINK, k))

func _draw_ab(z: Dictionary, u: float, k: float, bounce: float, font: Font) -> void:
	var a: Vector2 = z.a
	var b: Vector2 = z.b
	# tilted recess behind the two buttons
	var mid := (a + b) * 0.5
	var ang := (a - b).angle()
	var len := a.distance_to(b)
	var recess := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		var ex := Vector2(cos(t) * (len * 0.5 + u * 0.95), sin(t) * u * 0.95)
		recess.append(mid + ex.rotated(ang))
	draw_colored_polygon(recess, Color(0, 0, 0, 0.22))
	var fs := int(u * 0.22)
	for e in [["a", a, ORANGE.lerp(GREEN, k), "OK", "GUST"], ["b", b, LILAC.lerp(ORANGE, k), "BACK", "LETTER"]]:
		var c: Vector2 = e[1]
		var col: Color = e[2]
		var on: bool = _pressed(e[0]) or (k > 0.5 and game.touch.flash("gust" if e[0] == "a" else "letter") > 0.5)
		var r := u * 0.74 * bounce
		var drop := u * (0.04 if on else 0.12)
		draw_circle(c + Vector2(0, u * 0.12), r, INK)
		draw_circle(c + Vector2(0, u * 0.12 - drop), r, col.darkened(0.3 if on else 0.12))
		draw_arc(c + Vector2(-r * 0.12, -r * 0.18 + u * 0.12 - drop), r * 0.68, PI * 1.05, PI * 1.5, 12, Color(1, 1, 1, 0.5), r * 0.08, true)
		var ic := c + Vector2(0, u * 0.12 - drop)
		# icons cross-fade: A = check / gust swirl, B = back arrow / paper plane
		if e[0] == "a":
			if k < 0.99:
				draw_polyline(PackedVector2Array([ic + Vector2(-r * 0.3, 0), ic + Vector2(-r * 0.08, r * 0.24), ic + Vector2(r * 0.34, -r * 0.24)]), Color(1, 1, 1, 0.95 * (1.0 - k)), r * 0.13, true)
			if k > 0.01:
				for i in 3:
					draw_arc(ic + Vector2(-r * 0.25 + i * r * 0.16, 0), r * (0.2 + i * 0.12), -0.8, 0.8, 10, Color(1, 1, 1, 0.9 * k), r * 0.08, true)
		else:
			if k < 0.99:
				draw_arc(ic + Vector2(r * 0.05, r * 0.02), r * 0.3, -PI * 0.5, PI * 0.5, 12, Color(1, 1, 1, 0.95 * (1.0 - k)), r * 0.11, true)
				draw_colored_polygon(PackedVector2Array([ic + Vector2(-r * 0.32, -r * 0.28), ic + Vector2(0.0, -r * 0.48), ic + Vector2(0.0, -r * 0.08)]), Color(1, 1, 1, 0.95 * (1.0 - k)))
			if k > 0.01:
				var s := r * 0.034
				draw_colored_polygon(PackedVector2Array([ic + Vector2(16, 0) * s, ic + Vector2(-13, -11) * s, ic + Vector2(-6, 0) * s, ic + Vector2(-13, 11) * s]), Color(1, 1, 1, 0.92 * k))
				for i in 3:
					draw_circle(c + Vector2((-1 + i) * u * 0.2, u * 1.05), u * 0.055, Color(1.0, 0.85, 0.4, (0.9 if i < int(game.touch.letters) else 0.18) * k))
		# labels cross-fade too
		var ly: float = c.y + r + u * (0.55 if e[0] == "a" else 0.62) + (u * 0.2 if e[0] == "b" else 0.0)
		draw_string(font, Vector2(c.x - u * 1.5, ly), e[3], HORIZONTAL_ALIGNMENT_CENTER, u * 3.0, fs, Color(1, 1, 1, 0.6 * (1.0 - k)))
		draw_string(font, Vector2(c.x - u * 1.5, ly), e[4], HORIZONTAL_ALIGNMENT_CENTER, u * 3.0, fs, Color(1, 1, 1, 0.6 * k))

func _pill(r: Rect2, text: String, alpha: float, on: bool, font: Font, u: float) -> void:
	if alpha < 0.02:
		return
	var c := r.get_center()
	var pts := Art.rrect(Rect2(-r.size * 0.5, r.size), r.size.y * 0.5)
	var p2 := PackedVector2Array()
	for p in pts:
		p2.append(c + p.rotated(-0.42))
	draw_colored_polygon(p2, Color(INK, alpha))
	var p3 := PackedVector2Array()
	for p in pts:
		p3.append(c + (p * 0.94).rotated(-0.42) - Vector2(0, u * (0.0 if on else 0.05)))
	draw_colored_polygon(p3, Color(PLASTIC.lightened(0.1 if on else 0.0), alpha))
	draw_string(font, Vector2(r.position.x, r.end.y + u * 0.42), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(u * 0.2), Color(1, 1, 1, 0.6 * alpha))

static func _shape_rect(r: Rect2, rad: float, big: float) -> PackedVector2Array:
	# rounded rect whose bottom-right corner is much rounder (a handheld's shape)
	var out := PackedVector2Array()
	var corners := [[Vector2(r.end.x - rad, r.position.y + rad), rad, -PI * 0.5], [Vector2(r.end.x - big, r.end.y - big), big, 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), rad, PI * 0.5], [Vector2(r.position.x + rad, r.position.y + rad), rad, PI]]
	for cdef in corners:
		for i in 9:
			var a: float = cdef[2] + PI * 0.5 * i / 8.0
			out.append(cdef[0] + Vector2(cos(a), sin(a)) * cdef[1])
	return out

static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var c := p.duplicate()
	c.append(p[0])
	return c
