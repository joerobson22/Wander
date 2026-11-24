class_name PixelPen
extends RefCounted
## Draws on a canvas the way CanvasItem's draw_* calls do, but for pixel art:
## no smoothing at the edges, and nothing thinner or smaller than a pixel, so
## a shape drawn into a small viewport (one texel per art pixel) comes out as
## whole pixels and never vanishes. `p` is one art pixel in the canvas's units.

var canvas: CanvasItem
var p := 3.0


func _init(on: CanvasItem, pixel: float) -> void:
	canvas = on
	p = pixel


func _w(width: float) -> float:
	return maxf(width, p)


func draw_rect(rect: Rect2, colour: Color, filled: bool = true, width: float = -1.0, _aa: bool = false) -> void:
	if filled:
		canvas.draw_rect(rect.abs(), colour)
	else:
		canvas.draw_rect(rect.abs(), colour, false, _w(width))


func draw_circle(at: Vector2, r: float, colour: Color, filled: bool = true, width: float = -1.0, _aa: bool = false) -> void:
	if not filled:
		draw_arc(at, r, 0.0, TAU, 24, colour, width)
	elif r < p * 2.0:
		# Too small to be round (it would come out as a plus): a square of
		# whole pixels, one or more across.
		var side := maxf(1.0, roundf(r * 2.0 / p)) * p
		canvas.draw_rect(Rect2(((at - Vector2(side, side) * 0.5) / p).round() * p, Vector2(side, side)), colour)
	else:
		canvas.draw_circle(at, r, colour)


func draw_line(a: Vector2, b: Vector2, colour: Color, width: float = -1.0, _aa: bool = false) -> void:
	canvas.draw_line(a, b, colour, _w(width))


func draw_polyline(pts: PackedVector2Array, colour: Color, width: float = -1.0, _aa: bool = false) -> void:
	canvas.draw_polyline(pts, colour, _w(width))


func draw_arc(at: Vector2, r: float, a0: float, a1: float, points: int, colour: Color, width: float = -1.0, _aa: bool = false) -> void:
	canvas.draw_arc(at, r, a0, a1, points, colour, _w(width))


func draw_colored_polygon(pts: PackedVector2Array, colour: Color) -> void:
	canvas.draw_colored_polygon(pts, colour)


func draw_set_transform(at: Vector2, angle: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	canvas.draw_set_transform(at, angle, scale)


func draw_style_box(box: StyleBox, rect: Rect2) -> void:
	if box is StyleBoxFlat and (box as StyleBoxFlat).anti_aliasing:
		box = box.duplicate()
		(box as StyleBoxFlat).anti_aliasing = false
	canvas.draw_style_box(box, rect)
