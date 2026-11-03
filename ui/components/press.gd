class_name Press
extends RefCounted
## Turns a control's pointer events into taps and long presses, ignoring a
## press that wanders off into a scroll or a swipe. Controls pass their
## _gui_input events to handle(), so every tappable thing behaves alike.

signal tapped
signal held

## Where the last press started, in the owner's own space.
var at := Vector2.ZERO
## How long a press is held before it counts as a long press.
var hold_time := Gestures.LONG_PRESS

var _owner: Control
var _watch_hold := false
var _down := false
var _timer: SceneTreeTimer


func _init(owner: Control, watch_hold: bool = false) -> void:
	_owner = owner
	_watch_hold = watch_hold
	# Anything that can be tapped shows the hand.
	if owner.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		owner.mouse_default_cursor_shape = Cursor.HOVER


## Makes `control` tappable: wires its input to a new Press and keeps the
## Press alive as long as the control is (a Press only held in a local
## variable would be freed straight away, and the taps would go nowhere).
static func attach(control: Control, watch_hold: bool = false) -> Press:
	var press := Press.new(control, watch_hold)
	control.set_meta("press", press)
	control.gui_input.connect(press.handle)
	# Tab can land on it, and Enter or Space taps it.
	if control.focus_mode == Control.FOCUS_NONE:
		control.focus_mode = Control.FOCUS_ALL
	control.focus_entered.connect(_ring.bind(control))
	control.focus_exited.connect(_ring.bind(control))
	HoverGrow.attach(control)
	return press


## The focus ring round `control` while the keyboard is on it, as buttons
## have (not after a tap or a click).
static func _ring(control: Control) -> void:
	var ring: Panel = control.get_meta("focus_ring") if control.has_meta("focus_ring") else null
	if ring == null:
		if not control.has_focus(true):
			return
		ring = Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var panel := control.get_theme_stylebox("panel") as StyleBoxFlat
		ring.add_theme_stylebox_override("panel", UI.focus_ring(panel.corner_radius_top_left if panel else UI.RADIUS))
		control.add_child(ring, false, Node.INTERNAL_MODE_FRONT)
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		control.set_meta("focus_ring", ring)
	ring.visible = control.has_focus(true)


func handle(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			at = e.position
			if _watch_hold:
				_timer = _owner.get_tree().create_timer(hold_time)
				_timer.timeout.connect(_on_timer.bind(_timer))
		elif _down:
			_down = false
			_timer = null
			if e.position.distance_to(at) < Gestures.TAP_SLOP and Rect2(Vector2.ZERO, _owner.size).has_point(e.position):
				tapped.emit()
	elif e.is_action_pressed("ui_accept") and not e.is_echo():
		_owner.accept_event()
		tapped.emit()
	elif e is InputEventMouseMotion and _down and e.position.distance_to(at) >= Gestures.TAP_SLOP:
		# Moving first means a scroll or swipe, not a tap or a pick-up.
		_down = false
		_timer = null


func _on_timer(timer: SceneTreeTimer) -> void:
	if _down and timer == _timer and _owner.is_inside_tree():
		_down = false
		_timer = null
		Gestures.claimed = true
		held.emit()
