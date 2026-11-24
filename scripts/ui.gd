extends Control
## Menus built in code: title, garage, settings, pause, results, junction,
## recovery skip, finale, ad placeholder. Rounded glassy buttons.

const Art = preload("res://scripts/art.gd")

var main
var font: Font
var font_body: Font
var _box: Control
var _theme: Theme
var _primary: Dictionary = {}
var _focus_text := ""
const Looks = preload("res://scripts/looks.gd")
const CREAM := Color(1, 0.97, 0.92)
const INK := Color(0.13, 0.07, 0.12)

static func _sb(bg: Color, border: Color, bw: int, radius: int, shadow := 0, sh_col := Color(0, 0, 0, 0.3)) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_corner_radius_all(radius)
	b.corner_detail = 10
	b.anti_aliasing = true
	b.content_margin_left = 40
	b.content_margin_right = 40
	b.content_margin_top = 14
	b.content_margin_bottom = 16
	if shadow > 0:
		b.shadow_size = shadow
		b.shadow_color = sh_col
		b.shadow_offset = Vector2(0, shadow * 0.5)
	return b

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_menu_keys()
	_theme = Theme.new()
	_theme.default_font = font
	_theme.default_font_size = 38
	# secondary buttons: frosted glass with a soft shadow; hover lifts and glows
	var n := _sb(Color(1, 1, 1, 0.09), Color(1, 1, 1, 0.24), 2, 30, 6, Color(0, 0, 0, 0.22))
	var h := _sb(Color(1, 1, 1, 0.18), Color(1.0, 0.86, 0.55, 0.95), 3, 30, 10, Color(0, 0, 0, 0.28))
	var pr := _sb(Color(1, 1, 1, 0.26), Color(1.0, 0.86, 0.55, 1.0), 3, 30, 2, Color(0, 0, 0, 0.2))
	pr.content_margin_top = 17
	pr.content_margin_bottom = 13
	_theme.set_stylebox("normal", "Button", n)
	_theme.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), Color(1.0, 0.86, 0.55, 0.9), 3, 30))
	_theme.set_stylebox("hover", "Button", h)
	_theme.set_stylebox("pressed", "Button", pr)
	_theme.set_color("font_color", "Button", CREAM)
	_theme.set_color("font_hover_color", "Button", Color(1, 1, 1))
	_theme.set_color("font_pressed_color", "Button", Color(1, 0.92, 0.75))
	_theme.set_color("font_focus_color", "Button", Color(1, 1, 1))
	_theme.set_color("font_color", "Label", CREAM)
	_theme.set_constant("outline_size", "Label", 8)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.45))
	theme = _theme
	# primary call-to-action: warm sunset orange with a cream rim and deep shadow
	_primary = {
		"normal": _sb(Color(1.0, 0.60, 0.32), Color(1.0, 0.85, 0.55), 3, 34, 10, Color(0.35, 0.08, 0.05, 0.45)),
		"hover": _sb(Color(1.0, 0.68, 0.38), Color(1.0, 0.95, 0.75), 3, 34, 14, Color(0.35, 0.08, 0.05, 0.5)),
		"pressed": _sb(Color(0.93, 0.50, 0.26), Color(1.0, 0.85, 0.55), 3, 34, 3, Color(0.35, 0.08, 0.05, 0.4)),
		"focus": _sb(Color(0, 0, 0, 0), Color(1, 1, 1, 0.95), 4, 34),
	}

func _make_primary(b: Button) -> void:
	for k in _primary:
		b.add_theme_stylebox_override(k, _primary[k])
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, INK)

func _clear() -> void:
	if _box:
		_box.queue_free()
		_box = null

func _panel(anchor_y := 0.5, width := 760.0, backdrop := true) -> VBoxContainer:
	_clear()
	var c = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var holder: Control = c
	if backdrop:
		var pc = PanelContainer.new()
		var sb := _sb(Color(0.05, 0.06, 0.14, 0.74), Color(1, 1, 1, 0.13), 2, 44, 28, Color(0, 0, 0, 0.35))
		sb.set_content_margin_all(44)
		pc.add_theme_stylebox_override("panel", sb)
		c.add_child(pc)
		holder = pc
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(width, 0)
	if backdrop:
		holder.add_child(v)
	else:
		c.add_child(v)
		holder = v
	holder.anchor_left = 0.5
	holder.anchor_right = 0.5
	holder.anchor_top = anchor_y
	holder.anchor_bottom = anchor_y
	holder.offset_left = -width * 0.5 - (40 if backdrop else 0)
	holder.offset_right = width * 0.5 + (40 if backdrop else 0)
	holder.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box = c
	_appear(c)
	return v

## Soft entrance for every screen: fade in while settling from 97% scale.
func _appear(c: Control) -> void:
	c.modulate.a = 0.0
	c.pivot_offset = get_viewport_rect().size * 0.5
	c.scale = Vector2(0.97, 0.97)
	var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.28)
	tw.tween_property(c, "scale", Vector2.ONE, 0.32)

func _btn(v: Container, text: String, cb: Callable, size := 38) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	v.add_child(b)
	_juice(b)
	return b

## Hover/focus lifts the button a little; pressing squashes it.
func _juice(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	var to := func(sc: float, d: float):
		var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(sc, sc), d)
	b.mouse_entered.connect(to.bind(1.04, 0.18))
	b.focus_entered.connect(to.bind(1.04, 0.18))
	b.mouse_exited.connect(func(): if not b.has_focus(): to.call(1.0, 0.18))
	b.focus_exited.connect(to.bind(1.0, 0.18))
	b.button_down.connect(to.bind(0.96, 0.08))
	b.button_up.connect(to.bind(1.04, 0.14))

func _label(v: Container, text: String, size := 36, col := Color(1, 0.98, 0.94)) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if size < 44 and font_body != null:
		l.add_theme_font_override("font", font_body)
	v.add_child(l)
	return l

# ------------------------------------------------------------------ keyboard (0.8.13)
## Menus work with WASD as well as arrows; Enter, Space and E select.
func _add_menu_keys() -> void:
	var extra := {"ui_up": [KEY_W], "ui_down": [KEY_S], "ui_left": [KEY_A], "ui_right": [KEY_D], "ui_accept": [KEY_E]}
	for act in extra:
		for kc in extra[act]:
			var ev := InputEventKey.new()
			ev.physical_keycode = kc
			if not InputMap.action_has_event(act, ev):
				InputMap.action_add_event(act, ev)

## If a menu is open but nothing has focus (the mouse was used last), the first
## menu key focuses the first item instead of doing nothing.
func _input(event: InputEvent) -> void:
	if main.loading or not is_instance_valid(_box) or not _box.is_visible_in_tree():
		return
	if not (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept")):
		return
	var f := get_viewport().gui_get_focus_owner()
	if f != null and _box.is_ancestor_of(f):
		return
	var first := _first_focusable(_box)
	if first != null:
		first.grab_focus()
		get_viewport().set_input_as_handled()

func _first_focusable(n: Node) -> Control:
	for ch in n.get_children():
		if ch is BaseButton and ch.is_visible_in_tree() and not ch.disabled and ch.focus_mode != Control.FOCUS_NONE:
			return ch
		var deeper := _first_focusable(ch)
		if deeper != null:
			return deeper
	return null

var _opened_ms := 0

func _shadow(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0.01, 0.03, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 6)

## Predictable keyboard focus (0.8.14): every screen's buttons are grouped into
## rows (a horizontal box is one row, anything else is a row of its own).
## Up/Down step between rows and wrap; Left/Right step along a row and wrap,
## and do nothing on single-item rows.
func _auto_wire() -> void:
	if not is_instance_valid(_box):
		return
	var rows: Array = []
	var row_of := {}
	_collect_rows(_box, rows, row_of)
	var R := rows.size()
	if R == 0:
		return
	for r in R:
		var row: Array = rows[r]
		var n := row.size()
		for i in n:
			var b: Control = row[i]
			var left: Control = row[(i - 1 + n) % n]
			var right: Control = row[(i + 1) % n]
			var up_row: Array = rows[(r - 1 + R) % R]
			var dn_row: Array = rows[(r + 1) % R]
			var up: Control = up_row[mini(i, up_row.size() - 1)] if up_row.size() > 1 and n > 1 else up_row[0]
			var dn: Control = dn_row[mini(i, dn_row.size() - 1)] if dn_row.size() > 1 and n > 1 else dn_row[0]
			b.focus_neighbor_left = b.get_path_to(left)
			b.focus_neighbor_right = b.get_path_to(right)
			b.focus_neighbor_top = b.get_path_to(up)
			b.focus_neighbor_bottom = b.get_path_to(dn)
			b.focus_previous = b.get_path_to(left if n > 1 else up)
			b.focus_next = b.get_path_to(right if n > 1 else dn)

func _collect_rows(n: Node, rows: Array, row_of: Dictionary) -> void:
	for ch in n.get_children():
		if ch is BaseButton and ch.visible and ch.focus_mode != Control.FOCUS_NONE:
			var par := ch.get_parent()
			if par is HBoxContainer:
				var key := par.get_instance_id()
				if row_of.has(key):
					rows[row_of[key]].append(ch)
				else:
					row_of[key] = rows.size()
					rows.append([ch])
			else:
				rows.append([ch])
		elif ch is Control or ch is Node:
			_collect_rows(ch, rows, row_of)

# ------------------------------------------------------------------ screens
func show_none() -> void:
	_clear()

## Scenic View: only a small Back button; Esc also returns.
func show_scenic() -> void:
	_corner_button("Back  (Esc)", main.go_title, 28)

# ------------------------------------------------------------------ in-world menu
## A text menu item with no box: hover/focus brightens it, shows a small glowing
## diamond (Kavi's antenna kite) and draws a hairline under the text.
class MenuItem extends Button:
	var accent := Color(1.0, 0.82, 0.55)
	var status := ""
	var status_col := Color(1, 1, 1, 0.6)
	var fill := Color(1.0, 0.96, 0.90)
	var selected := false
	var hot := 0.0
	var on_focus: Callable

	func _ready() -> void:
		flat = true
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		focus_mode = Control.FOCUS_ALL
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 46
		e.content_margin_right = 12
		e.content_margin_top = 4
		e.content_margin_bottom = 8
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, e)
		# the text is drawn by _draw (with a soft drop shadow), so the
		# button's own text is invisible but still sizes the item
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(k, Color(0, 0, 0, 0))
		add_theme_constant_override("outline_size", 0)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(grab_focus)
		focus_entered.connect(func():
			if on_focus.is_valid():
				on_focus.call())

	func _process(dt: float) -> void:
		var target := 1.0 if has_focus() else 0.0
		if absf(hot - target) > 0.001:
			hot = move_toward(hot, target, dt * 7.0)
			queue_redraw()
		self_modulate.a = 0.82 + 0.18 * maxf(hot, 1.0 if selected else 0.0)
		# the focused item swells a little from its left edge (eased)
		var e := hot * hot * (3.0 - 2.0 * hot)
		pivot_offset = Vector2(0, size.y * 0.5)
		scale = Vector2.ONE * (1.0 + 0.06 * e)

	func _draw() -> void:
		var y := size.y * 0.5 - 2.0
		var f := get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# text: soft two-step drop shadow, a thin ink outline, then the fill
		var ch := size.y - 12.0
		var base := Vector2(46.0, 4.0 + (ch - (f.get_ascent(fs) + f.get_descent(fs))) * 0.5 + f.get_ascent(fs))
		var sh := maxf(2.0, fs * 0.06)
		draw_string_outline(f, base + Vector2(sh * 0.6, sh * 1.6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.22), Color(0, 0, 0, 0.16))
		draw_string(f, base + Vector2(sh * 0.6, sh * 1.2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.0, 0.01, 0.03, 0.55))
		draw_string_outline(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, int(fs * 0.14)), Color(0.02, 0.03, 0.07, 0.55))
		draw_string(f, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)
		if selected:
			draw_circle(Vector2(22, y), 4.0, Color(accent, 0.9))
		if hot > 0.01:
			var d := 9.0 * hot
			var m := Vector2(22 + 4.0 * hot, y)
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -d), m + Vector2(d * 0.7, 0), m + Vector2(0, d), m + Vector2(-d * 0.7, 0)]), Color(accent, hot))
			draw_line(Vector2(46, size.y - 6), Vector2(46 + tw * hot, size.y - 6), Color(accent, 0.55 * hot), 2.0, true)
		if status != "":
			var sf := get_theme_font("font")
			var ss := int(fs * 0.62)
			var sw := sf.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
			draw_string(sf, Vector2(size.x - sw - 8, y + ss * 0.35), status, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, status_col)

func _item(v: Container, text: String, cb: Callable, size := 40) -> MenuItem:
	var b := MenuItem.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		main.synth.play("ui")
		cb.call())
	b.focus_entered.connect(func():
		if Time.get_ticks_msec() - _opened_ms > 300:
			main.synth.play("ui", 1.9, -16.0))
	v.add_child(b)
	return b

## Right-hand column used by the title and Garage screens.
func _column(top := 0.24, animate := true) -> VBoxContainer:
	_clear()
	_opened_ms = Time.get_ticks_msec()
	_auto_wire.call_deferred()
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.anchor_left = 0.60
	v.anchor_right = 0.93
	v.anchor_top = top
	v.anchor_bottom = 0.92
	v.clip_contents = false
	c.add_child(v)
	_box = c
	if animate:
		_appear(c)
	return v

func _small(v: Container, text: String, size := 24, col := Color(1, 1, 1, 0.55)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.75))
	_shadow(l)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	if font_body != null:
		l.add_theme_font_override("font", font_body)
	v.add_child(l)
	return l

func _gap(v: Container, h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	v.add_child(g)

func show_title() -> void:
	main.garage_open = false
	main.menu_dim = false
	main.apply_look()
	var v := _column(0.30)
	var ch := int(main.save.data.story_chapter)
	var cont: bool = ch > 0 and not main.save.data.story_done
	var first := _item(v, ("Continue the journey" if cont else "Play story"), main.menu_story, 62)
	var sub := _small(v, ("Chapter %d  ·  %s" % [ch + 1, Art.biome(ch).name]) if cont else ("Carry the letters all the way to %s" % main.FRIEND), 24, Color(1.0, 0.86, 0.62, 0.75))
	sub.add_theme_constant_override("line_spacing", 0)
	_gap(v, 14)
	var rows: Array = [first]
	rows.append(_item(v, "Endless Road", main.menu_endless, 40))
	rows.append(_item(v, "Daily Relay", main.menu_daily, 40))
	rows.append(_item(v, "Scenic View", main.menu_scenic, 40))
	# rows only as wide as their words, so the sky and sea behind stay clickable
	for r in rows:
		r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_gap(v, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	v.add_child(row)
	var row_items := [["Garage", show_garage.bind("scarf")], ["Settings", show_settings], ["Tutorial", confirm_tutorial]]
	if main.can_quit():
		row_items.append(["Quit", confirm_quit])
	for it in row_items:
		var b := _item(row, it[0], it[1], 30)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Portal builds (CrazyGames etc.) must not show their own ad prompts.
	if main.ads.can_show() and not OS.has_feature("portal"):
		_item(v, "Free gift: a short ad for +1 Spark (%d left)" % main.ads.remaining_today(), main.watch_ad_for_spark, 24).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_gap(v, 18)
	# wallet + best score: bigger, outlined, so it reads over the bright ground
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 34)
	v.add_child(stats)
	for it in [["%d Stamps" % int(main.save.data.stamps), Color(1.0, 0.86, 0.55)], ["%d Sparks" % int(main.save.data.sparks), Color(0.65, 0.95, 1.0)], ["Best score %d" % main.best_any(), Color(1, 0.97, 0.9)]]:
		var l := Label.new()
		l.text = it[0]
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", it[1])
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.85))
		_shadow(l)
		stats.add_child(l)
	first.grab_focus.call_deferred()
	_glide_and_stagger(v)

## Title polish (0.8.10): a soft light band that glides to whichever item has
## focus, and the menu rows sliding in one after another.
class Glide extends Control:
	var col: VBoxContainer
	var r := Rect2()
	var vel := Vector2.ZERO
	var a := 0.0

	func _process(dt: float) -> void:
		var f := get_viewport().gui_get_focus_owner()
		var target_a := 0.0
		if f != null and col.is_ancestor_of(f) and f is Button:
			var fr: Rect2 = f.get_global_rect()
			# fit the band to the words, not the whole row
			var b: Button = f
			var tw: float = b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
			fr.size.x = minf(fr.size.x, (tw + 90.0) * b.scale.x)
			var local := Rect2(fr.position - global_position, fr.size)
			if r.size == Vector2.ZERO:
				r = local
			# critically damped spring toward the focused row
			var k := 1.0 - exp(-dt * 16.0)
			r.position = r.position.lerp(local.position, k)
			r.size = r.size.lerp(local.size, k)
			target_a = 1.0
		a = move_toward(a, target_a, dt * 4.0)
		queue_redraw()

	func _draw() -> void:
		if a <= 0.01 or r.size == Vector2.ZERO:
			return
		var warm := Color(1.0, 0.78, 0.45)
		var x0 := r.position.x - 30.0
		var x1 := r.position.x + r.size.x * 0.95
		var y0 := r.position.y + 2.0
		var y1 := r.end.y - 2.0
		var xm := lerpf(x0, x1, 0.22)
		var t := Time.get_ticks_msec() * 0.001
		var pulse := 0.85 + 0.15 * sin(t * 3.0)
		# soft glow: fades in from the left, out to the right, and out at the top
		# and bottom (a 2x3 grid of gradient quads, so there are no hard edges)
		var xs := [x0, xm, x1]
		var ax := [0.0, 1.0, 0.0]
		var hgt := y1 - y0
		var ys := [y0 - 8.0, y0 + hgt * 0.35, y1 - hgt * 0.35, y1 + 8.0]
		var ay := [0.0, 1.0, 1.0, 0.0]
		var pk := 0.24 * a * pulse
		for cx in 2:
			for cy in 3:
				draw_polygon(PackedVector2Array([Vector2(xs[cx], ys[cy]), Vector2(xs[cx + 1], ys[cy]), Vector2(xs[cx + 1], ys[cy + 1]), Vector2(xs[cx], ys[cy + 1])]),
					PackedColorArray([Color(warm, pk * ax[cx] * ay[cy]), Color(warm, pk * ax[cx + 1] * ay[cy]), Color(warm, pk * ax[cx + 1] * ay[cy + 1]), Color(warm, pk * ax[cx] * ay[cy + 1])]))
		# bright edge on the left, like light catching a page
		draw_line(Vector2(x0 + 18.0, y0 + 6.0), Vector2(x0 + 18.0, y1 - 6.0), Color(1.0, 0.92, 0.75, 0.75 * a), 3.0, true)
		# a little glint travelling along the row
		var gx := lerpf(xm, x1, fmod(t * 0.45, 1.0))
		draw_circle(Vector2(gx, y1 - 1.0), 2.5, Color(1, 0.95, 0.85, 0.6 * a))

func _glide_and_stagger(v: VBoxContainer) -> void:
	var g := Glide.new()
	g.col = v
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := v.get_parent()
	holder.add_child(g)
	holder.move_child(g, 0)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if bool(main.save.data.settings.get("reduced_motion", false)):
		return
	var rows: Array = v.get_children()
	for n in rows:
		if n is CanvasItem:
			n.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var i := 0
	for n in rows:
		if not is_instance_valid(n) or not (n is Control):
			continue
		var c: Control = n
		var base := c.position.x
		c.position.x = base + 70.0
		var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.45).set_delay(0.15 + i * 0.06)
		tw.tween_property(c, "position:x", base, 0.6).set_delay(0.15 + i * 0.06)
		i += 1

## Garage: Kavi in close-up on the left; categories and items on the right.
## Hovering an item tries it on; pressing buys (if affordable) or wears it.
## Switching tabs or buying rebuilds the list in place (no fade = no lag).
## Garage (0.8.15): moving along the category tabs (arrows, A/D, or the mouse)
## switches the list below straight away, no Enter needed. Only the item list
## is rebuilt (with a quick staggered slide-in); tabs, wallet and focus stay.
var _g_cat := "scarf"
var _g_list: VBoxContainer
var _g_scroll: ScrollContainer
var _g_tabs: Dictionary = {}
var _g_wallet: Array = []

func show_garage(cat := "scarf", animate := true) -> void:
	main.garage_open = true
	main.menu_dim = true
	main.apply_look()
	_g_cat = cat
	var v := _column(0.08, animate)
	_heading(v, "Garage", 64)
	# wallet + exchange
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 28)
	v.add_child(wallet)
	_g_wallet.clear()
	for w in [Color(1.0, 0.86, 0.55), Color(0.65, 0.95, 1.0)]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 34)
		l.add_theme_color_override("font_color", w)
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.85))
		_shadow(l)
		wallet.add_child(l)
		_g_wallet.append(l)
	_garage_wallet()
	var ex := HBoxContainer.new()
	ex.add_theme_constant_override("separation", 0)
	v.add_child(ex)
	var e1 := _item(ex, "Swap %d Stamps for 1 Spark" % Looks.STAMPS_PER_SPARK, _exchange.bind(true), 24)
	e1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var e2 := _item(ex, "1 Spark for %d Stamps" % Looks.STAMPS_FOR_SPARK, _exchange.bind(false), 24)
	e2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Looks.DEV_FREE:
		_small(v, "Preview build: everything is free to try while the game is in development.", 24, Color(0.6, 1.0, 0.85, 0.85))
	_gap(v, 4)
	_g_tabs.clear()
	const TABS_PER_ROW := 5
	var tabs: HBoxContainer
	for i in Looks.CATS.size():
		if i % TABS_PER_ROW == 0:
			tabs = HBoxContainer.new()
			tabs.add_theme_constant_override("separation", 0)
			v.add_child(tabs)
		var category: String = Looks.CATS[i]
		var tab := _item(tabs, Looks.CAT_NAMES[category], _garage_tab.bind(category), 24)
		tab.selected = category == cat
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.get_theme_stylebox("normal").content_margin_left = 34
		tab.get_theme_stylebox("normal").content_margin_right = 2
		tab.on_focus = _garage_tab.bind(category)
		_g_tabs[category] = tab
	_gap(v, 4)
	_g_scroll = ScrollContainer.new()
	_g_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_g_scroll.follow_focus = true
	_g_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_g_scroll.custom_minimum_size.y = 180
	v.add_child(_g_scroll)
	_g_list = VBoxContainer.new()
	_g_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_g_list.add_theme_constant_override("separation", 6)
	_g_scroll.add_child(_g_list)
	_gap(v, 8)
	var back := _item(v, "Back", main.go_title, 34)
	back.on_focus = main.apply_look
	_garage_fill(_focus_text, false)
	_focus_text = ""
	var fb: Control = _g_tabs[cat]
	fb.grab_focus.call_deferred()

func _garage_wallet() -> void:
	if _g_wallet.size() == 2:
		_g_wallet[0].text = "%d Stamps" % int(main.save.data.stamps)
		_g_wallet[1].text = "%d Sparks" % int(main.save.data.sparks)

## Focusing a tab shows its items at once.
func _garage_tab(c: String) -> void:
	if c == _g_cat or not is_instance_valid(_g_list):
		return
	_g_cat = c
	_g_scroll.scroll_vertical = 0
	for k in _g_tabs:
		_g_tabs[k].selected = k == c
		_g_tabs[k].queue_redraw()
	main.apply_look()
	_garage_fill("", true)

func _garage_fill(focus_name := "", animate := true) -> void:
	var data: Dictionary = main.save.data
	var cat := _g_cat
	for ch in _g_list.get_children():
		_g_list.remove_child(ch)
		ch.queue_free()
	var list: Array = Looks.ITEMS[cat]
	var rows: Array = []
	var focus_btn: Control = null
	for i in list.size():
		var it: Dictionary = list[i]
		var b := _item(_g_list, it.name, _garage_pick.bind(cat, i), 36)
		var wearing := int(data.wear[cat]) == i
		if wearing:
			b.status = "Wearing"
			b.status_col = Color(0.55, 1.0, 0.85, 0.95)
			b.selected = true
		elif Looks.owns(data, cat, i):
			b.status = "Free" if Looks.DEV_FREE and int(it.cost) > 0 else "Owned"
			b.status_col = Color(1, 1, 1, 0.65)
		else:
			b.status = Looks.price_text(it)
			var have := int(data[Looks.wallet_key(it)])
			b.status_col = (Color(1.0, 0.86, 0.5) if Looks.wallet_key(it) == "stamps" else Color(0.65, 0.95, 1.0)) if have >= int(it.cost) else Color(1, 1, 1, 0.4)
		b.on_focus = main.apply_look.bind(cat, i)
		if focus_name == it.name:
			focus_btn = b
		rows.append(b)
	_garage_wire.call_deferred()
	if focus_btn != null:
		focus_btn.grab_focus.call_deferred()
		_g_scroll.ensure_control_visible.call_deferred(focus_btn)
	if animate and not bool(main.save.data.settings.get("reduced_motion", false)):
		_stagger_in(rows, 0.025, 36.0)

## After the generic row wiring: Up from the first item returns to the
## selected tab. Down from the second row enters the list.
func _garage_wire() -> void:
	_auto_wire()
	if not is_instance_valid(_box) or not is_instance_valid(_g_list) or not _box.is_ancestor_of(_g_list) or _g_list.get_child_count() == 0:
		return
	var first: Control = _g_list.get_child(0)
	var tab: Control = _g_tabs.get(_g_cat)
	if tab != null:
		first.focus_neighbor_top = first.get_path_to(tab)
		for tb in _g_tabs.values():
			if tb.get_parent() == _g_tabs[Looks.CATS.back()].get_parent():
				tb.focus_neighbor_bottom = tb.get_path_to(first)

func _stagger_in(rows: Array, step: float, dx: float) -> void:
	for n in rows:
		n.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var i := 0
	for n in rows:
		if not is_instance_valid(n):
			continue
		var c: Control = n
		var base := c.position.x
		c.position.x = base + dx
		var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.28).set_delay(i * step)
		tw.tween_property(c, "position:x", base, 0.36).set_delay(i * step)
		i += 1

func _exchange(buy_spark: bool) -> void:
	var data: Dictionary = main.save.data
	if buy_spark and int(data.stamps) >= Looks.STAMPS_PER_SPARK:
		data.stamps = int(data.stamps) - Looks.STAMPS_PER_SPARK
		data.sparks = int(data.sparks) + 1
	elif not buy_spark and int(data.sparks) >= 1:
		data.sparks = int(data.sparks) - 1
		data.stamps = int(data.stamps) + Looks.STAMPS_FOR_SPARK
	else:
		main._toast("Not enough yet", get_viewport_rect().size * Vector2(0.76, 0.92), Color(1.0, 0.85, 0.4), 34)
		return
	main.save.save()
	main.synth.play("mote", 1.2)
	_garage_wallet()
	_garage_fill("", false)

func _garage_pick(cat: String, i: int) -> void:
	var data: Dictionary = main.save.data
	var it := Looks.item(cat, i)
	var key := Looks.wallet_key(it)
	if Looks.owns(data, cat, i):
		data.wear[cat] = i
	elif int(data[key]) >= int(it.cost):
		data[key] = int(data[key]) - int(it.cost)
		data.owned[cat].append(i)
		data.wear[cat] = i
		main.fx_unlock()
	else:
		main._toast("Need %d more %s" % [int(it.cost) - int(data[key]), "Sparks" if key == "sparks" else "Stamps"], get_viewport_rect().size * Vector2(0.76, 0.92), Color(1.0, 0.85, 0.4), 34)
		return
	main.save.save()
	main.apply_look()
	main.kite_pop()
	_garage_wallet()
	_garage_fill(it.name, false)

## Settings live in the right-hand column like the Garage (Kavi stays in view).
## Settings (0.8.25, owner): a tidy main page with sections, each item has a
## "?" that explains it, volumes are real sliders, and graphics has presets
## (Low / Medium / High / Extreme) plus a Custom mode, a live preview (the
## world stays visible beside the menu), performance stats and a benchmark.
var _page := "main"
var _help: Label

const HELP := {
	"Sound": "Volumes for the whole game, the music, sound effects and the sounds of the world.",
	"Graphics": "How detailed and smooth the game looks. Auto picks what suits this device.",
	"Controls": "Button size and which hand the touch buttons are for.",
	"Accessibility": "Options that make the game gentler or calmer.",
	"About KAVI": "Version, where to get updates, and who made the game.",
	"Master volume": "Everything at once.",
	"Music": "The soundtrack of each country.",
	"Sound effects": "Hops, perfects, menus and the little world toys.",
	"World sounds": "Waves, birds, wind and the river around Kavi.",
	"Button size": "How big the touch buttons are on phones and tablets.",
	"Left-handed controls": "Swaps the touch buttons left and right.",
	"Kind Mode": "Obstacles never end a run; Kavi just bonks and keeps going.",
	"Hover assist over gaps": "Kavi hovers a little on his own over gaps.",
	"Relaxed speed (82%)": "The whole game runs a bit slower.",
	"Reduced motion": "Less shaking, swaying and flashing.",
	"Camera shake": "The screen shakes a little on bumps and landings.",
	"Auto": "Starts on High and steps down only if this device is slow. Remembers what works.",
	"Low": "Lightest. Fewer details, no glow. For older phones.",
	"Medium": "Good balance. Most details, glow on. Phones draw at 1080p.",
	"High": "Everything on, full sharpness.",
	"Extreme": "High plus smooth edges on every shape, more effects and no frame-rate cap. Can heat up phones.",
	"Custom": "Choose each graphics option yourself.",
	"Scenery detail": "How many trees, houses, stars and little details fill the world.",
	"Glow": "Soft glow around lights, the sun and Kavi's face.",
	"Light rays": "Sunbeams and moonbeams through the sky.",
	"Floating lights": "Soft out-of-focus lights drifting in front of the camera.",
	"Effects": "How many sparks, puffs and confetti appear.",
	"Resolution": "Phones: draw at the screen's full sharpness, or at 1080p for speed.",
	"Frame-rate cap": "The most frames per second the game will draw. Higher is smoother but uses more battery.",
	"Performance overlay": "Shows frames per second while you play. Detailed adds 1% lows and timings.",
	"Performance stats": "How smoothly the game ran since it started.",
	"Run benchmark": "Measures 10 seconds of Scenic View at High, then picks an Auto level.",
}

## A row with a "?" button: the explanation appears under the list.
func _row(v: Container, text: String, cb: Callable, size := 32) -> MenuItem:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	v.add_child(h)
	var b := _item(h, text, cb, size)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if HELP.has(text):
		var q := _item(h, "?", func(): _show_help(text), size - 4)
		q.custom_minimum_size.x = 70
		q.get_theme_stylebox("normal").content_margin_left = 22
		q.fill = Color(1.0, 0.85, 0.55)
		q.focus_entered.connect(func(): _show_help(text))
	return b

func _show_help(key: String) -> void:
	if is_instance_valid(_help):
		_help.text = HELP.get(key, key)
		_help.modulate.a = 0.0
		_help.create_tween().tween_property(_help, "modulate:a", 1.0, 0.2)

func _help_area(v: Container) -> void:
	_gap(v, 6)
	_help = _small(v, "Tap ? to learn what an option does.", 24, Color(1.0, 0.92, 0.80, 0.85))

## Slider row: drag, click, or left/right on the keyboard.
class SliderItem extends MenuItem:
	var value := 0.5
	var on_change: Callable
	func _gui_input(e: InputEvent) -> void:
		var step := 0.0
		if e.is_action_pressed("ui_left"):
			step = -0.05
		elif e.is_action_pressed("ui_right"):
			step = 0.05
		if step != 0.0:
			_set_v(value + step)
			accept_event()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_set_from_x(e.position.x)
			accept_event()
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_set_from_x(e.position.x)
			accept_event()
		elif e is InputEventScreenDrag:
			_set_from_x(e.position.x)
			accept_event()
	func _bar() -> Rect2:
		return Rect2(size.x * 0.50, size.y * 0.5 - 4.0, size.x * 0.32, 8.0)
	func _set_from_x(x: float) -> void:
		var r := _bar()
		if x >= r.position.x - 20.0:
			_set_v((x - r.position.x) / r.size.x)
	func _set_v(nv: float) -> void:
		nv = clampf(snappedf(nv, 0.05), 0.0, 1.0)
		if absf(nv - value) > 0.001:
			value = nv
			status = "%d%%" % int(round(value * 100.0))
			queue_redraw()
			if on_change.is_valid():
				on_change.call(value)
	func _draw() -> void:
		super._draw()
		var r := _bar()
		draw_rect(Rect2(r.position.x, r.position.y + 2.0, r.size.x, 4.0), Color(1, 1, 1, 0.18))
		draw_rect(Rect2(r.position.x, r.position.y + 2.0, r.size.x * value, 4.0), Color(accent, 0.9))
		draw_circle(Vector2(r.position.x + r.size.x * value, r.get_center().y), 9.0 + 3.0 * hot, Color(1.0, 0.96, 0.90))

func _slider(v: Container, text: String, key: String) -> SliderItem:
	var st: Dictionary = main.save.data.settings
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	v.add_child(h)
	var b := SliderItem.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 32)
	b.value = float(st.get(key, 0.8))
	b.status = "%d%%" % int(round(b.value * 100.0))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.on_change = func(val: float):
		st[key] = val
		main._apply_audio_settings()
		if key != "music":
			main.synth.play("ui", 1.4, -6.0)
	b.focus_exited.connect(func(): main.save.save())
	h.add_child(b)
	if HELP.has(text):
		var q := _item(h, "?", func(): _show_help(text), 28)
		q.custom_minimum_size.x = 70
		q.get_theme_stylebox("normal").content_margin_left = 22
		q.fill = Color(1.0, 0.85, 0.55)
		q.focus_entered.connect(func(): _show_help(text))
	return b

func show_settings(animate := true) -> void:
	main.garage_open = false
	main.menu_dim = true
	_page = "main"
	var v := _column(0.16, animate)
	_heading(v, "Settings")
	var first := _row(v, "Sound", func(): _open_page("sound"))
	_row(v, "Graphics", func(): _open_page("graphics"))
	_row(v, "Controls", func(): _open_page("controls"))
	_row(v, "Accessibility", func(): _open_page("access"))
	_row(v, "About KAVI", show_about)
	_help_area(v)
	_gap(v, 6)
	_item(v, "Back", main.go_title, 34)
	if _focus_text == "":
		first.grab_focus.call_deferred()
	else:
		_refocus(v)

func _open_page(pg: String, animate := true) -> void:
	_page = pg
	match pg:
		"sound": _page_sound(animate)
		"graphics": _page_graphics(animate)
		"controls": _page_controls(animate)
		"access": _page_access(animate)
		"perf": _page_perf(animate)

func _page_sound(animate := true) -> void:
	var v := _column(0.16, animate)
	_heading(v, "Sound")
	var first := _slider(v, "Master volume", "master")
	_slider(v, "Music", "music")
	_slider(v, "Sound effects", "sfx")
	_slider(v, "World sounds", "world")
	_help_area(v)
	_gap(v, 6)
	_item(v, "Back", func(): main.save.save(); show_settings(), 34)
	first.grab_focus.call_deferred()

func _page_controls(animate := true) -> void:
	var v := _column(0.16, animate)
	_heading(v, "Controls")
	_cycle_row(v, "Button size", "controls_scale", [0.8, 1.0, 1.2, 1.4])
	_toggle_row(v, "Left-handed controls", "left_handed")
	_help_area(v)
	_gap(v, 6)
	_item(v, "Back", show_settings, 34)
	_refocus_or_first(v)

func _page_access(animate := true) -> void:
	var v := _column(0.16, animate)
	_heading(v, "Accessibility")
	_toggle_row(v, "Kind Mode", "kind_mode")
	_toggle_row(v, "Hover assist over gaps", "assist_hover")
	_toggle_row(v, "Relaxed speed (82%)", "slow_speed")
	_toggle_row(v, "Reduced motion", "reduced_motion")
	_toggle_row(v, "Camera shake", "shake")
	_help_area(v)
	_gap(v, 6)
	_item(v, "Back", show_settings, 34)
	_refocus_or_first(v)

const PRESETS := ["auto", "low", "medium", "high", "extreme"]

func _page_graphics(animate := true) -> void:
	var v := _column(0.06, animate)
	_heading(v, "Graphics", 56)
	var st: Dictionary = main.save.data.settings
	var cur: String = st.get("graphics", "auto")
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 0)
	v.add_child(preset_row)
	for p in PRESETS:
		var b := _item(preset_row, p.capitalize(), func():
			st.graphics = p
			st.custom = false
			_after_graphics_change(), 28)
		b.selected = p == cur and not st.get("custom", false)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.get_theme_stylebox("normal").content_margin_left = 30
		b.focus_entered.connect(func(): _show_help(p.capitalize()); _preview_pic(p))
	var pic := TextureRect.new()
	pic.name = "PresetPic"
	pic.custom_minimum_size = Vector2(0, 0 if st.get("custom", false) else 170)
	pic.visible = not st.get("custom", false)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	_toggle_row(v, "Custom", "custom", 28)
	if st.get("custom", false):
		_cycle_row(v, "Scenery detail", "gx_detail", [0, 1, 2], ["Low", "Medium", "High"], 26)
		_toggle_row(v, "Glow", "gx_glow", 26)
		_toggle_row(v, "Light rays", "gx_rays", 26)
		_toggle_row(v, "Floating lights", "gx_lights", 26)
		_cycle_row(v, "Effects", "gx_effects", [0, 1, 2], ["Few", "Normal", "Lots"], 26)
		if OS.has_feature("mobile"):
			_cycle_row(v, "Resolution", "gx_res", [0, 1], ["Full", "1080p"], 26)
		_cycle_row(v, "Frame-rate cap", "gx_fps", [30, 60, 90, 120, 0], ["30", "60", "90", "120", "None"], 26)
	_cycle_row(v, "Performance overlay", "show_fps", [0, 1, 2], ["Off", "Simple", "Detailed"], 26)
	_row(v, "Performance stats", func(): _open_page("perf"), 26)
	_row(v, "Run benchmark", main.start_quick_benchmark, 26)
	_help_area(v)
	_item(v, "Back", show_settings, 30)
	_preview_pic(cur)
	_refocus_or_first(v)

func _preview_pic(p: String) -> void:
	var pic: TextureRect = _box.find_child("PresetPic", true, false) if is_instance_valid(_box) else null
	if pic == null:
		return
	var path := "res://assets/ui/preset_%s.jpg" % ("high" if p == "auto" else p)
	pic.texture = load(path) if ResourceLoader.exists(path) else null

func _after_graphics_change() -> void:
	var f := get_viewport().gui_get_focus_owner()
	_focus_text = f.text if f is Button else ""
	main.save.save()
	main._apply_settings()
	_page_graphics(false)

func _page_perf(animate := true) -> void:
	var v := _column(0.10, animate)
	_heading(v, "Performance", 56)
	var r: Dictionary = main.perf_summary()
	_small(v, "Since the game started (%s):" % r.time, 26, Color(1.0, 0.92, 0.78))
	_small(v, "Average  %s fps     1%% low  %s fps     0.1%% low  %s fps" % [r.avg, r.low1, r.low01], 30, Color(1, 1, 1, 0.95))
	_small(v, "Last 10 s:  %s fps average,  %s fps 1%% low" % [r.recent_avg, r.recent_low1], 26, Color(1, 1, 1, 0.8))
	var details := _item(v, "More details", func(): _perf_more = not _perf_more; _page_perf(false), 26)
	details.status = "Shown" if _perf_more else ""
	if _perf_more:
		for line in r.details:
			_small(v, line, 22, Color(0.85, 0.9, 1.0, 0.8))
	_gap(v, 8)
	_item(v, "Back", func(): _open_page("graphics"), 30)
	_refocus_or_first(v)

var _perf_more := false

func _refocus_or_first(v: Container) -> void:
	if _focus_text != "":
		for n in v.find_children("*", "Button", true, false):
			if n.text == _focus_text:
				n.grab_focus.call_deferred()
				_focus_text = ""
				return
	var bs := v.find_children("*", "Button", true, false)
	if bs.size() > 0:
		bs[0].grab_focus.call_deferred()
	_focus_text = ""

func _toggle_row(v: Container, text: String, key: String, size := 32) -> void:
	var st: Dictionary = main.save.data.settings
	var b := _row(v, text, func():
		st[key] = not st.get(key, false)
		_settings_changed(), size)
	var on: bool = st.get(key, false)
	b.status = "On" if on else "Off"
	b.status_col = Color(0.55, 1.0, 0.85, 0.95) if on else Color(1, 1, 1, 0.5)

func _cycle_row(v: Container, text: String, key: String, vals: Array, names: Array = [], size := 32) -> void:
	var st: Dictionary = main.save.data.settings
	var b := _row(v, text, func():
		var i := 0
		for k in vals.size():
			if absf(float(vals[k]) - float(st.get(key, vals[0]))) < 0.01:
				i = k
		st[key] = vals[(i + 1) % vals.size()]
		_settings_changed(), size)
	var cur_i := 0
	for k in vals.size():
		if absf(float(vals[k]) - float(st.get(key, vals[0]))) < 0.01:
			cur_i = k
	b.status = str(names[cur_i]) if names.size() > 0 else "%d%%" % int(float(vals[cur_i]) * 100.0)

func _settings_changed() -> void:
	var f := get_viewport().gui_get_focus_owner()
	_focus_text = f.text if f is Button else ""
	main.save.save()
	main._apply_settings()
	if _page == "main":
		show_settings(false)
	else:
		_open_page(_page, false)

## After an in-place rebuild, put focus back on the item that was pressed.
func _refocus(v: Container) -> void:
	for c in v.get_children():
		if c is Button and c.text == _focus_text:
			c.grab_focus.call_deferred()
			return

func _toggle(v: Container, text: String, key: String) -> void:
	var st: Dictionary = main.save.data.settings
	var b := _item(v, text, func():
		st[key] = not st[key]
		_settings_changed(), 32)
	b.status = "On" if st[key] else "Off"
	b.status_col = Color(0.55, 1.0, 0.85, 0.95) if st[key] else Color(1, 1, 1, 0.5)

func _cycle(v: Container, text: String, key: String, vals: Array) -> void:
	var st: Dictionary = main.save.data.settings
	var b := _item(v, text, func():
		var i = 0
		for k in vals.size():
			if absf(vals[k] - st[key]) < 0.01:
				i = k
		st[key] = vals[(i + 1) % vals.size()]
		_settings_changed(), 32)
	b.status = "%d%%" % int(st[key] * 100.0)

func _heading(v: Container, text: String, size := 64, col := Color(1, 0.96, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	_shadow(l)
	v.add_child(l)
	return l

## Centred in-world column over a soft dim (pause, results, story screens).
func _center(width := 640.0, dim := 0.55) -> VBoxContainer:
	_clear()
	_opened_ms = Time.get_ticks_msec()
	_auto_wire.call_deferred()
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.02, 0.05, dim)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	c.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -width * 0.5
	v.offset_right = width * 0.5
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.add_child(v)
	_box = c
	_appear(c)
	return v

func show_pause() -> void:
	var v := _center(560, 0.8)
	_heading(v, "Paused", 80)
	_gap(v, 10)
	var r := _item(v, "Resume", main.resume, 46)
	_item(v, "Restart", main.menu_retry, 40)
	_item(v, "Main menu", main.go_title, 40)
	r.grab_focus.call_deferred()

func show_results(r: Dictionary) -> void:
	var v := _center(720)
	_heading(v, "NEW BEST!" if r.new_best else "Run complete", 80, Color(1.0, 0.85, 0.45) if r.new_best else Color(1, 0.96, 0.9))
	_heading(v, "Score  %d" % r.score, 54)
	_small(v, "%d m   ·   %d perfect moves   ·   best Tailwind x%d   ·   best score %d" % [r.dist, r.perfects, r.tier, r.best], 26, Color(1, 1, 1, 0.8))
	_gap(v, 6)
	_small(v, "Collected:  +%d Stamps    +%d Sparks" % [r.get("banked", r.stamps), r.sparks], 30, Color(1.0, 0.86, 0.5))
	_small(v, "Spend them in the Garage. Sparks come from Tailwind x4 and every 10 perfect moves.", 22, Color(1, 1, 1, 0.55))
	_gap(v, 14)
	var b := _item(v, "Run again", main.menu_retry, 48)
	_item(v, "Main menu", main.go_title, 40)
	b.grab_focus.call_deferred()

func show_story_over(ch: int) -> void:
	var v := _center(720)
	_heading(v, "Out of hearts", 76, Color(1.0, 0.65, 0.75))
	_small(v, "Kavi needs a rest. Your progress is saved: next time you start at chapter %d." % (ch + 1), 30, Color(1, 1, 1, 0.85))
	_gap(v, 14)
	var b := _item(v, "Back to home", main.go_title, 46)
	b.grab_focus.call_deferred()

func show_tutorial_done() -> void:
	var v := _center(720, 0.45)
	_heading(v, "Nice moves, courier!", 70, Color(0.75, 1.0, 0.95))
	_small(v, "Perfect timing builds TAILWIND (x2, x3, x4): more points and a brighter trail. A mistake only drops one tier.", 28, Color(1, 1, 1, 0.85))
	_gap(v, 14)
	var b := _item(v, "Start the story", main.menu_story, 48)
	_item(v, "Main menu", main.go_title, 40)
	b.grab_focus.call_deferred()

## The tutorial from the menu asks first instead of jumping straight in.
func confirm_tutorial() -> void:
	main.menu_dim = true
	var v := _column(0.34)
	_heading(v, "Replay the tutorial?", 56)
	_small(v, "A short practice run (about a minute) that shows every move again. Your story progress and Garage stay as they are.", 26, Color(1, 1, 1, 0.75))
	_gap(v, 16)
	var yes := _item(v, "Yes, start the tutorial", main.menu_tutorial, 40)
	var no := _item(v, "No, back to the menu", show_title, 40)
	no.grab_focus.call_deferred()

func confirm_quit() -> void:
	main.menu_dim = true
	var v := _column(0.38)
	_heading(v, "Leave the game?", 56)
	_small(v, "Your stamps, sparks and story progress are saved.", 26, Color(1, 1, 1, 0.75))
	_gap(v, 16)
	_item(v, "Yes, quit", main.quit_game, 40)
	var no := _item(v, "No, keep playing", show_title, 40)
	no.grab_focus.call_deferred()

func show_tutorial_skip() -> void:
	_corner_button("Skip tutorial  >", main.skip_tutorial, 28)

func _corner_button(text: String, cb: Callable, size: int) -> void:
	_clear()
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -420
	b.offset_right = -120
	b.offset_top = 130
	b.offset_bottom = 196
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	c.add_child(b)
	_box = c

func show_skip() -> void:
	_clear()
	var c = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var b = Button.new()
	b.text = "Skip  >"
	b.add_theme_font_size_override("font_size", 30)
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0
	b.offset_left = -360
	b.offset_right = -190
	b.offset_top = 130
	b.offset_bottom = 200
	b.pressed.connect(main.skip_recovery)
	c.add_child(b)
	_box = c

## Route choice after a breather (0.8.12): a visible countdown that gets more
## intense (orange, then red, pulsing ticks, shaking bar). In the last seconds
## the gentle route turns into a big "EASY ROUTE: tap anywhere" option.
var junction_wild: MenuItem
var junction_scenic: MenuItem
var junction_scenic_sub: Label

class JunctionTimer extends Control:
	var main: Node

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var total: float = main.JUNCTION_TIME
		var rem: float = clampf(total - main.junction_t, 0.0, total)
		var k: float = rem / total
		var urgent: float = clampf((3.5 - rem) / 3.5, 0.0, 1.0)
		var col: Color = Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.62, 0.25), clampf(urgent * 2.0, 0.0, 1.0)).lerp(Color(1.0, 0.25, 0.22), clampf(urgent * 2.0 - 1.0, 0.0, 1.0))
		var frac: float = fmod(rem, 1.0)
		var pop: float = exp(-(1.0 - frac) * 7.0) * urgent
		var t: float = Time.get_ticks_msec() * 0.001
		var shake := Vector2(sin(t * 47.0), cos(t * 41.0)) * 4.0 * urgent * urgent
		var w := size.x
		var cx := w * 0.5
		# big seconds number
		var f := get_theme_default_font()
		if main.font != null:
			f = main.font
		# fixed font size, popped by scaling (no new glyph sizes mid-run)
		var fs := 84
		var sc := 1.0 + 0.35 * pop
		var num := str(int(ceil(rem)))
		var nw := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(Vector2(cx, 74.0 - fs * 0.3) + shake, 0.0, Vector2(sc, sc))
		var np := Vector2(-nw * 0.5, fs * 0.42)
		draw_string_outline(f, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0.01, 0.02, 0.05, 0.8))
		draw_string(f, np, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# draining bar
		var bw := w * 0.8
		var by := 104.0
		var r := Rect2(Vector2(cx - bw * 0.5, by) + shake, Vector2(bw, 14))
		draw_rect(r, Color(0.01, 0.02, 0.05, 0.65))
		var fr := Rect2(r.position + Vector2(2, 2), Vector2((bw - 4) * k, 10))
		draw_rect(fr, col)
		if urgent > 0.0:
			draw_rect(fr.grow(3.0 + 6.0 * pop), Color(col, 0.25 * urgent), false, 3.0)

func show_junction(story: bool) -> void:
	var v := _center(900, 0.5)
	# sit right of Kavi so the words never cover him
	v.anchor_left = 0.64
	v.anchor_right = 0.64
	_heading(v, "A fork in the road", 60)
	var tm := JunctionTimer.new()
	tm.main = main
	tm.custom_minimum_size = Vector2(0, 130)
	tm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tm)
	_gap(v, 6)
	junction_wild = _item(v, "Wild route  (Up)", main.choose_route.bind("wild"), 46)
	junction_wild.accent = Color(1.0, 0.6, 0.4)
	junction_wild.fill = Color(1.0, 0.78, 0.62)
	_small(v, "shorter and faster to Lia, but much harder" if story else "harder, faster, score x1.5", 26, Color(1.0, 0.75, 0.6, 0.8))
	_gap(v, 12)
	junction_scenic = _item(v, "Scenic route  (Down)", main.choose_route.bind("scenic"), 46)
	junction_scenic.accent = Color(0.5, 1.0, 0.8)
	junction_scenic.fill = Color(0.72, 1.0, 0.86)
	junction_scenic_sub = _small(v, "longer and gentler, with more kind strangers" if story else "calmer stretch, steady score", 26, Color(0.6, 1.0, 0.8, 0.8))
	if main.junction_easy:
		junction_go_easy(false)

## Last seconds: the gentle route becomes the easy, glowing default.
func junction_go_easy(animate := true) -> void:
	if not is_instance_valid(junction_scenic):
		return
	junction_scenic.text = "EASY ROUTE: tap anywhere!"
	junction_scenic.selected = true
	junction_scenic.add_theme_font_size_override("font_size", 56)
	junction_scenic_sub.text = "no rush, the calm road is fine too"
	junction_scenic.grab_focus()
	if is_instance_valid(junction_wild):
		junction_wild.modulate.a = 0.45
	if animate:
		junction_scenic.pivot_offset = Vector2(0, 30)
		var tw := junction_scenic.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		junction_scenic.modulate = Color(1.6, 1.6, 1.6)
		tw.tween_property(junction_scenic, "modulate", Color.WHITE, 0.5)
	var glow := junction_scenic.create_tween().set_loops()
	glow.tween_property(junction_scenic_sub, "modulate:a", 0.45, 0.35)
	glow.tween_property(junction_scenic_sub, "modulate:a", 1.0, 0.35)

func show_finale_end() -> void:
	var v := _center(760, 0.25)
	_gap(v, 300)
	_heading(v, "Kavi found Lia.", 56, Color(1, 0.9, 0.95))
	_small(v, "The Endless Road is waiting.", 28, Color(1, 1, 1, 0.8))
	_gap(v, 10)
	var b := _item(v, "Endless Road", main.menu_endless, 44)
	_item(v, "Main menu", main.go_title, 38)
	b.grab_focus.call_deferred()

func show_ad_placeholder() -> void:
	var v := _center(800)
	_heading(v, "Ad placeholder", 56)
	_small(v, "No ad network is connected yet (pending the legal and Families Policy review). The reward is granted for testing.", 26, Color(1, 1, 1, 0.75))


## About (0.8.24, owner): version, where to get updates, and who made it.
const LINK_PLAY := "https://singh679.github.io/volt-run-luminous/"
const LINK_DOWNLOADS := "https://github.com/singh679/volt-run-luminous/releases/latest"
const LINK_SOURCE := "https://github.com/singh679/volt-run-luminous"

func show_about() -> void:
	main.garage_open = false
	main.menu_dim = true
	var v := _column(0.12)
	_heading(v, "About", 64)
	_small(v, "KAVI: Letters to Lia", 34, Color(1.0, 0.92, 0.78))
	_small(v, "Version %s  ·  made with Godot %s" % [str(ProjectSettings.get_setting("application/config/version", "?")), Engine.get_version_info().string.get_slice("-", 0)], 26, Color(1, 1, 1, 0.8))
	_gap(v, 6)
	_small(v, "Made by Baljeet Singh", 28, Color(0.85, 0.88, 0.95))
	_small(v, "BADCOOL INTERACTIVE", 22, Color(0.75, 0.78, 0.84))
	_gap(v, 12)
	var first := _item(v, "Play in your browser", func(): OS.shell_open(LINK_PLAY), 32)
	_item(v, "Downloads and updates", func(): OS.shell_open(LINK_DOWNLOADS), 32)
	_item(v, "Source on GitHub", func(): OS.shell_open(LINK_SOURCE), 32)
	_small(v, "github.com/singh679/volt-run-luminous", 22, Color(1, 1, 1, 0.55))
	_gap(v, 10)
	_item(v, "Back", show_settings, 34)
	first.grab_focus.call_deferred()
