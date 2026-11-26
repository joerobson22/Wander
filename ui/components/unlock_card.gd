class_name UnlockCard
extends RefCounted
## The popup for animals and places you've just unlocked: each one's
## picture, name and what earned it. Every unlock comes through here, however
## it happened (a walk's time, a level, a trade-in that finishes a table),
## from App.take_unlocks(), so none slips by.


## `unlocked` is [{type, id}]. Returns the popup, or null if there's nothing.
static func open(unlocked: Array) -> Modal:
	if unlocked.is_empty():
		return null
	var m := Modal.open(440)
	m.header.add_child(m.heading_row(Text.t("unlocked.title")))
	var rows := UI.vbox(14)
	for r in unlocked:
		rows.add_child(_row(str(r["type"]), str(r["id"])))
	m.body.add_child(rows)
	m.footer.add_child(UI.button(Text.t("unlocked.nice"), m.close.bind(true), "accent"))
	Audio.play("unlock", 1.0, -4.0, "chime")
	return m


static func _row(type: String, id: String) -> Control:
	var row := UI.hbox(16)
	var picture: Control
	var name := ""
	if type == "animal":
		picture = UI.animal_portrait(id, Content.animal_default_colours(id), Vector2(104, 84))
		name = str(Content.animal(id).get("name", ""))
	else:
		var biome := Content.biome(id)
		# The same size and shape as an animal's picture, so the rows match.
		picture = UI.place_tile(biome, 84)
		picture.custom_minimum_size = Vector2(104, 84)
		var sb := (picture.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		UI.corners(sb, 18)
		picture.add_theme_stylebox_override("panel", sb)
		name = str(biome.get("name", ""))
	row.add_child(picture)
	var words := UI.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_child(UI.label(Text.t("unlocked.new_animal" if type == "animal" else "unlocked.new_place"), 13, UI.INK_SOFT, false, 800))
	words.add_child(UI.label(name, 24, UI.ACCENT, true, 600))
	# What earned it, ticked off.
	var why := UI.hbox(6)
	why.add_child(UI.icon_rect("check", 14, UI.SUCCESS))
	why.add_child(UI.para(Unlocks.describe(Content.unlock_rule(type, id)), 14, UI.INK_SOFT, 700))
	words.add_child(why)
	row.add_child(words)
	row.accessibility_name = name
	return row
