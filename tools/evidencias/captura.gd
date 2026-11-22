extends Node
## Arnés de capturas Tarea 3 (UNAD) para PROTOCOL: ZERO.
## Carga las escenas REALES del juego, provoca estados reales (reparar el
## generador, abrir puertas, lanzar el pulso, acercarse a un dron) y guarda
## el fotograma renderizado por el motor. No compone ni retoca imágenes.
## Uso: godot --path . res://tools/evidencias/captura.tscn -- --set=antes|despues

const MENU := "res://scenes/menu/main_menu.tscn"
const LEVEL := "res://scenes/level/sector_01_bloque_0.tscn"

var _set := "antes"
var _prefix := "ANTES"
var _dir := "res://EVIDENCIAS_TAREA_3/ANTES"
var _level: Node
var _player: Player
var _hud: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--set="):
			_set = arg.substr(6)
	if _set == "despues":
		_prefix = "DESPUES"
		_dir = "res://EVIDENCIAS_TAREA_3/DESPUES"
	DirAccess.make_dir_recursive_absolute(_dir)
	await _menu_phase()
	await _level_phase()
	print("HARNESS: fin set=%s" % _set)
	get_tree().quit()


func _shot(num: int, label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var file := "%s/%s_%02d_%s.png" % [_dir, _prefix, num, label]
	var err := img.save_png(file)
	print("HARNESS shot=%s err=%d size=%s" % [file, err, str(img.get_size())])


func _move(pos: Vector2, settle := 0.45) -> void:
	if _player == null:
		return
	_player.global_position = pos
	# La cámara tiene suavizado: sin esto la captura sale descentrada.
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.reset_smoothing()
	await get_tree().create_timer(settle).timeout


func _prompt() -> String:
	if _player == null:
		return "no-player"
	var best: Interactable = _player.get_best_interactable()
	return best.get_prompt() if best != null else "none"


func _menu_phase() -> void:
	var menu: Node = load(MENU).instantiate()
	add_child(menu)
	await get_tree().create_timer(2.2).timeout
	await _shot(1, "Menu_principal")
	if _set == "antes":
		var help := menu.get_node_or_null("LeftMargin/MainVBox/HelpButton") as Button
		if help != null:
			help.pressed.emit()
			await get_tree().create_timer(0.55).timeout
			print("HARNESS menu: panel de instrucciones abierto")
			await _shot(3, "Controles_HUD")
	menu.queue_free()
	await get_tree().process_frame


func _level_phase() -> void:
	_level = load(LEVEL).instantiate()
	add_child(_level)
	await get_tree().create_timer(0.9).timeout
	_player = _level.get_node_or_null("Player") as Player
	_hud = get_tree().get_first_node_in_group("hud")
	print("HARNESS nivel listo player=%s hud=%s" % [str(_player), str(_hud)])
	if _set == "despues":
		# CAM-02: la tarjeta de controles se muestra sola al comenzar la partida.
		await _shot(3, "Controles_HUD")
		if _hud != null and _hud.has_method("hide_controls"):
			_hud.call("hide_controls")
			await get_tree().create_timer(0.3).timeout

	# CAM-01: objetos interactivos (generador sin energia)
	await _move(Vector2(950, 108))
	print("HARNESS generador prompt='%s'" % _prompt())
	await _shot(2, "Exploracion_y_objetos")

	# CAM-07: objetivo actual en el HUD (junto a la terminal)
	await _move(Vector2(1100, 20))
	print("HARNESS terminal prompt='%s'" % _prompt())
	await _shot(8, "Objetivo_actual")

	# CAM-03: reparacion del generador (3 s) y acceso energizado
	await _move(Vector2(950, 108))
	var gen := _level.get_node_or_null("Generator") as Generator
	if gen != null:
		print("HARNESS generador.interact() -> reparacion")
		gen.interact(_player)
	await get_tree().create_timer(3.5).timeout
	await _move(Vector2(792, 48))
	print("HARNESS acceso prompt='%s'" % _prompt())
	await _shot(4, "Energia_y_accesos")

	# CAM-05: el dron detecta al jugador (colocado frente a su mirada real).
	# El arnés anula SOLO el agarre (catch_distance) durante estas dos tomas:
	# interesa el estado del dron, no la pantalla de derrota. La IA, la visión
	# y el resto del comportamiento quedan intactos.
	var drone := _level.get_node_or_null("SecurityDrone") as SecurityDrone
	var saved_catch := 36.0
	if drone != null:
		saved_catch = float(drone.get("catch_distance"))
		drone.set("catch_distance", 0.0)
		var facing: Vector2 = drone.get("_facing")
		if facing.length() < 0.1:
			facing = Vector2.RIGHT
		await _move(drone.global_position + facing.normalized() * 175.0, 0.12)
		await get_tree().create_timer(0.16).timeout
		print("HARNESS dron state=%s visible=%s dist=%.0f" % [str(drone.state), str(drone.player_visible), drone.global_position.distance_to(_player.global_position)])
		await _shot(6, "Dron_seguridad")

		# CAM-04: pulso sobre ese dron (interrumpe, no daña)
		var pulse := _player.get_node_or_null("PulseDevice") as PulseDevice
		if pulse != null:
			print("HARNESS pulse.try_pulse()=%s" % str(pulse.try_pulse()))
		await get_tree().create_timer(0.14).timeout
		print("HARNESS dron stunned=%.1f state=%s" % [drone.stunned_timer, str(drone.state)])
		await _shot(5, "Pulse_Device")

	# CAM-06: retroalimentacion de una interaccion fallida (puerta dañada)
	await _move(Vector2(1704, -64))
	print("HARNESS puerta danada prompt='%s'" % _prompt())
	var best: Interactable = _player.get_best_interactable()
	if best != null:
		best.interact(_player)
	await get_tree().create_timer(0.2).timeout
	await _shot(7, "Retroalimentacion")
	if drone != null:
		drone.set("catch_distance", saved_catch)
