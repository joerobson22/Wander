class_name SaveSlots
extends RefCounted
## Save slots: separate accounts on one device, each with its own save file.
## An index file lists them in the order they were made and says which one
## is in use. The first slot keeps the original save.json, so a save from
## before slots carries straight on as the first slot.

const INDEX_PATH := "user://slots.json"
## The first slot's id.
const FIRST := "main"


## The save file for slot `id`, next to the index.
static func file(id: String, index_path: String = INDEX_PATH) -> String:
	var dir := index_path.get_base_dir()
	return dir.path_join(SaveSystem.SAVE_PATH.get_file() if id == FIRST else "save_%s.json" % id)


## {current: slot id, slots: [slot ids, oldest first], signed_out: whether
## you logged out}. With no index yet, just the first slot.
static func read_index(index_path: String = INDEX_PATH) -> Dictionary:
	var out := {"current": FIRST, "slots": [FIRST], "signed_out": false}
	if not FileAccess.file_exists(index_path):
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if not parsed is Dictionary:
		push_warning("Save slot list %s is damaged, starting again" % index_path)
		return out
	var slots: Array = []
	for id in parsed.get("slots", []):
		if id is String and id != "" and not slots.has(id):
			slots.append(id)
	if slots.is_empty():
		slots.append(FIRST)
	var current := str(parsed.get("current", ""))
	out["slots"] = slots
	out["current"] = current if slots.has(current) else slots[0]
	out["signed_out"] = bool(parsed.get("signed_out", false))
	return out


static func write_index(index: Dictionary, index_path: String = INDEX_PATH) -> Error:
	var f := FileAccess.open(index_path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"current": index["current"], "slots": index["slots"], "signed_out": bool(index.get("signed_out", false))}, "\t"))
	f.close()
	return OK


## A new slot id, unique among `taken`.
static func new_id(now: int, rng: RandomNumberGenerator, taken: Array) -> String:
	var id := ""
	while id == "" or taken.has(id) or id == FIRST:
		id = "%d_%04x" % [now, rng.randi() & 0xffff]
	return id


## Takes slot `id` out of the index and deletes its save. The slot in use
## can't be deleted.
static func remove(index: Dictionary, id: String, index_path: String = INDEX_PATH) -> bool:
	if id == index["current"] or not (index["slots"] as Array).has(id):
		return false
	(index["slots"] as Array).erase(id)
	var path := file(id, index_path)
	for p in [path, path + ".bak", path + ".tmp", path + ".old", path + ".bak.old"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	return true


## What the account switcher shows for a slot's save: {name, look,
## focused_seconds, achievements (whole percent earned)}.
static func summary(state: GameState, achievement_rows: Array) -> Dictionary:
	var p := state.profile
	var earned := achievement_rows.filter(func(r): return r["earned"]).size()
	return {
		"name": str(p.get("username", "")),
		"look": {"skin_tone": p.get("skin_tone", 0), "hair_tone": p.get("hair_tone", 0), "skin_colour": p.get("skin_colour", ""), "hair_colour": p.get("hair_colour", ""), "cosmetics": p.get("cosmetics", {})},
		"focused_seconds": state.total_seconds(),
		"achievements": roundi(100.0 * earned / achievement_rows.size()) if not achievement_rows.is_empty() else 0,
	}
