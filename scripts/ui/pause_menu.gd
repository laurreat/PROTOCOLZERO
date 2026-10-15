extends CanvasLayer
## Pause overlay. Instanced by the Sector 01 level next to the HUD; the panel
## is the only visual child so the layer stays up while hidden. ESC ("pause"
## action) toggles it ONLY while the run is live (level group "game" +
## is_playing(), never in WON/LOST) and never over the HUD reading modal or
## the win/lose overlays. Visual language cloned from the main menu
## (PanelFrame, BtnTex*, X, KeyCaps, icons, // tags): CONTINUAR resumes,
## REINICIAR reloads, VOLVER AL MENÚ returns (paused=false before every scene
## change). CONFIGURACIÓN is the full settings panel (audio sliders apply
## instantly through the Settings autoload; display/FPS use the same
## pending + confirmed-apply path as the main menu, closing without applying
## reverts). INSTRUCCIONES is the static help clone (DASH, not run: SHIFT
## fires the tactical dash). ESC or X over a subpanel closes the subpanel,
## not the pause. No open/close tweens by design: the tree is paused, so
## robustness beats animation. This layer runs with process_mode ALWAYS so
## resume/retry input survives the tree pause. Coexists with the HUD win/lose
## overlays: the states are exclusive, so no input double-handling.
## Scene-local flow, no autoload writes (menu, HUD end panels and pause each
## own their exits).

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

var _open := false
var _transitioning := false
## Subpanel abierto: "" (ninguno), "config" o "help".
var _sub := ""
var _sub_opener: Button = null

## Display pending state (main-menu path): selectors stage locally, apply
## confirms through Settings, close-without-apply reverts. Audio sliders
## apply instantly instead (same as the main menu).
var _mode := "window"
var _res_index := 0
var _applying := false
var _apply_error := ""

@onready var _panel: PanelContainer = $PausePanel
@onready var _resume: Button = $PausePanel/VBox/ResumeButton
@onready var _restart: Button = $PausePanel/VBox/RestartButton
@onready var _config_btn: Button = $PausePanel/VBox/ConfigButton
@onready var _help_btn: Button = $PausePanel/VBox/HelpButton
@onready var _menu: Button = $PausePanel/VBox/MenuButton
@onready var _config_panel: PanelContainer = $ConfigPanel
@onready var _help_panel: PanelContainer = $HelpPanel
@onready var _master: TechSlider = $ConfigPanel/VBox/AudioSection/MasterRow/MasterSlider
@onready var _master_value: Label = $ConfigPanel/VBox/AudioSection/MasterRow/MasterPct/MasterPctLabel
@onready var _music: TechSlider = $ConfigPanel/VBox/AudioSection/MusicRow/MusicSlider
@onready var _music_value: Label = $ConfigPanel/VBox/AudioSection/MusicRow/MusicPct/MusicPctLabel
@onready var _sfx: TechSlider = $ConfigPanel/VBox/AudioSection/SfxRow/SfxSlider
@onready var _sfx_value: Label = $ConfigPanel/VBox/AudioSection/SfxRow/SfxPct/SfxPctLabel
@onready var _config_back: Button = $ConfigPanel/VBox/ConfigBack
@onready var _config_x: Button = $ConfigPanel/VBox/HeaderBar/ConfigX
@onready var _help_back: Button = $HelpPanel/VBox/HelpBack
@onready var _help_x: Button = $HelpPanel/VBox/HeaderBar/HelpX
@onready var _window_selector: Button = $ConfigPanel/VBox/ScreenSection/WindowRow/WindowSelector
@onready var _res_selector: Button = $ConfigPanel/VBox/ScreenSection/ResRow/ResSelector
@onready var _fps_selector: Button = $ConfigPanel/VBox/ScreenSection/FpsRow/FpsSelector
@onready var _apply_button: Button = $ConfigPanel/VBox/ApplyButton
@onready var _pending_hint: Label = $ConfigPanel/VBox/ApplyErrorLabel


func _ready() -> void:
	_panel.visible = false
	_config_panel.visible = false
	_help_panel.visible = false
	_resume.pressed.connect(resume_game)
	_restart.pressed.connect(_on_restart_pressed)
	_config_btn.pressed.connect(_show_config)
	_help_btn.pressed.connect(_show_help)
	_menu.pressed.connect(_on_menu_pressed)
	_config_back.pressed.connect(_close_sub)
	_config_x.pressed.connect(_close_sub)
	_help_back.pressed.connect(_close_sub)
	_help_x.pressed.connect(_close_sub)
	for b in [_resume, _restart, _config_btn, _help_btn, _menu, _config_back, _config_x, _help_back, _help_x, _apply_button, _window_selector, _res_selector, _fps_selector]:
		b.pressed.connect(_on_button_click_sound)
	_master.value_changed.connect(_on_master_changed)
	_music.value_changed.connect(_on_music_changed)
	_sfx.value_changed.connect(_on_sfx_changed)
	_master.drag_ended.connect(_on_volume_drag_ended)
	_music.drag_ended.connect(_on_volume_drag_ended)
	_sfx.drag_ended.connect(_on_volume_drag_ended)
	_window_selector.pressed.connect(_on_window_selector)
	_res_selector.pressed.connect(_on_res_selector)
	_fps_selector.pressed.connect(_on_fps_selector)
	_apply_button.pressed.connect(_on_apply_pressed)
	_sync_audio()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if _sub != "":
		get_viewport().set_input_as_handled()
		_close_sub()
	elif _open:
		get_viewport().set_input_as_handled()
		resume_game()
	elif _is_playing() and not _hud_busy():
		get_viewport().set_input_as_handled()
		open_menu()


func is_open() -> bool:
	return _open


func open_menu() -> void:
	if _open or not _is_playing() or _hud_busy():
		return
	_open = true
	_sub = ""
	_panel.visible = true
	get_tree().paused = true
	_set_ducked(true)
	_resume.grab_focus()


func resume_game() -> void:
	if not _open:
		return
	_open = false
	_sub = ""
	_panel.visible = false
	_config_panel.visible = false
	_help_panel.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	_set_ducked(false)


func _on_restart_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	_set_ducked(false)
	tree.reload_current_scene()


func _on_menu_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	_set_ducked(false)
	tree.change_scene_to_file(MENU_SCENE)


## Subpaneles: ocultan el menú raíz mientras están abiertos; VOLVER, X o ESC
## los cierra y devuelve el foco al botón que los abrió. Cerrar config sin
## aplicar revierte el pending (mismo contrato que el menú principal).
func _show_config() -> void:
	if not _open or _sub != "":
		return
	_open_sub("config", _config_btn)
	_sync_audio()
	_clear_apply_error()
	_sync_display()
	_sync_fps()
	_config_back.grab_focus()


func _show_help() -> void:
	if not _open or _sub != "":
		return
	_open_sub("help", _help_btn)
	_help_back.grab_focus()


func _open_sub(which: String, opener: Button) -> void:
	if not _open or _sub != "":
		return
	_sub = which
	_sub_opener = opener
	_panel.visible = false
	Audio.play_ui("panel_open")
	if which == "config":
		_config_panel.visible = true
	else:
		_help_panel.visible = true


func _close_sub() -> void:
	if _sub == "":
		return
	if _sub == "config":
		_revert_pending()
	Audio.play_ui("panel_close")
	_sub = ""
	_config_panel.visible = false
	_help_panel.visible = false
	_panel.visible = true
	if _sub_opener != null and is_instance_valid(_sub_opener):
		_sub_opener.grab_focus()
	_sub_opener = null


## Audio: la pausa solo LEE y LLAMA al dueño (Settings autoload, que guarda
## al instante). Sin autoload (sonda aislada) es no-op seguro.
func _settings() -> Node:
	return get_node_or_null("/root/Settings")


func _sync_audio() -> void:
	var s := _settings()
	if s == null:
		return
	_master.set_value_no_signal(s.get_master())
	_music.set_value_no_signal(s.get_music())
	_sfx.set_value_no_signal(s.get_sfx())
	_refresh_value_labels()


func _refresh_value_labels() -> void:
	_master_value.text = "%d%%" % int(_master.value)
	_music_value.text = "%d%%" % int(_music.value)
	_sfx_value.text = "%d%%" % int(_sfx.value)


func _on_master_changed(v: float) -> void:
	var s := _settings()
	if s != null:
		s.set_master(v)
	_refresh_value_labels()


func _on_music_changed(v: float) -> void:
	var s := _settings()
	if s != null:
		s.set_music(v)
	_refresh_value_labels()


func _on_sfx_changed(v: float) -> void:
	var s := _settings()
	if s != null:
		s.set_sfx(v)
	_refresh_value_labels()


func _on_volume_drag_ended() -> void:
	Audio.play_ui("confirm")


## Display pending (camino del menú principal): los selectores ciclan estado
## local sin aplicar ni persistir; APLICAR confirma con readback real del SO.
func _sync_display() -> void:
	var s := _settings()
	if s == null:
		return
	_mode = s.get_display_mode()
	_res_index = s.get_resolution_index()
	_refresh_selectors()
	_refresh_apply_ui()


func _refresh_selectors() -> void:
	match _mode:
		"borderless":
			_window_selector.text = "‹ SIN BORDES ›"
		"fullscreen":
			_window_selector.text = "‹ PANTALLA COMPLETA ›"
		_:
			_window_selector.text = "‹ VENTANA ›"
	var res: Vector2i = Settings.RESOLUTIONS[_res_index]
	_res_selector.text = "‹ %d × %d ›" % [res.x, res.y]


func _on_window_selector() -> void:
	Audio.play_ui("select")
	var modes := Settings.MODES
	_mode = modes[(modes.find(_mode) + 1) % modes.size()]
	_clear_apply_error()
	_sync_pending_ui()


func _on_res_selector() -> void:
	Audio.play_ui("select")
	_res_index = (_res_index + 1) % Settings.RESOLUTIONS.size()
	_clear_apply_error()
	_sync_pending_ui()


func _has_pending() -> bool:
	var s := _settings()
	if s == null:
		return false
	return _mode != s.get_display_mode() or _res_index != s.get_resolution_index()


func _sync_pending_ui() -> void:
	_refresh_selectors()
	_refresh_apply_ui()


func _refresh_apply_ui() -> void:
	var pending := _has_pending()
	_apply_button.disabled = (not pending) or _applying
	if pending:
		_apply_button.text = "APLICAR CAMBIOS"
	else:
		_apply_button.text = "YA APLICADO"


func _revert_pending() -> void:
	_clear_apply_error()
	_sync_display()


func _clear_apply_error() -> void:
	_apply_error = ""
	_pending_hint.visible = false


func _on_apply_pressed() -> void:
	if _applying or not _has_pending():
		return
	_applying = true
	_refresh_apply_ui()
	var want_mode := _mode
	var want_res := _res_index
	var result: Dictionary = await Settings.apply_display_choice(want_mode, want_res)
	_applying = false
	if bool(result.get("ok", false)):
		_clear_apply_error()
		Audio.play_ui("confirm")
	else:
		var kept: Vector2i = Settings.get_resolution()
		var kept_mode := Settings.get_display_mode()
		var kept_label := "VENTANA"
		match kept_mode:
			"borderless":
				kept_label = "SIN BORDES"
			"fullscreen":
				kept_label = "PANTALLA COMPLETA"
		_apply_error = "NO SE PUDO APLICAR · SE MANTIENE %d×%d %s" % [kept.x, kept.y, kept_label]
		_pending_hint.text = _apply_error
		_pending_hint.visible = true
		push_warning("PauseMenu ApplyButton: OS kept %s for requested %s." % [result.get("effective", kept), result.get("wanted", kept)])
		Audio.play_ui("error")
	_sync_display()
	_config_back.grab_focus()


func _sync_fps() -> void:
	_refresh_fps_selector()


func _refresh_fps_selector() -> void:
	var s := _settings()
	if s == null:
		return
	if s.is_show_fps():
		_fps_selector.text = "‹ ON ›"
	else:
		_fps_selector.text = "‹ OFF ›"


func _on_fps_selector() -> void:
	Audio.play_ui("select")
	var s := _settings()
	if s == null:
		return
	s.set_show_fps(not s.is_show_fps())
	_refresh_fps_selector()


func _on_button_click_sound() -> void:
	Audio.play_ui("click")


## Routes the pause duck hook to the Audio autoload (part A). Dynamic lookup
## keeps this scene independently testable when the autoload is absent.
func _set_ducked(value: bool) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("set_ducked"):
		audio.call("set_ducked", value)


## HUD ocupado: modal de lectura o paneles win/lose. La pausa nunca se abre
## encima de ellos (doble pausa + robo de ESC).
func _hud_busy() -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	var hud: Node = tree.get_first_node_in_group("hud")
	if hud == null:
		return false
	if hud.has_method("is_reading") and bool(hud.call("is_reading")):
		return true
	if hud.has_method("is_win_visible") and bool(hud.call("is_win_visible")):
		return true
	if hud.has_method("is_lose_visible") and bool(hud.call("is_lose_visible")):
		return true
	return false


func _is_playing() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var game := tree.get_first_node_in_group("game")
	if game != null and game.has_method("is_playing"):
		return bool(game.call("is_playing"))
	return false
