extends RefCounted
## Garage items. Story idea (owner, 2026-11-22): Kavi himself is a little memory
## chip, so he can move into new suits the way people change clothes. His face
## screen and scarf stay recognisable whatever he wears.
##
## Two currencies (owner, 0.8.1): everyday items cost Stamps (collected while
## running, ~300 per run); special items (suits, patterned scarves) cost Sparks
## (rare). The Garage exchange converts between them, not 1:1.
## Pace: the first scarf + visor take about 3 runs; everything ~35 runs.
## DEV_FREE: while the game is in development every item is free (owner).
const DEV_FREE := true
const STAMPS_PER_SPARK := 50   # buy 1 Spark for 50 Stamps
const STAMPS_FOR_SPARK := 25   # sell 1 Spark for 25 Stamps

const CATS := ["suit", "paint", "visor", "face", "scarf", "antenna", "extra", "bag", "trail", "letter"]
const CAT_NAMES := {
	"suit": "Suits", "paint": "Paint", "visor": "Visor", "face": "Faces", "scarf": "Scarves",
	"antenna": "Antenna", "extra": "Extras", "bag": "Bags", "trail": "Trails", "letter": "Letters",
}

## The first six scarves keep the old save indices (owned_scarves) valid.
const ITEMS := {
	"scarf": [
		{"name": "Sunset Orange", "cost": 0, "col": Color(1.0, 0.35, 0.14)},
		{"name": "Sky Blue", "cost": 400, "cur": "stamps", "col": Color(0.30, 0.65, 1.0)},
		{"name": "Rose", "cost": 500, "cur": "stamps", "col": Color(1.0, 0.45, 0.65)},
		{"name": "Honey Gold", "cost": 600, "cur": "stamps", "col": Color(1.0, 0.80, 0.25)},
		{"name": "Mint", "cost": 600, "cur": "stamps", "col": Color(0.35, 0.95, 0.65)},
		{"name": "Violet", "cost": 700, "cur": "stamps", "col": Color(0.70, 0.45, 1.0)},
		{"name": "Candy Stripes", "cost": 6, "cur": "sparks", "col": Color(1.0, 0.40, 0.45), "col2": Color(1.0, 0.95, 0.90), "pattern": "stripes"},
		{"name": "Rainbow", "cost": 10, "cur": "sparks", "col": Color(1.0, 0.4, 0.4), "pattern": "rainbow"},
	],
	"visor": [
		{"name": "Cyan Glow", "cost": 0, "eye": Color(0.30, 1.0, 1.0)},
		{"name": "Sunny", "cost": 500, "cur": "stamps", "eye": Color(1.0, 0.85, 0.35)},
		{"name": "Bubblegum", "cost": 600, "cur": "stamps", "eye": Color(1.0, 0.50, 0.80)},
		{"name": "Lime", "cost": 700, "cur": "stamps", "eye": Color(0.60, 1.0, 0.40)},
		{"name": "Lavender", "cost": 700, "cur": "stamps", "eye": Color(0.75, 0.62, 1.0)},
	],
	"paint": [
		{"name": "Classic", "cost": 0, "shell": Color(0.965, 0.973, 0.988), "shade": Color(0.62, 0.74, 0.88), "accent": Color(0.15, 0.79, 0.80)},
		{"name": "Midnight", "cost": 900, "cur": "stamps", "shell": Color(0.30, 0.34, 0.52), "shade": Color(0.18, 0.20, 0.34), "accent": Color(1.0, 0.78, 0.30)},
		{"name": "Coral Reef", "cost": 900, "cur": "stamps", "shell": Color(1.0, 0.92, 0.86), "shade": Color(0.90, 0.66, 0.62), "accent": Color(1.0, 0.45, 0.42)},
		{"name": "Forest", "cost": 1000, "cur": "stamps", "shell": Color(0.86, 0.95, 0.86), "shade": Color(0.52, 0.70, 0.56), "accent": Color(0.25, 0.62, 0.38)},
		{"name": "Bubble Pink", "cost": 1000, "cur": "stamps", "shell": Color(1.0, 0.90, 0.96), "shade": Color(0.88, 0.66, 0.84), "accent": Color(0.85, 0.40, 0.95)},
	],
	"antenna": [
		{"name": "Diamond", "cost": 0, "tip": "kite"},
		{"name": "Star", "cost": 500, "cur": "stamps", "tip": "star"},
		{"name": "Heart", "cost": 500, "cur": "stamps", "tip": "heart"},
		{"name": "Leaf", "cost": 600, "cur": "stamps", "tip": "leaf"},
	],
	"face": [
		{"name": "Courier eyes", "cost": 0, "face": "classic"},
		{"name": "Button eyes", "cost": 400, "cur": "stamps", "face": "buttons"},
		{"name": "Star eyes", "cost": 500, "cur": "stamps", "face": "stars"},
		{"name": "Soft crescents", "cost": 500, "cur": "stamps", "face": "crescents"},
	],
	"bag": [
		{"name": "Courier satchel", "cost": 0, "bag": "classic"},
		{"name": "Mint daypack", "cost": 450, "cur": "stamps", "bag": "daypack"},
		{"name": "Plum postbag", "cost": 550, "cur": "stamps", "bag": "postbag"},
		{"name": "Golden rolltop", "cost": 6, "cur": "sparks", "bag": "rolltop"},
	],
	"extra": [
		{"name": "Nothing", "cost": 0, "extra": ""},
		{"name": "Round glasses", "cost": 500, "cur": "stamps", "extra": "glasses"},
		{"name": "Red bow", "cost": 500, "cur": "stamps", "extra": "bow"},
		{"name": "Daisy", "cost": 400, "cur": "stamps", "extra": "flower"},
		{"name": "Headphones", "cost": 700, "cur": "stamps", "extra": "headphones"},
		{"name": "Little crown", "cost": 8, "cur": "sparks", "extra": "crown"},
	],
	"trail": [
		{"name": "Wind (classic)", "cost": 0, "trail": ""},
		{"name": "Stars", "cost": 600, "cur": "stamps", "trail": "stars"},
		{"name": "Hearts", "cost": 600, "cur": "stamps", "trail": "hearts"},
		{"name": "Petals", "cost": 700, "cur": "stamps", "trail": "petals"},
		{"name": "Snowflakes", "cost": 700, "cur": "stamps", "trail": "snow"},
	],
	"letter": [
		{"name": "Paper white", "cost": 0, "letter": Color(0.96, 0.97, 1.0)},
		{"name": "Blush pink", "cost": 300, "cur": "stamps", "letter": Color(1.0, 0.76, 0.84)},
		{"name": "Mint", "cost": 300, "cur": "stamps", "letter": Color(0.72, 1.0, 0.86)},
		{"name": "Sky", "cost": 300, "cur": "stamps", "letter": Color(0.70, 0.86, 1.0)},
		{"name": "Gold", "cost": 4, "cur": "sparks", "letter": Color(1.0, 0.86, 0.45)},
	],
	"suit": [
		{"name": "Courier", "cost": 0, "helmet": "round"},
		{"name": "Kitty", "cost": 8, "cur": "sparks", "helmet": "cat"},
		{"name": "Explorer", "cost": 12, "cur": "sparks", "helmet": "explorer"},
		{"name": "Astro Bubble", "cost": 12, "cur": "sparks", "helmet": "astro"},
		{"name": "Teapot", "cost": 10, "cur": "sparks", "helmet": "teapot"},
		{"name": "Bunny", "cost": 9, "cur": "sparks", "helmet": "bunny"},
		{"name": "Blocky", "cost": 9, "cur": "sparks", "helmet": "block"},
		{"name": "Sprout", "cost": 8, "cur": "sparks", "helmet": "sprout"},
		{"name": "Lion", "cost": 12, "cur": "sparks", "helmet": "lion"},
		{"name": "Bear", "cost": 9, "cur": "sparks", "helmet": "bear"},
		{"name": "Fox", "cost": 10, "cur": "sparks", "helmet": "fox"},
		{"name": "Panda", "cost": 10, "cur": "sparks", "helmet": "panda"},
		{"name": "Frog", "cost": 9, "cur": "sparks", "helmet": "frog"},
		{"name": "Penguin", "cost": 10, "cur": "sparks", "helmet": "penguin"},
		{"name": "Bee", "cost": 9, "cur": "sparks", "helmet": "bee"},
		{"name": "Dino", "cost": 12, "cur": "sparks", "helmet": "dino"},
		{"name": "Tiger", "cost": 10, "cur": "sparks", "helmet": "tiger"},
		{"name": "Axolotl", "cost": 10, "cur": "sparks", "helmet": "axolotl"},
		{"name": "Bat", "cost": 9, "cur": "sparks", "helmet": "bat"},
		{"name": "Red Panda", "cost": 10, "cur": "sparks", "helmet": "red_panda"},
		{"name": "Otter", "cost": 9, "cur": "sparks", "helmet": "otter"},
		{"name": "Turtle", "cost": 9, "cur": "sparks", "helmet": "turtle"},
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
	if DEV_FREE:
		return true
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
		"face": item("face", int(w.get("face", 0))).face,
		"bag": item("bag", int(w.get("bag", 0))).bag,
		"extra": item("extra", int(w.get("extra", 0))).extra,
		"trail": item("trail", int(w.get("trail", 0))).trail,
		"letter": item("letter", int(w.get("letter", 0))).letter,
	}

static func wallet_key(it: Dictionary) -> String:
	return it.get("cur", "stamps")

static func price_text(it: Dictionary) -> String:
	return "%d %s" % [int(it.cost), "Sparks" if wallet_key(it) == "sparks" else "Stamps"]
