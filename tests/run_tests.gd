extends SceneTree
## Headless test suite. Run: tools/test.sh
## Refuses to run unless user data is redirected to an isolated directory.

const Track = preload("res://scripts/track.gd")
const Sim = preload("res://scripts/sim.gd")
const Tailwind = preload("res://scripts/tailwind.gd")
const Save = preload("res://scripts/save.gd")
const Tutorial = preload("res://scripts/tutorial.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	var data_dir := OS.get_user_data_dir()
	if not OS.has_environment("VOLT_TEST_ISOLATED") or not data_dir.begins_with(OS.get_environment("VOLT_TEST_ISOLATED")):
		push_error("Refusing to run: user data dir is not isolated (%s)" % data_dir)
		quit(2)
		return
	test_fairness()
	test_unfair_detected()
	test_smooth_start()
	test_tutorial()
	test_verbs()
	test_tailwind()
	test_save_roundtrip()
	print("checks: %d  failures: %d" % [checks, failures])
	quit(1 if failures > 0 or checks < 100 else 0)

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("FAIL: ", msg)

func all_types() -> Array:
	return [Track.HURDLE, Track.BEAM, Track.GAP, Track.WIDE_GAP, Track.GATE, Track.BELL, Track.BLOOM]

## The bot must clear every generated segment end to end on the real sim.
func test_fairness() -> void:
	var total := 0
	var fixes := 0
	var drops := 0
	for seed_i in 160:
		var tr = Track.new()
		var sp := 520.0 + float(seed_i % 8) * 60.0
		var diff := float(seed_i % 5) / 4.0
		var end: float = tr.gen_segment(0.0, 35.0, sp, diff, all_types(), seed_i * 7919 + 13, seed_i % 3 == 0, true)
		var fail_i: int = tr.bot_run(tr.obs, 0.0, end, sp)
		check(fail_i < 0, "seed %d sp %.0f diff %.2f: bot failed at obstacle %d (%s)" % [seed_i, sp, diff, fail_i,
			Track.NAMES[tr.obs[fail_i].t] if fail_i >= 0 else ""])
		total += tr.obs.size()
		fixes += tr.validation_fixes
		drops += tr.validation_drops
	check(total > 160 * 12, "generator produces enough obstacles (%d)" % total)
	print("fairness: %d obstacles, %d spacing fixes, %d drops" % [total, fixes, drops])

## A deliberately impossible layout must be caught by the validator.
## Every stretch starts with ~3 s of free running, and the first quarter is
## sparser than the last (the ramp gets harder).
func test_smooth_start() -> void:
	var early := 0
	var late := 0
	for seed_i in 40:
		var tr = Track.new()
		var sp := 560.0
		tr.gen_segment(0.0, 55.0, sp, 0.8, all_types(), seed_i * 31 + 5, false, true)
		check(tr.obs.size() > 0 and tr.obs[0].x >= sp * 2.9, "seed %d: first obstacle after the lead-in (%.0f px)" % [seed_i, tr.obs[0].x if tr.obs.size() > 0 else -1.0])
		for o in tr.obs:
			if o.x < sp * 55.0 * 0.25: early += 1
			elif o.x > sp * 55.0 * 0.75: late += 1
	check(late > early * 1.3, "difficulty ramps up within a stretch (early %d, late %d)" % [early, late])

## The tutorial course is clearable, every lesson prompts, and a player who
## does each prompted move (autopilot) finishes without failing.
func test_tutorial() -> void:
	var tr = Track.new()
	var end: float = Tutorial.build(tr)
	check(tr.bot_run(tr.obs.duplicate(true), 0.0, end, Tutorial.SPEED) < 0, "tutorial course is clearable")
	var tu = Tutorial.new()
	var s = Sim.new()
	s.track = tr
	s.v = Tutorial.SPEED
	var none := {"jump_pressed": false, "jump_held": false, "down_pressed": false, "down_held": false, "gust_pressed": false, "letter_pressed": false}
	var frozen_ticks := 0
	for i in 120 * 120:
		var f = tu.filter(none, s, 1.0 / 120.0, true)
		if f == null:
			frozen_ticks += 1
			continue
		s.step(1.0 / 120.0, f)
		if s.dead or s.x > end:
			break
	check(not s.dead and s.x > end, "autopilot finishes the tutorial (dead=%s x=%.0f end=%.0f)" % [s.dead, s.x, end])
	check(tu.lessons >= Tutorial.TOTAL_LESSONS, "all lessons prompted (%d of %d)" % [tu.lessons, Tutorial.TOTAL_LESSONS])
	check(frozen_ticks > 0, "game freezes on prompts")
	# A player who ignores a prompt never moves on: the game waits for them.
	var tu2 = Tutorial.new()
	var s2 = Sim.new()
	s2.track = tr
	s2.v = Tutorial.SPEED
	for i in 120 * 10:
		var f2 = tu2.filter(none, s2, 1.0 / 120.0, false)
		if f2 != null:
			s2.step(1.0 / 120.0, f2)
	check(not s2.dead and tu2.waiting == "jump", "first prompt waits for HOP (waiting=%s)" % tu2.waiting)

func test_unfair_detected() -> void:
	var tr = Track.new()
	var rng := RandomNumberGenerator.new()
	var a := Track.make(Track.HURDLE, 600.0, 520.0, rng)
	var b := Track.make(Track.BEAM, 600.0 + a.w + 5.0, 520.0, rng) # beam right on top of the hurdle exit
	var w := Track.make(Track.GAP, 1400.0, 520.0, rng)
	w.w = 520.0 * 1.6 # too wide even with hover
	var placed := [a, b, w]
	check(tr.bot_run(placed, 0.0, 3000.0, 520.0) >= 0, "impossible layout is detected")

func run_scripted(tr, sp: float, script: Callable, secs: float):
	var s = Sim.new()
	s.track = tr
	s.v = sp
	for i in int(secs * 120.0):
		s.step(1.0 / 120.0, script.call(s))
		if s.dead:
			break
	return s

func test_verbs() -> void:
	var rng := RandomNumberGenerator.new()
	var none := func(_s): return {"jump_pressed": false, "jump_held": false, "down_pressed": false, "down_held": false, "gust_pressed": false, "letter_pressed": false}
	# Running into a hurdle without input fails.
	var tr = Track.new()
	tr.obs = [Track.make(Track.HURDLE, 500.0, 520.0, rng)]
	var s = run_scripted(tr, 520.0, none, 2.0)
	check(s.dead and s.fail_reason == "hurdle", "idle run hits hurdle")
	# Tap vs hold: held jump goes higher.
	var tr2 = Track.new()
	var peak_hold := 0.0
	var peak_tap := 0.0
	for mode in 2:
		var ss = Sim.new()
		ss.track = tr2
		var peak := 0.0
		for i in 120:
			var held: bool = mode == 0 or i < 4
			ss.step(1.0 / 120.0, {"jump_pressed": i == 0, "jump_held": held, "down_pressed": false, "down_held": false, "gust_pressed": false, "letter_pressed": false})
			peak = minf(peak, ss.y)
		if mode == 0: peak_hold = -peak
		else: peak_tap = -peak
	check(peak_hold > 170.0 and peak_tap < peak_hold * 0.6, "variable jump height (hold %.0f, tap %.0f)" % [peak_hold, peak_tap])
	# Wide gap needs hover; plain hop falls.
	var tr3 = Track.new()
	var g := Track.make(Track.WIDE_GAP, 400.0, 520.0, rng)
	tr3.obs = [g]
	var tap_at_edge := func(s2):
		var d: float = g.x - (s2.x + Sim.HALF_W)
		return {"jump_pressed": s2.on_ground and d <= 2.0, "jump_held": not s2.on_ground and s2.vy < 0, "down_pressed": false, "down_held": false, "gust_pressed": false, "letter_pressed": false}
	s = run_scripted(tr3, 520.0, tap_at_edge, 3.0)
	check(s.dead and s.fail_reason == "fall", "wide gap without hover falls")
	g.passed = false
	var hover_edge := func(s2):
		var d: float = g.x - (s2.x + Sim.HALF_W)
		return {"jump_pressed": s2.on_ground and d <= 2.0, "jump_held": true, "down_pressed": false, "down_held": false, "gust_pressed": false, "letter_pressed": false}
	s = run_scripted(tr3, 520.0, hover_edge, 3.0)
	check(not s.dead, "wide gap with hover is crossed")
	# Gate blocks until gusted.
	var tr4 = Track.new()
	tr4.obs = [Track.make(Track.GATE, 600.0, 520.0, rng)]
	s = run_scripted(tr4, 520.0, none, 2.0)
	check(s.dead, "closed gate blocks")
	# Bloom wall needs a dive bounce.
	var tr5 = Track.new()
	tr5.obs = [Track.make(Track.BLOOM, 800.0, 520.0, rng)]
	var plain_jump := func(s2):
		var d: float = tr5.obs[0].wall_x - (s2.x + Sim.HALF_W)
		return {"jump_pressed": s2.on_ground and d < 90.0, "jump_held": true, "down_pressed": false, "down_held": false, "gust_pressed": false, "letter_pressed": false}
	s = run_scripted(tr5, 520.0, plain_jump, 3.0)
	check(s.dead, "bloom wall cannot be hopped")
	# Bot dive onto the bloom: exactly one strong bounce, no re-slam loop.
	var tr7 = Track.new()
	tr7.obs = [Track.make(Track.BLOOM, 800.0, 520.0, rng)]
	var s7 = Sim.new()
	s7.track = tr7
	var strong_bounces := 0
	for i in 400:
		s7.step(1.0 / 120.0, Track.bot_input(s7))
		for e in s7.events:
			if e.type == "bloom" and e.strong:
				strong_bounces += 1
	check(not s7.dead and strong_bounces == 1, "bloom bounces once (got %d)" % strong_bounces)
	# Kind mode never fails.
	var tr6 = Track.new()
	tr6.gen_segment(0.0, 20.0, 520.0, 1.0, all_types(), 99, false, true)
	var ks = Sim.new()
	ks.track = tr6
	ks.kind_mode = true
	for i in 20 * 120:
		ks.step(1.0 / 120.0, none.call(ks))
	check(not ks.dead, "kind mode never fails")

func test_tailwind() -> void:
	var tw = Tailwind.new()
	check(tw.tier() == 1, "starts at x1")
	for i in 3: tw.perfect()
	check(tw.tier() == 2, "3 perfects -> x2")
	for i in 5: tw.perfect()
	check(tw.tier() == 3, "8 perfects -> x3")
	for i in 7: tw.perfect()
	check(tw.tier() == 4, "15 perfects -> x4")
	tw.mistake()
	check(tw.tier() == 3, "mistake drops one tier, not a reset")
	tw.mistake(); tw.mistake(); tw.mistake()
	check(tw.tier() == 1, "floor is x1")

func test_save_roundtrip() -> void:
	var sv = Save.new()
	sv.data.best_endless = 1234
	sv.save()
	var sv2 = Save.new()
	sv2.load_data()
	check(sv2.data.best_endless == 1234, "save roundtrip in isolated dir")
