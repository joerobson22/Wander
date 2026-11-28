extends Pane
## The middle of the app: a greeting, and under it the focus orb with
## "Tap to focus" under it. Tap the orb (a soft bong) and it swells to
## fill the screen as the choose focus screen grows out of it. A home icon
## in the top left marks it, as each screen's icon does. Behind it all is
## the hilltop view (HomeBackdrop, drawn by the app shell). While a holiday
## is on, a switch in the top right turns its look on or off (its present
## and pet come either way). Debug builds also get small switches beside the
## home icon (DebugBar).
## Arriving home after making an account plays an intro (see intro()).

## The first arrival's done: the shell brings in the map and the arrows.
signal intro_done

## Room above the orb for the greeting, whose words sit at the bottom of it.
const GREETING_BOX := 160.0
const GREETING_SIZE := 24
## The gap between the greeting's last line and the orb.
const GREETING_GAP := 48.0

var _orb: FocusOrb
var _greeting: Label
var _hint: Label
var _home: Control
## The holiday's switch in the top right, and the holiday it's for ("" when
## there's none on, and it's hidden).
var _holiday_toggle: Control
var _toggle_for := ""
var _debug: DebugBar
var _sky_debug: Control
var _line := ""
## How many walks there had been when the greeting was picked: a new line
## each time you come home from one.
var _line_walks := -1
## The holiday it was picked for: a holiday brings its own lines.
var _line_holiday := ""
## True while the first arrival plays (see intro()), and how far it's got.
var _intro := false
var _intro_stage := 4


func build() -> void:
	_pick_line()
	_greeting = UI.label(_line, GREETING_SIZE, UI.INK, true, 600)
	_greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_greeting.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_greeting.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_greeting)
	if not is_instance_valid(_orb):
		_orb = FocusOrb.new()
		_orb.tapped.connect(_on_tapped)
		add_child(_orb)
	_hint = UI.label("", 15, UI.INK_SOFT, false, 700)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_home = UI.icon_tile(Minimap.ICONS["focus"])
	add_child(_home)
	_toggle_for = ""
	_holiday_toggle = null
	_sync_holiday_toggle()
	if OS.is_debug_build():
		_debug = DebugBar.new()
		add_child(_debug)
		_sky_debug = DebugBar.sky_controls()
		add_child(_sky_debug)
	_update_hint()
	_place()
	# Rebuilt mid-intro: the new words start where the intro has got to.
	if _intro:
		_set_stage(_intro_stage, true)


## Arriving home for the first time, after making an account. Everything
## but the debug switches is hidden while the view tilts up from the
## hilltop (`wait` seconds); then the orb grows from nothing, the greeting
## drops in and types itself out (as a walk's encouragement does), and
## "Tap to focus" rises into place. Then the home icon fades in, as the
## shell brings in the map and the arrows (intro_done).
func intro(wait: float) -> void:
	if not is_instance_valid(_greeting):
		rebuild()
	# A greeting with your new name in it.
	_line = ""
	_pick_line()
	_greeting.text = _line
	_set_stage(0)
	# One tween on the screen itself, which a rebuild doesn't free; each
	# step works on the words there are when it comes.
	var t := Motion.tween(self, "intro")
	t.tween_interval(Motion.time(wait))
	t.tween_callback(_set_stage.bind(1))
	t.tween_interval(Motion.time(Motion.style.orb_grow))
	t.tween_callback(_set_stage.bind(2))
	t.tween_interval(maxf(Motion.time(Motion.SLOW), _typing_time(_line)))
	t.tween_callback(_set_stage.bind(3))
	t.tween_interval(Motion.time(Motion.SLOW))
	t.tween_callback(_set_stage.bind(4))


## How long typing out `text` takes (Motion.type_out), or 0 when it isn't typed.
static func _typing_time(text: String) -> float:
	if Motion.reduced():
		return 0.0
	var total := 0.0
	for ch in text:
		total += Motion.style.type_letter + (Motion.style.type_space if ch == " " else 0.0)
	return Motion.time(total)


## The intro's steps: 0 nothing but the debug switches, 1 the orb grows in,
## 2 the greeting drops in typing itself out, 3 "Tap to focus" rises in, 4
## done (the home icon fades in, and the shell brings the map and arrows).
## `rebuilt`: the words were just made again mid-way, so they're put
## straight where this step has them.
func _set_stage(stage: int, rebuilt: bool = false) -> void:
	_intro = stage < 4
	_intro_stage = stage
	_greeting.visible_characters = 0 if stage < 2 else -1
	_greeting.modulate.a = 0.0 if stage < 2 else 1.0
	_hint.modulate.a = 0.0 if stage < 3 else 1.0
	_home.modulate.a = 0.0 if stage < 4 else 1.0
	if is_instance_valid(_holiday_toggle):
		_holiday_toggle.modulate.a = _home.modulate.a
	match stage:
		0:
			Motion.tween(_orb, "intro").kill()
			_orb.scale = Vector2.ZERO
		1:
			var t := Motion.tween(_orb, "intro")
			if not Motion.reduced():
				# A little overshoot, as it pops into being.
				t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(_orb, "scale", Vector2.ONE, Motion.time(Motion.style.orb_grow))
		2:
			if not rebuilt:
				_greeting.visible_characters = 0
				Motion.enter(_greeting, 0.0, -Motion.style.drop, Motion.SLOW)
				Motion.type_out(_greeting, _line, false)
		3:
			if not rebuilt:
				Motion.enter(_hint, 0.0, Motion.style.hint_rise, Motion.SLOW)
		4:
			if not rebuilt:
				_home.modulate.a = 0.0
				Motion.fade(_home, 1.0, Motion.style.home_ui_fade)
			intro_done.emit()
	if stage >= 2:
		Motion.tween(_orb, "intro").kill()
		_orb.scale = Vector2.ONE


## The orb keeps drifting through a rebuild (it doesn't take its colours
## from the palette).
func keeps() -> Array[Node]:
	return [_orb]


func _pick_line() -> void:
	var walks := int(App.state.profile.get("walks", 0))
	var holiday := App.holiday()
	if _line != "" and walks == _line_walks and holiday == _line_holiday:
		return
	_line_walks = walks
	_line_holiday = holiday
	# The time of day the sky shows (the debug slider can move it).
	var hour := int(App.day_hour())
	_line = Content.greeting(hour, str(App.state.profile.get("username", "")), App.rng, holiday)


## A fresh line when a holiday starts or ends (main calls this).
func holiday_changed() -> void:
	_sync_holiday_toggle()
	if not is_instance_valid(_greeting) or App.holiday() == _line_holiday:
		return
	_pick_line()
	_greeting.text = _line
	_place()


func _place() -> void:
	if not is_instance_valid(_orb):
		return
	# Half the screen: the orb's diameter is half the short side, a little
	# more on narrow phones where width is the short side.
	var d := minf(size.x * 0.7, size.y * 0.5)
	_orb.size = Vector2(d, d)
	_orb.position = (size - _orb.size) * 0.5 + Vector2(0, size.y * 0.02)
	# (It grows from its middle when it first appears.)
	_orb.pivot_offset = _orb.size * 0.5
	_hint.size = Vector2(d, _hint.get_combined_minimum_size().y)
	_hint.position = Vector2(_orb.position.x, _orb.position.y + d + 20)
	# The home icon sits where the other screens' title icons do.
	var insets := UI.safe_insets(self)
	_home.size = _home.custom_minimum_size
	_home.position = Vector2((32.0 if wide else 18.0) + insets["left"], float(Pane.EDGE_GAP) + insets["top"])
	if is_instance_valid(_debug):
		_debug.size = _debug.get_combined_minimum_size()
		_debug.position = Vector2(_home.position.x + _home.size.x + 12.0, _home.position.y)
		_sky_debug.size = _sky_debug.get_combined_minimum_size()
		var right: float = size.x - _sky_debug.size.x * DebugBar.SCALE - (32.0 if wide else 18.0) - insets["right"]
		var after_switches: float = _debug.position.x + _debug.size.x * DebugBar.SCALE + 16.0
		if right >= after_switches:
			_sky_debug.position = Vector2(right, _home.position.y)
		else:
			# No room beside the switches (a phone): under them.
			_sky_debug.position = Vector2(_debug.position.x, _debug.position.y + _debug.size.y * DebugBar.SCALE + 6.0)
	if is_instance_valid(_holiday_toggle):
		# Top right, level with the home icon (under the debug sky controls
		# when they're there).
		_holiday_toggle.size = _holiday_toggle.get_combined_minimum_size()
		var top: float = _home.position.y + (_home.size.y - _holiday_toggle.size.y) * 0.5
		if is_instance_valid(_sky_debug) and _sky_debug.position.y <= _home.position.y + 1.0:
			top = _sky_debug.position.y + _sky_debug.size.y * DebugBar.SCALE + 8.0
		_holiday_toggle.position = Vector2(size.x - _holiday_toggle.size.x - (32.0 if wide else 18.0) - insets["right"], top)
	var w := minf(560.0, size.x - 48.0)
	var bottom := _orb.position.y - GREETING_GAP
	# Debug builds: clear of the sky controls in the top right, if the
	# greeting could reach up beside them.
	if is_instance_valid(_sky_debug) and _sky_debug.position.x > size.x * 0.5 \
			and bottom - GREETING_BOX < _sky_debug.position.y + _sky_debug.size.y * DebugBar.SCALE:
		w = minf(w, (_sky_debug.position.x - size.x * 0.5 - 16.0) * 2.0)
	# A tall box with the words at its bottom, rather than one measured to
	# fit: a wrapping label's measured height isn't stable across rebuilds,
	# and the words would jump when the colours change.
	_greeting.size = Vector2(w, GREETING_BOX)
	# (It can come out taller; its bottom is what stays put.)
	_greeting.position = Vector2((size.x - w) * 0.5, bottom - _greeting.size.y)


func _update_hint() -> void:
	_hint.text = Text.t("focus.hint_first_pet" if App.state.active_pets().is_empty() else "focus.hint")
	_place()


## Only the hint (and, after a walk, the greeting) depend on the game state,
## and in debug builds the sky controls.
func _on_state_changed() -> void:
	if is_instance_valid(_sky_debug):
		# The debug pills show what's picked, even when the look stays the
		# same (Light picked while Auto was already light).
		var fresh := DebugBar.sky_controls()
		add_child(fresh)
		move_child(fresh, _sky_debug.get_index())
		remove_child(_sky_debug)
		_sky_debug.queue_free()
		_sky_debug = fresh
	if is_instance_valid(_hint):
		_update_hint()
	_sync_holiday_toggle()



func _on_resized() -> void:
	_place()


func _on_shown() -> void:
	if is_instance_valid(_orb):
		_orb.running = true
	if is_instance_valid(_greeting) and not _intro and (int(App.state.profile.get("walks", 0)) != _line_walks or App.holiday() != _line_holiday):
		_pick_line()
		_greeting.text = _line
		_place()
		Motion.enter(_greeting, 0.1, 10.0)


func _on_hidden() -> void:
	if is_instance_valid(_orb):
		_orb.running = false
		_orb.settle()


## Where a closing flow shrinks to: the orb's middle and radius on screen,
## or nothing before it's laid out.
func orb_circle() -> Dictionary:
	if not is_instance_valid(_orb) or _orb.size.x <= 0.0:
		return {}
	return {"centre": _orb.get_global_rect().get_center(), "radius": _orb.radius() * _orb.get_global_transform().get_scale().x}


## A full-screen flow is closing into the orb: it shrinks back from filling
## the screen as the flow's circle does.
func orb_return(seconds: float) -> void:
	if is_instance_valid(_orb):
		_orb.shrink_from_full(seconds)


func _on_tapped() -> void:
	Audio.play("orb_tap", 1.0, -4.0, "bong")
	_orb.fill_screen()
	App.go("choose_focus", {"from": _orb.get_global_rect().get_center()})


## Shows the holiday's switch while one is on (rebuilt when it changes),
## and hides it on an ordinary day.
func _sync_holiday_toggle() -> void:
	if not is_instance_valid(_home):
		return
	var id := App.holiday_now()
	if id == _toggle_for and (id == "") == not is_instance_valid(_holiday_toggle):
		return
	_toggle_for = id
	if is_instance_valid(_holiday_toggle):
		_holiday_toggle.queue_free()
		_holiday_toggle = null
	if id == "":
		return
	_holiday_toggle = _make_holiday_toggle(id)
	_holiday_toggle.modulate.a = _home.modulate.a
	add_child(_holiday_toggle)
	_place()


## A soft pill: the holiday's name, then its switch. Tapping anywhere on it
## flips it.
func _make_holiday_toggle(id: String) -> Control:
	var pill := PanelContainer.new()
	var sb := UI.box(Color(UI.SURFACE, 0.86), Color.TRANSPARENT, 999)
	sb.content_margin_left = 16
	sb.content_margin_right = 6
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	pill.add_theme_stylebox_override("panel", sb)
	var row := UI.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var title := UI.label(str(Content.holiday(id).get("name", id)), 15, UI.INK, false, 800)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var on := App.holiday_theme_on()
	var flip := Switch.new(on)
	flip.custom_minimum_size = Vector2(46, 40)
	flip.accessibility_name = Text.t("focus.holiday_toggle", {"holiday": title.text})
	flip.toggled.connect(func(now: bool):
		# After the knob has slid, so the screens redress behind it.
		get_tree().create_timer(Motion.time(Switch.SLIDE)).timeout.connect(func():
			App.set_setting("holiday_theme", now)))
	row.add_child(flip)
	pill.mouse_filter = Control.MOUSE_FILTER_STOP
	pill.mouse_default_cursor_shape = Cursor.HOVER
	pill.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed \
				and pill.get_global_rect().has_point(pill.get_global_transform() * e.position):
			flip.button_pressed = not flip.button_pressed)
	return pill
