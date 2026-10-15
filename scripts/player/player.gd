class_name Player
extends CharacterBody2D
## Top-down player controller (FASE 1) + interaction dispatch (FASE 2).
## Polls named Input Map actions in _physics_process and slides on collision.
## Camera is a child node configured in player.tscn (smoothing on, zoom ~2).
## Discrete E presses are handled in _unhandled_input and forwarded to the
## nearest Interactable reported by the child InteractionDetector.


@export var walk_speed: float = 200.0

## Dash tactico (C5): impulso breve con cooldown de 3 s en la accion `sprint`
## (Shift). Sustituye a la carrera sostenida: una pulsacion = una maniobra.
## Ruido unico al arrancar via NoiseSystem (reglas normales, nunca fase).
const DASH_SPEED := 520.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 3.0
const DASH_NOISE_RADIUS := 260.0

## Sprites 8-dir (Blender, sin armas): base + sufijos de pantalla.
const HERO_DIR := "res://assets/visual/characters/player/"
const HERO_8 := ["north", "north_east", "east", "south_east", "south",
	"south_west", "west", "north_west"]
const FX_STREAK := "res://assets/visual/fx/dash/dash_streak.png"

var _dashing := false
var _dash_left := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.RIGHT
var _last_dir := Vector2.RIGHT
var _ghost_t := 0.0
var _bob_t := 0.0
var _recover_t := 0.0

## Repair lock (Fase G): while true the player stands still (generator 3 s
## repair). Set only by the repair owner (Generator); cleared on completion
## or abort. Camera/HUD keep running; only locomotion + new interacts stop.
var movement_locked := false

@onready var _detector: InteractionDetector = $InteractionDetector
## Decorative heading wedge (visual only: rotation never touches collision).
## Legacy placeholder, hidden in scene; kept so old references never break.
@onready var _heading: Polygon2D = $Heading
## Final 8-dir art (never rotates: the frame itself carries the direction).
@onready var _art: Sprite2D = $Hero

## Frame cache: key -> Texture2D (loaded once in _ready).
var _frames := {}
var _dash_age := 0.0


func _ready() -> void:
	for d in HERO_8:
		_frames["idle_" + d] = load(HERO_DIR + "hero_idle_%s.png" % d)
		_frames["move_%s_f0" % d] = load(HERO_DIR + "hero_move_%s_f0.png" % d)
		_frames["move_%s_f1" % d] = load(HERO_DIR + "hero_move_%s_f1.png" % d)
		_frames["dash_" + d] = load(HERO_DIR + "hero_dash_%s.png" % d)
	_frames["dash_start"] = load(HERO_DIR + "hero_dash_start.png")
	_frames["dash_recovery"] = load(HERO_DIR + "hero_dash_recovery.png")
	_frames["interact_generator"] = load(HERO_DIR + "hero_interact_generator.png")
	_frames["interact_terminal"] = load(HERO_DIR + "hero_interact_terminal.png")
	_frames["interact_zero"] = load(HERO_DIR + "hero_interact_zero.png")
	_frames["interact_read"] = load(HERO_DIR + "hero_interact_read.png")
	_frames["detected"] = load(HERO_DIR + "hero_detected.png")
	_frames["captured"] = load(HERO_DIR + "hero_captured.png")
	_set_frame("idle_south")


## Screen-space 8-way name for a world direction (north = -Y).
func _dir8(d: Vector2) -> String:
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


func _set_frame(key: String) -> void:
	if _art == null or not _frames.has(key):
		return
	var t: Texture2D = _frames[key]
	if t != null and _art.texture != t:
		_art.texture = t


## Interaction frame follows the nearest interactable type (visual only;
## timers and logic untouched).
func _locked_frame() -> String:
	var best: Interactable = get_best_interactable()
	if best == null:
		return "interact_generator"
	if best is Generator:
		return "interact_generator"
	if best is Terminal or best is LoreTerminal:
		return "interact_terminal"
	if best is ZeroSystem:
		return "interact_zero"
	return "interact_read"


func _physics_process(delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_set_frame(_locked_frame())
		return
	if _dash_cd > 0.0:
		_dash_cd = maxf(0.0, _dash_cd - delta)
	if _dashing:
		_dash_left -= delta
		_dash_age += delta
		velocity = _dash_dir * DASH_SPEED
		move_and_slide()
		if _dash_age < 0.05:
			_set_frame("dash_start")
		else:
			_set_frame("dash_" + _dir8(_dash_dir))
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.06
			_spawn_ghost()
		if _dash_left <= 0.0:
			_finish_dash()
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * walk_speed
	move_and_slide()
	if _recover_t > 0.0:
		_recover_t -= delta
		_set_frame("dash_recovery")
		if _art != null:
			_art.scale = Vector2(0.25, 0.25)
		return
	if direction != Vector2.ZERO:
		_last_dir = direction.normalized()
		_face(_last_dir)
		# Marcha 2 fotogramas (el encuadre no cambia: no hay saltos).
		_bob_t += delta * 10.0
		var key := "move_%s_f0" % _dir8(_last_dir) if sin(_bob_t) >= 0.0 \
			else "move_%s_f1" % _dir8(_last_dir)
		_set_frame(key)
		if _art != null:
			var s := 1.0 + 0.03 * sin(_bob_t)
			_art.scale = Vector2(0.25 * s, 0.25 * s)
	else:
		_set_frame("idle_" + _dir8(_last_dir))
		if _art != null:
			_art.scale = Vector2(0.25, 0.25)
	# Flanco de pulsacion: mantener no repite (cooldown manda).
	if Input.is_action_just_pressed(&"sprint"):
		_try_dash()


## Orienta el arte (solo visual): el fotograma lleva la direccion, el nodo
## nunca rota asi no hay saltos ni deriva de pivote.
func _face(dir: Vector2) -> void:
	_last_dir = dir.normalized() if dir != Vector2.ZERO else _last_dir


func _unhandled_input(event: InputEvent) -> void:
	if movement_locked:
		return
	if _hud_reading():
		return
	if event.is_action_pressed(&"interact"):
		var best: Interactable = get_best_interactable()
		if best != null:
			best.interact(self)
			get_viewport().set_input_as_handled()


func get_best_interactable() -> Interactable:
	if _detector == null:
		return null
	return _detector.get_best()


## Modal de lectura abierto: E lo cierra el HUD, no re-interactua.
func _hud_reading() -> bool:
	var hud: Node = get_tree().get_first_node_in_group("hud") if is_inside_tree() else null
	return hud != null and hud.has_method("is_reading") and bool(hud.call("is_reading"))


## Segundos restantes de cooldown (HUD). 0 = disponible.
func get_dash_cooldown_remaining() -> float:
	return _dash_cd


func is_dashing() -> bool:
	return _dashing


func _try_dash() -> void:
	if _dashing or _dash_cd > 0.0 or movement_locked:
		return
	var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_dash_dir = dir.normalized() if dir != Vector2.ZERO else _last_dir
	_face(_dash_dir)
	_dashing = true
	_dash_left = DASH_TIME
	_dash_age = 0.0
	_dash_cd = DASH_COOLDOWN
	_ghost_t = 0.0
	_set_frame("dash_start")
	_spawn_streak(_dash_dir)
	# Estiron a lo largo del avance (eje local Y tras rotar) + impulso.
	if _art != null:
		_art.scale = Vector2(0.25 * 0.85, 0.25 * 1.2)
		var flash := create_tween()
		flash.tween_property(_art, "modulate:a", 0.6, 0.09)
		flash.tween_property(_art, "modulate:a", 1.0, 0.09)
	Sfx.play(get_tree(), Sfx.dash())
	_emit_noise(DASH_NOISE_RADIUS)


## Fin seguro: chocar no atraviesa (move_and_slide) ni deja dentro de muro;
## el cooldown corre igual se complete o no el recorrido.
func _finish_dash() -> void:
	_dashing = false
	velocity = Vector2.ZERO
	_recover_t = 0.15
	_set_frame("dash_recovery")
	if _art != null and is_instance_valid(_art):
		var back := create_tween()
		back.tween_property(_art, "scale", Vector2(0.25, 0.25), 0.15)


## Afterimage discreta que se queda atras (no sigue al jugador).
func _spawn_ghost() -> void:
	if _art == null or _art.texture == null or not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = _art.texture
	ghost.global_position = global_position
	ghost.rotation = _art.global_rotation
	ghost.scale = _art.scale
	ghost.modulate = Color(0.5, 0.9, 1.0, 0.45)
	parent.add_child(ghost)
	var fade := ghost.create_tween()
	fade.tween_property(ghost, "modulate:a", 0.0, 0.3)
	fade.tween_callback(ghost.queue_free)


## Estela direccional corta (no ocluye: alfa baja, se desvanece en 0.25 s).
func _spawn_streak(dir: Vector2) -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null:
		return
	var tex: Texture2D = load(FX_STREAK)
	if tex == null:
		return
	var streak := Sprite2D.new()
	streak.texture = tex
	streak.global_position = global_position
	streak.rotation = dir.angle()
	streak.scale = Vector2(0.5, 0.5)
	streak.modulate = Color(0.6, 0.9, 1.0, 0.55)
	streak.z_index = -1
	parent.add_child(streak)
	var fade := streak.create_tween()
	fade.set_parallel(true)
	fade.tween_property(streak, "modulate:a", 0.0, 0.25)
	fade.tween_property(streak, "scale", Vector2(0.7, 0.35), 0.25)
	fade.chain().tween_callback(streak.queue_free)


func _emit_noise(radius: float) -> void:
	if not is_inside_tree():
		return
	var noise := get_tree().get_first_node_in_group("noise_system")
	if noise != null and noise.has_method("emit_noise"):
		noise.emit_noise(global_position, radius)
