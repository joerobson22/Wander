class_name GiftButton
extends Button
## The "End focus" pill in the corner of a walk, with a small pie chart on
## its right of what your pet will bring back. For the first ten minutes a
## dark green slice sweeps round as the first gift gets closer. At ten
## minutes it dings, pops and fills from the middle with bright green: a
## gift is on its way. From then on blue, purple and gold slices show the
## chance of a rare, epic or legendary gift, growing as the walk goes on;
## once a rarity is certain the ones below it drop out, with another pop.
## Pressing it ends the walk.

const HEIGHT := 52.0
## The pie's size, and how far it sits in from the pill's right end.
const PIE := 36.0
const PIE_INSET := 8.0
## How long the bright green takes to fill from the middle, in seconds.
const REVEAL := 0.5
## Rarest first, clockwise from the top.
const SLICES := ["legendary", "epic", "rare", "common"]

var _seconds := 0
var _level := -2  # -2 = not set yet, -1 = no gift, 0 = common ... 3 = legendary
## How far round the first ten minutes are (0..1).
var _progress := 0.0
## How much of the bright green has filled in from the middle (0..1).
var _reveal := 0.0
## The chances on show, blending from `_from` to `_to` while `_blend` goes 0..1.
var _from := {}
var _to := {}
var _blend := 1.0
## The pie's size against its resting size, for its pops.
var _pie_scale := 1.0


func _init() -> void:
	text = Text.t("walk.end_focus")
	custom_minimum_size.y = HEIGHT
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Cursor.HOVER
	UI.style_button(self, UI.SURFACE, UI.INK, 999, true)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := get_theme_stylebox(state)
		if sb is StyleBoxFlat:
			sb.content_margin_left = 22
			sb.content_margin_right = PIE_INSET + PIE + 12
	add_theme_font_override("font", UI.font(false, 800))
	add_theme_font_size_override("font_size", 17)
	size_flags_vertical = Control.SIZE_SHRINK_END


## Updates the button for a walk this long, with a fanfare when it earns its
## first gift or a rarer one becomes certain.
func set_seconds(seconds: int) -> void:
	_seconds = seconds
	var table := Content.drop_table
	_progress = clampf(float(seconds) / maxf(1.0, float(table.get("min_seconds", 600))), 0.0, 1.0)
	var floor_rarity := GiftRoller.min_rarity(seconds, table)
	var reached := GiftRoller.RARITIES.find(floor_rarity) if floor_rarity != "" else -1
	var odds := GiftRoller.chances(seconds, table)
	if _level == -2:
		# The first look (or coming back to a walk): no fanfare.
		_reveal = 1.0 if reached >= 0 else 0.0
		_from = odds
		_to = odds
	elif reached > _level and _level < 0:
		_first_gift(odds)
	elif reached > _level:
		_pop(0.22)
		Audio.play("gift_odds_up", 1.0 + 0.12 * reached, 0.0, "pop")
		_blend_to(odds)
	else:
		_to = odds
		if _blend >= 1.0:
			_from = odds
	_level = reached
	queue_redraw()


func level() -> int:
	return _level


## The chances the pie shows right now.
func shown() -> Dictionary:
	var out := {}
	for r in GiftRoller.RARITIES:
		out[r] = lerpf(float(_from.get(r, 0.0)), float(_to.get(r, 0.0)), _blend)
	return out


## Ten minutes: a ding and a pop, the bright green fills from the middle,
## then the rarer slices grow in.
func _first_gift(odds: Dictionary) -> void:
	Audio.play("first_gift", 1.0, -2.0, "ding")
	_pop(0.25)
	_from = {"common": 1.0}
	_to = {"common": 1.0}
	_reveal = 0.0
	var t := Motion.method(self, "reveal", _set_reveal, 0.0, 1.0, REVEAL)
	t.tween_callback(_blend_to.bind(odds))


## The pie grows a little and settles back.
func _pop(amount: float) -> void:
	if Motion.reduced() or Motion.still:
		return
	var t := Motion.tween(self, "pie")
	t.tween_method(_set_pie_scale, 1.0, 1.0 + amount, 0.45 * 0.45)
	t.tween_method(_set_pie_scale, 1.0 + amount, 1.0, 0.45 * 0.55)


func _set_pie_scale(v: float) -> void:
	_pie_scale = v
	queue_redraw()


func _blend_to(odds: Dictionary) -> void:
	_from = shown()
	_to = odds
	_blend = 0.0
	Motion.method(self, "blend", _set_blend, 0.0, 1.0, Motion.NORMAL)


func _set_reveal(v: float) -> void:
	_reveal = v
	queue_redraw()


func _set_blend(v: float) -> void:
	_blend = v
	queue_redraw()


func _draw() -> void:
	var r := PIE * 0.5 * _pie_scale
	var c := Vector2(size.x - PIE_INSET - PIE * 0.5, size.y * 0.5)
	var green := Content.rarity_colour("common")
	draw_circle(c, r, UI.NEUTRAL, true, -1.0, true)
	if _reveal < 1.0:
		# The first ten minutes sweeping round, then the green filling in.
		_slice(c, r, -PI * 0.5, TAU * _progress, green.darkened(0.4))
		if _reveal > 0.0:
			draw_circle(c, r * _reveal, green, true, -1.0, true)
	else:
		var at := -PI * 0.5
		var shares := shown()
		for rarity in SLICES:
			var sweep := TAU * float(shares.get(rarity, 0.0))
			if sweep > 0.002:
				_slice(c, r, at, sweep, Content.rarity_colour(rarity))
				at += sweep
		# Thin lines between the slices so neighbours read apart.
		at = -PI * 0.5
		for rarity in SLICES:
			var share := float(shares.get(rarity, 0.0))
			if share > 0.002 and share < 0.998:
				draw_line(c, c + Vector2(cos(at), sin(at)) * r, Color(UI.SURFACE, 0.6), 1.0, true)
			at += TAU * share
	draw_arc(c, r - 1.0, 0, TAU, 40, Color(UI.EDGE, 0.8), 2.0, true)


## A slice of the pie from `from` (radians, clockwise) round `sweep`.
func _slice(c: Vector2, r: float, from: float, sweep: float, colour: Color) -> void:
	if sweep >= TAU - 0.001:
		draw_circle(c, r, colour, true, -1.0, true)
		return
	if sweep <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var steps := maxi(2, ceili(sweep / TAU * 64.0))
	for i in steps + 1:
		var a := from + sweep * i / steps
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, colour)
