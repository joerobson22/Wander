class_name Toast
extends PanelContainer
## A short message that floats up from the bottom, waits, then fades away
## ("Moved to Completed"). Lives on the same layer as popups, and wraps onto
## more lines if it's wider than the screen.

## How long it waits before fading; longer when it has a button to press.
var _wait := 1.8
var _text: Label


## `tone` colours it: "success" (green, something done), "danger" (red,
## something deleted) or "" (ink, anything else).
static func show_text(text: String, icon: String = "check", tone: String = "") -> void:
	_make(text, icon, tone)


## A toast with a button anchored to its right end ("Undo", with its icon
## after the word). It stays for 4 seconds, and pressing the button calls
## `on_press` and closes it.
static func show_action(text: String, icon: String, action: String, on_press: Callable, tone: String = "", action_icon: String = "undo") -> void:
	var t := _make(text, icon, tone)
	t._wait = 4.0
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var ink := t._ink
	var b := UI.button(action, Callable(), "ghost")
	UI.style_button(b, Color(1, 1, 1, 0.0), ink)
	for state in ["hover", "pressed", "hover_pressed"]:
		(b.get_theme_stylebox(state) as StyleBoxFlat).bg_color = Color(ink, 0.16 if state == "hover" else 0.24)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := b.get_theme_stylebox(state) as StyleBoxFlat
		UI.corners(sb, 999)
		sb.content_margin_left = 12
		sb.content_margin_right = 10
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
	b.custom_minimum_size = Vector2(0, 32)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 15)
	if action_icon != "":
		b.icon = Icons.texture(action_icon, 16, Color.WHITE, 2.6)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_constant_override("h_separation", 6)
	b.pressed.connect(func():
		on_press.call()
		b.disabled = true
		t.queue_free())
	var row: HBoxContainer = t.get_child(0)
	# The words take the room, pushing the button to the toast's right end.
	t._text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gap := Control.new()
	gap.custom_minimum_size.x = 6
	row.add_child(gap)
	row.add_child(b)
	(t.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 8


## The fill and the ink for a tone.
static func _colours(tone: String) -> Array[Color]:
	match tone:
		"success":
			return [UI.SUCCESS, UI.ON_COLOUR]
		"danger":
			return [UI.DANGER, UI.ON_COLOUR]
	return [UI.INK, UI.BG]


var _ink := Color.WHITE


## The one showing: a new toast takes its place at once, so two never pile
## up in the same spot (nor an old Undo stay under a new one).
static var _current: Toast


static func _make(text: String, icon: String, tone: String = "") -> Toast:
	if _current and is_instance_valid(_current):
		_current.queue_free()
	var t := Toast.new()
	_current = t
	var colours := _colours(tone)
	t._ink = colours[1]
	var b := UI.box(colours[0], Color.TRANSPARENT, 999)
	b.content_margin_left = 16
	b.content_margin_right = 20
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	t.add_theme_stylebox_override("panel", b)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(8)
	if icon != "":
		var pic := UI.icon_rect(icon, 16, t._ink)
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pic)
	t._text = UI.label(text, 15, t._ink, false, 800)
	t._text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t._text)
	t.add_child(row)
	var host: Node = (Engine.get_main_loop() as SceneTree).root
	if Modal.layer and is_instance_valid(Modal.layer):
		host = Modal.layer
	host.add_child(t)
	t._run.call_deferred()
	return t


func _run() -> void:
	var view := get_viewport_rect().size
	var most := view.x - 32.0
	var whole := get_combined_minimum_size().x
	if whole > most:
		var around := whole - _text.get_combined_minimum_size().x
		_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_text.custom_minimum_size.x = most - around
		var b := get_theme_stylebox("panel") as StyleBoxFlat
		UI.corners(b, 20)
	size = get_combined_minimum_size()
	var rest := Vector2((view.x - size.x) * 0.5, view.y - size.y - 96.0 - UI.safe_insets(self)["bottom"])
	position = rest + Vector2(0, 16)
	modulate.a = 0.0
	var t := Motion.tween(self, "toast")
	t.set_parallel(true)
	t.tween_property(self, "position", rest, Motion.time(Motion.NORMAL))
	t.tween_property(self, "modulate:a", 1.0, Motion.time(Motion.NORMAL))
	t.chain().tween_interval(_wait)
	t.chain().tween_property(self, "modulate:a", 0.0, Motion.time(Motion.NORMAL))
	t.chain().tween_callback(queue_free)
