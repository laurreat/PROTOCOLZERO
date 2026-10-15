class_name ExitZone
extends Area2D
## Win trigger (FASE 6). The pad visuals stay placeholders; this area watches
## for the player body and routes the single win transition through Main.
## Main.game_win() guards duplicates, so overlapping bodies are harmless.

signal player_entered


func _ready() -> void:
	add_to_group("exit_zone")
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not _is_zero_done():
		print("ExitZone: zero system required.")
		Sfx.play(get_tree(), Sfx.ui_deny())
		Sfx.message(get_tree(), "Zero system required.")
		return
	player_entered.emit()
	var tree := get_tree()
	if tree == null:
		return
	var game := tree.get_first_node_in_group("game")
	if game != null and game.has_method("game_win"):
		game.game_win()


## GATED (Sector 01): sin ZERO no hay victoria. Lee el latch del ZeroSystem.
func _is_zero_done() -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	var zero := tree.get_first_node_in_group("zero_system")
	if zero != null and "zero_used" in zero:
		return bool(zero.get("zero_used"))
	var game_parent: Node = null
	var exit_parent := get_parent()
	if exit_parent != null:
		var node := exit_parent.get_node_or_null("ZeroSystem")
		if node != null and "zero_used" in node:
			return bool(node.get("zero_used"))
	return false
