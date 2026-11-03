@tool
class_name Festoon
extends Control
## A string hung in swags across its width, dipping as deep as it is tall:
## fairy lights or party bunting. Used over the menus (art/holidays/*/menu.tscn),
## on the trees behind them (home.tscn) and, drawn with swag(), on the trees
## you walk past. Rotate it to drape it across something.

enum Kind { LIGHTS, BUNTING }

@export var kind := Kind.LIGHTS:
	set(v):
		kind = v
		queue_redraw()
## Roughly how wide each swag is; the width is shared out evenly.
@export var swag_width := 260.0:
	set(v):
		swag_width = maxf(v, 8.0)
		queue_redraw()
## How far apart the bulbs or flags are along the string.
@export var spacing := 28.0:
	set(v):
		spacing = maxf(v, 4.0)
		queue_redraw()
## A bulb's radius, or a flag's width.
@export var bulb := 5.0:
	set(v):
		bulb = v
		queue_redraw()
@export var colours := PackedColorArray([Color("#e8483c"), Color("#f2c53d"), Color("#4fb06d"), Color("#4a8fd9")]):
	set(v):
		colours = v
		queue_redraw()
@export var wire := Color("#3b302b"):
	set(v):
		wire = v
		queue_redraw()
## Lights glow brighter and dimmer, one after another.
@export var twinkle := true

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if twinkle and kind == Kind.LIGHTS and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var n := maxi(1, roundi(size.x / swag_width))
	var each := size.x / n
	for i in n:
		swag(self, Vector2(each * i, 0), Vector2(each * (i + 1), 0), size.y, kind, colours, spacing, bulb, wire, _time if twinkle else 0.0, i * 7)


## One swag from `a` to `b`, dipping `dip` in the middle (downwards on the
## canvas, whatever the slope), hung with lights or flags `spacing` apart.
## `offset` shifts the colours along so neighbouring swags don't match.
static func swag(canvas: CanvasItem, a: Vector2, b: Vector2, dip: float, what: Kind, palette: PackedColorArray,
		gap: float, px: float, line: Color, t: float = 0.0, offset: int = 0) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		var s := k / 16.0
		pts.append(a.lerp(b, s) + Vector2(0, dip * 4.0 * s * (1.0 - s)))
	canvas.draw_polyline(pts, line, maxf(1.0, px * 0.3), true)
	if palette.is_empty():
		return
	var length := 0.0
	for k in range(1, pts.size()):
		length += pts[k].distance_to(pts[k - 1])
	var count := maxi(1, floori(length / gap))
	for j in count:
		var s := (j + 0.5) / count
		var at := a.lerp(b, s) + Vector2(0, dip * 4.0 * s * (1.0 - s))
		var c := palette[(j + offset) % palette.size()]
		if what == Kind.BUNTING:
			var w := px
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-w * 0.5, 0), at + Vector2(w * 0.5, 0), at + Vector2(0, w * 1.1)]), c)
		else:
			var glow := 0.75 + 0.25 * sin(t * 2.2 + j * 1.9 + offset)
			canvas.draw_circle(at + Vector2(0, px * 1.1), px * 2.2, Color(c, 0.22 * glow), true, -1.0, true)
			canvas.draw_rect(Rect2(at + Vector2(-px * 0.35, 0), Vector2(px * 0.7, px * 0.5)), line)
			var body := PackedVector2Array()
			for k in 12:
				var ang := TAU * k / 12.0
				body.append(at + Vector2(0, px * 1.2) + Vector2(cos(ang) * px * 0.7, sin(ang) * px))
			canvas.draw_colored_polygon(body, c.lightened(0.25 * (glow - 0.75) * 4.0))
