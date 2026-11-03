extends Control
## The focus walk. Text is kept to the time, what you're working on and a
## quiet line of encouragement. The "End focus" pill in the bottom right
## ends the walk with a bong, and its small pie shows what gift is waiting
## (see GiftButton); when there is one, your pet dives into a bush and comes
## back out carrying it. The weather can be picked in the top left.
## Time on screen always comes from the session's timestamps (SessionClock),
## never from counting frames, so it stays right after the app is
## backgrounded, the laptop sleeps, or the app is killed and reopened.
## Heading out from the choose focus screen (params "intro"), the walk
## opens in the same place with your pet already standing on the path: you
## walk in from the left to join it, the lead appears with what you're
## working on, and a second later you set off together. Only then does the
## clock start: the time fades in, the encouragement types itself out word
## by word, and the buttons fade in. The encouragement changes every ten
## minutes of focus.
## params: {"from": where the opening circle grew from} for a walk already
## going, or {"intro": true, "project", "pet", "place", "scroll"} to set off.

var params := {}

## Ground pixels per second at walk speed 1.0 (at 720px tall).
const BASE_SPEED := 70.0
## The timings of setting off (walking in, the lead, the pause, typing out
## the encouragement and how often it changes) are in ui/motion.tres
## (MotionStyle), to change in the Godot editor.

var _scenery: Scenery
var _actors := Node2D.new()
var _walker: CharacterView
var _animal: AnimalView
## The bush your pet dives into (art/walk/bush.tscn, which you can change).
const BUSH := "res://art/walk/bush.tscn"
var _bush: Node2D
var _project: ProjectData
var _pet: PetData
var _hud: Control
var _timer: Label
var _title: Label
var _quote: Label
## Which encouragement shows (see _quote_key()).
var _quote_key := 0
## The buttons, which fade in once you set off.
var _buttons: Array[Control] = []
## True until you've walked in and set off (see _intro()).
var _arriving := false
var _walking_in := false
## True once you've started walking in (see begin()).
var _began := false
var _blocker: Control
var _pause: Button
var _sound: Button
var _gift: GiftButton
var _last_second := -1
var _ambience_check := 0.0
var _render_check := 0.0
## Scenery speed; eases down to 0 when the pet goes to fetch a gift.
var _pace := 1.0
var _lead_alpha := 1.0
var _finishing := false
var _done := false
var _result := {}


func _ready() -> void:
	var clock := App.state.active
	_arriving = bool(params.get("intro", false))
	if _arriving:
		_project = App.state.project(str(params.get("project", "")))
		_pet = App.state.pet(str(params.get("pet", "")))
	else:
		_project = App.state.project(clock.project_id) if clock else null
		_pet = App.state.pet(clock.pet_id) if clock else null
	if _project == null or _pet == null:
		# The project was deleted mid-walk, or there's no walk: nothing to show.
		App.cancel_walk()
		App.go.call_deferred("home", {})
		return

	_scenery = Scenery.new()
	_scenery.biome = Content.biome(str(params.get("place", "")) if _arriving else clock.biome_id)
	_scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Start somewhere different each walk (or just where you were standing).
	_scenery.scroll = float(params.get("scroll", App.rng.randf_range(0.0, 100000.0)))
	add_child(_scenery)

	add_child(_actors)
	_actors.draw.connect(_draw_lead)
	_walker = CharacterView.new()
	_actors.add_child(_walker)
	_animal = AnimalView.new()
	_animal.animal_id = _pet.animal_id
	_animal.colours = _pet.colours
	_actors.add_child(_animal)
	# The jungle's leaves and vines pass in front of you both.
	_scenery.front_into(self)

	_build_hud()
	DisplayServer.screen_set_keep_on(App.state.settings.get("keep_screen_on", true))
	resized.connect(_layout)
	_layout()
	_update_ambience()
	if _arriving:
		_intro()
		# Built out of sight while your pet steps over to the path (see
		# App.prepare()): you walk in once it's on show.
		if not bool(params.get("prepared", false)):
			begin()
		return
	_apply_paused(clock.is_paused())
	_gift.set_seconds(clock.elapsed(App.now()))
	_show_quote(false)


## Ready to set off: your pet on the path, you just off the left edge, and
## nothing on show yet but the scene.
func _intro() -> void:
	_pace = 0.0
	_lead_alpha = 0.0
	_animal.walking = false
	for c: CanvasItem in [_timer, _title, _quote]:
		c.modulate.a = 0.0
	for b in _buttons:
		b.modulate.a = 0.0
	# Nothing can be tapped until you set off.
	_blocker = Control.new()
	_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_blocker)
	# (Still to walk in: a resize keeps you off the edge.)
	_walking_in = true
	_walker.position.x = -90.0 * _unit()


## Setting off: you walk in from the left to your pet, the lead appears with
## the project's name, and a second later you set off together and the
## clock starts. (Main calls this when a walk built out of sight comes on.)
func begin() -> void:
	if not _arriving or _began:
		return
	_began = true
	_walker.walking = true
	# From just off the left edge to your place by your pet, worked out each
	# frame so a resize mid-way still ends in the right spot.
	var step := func(p: float):
		var home: Vector2 = ChooseFocus.walk_spots(size, _scenery.path_y())["walker"]
		_walker.position.x = lerpf(-90.0 * _unit(), home.x, p)
	step.call(0.0)
	var t := Motion.tween(_walker, "walk_in")
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(step, 0.0, 1.0, Motion.time(Motion.style.walk_in))
	await t.finished
	_walking_in = false
	_walker.walking = false
	Motion.method(self, "lead", func(v: float): _lead_alpha = v, 0.0, 1.0, Motion.style.lead_in)
	_drop_in(_title)
	await get_tree().create_timer(Motion.time(Motion.style.set_off_wait)).timeout
	if not is_inside_tree():
		return
	_set_off()


## You and your pet set off together: the clock starts, the scenery gets up
## to speed, the time drops in, then the encouragement types itself out,
## while the buttons fade in where they are.
func _set_off() -> void:
	App.start_walk(_project.id, _pet.id, str(_scenery.biome.get("id", "")))
	_arriving = false
	_walker.walking = true
	_animal.walking = true
	_apply_paused(false)
	_last_second = -1
	_gift.set_seconds(0)
	Motion.method(self, "pace", func(v: float): _pace = v, 0.0, 1.0, Motion.style.speed_up)
	_timer.modulate.a = 0.0
	var t := _drop_in(_timer)
	if is_instance_valid(_blocker):
		_blocker.queue_free()
	for b in _buttons:
		Motion.fade(b, 1.0, Motion.SLOW)
	await t.finished
	_show_quote(true)


## Fades `c` in as it drops gently into place.
func _drop_in(c: Control) -> Tween:
	return Motion.enter(c, 0.0, -Motion.style.drop, Motion.SLOW)


func _exit_tree() -> void:
	DisplayServer.screen_set_keep_on(false)
	RenderingServer.render_loop_enabled = true


func _notification(what: int) -> void:
	# Nothing to draw while the app is in the background.
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			RenderingServer.render_loop_enabled = false
		NOTIFICATION_APPLICATION_RESUMED:
			RenderingServer.render_loop_enabled = true


func _build_hud() -> void:
	var insets := UI.safe_insets(self)
	var wide := UI.is_wide(self)
	_hud = MarginContainer.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.add_theme_constant_override("margin_left", 22 + int(insets["left"]))
	_hud.add_theme_constant_override("margin_right", 22 + int(insets["right"]))
	_hud.add_theme_constant_override("margin_top", (40 if wide else 56) + int(insets["top"]))
	_hud.add_theme_constant_override("margin_bottom", 26 + int(insets["bottom"]))
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var col := UI.vbox(4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(col)

	_timer = _shadowed(UI.label("00:00:00", 84 if wide else 64, UI.ON_DARK, true, 500))
	# Kept this tall when it shrinks past a day, so nothing under it moves.
	_timer.custom_minimum_size.y = _timer.get_combined_minimum_size().y
	col.add_child(_timer)
	_title = _shadowed(UI.label(_project.name, 22, UI.ON_DARK, true, 500))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_quote = _shadowed(UI.label("", 15, UI.ON_DARK_SOFT, false, 700))
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.custom_minimum_size.x = minf(440.0, size.x - 60.0)
	_quote.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_quote)
	col.add_child(UI.spacer(true))

	var bottom := UI.hbox()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause = UI.round_button("pause", Text.t("walk.pause"), _toggle_pause, UI.SURFACE, UI.INK, 52, true)
	_pause.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(_pause)
	bottom.add_child(UI.spacer())
	# Debug time buttons: between pause and the gift where there's room, in
	# a row of their own just above them on phones.
	if OS.is_debug_build():
		var steps := DebugBar.time_buttons()
		_buttons.append(steps)
		if wide:
			bottom.add_child(steps)
			bottom.add_child(UI.spacer())
		else:
			steps.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(steps)
	_gift = GiftButton.new()
	_gift.pressed.connect(_on_gift_pressed)
	bottom.add_child(_gift)
	col.add_child(bottom)

	# Along the top: the weather picker on the left, sound on the right.
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 14 + int(insets["left"]))
	top.add_theme_constant_override("margin_right", 14 + int(insets["right"]))
	top.add_theme_constant_override("margin_top", 10 + int(insets["top"]))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var row := UI.hbox()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var weather := _weather_picker()
	row.add_child(weather)
	row.add_child(UI.spacer())
	_sound = UI.round_button("sound", Text.t("walk.sound"), _toggle_sound, UI.SURFACE, UI.INK, 40, true)
	row.add_child(_sound)
	_show_sound()
	_buttons.append_array([_pause, _gift, weather, _sound])


## The weather to walk in: the real weather (when you've let the app look
## it up) or any kind, remembered for next time. A holiday that pins the
## weather (snow at Christmas) shows it, and it can't be changed.
func _weather_picker() -> Dropdown:
	var look := App.holiday_look()
	if look and look.weather in Weather.KINDS:
		var pinned := Dropdown.new([[look.weather, Weather.look(look.weather, Content.weathers)["name"]]], look.weather, false, Text.t("walk.weather"), false).on_scenery()
		pinned.disabled = true
		return pinned
	var options := []
	if Outdoors.enabled():
		options.append(["real", Text.t("walk.weather_real")])
	for kind in Weather.KINDS:
		options.append([kind, Weather.look(kind, Content.weathers)["name"]])
	var now := Outdoors.choice()
	if now == "":
		now = "real" if Outdoors.enabled() else "sunny"
	var pick := Dropdown.new(options, now, false, Text.t("walk.weather"), false).on_scenery()
	pick.chosen.connect(func(option: String, _reversed: bool):
		Outdoors.set_choice("" if option == "real" else option)
		_update_ambience())
	return pick


## Sound on means the sound effects or the ambience are; the button turns
## both off together, or both back on.
func _sound_on() -> bool:
	return bool(App.state.settings.get("sound", true)) or bool(App.state.settings.get("ambience", true))


func _toggle_sound() -> void:
	var on := not _sound_on()
	App.state.settings["sound"] = on
	App.set_setting("ambience", on)
	Audio.refresh(_scenery.ambience())
	_show_sound()
	Motion.pop(_sound, 0.15, 0.3)


func _show_sound() -> void:
	var on := _sound_on()
	_sound.icon = Icons.texture("sound" if on else "mute", int(40 * 0.42), Color.WHITE, 2.6)
	_sound.accessibility_name = Text.t("walk.sound_off" if on else "walk.sound_on")


## Centred text with a soft shadow so it reads over any scenery.
func _shadowed(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.28))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## How big things are drawn: 720 is the short side of the design size, so
## phones and desktops match.
func _unit() -> float:
	return minf(size.x, size.y) / 720.0


func _layout() -> void:
	if _scenery == null:
		return
	var spots := ChooseFocus.walk_spots(size, _scenery.path_y())
	var s: float = spots["unit"]
	_walker.scale = Vector2(s, s)
	# (While walking in, only the height follows a resize.)
	_walker.position = Vector2(_walker.position.x if _walking_in else spots["walker"].x, spots["walker"].y)
	if not _finishing:
		_animal.scale = Vector2(s, s)
		_animal.position = spots["animal"]


func _process(delta: float) -> void:
	var clock := App.state.active
	if _scenery == null:
		return
	if clock == null or not clock.is_paused():
		var walk_speed := float(Content.animal(_pet.animal_id).get("walk_speed", 1.0))
		var motion := 0.35 if App.state.settings.get("reduce_motion", false) else 1.0
		_scenery.scroll += delta * BASE_SPEED * walk_speed * motion * _unit() * _pace
	_actors.queue_redraw()

	if clock:
		var elapsed := clock.elapsed(App.now())
		if elapsed != _last_second:
			_last_second = elapsed
			_timer.text = SessionClock.format(elapsed)
			# A day or more is three characters longer: smaller, to fit.
			var wide := UI.is_wide(self)
			_timer.add_theme_font_size_override("font_size", (84 if wide else 64) if elapsed < 86400 else (68 if wide else 48))
			_gift.set_seconds(elapsed)
			if _quote_key_now() != _quote_key and not _quote.text.is_empty():
				_show_quote(true)

	_ambience_check -= delta
	if _ambience_check <= 0.0:
		_update_ambience()
	_render_check -= delta
	if _render_check <= 0.0:
		_render_check = 0.5
		# A minimised window shows nothing, so stop drawing until it's back.
		var minimised := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED
		if RenderingServer.render_loop_enabled == minimised:
			RenderingServer.render_loop_enabled = not minimised


## Which encouragement to show: a new one every Motion.style.quote_every minutes of
## focus, starting from one picked by when the walk began.
func _quote_key_now() -> int:
	var clock := App.state.active
	if clock == null:
		return _quote_key
	@warning_ignore("integer_division")
	return clock.start_unix + clock.elapsed(App.now()) / (Motion.style.quote_every * 60)


## Shows the encouragement for now: typed out letter by letter (pausing a
## moment between words), after the old one fades, with `typed`; else just
## there.
func _show_quote(typed: bool) -> void:
	_quote_key = _quote_key_now()
	var text := Content.quote(_quote_key)
	if typed:
		Motion.type_out(_quote, text)
		return
	Motion.tween(_quote, "type").kill()
	_quote.text = text
	_quote.visible_characters = -1
	_quote.modulate.a = 1.0


func _draw_lead() -> void:
	if _lead_alpha <= 0.0:
		return
	var hand := _walker.position + _walker.hand * _walker.scale
	var collar := _animal.position + _animal.neck() * _animal.scale
	var mid := (hand + collar) * 0.5 + Vector2(0, 26.0 * _walker.scale.y)
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(hand.lerp(mid, t).lerp(mid.lerp(collar, t), t))
	_actors.draw_polyline(pts, Color("#7a3b2e", _lead_alpha), 3.0 * _walker.scale.x, true)


## The scenery follows the clock by itself; the sound catches up every
## half a minute (birds give way to the night chorus after dark).
func _update_ambience() -> void:
	_ambience_check = 30.0
	Audio.ambience(_scenery.ambience())


func _toggle_pause() -> void:
	if App.state.active == null:
		return
	if App.state.active.is_paused():
		App.resume_walk()
	else:
		App.pause_walk()
	_apply_paused(App.state.active.is_paused())


func _apply_paused(paused: bool) -> void:
	_pause.icon = Icons.texture("play" if paused else "pause", 22, Color.WHITE)
	_pause.accessibility_name = Text.t("walk.carry_on" if paused else "walk.pause")
	_walker.walking = not paused
	_animal.walking = not paused
	var walk_speed := float(Content.animal(_pet.animal_id).get("walk_speed", 1.0))
	_walker.speed = clampf(walk_speed, 0.3, 1.2)
	Motion.fade(_timer, 0.55 if paused else 1.0)


# --- Finishing ---------------------------------------------------------------

func _on_gift_pressed() -> void:
	if _finishing or App.state.active == null:
		return
	var seconds := App.state.active.elapsed(App.now())
	if GiftRoller.min_rarity(seconds, Content.drop_table) == "":
		var left := int(Content.drop_table.get("min_seconds", 600)) - seconds
		var minutes := ceili(left / 60.0)
		Modal.confirm(Text.t("walk.end_title"),
			Text.t("walk.end_body", {"pet": Content.pet_called(_pet, true), "time": Text.count("walk.minutes", minutes)}),
			Text.t("walk.end"), "danger", Text.t("walk.keep_walking")).closed.connect(func(ok):
				if ok:
					_end())
		return
	_end()


func _end() -> void:
	_finishing = true
	Audio.play("walk_end", 1.0, -4.0, "bong")
	_result = App.finish_walk()
	Motion.fade(_hud, 0.0)
	var gift: Dictionary = _result.get("gift", {})
	if gift.is_empty():
		_walker.walking = false
		_animal.walking = false
		_go_finish()
		return
	# Tap anywhere to skip straight to the gift.
	var skip := Control.new()
	skip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skip.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_go_finish())
	add_child(skip)
	_dive(str(gift["gift_id"]))


## The pet stops, dives into a bush, rustles about and comes back out with
## the gift. How it gets there comes from its "dive" in data/animals.json.
func _dive(gift_id: String) -> void:
	var s := _unit()
	var dive: Dictionary = Content.animal(_pet.animal_id).get("dive", {})
	var hops := int(dive.get("hops", 1))
	var height := float(dive.get("height", 80)) * s
	var seconds := float(dive.get("seconds", 0.9))
	var feet := _scenery.path_y()

	_bush = (load(BUSH) as PackedScene).instantiate()
	_bush.scale = Vector2(s, s)
	_bush.position = Vector2(size.x + 160.0 * s, feet + 6.0 * s)
	_actors.add_child(_bush)
	var t := Motion.tween(self, "dive")
	t.set_parallel(true)
	t.tween_method(_set_pace, 1.0, 0.0, Motion.time(1.0))
	t.tween_property(_bush, "position:x", minf(size.x * 0.82, _animal.position.x + 260.0 * s), Motion.time(1.0))
	t.tween_property(self, "_lead_alpha", 0.0, Motion.time(0.5))
	await t.finished
	if _done:
		return

	var start := _animal.position
	var inside := _bush.position + Vector2(-6.0 * s, -4.0 * s)
	_animal.walking = hops == 0
	t = Motion.tween(self, "dive")
	t.tween_method(_hop.bind(start, inside, hops, height, 1.0), 0.0, 1.0, Motion.time(seconds))
	t.parallel().tween_property(_animal, "modulate:a", 0.0, Motion.time(0.2)).set_delay(Motion.time(seconds * 0.85))
	await t.finished
	if _done:
		return

	Audio.play("bush_rustle", 1.0, 0.0, "rustle")
	t = Motion.tween(_bush, "rustle")
	for i in 7:
		t.tween_property(_bush, "rotation", 0.07 * (1.0 if i % 2 == 0 else -1.0), 0.1)
	t.tween_property(_bush, "rotation", 0.0, 0.1)
	await t.finished
	if _done:
		return

	_animal.held_gift = gift_id
	_animal.scale.x = -absf(_animal.scale.x)
	_animal.walking = hops == 0
	Audio.play(str(Content.animal(_pet.animal_id).get("sound", "")), 1.0, -4.0)
	var out := start + Vector2(30.0 * s, 0)
	t = Motion.tween(self, "dive")
	t.tween_property(_animal, "modulate:a", 1.0, Motion.time(0.15))
	t.parallel().tween_method(_hop.bind(inside, out, maxi(hops, 1), height * 0.6, -1.0), 0.0, 1.0, Motion.time(maxf(0.8, seconds * 0.8)))
	await t.finished
	_animal.walking = false
	# It stays facing you, back the way it came, into the end screen.
	Motion.pop(_animal, 0.12)
	Audio.play("gift_found", 1.0, -6.0, "chime")
	await get_tree().create_timer(Motion.time(0.7)).timeout
	_go_finish()


func _set_pace(v: float) -> void:
	_pace = v
	if v < 0.05:
		_walker.walking = false


## One frame of a hop (or a slide, with no hops) from `from` to `to`.
func _hop(t: float, from: Vector2, to: Vector2, hops: int, height: float, facing: float) -> void:
	var p := from.lerp(to, t)
	if hops > 0:
		p.y -= absf(sin(t * PI * hops)) * height
		_animal.rotation = -cos(t * PI * hops) * 0.22 * facing
	else:
		_animal.rotation = 0.0
	_animal.position = p


func _go_finish() -> void:
	if _done:
		return
	_done = true
	# The focus complete screen carries on from this exact scene.
	var params_out := _result.duplicate()
	params_out["instant"] = true
	params_out["scene"] = {
		"biome": _scenery.biome.get("id", "lake"), "scroll": _scenery.scroll, "clock": _scenery.clock,
		"walker": _walker.position, "animal": _animal.position, "unit": _unit(),
		"facing": signf(_animal.scale.x),
	}
	App.go("finish", params_out)
