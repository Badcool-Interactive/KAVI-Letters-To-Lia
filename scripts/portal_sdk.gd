extends RefCounted
## CrazyGames SDK v3 (0.8.40), portal build only: tells the portal when real
## gameplay starts and stops, so it can measure play. No ads, no login, no
## player data. Everywhere else (and if the SDK fails to load) it does nothing.
## The SDK script itself is added by the Web-Portal export preset's head_include.

var _on := false
var _playing := false

func init() -> void:
	if not (OS.has_feature("web") and OS.has_feature("portal")):
		return
	JavaScriptBridge.eval("""
		window.__kaviCG = {ready: false, playing: false};
		try {
			if (window.CrazyGames && window.CrazyGames.SDK) {
				window.CrazyGames.SDK.init().then(function () {
					window.__kaviCG.ready = true;
					if (window.__kaviCG.playing) { try { window.CrazyGames.SDK.game.gameplayStart(); } catch (e) {} }
				}).catch(function () {});
			}
		} catch (e) {}
	""", true)
	_on = true

## Call every frame with whether the player is actively playing; only the
## changes are sent.
func set_playing(playing: bool) -> void:
	if not _on or playing == _playing:
		return
	_playing = playing
	JavaScriptBridge.eval("try { window.__kaviCG.playing = %s; if (window.__kaviCG.ready) window.CrazyGames.SDK.game.%s(); } catch (e) {}" % ["true" if playing else "false", "gameplayStart" if playing else "gameplayStop"], true)
