class_name Customise
extends RefCounted
## The character editor popup: a preview on the left, and on the right
## three tabs (Head, Body, Legs) over the parts in that section. Each part
## is a carousel you scroll left and right through every option, with what
## the middle one is written under it. Skin and hair colour are five
## swatches and a sixth that picks any colour. The title, the preview and
## the tabs stay put while the parts scroll. The cross top left throws the
## changes away; the green tick top right keeps them.

## How wide each option is in a carousel, and the gap from one to the next.
const OPTION := Vector2(72, 56)
const SPACING := 86.0
const SWATCH := 36


static func open() -> Modal:
	var p := App.state.profile
	var draft := {
		"skin_tone": int(p["skin_tone"]),
		"hair_tone": int(p["hair_tone"]),
		"skin_colour": str(p.get("skin_colour", "")),
		"hair_colour": str(p.get("hair_colour", "")),
		"cosmetics": (p["cosmetics"] as Dictionary).duplicate(),
	}
	var m := Modal.open(680, false, 20)

	# The title and the preview stay put; only the list of parts scrolls.
	var top := UI.hbox(10)
	top.add_child(UI.ghost_button("close", Text.t("common.cancel"), m.close.bind(null), UI.INK, 44, 24))
	var title := UI.label(Text.t("customise.title"), 22, UI.INK, true, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UI.round_button("check", Text.t("common.save"), func():
		App.set_look(draft)
		m.close(true), UI.SUCCESS, Color.WHITE, 44))
	m.header.add_child(top)

	var narrow := m.get_viewport_rect().size.x < 560.0
	var row := UI.hbox(12 if narrow else 20)
	m.body.add_child(row)
	var preview := UI.character_portrait(draft, Vector2(110 if narrow else 200, 0))
	# As tall as the parts beside it, so their bottoms line up.
	preview.size_flags_vertical = Control.SIZE_FILL
	row.add_child(preview)
	var view: CharacterView = preview.get_child(0)
	view.holiday_hat = true

	var side := UI.vbox(12)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	# On a phone the tabs span the popup above the preview, as they'd
	# not fit beside it; otherwise they sit over the parts.
	var tabs := UI.hbox(8)
	if narrow:
		m.body.add_child(tabs)
		m.body.move_child(tabs, row.get_index())
	else:
		side.add_child(tabs)
	var list := UI.scroll_area()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(list)
	var room := MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(room)
	UI.clear_of_bar(list, room, 8)
	var rows := UI.vbox(14)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.add_child(rows)

	var first := str(Content.cosmetic_sections[0]["id"]) if not Content.cosmetic_sections.is_empty() else ""
	_show_section(first, tabs, rows, list, draft, view, narrow)

	# As tall as the popup allows without the whole body scrolling, up to
	# the height of the tallest section, so switching tabs never resizes it.
	var fit := func():
		var tallest := 0.0
		for section in Content.cosmetic_sections:
			tallest = maxf(tallest, _section_height(section))
		var gap := float((m.body if narrow else side).get_theme_constant("separation"))
		var tabs_tall := tabs.get_combined_minimum_size().y + gap
		if narrow:
			row.custom_minimum_size.y = minf(tallest, m.room() - tabs_tall)
		else:
			row.custom_minimum_size.y = minf(tabs_tall + tallest, m.room())
	m.resized.connect(fit)
	fit.call()
	return m


## Fills the tabs (with `section` open) and the rows of that section.
## Picking another tab calls this again.
static func _show_section(section: String, tabs: Control, rows: Control, list: ScrollContainer,
		draft: Dictionary, view: CharacterView, narrow: bool) -> void:
	for c in tabs.get_children() + rows.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	list.scroll_vertical = 0
	for s in Content.cosmetic_sections:
		var id: String = s["id"]
		var tab := _tab(s["name"], id == section, func():
			if id != section:
				_show_section(id, tabs, rows, list, draft, view, narrow))
		if narrow:
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
		if id == section:
			for part in s["rows"]:
				rows.add_child(_part_row(str(part), draft, view, rows, narrow))


## The row for one entry in a section: a colour row or a part's carousel.
static func _part_row(part: String, draft: Dictionary, view: CharacterView, rows: Control, narrow: bool) -> Control:
	if part == "skin_tone":
		return _tone_row(Text.t("customise.skin"), "skin", draft, view, rows, narrow)
	if part == "hair_tone":
		return _tone_row(Text.t("customise.hair"), "hair", draft, view, rows, narrow)
	return _slot_row(part, draft, view)


## Roughly how tall a section's rows stand, so the popup keeps one height
## whichever tab is open.
static func _section_height(section: Dictionary) -> float:
	var h := 0.0
	for part in section["rows"]:
		h += (SWATCH + 30.0) if str(part) in ["skin_tone", "hair_tone"] else (OPTION.y + 52.0)
		if str(part) == "hat" and App.holiday_hat() != "":
			h += 20.0
	return h + 14.0 * maxf(0.0, section["rows"].size() - 1)


## A section tab: the accent colour when it's open, greyed out when not.
static func _tab(text: String, on: bool, on_press: Callable) -> Button:
	var b := UI.pill_button(text, on, on_press, 34)
	var fill := UI.ACCENT if on else UI.SURFACE_SOFT
	var ink := UI.ON_COLOUR if on else UI.INK_FAINT
	UI.style_button(b, fill, ink, 999)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	b.add_theme_font_size_override("font_size", 14)
	return b


## What's worn in a slot in the draft, falling back to the slot's first option.
static func _current(draft: Dictionary, slot: String, options: Array) -> Dictionary:
	var id := str(draft["cosmetics"].get(slot, ""))
	for o in options:
		if o["id"] == id:
			return o
	return options[0] if not options.is_empty() else {}


## One part: its name, a carousel of every option (scroll left and right,
## or tap a neighbour), and what the middle one is under it.
static func _slot_row(slot: String, draft: Dictionary, view: CharacterView) -> Control:
	var v := UI.vbox(2)
	v.set_meta("slot", slot)
	var cap := UI.caption(Content.slot_name(slot))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var options := Content.cosmetic_options(slot, App.state.inventory)
	# A holiday hat (your party hat on your birthday) is worn whatever's
	# picked: the hats are held on it, greyed out, till the day's over. The
	# hat you'd picked stays saved for tomorrow.
	var held := App.holiday_hat() if slot == "hat" else ""
	if held != "" and not options.any(func(o): return o["id"] == held):
		options.append(Content.cosmetic(held))
	var carousel := Carousel.new()
	carousel.spacing = SPACING
	carousel.side_scale = 0.72
	carousel.side_alpha = 0.45
	carousel.reach = 2.6
	carousel.custom_minimum_size = Vector2(0, OPTION.y + 6.0)
	carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Closer together when narrow, so the neighbours either side show whole.
	carousel.resized.connect(func():
		var fit := clampf(carousel.size.x * 0.5 - OPTION.x * carousel.side_scale * 0.5 - 2.0, OPTION.x * 0.9, SPACING)
		if not is_equal_approx(fit, carousel.spacing):
			carousel.spacing = fit)
	var items: Array[Control] = []
	for o in options:
		items.append(Mini.new(draft, slot, o))
	v.add_child(carousel)
	var called := UI.label("", 14, UI.INK, false, 800)
	called.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(called)
	var start := options.find(_current(draft, slot, options))
	if held != "":
		for i in options.size():
			if options[i]["id"] == held:
				start = i
		carousel.locked = true
		# The others fade right back, so only the hat you're wearing reads.
		carousel.side_alpha = 0.18
	carousel.set_items(items, maxi(start, 0))
	called.text = str(options[carousel.index].get("name", "")) if not options.is_empty() else ""
	carousel.changed.connect(func(i: int):
		draft["cosmetics"][slot] = options[i]["id"]
		called.text = str(options[i].get("name", ""))
		view.refresh())
	if held != "":
		var why := Text.t("holiday.hat_locked", {"hat": str(Content.cosmetic(held).get("name", "")).to_lower()})
		carousel.accessibility_name = why
		var note := UI.label(why, 13, UI.INK_SOFT, false, 700)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(note)
	return v


## Skin or hair colour (`which`): five swatches, then a sixth that picks any
## colour (showing it once picked). The chosen one has a ring round it.
static func _tone_row(title: String, which: String, draft: Dictionary, view: CharacterView, rows: Control, narrow: bool) -> Control:
	var v := UI.vbox(6)
	v.set_meta("slot", which + "_tone")
	var cap := UI.caption(title)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	# Six in a row, smaller on a phone so they still fit across.
	var line := UI.hbox(4 if narrow else 10)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(line)
	var dot_size := 30.0 if narrow else SWATCH + 6.0
	var tones: Array[Color] = Content.skin_tones if which == "skin" else Content.hair_tones
	var dots: Array[_Dot] = []
	var changed := func():
		view.refresh()
		# Hair minis show the hair colour; tell every carousel to redraw.
		for m in rows.find_children("*", "Control", true, false):
			if m is Mini:
				(m as Mini).refresh()
		for d in dots:
			d.refresh()
	for i in tones.size():
		var d := _Dot.new(draft, which, i, dot_size)
		d.accessibility_name = Text.t("customise.skin_option" if which == "skin" else "customise.hair_option", {"n": i + 1})
		d.pressed.connect(func():
			draft[which + "_tone"] = i
			draft[which + "_colour"] = ""
			changed.call())
		dots.append(d)
		line.add_child(d)
	var custom := _Dot.new(draft, which, -1, dot_size)
	custom.accessibility_name = Text.t("customise.custom_colour")
	custom.pressed.connect(func():
		var start := Content.skin_of(draft) if which == "skin" else Content.hair_of(draft)
		var picked := Modal.colour(title, start, func(c: Color):
			draft[which + "_colour"] = "#" + c.to_html(false)
			changed.call())
		picked.closed.connect(func(_c): changed.call()))
	dots.append(custom)
	line.add_child(custom)
	return v


## One colour swatch in a tone row; index -1 is the "any colour" one.
class _Dot extends Button:
	var _draft: Dictionary
	var _which := ""
	var _index := 0

	func _init(draft: Dictionary, which: String, index: int, side: float) -> void:
		_draft = draft
		_which = which
		_index = index
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(side, side)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())

	func refresh() -> void:
		queue_redraw()

	func _own() -> String:
		return str(_draft.get(_which + "_colour", ""))

	func _chosen() -> bool:
		if _index < 0:
			return _own() != ""
		return _own() == "" and int(_draft.get(_which + "_tone", 0)) == _index

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		if _chosen():
			draw_arc(c, r + 2.5, 0, TAU, 48, UI.ACCENT, 2.5, true)
		if _index >= 0:
			var tones: Array[Color] = Content.skin_tones if _which == "skin" else Content.hair_tones
			draw_circle(c, r - 2.0, tones[_index], true, -1.0, true)
			draw_arc(c, r - 2.0, 0, TAU, 40, Color(UI.INK, 0.12), 1.0, true)
			return
		if _own() != "":
			draw_circle(c, r - 2.0, Color.from_string(_own(), Color.WHITE), true, -1.0, true)
			draw_arc(c, r - 2.0, 0, TAU, 40, Color(UI.INK, 0.12), 1.0, true)
		else:
			# A colour wheel: a ring of hues round a white middle.
			for k in 12:
				var a0 := TAU * k / 12.0
				draw_arc(c, r * 0.66, a0, a0 + TAU / 12.0 + 0.02, 6, Color.from_hsv(float(k) / 12.0, 0.7, 0.95), r * 0.5, true)
		var plus := Icons.texture("plus", 14, UI.INK)
		draw_circle(c, r * 0.45, Color(UI.SURFACE, UI.SURFACE.a * 0.9), true, -1.0, true)
		draw_texture(plus, c - Vector2(plus.get_size()) * 0.5)


## A little picture of one option for a part: the item on its own, or a
## crossed-out circle when it's nothing. Its accessibility name says what
## it is.
class Mini extends Control:
	var _draft: Dictionary
	var _slot: String
	var _item: Dictionary
	var _view := CharacterView.new()

	func _init(draft: Dictionary, slot: String, item: Dictionary) -> void:
		_draft = draft
		_slot = slot
		_item = item
		custom_minimum_size = OPTION
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		accessibility_name = str(item.get("name", ""))
		# Its own look: the draft's colours, wearing just this option.
		_view.look = _look()
		_view.holding_lead = false
		_view.part = slot
		_view.visible = str(item.get("style", "none")) != "none"
		add_child(_view)
		resized.connect(refresh)

	func _ready() -> void:
		refresh()

	func _look() -> Dictionary:
		var cosmetics := {}
		cosmetics[_slot] = _item.get("id", "")
		return {
			"skin_tone": _draft["skin_tone"], "hair_tone": _draft["hair_tone"],
			"skin_colour": _draft.get("skin_colour", ""), "hair_colour": _draft.get("hair_colour", ""),
			"cosmetics": cosmetics,
		}

	func refresh() -> void:
		_view.look = _look()
		_view.visible = str(_item.get("style", "none")) != "none"
		var r := CharacterView.part_rect(_slot, _item)
		# Fit the box, but small things (gloves, shoes) stop at half as big
		# again as on the character, so they don't turn into blobs.
		var s := minf(2.2, minf(size.x / r.size.x, size.y / r.size.y) * 0.9)
		_view.scale = Vector2(s, s)
		_view.position = size * 0.5 - r.get_center() * s
		_view.refresh()
		queue_redraw()

	func _draw() -> void:
		if _view.visible:
			return
		# Nothing worn here: a crossed-out circle.
		var c := size * 0.5
		var r := size.y * 0.34
		draw_arc(c, r, 0, TAU, 40, UI.INK_FAINT, 2.5, true)
		var d := Vector2(r, -r) * 0.7071
		draw_line(c - d, c + d, UI.INK_FAINT, 2.5, true)
