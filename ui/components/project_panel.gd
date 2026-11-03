class_name ProjectPanel
extends PanelContainer
## A wide panel about one project. Along the top: a badge saying whether it's
## ongoing (hourglass) or completed (tick), its name and its total focus
## time, then when it ran in muted text in the top right (left of a
## completed one's grade). The gifts it brought sit under the name, rarest
## first. Then two podiums (Podium): the pets that walked for it most and
## the places it was walked most, side by side (one above the other on a
## narrow panel). Used on the projects screen and in the stats popups, so
## they always match.
## With `gradeable`, a completed project's grade is a button: a circled "?"
## until it has a grade, then its grade badge; either asks for a grade
## (`grade_pressed`). Nothing else on the panel can be tapped. `flat` drops
## its own box, for a panel that is the whole of a popup; `on_close` puts a
## close button in its top right corner, after the grade.

signal grade_pressed(project_id: String)

## Narrower than this, the two podiums stack.
const PODIUMS_SIDE_BY_SIDE := 480.0
## Narrower than this, the dates leave the name's line for one of their own
## under it (still on the right), so the name keeps its room.
const DATES_BESIDE_NAME := 480.0

var project_id := ""


func _init(p: ProjectData, extra: String = "", gradeable: bool = false, flat: bool = false, on_close: Callable = Callable()) -> void:
	project_id = p.id
	var sb := UI.box(Color.TRANSPARENT if flat else UI.SURFACE, Color.TRANSPARENT, 24)
	if not flat:
		UI.with_shadow(sb, 0.8)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := UI.vbox(8)
	add_child(col)

	# The name's line and the gifts under it on the left; the grade (and a
	# close button) to their right, beside both, so it doesn't push the
	# gifts down.
	var top := UI.hbox(10)
	var left := UI.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left)
	var name_line := UI.hbox(10)
	name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(name_line)
	name_line.add_child(_status_badge(p.is_complete()))
	var title := UI.trimmed(p.name, 21, UI.INK, true, 600)
	title.size_flags_horizontal = Control.SIZE_FILL
	title.size_flags_stretch_ratio = 0.0
	# The name takes what it needs (up to the room there is) and the time
	# follows straight after it.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	var bar := UI.label("|", 18, UI.LINE, false, 600)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(bar)
	var time := UI.label(Stats.format_duration(App.state.project_seconds(p.id)), 17, UI.ACCENT, true, 600)
	time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(time)
	head.resized.connect(func():
		var room := head.size.x - bar.get_combined_minimum_size().x - time.get_combined_minimum_size().x - 16.0
		var want := title.get_theme_font("font").get_string_size(p.name, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x + 2.0
		title.custom_minimum_size.x = clampf(want, 0.0, maxf(room, 0.0)))
	name_line.add_child(head)
	var bias := App.tz_bias()
	var when := Text.t("project.dates", {"from": Stats.format_date(p.created_unix, bias),
		"to": Stats.format_date(p.completed_unix, bias) if p.is_complete() else Text.t("project.now")})
	if extra != "":
		when = Text.t("project.extra_and_dates", {"extra": extra, "dates": when})
	var dates := UI.label(when, 12, UI.INK_FAINT, false, 700)
	dates.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dates.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_line.add_child(dates)
	left.resized.connect(func():
		var beside := left.size.x >= DATES_BESIDE_NAME
		if beside == (dates.get_parent() == name_line):
			return
		dates.get_parent().remove_child(dates)
		if beside:
			name_line.add_child(dates)
		else:
			left.add_child(dates)
			left.move_child(dates, 1), CONNECT_DEFERRED)
	var graded := p.is_complete() and p.grade != "" and not Content.grade(p.grade).is_empty()
	var grade_button: _GradeButton = null
	if gradeable and p.is_complete():
		grade_button = _GradeButton.new(p.grade if graded else "")
		grade_button.pressed.connect(func(): grade_pressed.emit(project_id))
		top.add_child(grade_button)
	elif graded:
		var badge := UI.grade_badge(p.grade, 42)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(badge)
	var close_button: Button = null
	if on_close.is_valid():
		close_button = UI.ghost_button("close", Text.t("common.close"), on_close)
		close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(close_button)
	col.add_child(top)

	var gifts := App.state.project_gifts(p.id)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 6)
	var ids := gifts.keys()
	ids.sort_custom(func(a, b):
		var ra := GiftRoller.RARITIES.find(Content.gift(a).get("rarity", ""))
		var rb := GiftRoller.RARITIES.find(Content.gift(b).get("rarity", ""))
		return ra > rb if ra != rb else str(a) < str(b))
	for id in ids:
		flow.add_child(_gift_chip(id, gifts[id]))
	if ids.is_empty():
		flow.add_child(UI.label(Text.t("project.no_gifts"), 13, UI.INK_FAINT, false, 700))
	left.add_child(flow)

	col.add_child(UI.divider())
	var pair := BoxContainer.new()
	pair.add_theme_constant_override("separation", 16)
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_child(Podium.new(Text.t("project.pets"), Podium.pet_rows(p.pets), Text.t("project.no_walks")))
	var rule := _Rule.new()
	pair.add_child(rule)
	pair.add_child(Podium.new(Text.t("project.places"), Podium.place_rows(p.places), Text.t("project.no_walks")))
	pair.resized.connect(func():
		var stack := pair.size.x < PODIUMS_SIDE_BY_SIDE
		if pair.vertical != stack:
			pair.vertical = stack
			rule.queue_redraw())
	col.add_child(pair)
	UI.ignore_mouse(self)
	for b in [grade_button, close_button]:
		if b:
			b.mouse_filter = Control.MOUSE_FILTER_STOP


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


static func _gift_chip(gift_id: String, count: int) -> Control:
	var h := UI.hbox(3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := GiftArt.new(gift_id)
	art.custom_minimum_size = Vector2(26, 26)
	h.add_child(art)
	var n := UI.label(Text.t("gift.count", {"n": count}), 13, Content.rarity_text_colour(Content.gift(gift_id).get("rarity", "common")), false, 800)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	return h


## The grade corner: a "?" in a circle, or the grade's badge. It shades a
## little under the pointer.
class _GradeButton extends Button:
	const SIZE := 42.0
	var _shade := 0.0
	var _cover: Control

	func _init(grade_ref: String) -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
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
