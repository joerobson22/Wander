extends "res://tests/smoke.gd"
## Screenshots of the main screens in light and dark, with a popup and the
## choose focus screen, to look over the app's look.
##   godot --path . -s tests/style_shots.gd -- --shots=<dir>
## Without --shots it only checks each mode draws without script errors.


func _run() -> void:
	await process_frame
	await process_frame
	_fill_sample_data()
	var main := _main()
	var app := _app()
	app.state.settings["location"] = "off"
	app.set_setting("debug_hour", 12.0)
	await _wait(40)
	for mode in ["light", "dark"]:
		app.set_setting("debug_theme", mode)
		await _wait(30)
		check(bool(_class("res://ui/ui.gd").dark) == (mode == "dark"), "%s colours are in use" % mode)
		for pane in ["focus", "gifts", "projects", "stats", "profile"]:
			app.go(pane)
			await _wait(40)
			await _shot("%s_%s" % [mode, pane])
		# A popup: the accounts list, from the profile screen.
		_class("res://ui/components/account_switcher.gd").open()
		await _wait(30)
		await _shot("%s_popup" % mode)
		_close_modal()
		await _wait(20)
		app.go("focus")
		await _wait(30)
		app.go("choose_focus", {"from": main.size * 0.5})
		await _wait(60)
		await _shot("%s_choose_focus" % mode)
		app.go("home")
		await _wait(40)
	app.set_setting("debug_theme", "auto")
	app.set_setting("debug_hour", -1.0)
	await _wait(10)
	print("STYLE SHOTS FAIL" if _failed else "STYLE SHOTS OK")
	quit(1 if _failed else 0)
