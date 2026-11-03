@tool
extends Node2D
## The bush your pet dives into for a gift at the end of a walk
## (art/walk/bush.tscn). Its origin is where it meets the ground. Until you
## put your own sprites inside it, it draws a round leafy placeholder, in
## the editor too. It's drawn at the size of a screen 720 tall.

## The placeholder's leaf colours, dark to light.
@export var greens: Array[Color] = [Color("#4e7a46"), Color("#5f8f52"), Color("#6fa45e")]:
	set(v):
		greens = v
		queue_redraw()
## The little light dots round its top.
@export var highlight := Color("#86b874"):
	set(v):
		highlight = v
		queue_redraw()


func _ready() -> void:
	child_entered_tree.connect(func(_n): queue_redraw())
	child_exiting_tree.connect(func(_n): queue_redraw.call_deferred())


func _draw() -> void:
	if get_child_count() > 0 or greens.is_empty():
		return
	var blobs := [[-58, -28, 34], [58, -26, 32], [-30, -58, 40], [26, -60, 42], [0, -32, 46], [-6, -86, 34], [44, -44, 30], [-48, -50, 30]]
	for i in blobs.size():
		var b: Array = blobs[i]
		draw_circle(Vector2(b[0], b[1]), b[2], greens[i % greens.size()], true, -1.0, true)
	for i in 9:
		var a := -PI + PI * i / 8.0
		draw_circle(Vector2(cos(a) * 46.0, -50.0 + sin(a) * 40.0), 4.0, highlight, true, -1.0, true)
