class_name SecurityDrone
extends CharacterBody2D
## Patrol enemy with vision-cone AI (FASE 3). Clear, functional, demonstrable.
## States: PATROL loops waypoints; DETECT holds suspicion; INVESTIGATE checks
## a stimulus point; CHASE pursues the player via NavigationAgent2D; SEARCH
## sweeps around the last seen position, then returns to PATROL.
## Vision uses facing + distance + angle + a wall raycast each physics frame.
## Movement runs through NavigationAgent2D on the Main navmesh, with direct
## steering fallback when the target is off-mesh (the FASE 3 navmesh only
## covers the east-north patrol zone) so CHASE still works level-wide.
## Audio arrives in FASE 6: connect to state_changed for stings.


signal caught(player: Node2D)
signal state_changed(new_state: State)

enum State { PATROL, DETECT, INVESTIGATE, CHASE, SEARCH }

const COLOR_PATROL := Color(0.25, 0.5, 1.0)
const COLOR_DETECT := Color(1.0, 0.85, 0.2)
const COLOR_ALERT := Color(1.0, 0.55, 0.15)
const COLOR_CHASE := Color(1.0, 0.25, 0.2)
const COLOR_STUNNED := Color(0.55, 0.55, 0.6)
const CONE_ALPHA := 0.10
const ARRIVE_DISTANCE := 16.0
## Retorno fantasma (reporte usuario): distancia a la ruta por encima de la
## cual el retorno sin info viaja en fase. Dentro de la zona, fisica normal.
const SPAWN_ZONE_RADIUS := 120.0

@export var patrol_speed := 90.0
@export var chase_speed := 170.0
@export var investigate_speed := 120.0
@export var search_speed := 90.0
@export var view_distance := 260.0
@export var view_angle := 70.0
@export var detect_time := 0.6
@export var lose_time := 2.5
@export var search_time := 4.0
@export var investigate_look_time := 1.5
@export var catch_distance := 36.0
## Give-up timer (FASE 8): the stimulus can sit off-mesh (the FASE 3 navmesh
## covers only the east-north zone) or behind a wall, so the travel leg may
## never arrive. Without this the drone leaves patrol forever after one
## noise; with it the drone looks around where it gave up, then SEARCHes
## nearby and returns to PATROL. Reachable targets behave exactly as before.
@export var investigate_give_up_time := 6.0
@export var touch_sense_radius := 48.0
@export var search_points := 3
@export var search_radius := 160.0
@export var patrol_points: Array[Vector2] = []
@export var waypoint_paths: Array[NodePath] = []

var state: State = State.PATROL
var player_visible := false
var last_seen := Vector2.ZERO

var _player: Node2D
var _facing := Vector2.RIGHT
var _patrol: Array[Vector2] = []
var _wp_index := 0
var _detect_timer := 0.0
var _lose_timer := 0.0
var _look_timer := 0.0
var _arrived := false
var _investigate_target := Vector2.ZERO
var _travel_timer := 0.0
var _search_spots: Array[Vector2] = []
var _search_index := 0
var _search_timer := 0.0
var _catch_cooldown := 0.0
## Stun overlay (FASE 4, set by PulseDevice): while stunned_timer runs, the
## drone freezes and ignores vision, noise, states, and catch. The saved state
## below is restored on recovery (PATROL default). Not a State enum value, so
## the FASE 3 state machine is untouched.
var stunned_timer := 0.0
var _pre_stun_state: State = State.PATROL
## Excepcion fantasmal (§3 acabado): SOLO durante investigacion especial de
## sistemas (generador/terminal/ZERO). La mascara de colision se anula para
## cruzar muros/puertas hacia el punto y se restaura al llegar, al interrumpir
## (CHASE/DETECT/SEARCH/PATROL/stun) o al reintentar. Nunca es global ni
## permanente; CHASE y la deteccion normal siempre colisionan.
var _phase_alert := false
var _saved_mask := 1
## Antiatasco de retorno (C3): la patrulla es rumbo directo sin navmesh y una
## esquina puede detener el avance. Sin progreso en 6 s se hace SEARCH local
## (puntos aleatorios que tienden a despegarse) y se reintenta; tras 3 ciclos
## seguidos sin alcanzar waypoint queda de centinela (sin teleports).
var _seek_stuck := 0.0
var _seek_window_d := -1.0
var _seek_cycles := 0
## SECURITY ONLINE (Sector 01): the drone starts DORMANT (dark standby, no
## cone, no patrol) so the player orients safely. The first energy ON calls
## activate() -> PATROL. Single-writer: only activate() clears it.
var dormant := true

@onready var _nav: NavigationAgent2D = $NavigationAgent2D
@onready var _body: Polygon2D = $Body
@onready var _cone: Polygon2D = $VisionCone
@onready var _label: Label = $StateLabel
@onready var _detail: Sprite2D = $Detail

const DRONE_DIR := "res://assets/visual/enemies/security_drone/"
const DRONE_8 := ["north", "north_east", "east", "south_east", "south",
	"south_west", "west", "north_west"]
const FX_DET := "res://assets/visual/fx/detection/"

var _dframes := {}


func _load_dframes() -> void:
	for d in DRONE_8:
		_dframes["patrol_" + d] = load(DRONE_DIR + "drone_patrol_%s.png" % d)
		_dframes["alert_" + d] = load(DRONE_DIR + "drone_alert_%s.png" % d)
		_dframes["chase_%s_f0" % d] = load(DRONE_DIR + "drone_chase_%s_f0.png" % d)
		_dframes["chase_%s_f1" % d] = load(DRONE_DIR + "drone_chase_%s_f1.png" % d)
	_dframes["investigate_f0"] = load(DRONE_DIR + "drone_investigate_f0.png")
	_dframes["investigate_f1"] = load(DRONE_DIR + "drone_investigate_f1.png")
	_dframes["stunned"] = load(DRONE_DIR + "drone_stunned.png")
	_dframes["dormant"] = load(DRONE_DIR + "drone_dormant.png")
	_dframes["capture"] = load(DRONE_DIR + "drone_capture.png")


func _ddir8(d: Vector2) -> String:
	var n := -d.y
	var s := d.y
	var e := d.x
	var w := -d.x
	var vert := ""
	var horiz := ""
	if n > 0.38:
		vert = "north"
	elif s > 0.38:
		vert = "south"
	if e > 0.38:
		horiz = "east"
	elif w > 0.38:
		horiz = "west"
	if vert != "" and horiz != "":
		return vert + "_" + horiz
	if vert != "":
		return vert
	if horiz != "":
		return horiz
	return "south"


func _dset(key: String) -> void:
	if _detail == null or not _dframes.has(key):
		return
	var t: Texture2D = _dframes[key]
	if t != null and _detail.texture != t:
		_detail.texture = t


## Ping visual de un solo disparo (evento, nunca por fotograma).
func _dping(file: String, scl := 0.5, dur := 0.45) -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null:
		return
	var tex: Texture2D = load(FX_DET + file)
	if tex == null:
		return
	var ping := Sprite2D.new()
	ping.texture = tex
	ping.global_position = global_position
	ping.scale = Vector2(scl, scl)
	parent.add_child(ping)
	var tw := ping.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ping, "modulate:a", 0.0, dur)
	tw.tween_property(ping, "scale", Vector2(scl * 1.6, scl * 1.6), dur)
	tw.chain().tween_callback(ping.queue_free)


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("security_drone") # FASE 4: spec-literal group for NoiseSystem.
	_load_dframes()
	_dset("dormant")
	_resolve_waypoints()
	_wp_index = _nearest_waypoint()
	_build_cone()
	_refresh_visual()
	if not _patrol.is_empty():
		_nav.target_position = _patrol[_wp_index]


func _physics_process(delta: float) -> void:
	if dormant:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if stunned_timer > 0.0:
		stunned_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		_blink_stun_visual()
		if stunned_timer <= 0.0:
			_recover_from_stun()
		return
	_update_vision()
	if _catch_cooldown > 0.0:
		_catch_cooldown -= delta
	match state:
		State.PATROL:
			_tick_patrol(delta)
		State.DETECT:
			_tick_detect(delta)
		State.INVESTIGATE:
			_tick_investigate(delta)
		State.CHASE:
			_tick_chase(delta)
		State.SEARCH:
			_tick_search(delta)
	if _cone != null:
		_cone.rotation = _facing.angle()


## Noise API for FASE 4. No noise system exists yet; callers push positions.
func hear_noise(noise_pos: Vector2) -> void:
	if dormant:
		return
	if stunned_timer > 0.0:
		return
	if state != State.PATROL and state != State.SEARCH:
		return
	_investigate_target = noise_pos
	_enter(State.INVESTIGATE)


## Alerta de seguridad (Fase G): energia ON / ZERO activado. Los drones
## activos investigan el punto real del evento con mirada de 5 s; la vision,
## el ruido y las prioridades del sistema mandan (CHASE/DETECT no se
## interrumpen; aturdido y dormant se ignoran y resuelven por sus reglas).
func investigate_security_point(pos: Vector2, look_time := 5.0) -> void:
	if dormant:
		return
	if stunned_timer > 0.0:
		return
	if state == State.CHASE or state == State.DETECT:
		return
	_investigate_target = pos
	_enter(State.INVESTIGATE)
	_look_timer = maxf(_look_timer, look_time)
	# Viaje acotado pero suficiente: distancia/velocidad + margen. Sin esto,
	# el give_up base (6 s) cortaria el desplazamiento excepcional a medio
	# camino y el retorno partiria de una posicion invalida.
	_travel_timer = maxf(_travel_timer, global_position.distance_to(pos) / investigate_speed + 2.0)
	_engage_phase()


## Activa el desplazamiento excepcional (idempotente: re-alertas solo
## re-objetivo sin duplicar nada; no hay timers propios).
func _engage_phase() -> void:
	if not _phase_alert:
		_saved_mask = collision_mask
		_phase_alert = true
	collision_mask = 0


## Restaura la fisica normal. Toda salida de la fase pasa por aqui.
func _clear_phase() -> void:
	if _phase_alert:
		collision_mask = _saved_mask
		_phase_alert = false


## Retorno fantasma: sin info actual del jugador y lejos de la ruta propia.
func _should_ghost_home() -> bool:
	if player_visible:
		return false
	return _outside_spawn()


## Fuera de la zona de spawn/normalidad: ningun waypoint cerca.
func _outside_spawn() -> bool:
	if _patrol.is_empty():
		return false
	var best := SPAWN_ZONE_RADIUS
	for p in _patrol:
		best = minf(best, global_position.distance_to(p))
	return best >= SPAWN_ZONE_RADIUS


## Stun interrupt for the FASE 4 PulseDevice (minimal overlay, AI untouched).
## Freezes movement, vision, states, and catch while stunned_timer runs out;
## afterwards the drone resumes the state saved here (PATROL default).
## The pulse NEVER damages: this only interrupts.
func stun(duration: float) -> void:
	if dormant:
		return
	if duration <= 0.0:
		return
	_clear_phase()
	if stunned_timer <= 0.0:
		_pre_stun_state = state
	stunned_timer = maxf(stunned_timer, duration)
	_apply_stun_visual()


func _apply_stun_visual() -> void:
	if not is_node_ready():
		return
	_body.color = COLOR_STUNNED
	_cone.color = Color(COLOR_STUNNED, CONE_ALPHA)
	_label.text = "Zz"
	_dset("stunned")
	_dping("stun_spark.png", 0.45, 0.4)


func _blink_stun_visual() -> void:
	if _body == null:
		return
	var phase := int(Time.get_ticks_msec() / 150) % 2
	_body.modulate.a = 0.35 if phase == 0 else 1.0


func _recover_from_stun() -> void:
	stunned_timer = 0.0
	if _body != null:
		_body.modulate.a = 1.0
	state = _pre_stun_state
	_refresh_visual()


## SECURITY ONLINE: wakes the drone from dormant standby into PATROL.
## Idempotent; only the first energy ON has an effect.
func activate() -> void:
	if not dormant:
		return
	dormant = false
	_resolve_waypoints()
	_wp_index = _nearest_waypoint()
	if not _patrol.is_empty() and _nav != null:
		_nav.target_position = _patrol[_wp_index]
	_refresh_visual()
	print("SecurityDrone: online, patrolling.")


func _tick_patrol(delta: float) -> void:
	if _patrol.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _seek_cycles >= 3:
		# Centinela: espera sin bloquear la maquina (la alerta lo re-activa).
		# Planta quieta = sin viaje que fantasmear: fisica normal siempre.
		_clear_phase()
		velocity = Vector2.ZERO
		move_and_slide()
		if player_visible:
			_enter(State.DETECT)
		_dset("patrol_" + _ddir8(_facing))
		return
	var target := _patrol[_wp_index]
	var dist := _move_along(target, patrol_speed)
	if dist <= ARRIVE_DISTANCE:
		_wp_index = (_wp_index + 1) % _patrol.size()
		_clear_phase()
		_seek_stuck = 0.0
		_seek_window_d = -1.0
		_seek_cycles = 0
	elif _seek_window_d < 0.0:
		# Primera ventana: calibra sin juzgar.
		_seek_window_d = dist
		_seek_stuck = 0.0
	else:
		_seek_stuck += delta
		if _seek_stuck >= 6.0:
			var made: float = _seek_window_d - dist
			_seek_window_d = dist
			_seek_stuck = 0.0
			# Obstruido si avanza menos del 25 % de lo esperado.
			if made < patrol_speed * 6.0 * 0.25:
				_seek_cycles += 1
				_wp_index = _nearest_waypoint()
				last_seen = global_position
				_enter(State.SEARCH)
				return
	if player_visible:
		_enter(State.DETECT)
		return
	_dset("patrol_" + _ddir8(_facing))


func _tick_detect(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_dset("alert_" + _ddir8(_facing))
	if player_visible and _player != null:
		_facing = (_player.global_position - global_position).normalized()
		_detect_timer -= delta
		if _detect_timer <= 0.0:
			_enter(State.CHASE)
	else:
		_enter(State.PATROL)


func _tick_investigate(delta: float) -> void:
	if player_visible:
		_enter(State.CHASE)
		return
	_dset("investigate_f%d" % (int(Time.get_ticks_msec() / 400) % 2))
	if not _arrived:
		_travel_timer -= delta
		if _move_along(_investigate_target, investigate_speed) <= ARRIVE_DISTANCE or _travel_timer <= 0.0:
			_arrived = true
			# La fase especial conserva sus 5 s de inspeccion; la normal usa
			# el ajuste exportado. La fisica se restaura en ambos casos.
			if not _phase_alert:
				_look_timer = investigate_look_time
			_clear_phase()
			if _travel_timer <= 0.0:
				last_seen = global_position
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		_look_timer -= delta
		if _look_timer <= 0.0:
			last_seen = _investigate_target
			_enter(State.SEARCH)


func _tick_chase(delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		if player_visible:
			_lose_timer = lose_time
			last_seen = _player.global_position
		# Sin vision se persigue la ULTIMA posicion conocida, nunca la posicion
		# live (N4: sin wall-hack; al expirar lose_timer -> SEARCH normal).
		var target: Vector2 = _player.global_position if player_visible else last_seen
		_move_along(target, chase_speed)
		_dset("chase_%s_f%d" % [_ddir8(_facing),
			int(Time.get_ticks_msec() / 150) % 2])
		if player_visible and global_position.distance_to(target) <= catch_distance:
			_catch()
	else:
		_move_along(last_seen, chase_speed)
	if not player_visible:
		_lose_timer -= delta
		if _lose_timer <= 0.0:
			_enter(State.SEARCH)


func _tick_search(delta: float) -> void:
	if player_visible:
		_enter(State.CHASE)
		return
	_dset("patrol_" + _ddir8(_facing))
	_search_timer -= delta
	if _search_timer <= 0.0:
		_enter(State.PATROL)
		return
	if _search_index < _search_spots.size():
		if _move_along(_search_spots[_search_index], search_speed) <= ARRIVE_DISTANCE:
			_search_index += 1
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if _search_timer <= 0.0:
			_enter(State.PATROL)


func _enter(next: State) -> void:
	if state == next:
		return
	var was: State = state
	state = next
	match state:
		State.PATROL:
			_clear_phase()
			# Retorno fantasma: solo al volver de SEARCH (busqueda agotada =
			# sin info del jugador, el rojo ya es azul) y fuera de la zona.
			# DETECT directo, aturdido y dormido no abren fase.
			if was == State.SEARCH and _should_ghost_home():
				_engage_phase()
		State.DETECT:
			_clear_phase()
			_detect_timer = detect_time
			velocity = Vector2.ZERO
			_dping("suspect_glow.png", 0.6, 0.5)
		State.INVESTIGATE:
			_arrived = false
			_travel_timer = investigate_give_up_time
			_look_timer = investigate_look_time
			_dping("scan_ping.png", 0.5, 0.5)
		State.CHASE:
			_clear_phase()
			_lose_timer = lose_time
			_dping("alert_glow.png", 0.7, 0.5)
		State.SEARCH:
			_clear_phase()
			_search_timer = search_time
			_build_search_points()
	_refresh_visual()
	state_changed.emit(state)


## Steers toward target via the navmesh, falling back to direct steering when
## the path is finished but the target is still far (off-mesh FASE 3 case).
## Robustez (§3 acabado): este nivel no tiene NavigationRegion (verificado:
## el agente informa reachable=false); en ese caso el tramo nav son rumbos
## rancios y se ignora por completo. Con mapa valido solo se adopta si
## concuerda con el directo (dot > 0.7). Sin mapa, el rumbo directo manda.
func _move_along(target: Vector2, speed: float) -> float:
	var dir := target - global_position
	if _nav != null:
		_nav.target_position = target
		if not _nav.is_navigation_finished() and _nav.is_target_reachable():
			var next := _nav.get_next_path_position()
			var step := next - global_position
			if step.length() > 4.0 and dir.length() > 1.0 and step.normalized().dot(dir.normalized()) > 0.7:
				dir = step
	## Returns the remaining distance. Updates facing while moving.
	if dir.length() > 1.0:
		dir = dir.normalized()
		velocity = dir * speed
		_facing = dir
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	return global_position.distance_to(target)


func _update_vision() -> void:
	player_visible = false
	_player = _find_player()
	if _player == null:
		return
	var to: Vector2 = _player.global_position - global_position
	var dist := to.length()
	if dist > view_distance or dist <= 0.01:
		if dist <= touch_sense_radius and dist > 0.01:
			player_visible = _has_los(_player.global_position, _player)
			if player_visible:
				last_seen = _player.global_position
		return
	if dist > touch_sense_radius:
		var facing_dot := _facing.dot(to / dist)
		var angle := rad_to_deg(acos(clampf(facing_dot, -1.0, 1.0)))
		if angle > view_angle * 0.5:
			return
	if _has_los(_player.global_position, _player):
		player_visible = true
		last_seen = _player.global_position


## The ray ends inside the player body, so a hit against the player itself
## means a clear line of sight; only other colliders (walls, door) block it.
func _has_los(target: Vector2, body: Node) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit["collider"] == body


func _find_player() -> Node2D:
	var grouped := get_tree().get_first_node_in_group("player") as Node2D
	if grouped != null:
		return grouped
	return get_parent().get_node_or_null("Player") as Node2D


func _catch() -> void:
	if _catch_cooldown > 0.0:
		return
	_catch_cooldown = 1.0
	_dset("capture")
	_dping("capture_flash.png", 0.8, 0.6)
	caught.emit(_player)
	var game := get_tree().get_first_node_in_group("game")
	if game != null and game.has_method("game_over"):
		game.game_over("caught")
	else:
		print("SecurityDrone: player caught (no game_over hook; caught signal emitted).")


func _resolve_waypoints() -> void:
	_patrol.clear()
	for path in waypoint_paths:
		var marker := get_node_or_null(path) as Node2D
		if marker != null:
			_patrol.append(marker.global_position)
	if _patrol.is_empty():
		_patrol = patrol_points.duplicate()
	if _patrol.is_empty():
		_patrol = [global_position]


func _nearest_waypoint() -> int:
	var best := 0
	var best_dist := INF
	for i in _patrol.size():
		var d := global_position.distance_to(_patrol[i])
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _build_search_points() -> void:
	_search_spots.clear()
	_search_index = 0
	for i in search_points:
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, search_radius)
		var spot := last_seen + offset
		spot.x = clampf(spot.x, -790.0, 790.0)
		spot.y = clampf(spot.y, -590.0, 590.0)
		_search_spots.append(spot)


func _build_cone() -> void:
	if _cone == null:
		return
	var pts := PackedVector2Array([Vector2.ZERO])
	var segments := 16
	var half := deg_to_rad(view_angle * 0.5)
	for i in range(segments + 1):
		var a := lerpf(-half, half, float(i) / float(segments))
		pts.append(Vector2.RIGHT.rotated(a) * view_distance)
	_cone.polygon = pts


func _refresh_visual() -> void:
	if not is_node_ready():
		return
	if dormant:
		_body.color = Color(0.12, 0.13, 0.16)
		_cone.visible = false
		_label.text = "OFF"
		_dset("dormant")
		return
	if _cone != null:
		_cone.visible = true
	match state:
		State.PATROL:
			_body.color = COLOR_PATROL
			_cone.color = Color(COLOR_PATROL, CONE_ALPHA)
			_label.text = ""
			_dset("patrol_" + _ddir8(_facing))
		State.DETECT:
			_body.color = COLOR_DETECT
			_cone.color = Color(COLOR_DETECT, CONE_ALPHA + 0.06)
			_label.text = "?"
			_dset("alert_" + _ddir8(_facing))
		State.INVESTIGATE:
			_body.color = COLOR_ALERT
			_cone.color = Color(COLOR_ALERT, CONE_ALPHA)
			_label.text = "?"
			_dset("investigate_f0")
		State.CHASE:
			_body.color = COLOR_CHASE
			_cone.color = Color(COLOR_CHASE, CONE_ALPHA + 0.06)
			_label.text = "!"
			_dset("chase_%s_f0" % _ddir8(_facing))
		State.SEARCH:
			_body.color = COLOR_ALERT
			_cone.color = Color(COLOR_ALERT, CONE_ALPHA)
			_label.text = "?"
			_dset("patrol_" + _ddir8(_facing))
