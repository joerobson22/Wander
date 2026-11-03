class_name Text
extends RefCounted
## Every word the app shows, from data/text.json, so wording is a data edit.
## Keys are dotted paths into the file ("profile.settings"). A {word} in a
## line is filled in from `values` ({"name": "Joe"}), and {app} is always the
## app's name (Project Settings > Application > Config > Name, the one place
## it's set); anything else in braces is left alone. A line that differs for one thing and many is a pair:
## {"one": "{n} day", "other": "{n} days"}, picked by count().

const PATH := "res://data/text.json"

static var _data: Dictionary = {}


## The line at `key`, with its {words} filled in. A missing key shows the key
## itself, so a typo is easy to spot on screen.
static func t(key: String, values: Dictionary = {}) -> String:
	var found = lookup(key)
	if found is Dictionary and found.has("other"):
		found = found["other"]
	if not found is String:
		push_warning("Text: no line for \"%s\"" % key)
		return key
	return fill(found, values)


## The singular or plural line at `key` for `n` (also filled in as {n}).
static func count(key: String, n: int, values: Dictionary = {}) -> String:
	var found = lookup(key)
	if not found is Dictionary:
		return t(key, values.merged({"n": n}))
	var line = found.get("one" if n == 1 else "other", found.get("other", key))
	return fill(str(line), values.merged({"n": n}))


## The list at `key` (month names, greetings), or [] if there isn't one.
static func list(key: String) -> Array:
	var found = lookup(key)
	return found if found is Array else []


## Whatever is at `key`: a line, a list, a section, or null.
static func lookup(key: String) -> Variant:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if not parsed is Dictionary:
			push_error("Text: couldn't read %s" % PATH)
			return null
		_data = parsed
	var at: Variant = _data
	for part in key.split("."):
		if not at is Dictionary or not at.has(part):
			return null
		at = at[part]
	return at


static func fill(line: String, values: Dictionary) -> String:
	for k in values:
		line = line.replace("{%s}" % k, str(values[k]))
	return line.replace("{app}", ProjectSettings.get_setting("application/config/name", ""))
