class_name GiftTile
extends PanelContainer
## One gift: its picture (the gift on a disc of its rarity's colour) with no
## card behind it, and how many you have on a tag in its bottom-right corner
## when it's given a `count`. Shelf gifts (`glowing`) glow in their rarity's
## colour and glint under the pointer.
## What it does is up to where it is: `tappable` tiles report taps
## (`tapped`), and `draggable` ones can be picked up (`lifted`), by
## pressing and holding, or with `quick_drag` just by dragging. Either way
## they grow under the pointer, easing smoothly, and show the grab hand.
## `trades` tiles (your collection) show a GiftInfo card while hovered (on a
## phone, after a first tap); clicking one with enough to trade trades it
## in, and one without enough wiggles. Tiles that are only to look at ignore
## the pointer altogether.

signal tapped(gift_id: String)
signal lifted(tile: GiftTile)

var gift_id := ""
var art: GiftArt
## Dragging picks it up straight away, without holding first.
var quick_drag := false
var tappable := false:
	set(v):
		tappable = v
		_update_pointer()
var draggable := false:
	set(v):
		draggable = v
		# Gifts that can be moved pick up after a short hold.
		_press.hold_time = Gestures.QUICK_HOLD if v else Gestures.LONG_PRESS
		_update_pointer()
## Your collection: hover (or a first tap) for its card, click to trade.
var trades := false:
	set(v):
		trades = v
		_update_pointer()
var _press := Press.new(self, true)
var _hovered := false
## How fast the grow settles: about 95% of the way in three of these.
const EASE_TIME := 0.045
var _glint: Glint
var _drag_from := Vector2.ZERO
var _armed := false


## `count` below zero leaves the tag off. `side` is the picture's smallest
## height.
func _init(id: String, count: int = -1, glowing: bool = false, side: float = 78.0) -> void:
	gift_id = id
	var g := Content.gift(id)
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(4)
	add_theme_stylebox_override("panel", sb)
	_press.tapped.connect(_on_tapped)
	_press.held.connect(func():
		if draggable:
			# Picked up by holding: moving afterwards mustn't pick it up again.
			_armed = false
			Motion.pop(self, 0.08)
			lifted.emit(self))
	accessibility_name = g.get("name", "")
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	resized.connect(func(): pivot_offset = size * 0.5)
	set_process(false)
	_update_pointer()

	art = GiftArt.new(id)
	art.custom_minimum_size = Vector2(0, side)
	art.glow = 0.6 if glowing else 0.0
	add_child(art)
	if glowing:
		_glint = Glint.new(0.5, true)
		art.add_child(_glint)
	if count < 0:
		return
	# The count sits over the picture's corner. A PanelContainer stretches its
	# children, so the tag lives in its own holder.
	# The darker text shade, so the white count reads on it.
	var colour := Content.rarity_text_colour(g.get("rarity", "common"))
	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corner)
	var badge := UI.tag(Text.t("gift.count", {"n": count}), colour if count > 0 else UI.SURFACE_SOFT, UI.ON_COLOUR if count > 0 else UI.INK_SOFT, 12)
	corner.add_child(badge)
	corner.resized.connect(func():
		badge.size = badge.get_combined_minimum_size()
		badge.position = corner.size - badge.size)


## Greyed out and left alone: for a collection gift that's already on the
## shelf (it's handled from there).
func set_on_shelf() -> void:
	art.faded = true
	modulate = Color(1, 1, 1, 0.55)
	tappable = false
	draggable = false
	accessibility_name = Text.t("gift.on_shelf", {"gift": accessibility_name})


## Where the finger went down, in viewport coordinates.
func press_point() -> Vector2:
	return get_global_transform_with_canvas() * _press.at


func _interactive() -> bool:
	return tappable or draggable or trades


func _on_tapped() -> void:
	if trades:
		if App.touch_screen() and GiftInfo.showing(self) == null:
			GiftInfo.show_for(self, gift_id)
			set_process(true)
			return
		_trade()
	if tappable:
		tapped.emit(gift_id)


## Trades it in when there are enough (then shows what it brought), or
## wiggles to say "not yet".
func _trade() -> void:
	var rarity := Content.gift_rarity(gift_id)
	if not GiftInfo.can_trade(rarity, App.state.gift_count(gift_id)):
		Motion.wiggle(self)
		Audio.play("trade_not_yet", 0.7, -8.0, "pop")
		return
	GiftInfo.hide_any()
	# A gift you've had before (even if you've none left) isn't new.
	var seen := App.state.inventory.keys()
	var new_id := App.trade_in(gift_id)
	if new_id != "":
		GiftDetails.open(new_id, true, true, not seen.has(new_id))


## Only tiles that do something take the pointer; the rest let it through
## to whatever's under them (a swipe, a scroll).
func _update_pointer() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS if _interactive() else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Cursor.HOVER if _interactive() else Control.CURSOR_ARROW


func _hover(on: bool) -> void:
	_hovered = on
	if not _interactive():
		return
	set_process(true)
	if trades and not App.touch_screen():
		if on:
			GiftInfo.show_for(self, gift_id)
		elif GiftInfo.showing(self):
			GiftInfo.hide_any()
	if on and _glint:
		_glint.shine()


## Grown while hovered or while its card shows (a tap on a phone).
func _target() -> float:
	if not _interactive():
		return 1.0
	var grown := GiftInfo.showing(self) != null if trades else _hovered
	if trades and not App.touch_screen():
		grown = grown or _hovered
	return HoverGrow.GROW if grown else 1.0


## Eases the size towards where it's going every frame, rather than with a
## tween, so moving on and off quickly never restarts it from a standstill.
func _process(dt: float) -> void:
	var goal := _target()
	var s := lerpf(scale.x, goal, 1.0 - exp(-dt / EASE_TIME))
	if absf(s - goal) < 0.001:
		s = goal
		set_process(false)
	scale = Vector2.ONE * s


func _gui_input(e: InputEvent) -> void:
	if not _interactive():
		return
	_press.handle(e)
	if not draggable or not quick_drag:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_armed = e.pressed
		_drag_from = e.position
		if e.pressed:
			Gestures.lifts = true
	elif e is InputEventMouseMotion and _armed and e.position.distance_to(_drag_from) >= Gestures.LIFT_SLOP:
		_armed = false
		# The drag is the gift's now, not a scroll's or a swipe's.
		Gestures.claimed = true
		lifted.emit(self)
