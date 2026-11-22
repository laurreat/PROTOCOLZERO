class_name Interactable
extends Area2D
## Base interaction zone (FASE 2). Subclasses override get_prompt() and interact().
## Detection is one-way: this area is monitorable so the player's
## InteractionDetector finds it, but it monitors nothing itself.
## NOTE: monitoring=false / monitorable=true is required; reversing these flags
## would break Detector.area_entered detection.
##
## CAM-01 (Tarea 3): every interactable draws its own cyan focus ring, built in
## code from the area's real collision radius, so generator, terminal, doors
## (DoorRange proxy), archive plaques and ZERO all get the same contextual
## signal without touching each scene. The ring is hidden by default and only
## the scene coordinator lights the one the player can actually use.

signal interacted

@export var prompt_text: String = "Interact"

const FOCUS_COLOR := Color(0.4, 0.92, 1.0, 0.7)
const FOCUS_FALLBACK_RADIUS := 26.0
## Dashed ring: reads as "highlight", never confused with the solid pulse sweep.
const FOCUS_DASHES := 12
const FOCUS_DASH_DEGREES := 20.0

var _focus_ring: Node2D
var _focus_tween: Tween
var _focused := false


func _ready() -> void:
	monitoring = false
	monitorable = true
	_build_focus_ring()


## Dashed outline at the area's real CircleShape2D radius (rectangle areas use
## the fallback). Only Line2D nodes: no textures, no particles, no shaders.
func _build_focus_ring() -> void:
	_focus_ring = Node2D.new()
	_focus_ring.name = "FocusRing"
	_focus_ring.z_index = 1
	var radius := _zone_radius()
	var step := TAU / float(FOCUS_DASHES)
	var span := deg_to_rad(FOCUS_DASH_DEGREES)
	for i in FOCUS_DASHES:
		var start := step * float(i)
		var dash := Line2D.new()
		dash.width = 2.5
		dash.default_color = FOCUS_COLOR
		dash.antialiased = true
		var points := PackedVector2Array()
		for k in 4:
			var angle := start + span * float(k) / 3.0
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		dash.points = points
		_focus_ring.add_child(dash)
	_focus_ring.visible = false
	add_child(_focus_ring)


func _zone_radius() -> float:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		return (shape_node.shape as CircleShape2D).radius
	return FOCUS_FALLBACK_RADIUS


## Contextual highlight, driven by the level coordinator (only the interaction
## the player would actually trigger is lit, so the screen never fills up).
func set_focused(on: bool) -> void:
	if _focused == on:
		return
	_focused = on
	if _focus_ring == null:
		return
	_kill_focus_tween()
	if not on:
		_focus_ring.visible = false
		return
	_focus_ring.visible = true
	_focus_ring.modulate.a = 1.0
	_focus_tween = create_tween().set_loops()
	_focus_tween.tween_property(_focus_ring, "modulate:a", 0.4, 0.7)
	_focus_tween.tween_property(_focus_ring, "modulate:a", 1.0, 0.7)


func is_focused() -> bool:
	return _focused


func _kill_focus_tween() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = null


func get_prompt() -> String:
	return prompt_text


func interact(_player: Node2D) -> void:
	push_error("Interactable.interact() must be overridden by a subclass.")
