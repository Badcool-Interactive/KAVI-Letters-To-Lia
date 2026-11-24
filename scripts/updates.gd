extends Node

signal changed
signal restart_requested

const REPO := "https://github.com/singh679/volt-run-luminous"
const LATEST := "https://api.github.com/repos/singh679/volt-run-luminous/releases/latest"
const PAGES := "https://singh679.github.io/volt-run-luminous/"
const INSTALL_ARG := "--kavi-apply-update"
const CACHE := "user://updates"
const MAX_ASSET_BYTES := 256 * 1024 * 1024
const FILES := {"Linux": "KAVI-linux.x86_64", "Windows": "KAVI-windows.exe", "Android": "KAVI-android.apk"}
const TARGET_NAMES := {"Linux": ["Kavi.x86_64", "KAVI-linux.x86_64"], "Windows": ["Kavi.exe", "KAVI-windows.exe"]}
const USER_EXEC := 448  # 0700

var phase := ""
var message := ""
var version := ""
var _http: HTTPRequest
var _asset: Dictionary
var _path := ""
var _partial := ""
var _redirects := 0
var _percent := -1

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = not OS.has_feature("web")
	_http.max_redirects = 0
	_http.request_completed.connect(_completed)
	add_child(_http)
	set_process(false)
	var failure := CACHE.path_join("install-failed.txt")
	if FileAccess.file_exists(failure):
		_show("error", FileAccess.get_file_as_string(failure))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(failure))

func _exit_tree() -> void:
	if is_instance_valid(_http) and phase == "downloading":
		_http.cancel_request()
		if FileAccess.file_exists(_partial):
			DirAccess.remove_absolute(_partial)

func _show(next_phase: String, text: String) -> void:
	phase = next_phase
	message = text
	changed.emit()

func check() -> void:
	if phase in ["checking", "checking_web", "downloading", "ready", "installing", "web"]:
		return
	_http.timeout = 18
	_http.body_size_limit = 1024 * 1024
	_http.download_file = ""
	_show("checking", "Checking GitHub…")
	if _http.request(LATEST, ["Accept: application/vnd.github+json"]) != OK:
		_show("error", "Couldn’t check GitHub. Try again in a moment.")

func _completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if phase == "checking":
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_show("error", "Couldn’t check GitHub. Try again in a moment.")
			return
		_release_received(JSON.parse_string(body.get_string_from_utf8()))
	elif phase == "checking_web":
		var metadata = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if metadata is Dictionary and _version_number(str(metadata.get("version", ""))) >= _version_number(version):
			_show("web", "KAVI %s is available." % version)
		else:
			_show("error", "The browser build is still being published. Check again shortly.")
	elif phase == "downloading":
		_download_completed(result, code, headers)

static func _version_number(tag: String) -> int:
	var parts := tag.trim_prefix("v").split(".")
	if parts.size() != 3:
		return -1
	var number := 0
	for part in parts:
		if not part.is_valid_int() or part != str(int(part)) or int(part) < 0 or int(part) > 9999:
			return -1
		number = number * 10000 + int(part)
	return number

static func _is_digest(value: String) -> bool:
	return value.length() == 64 and value.is_valid_hex_number(false)

func _release_received(release: Variant) -> void:
	if not release is Dictionary or release.get("draft", true) or release.get("prerelease", true):
		_show("error", "GitHub didn’t return a stable KAVI release. Try again later.")
		return
	var tag := str(release.get("tag_name", ""))
	var latest := _version_number(tag)
	var current := _version_number(str(ProjectSettings.get_setting("application/config/version", "")))
	if latest < 0 or current < 0 or tag != "v" + tag.trim_prefix("v"):
		_show("error", "Couldn’t read the release version.")
		return
	if latest <= current:
		_show("current", "♥  We’re still the best!")
		return
	version = tag.trim_prefix("v")
	if OS.has_feature("web"):
		if _on_official_web():
			_show("checking_web", "Checking the browser build…")
			if _http.request(PAGES + "version.json?check=%d" % int(Time.get_unix_time_from_system())) != OK:
				_show("error", "Couldn’t check the browser build. Try again shortly.")
		else:
			_show("web", "KAVI %s is available." % version)
		return
	var filename: String = FILES.get(OS.get_name(), "")
	_asset = _release_asset(release.get("assets", null), tag, filename)
	if _asset.is_empty():
		_show("error", "A verified download for this device isn’t available yet.")
		return
	_begin_download()

static func _release_asset(assets: Variant, tag: String, filename: String) -> Dictionary:
	if not assets is Array or filename.is_empty():
		return {}
	var expected_url := "%s/releases/download/%s/%s" % [REPO, tag, filename]
	for entry in assets:
		if not entry is Dictionary or entry.get("name") != filename or entry.get("state") != "uploaded":
			continue
		var digest := str(entry.get("digest", ""))
		var size: int = int(entry.get("size", 0))
		if entry.get("browser_download_url") == expected_url and size > 0 and size <= MAX_ASSET_BYTES \
				and digest.begins_with("sha256:") and _is_digest(digest.trim_prefix("sha256:")):
			return {"name": filename, "url": expected_url, "size": size, "digest": digest.trim_prefix("sha256:").to_lower()}
	return {}

func _begin_download() -> void:
	var folder := ProjectSettings.globalize_path(CACHE.path_join(version))
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_show("error", "Couldn’t prepare a folder for the update.")
		return
	_path = folder.path_join(_asset.name)
	if _valid_download(_path):
		_download_ready()
		return
	_partial = "%s.%d.part" % [_path, OS.get_process_id()]
	_redirects = 0
	_percent = -1
	_http.timeout = 300
	_http.body_size_limit = _asset.size
	_http.download_file = _partial
	_show("downloading", "Downloading KAVI %s…" % version)
	_fetch_asset(_asset.url)
	set_process(phase == "downloading")

func _fetch_asset(url: String) -> void:
	if _http.request(url) != OK:
		_download_failed("Couldn’t start the download. Try again.")

func _process(_delta: float) -> void:
	var percent := int(100.0 * _http.get_downloaded_bytes() / float(_asset.size))
	if percent != _percent:
		_percent = percent
		_show("downloading", "Downloading KAVI %s… %d%%" % [version, clampi(percent, 0, 100)])

func _download_completed(result: int, code: int, headers: PackedStringArray) -> void:
	if code in [301, 302, 303, 307, 308] and _redirects < 3:
		for header in headers:
			if header.get_slice(":", 0).strip_edges().to_lower() != "location":
				continue
			var target := header.substr(header.find(":") + 1).strip_edges()
			if target.begins_with("https://release-assets.githubusercontent.com/") \
					or target.begins_with("https://objects.githubusercontent.com/"):
				_redirects += 1
				_fetch_asset.call_deferred(target)
				return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_download_failed("The download didn’t finish. Try again.")
		return
	if not _valid_download(_partial):
		_download_failed("The download didn’t match GitHub’s checksum. Try again.")
		return
	if DirAccess.rename_absolute(_partial, _path) != OK:
		_download_failed("Couldn’t save the verified update.")
		return
	_download_ready()

func _valid_download(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(_asset.size):
		return false
	file.close()
	return FileAccess.get_sha256(path) == str(_asset.digest)

func _download_failed(text: String) -> void:
	set_process(false)
	if FileAccess.file_exists(_partial):
		DirAccess.remove_absolute(_partial)
	_show("error", text)

func _download_ready() -> void:
	set_process(false)
	_show("ready", "KAVI %s is downloaded and verified." % version)

func action_text() -> String:
	match phase:
		"web": return "Reload KAVI" if _on_official_web() else "Open the official web build"
		"ready": return "Install update" if OS.has_feature("android") else "Restart and update"
		_: return ""

func apply() -> void:
	if phase == "web":
		if _on_official_web():
			var stamp := "%s-%d" % [version, int(Time.get_unix_time_from_system())]
			JavaScriptBridge.eval("(() => { const u = new URL(location.href); u.searchParams.set('kavi', %s); location.replace(u.href); })()" % JSON.stringify(stamp))
		else:
			OS.shell_open(PAGES)
	elif phase == "ready":
		if not _valid_download(_path):
			_show("error", "The downloaded file changed. Check for updates again.")
			return
		if OS.has_feature("android"):
			_install_android()
		else:
			_launch_desktop_helper()

static func _on_official_web() -> bool:
	return OS.has_feature("web") and bool(JavaScriptBridge.eval(
		"location.origin === 'https://singh679.github.io' && location.pathname.startsWith('/volt-run-luminous/')"
	))

func _install_android() -> void:
	var runtime = Engine.get_singleton("AndroidRuntime")
	var java = Engine.get_singleton("JavaClassWrapper")
	if runtime == null or java == null:
		_show("error", "The Android installer couldn’t open. Use Downloads and updates.")
		return
	var activity = runtime.getActivity()
	var intent_class = java.wrap("android.content.Intent")
	var file_class = java.wrap("java.io.File")
	var provider = java.wrap("androidx.core.content.FileProvider")
	var uri_class = java.wrap("android.net.Uri")
	var android_version = java.wrap("android.os.Build$VERSION")
	var package_name: String = activity.getPackageName()
	if int(android_version.SDK_INT) >= 26 and not activity.getPackageManager().canRequestPackageInstalls():
		var settings = intent_class.Intent("android.settings.MANAGE_UNKNOWN_APP_SOURCES")
		settings.setData(uri_class.parse("package:" + package_name))
		activity.startActivity(settings)
		_show("ready", "Allow installs from KAVI in Android settings, then tap Install update again.")
		return
	var uri = provider.getUriForFile(activity, package_name + ".fileprovider", file_class.File(_path))
	if uri == null:
		_show("error", "Android couldn’t open the APK. Use Downloads and updates.")
		return
	var intent = intent_class.Intent(intent_class.ACTION_VIEW)
	intent.setDataAndType(uri, "application/vnd.android.package-archive")
	intent.addFlags(intent_class.FLAG_GRANT_READ_URI_PERMISSION)
	activity.startActivity(intent)
	_show("ready", "Confirm the update in Android’s installer.")

func _launch_desktop_helper() -> void:
	var target := OS.get_executable_path()
	var names: Array = TARGET_NAMES.get(OS.get_name(), [])
	if OS.has_feature("editor") or target.get_file() not in names:
		_show("error", "Use Downloads and updates for this copy of KAVI.")
		return
	var original_digest := FileAccess.get_sha256(target)
	if not _is_digest(original_digest) or (OS.has_feature("linux") and FileAccess.set_unix_permissions(_path, USER_EXEC) != OK):
		_show("error", "KAVI couldn’t prepare to restart. Use Downloads and updates.")
		return
	var args := PackedStringArray(["--headless", "--", INSTALL_ARG, target, str(OS.get_process_id()), _asset.digest, original_digest])
	if OS.create_process(_path, args) < 0:
		_show("error", "KAVI couldn’t restart. Use Downloads and updates.")
		return
	_show("installing", "Restarting KAVI…")
	restart_requested.emit()

static func run_desktop_helper(args: PackedStringArray) -> int:
	if args.size() != 5 or not args[2].is_valid_int() or int(args[2]) <= 1:
		return 1
	var target := args[1].replace("\\", "/").simplify_path()
	var source := OS.get_executable_path().replace("\\", "/")
	var cache := ProjectSettings.globalize_path(CACHE).replace("\\", "/").trim_suffix("/")
	var names: Array = TARGET_NAMES.get(OS.get_name(), [])
	var digest := args[3]
	var original := args[4]
	if not target.is_absolute_path() or target.get_file() not in names or source == target \
			or not source.begins_with(cache + "/") or source.get_file() != FILES.get(OS.get_name()) \
			or not _is_digest(digest) or not _is_digest(original) or FileAccess.get_sha256(source) != digest:
		return 1
	var parent := int(args[2])
	if OS.has_feature("linux"):
		for i in 100:
			if not DirAccess.dir_exists_absolute("/proc/%d" % parent):
				break
			OS.delay_msec(100)
		if DirAccess.dir_exists_absolute("/proc/%d" % parent):
			return 1
	var lock := target + ".update-lock"
	var result := FAILED
	for i in 30:
		result = DirAccess.make_dir_absolute(lock)
		if result == OK or not DirAccess.dir_exists_absolute(lock):
			break
		OS.delay_msec(100)
	if result == OK:
		if FileAccess.get_sha256(target) == digest:
			DirAccess.remove_absolute(lock)
			return 0
		result = _replace_binary(source, target, digest, original)
		DirAccess.remove_absolute(lock)
	if result != OK:
		var failure := FileAccess.open(CACHE.path_join("install-failed.txt"), FileAccess.WRITE)
		if failure != null:
			failure.store_string("The update couldn’t replace this copy of KAVI. Use Downloads and updates.")
			failure.close()
	return int(OS.create_process(target, PackedStringArray()) < 0 or result != OK)

static func _replace_binary(source: String, target: String, digest: String, original: String) -> Error:
	var dir := DirAccess.open(target.get_base_dir())
	if dir == null or dir.is_link(target.get_file()) or FileAccess.get_sha256(target) != original:
		return ERR_INVALID_DATA
	var candidate := "%s.update-%d" % [target, OS.get_process_id()]
	var mode := FileAccess.get_unix_permissions(target) if OS.has_feature("linux") else -1
	var backup := source.get_base_dir().path_join("previous-" + target.get_file())
	var error := DirAccess.copy_absolute(target, backup, mode)
	if error == OK:
		error = DirAccess.copy_absolute(source, candidate, mode)
	if error == OK and FileAccess.get_sha256(candidate) != digest:
		error = ERR_FILE_CORRUPT
	if error == OK:
		error = _swap_binary(candidate, target)
	if FileAccess.file_exists(candidate):
		DirAccess.remove_absolute(candidate)
	return error

static func _swap_binary(candidate: String, target: String) -> Error:
	if not OS.has_feature("windows"):
		return DirAccess.rename_absolute(candidate, target)
	# Godot removes an existing Windows destination before renaming. Move the
	# old executable aside first so a failed swap can restore it.
	var previous := "%s.previous-%d" % [target, OS.get_process_id()]
	var error := FAILED
	for i in 100:
		error = DirAccess.rename_absolute(target, previous)
		if error == OK:
			break
		OS.delay_msec(100)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(candidate, target)
	if error != OK:
		DirAccess.rename_absolute(previous, target)
	else:
		DirAccess.remove_absolute(previous)
	return error
