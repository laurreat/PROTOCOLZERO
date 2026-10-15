class_name Generator
extends Interactable
## Power source (FASE 2). Pressing E toggles EnergySystem energy.
## Traversable placeholder for the MVP: no blocking body, so the player can
## stand on it without getting stuck. Visual color shows state (red OFF).

signal toggled(on: bool)

@export var energy_system: EnergySystem

## Noisy interaction (FASE 4): toggling power can attract the drone.
## Noisy interaction (FASE 4): toggling power can attract the drone.
const USE_NOISE_RADIUS := 150.0

## Reparacion de 3 s (Fase G): encender requiere trabajo. El jugador queda
## quieto (movement_locked, sin tocar su velocidad), suena el proceso y la
## energia solo se activa al terminar. Apagar sigue siendo instantaneo.
const REPAIR_TIME := 3.0

var _repairing := false
var _repair_tween: Tween = null

const COLOR_OFF := Color(0.85, 0.25, 0.25)
const COLOR_ON := Color(0.25, 0.9, 0.4)

@onready var _visual: Polygon2D = $Visual
@onready var _machine: Sprite2D = $Machine
@onready var _core: Polygon2D = $Core
@onready var _steam: GPUParticles2D = $Steam

## Startup overlay (visual only): brief red->amber->green lamp cycle after a
## successful power-on. Killed by any new toggle; ends on the ON color so it
## can never desync from the energy state. No FAILURE state exists in logic.
var _start_tween: Tween = null


func _ready() -> void:
	super._ready()
	if energy_system == null:
		energy_system = get_tree().get_first_node_in_group("energy_system") as EnergySystem
	if energy_system == null:
		push_error("Generator: no EnergySystem assigned or in group 'energy_system'.")
		return
	energy_system.energy_changed.connect(_on_energy_changed)
	_refresh_visual(energy_system.is_on())


func get_prompt() -> String:
	if energy_system != null and energy_system.is_on():
		return "Turn OFF generator [E]"
	return "Turn ON generator [E]"


func interact(player: Node2D) -> void:
	if energy_system == null:
		push_error("Generator: no EnergySystem available.")
		return
	var turning_on := not energy_system.is_on()
	if turning_on:
		_begin_repair(player)
		return
	energy_system.set_energy(false)
	_kill_startup()
	Sfx.play(get_tree(), Sfx.power_cut())
	Sfx.message(get_tree(), "Power cut.")
	_emit_noise()
	interacted.emit()


## Inicia la reparacion (anti-doble-E: pulsaciones repetidas se ignoran).
func _begin_repair(player: Node2D) -> void:
	if _repairing:
		return
	if player != null and player.get("movement_locked") == true:
		return
	_repairing = true
	_set_player_lock(player, true)
	Sfx.play(get_tree(), Sfx.repair_start())
	Sfx.message(get_tree(), "Repairing generator... hold still.")
	_play_repair_blink()
	_run_repair(player)


func _run_repair(player: Node2D) -> void:
	# process_always=false: con el arbol en pausa (muerte) el temporizador
	# espera; con recarga de escena los nodos se liberan y se aborta abajo.
	await get_tree().create_timer(REPAIR_TIME, false).timeout
	if not is_instance_valid(self):
		return
	if energy_system == null or (player != null and not is_instance_valid(player)):
		_repairing = false
		_kill_repair_blink()
		return
	if energy_system.is_on():
		_finish_repair(player)
		return
	energy_system.set_energy(true)
	_kill_startup()
	_kill_repair_blink()
	Sfx.play(get_tree(), Sfx.generator_on())
	Sfx.message(get_tree(), "Power restored.")
	_play_startup()
	_emit_noise()
	interacted.emit()
	_finish_repair(player)


func _finish_repair(player: Node2D) -> void:
	_repairing = false
	_kill_repair_blink()
	_set_player_lock(player, false)


func _set_player_lock(player: Node2D, locked: bool) -> void:
	if player != null and is_instance_valid(player):
		player.set("movement_locked", locked)


## Parpadeo del panel mientras se repara (presentacion; la logica la marca
## EnergySystem al terminar, nunca esta animacion).
func _play_repair_blink() -> void:
	if _visual == null or not is_inside_tree():
		return
	_kill_repair_blink()
	_repair_tween = create_tween().set_loops()
	_repair_tween.tween_property(_visual, "modulate:a", 0.35, 0.4)
	_repair_tween.tween_property(_visual, "modulate:a", 1.0, 0.4)


func _kill_repair_blink() -> void:
	if _repair_tween != null and _repair_tween.is_valid():
		_repair_tween.kill()
	_repair_tween = null
	if _visual != null and is_instance_valid(_visual):
		_visual.modulate.a = 1.0


func _play_startup() -> void:
	if _visual == null or not is_inside_tree():
		return
	_start_tween = create_tween()
	_start_tween.tween_property(_visual, "color", Color(0.9, 0.7, 0.2), 0.3).set_delay(0.2)
	_start_tween.tween_property(_visual, "color", COLOR_ON, 0.3)


func _kill_startup() -> void:
	if _start_tween != null and _start_tween.is_valid():
		_start_tween.kill()
	_start_tween = null


func _on_energy_changed(on: bool) -> void:
	_refresh_visual(on)
	toggled.emit(on)
	if on:
		print("Generator: energy ON.")
	else:
		print("Generator: energy OFF.")


func _refresh_visual(on: bool) -> void:
	if _visual == null:
		return
	_visual.color = COLOR_ON if on else COLOR_OFF
	# Estado legible sin HUD: carcasa atenuada + nucleo oculto en OFF.
	if _machine != null:
		_machine.modulate = Color(1, 1, 1, 1) if on else Color(0.45, 0.45, 0.5, 1)
	if _core != null:
		_core.visible = on
	# Vapor solo con energia (presentacion atada al estado real).
	if _steam != null:
		_steam.emitting = on


func _emit_noise() -> void:
	if not is_inside_tree():
		return
	var noise := get_tree().get_first_node_in_group("noise_system")
	if noise != null and noise.has_method("emit_noise"):
		noise.emit_noise(global_position, USE_NOISE_RADIUS)
