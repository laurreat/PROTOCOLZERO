class_name PulseDevice
extends Node2D
## Pulse tool (FASE 4): a defensive interrupt, NEVER a weapon.
## SPACE (pulse action) stuns SecurityDrones inside pulse_radius for stun_time.
## Trade-off: firing emits a loud noise (loud_noise_radius) that can attract
## drones standing further away. Cooldown blocks repeat use; denial feedback
## is rate-limited so holding SPACE does not spam the log.
## The pulse NEVER damages: it only calls drone.stun() (interrupt).
## No cameras exist in the MVP, so nothing is disabled here (hook noted below).
## Visual: spawns an expanding ring (pulse_ring.tscn) at the player position.

signal pulse_used
## CAM-04 (Tarea 3): read-only outcome events for HUD feedback. The mechanic
## itself (radius, cooldown, stun time, noise) is untouched.
signal pulse_result(stunned: int, radius: float)
signal pulse_ended(stunned: int)

@export var pulse_radius := 220.0
@export var pulse_cooldown := 6.0
@export var stun_time := 4.0
@export var loud_noise_radius := 300.0
@export var ring_duration := 0.5
@export var ring_scene: PackedScene = preload("res://scenes/fx/pulse_ring.tscn")

var _cooldown := 0.0
var _deny_quiet := 0.0


func _ready() -> void:
	add_to_group("pulse_device")


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	if _deny_quiet > 0.0:
		_deny_quiet = maxf(0.0, _deny_quiet - delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pulse"):
		if try_pulse():
			get_viewport().set_input_as_handled()


## Fires the pulse when off cooldown. Returns true on success.
func try_pulse() -> bool:
	if _cooldown > 0.0:
		if _deny_quiet <= 0.0:
			_deny_quiet = 0.5
			print("PulseDevice: recharging (%.1fs left)." % _cooldown)
			Sfx.play(get_tree(), Sfx.ui_deny())
		return false
	_cooldown = pulse_cooldown
	var stunned := _stun_nearby()
	_emit_loud_noise()
	_spawn_ring()
	pulse_used.emit()
	pulse_result.emit(stunned, pulse_radius)
	_schedule_pulse_end(stunned)
	Sfx.play(get_tree(), Sfx.pulse_sweep())
	print("PulseDevice: pulse fired (%d drone(s) stunned)." % stunned)
	return true


func get_cooldown_remaining() -> float:
	return _cooldown


## Returns how many drones the pulse actually interrupted (HUD feedback).
func _stun_nearby() -> int:
	var total := 0
	var tree := get_tree()
	if tree == null:
		return total
	var seen: Dictionary = {}
	for group in ["security_drone", "enemies"]:
		for node in tree.get_nodes_in_group(group):
			if seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			if not node.has_method("stun"):
				continue
			var body := node as Node2D
			if body == null:
				continue
			if body.global_position.distance_to(global_position) <= pulse_radius:
				node.stun(stun_time)
				total += 1
	# FASE 5 hook (no cameras in MVP): stun above only interrupts drones via
	# drone.stun(). When security cameras exist, disable the ones in group
	# "security_camera" inside pulse_radius here for stun_time.
	return total


## End-of-stun notice (CAM-04: activation and duration read differently in
## the HUD). WeakRef + lambda so a scene change mid-timer is a no-op.
func _schedule_pulse_end(count: int) -> void:
	if count <= 0 or not is_inside_tree():
		return
	var ref: WeakRef = weakref(self)
	var timer: SceneTreeTimer = get_tree().create_timer(stun_time, false)
	timer.timeout.connect(func() -> void:
		var device: Object = ref.get_ref()
		if device != null and device.is_inside_tree():
			device.emit_signal("pulse_ended", count))


func _emit_loud_noise() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var noise := tree.get_first_node_in_group("noise_system")
	if noise != null and noise.has_method("emit_noise"):
		noise.emit_noise(global_position, loud_noise_radius)


func _spawn_ring() -> void:
	if ring_scene == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	# current_scene is null when the level is hosted outside the scene-change
	# flow (SceneTree probes); fall back to the root viewport in that case.
	var host: Node = tree.current_scene
	if host == null:
		host = tree.root
	if host == null:
		return
	var ring := ring_scene.instantiate() as Node2D
	if ring == null:
		return
	host.add_child(ring)
	ring.global_position = global_position
	if ring.has_method("setup"):
		ring.setup(pulse_radius, ring_duration)
