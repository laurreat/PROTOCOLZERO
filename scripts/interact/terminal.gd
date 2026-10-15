class_name Terminal
extends Interactable
## Unlock terminal (FASE 2). Requires energy; pressing E with energy ON sets
## terminal_unlocked on the linked Door (wired via door_path) and re-evaluates it.

@export var door_path: NodePath

## One-way latch (FASE 6): set on the first successful unlock. The
## ObjectiveManager reads it; the Door's own terminal_unlocked stays the
## gameplay effect. Single writer: only interact() below sets it.
var terminal_used := false

## Noisy interaction (FASE 4): a successful unlock can attract the drone.
const USE_NOISE_RADIUS := 150.0

const COLOR_IDLE := Color(0.25, 0.5, 0.9)
const COLOR_GRANTED := Color(0.3, 0.9, 0.5)

const SCREEN_IDLE := Color(0.7, 0.95, 1.0)
const SCREEN_GRANTED := Color(0.35, 1.0, 0.6)
const SCREEN_DENIED := Color(1.0, 0.3, 0.3)

var _energy: EnergySystem
var _screen_tween: Tween = null

@onready var _visual: Polygon2D = $Visual
@onready var _screen: Polygon2D = $Screen


func _ready() -> void:
	super._ready()
	add_to_group("unlock_terminal")
	_energy = get_tree().get_first_node_in_group("energy_system") as EnergySystem
	if _energy == null:
		push_error("Terminal: no EnergySystem found in group 'energy_system'.")
	_set_screen(SCREEN_IDLE)


func get_door() -> Door:
	if door_path.is_empty():
		return null
	return get_node_or_null(door_path) as Door


func _emit_noise() -> void:
	if not is_inside_tree():
		return
	var noise := get_tree().get_first_node_in_group("noise_system")
	if noise != null and noise.has_method("emit_noise"):
		noise.emit_noise(global_position, USE_NOISE_RADIUS)


func get_prompt() -> String:
	var door := get_door()
	if door != null and door.terminal_unlocked:
		return "Terminal: access granted"
	return "Use terminal [E]"


func interact(_player: Node2D) -> void:
	var door := get_door()
	if door == null:
		push_error("Terminal: door_path is empty or invalid.")
		return
	if _energy == null or not _energy.is_on():
		print("Terminal: no power. Restore energy first.")
		Sfx.play(get_tree(), Sfx.terminal_deny())
		Sfx.message(get_tree(), "No power. Restore energy first.")
		_flash_denied()
		return
	if door.terminal_unlocked:
		print("Terminal: door already unlocked.")
		Sfx.message(get_tree(), _readout())
		return
	door.terminal_unlocked = true
	door.evaluate()
	terminal_used = true
	if _visual != null:
		_visual.color = COLOR_GRANTED
	_set_screen(SCREEN_GRANTED)
	print("Terminal: door unlocked.")
	Sfx.play(get_tree(), Sfx.terminal_ok())
	Sfx.message(get_tree(), _readout())
	_emit_noise()
	interacted.emit()


## Contextual readout (Sector 01): single multiline status after unlock.
func _readout() -> String:
	return "SYSTEM TERMINAL\nPOWER ONLINE\nSECURITY PARTIAL\nMAINTENANCE OFFLINE\nPROTOCOL UNKNOWN"


## Pantalla: estado directo + parpadeo de denegado que vuelve a IDLE.
func _set_screen(c: Color) -> void:
	_kill_screen_tween()
	if _screen != null:
		_screen.color = c


func _flash_denied() -> void:
	if _screen == null or not is_inside_tree():
		return
	_kill_screen_tween()
	_screen.color = SCREEN_DENIED
	_screen_tween = create_tween()
	_screen_tween.tween_interval(0.5)
	_screen_tween.tween_callback(_set_screen.bind(SCREEN_IDLE))


func _kill_screen_tween() -> void:
	if _screen_tween != null and _screen_tween.is_valid():
		_screen_tween.kill()
	_screen_tween = null
