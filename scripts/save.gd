extends RefCounted
## Local save data (user://). Tests run with an isolated user-data dir.

const PATH := "user://kavi_save.json"
## Older builds were called VOLT/RUN: their save lived in user://volt_run_save.json
## inside the "VOLT-RUN" folder. On first launch the old save is copied to
## kavi_save.json (0.8.33). Since 0.8.34 the old file is then MOVED into the
## KAVI folder as old_volt_run_save.json (owner: "the remaining files are also
## moved into that correct folder"); the original is removed only after the
## moved copy is verified byte for byte. Other files in the old folder
## (volt_settings.cfg, caches) belong to the legacy VOLT/RUN project and are
## never touched.
const LEGACY_IN_USER := "user://volt_run_save.json"
const LEGACY_DESKTOP_DIR := "godot/app_userdata/VOLT-RUN/volt_run_save.json"
const LEGACY_BACKUP := "user://old_volt_run_save.json"

func _migrate_legacy() -> void:
	var candidates := [LEGACY_IN_USER, OS.get_data_dir().path_join(LEGACY_DESKTOP_DIR)]
	for src in candidates:
		if not FileAccess.file_exists(src):
			continue
		var txt := FileAccess.get_file_as_string(src)
		if txt == "":
			continue
		if not FileAccess.file_exists(PATH):
			_write(PATH, txt)
		if not FileAccess.file_exists(LEGACY_BACKUP):
			_write(LEGACY_BACKUP, txt)
		if FileAccess.get_file_as_string(LEGACY_BACKUP) == txt and FileAccess.get_file_as_string(PATH) != "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path(src) if src.begins_with("user://") else src)

static func _write(path: String, txt: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		f.close()

const DEFAULT_WORLD_VOLUME := 0.45

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
		"cursor": "system",
		"music": 0.8,
		"sfx": 0.9,
		"left_handed": false,
		"controls_scale": 1.0,
		"graphics": "auto",
		"master": 1.0,
		"world": DEFAULT_WORLD_VOLUME,
		"world_mix_revision": 1,
		"custom": false,
		"gx_detail": 2,
		"gx_glow": true,
		"gx_rays": true,
		"gx_lights": false,
		"time_of_day": "classic",
		"gx_effects": 1,
		"gx_res": 0,
		"gx_fps": 60,
		"show_fps": 0,
		"kavi_limbs2": "jointed",
	},
}

## Device tests (benchmarks run on a real phone) set this: the player's save
## is never read or written, so a test can't touch real progress (studio rule 2).
var isolated := false

func load_data() -> void:
	if isolated:
		return
	_migrate_legacy()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var old_settings = parsed.get("settings")
		if old_settings is Dictionary and not old_settings.has("world_mix_revision"):
			# Older saves did not distinguish the default 70% from a manual 70%.
			var old_world = old_settings.get("world")
			if old_world is float and is_equal_approx(old_world, 0.7):
				old_settings["world"] = DEFAULT_WORLD_VOLUME
		_merge(data, parsed)

func _merge(into: Dictionary, src: Dictionary) -> void:
	for k in src:
		if into.has(k) and into[k] is Dictionary and src[k] is Dictionary:
			_merge(into[k], src[k])
		else:
			into[k] = src[k]

func save() -> void:
	if isolated:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
