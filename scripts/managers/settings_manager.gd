extends Node
## Authoritative settings owner (autoload `Settings`, part A).
## Justification for autoload: display/audio/FPS choices must apply at boot
## and survive menu<->gameplay scene changes with one writer. Sole owner of
## the `user://settings.cfg` ConfigFile; every change saves immediately.
## Keys: audio/master,music,sfx (0-100, defaults 100/80/100),
## display/mode (window/borderless/fullscreen, default window),
## display/resolution (index into RESOLUTIONS, default 0 = 1280x720),
## display/show_fps (bool, default false). Loads in _ready and applies.
## Migrates the pre-autoload cfg (same audio keys + legacy display/windowed
## bool + resolution over the old 3-entry list) without overwriting stored
## values; only missing keys take the new defaults. Window changes go
## through DisplayServer (mode + borderless flag + exact size, API 4.7.2).
## Windowed mode applies the EXACT stored size centered on the primary
## screen: no silent downscale (Bloque C fix — the old _fit_to_screen clamp
## applied a smaller size than the selector showed on screens below
## 1920x1080, so 1080p/1440p "never applied"). Verification is async: the
## OS applies mode/size changes some frames AFTER the call, so any readback
## in the same tick still sees the old size. _apply_display only issues the
## request; apply_display_choice() waits for the OS to settle, verifies by
## real readback, persists ONLY on confirmation, and rolls back to the
## previous working values otherwise. When the OS keeps a different size,
## the stored choice is kept and the mismatch is reported with a warning
## instead of maquillarlo. Borderless fills the primary screen; fullscreen
## only switches mode (the display mode owns the size, never a contradictory
## forced size). A size picked in fullscreen/borderless is stored and applied
## on the return to windowed. Stretch canvas_items already keeps UI undeformed.

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_MASTER := 100.0
const DEFAULT_MUSIC := 80.0
const DEFAULT_SFX := 100.0
const DEFAULT_MODE := "window"
const DEFAULT_RESOLUTION := 0
const DEFAULT_SHOW_FPS := false

const MODES: Array[String] = ["window", "borderless", "fullscreen"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
## Legacy 3-entry list (pre-autoload cfg) used for migration only.
const LEGACY_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

const FpsOverlayScript = preload("res://scripts/ui/fps_overlay.gd")

var _master := DEFAULT_MASTER
var _music := DEFAULT_MUSIC
var _sfx := DEFAULT_SFX
var _mode := DEFAULT_MODE
var _res_index := DEFAULT_RESOLUTION
var _show_fps := DEFAULT_SHOW_FPS
var _overlay: CanvasLayer = null


func _ready() -> void:
	_overlay = FpsOverlayScript.new() as CanvasLayer
	add_child(_overlay)
	reload_from_disk()


## Public reload (boot path + probes): reads the cfg and applies everything.
func reload_from_disk() -> void:
	_load()
	_apply_all()


func get_master() -> float:
	return _master


func get_music() -> float:
	return _music


func get_sfx() -> float:
	return _sfx


func get_display_mode() -> String:
	return _mode


func get_resolution_index() -> int:
	return _res_index


func get_resolution() -> Vector2i:
	return RESOLUTIONS[clampi(_res_index, 0, RESOLUTIONS.size() - 1)]


func is_show_fps() -> bool:
	return _show_fps


func set_master(value_0_100: float) -> void:
	var clamped := clampf(value_0_100, 0.0, 100.0)
	if is_equal_approx(clamped, _master):
		return
	_master = clamped
	Audio.set_master(_master)
	_save()


func set_music(value_0_100: float) -> void:
	var clamped := clampf(value_0_100, 0.0, 100.0)
	if is_equal_approx(clamped, _music):
		return
	_music = clamped
	Audio.set_music(_music)
	_save()


func set_sfx(value_0_100: float) -> void:
	var clamped := clampf(value_0_100, 0.0, 100.0)
	if is_equal_approx(clamped, _sfx):
		return
	_sfx = clamped
	Audio.set_sfx(_sfx)
	_save()


func set_display_mode(mode: String) -> void:
	if not MODES.has(mode):
		return
	if mode == _mode:
		return
	_mode = mode
	_apply_display()
	_save()


func set_resolution_index(index: int) -> void:
	var clamped := clampi(index, 0, RESOLUTIONS.size() - 1)
	if clamped == _res_index:
		return
	_res_index = clamped
	_apply_display()
	_save()


func set_show_fps(enabled: bool) -> void:
	if enabled == _show_fps:
		return
	_show_fps = enabled
	_apply_fps()
	_save()


func _load() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	_master = clampf(float(cfg.get_value("audio", "master", DEFAULT_MASTER)), 0.0, 100.0)
	_music = clampf(float(cfg.get_value("audio", "music", DEFAULT_MUSIC)), 0.0, 100.0)
	_sfx = clampf(float(cfg.get_value("audio", "sfx", DEFAULT_SFX)), 0.0, 100.0)
	var stored_mode := str(cfg.get_value("display", "mode", ""))
	if stored_mode != "" and MODES.has(stored_mode):
		_mode = stored_mode
		_res_index = clampi(int(cfg.get_value("display", "resolution", DEFAULT_RESOLUTION)), 0, RESOLUTIONS.size() - 1)
	elif cfg.has_section("display"):
		# Legacy cfg: windowed bool + resolution over LEGACY_RESOLUTIONS.
		var windowed := bool(cfg.get_value("display", "windowed", true))
		if windowed:
			_mode = "window"
		else:
			_mode = "fullscreen"
		_res_index = _migrate_legacy_resolution(int(cfg.get_value("display", "resolution", 0)))
	else:
		_mode = DEFAULT_MODE
		_res_index = DEFAULT_RESOLUTION
	_show_fps = bool(cfg.get_value("display", "show_fps", DEFAULT_SHOW_FPS))


## Maps a legacy 0-2 index to the matching size in RESOLUTIONS by value.
func _migrate_legacy_resolution(legacy_index: int) -> int:
	var clamped := clampi(legacy_index, 0, LEGACY_RESOLUTIONS.size() - 1)
	var wanted: Vector2i = LEGACY_RESOLUTIONS[clamped]
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == wanted:
			return i
	return DEFAULT_RESOLUTION


## Load-merge-save: keeps unknown sections intact.
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "master", _master)
	cfg.set_value("audio", "music", _music)
	cfg.set_value("audio", "sfx", _sfx)
	cfg.set_value("display", "mode", _mode)
	cfg.set_value("display", "resolution", _res_index)
	cfg.set_value("display", "show_fps", _show_fps)
	cfg.save(SETTINGS_PATH)


func _apply_all() -> void:
	Audio.set_master(_master)
	Audio.set_music(_music)
	Audio.set_sfx(_sfx)
	_apply_display()
	_apply_fps()


func _apply_fps() -> void:
	if _overlay != null:
		_overlay.visible = _show_fps


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _primary_screen_size() -> Vector2i:
	if _is_headless():
		return Vector2i.ZERO
	if DisplayServer.get_screen_count() <= 0:
		return Vector2i.ZERO
	return DisplayServer.screen_get_size(0)


## Effective window size read back from the OS (DisplayServer.window_get_size).
## Headless has no real window: reports the dummy Window size instead.
func get_effective_resolution() -> Vector2i:
	if _is_headless():
		var win := get_window()
		if win != null:
			return win.size
		return get_resolution()
	return DisplayServer.window_get_size()


## True when the OS window matches the stored choice. Fullscreen/borderless
## own their size by design, so they always match; windowed compares.
func resolution_matches() -> bool:
	if _mode != "window":
		return true
	return get_effective_resolution() == get_resolution()


## Issues the stored _mode/_res_index to the OS window via DisplayServer.
## Windowed: exact stored size + centered position clamped to the primary
## screen. Borderless: primary-screen size. Fullscreen: mode switch only.
## No readback here: the OS settles asynchronously, so same-tick reads still
## see the old size (that stale read was the 1280x720 self-revert). Boot path.
func _apply_display() -> void:
	if _is_headless():
		var dummy := get_window()
		if dummy == null:
			return
		match _mode:
			"fullscreen":
				dummy.borderless = false
				dummy.mode = Window.MODE_FULLSCREEN
			"borderless":
				dummy.mode = Window.MODE_WINDOWED
				dummy.borderless = true
			_:
				dummy.borderless = false
				dummy.mode = Window.MODE_WINDOWED
				dummy.size = RESOLUTIONS[clampi(_res_index, 0, RESOLUTIONS.size() - 1)]
		return
	match _mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen := _primary_screen_size()
			if screen.x > 0 and screen.y > 0:
				DisplayServer.window_set_position(DisplayServer.screen_get_position(0))
				DisplayServer.window_set_size(screen)
		_:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var wanted: Vector2i = RESOLUTIONS[clampi(_res_index, 0, RESOLUTIONS.size() - 1)]
			DisplayServer.window_set_size(wanted)
			var scr := _primary_screen_size()
			if scr.x > 0 and scr.y > 0:
				var pos := DisplayServer.screen_get_position(0)
				var cx := maxi(0, (scr.x - wanted.x) / 2)
				var cy := maxi(0, (scr.y - wanted.y) / 2)
				DisplayServer.window_set_position(pos + Vector2i(cx, cy))


## Waits for the OS to settle a mode/size request (Windows applies them
## some frames after the call). Headless applies synchronously: no wait.
func _await_os_settle() -> void:
	if _is_headless():
		return
	var tree := get_tree()
	if tree == null:
		return
	for i in 3:
		await tree.process_frame
	await tree.create_timer(0.25).timeout


## Confirmed-apply entry for the menu APLICAR path: stages the pending
## choice in memory, issues it, waits for the OS, verifies by real readback.
## Persists (cfg save) ONLY on confirmed success; on mismatch rolls back to
## the previous working values, re-applies them, and reports the effective
## truth. Never simulates success.
## Returns {"ok": bool, "wanted": Vector2i, "effective": Vector2i}.
func apply_display_choice(wanted_mode: String, wanted_res: int) -> Dictionary:
	if not MODES.has(wanted_mode):
		return {"ok": false, "wanted": get_resolution(), "effective": get_effective_resolution()}
	var want_res := clampi(wanted_res, 0, RESOLUTIONS.size() - 1)
	var prev_mode := _mode
	var prev_res := _res_index
	_mode = wanted_mode
	_res_index = want_res
	_apply_display()
	await _await_os_settle()
	if _mode != "window":
		_save()
		return {"ok": true, "wanted": get_resolution(), "effective": get_effective_resolution()}
	var wanted: Vector2i = RESOLUTIONS[want_res]
	var effective := get_effective_resolution()
	if effective == wanted:
		_save()
		return {"ok": true, "wanted": wanted, "effective": effective}
	push_warning("Settings: OS kept %s for requested %s; stored choice kept." % [effective, wanted])
	_mode = prev_mode
	_res_index = prev_res
	_apply_display()
	await _await_os_settle()
	return {"ok": false, "wanted": wanted, "effective": get_effective_resolution()}
