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

## FASE 7: Esc on the end panels now goes to the real menu (main_scene).

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"

var _msg_left := 0.0
var _objective_seen := false
var _transitioning := false

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

var _reading := false


func _ready() -> void:
	add_to_group("hud")
	_message.visible = false
	_win.visible = false
	_lose.visible = false
	if _read != null:
		_read.visible = false
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
	_tick_pulse()
	_tick_dash()


func _unhandled_input(event: InputEvent) -> void:
	# Cierre del modal de lectura (solo E: Esc queda para la pausa).
	if _reading:
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
			hide_document()
			get_viewport().set_input_as_handled()
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


func set_objective(text: String) -> void:
	if _objective == null:
		return
	_objective.text = text
	# Announce rotations after the initial snapshot, so a late HUD ready does
	# not spam the message label on boot.
	if _objective_seen:
		show_message("New objective: %s" % text)
	_objective_seen = true


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
	_message.visible = true
	_message.modulate.a = 1.0
	_msg_left = MESSAGE_TIME


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
