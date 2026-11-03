class_name FocusOrb
extends Control
## The living centre of the focus screen: soft, see-through circles of
## slightly different greens, each drifting round the middle at its own speed
## and direction, while the whole cluster slowly breathes in and out and its
## colours drift between greens and blues and back (about a minute round).
## Under the pointer it eases a little bigger and a shade deeper, and it dips
## when pressed. Tapping it is how a focus session starts: it swells to fill
## the screen alongside the choose focus screen's opening circle.
## On a holiday it takes the holiday's colours instead (HolidayLook's
## orb_colours: a rainbow on your birthday, reds and oranges at Halloween),
## each blob drifting through them in turn, easing over when the day changes.

signal tapped

const HOVER_GROW := HoverGrow.GROW
const PRESS_GROW := 0.95
## How long the hover takes to ease in and out, in seconds.
const HOVER_TIME := 0.35
## How much darker it gets under the pointer.
const HOVER_SHADE := 0.14
## How much more solid the blobs are drawn than their listed opacity, so the
## orb reads clearly over the view.
const DEPTH := 1.5
## In the light colours: how much more saturated and how much darker.
const LIGHT_SATURATE := 1.9
const LIGHT_DEPTH := 0.1
## Seconds for the colours to go from green to blue and back.
const TINT_PERIOD := 60.0

## [colour, opacity, radius, orbit, speed (radians/s), phase]; radius and
## orbit are fractions of the orb's radius.
const BLOBS := [
	["#4f9a80", 0.30, 0.86, 0.05, -0.11, 5.3],
	["#7fbf9f", 0.48, 0.76, 0.11, 0.21, 0.0],
	["#5fa88a", 0.36, 0.68, 0.17, -0.16, 1.7],
	["#8cc7c0", 0.40, 0.60, 0.19, -0.27, 4.4],
	["#a7d6be", 0.46, 0.56, 0.22, 0.32, 3.1],
	["#b5dfe0", 0.36, 0.44, 0.24, 0.47, 0.9],
	["#d3ecdf", 0.55, 0.34, 0.16, -0.38, 2.2],
]
## Each blob's colour at the blue end of the drift, in the same order.
const BLUES := ["#4f7fa8", "#7fa6cf", "#5f8fbd", "#8cb4d6", "#a7c6e3", "#b5d3ec", "#d3e3f1"]

## Paused while the focus screen is off to one side, to save battery.
var running := true:
	set(v):
		running = v
		set_process(v)
var _time := 0.0
var _press_at := Vector2.ZERO
var _pressing := false
var _hovered := false
## How big it's drawn, from the hover and press: 1 at rest.
var _grow := 1.0
## How shaded it is: 0 at rest, 1 hovered.
var _shade := 0.0
## Swelling to fill the screen after a tap.
var _filling := false
## The holiday colours shown (empty for the usual greens and blues), the
## ones before them, and how far it has eased from those to these (0 to 1).
var _palette := PackedColorArray()
var _old_palette := PackedColorArray()
var _blend := 1.0
## How much more solidly a holiday's colours are drawn than the usual ones.
const PALETTE_SOLID := 1.8
## How long it takes to ease into a holiday's colours.
const PALETTE_EASE := 1.2
## False until its first frame.
var _drawn := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Cursor.HOVER
	focus_mode = Control.FOCUS_ALL


func _process(delta: float) -> void:
	_time += delta * (0.4 if Motion.reduced() else 1.0)
	var look := App.holiday_look()
	var want := look.orb_colours if look else PackedColorArray()
	if want != _palette:
		_old_palette = _palette
		_palette = want
		# Easing over, unless it's its first frame or it's out of sight.
		_blend = 0.0 if _drawn and is_visible_in_tree() else 1.0
	_drawn = true
	_blend = minf(1.0, _blend + delta / PALETTE_EASE)
	queue_redraw()


## Blob `k`'s colour at `time` from `palette` (empty: the usual drift
## between greens and blues). Each blob starts further along the palette and
## they all drift through it, once round every TINT_PERIOD seconds.
static func blob_colour(k: int, time: float, palette: PackedColorArray) -> Color:
	if palette.is_empty():
		var tint := tint_at(time)
		return Color.from_string(BLOBS[k][0], Color.WHITE).lerp(Color.from_string(BLUES[k], Color.WHITE), tint)
	var n := palette.size()
	var at := fposmod(float(k) * n / BLOBS.size() + time / TINT_PERIOD * n, float(n))
	var i := floori(at)
	return palette[i % n].lerp(palette[(i + 1) % n], smoothstep(0.0, 1.0, at - i))


## The faint halo's colour.
static func halo_colour(time: float, palette: PackedColorArray) -> Color:
	if palette.is_empty():
		return Color(0.38, 0.65, 0.52).lerp(Color(0.36, 0.55, 0.74), tint_at(time))
	var sum := Color(0, 0, 0, 0)
	for c in palette:
		sum += c
	return sum / float(palette.size())


## Blob `k`'s colour now, eased over from the old palette.
func _colour(k: int) -> Color:
	var c := _shown(k, _palette)
	if _blend < 1.0:
		c = _shown(k, _old_palette).lerp(c, smoothstep(0.0, 1.0, _blend))
	return c


func _shown(k: int, palette: PackedColorArray) -> Color:
	var c := blob_colour(k, _time, palette)
	if not UI.dark and palette.is_empty():
		# Richer by day, so it doesn't wash out against a bright sky (a
		# holiday's colours are already as rich as they should be).
		c = Color.from_hsv(c.h, minf(1.0, c.s * LIGHT_SATURATE), c.v * (1.0 - LIGHT_DEPTH))
	return c


func radius() -> float:
	return minf(size.x, size.y) * 0.5


func _draw() -> void:
	var c := size * 0.5
	var base := radius() * _grow
	var breathe := 1.0 + 0.045 * sin(_time * 0.55) + 0.02 * sin(_time * 1.27 + 1.0)
	# A holiday's colours are drawn more solidly: mixed see-through, unlike
	# colours (red over green) turn muddy.
	var solid := lerpf(1.0 if _old_palette.is_empty() else PALETTE_SOLID, 1.0 if _palette.is_empty() else PALETTE_SOLID, smoothstep(0.0, 1.0, _blend))
	# A faint halo so the orb sits softly on the page.
	var halo := halo_colour(_time, _palette)
	if _blend < 1.0:
		halo = halo_colour(_time, _old_palette).lerp(halo, smoothstep(0.0, 1.0, _blend))
	for i in 6:
		draw_circle(c, base * breathe * (1.02 + i * 0.035), Color(halo, 0.035), true, -1.0, true)
	for k in BLOBS.size():
		var b: Array = BLOBS[k]
		var angle: float = b[5] + _time * b[4]
		var wobble := 1.0 + 0.035 * sin(_time * 0.9 + b[5] * 2.0)
		var p: Vector2 = c + Vector2(cos(angle), sin(angle)) * base * b[3] * breathe
		var colour := _colour(k)
		colour = colour.darkened(HOVER_SHADE * _shade)
		draw_circle(p, base * b[2] * breathe * wobble, Color(colour, minf(1.0, b[1] * DEPTH * solid)), true, -1.0, true)


## How far towards blue the colours are at `time` seconds: 0 green, 1 blue,
## easing to and fro.
static func tint_at(time: float) -> float:
	return 0.5 - 0.5 * cos(time * TAU / TINT_PERIOD)


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			_grow_to(PRESS_GROW if _pressing else HOVER_GROW)
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			_grow_to(1.0)


## Eases the size towards `v`, and the shade with it (deeper while hovered
## or pressed).
func _grow_to(v: float, seconds: float = HOVER_TIME) -> void:
	if _filling:
		return
	Motion.method(self, "grow", _set_grow, _grow, v, seconds)
	Motion.method(self, "shade", _set_shade, _shade, 1.0 if (_hovered or _pressing) else 0.0, seconds)


func _set_grow(v: float) -> void:
	_grow = v
	queue_redraw()


func _set_shade(v: float) -> void:
	_shade = v
	queue_redraw()


## Swells until it covers the whole screen, as fast as the choose focus
## screen's circle opens (CircleReveal.open), keeping a ring of it ahead of
## that circle's edge.
func fill_screen() -> void:
	var centre := get_global_rect().get_center()
	var view := get_viewport_rect().size
	var far := 0.0
	for corner in [Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)]:
		far = maxf(far, centre.distance_to(corner))
	var r := maxf(radius() * get_global_transform().get_scale().x, 1.0)
	_filling = true
	# Its biggest blobs reach about 0.86 of its radius: grown by far / 0.8
	# more, their edge stays ahead of the circle all the way.
	Motion.method(self, "grow", _set_grow, _grow, _grow + (far / 0.8 + 2.0) / r, Motion.SLOW)


## The other way: starts out covering the whole screen and shrinks back to
## its resting size in `seconds`, as a full-screen flow closes into it.
func shrink_from_full(seconds: float = Motion.SLOW) -> void:
	var r := maxf(radius() * get_global_transform().get_scale().x, 1.0)
	var far := 0.0
	var centre := get_global_rect().get_center()
	var view := get_viewport_rect().size
	for corner in [Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)]:
		far = maxf(far, centre.distance_to(corner))
	_filling = true
	_pressing = false
	_set_grow(1.0 + (far / 0.8 + 2.0) / r)
	var t := Motion.method(self, "grow", _set_grow, _grow, 1.0, seconds)
	t.tween_callback(func(): _filling = false)


## Back to its resting size at once (it's off screen).
func settle() -> void:
	_filling = false
	_pressing = false
	_hovered = false
	Motion.method(self, "grow", _set_grow, _grow, 1.0, 0.0)
	Motion.method(self, "shade", _set_shade, _shade, 0.0, 0.0)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = true
			_press_at = e.position
			_grow_to(PRESS_GROW, HoverGrow.TIME)
		elif _pressing:
			_pressing = false
			_grow_to(HOVER_GROW if _hovered else 1.0, HoverGrow.TIME)
			if e.position.distance_to(_press_at) < Gestures.TAP_SLOP and _has_point(e.position):
				tapped.emit()
		accept_event()
	elif e.is_action_pressed("ui_accept"):
		accept_event()
		tapped.emit()
