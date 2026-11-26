extends RefCounted
## Interactive tutorial ("learn by doing"). A short hand-built practice course.
## The solver bot knows the exact moment each move works; at that moment the
## game freezes on a prompt and resumes as soon as the player does the move.
## Failing never ends the tutorial: Kavi pops back and the prompt repeats.

const Track = preload("res://scripts/track.gd")
const Sim = preload("res://scripts/sim.gd")
enum { HURDLE, BEAM, GAP, WIDE_GAP, GATE, BELL, BLOOM, RESCUE, CART, FLOCK, TOWER }

const SPEED := 430.0
const TOTAL_LESSONS := 10

var waiting := ""        # "", "jump", "down", "gust", "letter", "hover"
var wait_t := 0.0
var title := ""
var sub := ""
var prompted := {}
var reprompt := false
var lessons := 0
var touch_mode := true

## Builds the practice course into `track`; returns the end x.
static func build(track) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var sp := SPEED
	# [type, seconds of running before it]
	var seq := [[HURDLE, 3.0], [HURDLE, 2.4], [BEAM, 2.6], [GAP, 2.6], [WIDE_GAP, 2.8],
		[GATE, 2.8], [BELL, 3.4], [BLOOM, 3.0], [HURDLE, 3.0], [-1, 0.0], [HURDLE, 2.6], [GAP, 2.2]]
	var placed: Array = []
	var t := 0.0
	for step in seq:
		if step[0] == -1:
			# Swoop lesson: a beam right after the previous hurdle.
			var h: Dictionary = placed[-1]
			placed.append(Track.make(BEAM, h.x + h.w + sp * 0.42, sp, rng))
			t = (placed[-1].x + placed[-1].w) / sp
			continue
		t += step[1]
		var o := Track.make(step[0], t * sp, sp, rng)
		if o.t == HURDLE:
			o.h = 64.0
		placed.append(o)
		t += Track.obstacle_extent(o) / sp
	var end_x := (t + 3.0) * sp
	for o in placed:
		track.obs.append(o)
	track._place_motes(placed, 0.0, end_x, sp, rng)
	track.end_x = end_x
	return end_x

func _set_text(need: String, o: Dictionary, sim) -> void:
	# Prompts name the controls the player actually uses (touch or keys).
	var k := func(keys: String, tap: String) -> String: return tap if touch_mode else keys
	match need:
		"jump":
			title = "HOP"
			sub = k.call("Press W, Up or Space", "Tap the top of the left pad")
			if o.t == GAP:
				sub = "Jump right at the edge: " + k.call("press W / Space", "tap the top of the left pad")
			elif o.t == BLOOM:
				title = "HOP toward the flower"
				sub = "Get airborne first: " + k.call("press W / Space", "tap the top of the left pad")
		"hover":
			title = "HOLD to HOVER"
			sub = k.call("Keep holding W / Space", "Keep your thumb on the top of the left pad") + ": the thrusters glide over wide gaps"
		"down":
			if o.t == BLOOM:
				title = "DIVE!"
				sub = k.call("Press S / Down", "Tap the bottom of the left pad") + " in the air to slam the bloom"
			elif not sim.on_ground:
				title = "SWOOP"
				sub = k.call("Press S / Down", "Tap the bottom of the left pad") + " in the air, keep holding to turbo-slide"
			else:
				title = "SCOOT"
				sub = k.call("Hold S / Down", "Hold the bottom of the left pad") + " to slide under"
		"gust":
			title = "GUST"
			sub = k.call("Press X", "Tap the big right button") + ": blow the gate open"
		"letter":
			title = "LETTER"
			sub = k.call("Press C", "Tap the small right button") + ": the paper plane rings the bell"

func _need(bot: Dictionary, sim, sp: float) -> String:
	if bot.jump_pressed and sim.on_ground:
		return "jump"
	if bot.down_pressed:
		return "down"
	if bot.gust_pressed:
		return "gust"
	if bot.letter_pressed:
		return "letter"
	if bot.jump_held and not sim.on_ground and sim.vy > -60.0 and not sim.hovering \
			and sim.hover_fuel > 0.0 and Track._landing_in_hole(sim, sp):
		# Only the wide gap needs a hover; a normal gap is cleared by a hop.
		var i: int = sim.track.first_index_after(sim.x - Sim.HALF_W)
		if i < sim.track.obs.size() and sim.track.obs[i].t == WIDE_GAP:
			return "hover"
	return ""

static func _does(need: String, raw: Dictionary) -> bool:
	match need:
		"jump": return raw.jump_pressed
		"down": return raw.down_pressed
		"gust": return raw.gust_pressed
		"letter": return raw.letter_pressed
		"hover": return raw.jump_held
	return false

## Returns the input to simulate this tick, or null while frozen on a prompt.
func filter(raw: Dictionary, sim, dt: float, autopilot: bool) -> Variant:
	var sp: float = sim.cur_speed()
	var bot := Track.bot_input(sim)
	if autopilot:
		raw = bot
	if waiting != "":
		wait_t += dt
		var ok := (wait_t > 0.9) if autopilot else _does(waiting, raw)
		if not ok:
			return null
		var inp := raw.duplicate()
		match waiting:
			"jump":
				inp.jump_pressed = true
				inp.jump_held = true
			"down":
				inp.down_pressed = true
				inp.down_held = true
			"gust": inp.gust_pressed = true
			"letter": inp.letter_pressed = true
			"hover": inp.jump_held = true
		waiting = ""
		lessons += 1
		sim.frozen = false
		return inp
	var need := _need(bot, sim, sp)
	if need != "" and (autopilot or not _does(need, raw)):
		var i: int = sim.track.first_index_after(sim.x - Sim.HALF_W)
		if i < sim.track.obs.size():
			var o: Dictionary = sim.track.obs[i]
			var key := need + str(o.t) + ("air" if not sim.on_ground else "")
			if not prompted.has(key) or reprompt:
				prompted[key] = true
				reprompt = false
				waiting = need
				wait_t = 0.0
				_set_text(need, o, sim)
				sim.frozen = true
				return null
	# Forgiving extras: hold the jump while rising, keep a started slide.
	var out := raw.duplicate()
	out.jump_held = raw.jump_held or (not sim.on_ground and sim.vy < 0.0)
	if sim.sliding and bot.down_held:
		out.down_held = true
	return out

func highlight_zone() -> String:
	match waiting:
		"jump", "hover": return "jump"
		"down": return "down"
		"gust": return "gust"
		"letter": return "letter"
	return ""
