class_name ProjectPanel
extends PanelContainer
## A wide panel about one project. Its header: a badge saying whether it's
## ongoing (hourglass) or completed (tick), its name and its total focus
## time (and a completed one's grade on the right). Under that, its body:
## how many gifts of each rarity it brought, then two podiums (Podium) of
## the pets that walked for it most and the places it was walked most, side
## by side (one above the other on a narrow panel), and when it ran in the
## bottom right ("Started 3 Oct", or "3 Oct – 9 Nov" once it's done). Used
## on the projects screen and in the stats popups, so they always match.
## With `folds`, the body starts folded away so only the header shows: tap
## the panel to open it out downwards, and its header to fold it back.
## With `gradeable`, a completed project's grade is a button: a circled "?"
## until it has a grade, then its grade badge; either asks for a grade
## (`grade_pressed`). `flat` drops its own box, for a panel that is the
## whole of a popup; `on_close` puts a close button in its top right
## corner, after the grade.

signal grade_pressed(project_id: String)
## The body opened out or folded away (`open`), by a tap.
signal toggled(open: bool)

## Narrower than this, the two podiums stack.
const PODIUMS_SIDE_BY_SIDE := 480.0
## How long the body takes to open out or fold away.
const FOLD_TIME := 0.3

var project_id := ""
var _header: Control
var _fold: _Fold
var _folds := false


func _init(p: ProjectData, gradeable: bool = false, flat: bool = false, on_close: Callable = Callable(),
		folds: bool = false, open: bool = true) -> void:
	project_id = p.id
	_folds = folds
	var sb := UI.box(Color.TRANSPARENT if flat else UI.SURFACE, Color.TRANSPARENT, 24)
	if not flat:
		UI.with_shadow(sb, 0.8)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := UI.vbox(0)
	add_child(col)

	# The header: badge, name | time, then the grade (and a close button).
	var top := UI.hbox(10)
	_header = top
	# Every row on the Projects screen is as tall as a grade, so folded
	# ongoing and completed ones line up the same height.
	if gradeable:
		top.custom_minimum_size.y = _GradeButton.SIZE
	top.add_child(_status_badge(p.is_complete()))
	var title := UI.trimmed(p.name, 21, UI.INK, true, 600)
	# The name takes what it needs (up to the room there is) and the time
	# follows straight after it.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var bar := UI.label("|", 18, UI.LINE, false, 600)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bar)
	var time := UI.label(Stats.format_duration(App.state.project_seconds(p.id)), 17, UI.ACCENT, true, 600)
	time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(time)
	head.add_child(UI.spacer())
	UI.fit_name(title, head)
	top.add_child(head)
	var graded := p.is_complete() and p.grade != "" and not Content.grade(p.grade).is_empty()
	var grade_button: _GradeButton = null
	if gradeable and p.is_complete():
		grade_button = _GradeButton.new(p.grade if graded else "")
		grade_button.pressed.connect(func(): grade_pressed.emit(project_id))
		top.add_child(grade_button)
	elif graded:
		var badge := UI.grade_badge(p.grade, 42)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(badge)
	var close_button: Button = null
	if on_close.is_valid():
		close_button = UI.ghost_button("close", Text.t("common.close"), on_close)
		close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(close_button)
	col.add_child(top)

	# The body, which folds away under the header. Its gap from the header
	# is inside it, so a folded panel is just the header.
	var body := UI.vbox(10)
	var room := MarginContainer.new()
	room.add_theme_constant_override("margin_top", 12)
	room.add_child(body)
	_fold = _Fold.new(room, 0.0 if folds and not open else 1.0)
	col.add_child(_fold)
	body.add_child(_rarity_counts(App.state.project_gifts(p.id)))
	body.add_child(UI.divider())
	var stops: Array[Control] = [grade_button, close_button]
	if App.phone_layout():
		var one := _one_podium(p)
		body.add_child(one)
		stops.append(one.get_child(0).get_child(-1))
	else:
		var pair := BoxContainer.new()
		pair.add_theme_constant_override("separation", 16)
		pair.add_child(Podium.new(Text.t("project.pets"), Podium.pet_rows(p.pets), Text.t("project.no_walks")))
		var rule := _Rule.new()
		pair.add_child(rule)
		pair.add_child(Podium.new(Text.t("project.places"), Podium.place_rows(p.places), Text.t("project.no_walks")))
		pair.resized.connect(func():
			var stack := pair.size.x < PODIUMS_SIDE_BY_SIDE
			if pair.vertical != stack:
				pair.vertical = stack
				rule.queue_redraw())
		body.add_child(pair)
	var bias := App.tz_bias()
	var when := Text.t("project.dates", {"from": Stats.format_date(p.created_unix, bias), "to": Stats.format_date(p.completed_unix, bias)}) \
		if p.is_complete() else Text.t("project.started", {"date": Stats.format_date(p.created_unix, bias)})
	var dates := UI.label(when, 12, UI.INK_FAINT, false, 700)
	dates.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(dates)
	UI.ignore_mouse(self)
	for b in stops:
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_STOP
	if folds:
		# A tap anywhere opens it; once open, a tap on the header folds it.
		# It doesn't grow under the pointer: it's swiped too.
		set_meta("no_grow", true)
		Press.attach(self).tapped.connect(func():
			var press: Press = get_meta("press")
			if not is_open():
				set_open(true)
			elif press.at.y <= _header.position.y + _header.size.y + get_theme_stylebox("panel").content_margin_top:
				set_open(false)
			else:
				return
			toggled.emit(is_open()))


## Whether the body is showing (or on its way out).
func is_open() -> bool:
	return _fold.target > 0.5


## Opens the body out downwards (or folds it away), tweened unless `animate`
## is false.
func set_open(open: bool, animate: bool = true) -> void:
	_fold.slide_to(1.0 if open else 0.0, FOLD_TIME if animate else 0.0)


## How many gifts of each rarity it brought, commonest first: the gift
## icon in the rarity's colour and the count beside it, the four spread
## evenly from edge to edge. A rarity it has none of is faded.
static func _rarity_counts(gifts: Dictionary) -> Control:
	var counts := {}
	for id in gifts:
		var r := str(Content.gift(id).get("rarity", "common"))
		counts[r] = int(counts.get(r, 0)) + int(gifts[id])
	var row := UI.hbox(0)
	for i in GiftRoller.RARITIES.size():
		if i > 0:
			row.add_child(UI.spacer())
		var rarity: String = GiftRoller.RARITIES[i]
		var n := int(counts.get(rarity, 0))
		var chip := UI.hbox(4)
		chip.accessibility_name = Text.t("project.rarity_count", {"n": n, "rarity": Content.rarity_name(rarity)})
		var icon := UI.icon_rect("gift", 26, Content.rarity_colour(rarity))
		icon.custom_minimum_size = Vector2(26, 26)
		chip.add_child(icon)
		var count := UI.label(Text.t("gift.count", {"n": n}), 13, Content.rarity_text_colour(rarity), false, 800)
		count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(count)
		if n == 0:
			chip.modulate.a = 0.35
		row.add_child(chip)
	return row


## Phones: one podium at a time, pets or places, picked from a menu in the
## section's top right (remembered for every panel). The menu says which it
## is, so the podium has no title of its own.
func _one_podium(p: ProjectData) -> Control:
	var section := UI.vbox(6)
	section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := UI.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UI.spacer())
	var which := str(App.state.settings.get(PODIUM_KEY, "pets"))
	if which not in ["pets", "places"]:
		which = "pets"
	var menu := Dropdown.new([["pets", Text.t("project.pets")], ["places", Text.t("project.places")]], which, false, "", false)
	menu.accessibility_name = Text.t("project.show")
	head.add_child(menu)
	section.add_child(head)
	var podium := [_podium_for(p, which)]
	section.add_child(podium[0])
	# Every panel showing follows the menu, so they all show the same.
	section.add_to_group(PODIUM_GROUP)
	section.set_meta("swap", func(option: String):
		menu.select(option)
		section.remove_child(podium[0])
		podium[0].queue_free()
		podium[0] = _podium_for(p, option)
		section.add_child(podium[0]))
	menu.chosen.connect(func(option: String, _r: bool):
		App.state.settings[PODIUM_KEY] = option
		App.save()
		for other in section.get_tree().get_nodes_in_group(PODIUM_GROUP):
			other.get_meta("swap").call(option))
	return section


const PODIUM_KEY := "panel_podium"
const PODIUM_GROUP := "project_one_podium"


static func _podium_for(p: ProjectData, which: String) -> Podium:
	var podium: Podium
	if which == "places":
		podium = Podium.new("", Podium.place_rows(p.places), Text.t("project.no_walks"))
	else:
		podium = Podium.new("", Podium.pet_rows(p.pets), Text.t("project.no_walks"))
	UI.ignore_mouse(podium)
	return podium


## A small round badge: an hourglass on amber while a project's going, a
## tick on green once it's done.
static func _status_badge(done: bool) -> Control:
	var badge := UI.panel(UI.SUCCESS if done else UI.SERIES[1], 999, 0)
	badge.custom_minimum_size = Vector2(30, 30)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.accessibility_name = Text.t("project.completed" if done else "project.ongoing")
	badge.add_child(UI.icon_rect("check" if done else "hourglass", 16, UI.ON_COLOUR))
	return badge


## The grade corner: a "?" in a circle, or the grade's badge. It shades a
## little under the pointer.
class _GradeButton extends Button:
	const SIZE := 42.0
	var _shade := 0.0
	var _cover: Control

	func _init(grade_ref: String) -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Cursor.HOVER
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		if grade_ref == "":
			custom_minimum_size = Vector2(SIZE, SIZE)
			accessibility_name = Text.t("project.add_grade")
		else:
			var badge := UI.grade_badge(grade_ref, int(SIZE))
			badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			custom_minimum_size = badge.custom_minimum_size
			add_child(badge)
			accessibility_name = Text.t("project.change_grade", {"grade": badge.accessibility_name})
		_cover = Control.new()
		_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cover.draw.connect(_draw_shade)
		add_child(_cover)
		mouse_entered.connect(_shade_to.bind(1.0))
		mouse_exited.connect(_shade_to.bind(0.0))

	func _shade_to(v: float) -> void:
		Motion.method(self, "shade", _set_shade, _shade, v, Motion.FAST)

	func _set_shade(v: float) -> void:
		_shade = v
		queue_redraw()
		_cover.queue_redraw()

	func _draw() -> void:
		if get_child_count() > 1:
			return  # the badge draws itself
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.5
		draw_circle(c, r, UI.SURFACE_SOFT.lerp(UI.ACCENT_SOFT, _shade), true, -1.0, true)
		draw_arc(c, r, 0, TAU, 40, UI.LINE.lerp(UI.ACCENT, _shade), 2.0, true)
		var font := UI.font(true, 600)
		var fs := int(size.y * 0.5)
		var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK_SOFT.lerp(UI.ACCENT, _shade))

	## Over a badge, the shade is a soft darkening of the whole circle.
	func _draw_shade() -> void:
		if get_child_count() > 1 and _shade > 0.0:
			var r := minf(size.x, size.y) * 0.5
			var disc := UI.box(Color(0, 0, 0, 0.12 * _shade), Color.TRANSPARENT, int(r))
			_cover.draw_style_box(disc, Rect2(Vector2.ZERO, size))


## A short line between the two podiums: upright while they sit side by
## side, flat while they stack.
class _Rule extends Control:
	const SHARE := 0.6

	func _init() -> void:
		custom_minimum_size = Vector2(1, 1)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		if size.y > size.x:
			draw_line(Vector2(c.x, c.y - size.y * SHARE * 0.5), Vector2(c.x, c.y + size.y * SHARE * 0.5), UI.LINE, 1.0)
		else:
			draw_line(Vector2(c.x - size.x * SHARE * 0.5, c.y), Vector2(c.x + size.x * SHARE * 0.5, c.y), UI.LINE, 1.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Holds a panel's body and shows `open` (0..1) of its height, so the body
## slides out downwards from under the header and back. Clips while it's
## part way.
class _Fold extends Container:
	var open := 1.0
	var target := 1.0
	var _body: Control

	func _init(body: Control, start: float) -> void:
		_body = body
		add_child(body)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_open(start)
		target = start

	func slide_to(to: float, seconds: float) -> void:
		target = to
		if seconds <= 0.0:
			Motion.tween(self, "fold").kill()
			_set_open(to)
			return
		Motion.method(self, "fold", _set_open, open, to, seconds)

	func _set_open(v: float) -> void:
		open = v
		clip_contents = v < 0.999
		_body.modulate.a = clampf(v * 1.6, 0.0, 1.0)
		_body.visible = v > 0.001
		update_minimum_size()

	func _get_minimum_size() -> Vector2:
		var m := _body.get_combined_minimum_size()
		return Vector2(m.x, roundf(m.y * open))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			fit_child_in_rect(_body, Rect2(Vector2.ZERO, Vector2(size.x, _body.get_combined_minimum_size().y)))
