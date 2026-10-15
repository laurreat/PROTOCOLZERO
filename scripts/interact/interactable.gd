class_name Interactable
extends Area2D
## Base interaction zone (FASE 2). Subclasses override get_prompt() and interact().
## Detection is one-way: this area is monitorable so the player's
## InteractionDetector finds it, but it monitors nothing itself.
## NOTE: monitoring=false / monitorable=true is required; reversing these flags
## would break Detector.area_entered detection.

signal interacted

@export var prompt_text: String = "Interact"


func _ready() -> void:
	monitoring = false
	monitorable = true


func get_prompt() -> String:
	return prompt_text


func interact(_player: Node2D) -> void:
	push_error("Interactable.interact() must be overridden by a subclass.")
