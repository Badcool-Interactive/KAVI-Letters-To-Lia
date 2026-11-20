extends Control
## Menus built in code: title, garage, settings, pause, results, junction,
## recovery skip, finale, ad placeholder. Rounded glassy buttons.

const Art = preload("res://scripts/art.gd")

var main
var font: Font
var _box: Control
var _theme: Theme
const SCARF_NAMES := ["Sunset Orange", "Sky Blue", "Rose", "Honey Gold", "Mint", "Violet"]
const SCARF_COST := [0, 3, 3, 5, 5, 8]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theme = Theme.new()
	_theme.default_font = font
	_theme.default_font_size = 38
	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.03, 0.06, 0.10, 0.55)
	n.border_color = Color(1, 1, 1, 0.22)
	n.set_border_width_all(2)
	n.set_corner_radius_all(40)
	n.content_margin_left = 40
	n.content_margin_right = 40
	n.content_margin_top = 16
	n.content_margin_bottom = 16
	var h = n.duplicate()
	h.bg_color = Color(0.10, 0.22, 0.28, 0.75)
	h.border_color = Color(0.4, 1.0, 1.0, 0.8)
	var p = h.duplicate()
	p.bg_color = Color(0.2, 0.45, 0.5, 0.85)
	for s in ["normal", "focus"]:
		_theme.set_stylebox(s, "Button", n if s == "normal" else h)
	_theme.set_stylebox("hover", "Button", h)
	_theme.set_stylebox("pressed", "Button", p)
	_theme.set_color("font_color", "Button", Color(1, 0.98, 0.94))
	_theme.set_color("font_hover_color", "Button", Color(1, 1, 1))
	_theme.set_color("font_color", "Label", Color(1, 0.98, 0.94))
	_theme.set_constant("outline_size", "Label", 8)
	_theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.5))
	theme = _theme

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
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.03, 0.07, 0.72)
		sb.set_corner_radius_all(36)
		sb.set_content_margin_all(40)
		sb.border_color = Color(1, 1, 1, 0.12)
		sb.set_border_width_all(2)
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
	return v

func _btn(v: Container, text: String, cb: Callable, size := 38) -> Button:
	var b = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	v.add_child(b)
	return b

func _label(v: Container, text: String, size := 36, col := Color(1, 0.98, 0.94)) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	v.add_child(l)
	return l

# ------------------------------------------------------------------ screens
func show_none() -> void:
	_clear()

func show_title() -> void:
	var v = _panel(0.64, 640, false)
	var first = _btn(v, "Story  ·  Find Lumi", main.menu_story, 44)
	_btn(v, "Endless Road", main.menu_endless)
	_btn(v, "Daily Relay", main.menu_daily)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var g = _btn(row, "Garage", show_garage, 32)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s = _btn(row, "Settings", show_settings, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if main.ads.can_show():
		_btn(v, "Free gift: watch a short ad for +1 Spark  (%d left today)" % main.ads.remaining_today(), main.watch_ad_for_spark, 26)
	_label(v, "Sparks: %d   ·   Stamps: %d   ·   Best: %d" % [main.save.data.sparks, main.save.data.stamps, main.save.data.best_endless], 26, Color(1, 1, 1, 0.65))
	first.grab_focus.call_deferred()

func show_garage() -> void:
	main.synth.play("ui")
	var v = _panel(0.5, 760)
	_label(v, "Garage  ·  Scarves", 56)
	_label(v, "Sparks: %d  (earn them from stamps, Tailwind x4 runs, or an optional ad)" % main.save.data.sparks, 26, Color(1, 0.9, 0.6))
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
	var w = _btn(v, "WILD ROUTE  (Up)\nshorter and faster to Lumi, but much harder" if story else "WILD ROUTE  (Up)\nharder, faster, score x1.5", main.choose_route.bind("wild"), 34)
	w.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	var s = _btn(v, "SCENIC ROUTE  (Down)\nlonger and gentler, with more kind strangers" if story else "SCENIC ROUTE  (Down)\ncalmer stretch, steady score", main.choose_route.bind("scenic"), 34)
	s.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	_box = c

func show_finale_end() -> void:
	var v = _panel(0.74, 700, false)
	_label(v, "Kite found Lumi.  The Endless Road is waiting.", 34, Color(1, 0.9, 0.95))
	var b = _btn(v, "Endless Road", main.menu_endless, 40)
	_btn(v, "Main menu", main.go_title)
	b.grab_focus.call_deferred()

func show_ad_placeholder() -> void:
	var v = _panel(0.5, 800)
	_label(v, "Ad placeholder", 56)
	_label(v, "No ad network is connected yet (pending the legal and Families Policy review). The reward is granted for testing.", 28, Color(1, 1, 1, 0.75))
