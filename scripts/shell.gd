extends Control
## Display shell (0.8.35): the game renders into a SubViewport shown here.
## Landscape: the game fills the window exactly as before (rendered at the
## window's real pixel size, so nothing gets blurrier).
## Portrait (owner: "Game Boy style"): a tall window or a phone held upright
## shows the game as a 16:9 screen at the top with a controller deck below:
## a Hop/Scoot rocker, big Gust and Letter buttons, Pause and Hide. Hide tucks
## the deck away (remembered); a small pill brings it back. Works on PC too.

const MAIN := preload("res://main.tscn")
const Art = preload("res://scripts/art.gd")

var sub: SubViewport
var view: TextureRect
var game: Node
var portrait := false
var game_rect := Rect2()
var deck_rect := Rect2()
var _held := {}          # pointer id -> zone
var _pill_rect := Rect2()

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

func _layout() -> void:
	var S := get_viewport_rect().size
	var win := Vector2(get_window().size)
	var f := win / S if get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS else Vector2.ONE
	portrait = S.y > S.x * 1.05
	var r := Rect2(Vector2.ZERO, S)
	if portrait:
		var gh := S.x * 9.0 / 16.0
		r = Rect2(0, (S.y - gh) * 0.42, S.x, gh) if _deck_hidden() else Rect2(0, S.y * 0.035, S.x, gh)
	game_rect = r
	deck_rect = Rect2(0, r.end.y, S.x, S.y - r.end.y) if portrait else Rect2()
	view.position = r.position
	view.size = r.size
	var logical := Vector2i(r.size.round())
	var px := Vector2i((r.size * f).round())
	if sub.size_2d_override != logical:
		sub.size_2d_override = logical
	if sub.size != px:
		sub.size = px

func _process(_dt: float) -> void:
	_layout()
	if game != null and "touch" in game and game.touch != null:
		game.touch.deck_mode = portrait and not _deck_hidden()
	queue_redraw()

# ------------------------------------------------------------------ input
func _to_game(ev: InputEvent) -> InputEvent:
	var k := Vector2(sub.size) / game_rect.size
	return ev.xformed_by(Transform2D.IDENTITY.translated(-game_rect.position).scaled(k))

func _gui_input(ev: InputEvent) -> void:
	# deck buttons first (portrait), everything else goes to the game
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

func _zones() -> Dictionary:
	var d := deck_rect
	var u: float = minf(d.size.y * 0.22, d.size.x * 0.13)
	var cy := d.position.y + d.size.y * 0.44
	return {
		"u": u,
		"rocker": Vector2(d.position.x + d.size.x * 0.22, cy),
		"gust": Vector2(d.position.x + d.size.x * 0.80, cy + u * 0.35),
		"letter": Vector2(d.position.x + d.size.x * 0.60, cy - u * 0.55),
		"pause": Rect2(d.position.x + d.size.x * 0.5 - u * 1.55, d.end.y - u * 1.0, u * 1.4, u * 0.5),
		"hide": Rect2(d.position.x + d.size.x * 0.5 + u * 0.15, d.end.y - u * 1.0, u * 1.4, u * 0.5),
	}

func _zone_at(p: Vector2) -> String:
	if _deck_hidden():
		return "show" if _pill_rect.grow(20).has_point(p) else ""
	if not deck_rect.has_point(p):
		return ""
	var z := _zones()
	var u: float = z.u
	if (z.pause as Rect2).grow(16).has_point(p):
		return "pause"
	if (z.hide as Rect2).grow(16).has_point(p):
		return "hide"
	if p.distance_to(z.letter) < u * 0.75:
		return "letter"
	if p.distance_to(z.gust) < u * 1.0:
		return "gust"
	var rk: Vector2 = z.rocker
	if absf(p.x - rk.x) < u * 0.95 and absf(p.y - rk.y) < u * 1.9:
		return "jump" if p.y < rk.y else "down"
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
		var zn2 := _zone_at(pos)
		if zn2 in ["jump", "down"] and zn2 != _held[id]:
			_release(_held[id])
			_held[id] = zn2
			game.touch.deck_press(zn2)
		return true
	if down:
		var zn := _zone_at(pos)
		if zn == "":
			return false
		_held[id] = zn
		match zn:
			"pause": _pause()
			"hide": _set_hidden(true)
			"show": _set_hidden(false)
			_: game.touch.deck_press(zn)
		return true
	if _held.has(id):
		_release(_held[id])
		_held.erase(id)
		return true
	return false

func _release(zn: String) -> void:
	if zn in ["jump", "down", "gust", "letter"]:
		game.touch.deck_release(zn)

func _set_hidden(h: bool) -> void:
	game.save.data.settings.deck_hidden = h
	game.save.save()
	game.touch.release_all()
	_held.clear()

func _pause() -> void:
	if game.state in ["run", "recovery", "junction", "rescue", "paused"]:
		game.toggle_pause()
		return
	# on menus Pause works as Back
	for pressed in [true, false]:
		var k := InputEventKey.new()
		k.keycode = KEY_ESCAPE
		k.physical_keycode = KEY_ESCAPE
		k.pressed = pressed
		sub.push_input(k, false)

# ------------------------------------------------------------------ deck art
func _draw() -> void:
	if not portrait:
		return
	var S := get_viewport_rect().size
	# console body behind everything (also behind the screen)
	draw_rect(Rect2(Vector2.ZERO, S), Color(0.07, 0.08, 0.14))
	draw_colored_polygon(PackedVector2Array([Vector2(0, S.y * 0.5), Vector2(S.x, S.y * 0.5), S, Vector2(0, S.y)]), Color(0.10, 0.11, 0.19))
	# screen bezel
	var b := game_rect.grow(10)
	draw_colored_polygon(Art.rrect(b, 18), Color(0.02, 0.02, 0.05))
	draw_line(Vector2(b.position.x + 30, b.end.y + 14), Vector2(b.end.x - 30, b.end.y + 14), Color(1.0, 0.45, 0.2, 0.85), 4.0)
	var font: Font = game.font if game != null and "font" in game and game.font != null else ThemeDB.fallback_font
	if game == null or game.loading:
		return
	if _deck_hidden():
		_pill_rect = Rect2(S.x * 0.5 - 170, game_rect.end.y + 60, 340, 64)
		draw_colored_polygon(Art.rrect(_pill_rect, 32), Color(1, 1, 1, 0.10))
		draw_string(font, _pill_rect.position + Vector2(0, 43), "Show controls", HORIZONTAL_ALIGNMENT_CENTER, _pill_rect.size.x, 28, Color(1, 1, 1, 0.75))
		return
	var z := _zones()
	var u: float = z.u
	var t: Dictionary = game.touch.state
	# brand plate
	draw_string(font, Vector2(deck_rect.position.x, deck_rect.position.y + u * 0.55), "KAVI  ·  Letters to Lia", HORIZONTAL_ALIGNMENT_CENTER, deck_rect.size.x, int(u * 0.22), Color(1.0, 0.92, 0.8, 0.35))
	# rocker: Hop on top, Scoot below
	var rk: Vector2 = z.rocker
	var pill := Rect2(rk.x - u * 0.8, rk.y - u * 1.75, u * 1.6, u * 3.5)
	draw_colored_polygon(Art.rrect(pill.grow(8), u * 0.85), Color(0.02, 0.02, 0.05))
	draw_colored_polygon(Art.rrect(pill, u * 0.8), Color(0.18, 0.20, 0.30))
	for e in [["jump", -1.0, Color(0.35, 0.95, 1.0), "HOP"], ["down", 1.0, Color(1.0, 0.45, 0.75), "SCOOT"]]:
		var c := rk + Vector2(0, e[1] * u * 0.85)
		var on: bool = t.get(e[0], false)
		var col: Color = e[2]
		draw_circle(c, u * 0.68, col.darkened(0.55) if not on else col.darkened(0.1))
		draw_arc(c, u * 0.68, 0, TAU, 40, Color(col, 0.6), 3.0, true)
		var d: float = -e[1]
		draw_polyline(PackedVector2Array([c + Vector2(-u * 0.25, u * 0.12 * d), c + Vector2(0, -u * 0.13 * d), c + Vector2(u * 0.25, u * 0.12 * d)]), Color(1, 1, 1, 0.9), u * 0.08, true)
		draw_string(font, Vector2(rk.x - u, c.y + e[1] * u * 1.1 + u * 0.1), e[3], HORIZONTAL_ALIGNMENT_CENTER, u * 2.0, int(u * 0.2), Color(1, 1, 1, 0.55))
	# Gust (big, teal-green) and Letter (orange)
	for e in [["gust", 1.0, Color(0.40, 0.95, 0.65), "GUST"], ["letter", 0.75, Color(1.0, 0.62, 0.25), "LETTER"]]:
		var c: Vector2 = z[e[0]]
		var r: float = u * e[1]
		var on2: bool = t.get(e[0], false) or game.touch.flash(e[0]) > 0.5
		draw_circle(c + Vector2(0, 8), r, Color(0, 0, 0, 0.45))
		draw_circle(c, r, (e[2] as Color).darkened(0.1 if on2 else 0.35))
		draw_arc(c + Vector2(-r * 0.15, -r * 0.15), r * 0.7, PI * 1.05, PI * 1.5, 12, Color(1, 1, 1, 0.45), r * 0.08, true)
		draw_string(font, Vector2(c.x - r * 1.5, c.y + r + (u * 0.62 if e[0] == "letter" else u * 0.32)), e[3], HORIZONTAL_ALIGNMENT_CENTER, r * 3.0, int(u * 0.2), Color(1, 1, 1, 0.55))
	# gust swirl and paper plane icons
	var g: Vector2 = z.gust
	for i in 3:
		draw_arc(g + Vector2(-u * 0.2 + i * u * 0.15, 0), u * (0.22 + i * 0.1), -0.8, 0.8, 10, Color(1, 1, 1, 0.85), u * 0.06, true)
	var l: Vector2 = z.letter
	var s := u * 0.022
	draw_colored_polygon(PackedVector2Array([l + Vector2(16, 0) * s * 1.4, l + Vector2(-13, -11) * s * 1.4, l + Vector2(-6, 0) * s * 1.4, l + Vector2(-13, 11) * s * 1.4]), Color(1, 1, 1, 0.9))
	for i in 3:
		draw_circle(l + Vector2((-1 + i) * u * 0.22, u * 0.92), u * 0.06, Color(1.0, 0.85, 0.4, 0.9 if i < int(game.touch.letters) else 0.18))
	# Pause and Hide pills
	for e in [["pause", "PAUSE"], ["hide", "HIDE"]]:
		var pr: Rect2 = z[e[0]]
		draw_colored_polygon(Art.rrect(pr, pr.size.y * 0.5), Color(0.20, 0.22, 0.32))
		draw_string(font, pr.position + Vector2(0, pr.size.y * 0.68), e[1], HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, int(u * 0.2), Color(1, 1, 1, 0.7))
