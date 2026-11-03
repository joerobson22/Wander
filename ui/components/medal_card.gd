class_name MedalCard
extends PanelContainer
## A card of achievement medals: as many as fit in the room it's given, the
## ones you've earned first (hardest won first), then the ones you're
## closest to (Achievements.showcase). The last spot is always "See all",
## which shades under the pointer and opens the whole list; it says how
## many more there are. Used on your profile and on friends' profiles.

## Every medal fit with rows to spare, so the card shrank to fit them: a
## parent that stretched to make room for it can stop stretching too.
signal shrank

const GAP := 10.0
const MEDAL_WIDTH := 72.0

var rows: Array
var _lines := 1
var _room := Control.new()
var _grid: GridContainer


## `list` is rows from Achievements.progress(). `lines` fixes how many rows
## of medals the card is tall; with 0 it stretches to fill the room it's
## given (at least one row) and fits in as many rows as that holds.
func _init(list: Array, lines: int = 0) -> void:
	rows = list
	_lines = lines
	if lines <= 0:
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	var b := UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 24))
	b.content_margin_left = 14
	b.content_margin_right = 14
	b.content_margin_top = 14
	b.content_margin_bottom = 12
	add_theme_stylebox_override("panel", b)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A plain Control: the medals inside don't make the card any bigger.
	var least := maxi(1, lines)
	_room.custom_minimum_size.y = least * Medal.HEIGHT + (least - 1) * GAP
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_room)
	_room.resized.connect(_fit, CONNECT_DEFERRED)


func _fit() -> void:
	if is_instance_valid(_grid):
		_room.remove_child(_grid)
		_grid.queue_free()
	var w := _room.size.x
	var columns := maxi(3, int((w + 4.0) / (MEDAL_WIDTH + 4.0)))
	var lines := _lines if _lines > 0 else maxi(1, floori((_room.size.y + GAP) / (Medal.HEIGHT + GAP)))
	var room := columns * lines
	var shown := mini(rows.size(), room - 1)
	var order := Achievements.showcase(rows)
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", int(GAP))
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in shown:
		var medal := Medal.new(order[i])
		medal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(medal)
	var more := More.new(rows.size() - shown)
	Press.attach(more).tapped.connect(open_list.bind(rows))
	_grid.add_child(more)
	_room.add_child(_grid)
	var h := _grid.get_combined_minimum_size().y
	_grid.size = Vector2(w, h)
	_grid.position.y = maxf(0.0, (_room.size.y - h) * 0.5)
	if _lines <= 0 and shown == rows.size() and _room.size.y - h >= Medal.HEIGHT:
		# Every medal fits with rows to spare: hand the spare room back to
		# the page rather than leave the card half empty.
		size_flags_vertical = Control.SIZE_FILL
		_room.custom_minimum_size.y = h
		shrank.emit()


## Every achievement in a popup, each with what it's for and how far along
## you are. The title stays at the top while the list scrolls.
static func open_list(list: Array) -> void:
	var m := Modal.open(480)
	m.header.add_child(m.heading_row(Text.t("achievements.title")))
	m.header.add_child(UI.para(Text.t("achievements.earned", {"have": list.filter(func(r): return r["earned"]).size(), "total": list.size()}), 14, UI.INK_SOFT, 700))
	var column := UI.vbox(12)
	var group := ""
	for r in list:
		var kind := Text.t("achievements.group_focus" if r["kind"] == "hours" else "achievements.group_gifts")
		if kind != group:
			group = kind
			if column.get_child_count() > 0:
				column.add_child(UI.divider())
			column.add_child(UI.caption(kind))
		column.add_child(_row(r))
	m.body.add_child(column)


## One achievement in the full list: its medal, its name and what it's for,
## and a bar showing how far along you are (a tick once it's yours).
static func _row(r: Dictionary) -> Control:
	var earned: bool = r["earned"]
	var row := UI.hbox(14)
	var disc := Disc.new(r, 48.0)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(disc)
	var words := UI.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UI.hbox(8)
	var title := UI.trimmed(r["name"], 16, UI.INK if earned else UI.INK_SOFT, false, 800)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if earned:
		top.add_child(UI.icon_rect("check", 16, UI.ACCENT))
	words.add_child(top)
	words.add_child(UI.para(r["description"], 13, UI.INK_SOFT, 700))
	var progress := UI.hbox(10)
	var bar := Bar.new(float(r["have"]) / maxf(1.0, float(r["goal"])))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_child(bar)
	var line := "achievements.progress_hours" if r["kind"] == "hours" else "achievements.progress_gifts"
	progress.add_child(UI.label(Text.t(line, {"have": Achievements.grouped(r["have"]), "goal": Achievements.grouped(r["goal"])}), 12, UI.INK_FAINT, false, 800))
	words.add_child(progress)
	row.add_child(words)
	return row


## An achievement's disc: in colour once earned (green for hours, gold for
## every gift, blue for an animal's set), grey before, with a ring round it
## showing how far along you are. Hours and gifts have an icon (or your own
## assets/icons/achievements/<id>.svg, as drawn); animal sets show the animal.
class Disc extends Control:
	var info: Dictionary
	var diameter := 52.0

	func _init(row: Dictionary, side: float) -> void:
		info = row
		diameter = side
		custom_minimum_size = Vector2(side, side)
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if row["animal"] != "":
			var pet := AnimalView.new()
			pet.animal_id = row["animal"]
			pet.colours = Content.animal_default_colours(row["animal"])
			pet.scale = Vector2.ONE * 0.3 * side / 52.0
			pet.position = Vector2(side * 0.42, side * 0.78)
			pet.modulate = Color.WHITE if row["earned"] else Color(1, 1, 1, 0.35)
			add_child(pet)
		else:
			var px := int(side * 0.46)
			var icon := UI.icon_rect(str(row["icon"]), px, Color.WHITE if row["earned"] else UI.INK_FAINT)
			# Your own full-colour picture for it, if you've drawn one.
			var own := Icons.drawn("achievements/" + str(row["id"]), int(side * 0.62))
			if own:
				px = int(side * 0.62)
				icon.texture = own
				icon.modulate = Color.WHITE if row["earned"] else Color(1, 1, 1, 0.4)
			icon.position = Vector2(side - px, side - px) * 0.5
			add_child(icon)
		UI.ignore_mouse(self)

	func _draw() -> void:
		var c := size * 0.5
		var r := diameter * 0.5
		if info["earned"]:
			var fill := UI.ACCENT
			if info["kind"] == "all_gifts":
				fill = Content.rarity_colour("legendary")
			elif info["kind"] == "table":
				fill = Content.rarity_colour("rare").lerp(Color.WHITE, 0.55)
			draw_circle(c, r, fill, true, -1.0, true)
			draw_arc(c, r - 3.0, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.0, true)
		else:
			draw_circle(c, r, UI.SURFACE_SOFT, true, -1.0, true)
			var share := float(info["have"]) / maxf(1.0, float(info["goal"]))
			if share > 0.0:
				draw_arc(c, r - 2.0, -PI * 0.5, -PI * 0.5 + TAU * share, 48, UI.ACCENT, 3.0, true)


## One medal: its disc with its name under it, on one line (trimmed with
## "..." when it's too long), so every medal takes the same room.
class Medal extends VBoxContainer:
	const HEIGHT := 72.0
	var info: Dictionary

	func _init(row: Dictionary) -> void:
		info = row
		add_theme_constant_override("separation", 4)
		custom_minimum_size = Vector2(MEDAL_WIDTH, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(Disc.new(row, 52.0))
		var name_label := UI.trimmed(row["name"], 11, UI.INK if row["earned"] else UI.INK_FAINT, false, 800)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size.x = MEDAL_WIDTH
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(name_label)


## The last spot: "See all", with how many more there are. It shades under
## the pointer, like the gift tiles, to show it can be tapped.
class More extends VBoxContainer:
	var _disc := Control.new()
	var _words: Label
	var _shade := 0.0

	func _init(more: int) -> void:
		add_theme_constant_override("separation", 4)
		custom_minimum_size = Vector2(MEDAL_WIDTH, Medal.HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Cursor.HOVER
		accessibility_name = Text.t("achievements.see_every")
		_disc.custom_minimum_size = Vector2(52, 52)
		_disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disc.draw.connect(func():
			var fill := UI.SURFACE_SOFT
			fill = fill.lightened(0.12 * _shade) if UI.dark else fill.darkened(0.1 * _shade)
			_disc.draw_circle(_disc.size * 0.5, 26.0, fill, true, -1.0, true))
		var plus := UI.label(Text.t("achievements.more", {"n": more}) if more > 0 else Text.t("achievements.all"), 17, UI.INK_SOFT, true, 600)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disc.add_child(plus)
		add_child(_disc)
		_words = UI.trimmed(Text.t("achievements.see_all"), 11, UI.INK_SOFT, false, 800)
		_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_words)
		mouse_entered.connect(_hover.bind(true))
		mouse_exited.connect(_hover.bind(false))

	func _hover(on: bool) -> void:
		Motion.method(self, "shade", _set_shade, _shade, 1.0 if on else 0.0, Motion.FAST)
		_words.add_theme_color_override("font_color", UI.INK if on else UI.INK_SOFT)

	func _set_shade(v: float) -> void:
		_shade = v
		_disc.queue_redraw()


## A thin progress bar for the achievements list.
class Bar extends Control:
	var share := 0.0

	func _init(fraction: float) -> void:
		share = clampf(fraction, 0.0, 1.0)
		custom_minimum_size = Vector2(60, 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_style_box(UI.bar_box(UI.SURFACE_SOFT, 3), Rect2(Vector2.ZERO, size))
		if share > 0.0:
			draw_style_box(UI.box(UI.ACCENT, Color.TRANSPARENT, 3), Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * share), size.y)))
