class_name ZeroSystem
extends Interactable
## ZERO SYSTEM consola (Sector 01, zona H Control Zero). Requiere energia y
## es de un solo uso: secuencia temporizada con mensajes + sonidos + cambio
## de luz, latch zero_used que leen ObjectiveManager y ExitZone.
## Single-writer: solo interact() fija zero_used.

signal zero_activated

const SEQUENCE: Array[String] = [
	"PROTOCOL ZERO",
	"INITIALIZING...",
	"USER DETECTED",
	"SECURITY OVERRIDE...",
	"PROTOCOL ZERO ACTIVATED",
]

const COLOR_IDLE := Color(0.20, 0.55, 0.65)
const COLOR_ACTIVE := Color(0.35, 0.95, 1.0)

var zero_used := false

var _running := false
var _energy: EnergySystem

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	super._ready()
	add_to_group("zero_system")
	_energy = get_tree().get_first_node_in_group("energy_system") as EnergySystem
	if _energy == null:
		push_error("ZeroSystem: no EnergySystem found in group 'energy_system'.")


func get_prompt() -> String:
	if zero_used:
		return "PROTOCOL ZERO: ACTIVE"
	if _running:
		return "Initializing..."
	return "Activate ZERO system [E]"


func interact(_player: Node2D) -> void:
	if zero_used or _running:
		return
	if _energy == null or not _energy.is_on():
		print("ZeroSystem: no power.")
		Sfx.play(get_tree(), Sfx.ui_deny())
		Sfx.message(get_tree(), "No power. Restore energy first.")
		return
	_running = true
	_run_sequence()


func _run_sequence() -> void:
	# Pulso de la consola durante la secuencia (solo presentacion: la
	# progresion real la marca zero_used al terminar, nunca la animacion).
	var pulse: Tween = null
	if _visual != null and is_inside_tree():
		_visual.scale = Vector2.ONE
		pulse = create_tween()
		for k in 4:
			pulse.tween_property(_visual, "scale", Vector2(1.25, 1.25), 0.35)
			pulse.tween_property(_visual, "scale", Vector2.ONE, 0.35)
	for i in SEQUENCE.size():
		var line: String = SEQUENCE[i]
		print("ZeroSystem: %s." % line)
		Sfx.message(get_tree(), line)
		if i == 0:
			Sfx.play(get_tree(), Sfx.terminal_boot())
		elif i == SEQUENCE.size() - 1:
			Sfx.play(get_tree(), Sfx.terminal_ok())
		else:
			Sfx.play(get_tree(), Sfx.terminal_scan())
		if i < SEQUENCE.size() - 1:
			await get_tree().create_timer(0.7).timeout
			if not is_instance_valid(self):
				return
	zero_used = true
	_running = false
	if _visual != null:
		_visual.color = COLOR_ACTIVE
		_visual.scale = Vector2.ONE
	zero_activated.emit()
