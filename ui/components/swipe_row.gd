class_name SwipeRow
extends Container
## Holds one panel that can be swiped sideways to act on it. Dragging right
## (left to right) uncovers red with a bin behind it; dragging left uncovers
## the `left_colour` with the `left_icon` (green and a tick to complete). The
## colour deepens as you go, and the icon pops once you're past THRESHOLD of
## the width: let go there and it acts (`swiped`), anywhere short of it and
## the panel springs back. A swipe that starts on the panel is the panel's,
## never the app's swipe between screens (Gestures.sideways); up and down
## still scroll the list. After acting, the screen plays celebrate() (a
## green flash and confetti) or vanish() (it shrinks away with a red flash),
## and collapse() closes the gap it leaves.

## +1 for a swipe to the right (delete), -1 to the left (complete).
signal swiped(direction: int)

const THRESHOLD := 0.4
## Moving this far sideways (more than up or down) makes it a swipe.
const START := 12.0
const RADIUS := 24

var left_colour := UI.SUCCESS
var left_icon := "check"
var right_colour := UI.DANGER
var right_icon := "bin"
## The corner rounding of what shows behind the panel; match the panel's.
var radius := RADIUS:
	set(v):
		radius = v
		_flash.radius = v
var content: Control

var _offset := 0.0
var _height := 1.0
var _tracking := false
var _dragging := false
var _press_at := Vector2.ZERO
var _armed := false
var _icon_pop := 0.0
var _flash := _Flash.new()


func _init(panel: Control) -> void:
	content = panel
	add_child(panel)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = false


func _get_minimum_size() -> Vector2:
	if not is_instance_valid(content):
		return Vector2.ZERO
	var m := content.get_combined_minimum_size()
	return Vector2(m.x, m.y * _height)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var full := content.get_combined_minimum_size().y
		fit_child_in_rect(content, Rect2(Vector2(_offset, 0), Vector2(size.x, maxf(full, size.y))))
		fit_child_in_rect(_flash, Rect2(Vector2(_offset, 0), Vector2(size.x, maxf(full, size.y))))
		content.pivot_offset = content.size * 0.5
		_flash.pivot_offset = content.pivot_offset
		_flash.scale = content.scale


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_tracking = true
			_dragging = false
			_press_at = e.global_position
			Gestures.sideways = true
		elif _tracking or _dragging:
			_tracking = false
			if _dragging:
				accept_event()
				_let_go()
	elif e is InputEventMouseMotion and (_tracking or _dragging):
		var d: Vector2 = e.global_position - _press_at
		if not _dragging:
			if absf(d.y) > START and absf(d.y) > absf(d.x):
				_tracking = false  # up or down: the list's
				return
			if absf(d.x) > START and absf(d.x) > absf(d.y) * 1.2:
				_dragging = true
				Gestures.claimed = true
		if _dragging:
			accept_event()
			_set_offset(clampf(d.x, -size.x * 0.85, size.x * 0.85))


func _set_offset(v: float) -> void:
	_offset = v
	var armed := absf(v) >= size.x * THRESHOLD
	if armed != _armed:
		_armed = armed
		Motion.method(self, "pop", _set_pop, _icon_pop, 1.0 if armed else 0.0, Motion.FAST)
	queue_sort()
	queue_redraw()


func _set_pop(v: float) -> void:
	_icon_pop = v
	queue_redraw()


func _set_height(v: float) -> void:
	_height = v
	update_minimum_size()


func _let_go() -> void:
	_dragging = false
	Gestures.claimed = false
	if _armed:
		swiped.emit(signi(roundi(_offset)))
	else:
		spring_back()


## Slides the panel home.
func spring_back() -> Tween:
	_armed = false
	return Motion.method(self, "offset", _set_offset, _offset, 0.0, Motion.FAST)


func _draw() -> void:
	if absf(_offset) < 0.5:
		return
	var right := _offset > 0.0
	var colour := right_colour if right else left_colour
	var reach := clampf(absf(_offset) / (size.x * THRESHOLD), 0.0, 1.0)
	var sb := UI.box(Color(colour, lerpf(0.35, 1.0, reach)), Color.TRANSPARENT, radius)
	draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(size.x, size.y)))
	var px := 26
	var tex := Icons.texture(right_icon if right else left_icon, px, Color.WHITE, 2.8)
	var s := lerpf(0.85, 1.25, _icon_pop)
	var gap := 28.0
	var cx := gap + px * 0.5 if right else size.x - gap - px * 0.5
	var at := Vector2(cx, size.y * 0.5)
	draw_set_transform(at, 0.0, Vector2(s, s))
	draw_texture(tex, -Vector2(px, px) * 0.5, Color(1, 1, 1, lerpf(0.6, 1.0, reach)))
	draw_set_transform(Vector2.ZERO)


## Springs home, flashes `colour` over the panel and throws confetti.
func celebrate() -> void:
	spring_back()
	_flash.colour = UI.SUCCESS
	var t := Motion.tween(_flash, "flash")
	t.tween_property(_flash, "strength", 0.55, Motion.time(0.12))
	t.tween_property(_flash, "strength", 0.0, Motion.time(0.5))
	if not Motion.reduced():
		var burst := _Confetti.new()
		burst.top_level = true
		add_child(burst)
		# From the middle of the panel, where it's springing back to.
		burst.global_position = global_position + Vector2(size.x * 0.5, minf(size.y * 0.35, 120.0))
		burst.start(size.x)
	await get_tree().create_timer(maxf(Motion.time(0.65), 0.05)).timeout


## Flashes red and shrinks away to nothing where it is.
func vanish() -> void:
	_flash.colour = UI.DANGER
	var t := Motion.tween(_flash, "flash")
	t.tween_property(_flash, "strength", 0.6, Motion.time(0.1))
	var shrink := Motion.tween(content, "shrink")
	shrink.set_parallel(true)
	shrink.tween_property(content, "scale", Vector2.ONE * 0.6, Motion.time(0.3)).set_delay(Motion.time(0.08))
	shrink.tween_property(content, "modulate:a", 0.0, Motion.time(0.3)).set_delay(Motion.time(0.08))
	shrink.tween_property(_flash, "modulate:a", 0.0, Motion.time(0.3)).set_delay(Motion.time(0.08))
	shrink.tween_method(func(_v): queue_sort(), 0.0, 1.0, Motion.time(0.38))
	await get_tree().create_timer(maxf(Motion.time(0.4), 0.05)).timeout
	await collapse()


## Closes up the room it took, so the list below slides up.
func collapse() -> void:
	var t := Motion.method(self, "height", _set_height, _height, 0.0, Motion.FAST)
	await get_tree().create_timer(maxf(Motion.time(Motion.FAST), 0.02)).timeout
	if t and t.is_running():
		await t.finished


## A rounded wash of colour over the panel, `strength` strong.
class _Flash extends Control:
	var colour := UI.SUCCESS
	var radius := RADIUS
	var strength := 0.0:
		set(v):
			strength = v
			queue_redraw()

	func _draw() -> void:
		if strength <= 0.0:
			return
		draw_style_box(UI.box(Color(colour, strength), Color.TRANSPARENT, radius), Rect2(Vector2.ZERO, size))


## A burst of paper bits that fly up and flutter down.
class _Confetti extends Control:
	const LIFE := 1.2
	var _bits: Array = []
	var _age := 0.0

	func start(width: float) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var colours: Array = UI.SERIES + Podium.MEDALS
		for i in 44:
			var angle := randf_range(-PI * 0.9, -PI * 0.1)
			var speed := randf_range(260.0, 560.0)
			_bits.append({
				"at": Vector2(randf_range(-width * 0.3, width * 0.3), 0.0),
				"v": Vector2(cos(angle), sin(angle)) * speed,
				"spin": randf_range(-9.0, 9.0),
				"turn": randf() * TAU,
				"size": Vector2(randf_range(5.0, 9.0), randf_range(3.0, 5.0)),
				"colour": colours[i % colours.size()],
			})

	func _process(dt: float) -> void:
		_age += dt
		if _age > LIFE:
			queue_free()
			return
		for b in _bits:
			b["v"] = b["v"] * (1.0 - 1.6 * dt) + Vector2(0, 900.0) * dt
			b["at"] += b["v"] * dt
			b["turn"] += b["spin"] * dt
		queue_redraw()

	func _draw() -> void:
		var fade := clampf((LIFE - _age) / 0.35, 0.0, 1.0)
		for b in _bits:
			draw_set_transform(b["at"], b["turn"], Vector2(1.0, absf(cos(b["turn"] * 1.7)) + 0.2))
			var s: Vector2 = b["size"]
			draw_rect(Rect2(-s * 0.5, s), Color(b["colour"], fade))
		draw_set_transform(Vector2.ZERO)
