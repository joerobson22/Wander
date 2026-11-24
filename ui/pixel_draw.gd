class_name PixelDraw
extends RefCounted
## Draws shapes on a pixel grid, so scenery drawn in code is pixel art like
## the animals and gifts (art/pixel_src). One art pixel is `p` screen units:
## 3 on a screen 720 tall, whatever the shape's size. Make one for a canvas in
## its _draw() and draw through it: polygons, circles, lines and rects come
## out as whole pixels, with no smoothing.

## The pixel size for a screen `height` units tall: the same 240 rows of
## pixels on every screen.
const ROWS := 240.0

var canvas: CanvasItem
var p := 3.0
## Where the grid's columns start, so neighbouring canvases share one grid.
var ox := 0.0


static func size_for(height: float) -> float:
	return maxf(1.0, height / ROWS)


func _init(on: CanvasItem, pixel: float, grid_x: float = 0.0) -> void:
	canvas = on
	p = pixel
	ox = fposmod(grid_x, pixel)


## The grid column or row a coordinate falls in, as its left or top edge.
func snap_x(x: float) -> float:
	return floorf((x + ox) / p + 0.0001) * p - ox


func snap_y(y: float) -> float:
	return floorf(y / p + 0.0001) * p


## The first column whose middle is at or past `x`.
func _col(x: float) -> float:
	return ceilf((x + ox) / p - 0.5 - 0.0001) * p - ox


func _span(y: float, x1: float, x2: float, colour: Color) -> void:
	var a := _col(x1)
	var b := _col(x2)
	if b > a:
		canvas.draw_rect(Rect2(a, y, b - a, p), colour)


func rect(r: Rect2, colour: Color) -> void:
	var a := Vector2(_col(r.position.x), snap_y(r.position.y + p * 0.5))
	var b := Vector2(_col(r.end.x), snap_y(r.end.y + p * 0.5))
	b.x = maxf(b.x, a.x + p)
	b.y = maxf(b.y, a.y + p)
	canvas.draw_rect(Rect2(a, b - a), colour)


## A one-pixel square at (x, y).
func dot(at: Vector2, colour: Color, pixels: int = 1) -> void:
	canvas.draw_rect(Rect2(snap_x(at.x), snap_y(at.y), p * pixels, p * pixels), colour)


func poly(pts: PackedVector2Array, colour: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var top := INF
	var bottom := -INF
	for v in pts:
		top = minf(top, v.y)
		bottom = maxf(bottom, v.y)
	var y := snap_y(top)
	var xs: Array[float] = []
	while y < bottom:
		var yc := y + p * 0.5
		xs.clear()
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			_span(y, xs[k], xs[k + 1], colour)
		y += p


func ellipse(c: Vector2, radius: Vector2, colour: Color) -> void:
	if radius.x < p * 0.6 or radius.y < p * 0.6:
		dot(c, colour)
		return
	var y := snap_y(c.y - radius.y)
	while y < c.y + radius.y:
		var dy := (y + p * 0.5 - c.y) / radius.y
		if absf(dy) < 1.0:
			var hw := radius.x * sqrt(1.0 - dy * dy)
			_span(y, c.x - hw, c.x + hw, colour)
		y += p


func circle(c: Vector2, r: float, colour: Color) -> void:
	ellipse(c, Vector2(r, r), colour)


## A circle's edge, a pixel thick.
func ring(c: Vector2, r: float, colour: Color) -> void:
	var steps := maxi(8, int(TAU * r / p))
	var last := Vector2(INF, INF)
	for k in steps:
		var a := TAU * k / steps
		var at := Vector2(snap_x(c.x + cos(a) * r), snap_y(c.y + sin(a) * r))
		if at != last:
			canvas.draw_rect(Rect2(at, Vector2(p, p)), colour)
			last = at


## A line `width` wide (at least a pixel), stepped pixel by pixel.
func line(a: Vector2, b: Vector2, colour: Color, width: float = 1.0) -> void:
	var w := maxf(p, roundf(width / p) * p)
	var steps := maxi(1, ceili(a.distance_to(b) / p))
	var half := Vector2(w, w) * 0.5
	var last := Vector2(INF, INF)
	for k in steps + 1:
		var at := a.lerp(b, float(k) / steps) - half
		at = Vector2(snap_x(at.x + p * 0.5), snap_y(at.y + p * 0.5))
		if at != last:
			canvas.draw_rect(Rect2(at, Vector2(w, w)), colour)
			last = at


func polyline(pts: PackedVector2Array, colour: Color, width: float = 1.0) -> void:
	for k in pts.size() - 1:
		line(pts[k], pts[k + 1], colour, width)


## A vertical band of colours from `top` to `bottom`, stepping through
## `bands` flat shades with a dithered row where each meets the next.
func gradient(r: Rect2, top: Color, bottom: Color, bands: int = 10) -> void:
	var rows := maxi(1, ceili(r.size.y / p))
	var per := maxf(1.0, float(rows) / bands)
	var y := r.position.y
	for row in rows:
		var band := floori(row / per)
		var shade := top.lerp(bottom, band / maxf(1.0, bands - 1.0))
		canvas.draw_rect(Rect2(r.position.x, y, r.size.x, p), shade)
		# The last row of a band: every other pixel takes the next shade.
		if fposmod(row + 1, per) < 1.0 and band < bands - 1:
			var next := top.lerp(bottom, (band + 1) / maxf(1.0, bands - 1.0))
			var x := snap_x(r.position.x) + (p if row % 2 else 0.0)
			while x < r.end.x:
				canvas.draw_rect(Rect2(x, y, p, p), next)
				x += p * 2.0
		y += p


# The same calls as a CanvasItem's draw_*, so code written for a canvas
# (CharacterView.draw_helmet) can draw on the grid instead. Each fills every
# pixel once, so see-through colours stay even.

func draw_rect(r: Rect2, colour: Color, filled: bool = true, width: float = -1.0, _aa: bool = false) -> void:
	if filled:
		rect(r, colour)
	else:
		var w := maxf(width, p)
		rect(Rect2(r.position, Vector2(r.size.x, w)), colour)
		rect(Rect2(r.position + Vector2(0, r.size.y - w), Vector2(r.size.x, w)), colour)
		rect(Rect2(r.position + Vector2(0, w), Vector2(w, r.size.y - w * 2)), colour)
		rect(Rect2(r.position + Vector2(r.size.x - w, w), Vector2(w, r.size.y - w * 2)), colour)


func draw_circle(at: Vector2, r: float, colour: Color, filled: bool = true, width: float = -1.0, _aa: bool = false) -> void:
	if filled:
		circle(at, r, colour)
	else:
		draw_arc(at, r, 0.0, TAU, 32, colour, width)


func draw_arc(at: Vector2, r: float, a0: float, a1: float, _points: int, colour: Color, width: float = -1.0, _aa: bool = false) -> void:
	var w := maxf(width, p)
	var steps := maxi(6, ceili(absf(a1 - a0) * r / p))
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / steps)
		outer.append(at + Vector2.from_angle(a) * (r + w * 0.5))
		inner.append(at + Vector2.from_angle(a) * maxf(0.0, r - w * 0.5))
	inner.reverse()
	outer.append_array(inner)
	poly(outer, colour)


func draw_line(a: Vector2, b: Vector2, colour: Color, width: float = -1.0, _aa: bool = false) -> void:
	var w := maxf(width, p)
	var side := (b - a).orthogonal().normalized() * w * 0.5
	if side == Vector2.ZERO:
		dot(a, colour)
		return
	poly(PackedVector2Array([a + side, b + side, b - side, a - side]), colour)


func draw_colored_polygon(pts: PackedVector2Array, colour: Color) -> void:
	poly(pts, colour)
