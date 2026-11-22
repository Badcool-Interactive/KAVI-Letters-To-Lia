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
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(k, Color(1.0, 0.96, 0.90))
		add_theme_constant_override("outline_size", 10)
		add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.6))
		mouse_entered.connect(grab_focus)
		focus_entered.connect(func():
			if on_focus.is_valid():
				on_focus.call())

	func _process(dt: float) -> void:
		var target := 1.0 if has_focus() else 0.0
		if absf(hot - target) > 0.001:
			hot = move_toward(hot, target, dt * 7.0)
			queue_redraw()
		self_modulate.a = 0.58 + 0.42 * maxf(hot, 1.0 if selected else 0.0)

	func _draw() -> void:
		var y := size.y * 0.5 - 2.0
		var f := get_theme_font("font")
		var fs := get_theme_font_size("font_size")
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
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
	v.add_child(b)
	return b

## Right-hand column used by the title and Garage screens.
func _column(top := 0.24, animate := true) -> VBoxContainer:
	_clear()
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
	var v := _column(0.30)
	var ch := int(main.save.data.story_chapter)
	var cont: bool = ch > 0 and not main.save.data.story_done
	var first := _item(v, ("Continue the journey" if cont else "Play story"), main.menu_story, 62)
	var sub := _small(v, ("Chapter %d  ·  %s" % [ch + 1, Art.biome(ch).name]) if cont else ("Carry the letters all the way to %s" % main.FRIEND), 24, Color(1.0, 0.86, 0.62, 0.75))
	sub.add_theme_constant_override("line_spacing", 0)
	_gap(v, 14)
	_item(v, "Endless Road", main.menu_endless, 40)
	_item(v, "Daily Relay", main.menu_daily, 40)
	_item(v, "Scenic View", main.menu_scenic, 40)
	_gap(v, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	v.add_child(row)
	for it in [["Garage", show_garage.bind("scarf")], ["Settings", show_settings], ["Tutorial", confirm_tutorial]]:
		var b := _item(row, it[0], it[1], 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Portal builds (CrazyGames etc.) must not show their own ad prompts.
	if main.ads.can_show() and not OS.has_feature("portal"):
		_item(v, "Free gift: a short ad for +1 Spark (%d left)" % main.ads.remaining_today(), main.watch_ad_for_spark, 24)
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
		stats.add_child(l)
	first.grab_focus.call_deferred()

## Garage: Kavi in close-up on the left; categories and items on the right.
## Hovering an item tries it on; pressing buys (if affordable) or wears it.
## Switching tabs or buying rebuilds the list in place (no fade = no lag).
func show_garage(cat := "scarf", animate := true) -> void:
	main.garage_open = true
	main.menu_dim = true
	main.apply_look()
	var v := _column(0.08, animate)
	var data: Dictionary = main.save.data
	_heading(v, "Garage", 64)
	# wallet + exchange
	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 28)
	v.add_child(wallet)
	for w in [["%d Stamps" % int(data.stamps), Color(1.0, 0.86, 0.55)], ["%d Sparks" % int(data.sparks), Color(0.65, 0.95, 1.0)]]:
		var l := Label.new()
		l.text = w[0]
		l.add_theme_font_size_override("font_size", 34)
		l.add_theme_color_override("font_color", w[1])
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.85))
		wallet.add_child(l)
	var ex := HBoxContainer.new()
	ex.add_theme_constant_override("separation", 0)
	v.add_child(ex)
	var e1 := _item(ex, "Swap %d Stamps for 1 Spark" % Looks.STAMPS_PER_SPARK, _exchange.bind(cat, true), 24)
	e1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var e2 := _item(ex, "1 Spark for %d Stamps" % Looks.STAMPS_FOR_SPARK, _exchange.bind(cat, false), 24)
	e2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Looks.DEV_FREE:
		_small(v, "Preview build: everything is free to try while the game is in development.", 24, Color(0.6, 1.0, 0.85, 0.85))
	_gap(v, 4)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	v.add_child(tabs)
	var focus_btn: Control = null
	for c in Looks.CATS:
		var tb := _item(tabs, Looks.CAT_NAMES[c], show_garage.bind(c, false), 27)
		tb.selected = c == cat
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.get_theme_stylebox("normal").content_margin_left = 34
		tb.get_theme_stylebox("normal").content_margin_right = 2
		if c == cat:
			focus_btn = tb
	_gap(v, 4)
	var list: Array = Looks.ITEMS[cat]
	for i in list.size():
		var it: Dictionary = list[i]
		var b := _item(v, it.name, _garage_pick.bind(cat, i), 36)
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
		if _focus_text == it.name:
			focus_btn = b
	_gap(v, 8)
	var back := _item(v, "Back", main.go_title, 34)
	back.on_focus = main.apply_look
	_focus_text = ""
	if focus_btn:
		focus_btn.grab_focus.call_deferred()

func _exchange(cat: String, buy_spark: bool) -> void:
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
	var f := get_viewport().gui_get_focus_owner()
	_focus_text = f.text if f is Button else ""
	show_garage(cat, false)
	for n in _box.find_children("*", "Button", true, false):
		if n.text == _focus_text:
			n.grab_focus.call_deferred()

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
	_focus_text = it.name
	show_garage(cat, false)

## Settings live in the right-hand column like the Garage (Kavi stays in view).
func show_settings(animate := true) -> void:
	main.garage_open = false
	main.menu_dim = true
	var v := _column(0.12, animate)
	_heading(v, "Settings")
	var st: Dictionary = main.save.data.settings
	_toggle(v, "Kind Mode (no fails, just bonks)", "kind_mode")
	_toggle(v, "Hover assist over gaps", "assist_hover")
	_toggle(v, "Relaxed speed (82%)", "slow_speed")
	_toggle(v, "Reduced motion", "reduced_motion")
	_toggle(v, "Camera shake", "shake")
	_toggle(v, "Left-handed controls", "left_handed")
	_cycle(v, "Music", "music", [0.0, 0.4, 0.8, 1.0])
	_cycle(v, "Sound effects", "sfx", [0.0, 0.5, 0.9, 1.0])
	_cycle(v, "Button size", "controls_scale", [0.8, 1.0, 1.2, 1.4])
	var gq: String = st.get("graphics", "auto")
	var g := _item(v, "Graphics", func():
		var opts := ["auto", "low", "medium", "high"]
		st["graphics"] = opts[(opts.find(gq) + 1) % opts.size()]
		_settings_changed(), 32)
	g.status = gq.capitalize()
	_gap(v, 10)
	var back := _item(v, "Back", main.go_title, 34)
	if animate:
		v.get_child(1).grab_focus.call_deferred()
	else:
		_refocus(v)

func _settings_changed() -> void:
	var f := get_viewport().gui_get_focus_owner()
	_focus_text = f.text if f is Button else ""
	main.save.save()
	main._apply_settings()
	show_settings(false)

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
	v.add_child(l)
	return l

## Centred in-world column over a soft dim (pause, results, story screens).
func _center(width := 640.0, dim := 0.55) -> VBoxContainer:
	_clear()
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
	var v := _center(560)
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

func show_junction(story: bool) -> void:
	_clear()
	var c = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v = VBoxContainer.new()
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -520
	v.offset_right = 520
	v.offset_top = -260
	v.offset_bottom = 200
	v.add_theme_constant_override("separation", 22)
	c.add_child(v)
	_label(v, "A fork in the road", 60)
	var w = _btn(v, "WILD ROUTE  (Up)\nshorter and faster to Lia, but much harder" if story else "WILD ROUTE  (Up)\nharder, faster, score x1.5", main.choose_route.bind("wild"), 34)
	w.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	var s = _btn(v, "SCENIC ROUTE  (Down)\nlonger and gentler, with more kind strangers" if story else "SCENIC ROUTE  (Down)\ncalmer stretch, steady score", main.choose_route.bind("scenic"), 34)
	s.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	_box = c

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
