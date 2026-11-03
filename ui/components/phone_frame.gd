class_name PhoneFrame
extends Control
## Debug phone view only: a phone's outline over the whole app, so a
## computer shows what a phone would. The screen's rounded corners, the
## camera's island at the top and the home bar at the bottom, sized like an
## iPhone's (390 × 844 points). UI.safe_insets() keeps the app clear of
## the island and the home bar, as the real phone's safe area would.

## The phone's safe area, in points: what UI.safe_insets() gives in the
## debug phone view.
const INSETS := {"top": 47.0, "bottom": 34.0, "left": 0.0, "right": 0.0}
const CORNER := 46.0
const ISLAND := Vector2(124, 36)
const ISLAND_TOP := 11.0
const HOME_BAR := Vector2(134, 5)
const HOME_BAR_GAP := 8.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var black := Color.BLACK
	# Each corner: the square's corner less a quarter circle.
	for corner in 4:
		var at := Vector2(0.0 if corner in [0, 3] else size.x, 0.0 if corner < 2 else size.y)
		var inward := Vector2(1.0 if corner in [0, 3] else -1.0, 1.0 if corner < 2 else -1.0)
		var centre := at + inward * CORNER
		var pts := PackedVector2Array([at])
		for i in 13:
			var a := float(i) / 12.0 * PI * 0.5
			pts.append(centre - Vector2(inward.x * sin(a), inward.y * cos(a)) * CORNER)
		draw_colored_polygon(pts, black)
	var island := Rect2(Vector2((size.x - ISLAND.x) * 0.5, ISLAND_TOP), ISLAND)
	_pill(island, black)
	var bar := Rect2(Vector2((size.x - HOME_BAR.x) * 0.5, size.y - HOME_BAR_GAP - HOME_BAR.y), HOME_BAR)
	_pill(bar, Color(UI.INK, 0.75))


func _pill(r: Rect2, colour: Color) -> void:
	var radius := r.size.y * 0.5
	draw_rect(Rect2(r.position + Vector2(radius, 0), r.size - Vector2(radius * 2.0, 0)), colour)
	draw_circle(r.position + Vector2(radius, radius), radius, colour, true, -1.0, true)
	draw_circle(r.end - Vector2(radius, radius), radius, colour, true, -1.0, true)
