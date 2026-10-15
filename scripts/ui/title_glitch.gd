extends Label
## Subtle chromatic-aberration glitch for one menu title line.
## Two ghost copies (GhostR reddish, GhostC cyan, children of this label,
## drawn behind it) sit at a permanent +-rest_offset so the title always
## carries a faint aberration. On an irregular timer (2-6s) a short event
## (0.08-0.15s) pushes the ghosts further out and raises their alpha, then
## settles back to rest. The main label never moves: always legible, no
## permanent shaking. Entry fade is inherited from the parent modulate.
## Probe API: is_event_active(), trigger_event(), settle_to_rest().

@export var min_wait := 2.0
@export var max_wait := 6.0
@export var min_event := 0.08
@export var max_event := 0.15
@export var rest_offset := 1.5
@export var event_shift_min := 2.0
@export var event_shift_max := 4.0
@export var rest_alpha := 0.35
@export var event_alpha := 0.8

var event_active := false

var _ghost_r: Label = null
var _ghost_c: Label = null
var _wait_left := 0.0
var _event_left := 0.0


func _ready() -> void:
	_ghost_r = get_node_or_null("GhostR") as Label
	_ghost_c = get_node_or_null("GhostC") as Label
	_apply_rest()
	_schedule_next()


func _process(delta: float) -> void:
	if _ghost_r == null or _ghost_c == null:
		return
	if event_active:
		_event_left -= delta
		if _event_left <= 0.0:
			settle_to_rest()
	else:
		_wait_left -= delta
		if _wait_left <= 0.0:
			trigger_event()


func is_event_active() -> bool:
	return event_active


## Starts a glitch event now (also called by the internal timer).
func trigger_event() -> void:
	if _ghost_r == null or _ghost_c == null:
		return
	event_active = true
	_event_left = randf_range(min_event, max_event)
	var shift := randf_range(event_shift_min, event_shift_max)
	if randf() < 0.5:
		shift = -shift
	_ghost_r.position.x = rest_offset + shift
	_ghost_c.position.x = -rest_offset + shift
	_ghost_r.modulate.a = event_alpha
	_ghost_c.modulate.a = event_alpha


## Returns ghosts to the permanent rest aberration.
func settle_to_rest() -> void:
	event_active = false
	_apply_rest()
	_schedule_next()


func _apply_rest() -> void:
	if _ghost_r != null:
		_ghost_r.position.x = rest_offset
		_ghost_r.modulate.a = rest_alpha
	if _ghost_c != null:
		_ghost_c.position.x = -rest_offset
		_ghost_c.modulate.a = rest_alpha


func _schedule_next() -> void:
	_wait_left = randf_range(min_wait, max_wait)
