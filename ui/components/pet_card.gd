class_name PetCard
extends RefCounted
## Popups about a pet or a place, from the stats chart. A pet's shows its
## picture, kind, when you adopted it and its time walked, then the projects
## it walked for most on a podium. A place's shows its tile and time, then
## the pets that walked there most. `extra` is a note under the time (e.g.
## "2h 10m this week").


static func open(pet: PetData, extra: String = "") -> Modal:
	var m := Modal.open(460)
	m.body.add_child(m.heading_row(pet.name))
	var row := UI.hbox(16)
	row.add_child(UI.animal_portrait(pet.animal_id, pet.colours, Vector2(112, 92)))
	var words := UI.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kind := str(Content.animal(pet.animal_id).get("name", ""))
	if pet.is_rehomed():
		kind = Text.t("pet_card.kind_rehomed", {"kind": kind})
	words.add_child(UI.label(kind, 14, UI.INK_SOFT, false, 800))
	words.add_child(UI.label(Stats.format_duration(App.state.pet_seconds(pet.id)), 24, UI.ACCENT, true, 600))
	words.add_child(UI.label(Text.t("pet_card.adopted", {"date": Stats.format_date(pet.adopted_unix, App.tz_bias())}), 13, UI.INK_FAINT, false, 700))
	if extra != "":
		words.add_child(UI.label(extra, 13, UI.INK_FAINT, false, 700))
	row.add_child(words)
	m.body.add_child(row)
	var totals := {}
	for p in App.state.projects:
		if int(p.pets.get(pet.id, 0)) > 0:
			totals[p.id] = int(p.pets[pet.id])
	m.body.add_child(UI.divider())
	m.body.add_child(Podium.new(Text.t("pet_card.top_projects"), project_rows(totals), Text.t("project.no_walks")))
	return m


static func open_place(place_id: String, extra: String = "") -> Modal:
	var biome := Content.biome(place_id)
	var m := Modal.open(460)
	m.body.add_child(m.heading_row(str(biome.get("name", ""))))
	var row := UI.hbox(16)
	row.add_child(UI.place_tile(biome, 84))
	var words := UI.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_child(UI.label(Stats.format_duration(int(App.state.place_seconds().get(place_id, 0))), 24, UI.ACCENT, true, 600))
	if extra != "":
		words.add_child(UI.label(extra, 13, UI.INK_FAINT, false, 700))
	row.add_child(words)
	m.body.add_child(row)
	var totals := {}
	for pet in App.state.pets:
		if int(pet.places.get(place_id, 0)) > 0:
			totals[pet.id] = int(pet.places[place_id])
	m.body.add_child(UI.divider())
	m.body.add_child(Podium.new(Text.t("pet_card.top_pets"), Podium.pet_rows(totals), Text.t("project.no_walks")))
	return m


## Projects for a podium: each a tile in its chart colour with its status
## (an hourglass while it's going, a tick once done).
static func project_rows(totals: Dictionary) -> Array:
	var out: Array = []
	for row in Stats.ranked(totals):
		var p := App.state.project(row[0])
		if p == null:
			continue
		out.append({
			"picture": func(side: float) -> Control: return _project_tile(p, side),
			"name": p.name,
			"time": Stats.format_duration(row[1]),
		})
	return out


static func _project_tile(p: ProjectData, side: float) -> Control:
	var tile := UI.panel(UI.series_colour(p.id), roundi(side * 0.28), 0)
	tile.custom_minimum_size = Vector2(side, side)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(UI.icon_rect("check" if p.is_complete() else "hourglass", roundi(side * 0.42), UI.ON_COLOUR))
	return tile
