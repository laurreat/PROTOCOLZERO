class_name TechnicianRange
extends Interactable
## Interaction proxy for a parent Technician (FASE 5).
## A CharacterBody2D cannot be an Interactable, and the InteractionDetector only
## tracks Interactable areas, so the NPC exposes this child range.
## All behavior delegates to the parent Technician; this node holds no state.

func _tech() -> Technician:
	return get_parent() as Technician


func get_prompt() -> String:
	var tech := _tech()
	if tech == null:
		return super.get_prompt()
	return tech.get_prompt()


func interact(player: Node2D) -> void:
	var tech := _tech()
	if tech == null:
		push_error("TechnicianRange: parent is not a Technician.")
		return
	tech.interact(player)
	interacted.emit()
