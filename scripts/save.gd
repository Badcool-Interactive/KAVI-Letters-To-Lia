extends RefCounted
## Local save data (user://). Tests run with an isolated user-data dir.

const PATH := "user://volt_run_save.json"

var data := {
	"best_endless": 0,
	"best_daily": 0,
	"best_story": 0,
	"daily_date": "",
	"stamps": 0,
	"sparks": 0,
	"story_done": false,
	"tutorial_done": false,
	"story_chapter": 0,
	"runs": 0,
	"runs_since_rescue": 0,
	"wear": {},
	"owned": {},
	"seen_hints": [],
	"photos": 0,
	"ads_date": "",
	"ads_today": 0,
	"settings": {
		"kind_mode": false,
		"assist_hover": false,
		"slow_speed": false,
		"reduced_motion": false,
		"shake": true,
		"music": 0.8,
		"sfx": 0.9,
		"left_handed": false,
		"controls_scale": 1.0,
		"graphics": "auto",
	},
}

func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)

func _merge(into: Dictionary, src: Dictionary) -> void:
	for k in src:
		if into.has(k) and into[k] is Dictionary and src[k] is Dictionary:
			_merge(into[k], src[k])
		else:
			into[k] = src[k]

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
