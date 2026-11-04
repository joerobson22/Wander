class_name WeatherPicker
extends Button
## The walk's weather: a small round paper button showing the weather's
## icon. Tapping it drops a column of icons under it, one for each kind of
## weather; pick one and the walk changes to it. With the real weather on
## (Outdoors), the first is "where you are": today's weather there, nudged
## up and left, with a map pin over its lower right. A holiday that pins the
## weather (snow at Christmas) shows it, and it can't be changed.

signal chosen(option: String)

const SIZE := 40
## Each kind's icon in assets/icons ("weather_rainy").
const ICON_NAME := "weather_%s"
const ICON := 20
## The icons in the menu, and the gap round them.
const ITEM := 40
const GAP := 6

## "real", or one of Weather.KINDS.
var current := ""
var _options: Array[String] = []
var _face: Control
var _menu: Control


func _init() -> void:
	accessibility_name = Text.t("walk.weather")
	custom_minimum_size = Vector2(SIZE, SIZE)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	focus_mode = Control.FOCUS_ALL
	UI.style_button(self, UI.SURFACE, UI.INK, 999)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		(get_theme_stylebox(state) as StyleBoxFlat).set_content_margin_all(0)
	var look := App.holiday_look()
	if look and look.weather in Weather.KINDS:
		current = look.weather
		_options = [look.weather]
		disabled = true
	else:
		if Outdoors.enabled():
			_options.append("real")
		_options.append_array(Weather.KINDS)
		current = Outdoors.choice()
		if current == "":
			current = "real" if Outdoors.enabled() else "sunny"
	pressed.connect(_open)
	_show()


## The name said for an option ("Where you are", "Rain").
static func option_name(option: String) -> String:
	if option == "real":
		return Text.t("walk.weather_real")
	return str(Weather.look(option, Content.weathers)["name"])


## An option's picture, `px` across, in `ink`: the weather's icon, or for
## "real" today's weather nudged up and left under a map pin.
static func face(option: String, px: int, ink: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if option != "real":
		var r := UI.icon_rect(ICON_NAME % option, px, ink)
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(r)
		return holder
	var under := UI.icon_rect(ICON_NAME % Outdoors.real_weather(), int(px * 0.85), ink)
	under.size = Vector2(px, px) * 0.85
	under.position = Vector2(-px * 0.12, -px * 0.12)
	holder.add_child(under)
	var pin_px := int(px * 0.6)
	# A ring of paper round the pin keeps it apart from the weather.
	var cut := TextureRect.new()
	cut.texture = Icons.texture("pin", pin_px, UI.SURFACE, 5.0)
	cut.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.size = Vector2(pin_px, pin_px)
	cut.position = Vector2(px * 0.5, px * 0.42)
	holder.add_child(cut)
	var pin := UI.icon_rect("pin", pin_px, UI.ACCENT)
	pin.size = Vector2(pin_px, pin_px)
	pin.position = cut.position
	holder.add_child(pin)
	return holder


func _show() -> void:
	if is_instance_valid(_face):
		_face.queue_free()
	_face = face(current, ICON, Color(UI.INK, 0.45) if disabled else UI.INK)
	add_child(_face)
	_face.position = (custom_minimum_size - _face.custom_minimum_size) * 0.5
	accessibility_name = Text.t("common.labelled", {"label": Text.t("walk.weather"), "value": option_name(current)})


## Sinks with the button when it's pressed.
func _process(_dt: float) -> void:
	if is_instance_valid(_face):
		_face.position = Vector2(size.x - ICON, size.y - ICON) * 0.5 + Vector2(0, float(UI.DEPTH) if is_pressed() else 0.0)


func _open() -> void:
	if is_instance_valid(_menu) or disabled:
		return
	var host: Control = Modal.layer if Modal.layer and is_instance_valid(Modal.layer) else get_tree().root.get_child(0)
	# A clear sheet behind the menu: tapping anywhere else closes it.
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	host.add_child(_menu)
	var card := UI.card(UI.SURFACE, GAP, 999)
	_menu.add_child(card)
	var list := UI.vbox(GAP)
	card.add_child(list)
	var keys := has_focus(true)
	for o in _options:
		var b := Button.new()
		b.custom_minimum_size = Vector2(ITEM, ITEM)
		b.accessibility_name = option_name(o)
		b.focus_mode = Control.FOCUS_ALL
		# The chosen one sits in a soft green circle; the rest only shade.
		var on := o == current
		UI.flat_button(UI.style_button(b, UI.ACCENT_SOFT if on else Color.TRANSPARENT, UI.INK, 999))
		var pic := face(o, ICON, UI.INK)
		b.add_child(pic)
		pic.position = Vector2(ITEM - ICON, ITEM - ICON) * 0.5
		b.pressed.connect(_choose.bind(o))
		list.add_child(b)
		if on and keys:
			b.grab_focus.call_deferred()
	card.size = card.get_combined_minimum_size()
	var at := get_global_rect()
	var y := at.end.y + 8.0
	if y + card.size.y > _menu.size.y - 8.0:
		y = at.position.y - 8.0 - card.size.y
	y = clampf(y, 8.0, maxf(8.0, _menu.size.y - card.size.y - 8.0))
	card.position = Vector2(at.get_center().x - card.size.x * 0.5, y)
	card.position.x = clampf(card.position.x, 8.0, _menu.size.x - card.size.x - 8.0)
	card.modulate.a = 0.0
	var t := Motion.tween(card, "menu")
	t.set_parallel(true)
	t.tween_property(card, "modulate:a", 1.0, Motion.time(Motion.FAST))
	t.tween_property(card, "position:y", card.position.y, Motion.time(Motion.FAST)).from(card.position.y - 4.0)


## Leaving with the menu open (the walk ends) takes the menu too, so its
## sheet doesn't stay over the screen catching every tap.
func _exit_tree() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()


func _choose(option: String) -> void:
	_close()
	if option == current:
		return
	current = option
	_show()
	chosen.emit(option)


## Esc closes the menu (not the walk) and goes back to the button.
func _unhandled_input(e: InputEvent) -> void:
	if is_instance_valid(_menu) and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if is_instance_valid(_menu):
		var m := _menu
		_menu = null
		if m.get_viewport().gui_get_focus_owner() and m.is_ancestor_of(m.get_viewport().gui_get_focus_owner()):
			grab_focus()
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.ignore_mouse(m)
		Motion.fade(m, 0.0, Motion.FAST).tween_callback(m.queue_free)
