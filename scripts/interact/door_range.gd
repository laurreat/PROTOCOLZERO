class_name DoorRange
extends Interactable
## Interaction proxy for a parent Door (FASE 2).
## A StaticBody2D cannot be an Interactable, and the InteractionDetector only
## tracks Interactable areas, so the door exposes this child range.
## All behavior delegates to the parent Door; this node holds no state.

func _door() -> Door:
	return get_parent() as Door


func get_prompt() -> String:
	var door := _door()
	if door == null:
		return super.get_prompt()
	return door.get_prompt()


func interact(player: Node2D) -> void:
	var door := _door()
	if door == null:
		push_error("DoorRange: parent is not a Door.")
		return
	door.interact(player)
	interacted.emit()
