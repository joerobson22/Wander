class_name GiftInfo
extends PanelContainer
## A small card that floats above a gift in your collection: its name with
## its rarity on a tag in the top right, its description, then how close it
## is to a trade-in: a bar in its rarity's colour with "x/y" at the bottom
## right. Once you have enough the bar turns the next rarity's colour and
## glows, pulsing, with "Click to trade 10 in for a rare!" above it.
## On a computer it shows while the pointer's over the gift; on a phone the
## first tap shows it. Only one shows at a time. It never takes the pointer,
## so the gift under it keeps its hover. It draws on its own layer over
## everything else (popups, toasts, the minimap), and doesn't show until it
## knows its size, so it's above the gift from its first frame.

const WIDTH := 260.0
## The gap between the card and the gift.
const GAP := 6.0
const BAR_HEIGHT := 8

## The layer over everything that the cards draw on.
const LAYER := 100

static var _shown: GiftInfo
static var _overlay: CanvasLayer

var tile: Control
var gift_id := ""
var _bar: _Bar
var _going := false
## Placed yet, and whether above the gift (or below, with no room above).
var _placed := false
var _above := true


## Shows the card for `id` over `target`, replacing any other.
static func show_for(target: Control, id: String) -> GiftInfo:
	if is_instance_valid(_shown):
		if _shown.tile == target:
			return _shown
		_shown.dismiss()
	var info := GiftInfo.new(id)
	info.tile = target
	_overlay_for(target).add_child(info)
	_shown = info
	info._appear()
	return info


## The layer the cards draw on, made the first time one shows.
static func _overlay_for(target: Control) -> CanvasLayer:
	if not is_instance_valid(_overlay):
		_overlay = CanvasLayer.new()
		_overlay.name = "GiftInfoLayer"
		_overlay.layer = LAYER
		target.get_tree().root.add_child(_overlay)
	return _overlay


## The card showing over `target`, if any.
static func showing(target: Control) -> GiftInfo:
	return _shown if is_instance_valid(_shown) and _shown.tile == target and not _shown._going else null


## Hides whichever card is showing.
static func hide_any() -> void:
	if is_instance_valid(_shown):
		_shown.dismiss()


## Whether `count` of a gift of `rarity` is enough to trade in.
static func can_trade(rarity: String, count: int) -> bool:
	var cost := Content.trade_cost(rarity)
	return cost > 0 and Content.next_rarity(rarity) != "" and count >= cost


func _init(id: String) -> void:
	gift_id = id
	var g := Content.gift(id)
	var rarity: String = g.get("rarity", "common")
	var count := App.state.gift_count(id)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 18))
	sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size.x = WIDTH
	var col := UI.vbox(6)
	add_child(col)

	var head := UI.hbox(8)
	var title := UI.label(g.get("name", ""), 17, UI.INK, true, 600)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var tag := UI.tag(Content.rarity_name(rarity).to_upper(), Content.rarity_text_colour(rarity), UI.ON_COLOUR, 11)
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(tag)
	col.add_child(head)
	var about := UI.para(g.get("description", ""), 13, UI.INK_SOFT)
	col.add_child(about)

	var cost := Content.trade_cost(rarity)
	var next := Content.next_rarity(rarity)
	if cost <= 0 or next == "":
		col.add_child(UI.para(Text.t("gift.no_trade"), 13, UI.INK_FAINT))
		return
	var full := count >= cost
	var gap := Control.new()
	gap.custom_minimum_size.y = 2
	col.add_child(gap)
	if full:
		var prompt := UI.label(Text.t(_call_key(), {"cost": cost, "a_rarity": UI.a(Content.rarity_name(next).to_lower())}), 13, Content.rarity_text_colour(next), false, 800)
		prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(prompt)
	var foot := UI.hbox(10)
	_bar = _Bar.new()
	_bar.fraction = clampf(float(count) / float(cost), 0.0, 1.0)
	_bar.colour = Content.rarity_colour(next if full else rarity)
	_bar.glowing = full
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_bar)
	var tally := UI.label(Text.t("gift.tally", {"have": count, "need": cost}), 13, Content.rarity_text_colour(next) if full else UI.INK_SOFT, false, 800)
	tally.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(tally)
	col.add_child(foot)


## "Tap" on a phone, "Click" with a mouse.
static func _call_key() -> String:
	return "gift.tap_to_trade" if App.touch_screen() else "gift.click_to_trade"


func _appear() -> void:
	# Hidden till its text has wrapped to its width and it knows how tall it
	# is: placed before then, it would sit too low and jump up.
	modulate.a = 0.0
	await get_tree().process_frame
	if _going or not is_instance_valid(tile):
		return
	_place()
	_placed = true
	pivot_offset = Vector2(size.x * 0.5, size.y if _above else 0.0)
	scale = Vector2.ONE * 0.96
	var t := Motion.tween(self, "appear")
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, Motion.time(0.12))
	t.tween_property(self, "scale", Vector2.ONE, Motion.time(0.12))


## Fades away and goes.
func dismiss() -> void:
	if _going:
		return
	_going = true
	if _shown == self:
		_shown = null
	var t := Motion.tween(self, "appear")
	t.tween_property(self, "modulate:a", 0.0, Motion.time(0.1))
	t.tween_callback(queue_free)


func _process(_dt: float) -> void:
	if not is_instance_valid(tile) or not tile.is_visible_in_tree():
		dismiss()
		return
	if _placed:
		_place()


## Above the gift (below it if there's no room), centred on it and kept on
## screen. It follows the gift if its list scrolls, and stays on the side it
## picked first.
func _place() -> void:
	if not is_instance_valid(tile):
		return
	size = get_combined_minimum_size()
	var view := get_viewport().get_visible_rect().size
	var r := tile.get_global_rect()
	var x := clampf(r.get_center().x - size.x * 0.5, 8.0, view.x - size.x - 8.0)
	if not _placed:
		_above = r.position.y - size.y - GAP >= 8.0
	var y := r.position.y - size.y - GAP if _above else r.end.y + GAP
	position = Vector2(x, y)


## On a phone, a tap anywhere but the gift puts the card away.
func _input(e: InputEvent) -> void:
	if _going or not (e is InputEventMouseButton and e.pressed):
		return
	if is_instance_valid(tile) and tile.get_global_rect().has_point(e.global_position):
		return
	dismiss()


## The trade-in bar. Full, it glows in its colour and pulses gently.
class _Bar extends Control:
	var fraction := 0.0
	var colour := Color.WHITE
	var glowing := false
	var _age := 0.0

	func _init() -> void:
		custom_minimum_size.y = BAR_HEIGHT
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		if glowing:
			_age += dt
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if glowing:
			# A soft halo that swells and fades about once a second.
			var pulse := 0.5 + 0.5 * sin(_age * TAU * 0.9)
			for i in 3:
				var spread := 2.0 + i * 3.0 + pulse * 3.0
				var halo := r.grow(spread)
				draw_style_box(UI.box(Color(colour, (0.16 - i * 0.045) * (0.6 + 0.4 * pulse)), Color.TRANSPARENT, 99), halo)
		draw_style_box(UI.box(UI.LINE, Color.TRANSPARENT, 99), r)
		var w := size.x * clampf(fraction, 0.0, 1.0)
		if w >= 1.0:
			var fill := colour.lightened(0.18 * (0.5 + 0.5 * sin(_age * TAU * 0.9))) if glowing else colour
			draw_style_box(UI.box(fill, Color.TRANSPARENT, 99), Rect2(Vector2.ZERO, Vector2(maxf(w, size.y), size.y)))
