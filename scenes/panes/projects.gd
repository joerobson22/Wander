extends Pane
## Projects, to the right of the focus screen. The menu in the top right
## shows ongoing projects, completed ones or all of them, and everything
## follows it: four headline numbers up top (how many there are, or for all
## of them how many are done; the focus time they took; the biggest by focus
## time; the longest from start to finish, or to today), then each project
## in a list of its own that scrolls, in the order picked from "Sort by".
## Swipe a project from right to left to complete it (confetti), or a
## completed one to put it back to ongoing; from left to right to delete it
## (with a few seconds to undo). Tap the circled "?" in a completed
## project's top right to give it a grade (GCSE, A-Level or university); its
## badge then shows there instead, and tapping that changes it.

static func sorts() -> Array:
	return [
		["gifts", Text.t("sort.most_gifts")], ["biggest", Text.t("sort.biggest")], ["longest", Text.t("sort.longest")],
		["grade", Text.t("sort.grade")], ["pet", Text.t("sort.top_pet")], ["name", Text.t("sort.a_to_z")],
	]


static func filters() -> Array:
	return [
		["ongoing", Text.t("projects.ongoing")], ["completed", Text.t("projects.completed")], ["all", Text.t("projects.all")],
	]
const SORT_KEY := "completed_sort"
const FILTER_KEY := "projects_filter"
## The least height the list gets: about one project panel.
const LIST_MIN := 170.0

## Which grading scale the picker opens on; remembered while the app runs.
var _scale := ""
var _list: VBoxContainer
## A project mid-swipe-action: the screen waits for it before rebuilding.
var _busy := false


func build() -> void:
	var col := frame(720)
	var head := title_row(Text.t("projects.title"))
	var filter := Dropdown.new(filters(), _filter(), false, "", false)
	filter.accessibility_name = Text.t("projects.show")
	filter.chosen.connect(func(option, _r):
		App.set_setting(FILTER_KEY, option))
	head.add_child(filter)
	col.add_child(head)
	var listed := shown_projects()
	if listed.is_empty():
		var empty := UI.card(UI.SURFACE, 24)
		var v := UI.vbox(6)
		v.add_child(UI.label(Text.t({"ongoing": "projects.empty_title_ongoing", "completed": "projects.empty_title_completed", "all": "projects.empty_title_all"}[_filter()]), 20, UI.INK, true, 600))
		v.add_child(UI.para(Text.t({"ongoing": "projects.empty_body_ongoing", "completed": "projects.empty_body_completed", "all": "projects.empty_body_all"}[_filter()])))
		empty.add_child(v)
		col.add_child(empty)
		return
	var stats := _stats(listed, col.custom_minimum_size.x)
	col.add_child(stats)

	var list_head := UI.hbox(8)
	var cap := UI.caption(Text.t({"ongoing": "projects.hint_ongoing", "completed": "projects.hint_completed", "all": "projects.hint_all"}[_filter()]))
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.clip_text = true
	list_head.add_child(cap)
	var sort := Dropdown.for_setting(sorts(), SORT_KEY, sorts()[0][0], true)
	sort.chosen.connect(func(_by, _reversed):
		_fill_list()
		scroll.scroll_vertical = 0)
	list_head.add_child(sort)
	col.add_child(list_head)

	_list = UI.vbox(14)
	var inner := UI.vbox(14)
	inner.add_child(_list)
	var holder := UI.shadow_scroll(inner)
	# Pane keeps this list's place when the screen rebuilds (e.g. on grading).
	scroll = holder.get_child(0)
	col.add_child(holder)
	_fill_list()
	_make_room(holder, stats, list_head, inner)


func _filter() -> String:
	var f := str(App.state.settings.get(FILTER_KEY, "ongoing"))
	return f if f in ["ongoing", "completed", "all"] else "ongoing"


## The projects the menu in the top right asks for.
func shown_projects() -> Array[ProjectData]:
	match _filter():
		"completed":
			return App.state.completed_projects()
		"all":
			return App.state.projects.duplicate()
		_:
			return App.state.active_projects()


## A rebuild mid-swipe would cut its animation short: it waits for the end.
func _on_state_changed() -> void:
	if _busy:
		mark_dirty()
		return
	super()


## On a screen too short for the stats and a whole project under them, the
## stats and the list's heading (the swipe hint and Sort by) go to the top
## of the list, in that order, and scroll away with it, so there's always
## room for the list itself.
func _make_room(holder: Control, stats: Control, list_head: Control, inner: VBoxContainer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(holder) or holder.size.y >= LIST_MIN:
		return
	for c in [stats, list_head]:
		c.get_parent().remove_child(c)
		inner.add_child(c)
	inner.move_child(stats, 0)
	inner.move_child(list_head, 1)


## The four headline numbers for the projects shown. Side by side on a wide
## screen, two by two on a phone so the times have room.
func _stats(listed: Array[ProjectData], width: float) -> Control:
	var panel := StatPanel.new(4 if width >= 520.0 else 2)
	var total := 0
	var graded := 0
	var done := 0
	var biggest: ProjectData = null
	var biggest_s := -1
	var longest: ProjectData = null
	var longest_s := -1
	for p in listed:
		var s := App.state.project_seconds(p.id)
		total += s
		if p.is_complete():
			done += 1
			if p.grade != "":
				graded += 1
		if s > biggest_s:
			biggest = p
			biggest_s = s
		if span(p) > longest_s:
			longest = p
			longest_s = span(p)
	match _filter():
		"all":
			# A badge and a big number like the other cells, so the names line up.
			panel.add(StatPanel.badge("check", UI.SUCCESS), Text.t("projects.complete"),
				Text.t("projects.x_of_y", {"x": done, "y": listed.size()}),
				"%d%%" % floori(100.0 * done / maxi(listed.size(), 1)))
		"completed":
			panel.add(StatPanel.badge("check", UI.SUCCESS), Text.t("projects.completed"),
				Text.t("projects.graded", {"n": graded}), str(listed.size()))
		_:
			panel.add(StatPanel.badge("hourglass", UI.SERIES[1]), Text.t("projects.ongoing"),
				"", str(listed.size()))
	panel.add(StatPanel.badge("clock", Content.rarity_colour("rare")), Text.t("projects.focus_time"),
		Text.t("projects.focus_time_note"), Stats.format_duration(total))
	panel.add(StatPanel.badge("trophy", Content.rarity_colour("epic")), Text.t("projects.biggest"),
		biggest.name, Stats.format_duration(biggest_s))
	panel.add(StatPanel.badge("calendar", Content.rarity_colour("legendary")), Text.t("projects.longest"),
		longest.name, span_text(longest_s))
	return panel


## Seconds from a project's start to its finish, or to now while it's going.
static func span(p: ProjectData) -> int:
	return maxi(0, (p.completed_unix if p.is_complete() else App.now()) - p.created_unix)


## "12 days" from a day on; under that, hours and minutes.
static func span_text(seconds: int) -> String:
	if seconds < 86400:
		return Stats.format_duration(seconds)
	var days := roundi(seconds / 86400.0)
	return Text.count("projects.days", days)


## Refills the list in the saved order, without rebuilding the rest.
func _fill_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var by := str(App.state.settings.get(SORT_KEY, sorts()[0][0]))
	var reversed := bool(App.state.settings.get(SORT_KEY + "_reversed", false))
	for p in sort_projects(shown_projects(), by, reversed):
		var panel := ProjectPanel.new(p, "", true)
		panel.grade_pressed.connect(_pick_grade)
		var row := ProjectSwipes.row(panel, p)
		row.swiped.connect(_on_swiped.bind(row, p.id))
		_list.add_child(row)


func _on_swiped(direction: int, row: SwipeRow, id: String) -> void:
	var p := App.state.project(id)
	if p == null or _busy:
		row.spring_back()
		return
	_busy = true
	await ProjectSwipes.act(direction, row, id, _filter() != "completed", _filter() != "ongoing")
	_busy = false
	if shown:
		rebuild()


## Most gifts, biggest (focus time) and longest (start to finish) put the
## most first; grade puts the best first (Content.grade_rank) with ungraded
## last; top pet goes by the name of the pet that walked most for it, with
## those not walked yet last; A–Z is by name. Ties go newest first.
## `reversed` flips the whole order.
static func sort_projects(projects: Array, by: String, reversed: bool) -> Array:
	var key := func(p: ProjectData) -> Array:
		var first: Array
		match by:
			"gifts":
				var n := 0
				for count in App.state.project_gifts(p.id).values():
					n += int(count)
				first = [-n]
			"biggest":
				first = [-App.state.project_seconds(p.id)]
			"longest":
				first = [-span(p)]
			"grade":
				first = Content.grade_rank(p.grade if p.is_complete() else "")
			"pet":
				var top := Stats.ranked(p.pets)
				var pet := App.state.pet(top[0][0]) if not top.is_empty() else null
				first = [0, pet.name.to_lower()] if pet else [1, ""]
			_:
				first = [p.name.to_lower()]
		return first + [-maxi(p.completed_unix, p.created_unix), p.name.to_lower()]
	var keys := {}
	for p in projects:
		keys[p] = key.call(p)
	var out := projects.duplicate()
	out.sort_custom(func(a, b): return keys[a] < keys[b])
	if reversed:
		out.reverse()
	return out


func _pick_grade(project_id: String) -> void:
	var p := App.state.project(project_id)
	if p == null:
		return
	var current := Content.grade(p.grade)
	if _scale == "":
		_scale = current.get("scale", Content.grade_scales[0]["id"])
	var m := Modal.open(440)
	m.body.add_child(m.heading_row(Text.t("projects.grade_title", {"project": p.name})))
	var tabs := UI.hbox(6)
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var fill := func(scale_id: String):
		_scale = scale_id
		for c in tabs.get_children() + grid.get_children():
			c.get_parent().remove_child(c)
			c.queue_free()
		for s in Content.grade_scales:
			var tab := UI.pill_button(s["name"], s["id"] == scale_id, Callable())
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.set_meta("scale", s["id"])
			tabs.add_child(tab)
		for s in Content.grade_scales:
			if s["id"] != scale_id:
				continue
			for g in s["grades"]:
				grid.add_child(_grade_choice("%s/%s" % [s["id"], g["id"]], p, m))
	m.body.add_child(tabs)
	m.body.add_child(grid)
	# The tabs are remade on each switch, so they're wired up as they arrive.
	tabs.child_entered_tree.connect(func(tab: Node):
		if tab is Button:
			tab.pressed.connect(func(): fill.call(tab.get_meta("scale"))))
	fill.call(_scale)
	if p.grade != "":
		m.body.add_child(UI.button(Text.t("projects.remove_grade"), func():
			App.set_grade(p.id, "")
			m.close(), "quiet"))


func _grade_choice(ref: String, p: ProjectData, m: Modal) -> Control:
	var g := Content.grade(ref)
	var b := Button.new()
	b.custom_minimum_size = Vector2(66, 72)
	b.accessibility_name = g.get("name", "")
	var on := p.grade == ref
	UI.style_button(b, UI.ACCENT_SOFT if on else UI.SURFACE_SOFT, UI.INK, 18)
	if on:
		for state in ["normal", "hover"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(state)
			sb.set_border_width_all(2)
			sb.border_color = UI.ACCENT
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(UI.grade_badge(ref, 46))
	UI.ignore_mouse(centre)
	b.add_child(centre)
	b.pressed.connect(func():
		App.set_grade(p.id, ref)
		m.close()
		Toast.show_text(Text.t("projects.graded_toast", {"project": p.name, "grade": g.get("label", "")}), "star"))
	return b
