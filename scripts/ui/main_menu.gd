extends Control
## Definitive main menu (post-FASE 7). Left-anchored composition over the
## imported background art: two-line title, tagline, four Spanish-labelled
## buttons with custom styles + icons, instructions + settings overlays in
## this same scene (FASE 7 overlay pattern kept), staggered fade-in entry
## tween. Keeps the FASE 7 contract: GAMEPLAY_SCENE route with an
## anti-double guard, callable quit_game(). Hover/focus/pressed visuals are
## pure theme state (instant, no tween); the tween is entry-only. W/S menu
## navigation is handled in code so the project Input Map stays untouched
## (pause/gameplay never see ui_up/ui_down from these keys). Scene-local
## flow, no autoloads: menu and gameplay each own their exits.
## Visual polish (pass 2): angular StyleBoxTexture 9-patch frames, left
## icon column with fixed divider, chromatic-aberration title ghosts
## (scripts/ui/title_glitch.gd on each title label), gray/red icon swap on
## hover+focus (same 32px size, no layout shift). Panels, navigation,
## routes and entry tween untouched.
## Instructions polish: two-column panel content (keycaps + four guide
## sections), header X button sharing the close path, open fade + rise
## 0.25s / close fade 0.15s. Menu buttons, navigation and routes untouched.
## Settings polish: 920x600 PanelFrame twin of the instructions panel
## (gear header + X + tech rule), AUDIO section with TechSlider rows +
## percent boxes, PANTALLA section with pending-apply cycling selectors
## (window mode + fixed resolutions stage locally; APLICAR CAMBIOS commits
## via Settings, close-without-apply reverts). Open/close/ESC/
## focus-restore path unchanged.
## Part A (functional settings): audio/display/FPS ownership moved to the
## Settings + Audio autoloads (menu only reads/writes through them); the
## PANTALLA section gains a MOSTRAR FPS row (same row style, OFF/ON
## cycling selector, no redesign); window offers VENTANA/SIN BORDES/
## PANTALLA COMPLETA and resolutions offer 5 sizes; menu buttons play
## subtle real UI sounds (hover/focus/click), panels play open/close
## sweeps, selectors play the select blip, sliders confirm on release (VOLVER/X rely on
## the close sweep so a single player never cuts itself).

const GAMEPLAY_SCENE := "res://scenes/level/sector_01_bloque_0.tscn"

## Gray/red icon pairs by button node name. Same 32x32 raster size, so the
## swap never moves the text. JUGAR maps red/red: always highlighted.
const _ICON_GRAY := {
	"PlayButton": preload("res://assets/ui/icons/play.svg"),
	"HelpButton": preload("res://assets/ui/icons/book.svg"),
	"SettingsButton": preload("res://assets/ui/icons/gear.svg"),
	"QuitButton": preload("res://assets/ui/icons/exit.svg"),
}
const _ICON_RED := {
	"PlayButton": preload("res://assets/ui/icons/play_red.svg"),
	"HelpButton": preload("res://assets/ui/icons/book_red.svg"),
	"SettingsButton": preload("res://assets/ui/icons/gear_red.svg"),
	"QuitButton": preload("res://assets/ui/icons/exit_red.svg"),
}

var _transitioning := false
var _menu_buttons: Array[Button] = []
var _opener: Button = null
## Base position.y per panel while a slide animation is in flight, so an
## interrupted open/close can resume from the true base without drift.
var _panel_base := {}
var _panel_tween: Tween = null

@onready var _background: TextureRect = $Background
@onready var _left: MarginContainer = $LeftMargin
@onready var _title_proto: Label = $LeftMargin/MainVBox/TitleProto
@onready var _title_zero: Label = $LeftMargin/MainVBox/TitleZero
@onready var _tagline: Label = $LeftMargin/MainVBox/Tagline
@onready var _hint: Label = $LeftMargin/MainVBox/NavHint
@onready var _play: Button = $LeftMargin/MainVBox/PlayButton
@onready var _help: Button = $LeftMargin/MainVBox/HelpButton
@onready var _settings_btn: Button = $LeftMargin/MainVBox/SettingsButton
@onready var _quit: Button = $LeftMargin/MainVBox/QuitButton
@onready var _dim: ColorRect = $Dim
@onready var _help_panel: PanelContainer = $InstructionsPanel
@onready var _help_back: Button = $InstructionsPanel/VBox/BackButton
@onready var _help_close: Button = $InstructionsPanel/VBox/HeaderBar/CloseButton
@onready var _settings_panel: PanelContainer = $SettingsPanel
@onready var _settings_back: Button = $SettingsPanel/VBox/SettingsBackButton
@onready var _settings_close: Button = $SettingsPanel/VBox/HeaderBar/SettingsCloseButton
@onready var _master_slider: TechSlider = $SettingsPanel/VBox/AudioSection/MasterRow/MasterSlider
@onready var _music_slider: TechSlider = $SettingsPanel/VBox/AudioSection/MusicRow/MusicSlider
@onready var _sfx_slider: TechSlider = $SettingsPanel/VBox/AudioSection/SfxRow/SfxSlider
@onready var _master_value: Label = $SettingsPanel/VBox/AudioSection/MasterRow/MasterPct/MasterPctLabel
@onready var _music_value: Label = $SettingsPanel/VBox/AudioSection/MusicRow/MusicPct/MusicPctLabel
@onready var _sfx_value: Label = $SettingsPanel/VBox/AudioSection/SfxRow/SfxPct/SfxPctLabel
@onready var _window_selector: Button = $SettingsPanel/VBox/ScreenSection/WindowRow/WindowSelector
@onready var _res_selector: Button = $SettingsPanel/VBox/ScreenSection/ResRow/ResSelector
@onready var _fps_selector: Button = $SettingsPanel/VBox/ScreenSection/FpsRow/FpsSelector
@onready var _apply_button: Button = $SettingsPanel/VBox/ApplyButton
@onready var _pending_hint: Label = $SettingsPanel/VBox/ApplyErrorLabel

## PENDING display state (PROTOCOL ZERO): cycling window/resolution only
## mutates these locals. Nothing is applied nor persisted until APLICAR
## CAMBIOS. The selectors always show the pending choice, never an
## auto-applied value. Synced from the Settings autoload on panel open.
var _mode := "window"
var _res_index := 0
## Synchronous-apply guard (anti-double) + last apply-failure message.
## Empty means no failure to report; the hint label stays hidden then.
var _applying := false
var _apply_error := ""


func _ready() -> void:
	# Part A: Settings autoload (ready before this scene) already applied
	# the saved audio/display/FPS state; the menu only mirrors it.
	# Part B: menu owns its music bed (autoload persists into gameplay).
	Audio.set_music_state(Audio.MusicState.MENU)
	_menu_buttons = [_play, _help, _settings_btn, _quit]
	_help_panel.visible = false
	_settings_panel.visible = false
	_dim.visible = false
	_left.visible = true
	_play.pressed.connect(_on_play_pressed)
	_help.pressed.connect(_show_instructions)
	_settings_btn.pressed.connect(_show_settings)
	_quit.pressed.connect(quit_game)
	for button in _menu_buttons:
		button.mouse_entered.connect(_on_button_highlight.bind(button))
		button.mouse_exited.connect(_on_button_highlight.bind(button))
		button.focus_entered.connect(_on_button_highlight.bind(button))
		button.focus_exited.connect(_on_button_highlight.bind(button))
		button.mouse_entered.connect(_on_menu_hover_sound)
		button.focus_entered.connect(_on_menu_focus_sound)
		button.pressed.connect(_on_menu_click_sound)
		_refresh_button_icon(button)
	_help_back.pressed.connect(_close_instructions)
	_help_close.pressed.connect(_close_instructions)
	_settings_back.pressed.connect(_close_settings)
	_settings_close.pressed.connect(_close_settings)
	_window_selector.pressed.connect(_on_window_selector)
	_res_selector.pressed.connect(_on_res_selector)
	_fps_selector.pressed.connect(_on_fps_selector)
	_apply_button.pressed.connect(_on_apply_pressed)
	_sync_sliders()
	_sync_display()
	_sync_fps()
	_master_slider.value_changed.connect(_on_master_changed)
	_music_slider.value_changed.connect(_on_music_changed)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_master_slider.drag_ended.connect(_on_volume_drag_ended)
	_music_slider.drag_ended.connect(_on_volume_drag_ended)
	_sfx_slider.drag_ended.connect(_on_volume_drag_ended)
	_play_entry()
	_play.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if _is_panel_open():
		if event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_panels()
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.physical_keycode:
			KEY_W:
				get_viewport().set_input_as_handled()
				_move_focus(-1)
			KEY_S:
				get_viewport().set_input_as_handled()
				_move_focus(1)


func _on_play_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	# Part B: crossfade to exploration before leaving (autoload voices
	# survive the scene change, so the fade continues into gameplay).
	Audio.set_music_state(Audio.MusicState.EXPLORATION)
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	tree.change_scene_to_file(GAMEPLAY_SCENE)


## Callable target of SALIR (kept separate so probes can check the wiring
## via has_method + button connection without quitting the test process).
func quit_game() -> void:
	get_tree().quit()


## Red icon while hovered or focused, gray otherwise. Hover and focus
## are OR-ed so losing one while keeping the other stays highlighted.
func _on_button_highlight(button: Button) -> void:
	_refresh_button_icon(button)


func _refresh_button_icon(button: Button) -> void:
	var gray := _ICON_GRAY[button.name] as Texture2D
	var red := _ICON_RED[button.name] as Texture2D
	if gray == null or red == null:
		return
	if button.is_hovered() or button.has_focus():
		button.icon = red
	else:
		button.icon = gray


## Resyncs all four menu icons from live Godot state (has_focus +
## is_hovered). Never simulates hover; only reads the real state, so a
## missed mouse_exited/focus_exited while the menu row was hidden cannot
## leave a stale red icon behind.
func _refresh_all_button_icons() -> void:
	for button in _menu_buttons:
		_refresh_button_icon(button)


func _show_instructions() -> void:
	_open_panel(_help_panel, _help_back, _help)


func _show_settings() -> void:
	_sync_sliders()
	_clear_apply_error()
	_sync_display()
	_sync_fps()
	_open_panel(_settings_panel, _settings_back, _settings_btn)


func _open_panel(panel: PanelContainer, back_button: Button, opener: Button) -> void:
	_opener = opener
	Audio.play_ui("panel_open")
	_kill_panel_tween()
	_left.visible = false
	_help_panel.visible = panel == _help_panel
	_settings_panel.visible = panel == _settings_panel
	_dim.visible = true
	# Fade + slight rise-in over 0.25s. The base is stored so a close/open
	# inside the animation window resumes without position drift.
	var base_y := panel.position.y
	if _panel_base.has(panel):
		base_y = float(_panel_base[panel])
		panel.position.y = base_y
	_panel_base[panel] = base_y
	panel.position.y = base_y + 16.0
	panel.modulate.a = 0.0
	back_button.grab_focus()
	_refresh_all_button_icons()
	_panel_tween = create_tween()
	_panel_tween.set_parallel(true)
	_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(panel, "position:y", base_y, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tween.set_parallel(false)
	_panel_tween.tween_callback(_clear_panel_base.bind(panel))


## Single close entry shared by VOLVER/X/ESC (dispatches to the open
## panel's per-panel closer so every exit path runs the same logic).
func _close_panels() -> void:
	var open_panel := _open_panel_or_null()
	if open_panel == null:
		return
	_close_panel(open_panel)


## Per-panel closers: each panel's VOLVER + X share exactly one of these;
## ESC funnels through _close_panels into the same _close_panel core.
func _close_instructions() -> void:
	_close_panel(_help_panel)


func _close_settings() -> void:
	_close_panel(_settings_panel)


func _close_panel(panel: PanelContainer) -> void:
	if not panel.visible:
		return
	if panel == _settings_panel:
		# Closing without applying reverts the selectors to the applied
		# choice. Cycling never called Settings, so nothing persisted
		# halfway; this only discards the unapplied pending locals.
		_revert_pending()
	Audio.play_ui("panel_close")
	_kill_panel_tween()
	_panel_tween = create_tween()
	_panel_tween.tween_property(panel, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.tween_callback(_finish_close)


## Settles the stored slide base once the open animation completes.
func _clear_panel_base(panel: PanelContainer) -> void:
	_panel_base.erase(panel)


func _open_panel_or_null() -> PanelContainer:
	if _help_panel.visible:
		return _help_panel
	if _settings_panel.visible:
		return _settings_panel
	return null


func _kill_panel_tween() -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = null


## Hides both overlays after the close fade and restores initial focus to
## JUGAR. The opener is NOT refocused: its theme focus style is the red
## frame (BtnTexRed + red icon via has_focus), so restoring focus there is
## what left the opener looking selected. Releasing first clears any stale
## hover/focus latch from the hidden menu row, then icons resync from live
## state (has_focus + is_hovered) with no simulated hover.
func _finish_close() -> void:
	_panel_tween = null
	for node in [_help_panel, _settings_panel]:
		var panel := node as PanelContainer
		if _panel_base.has(panel):
			panel.position.y = float(_panel_base[panel])
			_panel_base.erase(panel)
		panel.modulate.a = 1.0
		panel.visible = false
	_dim.visible = false
	_left.visible = true
	_opener = null
	get_viewport().gui_release_focus()
	_play.grab_focus()
	_refresh_all_button_icons()


func _is_panel_open() -> bool:
	return _help_panel.visible or _settings_panel.visible


## Circular W/S navigation over the four menu buttons. ENTER/SPACE selection
## and arrow-key movement use the default ui_accept/ui_up/ui_down routing
## through the tscn focus neighbors; this only adds the physical W/S keys.
func _move_focus(direction: int) -> void:
	if _menu_buttons.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var index := _menu_buttons.find(focused)
	if index < 0:
		_play.grab_focus()
		return
	index = posmod(index + direction, _menu_buttons.size())
	_menu_buttons[index].grab_focus()


## Subtle menu feedback through the Audio autoload (60 ms anti-spam inside).
func _on_menu_hover_sound() -> void:
	Audio.play_ui("hover")


func _on_menu_focus_sound() -> void:
	Audio.play_ui("focus")


func _on_menu_click_sound() -> void:
	Audio.play_ui("click")


## Confirm blip when a volume drag is released (audible level feedback).
func _on_volume_drag_ended() -> void:
	Audio.play_ui("confirm")


func _sync_sliders() -> void:
	_master_slider.set_value_no_signal(Settings.get_master())
	_music_slider.set_value_no_signal(Settings.get_music())
	_sfx_slider.set_value_no_signal(Settings.get_sfx())
	_refresh_value_labels()


func _refresh_value_labels() -> void:
	_master_value.text = "%d%%" % int(_master_slider.value)
	_music_value.text = "%d%%" % int(_music_slider.value)
	_sfx_value.text = "%d%%" % int(_sfx_slider.value)


func _on_master_changed(value: float) -> void:
	Settings.set_master(value)
	_refresh_value_labels()


func _on_music_changed(value: float) -> void:
	Settings.set_music(value)
	_refresh_value_labels()


func _on_sfx_changed(value: float) -> void:
	Settings.set_sfx(value)
	_refresh_value_labels()


## Pulls the APPLIED display choice into the pending selectors (panel
## open + revert paths). The failure hint is left untouched: only cycling
## or reopening clears a reported error.
func _sync_display() -> void:
	_mode = Settings.get_display_mode()
	_res_index = Settings.get_resolution_index()
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


## Cycles VENTANA -> SIN BORDES -> PANTALLA COMPLETA into the PENDING
## state only: no apply, no persist. The selector shows the pending mode.
func _on_window_selector() -> void:
	Audio.play_ui("select")
	var modes := Settings.MODES
	_mode = modes[(modes.find(_mode) + 1) % modes.size()]
	_clear_apply_error()
	_sync_pending_ui()


## Cycles the five fixed resolutions into the PENDING state only: no
## apply, no persist. The selector shows the pending resolution.
func _on_res_selector() -> void:
	Audio.play_ui("select")
	_res_index = (_res_index + 1) % Settings.RESOLUTIONS.size()
	_clear_apply_error()
	_sync_pending_ui()


## True when the pending choice differs from the applied Settings state.
func _has_pending() -> bool:
	return _mode != Settings.get_display_mode() or _res_index != Settings.get_resolution_index()


## Refreshes the pending-only UI: selectors (pending text) + apply button
## state. Enabled + "APLICAR CAMBIOS" is the pending indicator (style
## branch); disabled + "YA APLICADO" means nothing pending.
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


## Discards the pending choice: selectors return to the applied Settings
## state (close-without-apply path). Never touches Settings or the cfg.
func _revert_pending() -> void:
	_clear_apply_error()
	_sync_display()


func _clear_apply_error() -> void:
	_apply_error = ""
	_pending_hint.visible = false


## Applies the pending choice through Settings.apply_display_choice: real
## OS readback after settle frames, cfg persisted only on confirmation.
## Selectors keep showing the pending choice until the result lands, then
## sync to the applied (kept-on-failure) state. Never simulates success.
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
		push_warning("ApplyButton: OS kept %s for requested %s; kept %s %s." % [result.get("effective", kept), result.get("wanted", kept), kept, kept_mode])
		Audio.play_ui("error")
	_sync_display()
	_settings_back.grab_focus()


## Pulls the stored FPS flag into the OFF/ON cycling selector.
func _sync_fps() -> void:
	_refresh_fps_selector()


func _refresh_fps_selector() -> void:
	if Settings.is_show_fps():
		_fps_selector.text = "‹ ON ›"
	else:
		_fps_selector.text = "‹ OFF ›"


## Toggles the FPS overlay (immediate, persisted by Settings).
func _on_fps_selector() -> void:
	Audio.play_ui("select")
	Settings.set_show_fps(not Settings.is_show_fps())
	_refresh_fps_selector()


## Entry animation only (0.8s total): background fade, then staggered
## fade of title, tagline and buttons. Nothing heavy: no shaders,
## no particles, modulate-only tweens.
func _play_entry() -> void:
	var staged: Array[CanvasItem] = [
		_title_proto, _title_zero, _tagline,
		_play, _help, _settings_btn, _quit, _hint,
	]
	_background.modulate.a = 0.0
	for item in staged:
		item.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_background, "modulate:a", 1.0, 0.4)
	var delay := 0.1
	for item in staged:
		tween.tween_property(item, "modulate:a", 1.0, 0.3).set_delay(delay)
		delay += 0.05
