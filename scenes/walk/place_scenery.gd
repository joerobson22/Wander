@tool
class_name PlaceScenery
extends Node2D
## A place's scenery, to open and change in the Godot editor:
## art/scenery/<place id>/place.tscn. Each child is a SceneryLayer, drawn
## back to front in the order they're listed (the first is furthest away).
## Click one to change it in the Inspector, drag it up or down to move its
## line, add one (duplicate a layer, Ctrl+D) or delete one. The editor draws
## each layer as the walk does on a 1280 × 720 screen, inside the frame
## drawn here, with a plain sky behind and the path as a dashed line; the
## real sky, light and weather follow the time of day when you walk there
## (try the place in art/scenery/preview.tscn).
## What the place is called, what unlocks it, its sounds and weather are
## in data/biomes.json.

## The sky colour behind the layers in the editor (the walk draws its own).
@export var editor_sky := Color("#bcd9e8"):
	set(v):
		editor_sky = v
		queue_redraw()

## The frame and the path, drawn over the layers (editor only).
var _guide: _Guide


func _ready() -> void:
	if Engine.is_editor_hint():
		_guide = _Guide.new()
		_guide.place = self
		add_child(_guide, false, Node.INTERNAL_MODE_BACK)
		child_order_changed.connect(_refresh)


## Draws every layer again (after one is added, moved or removed, the path
## or the order may have changed).
func _refresh() -> void:
	if is_instance_valid(_guide):
		_guide.queue_redraw()
	for c in get_children():
		if c is SceneryLayer:
			(c as SceneryLayer).redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, SceneryLayer.SCREEN), editor_sky)


## The line feet walk on, from the ground layer (as the walk works it out).
func path_y() -> float:
	for c in get_children():
		var l := c as SceneryLayer
		if l and l.kind == "ground":
			return SceneryLayer.SCREEN.y * (l.y + l.height * 0.32)
	return SceneryLayer.SCREEN.y * 0.8


## The layers, back to front, as the walk reads them (see SceneryLayer).
## A layer with sprites of its own carries them as "art_tile".
func layers() -> Array:
	var out := []
	for c in get_children():
		var l := c as SceneryLayer
		if l == null:
			continue
		var d := l.to_layer()
		var tile = l.art_tile()
		if tile != null:
			d["art_tile"] = tile
		out.append(d)
	return out


class _Guide extends Node2D:
	var place: PlaceScenery

	func _draw() -> void:
		var screen := SceneryLayer.SCREEN
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.7), false, 3.0)
		var path := place.path_y()
		draw_dashed_line(Vector2(0, path), Vector2(screen.x, path), Color(1, 1, 1, 0.7), 2.0, 14.0)
