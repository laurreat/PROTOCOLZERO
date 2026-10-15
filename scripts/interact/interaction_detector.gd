class_name InteractionDetector
extends Area2D
## Player-owned sensor (FASE 2). Tracks overlapping Interactable areas,
## keeps the nearest one, and exposes it via get_best().
## Only area_entered/exited are used: doors expose an Interactable child
## (DoorRange), so StaticBody2D gates need no body-signal handling here.

var _tracked: Array[Interactable] = []


func _ready() -> void:
	monitorable = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func get_best() -> Interactable:
	_sweep_invalid()
	var best: Interactable = null
	var best_distance: float = INF
	for candidate in _tracked:
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		var candidate := area as Interactable
		if not _tracked.has(candidate):
			_tracked.append(candidate)


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		_tracked.erase(area as Interactable)


func _sweep_invalid() -> void:
	for index in range(_tracked.size() - 1, -1, -1):
		if not is_instance_valid(_tracked[index]):
			_tracked.remove_at(index)
