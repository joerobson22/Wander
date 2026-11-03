class_name SaveSystem
extends RefCounted
## The save: a small JSON file with atomic writes and a backup copy. It keeps
## only what can't be worked out again: your profile and settings, your
## projects and pets, focus time per day (by project, pet and place), your XP total,
## your gifts and any walk in progress. Everything else (levels, stats,
## achievements, what's unlocked) is worked out from these and the data
## files, so the data files can change freely.
## A save from another version isn't loaded: the app starts afresh and keeps
## the old file beside it as .old (see App).

const CURRENT_VERSION := 4
const SAVE_PATH := "user://save.json"


# --- Serialisation -----------------------------------------------------------

static func to_dict(state: GameState) -> Dictionary:
	var projects: Array = []
	for p in state.projects:
		projects.append(p.to_dict())
	var pets: Array = []
	for p in state.pets:
		pets.append(p.to_dict())
	# JSON keys are strings; days are kept in order so the file reads well.
	var days := {}
	var order := state.days.keys()
	order.sort()
	for day in order:
		days[str(day)] = state.days[day]
	return {
		"version": CURRENT_VERSION,
		"profile": state.profile,
		"xp": state.xp,
		"projects": projects,
		"pets": pets,
		"days": days,
		"inventory": state.inventory,
		"active": _active_dict(state.active),
		"settings": state.settings,
	}


## The walk in progress for the save, or null when there isn't one.
static func _active_dict(active: SessionClock) -> Variant:
	if active == null:
		return null
	return active.to_dict()


## The state in a save dictionary, or null if it's from another version.
static func from_dict(d: Dictionary) -> GameState:
	if int(d.get("version", 0)) != CURRENT_VERSION:
		return null
	var state := GameState.new()
	state.profile.merge(d.get("profile", {}), true)
	var cosmetics: Dictionary = GameState.default_profile()["cosmetics"]
	cosmetics.merge(state.profile.get("cosmetics", {}), true)
	state.profile["cosmetics"] = cosmetics
	for k in ["created_unix", "skin_tone", "hair_tone", "walks_since_epic", "walks", "agreed_unix"]:
		state.profile[k] = int(state.profile[k])
	state.profile["username"] = str(state.profile["username"])
	state.profile["institution"] = str(state.profile["institution"])
	state.profile["dob"] = str(state.profile["dob"])
	state.profile["shelf"] = state.shelf()
	# Older saves marked a half-made account; the create account screen does that now.
	state.profile.erase("setup_pending")
	state.xp = int(d.get("xp", 0))
	for p in d.get("projects", []):
		state.projects.append(ProjectData.from_dict(p))
	for p in d.get("pets", []):
		state.pets.append(PetData.from_dict(p))
	var days = d.get("days", {})
	if days is Dictionary:
		for key in days:
			var entry = days[key]
			if not str(key).is_valid_int() or not entry is Dictionary:
				continue
			var tidy := {"projects": {}, "pets": {}, "places": {}}
			for part in tidy:
				var totals = entry.get(part, {})
				if totals is Dictionary:
					for id in totals:
						tidy[part][str(id)] = int(totals[id])
			state.days[int(key)] = tidy
	for gift_id in d.get("inventory", {}):
		state.inventory[gift_id] = int(d["inventory"][gift_id])
	var active = d.get("active")
	if active is Dictionary:
		state.active = SessionClock.from_dict(active)
	state.settings.merge(d.get("settings", {}), true)
	return state


# --- Files -------------------------------------------------------------------

## Writes to a temp file then swaps it in, keeping the previous save as .bak,
## so a crash mid-write can never leave a half-written save.
static func write(state: GameState, path: String = SAVE_PATH) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(state)))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path)


## Returns the saved state, falling back to the backup if the main file is
## damaged, or null when there's no save, or only one from another version.
static func read(path: String = SAVE_PATH) -> GameState:
	for candidate in [path, path + ".bak"]:
		var parsed := _parse(candidate)
		if parsed.is_empty():
			continue
		return from_dict(parsed)
	return null


## True when there's a save at `path` that this version can't load.
static func out_of_date(path: String = SAVE_PATH) -> bool:
	for candidate in [path, path + ".bak"]:
		var parsed := _parse(candidate)
		if not parsed.is_empty():
			return int(parsed.get("version", 0)) != CURRENT_VERSION
	return false


## Moves a save this version can't load (and its backup) aside, to .old, so
## a fresh one can start without losing it.
static func set_aside(path: String = SAVE_PATH) -> void:
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			var old: String = p.trim_suffix(".bak") + (".bak.old" if p.ends_with(".bak") else ".old")
			if FileAccess.file_exists(old):
				DirAccess.remove_absolute(old)
			DirAccess.rename_absolute(p, old)


## The file's JSON, or {} if it's missing or damaged.
static func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_warning("Save file %s is damaged, trying backup" % path)
	return {}


## When the save was last written (unix seconds), or 0 if there isn't one.
static func saved_unix() -> int:
	return int(FileAccess.get_modified_time(SAVE_PATH)) if FileAccess.file_exists(SAVE_PATH) else 0
