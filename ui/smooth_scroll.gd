class_name SmoothScroll
extends Node
## Every scroll area glides: a turn of the mouse wheel eases the list to
## where it's going instead of jumping there, and turns in a row add up.
## Every scroll area can be dragged too, by a finger or the mouse, anywhere
## on it (on its cards and buttons as well as between them), and let go
## with a flick it glides on. A drag that starts on something that can't
## scroll that way is left alone (the app shell may make it a swipe), and
## so is one something else has claimed (Gestures). Trackpads and the
## scrollbar still move it directly (and take over from a glide that's under
## way). Every ScrollContainer gets it as it's made, wherever it's made;
## the app shell adds one of these.

## How far one notch of the wheel goes, as a share of what's on show.
const NOTCH := 0.16
## How quickly a glide catches up: the higher, the snappier.
const CATCH_UP := 16.0

## A drag becomes a scroll once it moves this far (more than a tap's slop,
## so a gift being picked up claims the drag first).
const DRAG_START := 16.0
## How far a let-go flick carries on, as seconds of its speed.
const FLING := 0.3

## Each gliding ScrollBar, to where it's going.
var _target: Dictionary = {}
## Each gliding ScrollBar, where the glide is (in fractions of a pixel,
## though the bar itself only takes whole ones).
var _pos: Dictionary = {}
## Each gliding ScrollBar's value as the glide last left it, so anything
## else moving it is noticed.
var _left: Dictionary = {}

## The press being watched, and the drag once it's scrolling: the bar it
## moves, the bar's value at the press, the axis (0 across, 1 down), and
## its speed in pixels a second.
var _pressed := false
var _press_at := Vector2.ZERO
var _drag_bar: ScrollBar
var _drag_from := 0.0
var _drag_axis := 1
var _drag_speed := 0.0
var _drag_time := 0
var _drag_last := 0.0
var _synthetic := false


func _ready() -> void:
	set_process(false)
	get_tree().node_added.connect(_on_added)
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		_on_added(n)


func _on_added(n: Node) -> void:
	if n is ScrollContainer and not n.has_meta("smooth_scroll"):
		n.set_meta("smooth_scroll", true)
		n.gui_input.connect(_on_input.bind(n))
		# Dragging is done here, the same everywhere, so the container's
		# own touch dragging (touch screens only) never starts.
		n.scroll_deadzone = 1000000


# --- Dragging ----------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if _synthetic:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			# Before the press reaches what's under it, which may set it.
			Gestures.lifts = false
			_pressed = not _drags_itself(get_viewport().gui_get_hovered_control())
			_press_at = e.position
			_drag_bar = null
		elif _drag_bar:
			get_viewport().set_input_as_handled()
			_let_go()
		else:
			_pressed = false
	elif e is InputEventMouseMotion and _pressed:
		if _drag_bar:
			get_viewport().set_input_as_handled()
			_drag_to(e.position)
		elif not Gestures.claimed and not Gestures.lifts and e.position.distance_to(_press_at) > DRAG_START:
			_try_drag(e.position)


## True for things a drag works on directly (scrollbars, sliders, colour
## pickers, text), which mustn't scroll the list they're in instead.
static func _drags_itself(c: Control) -> bool:
	while c != null:
		if c is ScrollBar or c is Slider or c is ColorPicker or c is LineEdit or c is TextEdit:
			return true
		if c is ScrollContainer:
			return false
		c = c.get_parent() as Control
	return false


## Starts scrolling the innermost list under the press that can move the
## way the pointer went; with none, leaves the drag to whatever wants it.
func _try_drag(pos: Vector2) -> void:
	var d := pos - _press_at
	var axis := 0 if absf(d.x) > absf(d.y) else 1
	var along := d[axis]
	var bar := _bar_under(_press_at, axis, along)
	if bar == null:
		_pressed = false
		return
	_stop(bar)
	_drag_bar = bar
	_drag_axis = axis
	# Carry on from here, so the list doesn't jump by the slop.
	_drag_from = bar.value + along
	_drag_speed = 0.0
	_drag_time = Time.get_ticks_usec()
	_drag_last = bar.value
	_cancel_press()
	get_viewport().set_input_as_handled()
	_drag_to(pos)


func _drag_to(pos: Vector2) -> void:
	if not is_instance_valid(_drag_bar):
		_drag_bar = null
		return
	var most := maxf(_drag_bar.min_value, _drag_bar.max_value - _drag_bar.page)
	_drag_bar.value = clampf(_drag_from - (pos - _press_at)[_drag_axis], _drag_bar.min_value, most)
	var now := Time.get_ticks_usec()
	var dt := maxf((now - _drag_time) / 1000000.0, 0.001)
	_drag_speed = lerpf(_drag_speed, (_drag_bar.value - _drag_last) / dt, 0.4)
	_drag_time = now
	_drag_last = _drag_bar.value


## Let go: a flick glides on a little and eases to a stop.
func _let_go() -> void:
	var bar := _drag_bar
	_drag_bar = null
	_pressed = false
	# Held still before letting go: no flick.
	if not is_instance_valid(bar) or Time.get_ticks_usec() - _drag_time > 80000:
		return
	var most := maxf(bar.min_value, bar.max_value - bar.page)
	var to := clampf(bar.value + _drag_speed * FLING, bar.min_value, most)
	if absf(to - bar.value) < 1.0:
		return
	_pos[bar] = bar.value
	_left[bar] = bar.value
	_target[bar] = to
	set_process(true)


## The bar of the innermost visible list at `pos` that can still scroll
## along `axis` the way a drag of `along` pixels pushes it, or null.
func _bar_under(pos: Vector2, axis: int, along: float) -> ScrollBar:
	var found: ScrollBar = null
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var sc := n as ScrollContainer
		if sc == null or not sc.is_visible_in_tree() or not sc.get_global_rect().has_point(pos):
			continue
		var mode := sc.horizontal_scroll_mode if axis == 0 else sc.vertical_scroll_mode
		var bar: ScrollBar = [sc.get_h_scroll_bar(), sc.get_v_scroll_bar()][axis]
		if mode == ScrollContainer.SCROLL_MODE_DISABLED or bar.max_value - bar.page <= bar.min_value:
			continue
		var most := bar.max_value - bar.page
		# Dragging up or left shows more further on. A few pixels' slack, as
		# the app shell gives swipes, so a list only just at its end lets go.
		if (along < 0.0 and bar.value < most - 8.0) or (along > 0.0 and bar.value > bar.min_value + 8.0):
			if found == null or found.get_parent().is_ancestor_of(sc):
				found = bar
	return found


## Tells whatever the pointer pressed that the press is over (by moving the
## pointer far away and letting go there), so a drag never also taps.
func _cancel_press() -> void:
	_synthetic = true
	var far := Vector2(-100000, -100000)
	var mm := InputEventMouseMotion.new()
	mm.position = far
	mm.global_position = far
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(mm, true)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = far
	mb.global_position = far
	get_viewport().push_input(mb, true)
	_synthetic = false


# --- The wheel ---------------------------------------------------------------


## Takes a wheel turn before the ScrollContainer does, and glides instead.
## Like the ScrollContainer, the wheel goes sideways with Shift held, or
## when there's no scrolling down; and a list resting at its end lets the
## turn through to whatever it's inside.
func _on_input(e: InputEvent, sc: ScrollContainer) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var way := 0.0
	var sideways := false
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			way = -1.0
		MOUSE_BUTTON_WHEEL_DOWN:
			way = 1.0
		MOUSE_BUTTON_WHEEL_LEFT:
			way = -1.0
			sideways = true
		MOUSE_BUTTON_WHEEL_RIGHT:
			way = 1.0
			sideways = true
		_:
			return
	var v_bar: ScrollBar = sc.get_v_scroll_bar()
	var h_bar: ScrollBar = sc.get_h_scroll_bar()
	var can_down := sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and v_bar.visible
	var can_across := sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and h_bar.visible
	if not sideways and ((can_across and mb.shift_pressed) or not can_down):
		sideways = true
	if (sideways and not can_across) or (not sideways and not can_down):
		return
	var bar: ScrollBar = h_bar if sideways else v_bar
	var factor: float = mb.factor if mb.factor > 0.0 else 1.0
	var from: float = _target.get(bar, bar.value)
	var to := clampf(from + way * bar.page * NOTCH * factor, bar.min_value, maxf(bar.min_value, bar.max_value - bar.page))
	var gliding := _target.has(bar)
	# A turn while it's still gliding to its end is kept here, or the
	# ScrollContainer would jump the rest of the way.
	if is_equal_approx(to, from) and not gliding:
		return
	sc.accept_event()
	if not gliding:
		_pos[bar] = bar.value
		_left[bar] = bar.value
	_target[bar] = to
	set_process(true)


func _process(delta: float) -> void:
	var rate := CATCH_UP * (2.0 if Motion.reduced() else 1.0)
	var step := 1.0 - exp(-rate * delta)
	for bar in _target.keys():
		# Gone, hidden, or moved by something else: that wins.
		if not is_instance_valid(bar) or not bar.is_visible_in_tree() or absf(bar.value - _left[bar]) > 0.5:
			_stop(bar)
			continue
		var to: float = _target[bar]
		var at := lerpf(float(_pos[bar]), to, step)
		if absf(to - at) < 0.5:
			at = to
		bar.value = at
		_pos[bar] = at
		_left[bar] = bar.value
		if at == to:
			_stop(bar)
	if _target.is_empty():
		set_process(false)


func _stop(bar: ScrollBar) -> void:
	_target.erase(bar)
	_pos.erase(bar)
	_left.erase(bar)
