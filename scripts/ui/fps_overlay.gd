class_name FpsOverlay
extends CanvasLayer
## Minimal FPS readout owned by the Settings autoload (part A).
## Layer 100 sits above HUD (11) and pause (12). Shows only "FPS: 60",
## top-right, refreshed at 4 Hz from Engine.get_frames_per_second().
## Visibility is driven by Settings.set_show_fps() (default hidden).

const INTERVAL := 0.25

var _label: Label = null
var _accum := 0.0


func _ready() -> void:
	layer = 100
	visible = false
	_label = Label.new()
	_label.name = "FpsLabel"
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 0.0
	_label.anchor_bottom = 0.0
	_label.offset_left = -180.0
	_label.offset_right = -16.0
	_label.offset_top = 12.0
	_label.offset_bottom = 36.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.91, 0.93, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.text = "FPS: 60"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(delta: float) -> void:
	if not visible or _label == null:
		return
	_accum += delta
	if _accum < INTERVAL:
		return
	_accum = 0.0
	_label.text = "FPS: %d" % Engine.get_frames_per_second()
