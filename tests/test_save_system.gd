extends TestCase

const PATH := "user://test_save.json"


func _cleanup() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _sample() -> GameState:
	var s := GameState.new()
	s.profile["username"] = "joe"
	var p := ProjectData.new()
	p.id = "p1"
	p.name = "Dissertation"
	p.pets = {"pet1": 1300}
	p.places = {"jungle": 1234, "lake": 66}
	p.gifts = {"dog_common": 2}
	s.projects.append(p)
	var pet := PetData.new()
	pet.id = "pet1"
	pet.name = "Biscuit"
	pet.animal_id = "dog1"
	pet.colours = [Color("#112233"), Color("#445566"), Color("#778899")]
	pet.adopted_unix = 400
	pet.rehomed_unix = 900
	pet.places = {"jungle": 1234, "lake": 66}
	s.pets.append(pet)
	s.log_focus(20380, "p1", "pet1", "jungle", 1234)
	s.log_focus(20381, "p1", "pet1", "lake", 66)
	s.xp = 321
	s.inventory["dog_common"] = 2
	s.active = SessionClock.begin("p1", "pet1", 500)
	return s


func test_round_trip() -> void:
	_cleanup()
	eq(SaveSystem.write(_sample(), PATH), OK)
	var back := SaveSystem.read(PATH)
	check(back != null)
	eq(back.profile["username"], "joe")
	eq(back.projects[0].name, "Dissertation")
	eq(back.projects[0].pets, {"pet1": 1300})
	eq(back.projects[0].places, {"jungle": 1234, "lake": 66})
	eq(back.pets[0].name, "Biscuit")
	eq(back.pets[0].colours[1].to_html(false), "445566")
	eq(back.pets[0].adopted_unix, 400)
	eq(back.pets[0].places, {"jungle": 1234, "lake": 66})
	check(back.pets[0].is_rehomed(), "a rehomed pet stays rehomed")
	eq(back.pet_seconds("pet1"), 1300)
	eq(back.project_gifts("p1"), {"dog_common": 2})
	eq(back.days[20380]["places"], {"jungle": 1234}, "days come back keyed by number")
	eq(back.project_seconds("p1"), 1300)
	eq(back.xp, 321)
	eq(back.inventory["dog_common"], 2)
	eq(back.active.start_unix, 500)
	eq(back.active.pet_id, "pet1")
	_cleanup()


## The save keeps only what can't be worked out: a year of daily walks
## stays small.
func test_save_stays_small() -> void:
	var s := _sample()
	for day in 365:
		s.log_focus(20000 + day, "p1", "pet1", "lake", 3600)
		s.log_focus(20000 + day, "p1", "pet1", "jungle", 1800)
	var text := JSON.stringify(SaveSystem.to_dict(s))
	check(text.length() < 40000, "a year of walks is %d characters" % text.length())
	check(not text.contains("\n\t"), "written compactly")


func test_damaged_save_falls_back_to_backup() -> void:
	_cleanup()
	SaveSystem.write(_sample(), PATH)
	SaveSystem.write(_sample(), PATH) # second write leaves a .bak
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var back := SaveSystem.read(PATH)
	check(back != null, "backup used")
	eq(back.projects.size(), 1)
	_cleanup()


func test_missing_save_is_null() -> void:
	_cleanup()
	check(SaveSystem.read(PATH) == null)


func test_missing_fields_get_defaults() -> void:
	var back := SaveSystem.from_dict({"version": SaveSystem.CURRENT_VERSION, "profile": {"username": "x"}})
	eq(back.profile["walks_since_epic"], 0)
	eq(back.settings["sound"], true)
	check(back.profile["cosmetics"].has("hat"))
	eq(back.profile["shelf"], ["", "", ""])


func test_other_versions_are_not_loaded() -> void:
	check(SaveSystem.from_dict({"version": 2, "profile": {"username": "x"}}) == null, "an older save")
	check(SaveSystem.from_dict({"profile": {"username": "x"}}) == null, "no version at all")
	_cleanup()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "sessions": []}))
	f.close()
	check(SaveSystem.out_of_date(PATH), "spotted on disk")
	check(SaveSystem.read(PATH) == null, "and not read")
	SaveSystem.set_aside(PATH)
	check(not FileAccess.file_exists(PATH) and FileAccess.file_exists(PATH + ".old"), "moved aside, not deleted")
	check(not SaveSystem.out_of_date(PATH), "leaving room for a fresh one")
	DirAccess.remove_absolute(PATH + ".old")
	SaveSystem.write(_sample(), PATH)
	check(not SaveSystem.out_of_date(PATH), "today's version is fine")
	_cleanup()


func test_shelf_round_trip_and_moves() -> void:
	var s := _sample()
	s.place_on_shelf("dog_common", 2)
	s.place_on_shelf("bear_rare", 0)
	eq(s.shelf(), ["bear_rare", "", "dog_common"])
	s.place_on_shelf("dog_common", 0)
	eq(s.shelf(), ["dog_common", "", "bear_rare"], "moving swaps")
	s.remove_from_shelf(2)
	eq(s.shelf(), ["dog_common", "", ""])
	var back := SaveSystem.from_dict(SaveSystem.to_dict(s))
	eq(back.shelf(), ["dog_common", "", ""])


func test_traded_away_gifts_leave_shelf_and_wardrobe() -> void:
	var s := _sample()
	s.inventory["bear_epic"] = 0
	s.place_on_shelf("bear_epic", 1)
	s.place_on_shelf("dog_common", 0)
	s.profile["cosmetics"]["walking_stick"] = "bear_epic"
	s.tidy_gift_references()
	eq(s.shelf(), ["dog_common", "", ""])
	eq(s.profile["cosmetics"]["walking_stick"], "")
