extends TestCase
## data/text.json holds every word on screen, so a key used in the code but
## missing from the file would show up as the key itself.


## Every Text.t / Text.count / Text.list key written out in the code exists.
func test_every_key_in_the_code_has_a_line() -> void:
	var pattern := RegEx.create_from_string("Text\\.(?:t|count|list)\\(\"([a-z_.]+)\"")
	var dotted := RegEx.create_from_string("\"([a-z_]+\\.[a-z_.]+)\"")
	var found := 0
	for path in _scripts("res://"):
		var source := FileAccess.get_file_as_string(path)
		var keys := {}
		for m in pattern.search_all(source):
			if not m.get_string(1).ends_with("."):
				keys[m.get_string(1)] = true
		# Keys picked by a condition: Text.t("a.b" if x else "a.c").
		for line in source.split("\n"):
			if line.contains("Text.") and not line.strip_edges().begins_with("#"):
				for m in dotted.search_all(line):
					if not m.get_string(1).ends_with(".") and not m.get_string(1).get_extension() in ["json", "gd", "png"]:
						keys[m.get_string(1)] = true
		for key in keys:
			found += 1
			check(Text.lookup(key) != null, "%s uses \"%s\", which isn't in text.json" % [path, key])
	check(found > 150, "found the keys (%d)" % found)


func test_window_modes_are_all_named() -> void:
	for id in Display.MODES:
		check(Text.lookup("window.modes." + id) is String, "window.modes.%s" % id)


func test_lists() -> void:
	eq(Text.list("dates.months").size(), 12)
	eq(Text.list("dates.days_short").size(), 7)
	eq(Text.list("dates.days_long").size(), 7)
	eq(Text.list("choose_focus.colour_roles").size(), 3)
	check(Text.list("quotes").size() > 10, "walk quotes")
	for part in ["morning", "afternoon", "evening", "night", "anytime"]:
		check(not Text.list("greetings." + part).is_empty(), "greetings for %s" % part)


func test_filling_in() -> void:
	eq(Text.t("choose_focus.rehomed", {"pet": "Biscuit"}), "Biscuit has a new home")
	eq(Text.count("stats.days", 1), "1 day")
	eq(Text.count("stats.days", 3), "3 days")
	eq(Text.count("walk.minutes", 1), "1 minute")
	eq(Text.t("not.a.key"), "not.a.key", "a missing line shows its key")


func _scripts(dir: String) -> Array:
	var out := []
	for sub in ["core", "scenes", "ui"]:
		out.append_array(_walk(dir + sub))
	return out


func _walk(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_walk(dir + "/" + sub))
	return out
