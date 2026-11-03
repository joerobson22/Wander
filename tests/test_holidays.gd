extends TestCase

var _list: Array = load_json("res://data/holidays.json")["holidays"]


func _at(year: int, month: int, day: int, hour: int = 12, minute: int = 0) -> Dictionary:
	return {"year": year, "month": month, "day": day, "hour": hour, "minute": minute}


func test_easter_sundays() -> void:
	eq(Holidays.easter(2024), Vector2i(3, 31))
	eq(Holidays.easter(2025), Vector2i(4, 20))
	eq(Holidays.easter(2026), Vector2i(4, 5))
	eq(Holidays.easter(2027), Vector2i(3, 28))
	eq(Holidays.easter(2038), Vector2i(4, 25), "as late as it gets")


func test_fixed_days() -> void:
	eq(Holidays.on(_at(2026, 10, 31), _list, ""), "halloween")
	eq(Holidays.on(_at(2026, 10, 30), _list, ""), "")
	eq(Holidays.on(_at(2026, 11, 1, 0, 0), _list, ""), "", "Halloween ends at midnight")
	eq(Holidays.on(_at(2026, 12, 23), _list, ""), "")
	for day in [24, 25, 26]:
		eq(Holidays.on(_at(2026, 12, day), _list, ""), "christmas", "the %dth" % day)
	eq(Holidays.on(_at(2026, 12, 27), _list, ""), "")


func test_easter_runs_good_friday_to_easter_monday() -> void:
	# Easter Sunday 2026 is the 5th of April.
	eq(Holidays.on(_at(2026, 4, 2), _list, ""), "")
	eq(Holidays.on(_at(2026, 4, 3), _list, ""), "easter")
	eq(Holidays.on(_at(2026, 4, 6, 23, 59), _list, ""), "easter")
	eq(Holidays.on(_at(2026, 4, 7), _list, ""), "")
	# Over a month end: Easter 2024 is the 31st of March.
	eq(Holidays.on(_at(2024, 4, 1), _list, ""), "easter")
	eq(Holidays.on(_at(2024, 3, 29), _list, ""), "easter")


func test_new_year_is_five_minutes() -> void:
	eq(Holidays.on(_at(2026, 12, 31, 23, 59), _list, ""), "")
	eq(Holidays.on(_at(2027, 1, 1, 0, 0), _list, ""), "new_year")
	eq(Holidays.on(_at(2027, 1, 1, 0, 5), _list, ""), "new_year")
	eq(Holidays.on(_at(2027, 1, 1, 0, 6), _list, ""), "")


func test_birthday() -> void:
	eq(Holidays.on(_at(2026, 6, 14), _list, "2001-06-14"), "birthday")
	eq(Holidays.on(_at(2026, 6, 15), _list, "2001-06-14"), "")
	eq(Holidays.on(_at(2026, 6, 14), _list, ""), "", "no date of birth, no birthday")
	eq(Holidays.on(_at(2026, 6, 14), _list, "not a date"), "")
	eq(Holidays.on(_at(2026, 10, 31), _list, "2001-10-31"), "birthday", "your birthday beats Halloween")
	eq(Holidays.on(_at(2027, 2, 28), _list, "2004-02-29"), "birthday", "leap day birthdays move to the 28th")
	eq(Holidays.on(_at(2028, 2, 28), _list, "2004-02-29"), "", "but not in a leap year")
	eq(Holidays.on(_at(2028, 2, 29), _list, "2004-02-29"), "birthday")



func test_birthday_beats_every_holiday() -> void:
	eq(Holidays.on(_at(2026, 12, 25), _list, "2001-12-25"), "birthday", "your birthday beats Christmas")
	eq(Holidays.on(_at(2027, 1, 1, 0, 2), _list, "2001-01-01"), "birthday", "and New Year")
	eq(Holidays.on(_at(2026, 4, 5), _list, "2001-04-05"), "birthday", "and Easter")
	# ...but Christmas is still on, for its present and its pet.
	eq(Holidays.all_on(_at(2026, 12, 25), _list, "2001-12-25"), ["birthday", "christmas"] as Array[String])
	eq(Holidays.all_on(_at(2026, 12, 25), _list, ""), ["christmas"] as Array[String])
	eq(Holidays.all_on(_at(2026, 6, 1), _list, ""), [] as Array[String])


## A span can run over New Year, in either direction.
func test_spans_over_new_year() -> void:
	var list := [{"id": "winter", "from": "12-30", "to": "01-02"}]
	eq(Holidays.on(_at(2026, 12, 31), list, ""), "winter")
	eq(Holidays.on(_at(2027, 1, 2, 23, 0), list, ""), "winter")
	eq(Holidays.on(_at(2027, 1, 3), list, ""), "")
	eq(Holidays.on(_at(2026, 12, 29), list, ""), "")


func test_best_seconds_counts_one_years_run() -> void:
	var xmas: Dictionary = _list.filter(func(h): return h["id"] == "christmas")[0]
	var days := {}
	var day := func(y: int, m: int, d: int, seconds: int):
		var unix := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12})
		days[Stats.local_day(unix, 0)] = {"projects": {"p": seconds}, "pets": {}, "places": {}}
	day.call(2025, 12, 24, 600)
	day.call(2025, 12, 26, 900)
	day.call(2025, 12, 27, 5000)  # after Christmas
	day.call(2026, 12, 25, 1200)
	eq(Holidays.best_seconds(xmas, days, ""), 1500, "Christmas 2025 adds up, other days don't count")


func test_holiday_unlock_rule() -> void:
	var rule := {"holiday": "halloween", "minutes": 30}
	eq(Unlocks.kind_of(rule), "holiday")
	var facts := {"level": 1, "total_seconds": 0, "place_seconds": {}, "found": {}, "holiday_seconds": {"halloween": 1200}}
	var p := Unlocks.progress(rule, facts, [])
	check(not p["done"], "20 minutes isn't enough")
	eq([p["have"], p["goal"]], [1200, 1800])
	facts["holiday_seconds"]["halloween"] = 1800
	check(Unlocks.progress(rule, facts, [])["done"], "half an hour is")
	eq(Unlocks.describe(rule), "Focus for 30 minutes on Halloween")


## Every holiday's present and pet is real, and each has a look.
func test_holiday_data_is_real() -> void:
	var gifts := {}
	for g in load_json("res://data/gifts.json")["gifts"]:
		gifts[g["id"]] = g
	for h in _list:
		check(Holidays.look(h["id"]) != null, "%s has a look" % h["id"])
		if h.has("gift"):
			check(gifts.has(h["gift"]), "%s's present %s" % [h["id"], h["gift"]])
			eq(gifts.get(h["gift"], {}).get("rarity", ""), "legendary", "%s's present is legendary" % h["id"])
			check(Text.lookup("holiday.present." + h["id"]) is String, "%s says happy holiday" % h["id"])
	for a in load_json("res://data/animals.json")["animals"]:
		var rule: Dictionary = a.get("unlock", {})
		if rule.has("holiday"):
			check(_list.any(func(h): return h["id"] == rule["holiday"]), "%s's holiday" % a["id"])
			eq(load_json("res://data/gifts.json")["gifts"].filter(func(g): return g["table"] == a["table"]).size(), 4, "%s has 4 gifts" % a["id"])


## Holiday gifts come once a year, so the Moon doesn't wait on them.
func test_finding_every_gift_leaves_out_holidays() -> void:
	var gifts := [{"id": "dog_a", "table": "dog"}, {"id": "pumpkin_head", "table": "holiday"}]
	var p := Unlocks.progress({"all_tables": true}, {"found": {"dog_a": true}}, gifts)
	check(p["done"], "the dog gift is all it takes")
	eq(p["goal"], 1)


## On a holiday the home screen greets you with that holiday's lines.
func test_holiday_greetings() -> void:
	var rng := RandomNumberGenerator.new()
	for h in _list:
		var lines := Text.list("greetings.holidays." + h["id"])
		check(not lines.is_empty(), "%s has greetings" % h["id"])
		var named: Array = lines.map(func(l): return Text.fill(str(l), {"name": "Sam"}))
		for i in 20:
			rng.seed = i
			var line := Content.greeting(12, "Sam", rng, h["id"])
			check(line in named, "%s: %s" % [h["id"], line])
			rng.seed = i
			check(not Content.greeting(12, "", rng, h["id"]).contains("{name}"), "no name, no {name}")
	rng.seed = 1
	check(Content.greeting(12, "Sam", rng, "") != "", "ordinary days still greet")
