extends RefCounted
## Garage items. Story idea (owner, 2026-11-22): Kavi himself is a little memory
## chip, so he can move into new suits the way people change clothes. His face
## screen and scarf stay recognisable whatever he wears.
##
## Pace (owner): the first two buys (a scarf and a visor) take about 3 runs;
## everything takes roughly 30-35 runs at ~12 Sparks per run.

const CATS := ["suit", "paint", "visor", "scarf", "antenna"]
const CAT_NAMES := {"suit": "Suits", "paint": "Paint", "visor": "Visor", "scarf": "Scarves", "antenna": "Antenna"}

## The first six scarves keep the old save indices (owned_scarves) valid.
const ITEMS := {
	"scarf": [
		{"name": "Sunset Orange", "cost": 0, "col": Color(1.0, 0.35, 0.14)},
		{"name": "Sky Blue", "cost": 15, "col": Color(0.30, 0.65, 1.0)},
		{"name": "Rose", "cost": 20, "col": Color(1.0, 0.45, 0.65)},
		{"name": "Honey Gold", "cost": 25, "col": Color(1.0, 0.80, 0.25)},
		{"name": "Mint", "cost": 25, "col": Color(0.35, 0.95, 0.65)},
		{"name": "Violet", "cost": 30, "col": Color(0.70, 0.45, 1.0)},
		{"name": "Candy Stripes", "cost": 40, "col": Color(1.0, 0.40, 0.45), "col2": Color(1.0, 0.95, 0.90), "pattern": "stripes"},
		{"name": "Rainbow", "cost": 55, "col": Color(1.0, 0.4, 0.4), "pattern": "rainbow"},
	],
	"visor": [
		{"name": "Cyan Glow", "cost": 0, "eye": Color(0.30, 1.0, 1.0)},
		{"name": "Sunny", "cost": 20, "eye": Color(1.0, 0.85, 0.35)},
		{"name": "Bubblegum", "cost": 25, "eye": Color(1.0, 0.50, 0.80)},
		{"name": "Lime", "cost": 30, "eye": Color(0.60, 1.0, 0.40)},
		{"name": "Lavender", "cost": 30, "eye": Color(0.75, 0.62, 1.0)},
	],
	"paint": [
		{"name": "Classic", "cost": 0, "shell": Color(0.965, 0.973, 0.988), "shade": Color(0.62, 0.74, 0.88), "accent": Color(0.15, 0.79, 0.80)},
		{"name": "Midnight", "cost": 35, "shell": Color(0.30, 0.34, 0.52), "shade": Color(0.18, 0.20, 0.34), "accent": Color(1.0, 0.78, 0.30)},
		{"name": "Coral Reef", "cost": 35, "shell": Color(1.0, 0.92, 0.86), "shade": Color(0.90, 0.66, 0.62), "accent": Color(1.0, 0.45, 0.42)},
		{"name": "Forest", "cost": 40, "shell": Color(0.86, 0.95, 0.86), "shade": Color(0.52, 0.70, 0.56), "accent": Color(0.25, 0.62, 0.38)},
		{"name": "Bubble Pink", "cost": 40, "shell": Color(1.0, 0.90, 0.96), "shade": Color(0.88, 0.66, 0.84), "accent": Color(0.85, 0.40, 0.95)},
	],
	"antenna": [
		{"name": "Kite", "cost": 0, "tip": "kite"},
		{"name": "Star", "cost": 20, "tip": "star"},
		{"name": "Heart", "cost": 20, "tip": "heart"},
		{"name": "Leaf", "cost": 25, "tip": "leaf"},
	],
	"suit": [
		{"name": "Courier", "cost": 0, "helmet": "round"},
		{"name": "Kitty", "cost": 50, "helmet": "cat"},
		{"name": "Explorer", "cost": 60, "helmet": "explorer"},
	],
}

static func item(cat: String, i: int) -> Dictionary:
	var list: Array = ITEMS[cat]
	return list[clampi(i, 0, list.size() - 1)]

## Save fields: "wear" {cat: index} and "owned" {cat: [indices]}. Older saves
## only had scarf / owned_scarves; they are migrated here.
static func ensure(data: Dictionary) -> void:
	if not data.has("wear") or not (data.wear is Dictionary):
		data.wear = {}
	if not data.has("owned") or not (data.owned is Dictionary):
		data.owned = {}
	for c in CATS:
		if not data.owned.has(c):
			data.owned[c] = [0]
		if not data.wear.has(c):
			data.wear[c] = 0
	if data.has("owned_scarves"):
		for i in data.owned_scarves:
			if not data.owned.scarf.has(int(i)):
				data.owned.scarf.append(int(i))
		data.erase("owned_scarves")
	if data.has("scarf"):
		data.wear.scarf = int(data.scarf)
		data.erase("scarf")

static func owns(data: Dictionary, cat: String, i: int) -> bool:
	var o: Array = data.owned[cat]
	return o.has(i) or o.has(float(i))

## Everything Kavi's renderer needs, from what he wears (plus an optional
## try-on preview of one item).
static func compose(wear: Dictionary, preview_cat := "", preview_i := -1) -> Dictionary:
	var w := wear.duplicate()
	if preview_cat != "" and preview_i >= 0:
		w[preview_cat] = preview_i
	var paint := item("paint", int(w.get("paint", 0)))
	var sc := item("scarf", int(w.get("scarf", 0)))
	return {
		"shell": paint.shell, "shade": paint.shade, "accent": paint.accent,
		"eye": item("visor", int(w.get("visor", 0))).eye,
		"scarf": sc.col, "scarf2": sc.get("col2", sc.col), "pattern": sc.get("pattern", "solid"),
		"tip": item("antenna", int(w.get("antenna", 0))).tip,
		"helmet": item("suit", int(w.get("suit", 0))).helmet,
	}
