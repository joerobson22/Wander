class_name DebugBar
extends VBoxContainer
## Only in debug builds (runs from the editor, debug exports). On the focus
## screen, small, beside the home icon in the top left: a switch that
## unlocks every animal and place (and tops every gift up to 50), and one
## that gives the window a phone's shape and lays the app out as on a phone
## (off: the window as it was). In the top right, sky_controls(): a time of
## day slider for the sky, which turns the colours dark after sunset (Now
## follows the clock), and a holiday picker to try each holiday's look
## (Today's date follows the calendar).
## The walk also shows the buttons here that move it on.

## How far the walk's time buttons move it on, in minutes.
const STEPS := [5, 10, 30, 60]


## How big the switches are drawn, so they sit quietly beside the home icon.
const SCALE := 0.8
## Each switch's row height, before SCALE: two rows match the icon's height.
const ROW := 26


func _init() -> void:
	scale = Vector2(SCALE, SCALE)
	add_theme_constant_override("separation", 4)
	# Two switches, one under the other, with "DEBUG" by the first.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(UI.label(Text.t("debug.title"), 11, UI.INK_FAINT, false, 900))
	_switch(grid, Text.t("debug.unlock_all"), Text.t("debug.unlock_all_note"), App.debug_unlock_all(), "debug_unlock_all")
	grid.add_child(Control.new())
	_switch(grid, Text.t("debug.phone_size"), Text.t("debug.phone_size_note"), App.debug_phone_view(), "debug_phone_view")
	add_child(grid)


## The time of day row, for the focus screen's top right.
static func sky_controls() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.scale = Vector2(SCALE, SCALE)
	box.add_theme_constant_override("separation", 4)
	box.add_child(_time_row())
	box.add_child(_holiday_row())
	return box


## Today's date, no holiday, or any holiday's look, whatever the date.
static func _holiday_row() -> Control:
	var row := UI.hbox(6)
	row.add_child(_caption(Text.t("debug.holiday")))
	var options := [["", Text.t("debug.holiday_real")], ["none", Text.t("debug.holiday_none")]]
	for h in Content.holidays:
		options.append([h["id"], h["name"]])
	var pick := Dropdown.new(options, str(App.state.settings.get("debug_holiday", "")), false, "", false)
	pick.accessibility_name = Text.t("debug.holiday_note")
	pick.chosen.connect(func(option: String, _reversed: bool): App.set_setting("debug_holiday", option))
	row.add_child(pick)
	return row


## A slider through the day, and Now to follow the clock again.
static func _time_row() -> Control:
	var row := UI.hbox(6)
	row.add_child(_caption(Text.t("debug.time")))
	var forced := float(App.state.settings.get("debug_hour", -1.0))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 24.0
	slider.step = 0.25
	slider.value = forced if forced >= 0.0 else App.day_hour()
	slider.custom_minimum_size = Vector2(150, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.accessibility_name = Text.t("debug.time_note")
	row.add_child(slider)
	var shown := UI.label(_clock(forced if forced >= 0.0 else App.day_hour()), 12, UI.INK_SOFT, false, 800)
	shown.custom_minimum_size.x = 40
	shown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(shown)
	# While dragging only the label and the sky follow; letting go saves it
	# (and the colours change if it's crossed sunset or sunrise).
	slider.value_changed.connect(func(v: float):
		shown.text = _clock(v)
		App.state.settings["debug_hour"] = v
		App.sky_moved.emit())
	slider.drag_ended.connect(func(_changed: bool): App.set_setting("debug_hour", slider.value))
	var now := UI.pill_button(Text.t("debug.time_now"), forced < 0.0, func():
		App.set_setting("debug_hour", -1.0), 24)
	now.add_theme_font_size_override("font_size", 12)
	row.add_child(now)
	return row


static func _caption(text: String) -> Label:
	var l := UI.label(text, 12, UI.INK_FAINT, false, 900)
	l.custom_minimum_size.x = 44
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## "14:30", or "Now" while following the clock.
static func _clock(hour: float) -> String:
	if hour < 0.0:
		return Text.t("debug.time_now")
	var minutes := int(round(hour * 60.0)) % (24 * 60)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _switch(grid: GridContainer, title: String, tip: String, on: bool, setting: String) -> void:
	var sw := Switch.new(on)
	sw.custom_minimum_size.y = ROW
	sw.accessibility_name = tip
	sw.toggled.connect(func(value: bool):
		App.set_setting(setting, value)
		# Unlocking everything hands out 50 of every gift too (kept after).
		if value and setting == "debug_unlock_all":
			App.debug_fill_gifts())
	grid.add_child(sw)
	var words := UI.label(title, 13, UI.INK_SOFT, false, 800)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(words)


## Small paper buttons that add 5, 10, 30 or 60 minutes to the walk.
static func time_buttons() -> HBoxContainer:
	var row := UI.hbox(6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for minutes in STEPS:
		var b := Button.new()
		b.text = Text.t("debug.add_minutes", {"minutes": minutes})
		b.custom_minimum_size = Vector2(46, 32)
		b.add_theme_font_size_override("font_size", 13)
		UI.style_button(b, UI.SURFACE, UI.INK, 999, true)
		b.pressed.connect(App.debug_add_minutes.bind(minutes))
		row.add_child(b)
	return row
