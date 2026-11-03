class_name GiftGrid
extends GridContainer
## Every gift you have at least one of, in rows, in the order picked from
## "Sort by" (the gifts screen and the shelf editor share the choice, so
## they always match). `make` turns each gift id into its GiftTile, so each
## place decides what its tiles do. Tiles share the width equally and are
## as tall as they're wide, so the gifts line up with the edges.

## The sort menu's setting, and what it starts as.
const SETTING := "gift_sort"
const DEFAULT := "rarity"
const GROUP := "gift_grids"

var _make: Callable


func _init(per_row: int, make: Callable) -> void:
	columns = per_row
	_make = make
	add_to_group(GROUP)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("h_separation", 8)
	add_theme_constant_override("v_separation", 8)
	refresh()


## Fills the grid again from the saved state.
func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for id in ids():
		var tile: GiftTile = _make.call(id)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.resized.connect(func(): tile.art.custom_minimum_size.y = maxf(0.0, tile.size.x - 8.0))
		add_child(tile)


## The gifts you have at least one of (a traded-away gift isn't shown), sorted.
static func ids() -> Array:
	var have: Array = App.state.inventory.keys().filter(func(id): return not Content.gift(id).is_empty() and App.state.gift_count(id) > 0)
	return Collection.sort_gifts(have, str(App.state.settings.get(SETTING, DEFAULT)), bool(App.state.settings.get(SETTING + "_reversed", false)),
		Content.gifts, Content.tables)


## The "Sort by" menu for it. A new order just re-fills the grids (every
## one, so the gifts screen and the shelf editor stay in step) rather than
## rebuilding the screen they're on.
static func sort_menu() -> Dropdown:
	var d := Dropdown.for_setting(Collection.sorts(), SETTING, DEFAULT, true)
	d.chosen.connect(func(_option, _reversed): d.get_tree().call_group(GROUP, "refresh"))
	return d

