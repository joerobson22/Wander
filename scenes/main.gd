extends Control
## App shell. Five panes are laid out like a plus sign with the focus screen
## in the middle: gifts to the left, projects to the right, your
## profile above and stats below. Swipe between them, use the arrow keys
## (Esc comes back to the middle), click the big faint arrows at the edges
## (computers), or open the minimap (bottom left on computers, bottom middle
## on phones) and pick one. Every pane is built once and kept, so each one
## is as you left it when you come back. Full-screen flows (choosing a focus, the walk, the end of a
## walk) open over everything through a growing circle.
## Screens ask to move with App.go(). A new save slot stays on the profile
## screen, with no map or arrows, until its profile is filled in.
## On a holiday its decorations hang over the screens (lights, bunting), and
## opening the app that day brings its present.

const PANES := {
	"focus": [Vector2i(0, 0), "res://scenes/panes/focus.gd"],
	"gifts": [Vector2i(-1, 0), "res://scenes/panes/gifts.gd"],
	"projects": [Vector2i(1, 0), "res://scenes/panes/projects.gd"],
	"profile": [Vector2i(0, -1), "res://scenes/panes/profile.gd"],
	"stats": [Vector2i(0, 1), "res://scenes/panes/stats.gd"],
}
const FLOWS := {
	"choose_focus": "res://scenes/choose_focus/choose_focus.gd",
	"walk": "res://scenes/walk/walk.gd",
	"finish": "res://scenes/walk/finish.gd",
	"ended": "res://scenes/walk/ended.gd",
}
## The UI is laid out for a short side of this many points; smaller windows
## (phones) get a smaller design size so text stays its intended size.
const DESIGN_SHORT_SIDE := 720.0
const PHONE_MIN_SHORT_SIDE := 360.0
## Computers: the window's short side in design units, whatever its size.
const DESKTOP_SHORT_SIDE := 600.0
const MIN_DESKTOP_SCALE := 0.75
## Computers: a window narrower than this share of its height is laid out
## as a phone.
const NARROW_WINDOW := 0.75
## The minimap's gap from the bottom (and the left, on computers).
const MAP_INSET := 18.0
## A drag becomes a swipe once it moves this far...
const SWIPE_START := 16.0
## ...and goes through when let go past this much of the screen, or flicked.
const SWIPE_COMMIT := 0.22
const FLICK_SPEED := 1.6  # screens per second
## The wheel or trackpad moves to the next pane after this much turning in
## one go (a wheel notch is 1; a trackpad sends small amounts)...
const WHEEL_STEP := 1.0
## ...and a pause this long (seconds) between turns starts a fresh one.
const WHEEL_GAP := 0.25
## A trackpad's turn against a wheel's, so a small flick is enough.
const PAN_SCALE := 1.6
## How long the old colours take to fade into the new ones.
const PALETTE_FADE := 0.8

var _world := Control.new()
var _panes := {}  # Vector2i -> Pane
var _names := {}  # Vector2i -> pane name
var _at := Vector2i.ZERO
var _moving := false
var _flow_layer := Control.new()
var _flows: Array[CircleReveal] = []
## A flow built out of sight under the one showing (App.prepare()), and
## which screen it is.
var _prepared: CircleReveal
var _prepared_for := ""
var _modal_layer := Control.new()
## Holds the picture of the old colours while it fades out.
var _fade_layer := Control.new()
var _fading := 0
var _minimap: Minimap
var _arrows := {}  # Vector2i direction -> NavArrow
var _bg := UI.backdrop()
## The view behind every screen (art/home/backdrop.tscn), if there is one:
## made once and kept, panning as you move between screens.
var _backdrop: HomeBackdrop
const BACKDROP := "res://art/home/backdrop.tscn"
## How often the time of day is looked at again, in seconds.
const SKY_EVERY := 20.0
## The window settings last put in place, so only a change to them moves it.
var _window_applied := ""
## True while the create account screen is up (App.needs_account()).
var _locked := false
## True while arriving home after making an account (the focus screen's
## intro): the map and the arrows wait till it's done.
var _arriving := false
## Holds the create account screen, over flows and under popups.
var _account_layer := Control.new()
var _account: CreateAccount
## Whether the debug phone view was last laid out, and the phone's outline
## (rounded corners, the camera's island and the home bar) drawn over it.
var _phone_view := false
var _phone_frame := PhoneFrame.new()
## Holds a holiday's decorations over the screens (its look's menu_scene),
## and the holiday they're for.
var _decor_layer := Control.new()
var _decor_for := ""

var _press := false
var _press_pos := Vector2.ZERO
var _swiping := false
var _target := Vector2i.ZERO
var _progress := 0.0
var _velocity := 0.0
var _last_time := 0
var _press_time := 0
var _synthetic := false
## The wheel or trackpad turn under way: when its last event came (usec),
## how far it has gone each way, and whether it can still move pane (no
## list took any of it, and it hasn't moved one yet).
var _wheel_at := 0
var _wheel_sum := Vector2.ZERO
var _wheel_free := false


func _ready() -> void:
	_apply_window()
	_fit_design_size()
	UI.vision = str(App.state.settings.get("vision", "off"))
	UI.set_dark(App.wants_dark())
	theme = UI.build_theme()
	# Before the panes connect, so a palette change lands before they rebuild.
	App.state_changed.connect(_on_state_changed)
	UI.dress_backdrop(_bg)
	add_child(_bg)
	if ResourceLoader.exists(BACKDROP):
		_backdrop = (load(BACKDROP) as PackedScene).instantiate()
		add_child(_backdrop)
	# The sky and the app's colours follow the time of day.
	var sky_timer := Timer.new()
	sky_timer.wait_time = SKY_EVERY
	sky_timer.autostart = true
	sky_timer.timeout.connect(_on_sky_tick)
	add_child(sky_timer)
	Outdoors.changed.connect(_on_sky_tick)
	App.sky_moved.connect(func():
		if is_instance_valid(_backdrop):
			_backdrop.refresh())

	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_decor_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_decor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_decor_layer)
	for pane_name in PANES:
		var cell: Vector2i = PANES[pane_name][0]
		var pane: Pane = load(PANES[pane_name][1]).new()
		pane.name = pane_name.capitalize()
		pane.visible = cell == _at
		pane.arrows = _ways_from(cell)
		_world.add_child(pane)
		_panes[cell] = pane
		_names[cell] = pane_name

	add_child(Cursor.new())
	add_child(SmoothScroll.new())
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var arrow := NavArrow.new(dir)
		arrow.pressed.connect(func(d: Vector2i): _go_cell(_at + d))
		add_child(arrow)
		_arrows[dir] = arrow
	_minimap = Minimap.new()
	_minimap.hover_grow = not App.phone_layout()
	_minimap.cells = _names.duplicate()
	_minimap.picked.connect(_go_cell)
	add_child(_minimap)

	for layer in [_fade_layer, _flow_layer, _account_layer, _modal_layer]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	# Flows and popups always draw on top, even over things lifted above
	# the fade between light and dark.
	_flow_layer.z_index = 2
	_account_layer.z_index = 2
	_modal_layer.z_index = 2
	Modal.layer = _modal_layer
	_phone_frame.visible = _phone_view
	_phone_frame.z_index = 4
	add_child(_phone_frame)

	App.navigate.connect(_open)
	App.prepare_screen.connect(_prepare_flow)
	get_viewport().size_changed.connect(_fit_design_size)
	resized.connect(_layout)
	_layout()
	_panes[_at].show_pane()
	_minimap.show_cell(_at, true)
	_sync_lock(true)
	_sync_map_cells()
	_dress_screens()
	_give_holiday_present.call_deferred()

	# Closing the app ends a walk; say so the next time it opens.
	if not App.ended_walk.is_empty():
		_open_flow("ended", App.ended_walk, true)
		App.ended_walk = {}
	if App.save_reset:
		App.save_reset = false
		Toast.show_text.call_deferred(Text.t("save.reset"), "gear")
	else:
		_maybe_ask_location()


## On phones the design size is the screen's own size in points, so text
## stays its intended size; the debug phone view does the same with a
## phone's width. On computers everything scales with the window: its short
## side is always DESKTOP_SHORT_SIDE design units, so a bigger window draws
## everything bigger (never below MIN_DESKTOP_SCALE). A tall, narrow window
## is laid out as a phone instead (see NARROW_WINDOW).
func _fit_design_size() -> void:
	var window := get_window()
	var side: float
	var phone_view := App.debug_phone_view()
	if phone_view != _phone_view:
		_phone_view = phone_view
		_phone_frame.visible = phone_view
		# Every screen is built again at the phone's size once it's in place.
		_relayout_all.call_deferred()
	if phone_view:
		# Exactly a phone's screen, whatever shape the window ends up: the
		# picture keeps the phone's shape, with black either side if the
		# window couldn't be made that narrow.
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		_set_narrow(false)
		if window.content_scale_size != Display.PHONE:
			window.content_scale_size = Display.PHONE
		return
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if OS.has_feature("mobile"):
		var points := Vector2(DisplayServer.window_get_size()) / Display.screen_scale()
		side = clampf(minf(points.x, points.y), PHONE_MIN_SHORT_SIDE, DESIGN_SHORT_SIDE)
	else:
		var window_size := Vector2(DisplayServer.window_get_size()).max(Vector2.ONE)
		var short := minf(window_size.x, window_size.y)
		if window_size.x < window_size.y * NARROW_WINDOW:
			# As tall as a phone in design units, so it's as wide as one.
			side = clampf(window_size.x * Display.PHONE.y / window_size.y, PHONE_MIN_SHORT_SIDE, DESIGN_SHORT_SIDE)
		else:
			side = maxf(short / maxf(short / DESKTOP_SHORT_SIDE, MIN_DESKTOP_SCALE), PHONE_MIN_SHORT_SIDE)
	_set_narrow(not OS.has_feature("mobile") \
		and DisplayServer.window_get_size().x < DisplayServer.window_get_size().y * NARROW_WINDOW)
	var target := Vector2i(roundi(side), roundi(side))
	if window.content_scale_size != target:
		window.content_scale_size = target


## After the debug phone view comes or goes: waits for the new size to
## settle, then lays the shell out and has every screen build itself again.
func _relayout_all() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _minimap:
		_minimap.hover_grow = not App.phone_layout()
	_layout()
	App.state_changed.emit()


## Switches to or from the phone layout as the window narrows or widens.
func _set_narrow(narrow: bool) -> void:
	if narrow == App.narrow_window:
		return
	App.narrow_window = narrow
	if _minimap:
		_minimap.hover_grow = not App.phone_layout()
		_layout()
	# Every screen lays itself out again for its new shape.
	App.state_changed.emit()


## Puts the window settings (and the debug phone view) in place, if they
## changed since last time.
func _apply_window() -> void:
	var s := App.state.settings
	var want := "%s|%s|%s" % [s.get("window_mode", ""), s.get("resolution", ""), App.debug_phone_view()]
	if want == _window_applied:
		return
	_window_applied = want
	Display.apply(get_window())
	if _minimap:
		_minimap.hover_grow = not App.phone_layout()
		_layout()


func _layout() -> void:
	for cell in _panes:
		var pane: Pane = _panes[cell]
		pane.position = Vector2(cell) * size
		pane.size = size
	if not _moving and not _swiping:
		_world.position = -Vector2(_at) * size
	var insets := UI.safe_insets(self)
	# A holiday's decorations hang below the phone's notch and clock.
	_decor_layer.offset_top = insets["top"]
	var floor_y: float = size.y - MAP_INSET - insets["bottom"]
	if App.phone_layout():
		# Phones: in the middle (of the part clear of the notch), for either thumb.
		_minimap.dock(Vector2((insets["left"] + size.x - insets["right"]) * 0.5, floor_y), true)
	else:
		_minimap.dock(Vector2(MAP_INSET + insets["left"], floor_y))
	for dir in _arrows:
		_arrows[dir].dock(size, insets)


## The ways on from `cell`: every way from the middle, and back to the
## middle from a screen at the side.
func _ways_from(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if PANES.values().any(func(p): return p[0] == cell + dir) and (cell == Vector2i.ZERO or cell + dir == Vector2i.ZERO):
			out.append(dir)
	return out


## The edge arrows show (computers only) once you've arrived on a screen,
## and hide while moving, during walks and while a popup is up.
func _process(_delta: float) -> void:
	var arrows_on := not App.phone_layout() and not _moving and not _swiping \
		and _flows.is_empty() and not Modal.is_open() and not _locked and not _arriving
	var ways: Array[Vector2i] = _ways_from(_at).filter(func(d: Vector2i): return _can_go(_at + d)) if arrows_on else ([] as Array[Vector2i])
	for dir in _arrows:
		_arrows[dir].appear(ways.has(dir))
	if is_instance_valid(_backdrop):
		_backdrop.pan = _world.position
		# A flow that has finished opening covers everything, so the view
		# needn't draw; it shows again as soon as one starts closing.
		_backdrop.covered = not _world.visible


# --- Light and dark ----------------------------------------------------------

func _on_state_changed() -> void:
	_apply_window()
	_fit_design_size()
	_sync_lock()
	_sync_map_cells()
	_on_sky_tick()


## Looks at the time of day again: the backdrop's sky, and dark colours
## from sunset to sunrise. A new colour vision setting recolours the same way.
## And whether it's a holiday: its decorations, and its present.
func _on_sky_tick() -> void:
	var want := App.wants_dark()
	var vision := str(App.state.settings.get("vision", "off"))
	if want != UI.dark or vision != UI.vision:
		UI.vision = vision
		_switch_palette(want)
	if is_instance_valid(_backdrop):
		_backdrop.refresh()
	_dress_screens()
	_give_holiday_present.call_deferred()


## Hangs the holiday's decorations over the screens, or takes them down.
func _dress_screens() -> void:
	var id := App.holiday()
	if id == _decor_for:
		return
	_decor_for = id
	var focus: Node = _panes.get(Vector2i.ZERO)
	if focus and focus.has_method("holiday_changed"):
		focus.holiday_changed()
	for c in _decor_layer.get_children():
		c.queue_free()
	var look := Holidays.look(id)
	if look and look.menu_scene:
		_decor_layer.add_child(look.menu_scene.instantiate())


## Opening the app on a holiday brings a present, once a year: it pops up
## once you're on the screens (not mid-walk, or over another popup).
func _give_holiday_present() -> void:
	if _locked or not _flows.is_empty() or Modal.is_open():
		return
	var present := App.claim_holiday_gift()
	if present.is_empty():
		return
	GiftDetails.open(present["gift"], true, true, true, Text.t("holiday.present." + str(present["holiday"])))
	# Your birthday at Christmas: the next present once this one's put away.
	var shown := Modal.top()
	if shown:
		shown.closed.connect(func(_r): _give_holiday_present.call_deferred())


## Swaps light and dark without anything moving: the screen on show is
## rebuilt in the new colours exactly as it was (same layout, scroll and
## text, no entry animations), under a picture of the old colours that
## then fades away. What a pane keeps through a rebuild (the orb, the
## toggle) is lifted above the picture so it carries on moving.
func _switch_palette(dark: bool) -> void:
	# There's no picture to take when running without a display.
	var snapshot: Image = null
	if DisplayServer.get_name() != "headless":
		snapshot = get_viewport().get_texture().get_image()
	UI.set_dark(dark)
	theme = UI.build_theme()
	UI.dress_backdrop(_bg)
	_minimap.queue_redraw()
	_phone_frame.queue_redraw()
	for dir in _arrows:
		_arrows[dir].refresh()
	if _account:
		var typed := _account.typed()
		_account.queue_free()
		_show_account(true, typed)
	var lifted: Array[Node] = []
	Motion.still = true
	for cell in _panes:
		var pane: Pane = _panes[cell]
		if pane.shown:
			pane.rebuild()
			lifted.append_array(pane.keeps())
		else:
			pane.mark_dirty()
	if snapshot == null or snapshot.is_empty():
		_settle.call_deferred()
		return
	var cover := TextureRect.new()
	cover.texture = ImageTexture.create_from_image(snapshot)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(cover)
	_fading += 1
	for node in lifted:
		(node as CanvasItem).z_index = 1
	await _settle()
	Motion.fade(cover, 0.0, PALETTE_FADE).tween_callback(func():
		cover.queue_free()
		_fading -= 1
		if _fading == 0:
			for node in lifted:
				if is_instance_valid(node):
					(node as CanvasItem).z_index = 0)


## Some screens start animations a frame after they're built, so animations
## stay still until then.
func _settle() -> void:
	await get_tree().process_frame
	Motion.still = false


# --- Navigation --------------------------------------------------------------

## Puts up the create account screen when App.needs_account() (a first
## launch, or after Log out), and takes it away after. Leaving it always
## lands on the focus screen, with any flow closed.
func _sync_lock(instant: bool = false) -> void:
	var locked := App.needs_account()
	if locked == _locked:
		if _account:
			_account.refresh_accounts()
		return
	_locked = locked
	if locked:
		_close_flows()
		_show_account(instant)
		_show_home(false, instant)
		return
	if _at != Vector2i.ZERO:
		_at = Vector2i.ZERO
		_minimap.show_cell(_at, true)
		_layout()
		_panes[_at].visible = true
		_panes[_at].show_pane()
		_hide_others()
	# (Once the focus screen's on, as it plays its intro.)
	_show_home(true, instant)
	var going := _account
	_account = null
	if going:
		if instant:
			going.queue_free()
		else:
			Motion.fade(going, 0.0, Motion.NORMAL).tween_callback(going.queue_free)


## Fades the screens and the minimap in or out, leaving the hilltop view:
## the create account screen sits straight on it.
func _show_home(on: bool, instant: bool) -> void:
	_arriving = on and not instant
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE if _arriving else Control.MOUSE_FILTER_STOP
	for item: CanvasItem in [_world, _minimap]:
		if instant:
			item.modulate.a = 1.0 if on else 0.0
		elif not (_arriving and item == _minimap):
			Motion.fade(item, 1.0 if on else 0.0, Motion.NORMAL)
	if _arriving:
		# The focus screen plays its intro as the view tilts up, then the
		# map and the arrows come in.
		var focus: Node = _panes[Vector2i.ZERO]
		if not focus.intro_done.is_connected(_on_arrived):
			focus.intro_done.connect(_on_arrived)
		focus.intro(Motion.style.account_rise)
	# The create account screen looks down at the hilltop under your feet;
	# once it's done the view tilts up to the forest and the sky.
	if is_instance_valid(_backdrop):
		var down := 0.0 if on else 1.0
		if instant:
			_backdrop.look_down = down
		else:
			Motion.to(_backdrop, "look_down", down, Motion.style.account_rise if on else Motion.SLOW)


## The focus screen's intro is done: the map fades in (the arrows follow
## by themselves, see _process).
func _on_arrived() -> void:
	if not _arriving:
		return
	_arriving = false
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	Motion.fade(_minimap, 1.0, Motion.style.home_ui_fade)


func _show_account(instant: bool, typed: Dictionary = {}) -> void:
	_account = CreateAccount.new(typed, _backdrop == null)
	_account_layer.add_child(_account)
	if not instant:
		_account.modulate.a = 0.0
		Motion.fade(_account, 1.0, Motion.NORMAL)


## True if you can go to `cell`: anywhere, unless the create account screen
## is up. Until you've a pet or a project, only up and down (see
## _sideways_open()).
func _can_go(cell: Vector2i) -> bool:
	return _panes.has(cell) and not _locked and (cell.x == 0 or _sideways_open())


## The screens to either side (gifts and projects) open once you have a pet
## or a project; before then there's only your profile and your stats.
func _sideways_open() -> bool:
	return not (App.state.active_pets().is_empty() and App.state.projects.is_empty())


## The map shows only the screens you can go to (and the one you're on).
func _sync_map_cells() -> void:
	var cells := {}
	for cell in _names:
		if cell == _at or cell.x == 0 or _sideways_open():
			cells[cell] = _names[cell]
	if cells.keys() != _minimap.cells.keys():
		_minimap.cells = cells
		_minimap.queue_redraw()

func _open(screen: String, params: Dictionary) -> void:
	if PANES.has(screen):
		_close_flows()
		_go_cell(PANES[screen][0])
	elif screen == "home":
		_close_flows()
	elif FLOWS.has(screen):
		_open_flow(screen, params, bool(params.get("instant", false)))
	else:
		push_error("Unknown screen %s" % screen)


## Slides to a pane. Panes off to the side only connect to the middle, so
## going from one side to another passes through the focus screen.
func _go_cell(cell: Vector2i) -> void:
	if not _can_go(cell) or _moving or cell == _at:
		return
	if _at != Vector2i.ZERO and cell != Vector2i.ZERO:
		await _slide_to(Vector2i.ZERO, Motion.NORMAL * 0.75)
	await _slide_to(cell)


func _slide_to(cell: Vector2i, seconds: float = Motion.NORMAL + 0.06) -> void:
	var from := _at
	var pane: Pane = _panes[cell]
	pane.visible = true
	if not pane.shown:
		pane.show_pane()
	_at = cell
	_minimap.show_cell(cell)
	_sync_map_cells()
	_moving = true
	await Motion.to(_world, "position", -Vector2(cell) * size, seconds).finished
	_moving = false
	if from != cell:
		_panes[from].hide_pane()
	_hide_others()


func _hide_others() -> void:
	for c in _panes:
		if c != _at:
			_panes[c].visible = false
			if _panes[c].shown:
				_panes[c].hide_pane()


## Builds a flow fully open under the one showing (hidden behind it), so
## its first frame is already drawn when it takes over: the walk is made
## while your pet steps over to the path, so the scene never blinks empty.
func _prepare_flow(screen: String, params: Dictionary) -> void:
	_drop_prepared()
	if not FLOWS.has(screen) or _flows.is_empty():
		return
	_prepared = _make_flow(screen, params)
	_prepared_for = screen
	_flow_layer.move_child(_prepared, 0)
	_prepared.open(true)


func _drop_prepared() -> void:
	if is_instance_valid(_prepared):
		_prepared.queue_free()
	_prepared = null
	_prepared_for = ""


func _make_flow(screen: String, params: Dictionary) -> CircleReveal:
	var content: Control = load(FLOWS[screen]).new()
	content.set("params", params)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var reveal := CircleReveal.new()
	reveal.origin = params.get("from", size * 0.5)
	reveal.add_child(content)
	_flow_layer.add_child(reveal)
	return reveal


func _open_flow(screen: String, params: Dictionary, instant: bool = false) -> void:
	var reveal: CircleReveal
	if is_instance_valid(_prepared) and _prepared_for == screen:
		# Already built (and drawn) underneath: it comes to the top and
		# carries on from there.
		reveal = _prepared
		_prepared = null
		_prepared_for = ""
		_flow_layer.move_child(reveal, -1)
		var content: Node = reveal.get_child(0)
		if content.has_method("begin"):
			content.begin()
	else:
		_drop_prepared()
		reveal = _make_flow(screen, params)
	var below := _flows.duplicate()
	_flows.append(reveal)
	_minimap.shrink(true)
	Motion.fade(_minimap, 0.0, Motion.FAST)
	var t := reveal.open(instant)
	if t:
		await t.finished
	for f in below:
		_flows.erase(f)
		f.queue_free()
	# Nothing behind a full-screen flow needs drawing.
	if not _flows.is_empty():
		_world.visible = false
		_panes[_at].hide_pane()


## Back to the focus screen from any flow, shrinking the circle away.
func _close_flows() -> void:
	_drop_prepared()
	if _flows.is_empty():
		return
	var top: CircleReveal = _flows.back()
	for f in _flows:
		if f != top:
			f.queue_free()
	_flows.clear()
	# The places' sounds stay with them.
	Audio.ambience("")
	_maybe_ask_location()
	if _at != Vector2i.ZERO:
		_at = Vector2i.ZERO
		_minimap.show_cell(_at, true)
		_layout()
	_world.visible = true
	_panes[_at].visible = true
	_panes[_at].show_pane()
	_hide_others()
	# The flow shrinks back into the focus orb, which shrinks from filling
	# the screen back to its place in the middle, as it grew when you tapped
	# it.
	var focus: Node = _panes[Vector2i.ZERO]
	var orb: Dictionary = focus.orb_circle() if focus.has_method("orb_circle") else {}
	if orb.is_empty():
		top.origin = size * 0.5
		top.close()
	else:
		top.origin = orb["centre"]
		top.close(Motion.SLOW, orb["radius"] * 0.85)
		focus.orb_return(Motion.SLOW)
	Motion.fade(_minimap, 1.0)


## Asks once, a moment after the focus screen shows, whether the places may
## follow the real sunrise, sunset and weather where you are.
func _maybe_ask_location() -> void:
	if Outdoors.asked():
		return
	await get_tree().create_timer(1.5).timeout
	if Outdoors.asked() or not _flows.is_empty() or Modal.is_open() or _at != Vector2i.ZERO:
		return
	var m := Modal.confirm(Text.t("weather_prompt.title"), Text.t("weather_prompt.body"),
		Text.t("weather_prompt.allow"), "accent", Text.t("weather_prompt.not_now"))
	Outdoors.set_enabled(await m.closed == true)


func _go_back() -> void:
	if Modal.is_open():
		# (One that has to be answered stays.)
		if Modal.top().dismissible:
			Modal.top().close(null)
	elif not _flows.is_empty():
		var content: Node = _flows.back().get_child(0)
		if content.has_method("go_back"):
			content.go_back()
	elif _at != Vector2i.ZERO:
		_go_cell(Vector2i.ZERO)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


# --- Wheel and trackpad ------------------------------------------------------

## How far a wheel or trackpad event turns, down and right positive, or zero
## for anything else.
static func _wheel_turn(e: InputEvent) -> Vector2:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed:
		var f: float = mb.factor if mb.factor > 0.0 else 1.0
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				return Vector2(-f, 0) if mb.shift_pressed else Vector2(0, -f)
			MOUSE_BUTTON_WHEEL_DOWN:
				return Vector2(f, 0) if mb.shift_pressed else Vector2(0, f)
			MOUSE_BUTTON_WHEEL_LEFT:
				return Vector2(-f, 0)
			MOUSE_BUTTON_WHEEL_RIGHT:
				return Vector2(f, 0)
	var pan := e as InputEventPanGesture
	if pan:
		return pan.delta * PAN_SCALE
	return Vector2.ZERO


## A wheel or trackpad turn at `pos`. A list under the pointer that can
## still scroll that way takes it, and then the whole turn is the list's,
## however long a trackpad keeps it going: only a fresh turn (after a short
## pause) can move pane. Otherwise, once the turn has gone far enough one
## way, it moves one pane that way, as the arrow keys do, and the rest of
## the turn does nothing more.
func _on_wheel(turn: Vector2, pos: Vector2) -> void:
	var now := Time.get_ticks_usec()
	if now - _wheel_at > WHEEL_GAP * 1000000.0:
		_wheel_free = true
		_wheel_sum = Vector2.ZERO
	_wheel_at = now
	if not _wheel_free or not _flows.is_empty() or Modal.is_open() or _swiping:
		return
	var sideways := absf(turn.x) > absf(turn.y)
	var along := -(turn.x if sideways else turn.y)
	# A list that only scrolls sideways takes the wheel down too.
	if _moving or _scroll_blocks(pos, sideways, along) or (not sideways and _scroll_blocks(pos, true, along, true)):
		_wheel_free = false
		return
	_wheel_sum += turn
	var step := Vector2i.ZERO
	if absf(_wheel_sum.x) >= WHEEL_STEP and absf(_wheel_sum.x) > absf(_wheel_sum.y):
		step = Vector2i(1 if _wheel_sum.x > 0.0 else -1, 0)
	elif absf(_wheel_sum.y) >= WHEEL_STEP:
		step = Vector2i(0, 1 if _wheel_sum.y > 0.0 else -1)
	if step == Vector2i.ZERO:
		return
	_wheel_free = false
	if _can_go(_at + step):
		get_viewport().set_input_as_handled()
		_go_cell(_at + step)


# --- Swiping -----------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if _synthetic:
		return
	if e is InputEventKey and e.pressed and e.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_tab(-1 if e.shift_pressed else 1)
		return
	var turn := _wheel_turn(e)
	if turn != Vector2.ZERO:
		_on_wheel(turn, e.position)
		return
	if not _flows.is_empty() or Modal.is_open() or _moving:
		_press = false
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			# A press on something you drag (a slider, a scroll bar, a text
			# box) is for that, never the start of a swipe.
			_press = not _drags_something(e.position)
			_swiping = false
			_press_pos = e.position
			_press_time = Time.get_ticks_usec()
			Gestures.claimed = false
			Gestures.sideways = false
		else:
			if _swiping:
				get_viewport().set_input_as_handled()
				_end_swipe()
			_press = false
			Gestures.claimed = false
	elif e is InputEventMouseMotion and _press:
		if _swiping:
			get_viewport().set_input_as_handled()
			_update_swipe(e.position)
		elif not Gestures.claimed and e.position.distance_to(_press_pos) > SWIPE_START:
			_try_swipe(e.position)
	elif e is InputEventKey and e.pressed and not e.echo and not _typing():
		var step := Vector2i.ZERO
		match e.keycode:
			KEY_LEFT:
				step = Vector2i.LEFT
			KEY_RIGHT:
				step = Vector2i.RIGHT
			KEY_UP:
				step = Vector2i.UP
			KEY_DOWN:
				step = Vector2i.DOWN
		if step != Vector2i.ZERO and _can_go(_at + step):
			get_viewport().set_input_as_handled()
			_go_cell(_at + step)


# --- Keyboard ----------------------------------------------------------------

## Tab and Shift+Tab: the next or last thing you can press on whatever's on
## top (an open menu, the newest popup, the create account screen, a flow,
## or else the screen you're on), round and round, scrolling it into view.
## Enter or Space presses it; Esc goes back; the arrow keys move screens.
func _tab(step: int) -> void:
	var stops := focus_stops(_focus_scope())
	if stops.is_empty():
		return
	var at := stops.find(get_viewport().gui_get_focus_owner())
	var next: Control = stops[posmod(at + step, stops.size()) if at >= 0 else (0 if step > 0 else stops.size() - 1)]
	next.grab_focus()
	var up := next.get_parent()
	while up:
		if up is ScrollContainer:
			(up as ScrollContainer).ensure_control_visible(next)
		up = up.get_parent()


func _focus_scope() -> Control:
	for layer in [_modal_layer, _account_layer, _flow_layer]:
		for i in range(layer.get_child_count() - 1, -1, -1):
			var c := layer.get_child(i) as Control
			# (A popup that's closing lets the mouse through already.)
			if c and c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and not c is Toast:
				return c
	return self if _flows.is_empty() else _flow_layer


## Everything in `root` that Tab stops on, in order: shown, switched on and
## able to take the keyboard. From the shell, only the screen you're on.
func focus_stops(root: Control) -> Array[Control]:
	var out: Array[Control] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var c := n as Control
		if c == null or not c.visible or (n is Pane and n != _panes[_at]):
			continue
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() and not (c is BaseButton and (c as BaseButton).disabled):
			out.append(c)
		var kids := n.get_children()
		kids.reverse()
		stack.append_array(kids)
	return out


## True if `pos` is on a control that a drag works by itself: a slider or
## scroll bar, or a text box (dragging selects text).
func _drags_something(pos: Vector2) -> bool:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var c := n as Control
		if c and not c.is_visible_in_tree():
			continue
		stack.append_array(n.get_children())
		if (n is Range and not n is ProgressBar) or n is LineEdit or n is TextEdit:
			if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(pos):
				return true
	return false


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _try_swipe(pos: Vector2) -> void:
	var d := pos - _press_pos
	var horizontal := absf(d.x) > absf(d.y)
	var along := d.x if horizontal else d.y
	# The finger drags the screen: moving right brings in the pane on the left.
	var step := Vector2i(-signi(roundi(along)), 0) if horizontal else Vector2i(0, -signi(roundi(along)))
	var target := _at + step
	if not _can_go(target) or _scroll_blocks(pos, horizontal, along) or (horizontal and Gestures.sideways):
		# Not a swipe: leave this drag to whatever's under the finger.
		_press = false
		return
	_swiping = true
	_target = target
	_progress = 0.0
	_last_time = Time.get_ticks_usec()
	_cancel_gui_press()
	get_viewport().set_input_as_handled()
	var pane: Pane = _panes[target]
	pane.visible = true
	if not pane.shown:
		pane.show_pane()
	_update_swipe(pos)
	# The speed so far is the distance since the press over the time since;
	# measuring it from this instant instead would make every swipe a flick.
	_velocity = _progress / maxf((_last_time - _press_time) / 1000000.0, 0.016)


func _update_swipe(pos: Vector2) -> void:
	var dir := Vector2(_target - _at)
	var dim := size.x if dir.x != 0.0 else size.y
	var along := (pos - _press_pos).dot(dir.abs())
	var progress := clampf(-along * (dir.x + dir.y) / dim, 0.0, 1.0)
	var now := Time.get_ticks_usec()
	var dt := maxf((now - _last_time) / 1000000.0, 0.001)
	_velocity = lerpf(_velocity, (progress - _progress) / dt, 0.35)
	_last_time = now
	_progress = progress
	_world.position = -(Vector2(_at) + dir * progress) * size


func _end_swipe() -> void:
	_swiping = false
	if _progress > SWIPE_COMMIT or _velocity > FLICK_SPEED:
		_slide_to(_target, Motion.NORMAL * maxf(0.4, 1.0 - _progress))
	else:
		var back := _target
		_moving = true
		await Motion.to(_world, "position", -Vector2(_at) * size, Motion.NORMAL * maxf(0.4, _progress * 2.0)).finished
		_moving = false
		if back != _at:
			_panes[back].hide_pane()
			_panes[back].visible = false


## True if a scroll area under the finger can still move that way, so the
## drag should scroll it rather than swipe to another pane.
## With `only_sideways`, only lists that can't scroll down count.
func _scroll_blocks(pos: Vector2, horizontal: bool, along: float, only_sideways: bool = false) -> bool:
	var stack: Array[Node] = [_panes[_at]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var sc := n as ScrollContainer
		if sc == null or not sc.is_visible_in_tree() or not sc.get_global_rect().has_point(pos):
			continue
		if only_sideways and sc.get_v_scroll_bar().visible:
			continue
		var bar: ScrollBar = sc.get_v_scroll_bar()
		if horizontal:
			bar = sc.get_h_scroll_bar()
		var mode := sc.horizontal_scroll_mode if horizontal else sc.vertical_scroll_mode
		if mode == ScrollContainer.SCROLL_MODE_DISABLED:
			continue
		var value := bar.value
		var most := bar.max_value - bar.page
		# A few pixels' slack, so a page that only just overflows doesn't
		# have to be scrolled to its very end before you can swipe off it.
		if (along < 0.0 and value < most - 8.0) or (along > 0.0 and value > 8.0):
			return true
	return false


## Tells whatever the finger pressed that the press is over (by moving the
## pointer far away and letting go there), so a swipe never also taps.
func _cancel_gui_press() -> void:
	_synthetic = true
	var far := Vector2(-100000, -100000)
	var mm := InputEventMouseMotion.new()
	mm.position = far
	mm.global_position = far
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(mm, true)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = far
	mb.global_position = far
	get_viewport().push_input(mb, true)
	_synthetic = false
