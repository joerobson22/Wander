@tool
class_name Fireworks
extends Control
## Fireworks going off now and then across its rect: a spark climbs, bursts
## into a ring of falling, fading stars, and is gone. For the sky behind the
## menus and on walks (art/holidays/new_year/look.tres turns them on).

## How many are in the air at once, at most.
@export var bursts := 3
## How long one takes, from launch to the last star fading, in seconds.
@export var life := 2.6
@export var colours := PackedColorArray([Color("#ffd25e"), Color("#ff6f91"), Color("#7fd3ff"), Color("#b6f27a"), Color("#ffffff")])
## How big a burst is, as a share of the rect's height.
@export_range(0.05, 0.6) var reach := 0.22

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if colours.is_empty() or size.y <= 0.0:
		return
	var r := size.y * reach
	for slot in bursts:
		# Each slot sends one up every `life` (and a bit), staggered.
		var period := life * (1.15 + 0.3 * _hash(slot, 1.0))
		var t := _time + period * _hash(slot, 2.0)
		var round_no := floori(t / period)
		var age := fposmod(t, period)
		var k := round_no * 31 + slot
		if _hash(k, 9.0) < 0.2:
			continue  # a quiet moment now and then
		var top := Vector2(size.x * (0.12 + 0.76 * _hash(k, 3.0)), size.y * (0.18 + 0.4 * _hash(k, 4.0)))
		var c := colours[int(_hash(k, 5.0) * colours.size()) % colours.size()]
		var climb := life * 0.25
		if age < climb:
			var rise := age / climb
			var at := Vector2(top.x, size.y).lerp(top, 1.0 - pow(1.0 - rise, 2.0))
			draw_line(at, at + Vector2(0, r * 0.25), Color(c, 0.35), 2.0, true)
			draw_circle(at, 2.2, Color(c.lightened(0.4), 0.9), true, -1.0, true)
			continue
		var s := clampf((age - climb) / (life - climb), 0.0, 1.0)
		var spread := r * (1.0 - pow(1.0 - s, 3.0))
		var fall := r * 0.35 * s * s
		var fade := 1.0 - s
		if s < 0.08:
			draw_circle(top, r * 0.4 * (1.0 - s / 0.08), Color(c.lightened(0.5), 0.35), true, -1.0, true)
		var count := 14 + int(_hash(k, 6.0) * 8.0)
		for j in count:
			var ang := TAU * j / count + _hash(k, 7.0)
			var at := top + Vector2(cos(ang), sin(ang)) * spread + Vector2(0, fall)
			var tail := top + Vector2(cos(ang), sin(ang)) * spread * 0.8 + Vector2(0, fall * 0.7)
			draw_line(tail, at, Color(c, 0.45 * fade), 2.0, true)
			draw_circle(at, 2.4 * (0.5 + fade * 0.5), Color(c.lightened(0.2), fade), true, -1.0, true)


static func _hash(i: int, sd: float) -> float:
	return fposmod(sin(i * 12.9898 + sd * 78.233) * 43758.5453, 1.0)
