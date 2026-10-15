class_name TechSlider
extends Control
## Technological 0-100 slider drawn in _draw (no HSlider theming needed).
## Dark track (#182532) + secondary hairline (#42566A) + faint ticks +
## red progress (#E51B23) + ring handle (red ring, white core, mini-glow).
## Mouse drag via _gui_input (press + motion); ui_left/ui_right adjust by
## keyboard_step while focused. Same value_changed(float) contract as
## HSlider; set_value_no_signal() skips emission for external sync.

signal value_changed(value: float)
## Emitted on left-button release after a drag (part A: menu plays a confirm
## blip on release). No visual change; keyboard steps do not emit it.
signal drag_ended

@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var keyboard_step: float = 5.0

const _TRACK := Color(0.094, 0.145, 0.196, 1.0)
const _SECOND := Color(0.259, 0.337, 0.416, 1.0)
const _RED := Color(0.898, 0.106, 0.137, 1.0)
const _WHITE := Color(0.906, 0.929, 0.953, 1.0)
const _TRACK_H := 6.0
const _HANDLE_R := 8.0
const _MARGIN := 12.0

var value: float = 100.0
var _dragging := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)


## Clamped set with signal (mouse drag / keyboard path).
func set_value(v: float) -> void:
	var clamped := roundf(clampf(v, min_value, max_value))
	if is_equal_approx(clamped, value):
		return
	value = clamped
	queue_redraw()
	value_changed.emit(value)


## Clamped set without signal (external sync from saved settings).
func set_value_no_signal(v: float) -> void:
	value = roundf(clampf(v, min_value, max_value))
	queue_redraw()


func _draw() -> void:
	var cy := size.y * 0.5
	var x0 := _MARGIN
	var x1 := size.x - _MARGIN
	if x1 <= x0:
		return
	var frac := clampf((value - min_value) / maxf(1.0, max_value - min_value), 0.0, 1.0)
	var hx := lerpf(x0, x1, frac)
	# Secondary tech hairline below the track.
	draw_line(Vector2(x0, cy + 9.0), Vector2(x1, cy + 9.0), Color(_SECOND, 0.55), 1.0)
	# Dark track.
	draw_rect(Rect2(x0, cy - _TRACK_H * 0.5, x1 - x0, _TRACK_H), _TRACK)
	# Faint ticks every 10%.
	for i in range(11):
		var tx := lerpf(x0, x1, float(i) / 10.0)
		draw_line(
			Vector2(tx, cy - _TRACK_H * 0.5 - 3.0),
			Vector2(tx, cy - _TRACK_H * 0.5 - 1.0),
			Color(_SECOND, 0.4), 1.0
		)
	# Red progress + tip glow.
	if hx > x0:
		draw_rect(Rect2(x0, cy - _TRACK_H * 0.5, hx - x0, _TRACK_H), _RED)
		draw_circle(Vector2(hx, cy), _TRACK_H, Color(_RED, 0.25))
	# Ring handle: mini-glow + red ring + white core.
	var hp := Vector2(hx, cy)
	draw_circle(hp, _HANDLE_R + 4.0, Color(_RED, 0.16))
	draw_arc(hp, _HANDLE_R, 0.0, TAU, 24, _RED, 3.0, true)
	draw_circle(hp, 3.0, _WHITE)
	# Visible keyboard-focus frame (distinct from hover: there is no hover
	# fill on this control, the ring is the value indicator).
	if has_focus():
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), _RED, false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				grab_focus()
				_set_from_x(mb.position.x)
			elif _dragging:
				_dragging = false
				drag_ended.emit()
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_set_from_x(mm.position.x)
			accept_event()
	elif event.is_action_pressed(&"ui_left"):
		set_value(value - keyboard_step)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		set_value(value + keyboard_step)
		accept_event()


func _set_from_x(x: float) -> void:
	var x0 := _MARGIN
	var x1 := size.x - _MARGIN
	if x1 <= x0:
		return
	var frac := clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	set_value(lerpf(min_value, max_value, frac))
