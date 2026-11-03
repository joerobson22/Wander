class_name StatPanel
extends PanelContainer
## A card of headline numbers side by side, each in an equal-width cell: a
## picture on top (a ProgressRing, or a badge() for a number that isn't a
## share of anything), an optional big value, a name, and one muted line
## under it. Gifts and Projects both use it, so their stats always match.
## On a narrow screen `columns` can wrap the cells onto more rows.

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


## Fills every ring in the panel up from empty.
func sweep() -> void:
	for cell in _grid.get_children():
		for c in cell.get_children():
			if c is ProgressRing:
				c.sweep()


## A filled circle in `colour` with a white icon in it, for a cell whose
## number isn't a share of anything.
static func badge(icon: String, colour: Color, diameter: int = 52) -> Control:
	var p := UI.panel(colour, 999, 0)
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UI.icon_rect(icon, int(diameter * 0.5), UI.ON_COLOUR))
	return p
