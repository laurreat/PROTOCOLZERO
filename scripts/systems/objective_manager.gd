class_name ObjectiveManager
extends Node
## Linear objective tracker (FASE 6). Scene-local manager like EnergySystem:
## it owns NOTHING, it only reads real flags owned elsewhere and publishes
## the current objective text. Sequence: 0 "Restore power" until energy_on,
## 1 "Use the terminal" until terminal_used, 2 "Ask the technician for help"
## until the technician reaches DONE, 3 "Reach the exit" (won via ExitZone).
## Listeners pull get_current_objective() on subscribe (late-listener-safe)
## and then follow objective_changed.

signal objective_changed(text: String)

const OBJECTIVES: Array[String] = [
	"Restore power",
	"Use the terminal",
	"Ask the technician for help",
	"Activate ZERO system",
	"Reach the exit",
]

var current_index := 0

var _terminal: Terminal
var _technician: Technician
var _zero: ZeroSystem


func _ready() -> void:
	add_to_group("objective_manager")
	var tree := get_tree()
	if tree != null:
		var energy := tree.get_first_node_in_group("energy_system")
		if energy != null and energy.has_signal("energy_changed"):
			energy.connect("energy_changed", _on_source_changed)
	_terminal = get_parent().get_node_or_null("Terminal") as Terminal
	if _terminal != null:
		_terminal.interacted.connect(_on_source_changed)
	_technician = get_parent().get_node_or_null("Technician") as Technician
	if _technician != null:
		_technician.state_changed.connect(_on_source_changed)
	_zero = get_parent().get_node_or_null("ZeroSystem") as ZeroSystem
	if _zero != null:
		_zero.zero_activated.connect(_on_source_changed)
	_refresh()


func get_current_objective() -> String:
	return OBJECTIVES[current_index]


## Terminal use is a one-way latch owned by the Terminal itself; the manager
## only reads it (single-writer rule preserved).
func _is_terminal_done() -> bool:
	return _terminal != null and _terminal.terminal_used


func _is_repair_done() -> bool:
	return _technician != null and _technician.state == Technician.State.DONE


func _is_zero_done() -> bool:
	return _zero != null and _zero.zero_used


func _compute_index() -> int:
	var tree := get_tree()
	var energy := tree.get_first_node_in_group("energy_system") if tree != null else null
	if energy == null or not energy.is_on():
		return 0
	if not _is_terminal_done():
		return 1
	if not _is_repair_done():
		return 2
	if not _is_zero_done():
		return 3
	return 4


func _refresh() -> void:
	var next := _compute_index()
	if next == current_index:
		return
	current_index = next
	objective_changed.emit(OBJECTIVES[current_index])


func _on_source_changed(_unused: Variant = null) -> void:
	_refresh()
