extends TestCase
## Icons are SVG files Joe can edit (assets/icons), so a missing or broken
## one would quietly show the X instead.


func test_every_icon_file_draws() -> void:
	for file in DirAccess.get_files_at(Icons.DIR):
		if file.get_extension() != "svg":
			continue
		var img := Image.new()
		eq(img.load_svg_from_string(FileAccess.get_file_as_string(Icons.DIR + file), 1.0), OK, file)
		var imp := Icons.DIR + file + ".import"
		check(FileAccess.file_exists(imp) and FileAccess.get_file_as_string(imp).contains('importer="keep"'),
			"%s ships as it is, so it can be recoloured" % file)


## Every icon named in code and data has a file.
func test_named_icons_exist() -> void:
	var names := {}
	for b in load_json("res://data/biomes.json")["biomes"]:
		names[b["icon"]] = true
	var used := RegEx.create_from_string('(?:icon_rect|Icons\\.texture|round_button|ghost_button)\\("([a-z_]+)"')
	for dir in ["res://ui/", "res://ui/components/", "res://scenes/", "res://scenes/panes/", "res://scenes/walk/",
			"res://scenes/choose_focus/", "res://scenes/customise/", "res://scenes/account/", "res://core/"]:
		for file in DirAccess.get_files_at(dir):
			if file.get_extension() != "gd":
				continue
			for m in used.search_all(FileAccess.get_file_as_string(dir + file)):
				names[m.get_string(1)] = true
	check(names.size() > 20, "found the icons in use (%d)" % names.size())
	for n in names:
		check(Icons.has(n), "%s%s.svg" % [Icons.DIR, n])


func test_tinting_keeps_the_shape() -> void:
	var tex := Icons.texture("close", 24, Color.RED)
	var img := tex.get_image()
	@warning_ignore("integer_division")
	var half := img.get_size() / 2
	var middle := img.get_pixel(half.x, half.y)
	check(middle.a > 0.9 and middle.is_equal_approx(Color.RED), "the cross is red where it's drawn")
	check(img.get_pixel(1, half.y).a < 0.05, "and clear around it")
