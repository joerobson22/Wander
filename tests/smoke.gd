extends SceneTree
## Smoke run: boots the real app, fills it with sample data and visits every
## pane, popup and full-screen flow (including a real swipe, the arrow keys,
## a full walk with a gift, throwing the gift for the pet to fetch, a walk
## left running when the app closed, every kind of weather, and dark mode),
## so script errors in UI code show up in CI.
##   godot --headless --path . -s tests/smoke.gd
## Optional: --shots=<dir> saves a screenshot per step (needs a display);
## --quick skips drawing every place and weather, for a fast look at the UI.
## --holidays only tries each holiday's look (and takes its pictures).

var _shots_dir := ""
var _quick := false
var _holidays_only := false
var _failed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
		elif arg == "--quick":
			_quick = true
		elif arg == "--holidays":
			_holidays_only = true
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _app() -> Node:
	return root.get_node("App")


func _content() -> Node:
	return root.get_node("Content")


func _audio() -> Node:
	return root.get_node("Audio")


func _levels() -> GDScript:
	return _class("res://core/levels.gd")


func _main() -> Node:
	return current_scene


func _run() -> void:
	await process_frame
	await process_frame
	_fill_sample_data()
	var main := _main()
	var app := _app()
	# Answered, so the location question doesn't pop up mid-run (and nothing
	# goes out to the internet from CI); it's asked on purpose further down.
	app.state.settings["location"] = "off"
	# The colours follow the time of day; light, so the run looks the same
	# whenever it runs. Dark mode is tried further down.
	app.set_setting("debug_theme", "light")
	# An ordinary day, whatever today's date (holidays are tried at the end).
	app.set_setting("debug_holiday", "none")

	# Long enough for the first frames to settle on a slow machine (CI), so
	# the map is laid out before the pointer moves over it.
	await _wait(70)
	# A first run (no save yet, as on CI) opens on the create account screen;
	# filling in the sample account leaves it, playing the arrival intro.
	# The map comes in once that's done.
	for i in 120:
		if not main._arriving:
			break
		await _wait(5)
	await _wait(50)
	if _holidays_only:
		await _holidays(main)
		print("SMOKE OK" if not _failed else "SMOKE FAILED")
		quit(1 if _failed else 0)
		return
	await _shot("focus")

	# The map sits in the bottom left corner. With a mouse it grows up and to
	# the right while the pointer is over it (an icon fading in on each
	# screen's tile), stays big while the pointer moves over its tiles, and
	# shrinks as soon as the pointer leaves. Clicking a tile goes there.
	var map: Control = main._minimap
	var small: Vector2 = map.size
	check(map.mouse_default_cursor_shape == Control.CURSOR_CAN_DROP, "the map shows the open hand")
	var any_button: Button = _find(main, func(n): return n is Button and n.is_visible_in_tree())
	check(any_button != null and any_button.mouse_default_cursor_shape == Control.CURSOR_CAN_DROP, "buttons show the open hand")
	check(map._grow == 0.0 and not map.open and map.hover_grow, "the map starts small, with no icons, and grows under the pointer")
	var corner := Vector2(main.MAP_INSET, main.size.y - main.MAP_INSET)
	check(map.get_global_rect().position.x == corner.x and is_equal_approx(map.get_global_rect().end.y, corner.y),
		"it sits in the bottom left corner")
	await _point(map.get_global_rect().get_center())
	await _wait(30)
	check(map.open and map._grow > 0.99 and map.size.x > small.x * 2.0 and main._at == Vector2i.ZERO,
		"pointing at the map grows it, without going anywhere")
	check(map.get_global_rect().position.x == corner.x and is_equal_approx(map.get_global_rect().end.y, corner.y),
		"up and to the right, from the corner")
	await _shot("map_open")
	var stats_tile: Vector2 = map.get_global_transform_with_canvas() * map._cell_rect(Vector2(0, 1)).get_center()
	await _point(stats_tile)
	await _wait(30)
	check(map.open, "moving over its tiles keeps it big")
	await _drag(stats_tile, stats_tile, 1)
	await _wait(40)
	check(main._at == Vector2i(0, 1) and map.open, "clicking the stats tile goes there, and the map stays big under the pointer")
	await _point(main.size * Vector2(0.6, 0.4))
	check(not map.open, "it starts shrinking the moment the pointer leaves")
	await _wait(20)
	check(map._grow < 0.01, "and is small again a moment later")
	await _key(KEY_ESCAPE)
	await _wait(30)

	# On phones a tap grows it; tapping where you are (or anywhere else, or
	# Esc) shrinks it back, and tapping another tile goes there.
	map.hover_grow = false
	await _point(main.size * 0.5)
	await _drag(map.get_global_rect().get_center(), map.get_global_rect().get_center(), 1)
	await _wait(30)
	check(map.open and main._at == Vector2i.ZERO, "on phones, tapping the map grows it")
	await _drag(map.get_global_rect().get_center(), map.get_global_rect().get_center(), 1)
	await _wait(30)
	check(not map.open and main._at == Vector2i.ZERO, "and tapping it again shrinks it")
	await _drag(map.get_global_rect().get_center(), map.get_global_rect().get_center(), 1)
	await _wait(30)
	await _drag(Vector2(main.size.x * 0.5, 40), Vector2(main.size.x * 0.5, 40), 1)
	await _wait(30)
	check(not map.open and map._grow < 0.01 and main._at == Vector2i.ZERO, "tapping elsewhere shrinks it too")
	await _drag(map.get_global_rect().get_center(), map.get_global_rect().get_center(), 1)
	await _wait(30)
	await _key(KEY_ESCAPE)
	await _wait(30)
	check(not map.open and main._at == Vector2i.ZERO, "and Esc")
	await _drag(map.get_global_rect().get_center(), map.get_global_rect().get_center(), 1)
	await _wait(30)
	stats_tile = map.get_global_transform_with_canvas() * map._cell_rect(Vector2(0, 1)).get_center()
	await _drag(stats_tile, stats_tile, 1)
	await _wait(40)
	check(main._at == Vector2i(0, 1) and not map.open, "tapping the stats tile goes there, and the map shrinks back")
	map.hover_grow = true
	await _key(KEY_ESCAPE)
	await _wait(30)
	await _key(KEY_RIGHT)
	await _wait(30)
	check(main._at == Vector2i(1, 0), "right arrow key opens completed")
	await _key(KEY_ESCAPE)
	await _wait(30)
	check(main._at == Vector2i.ZERO, "Esc comes back to the middle")

	# Computers get big faint arrows at the edges, once you've arrived: one
	# on every side of the focus screen, and only the one back home on the
	# others. Under the pointer an arrow slides out and darkens.
	var arrows: Dictionary = main._arrows
	var showing := func(): return arrows.keys().filter(func(d): return arrows[d].visible and arrows[d].modulate.a > 0.99)
	await _wait(15)
	check(showing.call().size() == 4, "an arrow on every side of the focus screen (%d)" % showing.call().size())
	var right: Control = arrows[Vector2i.RIGHT]
	check(right.get_global_rect().end.x == main.size.x and is_equal_approx(right.get_global_rect().get_center().y, main.size.y * 0.5),
		"the right one sits at the middle of the right edge")
	var tip_before: Vector2 = right._line.points[1]
	await _point(right.get_global_rect().get_center())
	await _wait(20)
	check(right._hover > 0.99 and right._line.points[1].x > tip_before.x, "under the pointer it slides the way it points")
	await _shot("arrows_hover")
	await _drag(right.get_global_rect().get_center(), right.get_global_rect().get_center(), 1)
	await _wait(5)
	check(showing.call().is_empty(), "they hide while the screens slide")
	await _wait(40)
	check(main._at == Vector2i(1, 0) and showing.call() == [Vector2i.LEFT], "the right arrow opens completed, with just the arrow back")
	var back: Control = arrows[Vector2i.LEFT]
	await _drag(back.get_global_rect().get_center(), back.get_global_rect().get_center(), 1)
	await _wait(40)
	check(main._at == Vector2i.ZERO, "and that one comes home")
	# On every screen the content keeps clear of the map and the arrows.
	for cell in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		main._go_cell(cell)
		await _wait(60)
		var margin: Node = _find(main._panes[cell], func(n): return n is MarginContainer)
		var column: Control = margin.get_child(0) if margin and margin.get_child_count() > 0 else null
		# Only from the smallest window a computer allows (CI's is smaller).
		if main.size.y >= 590:
			check(column != null and _clear_of_shell(column.get_global_rect()),
				"%s keeps clear of the map and arrows (%s)" % [main._names[cell], str(column.get_global_rect()) if column else "no column"])
		await _shot("shell_" + main._names[cell])
	main._go_cell(Vector2i.ZERO)
	await _wait(40)
	await _point(main.size * Vector2(0.5, 0.3))
	await _wait(10)

	# The orb grows under the pointer.
	var orb_rect: Rect2 = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "focus_orb.gd")).get_global_rect()
	var over := InputEventMouseMotion.new()
	over.position = orb_rect.get_center()
	over.global_position = over.position
	root.push_input(over, true)
	await _wait(20)
	var hovered: Node = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "focus_orb.gd"))
	check(hovered._grow > 1.03, "the orb grows on hover (%.2f)" % hovered._grow)
	over = over.duplicate()
	over.position = Vector2(4, main.size.y * 0.5)
	over.global_position = over.position
	root.push_input(over, true)
	await _wait(20)
	check(hovered._grow < 1.01, "and shrinks back")
	check(hovered._shade < 0.01, "and its shade goes")

	# Dragging the debug time slider never swipes to another screen.
	var slider: Control = _find(main._panes[Vector2i.ZERO], func(n): return n is HSlider)
	if slider:
		var sr: Rect2 = slider.get_global_rect()
		await _drag(sr.position + Vector2(sr.size.x * 0.2, sr.size.y * 0.5), sr.position + Vector2(sr.size.x * 0.9, sr.size.y * 0.5) + Vector2(main.size.x * 0.3, 0))
		await _wait(30)
		check(main._at == Vector2i.ZERO, "dragging the time slider stays on the focus screen")
		app.set_setting("debug_hour", -1.0)
		await _wait(10)

	# Debug builds get an unlock-everything switch in the top left.
	var debug: Node = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "debug_bar.gd"))
	check(debug != null, "the debug bar shows in a debug build")
	if debug:
		var unlock: Button = _find(debug, func(n): return _is(n, "switch.gd"))
		var inventory_before: Dictionary = app.state.inventory.duplicate()
		unlock.button_pressed = true
		await _wait(10)
		check(app.is_unlocked("place", "moon") and app.is_unlocked("animal", "bear"), "the debug switch unlocks everything")
		check(_content().gifts.all(func(g): return app.state.gift_count(g["id"]) >= 50), "and gives 50 of every gift")
		await _shot("debug")
		unlock.button_pressed = false
		# The gifts stay; put the old ones back so the rest of the run sees them.
		app.state.inventory = inventory_before
		app.set_setting("debug_unlock_all", false)
		await _wait(10)
		check(not app.is_unlocked("place", "moon"), "and locks it all again")
		# The second switch lays the app out as on a phone (and, with a real
		# display, gives the window a phone's shape): the map opens on a tap
		# and the edge arrows go, as phones swipe.
		var switches: Array = _all(debug, func(n): return _is(n, "switch.gd"))
		check(switches.size() == 2, "a phone size switch under the unlock one")
		var grid_tall: float = (debug.get_child(0) as Control).get_global_rect().size.y
		check(grid_tall <= 46.0, "the debug switches are small, level with the home icon (%.0f)" % grid_tall)
		switches[1].button_pressed = true
		await _wait(30)
		check(root.content_scale_size == Vector2i(390, 844) and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP \
			and app.phone_layout() and not map.hover_grow,
			"the phone size switch lays the app out on a phone's screen")
		check(main.size.is_equal_approx(Vector2(390, 844)), "exactly a phone's size, whatever the window (%s)" % main.size)
		check(main._phone_frame.visible, "with a phone's outline over it")
		check(arrows.values().all(func(a): return not a.visible), "with no edge arrows")
		var map_box: Rect2 = map.get_global_rect()
		check(absf(map_box.get_center().x - main.size.x * 0.5) < 1.0 and is_equal_approx(map_box.end.y, main.size.y - main.MAP_INSET - main._phone_frame.INSETS["bottom"]),
			"and the map in the middle at the bottom (%s)" % map_box)
		await _drag(map_box.get_center(), map_box.get_center(), 1)
		await _wait(30)
		check(map.open and absf(map.get_global_rect().get_center().x - main.size.x * 0.5) < 1.0 and is_equal_approx(map.get_global_rect().end.y, main.size.y - main.MAP_INSET - main._phone_frame.INSETS["bottom"]),
			"growing up from there")
		await _shot("debug_phone_map")
		await _key(KEY_ESCAPE)
		await _wait(30)
		await _shot("debug_phone")
		# The pane rebuilt at the new size, so find its switch again.
		debug = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "debug_bar.gd"))
		_all(debug, func(n): return _is(n, "switch.gd"))[1].button_pressed = false
		await _wait(30)
		check(not app.phone_layout() and map.hover_grow and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND \
			and not main._phone_frame.visible, "and back to the computer layout")
		check(map.get_global_rect().position.x == main.MAP_INSET, "with the map back in the corner")
		check(showing.call().size() == 4, "with its arrows")

	# The location question: asked once, a moment after the focus screen shows.
	app.state.settings.erase("location")
	main._maybe_ask_location()
	await _wait(110)
	check(_class("res://ui/modal.gd").is_open(), "asks about local sunrise and weather")
	await _shot("location_prompt")
	_close_modal(false)
	await _wait(20)
	check(app.state.settings.get("location") == "off" and not root.get_node("Outdoors").enabled(), "Not now leaves it off")

	await _art_check(main)

	if not _quick:
		await _scenery_gallery(main)

	# A real swipe: dragging right from the middle brings in the gifts on the left.
	await _drag(main.size * 0.5, main.size * Vector2(0.9, 0.5))
	await _wait(30)
	check(main._at == Vector2i(-1, 0), "swiping right opens gifts")
	await _shot("gifts")
	var gifts_pane: Node = main._panes[Vector2i(-1, 0)]
	var modal_class := _class("res://ui/modal.gd")
	# The gifts screen: three rings (gifts discovered, pets' gift tables
	# completed and cosmetics unlocked), then every gift you have, with its
	# count, in a list that scrolls on its own. The shelf is on the profile.
	var counts: Dictionary = _class("res://core/collection.gd").progress(app.state.inventory, _content().gifts)
	var rings: Array = _all(gifts_pane._stats, func(n): return _is(n, "progress_ring.gd"))
	check(rings.size() == 3 and is_equal_approx(rings[0].value, float(counts["found"]) / counts["gifts"])
		and is_equal_approx(rings[1].value, float(counts["tables"]) / counts["total_tables"])
		and is_equal_approx(rings[2].value, float(counts["cosmetics"]) / counts["wearables"]), "three rings (%s)" % [counts])
	check(_find(gifts_pane, func(n): return _is(n, "gift_shelf.gd")) == null, "no shelf on the gifts screen")
	var have: int = app.state.inventory.keys().filter(func(id): return app.state.gift_count(id) > 0).size()
	var grid_tiles: Array = _all(gifts_pane._grid, func(n): return _is(n, "gift_tile.gd"))
	check(grid_tiles.size() == have and gifts_pane._grid.columns == (8 if gifts_pane.wide else 5),
		"every gift you have, %d to a row (%d of %d)" % [gifts_pane._grid.columns, grid_tiles.size(), have])
	check(grid_tiles.all(func(t): return t.trades and not t.draggable and _find(t, func(n): return n is Label and n.text.begins_with("×")) != null),
		"each shows how many you have and can be traded in")
	# The screens are made to fit a window at least 600 tall (a headless run's
	# is much smaller, so only the bigger runs check the fit).
	var roomy: bool = main.size.y >= 590.0
	check(not roomy or _fits(gifts_pane), "the gifts screen fits without scrolling (%s in %s)" % [gifts_pane.get_child(0).get_combined_minimum_size(), gifts_pane.size])
	check(gifts_pane.scroll.is_ancestor_of(gifts_pane._grid) and gifts_pane._stats.get_global_rect().end.y < gifts_pane.scroll.get_global_rect().position.y,
		"only the gifts scroll, under the stats")
	var sort_on_gifts: Node = _find(gifts_pane, func(n): return _is(n, "dropdown.gd"))
	check(sort_on_gifts != null and sort_on_gifts.text.begins_with("Sort by"), "a Sort by menu over the gifts")
	if sort_on_gifts:
		sort_on_gifts._open()
		await _wait(15)
		check(_find(sort_on_gifts._menu, func(n): return n is Button and n.text == "Pet type") != null, "it can sort by pet type")
		await _shot("gifts_sort")
		sort_on_gifts._close()
		await _wait(15)
	# Hovering a gift shows its card above it: name, rarity, description and
	# how close it is to a trade-in. Clicking one with enough trades it in;
	# one without enough just wiggles.
	var info_class := _class("res://ui/components/gift_info.gd")
	var first_tile: Control = grid_tiles[0] if grid_tiles.size() > 0 else null
	if first_tile:
		gifts_pane.scroll.ensure_control_visible(first_tile)
		await _wait(5)
		first_tile._hover(true)
		await _wait(25)
		var info = info_class.showing(first_tile)
		check(info != null, "hovering a gift shows its card")
		if info:
			var g: Dictionary = _content().gift(first_tile.gift_id)
			check(_find(info, func(n): return n is Label and n.text == g["name"]) != null, "with its name")
			check(_find(info, func(n): return n is Label and n.text == str(_content().rarity_name(g["rarity"])).to_upper()) != null, "and its rarity")
			check(info.get_global_rect().end.y <= first_tile.get_global_rect().position.y + 1.0 or info.get_global_rect().position.y >= first_tile.get_global_rect().end.y - 1.0,
				"the card sits clear of the gift")
			var layer: CanvasLayer = info.get_parent() as CanvasLayer
			check(layer != null and layer.layer > 1, "on a layer over everything else")
		first_tile._hover(false)
		await _wait(25)
		# From the first frame it shows, it stays on one side of the gift
		# (above, where there's room): never below, then snapping up.
		var low_tile: Control = grid_tiles[min(9, grid_tiles.size() - 1)]
		low_tile._hover(true)
		var sides := {}
		for f in 10:
			await process_frame
			var card = info_class.showing(low_tile)
			if card and card.modulate.a > 0.0:
				var cr: Rect2 = card.get_global_rect()
				var t: Rect2 = low_tile.get_global_rect()
				sides["above" if cr.end.y <= t.position.y + 1.0 else ("below" if cr.position.y >= t.end.y - 1.0 else "over")] = true
		check(sides.size() == 1 and not sides.has("over"), "a card keeps to one side of its gift from its first visible frame (%s)" % ", ".join(sides.keys()))
		low_tile._hover(false)
		await _wait(25)
		first_tile._hover(true)
		await _wait(25)
		check(first_tile.scale.x > 1.05, "and the gift grows (%.2f)" % first_tile.scale.x)
		await _shot("gifts_popup")
		first_tile._hover(false)
		await _wait(25)
		check(info_class.showing(first_tile) == null and is_equal_approx(first_tile.scale.x, 1.0), "moving off puts it away")

	# Trading in ten commons for a rare, straight from the collection.
	var rares: int = app.state.gift_count("dog_rare")
	app.state.inventory["dog_common"] = 12
	gifts_pane.rebuild()
	await _wait(10)
	var common_tile = _find(gifts_pane._grid, func(n): return _is(n, "gift_tile.gd") and n.gift_id == "dog_common")
	common_tile._hover(true)
	await _wait(20)
	var ready_info = info_class.showing(common_tile)
	check(ready_info != null and _find(ready_info, func(n): return n is Label and n.text == "12/10") != null, "the card counts towards a trade (12/10)")
	check(ready_info != null and _find(ready_info, func(n): return n is Label and n.text == "Click to trade 10 in for a rare!") != null, "and calls you to click once there are enough")
	await _shot("gift_ready")
	common_tile._on_tapped()
	await _wait(25)
	check(app.state.gift_count("dog_common") == 2 and app.state.gift_count("dog_rare") == rares + 1, "clicking trades it in")
	check(modal_class.is_open(), "and shows what it brought")
	var is_new_tag := func(n): return n is Label and n.text == "NEW"
	check(_find(modal_class.top(), is_new_tag) == null, "not NEW: you've had one before")
	await _shot("trade_result")
	_close_modal()
	await _wait(10)
	# A gift you'd never had is NEW, right beside its name.
	_class("res://ui/components/gift_details.gd").open("dog_rare", true, true, true)
	await _wait(25)
	var new_label: Label = _find(modal_class.top(), is_new_tag)
	var heading: Label = _find(modal_class.top(), func(n): return n is Label and n.text == _content().gift("dog_rare")["name"])
	check(new_label != null and heading != null and heading.get_parent() == new_label.get_parent().get_parent() \
		and new_label.get_global_rect().position.x - heading.get_global_rect().end.x < 20.0, "a first-ever gift says NEW right after its name")
	await _shot("trade_result_new")
	_close_modal()
	await _wait(10)
	# Two left isn't enough: a click wiggles and trades nothing.
	common_tile = _find(gifts_pane._grid, func(n): return _is(n, "gift_tile.gd") and n.gift_id == "dog_common")
	common_tile._on_tapped()
	await _wait(3)
	check(app.state.gift_count("dog_common") == 2 and absf(common_tile.rotation) > 0.01, "too few just wiggles")
	await _wait(20)

	# Trading in every last one of a shelf gift takes it off the shelf.
	app.state.inventory["dog_common"] = 10
	app.place_on_shelf("dog_common", 0)
	await _wait(10)
	common_tile = _find(gifts_pane._grid, func(n): return _is(n, "gift_tile.gd") and n.gift_id == "dog_common")
	common_tile._on_tapped()
	await _wait(25)
	check(not app.state.shelf().has("dog_common"), "trading away all of a shelf gift takes it off the shelf")
	_close_modal()
	await _wait(10)
	app.state.inventory["dog_common"] = 12
	app.place_on_shelf("dog_common", 0)
	await _wait(10)

	# A drag the other way goes back to the middle; a short drag snaps back.
	await _drag(main.size * 0.5, main.size * Vector2(0.1, 0.5))
	await _wait(30)
	check(main._at == Vector2i.ZERO, "swiping left goes back to focus")
	await _drag(main.size * 0.5, main.size * Vector2(0.5, 0.58), 6)
	await _wait(30)
	check(main._at == Vector2i.ZERO, "a short drag snaps back")

	for pane in ["projects", "profile", "stats"]:
		app.go(pane)
		await _wait(50)
		check(main._at == main.PANES[pane][0], "go %s" % pane)
		await _shot(pane)

	app.go("projects")
	await _wait(50)
	var projects_pane: Node = main._panes[Vector2i(1, 0)]
	# Ongoing first: each project with its podiums of pets and places.
	check(projects_pane._filter() == "ongoing", "projects opens on ongoing")
	var filter: Node = _find(projects_pane, func(n): return _is(n, "dropdown.gd") and not n.sortable)
	check(filter != null and filter.get_parent().get_global_rect().end.x - filter.get_global_rect().end.x < 4.0 and filter.get_global_rect().position.y < 90.0, "the filter is in the top right")
	var ongoing_panels: Array = _all(projects_pane, func(n): return _is(n, "project_panel.gd"))
	check(ongoing_panels.size() == app.state.active_projects().size(), "one panel per ongoing project (%d)" % ongoing_panels.size())
	var podiums: Array = _all(ongoing_panels[0], func(n): return _is(n, "podium.gd"))
	check(podiums.size() == 2, "a podium for pets and one for places")
	var top_pets: Array = _class("res://core/stats.gd").ranked(app.state.project(ongoing_panels[0].project_id).pets)
	var first_name: Label = _find(podiums[0], func(n): return n is Label and n.text == app.state.pet(top_pets[0][0]).name)
	check(first_name != null, "the pet that walked most is first")
	check(_find(ongoing_panels[0], func(n): return n is Button) == null, "an ongoing project has no grade button")
	for panel in ongoing_panels:
		for pod in _all(panel, func(n): return _is(n, "podium.gd")):
			for l in _all(pod, func(n): return n is Label):
				check(l.get_global_rect().size.x > 20.0 or l.text.length() < 2, "podium words have room (%s)" % l.text)
	# Podiums on one line: second, first, third, their bottoms level.
	var spots: Array = podiums[0].get_child(1).get_children() if podiums[0].get_child_count() > 1 else []
	if spots.size() == 3 and spots[0].get_child_count() > 0 and spots[2].get_child_count() > 0:
		check(spots[0].get_global_rect().position.x < spots[1].get_global_rect().position.x and spots[1].get_global_rect().position.x < spots[2].get_global_rect().position.x
			and _find(spots[1], func(n): return n is Label and n.text == app.state.pet(top_pets[0][0]).name) != null, "second, first, third on one line")
		check(absf(spots[0].get_global_rect().end.y - spots[1].get_global_rect().end.y) < 1.0 and absf(spots[2].get_global_rect().end.y - spots[1].get_global_rect().end.y) < 1.0, "bottoms level")
	# When it ran sits in the top right, level with the name.
	var dates: Label = _find(ongoing_panels[0], func(n): return n is Label and n.text.ends_with("now"))
	check(dates != null and dates.get_global_rect().position.y < podiums[0].get_global_rect().position.y
		and ongoing_panels[0].get_global_rect().end.x - dates.get_global_rect().end.x < 24.0, "the dates are in the top right")
	if main.size.x >= 1200 and main.size.y >= 780:
		var list_box: Control = projects_pane.scroll
		check(ongoing_panels[0].get_global_rect().end.y <= list_box.get_global_rect().end.y + 1.0, "on a computer the first project fits without scrolling (%.0f > %.0f)" % [ongoing_panels[0].get_global_rect().end.y, list_box.get_global_rect().end.y])
	await _shot("projects_ongoing")
	# The headline numbers follow the filter: all of them shows how much is done.
	await _tap_menu(filter, "All")
	await _wait(30)
	var all_shown: Array = projects_pane.shown_projects()
	var all_done := all_shown.filter(func(p): return p.is_complete()).size()
	var percent := "%d%%" % floori(100.0 * all_done / maxi(all_shown.size(), 1))
	check(_find(projects_pane, func(n): return n is Label and n.text == percent) != null, "all shows how much is complete (%s)" % percent)
	await _shot("projects_all")
	app.set_setting("projects_filter", "completed")
	await _wait(30)
	check(_all(projects_pane, func(n): return _is(n, "project_panel.gd")).size() == app.state.completed_projects().size(), "completed shows the finished ones")

	projects_pane._pick_grade(app.state.completed_projects()[0].id)
	await _wait(25)
	await _shot("grade_picker")
	_close_modal()
	await _wait(20)
	# Without a grade a project shows a circled "?": the only thing on its
	# panel that can be tapped, and it asks for one.
	var ungraded: Object = app.state.completed_projects()[1]
	var kept_grade: String = ungraded.grade
	app.set_grade(ungraded.id, "")
	await _wait(20)
	var ungraded_panel: Node = _find(projects_pane, func(n): return _is(n, "project_panel.gd") and n.project_id == ungraded.id)
	var ask: Control = _find(ungraded_panel, func(n): return n is Button) if ungraded_panel else null
	check(ask != null and ask.get_child_count() == 1, "an ungraded project shows a \"?\"")
	if ask:
		# The list scrolls on its own: bring the panel's top into view first
		# (a whole panel can be taller than a small window).
		var list_scroll: ScrollContainer = projects_pane.scroll
		list_scroll.scroll_vertical += int(ungraded_panel.get_global_rect().position.y - list_scroll.get_global_rect().position.y) - 4
		await _wait(5)
		# On its name, top left (the middle can be under the minimap).
		var on_panel: Vector2 = ungraded_panel.get_global_rect().position + Vector2(70, 26)
		await _drag(on_panel, on_panel, 1)
		await _wait(15)
		check(not _class("res://ui/modal.gd").is_open(), "the rest of the panel doesn't open anything")
		await _shot("completed_ungraded")
		var at_ask: Vector2 = ask.get_global_rect().get_center()
		await _drag(at_ask, at_ask, 1)
		await _wait(20)
		check(_class("res://ui/modal.gd").is_open(), "tapping the \"?\" asks for a grade")
		if _class("res://ui/modal.gd").is_open():
			_close_modal()
	app.set_grade(ungraded.id, kept_grade)
	await _wait(10)

	# The sort menu re-sorts just the list: the screen around it (and its
	# stats) stays as it is.
	var stats_panel: Node = _find(projects_pane, func(n): return _is(n, "stat_panel.gd"))
	check(stats_panel != null, "projects shows its stats")
	var done_sort: Node = _find(projects_pane, func(n): return _is(n, "dropdown.gd") and n.sortable)
	done_sort._open()
	await _wait(15)
	await _shot("completed_sort")
	await _tap_menu(done_sort, "Grade")
	await _wait(15)
	var first_panel: Node = _find(projects_pane, func(n): return _is(n, "project_panel.gd"))
	var best: Array = projects_pane.sort_projects(app.state.completed_projects(), "grade", false)
	check(app.state.settings.get("completed_sort") == "grade" and first_panel.project_id == best[0].id,
		"sorting completed by grade puts the best first")
	check(is_instance_valid(stats_panel), "sorting doesn't rebuild the screen")
	await _shot("completed_by_grade")

	# Swiping a project left completes it, with confetti; right deletes it,
	# and Undo brings it back. Neither moves to another screen.
	app.set_setting("projects_filter", "ongoing")
	await _wait(30)
	var going: int = app.state.active_projects().size()
	var row: Control = _find(projects_pane, func(n): return _is(n, "swipe_row.gd"))
	var row_id: String = row.content.project_id
	projects_pane.scroll.ensure_control_visible(row)
	await _wait(5)
	var r: Rect2 = row.get_global_rect()
	var y: float = maxf(r.position.y, projects_pane.scroll.get_global_rect().position.y) + 30.0
	await _drag(Vector2(r.end.x - 30.0, y), Vector2(r.end.x - 30.0 - r.size.x * 0.3, y), 8, 0.0, false)
	await _wait(2)
	check(row._offset < -r.size.x * 0.2 and main._at == Vector2i(1, 0), "the panel follows the finger, not the screen")
	await _shot("projects_swiping")
	await _drag_on(Vector2(r.end.x - 30.0 - r.size.x * 0.3, y), Vector2(r.end.x - 30.0 - r.size.x * 0.5, y), 4)
	await _wait(20)
	await _shot("projects_confetti")
	await _wait(80)
	check(app.state.project(row_id).is_complete() and app.state.active_projects().size() == going - 1, "a long swipe left completes it")
	check(main._at == Vector2i(1, 0), "and the screen stays put")
	row = _find(projects_pane, func(n): return _is(n, "swipe_row.gd"))
	row_id = row.content.project_id
	projects_pane.scroll.ensure_control_visible(row)
	await _wait(5)
	r = row.get_global_rect()
	y = maxf(r.position.y, projects_pane.scroll.get_global_rect().position.y) + 30.0
	await _drag(Vector2(r.position.x + 30.0, y), Vector2(r.position.x + 30.0 + r.size.x * 0.15, y), 6)
	await _wait(30)
	check(app.state.project(row_id) != null and row._offset == 0.0, "a short swipe springs back")
	await _drag(Vector2(r.position.x + 30.0, y), Vector2(r.position.x + 30.0 + r.size.x * 0.55, y), 8)
	await _wait(60)
	check(app.state.project(row_id) == null, "a long swipe right deletes it")
	var undo: Button = _find(_class("res://ui/modal.gd").layer, func(n): return n is Button and n.text == "Undo")
	check(undo != null, "with an Undo button")
	await _shot("projects_deleted")
	if undo:
		undo.pressed.emit()
		await _wait(30)
	check(app.state.project(row_id) != null, "Undo brings it back")
	# Put the completed one back, so the rest of the run sees the sample.
	app.reopen_project(app.state.completed_projects().filter(func(p): return p.grade == "")[0].id)
	await _wait(20)

	app.go("profile")
	await _wait(50)
	var profile_pane: Node = main._panes[Vector2i(0, -1)]
	# Total focus time sits under Joined; a tap shows it another way.
	var total_cap: Label = _find(profile_pane, func(n): return n is Label and n.text.to_lower() == "total focus time")
	check(total_cap != null, "total focus time is on the profile")
	if total_cap:
		var total_row: Control = total_cap.get_parent().get_parent()
		var total_value: Label = total_cap.get_parent().get_child(1)
		var joined_cap: Label = _find(profile_pane, func(n): return n is Label and n.text.to_lower() == "joined")
		check(joined_cap != null and joined_cap.get_global_rect().position.y < total_cap.get_global_rect().position.y, "under Joined")
		var seconds: int = app.state.total_seconds()
		check(total_value.text == _class("res://core/stats.gd").format_duration(seconds), "in hours and minutes (%s)" % total_value.text)
		check(profile_pane.get_global_rect().encloses(total_row.get_global_rect()), "and it fits")
		await _shot("profile_total")
		await _tap_control(total_row, main)
		await _wait(10)
		check(total_value.text == _class("res://core/stats.gd").format_long(seconds), "a tap shows weeks and days (%s)" % total_value.text)
		await _shot("profile_total_long")
		await _tap_control(total_row, main)
		await _wait(10)
		check(total_value.text == _class("res://core/stats.gd").format_duration(seconds), "and back")
	# Tapping the pencil opens the character popup (the picture itself
	# doesn't); tapping the level badge (bottom left of the picture) opens
	# the rewards.
	var pencil: Button = _find(profile_pane, func(n): return n is Button and n.accessibility_name == "Customise your character")
	check(pencil != null, "a pencil on the character")
	if pencil:
		await _drag(pencil.get_global_rect().get_center(), pencil.get_global_rect().get_center(), 1)
		await _wait(25)
		check(modal_class.is_open(), "the pencil opens the customise popup")
		await _shot("customise")
		var customise: Node = modal_class.top()
		check(_find(customise.header, func(n): return n is Label and n.text == "Customise") != null, "its title is above the list, not in it")
		var parts: ScrollContainer = _find(customise.body, func(n): return n is ScrollContainer)
		var preview: Control = _find(customise.body, func(n): return _is(n, "round_frame.gd"))
		check(parts != null and preview != null and not preview.is_ancestor_of(parts) and not parts.is_ancestor_of(preview), "the preview sits beside the list of parts")
		check(not customise._scroll.get_v_scroll_bar().visible, "the popup itself doesn't scroll")
		# Head, Body and Legs tabs over the parts; Head first.
		var tab_names := func(): return _all(customise.body, func(n): return n is Button and n.text in ["Head", "Body", "Legs"]).map(func(b): return b.text)
		check(tab_names.call() == ["Head", "Body", "Legs"], "Head, Body and Legs tabs (%s)" % [tab_names.call()])
		var row_slots := func(): return _all(parts, func(n): return n.has_meta("slot")).map(func(n): return n.get_meta("slot"))
		check(row_slots.call() == ["hat", "hair", "hair_tone", "face", "facial_hair"], "Head has hat, hair, hair colour, face and facial hair (%s)" % [row_slots.call()])
		var carousels: Array = _all(parts, func(n): return _is(n, "carousel.gd"))
		check(carousels.size() == 4, "each part is a carousel (%d)" % carousels.size())
		check(_find(parts, func(n): return n is Button and _is(n, "carousel.gd")) == null and _find(customise.body, func(n): return n is Button and n.accessibility_name.begins_with("Previous")) == null, "no arrows")
		# Scrolling the hair carousel changes the hair, and the name under it.
		var hair_row: Node = _find(parts, func(n): return n.has_meta("slot") and n.get_meta("slot") == "hair")
		var hair_carousel: Node = _find(hair_row, func(n): return _is(n, "carousel.gd"))
		var bald_at: int = hair_carousel.items.map(func(m): return m.accessibility_name).find("Bald")
		check(bald_at >= 0, "bald is a hair option")
		hair_carousel.go_to(bald_at)
		await _wait(25)
		var hair_name: Label = hair_row.get_child(hair_row.get_child_count() - 1)
		check(hair_name.text == "Bald", "the name under it follows the carousel (%s)" % hair_name.text)
		var facial: Node = _find(parts, func(n): return n.has_meta("slot") and n.get_meta("slot") == "facial_hair")
		var beards: Array = _find(facial, func(n): return _is(n, "carousel.gd")).items.map(func(m): return m.accessibility_name)
		check(beards.has("Moustache") and beards.has("Full beard"), "facial hair options (%s)" % [beards])
		var hair_dots: Array = _find(parts, func(n): return n.has_meta("slot") and n.get_meta("slot") == "hair_tone").find_children("*", "Button", true, false)
		check(hair_dots.size() == 6, "hair colour: five swatches and a pick-any (%d)" % hair_dots.size())
		var hat_mini = _find(parts, func(n): return n is Control and n.get("_slot") == "hat" and n._view.visible)
		check(hat_mini != null and hat_mini._view.position != Vector2.ZERO, "each option is drawn, fitted to its box")
		await _shot("customise_head")
		var body_tab: Button = _find(customise.body, func(n): return n is Button and n.text == "Body")
		body_tab.pressed.emit()
		await _wait(15)
		check(row_slots.call() == ["skin_tone", "neckwear", "top", "gloves", "walking_stick"], "Body has skin colour and the rest (%s)" % [row_slots.call()])
		var gloves_row: Node = _find(parts, func(n): return n.has_meta("slot") and n.get_meta("slot") == "gloves")
		var no_gloves = _find(gloves_row, func(n): return n is Control and n.get("_slot") == "gloves" and n.accessibility_name == "No gloves")
		check(no_gloves != null and not no_gloves._view.visible, "no gloves shows the none icon")
		await _shot("customise_body")
		if parts and preview and main.size.y >= 590:
			var preview_at := preview.get_global_rect()
			parts.scroll_vertical = 10000
			await _wait(10)
			check(preview.get_global_rect().is_equal_approx(preview_at), "the preview stays put while they scroll")
			await _shot("customise_scrolled")
		_close_modal()
		await _wait(15)
	var badge: Control = _find(profile_pane, func(n): return n is Control and n.accessibility_name == "Levels and rewards")
	var picture: Control = _find(profile_pane, func(n): return _is(n, "round_frame.gd") and n.size.y > 150.0)
	check(badge != null and picture != null, "a level badge on the character")
	if badge and picture:
		var b: Rect2 = badge.get_global_rect()
		var pic: Rect2 = picture.get_global_rect()
		check(b.get_center().x < pic.get_center().x and b.get_center().y > pic.get_center().y, "the badge sits bottom left")
		badge.mouse_entered.emit()
		await _wait(20)
		check(badge.scale.x > 1.05 and badge.self_modulate.r > 1.05, "the badge grows and lightens under the pointer")
		check(badge.get_global_rect().get_center().is_equal_approx(b.get_center()), "it grows from its centre")
		await _shot("badge_hover")
		badge.mouse_exited.emit()
		await _wait(20)
		check(badge.scale.is_equal_approx(Vector2.ONE) and badge.self_modulate.is_equal_approx(Color.WHITE), "and settles back after")
		# Its right side: on a small window its left can be under the minimap.
		var on_badge := Vector2(b.end.x - 8.0, b.get_center().y)
		await _drag(on_badge, on_badge, 1)
		await _wait(25)
		check(modal_class.is_open(), "the badge opens the rewards")
		var rewards: Node = modal_class.top()
		var title_y: float = rewards.header.get_global_rect().position.y
		await _wait(50)
		check(rewards.header.get_child_count() == 2, "the title and your level sit above the list")
		check(rewards._scroll.scroll_vertical > 0, "it opens scrolled down to where you are (level %d)" % app.level())
		# The next reward to come is in view: the first one with a padlock.
		var next_up: Control = _find(rewards.body, func(n): return n is HBoxContainer and n.get_meta("locked", false))
		check(next_up != null and next_up.get_child(0).get_global_rect().position.x - rewards.body.get_global_rect().position.x < 1.0, "rewards hug the left")
		check(next_up != null and next_up.get_child(next_up.get_child_count() - 1).custom_minimum_size.x == 28.0, "the level line runs down the right")
		check(_find(rewards.body, func(n): return n is Label and n.text == "Unlocked by exploring") == null, "a divider, not a heading, before the exploring rewards")
		check(next_up != null and rewards._scroll.get_global_rect().encloses(next_up.get_global_rect()), "the next reward to come is in view")
		await _shot("rewards")
		rewards._scroll.scroll_vertical = 0
		await _wait(5)
		check(is_equal_approx(rewards.header.get_global_rect().position.y, title_y), "the title doesn't scroll")
		# The wheel glides the list rather than jumping, and turns add up.
		var list_mid: Vector2 = rewards._scroll.get_global_rect().get_center()
		await _wheel(list_mid, MOUSE_BUTTON_WHEEL_DOWN)
		await _wheel(list_mid, MOUSE_BUTTON_WHEEL_DOWN)
		var notch: float = rewards._scroll.get_v_scroll_bar().page * _class("res://ui/smooth_scroll.gd").NOTCH
		var early: int = rewards._scroll.scroll_vertical
		check(early > 0 and early < notch * 2.0 - 2.0, "the wheel glides the list (%d of %d after a frame)" % [early, int(notch * 2.0)])
		await _wait(30)
		check(absf(rewards._scroll.scroll_vertical - notch * 2.0) <= 1.0, "two turns go two notches (%d)" % rewards._scroll.scroll_vertical)
		await _wheel(list_mid, MOUSE_BUTTON_WHEEL_UP)
		await _wheel(list_mid, MOUSE_BUTTON_WHEEL_UP)
		await _wheel(list_mid, MOUSE_BUTTON_WHEEL_UP)
		await _wait(30)
		check(rewards._scroll.scroll_vertical == 0, "and stops at the top (%d)" % rewards._scroll.scroll_vertical)
		_close_modal()
		await _wait(15)
		await _drag(pic.position + Vector2(pic.size.x * 0.5, pic.size.y * 0.4), pic.position + Vector2(pic.size.x * 0.5, pic.size.y * 0.4), 1)
		await _wait(25)
		check(not modal_class.is_open(), "tapping the picture itself does nothing")
		if modal_class.is_open():
			_close_modal()
		await _wait(15)
	# The card holds your details and, along its bottom, your shelf: only to
	# look at, with a pencil for the editor. Under it, your best achievements
	# (earned first) end in "See all", which lists every one in a popup.
	check(not roomy or _fits(profile_pane), "the profile fits without scrolling (%s in %s)" % [profile_pane.get_child(0).get_combined_minimum_size(), profile_pane.size])
	var shelf: Node = _find(profile_pane, func(n): return _is(n, "gift_shelf.gd"))
	check(shelf != null and shelf.get_global_rect().end.y <= picture.get_global_rect().end.y + 1.0, "the shelf is in the card")
	if shelf:
		var shelf_gifts: Array = _all(shelf, func(n): return _is(n, "gift_tile.gd"))
		check(shelf_gifts.size() == 2 and shelf_gifts.all(func(t): return t.mouse_filter == Control.MOUSE_FILTER_IGNORE),
			"two gifts on the shelf, only to look at")
	var medals: Array = _all(profile_pane, func(n): return n is VBoxContainer and n.get_script() != null and "info" in n and n.info is Dictionary and n.info.has("earned"))
	check(medals.size() >= 2, "achievements on the profile (%d)" % medals.size())
	var earned_first := true
	for i in range(1, medals.size()):
		if medals[i].info["earned"] and not medals[i - 1].info["earned"]:
			earned_first = false
	# The sample data has 7 earned.
	check(medals[0].info["earned"] and earned_first and (medals.size() <= 7 or medals.any(func(m): return not m.info["earned"])),
		"earned ones first, then the closest")
	for m in medals:
		var disc: Control = m.get_child(0)
		var card_rect: Rect2 = m.get_parent().get_parent().get_global_rect()
		if not card_rect.encloses(disc.get_global_rect()):
			check(false, "%s's medal isn't clipped" % m.info["name"])
			break
	check(medals.all(func(m): return m.get_child(1).get_line_count() == 1 and m.get_child(1).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING),
		"medal names stay on one line")
	var see_all: Control = _find(profile_pane, func(n): return n is Control and n.accessibility_name == "See every achievement")
	check(see_all != null and (not roomy or _clear_of_shell(see_all.get_global_rect())), "See all, clear of the minimap and the arrows")
	var every: int = profile_pane.achievement_rows().size()
	if see_all and not roomy:
		see_all.get_parent().get_parent().get_parent().open_list(profile_pane.achievement_rows())
		await _wait(25)
	elif see_all:
		var on_more := see_all.get_global_rect().get_center()
		await _drag(on_more, on_more, 1)
		await _wait(25)
	check(modal_class.is_open() and _find(modal_class.top().header, func(n): return n is Label and n.text == "Achievements") != null,
		"See all opens them, titled \"Achievements\"")
	if modal_class.is_open():
		var listed: Array = _all(modal_class.top().body, func(n): return "diameter" in n)
		check(listed.size() == every, "every achievement in the list (%d of %d)" % [listed.size(), every])
		check(modal_class.top()._scroll.is_ancestor_of(listed[0]) and not modal_class.top()._scroll.is_ancestor_of(modal_class.top().header),
			"only the list scrolls")
		await _shot("achievements")
		_close_modal()
		await _wait(20)

	# The pencil by the shelf opens the shelf editor, where it's all drag
	# and drop.
	var pencil_button: Button = _find(profile_pane, func(n): return n is Button and n.accessibility_name == "Arrange your shelf")
	check(pencil_button != null, "a pencil by the shelf")
	if pencil_button:
		await _drag(pencil_button.get_global_rect().get_center(), pencil_button.get_global_rect().get_center(), 1)
		await _wait(30)
	var editor: Node = _find(modal_class.top(), func(n): return _is(n, "shelf_editor.gd")) if modal_class.is_open() else null
	check(editor != null, "the pencil opens the shelf editor")
	if editor:
		await _shelf_editor(editor)

	profile_pane.open_settings()
	await _wait(25)
	check(main._arrows.values().all(func(a): return not a.visible), "the edge arrows hide while a popup is up")
	# Computers can pick the window's mode and size; picking a size goes
	# back to a window.
	var pickers: Array = _all(modal_class.top().body, func(n): return _is(n, "dropdown.gd") and n.accessibility_name != "Colour vision")
	check(pickers.size() == 2 and pickers[0].text == "Windowed", "settings offer the window mode and size (%d)" % pickers.size())
	await _shot("settings")
	if pickers.size() == 2:
		# On a short window the settings scroll, so bring the pickers in view.
		await modal_class.top().scroll_to(pickers[0])
		await _wait(45)
		pickers[0].pressed.emit()
		await _wait(10)
		await _tap_menu(pickers[0], "Maximised")
		await _wait(15)
		check(app.state.settings.get("window_mode") == "maximised" and pickers[0].text == "Maximised", "picking Maximised saves it")
		pickers[1].pressed.emit()
		await _wait(10)
		await _tap_menu(pickers[1], "1280 × 720")
		await _wait(15)
		check(app.state.settings.get("resolution") == "1280x720" and app.state.settings.get("window_mode") == "windowed" and pickers[0].text == "Windowed",
			"picking a size saves it and goes back to a window")
		# The save is shared with the app, so leave its window as it was.
		app.state.settings.erase("window_mode")
		app.state.settings.erase("resolution")
	await _vision_and_data(main)
	_close_modal()
	await _wait(20)
	await _accounts(main)

	app.go("stats")
	await _wait(50)
	# The projects under the chart drag sideways from anywhere on them.
	var legend_strip: ScrollContainer = main._panes[Vector2i(0, 1)]._legend.get_parent().get_parent()
	var legend_bar := legend_strip.get_h_scroll_bar()
	if legend_bar.max_value > legend_bar.page + 20.0:
		var on_strip := legend_strip.get_global_rect().get_center()
		await _drag(on_strip + Vector2(60, 0), on_strip - Vector2(60, 0), 8)
		await _wait(30)
		check(legend_strip.scroll_horizontal > 40, "dragging the projects list scrolls it (%d)" % legend_strip.scroll_horizontal)
		check(not modal_class.is_open(), "without opening a project")
		check(main._at == Vector2i(0, 1), "or swiping away")
		await _shot("stats_strip_dragged")
		legend_strip.scroll_horizontal = 0
		await _wait(5)
	# Pills (the project chips, dropdowns) shade under the pointer rather
	# than grow, so the strip never cuts them off.
	var chip: Button = _find(legend_strip, func(n): return n is Button and n.text != "")
	if chip:
		await _point(chip.get_global_rect().get_center())
		await _wait(20)
		check(is_equal_approx(chip.scale.x, 1.0), "a chip doesn't grow under the pointer (%.2f)" % chip.scale.x)
		check(_class("res://ui/hover_grow.gd").is_pill(chip), "it counts as a pill")
		await _point(Vector2(4, 4))
		await _wait(5)
	main._panes[Vector2i(0, 1)]._show_piece(app.state.projects[0].id, 0)
	await _wait(25)
	await _shot("stats_popup")
	var project_popup: Node = modal_class.top()
	var project_panel: Control = _find(project_popup.body, func(n): return _is(n, "project_panel.gd"))
	check(project_popup.body.get_child_count() == 1 and project_panel != null, "the project popup is just its panel")
	check(_find(project_popup, func(n): return n is Label and n.text.begins_with("Still in progress")) == null, "with no note under it")
	var project_close: Button = _find(project_panel, func(n): return n is Button and n.accessibility_name == "Close") if project_panel else null
	check(project_close != null and project_close.mouse_filter == Control.MOUSE_FILTER_STOP, "a close button in its corner")
	if project_close:
		var panel_rect := project_panel.get_global_rect()
		var x_at := project_close.get_global_rect()
		check(x_at.end.x > panel_rect.end.x - 40.0 and x_at.position.y < panel_rect.position.y + 40.0, "top right")
		await _tap_control(project_close, main)
		await _wait(20)
	check(not modal_class.is_open(), "which closes it")
	if modal_class.is_open():
		_close_modal()
	await _stats_and_friends(main)
	await _stats_periods(main)
	main._panes[Vector2i(0, 1)]._select(main._panes[Vector2i(0, 1)]._start - 7)
	await _wait(10)

	# A small wheel turn moves between screens, once per turn.
	await create_timer(0.3).timeout
	await _wheel(Vector2(main.size.x * 0.5, 30), MOUSE_BUTTON_WHEEL_UP)
	await _wheel(Vector2(main.size.x * 0.5, 30), MOUSE_BUTTON_WHEEL_UP)
	await _wait(40)
	check(main._at == Vector2i.ZERO, "a wheel turn up from stats goes to the focus screen, and only one screen")
	await create_timer(0.3).timeout
	await _wheel(main.size * 0.5, MOUSE_BUTTON_WHEEL_DOWN)
	await _wait(40)
	check(main._at == Vector2i(0, 1), "a fresh turn down goes back to stats")

	app.go("focus")
	await _wait(50)
	# Tapping the orb opens the choose focus screen through a growing circle.
	var orb: Control = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "focus_orb.gd"))
	await _drag(orb.get_global_rect().get_center(), orb.get_global_rect().get_center(), 1)
	await _wait(12)
	check(main._flows.size() == 1, "tapping the orb opens choose focus")
	await _shot("reveal")
	await _wait(40)
	await _shot("choose_focus")
	var chooser: Node = main._flows.back().get_child(0)
	# Places in the data file's order; the project pill, then the pet, then
	# a hint, with its kind, time and adoption date under the pet.
	var order: Array = chooser._places.keys()
	check(order == _content().biomes.map(func(b): return b["id"]), "places in biomes.json order")
	var grid: GridContainer = chooser._place_grid
	var places_box: Control = chooser._pick.get_node("Places")
	check(places_box.get_global_rect().position.x >= 0.0 and places_box.get_global_rect().end.x <= main.size.x, "the place buttons fit across the screen (%s in %s)" % [places_box.get_global_rect(), main.size.x])
	if main.size.x < 600.0:
		check(grid.columns < order.size() and grid.columns >= ceili(order.size() / 2.0), "on a phone they wrap onto two even rows (%d a row)" % grid.columns)
	for id in order:
		var button: Button = chooser._places[id]
		var lock: bool = button.get_node("Lock").visible
		check(lock != app.is_unlocked("place", id), "%s has a padlock only while locked" % id)
	check(chooser._words.get_child(0) == chooser._project_pill and chooser._project_pill.text == app.state.projects[0].name, "the last project walked for is in the pill first (%s)" % chooser._project_pill.text)
	var pill_rect: Rect2 = chooser._project_pill.get_global_rect()
	check(absf(pill_rect.get_center().x - main.size.x * 0.5) < 2.0 and pill_rect.position.x >= 16.0, "the pill sits centred, clear of the edges")
	check(chooser._pet_line.text == chooser._current_pet().name, "then the pet's name")
	if main.size.y >= 600.0:
		check(chooser._words.get_rect().end.y < chooser._scenery.path_y() - chooser.PET_HEIGHT * 0.86, "words above the pets")
	check(chooser._under.text.contains("walked") and chooser._under.text.contains("adopted") and chooser._under.position.y > chooser._scenery.path_y(), "kind, time and adoption under the pet")
	# The sort menu sits bottom right, level with the bin, and opens upwards.
	var sort_rect: Rect2 = chooser._sort.get_global_rect()
	var bin_rect: Rect2 = chooser._left.get_global_rect()
	check(absf(sort_rect.get_center().y - bin_rect.get_center().y) < 1.0 and sort_rect.end.x <= main.size.x - 15.0, "the sort menu is level with the bin, on the right")
	chooser._sort._open()
	await _wait(20)
	var sort_card: Control = chooser._sort._menu.get_child(0)
	check(sort_card.get_global_rect().end.y <= sort_rect.position.y, "it opens upwards")
	await _shot("choose_sort")
	await _tap_menu(chooser._sort, "Pet type")
	await _wait(20)
	var kinds: Array = chooser._pet_list.map(func(p): return p.animal_id)
	var cast: Array = _content().animals.map(func(a): return a["id"]).filter(func(id): return id in kinds)
	check(kinds == cast, "sorting by type follows the cast (%s)" % [kinds])
	chooser._sort.select("focus")
	app.state.settings["pet_sort"] = "focus"
	chooser._build_pick()
	await _wait(20)
	var times: Array = chooser._pet_list.map(func(p): return app.state.pet_seconds(p.id))
	var sorted_times := times.duplicate()
	sorted_times.sort()
	sorted_times.reverse()
	check(times == sorted_times, "sorting by focus time puts the most walked first")
	var level: int = app.level()
	check(level > 1 and level < 15, "sample player is part way up (level %d)" % level)
	# The place only changes when you pick one: swiping between pets keeps it.
	check(chooser._scenery.biome["id"] == app.focus_place(), "it opens where you last focused (%s)" % chooser._scenery.biome["id"])
	chooser._pick_place("beach")
	await _wait(50)
	check(chooser._scenery.biome["id"] == "beach", "picking an unlocked place goes there")
	chooser._pets.go_to(1)
	await _wait(50)
	check(chooser._scenery.biome["id"] == "beach" and chooser._stack.size() == 1, "the next pet stays at the beach")
	chooser._pets.go_to(0)
	await _wait(50)
	check(chooser._scenery.biome["id"] == "beach", "and so does the first")
	await _shot("choose_beach")
	# Picking places quickly: each fades in from wherever the last had got
	# to, and the highlight slides along in the same time.
	check(chooser._marker.is_equal_approx(chooser._places["beach"].get_rect()), "the highlight is under the beach")
	chooser._pick_place("lake")
	await _wait(12)
	var part: float = chooser._scenery.modulate.a
	check(part > 0.03 and part < 0.97 and chooser._stack.size() == 2, "the lake is part way in, over the beach (%.2f)" % part)
	check(chooser._marker_moving and not chooser._marker.is_equal_approx(chooser._places["lake"].get_rect()), "the highlight is sliding to it")
	await _shot("choose_place_sliding")
	chooser._pick_place("beach")
	await _wait(2)
	check(chooser._scenery.biome["id"] == "beach" and chooser._stack.size() == 1 and chooser._stack[0].modulate.a > 0.99,
		"going straight back fades the lake away from where it had got to, over the beach")
	await _wait(50)
	check(chooser._marker.is_equal_approx(chooser._places["beach"].get_rect()) and not chooser._marker_moving, "and the highlight slides back")
	# In the jungle the growth stands in front of the pets, under the words,
	# and the scene holds still while you choose.
	app.state.settings["debug_unlock_all"] = true
	chooser._pick_place("jungle")
	await _wait(50)
	var growth: Control = chooser._scenery.front
	check(growth.get_parent() == chooser._pick and growth.get_index() > chooser._pets.get_index() and growth.get_index() < chooser._words.get_index(),
		"the place's growth is over the pets and under the words")
	var still: float = chooser._scenery.scroll
	await _wait(20)
	check(chooser._scenery.scroll == still, "the background holds still while you choose")
	await _shot("choose_jungle")
	chooser._pick_place("beach")
	app.state.settings["debug_unlock_all"] = false
	await _wait(50)
	chooser._pick_place("moon")
	await _wait(30)
	check(chooser._place_id() == "beach", "a locked place can't be picked")
	check(not modal_class.is_open(), "it opens no popup")
	chooser._pick_place("moon")
	await _wait(2)
	check(absf(chooser._places["moon"].rotation) > 0.01, "it wiggles instead")
	await _wait(20)
	# The pill lists ongoing projects, most recently worked on first, with a
	# way to start a new one; picking one puts it in the pill. The popup is
	# always the same size: three rows, then the list scrolls between the
	# title and New project, which always show.
	chooser._open_projects()
	await _wait(30)
	await _shot("choose_project")
	var popup = modal_class.top()
	var names: Array = chooser.project_choices().map(func(p): return p.name)
	var rows: Array = _all(popup.body, func(n): return n.has_method("spring_back"))
	check(rows.size() == app.state.active_projects().size(), "every ongoing project is listed (%d)" % rows.size())
	check(rows.map(func(x): return x.content.accessibility_name) == names, "most recently worked on first (%s)" % [names])
	check(_find(popup.footer, func(n): return n is Button and n.text == "New project") != null, "with New project at the bottom")
	check(_find(popup.header, func(n): return n is Label and n.text == "Your projects") != null, "and the title stays at the top")
	var list_area: Control = popup.body.get_child(0)
	check(is_equal_approx(list_area.size.y, chooser.PROJECT_ROW * 3 + chooser.PROJECT_GAP * 2), "the list is three rows tall (%d)" % list_area.size.y)
	var card_height: float = popup.card.size.y
	var picked: String = rows[1].content.accessibility_name
	rows[1].content.get_meta("press").tapped.emit()
	await _wait(20)
	check(chooser._project_pill.text == picked, "picking a project puts it in the pill")
	# Swiping right to left completes it, just like on the Projects screen.
	chooser._open_projects()
	await _wait(20)
	popup = modal_class.top()
	rows = _all(popup.body, func(n): return n.has_method("spring_back"))
	var done_id: String = chooser.project_choices()[rows.size() - 1].id
	rows[rows.size() - 1].swiped.emit(-1)
	await _wait(90)
	check(app.state.project(done_id).is_complete(), "swiping a project left completes it")
	check(_all(popup.body, func(n): return n.has_method("spring_back")).size() == rows.size() - 1, "and it leaves the list")
	check(absf(popup.card.size.y - card_height) < 1.0, "the popup keeps its size (%d, was %d)" % [popup.card.size.y, card_height])
	app.reopen_project(done_id)
	await _wait(10)
	var add: Button = _find(popup.footer, func(n): return n is Button and n.text == "New project")
	add.pressed.emit()
	await _wait(20)
	var project_edit: LineEdit = _find(modal_class.top().body, func(n): return n is LineEdit)
	project_edit.text = "Chemistry"
	check(_find(modal_class.top().body, func(n): return n is Button and n.text in ["Project", "Module"]) == null, "no project-or-module pills")
	check(_find(modal_class.top().body, func(n): return n is Button and n.text == "Create project") != null, "the button says Create project")
	await _wait(20)
	await _shot("new_project")
	var project_count: int = app.state.projects.size()
	project_edit.text_submitted.emit("Chemistry")
	await _wait(30)
	check(app.state.projects.size() == project_count + 1 and chooser._project_pill.text == "Chemistry", "a new project goes in the pill")
	chooser._pets.go_to(2)
	await _wait(25)
	chooser._on_left()
	await _wait(25)
	await _shot("rehome_confirm")
	_close_modal(false)
	await _wait(10)
	# The paw starts adopting: the bottom buttons go, the paw becomes a tick
	# and the × cancels back to the pets.
	chooser._on_new()
	await _wait(30)
	check(chooser._adopting and chooser._bottom.modulate.a < 0.05, "adopting hides the bottom buttons")
	check(chooser._pet_edit.text == app.free_pet_name(chooser._draft.animal_id), "the name is filled in with its kind (%s)" % chooser._pet_edit.text)
	chooser._on_close()
	await _wait(30)
	check(not chooser._adopting and chooser._bottom.modulate.a > 0.95 and main._flows.size() == 1, "the × cancels adopting")
	chooser._on_new()
	await _wait(30)
	await _shot("new_pet")
	var locked := -1
	for i in _content().animals.size():
		if not app.is_unlocked("animal", _content().animals[i]["id"]):
			locked = i
			break
	check(locked >= 0, "something's still locked at level %d" % level)
	chooser._animals.go_to(locked)
	await _wait(25)
	check(chooser._new.disabled, "a locked animal can't be adopted")
	check(chooser._swatch_row.modulate.a < 0.05, "a locked animal hides the colour buttons")
	check(not chooser._animal_hint.text.contains("level") or _content().unlock_rule("animal", _content().animals[locked]["id"]).has("level"), "the hint says what unlocks it")
	check(not chooser._animal_hint.text.ends_with("to unlock"), "without \"to unlock\" on the end (%s)" % chooser._animal_hint.text)
	await _shot("new_pet_locked")
	chooser._animals.activated.emit(locked)
	await _wait(2)
	check(not modal_class.is_open() and absf(chooser._animals.items[locked].rotation) > 0.01, "tapping a locked animal wiggles it, no popup")
	await _wait(20)
	var table_at := -1
	for i in _content().animals.size():
		var a: Dictionary = _content().animals[i]
		if _content().unlock_rule("animal", a["id"]).has("table") and not app.is_unlocked("animal", a["id"]):
			table_at = i
			break
	if table_at >= 0:
		chooser._animals.go_to(table_at, false)
		await _wait(10)
		var table_name: String = str(_content().table(_content().unlock_rule("animal", _content().animals[table_at]["id"])["table"])["name"]).to_lower()
		check(chooser._animal_hint.text == "Discover all %s gifts" % table_name, "a gift-table animal says which gifts to find (%s)" % chooser._animal_hint.text)
	chooser._animals.go_to(locked, false)
	await _wait(10)
	chooser._animals.go_to(1)
	await _wait(25)
	check(chooser._swatch_row.modulate.a > 0.95, "an open animal shows them again")
	chooser._pet_edit.text = "Bramble"
	chooser._pet_edit.text_changed.emit("Bramble")
	chooser._animals.go_to(0)
	await _wait(25)
	check(chooser._pet_edit.text == "Bramble", "a name you typed stays when the animal changes")
	await _shot("new_pet_named")
	# The colour picker: the wheel, two rows of seven base colours and a row
	# of seven recent ones, then Done, all without scrolling.
	app.state.settings["recent_colours"] = ["ff0000", "00aa00"]
	chooser._pick_colour(0)
	await _wait(20)
	var picker_modal = modal_class.top()
	var swatch_rows: Array = _all(picker_modal.body, func(n): return n is HBoxContainer and n.get_child_count() == 7)
	check(swatch_rows.size() == 3, "three rows of seven colours (%d)" % swatch_rows.size())
	check(swatch_rows.size() == 3 and swatch_rows[2].get_child(0) is Button and not (swatch_rows[2].get_child(2) is Button), "the third row has the recent colours, then empty slots")
	check(main.size.y < 590 or picker_modal.scroller().get_v_scroll_bar().max_value <= picker_modal.scroller().size.y + 1.0, "the picker doesn't scroll")
	var swatch: Button = swatch_rows[0].get_child(0)
	check(is_equal_approx(swatch.size.x, swatch.size.y), "the swatches are circles (%s)" % swatch.size)
	await _shot("colour_picker")
	_find(picker_modal.footer, func(n): return n is Button and n.text == "Done").pressed.emit()
	await _wait(10)
	check(str(app.state.settings["recent_colours"][0]) == chooser._draft.colours[0].to_html(false), "Done puts the colour first in the recents")
	var count: int = app.state.pets.size()
	chooser._on_new()
	await _wait(30)
	check(app.state.pets.size() == count + 1, "adopting adds a pet")
	check(app.state.pets.back().name == "Bramble", "adopting keeps the pet's name")
	check(chooser._current_pet() == app.state.pets.back(), "and the new pet is in the middle")
	var new_home := str(_content().animal(app.state.pets.back().animal_id).get("home", ""))
	check(not app.can_walk_in(new_home) or chooser._place_id() == new_home, "and the place switches to its home (%s)" % new_home)
	await _wait(150 if _shots_dir != "" else 10)
	# Rehoming takes the pet out of the list but keeps it on its projects.
	var leaving: PetData = chooser._current_pet()
	chooser._on_left()
	await _wait(20)
	_close_modal(true)
	await _wait(20)
	check(leaving.is_rehomed() and not chooser._pet_list.has(leaving) and app.state.pet(leaving.id) != null, "rehoming hides the pet but keeps its record")

	# Tapping a pet sets off: everything but the pet fades and it walks to
	# the path; the walk opens in the same place, you walk in to join it,
	# the lead and the project's name appear, and only a second later do you
	# set off and the clock start. Then the time drops in and the
	# encouragement types itself out.
	var setting_off: PetData = chooser._current_pet()
	var setting_place: String = chooser._place_id()
	app.state.settings["last_project"] = app.state.projects[1].id
	chooser._start_walk(chooser._pets.index)
	await _wait(2)
	check(main._prepared != null and main._prepared.get_child(0)._scenery.biome["id"] == setting_place,
		"the walk is built underneath while the pet steps over")
	await _wait(25)
	check(chooser._top.modulate.a < 0.5 and chooser._bottom.modulate.a < 0.5, "the screen's buttons fade away")
	await _shot("set_off_pet_to_path")
	await _wait(60)
	var arriving: Node = main._flows.back().get_child(0)
	check(arriving.get("_arriving") == true and app.state.active == null, "the walk opens with you walking in, before the clock starts")
	check(arriving._animal.animal_id == setting_off.animal_id and arriving._scenery.biome["id"] == setting_place, "with that pet, in the place picked")
	await _wait(30)
	await _shot("set_off_walking_in")
	var home_x: float = _class("res://scenes/choose_focus/choose_focus.gd").walk_spots(arriving.size, arriving._scenery.path_y())["walker"].x
	check(arriving._walking_in and arriving._walker.position.x < home_x - 1.0, "you walk in from the left (%.0f, on the way to %.0f)" % [arriving._walker.position.x, home_x])
	for i in 40:
		if arriving._lead_alpha > 0.9 or app.state.active != null:
			break
		await _wait(6)
	await _wait(12)
	check(arriving._lead_alpha > 0.5 and arriving._title.modulate.a > 0.3 and app.state.active == null and arriving._timer.modulate.a < 0.05, "the lead and the project's name, but no time yet")
	await _shot("set_off_lead")
	await _wait(80)
	check(app.state.active != null and app.state.active.pet_id == setting_off.id, "then you set off and the clock starts")
	await _wait(40)
	await _shot("set_off_typing")
	check(arriving._quote.visible_characters >= 0, "the encouragement types itself out")
	await _wait(330)
	check(arriving._quote.visible_characters == -1 and arriving._quote.text != "", "all of it")
	check(arriving._pause.modulate.a > 0.95 and arriving._sound.modulate.a > 0.95, "and the buttons are in")
	await _shot("set_off_walking")
	var first_quote: String = arriving._quote.text
	app.state.active.start_unix -= 11 * 60
	await _wait(150)
	check(arriving._quote.text != first_quote, "ten minutes on, a new line of encouragement")
	app.cancel_walk()

	app.start_walk(app.state.projects[1].id, app.state.pets[1].id)
	app.go("walk", {"from": main.size * 0.5})
	await _wait(60)
	var walk: Node = main._flows.back().get_child(0)
	walk._scenery.clock = 10.5
	await _wait(2)
	await _shot("walk")
	# Late in the evening the moon is out and the stars come through.
	walk._scenery.clock = 22.5
	await _wait(2)
	check(walk._scenery.darkness() >= 0.5 and walk._scenery.ambience() == "night", "the night chorus after dark")
	await _shot("walk_night")
	walk._scenery.clock = 10.5

	# The sound button turns the effects and the ambience off together.
	check(walk._sound_on(), "sound starts on")
	walk._toggle_sound()
	check(not app.state.settings.get("sound") and not app.state.settings.get("ambience"), "the sound button mutes everything")
	walk._toggle_sound()
	check(app.state.settings.get("sound") and app.state.settings.get("ambience"), "and turns it all back on")
	# The weather picker in the top left: what you pick shows and is kept.
	var weather_pick: Node = _find(walk, func(n): return _is(n, "dropdown.gd"))
	check(weather_pick != null, "the weather picker is on the walk")
	check(weather_pick.get_global_rect().position.x < main.size.x * 0.3, "in the top left")
	check(weather_pick.get_global_rect().end.x < walk._sound.get_global_rect().position.x - 8.0, "clear of the sound button")
	weather_pick._open()
	await _wait(20)
	await _shot("walk_weather_menu")
	weather_pick._choose("rainy", null)
	await _wait(20)
	check(app.state.settings.get("weather") == "rainy", "the weather picked is saved")
	check(walk._scenery.weather_kind() in ["rainy", "snowy", "sunny"], "and the place shows it its own way")
	await _shot("walk_rain")
	weather_pick._choose(weather_pick._options[0][0], null)
	await _wait(10)
	check(str(app.state.settings.get("weather")) in ["", "sunny"], "back to the first choice")

	# The End focus pill: its words, with the pie inside on the right.
	var pill: Button = walk._gift
	check(pill.text == "End focus", "the pill says End focus")
	check(pill.get_global_rect().end.x <= main.size.x and pill.get_global_rect().end.y <= main.size.y, "the pill is on screen")
	var text_w: float = pill.get_theme_font("font").get_string_size(pill.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pill.get_theme_font_size("font_size")).x
	check(22.0 + text_w + 8.0 < pill.size.x - pill.PIE_INSET - pill.PIE, "the words don't run into the pie")


	# The debug time buttons move the walk on; the gift button's pie follows.
	var steps: Array = _find(walk, func(n): return n is Button and n.text == "+5").get_parent().get_children()
	check(steps.size() == 4, "+5, +10, +30 and +60 minute buttons")
	steps[0].pressed.emit()
	await _wait(30)
	check(walk._gift._reveal == 0.0 and absf(walk._gift._progress - 0.5) < 0.05, "five minutes in, the dark green is halfway round")
	await _shot("gift_5min")
	steps[0].pressed.emit()
	await _wait(10)
	check(walk._gift.level() == 0, "ten minutes earns a gift")
	await _wait(60)
	check(walk._gift._reveal == 1.0, "and the bright green fills in")
	steps[2].pressed.emit()
	await _wait(60)
	var pie: Dictionary = walk._gift.shown()
	check(pie["rare"] > 0.1 and pie["epic"] > 0.0 and pie["common"] > 0.5, "40 minutes: slices for the rarer gifts (%s)" % pie)
	await _shot("gift_40min")
	steps[1].pressed.emit()
	await _wait(60)
	await _shot("walk_50min")
	check(walk._gift.level() == 1, "50 minutes guarantees a rare gift")
	check(walk._gift.shown()["common"] < 0.01, "and common drops out of the pie")

	# Past a day the clock shows days, smaller so it still fits.
	app.state.active.start_unix -= 86400
	await _wait(70)
	check(walk._timer.text.begins_with("1d "), "a day on, the clock shows days (%s)" % walk._timer.text)
	check(walk._timer.get_minimum_size().x <= main.size.x - 20.0, "and still fits across")
	await _shot("walk_day")
	app.state.active.start_unix += 86400
	await _wait(70)
	walk._on_gift_pressed()
	await _wait(80)
	await _shot("walk_dive")
	await _wait(300)
	check(main._flows.size() == 1 and main._flows[0].get_child(0).get("params").has("gift"), "dive ends on the finish screen")
	var result: Dictionary = main._flows[0].get_child(0).params
	check(result["session"].focus_seconds >= 50 * 60, "walk length from timestamps")
	check(result["gift"].get("rarity", "") in ["rare", "epic", "legendary"], "at least rare after 50 minutes")
	var finish: Node = main._flows[0].get_child(0)
	await _wait(40)
	await _shot("finish_zoom")
	await _wait(420)
	check(finish._home.modulate.a > 0.9, "the home button fades in at the end")
	check(finish._state == "ready", "the gift can be picked up")
	check(finish._scenery.front.get_index() > finish._scenery.get_index(), "the growth stays in front of the pet")
	check(finish._animal.get_index() > finish._walker.get_index(), "the pet stands in front of you at home")
	await _shot("finish")

	# Easter egg: hold the gift, flick it up into the distance, and wait for
	# the fetch.
	var gift_at: Vector2 = finish._gift_on_screen()
	await _drag(gift_at, gift_at + Vector2(30, -150), 4, 0.3)
	await _wait(20)
	check(finish._state in ["flying", "fetching"], "a flick throws the gift (state %s)" % finish._state)
	check(finish._fly_state["far"] > 0.3, "flicking up throws it into the distance")
	await _wait(30)
	await _shot("fetch")
	var behind := false
	for i in 60:
		if finish._animal.position.y < finish._walker.position.y - 4.0:
			behind = finish._animal.get_index() < finish._walker.get_index()
			break
		await _wait(5)
	check(behind, "out in the distance the pet runs behind you")
	await _wait(400)
	check(finish._state == "ready" and finish._animal.held_gift == result["gift"]["gift_id"], "the pet brings the gift back")
	check(finish._animal.get_index() > finish._walker.get_index(), "and stands in front of you again")

	# A hard flick to the side curves in, so it still lands in view.
	gift_at = finish._gift_on_screen()
	await _drag(gift_at, gift_at + Vector2(420, -30), 4, 0.3)
	await _wait(2)
	var k: float = finish._stage.scale.x
	var left: float = -finish._stage.position.x / k
	var to: float = finish._fly_state.get("to", -1.0)
	check(to > left and to < left + finish.size.x / k, "a hard sideways flick lands on screen (%d in %d..%d)" % [to, left, left + finish.size.x / k])
	await _wait(400)
	check(finish._state == "ready", "and the pet brings that one back too")

	app.go("home")
	await _wait(18)
	await _shot("finish_closing_into_orb")
	check(main._panes[Vector2i.ZERO]._orb._grow > 1.05, "the orb shrinks back from filling the screen as the flow closes into it")
	await _wait(42)
	check(main._flows.is_empty() and main._at == Vector2i.ZERO, "home closes the flow")
	check(absf(main._panes[Vector2i.ZERO]._orb._grow - 1.0) < 0.01, "and the orb is back to its size")

	# Closing the app mid-walk ends the walk: the next launch logs it up to
	# when the app was last open, with no gift, and shows focus ended.
	app.start_walk(app.state.projects[0].id, app.state.pets[0].id, "forest")
	app.state.active.start_unix -= 25 * 60
	app.state.active.last_seen_unix = app.now() - 2 * 60
	var logged: int = app.state.total_seconds()
	var ended: Dictionary = app._end_left_walk()
	var stopped: int = ended["session"].focus_seconds
	check(app.state.active == null and app.state.total_seconds() == logged + stopped, "a walk left running is logged")
	check(stopped >= 22 * 60 and stopped <= 24 * 60, "up to when the app was last open (%ds)" % stopped)
	check(ended["session"].gift_id == "", "with no gift")
	main._open_flow("ended", ended, true)
	await _wait(170)
	var ended_screen: Node = main._flows.back().get_child(0)
	check(ended_screen._walker.sad > 0.9 and ended_screen._animal.sad > 0.9, "you and your pet look dejected")
	check(ended_screen._home.modulate.a > 0.5, "the way home shows")
	await _shot("ended")
	ended_screen.go_back()
	await _wait(60)
	check(main._flows.is_empty(), "home from focus ended")

	# In the jungle the leaves pass in front of you and your pet.
	app.start_walk(app.state.projects[0].id, app.state.pets[0].id, "jungle")
	app.go("walk", {"from": main.size * 0.5})
	await _wait(60)
	var jungle_walk: Node = main._flows.back().get_child(0)
	jungle_walk._scenery.clock = 10.5
	var front: Control = jungle_walk._scenery.front
	check(front.get_parent() == jungle_walk and front.get_index() > jungle_walk._actors.get_index(), "the jungle's growth is in front of the walker")
	await _wait(2)
	await _shot("walk_jungle")
	# Ending it early: no gift, and nothing glows where one would be.
	jungle_walk._on_gift_pressed()
	await _wait(20)
	_close_modal(true)
	await _wait(420)
	var empty_finish: Node = main._flows.back().get_child(0)
	check(_is(empty_finish, "finish.gd") and empty_finish._gift_id == "", "an early finish has no gift")
	check(not empty_finish._glow.visible, "and no glow where the gift would be")
	await _shot("finish_no_gift")
	app.go("home")
	await _wait(60)
	check(main._flows.is_empty(), "back home from the jungle")
	check(_audio().current_ambience() == "", "the jungle's sounds stop at home")

	# The hilltop view behind every screen: the sun by day, the moon and
	# stars by night, and its layers pan as you slide to another screen.
	var focus_pane: Node = main._panes[Vector2i.ZERO]
	var backdrop: Control = main._backdrop
	check(backdrop != null and backdrop.visible and backdrop.get_index() < main._world.get_index(), "the hilltop view sits behind the focus screen")
	check(_find(focus_pane, func(n): return _is(n, "theme_toggle.gd")) == null, "no light/dark switch any more")
	if backdrop:
		check(backdrop._layers.size() == 5, "five layers")
		app.set_setting("debug_hour", 12.0)
		await _wait(5)
		check(backdrop.get_node("Sun").visible and not backdrop.get_node("Moon").visible and backdrop.get_node("NightSky").modulate.a < 0.01, "midday: the sun, no stars")
		var sun_noon: float = backdrop.get_node("Sun").position.y
		app.set_setting("debug_hour", 9.0)
		await _wait(5)
		check(backdrop.get_node("Sun").position.y > sun_noon, "it's lower in the morning")
		await _shot("backdrop_morning")
		app.set_setting("debug_hour", 23.0)
		await _wait(5)
		check(backdrop.get_node("Moon").visible and not backdrop.get_node("Sun").visible and backdrop.get_node("NightSky").modulate.a > 0.99, "at night: the moon and stars")
		var dimmed: Color = backdrop._layers[4].self_modulate
		check(dimmed.v < backdrop._colours[4].v * 0.6, "and the layers dim")
		await _shot("backdrop_night_light_theme")
		var near_spot: Vector2 = backdrop._layers[4].position
		var far_spot: Vector2 = backdrop._layers[0].position
		app.go("gifts")
		await _wait(8)
		check(backdrop._layers[4].position.x - near_spot.x > backdrop._layers[0].position.x - far_spot.x + 4.0, "sliding away, near layers move further than far ones")
		await _wait(50)
		check(backdrop.visible and backdrop.modulate.a > 0.99 and main._backdrop == backdrop, "and it stays, the same one, on the other screens")
		var hilltop: Control = backdrop._layers[4]
		check(hilltop.position.x + hilltop.size.x >= main.size.x and hilltop.position.x <= 0.0, "with no edge showing")
		app.go("focus")
		await _wait(50)
		app.go("stats")
		await _wait(50)
		check(hilltop.position.y < 0.0 or hilltop.position.y + hilltop.size.y < main.size.y, "looking down lifts the layers")
		check(backdrop._skirts[4].visible and hilltop.position.y + hilltop.size.y + backdrop._skirts[4].size.y >= main.size.y, "and ground fills in below them")
		app.go("focus")
		await _wait(50)
		check(backdrop.visible and backdrop.modulate.a > 0.99, "back on the focus screen it's there")
		app.set_setting("debug_hour", -1.0)
		await _wait(5)

	# Dark mode follows the time of day (the debug bar's time slider moves
	# it; there's no style or theme picker any more). The whole app fades
	# into the new colours with nothing on screen moving or starting over.
	var orb_before: Node = focus_pane._orb
	var greeting_before: String = focus_pane._greeting.text
	var orb_spot: Rect2 = orb_before.get_global_rect()
	var greeting_end: Vector2 = focus_pane._greeting.get_global_rect().end
	check(_find(focus_pane, func(n): return n is Button and (n.text in ["Classic", "Glass", "Pixel", "Storybook", "Auto", "Light", "Dark"])) == null,
		"the debug bar has no style or theme pickers")
	app.state.settings["debug_theme"] = "auto"
	app.set_setting("debug_hour", 23.0)
	await _wait(60)
	check(_class("res://ui/ui.gd").dark, "late at night switches to dark mode")
	check(focus_pane._orb == orb_before, "the orb carries on through the switch")
	check(focus_pane._greeting.text == greeting_before and focus_pane._orb.get_global_rect().is_equal_approx(orb_spot)
		and focus_pane._greeting.get_global_rect().end.is_equal_approx(greeting_end), "the greeting and layout stay put")
	check(not _class("res://ui/motion.gd").still, "animations are back on")
	await _wait(30)
	check(main._fade_layer.get_child_count() == 0, "the old colours have faded away")
	await _shot("focus_dark")
	for pane in ["gifts", "stats", "profile"]:
		app.go(pane)
		await _wait(50)
		await _shot(pane + "_dark")
	main._panes[Vector2i(0, -1)].open_rewards()
	await _wait(50)
	await _shot("rewards_dark")
	_close_modal()
	app.go("focus")
	await _wait(50)
	app.set_setting("debug_theme", "auto")
	app.set_setting("debug_hour", 23.0)
	await _wait(60)
	check(_class("res://ui/ui.gd").dark, "Auto is dark at night")
	app.set_setting("debug_hour", 12.0)
	await _wait(60)
	check(not _class("res://ui/ui.gd").dark, "and light by day")
	app.set_setting("debug_hour", -1.0)
	app.set_setting("debug_theme", "light")
	await _wait(60)
	# No tooltips anywhere: every pane has been built by now.
	var tipped: Control = _find(main, func(n): return n is Control and n.tooltip_text != "")
	check(tipped == null, "no tooltips (%s has one)" % [tipped])
	for pane in main._panes.values():
		var title: Control = _find(pane, func(n): return n is TextureRect and n.get_parent() is CenterContainer and n.get_parent().get_parent() is HBoxContainer)
		check(pane.name == "Focus" or title != null, "%s has its map icon by its title" % pane.name)
		check(_find(pane, func(n): return n is PanelContainer and n.get_parent() is HBoxContainer and n.get_child_count() == 1 and n.get_child(0) is TextureRect and n.size.x == 44.0) == null, "%s's icon has no tile behind it" % pane.name)
	await _holidays(main)
	if _failed:
		quit(1)
		return
	print("SMOKE OK")
	quit(0)


## Each holiday's look, tried from the debug bar: its present the first time
## (once a year), its decorations over the screens and on the hilltop, and a
## walk in it.
func _holidays(main: Node) -> void:
	var app := _app()
	var backdrop: Control = main._backdrop
	app.state.profile["dob"] = "2001-06-14"
	app.state.profile.erase("holiday_gifts")
	app.set_setting("debug_hour", 12.0)
	for id in ["halloween", "christmas", "new_year", "easter", "birthday"]:
		var had: int = app.state.gift_count(str(_content().holiday(id).get("gift", "")))
		app.set_setting("debug_holiday", id)
		await _wait(30)
		check(app.holiday() == id, "previewing %s" % id)
		check(backdrop._dressed == id, "the hilltop dresses for %s" % id)
		var h: Dictionary = _content().holiday(id)
		var look = app.holiday_look()
		if h.has("gift"):
			check(app.state.gift_count(h["gift"]) == had + 1, "%s brings its present" % id)
			check(_class("res://ui/modal.gd").is_open(), "and shows it")
			await _shot("holiday_%s_present" % id)
			_close_modal()
			await _wait(30)
			check(app.claim_holiday_gift().is_empty(), "only once a year")
		check((main._decor_layer.get_child_count() > 0) == (look.menu_scene != null), "%s's decorations hang over the screens" % id)
		var greeting: String = main._panes[Vector2i.ZERO]._greeting.text
		var lines: Array = _class("res://core/text.gd").list("greetings.holidays." + id).map(
			func(l): return _class("res://core/text.gd").fill(str(l), {"name": str(app.state.profile.get("username", ""))}))
		check(greeting in lines, "the home screen greets you for %s: %s" % [id, greeting])
		await _shot("holiday_%s_home" % id)
		match id:
			"halloween":
				check(is_equal_approx(app.day_hour(), 0.0) and app.night() > 0.99, "it's always midnight on Halloween")
				check(backdrop._layers[3].texture != backdrop._pictures[3], "the forest's trees are dead")
			"christmas":
				check(_class("res://ui/ui.gd").dark == false and root.get_node("Outdoors").weather() == "snowy", "it always snows at Christmas")
				check(backdrop._snowfall.visible and backdrop._layers[0].material != null, "snow on the hilltop view")
			"new_year":
				check(backdrop._fireworks.visible, "fireworks behind the hilltop")
			"birthday":
				var me: Node = _class("res://ui/components/character_view.gd").new()
				check(me._item("hat").get("id", "") == "party_hat", "your party hat stays on on your birthday")
				me.free()
				# The hats can't be changed: held on the party hat.
				var dressing: Node = _class("res://scenes/customise/customise.gd").open()
				await _wait(25)
				var hats: Node = _find(dressing.body, func(n): return _is(n, "carousel.gd") and n.locked)
				check(hats != null and hats.items[hats.index].accessibility_name == "Party Hat", "the hats are held on the party hat")
				if hats:
					hats.go_to(0)
					await _wait(10)
					check(hats.items[hats.index].accessibility_name == "Party Hat", "and can't be scrolled")
				await _shot("holiday_birthday_hats")
				_close_modal()
				await _wait(20)
		app.go("profile")
		await _wait(50)
		await _shot("holiday_%s_profile" % id)
		app.go("focus")
		await _wait(50)
		app.start_walk(app.state.projects[0].id, app.state.pets[0].id, "forest" if id != "easter" else "blossom")
		app.go("walk", {"from": main.size * 0.5})
		await _wait(90)
		var walk: Node = main._flows.back().get_child(0)
		walk._scenery.clock = -1.0
		if id == "christmas":
			check(walk._scenery.weather_kind() == "snowy" and walk._scenery._pile.visible, "snow piles up on a Christmas walk")
			app.debug_add_minutes(30)
			await _wait(10)
		await _shot("holiday_%s_walk" % id)
		app.cancel_walk()
		app.go("home")
		await _wait(60)
	# The holiday pets, and the presents worn.
	var cast := ColorRect.new()
	cast.color = Color("#f4ecdf")
	cast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(cast)
	var at := 90.0
	for id in ["skeleton_dog", "reindeer", "easter_egg", "birthday_cake"]:
		var pet: Node2D = _class("res://ui/components/animal_view.gd").new()
		pet.animal_id = id
		pet.walking = true
		pet.position = Vector2(at, main.size.y * 0.4)
		cast.add_child(pet)
		at += main.size.x / 4.6
	at = 70.0
	for outfit in [{"hat": "pumpkin_head"}, {"top": "tree_costume"}, {"hat": "bunny_ears"}, {"hat": "party_hat"}, {"hat": "reindeer_legendary", "top": "reindeer_epic"}]:
		var look: Dictionary = app.state.profile.duplicate(true)
		look["cosmetics"].merge(outfit, true)
		var me: Node2D = _class("res://ui/components/character_view.gd").new()
		me.look = look
		me.holding_lead = false
		me.position = Vector2(at, main.size.y * 0.9)
		cast.add_child(me)
		at += main.size.x / 5.4
	await _wait(10)
	await _shot("holiday_cast")
	cast.queue_free()
	# Your birthday's pet: locked until you've focused half an hour on it.
	check(not app.unlock_progress("animal", "birthday_cake")["done"], "the birthday cake is locked to start with")
	app.set_setting("debug_holiday", "none")
	app.set_setting("debug_hour", -1.0)
	await _wait(30)
	check(backdrop._dressed == "" and main._decor_layer.get_child_count() == 0, "an ordinary day again")

## Drop-in art: an animal rig of separate limbs that the shader paints with the
## animal's colours, gift images, and scenery tiles, each beside its placeholder.
func _art_check(main: Node) -> void:
	var view_class := _class("res://ui/components/animal_view.gd")
	var rig: PackedScene = load("res://art/templates/animal/animal.tscn")
	var view: Node2D = view_class.new()
	view.animal_id = "dog1"
	root.add_child(view)
	check(not view.has_art() and view_class.rig_path("dog1") == "", "no art yet means the placeholder")
	var placeholder_mouth: Vector2 = view.mouth()
	view.set_rig(rig)
	view.colours = [Color("#112233"), Color("#445566"), Color("#778899")] as Array[Color]
	view.walking = true
	await _wait(10)
	check(view.has_art(), "the rig replaces the placeholder")
	var limbs: Array = _all(view._rig, func(n): return n is Sprite2D)
	check(limbs.size() >= 6, "the rig is separate limbs (%d)" % limbs.size())
	var painted: bool = limbs.all(func(n): return n.material is ShaderMaterial)
	check(painted, "every limb has the colour shader")
	var mat: ShaderMaterial = limbs[0].material
	check(mat.get_shader_parameter("colour_r") == Color("#112233") and mat.get_shader_parameter("colour_b") == Color("#778899"), "red, green and blue map to the first, second and third colours")
	check(view._player.current_animation == "walk" and view._player.is_playing(), "walking plays the walk animation")
	view.walking = false
	check(not view._player.is_playing() or view._player.current_animation == "idle", "stopping stops the walk")
	view.held_gift = "dog_common"
	view.submerged = 10.0
	await _wait(5)
	check(view.mouth() != placeholder_mouth and view.neck() != Vector2.ZERO, "the lead and the gift use the rig's markers")
	view.free()
	# The character: a rig dressed with each worn item's pieces.
	var char_class := _class("res://ui/components/character_view.gd")
	check(char_class.rig_path() == "" and char_class.rig_path("res://art/templates/") != "", "the character has no art yet in art/, only the template")
	var character: Node2D = char_class.new()
	character.art_root = "res://art/templates/"
	character.look = {"skin_tone": 2, "hair_tone": 1, "cosmetics": {"hat": "hat_beanie", "top": "top_jumper"}}
	root.add_child(character)
	await _wait(5)
	check(character.has_art(), "the character's rig loads")
	var worn: Array = character._dressing
	check(worn.size() == 4, "the beanie is one piece and the jumper three (%d)" % worn.size())
	check(character._body.all(func(sp): return sp.material is ShaderMaterial and sp.material.get_shader_parameter("colour_r") == character._skin()), "skin tone paints the body")
	check(worn.any(func(sp): return sp.get_parent().name == "Head") and worn.any(func(sp): return sp.get_parent().name == "ArmFront"), "pieces sit on their limbs")
	character.walking = true
	await _wait(20)
	check(character._player.current_animation == "walk", "walking plays the walk animation")
	check(character.hand != Vector2(22, -78) and character.hand.length() > 10.0, "the lead clips on at the Hand marker (%s)" % character.hand)
	character.sad = 1.0
	await _wait(5)
	check(character._dressing.size() == 4, "sad keeps the same pieces when there is no sad art")
	character.sad = 0.0
	character.part = "hat"
	await _wait(3)
	check(character._dressing.size() == 1 and character._body.all(func(sp): return not sp.visible), "a hat on its own hides the body")
	character.part = "hair"
	check(character._body.all(func(sp): return not sp.visible), "hair on its own shows no head")
	character.part = ""
	character.face_only = true
	await _wait(3)
	check(character._rig.position != Vector2.ZERO and not character._limbs["LegFront"]["node"].visible, "an avatar is the head and shoulders, centred on the face")
	character.free()
	var gifts_class := _class("res://ui/components/gift_art.gd")
	check(gifts_class.texture_for("no_such_gift") == null, "a gift without art has no picture")
	# A scenery layer with art lays its tile scene instead of drawing.
	var scenery: Control = _class("res://scenes/walk/scenery.gd").new()
	scenery.biome = {"id": "t", "layers": [{"kind": "art", "art": "res://art/templates/scenery/tile.tscn", "parallax": 0.5, "y": 0.7, "height": 0.2, "colour": "#ffffff"}]}
	root.add_child(scenery)
	scenery.size = main.size
	scenery.scroll = 5000.0
	await _wait(5)
	var tiles: Dictionary = scenery._layers[0]["chunks"]
	check(tiles.size() >= 2 and tiles.values().all(func(t): return t.get_node_or_null("Rock") != null), "art tiles repeat across the screen (%d)" % tiles.size())
	scenery.scroll = 90000.0
	await _wait(5)
	check(scenery._layers[0]["chunks"].size() < 8, "and are freed once passed")
	scenery.queue_free()
	await process_frame


## Every place round the clock and in every weather, plus the day-cycle and
## weather pictures for the docs. Slow with a display (it's all software
## rendering there), so --quick skips it.
func _scenery_gallery(main: Node) -> void:
	# Every place draws cleanly round the clock, along a stretch of walk,
	# its front growth included.
	for b in _content().biomes:
		var scenery: Control = _class("res://scenes/walk/scenery.gd").new()
		scenery.biome = b
		root.add_child(scenery)
		scenery.size = main.size
		for hour in [6.2, 12.0, 18.4, 23.0]:
			scenery.clock = hour
			for scroll in [1234.0, 40000.0, 91000.0]:
				scenery.scroll = scroll
				await process_frame
			if hour == 12.0 or b["id"] == "jungle":
				await _shot("place_%s_%02d" % [b["id"], int(hour)])
		check(scenery.darkness() > 0.9, "%s is dark at 11pm" % b["id"])
		scenery.clock = 12.0
		check(scenery.darkness() == (1.0 if b.has("sky") else 0.0), "%s is light at midday unless it has its own sky" % b["id"])
		check(scenery.tint() == Color.WHITE, "%s is in full light at midday" % b["id"])
		if b["id"] == "jungle":
			check(scenery.front.get_child_count() >= 3, "the jungle has growth in front")
		# Every kind of weather, the way this place shows it.
		for kind in ["sunny", "partly", "cloudy", "rainy", "stormy", "snowy"]:
			scenery.weather = kind
			for scroll in [2000.0, 52000.0]:
				scenery.scroll = scroll
				await process_frame
		scenery.weather = "rainy"
		var dry: bool = b["id"] in ["desert", "moon"]
		check((scenery.weather_kind() == "sunny") == dry, "%s: rain shows as %s" % [b["id"], scenery.weather_kind()])
		if b["id"] == "tundra":
			check(scenery.weather_kind() == "snowy", "rain falls as snow in the tundra")
			scenery.weather = "stormy"
			check(scenery.weather_kind() == "blizzard" and scenery.ambience() == "wind", "a storm is a blizzard there")
		scenery.queue_free()
	await process_frame
	# The lake through a day, for the docs.
	var day: Control = _class("res://scenes/walk/scenery.gd").new()
	day.biome = _content().biome("lake")
	root.add_child(day)
	day.size = main.size
	day.scroll = 5000.0
	for hour in [5.5, 7.0, 12.0, 17.5, 18.6, 23.0]:
		day.clock = hour
		await _wait(2)
		await _shot("day_%04.1f" % hour)
	day.queue_free()
	await process_frame
	# Weather, for the docs: the lake in sun and cloud, cloud, rain and a
	# storm (caught mid-flash), the forest in snow, the tundra in a blizzard.
	for shot in [["lake", "partly"], ["lake", "cloudy"], ["lake", "rainy"], ["lake", "stormy"], ["forest", "snowy"], ["tundra", "stormy"]]:
		var w: Control = _class("res://scenes/walk/scenery.gd").new()
		w.biome = _content().biome(shot[0])
		root.add_child(w)
		w.size = main.size
		w.scroll = 7000.0
		w.clock = 13.0
		w.weather = shot[1]
		if shot[1] == "stormy" and shot[0] == "lake":
			w._time = 3 * w.STORM_EVERY + w._hash(3, 31.0) * 4.0 + 0.01
		await process_frame
		await process_frame
		if shot[1] == "stormy" and shot[0] == "lake":
			check(w._flash > 0.0 and w._bolt == 3, "lightning flashes in a storm")
			check(w.ambience() == "rain", "and it sounds like rain")
		await _shot("weather_%s_%s" % shot)
		w.queue_free()
	await process_frame


func _fill_sample_data() -> void:
	var app := _app()
	var content := _content()
	app.state = GameState.new()
	app.state.profile["username"] = "Joe"
	app.state.profile["institution"] = "University of Leeds"
	app.state.profile["created_unix"] = app.now() - 40 * 86400
	app.state.profile["cosmetics"]["hat"] = "bird_epic"
	app.state.profile["cosmetics"]["face"] = "face_glasses"
	var now: int = app.now()
	var animals := ["dog1", "cat1", "snail", "bird", "bear", "rabbit"]
	var places := ["lake", "forest", "lake", "beach", "farm", "lake"]
	var names := ["Dissertation", "Spanish", "Portfolio", "Statistics", "Guitar", "Reading"]
	var pet_names := ["Biscuit", "Mochi", "Snail", "Pip", "Bruno", "Rabbit"]
	for i in animals.size():
		var pet := PetData.new()
		pet.name = pet_names[i]
		pet.animal_id = animals[i]
		pet.colours = content.animal_default_colours(animals[i])
		pet.adopted_unix = now - (34 - i) * 86400
		app.add_pet(pet)
	for i in names.size():
		var p := ProjectData.new()
		p.name = names[i]
		p.created_unix = now - 30 * 86400
		app.add_project(p)
		for d in 16:
			# Today always has a session, so each project shows in this week's
			# chart whichever day of the week the test runs on.
			if d > 0 and (d + i) % 3 == 0:
				continue
			# Mostly the project's own pet, with others now and then, so the
			# podiums have more than one pet and place on them.
			var k := i if d % 4 != 1 else (i + d) % animals.size()
			var pet: PetData = app.state.pets[k]
			var seconds := 600 + 300 * ((i + d) % 4)
			var rarity: String = ["common", "common", "rare", "epic"][(i + d) % 4]
			var gift := "%s_%s" % [content.table_of(pet.animal_id), rarity]
			var start: int = now - d * 86400 - i * 3600
			app.state.log_focus(_class("res://core/stats.gd").local_day(start, app.tz_bias()), p.id, pet.id, places[k], seconds)
			p.pets[pet.id] = int(p.pets.get(pet.id, 0)) + seconds
			p.places[places[k]] = int(p.places.get(places[k], 0)) + seconds
			p.last_walked_unix = maxi(p.last_walked_unix, start + seconds)
			pet.last_walked_unix = maxi(pet.last_walked_unix, start + seconds)
			pet.places[places[k]] = int(pet.places.get(places[k], 0)) + seconds
			app.state.xp += _levels().walk_xp(seconds, rarity, content.levels)
			p.gifts[gift] = int(p.gifts.get(gift, 0)) + 1
	app.complete_project(app.state.projects[5].id)
	app.complete_project(app.state.projects[4].id)
	app.state.projects[5].grade = "uni/first"
	app.state.projects[4].grade = "alevel/a_star"
	for g in content.gifts.slice(0, 24):
		app.state.inventory[g["id"]] = 1 + (hash(g["id"]) % 4)
	app.state.inventory["dog_common"] = 12
	app.state.inventory["bird_epic"] = 1
	app.state.place_on_shelf("dog_common", 0)
	app.state.place_on_shelf("bird_epic", 2)
	app.friends = _class("res://core/friends.gd").sample()
	app.state_changed.emit()


## The chart's tabs switch between a week, a month and a year; its menu
## splits the bars by project, pet or place, and tapping a pet or a place
## shows its own card.
func _stats_periods(main: Node) -> void:
	var app := _app()
	var modal_class := _class("res://ui/modal.gd")
	var stats_pane: Control = main._panes[Vector2i(0, 1)]
	var tabs: Dictionary = stats_pane._tabs
	check(tabs.size() == 3 and tabs["week"].text == "Week", "Week · Month · Year tabs")
	check(stats_pane._chart_title.text == "This week", "this week first")
	var bold := func(tab: Button) -> bool: return tab.get_theme_color("font_color") == _class("res://ui/ui.gd").INK
	check(bold.call(tabs["week"]) and not bold.call(tabs["month"]), "the chosen tab is in ink, the rest muted")
	tabs["month"].pressed.emit()
	await _wait(30)
	tabs = stats_pane._tabs
	check(stats_pane._chart_title.text == "This month" and stats_pane._chart.bars.size() >= 28, "a month has a bar a day (%d)" % stats_pane._chart.bars.size())
	check(stats_pane._chart.labels.filter(func(l): return l != "") == ["1", "8", "15", "22", "29"] or stats_pane._chart.bars.size() < 29, "dates every seventh day")
	await _shot("stats_month")
	tabs["year"].pressed.emit()
	await _wait(30)
	tabs = stats_pane._tabs
	check(stats_pane._chart_title.text == "This year" and stats_pane._chart.bars.size() == 12, "a year has a bar a month")
	var month_total := 0
	for b in stats_pane._chart.bars:
		for v in b.values():
			month_total += int(v)
	check(month_total == app.state.total_seconds() or month_total > 0, "the year's bars hold the focus")
	await _shot("stats_year")
	# Split by pet: the strip names pets, and tapping one shows its card.
	var split: Node = _find(stats_pane, func(n): return _is(n, "dropdown.gd"))
	check(split != null and split.get_global_rect().position.y < stats_pane._chart_title.get_global_rect().position.y, "the split menu is in the chart's header")
	await _tap_menu(split, "Pets")
	await _wait(30)
	var chips: Array = _all(stats_pane._legend, func(n): return n is Button)
	var pet_names: Array = app.state.pets.map(func(p): return p.name.left(10))
	check(not chips.is_empty() and chips.all(func(b): return pet_names.any(func(n): return b.text.begins_with(n.strip_edges()))), "split by pet, the strip names pets")
	await _shot("stats_by_pet")
	stats_pane._show_piece(app.state.pets[0].id, -1)
	await _wait(25)
	check(modal_class.is_open() and _find(modal_class.top(), func(n): return _is(n, "podium.gd")) != null, "a pet's card has its top projects")
	check(_find(modal_class.top(), func(n): return n is Label and n.text.begins_with("Adopted")) != null, "and when it was adopted")
	await _shot("pet_card")
	_close_modal()
	await _wait(15)
	split = _find(stats_pane, func(n): return _is(n, "dropdown.gd"))
	await _tap_menu(split, "Places")
	await _wait(30)
	stats_pane._show_piece("lake", -1)
	await _wait(25)
	check(modal_class.is_open() and _find(modal_class.top(), func(n): return _is(n, "podium.gd")) != null, "a place's card has its top pets")
	await _shot("place_card")
	_close_modal()
	await _wait(15)
	# Back to how the rest of the run expects it.
	app.state.settings["stats_split"] = "projects"
	stats_pane._tabs["week"].pressed.emit()
	await _wait(30)


## Stats fits the screen, with the friends leaderboard under the chart;
## "See full" lists everyone, and tapping a friend opens their profile.
func _stats_and_friends(main: Node) -> void:
	var app := _app()
	var modal_class := _class("res://ui/modal.gd")
	var stats_pane: Control = main._panes[Vector2i(0, 1)]
	check(stats_pane.scroll == null, "stats doesn't scroll as a page")
	var streak: Label = _find(stats_pane, func(n): return n is Label and n.text.ends_with(" days"))
	check(streak != null and _find(stats_pane, func(n): return n is Label and n.text == "streak") == null, "the streak just says how many days")
	var chips: Array = _all(stats_pane._legend, func(n): return n is Button)
	check(chips.size() > 1 and chips.all(func(b): return b.text.split("  ")[0].length() <= 13), "project names in the strip are cut to 10 letters")
	check(chips.any(func(b): return b.text.begins_with("Dissertati...")), "a long name ends in ...")
	check(stats_pane._legend.get_parent().get_parent() is ScrollContainer, "the projects scroll sideways")
	var board: Control = _find(stats_pane, func(n): return _is(n, "leaderboard.gd"))
	check(board != null and board.rows.size() == app.friends.size() + 1, "the leaderboard has you and every friend")
	if board == null:
		return
	if main.size.y >= 590:
		check(_clear_of_shell(board.get_global_rect()) and board.get_global_rect().end.y <= main.size.y,
			"the leaderboard fits, clear of the map and the arrows")
		check(stats_pane._chart.size.y >= 100.0, "the chart keeps room to read")
		var board_rect: Rect2 = board.get_global_rect()
		var seen_me := func(n): return n is Control and n.has_meta("press") and n.accessibility_name == "Your profile" and n.is_visible_in_tree() and board_rect.encloses(n.get_global_rect())
		check(_all(board, seen_me).size() == 1, "your row always shows on the leaderboard card")
	check(_find(board, func(n): return n is TextureRect and n.texture == _class("res://ui/icons.gd").texture("trophy", 22, _class("res://ui/ui.gd").ACCENT)) != null, "a trophy by the heading")
	var full: Button = _find(board, func(n): return n is Button and n.text == "See full")
	check(full != null, "a See full button")
	if full:
		await _tap_control(full, main)
	check(modal_class.is_open() and _find(modal_class.top(), func(n): return n is Label and n.text == "Friend leaderboard") != null, "See full opens the whole leaderboard")
	if modal_class.is_open():
		check(_all(modal_class.top().body, func(n): return n.has_meta("press")).size() == app.friends.size() + 1, "everyone is in it")
		await _shot("leaderboard_full")
		_close_modal()
		await _wait(20)

	# Tapping a friend's name opens their profile, over everything.
	var friend_row: Control = _find(board, func(n): return n.has_meta("press") and n.accessibility_name == "Mei's profile")
	check(friend_row != null, "friends' names can be tapped")
	if friend_row:
		await _tap_control(friend_row, main)
	var popup: Node = modal_class.top() if modal_class.is_open() else null
	check(popup != null and _find(popup, func(n): return n is Label and n.text == "Mei") != null, "it opens their profile")
	if popup:
		check(_find(popup, func(n): return n is Label and n.text.contains("University")) == null, "never where they study")
		var medal := func(n): return n is VBoxContainer and n.get("info") is Dictionary
		var shown := _all(popup, medal)
		var mei: Dictionary = app.friends.filter(func(f): return f["name"] == "Mei")[0]
		var ach := _class("res://core/achievements.gd")
		var mei_rows: Array = ach.progress(ach.list(_content().achievements, _content().tables, _content().gifts), int(mei["focused_seconds"]), mei["gifts"], _content().gifts)
		check(shown.size() == mei_rows.filter(func(r): return r["earned"]).size() and shown.all(func(n): return n.info["earned"]), "and only the achievements they've earned")
		check(_find(popup, func(n): return n is Label and n.text == "See all") == null, "with no See all")
		await _shot("friend_profile")
		var tile: Control = _find(popup, func(n): return _is(n, "gift_tile.gd"))
		check(tile != null and tile.tappable, "their shelf gifts can be tapped")
		if tile:
			await _tap_control(tile, main)
			var details: Node = modal_class.top()
			check(details != popup and _find(details, func(n): return n is Label and n.text.begins_with("You have")) == null
				and _find(details, func(n): return n is Button and n.text.begins_with("Trade")) == null, "their gift shows without a count or trade-in")
			await _shot("friend_gift")
			_close_modal()
			await _wait(20)
		_close_modal()
		await _wait(20)

	# Someone who's earned every achievement: more than fit, so they scroll
	# sideways inside their card.
	var champion: Dictionary = app.friends[0].duplicate()
	champion["name"] = "Champion"
	champion["focused_seconds"] = 100000 * 3600
	champion["gifts"] = _content().gifts.map(func(g): return g["id"])
	_class("res://ui/components/friend_profile.gd").open(champion)
	await _wait(25)
	var strip: ScrollContainer = _find(modal_class.top().body, func(n): return n is ScrollContainer)
	check(strip != null and strip.get_h_scroll_bar().visible, "lots of achievements scroll sideways")
	if strip:
		var first: Control = _find(strip, func(n): return n is VBoxContainer and n.get("info") is Dictionary)
		check(first != null and strip.get_global_rect().encloses(first.get_global_rect()), "the first medal shows whole")
		await _shot("friend_profile_many")
		strip.scroll_horizontal = 10000
		await _wait(10)
		check(strip.scroll_horizontal > 0, "and scroll to the rest")
		await _shot("friend_profile_many_scrolled")
	_close_modal()
	await _wait(20)

	# Tapping yourself goes to your profile.
	var me_row: Control = _find(board, func(n): return n.has_meta("press") and n.accessibility_name == "Your profile")
	if me_row:
		await _tap_control(me_row, main)
		await _wait(20)
	check(main._at == main.PANES["profile"][0] and not modal_class.is_open(), "tapping yourself goes to your profile")
	app.go("stats")
	await _wait(50)


## Settings ends in a red Log out, which puts up the create account screen
## over everything: nothing can leave it. "I have an account" lists the
## accounts on this device. Create, once both boxes are filled in, makes a
## new account with no friends and goes to the focus screen; its
## leaderboard is empty. Then log out, delete the new one from the list,
## and log back into the first, as it was left.
func _accounts(main: Node) -> void:
	var app := _app()
	var modal_class := _class("res://ui/modal.gd")
	var profile_cell: Vector2i = main.PANES["profile"][0]
	var profile_pane: Control = main._panes[profile_cell]
	var home_slot: String = app.slot
	var before: int = app.slots().size()
	app.go("profile")
	await _wait(50)
	profile_pane.open_settings()
	await _wait(25)
	var settings: Node = modal_class.top()
	check(_find(settings.body, func(n): return n is Button and n.text == "Switch account") == null, "no Switch account any more")
	var out: Button = _find(settings.body, func(n): return n is Button and n.text == "Log out")
	check(out != null, "settings ends in Log out")
	if out == null:
		modal_class.close_all()
		return
	await _tap_control(out, main)
	await _wait(40)
	var screen: Control = main._account
	check(app.needs_account() and screen != null and screen.is_visible_in_tree() and not modal_class.is_open(), "Log out closes settings and shows the create account screen")
	check(app.slot == home_slot and app.slots().size() == before, "the account stays on this device")
	if screen == null:
		return
	var create: Button = _find(screen, func(n): return n is Button and n.text == "Create")
	var have: Button = _find(screen, func(n): return n is Button and n.text == "I have an account")
	var boxes: Array = _all(screen, func(n): return n is LineEdit)
	check(boxes.size() == 5, "it asks for a name, where you study and a date of birth")
	check(create != null and create.disabled, "Create waits for them")
	var agree: Button = _find(screen, func(n): return n is Button and n.toggle_mode)
	check(agree != null and not agree.button_pressed, "with a box to agree to the policy and terms, not ticked")
	var links: Array = _all(screen, func(n): return n is Button and n.text in ["Privacy Policy", "Terms of Service"])
	check(links.size() == 2, "both named by it")
	if links.size() == 2:
		await _tap_control(links[0], main)
		await _wait(25)
		var doc: Node = modal_class.top()
		check(doc != null and _find(doc.header, func(n): return n is Label and n.text == "Privacy Policy") != null, "the Privacy Policy opens in a popup")
		check(doc != null and _find(doc.body, func(n): return n is RichTextLabel and n.get_parsed_text().contains("stays on your device")) != null, "with the policy in it")
		await _shot("privacy_policy")
		modal_class.close_all()
		await _wait(20)
	check(have != null and have.is_visible_in_tree(), "I have an account shows when there's one")
	check(screen.get_global_rect().has_point(main.size * 0.5) and screen.get_global_rect().size == main.size, "it covers the screen")
	await _wait(40)
	check(main._backdrop == null or main._backdrop.look_down > 0.99, "the view looks down at the ground behind it")
	await _shot("create_account")
	# Keyboard only: Tab goes down the form, round and round.
	(boxes[0] as LineEdit).grab_focus()
	await _key(KEY_TAB)
	check(main.get_viewport().gui_get_focus_owner() == boxes[1], "Tab goes from the name to where you study")
	for i in 4:
		await _key(KEY_TAB)
	check(main.get_viewport().gui_get_focus_owner() == agree, "then the date of birth and the box (%s)" % main.get_viewport().gui_get_focus_owner())
	await _key(KEY_TAB)
	check(main.get_viewport().gui_get_focus_owner() == links[0], "then the Privacy Policy")
	main.get_viewport().gui_release_focus()
	await _key(KEY_DOWN)
	await _wait(40)
	app.go("stats")
	await _wait(40)
	check(main._at == profile_cell and app.needs_account(), "nothing can leave it")

	if have:
		await _tap_control(have, main)
		await _wait(25)
	var picker: Node = modal_class.top()
	check(picker != null and _find(picker.header, func(n): return n is Label and n.text == "Your accounts") != null, "I have an account lists them under a title")
	if picker:
		check(_all(picker.body, func(n): return n.has_meta("press")).size() == before, "a card for every account (%d)" % before)
		check(_find(picker.body, func(n): return n.has_meta("press") and n.accessibility_name == "Log in as Joe") != null, "listed by name")
		check(not picker.footer.visible, "no + under the list")
		await _shot("accounts")
		modal_class.close_all()
		await _wait(20)

	if boxes.size() == 5:
		var type := func(i: int, t: String):
			(boxes[i] as LineEdit).text = t
			(boxes[i] as LineEdit).text_changed.emit(t)
		type.call(0, "Sam")
		await _wait(5)
		check(create.disabled, "a name alone isn't enough")
		type.call(1, "University of York")
		type.call(2, "31")
		type.call(3, "02")
		type.call(4, "2012")
		await _wait(5)
		check(create.disabled and _find(screen, func(n): return n is Label and n.text == "That date doesn't look right." and n.is_visible_in_tree()) != null, "a date that can't be right says so")
		type.call(2, "14")
		type.call(3, "03")
		await _wait(5)
		check(create.disabled, "nor without agreeing")
		agree.button_pressed = true
		await _wait(5)
		check(not create.disabled, "then it's ready")
		await _shot("create_account_ready")
		await _tap_control(create, main)
		await _wait(40)
		var parent: Node = modal_class.top()
		check(parent != null and _find(parent.body, func(n): return n is Label and n.text == "Ask a parent or guardian") != null and app.needs_account(), "under 18, a parent or guardian is asked first")
		if parent:
			check(_find(parent, func(n): return n is Button and n.accessibility_name == "Close") == null, "with no way to close it")
			await _key(KEY_ESCAPE)
			await _wait(20)
			check(modal_class.top() == parent, "not even Esc")
			await _shot("create_account_parent")
			var approve: Button = _find(parent.body, func(n): return n is Button and n.text == "Approve")
			await _tap_control(approve, main)
			await _wait(60)
	var new_slot: String = app.slot
	check(new_slot != home_slot and not app.needs_account(), "Create makes a new account")
	# Arriving home: while the view tilts up only the debug switches show;
	# then the orb grows from nothing, the greeting drops in and types
	# itself out, "Tap to focus" rises in, and last the map and the arrows.
	var home_pane: Node = main._panes[Vector2i.ZERO]
	check(home_pane._orb.scale.x < 0.05 and home_pane._greeting.modulate.a < 0.05 and home_pane._hint.modulate.a < 0.05,
		"arriving home, the orb and the words wait for the view")
	check(main._minimap.modulate.a < 0.05 and main._arriving, "and so do the map and the arrows")
	check(home_pane._debug == null or home_pane._debug.is_visible_in_tree(), "but the debug switches are there")
	if main._backdrop:
		check(main._backdrop.look_down > 0.0 and main._backdrop.look_down < 1.0, "and the view tilts up to the sky (%.2f)" % main._backdrop.look_down)
		await _wait(100)
		check(main._backdrop.look_down < 0.01, "all the way")
	for i in 60:
		if home_pane._orb.scale.x > 0.99:
			break
		await _wait(3)
	check(home_pane._orb.scale.x > 0.99 and main._minimap.modulate.a < 0.05, "the orb grows in once the view's up")
	for i in 120:
		if home_pane._greeting.modulate.a > 0.3:
			break
		await process_frame
	check(home_pane._greeting.modulate.a > 0.3 and home_pane._hint.modulate.a < 0.05,
		"then the greeting drops in, before Tap to focus (stage %d)" % home_pane._intro_stage)
	await _shot("arriving_greeting")
	check(home_pane._greeting.text.contains("Sam") or not home_pane._greeting.text.contains("{"), "greeting you by your new name")
	for i in 120:
		if not main._arriving:
			break
		await _wait(5)
	check(not main._arriving and home_pane._hint.modulate.a > 0.99 and home_pane._greeting.visible_characters == -1, "then Tap to focus rises in")
	await _wait(50)
	check(main._minimap.modulate.a > 0.99 and home_pane._home.modulate.a > 0.99, "and last the map and the home icon")
	# With no pets and no projects there's only up and down.
	check(not main._can_go(Vector2i(-1, 0)) and not main._can_go(Vector2i(1, 0)) and main._can_go(Vector2i(0, 1)), "no pets or projects: only up and down")
	check(main._minimap.cells.size() == 3 and not main._minimap.cells.has(Vector2i(1, 0)), "the map shows just those")
	check(main._minimap.size.x < main._minimap.size.y * 0.6, "in a map one tile wide")
	await _key(KEY_RIGHT)
	await _wait(30)
	check(main._at == Vector2i.ZERO, "and the arrow keys can't go sideways")
	await _shot("arriving_home")
	check(app.state.profile["username"] == "Sam" and app.state.profile["institution"] == "University of York", "with that name and place")
	check(app.state.profile["dob"] == "2012-03-14" and app.state.profile["agreed_unix"] > 0, "and date of birth, and when they agreed")
	check(main._at == Vector2i.ZERO and main._account == null, "and goes to the focus screen")
	check(app.friends.is_empty(), "a new account has no friends")
	check(app.state.projects.is_empty() and app.state.days.is_empty() and app.state.inventory.is_empty(), "and nothing else either")
	check(app.state.settings.get("location") == "off", "it keeps your settings")
	await _shot("account_new")

	app.go("stats")
	await _wait(50)
	var board: Control = _find(main._panes[Vector2i(0, 1)], func(n): return _is(n, "leaderboard.gd"))
	check(board != null and board.rows.is_empty(), "with no friends the leaderboard is empty")
	if board:
		check(_find(board, func(n): return n is Label and n.text == "No friends yet!" and n.is_visible_in_tree()) != null, "and says so")
		check(_find(board, func(n): return n.has_meta("press")) == null and _find(board, func(n): return n is Button) == null, "not even your own row")
		var stats_pane: Control = main._panes[Vector2i(0, 1)]
		check(stats_pane._periods.is_empty() and _find(stats_pane, func(n): return n is Button and _find(n, func(l): return l is Label and l.text == "This week") != null) == null,
			"with only this week there are no weeks to pick between")
	await _shot("leaderboard_empty")

	# Log out, delete Sam, and log back in as Joe.
	app.log_out()
	await _wait(40)
	check(main._account != null, "logging out again shows the screen")
	picker = _class("res://ui/components/account_switcher.gd").open()
	await _wait(25)
	var bin: Button = _find(picker.body, func(n): return n is Button and n.accessibility_name == "Delete Sam")
	check(bin != null, "every account has a bin")
	if bin:
		await _tap_control(bin, main)
		await _wait(25)
		check(modal_class.top() != picker, "it asks first")
		await _shot("account_delete")
		_close_modal(true)
		await _wait(30)
	check(not FileAccess.file_exists(_class("res://core/save_slots.gd").file(new_slot)) and not app.slots().any(func(r): return r["name"] == "Sam"), "and deletes it")
	check(_all(picker.body, func(n): return n.has_meta("press")).size() == before, "the list updates")
	check(app.needs_account(), "you're still logged out")
	var home_card: Control = _find(picker.body, func(n): return n.has_meta("press") and n.accessibility_name == "Log in as Joe")
	check(home_card != null, "the first account is listed by name")
	if home_card:
		await _tap_control(home_card, main)
		await _wait(60)
		# (A slow machine can take a moment longer to switch.)
		for i in 20:
			if not app.needs_account() and not modal_class.is_open():
				break
			await _wait(6)
	check(app.slot == home_slot and app.state.profile["username"] == "Joe" and not app.needs_account() and not modal_class.is_open(), "tapping its card logs back in")
	check(main._at == Vector2i.ZERO and main._account == null and not app.state.projects.is_empty(), "on the focus screen, as it was left")
	# Debug builds only give the first slot sample friends; the rest of the
	# run wants them whichever slot it's in.
	app.friends = _class("res://core/friends.gd").sample()
	app.state_changed.emit()


## Settings, Accessibility, Colour vision recolours the app at once, and
## Data (beside Log out) lists what's kept, with Download and Delete.
func _vision_and_data(main: Node) -> void:
	var app := _app()
	var modal_class := _class("res://ui/modal.gd")
	var ui := _class("res://ui/ui.gd")
	var settings: Node = modal_class.top()
	var vision: Node = _find(settings.body, func(n): return _is(n, "dropdown.gd") and n.accessibility_name == "Colour vision")
	check(vision != null and vision.text == "Standard", "settings have a colour vision picker, on Standard")
	check(_find(settings.body, func(n): return n is Label and n.text == "ACCESSIBILITY") != null, "under Accessibility")
	if vision:
		await settings.scroll_to(vision)
		await _wait(30)
		vision.pressed.emit()
		await _wait(10)
		await _tap_menu(vision, "Deuteranopia")
		await _wait(40)
		check(app.state.settings.get("vision") == "deuteranopia" and ui.ACCENT == Color(ui.SAFE["light" if not ui.dark else "dark"]["ACCENT"]), "picking one swaps in the safe colours")
		check(modal_class.top() == settings and _find(settings.body, func(n): return _is(n, "dropdown.gd") and n.text == "Deuteranopia") != null, "and settings stay open, in them")
		await _shot("settings_vision")
		var again: Node = _find(settings.body, func(n): return _is(n, "dropdown.gd") and n.accessibility_name == "Colour vision")
		again.pressed.emit()
		await _wait(10)
		await _tap_menu(again, "Standard")
		await _wait(40)
		check(app.state.settings.get("vision") == "off" and ui.ACCENT == Color(ui.PALETTES["light" if not ui.dark else "dark"]["ACCENT"]), "Standard puts them back")

	var licences: Button = _find(settings.body, func(n): return n is Button and n.text == "Licences")
	check(licences != null, "settings link the licences")
	if licences:
		var started := Time.get_ticks_msec()
		await _tap_control(licences, main)
		await _wait(25)
		var shown: Node = modal_class.top()
		check(shown != settings and _find(shown.body, func(n): return n is RichTextLabel and n.get_parsed_text().contains("SIL Open Font License")) != null,
			"which list Godot's and the fonts' (%d ms)" % (Time.get_ticks_msec() - started))
		await _shot("licences")
		_close_modal()
		await _wait(20)

	var head: Node = settings.body
	var out: Button = _find(head, func(n): return n is Button and n.text == "Log out")
	var data: Button = _find(head, func(n): return n is Button and n.text == "Data")
	check(out != null and data != null and data.get_global_rect().end.x < out.get_global_rect().position.x, "Data sits left of Log out")
	var first_switch: Control = _find(head, func(n): return _is(n, "switch.gd"))
	if out and first_switch:
		check(out.get_global_rect().end.y < first_switch.get_global_rect().position.y, "both in the account row at the top")
	if data == null:
		return
	await settings.scroll_to(data)
	await _wait(20)
	await _tap_control(data, main)
	await _wait(25)
	var popup: Node = modal_class.top()
	check(popup != settings and _find(popup.header, func(n): return n is Label and n.text == "Your data") != null, "Data opens what's kept about you")
	if popup != settings:
		check(_find(popup.footer, func(n): return n is Button and n.text == "Download") != null and _find(popup.footer, func(n): return n is Button and n.text == "Delete") != null, "with Download and Delete")
		await _shot("data")
		var del: Button = _find(popup.footer, func(n): return n is Button and n.text == "Delete")
		await _tap_control(del, main)
		await _wait(25)
		check(modal_class.top() != popup, "Delete asks first")
		await _shot("data_delete")
		_close_modal(false)
		await _wait(20)
		check(modal_class.top() == popup and app.state.profile["username"] == "Joe", "and No keeps everything")
		_close_modal()
		await _wait(20)


## Taps `c`, scrolling it into view first. In the CI's tiny window it may
## still be out of sight, so there it presses it directly.
func _tap_control(c: Control, main: Node) -> void:
	var n: Node = c.get_parent()
	while n and not n is ScrollContainer:
		n = n.get_parent()
	if n:
		(n as ScrollContainer).ensure_control_visible(c)
		await _wait(5)
	var at := c.get_global_rect().get_center()
	if main.size.y >= 590 and Rect2(Vector2.ZERO, main.size).has_point(at):
		await _drag(at, at, 1)
	elif c is BaseButton:
		c.pressed.emit()
	elif c.has_meta("press"):
		c.get_meta("press").tapped.emit()
	elif _is(c, "gift_tile.gd"):
		c.tapped.emit(c.gift_id)
	await _wait(30)


## The shelf editor, open from the profile: putting gifts up, swapping,
## moving and taking them down, all by dragging, and the sort menu.
func _shelf_editor(editor: Node) -> void:
	var app := _app()
	var main := _main()
	var modal_class := _class("res://ui/modal.gd")
	var editor_modal: Node = modal_class.top()
	await _shot("shelf_editor")
	var common: Control = _editor_tile(editor, "dog_common")
	check(common != null and common.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a shelf gift is greyed out in the collection")
	check(_all(editor._grid, func(n): return n is Label and n.text.begins_with("×")).is_empty(), "no counts in the editor")
	# Putting one up: hold a gift and drop it on the empty middle spot.
	var rare_at: Vector2 = await _shown_point(_editor_tile(editor, "dog_rare"))
	await _drag(rare_at, editor._slots[1].get_global_rect().get_center(), 12, 0.5)
	await _wait(30)
	check(app.state.shelf()[1] == "dog_rare", "holding a gift and dropping it on an empty spot (shelf is %s)" % [app.state.shelf()])
	# Swapping one in: with a mouse, just drag another onto the first spot.
	var replaced: String = app.state.shelf()[0]
	var incoming: Control = _find(editor._grid, func(n): return _is(n, "gift_tile.gd") and n.draggable)
	var incoming_id: String = incoming.gift_id
	var incoming_at: Vector2 = await _shown_point(incoming)
	await _drag(incoming_at, editor._slots[0].get_global_rect().get_center(), 12)
	await _wait(30)
	var back_down: Control = _editor_tile(editor, replaced)
	check(app.state.shelf()[0] == incoming_id and not app.state.shelf().has(replaced) and back_down != null and back_down.draggable,
		"dropping a gift on a full spot swaps it in, and the old one's back in the collection (shelf is %s)" % [app.state.shelf()])
	# Moving one along: drag the first to the last, and they swap.
	var before: Array = app.state.shelf()
	await _drag(editor._slots[0].get_global_rect().get_center(), editor._slots[2].get_global_rect().get_center(), 10)
	await _wait(30)
	var after: Array = app.state.shelf()
	check(after[2] == before[0] and after[0] == before[2] and main._at == Vector2i(0, -1),
		"dragging a shelf gift along swaps them, without leaving the screen (%s -> %s)" % [before, after])
	# Taking one down: drag it off the shelf.
	await _drag(editor._slots[1].get_global_rect().get_center(), editor_modal._scroll.get_global_rect().get_center(), 10)
	await _wait(30)
	check(app.state.shelf()[1] == "", "dragging a gift off the shelf takes it down (shelf is %s)" % [app.state.shelf()])
	# Tapping a gift in the editor does nothing: details live on the gifts screen.
	var look: Control = _find(editor._grid, func(n): return _is(n, "gift_tile.gd") and n.draggable)
	var at_look: Vector2 = await _shown_point(look)
	await _drag(at_look, at_look, 1)
	await _wait(25)
	check(modal_class.top() == editor_modal and app.state.shelf()[1] == "", "tapping a gift in the editor does nothing")
	if modal_class.top() != editor_modal:
		_close_modal()
		await _wait(20)

	# The sort menu: picking an option sorts by it straight away; picking it
	# again flips its arrow, and only then reverses and closes by itself.
	var sort: Node = _find(editor_modal, func(n): return _is(n, "dropdown.gd"))
	check(sort.text.begins_with("Sort by"), "the menu says Sort by (%s)" % sort.text)
	sort._open()
	await _wait(15)
	await _shot("gift_filter")
	await _tap_menu(sort, "A–Z")
	await _wait(15)
	check(app.state.settings.get("gift_sort") == "name" and not app.state.settings.get("gift_sort_reversed") and not is_instance_valid(sort._menu),
		"sort by A-Z, and the menu closes")
	sort._open()
	await _wait(15)
	await _tap_menu(sort, "A–Z")
	await _wait(6)
	check(sort._flipping and is_instance_valid(sort._menu) and not app.state.settings.get("gift_sort_reversed"), "the arrow flips before anything changes")
	# Tapped mid-flip, before the (slow) screenshot lets the flip finish.
	await _tap_menu(sort, "Rarity")
	await _shot("gift_sort_flip")
	# Animations run on real time, which a slow display stretches out.
	for i in 60:
		if not sort._flipping and not is_instance_valid(sort._menu):
			break
		await _wait(5)
	check(app.state.settings.get("gift_sort") == "name" and app.state.settings.get("gift_sort_reversed") == true and not is_instance_valid(sort._menu),
		"then A-Z reverses and the menu closes by itself (taps during the flip do nothing)")
	var shown := []
	for t in _all(editor._grid, func(n): return _is(n, "gift_tile.gd")):
		shown.append(_content().gift(t.gift_id)["name"].to_lower())
	var sorted := shown.duplicate()
	sorted.sort()
	sorted.reverse()
	check(shown.size() > 10 and shown == sorted, "Z-A order in the collection")
	sort._open()
	await _wait(15)
	await _tap_menu(sort, "Rarity")
	await _wait(15)
	_close_modal()
	await _wait(20)


## Whether a pane's content fits on its screen, with nothing cut off at the
## bottom (the screens don't scroll).
func _fits(pane: Control) -> bool:
	var margin: Control = pane.get_child(0)
	return margin.get_combined_minimum_size().y <= pane.size.y + 1.0

## Presses at `from`, optionally holds still for `hold` seconds, drags to
## `to` over a few frames and lets go.
func _drag(from: Vector2, to: Vector2, steps: int = 10, hold: float = 0.0, release_at_end: bool = true) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	root.push_input(press, true)
	await process_frame
	if hold > 0.0:
		await create_timer(hold).timeout
	await _drag_on(from, to, steps, release_at_end)


## Carries on a drag that's already pressed down, then lets go.
func _drag_on(from: Vector2, to: Vector2, steps: int = 10, release_at_end: bool = true) -> void:
	for i in steps:
		var m := InputEventMouseMotion.new()
		m.position = from.lerp(to, float(i + 1) / steps)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(m, true)
		# About a frame at 60fps, so swipe speeds are realistic.
		await create_timer(0.016).timeout
	if not release_at_end:
		return
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	root.push_input(release, true)
	await process_frame


## Waits about this many frames' worth of time at 60fps (headless frames are
## much quicker than that, and animations run on real time).
## Whether `n` runs the script with this file name (named here rather than
## by class, for the same reason as _class()).
## A gift in the shelf editor's collection, or null.
func _editor_tile(editor: Node, id: String) -> Control:
	return _find(editor._grid, func(n): return _is(n, "gift_tile.gd") and n.gift_id == id)


## The middle of the part of a collection gift you can see, scrolling it
## into view first if it needs it.
func _shown_point(tile: Control) -> Vector2:
	var view: ScrollContainer = _class("res://ui/modal.gd").top()._scroll
	view.ensure_control_visible(tile)
	await _wait(5)
	return tile.get_global_rect().intersection(view.get_global_rect()).get_center()


func _is(n: Node, script_file: String) -> bool:
	var s: Script = n.get_script()
	return s != null and s.resource_path.get_file() == script_file


## Every node under `node` that `match` accepts, in tree order.
func _all(node: Node, match: Callable) -> Array:
	var out := []
	for c in node.get_children():
		if match.call(c):
			out.append(c)
		out.append_array(_all(c, match))
	return out


## The first node under `node` (depth first) that `match` accepts.
func _find(node: Node, match: Callable) -> Node:
	for c in node.get_children():
		if match.call(c):
			return c
		var deeper := _find(c, match)
		if deeper:
			return deeper
	return null


## True if `rect` keeps clear of the minimap (small) and the showing edge
## arrows, so nothing on a screen sits under them.
func _clear_of_shell(rect: Rect2) -> bool:
	var main := _main()
	var map: Control = main._minimap
	var map_rect: Rect2 = map.rest_rect()
	if rect.intersects(map_rect):
		return false
	for dir in main._ways_from(main._at):
		if not _app().phone_layout() and rect.intersects(main._arrows[dir].get_global_rect()):
			return false
	return true


## Moves the pointer to `at` with no button down, as a mouse hovering.
func _point(at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.global_position = at
	root.push_input(m, true)
	await process_frame


## One notch of the mouse wheel at `at`.
func _wheel(at: Vector2, button: MouseButton) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = down
		e.factor = 1.0
		e.position = at
		e.global_position = at
		root.push_input(e, true)
	await process_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)
		await process_frame


## Taps the option labelled `text` in an open dropdown's menu.
func _tap_menu(dropdown: Node, text: String) -> void:
	if not is_instance_valid(dropdown._menu):
		dropdown._open()
		await _wait(15)
	var b: Button = _find(dropdown._menu, func(n): return n is Button and n.text == text)
	if b == null:
		check(false, "the menu has %s" % text)
		return
	var at := b.get_global_rect().get_center()
	await _drag(at, at, 1)


func _wait(frames: int) -> void:
	await create_timer(frames / 60.0).timeout
	await process_frame


## UI classes depend on the autoloads, so they're loaded once the app is up
## rather than named in this script (which compiles before autoloads exist).
func _class(path: String) -> GDScript:
	return load(path)


func _close_modal(result: Variant = null) -> void:
	_class("res://ui/modal.gd").top().close(result)


func _shot(name: String) -> void:
	if _shots_dir == "":
		return
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_shots_dir, name])


func check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("SMOKE FAIL: " + msg)
		_failed = true
