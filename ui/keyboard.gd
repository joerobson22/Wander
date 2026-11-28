class_name Keyboard
extends CanvasLayer
## Helps with the on-screen keyboard on phones and tablets. While a text box
## is being typed in, a bar with Done sits on top of the keyboard: a number
## pad has no return key, so without it there'd be no way to put the
## keyboard away. Tapping anywhere outside the box puts it away too. If the
## keyboard would cover the box, the whole app slides up just enough to
## keep it in view, and back down after.
## Boxes that know when they're full (a date's year) call Keyboard.done().
## The app shell makes one and hands it the node to slide (`lift`).

## The bar's height, and the room kept between the box and the bar.
const BAR := 46.0
const GAP := 14.0
## Shows the bar on a computer too (for screenshots and tests).
static var force := false

## What slides up out of the keyboard's way.
var lift: Control
var _bar: PanelContainer
var _done: Button
var _lifted := 0.0
## The box being typed in, last frame.
var _box: Control


func _init(to_lift: Control) -> void:
	lift = to_lift
	layer = 20
	_bar = PanelContainer.new()
	_bar.visible = false
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := MarginContainer.new()
	row.add_theme_constant_override("margin_right", 10)
	_bar.add_child(row)
	_done = Button.new()
	_done.text = Text.t("keyboard.done")
	_done.pressed.connect(done)
	_done.mouse_default_cursor_shape = Cursor.HOVER
	_done.size_flags_horizontal = Control.SIZE_SHRINK_END
	_done.focus_mode = Control.FOCUS_NONE
	_done.accessibility_name = Text.t("keyboard.done_name")
	row.add_child(_done)
	add_child(_bar)
	restyle()


## In the current colours: a paper strip with a line along its top and Done
## in bold accent on the right, as phones do it.
func restyle() -> void:
	var sb := UI.box(UI.SURFACE, Color.TRANSPARENT, 0)
	sb.set_border_width_all(0)
	sb.border_width_top = 1
	sb.border_color = UI.EDGE
	sb.set_content_margin_all(0)
	_bar.add_theme_stylebox_override("panel", sb)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var b := StyleBoxEmpty.new()
		b.content_margin_left = 14
		b.content_margin_right = 14
		_done.add_theme_stylebox_override(state, b)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_done.add_theme_color_override(c, UI.ACCENT)
	_done.add_theme_font_override("font", UI.font(true, 600))
	_done.add_theme_font_size_override("font_size", 17)


## Whether the bar is wanted at all: touch screens (or forced).
static func wanted(app: Node) -> bool:
	return force or (app != null and app.state != null and app.touch_screen())


## Puts the keyboard away: the box being typed in lets go.
func done() -> void:
	var focused := lift.get_viewport().gui_get_focus_owner() if lift.is_inside_tree() else null
	if focused:
		focused.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


## Puts the keyboard away from anywhere (a box that's full).
static func dismiss(from: Node) -> void:
	for k in from.get_tree().get_nodes_in_group("keyboard"):
		(k as Keyboard).done()
		return
	if from.get_viewport() and from.get_viewport().gui_get_focus_owner():
		from.get_viewport().gui_get_focus_owner().release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


func _ready() -> void:
	add_to_group("keyboard")


## The keyboard's height in design units (0 when there's none, or it isn't
## known yet).
func _keyboard_height() -> float:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0.0
	var px := float(DisplayServer.virtual_keyboard_get_height())
	var stretch := lift.get_viewport().get_final_transform().get_scale().y
	return px / maxf(stretch, 0.001)


func _typing_box() -> Control:
	if not lift.is_inside_tree():
		return null
	var focused := lift.get_viewport().gui_get_focus_owner()
	if focused is LineEdit and (focused as LineEdit).editable and focused.is_visible_in_tree():
		return focused
	if focused is TextEdit and (focused as TextEdit).editable and focused.is_visible_in_tree():
		return focused
	return null


func _process(delta: float) -> void:
	var app := get_tree().root.get_node_or_null("App")
	var box := _typing_box() if wanted(app) else null
	_box = box
	var view := lift.get_viewport_rect().size if lift.is_inside_tree() else Vector2.ZERO
	var keys := _keyboard_height() if box else 0.0
	_bar.visible = box != null
	if box:
		var insets := UI.safe_insets(lift)
		# On top of the keyboard, or along the bottom (above the home bar)
		# until the keyboard says how tall it is.
		var bottom := view.y - (keys if keys > 0.0 else float(insets["bottom"]))
		_bar.position = Vector2(0, bottom - BAR)
		_bar.size = Vector2(view.x, BAR)
	# Slide up just enough to keep the box clear of the bar.
	var want := 0.0
	if box:
		var bottom_of_box := box.get_global_rect().end.y + _lifted
		var clear := view.y - keys - BAR - GAP
		want = clampf(bottom_of_box - clear, 0.0, maxf(0.0, keys))
	_lifted = move_toward(_lifted, want, delta * maxf(600.0, absf(want - _lifted) * 10.0))
	if lift.is_inside_tree():
		lift.position.y = -_lifted


## A tap outside the box being typed in (and off the bar) puts the keyboard
## away. The tap still goes on to whatever it landed on.
func _input(e: InputEvent) -> void:
	if _box == null or not is_instance_valid(_box):
		return
	var pos := Vector2.INF
	if e is InputEventScreenTouch and e.pressed:
		pos = e.position
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pos = e.position
	if pos == Vector2.INF:
		return
	if _box.get_global_rect().has_point(pos) or (_bar.visible and _bar.get_global_rect().has_point(pos)):
		return
	done()
