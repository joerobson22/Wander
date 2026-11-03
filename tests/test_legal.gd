extends TestCase
## Dates of birth, the age that needs a parent, the documents and the data
## the Data popup lists and downloads.

const TODAY := {"year": 2026, "month": 11, "day": 1}


func test_a_real_date_of_birth() -> void:
	eq(Legal.dob("14", "3", "2012", TODAY), "2012-03-14", "padded")
	eq(Legal.dob("29", "02", "2004", TODAY), "2004-02-29", "a leap day")


func test_dates_that_cant_be_right() -> void:
	for d in [["31", "02", "2012"], ["29", "02", "2005"], ["00", "05", "2000"], ["10", "13", "2000"], ["1", "1", "12"],
			["", "", ""], ["2", "11", "2026"], ["1", "1", "1850"], ["a", "1", "2000"]]:
		eq(Legal.dob(d[0], d[1], d[2], TODAY), "", "%s/%s/%s" % d)


func test_age_turns_on_the_birthday() -> void:
	eq(Legal.age("2008-11-01", TODAY), 18, "18 today")
	eq(Legal.age("2008-11-02", TODAY), 17, "18 tomorrow")
	eq(Legal.age("2026-11-01", TODAY), 0, "born today")
	eq(Legal.age("", TODAY), -1, "no date")
	check(Legal.age("2009-01-01", TODAY) < Legal.ADULT, "under 18 needs a parent")


func test_documents_are_filled_in_from_business() -> void:
	var b := Legal.business()
	check(str(b.get("app", "")) != "", "the app's name is added")
	for doc in [Legal.PRIVACY, Legal.TERMS]:
		var text := Legal.text(doc)
		check(text.begins_with("# "), "%s starts with its title" % doc)
		check(text.contains(str(b["email"])), "%s has the contact email" % doc)
		check(not RegEx.create_from_string("\\{[a-z_]+\\}").search(text), "%s has nothing left in braces" % doc)


func test_the_policy_reads_as_paragraphs() -> void:
	var page := Legal.page("## Heading\n\nSome [words].\n- a point")
	var text := page.get_parsed_text()
	check(text.contains("Heading") and text.contains("[words]") and text.contains("•  a point"), text)
	page.free()


func test_data_lists_everything_kept() -> void:
	var s := GameState.new()
	s.projects.append(ProjectData.new())
	s.inventory = {"dog_common": 3, "cat_rare": 1}
	var rows := Legal.held(s)
	eq(rows.size(), 5, "account, projects, focus, gifts, settings")
	check(str(rows[3][1]).begins_with("4 gifts"), rows[3][1])


func test_the_download_is_the_save_without_a_walk() -> void:
	var s := GameState.new()
	s.profile["username"] = "Sam"
	s.profile["dob"] = "2012-03-14"
	var parsed: Dictionary = JSON.parse_string(Legal.export_json(s))
	eq(parsed["profile"]["username"], "Sam")
	eq(parsed["profile"]["dob"], "2012-03-14")
	check(not parsed.has("active"), "no walk in progress")


func test_a_new_account_keeps_its_birthday_through_a_save() -> void:
	var s := GameState.new()
	s.profile["dob"] = "2001-05-06"
	s.profile["agreed_unix"] = 5
	var back := SaveSystem.from_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_dict(s))))
	eq(back.profile["dob"], "2001-05-06")
	eq(back.profile["agreed_unix"], 5)


func test_licences_include_the_engine_and_fonts() -> void:
	var text := Legal.licences_text()
	check(text.contains("Godot Engine contributors"), "Godot's notice")
	check(text.contains("Fraunces") and text.contains("Quicksand") and text.contains("SIL Open Font License"), "both fonts")
	check(text.contains("Open-Meteo"), "the weather credit")
