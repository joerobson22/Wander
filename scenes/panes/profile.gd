extends Pane
## Your profile, above the focus screen. One card at the top: your
## character head to toe on the left (the pencil changes how they look),
## with your level badge in the bottom left and your XP filling a bar along
## the bottom (tap the badge for everything levelling up unlocks). On the
## right, your details at the top and your gift shelf at the bottom, with a
## pencil to arrange it. Under the card, as many of your best achievements
## as fit; "See all" lists every one. It all fits the screen without scrolling. The
## gear in the top right opens the settings. A new save slot shows what's
## left to fill in above the achievements, and keeps you here till then.

## Whether your total focus time shows in years, months, weeks and so on
## (tap it to switch) rather than hours and minutes.
var _long_total := false


func build() -> void:
	var col := frame(720, 14)
	var head := title_row(Text.t("profile.title"))
	head.add_child(UI.round_button("gear", Text.t("settings.title"), open_settings, UI.SURFACE, UI.INK, 44))
	col.add_child(head)

	var me := UI.card(UI.SURFACE, 14)
	# On a tall screen the card and the achievements share the spare room:
	# the character grows, and more medals fit.
	me.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := UI.hbox(22 if wide else 14)
	me.add_child(body)
	col.add_child(me)
	body.add_child(_figure())
	var side := UI.vbox(8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_details())
	side.add_child(UI.spacer(true))
	side.add_child(_shelf())
	body.add_child(side)

	col.add_child(_achievements())


## The character, with a pencil in the corner to change how they look. Your
## level badge sits in the bottom left with your XP filling a bar along the
## bottom; under the pointer the badge grows from its centre, turns a shade
## lighter and shines, and tapping it shows every reward levelling up
## brings. It's as tall as the card.
func _figure() -> Control:
	var figure := UI.character_portrait({}, Vector2(220 if wide else 128, 0), false, UI.ACCENT_SOFT, 48.0)
	var pencil := UI.round_button("edit", Text.t("profile.customise"), Customise.open, UI.SURFACE, UI.INK, 34)
	figure.add_child(pencil)

	var level := LevelBar.new(App.xp(), false, false)
	figure.add_child(level)
	var badge := level.badge()
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.mouse_default_cursor_shape = Cursor.HOVER
	badge.accessibility_name = Text.t("profile.levels")
	badge.set_meta("no_grow", true)
	Press.attach(badge).tapped.connect(open_rewards)
	var shine := Glint.new(0.5)
	badge.add_child(shine)
	badge.mouse_entered.connect(func():
		shine.shine()
		_hover_badge(badge, true))
	badge.mouse_exited.connect(_hover_badge.bind(badge, false))
	figure.resized.connect(func():
		pencil.size = pencil.get_combined_minimum_size()
		pencil.position = Vector2(figure.size.x - pencil.size.x - 8, 8)
		level.size = Vector2(figure.size.x - 16, level.get_combined_minimum_size().y)
		level.position = Vector2(8, figure.size.y - level.size.y - 8))
	return figure


## Grows the level badge from its centre and lightens its fill, or settles
## it back. Only the fill lightens: the number and the white rim stay put.
static func _hover_badge(badge: Control, on: bool) -> void:
	badge.pivot_offset = badge.size * 0.5
	var t := Motion.tween(badge, "hover")
	t.set_parallel(true)
	t.tween_property(badge, "scale", Vector2.ONE * (HoverGrow.GROW if on else 1.0), Motion.time(HoverGrow.TIME))
	t.tween_property(badge, "self_modulate", Color(1.22, 1.22, 1.22) if on else Color.WHITE, Motion.time(HoverGrow.TIME))


## Your name, where you study, when you joined and how long you've focused
## in all (every project, finished or not): small, at the top.
func _details() -> Control:
	var p := App.state.profile
	var username := str(p.get("username", ""))
	var school := str(p.get("institution", ""))
	var joined := int(p.get("created_unix", 0))
	return ProfileCard.details([
		ProfileCard.field(Text.t("profile.username"), username if username != "" else Text.t("profile.username_empty"), username == "",
			_edit.bind("username", Text.t("profile.username_prompt"), Text.t("profile.username_placeholder"), 24)),
		ProfileCard.field(Text.t("profile.school"), school if school != "" else Text.t("profile.school_empty"), school == "",
			_edit.bind("institution", Text.t("profile.school_prompt"), Text.t("profile.school_placeholder"), 60)),
		ProfileCard.field(Text.t("profile.joined"), Stats.format_date(joined, App.tz_bias()) if joined > 0 else Text.t("profile.joined_today")),
		_total_focus(),
	])


## Your total focus time; tapping it switches between "312h 40m" and
## "1wk 6d 40m".
func _total_focus() -> Control:
	var row := ProfileCard.field(Text.t("profile.total_focus"), _total_text())
	var value: Label = row.get_child(0).get_child(1)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.set_meta("no_grow", true)
	row.accessibility_name = Text.t("profile.total_focus_tap", {"time": value.text})
	Press.attach(row).tapped.connect(func():
		_long_total = not _long_total
		value.text = _total_text()
		row.accessibility_name = Text.t("profile.total_focus_tap", {"time": value.text}))
	return row


func _total_text() -> String:
	var seconds := App.state.total_seconds()
	return Stats.format_long(seconds) if _long_total else Stats.format_duration(seconds)


## Your gift shelf, along the bottom of the card, with a pencil that opens
## the shelf editor. The gifts here are only to look at.
func _shelf() -> Control:
	return ProfileCard.shelf(GiftShelf.new(GiftShelf.mine(), 66.0 if wide else 60.0), ShelfEditor.open)


func _edit(key: String, title: String, placeholder: String, max_length: int) -> void:
	Modal.prompt(title, str(App.state.profile.get(key, "")), placeholder, max_length).closed.connect(func(text):
		if text is String:
			App.set_profile(key, text))


## Every achievement with how far along you are, in order: the hours
## focused, then every gift, then each animal's set.
static func achievement_rows() -> Array:
	return App.achievement_rows()


## The achievements under the card: a heading with how many you have, then
## your best medals filling the rest of the screen, ending in "See all".
func _achievements() -> Control:
	var rows := achievement_rows()
	var section := UI.vbox(8)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	section.add_child(ProfileCard.achievements_head(rows))
	var medals := MedalCard.new(rows)
	medals.shrank.connect(func(): section.size_flags_vertical = Control.SIZE_FILL)
	section.add_child(medals)
	return section


# --- Settings ----------------------------------------------------------------

func open_settings() -> void:
	_fill_settings(Modal.open(480))


## The settings in `m`, built again in the new colours when colour vision
## changes.
func _fill_settings(m: Modal) -> void:
	for part in [m.header, m.body]:
		for child in part.get_children():
			child.queue_free()
	# The title stays put while the settings scroll.
	m.header.add_child(m.heading_row(Text.t("settings.title")))
	var s := UI.vbox(10)
	s.add_child(_account_row())
	s.add_child(UI.divider())
	s.add_child(_toggle(Text.t("settings.sound"), Text.t("settings.sound_note"), "sound"))
	s.add_child(UI.divider())
	s.add_child(_toggle(Text.t("settings.ambience"), Text.t("settings.ambience_note"), "ambience"))
	s.add_child(UI.divider())
	s.add_child(_toggle(Text.t("settings.keep_screen_on"), Text.t("settings.keep_screen_on_note"), "keep_screen_on"))
	s.add_child(UI.divider())
	s.add_child(_location_toggle())
	for row in Display.settings_rows(get_window()):
		s.add_child(UI.divider())
		s.add_child(row)
	s.add_child(UI.divider())
	s.add_child(UI.caption(Text.t("settings.accessibility")))
	s.add_child(_vision_row(m))
	s.add_child(UI.divider())
	s.add_child(_toggle(Text.t("settings.reduce_motion"), Text.t("settings.reduce_motion_note"), "reduce_motion"))
	s.add_child(UI.divider())
	var links := HFlowContainer.new()
	links.alignment = FlowContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("h_separation", 14)
	links.add_child(UI.text_link(Text.t("legal.privacy"), Legal.open.bind(Legal.PRIVACY), 14))
	links.add_child(UI.text_link(Text.t("legal.terms"), Legal.open.bind(Legal.TERMS), 14))
	links.add_child(UI.text_link(Text.t("legal.licences"), Legal.open_licences, 14))
	s.add_child(links)
	var about := UI.para(Text.t("settings.about", {"app": ProjectSettings.get_setting("application/config/name", ""),
		"version": ProjectSettings.get_setting("application/config/version", "")}), 13, UI.INK_SOFT)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_child(about)
	# Clear of the scrollbar, so the switches never touch it.
	var room := MarginContainer.new()
	room.add_child(s)
	m.body.add_child(room)
	UI.clear_of_bar(m.scroller(), room)


## Whose account this is: their face, name and where they study, with Data
## (what's kept about you) and Log out on the right. The account stays on
## this device to log back into.
func _account_row() -> Control:
	var row := UI.hbox(12)
	var face := UI.character_portrait({}, Vector2(44, 44), true)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(face)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var username := str(App.state.profile.get("username", ""))
	text.add_child(UI.trimmed(username if username != "" else Text.t("accounts.unnamed"), 16, UI.INK, false, 800))
	var school := str(App.state.profile.get("institution", ""))
	if school != "":
		text.add_child(UI.trimmed(school, 13, UI.INK_SOFT, false, 600))
	row.add_child(text)
	var data := _small_button(Text.t("settings.data"), Legal.open_data, "quiet")
	data.accessibility_name = Text.t("settings.data_name")
	row.add_child(data)
	row.add_child(_small_button(Text.t("accounts.log_out"), func():
		Modal.close_all()
		App.log_out(), "danger"))
	return row


func _small_button(text: String, on_press: Callable, kind: String) -> Button:
	var b := UI.button(text, on_press, kind)
	b.custom_minimum_size.y = 38
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var sb := (b.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		b.add_theme_stylebox_override(state, sb)
	return b


## Colour vision (UI.VISIONS): the app recolours as soon as one's picked.
func _vision_row(m: Modal) -> Control:
	var row := UI.hbox(16)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(Text.t("settings.vision"), 16, UI.INK, false, 800))
	text.add_child(UI.para(Text.t("settings.vision_note"), 13))
	row.add_child(text)
	var options := UI.VISIONS.map(func(id): return [id, Text.t("settings.visions." + id)])
	var pick := Dropdown.new(options, str(App.state.settings.get("vision", "off")), false, "", false)
	pick.accessibility_name = Text.t("settings.vision")
	pick.chosen.connect(func(id: String, _reversed: bool):
		if id != UI.vision:
			App.set_setting("vision", id)
			_fill_settings(m))
	row.add_child(pick)
	return row


func _toggle(title: String, detail: String, key: String) -> Control:
	var row := UI.hbox(16)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, 16, UI.INK, false, 800))
	text.add_child(UI.para(detail, 13))
	row.add_child(text)
	var sw := Switch.new(bool(App.state.settings.get(key, false)))
	sw.accessibility_name = title
	sw.toggled.connect(func(on: bool):
		App.set_setting(key, on)
		if key == "ambience":
			Audio.refresh(Audio.current_ambience()))
	row.add_child(sw)
	return row


## Real sunrise, sunset and weather: on and off goes through Outdoors, which
## also says where it thinks you are once it knows.
func _location_toggle() -> Control:
	var row := UI.hbox(16)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(Text.t("settings.weather"), 16, UI.INK, false, 800))
	var detail := Text.t("settings.weather_note")
	if Outdoors.place_name() != "":
		detail += " " + Text.t("settings.weather_now", {"place": Outdoors.place_name(), "weather": Weather.look(Outdoors.weather(), Content.weathers)["name"].to_lower()})
	text.add_child(UI.para(detail, 13))
	row.add_child(text)
	var sw := Switch.new(Outdoors.enabled())
	sw.accessibility_name = Text.t("settings.weather")
	sw.toggled.connect(Outdoors.set_enabled)
	row.add_child(sw)
	return row


# --- Rewards -----------------------------------------------------------------

## The level line's width in the rewards (and the padlock column under it).
const TRACK_WIDTH := 28

## Everything levelling up unlocks, in order, each row hugging the left
## with a line down the right filled to where you are now (levels still to
## come have a padlock on their dot). Under a divider, what's unlocked by
## exploring (hours in a place, a finished gift table), each with a bar for
## how far along you are. The title and your level stay at the top while
## the rewards scroll, and it opens scrolled to where you are.
func open_rewards() -> void:
	var table := Content.levels
	var xp := App.xp()
	var p := Levels.progress(xp, table)
	# Where you are, as a level with a fraction: 7.4 is 40% of the way to 8.
	var at := float(p["level"]) + float(p["into"]) / maxf(1.0, float(p["needed"]))
	var m := Modal.open(460)
	# The title and where you are stay put; only the rewards scroll.
	m.header.add_child(m.heading_row(Text.t("rewards.title")))
	var head := UI.hbox(12)
	head.add_child(UI.level_badge(p["level"], 44))
	var words := UI.vbox(0)
	words.add_child(UI.label(Text.t("rewards.level", {"level": p["level"]}), 18, UI.INK, true, 600))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UI.para(Text.t("rewards.to_next", {"xp": int(p["needed"]) - int(p["into"]), "level": int(p["level"]) + 1}), 13, UI.INK_SOFT, 700))
	head.add_child(words)
	m.header.add_child(head)

	var rows := _reward_list()
	var list := UI.vbox(0)
	# The first reward still to come: just past where you are on the line.
	var here: Control = null
	for i in rows.size():
		var before: int = rows[i - 1]["level"] if i > 0 else 1
		var after: int = rows[i + 1]["level"] if i + 1 < rows.size() else rows[i]["level"] + 1
		var row := _reward_row(rows[i], before, after, at)
		list.add_child(row)
		if here == null and float(rows[i]["level"]) > at:
			here = row
	m.body.add_child(list)
	var others := Unlocks.other_rewards()
	if not others.is_empty():
		m.body.add_child(UI.divider())
		var more := UI.vbox(0)
		for r in others:
			more.add_child(_other_row(r))
		m.body.add_child(more)
	m.scroll_to(here if here else list.get_child(list.get_child_count() - 1))


## Level 1's animals and places first, then each reward in level order.
func _reward_list() -> Array:
	return Unlocks.level_rewards()


## An animal or place unlocked by exploring: what it takes and, until it's
## yours, a bar for how far along you are and a padlock on the right.
func _other_row(r: Dictionary) -> Control:
	var open := App.is_unlocked(r["type"], r["id"])
	var row := UI.hbox(12)
	row.custom_minimum_size.y = 72
	row.set_meta("locked", not open)
	var icon := _reward_picture(r)
	icon.modulate.a = 1.0 if open else 0.45
	row.add_child(icon)
	var title: String = _reward_name(r)
	var words := UI.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(UI.trimmed(title, 17, UI.INK if open else UI.INK_SOFT, false, 800))
	words.add_child(UI.para(Unlocks.describe(Content.unlock_rule(r["type"], r["id"])), 13, UI.INK_FAINT, 700))
	if not open:
		var p := App.unlock_progress(r["type"], r["id"])
		var goal := float(p["goal"])
		var bar := UI.progress_line(float(p["have"]) / goal if goal > 0.0 else 0.0, UI.ACCENT, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gap := Control.new()
		gap.custom_minimum_size.y = 4
		words.add_child(gap)
		words.add_child(bar)
	row.add_child(words)
	if not open:
		var lock := UI.icon_rect("lock", 16, UI.INK_FAINT)
		lock.custom_minimum_size.x = TRACK_WIDTH
		row.add_child(lock)
	return row


## A reward's picture: the place's tile or the animal.
func _reward_picture(r: Dictionary) -> Control:
	var icon: Control
	if r["type"] == "place":
		icon = UI.place_tile(Content.biome(r["id"]), 56)
	else:
		icon = UI.animal_portrait(r["id"], Content.animal_default_colours(r["id"]), Vector2(56, 56))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon


func _reward_name(r: Dictionary) -> String:
	return str(Content.biome(r["id"]).get("name", "") if r["type"] == "place" else Content.animal(r["id"]).get("name", ""))


func _reward_row(r: Dictionary, before: int, after: int, at: float) -> Control:
	var level: int = r["level"]
	var open := at >= level
	var row := UI.hbox(12)
	row.custom_minimum_size.y = 72
	row.set_meta("locked", not open)
	var icon := _reward_picture(r)
	icon.modulate.a = 1.0 if open else 0.45
	row.add_child(icon)

	var words := UI.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(UI.trimmed(_reward_name(r), 17, UI.INK if open else UI.INK_SOFT, false, 800))
	var when := Text.t("rewards.new_place" if r["type"] == "place" else "rewards.new_animal", {"when": Text.t("rewards.from_start") if level == 1 else Text.t("rewards.level", {"level": level})})
	words.add_child(UI.label(when, 13, UI.INK_FAINT, false, 700))
	row.add_child(words)

	# The line runs down the right; a level still to come has a padlock on
	# its dot.
	var track := _Track.new()
	track.custom_minimum_size.x = TRACK_WIDTH
	# How full the line is above this row's dot (coming from the row before)
	# and below it (going on to the next).
	# Rewards at the same level share a stretch of line, filled once that
	# level is reached.
	var same := 1.0 if open else 0.0
	track.above = same if before == level else clampf((at - before) / float(level - before) * 2.0 - 1.0, 0.0, 1.0)
	track.below = same if after == level else clampf((at - level) / float(after - level) * 2.0, 0.0, 1.0)
	track.reached = open
	row.add_child(track)
	return row


## One row's piece of the progress line, with its dot.
class _Track extends Control:
	var above := 0.0
	var below := 0.0
	var reached := false

	func _draw() -> void:
		var x := size.x * 0.5
		var mid := size.y * 0.5
		var w := 4.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), UI.LINE, w)
		if above > 0.0:
			draw_line(Vector2(x, 0), Vector2(x, mid * above), UI.ACCENT, w)
		if below > 0.0:
			draw_line(Vector2(x, mid), Vector2(x, mid + mid * below), UI.ACCENT, w)
		if reached:
			draw_circle(Vector2(x, mid), 8.0, UI.ACCENT, true, -1.0, true)
			return
		# Still to come: a padlock in a ring on the line.
		var r := 12.0
		draw_circle(Vector2(x, mid), r, UI.SURFACE, true, -1.0, true)
		draw_arc(Vector2(x, mid), r, 0, TAU, 32, UI.LINE, 3.0, true)
		var lock := Icons.texture("lock", 14, UI.INK_FAINT)
		draw_texture(lock, Vector2(x, mid) - Vector2(lock.get_size()) * 0.5)
