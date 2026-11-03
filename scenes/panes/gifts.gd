extends Pane
## Gifts, to the left of the focus screen. At the top, three rings for how
## your collection's coming along: gifts discovered, animals whose whole gift
## table you've found, and cosmetics unlocked from gifts. Under them, every
## gift you have, with how many on each and a "Sort by" menu (shared with
## the shelf editor); only the gifts scroll. Gifts grow under the pointer
## and show a card with their trade-in progress (GiftInfo); click one with
## enough to trade it in. Your shelf is on your profile.

var _stats: StatPanel
var _grid: GiftGrid


func build() -> void:
	_stats = null
	_grid = null
	var col := frame(760, 16)
	col.add_child(title_row(Text.t("gifts.title")))
	var counts := Collection.progress(App.state.inventory, Content.gifts)
	col.add_child(_progress(counts))

	var section := UI.vbox(8)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := UI.hbox(8)
	var cap := UI.caption(Text.t("gifts.your_collection"))
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	head.add_child(UI.spacer())
	section.add_child(head)
	col.add_child(section)
	if GiftGrid.ids().is_empty():
		var empty := UI.card(UI.SURFACE, 24)
		var v := UI.vbox(6)
		v.add_child(UI.label(Text.t("gifts.empty_title"), 20, UI.INK, true, 600))
		v.add_child(UI.para(Text.t("gifts.empty_body", {"minutes": floori(Content.drop_table.get("min_seconds", 600) / 60.0)})))
		empty.add_child(v)
		section.add_child(empty)
		return
	head.add_child(GiftGrid.sort_menu())
	# The list scrolls on its own, keeping its place when the screen rebuilds
	# (after a trade, say).
	scroll = UI.scroll_area()
	section.add_child(scroll)
	_grid = GiftGrid.new(8 if wide else 5, _tile)
	scroll.add_child(_grid)


## The rings fill up each time you come to the screen.
func _on_shown() -> void:
	if _stats:
		_stats.sweep()


## One gift in the collection: its picture and how many you have; hover
## for its card, click to trade it in.
func _tile(id: String) -> GiftTile:
	var tile := GiftTile.new(id, App.state.gift_count(id))
	tile.trades = true
	return tile


## Three rings side by side: gifts in green, pets' gift tables in blue and
## cosmetics in purple (the common, rare and epic colours).
func _progress(counts: Dictionary) -> Control:
	var section := UI.vbox(8)
	section.add_child(UI.caption(Text.t("gifts.collection_stats")))
	_stats = StatPanel.new(3)
	section.add_child(_stats)
	var diameter := clampf(size.y * 0.12, 64.0, 104.0)
	var stats := [
		[Text.t("gifts.discovered"), Text.t("gifts.discovered_note", {"have": counts["found"], "total": counts["gifts"]}), counts["found"], counts["gifts"], "common"],
		[Text.t("gifts.pet_tables"), Text.t("gifts.pet_tables_note", {"have": counts["tables"], "total": counts["total_tables"]}), counts["tables"], counts["total_tables"], "rare"],
		[Text.t("gifts.cosmetics"), Text.t("gifts.cosmetics_note", {"have": counts["cosmetics"], "total": counts["wearables"]}), counts["cosmetics"], counts["wearables"], "epic"],
	]
	for s in stats:
		_stats.add(ProgressRing.new(Collection.fraction(s[2], s[3]), Content.rarity_colour(s[4]), diameter), s[0], s[1])
	return section
