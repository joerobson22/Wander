class_name ProgressRing
extends Control
## A progress circle: a faint outline all the way round, filled clockwise
## from the top in its colour as far as `value` (0..1), with the percentage
## in the middle. sweep() fills it up from empty.

var value := 0.0
var colour := Color.WHITE
var _shown := 0.0
var _label: Label


func _init(fraction: float, ring_colour: Color, diameter: float) -> void:
	value = clampf(fraction, 0.0, 1.0)
	colour = ring_colour
	custom_minimum_size = Vector2(diameter, diameter)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UI.label("", int(diameter * 0.24), UI.INK, true, 600)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_label)
	_set_shown(value)


## Fills it from empty up to its value.
func sweep() -> void:
	_set_shown(0.0)
	Motion.method(self, "sweep", _set_shown, 0.0, value, Motion.SLOW * 1.5)


func _set_shown(v: float) -> void:
	_shown = v
	# Rounded down, so it only says 100% once it's all there.
	_label.text = "%d%%" % floori(v * 100.0 + 0.0001)
	queue_redraw()


func _draw() -> void:
	var width := maxf(6.0, size.x * 0.085)
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - width * 0.5
	draw_arc(c, r, 0.0, TAU, 96, Color(colour, 0.16), width, true)
	if _shown <= 0.0:
		return
	var start := -PI * 0.5
	var end := start + TAU * _shown
	draw_arc(c, r, start, end, maxi(8, ceili(96 * _shown)), colour, width, true)
	# Round ends on the filled part.
	for a in [start, end]:
		draw_circle(c + Vector2.from_angle(a) * r, width * 0.5, colour, true, -1.0, true)
