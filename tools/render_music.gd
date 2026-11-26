extends SceneTree
## Renders each country's song (synth.gd compose(): pad, drive, lead layers)
## to WAV in a temp folder; tools/render-music.sh then encodes them to OGG in
## assets/music/. Run: tools/render-music.sh
const Synth = preload("res://scripts/synth.gd")

func _initialize() -> void:
	var out := OS.get_environment("KAVI_MUSIC_TMP")
	if out == "":
		out = "/tmp/kavi-music"
	DirAccess.make_dir_recursive_absolute(out)
	for b in Synth.KEYS.size():
		var t0 := Time.get_ticks_msec()
		var layers: Array = Synth.compose(b)
		var names := ["pad", "drive", "lead"]
		for i in 3:
			Synth._wav_rate(layers[i], Synth.MRATE, false).save_to_wav("%s/b%d_%s.wav" % [out, b, names[i]])
		print("rendered country ", b, " in ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
	quit()
