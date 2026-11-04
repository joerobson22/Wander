extends Pane
## Stats, below the focus screen. A chart of your focus for this week, month
## or year (the tabs at the top of the chart: a bar per day, or per month
## for a year), each bar split by project, pet or place (the menu beside the
## tabs); tap a piece, or a name in the sideways strip under the chart, for
## its details. Arrows either side of the period's name and its total step
## back to earlier periods and forward again. Your streak is in the top
## right: tap it for your best ever. The friends leaderboard is underneath,
## sharing the room evenly with the chart, with a button to add friends. It
## all fits the screen; only the strip and the leaderboard scroll.

## Names in the strip under the chart are cut to this many letters.
const CHIP_LETTERS := 10
const PERIODS := ["week", "month", "year"]
## The gold of the streak record's trophy (first place on a podium).
const RECORD_GOLD := Color("#e2b33c")


static func splits() -> Array:
	return [["projects", Text.t("stats.by_projects")], ["pets", Text.t("stats.by_pets")], ["places", Text.t("stats.by_places")]]


## The period being charted (its first day as a day number); kept while the
## app runs. Which kind of period and how the bars split are settings.
var _start := -1
var _chart: _Chart
var _chart_title: Label
var _chart_total: Label
var _tabs: Dictionary = {}  # period -> its tab
var _legend: HBoxContainer
var _earlier: Button
var _later: Button
## Showing your best streak instead of the one now (tap the streak).
var _record := false


func _period() -> String:
	var p := str(App.state.settings.get("stats_period", "week"))
	return p if p in PERIODS else "week"


func _split() -> String:
	var s := str(App.state.settings.get("stats_split", "projects"))
	return s if s in ["projects", "pets", "places"] else "projects"


func build() -> void:
	var today := App.today()
	var current := Stats.period_start(today, _period())
	if _start < 0 or _start > current or Stats.period_start(_start, _period()) != _start:
		_start = current
	var col := frame(760, 14)

	var head := title_row(Text.t("stats.title"))
	head.add_child(_streak())
	col.add_child(head)

	var chart_card := UI.card(UI.SURFACE, 16)
	chart_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var c := UI.vbox(6)
	chart_card.add_child(c)
	# Week · Month · Year on the left, how the bars split on the right...
	var tab_row := UI.hbox(8)
	var tabs := UI.hbox(2)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.clear()
	for i in PERIODS.size():
		if i > 0:
			var dot := UI.label("·", 15, UI.INK_FAINT, false, 800)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tabs.add_child(dot)
		var tab := _tab(PERIODS[i])
		tabs.add_child(tab)
		_tabs[PERIODS[i]] = tab
	tab_row.add_child(tabs)
	var split := Dropdown.new(splits(), _split(), false, "", false)
	split.accessibility_name = Text.t("stats.split_by")
	split.chosen.connect(func(option, _r):
		App.state.settings["stats_split"] = option
		App.save()
		_select(_start))
	tab_row.add_child(split)
	c.add_child(tab_row)
	# ...then the period's name and its total, between arrows to step back
	# to earlier periods and on again.
	var chart_head := UI.hbox(4)
	_earlier = UI.ghost_button("back", Text.t("stats.earlier"), _step.bind(-1), UI.INK, 32, 18)
	chart_head.add_child(_earlier)
	_chart_title = UI.trimmed("", 20, UI.INK, true, 600)
	chart_head.add_child(_chart_title)
	_chart_total = UI.label("", 20, UI.ACCENT, true, 600)
	chart_head.add_child(_chart_total)
	_later = UI.ghost_button("forward", Text.t("stats.later"), _step.bind(1), UI.INK, 32, 18)
	chart_head.add_child(_later)
	c.add_child(chart_head)
	_chart = _Chart.new()
	_chart.custom_minimum_size.y = 100
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.segment_tapped.connect(_show_piece)
	c.add_child(_chart)
	var strip := UI.scroll_area(true)
	strip.custom_minimum_size.y = 34
	var strip_room := MarginContainer.new()
	_legend = UI.hbox(8)
	strip_room.add_child(_legend)
	strip.add_child(strip_room)
	UI.clear_of_bar(strip, strip_room, 4)
	c.add_child(strip)

	# The chart and the leaderboard share the room evenly.
	chart_card.size_flags_stretch_ratio = 1.0
	col.add_child(chart_card)
	var mine := Stats.week_total(App.state.days, Stats.week_start(today))
	var board := Leaderboard.new(Friends.ranked(App.friends, mine, App.state.active != null), true)
	# At least a row and yours: a friend above you, then your pinned row.
	board.custom_minimum_size.y = 128
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_stretch_ratio = 1.0
	col.add_child(board)
	_select(_start, false)


## Your streak: the flame with how many days. Tap it and it fades over (a
## tenth of a second out, a tenth in) to your best ever, by a golden trophy
## holding a flame; tap again for the streak now.
func _streak() -> Control:
	var days := Stats.current_streak(App.state.days, App.today())
	var best := Stats.best_streak(App.state.days)
	var holder := UI.hbox(8)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.mouse_default_cursor_shape = Cursor.HOVER
	holder.set_meta("no_grow", true)
	var icon := UI.icon_rect("flame", 32, UI.FLAME if days > 0 else UI.INK_FAINT)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(icon)
	var words := UI.label("", 22, UI.INK, true, 600)
	holder.add_child(words)
	var face := func(record: bool):
		icon.texture = Icons.texture("trophy_flame", 32, RECORD_GOLD) if record \
			else Icons.texture("flame", 32, UI.FLAME if days > 0 else UI.INK_FAINT)
		words.text = Text.count("stats.best", best) if record else Text.count("stats.days", days)
		holder.accessibility_name = Text.count("stats.best_streak" if record else "stats.streak", best if record else days)
	face.call(_record)
	Press.attach(holder).tapped.connect(func():
		_record = not _record
		var t := Motion.tween(holder, "swap")
		t.tween_property(holder, "modulate:a", 0.0, Motion.time(0.1))
		t.tween_callback(face.bind(_record))
		t.tween_property(holder, "modulate:a", 1.0, Motion.time(0.1)))
	return holder


## A tab for a period: bold in ink while it's the one charted, muted
## otherwise.
func _tab(period: String) -> Button:
	var b := Button.new()
	b.text = Text.t({"week": "stats.tab_week", "month": "stats.tab_month", "year": "stats.tab_year"}[period])
	b.flat = true
	var on := period == _period()
	UI.style_button(b, Color.TRANSPARENT, UI.INK if on else UI.INK_FAINT, 12)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		if state == "hover" and not on:
			sb.bg_color = Color(UI.INK, 0.05)
	b.add_theme_font_override("font", UI.font(true, 600 if on else 500))
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size.y = 34
	b.accessibility_name = b.text
	b.pressed.connect(func():
		if period != _period():
			App.state.settings["stats_period"] = period
			App.save()
			_start = -1
			rebuild())
	return b


## "This week", "Last month", "13 Oct – 19 Oct", "September 2026", "2025".
func _period_name(start: int, short: bool) -> String:
	var period := _period()
	var current := Stats.period_start(App.today(), period)
	var d := Stats.day_date(start)
	match period:
		"month":
			if start == current:
				return Text.t("stats.this_month")
			if start == Stats.period_before(current, period):
				return Text.t("stats.last_month")
			return Text.t("stats.month_name", {"month": Text.list("dates.months_long")[int(d["month"]) - 1], "year": d["year"]})
		"year":
			if start == current:
				return Text.t("stats.this_year")
			if start == Stats.period_before(current, period):
				return Text.t("stats.last_year")
			return str(d["year"])
		_:
			if start == current:
				return Text.t("stats.this_week")
			if start == current - 7 and short:
				return Text.t("stats.last_week")
			if short:
				return Text.t("stats.week_span", {"from": Stats.format_day(start), "to": Stats.format_day(start + 6)})
			return Text.t("stats.week_of", {"day": Stats.format_day(start)})


## The first period there's anything to look back on: the earliest with
## focus, or the one you started in.
func _first_start() -> int:
	var history := Stats.period_history(App.state.days, App.today(), _period(), Stats.local_day(int(App.state.profile.get("created_unix", 0)), App.tz_bias()))
	return history.back() if not history.is_empty() else Stats.period_start(App.today(), _period())


## One period back (-1) or on (+1), no further than the first or this one.
func _step(way: int) -> void:
	var period := _period()
	var to := Stats.period_before(_start, period) if way < 0 else Stats.period_next(_start, period)
	if to < _first_start() or to > Stats.period_start(App.today(), period):
		return
	_select(to)


func _select(start: int, animate: bool = true) -> void:
	_start = start
	var period := _period()
	_earlier.disabled = start <= _first_start()
	_later.disabled = start >= Stats.period_start(App.today(), period)
	var split := _split()
	var today := App.today()
	_chart_title.text = _period_name(start, false)
	_chart_total.text = Stats.format_duration(Stats.period_total(App.state.days, start, period))
	var buckets := Stats.period_buckets(App.state.days, start, period, split)
	var now_index := -1
	if start == Stats.period_start(today, period):
		now_index = int(Stats.day_date(today)["month"]) - 1 if period == "year" else today - start
	_chart.split = split
	_chart.set_bars(buckets, _labels(buckets.size()), now_index, animate)
	# The chart's words for a screen reader; the chips under it say who.
	_chart.accessibility_name = Text.t("alt.chart", {"period": _chart_title.text, "time": _chart_total.text})

	for child in _legend.get_children():
		child.queue_free()
	var totals := Stats.period_totals(App.state.days, start, period, split)
	var rows := Stats.ranked(totals)
	if rows.is_empty():
		_legend.add_child(UI.label(Text.t({"week": "stats.no_focus_week", "month": "stats.no_focus_month", "year": "stats.no_focus_year"}[period]), 14, UI.INK_FAINT, false, 700))
	for row in rows:
		_legend.add_child(_legend_chip(row[0], row[1]))


## The words under the bars: day names for a week, every seventh date for a
## month (1, 8, 15...), month names for a year.
func _labels(count: int) -> Array:
	var out := []
	for i in count:
		match _period():
			"month":
				out.append(str(i + 1) if i % 7 == 0 else "")
			"year":
				out.append(Text.list("dates.months")[i])
			_:
				out.append(Text.list("dates.days_short")[i])
	return out


## A project's, pet's or place's name as the chart calls it ("" if gone).
func _name_of(id: String) -> String:
	match _split():
		"pets":
			var pet := App.state.pet(id)
			return pet.name if pet else ""
		"places":
			return str(Content.biome(id).get("name", "")) if Content.biome(id).get("id", "") == id else ""
		_:
			var p := App.state.project(id)
			return p.name if p else ""


func _legend_chip(id: String, seconds: int) -> Control:
	var title := _name_of(id)
	var gone := title == ""
	if gone:
		title = Text.t("stats.deleted_project")
	if title.length() > CHIP_LETTERS:
		title = title.left(CHIP_LETTERS).strip_edges() + "..."
	var b := UI.button(Text.t("stats.chip", {"project": title, "time": Stats.format_duration(seconds)}), _show_piece.bind(id, -1), "quiet")
	b.custom_minimum_size.y = 34
	b.add_theme_font_size_override("font_size", 13)
	b.icon = Icons.texture("dot", 12, UI.series_colour(id, _split()))
	b.add_theme_constant_override("h_separation", 8)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		UI.corners(sb, 999)
		sb.content_margin_left = 12
		sb.content_margin_right = 14
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	b.disabled = gone
	return b


## The note for a popup: the time in the period, or with `bar` (an index
## into the chart) that bar's day or month.
func _extra(id: String, bar: int) -> String:
	var period := _period()
	var split := _split()
	var total := int(Stats.period_totals(App.state.days, _start, period, split).get(id, 0))
	var extra := Text.t({"week": "stats.time_this_week", "month": "stats.time_this_month", "year": "stats.time_this_year"}[period], {"time": Stats.format_duration(total)})
	if _start != Stats.period_start(App.today(), period):
		extra = Text.t("stats.time_in", {"time": Stats.format_duration(total), "period": _period_name(_start, false)})
	if bar >= 0:
		var buckets := Stats.period_buckets(App.state.days, _start, period, split)
		var t := Stats.format_duration(int(buckets[bar].get(id, 0)))
		match period:
			"year":
				extra = Text.t("stats.time_in", {"time": t, "period": Text.list("dates.months_long")[bar]})
			"month":
				extra = Text.t("stats.time_on_day", {"time": t, "day": Stats.format_day(_start + bar)})
			_:
				extra = Text.t("stats.time_on_day", {"time": t, "day": Text.list("dates.days_long")[bar]})
	return extra


## A project's panel, or a pet's or place's card, in a popup.
func _show_piece(id: String, bar: int) -> void:
	match _split():
		"pets":
			var pet := App.state.pet(id)
			if pet:
				PetCard.open(pet, _extra(id, bar))
		"places":
			if Content.biome(id).get("id", "") == id:
				PetCard.open_place(id, _extra(id, bar))
		_:
			var p := App.state.project(id)
			if p == null:
				return
			# The popup is the project's panel itself, with a close button in its corner.
			var m := Modal.open(560, true, 0)
			var panel := ProjectPanel.new(p, _extra(id, bar), false, true, m.close.bind(null))
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.body.add_child(panel)


## The period's bars: one per day (or month), stacked by project, pet or
## place, tappable piece by piece, with a label under some of them.
class _Chart extends Control:
	signal segment_tapped(id: String, bar: int)

	var bars: Array[Dictionary] = []
	var labels: Array = []
	var now_index := -1
	var split := "projects"
	var _grow := 1.0
	var _pieces: Array = []  # [Rect2, id, bar]
	var _press := Press.new(self)
	var _tap_at := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		_press.tapped.connect(func():
			var hit := _piece_at(_tap_at)
			if not hit.is_empty():
				segment_tapped.emit(hit[1], hit[2]))

	func set_bars(b: Array[Dictionary], words: Array, now: int, animate: bool) -> void:
		bars = b
		labels = words
		now_index = now
		if animate:
			Motion.method(self, "grow", _set_grow, 0.0, 1.0, Motion.SLOW)
		else:
			_set_grow(1.0)

	func _set_grow(v: float) -> void:
		_grow = v
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_tap_at = e.position
		_press.handle(e)

	func _piece_at(p: Vector2) -> Array:
		for piece in _pieces:
			if (piece[0] as Rect2).grow_individual(6, 1, 6, 1).has_point(p):
				return piece
		return []

	func _draw() -> void:
		_pieces.clear()
		var font := UI.font(false, 800)
		var area := Rect2(34, 8, size.x - 34, size.y - 8 - 28)
		var most := 0
		for d in bars:
			var total := 0
			for s in d.values():
				total += int(s)
			most = maxi(most, total)
		var hours := maxi(1, ceili(most / 3600.0))
		# At most four steps up, and the top line sits at the top of the chart.
		var step := ceili(hours / 4.0)
		hours = ceili(hours / float(step)) * step
		var h := 0
		while h <= hours:
			var y := area.end.y - area.size.y * h / float(hours)
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), UI.LINE, 1.0)
			draw_string(font, Vector2(0, y + 4), "%dh" % h if h > 0 else "0", HORIZONTAL_ALIGNMENT_LEFT, 30, 12, UI.INK_FAINT)
			h += step
		if bars.is_empty():
			return
		var n := bars.size()
		var col := area.size.x / n
		var bar := minf(col * (0.58 if n <= 12 else 0.7), 38.0)
		# Thin bars get a smaller gap between their pieces and squarer corners.
		var gap := 2.0 if bar >= 8.0 else 1.0
		# In a month, today's column has a soft band behind it.
		if n > 12 and now_index >= 0:
			draw_style_box(UI.box(Color(UI.ACCENT, 0.1), Color.TRANSPARENT, 4), Rect2(area.position.x + col * now_index, area.position.y, col, area.size.y))
		for i in n:
			var x := area.position.x + col * (i + 0.5) - bar * 0.5
			# Each piece leaves a gap above it, so the stack still ends at its total.
			var y := area.end.y + gap
			var ids := bars[i].keys()
			ids.sort_custom(func(a, b): return UI.SERIES.find(UI.series_colour(a, split)) < UI.SERIES.find(UI.series_colour(b, split)) if UI.series_colour(a, split) != UI.series_colour(b, split) else str(a) < str(b))
			for id in ids:
				var seg := area.size.y * float(bars[i][id]) / (hours * 3600.0) * _grow
				if seg < 0.5:
					continue
				var r := Rect2(x, y - seg, bar, maxf(seg - gap, 1.0))
				var sb := UI.box(UI.series_colour(id, split), Color.TRANSPARENT, 2 if bar >= 8.0 else 1)
				draw_style_box(sb, r)
				_pieces.append([r, id, i])
				y -= seg
			if i < labels.size() and str(labels[i]) != "":
				var colour := UI.ACCENT if i == now_index else UI.INK_SOFT
				var word := str(labels[i])
				# Month names shrink to their first letter where three won't fit.
				if n == 12 and col < 26.0:
					word = word.left(1)
				# A week's or year's word fills its own column; a month's
				# dates are centred under their bar with room either side.
				var w := col if n <= 12 else col * 3.0
				var lx := area.position.x + col * i if n <= 12 else area.position.x + col * (i + 0.5) - w * 0.5
				draw_string(font, Vector2(lx, size.y - 6), word, HORIZONTAL_ALIGNMENT_CENTER, w, 12, colour)
