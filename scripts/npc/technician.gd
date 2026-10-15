class_name Technician
extends CharacterBody2D
## Field technician NPC (FASE 5). Simple 4-state helper that chains FASE 2 systems.
## The player talks to the NPC with E through the child TechnicianRange proxy,
## because the InteractionDetector only tracks Interactable areas (same pattern
## as DoorRange). If energy is OFF the NPC refuses and points at the generator;
## if ON it walks to Door B, channels a 3s repair with blink feedback, then
## calls set_repaired() so the maintenance gate becomes operational.
## No complex dialogue: short sequential messages via prints, prompt text and a
## floating status label. Movement is direct steering with move_and_slide; the
## site sits a short clear walk south of Door B by level design.

enum State { IDLE, TO_SITE, REPAIRING, DONE }

signal state_changed(state: State)

@export var repair_target_path: NodePath
@export var move_speed := 120.0
@export var arrive_distance := 40.0
@export var repair_time := 3.0
@export var stand_offset := Vector2(0.0, 70.0)

const COLOR_IDLE := Color(0.2, 0.9, 0.9)
const COLOR_BUSY := Color(0.3, 0.7, 0.9)
const COLOR_DONE := Color(0.35, 0.9, 0.5)

var state: State = State.IDLE

var _repair_left := 0.0
var _blink := 0.0
var _energy: EnergySystem

@onready var _visual: Polygon2D = $Visual
@onready var _status: Label = $StatusLabel
@onready var _detail: Sprite2D = $Detail

const TECH_DIR := "res://assets/visual/characters/tech/"
const TECH_8 := ["north", "north_east", "east", "south_east", "south",
	"south_west", "west", "north_west"]

var _tframes := {}
var _face := "south"


func _load_frames() -> void:
	for d in TECH_8:
		_tframes["idle_" + d] = load(TECH_DIR + "tech_idle_%s.png" % d)
		_tframes["move_%s_f0" % d] = load(TECH_DIR + "tech_move_%s_f0.png" % d)
		_tframes["move_%s_f1" % d] = load(TECH_DIR + "tech_move_%s_f1.png" % d)
	for i in 3:
		_tframes["repair_f%d" % i] = load(TECH_DIR + "tech_repair_f%d.png" % i)
	_tframes["interact"] = load(TECH_DIR + "tech_interact.png")
	_tframes["react"] = load(TECH_DIR + "tech_react.png")
	_tframes["done"] = load(TECH_DIR + "tech_done.png")


func _tdir8(d: Vector2) -> String:
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


func _tset(key: String) -> void:
	if _detail == null or not _tframes.has(key):
		return
	var t: Texture2D = _tframes[key]
	if t != null and _detail.texture != t:
		_detail.texture = t


func _ready() -> void:
	_load_frames()
	_tset("idle_south")
	_energy = get_tree().get_first_node_in_group("energy_system") as EnergySystem
	if _energy == null:
		push_error("Technician: no EnergySystem found in group 'energy_system'.")
	elif _energy.has_signal("energy_changed"):
		_energy.energy_changed.connect(_on_energy_security)
	_refresh_visual()
	_refresh_status()


## Display-only refresh so the floating status label never contradicts the
## live prompt (get_prompt reads energy live; the label previously went stale
## after boot). No behavior change: state machine and movement untouched.
func _on_energy_security(_on: bool) -> void:
	_refresh_visual()
	_refresh_status()


func get_target() -> Door:
	if repair_target_path.is_empty():
		return null
	return get_node_or_null(repair_target_path) as Door


func is_energy_on() -> bool:
	return _energy != null and _energy.is_on()


func repair_site() -> Vector2:
	var door := get_target()
	if door == null:
		return global_position
	return door.global_position + stand_offset


func get_prompt() -> String:
	match state:
		State.IDLE:
			if is_energy_on():
				return "Ask technician for repairs [E]"
			return "Technician: restore power first [E]"
		State.TO_SITE:
			return "Technician: on my way..."
		State.REPAIRING:
			return "Repairing... %.1fs" % maxf(_repair_left, 0.0)
		_:
			return "Maintenance gate operational. Good luck."


func interact(_player: Node2D) -> void:
	_maybe_warn_quiet()
	match state:
		State.DONE:
			print("Technician: gate is open, move out.")
			Sfx.message(get_tree(), "Maintenance gate operational. Good luck.")
			return
		State.TO_SITE, State.REPAIRING:
			print("Technician: repair in progress, hold on.")
			Sfx.message(get_tree(), "Repair in progress, hold on.")
			return
		State.IDLE:
			if get_target() == null:
				push_error("Technician: repair_target_path is empty or invalid.")
				return
			if not is_energy_on():
				print("Technician: restore power first.")
				Sfx.play(get_tree(), Sfx.ui_deny())
				Sfx.message(get_tree(), "Restore power first.")
				_face_to_player(_player)
				_tset("react")
				return
			state = State.TO_SITE
			_face_to_player(_player)
			print("Technician: on my way to the maintenance gate.")
			Sfx.play(get_tree(), Sfx.ui_ok())
			Sfx.message(get_tree(), "Technician on the way.")
			state_changed.emit(state)
			_refresh_visual()
			_refresh_status()


func _physics_process(delta: float) -> void:
	match state:
		State.TO_SITE:
			_step_to_site()
		State.REPAIRING:
			_step_repair(delta)


func _step_to_site() -> void:
	var to: Vector2 = repair_site() - global_position
	if to.length() <= arrive_distance:
		velocity = Vector2.ZERO
		state = State.REPAIRING
		_repair_left = repair_time
		_blink = 0.0
		print("Technician: starting repairs.")
		state_changed.emit(state)
		_refresh_visual()
		_refresh_status()
		return
	velocity = to.normalized() * move_speed
	_face = _tdir8(to)
	var phase := int(Time.get_ticks_msec() / 150) % 2
	_tset("move_%s_f%d" % [_face, phase])
	move_and_slide()


func _step_repair(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_repair_left -= delta
	_blink += delta
	if _visual != null:
		_visual.modulate.a = 0.55 + 0.45 * sin(_blink * 12.0)
	# Fases 1:1 con los 3 s reales de reparacion (f0 -> f1 -> f2).
	if _repair_left > 2.0:
		_tset("repair_f0")
	elif _repair_left > 1.0:
		_tset("repair_f1")
	else:
		_tset("repair_f2")
	_refresh_status()
	if _repair_left <= 0.0:
		_finish_repair()


func _finish_repair() -> void:
	var door := get_target()
	if door == null:
		push_error("Technician: repair target lost.")
		state = State.IDLE
		_refresh_visual()
		_refresh_status()
		return
	door.set_repaired()
	state = State.DONE
	if _visual != null:
		_visual.modulate.a = 1.0
	print("Technician: maintenance gate repaired.")
	Sfx.play(get_tree(), Sfx.ui_ok())
	Sfx.message(get_tree(), "Maintenance gate repaired.")
	state_changed.emit(state)
	_refresh_visual()
	_refresh_status()


func _refresh_visual() -> void:
	if _visual == null:
		return
	match state:
		State.IDLE:
			_visual.color = COLOR_IDLE
			_tset("idle_" + _face)
		State.DONE:
			_visual.color = COLOR_DONE
			_tset("done")
		State.REPAIRING:
			_visual.color = COLOR_BUSY
		_:
			_visual.color = COLOR_BUSY
			_tset("interact")


## Mira al jugador al hablar (solo visual; sin tocar movimiento ni IA).
func _face_to_player(p: Node2D) -> void:
	if p == null or not is_instance_valid(p):
		return
	var to: Vector2 = p.global_position - global_position
	if to.length() > 1.0:
		_face = _tdir8(to)
		if state == State.IDLE:
			_tset("idle_" + _face)
		else:
			_tset("interact")


func _refresh_status() -> void:
	if _status == null:
		return
	match state:
		State.IDLE:
			_status.text = "Tech: need power" if not is_energy_on() else "Tech: ready"
		State.TO_SITE:
			_status.text = "Tech: moving"
		State.REPAIRING:
			_status.text = "Fixing %.1f" % maxf(_repair_left, 0.0)
		_:
			_status.text = "Tech: done"


## Minimo viable (Sector 01): si el dron esta cerca (<300px), linea corta.
func _maybe_warn_quiet() -> void:
	if not is_inside_tree():
		return
	var drone := get_tree().get_first_node_in_group("security_drone") as Node2D
	if drone == null:
		drone = get_tree().get_first_node_in_group("enemies") as Node2D
	if drone == null:
		return
	if global_position.distance_to(drone.global_position) < 300.0:
		print("Technician: keep quiet.")
		Sfx.message(get_tree(), "Keep quiet.")
