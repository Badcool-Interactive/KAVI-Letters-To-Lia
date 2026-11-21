extends SceneTree
## Pre-renders the procedural music loops to assets/music/*.wav so phones and
## browsers load them instantly instead of synthesising at runtime.
## Run: godot --headless --path . --script res://tools/render_music.gd
const Synth = preload("res://scripts/synth.gd")

func _initialize() -> void:
	var s = Synth.new()
	for b in Synth.KEYS.size():
		s._render_music(b)
		var pair: Array = s._cache[b]
		pair[0].save_to_wav("res://assets/music/b%d_pad.wav" % b)
		pair[1].save_to_wav("res://assets/music/b%d_drive.wav" % b)
		print("rendered biome ", b)
	s.free()
	quit()
