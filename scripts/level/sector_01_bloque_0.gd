extends Node2D
## Sector 01 Bloque 0 coordinator (scene-local, no autoloads).
## Mirrors main.gd prompt wiring: pulls the best interactable from the Player
## each frame into InteractionPrompt/Label. Energy, noise, objectives, HUD and
## SFX resolve through scene groups; this script owns no gameplay state.

const ALARM_COOLDOWN := 5.0
const DETECT_COOLDOWN := 3.0
const AMBIENT_OFF := Color(0.30, 0.30, 0.38)
const AMBIENT_ON := Color(0.78, 0.78, 0.84)

var _game_over_done := false
var _run_time := 0.0
var _alarm_left := 0.0
var _detect_left := 0.0
## Parpadeo de emergencia en apagón (un solo tween en bucle, muerto en cada
## cambio de energia para no acumular animaciones).
var _emergency_tween: Tween = null

@onready var _player: Player = $Player
@onready var _prompt_label: Label = $InteractionPrompt/Label
@onready var _ambience: CanvasModulate = $Ambience


func _ready() -> void:
	add_to_group("game")
	_wire_drones()
	_wire_security_online()
	_wire_zero()
	_wire_terminals()
	_apply_lighting(false)
	var bed: Node = get_node_or_null("/root/Audio")
	if bed != null:
		bed.call("set_music_state", Audio.MusicState.EXPLORATION)


func _process(_delta: float) -> void:
	if not _game_over_done:
		_run_time += _delta
	if _alarm_left > 0.0:
		_alarm_left = maxf(0.0, _alarm_left - _delta)
	if _detect_left > 0.0:
		_detect_left = maxf(0.0, _detect_left - _delta)
	if _player == null or _prompt_label == null:
		return
	var best: Interactable = _player.get_best_interactable()
	if best == null:
		_prompt_label.visible = false
		return
	_prompt_label.visible = true
	_prompt_label.text = best.get_prompt()


## Catch hook: single guarded transition with lose sting + overlay + pause.
## Shares the end-of-run guard with game_win (win/lose mutually exclusive).
func game_over(reason: String) -> void:
	if _game_over_done:
		return
	_game_over_done = true
	print("Sector01Bloque0: game over (%s)." % reason)
	var tree := get_tree()
	Sfx.play(tree, Sfx.lose())
	var hud: Node = tree.get_first_node_in_group("hud") if tree != null else null
	if hud != null and hud.has_method("show_lose"):
		hud.call("show_lose")
	if tree != null:
		tree.paused = true


## Win hook (ExitZone): guarded transition with win sting + overlay + pause.
func game_win() -> void:
	if _game_over_done:
		return
	_game_over_done = true
	print("Sector01Bloque0: PROTOCOL ZERO complete.")
	var tree := get_tree()
	Sfx.play(tree, Sfx.win())
	var hud: Node = tree.get_first_node_in_group("hud") if tree != null else null
	if hud != null and hud.has_method("show_win"):
		hud.call("show_win", _run_time)
	if tree != null:
		tree.paused = true


## Pause gate: the pause overlay only opens while the run is live (never in
## WON/LOST). _game_over_done covers both ends (game_over + game_win set it).
func is_playing() -> bool:
	return not _game_over_done


## Drones resolve through group "security_drone" (each drone self-registers),
## so the second drone needs no coordinator list to maintain.
func _wire_drones() -> void:
	var drones: Array[Node] = get_tree().get_nodes_in_group("security_drone")
	for drone in drones:
		if drone != null and drone.has_signal("state_changed"):
			drone.connect("state_changed", _on_drone_state_changed)


## SECURITY ONLINE: first energy ON wakes every dormant drone with message +
## sting. Later energy cuts intentionally do NOT stop the drones (backup power).
func _wire_security_online() -> void:
	var energy: Node = get_node_or_null("EnergySystem")
	if energy == null:
		energy = get_tree().get_first_node_in_group("energy_system")
	if energy != null and energy.has_signal("energy_changed"):
		energy.connect("energy_changed", _on_energy_security)


func _on_energy_security(on: bool) -> void:
	_apply_lighting(on)
	var bed: Node = get_node_or_null("/root/Audio")
	if bed != null and bed.has_method("play_ambience"):
		if on:
			bed.call("play_ambience", "res://assets/audio/ambience/05_maquinaria_titan_powerplant.mp3")
		elif bed.has_method("stop_ambience"):
			bed.call("stop_ambience")
	if not on:
		return
	var drones: Array[Node] = get_tree().get_nodes_in_group("security_drone")
	var woken := 0
	for drone in drones:
		if drone == null or not is_instance_valid(drone):
			continue
		if drone.get("dormant") == true:
			if drone.has_method("activate"):
				drone.call("activate")
			woken += 1
	if woken > 0:
		print("Sector01Bloque0: SECURITY SYSTEM ONLINE.")
		Sfx.play(get_tree(), Sfx.alarm())
		Sfx.message(get_tree(), "SECURITY SYSTEM: ONLINE")
	# Fase G: los activos investigan el generador real (una sola emision por
	# encendido; prioridades y estados los decide cada dron).
	var gen_nd := get_node_or_null("Generator") as Node2D
	var gpos := gen_nd.global_position if gen_nd != null else Vector2(950, 40)
	for drone in get_tree().get_nodes_in_group("security_drone"):
		if drone != null and is_instance_valid(drone) and drone.has_method("investigate_security_point"):
			drone.call("investigate_security_point", gpos)


## Lighting follows energy state: ambient swap + energy-gated lights toggle +
## emergency reds dim once restored (bright in blackout, faint with power).
## Null-guarded so a missing Ambience node or empty group never breaks the
## security wake block.
func _apply_lighting(on: bool) -> void:
	_kill_emergency_blink()
	if _ambience != null:
		_ambience.color = AMBIENT_ON if on else AMBIENT_OFF
	var tree := get_tree()
	if tree == null:
		return
	var lights: Array[Node] = tree.get_nodes_in_group("energy_lights")
	for light in lights:
		var item := light as CanvasItem
		if item != null:
			item.visible = on
	var reds := tree.get_nodes_in_group("emergency_lights")
	if on:
		for red in reds:
			if red != null and is_instance_valid(red) and red.has_method("set"):
				red.set("energy", 0.25)
	else:
		for red in reds:
			if red != null and is_instance_valid(red) and red.has_method("set"):
				red.set("energy", 1.0)
		_play_emergency_blink(reds)


## Pulso rojo en apagon (solo presentacion; _apply_lighting lo mata).
## Dos grupos paralelos encadenados (bajada + subida) en un solo tween en
## bucle: todas las rojas respiran sincronizadas sin acumular animaciones.
func _play_emergency_blink(reds: Array[Node]) -> void:
	if not is_inside_tree():
		return
	var live: Array[Node] = []
	for red in reds:
		if red != null and is_instance_valid(red) and red.has_method("set"):
			live.append(red)
	if live.is_empty():
		return
	_emergency_tween = create_tween().set_loops()
	_emergency_tween.set_parallel(true)
	for red in live:
		_emergency_tween.tween_property(red, "energy", 0.35, 0.8)
	_emergency_tween.set_parallel(false)
	_emergency_tween.tween_interval(0.05)
	_emergency_tween.set_parallel(true)
	for red in live:
		_emergency_tween.tween_property(red, "energy", 1.0, 0.8)
	_emergency_tween.set_parallel(false)
	_emergency_tween.tween_interval(0.4)


func _kill_emergency_blink() -> void:
	if _emergency_tween != null and _emergency_tween.is_valid():
		_emergency_tween.kill()
	_emergency_tween = null


## ZERO wiring: resolve through group "zero_system" with sibling fallback,
## then announce the extraction unlock on activation.
func _wire_zero() -> void:
	var zero: Node = get_tree().get_first_node_in_group("zero_system")
	if zero == null:
		zero = get_node_or_null("ZeroSystem")
	if zero != null and zero.has_signal("zero_activated"):
		zero.connect("zero_activated", _on_zero_activated)


## Alerta de terminal (§3B.2 acabado): un desbloqueo con exito (la unica via
## que emite `interacted`) ordena investigar la terminal real. Una emision por
## terminal: el latch `terminal_used` impide re-emitir.
func _wire_terminals() -> void:
	for term in get_tree().get_nodes_in_group("unlock_terminal"):
		if term != null and is_instance_valid(term) and term.has_signal("interacted"):
			term.connect("interacted", _on_terminal_alert.bind(term))


func _on_terminal_alert(term: Node) -> void:
	if term == null or not is_instance_valid(term):
		return
	var tpos := (term as Node2D).global_position
	print("Sector01Bloque0: terminal alert, investigating.")
	Sfx.message(get_tree(), "SECURITY ALERT: terminal access")
	for drone in get_tree().get_nodes_in_group("security_drone"):
		if drone != null and is_instance_valid(drone) and drone.has_method("investigate_security_point"):
			drone.call("investigate_security_point", tpos)


func _on_zero_activated() -> void:
	print("Sector01Bloque0: PROTOCOL ZERO // EXTRACTION UNLOCKED.")
	Sfx.play(get_tree(), Sfx.sequence([660.0, 880.0, 1320.0], 0.12))
	Sfx.message(get_tree(), "PROTOCOL ZERO // EXTRACTION UNLOCKED")
	# Fase G: alerta distinta e identificable; los activos comprueban la
	# consola real (el desbloqueo de extraccion ya quedo latchado).
	var zc := get_node_or_null("ZeroSystem") as Node2D
	var zpos := zc.global_position if zc != null else Vector2(2560, -80)
	for drone in get_tree().get_nodes_in_group("security_drone"):
		if drone != null and is_instance_valid(drone) and drone.has_method("investigate_security_point"):
			drone.call("investigate_security_point", zpos)
	# Destello de la luz cian de ZERO (presentacion; la progresion ya quedo
	# latchada en ZeroSystem.zero_used antes de esta senal).
	var zl := get_node_or_null("Light_Zero") as PointLight2D
	if zl != null and is_instance_valid(zl):
		var flash := create_tween()
		flash.tween_property(zl, "texture_scale", 3.0, 0.4)
		flash.tween_property(zl, "texture_scale", 2.0, 0.6)
	# Rafaga de particulas de un solo disparo.
	var zb := get_node_or_null("ZeroSystem/ZeroBurst") as GPUParticles2D
	if zb != null and is_instance_valid(zb):
		zb.emitting = true


## CHASE sting: alarm + message on entering CHASE, rate-limited so a long
## chase does not spam it. Survives a missing drone (guarded in _ready).
## Music bed follows every transition (TENSION on suspicion, fast CHASE,
## STEALTH near a calm drone, calm-down when far).
func _on_drone_state_changed(new_state: SecurityDrone.State) -> void:
	_route_music(new_state)
	if new_state == SecurityDrone.State.DETECT and _detect_left <= 0.0:
		_detect_left = DETECT_COOLDOWN
		Sfx.play(get_tree(), Sfx.terminal_beep())
	if new_state != SecurityDrone.State.CHASE:
		return
	if _alarm_left > 0.0:
		return
	_alarm_left = ALARM_COOLDOWN
	Sfx.play(get_tree(), Sfx.alarm())
	Sfx.message(get_tree(), "Detected!")


func _route_music(new_state: SecurityDrone.State) -> void:
	var audio: Node = get_node_or_null("/root/Audio")
	if audio == null:
		return
	match new_state:
		SecurityDrone.State.CHASE:
			audio.call("set_music_state", Audio.MusicState.CHASE)
		SecurityDrone.State.DETECT, SecurityDrone.State.INVESTIGATE, SecurityDrone.State.SEARCH:
			audio.call("set_music_state", Audio.MusicState.TENSION)
		SecurityDrone.State.PATROL:
			_on_patrol_music(audio)


func _on_patrol_music(audio: Node) -> void:
	if _player != null and is_instance_valid(_player):
		for d in get_tree().get_nodes_in_group("security_drone"):
			var body := d as Node2D
			if body != null and is_instance_valid(body) and body.global_position.distance_to(_player.global_position) < 400.0:
				audio.call("set_music_state", Audio.MusicState.STEALTH)
				return
	if audio.has_method("calm_down"):
		audio.call("calm_down")
	elif audio.has_method("set_music_state"):
		audio.call("set_music_state", Audio.MusicState.EXPLORATION)
