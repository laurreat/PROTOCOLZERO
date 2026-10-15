class_name NoiseSystem
extends Node
## Event-only noise bus (FASE 4, scene-local manager like EnergySystem).
## No realistic physics: emit_noise() forwards a position event to every drone
## within radius; each drone decides via hear_noise().
## Drones live in group "enemies" (see security_drone.gd); group
## "security_drone" is also honored so the FASE 4 spec group works literally.
## No cameras exist in the MVP; camera-disabling hooks belong to FASE 5+.

const DRONE_GROUPS: Array[String] = ["security_drone", "enemies"]


func _ready() -> void:
	add_to_group("noise_system")


## Broadcasts a noise event at pos with the given radius in pixels.
func emit_noise(pos: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	var tree := get_tree()
	if tree == null:
		return
	var seen: Dictionary = {}
	for group in DRONE_GROUPS:
		for node in tree.get_nodes_in_group(group):
			if seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			if not node.has_method("hear_noise"):
				continue
			var body := node as Node2D
			if body == null:
				continue
			if body.global_position.distance_to(pos) <= radius:
				node.hear_noise(pos)
