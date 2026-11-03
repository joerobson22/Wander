class_name CircleReveal
extends Control
## Shows its content through a circle that grows from a point until it fills
## the screen, and shrinks back to close: how full-screen flows open over the
## app. Clipping is switched off once fully open, so it costs nothing while
## the flow is in use.

var origin := Vector2.ZERO
var _radius := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	if clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
		draw_circle(origin, _radius, Color.WHITE, true, -1.0, true)


func _set_radius(r: float) -> void:
	_radius = r
	queue_redraw()


## Distance from the origin to the farthest corner: a circle this big covers everything.
func _full() -> float:
	var r := 0.0
	for corner in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		r = maxf(r, origin.distance_to(corner))
	return r + 2.0


func open(instant: bool = false, seconds: float = Motion.SLOW) -> Tween:
	if instant:
		clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		queue_redraw()
		return null
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_set_radius(0.0)
	var t := Motion.method(self, "reveal", _set_radius, 0.0, _full(), seconds)
	t.tween_callback(func():
		clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		queue_redraw())
	return t


## Shrinks back to the origin, then frees itself. With `to_radius` it
## stops at a circle that big (the focus orb's), fading away as it gets
## there.
func close(seconds: float = Motion.SLOW, to_radius: float = 0.0) -> Tween:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var t := Motion.method(self, "reveal", _set_radius, _full(), to_radius, seconds)
	if to_radius > 0.0:
		t.parallel().tween_property(self, "modulate:a", 0.0, Motion.time(seconds * 0.4)).set_delay(Motion.time(seconds * 0.6))
	t.tween_callback(queue_free)
	return t
