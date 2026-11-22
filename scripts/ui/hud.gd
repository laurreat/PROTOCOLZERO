extends CanvasLayer
## Sober HUD (FASE 6). Lives under its own CanvasLayer so it stays independent
## of the world camera (anchors + offsets only, no containers needed for four
## fixed labels). Owns the two end-of-run overlays as well, so pause + input
## stay in one place: this layer runs with process_mode ALWAYS and only the
## overlay input path needs it (message fade + pulse polling are pause-safe).
## Late-listener-safe: on ready it pulls current energy/objective snapshots
## and then subscribes to their change signals (per programming-patterns:
## signals are not stored state).

const MESSAGE_TIME := 2.5
const FADE_TIME := 0.5

const COLOR_POWER_ON := Color(0.35, 0.9, 0.45)
const COLOR_POWER_OFF := Color(0.9, 0.3, 0.3)
const COLOR_PULSE_READY := Color(0.35, 0.9, 0.45)
const COLOR_PULSE_WAIT := Color(0.75, 0.75, 0.8)
## CAM-06: outcome colours for interaction feedback (✓ ok / ✕ fail / ! warn).
const COLOR_MSG_INFO := Color(0.92, 0.94, 0.97)
const COLOR_MSG_OK := Color(0.45, 0.95, 0.6)
const COLOR_MSG_FAIL := Color(1.0, 0.45, 0.4)
const COLOR_MSG_WARN := Color(1.0, 0.8, 0.35)
const COLOR_POWER_HINT_ON := Color(0.45, 0.85, 0.6)
const COLOR_POWER_HINT_OFF := Color(0.76, 0.46, 0.46)
## CAM-02: the controls card shows itself at run start, then fades out.
const CONTROLS_AUTOHIDE := 8.0

## FASE 7: Esc on the end panels now goes to the real menu (main_scene).

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

var _msg_left := 0.0
var _objective_seen := false
var _transitioning := false
var _controls_left := 0.0

@onready var _energy: Label = $EnergyLabel
@onready var _objective: Label = $ObjectiveLabel
@onready var _pulse: Label = $PulseLabel
@onready var _dash: Label = $DashLabel
@onready var _message: Label = $MessageLabel
@onready var _win: PanelContainer = $WinPanel
@onready var _win_time: Label = $WinPanel/VBox/WinTime
@onready var _lose: PanelContainer = $LosePanel
@onready var _read: PanelContainer = $ReadPanel
@onready var _read_title: Label = $ReadPanel/VBox/ReadTitle
@onready var _read_meta: Label = $ReadPanel/VBox/ReadMeta
@onready var _read_scroll: ScrollContainer = $ReadPanel/VBox/ReadScroll
@onready var _read_body: Label = $ReadPanel/VBox/ReadScroll/ReadBody
@onready var _read_page: Label = $ReadPanel/VBox/ReadPage
@onready var _read_badge: Label = $ReadPanel/VBox/ReadRead
@onready var _read_hint: Label = $ReadPanel/VBox/ReadHint
@onready var _power_hint: Label = $PowerHint
@onready var _threat: Label = $ThreatChip
@onready var _controls: PanelContainer = $ControlsCard
@onready var _help_hint: Label = $HelpHint

var _reading := false


func _ready() -> void:
	add_to_group("hud")
	_message.visible = false
	_win.visible = false
	_lose.visible = false
	if _read != null:
		_read.visible = false
	if _threat != null:
		_threat.text = ""
	# CAM-02: brief controls reminder on run start; H brings it back.
	show_controls(CONTROLS_AUTOHIDE)
	var tree := get_tree()
	if tree != null:
		var energy := tree.get_first_node_in_group("energy_system")
		if energy != null:
			set_energy(energy.is_on())
			if energy.has_signal("energy_changed"):
				energy.connect("energy_changed", set_energy)
		var objectives := tree.get_first_node_in_group("objective_manager")
		if objectives != null:
			set_objective(objectives.get_current_objective())
			if objectives.has_signal("objective_changed"):
				objectives.connect("objective_changed", set_objective)


func _process(delta: float) -> void:
	_tick_message(delta)
	_tick_controls(delta)
	_tick_pulse()
	_tick_dash()


func _unhandled_input(event: InputEvent) -> void:
	# Cierre del modal de lectura (solo E: Esc queda para la pausa).
	if _reading:
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
			hide_document()
			get_viewport().set_input_as_handled()
		return
	# CAM-02: H toggles the in-run controls card (never while reading a doc).
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_H:
			get_viewport().set_input_as_handled()
			toggle_controls()
			return
	# The event is consumed BEFORE _restart(): reload_current_scene() pulls
	# the old scene out of the tree, so get_viewport() would be null after.
	if _win.visible:
		if event.is_action_pressed(&"ui_accept"):
			get_viewport().set_input_as_handled()
			_restart()
		elif event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
			_go_to_menu()
	elif _lose.visible:
		if event.is_action_pressed(&"ui_accept"):
			get_viewport().set_input_as_handled()
			_restart()
		elif event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
			_go_to_menu()
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R:
				get_viewport().set_input_as_handled()
				_restart()
			elif event.keycode == KEY_M:
				get_viewport().set_input_as_handled()
				_go_to_menu()


func set_energy(on: bool) -> void:
	if _energy == null:
		return
	_energy.text = "POWER: ON" if on else "POWER: OFF"
	_energy.add_theme_color_override("font_color", COLOR_POWER_ON if on else COLOR_POWER_OFF)
	# CAM-03: the subtitle states what the grid feeds, not just on/off.
	if _power_hint != null:
		_power_hint.text = "Grid online — terminals, doors and ZERO energized" if on else "No grid power — generator offline"
		_power_hint.add_theme_color_override("font_color", COLOR_POWER_HINT_ON if on else COLOR_POWER_HINT_OFF)


func set_objective(text: String) -> void:
	if _objective == null:
		return
	# CAM-07: explicit position in the 5-step sequence ("OBJECTIVE 2/5 · ...").
	var progress := _objective_progress()
	if int(progress[1]) > 0:
		_objective.text = "OBJECTIVE %d/%d · %s" % [int(progress[0]), int(progress[1]), text]
	else:
		_objective.text = text
	# Announce rotations after the initial snapshot, so a late HUD ready does
	# not spam the message label on boot.
	if _objective_seen:
		show_feedback("OBJECTIVE COMPLETE — next: %s" % text, "ok")
	_objective_seen = true


## Reads progress from the ObjectiveManager (group lookup, no new signal).
func _objective_progress() -> Array:
	var tree := get_tree()
	if tree == null:
		return [0, 0]
	var manager := tree.get_first_node_in_group("objective_manager")
	if manager != null and manager.has_method("get_current_index") and manager.has_method("get_total"):
		return [int(manager.call("get_current_index")) + 1, int(manager.call("get_total"))]
	return [0, 0]


## CAM-05: one-line security readout driven by the level coordinator.
func set_threat(text: String, color: Color) -> void:
	if _threat == null:
		return
	_threat.text = text
	_threat.add_theme_color_override("font_color", color)


## CAM-02: show (optionally auto-hiding after `seconds`) / hide the card.
func show_controls(seconds := 0.0) -> void:
	if _controls == null:
		return
	_controls.visible = true
	_controls.modulate.a = 1.0
	_controls_left = seconds


func hide_controls() -> void:
	if _controls == null:
		return
	_controls.visible = false
	_controls_left = 0.0


func toggle_controls() -> void:
	if _controls == null:
		return
	if _controls.visible:
		hide_controls()
	else:
		show_controls(0.0)


func is_controls_visible() -> bool:
	return _controls != null and _controls.visible


func set_pulse(cooldown_left: float) -> void:
	if _pulse == null:
		return
	if cooldown_left <= 0.0:
		_pulse.text = "PULSE READY"
		_pulse.add_theme_color_override("font_color", COLOR_PULSE_READY)
	else:
		_pulse.text = "PULSE %.1fs" % cooldown_left
		_pulse.add_theme_color_override("font_color", COLOR_PULSE_WAIT)


## Dash (C5): reutiliza el lenguaje del pulse en el espacio existente.
func set_dash(cooldown_left: float) -> void:
	if _dash == null:
		return
	if cooldown_left <= 0.0:
		_dash.text = "DASH READY"
		_dash.add_theme_color_override("font_color", COLOR_PULSE_READY)
	else:
		_dash.text = "DASH %.1fs" % cooldown_left
		_dash.add_theme_color_override("font_color", COLOR_PULSE_WAIT)


func show_message(text: String) -> void:
	if _message == null:
		return
	_message.text = text
	_message.add_theme_color_override("font_color", COLOR_MSG_INFO)
	_message.visible = true
	_message.modulate.a = 1.0
	_msg_left = MESSAGE_TIME


## CAM-06: same transient line, but outcome-coloured and prefixed, so a
## successful action and a denied one never look alike.
func show_feedback(text: String, kind := "info") -> void:
	var prefix := ""
	var color := COLOR_MSG_INFO
	match kind:
		"ok":
			prefix = "✓ "
			color = COLOR_MSG_OK
		"fail":
			prefix = "✕ "
			color = COLOR_MSG_FAIL
		"warn":
			prefix = "! "
			color = COLOR_MSG_WARN
	show_message(prefix + text)
	if _message != null:
		_message.add_theme_color_override("font_color", color)


func show_win(elapsed: float) -> void:
	_win_time.text = "Time %s" % format_time(elapsed)
	_win.visible = true


func show_lose() -> void:
	_lose.visible = true


## Modal de lectura: titulo + cuerpo + PÁGINA N/TOTAL. Pausa el arbol;
## el HUD es ALWAYS asi que sigue recibiendo input para cerrar con E.
## show_lore es la vía principal (diccionario ES con metadatos); show_document
## queda como fallback compatible (mismo bloqueo, pausa y cierre).
func show_lore(doc: Dictionary, page: int, total: int) -> void:
	if _read == null:
		return
	_read_title.text = str(doc.get("titulo", "DOCUMENTO"))
	var meta := "%s · %s · %s" % [
		str(doc.get("tipo", "Archivo")),
		str(doc.get("autor", "Sector 01")),
		str(doc.get("fecha", "")),
	]
	_read_meta.text = meta
	var body := str(doc.get("cuerpo", ""))
	var datos := str(doc.get("datos", ""))
	var pista := str(doc.get("pista", ""))
	if datos != "":
		body += "\n\nDATOS: " + datos
	if pista != "":
		body += "\nPISTA: " + pista
	_read_body.text = body
	_read_page.text = "PÁGINA %d / %d" % [page, total]
	_read_badge.text = "✓ LEÍDO"
	_read_hint.text = "E: cerrar · Rueda: desplazar texto largo"
	if _read_scroll != null:
		_read_scroll.scroll_vertical = 0
	_read.visible = true
	_reading = true
	var tree := get_tree()
	if tree != null:
		tree.paused = true


func show_document(title: String, lines: Array[String], page: int, total: int) -> void:
	if _read == null:
		return
	_read_title.text = title
	_read_meta.text = "Archivo del Sector 01"
	_read_body.text = "\n".join(lines)
	_read_page.text = "PÁGINA %d / %d" % [page, total]
	_read_badge.text = "✓ LEÍDO"
	_read_hint.text = "E: cerrar · Rueda: desplazar texto largo"
	if _read_scroll != null:
		_read_scroll.scroll_vertical = 0
	_read.visible = true
	_reading = true
	var tree := get_tree()
	if tree != null:
		tree.paused = true


func hide_document() -> void:
	_reading = false
	if _read != null:
		_read.visible = false
	var tree := get_tree()
	if tree != null:
		tree.paused = false


func is_reading() -> bool:
	return _reading


func is_win_visible() -> bool:
	return _win != null and _win.visible


func is_lose_visible() -> bool:
	return _lose != null and _lose.visible


static func format_time(t: float) -> String:
	var total := maxi(0, int(t))
	return "%d:%02d" % [total / 60, total % 60]


func _tick_controls(delta: float) -> void:
	if _controls == null or _controls_left <= 0.0:
		return
	_controls_left = maxf(0.0, _controls_left - delta)
	if _controls_left <= 0.0:
		hide_controls()
	elif _controls_left < FADE_TIME:
		_controls.modulate.a = _controls_left / FADE_TIME


func _tick_message(delta: float) -> void:
	if _msg_left <= 0.0 or _message == null:
		return
	_msg_left = maxf(0.0, _msg_left - delta)
	if _msg_left <= 0.0:
		_message.visible = false
	elif _msg_left < FADE_TIME:
		_message.modulate.a = _msg_left / FADE_TIME


func _tick_pulse() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var device := tree.get_first_node_in_group("pulse_device")
	if device != null and device.has_method("get_cooldown_remaining"):
		set_pulse(device.get_cooldown_remaining())


func _tick_dash() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var player := tree.get_first_node_in_group("player")
	if player != null and player.has_method("get_dash_cooldown_remaining"):
		set_dash(player.get_dash_cooldown_remaining())


func _restart() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	tree.reload_current_scene()


## FASE 7 menu exit (win/lose panels): single guarded transition, paused=false
## first so the menu boots unpaused. Mirrors the pause overlay exit.
func _go_to_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	tree.change_scene_to_file(MENU_SCENE)
