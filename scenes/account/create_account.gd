class_name CreateAccount
extends Control
## The create account screen: on a first launch and after Log out it covers
## the whole app. It asks for your name, where you study and your date of
## birth, and Create waits for all three and for the box agreeing to the
## Privacy Policy and Terms of Service (each opens in a popup). Under 18,
## Create first asks a parent or guardian to approve, in a popup that only
## Approve closes. Then the account starts and the focus screen shows.
## "I have an account" under it lists the accounts on this device to log
## back into (AccountSwitcher); it only shows when there's one.

## As wide as this, or the screen less a 16px gutter each side.
const WIDTH := 420.0
const GUTTER := 16.0
## Shorter than this, the paw over the title goes.
const SHORT := 680.0

var _name: LineEdit
var _school: LineEdit
## Day, month and year of birth.
var _dob: Array[LineEdit] = []
var _dob_wrong: Label
var _agree: Button
var _create: Button
var _have: Button
var _col: VBoxContainer


## `kept`: what was typed before the screen was rebuilt (typed()).
## `own_backdrop`: draw the app's background colour behind it; otherwise it
## sits on the hilltop view the app keeps behind every screen.
func _init(kept: Dictionary = {}, own_backdrop: bool = true) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if own_backdrop:
		add_child(UI.backdrop())

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var col := UI.vbox(12)
	_col = col
	centre.add_child(col)
	var mark := UI.icon_rect("paw", 44, UI.ACCENT)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(mark)
	resized.connect(func():
		_col.custom_minimum_size.x = minf(WIDTH, size.x - GUTTER * 2.0)
		# On a short screen (a computer's) the paw makes room for the form.
		mark.visible = size.y >= SHORT)
	var title := UI.label(Text.t("create.title"), 34, UI.INK, true, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	# Ink, not the soft grey: it sits over the ground, not a card.
	var note := UI.para(Text.t("create.note"), 15, UI.INK)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)

	var card := UI.card(UI.SURFACE, 20)
	col.add_child(card)
	var form := UI.vbox(6)
	card.add_child(form)
	_name = _field(form, Text.t("create.name"), Text.t("profile.username_placeholder"), 24, kept.get("name", ""))
	form.add_child(_gap(2))
	_school = _field(form, Text.t("create.school"), Text.t("profile.school_placeholder"), 60, kept.get("school", ""))
	form.add_child(_gap(2))
	form.add_child(_birth_row(kept.get("dob", ["", "", ""])))
	form.add_child(_gap(2))
	form.add_child(_agree_row(kept.get("agreed", false)))
	form.add_child(_gap(2))
	_create = UI.button(Text.t("create.create"), _submit, "accent")
	form.add_child(_create)

	_have = UI.button(Text.t("create.have_account"), _open_accounts, "ghost")
	_have.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_have.add_theme_color_override("font_color", UI.ACCENT)
	_have.add_theme_color_override("font_hover_color", UI.ACCENT)
	_have.add_theme_font_size_override("font_size", 15)
	if not own_backdrop:
		# A soft pill behind it, as behind the focus screen's hint, so it
		# reads over the hilltop view.
		_have.custom_minimum_size.y = 38
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var sb := (_have.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
			if state != "focus":
				sb.bg_color = Color(UI.BG, 0.8)
			sb.set_corner_radius_all(99)
			sb.content_margin_left = 18
			sb.content_margin_right = 18
			_have.add_theme_stylebox_override(state, sb)
	col.add_child(_have)

	_name.text_changed.connect(func(_t): _refresh())
	_school.text_changed.connect(func(_t): _refresh())
	_name.text_submitted.connect(func(_t): _school.grab_focus())
	_school.text_submitted.connect(func(_t): _dob[0].grab_focus())
	_refresh()


func _ready() -> void:
	refresh_accounts()
	if not App.touch_screen():
		_name.grab_focus.call_deferred()


## What's typed so far, to carry over when the screen is rebuilt.
func typed() -> Dictionary:
	return {"name": _name.text, "school": _school.text, "dob": _dob.map(func(e): return e.text), "agreed": _agree.button_pressed}


static func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap


## A caption over a text box, in `form`.
func _field(form: Control, caption: String, placeholder: String, max_length: int, text: String) -> LineEdit:
	form.add_child(UI.caption(caption.to_upper()))
	var edit := _edit(placeholder, max_length, text, caption)
	form.add_child(edit)
	return edit


static func _edit(placeholder: String, max_length: int, text: String, spoken: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.text = text
	edit.custom_minimum_size.y = 46
	edit.accessibility_name = spoken
	return edit


## Date of birth: day, month and year boxes that take only digits, moving
## on to the next box once one is full. A date that can't be right says so
## under them.
func _birth_row(start: Array) -> Control:
	var box := UI.vbox(6)
	box.add_child(UI.caption(Text.t("create.dob").to_upper()))
	var row := UI.hbox(8)
	var parts := [["dob_day", 2, 66.0], ["dob_month", 2, 66.0], ["dob_year", 4, 96.0]]
	for i in parts.size():
		var edit := _edit(Text.t("create." + parts[i][0]), parts[i][1], str(start[i]), Text.t("create.%s_name" % parts[i][0]))
		edit.custom_minimum_size.x = parts[i][2]
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		edit.text_changed.connect(_on_dob_typed.bind(i))
		edit.text_submitted.connect(func(_t): _next_after(i))
		_dob.append(edit)
		row.add_child(edit)
	box.add_child(row)
	_dob_wrong = UI.para(Text.t("create.dob_invalid"), 13, UI.DANGER, 700)
	_dob_wrong.visible = false
	box.add_child(_dob_wrong)
	return box


func _on_dob_typed(text: String, i: int) -> void:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	var edit := _dob[i]
	if digits != text:
		edit.text = digits
		edit.caret_column = digits.length()
	if digits.length() == edit.max_length and edit.has_focus():
		_next_after(i)
	_refresh()


func _next_after(i: int) -> void:
	if i + 1 < _dob.size():
		_dob[i + 1].grab_focus()
	elif _agree:
		_agree.grab_focus()


func _birth() -> String:
	return Legal.dob(_dob[0].text, _dob[1].text, _dob[2].text, Time.get_date_dict_from_system())


## The box to tick, then "I agree to the Privacy Policy and Terms of
## Service", wrapping on a narrow screen. The two names open their
## documents; tapping the other words ticks the box too.
func _agree_row(start: bool) -> Control:
	var row := UI.hbox(12)
	_agree = Button.new()
	_agree.toggle_mode = true
	_agree.button_pressed = start
	_agree.custom_minimum_size = Vector2(28, 28)
	_agree.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_agree.accessibility_name = Text.t("create.agree_name")
	_agree.expand_icon = false
	_agree.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var off := UI.box(UI.SURFACE, UI.INK_SOFT, 8)
	var on := UI.box(UI.ACCENT, UI.ACCENT, 8)
	for sb in [off, on]:
		sb.set_content_margin_all(0)
	var focus := UI.button_styles(Color.TRANSPARENT, 8)["focus"] as StyleBoxFlat
	for state in ["normal", "hover", "disabled"]:
		_agree.add_theme_stylebox_override(state, off)
	for state in ["pressed", "hover_pressed"]:
		_agree.add_theme_stylebox_override(state, on)
	_agree.add_theme_stylebox_override("focus", focus)
	_agree.add_theme_color_override("icon_pressed_color", UI.ON_ACCENT)
	_agree.add_theme_color_override("icon_hover_pressed_color", UI.ON_ACCENT)
	_agree.add_theme_color_override("icon_focus_color", UI.ON_ACCENT)
	_agree.toggled.connect(func(_on): _refresh())
	row.add_child(_agree)

	var words := HFlowContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("h_separation", 4)
	words.add_theme_constant_override("v_separation", 0)
	var lead := UI.label(Text.t("create.agree"), 15, UI.INK, false, 700)
	lead.mouse_filter = Control.MOUSE_FILTER_STOP
	lead.set_meta("no_grow", true)
	Press.attach(lead).tapped.connect(func(): _agree.button_pressed = not _agree.button_pressed)
	# Tab stops on the box itself, not on its words too.
	lead.focus_mode = Control.FOCUS_NONE
	words.add_child(lead)
	words.add_child(UI.text_link(Text.t("legal.privacy"), Legal.open.bind(Legal.PRIVACY)))
	var join := UI.label(Text.t("create.agree_and"), 15, UI.INK, false, 700)
	words.add_child(join)
	words.add_child(UI.text_link(Text.t("legal.terms"), Legal.open.bind(Legal.TERMS)))
	row.add_child(words)
	return row


func _ready_to_create() -> bool:
	return _name.text.strip_edges() != "" and _school.text.strip_edges() != "" and _birth() != "" and _agree.button_pressed


func _refresh() -> void:
	_create.disabled = not _ready_to_create()
	_agree.icon = Icons.texture("check", 18, Color.WHITE, 3.2) if _agree.button_pressed else null
	# Only once every box is full, so it doesn't nag while you type.
	_dob_wrong.visible = _dob.all(func(e): return e.text.length() == e.max_length) and _birth() == ""


## Shows "I have an account" only when there's one to log into.
func refresh_accounts() -> void:
	_have.visible = App.has_accounts()


func _submit() -> void:
	if not _ready_to_create():
		return
	var birth := _birth()
	if Legal.age(birth, Time.get_date_dict_from_system()) < Legal.ADULT:
		_ask_parent().closed.connect(func(_r): _finish(birth))
	else:
		_finish(birth)


func _finish(birth: String) -> void:
	App.create_account(_name.text, _school.text, birth)
	App.go("focus")


## The under 18 popup: what a parent or guardian is agreeing to, and
## Approve, the only way out of it.
func _ask_parent() -> Modal:
	var m := Modal.open(420, false)
	m.body.add_child(m.heading(Text.t("create.parent_title")))
	m.body.add_child(UI.para(Text.t("create.parent_body"), 16))
	var points := UI.vbox(8)
	for line in Text.list("create.parent_points"):
		var row := UI.hbox(10)
		var tick := UI.icon_rect("check", 18, UI.ACCENT)
		tick.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(tick)
		row.add_child(UI.para(Text.fill(line, {"name": _name.text.strip_edges()}), 15, UI.INK))
		points.add_child(row)
	m.body.add_child(points)
	var policy := UI.text_link(Text.t("legal.privacy"), Legal.open.bind(Legal.PRIVACY))
	m.body.add_child(policy)
	var approve := UI.button(Text.t("create.parent_approve"), m.close.bind(true), "accent")
	m.body.add_child(approve)
	# Enter approves; the ring only shows once Tab is pressed.
	approve.grab_focus.call_deferred(true)
	return m


func _open_accounts() -> void:
	AccountSwitcher.open().closed.connect(func(_r):
		if is_instance_valid(self):
			refresh_accounts())
