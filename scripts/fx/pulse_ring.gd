extends Node2D
## Expanding pulse ring FX (FASE 4). Draws one fading circle outline that grows
## from 20% to full radius, then frees itself. No particles: a single _draw.


var max_radius := 220.0
var duration := 0.5

var _age := 0.0


func setup(radius: float, ring_duration: float = 0.5) -> void:
	max_radius = maxf(1.0, radius)
	duration = maxf(0.05, ring_duration)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= duration:
		queue_free()


func _draw() -> void:
	var k := clampf(_age / duration, 0.0, 1.0)
	var radius := max_radius * lerpf(0.2, 1.0, k)
	var alpha := 1.0 - k
	draw_circle(Vector2.ZERO, radius, Color(0.4, 0.9, 1.0, 0.10 * alpha))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.4, 0.9, 1.0, 0.9 * alpha), 4.0)
