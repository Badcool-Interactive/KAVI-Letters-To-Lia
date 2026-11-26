extends SceneTree
## Writes every procedural sound effect to WAV files so the owner can listen
## to each one (sound board). Run: godot --headless --path . --script res://tools/dump_sounds.gd -- OUT_DIR
const Synth = preload("res://scripts/synth.gd")

func _initialize() -> void:
	var out := "/tmp/kavi-sounds"
	for a in OS.get_cmdline_user_args():
		out = a
	DirAccess.make_dir_recursive_absolute(out)
	var s = Synth.new()
	s._build_sfx()
	var names: Array = s.sfx.keys()
	names.sort()
	for n in names:
		(s.sfx[n] as AudioStreamWAV).save_to_wav("%s/%s.wav" % [out, n])
	print("wrote ", names.size(), " sounds: ", ", ".join(names))
	s.free()
	quit()
