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
const SCARF_NAMES := ["Sunset Orange", "Sky Blue", "Rose", "Honey Gold", "Mint", "Violet"]
const SCARF_COST := [0, 3, 3, 5, 5, 8]
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

func show_title() -> void:
	_clear()
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	var sb := _sb(Color(0.05, 0.06, 0.14, 0.80), Color(1, 1, 1, 0.14), 2, 48, 30, Color(0, 0, 0, 0.32))
	sb.set_content_margin_all(40)
	card.add_theme_stylebox_override("panel", sb)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -760
	card.offset_right = -110
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	_box = c
	var ch := int(main.save.data.story_chapter)
	var cont: bool = ch > 0 and not main.save.data.story_done
	var first := _btn(v, ("Continue  ·  Chapter %d" % (ch + 1)) if cont else "Play Story", main.menu_story, 50)
	_make_primary(first)
	first.custom_minimum_size.y = 104
	_label(v, ("%s is waiting. Keep going!" % main.FRIEND) if cont else ("Carry letters across Europe to %s" % main.FRIEND), 26, Color(1, 1, 1, 0.62))
	_btn(v, "Endless Road", main.menu_endless, 36)
	_btn(v, "Daily Relay", main.menu_daily, 36)
	var sv := _btn(v, "Scenic View", main.menu_scenic, 36)
	sv.add_theme_color_override("font_color", Color(0.72, 1.0, 0.9))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for it in [["Garage", show_garage], ["Settings", show_settings], ["Tutorial", main.menu_tutorial]]:
		var b := _btn(row, it[0], it[1], 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed"]:
			var x: StyleBoxFlat = _theme.get_stylebox(st, "Button").duplicate()
			x.content_margin_left = 12
			x.content_margin_right = 12
			b.add_theme_stylebox_override(st, x)
	# Portal builds (CrazyGames etc.) must not show their own ad prompts.
	if main.ads.can_show() and not OS.has_feature("portal"):
		_btn(v, "Free gift: short ad for +1 Spark  (%d left)" % main.ads.remaining_today(), main.watch_ad_for_spark, 24)
	_label(v, "%d Sparks   ·   %d Stamps   ·   Best %d" % [main.save.data.sparks, main.save.data.stamps, main.save.data.best_endless], 26, Color(1.0, 0.88, 0.6, 0.9))
	_appear(c)
	first.grab_focus.call_deferred()

## Scenic View: only a small Back button; Esc also returns.
func show_scenic() -> void:
	_corner_button("Back  (Esc)", main.go_title, 28)

func show_garage() -> void:
	main.synth.play("ui")
	var v = _panel(0.5, 760)
	_label(v, "Garage  ·  Scarves", 56)
	var how := "1 Spark for every 25 stamps you collect, +1 for reaching Tailwind x4" + ("" if OS.has_feature("portal") else ", or an optional ad")
	_label(v, "Sparks: %d   ·   %s" % [main.save.data.sparks, how], 26, Color(1, 0.9, 0.6))
	var owned: Array = main.save.data.owned_scarves
	for i in SCARF_NAMES.size():
		var txt: String = SCARF_NAMES[i]
		if int(main.save.data.scarf) == i:
			txt += "   (wearing)"
		elif owned.has(i) or owned.has(float(i)):
			txt += "   wear"
		else:
			txt += "   %d sparks" % SCARF_COST[i]
		var b = _btn(v, txt, _scarf_pick.bind(i), 30)
		b.add_theme_color_override("font_color", [Color(1.0, 0.55, 0.35), Color(0.5, 0.8, 1.0), Color(1.0, 0.6, 0.8), Color(1.0, 0.85, 0.4), Color(0.5, 1.0, 0.75), Color(0.8, 0.6, 1.0)][i])
	_btn(v, "Back", main.go_title)

func _scarf_pick(i: int) -> void:
	var owned: Array = main.save.data.owned_scarves
	if owned.has(i) or owned.has(float(i)):
		main.save.data.scarf = i
	elif int(main.save.data.sparks) >= SCARF_COST[i]:
		main.save.data.sparks = int(main.save.data.sparks) - SCARF_COST[i]
		owned.append(i)
		main.save.data.scarf = i
	main.save.save()
	show_garage()

func show_settings() -> void:
	main.synth.play("ui")
	var v = _panel(0.5, 820)
	_label(v, "Settings", 56)
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
	_btn(v, "Graphics:  %s" % gq.capitalize(), func():
		var opts := ["auto", "low", "medium", "high"]
		st["graphics"] = opts[(opts.find(gq) + 1) % opts.size()]
		main.save.save()
		main._apply_settings()
		show_settings(), 28)
	_btn(v, "Back", main.go_title)

func _toggle(v: Container, text: String, key: String) -> void:
	var st: Dictionary = main.save.data.settings
	_btn(v, "%s:  %s" % [text, "ON" if st[key] else "off"], func():
		st[key] = not st[key]
		main.save.save()
		main._apply_settings()
		show_settings(), 28)

func _cycle(v: Container, text: String, key: String, vals: Array) -> void:
	var st: Dictionary = main.save.data.settings
	_btn(v, "%s:  %d%%" % [text, int(st[key] * 100.0)], func():
		var i = 0
		for k in vals.size():
			if absf(vals[k] - st[key]) < 0.01:
				i = k
		st[key] = vals[(i + 1) % vals.size()]
		main.save.save()
		main._apply_settings()
		show_settings(), 28)

func show_pause() -> void:
	var v = _panel(0.5, 560)
	_label(v, "Paused", 64)
	var r = _btn(v, "Resume", main.resume)
	_btn(v, "Restart", main.menu_retry)
	_btn(v, "Main menu", main.go_title)
	r.grab_focus.call_deferred()

func show_results(r: Dictionary) -> void:
	var v = _panel(0.5, 720)
	_label(v, "NEW BEST!" if r.new_best else "Run complete", 72, Color(1.0, 0.85, 0.45) if r.new_best else Color(1, 0.98, 0.94))
	_label(v, "Score  %d" % r.score, 54)
	_label(v, "%d m   ·   %d stamps   ·   %d perfects   ·   best Tailwind x%d" % [r.dist, r.stamps, r.perfects, r.tier], 30, Color(1, 1, 1, 0.8))
	if r.sparks > 0:
		_label(v, "+%d Spark%s for the Garage" % [r.sparks, "s" if r.sparks > 1 else ""], 30, Color(1, 0.85, 0.4))
	_label(v, "Best %d" % r.best, 28, Color(1, 1, 1, 0.6))
	var b = _btn(v, "Run again", main.menu_retry, 44)
	_btn(v, "Main menu", main.go_title)
	b.grab_focus.call_deferred()

func show_story_over(ch: int) -> void:
	var v := _panel(0.5, 720)
	_label(v, "Out of hearts", 68, Color(1.0, 0.6, 0.7))
	_label(v, "Vayu needs a rest. Your progress is saved: next time you start at chapter %d." % (ch + 1), 32, Color(1, 1, 1, 0.85))
	var b := _btn(v, "Back to home", main.go_title, 44)
	b.grab_focus.call_deferred()

func show_tutorial_skip() -> void:
	_corner_button("Skip tutorial  >", main.skip_tutorial, 28)

func show_tutorial_done() -> void:
	var v := _panel(0.55, 700)
	_label(v, "Nice moves, courier!", 60, Color(0.75, 1.0, 0.95))
	_label(v, "Perfect timing builds TAILWIND (x2, x3, x4): more points, a brighter trail. A mistake only drops one tier.", 30, Color(1, 1, 1, 0.85))
	var b := _btn(v, "Start the story", main.menu_story, 44)
	_btn(v, "Main menu", main.go_title)
	b.grab_focus.call_deferred()

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
	var v = _panel(0.74, 700, false)
	_label(v, "Vayu found Lia.  The Endless Road is waiting.", 34, Color(1, 0.9, 0.95))
	var b = _btn(v, "Endless Road", main.menu_endless, 40)
	_btn(v, "Main menu", main.go_title)
	b.grab_focus.call_deferred()

func show_ad_placeholder() -> void:
	var v = _panel(0.5, 800)
	_label(v, "Ad placeholder", 56)
	_label(v, "No ad network is connected yet (pending the legal and Families Policy review). The reward is granted for testing.", 28, Color(1, 1, 1, 0.75))
