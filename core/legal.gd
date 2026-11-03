class_name Legal
extends RefCounted
## The legal side of accounts: the privacy policy and terms (legal/*.md,
## filled in from legal/business.json), dates of birth and the age that
## needs a parent's approval, your data (what's kept, a copy to download,
## deleting it) and the open source licences the app has to show.
## legal/README.md says how to edit them.

const DIR := "res://legal/"
## Under this age, a parent or guardian approves a new account.
const ADULT := 18
## The documents, by file name.
const PRIVACY := "privacy_policy"
const TERMS := "terms_of_service"
## The fonts' licences, shown with the engine's under Licences.
const FONT_LICENCES := ["res://ui/fonts/Fraunces-OFL.txt", "res://ui/fonts/Quicksand-OFL.txt"]


## Who runs the app (legal/business.json), with "app" added: the app's name.
static func business() -> Dictionary:
	var out := {}
	var f := FileAccess.open(DIR + "business.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			out = parsed
	out["app"] = ProjectSettings.get_setting("application/config/name", "")
	return out


## A document's Markdown with every {key} from business() filled in.
static func text(doc: String) -> String:
	var f := FileAccess.open(DIR + doc + ".md", FileAccess.READ)
	return f.get_as_text().format(business()) if f else ""


## A document in a popup: its "# " line is the title and the rest scrolls.
static func open(doc: String) -> Modal:
	var lines := text(doc).split("\n")
	var title := lines[0].trim_prefix("# ") if lines.size() > 0 else ""
	var m := Modal.open(560)
	m.header.add_child(m.heading_row(title))
	m.body.add_child(page("\n".join(lines.slice(1))))
	return m


## Markdown as the app's type: "## " headings, "- " bullets and paragraphs.
static func page(markdown: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.selection_enabled = true
	r.focus_mode = Control.FOCUS_NONE
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_override("normal_font", UI.font(false, 600))
	r.add_theme_font_override("bold_font", UI.font(true, 600))
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_font_size_override("bold_font_size", 19)
	r.add_theme_color_override("default_color", UI.INK_SOFT)
	r.add_theme_constant_override("line_separation", 3)
	var out := PackedStringArray()
	var last := ""
	for line in markdown.strip_edges().split("\n"):
		line = line.replace("[", "[lb]")
		# Licence texts come hard-wrapped: a long line carries on into the next.
		var carries := last.length() >= 60 and line != "" and not line.begins_with("#") and not line.begins_with("- ")
		last = line
		if carries:
			out[out.size() - 1] += " " + line.strip_edges()
		elif line.begins_with("## "):
			out.append("[b][color=#%s]%s[/color][/b]" % [UI.INK.to_html(false), line.trim_prefix("## ")])
		elif line.begins_with("- "):
			out.append("[indent]•  %s[/indent]" % line.trim_prefix("- "))
		else:
			out.append(line)
	r.text = "\n".join(out)
	return r


# --- Dates of birth ----------------------------------------------------------

## "YYYY-MM-DD" for a real date that's already happened, or "".
static func dob(day: String, month: String, year: String, today: Dictionary) -> String:
	if not (day.is_valid_int() and month.is_valid_int() and year.is_valid_int()) or year.length() != 4:
		return ""
	var y := int(year)
	var m := int(month)
	var d := int(day)
	var leap := (y % 4 == 0 and y % 100 != 0) or y % 400 == 0
	var days := [31, 29 if leap else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if y < 1900 or m < 1 or m > 12 or d < 1 or d > days[m - 1]:
		return ""
	var out := "%04d-%02d-%02d" % [y, m, d]
	return out if age(out, today) >= 0 else ""


## Whole years since `birth` ("YYYY-MM-DD") on `today` ({year, month, day});
## -1 for no date or one still to come.
static func age(birth: String, today: Dictionary) -> int:
	var parts := birth.split("-")
	if parts.size() != 3:
		return -1
	var years := int(today["year"]) - int(parts[0])
	if int(today["month"]) * 100 + int(today["day"]) < int(parts[1]) * 100 + int(parts[2]):
		years -= 1
	return years


# --- Your data ---------------------------------------------------------------

## What's kept about you, as [title, detail] rows, for the Data popup.
static func held(s: GameState) -> Array:
	var gifts := 0
	for id in s.inventory:
		gifts += int(s.inventory[id])
	return [
		[Text.t("data.profile"), Text.t("data.profile_detail")],
		[Text.t("data.projects"), Text.count("data.projects_detail", s.projects.size(), {"pets": Text.count("data.pets", s.pets.size())})],
		[Text.t("data.focus"), Text.count("data.focus_detail", s.days.size())],
		[Text.t("data.gifts"), Text.count("data.gifts_detail", gifts)],
		[Text.t("data.settings"), Text.t("data.settings_detail")],
	]


## The Data popup: what's kept and where, then Download and Delete.
static func open_data() -> Modal:
	var m := Modal.open(460)
	m.header.add_child(m.heading_row(Text.t("data.title")))
	m.body.add_child(UI.para(Text.t("data.where"), 15))
	var list := UI.vbox(10)
	for row in held(App.state):
		var item := UI.vbox(1)
		item.add_child(UI.label(row[0], 16, UI.INK, false, 800))
		item.add_child(UI.para(row[1], 13))
		list.add_child(item)
	m.body.add_child(list)
	var policy := UI.text_link(Text.t("legal.privacy"), open.bind(PRIVACY))
	m.body.add_child(policy)
	var buttons := UI.hbox(10)
	var get_copy := UI.button(Text.t("data.download"), download, "quiet")
	get_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(get_copy)
	var wipe := UI.button(Text.t("data.delete"), _confirm_delete, "danger")
	wipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(wipe)
	m.footer.add_child(buttons)
	return m


## Everything kept about you, as the file Download saves.
static func export_json(s: GameState) -> String:
	var out := SaveSystem.to_dict(s)
	out.erase("active")
	return JSON.stringify(out, "\t")


## Saves a copy of your data where you choose (on a phone, into the app's
## folder in Files).
static func download() -> void:
	var name := "%s data.json" % ProjectSettings.get_setting("application/config/name", "")
	var json := export_json(App.state)
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE) and not OS.has_feature("mobile"):
		DisplayServer.file_dialog_show(Text.t("data.download"), OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS), name, false,
			DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.json"]), func(ok: bool, paths: PackedStringArray, _filter: int):
				if ok and not paths.is_empty():
					_write(paths[0], json, paths[0].get_file()))
	else:
		_write("user://" + name, json, Text.t("data.saved_phone"))


static func _write(path: String, json: String, where: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Toast.show_text(Text.t("data.save_failed"), "close")
		return
	f.store_string(json)
	f.close()
	Toast.show_text(Text.t("data.saved", {"where": where}))


static func _confirm_delete() -> void:
	var name := str(App.state.profile.get("username", ""))
	Modal.confirm(Text.t("data.delete_title"), Text.t("data.delete_body", {"name": name}), Text.t("data.delete")).closed.connect(func(yes):
		if yes:
			Modal.close_all()
			App.delete_account())


# --- Licences ----------------------------------------------------------------

## Every open source part the app is built from, with its licence: the
## Godot engine and what it's made of, the fonts, and the weather data.
static func licences_text() -> String:
	var out := PackedStringArray()
	out.append("## Godot Engine")
	out.append(Engine.get_license_text().strip_edges())
	out.append("## Fonts")
	for path in FONT_LICENCES:
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			out.append(f.get_as_text().strip_edges())
	out.append("## Weather")
	out.append(Text.t("legal.weather_credit"))
	out.append("## Parts of Godot")
	for part in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for piece in part["parts"]:
			for who in piece["copyright"]:
				lines.append("© " + who)
			lines.append(Text.t("legal.licence", {"licence": piece["license"]}))
		out.append("%s\n%s" % [part["name"], "\n".join(lines)])
	var texts: Dictionary = Engine.get_license_info()
	for id in texts:
		out.append("## " + id)
		out.append(str(texts[id]).strip_edges())
	return "\n\n".join(out)


static func open_licences() -> Modal:
	var m := Modal.open(560)
	m.header.add_child(m.heading_row(Text.t("legal.licences")))
	m.body.add_child(page(licences_text()))
	return m
