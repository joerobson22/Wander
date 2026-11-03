class_name ChooseFocus
extends Control
## Choose what to focus on, standing in the place you're about to walk.
## The buttons at the top pick where this pet walks (each pet remembers its
## own, starting in its animal's home); locked places are greyed out under a
## padlock, and tapping one shows what unlocks it. They wrap onto a second
## row where there isn't room for one. Under them, the project pill says
## what you're working on: tap it for your ongoing projects, or to start a
## new one. Then the pet's name; swipe left and right through your pets,
## which stand on the path with their kind, time walked and adoption date
## underneath (the one in the middle walks on the spot), and tap one to head
## out. At the bottom, the red bin rehomes that pet after a check, and the
## sort menu on the right orders the pets. The × at the top left goes back
## home, and the paw at the top right switches to adopting a new pet: give
## it a name (filled in with its kind), scroll up and down through the
## animals (locked ones are grey under a padlock, say what unlocks them, and
## tapping one shows how far along you are) and pick its three colours.
## While adopting the bottom buttons go away, the × cancels and the paw
## turns into a tick that adopts it.
## params: {"from": where the opening circle grew from}

## The project list: each row's height, the gap between rows, how many rows
## show before it scrolls, and the rows' corner rounding.
const PROJECT_ROW := 56
const PROJECT_GAP := 6
const PROJECTS_SHOWN := 3
const PROJECT_RADIUS := 16
## How tall pets stand in the chooser.
const PET_HEIGHT := 200.0
## The place buttons: each one's side, the gap between them and the glass
## panel's padding round them.
const PLACE_BUTTON := 42
const PLACE_GAP := 4
const PLACE_PAD := 6
## The bin: how much it grows under the pointer, and how long that takes.
const BIN_GROW := 1.05
const BIN_GROW_TIME := 0.2

static func sorts() -> Array:
	return [
		["focus", Text.t("sort.focus_time")], ["recent", Text.t("sort.recently_walked")],
		["adopted", Text.t("sort.recently_adopted")], ["type", Text.t("sort.pet_type")],
	]
const SORT_KEY := "pet_sort"

var params := {}

## Your pets, in the order picked from the sort menu.
var _pet_list: Array[PetData] = []
var _adopting := false
var _draft: PetData
## The name box still holds the name it was filled in with, so it follows
## the animal until you type your own.
var _name_is_default := true
var _scenery: Scenery
## Every place still showing, back to front: the last is the one picked,
## fading in over the others, which go once it's fully in.
var _stack: Array[Scenery] = []
## The place buttons' highlight, in the grid's space; it slides from one
## button to the next.
var _marker := Rect2()
var _marker_moving := false
var _marker_target := Rect2()
var _shade := _Shade.new()
var _pick := Control.new()
var _adopt_layer := Control.new()
var _pets: Carousel
var _places: Dictionary = {}  # place id -> its button
var _place_grid: GridContainer
var _place_name: Label
var _words: VBoxContainer
var _project_pill: Button
var _pet_line: Label
var _hint: Label
## Under the pet: its kind, how long it has walked and when you adopted it.
var _under: Label
var _animals: Carousel
var _animal_title: Label
var _animal_hint: Label
var _pet_edit: LineEdit
var _swatches: Array[Button] = []
var _swatch_row: Control
var _close: Button
var _top: Control
var _left: Button
var _sort: Dropdown
var _bottom: Control
## The paw at the top right; a tick while adopting.
var _new: Button
## True once a pet's been picked and the screen is fading out for the walk.
var _leaving := false
## The place picked (see _place_id()).
var _place := ""


func _ready() -> void:
	_show_place(_place_id())
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for layer in [_pick, _adopt_layer]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	_adopt_layer.visible = false

	var insets := UI.safe_insets(self)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 12 + int(insets["left"]))
	top.add_theme_constant_override("margin_right", 18 + int(insets["right"]))
	top.add_theme_constant_override("margin_top", 14 + int(insets["top"]))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_top = top
	var row := UI.hbox()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	# Just the ×, no button round it (see _style_top).
	_close = UI.ghost_button("close", Text.t("common.back"), _on_close, UI.ON_DARK, 48, 26)
	row.add_child(_close)
	row.add_child(UI.spacer())
	_new = UI.round_button("paw_add", Text.t("choose_focus.new_pet"), _on_new, UI.SURFACE, UI.INK, 48)
	row.add_child(_new)

	var bottom := MarginContainer.new()
	_bottom = bottom
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.add_theme_constant_override("margin_left", 16 + int(insets["left"]))
	bottom.add_theme_constant_override("margin_right", 16 + int(insets["right"]))
	bottom.add_theme_constant_override("margin_bottom", 22 + int(insets["bottom"]))
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var buttons := UI.hbox()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(buttons)
	_left = _bin_button()
	buttons.add_child(_left)
	buttons.add_child(UI.spacer())
	_sort = Dropdown.for_setting(sorts(), SORT_KEY, sorts()[0][0], true).on_scenery(56)
	_sort.opens_up = true
	_sort.chosen.connect(func(_by, _reversed): _build_pick(_current_pet_id()))
	buttons.add_child(_sort)

	_build_pick()
	_style_top(false)
	resized.connect(_layout)
	_layout.call_deferred()
	Audio.ambience(_scenery.ambience())


## Back to the focus screen, from either mode.
func go_back() -> void:
	App.go("home")


## The × cancels adopting, or goes back home.
func _on_close() -> void:
	if _adopting:
		_show_mode(false)
	else:
		go_back()


## The paw starts adopting; as a tick it adopts.
func _on_new() -> void:
	if _adopting:
		_adopt()
	else:
		_start_adopting()


# --- The place ---------------------------------------------------------------

## The place picked: it opens on where you last focused (App.focus_place),
## and only changes when you pick one, or adopt a pet (to its home).
## Swiping between pets leaves it where it is.
func _place_id() -> String:
	if _place == "":
		_place = App.focus_place()
	return _place if App.can_walk_in(_place) else "lake"


## A place's name.
static func _place_title(id: String) -> String:
	return str(Content.biome(id).get("name", ""))


## The pet in the middle (before the pets are laid out, the one the screen
## will open on), or null with none.
func _current_pet() -> PetData:
	if not is_instance_valid(_pets):
		var active := App.state.active_pets()
		for p in active:
			if p.id == str(App.state.settings.get("last_pet", "")):
				return p
		return active[0] if not active.is_empty() else null
	if _pet_list.is_empty():
		return null
	return _pet_list[clampi(_pets.index, 0, _pet_list.size() - 1)]


func _current_pet_id() -> String:
	var p := _current_pet()
	return p.id if p else ""


## Puts the place's scenery behind everything, fading in over whatever is
## showing now, from however far any earlier fade had got: picking places
## quickly never makes one jump. Going back to the place still showing
## underneath fades away what's over it instead.
func _show_place(id: String) -> void:
	var old := _scenery
	if _stack.size() > 1 and str(_stack[0].biome.get("id", "")) == id:
		_scenery = _stack[0]
		for i in range(1, _stack.size()):
			var going := _stack[i]
			Motion.fade(going, 0.0, Motion.style.place_fade * going.modulate.a).tween_callback(going.queue_free)
		_stack.resize(1)
		Motion.to(_scenery, "front_tint:a", 1.0, Motion.style.place_fade)
		_attach_front()
		Audio.ambience(_scenery.ambience())
		_layout()
		return
	_scenery = Scenery.new()
	_scenery.biome = Content.biome(id)
	_scenery.scroll = old.scroll if old else App.rng.randf_range(0.0, 50000.0)
	_scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scenery)
	move_child(_scenery, old.get_index() + 1 if old else 0)
	_stack.append(_scenery)
	_attach_front()
	if old:
		var coming := _scenery
		coming.modulate.a = 0.0
		Motion.fade(coming, 1.0, Motion.style.place_fade).tween_callback(_drop_below.bind(coming))
		# The places underneath are still there, but not their growth in
		# front of the pets.
		for under in _stack:
			if under != coming:
				Motion.to(under, "front_tint:a", 0.0, Motion.style.place_fade)
		Audio.ambience(_scenery.ambience())
	_layout()


## Once `top` has fully faded in, the places under it go.
func _drop_below(top: Scenery) -> void:
	var at := _stack.find(top)
	if at <= 0:
		return
	for i in at:
		_stack[i].queue_free()
	_stack = _stack.slice(at)


## The place's front growth goes over the pets (a still scene, but you're
## standing in it) and under the words. Tall plants keep clear of the pet in
## the middle, the one you're choosing.
func _attach_front() -> void:
	if not is_instance_valid(_pets) or not is_instance_valid(_scenery):
		return
	if _scenery.front.get_parent() != _pick:
		_scenery.front_into(_pick)
	_pick.move_child(_scenery.front, _pets.get_index() + 1)


func _pick_place(id: String) -> void:
	if not App.is_unlocked("place", id):
		# Locked: it just wiggles. What unlocks it is on the level rewards.
		Motion.wiggle(_places[id])
		Audio.play("locked", 0.8, -8.0, "pop")
		return
	if id == _place_id():
		return
	_place = id
	_show_place(id)
	_refresh_places(true)


func _place_buttons() -> Control:
	var panel := UI.panel(UI.SURFACE, 22, PLACE_PAD)
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).shadow_color = UI.SHADOW
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 10
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).shadow_offset = Vector2(0, 3)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_place_grid = GridContainer.new()
	_place_grid.add_theme_constant_override("h_separation", PLACE_GAP)
	_place_grid.add_theme_constant_override("v_separation", PLACE_GAP)
	panel.add_child(_place_grid)
	# The highlight under the picked place, drawn under the buttons, as the
	# app's map does; it stays with its button as the grid lays out again.
	_marker = Rect2()
	_place_grid.draw.connect(func():
		if _marker.size != Vector2.ZERO:
			_place_grid.draw_style_box(UI.box(UI.ACCENT_SOFT, Color.TRANSPARENT, 14), _marker))
	_place_grid.sort_children.connect(func(): _move_marker.call_deferred(_marker_moving))
	_places.clear()
	for b in Content.biomes:
		var id: String = b["id"]
		var button := Button.new()
		button.custom_minimum_size = Vector2(PLACE_BUTTON, PLACE_BUTTON)
		button.accessibility_name = b["name"]
		button.pressed.connect(_pick_place.bind(id))
		_place_grid.add_child(button)
		_places[id] = button
		# While it's locked the place's icon fades back under a padlock
		# badge in the corner (see _refresh_places).
		var lock := UI.panel(UI.INK_SOFT, 999, 3)
		lock.name = "Lock"
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.add_child(UI.icon_rect("lock", 11, UI.SURFACE))
		button.add_child(lock)
		lock.position = Vector2(PLACE_BUTTON - 19, PLACE_BUTTON - 19)
	_fit_place_grid()
	_refresh_places()
	return panel


## As many place buttons to a row as fit across the screen, shared out
## evenly between the rows (so 11 on a phone go 6 and 5, not 7 and 4).
func _fit_place_grid() -> void:
	if not is_instance_valid(_place_grid):
		return
	var count := _places.size()
	var insets := UI.safe_insets(self)
	var room: float = size.x - 32.0 - PLACE_PAD * 2.0 - float(insets["left"]) - float(insets["right"])
	var fit := maxi(1, floori((room + PLACE_GAP) / float(PLACE_BUTTON + PLACE_GAP)))
	var rows := ceili(count / float(fit))
	_place_grid.columns = maxi(1, ceili(count / float(maxi(rows, 1))))


## Shows which place is picked: its icon goes green as the highlight slides
## under it (with `slide`; else it's simply there).
func _refresh_places(slide: bool = false) -> void:
	var current := _place_id()
	for id in _places:
		var button: Button = _places[id]
		var unlocked := App.is_unlocked("place", id)
		var on: bool = id == current
		var ink := UI.ACCENT if on else Color(UI.INK_SOFT, 1.0 if unlocked else 0.45)
		button.get_node("Lock").visible = not unlocked
		button.accessibility_name = _place_title(id) if unlocked else Text.t("choose_focus.place_locked_name", {"place": _place_title(id), "rule": Unlocks.describe(Content.unlock_rule("place", id))})
		UI.style_button(button, Color.TRANSPARENT, ink, 14)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			(button.get_theme_stylebox(state) as StyleBoxFlat).set_content_margin_all(0)
		button.icon = Icons.place(Content.biome(id), 22)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _place_name:
		_place_name.text = str(Content.biome(current).get("name", "")).to_upper()
	_move_marker(slide)


## Sends the highlight to the picked place's button, sliding there in the
## time the places take to fade (or jumping, when `slide` is off).
func _move_marker(slide: bool) -> void:
	if not is_instance_valid(_place_grid) or not _places.has(_place_id()):
		return
	var target: Rect2 = (_places[_place_id()] as Control).get_rect()
	if target.size == Vector2.ZERO:
		return
	if not slide or _marker.size == Vector2.ZERO or not is_inside_tree():
		Motion.tween(_place_grid, "marker").kill()
		_marker_moving = false
		_set_marker(target)
		return
	if _marker_moving and _marker_target.is_equal_approx(target):
		return
	_marker_target = target
	_marker_moving = true
	var t := Motion.method(_place_grid, "marker", _set_marker, _marker, target, Motion.style.place_fade)
	t.tween_callback(func(): _marker_moving = false)


func _set_marker(r: Rect2) -> void:
	_marker = r
	if is_instance_valid(_place_grid):
		_place_grid.queue_redraw()


# --- Choosing ----------------------------------------------------------------

## Your pets in the order the sort menu says. Focus time and the two
## "recently"s put the most first; type follows the cast. Ties go to the
## newest adopted. `reversed` flips the whole order.
static func sort_pets(pets: Array, by: String, reversed: bool) -> Array:
	var order := {}
	for i in Content.animals.size():
		order[Content.animals[i]["id"]] = i
	var key := func(p: PetData) -> Array:
		var first: Array
		match by:
			"focus":
				first = [-App.state.pet_seconds(p.id)]
			"recent":
				first = [-p.last_walked_unix]
			"type":
				first = [order.get(p.animal_id, 99)]
			_:
				first = []
		return first + [-p.adopted_unix, p.name.to_lower()]
	var keys := {}
	for p in pets:
		keys[p] = key.call(p)
	var out := pets.duplicate()
	out.sort_custom(func(a, b): return keys[a] < keys[b])
	if reversed:
		out.reverse()
	return out


## Your ongoing projects, the one walked for most recently first (then the
## newest).
static func project_choices() -> Array[ProjectData]:
	var out := App.state.active_projects()
	out.sort_custom(func(a, b):
		var ka := maxi(a.last_walked_unix, a.created_unix)
		var kb := maxi(b.last_walked_unix, b.created_unix)
		return ka > kb if ka != kb else a.name.to_lower() < b.name.to_lower())
	return out


## The project this walk is for: the last one picked if it's still going,
## else the one most recently on the go; null with no ongoing projects.
static func current_project() -> ProjectData:
	var choices := project_choices()
	var last := str(App.state.settings.get("last_project", ""))
	for p in choices:
		if p.id == last:
			return p
	return choices[0] if not choices.is_empty() else null


func _build_pick(select_id: String = "") -> void:
	for c in _pick.get_children():
		if c.is_in_group(Scenery.FRONT_GROUP):
			continue  # belongs to its scenery, which frees it
		_pick.remove_child(c)
		c.queue_free()
	var by := str(App.state.settings.get(SORT_KEY, sorts()[0][0]))
	var reversed := bool(App.state.settings.get(SORT_KEY + "_reversed", false))
	_pet_list.assign(sort_pets(App.state.active_pets(), by, reversed))
	if select_id == "":
		select_id = str(App.state.settings.get("last_pet", ""))

	var places := UI.vbox(4)
	places.name = "Places"
	places.mouse_filter = Control.MOUSE_FILTER_IGNORE
	places.add_child(_place_buttons())
	_place_name = _shadowed(UI.label("", 12, UI.ON_DARK, false, 900))
	_place_name.add_theme_constant_override("outline_size", 0)
	places.add_child(_place_name)
	_refresh_places()
	_pick.add_child(places)

	_words = UI.vbox(4)
	_words.name = "Words"
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pick.add_child(_words)
	_project_pill = _make_project_pill()
	_words.add_child(_project_pill)
	_refresh_project_pill()
	_left.disabled = _pet_list.is_empty()
	# Nothing to sort with fewer than two pets.
	_sort.visible = _pet_list.size() > 1
	_set_icon(_left, "bin", Text.t("choose_focus.rehome_pet"))
	if _pet_list.is_empty():
		_words.add_child(_shadowed(UI.label(Text.t("choose_focus.no_pets_title"), 30, UI.ON_DARK, true, 600)))
		var p := _shadowed(UI.label(Text.t("choose_focus.no_pets_body"), 15, UI.ON_DARK_SOFT, false, 700))
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_words.add_child(p)
		_pets = null
		_layout()
		return

	_pet_line = _shadowed(UI.label("", 32, UI.ON_DARK, true, 600))
	_pet_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.add_child(_pet_line)
	_hint = _shadowed(UI.label("", 13, UI.ON_DARK_SOFT, false, 700))
	_words.add_child(_hint)
	_refresh_hint()
	_under = _shadowed(UI.label("", 14, UI.ON_DARK, false, 800))
	_under.name = "Under"
	_pick.add_child(_under)

	_pets = Carousel.new()
	# As wide as the screen, so nothing spills sideways; unclipped, so a
	# tall pet shows in full above the band.
	_pets.clip_contents = false
	_pets.spacing = clampf(size.x * 0.44, 170.0, 300.0)
	_pick.add_child(_pets)
	var items: Array[Control] = []
	var start := 0
	for i in _pet_list.size():
		items.append(_pet(_pet_list[i].animal_id, _pet_list[i].colours, PET_HEIGHT))
		if _pet_list[i].id == select_id:
			start = i
	_pets.changed.connect(_on_pet_changed)
	_pets.activated.connect(_start_walk)
	_pets.set_items(items, start)
	# The pets stand at the back, under the growth and the words.
	_pick.move_child(_pets, 0)
	_attach_front()
	_on_pet_changed(start)
	_layout()
	_pets.grab_focus.call_deferred()


## Places along the top; the words in the sky; the pets with their feet on
## the scenery's path.
func _layout() -> void:
	if not is_instance_valid(_scenery):
		return
	var insets := UI.safe_insets(self)
	var places := _pick.get_node_or_null("Places") as Control
	_fit_place_grid()
	if places:
		places.size = places.get_combined_minimum_size()
		places.position = Vector2((size.x - places.size.x) * 0.5, 72.0 + insets["top"])
	var path := _scenery.path_y()
	_fit_project_pill()
	if is_instance_valid(_words):
		var w := minf(520.0, size.x - 40.0)
		_words.size = Vector2(w, 0)
		_words.size = Vector2(w, _words.get_combined_minimum_size().y)
		# Just under the place buttons.
		_words.position = Vector2((size.x - w) * 0.5, (places.position.y + places.size.y + 12.0) if places else 140.0)
	if is_instance_valid(_under):
		_under.size = Vector2(size.x, _under.get_combined_minimum_size().y)
		_under.position = Vector2(0, path + 16.0)
	_scenery.front_gap = Vector2(size.x * 0.5 - PET_HEIGHT * 0.8, size.x * 0.5 + PET_HEIGHT * 0.8)
	if is_instance_valid(_pets):
		var band := PET_HEIGHT * 1.15
		_pets.size = Vector2(size.x, band)
		_pets.position = Vector2(0, path - 0.36 * PET_HEIGHT - band * 0.5)


func _on_pet_changed(i: int) -> void:
	for j in _pets.items.size():
		(_pets.items[j].get_meta("view") as AnimalView).walking = j == i
	var p := _pet_list[i]
	App.state.settings["last_pet"] = p.id
	_pet_line.text = p.name
	_under.text = Text.t("choose_focus.pet_under", {
		"kind": Content.animal(p.animal_id).get("name", ""),
		"time": Stats.format_duration(App.state.pet_seconds(p.id)),
		"date": Stats.format_date(p.adopted_unix, App.tz_bias()),
	})
	Motion.pop(_pet_line, 0.04, 0.25)
	_layout()


func _start_walk(i: int) -> void:
	var project := current_project()
	if project == null:
		# Nothing to walk for yet: say so on the pill, and offer one.
		Motion.shake(_project_pill, 6.0)
		_open_projects()
		return
	_head_out(i, project)


## Heading out: everything on the screen fades away but the pet you picked,
## which walks over to where it stands on the walk. Then the walk takes
## over in this same place, where your character walks in to join it (see
## walk.gd), and the clock starts once you set off together.
func _head_out(i: int, project: ProjectData) -> void:
	if _leaving:
		return
	_leaving = true
	var p := _pet_list[i]
	# The walk is built underneath while the pet steps over, so it's fully
	# drawn when it takes over.
	var walk := {"intro": true, "instant": true, "project": project.id, "pet": p.id,
		"place": _place_id(), "scroll": _scenery.scroll, "prepared": true}
	App.prepare("walk", walk)
	# Nothing more can be tapped.
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	var fading: Array[CanvasItem] = [_top, _bottom, _shade, _words]
	for n in ["Places", "Under"]:
		var c := _pick.get_node_or_null(n) as CanvasItem
		if c:
			fading.append(c)
	for c in fading:
		Motion.fade(c, 0.0, Motion.style.leave_fade)
	for j in _pets.items.size():
		if j != i:
			Motion.fade(_pets.items[j], 0.0, Motion.style.leave_fade)
	# The pet steps out of the chooser (its shadow fades) and over to its
	# place on the path, at the walk's size.
	var stage := _pets.items[i]
	var view: AnimalView = stage.get_meta("view")
	var held := view.get_global_transform()
	view.reparent(self, false)
	view.global_position = held.origin
	view.scale = held.get_scale()
	move_child(view, _pick.get_index())
	Motion.fade(stage, 0.0, Motion.style.leave_fade)
	_scenery.front_gap = Vector2.ZERO
	var spot := walk_spots(size, _scenery.path_y())
	var to: Vector2 = spot["animal"]
	var unit: float = spot["unit"]
	var left := to.x < view.position.x - 1.0
	view.walking = true
	if left:
		view.scale.x = -absf(view.scale.x)
	var t := Motion.tween(view, "head_out")
	t.set_parallel(true)
	t.tween_property(view, "position", to, Motion.time(Motion.style.pet_to_path))
	t.tween_property(view, "scale", Vector2(-unit if left else unit, unit), Motion.time(Motion.style.pet_to_path))
	await t.finished
	view.walking = false
	if left:
		# Facing the way the walk goes again.
		var turn := Motion.tween(view, "turn")
		turn.tween_property(view, "scale:x", unit, Motion.time(0.2))
		await turn.finished
	App.go("walk", walk)


## Where the walk puts you and your pet on a `view` sized screen whose path
## is at `feet`: {walker, animal, unit}. Shared with walk.gd, so heading out
## ends exactly where the walk begins.
static func walk_spots(view: Vector2, feet: float) -> Dictionary:
	var unit := minf(view.x, view.y) / 720.0
	var x := view.x * (0.3 if view.x < view.y else 0.38)
	return {"walker": Vector2(x, feet), "animal": Vector2(x + 170.0 * unit, feet + 4.0 * unit), "unit": unit}


func _on_left() -> void:
	var p := _pet_list[_pets.index]
	Modal.confirm(Text.t("choose_focus.rehome_title", {"pet": p.name}),
		Text.t("choose_focus.rehome_body", {"pet": p.name}),
		Text.t("choose_focus.rehome"), "danger").closed.connect(func(ok):
			if ok:
				var next := _neighbour_id(p.id)
				App.rehome_pet(p.id)
				Toast.show_text(Text.t("choose_focus.rehomed", {"pet": p.name}), "paw")
				_build_pick(next))


## The pet that should be in the middle once this one's gone.
func _neighbour_id(id: String) -> String:
	var i := -1
	for j in _pet_list.size():
		if _pet_list[j].id == id:
			i = j
	if i + 1 < _pet_list.size():
		return _pet_list[i + 1].id
	return _pet_list[i - 1].id if i > 0 else ""


# --- The project ---------------------------------------------------------------

## A paper pill with the project's name and a little arrow, so it reads as
## something to open.
func _make_project_pill() -> Button:
	var b := Button.new()
	UI.style_button(b, UI.SURFACE, UI.INK, 999, true)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		sb.content_margin_left = 16
		sb.content_margin_right = 14
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	b.custom_minimum_size.y = 40
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_constant_override("h_separation", 8)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_open_projects)
	return b


func _refresh_project_pill() -> void:
	var p := current_project()
	if p:
		_project_pill.text = p.name
		_project_pill.icon = Icons.texture("sort_down", 14, Color.WHITE, 2.6)
		_project_pill.accessibility_name = Text.t("choose_focus.project_named", {"project": p.name})
	else:
		_project_pill.text = Text.t("choose_focus.new_project")
		_project_pill.icon = Icons.texture("plus", 14, Color.WHITE, 2.6)
		_project_pill.accessibility_name = _project_pill.text
	_fit_project_pill()


## Long project names stop short of the screen's edges, trimmed with "…".
func _fit_project_pill() -> void:
	if not is_instance_valid(_project_pill) or size.x <= 0.0:
		return
	# Measured at full length: a button that trims its words to fit asks
	# for no room for them at all.
	_project_pill.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_project_pill.clip_text = false
	_project_pill.custom_minimum_size.x = 0.0
	var room := minf(460.0, size.x - 48.0)
	if _project_pill.get_combined_minimum_size().x > room:
		_project_pill.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_project_pill.clip_text = true
		_project_pill.custom_minimum_size.x = room


func _refresh_hint() -> void:
	if is_instance_valid(_hint):
		_hint.text = Text.t("choose_focus.tap_to_walk" if current_project() else "choose_focus.pick_project_first")


## Your ongoing projects, most recently worked on first, each with its time
## so far; tap one to walk for it. The popup is always the same size: the
## title and "New project" stay put and the list scrolls between them,
## three projects tall. Swipe a project just as on the Projects screen: left
## to right deletes it, right to left completes it.
func _open_projects() -> void:
	var m := Modal.open(420)
	m.header.add_child(m.heading_row(Text.t("choose_focus.projects_title")))
	var list := UI.vbox(PROJECT_GAP)
	var scroll := UI.scroll_area()
	# Exactly three rows tall, with a scroll bar beside them when there are
	# more (the list glides, as every list does: SmoothScroll).
	scroll.custom_minimum_size.y = PROJECT_ROW * PROJECTS_SHOWN + PROJECT_GAP * (PROJECTS_SHOWN - 1)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var empty := UI.label(Text.t("choose_focus.no_projects"), 15, UI.INK_FAINT, false, 700)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var area := Control.new()
	area.custom_minimum_size.y = scroll.custom_minimum_size.y
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(scroll)
	area.add_child(empty)
	m.body.add_child(area)
	# Swipes play out before the list refills; refills from elsewhere (an
	# undo) wait for them too.
	var busy := [false]
	var fill := func():
		for c in list.get_children():
			list.remove_child(c)
			c.queue_free()
		var current := current_project()
		for p in project_choices():
			list.add_child(_project_row(p, current != null and p.id == current.id, m, busy))
		empty.visible = list.get_child_count() == 0
	fill.call()
	var refill := func():
		if not busy[0] and is_instance_valid(list):
			fill.call()
	App.state_changed.connect(refill)
	# The list goes when the popup closes or turns into the new project form.
	list.tree_exiting.connect(func():
		if App.state_changed.is_connected(refill):
			App.state_changed.disconnect(refill))
	var add := UI.button(Text.t("choose_focus.new_project"), _new_project.bind(m), "accent")
	add.icon = Icons.texture("plus", 18, Color.WHITE, 2.6)
	m.footer.add_child(add)
	m.closed.connect(func(_r):
		if is_instance_valid(_project_pill):
			_refresh_project_pill()
			_refresh_hint()
			_layout())


## One project in the list: its name and time, filled in when it's the one
## picked. Tap to pick it; swipe it like a Projects screen panel.
func _project_row(p: ProjectData, on: bool, m: Modal, busy: Array) -> SwipeRow:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = PROJECT_ROW
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.accessibility_name = p.name
	# A swiping row doesn't grow under the pointer; it shades instead.
	panel.set_meta("no_grow", true)
	var fill := UI.SURFACE_SOFT if on else UI.SURFACE
	var styles := UI.button_styles(fill, PROJECT_RADIUS)
	panel.add_theme_stylebox_override("panel", styles["normal"])
	panel.mouse_entered.connect(func(): panel.add_theme_stylebox_override("panel", styles["hover"]))
	panel.mouse_exited.connect(func(): panel.add_theme_stylebox_override("panel", styles["normal"]))
	var inside := UI.hbox(10)
	var title := UI.trimmed(p.name, 16, UI.INK, false, 800)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inside.add_child(title)
	var time := UI.label(Stats.format_duration(App.state.project_seconds(p.id)), 14, UI.INK_SOFT, false, 700)
	time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inside.add_child(time)
	panel.add_child(inside)
	UI.ignore_mouse(inside)
	Press.attach(panel).tapped.connect(func():
		App.set_setting("last_project", p.id)
		m.close())
	var row := ProjectSwipes.row(panel, p)
	row.radius = PROJECT_RADIUS
	row.swiped.connect(func(direction: int):
		if busy[0]:
			row.spring_back()
			return
		busy[0] = true
		await ProjectSwipes.act(direction, row, p.id, true, false)
		busy[0] = false
		if is_instance_valid(row) and row.is_inside_tree():
			App.state_changed.emit())
	return row


## Swaps the project list for a name box and a "Create project" button.
func _new_project(m: Modal) -> void:
	for part in [m.header, m.body, m.footer]:
		for c in part.get_children():
			part.remove_child(c)
			c.queue_free()
	m.footer.visible = false
	m.header.add_child(m.heading_row(Text.t("choose_focus.new_project")))
	var edit := LineEdit.new()
	edit.placeholder_text = Text.t("choose_focus.project_placeholder")
	edit.max_length = 40
	edit.custom_minimum_size.y = 50
	m.body.add_child(edit)
	var create := func():
		var title := edit.text.strip_edges()
		if title == "":
			edit.placeholder_text = Text.t("choose_focus.name_first")
			Motion.shake(edit)
			edit.grab_focus()
			return
		var p := ProjectData.new()
		p.name = title
		App.add_project(p)
		App.set_setting("last_project", p.id)
		Toast.show_text(Text.t("choose_focus.project_started", {"project": title}), "check")
		m.close()
	m.body.add_child(UI.button(Text.t("choose_focus.create_project"), create, "accent"))
	edit.text_submitted.connect(func(_t): create.call())
	edit.grab_focus.call_deferred()


# --- Adopting ----------------------------------------------------------------

func _start_adopting() -> void:
	if _adopting:
		return
	_draft = PetData.new()
	_name_is_default = true
	_build_adopt()
	_show_mode(true)


## Fades between choosing (scenery) and adopting (the form over a soft sheet).
func _show_mode(adopting: bool, select_id: String = "") -> void:
	_adopting = adopting
	var hide_layer := _pick if adopting else _adopt_layer
	var show_layer := _adopt_layer if adopting else _pick
	_new.accessibility_name = Text.t("choose_focus.adopt" if adopting else "choose_focus.new_pet")
	_close.accessibility_name = Text.t("common.cancel" if adopting else "common.back")
	if not adopting:
		_new.disabled = false
		_build_pick(select_id)
	# The bin and the sort menu at the bottom are for the pets you have.
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in [_left, _sort]:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE if adopting else Control.MOUSE_FILTER_STOP
	Motion.fade(_bottom, 0.0 if adopting else 1.0, Motion.FAST)
	_style_top(adopting)
	var t := Motion.tween(self, "mode")
	t.tween_property(hide_layer, "modulate:a", 0.0, Motion.time(Motion.FAST))
	t.tween_callback(func():
		hide_layer.visible = false
		show_layer.visible = true
		show_layer.modulate.a = 0.0)
	t.tween_property(show_layer, "modulate:a", 1.0, Motion.time(Motion.NORMAL))


func _build_adopt() -> void:
	for c in _adopt_layer.get_children():
		_adopt_layer.remove_child(c)
		c.queue_free()
	var sheet := ColorRect.new()
	sheet.color = Color(UI.BG, 0.93)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_adopt_layer.add_child(sheet)
	var insets := UI.safe_insets(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16 + int(insets["left"]))
	margin.add_theme_constant_override("margin_right", 16 + int(insets["right"]))
	margin.add_theme_constant_override("margin_top", 76 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 28 + int(insets["bottom"]))
	_adopt_layer.add_child(margin)
	var v := UI.vbox(8)
	margin.add_child(v)

	_pet_edit = _field(Text.t("choose_focus.name_pet_placeholder"), 24, 18)
	v.add_child(_pet_edit)
	_pet_edit.text_changed.connect(func(_t): _name_is_default = false)
	_pet_edit.text_submitted.connect(func(_t): _pet_edit.release_focus())

	_animals = Carousel.new()
	_animals.vertical = true
	_animals.spacing = 150.0
	_animals.side_scale = 0.62
	_animals.reach = 1.7
	_animals.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Space the animals to the room there is, so the neighbours peek in above
	# and below on short windows too.
	_animals.resized.connect(func(): _animals.spacing = clampf(_animals.size.y * 0.36, 90.0, 150.0))
	v.add_child(_animals)
	_animal_title = UI.label("", 24, UI.INK, true, 600)
	_animal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_animal_title)
	_animal_hint = UI.label("", 13, UI.INK_FAINT, false, 700)
	_animal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_animal_hint)

	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_swatches.clear()
	for k in Text.list("choose_focus.colour_roles").size():
		var cell := UI.vbox(4)
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.accessibility_name = Text.t("choose_focus.colour_name", {"role": Text.list("choose_focus.colour_roles")[k]})
		b.pressed.connect(_pick_colour.bind(k))
		cell.add_child(b)
		var l := UI.caption(Text.list("choose_focus.colour_roles")[k])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		row.add_child(cell)
		_swatches.append(b)
	v.add_child(row)
	_swatch_row = row

	var items: Array[Control] = []
	var first_open := -1
	for i in Content.animals.size():
		var a: Dictionary = Content.animals[i]
		var open := App.is_unlocked("animal", a["id"])
		items.append(_pet(a["id"], Content.animal_default_colours(a["id"]), 150.0, not open))
		if open and first_open < 0:
			first_open = i
	_animals.changed.connect(_on_animal_changed)
	_animals.activated.connect(func(i: int):
		var a: Dictionary = Content.animals[i]
		if not App.is_unlocked("animal", a["id"]):
			Motion.wiggle(_animals.items[i])
			Audio.play("locked", 0.8, -8.0, "pop"))
	_animals.set_items(items, maxi(first_open, 0))
	_on_animal_changed(_animals.index)


func _on_animal_changed(i: int) -> void:
	var a: Dictionary = Content.animals[i]
	var open := App.is_unlocked("animal", a["id"])
	if open:
		_draft.animal_id = a["id"]
		_draft.colours = Content.animal_default_colours(a["id"])
	for j in _animals.items.size():
		var view: AnimalView = _animals.items[j].get_meta("view")
		var locked: bool = _animals.items[j].get_meta("locked", false)
		view.walking = j == i and not locked
		if j == i and open:
			view.colours = _draft.colours
		elif not locked:
			view.colours = Content.animal_default_colours(Content.animals[j]["id"])
	_animal_title.text = a["name"]
	if open:
		_animal_hint.text = Text.t("choose_focus.scroll_animals")
		_animal_hint.add_theme_color_override("font_color", UI.INK_FAINT)
		if _name_is_default:
			_pet_edit.text = App.free_pet_name(a["id"])
	else:
		_animal_hint.text = Text.t("choose_focus.animal_locked", {"rule": Unlocks.describe(Content.unlock_rule("animal", a["id"]))})
		_animal_hint.add_theme_color_override("font_color", UI.INK_SOFT)
	_new.disabled = not open
	# A locked animal can't be coloured in: the colour buttons fade away, but
	# keep their space so the scroller above doesn't jump.
	for b in _swatches:
		b.disabled = not open
		b.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	Motion.fade(_swatch_row, 1.0 if open else 0.0, Motion.FAST)
	_refresh_swatches()


func _refresh_swatches() -> void:
	var parts: Array = Content.animal(_draft.animal_id).get("parts", [])
	for k in _swatches.size():
		var b := _swatches[k]
		b.visible = k < parts.size()
		var c := _draft.colours[k] if k < _draft.colours.size() else Color.WHITE
		UI.style_button(b, c, UI.INK, 999, true)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(state)
			sb.set_border_width_all(3)
			sb.border_color = UI.SURFACE


func _pick_colour(k: int) -> void:
	var start := _draft.colours[k]
	Modal.colour(Text.t("choose_focus.colour_name", {"role": Text.list("choose_focus.colour_roles")[k]}), start, _set_colour.bind(k))


func _set_colour(c: Color, k: int) -> void:
	_draft.colours[k] = c
	var view: AnimalView = _animals.items[_animals.index].get_meta("view")
	view.queue_redraw()
	_refresh_swatches()


func _adopt() -> void:
	var pet_name := _pet_edit.text.strip_edges()
	if pet_name == "":
		_pet_edit.placeholder_text = Text.t("choose_focus.name_first")
		Motion.shake(_pet_edit)
		_pet_edit.grab_focus()
		return
	_draft.name = pet_name
	App.add_pet(_draft)
	Audio.play(str(Content.animal(_draft.animal_id).get("sound", "")), 1.0, -6.0)
	# A new pet is met in its home (if you can walk there yet).
	var home := str(Content.animal(_draft.animal_id).get("home", ""))
	if App.can_walk_in(home) and home != _place_id():
		_place = home
		_show_place(home)
	_show_mode(false, _draft.id)


# --- Pieces ------------------------------------------------------------------

## The × is just a cross, with no button round it: white over the place,
## ink over the adopt form's paper. The paw is a round paper button; on the
## adopt form it turns into a solid green tick.
func _style_top(on_form: bool) -> void:
	var ink := UI.INK if on_form else UI.ON_DARK
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		_close.add_theme_color_override(state, ink)
	if on_form:
		UI.style_button(_new, UI.SUCCESS, Color.WHITE, 999, true)
		_new.icon = Icons.texture("check", 22, Color.WHITE, 3.0)
	else:
		UI.style_button(_new, UI.SURFACE, UI.INK, 999, true)
		_new.icon = Icons.texture("paw_add", 22, Color.WHITE, 2.4)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		(_new.get_theme_stylebox(state) as StyleBoxFlat).set_content_margin_all(0)


## The bin that rehomes a pet: a round paper button like the others, with a
## red bin and a red rim to say it's for something you can't undo. It eases a
## little bigger under the pointer (no shade, so nothing jumps).
func _bin_button() -> Button:
	var b := UI.round_button("bin", Text.t("choose_focus.rehome_pet"), _on_left, UI.SURFACE, UI.DANGER, 56, true)
	var styles := UI.button_styles(UI.SURFACE, 999, true)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		# Hovering keeps the resting look; only a press shades it.
		var sb: StyleBoxFlat = (styles["pressed" if state in ["pressed", "hover_pressed"] else ("disabled" if state == "disabled" else "normal")] as StyleBoxFlat).duplicate()
		if state == "focus":
			sb = styles["focus"]
		else:
			sb.set_border_width_all(3)
			sb.border_color = Color(UI.DANGER, sb.bg_color.a / maxf(UI.SURFACE.a, 0.01))
		sb.set_content_margin_all(0)
		b.add_theme_stylebox_override(state, sb)
	b.set_meta("no_grow", true)
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	var grow := func(to: float):
		if to > 1.0 and (b.disabled or App.touch_screen()):
			return
		b.pivot_offset = b.size * 0.5
		var t := Motion.tween(b, "bin_grow")
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", Vector2.ONE * to, Motion.time(BIN_GROW_TIME))
	b.mouse_entered.connect(grow.bind(BIN_GROW))
	b.mouse_exited.connect(grow.bind(1.0))
	return b


## Light text with a soft shadow, centred, so it reads over any scenery.
func _shadowed(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.32))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A centred text box for the adopt form.
func _field(placeholder: String, max_length: int, font_size: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.max_length = max_length
	e.custom_minimum_size = Vector2(minf(420.0, size.x - 48.0), 52)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.add_theme_font_size_override("font_size", font_size)
	return e


func _set_icon(b: Button, icon: String, tip: String) -> void:
	b.icon = Icons.texture(icon, int(b.custom_minimum_size.x * 0.42), Color.WHITE, 2.6)
	b.accessibility_name = tip


## An animal standing on a soft shadow, for the carousels. `locked` greys
## it out under a padlock.
func _pet(animal_id: String, colours: Array[Color], height: float, locked: bool = false) -> Control:
	var stage := _Stage.new()
	stage.custom_minimum_size = Vector2(height * 1.25, height)
	var view := AnimalView.new()
	view.animal_id = animal_id
	view.colours = colours
	stage.add_child(view)
	stage.set_meta("view", view)
	var s := minf(stage.custom_minimum_size.x / 175.0, height / 105.0) / float(Content.animal(animal_id).get("size", 1.0))
	view.scale = Vector2(s, s)
	view.position = Vector2(stage.custom_minimum_size.x * 0.44, height * 0.86)
	if locked:
		stage.set_meta("locked", true)
		var greys: Array[Color] = []
		for k in colours.size():
			greys.append(UI.NEUTRAL.lerp(UI.INK_FAINT, k * 0.3))
		view.colours = greys
		view.modulate.a = 0.75
		# A padlock on a disc over the middle of the animal.
		var badge := UI.panel(UI.SURFACE_SOFT, 999, 9)
		badge.add_child(UI.icon_rect("lock", 22, UI.INK_SOFT))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(badge)
		var side := badge.get_combined_minimum_size()
		badge.position = Vector2(stage.custom_minimum_size.x * 0.48, height * 0.5) - side * 0.5
	return stage


class _Stage extends Control:
	func _draw() -> void:
		draw_set_transform(Vector2(size.x * 0.48, size.y * 0.87), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, size.x * 0.34, Color(0.0, 0.0, 0.0, 0.16), true, -1.0, true)


## A soft darkening at the top of the scenery so the place buttons and the
## pet's name stay readable in bright daylight.
class _Shade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var dark := Color(0, 0, 0, 0.28)
		var clear := Color(0, 0, 0, 0)
		var h := size.y * 0.5
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, h), Vector2(0, h)]),
			PackedColorArray([dark, dark, clear, clear]))
