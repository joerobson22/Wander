class_name Carousel
extends Control
## A swipeable row (or column) with the chosen item in the middle; the
## others shrink and fade the further away they are. Drag it, flick it, use
## the mouse wheel or arrow keys, or tap a neighbour to bring it to the
## middle. Tapping the middle item "activates" it.

signal changed(index: int)
signal activated(index: int)

var vertical := false
## Distance between item centres, in pixels.
var spacing := 200.0:
	set(v):
		spacing = v
		_layout()
var side_scale := 0.6
var side_alpha := 0.32
## How many items away from the middle are still shown (they fade out towards it).
var reach := 2.4
var index := 0
var items: Array[Control] = []
## Held on the item in the middle: it can't be scrolled, dragged or tapped
## (e.g. the hat carousel on your birthday, when the party hat stays on).
var locked := false:
	set(v):
		locked = v
		mouse_filter = Control.MOUSE_FILTER_IGNORE if v else Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL

var _pos := 0.0  # where the middle is, in items (animates between whole numbers)
var _pressing := false
var _dragging := false
var _press_at := Vector2.ZERO
var _press_pos := 0.0
var _last_motion := Vector2.ZERO
var _velocity := 0.0  # items per second while dragging


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	# Neighbours fade out at the edges rather than spilling over what's around it.
	clip_contents = true
	resized.connect(_layout)


func set_items(list: Array[Control], start: int = 0) -> void:
	for c in items:
		c.queue_free()
	items = list
	for c in items:
		add_child(c)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.ignore_mouse(c)
		c.resized.connect(_layout)
	index = clampi(start, 0, maxi(0, items.size() - 1))
	_pos = index
	_layout()


func go_to(i: int, animate: bool = true) -> void:
	if items.is_empty() or (locked and i != index):
		return
	i = clampi(i, 0, items.size() - 1)
	var moved := i != index
	index = i
	if animate:
		Motion.method(self, "pos", _set_pos, _pos, float(i))
	else:
		_set_pos(i)
	if moved:
		changed.emit(i)


func _set_pos(v: float) -> void:
	_pos = v
	_layout()


func _layout() -> void:
	var centre := size * 0.5
	for i in items.size():
		var it := items[i]
		var d := float(i) - _pos
		var near := clampf(absf(d), 0.0, 1.0)
		var s := lerpf(1.0, side_scale, near)
		it.size = it.get_combined_minimum_size()
		it.pivot_offset = it.size * 0.5
		it.scale = Vector2(s, s)
		var offset := d * spacing
		it.position = centre - it.size * 0.5 + (Vector2(0, offset) if vertical else Vector2(offset, 0))
		it.modulate.a = lerpf(1.0, side_alpha, near) * clampf(reach - absf(d), 0.0, 1.0)
		it.visible = absf(d) < reach


func _item_at(p: Vector2) -> int:
	var best := -1
	for i in items.size():
		var it := items[i]
		if not it.visible:
			continue
		var r := Rect2(it.position + it.pivot_offset * (Vector2.ONE - it.scale), it.size * it.scale)
		if r.has_point(p) and (best < 0 or absf(i - _pos) < absf(best - _pos)):
			best = i
	return best


func _gui_input(e: InputEvent) -> void:
	if items.is_empty():
		return
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_LEFT:
				if e.pressed:
					_pressing = true
					_dragging = false
					_press_at = e.position
					_last_motion = e.position
					_press_pos = _pos
					_velocity = 0.0
					grab_focus()
				elif _pressing:
					_pressing = false
					if _dragging:
						_settle()
					else:
						var hit := _item_at(e.position)
						if hit == index:
							activated.emit(index)
						elif hit >= 0:
							go_to(hit)
				accept_event()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				# A sideways carousel leaves the up-and-down wheel to the list
				# it's in.
				if not vertical and e.button_index == MOUSE_BUTTON_WHEEL_UP:
					return
				if e.pressed:
					go_to(index - 1)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				if not vertical and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					return
				if e.pressed:
					go_to(index + 1)
				accept_event()
	elif e is InputEventMouseMotion and _pressing:
		var along := _along(e.position - _press_at)
		var moved: Vector2 = e.position - _press_at
		var across: float = moved.x if vertical else moved.y
		if not _dragging and absf(across) > Gestures.TAP_SLOP and absf(across) > absf(along):
			# Moving the other way: that's the list around it scrolling.
			_pressing = false
			return
		if not _dragging and absf(along) > Gestures.TAP_SLOP:
			_dragging = true
		if _dragging:
			var step := _along(e.position - _last_motion) / spacing
			var dt := maxf(get_process_delta_time(), 1.0 / 240.0)
			_velocity = lerpf(_velocity, -step / dt, 0.4)
			_set_pos(clampf(_press_pos - along / spacing, -0.4, items.size() - 0.6))
		_last_motion = e.position
		accept_event()
	elif e.is_action_pressed("ui_up" if vertical else "ui_left"):
		go_to(index - 1)
		accept_event()
	elif e.is_action_pressed("ui_down" if vertical else "ui_right"):
		go_to(index + 1)
		accept_event()
	elif e.is_action_pressed("ui_accept"):
		activated.emit(index)
		accept_event()


func _along(v: Vector2) -> float:
	return v.y if vertical else v.x


## After a drag: land on the nearest item, carried on a little by a flick.
func _settle() -> void:
	var target := roundi(_pos + clampf(_velocity * 0.12, -1.5, 1.5))
	target = clampi(target, 0, items.size() - 1)
	if target == index:
		Motion.method(self, "pos", _set_pos, _pos, float(target))
	else:
		go_to(target)
