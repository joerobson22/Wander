class_name Pane
extends Control
## One of the five screens laid out round the focus screen. Each is built
## once and kept for as long as the app runs, so it's exactly as you left it
## when you swipe back. When the game state changes it rebuilds its content,
## keeping its scroll position; while it's off screen it just notes that it
## needs to, and does it when it's next shown.

## True while this pane is the one on screen (or sliding in).
var shown := false
var wide := false
var scroll: ScrollContainer

## The sides of this screen with an arrow to another one (the app shell
## sets them; computers only), so its content keeps clear of them.
var arrows: Array[Vector2i] = []

## Room kept clear under a screen's content for the minimap on phones,
## where the content is as wide as the screen.
const BOTTOM_CLEAR := 96
## The usual gap above and below a screen's content.
const EDGE_GAP := 26
## On computers content keeps this far in from the sides, clear of the
## minimap in the bottom left corner (and the edge arrows).
const MAP_CLEAR_X := 88.0

var _dirty := true
var _resize_queued := false


func _ready() -> void:
	clip_contents = true
	App.state_changed.connect(_on_state_changed)
	resized.connect(_on_resized)


func show_pane() -> void:
	shown = true
	if _dirty:
		rebuild()
	_on_shown()


func hide_pane() -> void:
	shown = false
	_on_hidden()


func rebuild() -> void:
	_dirty = false
	wide = size.x >= UI.WIDE_BREAKPOINT
	var keep := scroll.scroll_vertical if is_instance_valid(scroll) else 0
	var kept := keeps()
	for c in get_children():
		if c in kept:
			continue
		remove_child(c)
		c.queue_free()
	scroll = null
	build()
	if keep > 0 and scroll:
		_restore_scroll(keep)


## Rebuild next time it's shown (e.g. after a switch to dark mode).
func mark_dirty() -> void:
	_dirty = true


## Subclasses add their content here.
func build() -> void:
	pass


## Children that survive a rebuild as they are, mid-animation (things whose
## look doesn't depend on the game state or the palette). build() should
## only make them if they don't exist yet.
func keeps() -> Array[Node]:
	return []


func _on_shown() -> void:
	pass


func _on_hidden() -> void:
	pass


func _on_state_changed() -> void:
	if shown:
		rebuild()
	else:
		_dirty = true


func _on_resized() -> void:
	if not shown:
		_dirty = true
		return
	if not _resize_queued:
		_resize_queued = true
		_rebuild_after_resize.call_deferred()


func _rebuild_after_resize() -> void:
	_resize_queued = false
	if shown:
		rebuild()


func _restore_scroll(value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value


## A scrolling, centred column for the pane's content, clear of the notch at
## the top, the edge arrows and the minimap. Returns the column to fill.
func page() -> VBoxContainer:
	var m := margins(680.0)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := _margin_container(m)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var column := UI.vbox(18)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(column)
	column.custom_minimum_size.x = m["width"]
	return column


## A column filling the pane exactly, centred and at most `max_width` wide,
## clear of the notch at the top and the minimap at the bottom. Unlike
## page() it never scrolls: whatever's in it has to fit, so give the parts
## that can give way SIZE_EXPAND_FILL, and put long lists in a
## UI.scroll_area() of their own. Returns the column to fill.
func frame(max_width: float = 680.0, gap: int = 18) -> VBoxContainer:
	var m := margins(max_width)
	var margin := _margin_container(m)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.clip_contents = true
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := UI.vbox(gap)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.custom_minimum_size.x = m["width"]
	margin.add_child(column)
	return column


## Where a centred column at most `max_width` wide goes: its "width", and
## the room round it ("left", "right", "top", "bottom"), clear of the notch,
## the edge arrows (computers) and the minimap in the bottom left corner.
func margins(max_width: float) -> Dictionary:
	var insets := UI.safe_insets(self)
	var phone := App.phone_layout()
	var side := 32.0 if wide else 18.0
	var bottom := float(EDGE_GAP)
	if phone:
		# Full width, so leave the bottom free for the minimap.
		bottom = BOTTOM_CLEAR
	else:
		# Narrower instead, clear of the minimap in the corner and the edge
		# arrows, so the content can go all the way down.
		side = maxf(side, MAP_CLEAR_X)
		if arrows.has(Vector2i.DOWN):
			bottom = float(NavArrow.ROOM + 8)
	var top := float(EDGE_GAP)
	if not phone and arrows.has(Vector2i.UP):
		top = float(NavArrow.ROOM + 8)
	var left := side + float(insets["left"])
	var right := side + float(insets["right"])
	var width := maxf(0.0, minf(max_width, size.x - left - right))
	return {"width": width, "left": left, "right": right,
		"top": top + float(insets["top"]), "bottom": bottom + float(insets["bottom"])}


func _margin_container(m: Dictionary) -> MarginContainer:
	var margin := MarginContainer.new()
	for key in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + key, int(m[key]))
	return margin


## The pane's title with its app-map icon beside it (UI.title_row).
func title_row(title: String) -> HBoxContainer:
	return UI.title_row(title, Minimap.ICONS.get(name.to_lower(), ""))
