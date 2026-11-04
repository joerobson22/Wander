class_name StatPanel
extends PanelContainer
## A card of headline numbers side by side, each in an equal-width cell: a
## picture on top (a ProgressRing for a share of something, or an
## icon_value() for a number that isn't), an optional big value, a name, and one muted line
## under it. Gifts and Projects both use it, so their stats always match.
## On a narrow screen `columns` can wrap the cells onto more rows.

## How strongly an icon_value's picture shows behind its number.
const ICON_FADE := 0.45

var _grid: GridContainer


func _init(columns: int = 0) -> void:
	var sb := UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 24))
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = GridContainer.new()
	_grid.columns = maxi(1, columns) if columns > 0 else 99
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 18)
	add_child(_grid)


## Adds a cell. `value` (e.g. "12h 30m") shows big under the picture; leave
## it out when the picture already says it (a ring shows its percentage).
func add(picture: Control, title: String, sub: String = "", value: String = "") -> VBoxContainer:
	var cell := UI.vbox(4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(picture)
	if value != "":
		var big := UI.trimmed(value, 22, UI.INK, true, 600)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(big)
	var name_label := UI.trimmed(title, 15, UI.INK, false, 800)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(name_label)
	if sub != "":
		var line := UI.trimmed(sub, 12, UI.INK_FAINT, false, 700)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(line)
	_grid.add_child(cell)
	return cell


## How big the rings are on a screen `view` in size, the same on every
## screen with a stat panel (Gifts, Projects), so the panels match. Three
## always fit across, even on a phone.
static func ring_size(view: Vector2) -> float:
	return clampf(minf(view.y * 0.12, view.x * 0.22), 56.0, 104.0)


## Fills every ring in the panel up from empty, and fades the pictures
## behind numbers (icon_value) in.
func sweep() -> void:
	for cell in _grid.get_children():
		for c in cell.get_children():
			if c is ProgressRing:
				c.sweep()
			elif c.has_meta("icon_value"):
				var pic: CanvasItem = c.get_meta("icon_value")
				pic.modulate.a = 0.0
				Motion.fade(pic, 1.0, Motion.SLOW)


## A number over a big line icon in `colour`, faded back, the size of a
## ring: for a number that isn't a share of anything (a ring round it would
## always be full). E.g. the hours focused over a clock.
static func icon_value(icon: String, text: String, colour: Color, diameter: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(diameter, diameter)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = Icons.texture(icon, int(diameter * 0.96), Color(colour, ICON_FADE), 1.6)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(pic)
	holder.set_meta("icon_value", pic)
	var words := UI.label(text, int(diameter * 0.26), UI.INK, true, 600)
	# Long words get smaller to stay inside, as in a ring.
	if text.length() > 4:
		words.add_theme_font_size_override("font_size", int(diameter * 0.26 * 4.0 / text.length()))
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A soft halo in the card's colour, so the lines behind never cut
	# through the number.
	words.add_theme_color_override("font_outline_color", UI.SURFACE)
	words.add_theme_constant_override("outline_size", 8)
	holder.add_child(words)
	return holder


## A filled circle in `colour` with a white icon in it, for a cell whose
## number isn't a share of anything.
static func badge(icon: String, colour: Color, diameter: int = 52) -> Control:
	var p := UI.panel(colour, 999, 0)
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UI.icon_rect(icon, int(diameter * 0.5), UI.ON_COLOUR))
	return p
