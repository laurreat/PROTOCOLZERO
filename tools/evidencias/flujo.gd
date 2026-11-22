extends Node
## Prueba funcional de regresión (Tarea 3): recorre el circuito completo del
## Sector 01 sobre la escena real, usando el despacho real de interacción del
## jugador (InteractionDetector -> Interactable.interact). No captura imágenes:
## imprime el estado resultante para el informe.
## Uso: godot --path . res://tools/evidencias/flujo.tscn

const LEVEL := "res://scenes/level/sector_01_bloque_0.tscn"

var _level: Node
var _player: Player
var _hud: Node
var _fails: Array[String] = []


func _ready() -> void:
	_level = load(LEVEL).instantiate()
	add_child(_level)
	await get_tree().create_timer(0.9).timeout
	_player = _level.get_node("Player") as Player
	_hud = get_tree().get_first_node_in_group("hud")
	# Aislamiento de la prueba: el agarre se anula para recorrer el circuito
	# (la prueba valida progresion y feedback, no la derrota por captura).
	for drone in get_tree().get_nodes_in_group("security_drone"):
		drone.set("catch_distance", 0.0)
	await _run()
	print("FLUJO: %s" % ("OK" if _fails.is_empty() else "FALLOS -> %s" % ", ".join(_fails)))
	get_tree().quit()


func _check(name: String, ok: bool, detail: String) -> void:
	print("FLUJO %s: %s (%s)" % ["OK  " if ok else "FAIL", name, detail])
	if not ok:
		_fails.append(name)


func _place(pos: Vector2) -> void:
	_player.global_position = pos
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.reset_smoothing()
	await get_tree().create_timer(0.35).timeout


func _use(pos: Vector2, label: String) -> void:
	await _place(pos)
	var best: Interactable = _player.get_best_interactable()
	if best == null:
		_check(label, false, "sin interactuable en alcance")
		return
	best.interact(_player)
	await get_tree().create_timer(0.15).timeout


func _run() -> void:
	var energy := _level.get_node_or_null("EnergySystem")
	var door_d1 := _level.get_node_or_null("DoorD1") as Door
	var door_d2 := _level.get_node_or_null("DoorD2") as Door
	var tech := _level.get_node_or_null("Technician") as Technician
	var zero := _level.get_node_or_null("ZeroSystem") as ZeroSystem
	var objectives := get_tree().get_first_node_in_group("objective_manager")

	# 1. Energia: reparacion real de 3 s.
	await _use(Vector2(950, 108), "generador en alcance")
	await get_tree().create_timer(3.4).timeout
	_check("energia ON", energy != null and energy.is_on(), "energy_on=%s" % str(energy.is_on() if energy else "?"))

	# 2. Terminal: desbloquea la puerta enlazada.
	await _use(Vector2(1100, 20), "terminal en alcance")
	_check("terminal desbloquea D1", door_d1 != null and door_d1.terminal_unlocked, "terminal_unlocked=%s" % str(door_d1.terminal_unlocked if door_d1 else "?"))

	# 3. Puerta D1: se abre con E.
	await _use(Vector2(1288, -70), "D1 en alcance")
	await get_tree().create_timer(0.5).timeout
	_check("D1 abierta", door_d1 != null and door_d1.state == Door.State.OPEN, "state=%s" % str(door_d1.state) if door_d1 else "?")

	# 4. Tecnico: repara la puerta dañada D2.
	await _use(Vector2(1420, 20), "tecnico en alcance")
	await get_tree().create_timer(6.4).timeout
	_check("tecnico DONE", tech != null and tech.state == Technician.State.DONE, "state=%s" % str(tech.state) if tech else "?")
	_check("D2 reparada", door_d2 != null and not door_d2.repair_required, "repair_required=%s" % str(door_d2.repair_required if door_d2 else "?"))

	# 5. Puerta D2: ya operable, se abre.
	await _use(Vector2(1704, -70), "D2 en alcance")
	await get_tree().create_timer(0.5).timeout
	_check("D2 abierta", door_d2 != null and door_d2.state == Door.State.OPEN, "state=%s" % str(door_d2.state) if door_d2 else "?")

	# 6. ZERO: secuencia de activacion (~3 s).
	await _use(Vector2(2560, -10), "ZERO en alcance")
	await get_tree().create_timer(4.2).timeout
	_check("ZERO activado", zero != null and zero.zero_used, "zero_used=%s" % str(zero.zero_used if zero else "?"))

	# 7. Objetivo final del HUD antes de la extraccion.
	if objectives != null:
		_check("objetivo 5/5", objectives.get_current_index() == 4, "index=%d" % objectives.get_current_index())

	# 8. Extraccion: dispara la victoria.
	await _place(Vector2(2572, 380))
	await get_tree().create_timer(0.8).timeout
	var won := _hud != null and _hud.has_method("is_win_visible") and bool(_hud.call("is_win_visible"))
	_check("victoria en extraccion", won, "win_visible=%s paused=%s" % [str(won), str(get_tree().paused)])
