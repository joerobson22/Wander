class_name Snowfall
extends Control
## Gentle snow falling across its rect, behind the menus at Christmas.

@export var flakes := 80
@export var colour := Color(1, 1, 1, 0.85)

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var area := clampf(size.x * size.y / (720.0 * 720.0), 0.5, 3.0)
	for i in int(flakes * area):
		var speed := 24.0 + 36.0 * Fireworks._hash(i, 6.0)
		var y := fposmod(Fireworks._hash(i, 7.0) * size.y + _time * speed, size.y + 20.0) - 10.0
		var x := fposmod(Fireworks._hash(i, 8.0) * size.x + sin(_time * 0.6 + i) * 14.0 - _time * 8.0, size.x + 20.0) - 10.0
		draw_circle(Vector2(x, y), 1.2 + 2.0 * Fireworks._hash(i, 9.0), colour)
