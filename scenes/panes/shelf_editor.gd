class_name ShelfEditor
extends Control
## Arranging the shelf, in a popup from the pencil by the shelf on your
## profile: the three spots stay along the top with every gift you have
## scrolling below (in the order picked from "Sort by"). It's all drag and
## drop: drag a gift onto an empty spot to put it there, onto a full one to
## swap it in, along the shelf to move it, or off the shelf to take it down.
## Gifts already on the shelf are greyed out below, and every gift glows in
## its rarity's colour, as on the gifts screen. A gift follows your finger
## (or the pointer) the moment you press it: dragging is all there is to do
## here, so there's no hold first. (The list scrolls from the gaps between
## gifts or with the wheel.) Nothing jumps: a gift swapped off a spot slides
## to where it's going, and one taken down flies back to its place in the
## collection, before the shelf is saved. There's no tapping here: details
## and trade-ins are on the gifts screen. Every change saves straight away,
## and being a popup, none of it can move the app between screens.

## Gifts per row in the collection.
const PER_ROW := 5

var _shelf_box: VBoxContainer
var _grid: GiftGrid
var _slots: Array[GiftShelf.Slot] = []
var _ghost: GiftArt
var _drag_id := ""
var _drag_from := -1
var _drag_source: Control
var _hover := -1
var _off_shelf := false
## The pointer while dragging, in viewport coordinates.
var _pointer := Vector2.ZERO


static func open() -> Modal:
	var m := Modal.open(560)
	var editor := ShelfEditor.new()
	m.header.add_child(m.heading_row(Text.t("shelf.title")))
	editor._shelf_box = UI.vbox(0)
	m.header.add_child(editor._shelf_box)
	m.header.add_child(UI.para(Text.t("shelf.how"), 13, UI.INK_SOFT))
	var head := UI.hbox(8)
	var cap := UI.caption(Text.t("gifts.your_collection"))
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	head.add_child(UI.spacer())
	head.add_child(GiftGrid.sort_menu())
	m.header.add_child(head)
	var per_row := PER_ROW if m.body.custom_minimum_size.x >= 420.0 else 4
	editor._grid = GiftGrid.new(per_row, editor._collection_tile)
	m.body.add_child(editor._grid)
	# The editor itself lies over the whole popup, so the gift being dragged
	# draws on top of everything.
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(editor)
	editor.refresh()
	App.state_changed.connect(editor.refresh)
	return m


## Rebuilds the shelf and the collection from the saved state.
func refresh() -> void:
	for c in _shelf_box.get_children():
		_shelf_box.remove_child(c)
		c.queue_free()
	var shelf := GiftShelf.new(GiftShelf.mine(), 104, func(tile: GiftTile, i: int):
		tile.draggable = true
		tile.lift_on_press = true
		tile.lifted.connect(_lift.bind(i)))
	_slots = shelf.slots
	_shelf_box.add_child(shelf)
	_grid.refresh()


## A gift in the collection: just its picture, with no count, to drag up
## onto the shelf.
func _collection_tile(id: String) -> GiftTile:
	var tile := GiftTile.new(id)
	# Its rarity's glow, as on the gifts screen.
	tile.art.glow = 1.0
	tile.art.glow_reach = 0.4
	if App.state.shelf().has(id):
		tile.set_on_shelf()
	else:
		tile.draggable = true
		tile.lift_on_press = true
		tile.lifted.connect(_lift.bind(-1))
	return tile


# --- Dragging ----------------------------------------------------------------

func _lift(tile: GiftTile, from: int) -> void:
	if _drag_id != "":
		return
	_drag_id = tile.gift_id
	_drag_from = from
	_drag_source = tile
	# Off the shelf it leaves an empty spot; from the list, a faint copy.
	tile.modulate.a = 0.0 if from >= 0 else 0.3
	_ghost = GiftArt.new(_drag_id, 0.9)
	_ghost.size = Vector2(84, 84)
	_ghost.pivot_offset = _ghost.size * 0.5
	add_child(_ghost)
	_pointer = tile.press_point()
	_off_shelf = false
	_move_ghost()
	Motion.pop(_ghost, 0.15)
	Audio.play("shelf_pick_up", 0.85, -8.0, "pop")
	_update_hover()


func _input(e: InputEvent) -> void:
	if _drag_id == "":
		return
	if e is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		_pointer = e.position
		_move_ghost()
		_update_hover()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		# The release carries on to the list too, so it stops drag-scrolling.
		_pointer = e.position
		_update_hover()
		_drop()


func _move_ghost() -> void:
	_ghost.position = get_global_transform_with_canvas().affine_inverse() * _pointer - _ghost.size * 0.5


## Lights up the spot under the pointer. A shelf gift dragged away from the
## shelf shrinks and fades, to show it'll come down if you let go.
func _update_hover() -> void:
	var hit := -1
	for i in _slots.size():
		if _slots[i].get_global_rect().grow(10.0).has_point(_pointer):
			hit = i
	if hit != _hover:
		if _hover >= 0 and _hover < _slots.size():
			_slots[_hover].highlight = false
		_hover = hit
		if hit >= 0:
			_slots[hit].highlight = true
	var off := _drag_from >= 0 and not _shelf_box.get_global_rect().grow(10.0).has_point(_pointer)
	if off != _off_shelf:
		_off_shelf = off
		# The same key as dropping it, so a drop takes over from this.
		var t := Motion.tween(_ghost, "ghost")
		t.set_parallel(true)
		t.tween_property(_ghost, "modulate:a", 0.5 if off else 1.0, Motion.time(Motion.FAST))
		t.tween_property(_ghost, "scale", Vector2.ONE * (0.8 if off else 1.0), Motion.time(Motion.FAST))


func _drop() -> void:
	Gestures.claimed = false
	var id := _drag_id
	var from := _drag_from
	_drag_id = ""
	var ghost := _ghost
	_ghost = null
	var t := Motion.tween(ghost, "ghost")
	t.set_parallel(true)
	if _hover >= 0 and _hover != from:
		# Onto a spot: an empty one takes it, a full one swaps it in. Its gift
		# slides out of the way at the same time: along to where this one
		# came from, or back down to its place in the collection.
		var target := _hover
		_fly(ghost, _slots[target].get_global_rect(), t)
		var bumped := _shelf_tile(target)
		if bumped:
			var to := _slots[from].get_global_rect() if from >= 0 else _collection_rect(bumped.gift_id)
			_fly(_stand_in(bumped), to, t, from < 0)
		t.chain().tween_callback(func():
			ghost.queue_free()
			App.place_on_shelf(id, target))
		Audio.play("shelf_place", 1.1, -4.0, "pop")
	elif from >= 0 and _off_shelf:
		# Dragged off the shelf: it goes from the shelf and flies back down
		# to its place in the collection.
		_fly(ghost, _collection_rect(id), t, true)
		t.chain().tween_callback(func():
			ghost.queue_free()
			App.remove_from_shelf(from))
		Audio.play("shelf_remove", 0.7, -8.0, "pop")
	else:
		# Dropped nowhere (or back on its own spot): it floats back to where
		# it came from.
		var source := _drag_source
		_fly(ghost, source.get_global_rect() if is_instance_valid(source) else ghost.get_global_rect(), t)
		t.chain().tween_callback(func():
			if is_instance_valid(source):
				source.modulate.a = 1.0
			ghost.queue_free())
	if _hover >= 0:
		_slots[_hover].highlight = false
	_hover = -1
	_off_shelf = false


## Slides `art` (a picture over the editor) so it sits over `to` (a rect on
## screen), sized to its picture there, as part of `t`; `fade` lets it go
## see-through as it lands, for one going back into the list.
func _fly(art: Control, to: Rect2, t: Tween, fade: bool = false) -> void:
	var local := get_global_transform_with_canvas().affine_inverse()
	var centre := local * to.get_center()
	# The picture inside a tile is a little smaller than the tile.
	var side := maxf(8.0, minf(to.size.x, to.size.y) - 8.0)
	t.tween_property(art, "position", centre - art.size * 0.5, Motion.time(Motion.NORMAL)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(art, "scale", Vector2.ONE * side / art.size.x, Motion.time(Motion.NORMAL)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if fade:
		t.tween_property(art, "modulate:a", 0.0, Motion.time(Motion.FAST)).set_delay(Motion.time(Motion.NORMAL - Motion.FAST))


## The gift tile in spot `i` of the shelf, or null if it's empty.
func _shelf_tile(i: int) -> GiftTile:
	if i < 0 or i >= _slots.size():
		return null
	for c in _slots[i].get_children():
		if c is GiftTile:
			return c
	return null


## Where gift `id` sits in the collection list, on screen (where the list
## shows, if it's scrolled out of sight).
func _collection_rect(id: String) -> Rect2:
	for c in _grid.get_children():
		if c is GiftTile and c.gift_id == id:
			var r: Rect2 = c.get_global_rect()
			var view := _grid.get_parent() as Control
			while view and not view is ScrollContainer:
				view = view.get_parent() as Control
			if view:
				var shown := view.get_global_rect()
				r.position.y = clampf(r.position.y, shown.position.y - r.size.y * 0.5, shown.end.y - r.size.y * 0.5)
			return r
	return _grid.get_global_rect()


## A picture standing in for `tile` over the editor, so it can slide
## somewhere; the tile itself hides.
func _stand_in(tile: GiftTile) -> GiftArt:
	var art := GiftArt.new(tile.gift_id, 0.9)
	var r := tile.get_global_rect()
	var side := minf(r.size.x, r.size.y) - 8.0
	art.size = Vector2(84, 84)
	art.pivot_offset = art.size * 0.5
	art.scale = Vector2.ONE * side / 84.0
	art.position = get_global_transform_with_canvas().affine_inverse() * r.get_center() - art.size * 0.5
	add_child(art)
	tile.modulate.a = 0.0
	_free_on_save(art)
	return art


## Gone with the next rebuild (once the change is saved).
func _free_on_save(art: Control) -> void:
	App.state_changed.connect(func():
		if is_instance_valid(art):
			art.queue_free(), CONNECT_ONE_SHOT)
