extends TestCase

const DIR := "user://test_slots"
const INDEX := DIR + "/slots.json"


func _cleanup() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var d := DirAccess.open(DIR)
	for f in d.get_files():
		d.remove(f)


func test_no_index_means_just_the_first_slot() -> void:
	_cleanup()
	var index := SaveSlots.read_index(INDEX)
	eq(index["current"], SaveSlots.FIRST)
	eq(index["slots"], [SaveSlots.FIRST])


func test_first_slot_keeps_the_original_save() -> void:
	eq(SaveSlots.file(SaveSlots.FIRST), SaveSystem.SAVE_PATH, "first slot's file")
	eq(SaveSlots.file("abc", INDEX), DIR + "/save_abc.json")


func test_index_round_trip() -> void:
	_cleanup()
	eq(SaveSlots.write_index({"current": "b", "slots": ["main", "b"]}, INDEX), OK)
	var index := SaveSlots.read_index(INDEX)
	eq(index["current"], "b")
	eq(index["slots"], ["main", "b"])


func test_damaged_or_odd_index_is_tidied() -> void:
	_cleanup()
	var f := FileAccess.open(INDEX, FileAccess.WRITE)
	f.store_string('{"current": "gone", "slots": ["main", "", "main", "b", 4]}')
	f.close()
	var index := SaveSlots.read_index(INDEX)
	eq(index["slots"], ["main", "b"], "duplicates and junk dropped")
	eq(index["current"], "main", "a missing current falls back to the first")
	f = FileAccess.open(INDEX, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	eq(SaveSlots.read_index(INDEX)["slots"], [SaveSlots.FIRST], "a damaged index starts again")


func test_new_ids_are_unique() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var taken: Array = []
	for i in 50:
		var id := SaveSlots.new_id(1000, rng, taken)
		check(not taken.has(id) and id != SaveSlots.FIRST, "id %s is new" % id)
		taken.append(id)


func test_remove_deletes_the_save_but_never_the_current_slot() -> void:
	_cleanup()
	var index := {"current": "main", "slots": ["main", "b"]}
	var path := SaveSlots.file("b", INDEX)
	SaveSystem.write(GameState.new(), path)
	SaveSystem.write(GameState.new(), path)
	check(FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bak"))
	check(not SaveSlots.remove(index, "main", INDEX), "the slot in use stays")
	check(SaveSlots.remove(index, "b", INDEX), "another slot goes")
	eq(index["slots"], ["main"])
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"), "its save and backup are deleted")
	check(not SaveSlots.remove(index, "b", INDEX), "and can't be removed twice")


func test_summary() -> void:
	var s := GameState.new()
	s.profile["username"] = "Joe"
	s.log_focus(100, "a", "pet", "lake", 3000)
	s.log_focus(101, "b", "pet", "forest", 600)
	var rows := [{"earned": true}, {"earned": false}, {"earned": false}]
	var out := SaveSlots.summary(s, rows)
	eq(out["name"], "Joe")
	eq(out["focused_seconds"], 3600, "every day's focus")
	eq(out["achievements"], 33, "whole percent earned")
	eq(SaveSlots.summary(s, [])["achievements"], 0, "no achievements")


## Logging out is remembered, so the create account screen is still up
## next time the app opens.
func test_logged_out_survives_a_restart() -> void:
	_cleanup()
	check(not SaveSlots.read_index(INDEX)["signed_out"], "logged in by default")
	eq(SaveSlots.write_index({"current": "main", "slots": ["main"], "signed_out": true}, INDEX), OK)
	check(SaveSlots.read_index(INDEX)["signed_out"], "then logged out")
	SaveSlots.write_index({"current": "main", "slots": ["main"]}, INDEX)
	check(not SaveSlots.read_index(INDEX)["signed_out"], "an index without it is logged in")


func test_old_half_made_accounts_lose_their_flag() -> void:
	var s := SaveSystem.from_dict({"version": SaveSystem.CURRENT_VERSION, "profile": {"setup_pending": true}})
	check(not s.profile.has("setup_pending"))


func test_no_friends_means_an_empty_leaderboard() -> void:
	eq(Friends.ranked([], 3600, false), [], "not even you")
	eq(Friends.ranked(Friends.sample(), 3600, false).size(), Friends.sample().size() + 1, "you and every friend")
