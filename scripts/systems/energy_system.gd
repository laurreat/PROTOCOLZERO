class_name EnergySystem
extends Node
## Authoritative energy state for the level (FASE 2, scene-local manager).
## Single writer rule: every mutation goes through set_energy(); observers
## read is_on() at startup and subscribe to energy_changed afterwards.
## Registers itself in group "energy_system" so reusable scenes (Generator,
## Terminal, Door) can resolve it without brittle cross-scene paths.

signal energy_changed(on: bool)

var energy_on: bool = false


func _ready() -> void:
	add_to_group("energy_system")


func is_on() -> bool:
	return energy_on


func set_energy(on: bool) -> void:
	if on == energy_on:
		return
	energy_on = on
	energy_changed.emit(energy_on)
