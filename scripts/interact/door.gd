class_name Door
extends StaticBody2D
## Gated passage (FASE 2). StaticBody2D blocks movement while CLOSED/LOCKED.
## Interaction runs through the child DoorRange (Interactable), which forwards
## get_prompt()/interact() here. Energy state is owned by EnergySystem; the
## linked Terminal flips terminal_unlocked and calls evaluate().
## Design: a door left OPEN stays open on power loss (fail-open, no trap).

enum State { LOCKED, CLOSED, OPENING, OPEN }

signal state_changed(state: State)

@export var requires_energy := true
@export var unlocked_by_terminal := false
## Damaged gate (FASE 5): while true, neither energy nor the terminal can open
## the door; only the Technician clears it via set_repaired().
@export var repair_required := false

var state: State = State.CLOSED
var terminal_unlocked := false

const OPEN_OFFSET := Vector2(0.0, -72.0)
const OPEN_TIME := 0.4
const CLOSE_TIME := 0.25

const COLOR_LOCKED := Color(0.8, 0.22, 0.22)
const COLOR_CLOSED := Color(0.85, 0.6, 0.2)
const COLOR_OPENING := Color(0.9, 0.85, 0.3)
const COLOR_OPEN := Color(0.3, 0.8, 0.4)

var _energy: EnergySystem
var _tween: Tween

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual
@onready var _visual_home: Vector2 = $Visual.position
@onready var _lamp: Polygon2D = $StatusLamp


func _ready() -> void:
	_energy = _find_energy()
	if _energy != null:
		_energy.energy_changed.connect(_on_energy_changed)
	elif requires_energy:
		push_error("Door: requires_energy but no EnergySystem in group 'energy_system'.")
	evaluate()


func requirements_met() -> bool:
	if repair_required:
		return false
	if requires_energy:
		var energy := _find_energy()
		if energy == null or not energy.is_on():
			return false
	if unlocked_by_terminal and not terminal_unlocked:
		return false
	return true


func missing_requirements() -> String:
	var missing: Array[String] = []
	if repair_required:
		missing.append("repairs")
	if requires_energy:
		var energy := _find_energy()
		if energy == null or not energy.is_on():
			missing.append("power")
	if unlocked_by_terminal and not terminal_unlocked:
		missing.append("terminal")
	return " + ".join(missing)


func evaluate() -> void:
	if state == State.OPENING or state == State.OPEN:
		return
	if repair_required:
		if state == State.CLOSED:
			state = State.LOCKED
			state_changed.emit(state)
		_refresh_visual()
		return
	if requirements_met():
		if state == State.LOCKED:
			state = State.CLOSED
			print("Door: unlocked.")
			state_changed.emit(state)
	else:
		if state == State.CLOSED:
			state = State.LOCKED
			state_changed.emit(state)
	_refresh_visual()


func get_prompt() -> String:
	if repair_required:
		return "Damaged - technician needed"
	match state:
		State.LOCKED:
			return "Locked (needs %s)" % missing_requirements()
		State.CLOSED:
			return "Open door [E]"
		State.OPEN:
			return "Close door [E]"
		_:
			return "Opening..."


func interact(_player: Node2D) -> void:
	if repair_required:
		print("Door: damaged - technician needed.")
		Sfx.play(get_tree(), Sfx.door_damaged())
		Sfx.message(get_tree(), "Damaged - technician needed.")
		return
	match state:
		State.OPENING:
			return
		State.OPEN:
			close()
		State.CLOSED:
			if requirements_met():
				open()
			else:
				_deny()
		State.LOCKED:
			_deny()


## Shared locked-deny feedback (FASE 6): print + deny sting + HUD message.
func _deny() -> void:
	print("Door: locked (needs %s)." % missing_requirements())
	Sfx.play(get_tree(), Sfx.door_locked())
	Sfx.message(get_tree(), "Locked (needs %s)." % missing_requirements())


## FASE 5: clears the damage flag (Technician only) and re-evaluates, so the
## gate becomes operational and opens on E when energy is available.
func set_repaired() -> void:
	if not repair_required:
		return
	repair_required = false
	evaluate()
	print("Door: repaired, operational.")


func open() -> void:
	if state != State.CLOSED:
		return
	state = State.OPENING
	_refresh_visual()
	state_changed.emit(state)
	_collision.set_deferred("disabled", true)
	Sfx.play(get_tree(), Sfx.door_open())
	Sfx.message(get_tree(), "Door open.")
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_visual, "position", _visual_home + OPEN_OFFSET, OPEN_TIME)
	_tween.tween_callback(_finish_open)


func close() -> void:
	if state != State.OPEN:
		return
	_kill_tween()
	state = State.CLOSED
	_collision.set_deferred("disabled", false)
	Sfx.play(get_tree(), Sfx.door_close())
	_tween = create_tween()
	_tween.tween_property(_visual, "position", _visual_home, CLOSE_TIME)
	_refresh_visual()
	state_changed.emit(state)
	print("Door: closed.")


func _finish_open() -> void:
	state = State.OPEN
	_refresh_visual()
	state_changed.emit(state)
	print("Door: open.")


func _on_energy_changed(_on: bool) -> void:
	var was: State = state
	evaluate()
	# Desbloqueo audible solo al pasar a operable y cerca del jugador
	# (una puerta lejana no spamea; abrir sigue siendo manual).
	if was == State.LOCKED and state == State.CLOSED:
		_play_unlock_nearby()


func _play_unlock_nearby() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var p := tree.get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if p.global_position.distance_to(global_position) <= 600.0:
		Sfx.play(tree, Sfx.door_unlock())


func _find_energy() -> EnergySystem:
	if _energy != null and is_instance_valid(_energy):
		return _energy
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("energy_system") as EnergySystem


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _refresh_visual() -> void:
	if _visual == null:
		return
	match state:
		State.LOCKED:
			_visual.color = COLOR_LOCKED
		State.CLOSED:
			_visual.color = COLOR_CLOSED
		State.OPENING:
			_visual.color = COLOR_OPENING
		State.OPEN:
			_visual.color = COLOR_OPEN
	# Status lamp mirrors the leaf so the state stays readable when the open
	# leaf slides into the wall. Display only; collision and logic untouched.
	if _lamp != null:
		_lamp.color = _visual.color.lightened(0.25)
