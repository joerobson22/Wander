extends Control
## Focus ended: what you see when the app opens after being closed in the
## middle of a walk. The walk stopped when the app did. You and your pet
## stand still where you were walking; the sky darkens, the camera moves in
## and you both slowly hang your heads. The time still counts, but there's no gift. The home button
## goes back to the focus screen.
## params: {"session": FocusSession, "biome": place id}

const SHEET_ALPHA := 0.4
## How far the camera moves in on the two of you.
const ZOOM := 1.8

var params := {}

## The scene the camera moves over: scenery, you and your pet, the growth.
var _stage := Control.new()
var _scenery: Scenery
var _actors := Control.new()
var _walker: CharacterView
var _animal: AnimalView
var _sheet := ColorRect.new()
var _words: Array[Control] = []
var _home: Button


func _ready() -> void:
	var session: FocusSession = params.get("session")
	var pet := App.state.pet(session.pet_id) if session else null
	Audio.ambience("")

	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_scenery = Scenery.new()
	_scenery.biome = Content.biome(str(params.get("biome", "lake")))
	_scenery.scroll = App.rng.randf_range(0.0, 50000.0)
	_scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_scenery)
	_actors.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_actors.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_actors)
	_walker = CharacterView.new()
	_walker.holding_lead = false
	_actors.add_child(_walker)
	if pet:
		_animal = AnimalView.new()
		_animal.animal_id = pet.animal_id
		_animal.colours = pet.colours
		_actors.add_child(_animal)
	_scenery.front_into(_stage)
	_sheet.color = Color(0, 0, 0, 0)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)

	_build_words(session, pet)
	resized.connect(_layout)
	_layout()
	_play.call_deferred()


func go_back() -> void:
	App.go("home")


func _layout() -> void:
	_stage.size = size
	var unit := minf(size.x, size.y) / 720.0
	var feet := _scenery.path_y()
	var x := size.x * (0.3 if size.x < size.y else 0.38)
	_walker.scale = Vector2(unit, unit)
	_walker.position = Vector2(x, feet)
	if _animal:
		_animal.scale = Vector2(unit, unit)
		_animal.position = Vector2(x + 150.0 * unit, feet + 4.0 * unit)
	# Tall plants keep out of the way of the two of you.
	_scenery.front_gap = Vector2(x - 60.0 * unit, x + 260.0 * unit)
	if _stage.scale.x >= ZOOM - 0.001:
		_stage.position = _zoomed_position()


## Where the stage goes so the camera, moved in, has the two of you in the
## middle of the lower half.
func _zoomed_position() -> Vector2:
	var unit := minf(size.x, size.y) / 720.0
	var focus := _walker.position + Vector2(85.0 * unit, -60.0 * unit)
	return Vector2(size.x * 0.5, size.y * 0.66) - focus * ZOOM


func _build_words(session: FocusSession, pet_data: PetData) -> void:
	var insets := UI.safe_insets(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24 + int(insets["left"]))
	margin.add_theme_constant_override("margin_right", 24 + int(insets["right"]))
	margin.add_theme_constant_override("margin_top", 46 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 24 + int(insets["bottom"]))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col := UI.vbox(6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var seconds := session.focus_seconds if session else 0
	var pet := Content.pet_called(pet_data)
	var title := _word(UI.label(Text.t("ended.title"), 40, UI.ON_DARK, true, 600))
	col.add_child(title)
	var time := _word(UI.label(SessionClock.format(seconds), 24, UI.ON_DARK_SOFT, true, 500))
	col.add_child(time)
	var why := _word(UI.para(Text.t("ended.why", {"pet": pet}), 16, UI.ON_DARK))
	why.custom_minimum_size.x = minf(440.0, size.x - 48.0)
	why.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(why)
	var counted := Text.t("ended.too_short") if seconds < 60 else Text.t("ended.counted", {"time": Stats.format_duration(seconds)})
	var after := _word(UI.para(counted, 15, UI.ON_DARK_SOFT))
	after.custom_minimum_size.x = why.custom_minimum_size.x
	after.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(after)
	_words = [title, time, why, after]
	for w in _words:
		w.modulate.a = 0.0
	col.add_child(UI.spacer(true))

	var bottom := UI.hbox()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(UI.spacer())
	_home = UI.round_button("home", Text.t("common.home"), go_back, Color.WHITE, UI.ACCENT.darkened(0.2), 64)
	_home.modulate.a = 0.0
	_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_home)
	col.add_child(bottom)


## Centred light text with a soft shadow.
func _word(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The sky darkens and their heads drop, then the words and the way home.
func _play() -> void:
	var t := Motion.tween(self, "ended")
	t.set_parallel(true)
	t.tween_property(_sheet, "color:a", SHEET_ALPHA, Motion.time(1.0))
	t.tween_property(_stage, "scale", Vector2.ONE * ZOOM, Motion.time(1.6))
	t.tween_property(_stage, "position", _zoomed_position(), Motion.time(1.6))
	t.tween_property(_walker, "sad", 1.0, Motion.time(1.4)).set_delay(Motion.time(0.3))
	if _animal:
		t.tween_property(_animal, "sad", 1.0, Motion.time(1.4)).set_delay(Motion.time(0.5))
	await get_tree().create_timer(Motion.time(0.8)).timeout
	for i in _words.size():
		Motion.enter(_words[i], i * 0.14)
	await get_tree().create_timer(Motion.time(0.6 + _words.size() * 0.14)).timeout
	_home.mouse_filter = Control.MOUSE_FILTER_STOP
	Motion.fade(_home, 1.0, Motion.SLOW)
