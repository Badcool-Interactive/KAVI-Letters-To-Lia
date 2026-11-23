extends Node2D
## VOLT/RUN game orchestrator: modes, segments, recovery breaks, junctions,
## rescues, finale, camera, HUD, menus and the capture director.

const Art = preload("res://scripts/art.gd")
const Sim = preload("res://scripts/sim.gd")
const Track = preload("res://scripts/track.gd")
const Tailwind = preload("res://scripts/tailwind.gd")
const Save = preload("res://scripts/save.gd")
const Ads = preload("res://scripts/ads.gd")
const Chars = preload("res://scripts/chars.gd")
const Painter = preload("res://scripts/painter.gd")
const WorldView = preload("res://scripts/world_view.gd")
const TrackView = preload("res://scripts/track_view.gd")
const KiteView = preload("res://scripts/kite_view.gd")
const Fx = preload("res://scripts/fx.gd")
const Synth = preload("res://scripts/synth.gd")
const Touch = preload("res://scripts/touch.gd")
const UI = preload("res://scripts/ui.gd")
const Looks = preload("res://scripts/looks.gd")
const Tutorial = preload("res://scripts/tutorial.gd")

enum { HURDLE, BEAM, GAP, WIDE_GAP, GATE, BELL, BLOOM, RESCUE }
const PX_PER_M := 40.0

# ------------------------------------------------------------------ nodes
var save = Save.new()
var ads = Ads.new()
var tw = Tailwind.new()
var tut = null
var sim
var track
var world_view
var track_view
var kite
var fx
var synth
var touch
var ui
var cam: Camera2D
var cast_base: Node2D
var cast_add: Node2D
var fg: Node2D
var hud: Node2D
var vignette: TextureRect
var font: Font       # Fredoka SemiBold: titles, HUD numbers, buttons
var font_body: Font  # Nunito ExtraBold: captions, tips, descriptions

## Player-facing names live here so a rename is one edit.
const GAME_TITLE := "KAVI"
const GAME_SUB := "Letters to Lia"
const HERO := "Kavi"
const FRIEND := "Lia"
const SCENIC_SPEED := 430.0
const SCENIC_STAY := 38.0  # seconds per country in Scenic View
var scenic_next := 0.0
var garage_open := false
var debug_pose := ""     # capture director: show Kavi in a given pose on the title
var debug_speed := 0.0
var debug_expr := ""
var menu_dim := false  # stronger shade behind the menu column (Garage, Settings)
## Title mini-game (0.8.11): click near the paper plane to push it away from
## the click; steer it to Kavi and it circles him. Too many clicks too fast and
## it stalls and falls; a new plane glides in.
var plane := {}
var plane_fx: Array = []
var plane_trail: Array = []
var plane_delivered := 0
var plane_hint := true
var plane_happy_t := 0.0
var logo_lift: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]  # per-letter mouse hop (title logo)
var _look_key := ""

## Garage purchase: sparkle around Kavi, a chime, a happy face.
func fx_unlock() -> void:
	synth.play("tier")
	var p := Vector2(sim.x, sim.y - 60.0)
	fx.burst(p, Color(1.0, 0.85, 0.4), 26, 420.0, 0.8, 5.0, 300.0)
	fx.ring(p, Color(1.0, 0.9, 0.6), 160.0, 0.5, 5.0)
	kite.expr = "heart"

## Dress Kavi in what he wears, or try on one Garage item (preview).
func apply_look(preview_cat := "", preview_i := -1) -> void:
	var key := "%s|%s|%d" % [str(save.data.wear), preview_cat, preview_i]
	if key == _look_key:
		return
	_look_key = key
	kite.set_look(Looks.compose(save.data.wear, preview_cat, preview_i))

# ------------------------------------------------------------------ state
var state = "title"     # title, run, recovery, junction, rescue, fail, results, finale, paused
var mode = "story"      # story, endless, daily
var t = 0.0
var state_t = 0.0
var chapter = 0
var seg_idx = 0          # endless segment index / story stage within chapter
var stage = "intro"      # story: intro, route
var route = "scenic"
var seg_end = 0.0
var biome = 0
var pal: Dictionary = Art.biome(0)
var pal_from: Dictionary = Art.biome(0)
var pal_k = 1.0
var score = 0.0
var stamps_run = 0
var perfects_run = 0
var dist_start = 0.0
var story_total = 1.0
var story_done_px = 0.0
var lb = 0.0              # letterbox 0..1
var lb_target = 0.0
var zoom = 1.0
var zoom_target = 1.0
var shake = 0.0
var slowmo_t = 0.0
var fade = 0.0
var fade_target = 0.0
var card = {}             # chapter card {title, sub, t}
var toasts: Array = []
var caption = ""
var caption_t = 0.0
var hint = ""
var hint_t = 0.0
var activity = {}
var npc_x = 0.0
var rescue = {}
var finale = {}
var kite_override = false
var kite_pos = Vector2.ZERO
var input_latch = {"jump": false, "down": false, "gust": false, "letter": false}
var autopilot = false
var paused_from = ""
var rescue_planned = {}   # {"chapter": c} or {"seg": n}
var junction_choice = ""
const JUNCTION_TIME := 7.0
var junction_t := 0.0     # own timer, so pausing doesn't eat the countdown
var junction_easy := false
var _junction_tick := -1
var cam_pos = Vector2.ZERO
var title_x = 0.0
var fail_t = 0.0
var last_result = {}

# capture director
var capture_dir = ""
var bench = {}
var input_mode := "touch"   # "touch" or "keys": decides touch buttons vs key hints
var hearts := 3
const MAX_HEARTS := 3
var env: Environment
var forced_quality := -1
var q_frames: Array = []
var q_cool := 0.0
var cap_steps: Array = []
var cap_i = 0
var cap_wait = 0.0
var cap_events = {}
var cap_shots: Array = []

# ------------------------------------------------------------------ setup
func _ready() -> void:
	randomize()
	save.load_data()
	Looks.ensure(save.data)
	ads.save = save
	font = _load_font("res://assets/fonts/Fredoka.ttf", 600)
	font_body = _load_font("res://assets/fonts/Nunito.ttf", 800)
	_build_scene()
	# Display title (window / browser tab). project config/name stays "VOLT/RUN"
	# because it names the save folder on desktop.
	get_window().title = "%s: %s" % [HERO, GAME_SUB]
	_setup_cursor()
	input_mode = "touch" if DisplayServer.is_touchscreen_available() else "keys"
	if OS.has_feature("web") or OS.has_feature("mobile"):
		Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			capture_dir = a.substr(10)
		if a.begins_with("--hide="):
			set_meta("hide", a.substr(7).split(","))
		if a.begins_with("--quality="):
			forced_quality = ["low", "medium", "high"].find(a.substr(10))
		if a.begins_with("--bench="):
			bench = {"out": a.substr(8), "frames": [], "script": [], "draws": [], "prims": [], "t": 0.0}
	_apply_settings()
	if capture_dir != "":
		_setup_capture()
	# Returning players (any earlier progress) are never forced into it.
	if not save.data.tutorial_done and (int(save.data.runs) > 0 or save.data.story_done or (save.data.seen_hints as Array).size() > 0):
		save.data.tutorial_done = true
		save.save()
	go_title()
	if has_meta("hide"):
		var nodes = {"world": world_view, "track": track_view, "kite": kite, "hud": hud, "fg": fg, "fx": fx, "cast": cast_base, "touch": touch, "ui": ui, "vignette": vignette}
		for k in get_meta("hide"):
			if nodes.has(k):
				nodes[k].visible = false
	if bench.size() > 0:
		autopilot = true
		save.data.tutorial_done = true
		start_story(1)
		card = {}
	elif capture_dir == "" and not save.data.tutorial_done:
		start_tutorial()

func _build_scene() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 4
	env.glow_enabled = true
	env.glow_intensity = 0.32
	env.glow_strength = 0.85
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.15
	env.glow_hdr_scale = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, [0.0, 0.5, 0.8, 0.5, 0.3, 0.0, 0.0][i])
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var bg = CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	world_view = WorldView.new()
	bg.add_child(world_view)

	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()

	track_view = TrackView.new()
	add_child(track_view)
	cast_base = Painter.new()
	cast_base.fn = _draw_cast.bind(false)
	add_child(cast_base)
	cast_add = Painter.new()
	cast_add.fn = _draw_cast.bind(true)
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cast_add.material = m
	add_child(cast_add)
	kite = KiteView.new()
	add_child(kite)
	fx = Fx.new()
	add_child(fx)

	var fgl = CanvasLayer.new()
	fgl.layer = 3
	add_child(fgl)
	fg = Painter.new()
	fg.fn = func(ci): world_view.draw_foreground(ci, 0.0)
	fgl.add_child(fg)

	var ul = CanvasLayer.new()
	ul.layer = 10
	add_child(ul)
	vignette = TextureRect.new()
	var gt = GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.46)
	gt.fill_to = Vector2(1.08, 1.08)
	var g = Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.45))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	gt.gradient = g
	gt.width = 256
	gt.height = 256
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ul.add_child(vignette)
	hud = Painter.new()
	hud.fn = _draw_hud
	ul.add_child(hud)
	touch = Touch.new()
	ul.add_child(touch)
	ui = UI.new()
	ui.main = self
	ui.font = font
	ui.font_body = font_body
	ul.add_child(ui)

	synth = Synth.new()
	add_child(synth)

## Quality: 0 low (no HDR/glow, sparse detail), 1 medium, 2 high.
## "Auto" starts at medium on phones and browsers, high on desktop, and steps
## down by itself if frames stay slow during play.
func _initial_quality() -> int:
	if forced_quality >= 0:
		return forced_quality
	var g = save.data.settings.get("graphics", "auto")
	var i = ["low", "medium", "high"].find(g)
	if i >= 0:
		return i
	return 1 if (OS.has_feature("web") or OS.has_feature("mobile")) else 2

func apply_quality(q: int) -> void:
	Art.Q = clampi(q, 0, 2)
	Art.AA = Art.Q >= 2
	set_meta("quality_name", ["low", "medium", "high"][Art.Q])
	if env:
		env.glow_enabled = Art.Q >= 1
	get_viewport().use_hdr_2d = Art.Q >= 1
	fx.density = [0.35, 0.7, 1.0][Art.Q] * (0.5 if save.data.settings.reduced_motion else 1.0)
	fx.max_parts = [120, 300, 600][Art.Q]
	kite.trail_on = Art.Q >= 1
	q_frames.clear()

func _adapt_quality(real_dt: float) -> void:
	if forced_quality >= 0 or capture_dir != "" or save.data.settings.get("graphics", "auto") != "auto":
		return
	q_cool = maxf(q_cool - real_dt, 0.0)
	if state != "run" or Art.Q == 0 or q_cool > 0.0:
		return
	q_frames.append(real_dt)
	if q_frames.size() < 120:
		return
	var sum := 0.0
	for f in q_frames:
		sum += f
	q_frames.clear()
	if sum / 120.0 > 0.021:
		apply_quality(Art.Q - 1)
		q_cool = 4.0
		_toast("Graphics: " + str(get_meta("quality_name")) + " (smoother)", Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.2), Color(1, 1, 1, 0.7), 28)

func _apply_settings() -> void:
	var st: Dictionary = save.data.settings
	synth.music_vol = st.music
	synth.sfx_vol = st.sfx
	touch.left_handed = st.left_handed
	touch.scale_k = st.controls_scale
	kite.reduced_motion = st.reduced_motion
	apply_quality(_initial_quality())
	if sim != null:
		sim.kind_mode = st.kind_mode
		sim.assist_hover = st.assist_hover
	track_view.kind_mode = st.kind_mode

# ------------------------------------------------------------------ flow
## Bundled OFL fonts (see docs/LEDGER.csv); a system font is the fallback.
func _load_font(path: String, weight: int) -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Nunito", "Noto Sans", "DejaVu Sans", "sans-serif"])
	sys.font_weight = weight
	var base = load(path) if ResourceLoader.exists(path) else null
	if base == null:
		return sys
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	# a touch of extra space between letters reads better on PC screens
	v.spacing_glyph = 1
	v.fallbacks = [sys]
	return v

func go_title() -> void:
	Engine.time_scale = 1.0
	state = "title"
	state_t = 0.0
	_new_world(0)
	set_biome(0, true)
	sim.frozen = true
	title_x = 0.0
	lb_target = 0.0
	zoom_target = 1.3
	garage_open = false
	menu_dim = false
	touch.visible_controls = false
	touch.highlight = ""
	mode = "story"
	ui.show_title()
	synth.set_drive(0.0)

func _new_world(b: int) -> void:
	track = Track.new()
	sim = Sim.new()
	sim.track = track
	track_view.track = track
	track_view.sim = sim
	kite.reset_scarf()
	tw.reset()
	score = 0.0
	stamps_run = 0
	perfects_run = 0
	toasts.clear()
	fx.parts.clear()
	_apply_settings()

func set_biome(b: int, instant := false) -> void:
	if instant:
		world_view.end_transition()
		track_view.end_transition()
	elif b != biome or pal_k < 1.0:
		# the new country sweeps in from the right (see world_view/track_view)
		world_view.begin_transition(Art.biome(biome), Art.biome(b))
		track_view.begin_transition(Art.biome(biome).get("surface", ""), Art.biome(b).get("surface", ""), track_view.view_r + 200.0)
	pal_from = pal if not instant else Art.biome(b)
	biome = b
	pal_k = 1.0 if instant else 0.0
	if instant:
		pal = Art.biome(b)
	synth.set_biome(b % 4)

func run_zoom() -> float:
	return clampf(1.24 - (sim.v - 500.0) / 460.0 * 0.14, 1.06, 1.24) if sim != null else 1.2

func speed_mult() -> float:
	return 0.82 if save.data.settings.slow_speed else 1.0

func start_story(from_chapter := 0) -> void:
	mode = "story"
	hearts = MAX_HEARTS
	_new_world(from_chapter)
	chapter = from_chapter
	stage = "intro"
	set_biome(chapter, true)
	var c = 0
	var r = randi() % 2
	rescue_planned = {"chapter": 1 + r, "stage": "route"}
	_compute_story_total()
	dist_start = sim.x
	story_done_px = 0.0
	_begin_story_segment()
	_enter_run()
	_show_card(Art.biome(chapter).name, "Chapter %d · %s" % [chapter + 1, Art.biome(chapter).country])

func start_tutorial() -> void:
	mode = "tutorial"
	_new_world(0)
	set_biome(0, true)
	tut = Tutorial.new()
	sim.v = Tutorial.SPEED
	sim.kind_mode = false
	dist_start = sim.x
	seg_end = Tutorial.build(track)
	_enter_run()
	ui.show_tutorial_skip()
	_show_card("Welcome, courier", "%s runs on his own. You make the moves." % HERO, 0.2)

func finish_tutorial() -> void:
	state = "tut_done"
	state_t = 0.0
	sim.frozen = true
	touch.visible_controls = false
	touch.highlight = ""
	save.data.tutorial_done = true
	# The story's first-time hints would repeat what was just learned.
	save.data.seen_hints = ["hurdle", "beam", "gap", "wide_gap", "gate", "bell", "bloom"]
	save.save()
	synth.play("tier")
	_toast("YOU'RE READY!", Vector2(get_viewport_rect().size.x * 0.5, get_viewport_rect().size.y * 0.3), Color(0.6, 1.0, 0.9), 72)
	ui.show_tutorial_done()

func skip_tutorial() -> void:
	save.data.tutorial_done = true
	save.save()
	touch.highlight = ""
	synth.play("ui")
	go_title()

func menu_tutorial() -> void:
	synth.play("ui")
	start_tutorial()

func _story_params(ch: int, stg: String, rt: String) -> Dictionary:
	var base_v: float = [500.0, 540.0, 580.0, 620.0][ch] * speed_mult()
	var types: Array = [[HURDLE, BEAM, GAP], [HURDLE, BEAM, GAP, WIDE_GAP, GATE, BLOOM],
		[HURDLE, BEAM, GAP, WIDE_GAP, GATE, BLOOM, BELL], [HURDLE, BEAM, GAP, WIDE_GAP, GATE, BLOOM, BELL]][ch]
	if ch == 0 and stg == "route":
		types = [HURDLE, BEAM, GAP, WIDE_GAP]
	var p = {"v": base_v, "secs": 50.0, "diff": [0.1, 0.25, 0.35, 0.45][ch], "types": types, "combos": ch >= 2}
	if stg == "route":
		if rt == "wild":
			p.v = base_v * 1.1
			p.secs = 40.0
			p.diff = minf(p.diff + 0.45, 1.0)
			p.combos = ch >= 1
		else:
			p.secs = 62.0
			p.diff = p.diff + 0.05
	return p

func _compute_story_total() -> void:
	var tot = 0.0
	for ch in 4:
		var a = _story_params(ch, "intro", "")
		var b = _story_params(ch, "route", "scenic")
		tot += a.v * a.secs + b.v * b.secs + 160.0 * 24.0
	story_total = tot

func _begin_story_segment() -> void:
	var p = _story_params(chapter, stage, route)
	sim.v = p.v
	var with_rescue: bool = rescue_planned.get("chapter", -1) == chapter and rescue_planned.get("stage", "") == stage
	var x0: float = sim.x + 40.0
	seg_end = track.gen_segment(x0, p.secs, p.v, p.diff, p.types, randi(), with_rescue, p.combos)
	if with_rescue:
		rescue_planned = {}

func start_endless(daily := false) -> void:
	mode = "daily" if daily else "endless"
	hearts = MAX_HEARTS
	_new_world(0)
	seg_idx = 0
	route = "scenic"
	set_biome(0, true)
	var runs: int = save.data.runs_since_rescue
	rescue_planned = {}
	if not daily and (runs >= 3 or (runs >= 1 and randf() < 0.45)):
		rescue_planned = {"seg": 1 + randi() % 2}
	dist_start = sim.x
	_begin_endless_segment()
	_enter_run()
	_show_card("The Endless Road" if not daily else "Daily Relay", "How far will %s's tailwind carry?" % HERO if not daily else _daily_key())

func _daily_key() -> String:
	var d = Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _endless_params(n: int, rt: String) -> Dictionary:
	var v = minf(540.0 + 34.0 * n, 960.0) * speed_mult()
	var types: Array = [HURDLE, BEAM, GAP]
	if n >= 1: types += [WIDE_GAP, GATE]
	if n >= 2: types += [BLOOM]
	if n >= 3: types += [BELL]
	var p = {"v": v, "secs": 55.0, "diff": minf(0.1 + 0.13 * n, 0.95), "types": types, "combos": n >= 2}
	if rt == "wild":
		p.v += 40.0
		p.secs = 42.0
		p.diff = minf(p.diff + 0.25, 1.0)
		p.combos = true
	return p

func _begin_endless_segment() -> void:
	var p = _endless_params(seg_idx, route)
	sim.v = p.v
	var with_rescue: bool = rescue_planned.get("seg", -1) == seg_idx
	var seed_v = randi()
	if mode == "daily":
		seed_v = hash(_daily_key()) + seg_idx * 7919 + (1 if route == "wild" else 0)
	seg_end = track.gen_segment(sim.x + 40.0, p.secs, p.v, p.diff, p.types, seed_v, with_rescue, p.combos)
	if with_rescue:
		rescue_planned = {}

func _enter_run() -> void:
	Engine.time_scale = 1.0
	state = "run"
	state_t = 0.0
	sim.frozen = false
	lb_target = 0.0
	zoom_target = run_zoom()
	touch.visible_controls = _want_touch()
	touch.release_all()
	ui.show_none()
	synth.set_drive(1.0)

func _segment_finished() -> void:
	# called when Kite passes seg_end
	if mode == "tutorial":
		finish_tutorial()
		return
	if mode == "story":
		story_done_px += _story_params(chapter, stage, route).v * _story_params(chapter, stage, route).secs
		if stage == "intro":
			_enter_recovery(true)
		else:
			if chapter >= 3:
				_enter_finale()
			else:
				_enter_recovery(false)
	else:
		seg_idx += 1
		_enter_recovery(true)

# ------------------------------------------------------------------ recovery
const ACTIVITIES := [
	{"pose": "eat", "npc": "yiayia", "text": "Yiayia Froso insists: \"Eat! You're all circuits and no koulouri!\""},
	{"pose": "drink", "npc": "shop", "text": "A shopkeeper hands Kavi cold water. \"For the road, little courier.\""},
	{"pose": "read", "npc": "", "text": "Message from Lia: \"I painted the sunrise for you today.\""},
	{"pose": "map", "npc": "", "text": "Kavi checks the map. Lia is getting closer."},
	{"pose": "photo", "npc": "", "text": "Snap! A new memory for the scrapbook."},
	{"pose": "stretch", "npc": "kid", "text": "Kids cheer from the roadside: \"Go, Kavi, go!\""},
	{"pose": "eat", "npc": "farmer", "text": "A farmer shares a ripe peach from the orchard."},
	{"pose": "read", "npc": "", "text": "Message from Lia: \"The storks came back today. I saved you a sketch.\""},
	{"pose": "read", "npc": "", "text": "Message from Lia: \"Grandma calls me Cornelia when I'm late for dinner. You can keep calling me Lia.\""},
	{"pose": "read", "npc": "", "text": "Message from Lia: \"If you wanted to, you would. ...You did.\""},
]

func _enter_recovery(then_junction: bool) -> void:
	_ground_kite()
	_clear_ahead()
	state = "recovery"
	state_t = 0.0
	sim.frozen = true
	activity = ACTIVITIES[randi() % ACTIVITIES.size()].duplicate()
	activity.dur = 10.0 if mode == "story" else 7.0
	activity.junction = then_junction
	activity.next_chapter = (mode == "story" and stage == "route")
	npc_x = sim.x + 300.0
	lb_target = 1.0
	zoom_target = 1.38
	touch.visible_controls = false
	synth.set_drive(0.0)
	caption = activity.text
	caption_t = activity.dur
	if activity.pose == "photo":
		save.data.photos = int(save.data.photos) + 1
	if mode != "story":
		set_biome((biome + 1) % 4)
	elif activity.next_chapter:
		var got := _bank_run(2)
		_toast("Chapter done!  +%d Stamps   +%d Sparks" % [got.stamps, got.sparks], get_viewport_rect().size * Vector2(0.5, 0.22), Color(1.0, 0.85, 0.45), 44)
		chapter += 1
		stage = "intro"
		save.data.story_chapter = maxi(int(save.data.story_chapter), chapter)
		save.save()
		set_biome(chapter)
		_show_card(Art.biome(chapter).name, "Chapter %d · %s" % [chapter + 1, Art.biome(chapter).country], 2.0)
	ui.show_skip()

func _update_recovery(dt: float) -> void:
	var d: float = activity.dur
	var k = state_t
	var walk = 0.0
	if k < 1.6:
		walk = lerpf(sim.v * 0.6, 140.0, k / 1.6)
	elif k > d - 1.8:
		walk = lerpf(140.0, sim.v * 0.7, (k - (d - 1.8)) / 1.8)
	elif k < 2.6:
		walk = 140.0 * (1.0 - (k - 1.6))
	sim.x += maxf(walk, 0.0) * dt
	if k >= d:
		_after_recovery()

func skip_recovery() -> void:
	if state == "recovery" and state_t > 0.4:
		_after_recovery()

func _after_recovery() -> void:
	caption_t = 0.0
	ui.show_none()
	if activity.get("junction", false):
		_enter_junction()
	else:
		_begin_next_segment()

func _begin_next_segment() -> void:
	if mode == "story":
		_begin_story_segment()
	else:
		_begin_endless_segment()
	_enter_run()

# ------------------------------------------------------------------ junction
func _enter_junction() -> void:
	_ground_kite()
	state = "junction"
	state_t = 0.0
	junction_choice = ""
	junction_t = 0.0
	junction_easy = false
	_junction_tick = -1
	sim.frozen = true
	lb_target = 0.6
	zoom_target = 1.15
	ui.show_junction(mode == "story")

func choose_route(r: String) -> void:
	if state != "junction":
		return
	junction_choice = r
	route = r
	synth.play("ui")
	if mode == "story":
		stage = "route"
		if r == "wild":
			story_total -= (_story_params(chapter, "route", "scenic").v * _story_params(chapter, "route", "scenic").secs
				- _story_params(chapter, "route", "wild").v * _story_params(chapter, "route", "wild").secs)
	ui.show_none()
	_toast(("WILD ROUTE" if r == "wild" else "SCENIC ROUTE"), _kite_screen() + Vector2(0, -180), Color(1.0, 0.6, 0.4) if r == "wild" else Color(0.5, 1.0, 0.8), 64)
	_begin_next_segment()

func _update_junction(dt: float) -> void:
	sim.x += 160.0 * dt
	junction_t += dt
	var rem := JUNCTION_TIME - junction_t
	# ticks in the last seconds, rising in pitch
	var sec := int(ceil(rem))
	if sec != _junction_tick and sec <= 4 and sec > 0:
		synth.play("ui", 1.0 + (4 - sec) * 0.18, -2.0 + (4 - sec) * 1.5)
	_junction_tick = sec
	if rem < 2.3 and not junction_easy:
		junction_easy = true
		synth.play("mote", 0.8)
		ui.junction_go_easy()
	if rem <= 0.0 and junction_choice == "":
		choose_route("scenic")

# ------------------------------------------------------------------ rescue
func _start_rescue(o: Dictionary) -> void:
	state = "rescue"
	state_t = 0.0
	o.fall_t = 0.0
	sim.frozen = true
	var v: int = randi() % Chars.BIKERS.size()
	rescue = {"o": o, "v": v, "kx": sim.x, "land": o.x + o.w + 260.0, "bx": sim.x - 1100.0, "by": 0.0, "lean": 0.0}
	lb_target = 1.0
	zoom_target = 1.0
	kite.expr = "scared"
	touch.visible_controls = false
	ui.show_none()
	synth.play("engine", 1.0, -2.0)
	save.data.runs_since_rescue = 0
	save.save()

func _update_rescue(real_dt: float) -> void:
	var r = rescue
	var o: Dictionary = r.o
	var k = state_t
	o.fall_t = o.get("fall_t", 0.0) + real_dt * (0.35 if k < 1.0 else 1.0)
	var reduced: bool = save.data.settings.reduced_motion
	Engine.time_scale = 1.0 if reduced else (0.35 if k < 1.0 else 1.0)
	kite_override = true
	if k < 1.0:
		# biker races in from behind
		var f = ease(k / 1.0, 0.6)
		r.bx = lerpf(r.kx - 1100.0, r.kx - 30.0, f)
		r.by = 0.0
		r.lean = -0.05
		kite_pos = Vector2(r.kx + k * 30.0, 0)
		kite.pose = "fail" if k > 0.7 else "run"
		kite.expr = "scared"
		if k > 0.9 and not r.has("grab"):
			r.grab = true
			fx.burst(Vector2(r.kx, -60), Color(1, 0.8, 0.5), 30, 400, 0.5, 5)
			synth.play("land", 0.8)
	elif k < 2.7:
		# the big jump over the collapse
		var f2 = (k - 1.0) / 1.7
		var x0: float = r.kx
		var x1: float = r.land
		r.bx = lerpf(x0, x1, f2)
		r.by = -sin(f2 * PI) * 330.0
		r.lean = lerpf(-0.25, 0.2, f2)
		kite_pos = Vector2(r.bx - 18.0, r.by - 62.0)
		kite.pose = "ride"
		kite.expr = "wow"
		if not r.has("land_fx") and f2 > 0.97:
			r.land_fx = true
			fx.burst(Vector2(x1, 0), pal.rim, 40, 500, 0.6, 5, 600, PI, -PI * 0.5)
			shake = 8.0
	elif k < 5.0:
		# thank-you moment
		r.bx = r.land + (k - 2.7) * 20.0
		r.by = 0.0
		r.lean = 0.0
		kite_pos = Vector2(r.land + 120.0, 0)
		kite.pose = "wave"
		kite.expr = "heart"
		if not r.has("thanks"):
			r.thanks = true
			var b: Dictionary = Chars.BIKERS[r.v]
			caption = "%s swoops in out of nowhere!  Kavi: \"THANK YOU!!\"  %s: \"Anytime, little courier. Ride safe!\"" % [b.name, b.name]
			caption_t = 3.6
			_toast("THANK YOU!", _world_to_screen(kite_pos + Vector2(0, -170)), Color(1.0, 0.6, 0.8), 58)
			_add_memory("Rescued by " + b.name)
	elif k < 6.2:
		r.bx += real_dt * (300.0 + (k - 5.0) * 1600.0)
		r.lean = -0.1
		kite_pos = Vector2(r.land + 120.0, 0)
		kite.pose = "wave"
	else:
		kite_override = false
		sim.x = r.land + 120.0
		sim.y = 0.0
		sim.vy = 0.0
		sim.on_ground = true
		sim.dead = false
		o.passed = true
		Engine.time_scale = 1.0
		rescue = {}
		kite.expr = "happy"
		_enter_recovery(mode != "story" or stage == "intro")

func _add_memory(text: String) -> void:
	_toast("+ memory: " + text, Vector2(get_viewport_rect().size.x * 0.5, 230), Color(1.0, 0.9, 0.6), 30)

# ------------------------------------------------------------------ finale
func _enter_finale() -> void:
	_ground_kite()
	track.obs = track.obs.filter(func(o): return o.x + Track.obstacle_extent(o) < sim.x)
	state = "finale"
	state_t = 0.0
	sim.frozen = true
	finale = {"lx": sim.x + 900.0}
	lb_target = 1.0
	zoom_target = 1.45
	touch.visible_controls = false
	synth.set_drive(0.0)

func _update_finale(dt: float) -> void:
	var lx: float = finale.lx
	var k = state_t
	if sim.x < lx - 110.0:
		sim.x += lerpf(sim.v * 0.6, 140.0, clampf(k / 3.0, 0.0, 1.0)) * dt
	if k > 3.2 and not finale.has("met"):
		finale.met = true
		caption = "Lia: \"You came all this way...\"   Kavi: \"If you wanted to, you would.\""
		caption_t = 5.0
	if k > 9.0 and not finale.has("end"):
		finale.end = true
		save.data.story_done = true
		save.data.best_story = maxi(int(save.data.get("best_story", 0)), int(score))
		save.save()
		_bank_run(2)
		save.save()
		ui.show_finale_end()

const SAFE_SECONDS := 4.0
var fail_puffed := false

func _respawn_clear() -> void:
	var px: float = sim.x
	var until: float = px + sim.cur_speed() * SAFE_SECONDS
	# puff over Kavi, and a small puff wherever a visible obstacle disappears
	fx.smoke(Vector2(px, sim.y - 50.0), 14, 90.0, 1.2)
	fx.smoke(Vector2(px, -40.0), 8, 70.0, 1.0)
	var keep: Array = []
	for o in track.obs:
		var ox: float = o.x
		var ext: float = Track.obstacle_extent(o)
		if ox + ext > px - 300.0 and ox < until and not (o.t == RESCUE and o.passed):
			if ox < track_view.view_r + 200.0:
				fx.smoke(Vector2(ox + ext * 0.5, -60.0), 7, 70.0, 0.9)
		else:
			keep.append(o)
	track.obs = keep
	sim.respawn(px)
	sim.x = px
	synth.play("ui")

## A break can start mid-stretch (after a rescue): drop what is left of
## that stretch so it never overlaps the next one.
func _clear_ahead() -> void:
	if mode == "story" and seg_end > sim.x:
		story_done_px += maxf(seg_end - sim.x, 0.0)
	track.obs = track.obs.filter(func(o): return o.x + Track.obstacle_extent(o) < sim.x - 10.0 or (o.t == RESCUE and o.passed))
	track.motes = track.motes.filter(func(m): return m.x < sim.x)
	seg_end = minf(seg_end, sim.x)

func _ground_kite() -> void:
	sim.y = 0.0
	sim.vy = 0.0
	sim.on_ground = true
	sim.sliding = false
	sim.diving = false
	sim.hovering = false
	sim.planes.clear()

# ------------------------------------------------------------------ fail
func _on_fail() -> void:
	if mode == "tutorial":
		tut.reprompt = true
	else:
		tw.mistake()
		hearts -= 1
		_toast("%d heart%s left" % [hearts, "" if hearts == 1 else "s"] if hearts > 0 else "Out of hearts", _kite_screen() + Vector2(0, -170), Color(1.0, 0.55, 0.65), 44)
	shake = 14.0 if save.data.settings.shake else 0.0
	synth.play("fail")
	kite.expr = "dizzy"
	fx.burst(Vector2(sim.x, sim.y - 50), Color(1.0, 0.5, 0.4), 26, 420, 0.6, 5, 500)
	state = "fail"
	state_t = 0.0
	fail_t = 0.0

func _update_fail(dt: float) -> void:
	if mode == "tutorial":
		if state_t > 0.7:
			var back2: float = sim.x - Tutorial.SPEED * 1.6
			var g2 = 0
			while track.hole_at(back2) and g2 < 50:
				back2 -= 30.0
				g2 += 1
			sim.respawn(back2)
			kite.reset_scarf()
			kite.expr = "focus"
			state = "run"
			state_t = 0.0
			_toast("Try again!", _kite_screen() + Vector2(0, -150), Color(1, 0.9, 0.7), 40)
		return
	if hearts <= 0:
		if state_t > 1.3:
			_game_over()
		return
	# Owner design (0.8.2): a cartoon smoke puff hides Kavi and any obstacles
	# in the next few seconds; he pops out running where he fell (the meters
	# keep counting), with ~4 s of clear road before the next obstacle.
	if state_t > 0.55 and not fail_puffed:
		fail_puffed = true
		_respawn_clear()
	if state_t > 0.95:
		kite.reset_scarf()
		kite.expr = "focus"
		state = "run"
		state_t = 0.0
		fail_puffed = false

## Three hearts per run. When they are gone the run is over: story players go
## back to the home screen (their reached chapter is kept); endless shows results.
## Two currencies (owner design, 0.8.1): Stamps are collected while running;
## Sparks are rare: +1 for reaching Tailwind x4, +1 per 10 perfect moves and
## +2 for every story chapter finished. The Garage can exchange them.
func _bank_run(chapter_bonus := 0) -> Dictionary:
	var sparks: int = (1 if tw.best_tier >= 4 else 0) + perfects_run / 10 + chapter_bonus
	var got := {"stamps": stamps_run, "sparks": sparks}
	save.data.stamps = int(save.data.stamps) + stamps_run
	save.data.sparks = int(save.data.sparks) + sparks
	stamps_run = 0
	perfects_run = 0
	tw.best_tier = tw.tier()
	return got

## Highest score in any mode (shown on the title screen).
func best_any() -> int:
	return maxi(int(save.data.best_endless), maxi(int(save.data.best_daily), int(save.data.get("best_story", 0))))

func _game_over() -> void:
	if mode == "story":
		save.data.best_story = maxi(int(save.data.get("best_story", 0)), int(score))
		var got := _bank_run()
		_toast("+%d Stamps   +%d Sparks" % [got.stamps, got.sparks], get_viewport_rect().size * Vector2(0.5, 0.3), Color(1.0, 0.85, 0.45), 44)
		state = "results"
		state_t = 0.0
		sim.frozen = true
		touch.visible_controls = false
		toasts.clear()
		save.data.story_chapter = maxi(int(save.data.story_chapter), chapter)
		save.data.runs = int(save.data.runs) + 1
		save.save()
		synth.set_drive(0.0)
		ui.show_story_over(chapter)
	else:
		_end_run()

func _end_run() -> void:
	toasts.clear()
	state = "results"
	state_t = 0.0
	sim.frozen = true
	touch.visible_controls = false
	var dist_m = (sim.x - dist_start) / PX_PER_M
	var key = "best_daily" if mode == "daily" else "best_endless"
	var best = int(save.data[key])
	var sc = int(score)
	var new_best: bool = sc > best
	if new_best:
		save.data[key] = sc
	var run_perfects: int = perfects_run
	var run_tier: int = tw.best_tier
	var got := _bank_run()
	var sparks: int = got.sparks
	save.data.runs = int(save.data.runs) + 1
	save.data.runs_since_rescue = int(save.data.runs_since_rescue) + 1
	save.save()
	last_result = {"score": sc, "dist": int(dist_m), "stamps": got.stamps, "perfects": run_perfects, "tier": run_tier,
		"best": maxi(best, sc), "new_best": new_best, "sparks": sparks, "banked": got.stamps}
	ui.show_results(last_result)
	synth.set_drive(0.0)

# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if touch.handle(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_back_pressed()
		get_viewport().set_input_as_handled()
		return
	if state == "recovery" and _is_press(event, ["jump"]):
		skip_recovery()

func _is_press(event: InputEvent, names: Array) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode in [KEY_UP, KEY_W, KEY_SPACE]
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_A
	return false

func _key_dir(event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_UP, KEY_W]: return -1
		if event.keycode in [KEY_DOWN, KEY_S]: return 1
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP: return -1
		if event.button_index == JOY_BUTTON_DPAD_DOWN: return 1
	return 0

func _read_input() -> Dictionary:
	var held_jump = Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var held_down = Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	var gust = Input.is_key_pressed(KEY_X) or Input.is_key_pressed(KEY_J) or Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	var letter = Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_K) or Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
	var tp: Dictionary = touch.consume()
	held_jump = held_jump or touch.state.jump
	held_down = held_down or touch.state.down
	var inp = {
		"jump_pressed": (held_jump and not input_latch.jump) or tp.jump,
		"jump_held": held_jump,
		"down_pressed": (held_down and not input_latch.down) or tp.down,
		"down_held": held_down,
		"gust_pressed": (gust and not input_latch.gust) or tp.gust,
		"letter_pressed": (letter and not input_latch.letter) or tp.letter,
	}
	input_latch = {"jump": held_jump, "down": held_down, "gust": gust, "letter": letter}
	return inp

## Esc on desktop and the Back button on Android (0.8.11): leave Scenic View,
## pause a run, step back out of a menu, or ask before quitting from the title.
func _back_pressed() -> void:
	if state == "scenic":
		go_title()
	elif state == "title":
		if garage_open or menu_dim:
			ui.show_title()
		elif can_quit():
			ui.confirm_quit()
	else:
		toggle_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back_pressed()

## The web build has no Quit (closing the tab is how you leave a web page).
func can_quit() -> bool:
	return not OS.has_feature("web")

func quit_game() -> void:
	save.save()
	get_tree().quit()

func toggle_pause() -> void:
	if state in ["run", "recovery", "junction"]:
		paused_from = state
		state = "paused"
		Engine.time_scale = 1.0
		ui.show_pause()
	elif state == "paused":
		resume()

func resume() -> void:
	if state == "paused":
		state = paused_from
		ui.show_none()
		if state == "recovery":
			ui.show_skip()
		elif mode == "tutorial" and state == "run":
			ui.show_tutorial_skip()
		elif state == "junction":
			ui.show_junction(mode == "story")
		touch.release_all()

# ------------------------------------------------------------------ simulation tick
var _pending_inputs = {"jump_pressed": false, "down_pressed": false, "gust_pressed": false, "letter_pressed": false}
var _prev_x = 0.0
var _prev_y = 0.0

func _physics_process(dt: float) -> void:
	if state != "run" and state != "fail":
		return
	if state == "fail":
		return
	var inp: Dictionary
	if mode == "tutorial":
		tut.touch_mode = input_mode == "touch"
		var f = tut.filter(_read_input(), sim, dt, autopilot)
		touch.highlight = tut.highlight_zone()
		if f == null:
			if tut.wait_t == 0.0:
				note_capture_event("tut_prompt")
				synth.play("ui", 1.2, -6.0)
			_prev_x = sim.x
			_prev_y = sim.y
			return
		inp = f
	elif autopilot:
		inp = Track.bot_input(sim)
	else:
		inp = _read_input()
	_prev_x = sim.x
	_prev_y = sim.y
	# ease into speed at the start of every stretch
	sim.speed_scale = 1.0 if mode == "tutorial" else clampf(0.72 + 0.28 * state_t / 2.5, 0.72, 1.0)
	sim.step(dt, inp)
	for e in sim.events:
		_on_event(e)
	if state != "run":
		return
	# motes
	var kc = Vector2(sim.x, sim.y - 50.0)
	for m in track.motes:
		if m.x > sim.x + 60.0:
			break
		if not m.taken and absf(m.x - kc.x) < 46.0 and absf(m.y - kc.y) < 60.0:
			m.taken = true
			stamps_run += 1
			score += 10.0 * tw.tier()
			synth.play("mote", 1.0 + randf() * 0.3, -6.0)
			fx.burst(Vector2(m.x, m.y), pal.mote, 8, 220, 0.4, 4)
	score += sim.cur_speed() * dt / PX_PER_M * (1.5 if route == "wild" and mode != "story" else 1.0)
	if sim.x > seg_end:
		_segment_finished()
	track.trim_before(sim.x - 3000.0)

func _on_event(e: Dictionary) -> void:
	note_capture_event(e.type)
	match e.type:
		"jump":
			synth.play("jump", 1.0 + randf() * 0.05, -4.0)
			fx.burst(Vector2(sim.x, 0), pal.rim, 8, 180, 0.35, 3, 300, PI * 0.8, -PI * 0.5)
		"land":
			if e.impact > 900.0:
				synth.play("land", 1.0, -6.0)
				fx.burst(Vector2(sim.x, 0), pal.rim, 10, 220, 0.35, 3, 200, PI * 0.9, -PI * 0.5)
		"slide":
			synth.play("slide", 1.0, -6.0)
		"dive":
			synth.play("dive", 1.0, -5.0)
		"hover":
			synth.play("hover", 1.0, -8.0)
		"swoop":
			_perfect("SWOOP!", Color(1.0, 0.6, 0.3))
			shake = maxf(shake, 4.0)
			fx.burst(Vector2(sim.x, 0), Color(1.0, 0.7, 0.3), 24, 500, 0.45, 4, 0, PI * 0.5, PI)
		"gust":
			synth.play("gust", 1.0, -4.0)
			fx.gust(Vector2(sim.x + 30.0, sim.y - 56.0))
			kite.pose = "gust"
		"gate_open":
			fx.burst(Vector2(e.o.x + 20.0, -200), Color(0.5, 1.0, 0.6), 24, 380, 0.6, 5)
			if e.perfect:
				_perfect("PERFECT GUST", Color(0.5, 1.0, 0.6))
		"letter":
			synth.play("letter", 1.0, -4.0)
		"bell":
			synth.play("bell", 1.0, -2.0)
			fx.ring(Vector2(e.o.bell_x - 20.0, e.o.bell_y + 26.0), Color(1.0, 0.85, 0.4), 160, 0.7, 6)
			if e.perfect:
				_perfect("BULLSEYE!", Color(1.0, 0.85, 0.4))
		"bloom":
			if e.strong:
				synth.play("jump", 0.7, -2.0)
				fx.burst(Vector2(sim.x, 0), Color(1.0, 0.4, 0.8), 30, 520, 0.6, 5, 300, PI * 0.7, -PI * 0.5)
				if e.perfect:
					_perfect("PERFECT BLOOM", Color(1.0, 0.45, 0.8))
		"clear":
			var o: Dictionary = e.o
			score += 25.0 * tw.tier()
			if e.perfect and o.t in [HURDLE, GAP, WIDE_GAP, BEAM]:
				_perfect("PERFECT", TrackView.AMBER if o.t == HURDLE else (TrackView.ROSE if o.t == BEAM else TrackView.CYAN))
			if o.t in [WIDE_GAP] and not e.perfect:
				_toast("nice glide", _kite_screen() + Vector2(0, -150), Color(0.6, 1, 1), 30)
		"bonk":
			_toast("oops! (Kind Mode)", _kite_screen() + Vector2(0, -150), Color(1, 0.8, 0.8), 30)
			kite.expr = "wow"
		"rescue":
			_start_rescue(e.o)
		"fail":
			_on_fail()

func _perfect(text: String, col: Color) -> void:
	note_capture_event("perfect")
	perfects_run += 1
	var up: bool = tw.perfect()
	score += 50.0 * tw.tier()
	synth.perfect_note(tw.tier())
	var sp = _kite_screen()
	_toast(text, sp + Vector2(0, -170), col, 46)
	fx.burst(Vector2(sim.x, sim.y - 50.0), col, 16, 360, 0.5, 4)
	kite.expr = "happy"
	if up:
		synth.play("tier", 1.0, -2.0)
		fx.ring(Vector2(sim.x, sim.y - 50.0), KiteView.TIER_COL[tw.tier() - 1], 220, 0.6, 8)
		_toast("TAILWIND x%d" % tw.tier(), sp + Vector2(0, -240), KiteView.TIER_COL[tw.tier() - 1], 60)
		if not save.data.settings.reduced_motion:
			slowmo_t = 0.22

# ------------------------------------------------------------------ frame update
func _process(delta: float) -> void:
	var real_dt = delta / maxf(Engine.time_scale, 0.01)
	_adapt_quality(real_dt)
	t += real_dt
	state_t += real_dt
	if state == "title" and not (garage_open or menu_dim or has_meta("keyart")):
		_plane_update(real_dt)
	_update_cursor_hover()
	if slowmo_t > 0.0:
		slowmo_t -= real_dt
		Engine.time_scale = 0.45 if slowmo_t > 0.0 else 1.0
	match state:
		"scenic":
			_update_scenic(real_dt)
		"title":
			zoom_target = 2.2 if garage_open else 1.3
			sim.x = title_x
			kite.pose = debug_pose if debug_pose != "" else "idle"
			kite.expr = debug_expr if debug_expr != "" else ("normal" if fmod(t, 6.0) < 5.0 else "happy")
			# title mini-game: Kavi waves and makes heart eyes when a plane reaches him
			if plane_happy_t > 0.0 and debug_pose == "" and not garage_open:
				kite.expr = "heart"
				if plane_happy_t > 0.8:
					kite.pose = "wave"
		"recovery":
			_update_recovery(real_dt)
		"junction":
			_update_junction(real_dt)
		"rescue":
			_update_rescue(real_dt)
		"finale":
			_update_finale(real_dt)
		"fail":
			_update_fail(real_dt)
	if pal_k < 1.0:
		pal_k = minf(pal_k + real_dt / 7.0, 1.0)
		pal = Art.blend_biome(pal_from, Art.biome(biome), pal_k)
	_update_hints(real_dt)
	_update_kite_view(real_dt)
	_update_camera(real_dt)
	_update_views(real_dt)
	for ts in toasts:
		ts.t += real_dt
		ts.pos.y -= real_dt * 40.0
	toasts = toasts.filter(func(ts): return ts.t < ts.life)
	caption_t = maxf(caption_t - real_dt, 0.0)
	hint_t = maxf(hint_t - real_dt, 0.0)
	if card.size() > 0:
		card.t += real_dt
		if card.t > card.life:
			card = {}
	fade = move_toward(fade, fade_target, real_dt * 4.0)
	lb = move_toward(lb, lb_target, real_dt * 1.8)
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-real_dt * 2.0))
	if capture_dir != "":
		_capture_tick(real_dt)
	if bench.size() > 0:
		_bench_tick(real_dt)

func _update_kite_view(dt: float) -> void:
	var p = Vector2(sim.x, sim.y)
	if kite_override:
		p = kite_pos
	else:
		var f = Engine.get_physics_interpolation_fraction()
		if state == "run":
			p = Vector2(lerpf(_prev_x, sim.x, f), lerpf(_prev_y, sim.y, f))
		if state == "recovery" or state == "junction" or state == "finale":
			_recovery_pose()
		elif state == "run":
			_run_pose()
		elif state == "fail":
			kite.pose = "fail"
		elif state == "tut_done":
			# The course has ended and the world is still: celebrate, don't run in place.
			kite.pose = "wave"
	kite.position = p
	if state == "run" or state == "paused":
		# Frozen (tutorial prompt) or paused: hold the pose; legs cycling while
		# the world stands still reads as moonwalking backwards.
		kite.speed = 0.0 if (sim.frozen or state == "paused") else sim.cur_speed()
	elif state == "scenic":
		kite.speed = SCENIC_SPEED
	elif debug_pose != "":
		kite.speed = debug_speed
	else:
		kite.speed = 120.0
	kite.limbs = str(save.data.settings.get("kavi_limbs2", "jointed"))
	kite.vy = sim.vy
	kite.grounded = sim.on_ground or state != "run"
	kite.tier = tw.tier()
	if _look_key == "":
		apply_look()
	kite.rim = pal.rim
	kite.tick(dt)

func _run_pose() -> void:
	if sim.throw_t > 0.0:
		kite.pose = "throw"
	elif sim.gust_t > 0.0:
		kite.pose = "gust"
	elif sim.sliding:
		kite.pose = "slide"
	elif not sim.on_ground:
		if sim.diving:
			kite.pose = "dive"
		elif sim.hovering:
			kite.pose = "hover"
		elif sim.vy < 0.0:
			kite.pose = "jump"
		else:
			kite.pose = "fall"
	else:
		kite.pose = "run"
	if kite.expr in ["happy", "wow", "focus", "dizzy"] and fmod(t, 1.4) < 0.02:
		kite.expr = "normal"
	if state_t < 0.05 and kite.expr == "dizzy":
		kite.expr = "focus"

func _recovery_pose() -> void:
	if state == "finale":
		var k = state_t
		kite.pose = "walk" if sim.x < finale.lx - 112.0 else ("front" if k < 5.0 else "front_wave")
		kite.expr = "wow" if k < 3.5 else "heart"
		return
	if state == "junction":
		kite.pose = "walk"
		kite.expr = "focus"
		return
	var k2 = state_t
	var d: float = activity.dur
	if k2 < 2.4 or k2 > d - 1.8:
		kite.pose = "walk"
		kite.expr = "calm"
	else:
		kite.pose = activity.pose
		kite.expr = "happy" if activity.npc != "" or activity.pose == "read" else "calm"

func _update_camera(dt: float) -> void:
	var size = get_viewport_rect().size
	var target = Vector2(sim.x + size.x * 0.2 / zoom, -300.0 / zoom + 300.0 - 300.0)
	if kite_override:
		target.x = kite_pos.x + size.x * 0.12
	var ky = kite_pos.y if kite_override else sim.y
	var follow_y = minf(ky + 220.0, 0.0) * 0.55
	target.y = -size.y * (0.80 - 0.5) / zoom + follow_y
	if state == "recovery" or state == "finale":
		target.x = sim.x + size.x * 0.1
		if state == "finale":
			target.x = (sim.x + finale.lx) * 0.5
	if state == "title" or state == "scenic":
		target.x = sim.x + size.x * 0.27 / zoom
	if state == "title" and garage_open:
		# close-up of Kavi on the left while the Garage list is on the right
		target.x = sim.x + size.x * 0.18 / zoom
		target.y += size.y * 0.16 / zoom
	cam_pos.x = target.x if cam_pos == Vector2.ZERO else lerpf(cam_pos.x, target.x, 1.0 - exp(-dt * 9.0))
	cam_pos.y = lerpf(cam_pos.y, target.y, 1.0 - exp(-dt * 4.0))
	shake = move_toward(shake, 0.0, dt * 30.0)
	var sh = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake if save.data.settings.shake else Vector2.ZERO
	cam.position = cam_pos + sh
	cam.zoom = Vector2(zoom, zoom)

func _update_views(dt: float) -> void:
	var size = get_viewport_rect().size
	var half = size * 0.5 / zoom
	world_view.pal = pal
	world_view.cam_x = cam.position.x
	world_view.cam_y = cam.position.y + size.y * (0.80 - 0.5) / zoom
	world_view.t = t
	world_view.hero_x = _kite_screen().x
	world_view.interactive = (state == "title" and not (garage_open or menu_dim)) or state == "scenic"
	world_view.sun_shift = -0.30 * get_viewport_rect().size.x if state == "title" else 0.0
	world_view.calm = move_toward(world_view.calm, 1.0 if state in ["recovery", "finale", "title", "scenic"] else 0.0, dt)
	world_view.refresh()
	track_view.pal = pal
	track_view.t = t
	track_view.view_l = cam.position.x - half.x
	track_view.view_r = cam.position.x + half.x
	for o in track.obs:
		if o.open:
			o.open_t += dt
		if o.x > track_view.view_r:
			break
	track_view.refresh()
	fx.tick(dt)
	# speed streaks at high tailwind
	if state == "run" and tw.tier() >= 3 and randf() < 0.5 * fx.density:
		var sp = cam.position + Vector2(half.x + 40.0, randf_range(-half.y, half.y * 0.6))
		fx.parts.append({"p": sp, "v": Vector2(-2200, 0), "l": 0.3, "m": 0.3, "s": 2.0, "c": Color(KiteView.TIER_COL[tw.tier() - 1], 0.5), "g": 0.0})
	if state == "run" and sim.sliding and randf() < 0.6:
		fx.burst(Vector2(sim.x - 10.0, -2), Color(1.0, 0.75, 0.35), 2, 260, 0.25, 2.5, 600, 0.8, PI + 0.4)
	if state == "run" and sim.hovering and randf() < 0.7:
		fx.burst(Vector2(sim.x - 22.0, sim.y - 36.0), KiteView.TIER_COL[tw.tier() - 1], 1, 200, 0.3, 3, 400, 0.5, PI * 0.5)
	cast_base.queue_redraw()
	cast_add.queue_redraw()
	fg.queue_redraw()
	hud.queue_redraw()
	touch.letters = sim.letters

func _update_hints(dt: float) -> void:
	if state != "run" or mode != "story" or track == null:
		return
	var i: int = track.first_index_after(sim.x)
	if i >= track.obs.size():
		return
	var o: Dictionary = track.obs[i]
	if o.x - sim.x > 1100.0 or o.t == RESCUE:
		return
	var key: String = Track.NAMES[o.t]
	if (save.data.seen_hints as Array).has(key):
		return
	(save.data.seen_hints as Array).append(key)
	save.save()
	hint = {
		"hurdle": "HOP  ·  press UP (Space)  —  hold for a higher jump. Jump late for PERFECT.",
		"beam": "SCOOT  ·  hold DOWN to slide under. Start late for PERFECT.",
		"gap": "Jump right at the edge of a gap for a PERFECT.",
		"wide_gap": "HOVER  ·  keep holding UP after a jump to glide on your thrusters.",
		"gate": "GUST  ·  press GUST (X) to blow the gate open. Closer = PERFECT.",
		"bell": "LETTER  ·  press LETTER (C): the paper plane rings the bell and drops the bridge.",
		"bloom": "DIVE  ·  jump, then press DOWN in the air to slam the bloom. It bounces you sky-high.",
	}.get(key, "")
	hint_t = 4.5

# ------------------------------------------------------------------ cast (NPCs, Lumi, bikers)
func _draw_cast(ci: Node2D, add: bool) -> void:
	if state == "recovery" and activity.get("npc", "") != "":
		Chars.npc(ci, Vector2(npc_x, 0), add, t, activity.npc, state_t > 2.0 and state_t < 4.0)
	if state == "rescue" and rescue.size() > 0:
		var r = rescue
		Chars.biker(ci, Vector2(r.bx, r.by), add, t, r.v, r.lean, 1.0 if state_t > 2.9 and state_t < 5.0 else 0.0)
	if state == "finale":
		var k = state_t
		Chars.lumi(ci, Vector2(finale.lx, 0), add, t, "heart" if k > 4.0 else ("happy" if k > 2.5 else "normal"), -1.0)
		if add and k > 4.0:
			for i in 6:
				var hp = Vector2(finale.lx - 60.0 + sin(t + i) * 50.0, -150.0 - fmod(t * 50.0 + i * 40.0, 220.0))
				KiteView._heart(ci, hp, 8.0, Art.hdr(Color(1.0, 0.5, 0.75, 0.8), 1.5))
	if state == "junction":
		var sx = sim.x + 520.0
		if add:
			_signpost(ci, sx)
		else:
			ci.draw_rect(Rect2(sx - 6, -240, 12, 240), pal.ground.lightened(0.08))

func _signpost(ci: Node2D, x: float) -> void:
	var up = Color(1.0, 0.55, 0.35)
	var dn = Color(0.45, 1.0, 0.75)
	var pulse = 0.7 + 0.3 * sin(t * 4.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x, -250), Vector2(x + 130, -250), Vector2(x + 160, -225), Vector2(x + 130, -200), Vector2(x, -200)]), Color(up, 0.35 * pulse))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x, -180), Vector2(x + 130, -180), Vector2(x + 160, -155), Vector2(x + 130, -130), Vector2(x, -130)]), Color(dn, 0.35 * pulse))

func _world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p

func _kite_screen() -> Vector2:
	return _world_to_screen(Vector2(sim.x, sim.y - 60.0))

func _toast(text: String, pos: Vector2, col: Color, size: int) -> void:
	toasts.append({"text": text, "pos": pos, "col": col, "size": size, "t": 0.0, "life": 1.1})

func _show_card(title: String, sub: String, delay := 0.4) -> void:
	card = {"title": title, "sub": sub, "t": -delay, "life": 3.4}

# ------------------------------------------------------------------ HUD
func _text(ci: Node2D, s: String, p: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0) -> void:
	var w = 2000.0
	var x = p.x - w * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else (p.x if align == HORIZONTAL_ALIGNMENT_LEFT else p.x - w)
	if outline > 0:
		ci.draw_string_outline(font, Vector2(x, p.y), s, align, w, size, outline, Color(0, 0, 0, col.a * 0.55))
	ci.draw_string(font, Vector2(x, p.y), s, align, w, size, col)

func _draw_hud(ci: Node2D) -> void:
	var sz = get_viewport_rect().size
	if has_meta("keyart"):
		_draw_logo(ci, Vector2(sz.x * 0.74, sz.y * 0.44), 10.0, 1.1)
		return
	# letterbox
	if lb > 0.001:
		var h = sz.y * 0.09 * ease(lb, 0.6)
		ci.draw_rect(Rect2(0, 0, sz.x, h), Color(0, 0, 0, 0.92))
		ci.draw_rect(Rect2(0, sz.y - h, sz.x, h), Color(0, 0, 0, 0.92))
	if state == "title":
		_draw_title(ci, sz)
	if state == "paused":
		# paused: no HUD, captions, cards or toasts; only the pause menu (UI layer)
		return
	if state in ["run", "fail", "recovery", "junction", "tut_done"]:
		_draw_run_hud(ci, sz)
	if state == "junction":
		_draw_junction_pressure(ci, sz)
	# toasts
	for ts in toasts:
		var a = 1.0 - pow(ts.t / ts.life, 3.0)
		var sc = 1.0 + (0.25 * (1.0 - minf(ts.t / 0.12, 1.0)))
		var col: Color = ts.col
		col.a = a
		_text(ci, ts.text, ts.pos, int(ts.size * sc), col, HORIZONTAL_ALIGNMENT_CENTER, 8)
	# caption (story text)
	if caption_t > 0.0 and caption != "":
		var a2 = minf(caption_t / 0.4, 1.0) * minf(1.0, 1.0)
		var y = sz.y - sz.y * 0.09 * lb - 40.0
		var tw_w = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		ci.draw_colored_polygon(Art.rrect(Rect2(sz.x * 0.5 - tw_w * 0.5 - 30, y - 50, tw_w + 60, 66), 33), Color(0.02, 0.03, 0.06, 0.6 * a2))
		_text(ci, caption, Vector2(sz.x * 0.5, y - 6), 34, Color(1, 0.97, 0.92, a2))
	if hint_t > 0.0 and hint != "":
		var a3 = minf(hint_t / 0.4, 1.0)
		var hw = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var hy = sz.y * 0.26
		ci.draw_colored_polygon(Art.rrect(Rect2(sz.x * 0.5 - hw * 0.5 - 34, hy - 44, hw + 68, 64), 30), Color(0.02, 0.05, 0.09, 0.66 * a3))
		ci.draw_polyline(Art.rrect(Rect2(sz.x * 0.5 - hw * 0.5 - 34, hy - 44, hw + 68, 64), 30), Color(0.4, 1, 1, 0.5 * a3), 2.0, Art.AA)
		_text(ci, hint, Vector2(sz.x * 0.5, hy), 34, Color(0.85, 1, 1, a3))
	# chapter card
	if card.size() > 0 and card.t > 0.0:
		var k: float = card.t
		var a4 = minf(k / 0.6, 1.0) * clampf((card.life - k) / 0.8, 0.0, 1.0)
		_text(ci, card.title, Vector2(sz.x * 0.5, sz.y * 0.40), 96, Color(1, 0.98, 0.92, a4), HORIZONTAL_ALIGNMENT_CENTER, 14)
		ci.draw_line(Vector2(sz.x * 0.5 - 220 * a4, sz.y * 0.43), Vector2(sz.x * 0.5 + 220 * a4, sz.y * 0.43), Color(pal.rim, a4 * 0.8), 2.0)
		_text(ci, card.sub, Vector2(sz.x * 0.5, sz.y * 0.48), 40, Color(pal.rim, a4), HORIZONTAL_ALIGNMENT_CENTER, 8)
	# recovery countdown
	if state == "recovery":
		var rem: float = activity.dur - state_t
		var c = Vector2(sz.x - 120, sz.y * 0.09 * lb + 230)
		ci.draw_arc(c, 40, -PI * 0.5, -PI * 0.5 + TAU * clampf(rem / activity.dur, 0, 1), 40, Color(1, 1, 1, 0.8), 5.0, Art.AA)
		_text(ci, str(int(ceil(rem))), c + Vector2(0, 14), 40, Color(1, 1, 1, 0.9))
		_text(ci, "breather", c + Vector2(0, 76), 24, Color(1, 1, 1, 0.6))
	if state == "finale" and state_t > 6.0:
		var a5 = minf((state_t - 6.0) / 1.5, 1.0)
		_text(ci, "If you wanted to, you would.", Vector2(sz.x * 0.5, sz.y * 0.28), 72, Color(1, 0.9, 0.95, a5), HORIZONTAL_ALIGNMENT_CENTER, 12)
	if mode == "tutorial" and tut != null and tut.waiting != "" and state == "run":
		var k = minf(tut.wait_t / 0.25, 1.0)
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.01, 0.03, 0.38 * k))
		var kp = _kite_screen()
		var pulse = 0.5 + 0.5 * sin(t * 6.0)
		ci.draw_arc(kp, 90.0 + pulse * 10.0, 0.0, TAU, 48, Color(0.6, 1.0, 0.95, 0.6 * k), 3.0, Art.AA)
		var py = sz.y * 0.30
		var sw = font.get_string_size(tut.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		var pw = maxf(sw, 420.0) + 90.0
		ci.draw_colored_polygon(Art.rrect(Rect2(sz.x * 0.5 - pw * 0.5, py - 96, pw, 170), 40), Color(0.02, 0.04, 0.08, 0.82 * k))
		ci.draw_polyline(Art.rrect(Rect2(sz.x * 0.5 - pw * 0.5, py - 96, pw, 170), 40), Color(0.6, 1.0, 0.95, 0.55 * k), 2.0, Art.AA)
		_text(ci, tut.title, Vector2(sz.x * 0.5, py - 10), 76, Color(0.75, 1.0, 0.95, k), HORIZONTAL_ALIGNMENT_CENTER, 8)
		_text(ci, tut.sub, Vector2(sz.x * 0.5, py + 46), 34, Color(1, 1, 1, 0.92 * k))
	if fade > 0.001:
		ci.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.01, 0.01, 0.03, fade))

func _draw_title(ci: Node2D, sz: Vector2) -> void:
	# soft darkening behind the menu column for readability (no box)
	var shade := Color(0.01, 0.02, 0.05)
	# back to the lighter 0.8.12 shade (owner: the darker one made the game feel
	# dark); readability now comes from drop shadows on the menu text instead
	ci.draw_polygon(PackedVector2Array([Vector2(sz.x * 0.52, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(sz.x * 0.52, sz.y)]),
		PackedColorArray([Color(shade, 0.0), Color(shade, 0.78 if menu_dim else 0.55), Color(shade, 0.78 if menu_dim else 0.55), Color(shade, 0.0)]))
	if garage_open or menu_dim:
		return
	_draw_motes(ci, sz)
	_draw_plane_game(ci)
	_draw_logo(ci, Vector2(sz.x * 0.29, sz.y * 0.25), state_t, 1.0)

## Title ambience (0.8.10): warm motes of light drifting up through the scene,
## twinkling, nudged a little by the mouse (parallax by depth).
func _draw_motes(ci: Node2D, sz: Vector2) -> void:
	var n: int = [14, 26, 40][Art.Q]
	var fade_in := clampf(state_t / 1.5, 0.0, 1.0)
	var m := (get_viewport().get_mouse_position() / sz - Vector2(0.5, 0.5))
	if DisplayServer.get_name().begins_with("headless"):
		m = Vector2.ZERO
	var warm: Color = pal.rim.lerp(Color(1.0, 0.9, 0.7), 0.5)
	for i in n:
		var h1 := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var h2 := fposmod(sin(i * 78.233) * 12543.123, 1.0)
		var h3 := fposmod(sin(i * 39.425) * 24634.634, 1.0)
		var depth := 0.35 + h3 * 0.65
		var spd := 18.0 + 30.0 * depth
		var y := fposmod(h2 * sz.y - t * spd, sz.y + 40.0) - 20.0
		var x := h1 * sz.x + sin(t * (0.4 + h3) + i) * 26.0 - m.x * 40.0 * depth
		y -= m.y * 24.0 * depth
		var tw := 0.55 + 0.45 * sin(t * (1.5 + h2 * 2.0) + i * 2.1)
		var r := (1.4 + 2.6 * depth)
		var a := fade_in * tw * (0.25 + 0.5 * depth) * smoothstep(0.0, 0.25, y / sz.y)
		ci.draw_circle(Vector2(x, y), r * 3.0, Color(warm, a * 0.05))
		ci.draw_circle(Vector2(x, y), r * 1.8, Color(warm, a * 0.12))
		ci.draw_circle(Vector2(x, y), r, Color(1.0, 0.97, 0.9, a))

## The logo lives in the world: cream letters with an ink outline and a thin
## rim of the country's light, letters rising in one by one, a letterspaced
## subtitle and a paper plane (Kavi's letters) gliding around it.
func _draw_logo(ci: Node2D, c: Vector2, time: float, scale_k: float) -> void:
	var fs := int(176 * scale_k)
	var gap := 10.0 * scale_k
	var cream := Color(1.0, 0.96, 0.90)
	var rim: Color = pal.rim
	var ink := Color(0.03, 0.04, 0.09)
	var letters := GAME_TITLE
	var widths: Array = []
	var total := 0.0
	for ch in letters:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w + gap
	total -= gap
	var x := c.x - total * 0.5
	# a sheen sweeps across the letters every few seconds (0.8.10)
	var sweep_k := fmod(maxf(time - 1.2, 0.0), 5.5) / 1.1
	var sweep_x := lerpf(c.x - total * 0.7, c.x + total * 0.7, sweep_k) if sweep_k < 1.0 else -99999.0
	var mouse := get_viewport().get_mouse_position()
	var live := not (has_meta("keyart") or DisplayServer.get_name().begins_with("headless"))
	for i in letters.length():
		var k := clampf((time - 0.25 - i * 0.12) / 0.55, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var bob := sin(t * 1.4 + i * 0.9) * 3.0 * scale_k
		var mid: float = x + widths[i] * 0.5
		# letters hop up when the mouse passes over them
		var near := 0.0
		if live:
			var d := Vector2((mouse.x - mid) / (widths[i] * 0.9), (mouse.y - (c.y - fs * 0.35)) / (fs * 0.8))
			near = clampf(1.0 - d.length(), 0.0, 1.0)
		var lift_i: float = logo_lift[i] if i < logo_lift.size() else 0.0
		lift_i = lerpf(lift_i, near, 0.18)
		if i < logo_lift.size():
			logo_lift[i] = lift_i
		var p := Vector2(x, c.y + (1.0 - e) * 26.0 + bob - lift_i * 22.0 * scale_k)
		var ch := letters[i]
		ci.draw_string_outline(font, Vector2(x, c.y + (1.0 - e) * 26.0 + bob) + Vector2(0, 6 + lift_i * 8.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 18, Color(0, 0, 0, 0.35 * e * (1.0 - lift_i * 0.4)))
		ci.draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(ink, e))
		ci.draw_string(font, p + Vector2(2.5, -2.5), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(rim.lightened(0.2), e))
		ci.draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(cream, e))
		var shine := exp(-pow((mid - sweep_x) / (widths[i] * 0.8), 2.0))
		var glow := maxf(shine, lift_i * 0.5) * e
		if glow > 0.02:
			ci.draw_string(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 1.0, 0.97, 0.75 * glow))
			ci.draw_string_outline(font, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(rim.lightened(0.5), 0.6 * glow))
		x += widths[i] + gap
	# subtitle: letterspaced small caps between two hairlines
	var sub := GAME_SUB.to_upper()
	var sfs := int(30 * scale_k)
	var sgap := 7.0 * scale_k
	var sw := 0.0
	for ch in sub:
		sw += font_body.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x + sgap
	var ks := clampf((time - 0.9) / 0.8, 0.0, 1.0)
	var sy := c.y + 62.0 * scale_k
	var sx := c.x - sw * 0.5
	for ch in sub:
		ci.draw_string(font_body, Vector2(sx, sy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(rim.lerp(cream, 0.35), ks))
		sx += font_body.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs).x + sgap
	var lw := 90.0 * scale_k * ks
	var ly := sy - 10.0 * scale_k
	ci.draw_line(Vector2(c.x - sw * 0.5 - 24 - lw, ly), Vector2(c.x - sw * 0.5 - 24, ly), Color(rim, 0.7 * ks), 2.0, true)
	ci.draw_line(Vector2(c.x + sw * 0.5 + 18, ly), Vector2(c.x + sw * 0.5 + 18 + lw, ly), Color(rim, 0.7 * ks), 2.0, true)
	# paper plane looping around the logo with a dotted trail
	var kp := clampf((time - 1.4) / 1.0, 0.0, 1.0)
	if kp > 0.0 and has_meta("keyart"):
		# an orbit around the whole logo, passing behind the subtitle
		var R := Vector2(total * 0.72, 150.0 * scale_k)
		var oc := c + Vector2(0, -30.0 * scale_k)
		for d in 9:
			var td: float = t - d * 0.09
			var q := oc + Vector2(cos(td * 0.5) * R.x, sin(td * 0.5) * R.y)
			ci.draw_circle(q, 2.4 * scale_k, Color(cream, kp * 0.5 * (1.0 - d / 9.0)))
		var q0 := oc + Vector2(cos(t * 0.5) * R.x, sin(t * 0.5) * R.y)
		var q1 := oc + Vector2(cos((t + 0.05) * 0.5) * R.x, sin((t + 0.05) * 0.5) * R.y)
		var dir := (q1 - q0).normalized()
		var nrm := dir.orthogonal()
		var L := 20.0 * scale_k
		ci.draw_colored_polygon(PackedVector2Array([q0 + dir * L, q0 - dir * L * 0.6 + nrm * L * 0.55, q0 - dir * L * 0.3]), Color(cream, kp))
		ci.draw_colored_polygon(PackedVector2Array([q0 + dir * L, q0 - dir * L * 0.3, q0 - dir * L * 0.6 - nrm * L * 0.35]), Color(cream.darkened(0.18), kp))

## Keyboard players see a hint bar at the bottom instead of touch buttons.
func _key_hints(ci: Node2D, sz: Vector2) -> void:
	var items := [["W / Up / Space", "Hop · hold to hover"], ["S / Down", "Scoot · dive in air"], ["X", "Gust"], ["C", "Letter"], ["Esc", "Pause"]]
	var fs := 24
	var widths := []
	var total := 0.0
	for it in items:
		var w: float = font.get_string_size(it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0 + font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 46.0
		widths.append(w)
		total += w
	var x := sz.x * 0.5 - total * 0.5
	var y: float = sz.y - 46.0 - sz.y * 0.09 * lb
	ci.draw_colored_polygon(Art.rrect(Rect2(x - 20, y - 30, total + 40, 52), 26), Color(0.02, 0.03, 0.07, 0.55))
	for i in items.size():
		var kw: float = font.get_string_size(items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20.0
		ci.draw_colored_polygon(Art.rrect(Rect2(x, y - 22, kw, 36), 9), Color(1, 1, 1, 0.16))
		ci.draw_string(font, Vector2(x + 10, y + 5), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
		ci.draw_string(font, Vector2(x + kw + 10, y + 5), items[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.7))
		x += widths[i]

func _draw_run_hud(ci: Node2D, sz: Vector2) -> void:
	var top = sz.y * 0.09 * lb + 26.0
	# tailwind badge
	var tier = tw.tier()
	var tc: Color = KiteView.TIER_COL[tier - 1]
	var c = Vector2(90, top + 64)
	ci.draw_circle(c, 52, Color(0.02, 0.04, 0.08, 0.55))
	ci.draw_arc(c, 52, -PI * 0.5, -PI * 0.5 + TAU * tw.progress(), 40, Art.hdr(tc, 1.0), 6.0, Art.AA)
	_text(ci, "x%d" % tier, c + Vector2(0, 16), 46, tc)
	_text(ci, "TAILWIND", c + Vector2(0, 82), 20, Color(tc, 0.8))
	if mode != "tutorial" and not save.data.settings.kind_mode:
		for i in MAX_HEARTS:
			KiteView._heart(ci, Vector2(184 + i * 40, top + 112), 15.0, Color(1.0, 0.45, 0.6, 0.95) if i < hearts else Color(1, 1, 1, 0.18))
	if input_mode == "keys" and state in ["run", "fail"] and not has_meta("clean_trailer"):
		_key_hints(ci, sz)
	# letters
	for i in 3:
		var lc = Color(1, 0.9, 0.6, 0.95 if i < sim.letters else 0.18)
		var lp = Vector2(180 + i * 34, top + 64)
		ci.draw_colored_polygon(PackedVector2Array([lp + Vector2(14, 0), lp + Vector2(-10, -9), lp + Vector2(-5, 0), lp + Vector2(-10, 9)]), lc)
	# progress / score
	if mode == "tutorial":
		_text(ci, "PRACTICE RUN", Vector2(sz.x * 0.5, top + 46), 34, Color(1, 1, 1, 0.85))
		var n: int = mini(tut.lessons, Tutorial.TOTAL_LESSONS)
		for i in Tutorial.TOTAL_LESSONS:
			var px = sz.x * 0.5 + (i - (Tutorial.TOTAL_LESSONS - 1) * 0.5) * 30.0
			ci.draw_circle(Vector2(px, top + 76), 7.0, Color(0.5, 1.0, 0.9, 0.95) if i < n else Color(1, 1, 1, 0.22))
	elif mode == "story":
		var w = sz.x * 0.36
		var x0 = sz.x * 0.5 - w * 0.5
		var prog = clampf((story_done_px + maxf(sim.x - _seg_start_estimate(), 0.0)) / maxf(story_total, 1.0), 0.0, 1.0)
		ci.draw_line(Vector2(x0, top + 40), Vector2(x0 + w, top + 40), Color(1, 1, 1, 0.25), 4.0, Art.AA)
		ci.draw_line(Vector2(x0, top + 40), Vector2(x0 + w * prog, top + 40), Art.hdr(Color(pal.rim, 0.95), 1.2), 4.0, Art.AA)
		ci.draw_circle(Vector2(x0 + w * prog, top + 40), 9, Color(0.3, 1, 1))
		KiteView._heart(ci, Vector2(x0 + w + 22, top + 38), 13.0, Color(1.0, 0.55, 0.8))
		var km = (story_total - story_done_px - maxf(sim.x - _seg_start_estimate(), 0.0)) / PX_PER_M / 1000.0
		_text(ci, "%.1f km to Lia  ·  %s" % [maxf(km, 0.0), pal.name], Vector2(sz.x * 0.5, top + 92), 28, Color(1, 1, 1, 0.75))
	else:
		_text(ci, str(int(score)), Vector2(sz.x * 0.5, top + 64), 60, Color(1, 0.98, 0.94), HORIZONTAL_ALIGNMENT_CENTER, 8)
		var key = "best_daily" if mode == "daily" else "best_endless"
		_text(ci, "best %d  ·  %s%s" % [int(save.data[key]), pal.name, "  ·  WILD x1.5" if route == "wild" else ""], Vector2(sz.x * 0.5, top + 100), 24, Color(1, 1, 1, 0.6))
	# stamps
	var sp = Vector2(sz.x - 200, top + 56)
	Art.glow(ci, sp, 22, Color(pal.mote, 0.6), 3)
	ci.draw_circle(sp, 8, pal.mote)
	_text(ci, str(stamps_run), sp + Vector2(24, 12), 36, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	# pause button
	var pb = Vector2(sz.x - 64, top + 50)
	ci.draw_circle(pb, 30, Color(0, 0, 0, 0.35))
	ci.draw_rect(Rect2(pb.x - 10, pb.y - 12, 7, 24), Color(1, 1, 1, 0.8))
	ci.draw_rect(Rect2(pb.x + 3, pb.y - 12, 7, 24), Color(1, 1, 1, 0.8))

var _seg_start = 0.0
func _seg_start_estimate() -> float:
	return seg_end - _story_params(chapter, stage, route).v * _story_params(chapter, stage, route).secs - 40.0

func pause_hit(p: Vector2) -> bool:
	var sz = get_viewport_rect().size
	var top = sz.y * 0.09 * lb + 26.0
	return p.distance_to(Vector2(sz.x - 64, top + 50)) < 50.0

func _want_touch() -> bool:
	return input_mode == "touch" and capture_dir == "" and bench.size() == 0

## Switch between touch buttons and keyboard hints by what the player uses.
func _set_input_mode(m: String) -> void:
	if m == input_mode:
		return
	input_mode = m
	if state in ["run", "fail"]:
		touch.visible_controls = _want_touch()

func _input(event: InputEvent) -> void:
	if state in ["title", "scenic"] and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hc0 := get_viewport().gui_get_hovered_control()
		if not (hc0 is BaseButton) and _sky_poke(event.position):
			get_viewport().set_input_as_handled()
			return
	if state == "title" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _plane_push(event.position):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenTouch and event.pressed:
		_set_input_mode("touch")
	elif (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed):
		_set_input_mode("keys")
	if state in ["run", "recovery", "junction"] and event is InputEventScreenTouch and event.pressed and pause_hit(event.position):
		toggle_pause()
		get_viewport().set_input_as_handled()
	if state == "junction" and _junction_input(event):
		get_viewport().set_input_as_handled()
		return
	# Mouse click on the pause button (desktop/web). Touch screens send an
	# emulated mouse click too; that one is skipped so a tap pauses only once.
	if state in ["run", "recovery", "junction"] and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION \
			and pause_hit(event.position):
		toggle_pause()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ menus glue (called by ui.gd)
## Scenic View: no obstacles, no HUD. Kavi just runs while the four countries
## roll past, one full cycle every ~2.5 minutes, then it loops.
func menu_scenic() -> void:
	synth.play("ui")
	state = "scenic"
	state_t = 0.0
	mode = "scenic"
	_new_world(0)
	set_biome(0, true)
	sim.frozen = true
	title_x = 0.0
	zoom_target = 1.2
	lb_target = 0.0
	touch.visible_controls = false
	scenic_next = SCENIC_STAY
	ui.show_scenic()
	synth.set_drive(0.25)
	_show_card(Art.biome(0).name, Art.biome(0).country, 0.6)

func _update_scenic(dt: float) -> void:
	title_x += dt * SCENIC_SPEED
	sim.x = title_x
	kite.pose = "run"
	kite.expr = "normal" if fmod(t, 7.0) < 5.5 else "happy"
	if state_t >= scenic_next:
		scenic_next += SCENIC_STAY
		var b: int = (biome + 1) % 4
		set_biome(b)
		_show_card(Art.biome(b).name, Art.biome(b).country, 1.5)

func menu_story() -> void:
	synth.play("ui")
	var ch := int(save.data.story_chapter)
	start_story(ch if (ch > 0 and not save.data.story_done) else 0)

func menu_story_restart() -> void:
	synth.play("ui")
	save.data.story_chapter = 0
	save.save()
	start_story(0)

func menu_endless() -> void:
	synth.play("ui")
	start_endless(false)

func menu_daily() -> void:
	synth.play("ui")
	start_endless(true)

func menu_retry() -> void:
	if mode == "tutorial":
		start_tutorial()
	elif mode == "story":
		start_story(chapter)
	else:
		start_endless(mode == "daily")

func watch_ad_for_spark() -> void:
	if not ads.can_show():
		return
	ui.show_ad_placeholder()
	ads.show_rewarded(self, func():
		save.data.sparks = int(save.data.sparks) + 1
		save.save()
		ui.show_title()
		_toast("+1 Spark", Vector2(get_viewport_rect().size.x * 0.5, 300), Color(1, 0.85, 0.4), 56))

# ------------------------------------------------------------------ capture director
func _setup_capture() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	autopilot = true
	save.data.seen_hints = []
	if "--scenic" in OS.get_cmdline_user_args():
		# Background review: two shots per country in Scenic View.
		save.data.tutorial_done = true
		cap_steps = [{"do": "scenic"}]
		for b in 4:
			if b > 0:
				cap_steps.append({"do": "scenic_next"})
			cap_steps.append_array([{"do": "wait", "s": 5.0}, {"shot": "scenic-%d-a" % b}, {"do": "wait", "s": 6.0}, {"shot": "scenic-%d-b" % b}])
		cap_steps.append({"do": "quit"})
		return
	if "--kavi" in OS.get_cmdline_user_args():
		# Character sheet: Kavi in close-up in each pose / expression.
		save.data.tutorial_done = true
		cap_steps = [{"do": "kavi_zoom"}, {"do": "wait", "s": 2.0}]
		var modes: Array = ["floating", "jointed"]
		for md in modes:
			cap_steps.append({"do": "limbs", "v": md})
			cap_steps.append_array([{"do": "kpose", "pose": "run", "speed": 600.0, "expr": ""}, {"do": "wait", "s": 0.8}])
			for fi in 8:
				cap_steps.append_array([{"do": "wait", "s": 0.035}, {"shot": "%s-run-%d" % [md, fi]}])
		cap_steps.append({"do": "limbs", "v": "floating"})
		for ps in [["idle", 0.0, "normal", "k0-idle"], ["idle", 0.0, "happy", "k1-happy"], ["run", 450.0, "", "k2-jog"],
				["run", 450.0, "", "k3-jog-b"], ["run", 900.0, "focus", "k4-sprint"], ["run", 900.0, "", "k5-sprint-b"],
				["jump", 0.0, "wow", "k6-jump"], ["hover", 0.0, "", "k7-hover"], ["slide", 0.0, "", "k8-scoot"],
				["wave", 0.0, "heart", "k9-wave"], ["fall", 0.0, "scared", "k10-fall"], ["gust", 0.0, "focus", "k11-gust"]]:
			cap_steps.append_array([{"do": "kpose", "pose": ps[0], "speed": ps[1], "expr": ps[2]}, {"do": "wait", "s": 0.55 if ps[0] == "run" else 1.0}, {"shot": ps[3]}])
		cap_steps.append({"do": "quit"})
		return
	if "--sky" in OS.get_cmdline_user_args():
		# Clickable sky/sea on the title, plus keyboard menu focus.
		save.data.tutorial_done = true
		cap_steps = [{"do": "wait", "s": 3.0}, {"shot": "s0-title"},
			{"do": "poke_kind", "kind": "balloon"}, {"do": "wait", "s": 0.45}, {"shot": "s1-balloon"},
			{"do": "poke_kind", "kind": "balloon"}, {"do": "poke_kind", "kind": "balloon"}, {"do": "wait", "s": 1.2}, {"shot": "s2-rocket"},
			{"do": "poke_kind", "kind": "ship"}, {"do": "wait", "s": 0.6}, {"shot": "s3-ship"},
			{"do": "poke_kind", "kind": "plane"}, {"do": "wait", "s": 1.6}, {"shot": "s4-plane-heart"}, {"do": "wait", "s": 1.5}, {"shot": "s5-plane-heart-b"},
			{"do": "unfocus"}]
		# focus Play, then down x4 to the Garage row, right to Settings, Enter
		for kk in [KEY_S, KEY_S, KEY_DOWN, KEY_S, KEY_S, KEY_D]:
			cap_steps.append_array([{"do": "key", "k": kk}, {"do": "wait", "s": 0.25}])
		cap_steps.append_array([{"do": "wait", "s": 0.3}, {"shot": "s6-keys"},
			{"do": "key", "k": KEY_ENTER}, {"do": "wait", "s": 1.0}, {"shot": "s7-enter"}, {"do": "quit"}])
		return
	if "--junction" in OS.get_cmdline_user_args():
		# Route choice countdown: calm, urgent, easy option.
		save.data.tutorial_done = true
		cap_steps = [{"do": "endless"}, {"do": "wait", "s": 3.0}, {"do": "force_junction"}, {"do": "wait", "s": 1.0}, {"shot": "j0-start"},
			{"do": "wait", "s": 3.1}, {"shot": "j1-urgent"}, {"do": "wait", "s": 1.4}, {"shot": "j2-easy"}, {"do": "wait", "s": 0.9}, {"shot": "j3-last"},
			{"do": "wait", "s": 1.5}, {"shot": "j4-after"}, {"do": "quit"}]
		return
	if "--plane" in OS.get_cmdline_user_args():
		# Title paper-plane mini-game: hint, steer to Kavi, orbit, over-click stall; quit dialog.
		save.data.tutorial_done = true
		cap_steps = [{"do": "wait", "s": 3.2}, {"shot": "p0-hint"}, {"do": "steer"}, {"do": "wait", "s": 0.25}, {"shot": "p1-delivered"},
			{"do": "wait", "s": 1.4}, {"shot": "p2-orbit"}, {"do": "wait", "s": 7.5}, {"do": "spam"}, {"do": "wait", "s": 0.15}, {"shot": "p3-stall"},
			{"do": "wait", "s": 0.5}, {"shot": "p4-fall"}, {"do": "quitmenu"}, {"do": "wait", "s": 1.0}, {"shot": "p5-quit"}]
		for k in 6:
			cap_steps.append_array([{"do": "wait", "s": 0.12}, {"shot": "p6-fly-%d" % k}])
		cap_steps.append({"do": "quit"})
		return
	if "--menus" in OS.get_cmdline_user_args():
		# Title + Garage review: the logo reveal, then try-ons of several items.
		save.data.tutorial_done = true
		save.data.sparks = 60
		cap_steps = [{"do": "wait", "s": 0.7}, {"shot": "m0-logo-reveal"}, {"do": "wait", "s": 3.0}, {"shot": "m1-title"},
			{"do": "garage", "cat": "scarf"}, {"do": "wait", "s": 1.5}, {"shot": "m2-garage"}]
		for tr in [["suit", 1, "m3-kitty"], ["suit", 2, "m4-explorer"], ["paint", 1, "m5-midnight"], ["scarf", 7, "m6-rainbow"], ["antenna", 1, "m7-star"], ["visor", 2, "m8-pink"]]:
			cap_steps.append_array([{"do": "garage", "cat": tr[0]}, {"do": "try", "cat": tr[0], "i": tr[1]}, {"do": "wait", "s": 1.2}, {"shot": tr[2]}])
		cap_steps.append_array([{"do": "settings"}, {"do": "wait", "s": 1.0}, {"shot": "m9-settings"},
			{"do": "confirm"}, {"do": "wait", "s": 1.0}, {"shot": "m10-confirm-tutorial"},
			{"do": "endless"}, {"do": "wait", "s": 4.0}, {"do": "pause"}, {"do": "wait", "s": 0.8}, {"shot": "m11-pause"},
			{"do": "resume"}, {"do": "end_run"}, {"do": "wait", "s": 1.0}, {"shot": "m12-results"}])
		cap_steps.append({"do": "quit"})
		return
	if "--transition" in OS.get_cmdline_user_args():
		# Filmstrip of a country change in Scenic View: one shot every 2 s.
		save.data.tutorial_done = true
		cap_steps = [{"do": "scenic"}, {"do": "wait", "s": 4.0}, {"do": "scenic_next"}]
		for k in 9:
			cap_steps.append_array([{"do": "wait", "s": 2.0}, {"shot": "tr-%02d" % k}])
		cap_steps.append({"do": "quit"})
		return
	if "--keyart" in OS.get_cmdline_user_args():
		# Key art for the loading screen / store banner: the reunion + logo.
		save.data.tutorial_done = true
		set_meta("keyart", true)
		cap_steps = [
			{"do": "story", "ch": 3}, {"do": "wait", "s": 1.0},
			{"do": "force_finale"}, {"do": "wait", "s": 7.5}, {"shot": "keyart"},
			{"do": "quit"},
		]
		return
	if "--trailer" in OS.get_cmdline_user_args():
		# ~19 s gameplay montage for store/portal preview videos (recorded with --write-movie).
		save.data.tutorial_done = true
		if "--trailer-long" in OS.get_cmdline_user_args():
			# ~63 s raw take for the YouTube trailer and Short (cut in ffmpeg).
			# No tutorial tips or key bar: the video adds its own captions.
			set_meta("clean_trailer", true)
			save.data.seen_hints = ["hurdle", "beam", "gap", "wide_gap", "gate", "bell", "bloom"]
			cap_steps = [
				{"do": "wait", "s": 3.5},
				{"do": "story", "ch": 0}, {"do": "wait", "s": 8.0},
				{"do": "story", "ch": 1}, {"do": "wait", "s": 9.0},
				{"do": "force_rescue"}, {"do": "wait", "s": 5.0},
				{"do": "story", "ch": 2}, {"do": "wait", "s": 8.0},
				{"do": "force_junction"}, {"do": "wait", "s": 3.0},
				{"do": "story", "ch": 3}, {"do": "wait", "s": 10.0},
				{"do": "endless"}, {"do": "wait", "s": 8.0},
				{"do": "force_finale"}, {"do": "wait", "s": 8.0},
				{"do": "quit"},
			]
			return
		cap_steps = [
			{"do": "story", "ch": 0}, {"do": "wait", "s": 3.6},
			{"do": "story", "ch": 1}, {"do": "wait", "s": 4.2},
			{"do": "force_rescue"}, {"do": "wait", "s": 3.6},
			{"do": "story", "ch": 2}, {"do": "wait", "s": 3.2},
			{"do": "force_finale"}, {"do": "wait", "s": 4.6},
			{"do": "quit"},
		]
		return
	cap_steps = [
		{"do": "wait", "s": 3.0}, {"shot": "01-title"},
		{"do": "scenic"}, {"do": "wait", "s": 5.0}, {"shot": "01d-scenic-greece"},
		{"do": "scenic_next"}, {"do": "wait", "s": 6.0}, {"shot": "01e-scenic-rhodope"},
		{"do": "scenic_next"}, {"do": "wait", "s": 6.0}, {"shot": "01f-scenic-danube"},
		{"do": "scenic_next"}, {"do": "wait", "s": 6.0}, {"shot": "01g-scenic-carpathian"},
		{"do": "tutorial"}, {"until": "tut_prompt", "max": 12.0}, {"do": "wait", "s": 0.4}, {"shot": "01a-tutorial-hop"},
		{"until_tut": 4, "max": 40.0}, {"until": "tut_prompt", "max": 20.0}, {"do": "wait", "s": 0.4}, {"shot": "01b-tutorial-hover"},
		{"until_state": "tut_done", "max": 90.0}, {"do": "wait", "s": 0.6}, {"shot": "01c-tutorial-done"},
		{"do": "story", "ch": 0}, {"do": "wait", "s": 2.2}, {"shot": "02-chapter-card"},
		{"until": "jump", "max": 8.0}, {"do": "wait", "s": 0.25}, {"shot": "03-hop"},
		{"until": "slide", "max": 12.0}, {"do": "wait", "s": 0.12}, {"shot": "04-scoot"},
		{"until": "perfect", "max": 20.0}, {"do": "wait", "s": 0.05}, {"shot": "05-perfect"},
		{"do": "story", "ch": 1}, {"until": "hover", "max": 30.0}, {"do": "wait", "s": 0.3}, {"shot": "06-hover-rhodope"},
		{"until": "gust", "max": 30.0}, {"do": "wait", "s": 0.08}, {"shot": "07-gust"},
		{"until": "bloom", "max": 30.0}, {"do": "wait", "s": 0.12}, {"shot": "08-bloom-bounce"},
		{"do": "force_rescue"}, {"do": "wait", "s": 0.55}, {"shot": "09-rescue-incoming"},
		{"do": "wait", "s": 0.9}, {"shot": "10-rescue-jump"}, {"do": "wait", "s": 1.6}, {"shot": "11-rescue-thanks"},
		{"until_state": "recovery", "max": 10.0}, {"do": "wait", "s": 4.0}, {"shot": "12-recovery"},
		{"do": "story", "ch": 2}, {"until": "letter", "max": 40.0}, {"do": "wait", "s": 0.35}, {"shot": "13-letter-danube"},
		{"do": "force_junction"}, {"do": "wait", "s": 1.2}, {"shot": "14-junction"},
		{"do": "story", "ch": 3}, {"do": "wait", "s": 9.0}, {"shot": "15-carpathian"},
		{"do": "force_finale"}, {"do": "wait", "s": 7.5}, {"shot": "16-finale"},
		{"do": "endless"}, {"do": "wait", "s": 14.0}, {"shot": "17-endless"},
		{"do": "end_run"}, {"do": "wait", "s": 0.6}, {"shot": "18-results"},
		{"do": "story", "ch": 0}, {"do": "wait", "s": 5.0}, {"do": "die"}, {"do": "wait", "s": 2.2}, {"do": "die"}, {"do": "wait", "s": 2.2}, {"shot": "19-one-heart-left"},
		{"do": "die"}, {"do": "wait", "s": 2.4}, {"shot": "20-out-of-hearts"},
		{"do": "quit"},
	]

## Benchmark: 3 s warm-up then 15 s of autopilot in chapter 2 (the densest
## forest). Frame time, GDScript draw-generation time, draw calls, primitives.
func _bench_tick(dt: float) -> void:
	bench.t += dt
	var script_ms: float = Painter.cost_usec / 1000.0
	Painter.cost_usec = 0
	if bench.t < 3.0:
		return
	bench.frames.append(dt * 1000.0)
	bench.script.append(script_ms)
	bench.draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	bench.prims.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if bench.t >= 18.0:
		var res := {}
		for k in ["frames", "script", "draws", "prims"]:
			var a: Array = bench[k].duplicate()
			a.sort()
			var sum := 0.0
			for v in a:
				sum += v
			res[k] = {"avg": snappedf(sum / a.size(), 0.01), "p95": snappedf(a[int(a.size() * 0.95)], 0.01)}
		res["n"] = bench.frames.size()
		res["quality"] = str(get_meta("quality_name", "baseline"))
		var f := FileAccess.open(bench.out, FileAccess.WRITE)
		f.store_string(JSON.stringify(res, "  "))
		f.close()
		print("bench: ", JSON.stringify(res))
		set_process(false)
		set_physics_process(false)
		get_tree().quit()

func _capture_tick(dt: float) -> void:
	if cap_i >= cap_steps.size():
		return
	var st: Dictionary = cap_steps[cap_i]
	cap_wait += dt
	if st.has("shot"):
		cap_i += 1
		cap_wait = 0.0
		_take_shot(st.shot)
		return
	if st.has("until"):
		if cap_events.has(st.until) or cap_wait > st.max:
			cap_events.clear()
			cap_i += 1
			cap_wait = 0.0
		return
	if st.has("until_tut"):
		if (tut != null and tut.lessons >= st.until_tut) or cap_wait > st.max:
			cap_events.clear()
			cap_i += 1
			cap_wait = 0.0
		return
	if st.has("until_state"):
		if state == st.until_state or cap_wait > st.max:
			cap_i += 1
			cap_wait = 0.0
		return
	match st.do:
		"poke_kind":
			# wait (up to 30 s) until one of these is on screen, then click its middle
			var found := false
			for list in [world_view._hits_air, world_view._hits_sea]:
				for h in list:
					var hr: Rect2 = h.rect
					if h.kind == st.kind and hr.position.x > 40.0 and hr.end.x < get_viewport_rect().size.x - 40.0:
						var ev := InputEventMouseButton.new()
						ev.button_index = MOUSE_BUTTON_LEFT
						ev.pressed = true
						ev.position = hr.get_center()
						ev.global_position = ev.position
						Input.parse_input_event(ev)
						found = true
						break
				if found:
					break
			if not found and cap_wait < 30.0:
				return
		"unfocus":
			get_viewport().gui_release_focus()
		"key":
			for pressed in [true, false]:
				var kev := InputEventKey.new()
				kev.keycode = st.k
				kev.physical_keycode = st.k
				kev.pressed = pressed
				Input.parse_input_event(kev)
		"steer":
			if not ((plane.size() > 0 and plane.state == "orbit") or cap_wait > 30.0):
				if plane.size() > 0 and plane.state == "fly" and fmod(cap_wait, 0.55) < dt:
					var away: Vector2 = (_plane_target() - plane.pos).normalized()
					_plane_push(plane.pos - away * 110.0)
				return
		"spam":
			if (plane.is_empty() or plane.state != "fly") and cap_wait < 15.0:
				return
			for k in 8:
				_plane_push(plane.pos + Vector2(0, -60))
		"quitmenu":
			ui.confirm_quit()
		"wait":
			if cap_wait >= st.s:
				cap_i += 1
				cap_wait = 0.0
			return
		"garage":
			ui.show_garage(st.cat)
		"kavi_zoom":
			garage_open = true
			ui.show_none()
		"limbs":
			save.data.settings.kavi_limbs2 = st.v
		"kpose":
			debug_pose = st.pose
			debug_speed = st.speed
			debug_expr = st.expr
		"settings":
			ui.show_settings()
		"confirm":
			ui.confirm_tutorial()
		"pause":
			toggle_pause()
		"resume":
			resume()
		"try":
			apply_look(st.cat, st.i)
		"scenic":
			menu_scenic()
		"scenic_next":
			scenic_next = state_t
		"story":
			start_story(st.ch)
			card = {}
		"force_rescue":
			var o = Track.make(RESCUE, sim.x + sim.v * 0.6, sim.v, RandomNumberGenerator.new())
			track.obs.insert(track.first_index_after(sim.x), o)
			_start_rescue(o)
		"die":
			if state == "run":
				sim.dead = true
				_on_fail()
		"tutorial":
			start_tutorial()
			card = {}
		"endless":
			start_endless(false)
			card = {}
		"end_run":
			_end_run()
		"force_junction":
			_enter_junction()
		"force_finale":
			chapter = 3
			_enter_finale()
		"quit":
			print("capture: %d shots -> %s" % [cap_shots.size(), capture_dir])
			set_process(false)
			set_physics_process(false)
			get_tree().quit()
			return
	cap_events.clear()
	cap_i += 1
	cap_wait = 0.0

func _take_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var path = capture_dir.path_join(name + ".png")
	img.save_png(path)
	cap_shots.append(path)

func note_capture_event(e: String) -> void:
	if capture_dir != "":
		cap_events[e] = true

# ------------------------------------------------------------------ title plane mini-game
const PLANE_REACH := 240.0     # clicks closer than this push the plane
const PLANE_CRUISE := 150.0
const PLANE_HEAT_MAX := 6.0    # this many quick clicks and it stalls

func _plane_spawn(first := false) -> void:
	var sz := get_viewport_rect().size
	var pos: Vector2
	var vel: Vector2
	if first:
		pos = Vector2(sz.x * 0.47, sz.y * 0.12)
		vel = Vector2(-1, 0.35).normalized() * PLANE_CRUISE
	else:
		match randi() % 3:
			0:
				pos = Vector2(-40, randf_range(0.12, 0.5) * sz.y)
				vel = Vector2(1, randf_range(-0.2, 0.3)).normalized() * PLANE_CRUISE * 1.4
			1:
				pos = Vector2(sz.x * randf_range(0.1, 0.5), -40)
				vel = Vector2(randf_range(-0.4, 0.6), 1).normalized() * PLANE_CRUISE * 1.4
			_:
				pos = Vector2(sz.x * 0.56, randf_range(0.1, 0.3) * sz.y)
				vel = Vector2(-1, randf_range(-0.1, 0.3)).normalized() * PLANE_CRUISE * 1.4
	plane = {"pos": pos, "vel": vel, "ang": vel.angle(), "state": "fly", "t": 0.0, "heat": 0.0,
		"wander": vel.angle(), "orbit_a": 0.0, "spin": 0.0, "wait": 0.0}
	plane_trail.clear()

func _plane_target() -> Vector2:
	return _world_to_screen(Vector2(sim.x, sim.y - 125.0))

func _plane_push(click: Vector2) -> bool:
	if plane.is_empty() or plane.state != "fly" or garage_open or menu_dim:
		return false
	var hc := get_viewport().gui_get_hovered_control()
	if hc is BaseButton:
		return false
	var d: Vector2 = plane.pos - click
	var dist := d.length()
	if dist > PLANE_REACH:
		return false
	var dir := d.normalized() if dist > 1.0 else Vector2.UP
	var strength := lerpf(430.0, 170.0, dist / PLANE_REACH)
	plane.vel += dir * strength
	plane.heat += 1.0
	plane_hint = false
	plane_fx.append({"kind": "ring", "p": click, "t": 0.0, "life": 0.35})
	synth.play("hover", 1.3 + randf() * 0.3, -6.0)
	if plane.heat > PLANE_HEAT_MAX:
		plane.state = "stall"
		plane.spin = (1.0 if plane.vel.x >= 0.0 else -1.0) * 7.0
		var vs := get_viewport_rect().size
		_toast("Whoa, too many pushes!", Vector2(clampf(plane.pos.x, 230.0, vs.x - 230.0), clampf(plane.pos.y - 50.0, 60.0, vs.y - 60.0)), Color(1, 0.8, 0.6), 30)
		synth.play("dive", 0.8)
	return true

func _plane_update(dt: float) -> void:
	if plane.is_empty():
		if state_t > 1.4:
			_plane_spawn(true)
		return
	var sz := get_viewport_rect().size
	plane.t += dt
	plane.heat = maxf(plane.heat - dt * 1.3, 0.0)
	plane_happy_t = maxf(plane_happy_t - dt, 0.0)
	match plane.state:
		"fly":
			# gentle wandering cruise; pushes decay back into it
			plane.wander += sin(t * 0.7 + plane.t * 0.3) * dt * 0.9
			var c := Vector2(sz.x * 0.38, sz.y * 0.36)
			var p: Vector2 = plane.pos
			var edge := 0.0
			if p.x < 80 or p.x > sz.x * 0.58 or p.y < 70 or p.y > sz.y * 0.72:
				edge = 1.0
			var wish := Vector2.from_angle(plane.wander)
			if edge > 0.0:
				wish = wish.lerp((c - p).normalized(), 0.08).normalized()
				plane.wander = lerp_angle(plane.wander, (c - p).angle(), dt * 1.5)
			plane.vel = plane.vel.lerp(wish * PLANE_CRUISE, 1.0 - exp(-dt * 0.9))
			plane.vel.y += sin(t * 2.3 + plane.t) * 18.0 * dt
			plane.pos += plane.vel * dt
			# soft walls
			if plane.pos.x < 20.0 or plane.pos.x > sz.x - 20.0:
				plane.vel.x *= -0.6
				plane.pos.x = clampf(plane.pos.x, 20.0, sz.x - 20.0)
			if plane.pos.y < 20.0 or plane.pos.y > sz.y * 0.8:
				plane.vel.y *= -0.6
				plane.pos.y = clampf(plane.pos.y, 20.0, sz.y * 0.8)
			plane.ang = lerp_angle(plane.ang, plane.vel.angle(), 1.0 - exp(-dt * 8.0))
			# the paper plane bumps into balloons and birds on its way
			var bump: String = world_view.poke(plane.pos, true)
			if bump != "":
				_sky_react(bump, plane.pos, true)
			# delivered: it reached Kavi
			var tg := _plane_target()
			if plane.pos.distance_to(tg) < 95.0:
				plane.state = "orbit"
				plane.t = 0.0
				plane.orbit_a = (plane.pos - tg).angle()
				plane_delivered += 1
				plane_happy_t = 3.0
				synth.play("letter")
				synth.play("bell", 1.5, -4.0)
				_toast("Letter delivered!", tg + Vector2(0, -110), Color(1, 0.9, 0.6), 38)
				for i in 18:
					var a := TAU * i / 18.0
					plane_fx.append({"kind": "spark", "p": tg, "v": Vector2.from_angle(a) * randf_range(120, 260), "t": 0.0, "life": 0.8})
		"orbit":
			var tg2 := _plane_target()
			plane.orbit_a += dt * 2.8
			var r := Vector2(105.0, 60.0)
			var np := tg2 + Vector2(cos(plane.orbit_a) * r.x, sin(plane.orbit_a) * r.y)
			plane.vel = (np - plane.pos) / maxf(dt, 0.001)
			plane.pos = np
			plane.ang = lerp_angle(plane.ang, plane.vel.angle(), 1.0 - exp(-dt * 12.0))
			if plane.t > 7.0:
				plane.state = "leave"
				plane.vel = Vector2(260, -380)
		"leave":
			plane.vel = plane.vel * (1.0 + dt * 0.5)
			plane.pos += plane.vel * dt
			plane.ang = lerp_angle(plane.ang, plane.vel.angle(), 1.0 - exp(-dt * 6.0))
			if plane.pos.y < -60 or plane.pos.x > sz.x + 60:
				plane.state = "gone"
				plane.wait = 1.0
		"stall":
			plane.vel.y += 900.0 * dt
			plane.vel.x *= 1.0 - dt * 0.6
			plane.pos += plane.vel * dt
			plane.ang += plane.spin * dt
			if randf() < dt * 14.0:
				plane_fx.append({"kind": "puff", "p": plane.pos, "v": Vector2(randf_range(-20, 20), -30), "t": 0.0, "life": 0.7})
			if plane.pos.y > sz.y + 60:
				plane.state = "gone"
				plane.wait = 1.5
		"gone":
			plane.wait -= dt
			if plane.wait <= 0.0:
				_plane_spawn()
	if plane.state in ["fly", "orbit", "leave"]:
		plane_trail.push_front(plane.pos)
		if plane_trail.size() > 14:
			plane_trail.pop_back()
	elif plane_trail.size() > 0:
		plane_trail.pop_back()
	for f in plane_fx:
		f.t += dt
		if f.has("v"):
			f.p += f.v * dt
			f.v *= 1.0 - dt * 2.5
	plane_fx = plane_fx.filter(func(f): return f.t < f.life)

func _draw_plane_game(ci: Node2D) -> void:
	if plane.is_empty():
		return
	var cream := Color(1.0, 0.96, 0.90)
	var appear := clampf(state_t / 1.5, 0.0, 1.0)
	for i in plane_trail.size():
		if i % 2 == 1:
			continue
		ci.draw_circle(plane_trail[i], 2.6, Color(cream, appear * 0.5 * (1.0 - float(i) / plane_trail.size())))
	for f in plane_fx:
		var k: float = f.t / f.life
		match f.kind:
			"ring":
				ci.draw_arc(f.p, 18.0 + 40.0 * k, 0.0, TAU, 32, Color(1, 0.92, 0.75, 0.6 * (1.0 - k)), 3.0, true)
			"spark":
				ci.draw_circle(f.p, 4.0 * (1.0 - k) + 1.0, Color(1.0, 0.85 - 0.3 * k, 0.5, 1.0 - k))
			"puff":
				ci.draw_circle(f.p, 6.0 + 14.0 * k, Color(0.85, 0.85, 0.9, 0.35 * (1.0 - k)))
	if plane.state == "gone":
		return
	var q0: Vector2 = plane.pos
	var dir := Vector2.from_angle(plane.ang)
	var nrm := dir.orthogonal()
	var L := 26.0
	# warning wobble when the plane is getting overheated by clicks
	var heat_k := clampf((plane.heat - 3.0) / (PLANE_HEAT_MAX - 3.0), 0.0, 1.0) if plane.state == "fly" else 0.0
	if heat_k > 0.0:
		q0 += Vector2(sin(t * 40.0), cos(t * 37.0)) * 3.0 * heat_k
	var body := cream.lerp(Color(1.0, 0.62, 0.5), heat_k * 0.6)
	ci.draw_colored_polygon(PackedVector2Array([q0 + dir * L + Vector2(0, 5), q0 - dir * L * 0.6 + nrm * L * 0.55 + Vector2(0, 5), q0 - dir * L * 0.3 + Vector2(0, 5)]), Color(0, 0, 0, 0.18 * appear))
	ci.draw_colored_polygon(PackedVector2Array([q0 + dir * L, q0 - dir * L * 0.6 + nrm * L * 0.55, q0 - dir * L * 0.3]), Color(body, appear))
	ci.draw_colored_polygon(PackedVector2Array([q0 + dir * L, q0 - dir * L * 0.3, q0 - dir * L * 0.6 - nrm * L * 0.35]), Color(body.darkened(0.18), appear))
	ci.draw_polyline(PackedVector2Array([q0 + dir * L, q0 - dir * L * 0.6 + nrm * L * 0.55, q0 - dir * L * 0.3, q0 - dir * L * 0.6 - nrm * L * 0.35, q0 + dir * L]), Color(0.03, 0.04, 0.09, 0.55 * appear), 1.6, true)
	# first-time hint
	if plane_hint and plane.state == "fly" and state_t > 2.5:
		var ha := clampf((state_t - 2.5) / 0.6, 0.0, 1.0) * (0.75 + 0.25 * sin(t * 3.0))
		var hsz := get_viewport_rect().size
		_text(ci, "Tip: click near the paper plane to steer it to %s" % HERO, Vector2(hsz.x * 0.29, hsz.y * 0.25 + 120.0), 26, Color(1, 0.95, 0.85, ha * appear), HORIZONTAL_ALIGNMENT_CENTER, 6)
	if plane_delivered > 0:
		var sz := get_viewport_rect().size
		_text(ci, "Letters delivered: %d" % plane_delivered, Vector2(sz.x * 0.29, sz.y * 0.25 + 120.0), 26, Color(1, 0.9, 0.7, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 6)

## Route choice keys: Up = wild, Down = scenic. Once the easy option shows,
## any key, click or tap (except on the wild route or the pause button) picks it.
func _junction_input(event: InputEvent) -> bool:
	var d := _key_dir(event)
	if d < 0:
		choose_route("wild")
		return true
	if d > 0:
		choose_route("scenic")
		return true
	if not junction_easy:
		return false
	var press := false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_ESCAPE:
		press = true
	elif event is InputEventJoypadButton and event.pressed and event.button_index != JOY_BUTTON_START:
		press = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if pause_hit(event.position):
			return false
		var hc := get_viewport().gui_get_hovered_control()
		if hc != null and is_instance_valid(ui.junction_wild) and (hc == ui.junction_wild):
			return false
		press = true
	if press:
		choose_route("scenic")
	return press

## Last seconds of the route choice: the screen edges throb red with each tick.
func _draw_junction_pressure(ci: Node2D, sz: Vector2) -> void:
	var rem := JUNCTION_TIME - junction_t
	var urgent := clampf((3.5 - rem) / 3.5, 0.0, 1.0)
	if urgent <= 0.0 or save.data.settings.reduced_motion:
		return
	var beat := exp(-(1.0 - fmod(maxf(rem, 0.0), 1.0)) * 5.0)
	var a := urgent * (0.18 + 0.32 * beat)
	var red := Color(0.85, 0.08, 0.06)
	var e := 150.0 + 60.0 * beat
	var c0 := Color(red, a)
	var c1 := Color(red, 0.0)
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, e), Vector2(0, e)]), PackedColorArray([c0, c0, c1, c1]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, sz.y - e), Vector2(sz.x, sz.y - e), Vector2(sz.x, sz.y), Vector2(0, sz.y)]), PackedColorArray([c1, c1, c0, c0]))
	ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, 0), Vector2(e, sz.y), Vector2(0, sz.y)]), PackedColorArray([c0, c1, c1, c0]))
	ci.draw_polygon(PackedVector2Array([Vector2(sz.x - e, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(sz.x - e, sz.y)]), PackedColorArray([c1, c0, c0, c1]))

# ------------------------------------------------------------------ sky toys + cursor (0.8.13)
func _sky_poke(pos: Vector2) -> bool:
	var kind: String = world_view.poke(pos)
	if kind == "":
		return false
	_sky_react(kind, pos, false)
	return true

## Sounds and a little speech pop for each thing in the sky or on the sea.
func _sky_react(kind: String, pos: Vector2, quiet: bool) -> void:
	var vol := -8.0 if quiet else 0.0
	match kind:
		"balloon":
			synth.play("mote", 0.9 + randf() * 0.2, vol)
			if not quiet:
				_toast(["Hello!", "Hi there!", "Wheee", "Ahoy!"][randi() % 4], pos + Vector2(0, -70), Color(1, 0.9, 0.95), 28)
		"balloon_rocket":
			synth.play("whoosh", 0.9, vol)
			synth.play("jump", 0.7, vol)
			_toast("Wheeeee!", pos + Vector2(0, -80), Color(1, 0.85, 0.6), 36)
		"plane":
			synth.play("letter", 0.8, vol)
			_toast("Sending love!", pos + Vector2(0, 60), Color(1, 0.75, 0.85), 26)
		"ship":
			synth.play("toot", 1.0, vol)
			if not quiet:
				_toast("Toot toot!", pos + Vector2(0, -60), Color(0.85, 0.95, 1.0), 28)
		"birds":
			for k in 3:
				synth.play("tweet", 0.9 + k * 0.15 + randf() * 0.1, vol - 3.0)
			if not quiet:
				_toast("Tweet!", pos + Vector2(0, -50), Color(1, 1, 0.9), 26)

var _cursor_hand := false

func _setup_cursor() -> void:
	if OS.has_feature("mobile"):
		return
	var arrow: Texture2D = load("res://assets/cursor/arrow.png")
	var point: Texture2D = load("res://assets/cursor/point.png")
	if arrow == null or point == null:
		return
	Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, Vector2(3, 3))
	Input.set_custom_mouse_cursor(point, Input.CURSOR_POINTING_HAND, Vector2(3, 3))

## Over something clickable in the scene (sky toys, the paper plane) the
## cursor shows the glowing pointer, like it does over menu items.
func _update_cursor_hover() -> void:
	var want := false
	if state in ["title", "scenic"] and not (garage_open or menu_dim):
		var m := get_viewport().get_mouse_position()
		if world_view.hover_hit(m):
			want = true
		elif state == "title" and not plane.is_empty() and plane.state == "fly" and m.distance_to(plane.pos) < 70.0:
			want = true
	if want != _cursor_hand:
		_cursor_hand = want
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if want else Input.CURSOR_ARROW)
