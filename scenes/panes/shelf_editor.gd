class_name ShelfEditor
extends Control
## Arranging the shelf, in a popup from the pencil by the shelf on your
## profile: the three spots stay along the top with every gift you have
## scrolling below (in the order picked from "Sort by"). It's all drag and
## drop: drag a gift onto an empty spot to put it there, onto a full one to
## swap it in, along the shelf to move it, or off the shelf to take it down.
## Gifts already on the shelf are greyed out below. On a computer, gifts
## pick up as soon as you drag them; on a phone or tablet dragging scrolls
## the list, so press and hold one first. There's no tapping here: details
## and trade-ins are on the gifts screen. Every change saves straight away,
## and being a popup, none of it can move the app between screens.

## Gifts per row in the collection.
const PER_ROW := 5

var modal: Modal
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
	editor.modal = m
	m.header.add_child(m.heading_row(Text.t("shelf.title")))
	editor._shelf_box = UI.vbox(0)
	m.header.add_child(editor._shelf_box)
	var how := Text.t("shelf.how_mouse" if _quick() else "shelf.how_touch")
	m.header.add_child(UI.para(how, 13, UI.INK_SOFT))
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


## Whether collection gifts pick up as soon as they're dragged: on a
## computer, where the list scrolls with the wheel. (The app turns mouse
## presses into touches, so it can't go by whether there's a touch screen.)
static func _quick() -> bool:
	return OS.has_feature("pc")


## Rebuilds the shelf and the collection from the saved state.
func refresh() -> void:
	for c in _shelf_box.get_children():
		_shelf_box.remove_child(c)
		c.queue_free()
	var shelf := GiftShelf.new(GiftShelf.mine(), 104, func(tile: GiftTile, i: int):
		tile.draggable = true
		tile.quick_drag = true
		tile.lifted.connect(_lift.bind(i)))
	_slots = shelf.slots
	_shelf_box.add_child(shelf)
	_grid.refresh()


## A gift in the collection: just its picture, with no count, to drag up
## onto the shelf.
func _collection_tile(id: String) -> GiftTile:
	var tile := GiftTile.new(id)
	if App.state.shelf().has(id):
		tile.set_on_shelf()
	else:
		tile.draggable = true
		tile.quick_drag = _quick()
		tile.lifted.connect(_lift.bind(-1))
	return tile


# --- Dragging ----------------------------------------------------------------

func _lift(tile: GiftTile, from: int) -> void:
	if _drag_id != "":
		return
	_drag_id = tile.gift_id
	_drag_from = from
	_drag_source = tile
	tile.modulate.a = 0.3
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
	var t := Motion.tween(ghost, "ghost")
	t.set_parallel(true)
	if _hover >= 0:
		# Onto a spot: an empty one takes it, a full one swaps it in (its gift
		# goes back to the collection, or along to where this one came from).
		var slot := _slots[_hover]
		var at := get_global_transform_with_canvas().affine_inverse() * slot.get_global_rect().get_center() - ghost.size * 0.5
		var target := _hover
		t.tween_property(ghost, "position", at, Motion.time(Motion.FAST))
		t.chain().tween_callback(func():
			ghost.queue_free()
			App.place_on_shelf(id, target))
		Audio.play("shelf_place", 1.1, -4.0, "pop")
	elif from >= 0 and _off_shelf:
		# Dragged off the shelf: take it down.
		t.tween_property(ghost, "modulate:a", 0.0, Motion.time(Motion.FAST))
		t.tween_property(ghost, "scale", Vector2.ONE * 0.5, Motion.time(Motion.FAST))
		t.chain().tween_callback(func():
			ghost.queue_free()
			App.remove_from_shelf(from))
		Audio.play("shelf_remove", 0.7, -8.0, "pop")
	else:
		# Dropped nowhere: float back to where it came from.
		var source := _drag_source
		var home := get_global_transform_with_canvas().affine_inverse() * source.get_global_rect().get_center() - ghost.size * 0.5
		t.tween_property(ghost, "position", home, Motion.time(Motion.NORMAL))
		t.tween_property(ghost, "modulate:a", 0.0, Motion.time(Motion.NORMAL))
		t.chain().tween_callback(func():
			if is_instance_valid(source):
				source.modulate.a = 1.0
			ghost.queue_free())
	if _hover >= 0:
		_slots[_hover].highlight = false
	_hover = -1
	_off_shelf = false


