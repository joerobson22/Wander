class_name FriendProfile
extends RefCounted
## A friend's profile in a popup, laid out like your profile screen but
## fitting one popup: their character head to toe on the left; when they
## joined and their week on the right (never where they study, which stays
## private), with their gift
## shelf along the bottom (tap a gift for a closer look); then the
## achievements they've earned, in a row that scrolls sideways when there
## are more than fit. Opened by tapping a friend's face or name anywhere.
## Tapping your own goes to your profile screen instead.


## `f` is a friend (see Friends), or the leaderboard's row for you.
static func open(f: Dictionary) -> void:
	if f.get("me", false):
		while Modal.top():
			Modal.top().close()
		App.go("profile")
		return
	var m := Modal.open(620)
	var narrow := m.get_viewport_rect().size.x < 560.0
	m.header.add_child(m.heading_row(str(f.get("name", ""))))

	var body := UI.hbox(22 if not narrow else 14)
	var figure := UI.character_portrait(f.get("look", {}), Vector2(180 if not narrow else 116, 0))
	body.add_child(figure)
	var side := UI.vbox(8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var joined := int(f.get("joined_unix", 0))
	side.add_child(ProfileCard.details([
		ProfileCard.field(Text.t("profile.joined"), Stats.format_date(joined, App.tz_bias()) if joined > 0 else Text.t("friend.joined_unknown")),
		ProfileCard.field(Text.t("stats.this_week"), Stats.format_duration(int(f.get("weekly_seconds", 0)))),
	]))
	side.add_child(UI.spacer(true))
	var shelf := GiftShelf.new(f.get("shelf", ["", "", ""]), 60.0, func(tile: GiftTile, _i: int):
		tile.tappable = true
		tile.tapped.connect(func(id: String): GiftDetails.open(id, false, false)))
	side.add_child(ProfileCard.shelf(shelf))
	body.add_child(side)
	m.body.add_child(body)

	var rows := Achievements.progress(Achievements.list(Content.achievements, Content.tables, Content.gifts),
		int(f.get("focused_seconds", 0)), f.get("gifts", []), Content.gifts)
	var section := UI.vbox(8)
	section.add_child(ProfileCard.achievements_head(rows))
	section.add_child(_earned(rows))
	m.body.add_child(section)


## The medals for every achievement they've earned, hardest won first, in
## a card one medal tall. More than fit scroll sideways.
static func _earned(rows: Array) -> Control:
	# On the popup's white a thin outline sets the medals apart, rather than
	# a shadow the popup's edges would cut off.
	var card := PanelContainer.new()
	var outline := UI.box(UI.SURFACE, UI.LINE, 24)
	outline.set_border_width_all(2)
	# The medals scroll almost up to the outline, but start and end 14 in.
	outline.content_margin_left = 8
	outline.content_margin_right = 8
	outline.content_margin_top = 14
	outline.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", outline)
	card.custom_minimum_size.y = MedalCard.Medal.HEIGHT + outline.get_minimum_size().y
	var earned := Achievements.showcase(rows).filter(func(r): return r["earned"])
	if earned.is_empty():
		outline.content_margin_left = 14
		outline.content_margin_right = 14
		var none := UI.label(Text.t("friend.no_achievements"), 15, UI.INK_FAINT, false, 800)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(none)
		return card
	var strip := UI.scroll_area(true)
	strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var room := MarginContainer.new()
	room.add_theme_constant_override("margin_left", 6)
	room.add_theme_constant_override("margin_right", 6)
	var medals := UI.hbox(12)
	for r in earned:
		medals.add_child(MedalCard.Medal.new(r))
	room.add_child(medals)
	strip.add_child(room)
	UI.clear_of_bar(strip, room, 8)
	card.add_child(strip)
	return card
