@tool
class_name SceneryLayer
extends Node2D
## One layer of a place's scenery, in that place's scene
## (art/scenery/<place id>/place.tscn). Layers are drawn back to front in
## the order they're listed in the scene tree, so the first is the furthest
## away. Pick a `kind` to have it drawn for you (hills, trees, water...),
## and set how it looks in the Inspector; or put your own art inside it
## (any sprites, as children of this node) and that repeats along the walk
## instead. In the editor the layer draws itself just as the walk does, at
## its place in a 1280 × 720 screen, so you see your changes straight away.
##
## The node's height on screen is its `y`: drag it up and down in the 2D
## view, or type a `y` (0 is the top of the screen, 1 the bottom).

## Every kind the walk can draw for you.
const KINDS := "hills,mountains,trees,pines,broadleaf,canopy,palms,acacias,blossoms,mesas,cacti,water,ground,fields,barns,fences,buildings,lamps,reeds,fronds,drifts,undergrowth,vines,stalks,planet"
## The screen the editor draws the layer on, and the walk's art is made for.
const SCREEN := Vector2(1280, 720)

## What the walk draws for this layer (unless it has art of its own).
@export_enum("hills", "mountains", "trees", "pines", "broadleaf", "canopy", "palms", "acacias", "blossoms", "mesas", "cacti", "water", "ground", "fields", "barns", "fences", "buildings", "lamps", "reeds", "fronds", "drifts", "undergrowth", "vines", "stalks", "planet")
var kind: String = "hills":
	set(v):
		kind = v
		_changed()
## How fast it scrolls past against the path (1 moves with the path; far
## things are slower).
@export_range(0.0, 3.0, 0.01) var parallax := 0.3:
	set(v):
		parallax = v
		_changed()
## The line it stands on, from the top of the screen (0) to the bottom (1).
## Things grow up from it; water and ground run down from it.
@export_range(0.0, 1.0, 0.005) var y := 0.6:
	set(v):
		y = v
		if position.y != y * SCREEN.y:
			position = Vector2(0.0, y * SCREEN.y)
		_changed()
## How tall it is, as a share of the screen's height.
@export_range(0.0, 1.0, 0.005) var height := 0.15:
	set(v):
		height = v
		_changed()
## Its colour by day; the time of day and the weather tint it.
@export var colour := Color("#55765c"):
	set(v):
		colour = v
		_changed()
## Changes the random shapes (where each tree goes, how the hills roll).
@export var pattern := 1:
	set(v):
		pattern = v
		_changed()

@export_group("Shape")
## The gap between things (trees, buildings...), in pixels. 0 uses 70.
@export_range(0, 600, 1) var spacing := 0:
	set(v):
		spacing = v
		_changed()
## How far apart the rises of hills and fields are, in pixels. 0 uses 400.
@export_range(0, 1200, 1) var wavelength := 0:
	set(v):
		wavelength = v
		_changed()
## The share of spaces left empty (undergrowth, vines and stalks). Below 0
## uses the kind's own.
@export_range(-0.01, 1.0, 0.01) var skip := -0.01:
	set(v):
		skip = v
		_changed()
## In front of you and your pet (the jungle's big leaves and vines).
@export var front := false:
	set(v):
		front = v
		_changed()
## White tips on mountains and pines.
@export var snow := false:
	set(v):
		snow = v
		_changed()
## Surf along the edge of water.
@export var foam := false:
	set(v):
		foam = v
		_changed()
## Craters in the ground (the Moon).
@export var craters := false:
	set(v):
		craters = v
		_changed()
## The path's colour, on the ground layer. Fully see-through uses sand.
@export var path_colour := Color(0, 0, 0, 0):
	set(v):
		path_colour = v
		_changed()

@export_group("Your art")
## A scene to repeat along the layer instead of the drawn kind (see
## assets/README.md). Sprites placed inside this node work the same way and
## win over this.
@export var art: PackedScene:
	set(v):
		art = v
		_changed()
## How wide one repeat of the art is, when it has no TileBounds box.
@export var tile_width := 768.0

## The editor's drawing of the layer (never saved with the scene).
var _preview: Node2D
var _redrawing_place := false


func _ready() -> void:
	position = Vector2(0.0, y * SCREEN.y)
	_changed()


func _notification(what: int) -> void:
	# Dragged up or down in the editor: that's a new `y`.
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		var from_drag := clampf(position.y / SCREEN.y, 0.0, 1.0)
		if not is_equal_approx(from_drag, y):
			y = snappedf(from_drag, 0.005)


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)


## The layer as the walk reads it (the same keys biomes.json layers used).
func to_layer() -> Dictionary:
	var out := {"kind": kind, "parallax": parallax, "y": y, "height": height,
		"colour": "#" + colour.to_html(false), "seed": pattern}
	if spacing > 0:
		out["spacing"] = spacing
	if wavelength > 0:
		out["wavelength"] = wavelength
	if skip >= 0.0:
		out["skip"] = skip
	for flag in ["front", "snow", "foam", "craters"]:
		if get(flag):
			out[flag] = true
	if path_colour.a > 0.0:
		out["path"] = "#" + path_colour.to_html(false)
	if art:
		out["art"] = art.resource_path
	return out


## This layer's own sprites (anything inside it but the editor's drawing),
## as a tile to repeat: {node, width}, or null when it has none. Its
## TileBounds box, if any, sets the width.
func art_tile() -> Variant:
	var parts: Array[Node] = []
	for c in get_children():
		if c != _preview:
			parts.append(c)
	if parts.is_empty():
		return null
	var tile := Node2D.new()
	var width := tile_width
	for c in parts:
		if c.name == "TileBounds" and c is Control:
			width = maxf(1.0, (c as Control).size.x)
			continue
		tile.add_child(c.duplicate())
	return {"node": tile, "width": width}


## Draws the layer again in the editor.
func redraw() -> void:
	_changed()


func _changed() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_draw_preview.call_deferred()
	# The ground moves the path, which the frame and the other layers show.
	var place := get_parent() as PlaceScenery
	if place and kind == "ground" and not _redrawing_place:
		_redrawing_place = true
		place._refresh.call_deferred()
		(func(): _redrawing_place = false).call_deferred()


## In the editor: draws the layer across the screen as the walk would (if
## it has no art of its own), so the place looks right as you change it.
func _draw_preview() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	if is_instance_valid(_preview):
		_preview.free()
	_preview = null
	var own_art := false
	for c in get_children():
		own_art = true
	if own_art or art != null:
		if art != null and not own_art:
			_preview = Node2D.new()
			var x := 0.0
			var width := tile_width
			var probe := art.instantiate()
			var bounds := probe.get_node_or_null("TileBounds") as Control
			if bounds and bounds.size.x > 0.0:
				width = bounds.size.x
			probe.free()
			while x < SCREEN.x:
				var t := art.instantiate() as Node2D
				t.position.x = x
				_preview.add_child(t)
				x += width
			add_child(_preview, false, Node.INTERNAL_MODE_BACK)
		return
	if kind == "planet":
		_preview = _Planet.new()
		(_preview as _Planet).layer = self
		add_child(_preview, false, Node.INTERNAL_MODE_BACK)
		return
	_preview = Node2D.new()
	# Drawn in screen space: the painters measure from the top.
	_preview.position.y = -position.y
	var layer := to_layer()
	var place := get_parent() as PlaceScenery
	var path := place.path_y() if place else SCREEN.y * 0.8
	for i in ceili(SCREEN.x / SceneryPainter.CHUNK):
		var p := SceneryPainter.new()
		p.layer = layer
		p.index = i
		p.view_size = SCREEN
		p.path_line = path
		p.position.x = i * SceneryPainter.CHUNK
		_preview.add_child(p)
	add_child(_preview, false, Node.INTERNAL_MODE_BACK)


## The Moon's planet hangs in the sky; the editor shows roughly where.
class _Planet extends Node2D:
	var layer: SceneryLayer

	func _draw() -> void:
		var r := layer.height * SceneryLayer.SCREEN.y * 0.5
		draw_circle(Vector2(SceneryLayer.SCREEN.x * 0.75, 0), r, layer.colour, true, -1.0, true)
