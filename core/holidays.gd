class_name Holidays
extends RefCounted
## Days the app dresses up: Halloween, Christmas, New Year, Easter and your
## birthday (data/holidays.json says when; art/holidays/<id>/look.tres says
## how each looks). Everything here works from a date you pass in, so it can
## be tested; App.holiday() asks it about today.

const LOOK := "res://art/holidays/%s/look.tres"

static var _looks := {}


## The holiday on at `t` ({year, month, day, hour, minute}, local), from
## `list` (Content.holidays) in order, the first that matches; "" for none.
## `dob` is your date of birth, "YYYY-MM-DD" ("" for not given).
static func on(t: Dictionary, list: Array, dob: String) -> String:
	var all := all_on(t, list, dob)
	return all[0] if not all.is_empty() else ""


## Every holiday on at `t`, in `list`'s order: on your birthday at
## Christmas the app dresses for your birthday (the first), but both
## presents are given.
static func all_on(t: Dictionary, list: Array, dob: String) -> Array[String]:
	var out: Array[String] = []
	for h in list:
		if is_on(h, t, dob):
			out.append(str(h["id"]))
	return out


static func is_on(h: Dictionary, t: Dictionary, dob: String) -> bool:
	var year := int(t["year"])
	var now := _stamp(int(t["month"]), int(t["day"]), int(t.get("hour", 0)) * 60 + int(t.get("minute", 0)))
	var span := days_of(h, year, dob)
	if span.is_empty():
		return false
	return now >= span[0] and now <= span[1] if span[0] <= span[1] else now >= span[0] or now <= span[1]


## When a holiday runs in `year`, as [from, to] stamps (see _stamp), or []
## if it can't be worked out (a birthday with no date of birth).
static func days_of(h: Dictionary, year: int, dob: String) -> Array:
	if h.has("easter"):
		var sunday := easter(year)
		var run: Array = h["easter"]
		var first := _shift(year, sunday, int(run[0]))
		var last := _shift(year, sunday, int(run[1]))
		return [_stamp(first.x, first.y, 0), _stamp(last.x, last.y, 24 * 60 - 1)]
	if bool(h.get("birthday", false)):
		var md := birthday(dob)
		if md == Vector2i.ZERO:
			return []
		# Born on the 29th of February: the 28th in other years.
		if md == Vector2i(2, 29) and not _leap(year):
			md = Vector2i(2, 28)
		return [_stamp(md.x, md.y, 0), _stamp(md.x, md.y, 24 * 60 - 1)]
	return [_parse(str(h.get("from", "")), 0), _parse(str(h.get("to", h.get("from", ""))), 24 * 60 - 1)]


## Easter Sunday in `year`, as (month, day): the anonymous Gregorian method.
@warning_ignore_start("integer_division")
static func easter(year: int) -> Vector2i:
	var a := year % 19
	var b := year / 100
	var c := year % 100
	var d := b / 4
	var e := b % 4
	var f := (b + 8) / 25
	var g := (b - f + 1) / 3
	var h := (19 * a + b - d - g + 15) % 30
	var i := c / 4
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := (a + 11 * h + 22 * l) / 451
	var month := (h + l - 7 * m + 114) / 31
	var day := (h + l - 7 * m + 114) % 31 + 1
	return Vector2i(month, day)
@warning_ignore_restore("integer_division")


## Your birthday as (month, day) from "YYYY-MM-DD", or ZERO if it isn't one.
static func birthday(dob: String) -> Vector2i:
	var bits := dob.split("-")
	if bits.size() != 3 or not bits[1].is_valid_int() or not bits[2].is_valid_int():
		return Vector2i.ZERO
	var md := Vector2i(int(bits[1]), int(bits[2]))
	if md.x < 1 or md.x > 12 or md.y < 1 or md.y > 31:
		return Vector2i.ZERO
	return md


## The most focus time (seconds) in any one year's run of a holiday: what
## its pet's unlock rule counts. `days` is GameState.days (by local day).
static func best_seconds(h: Dictionary, days: Dictionary, dob: String) -> int:
	var by_year := {}
	for day in days:
		var t := Time.get_date_dict_from_unix_time(int(day) * Stats.SECONDS_PER_DAY)
		t["hour"] = 12
		if not is_on(h, t, dob):
			continue
		# A run over New Year counts as the year it started in.
		var year := int(t["year"])
		var span := days_of(h, year, dob)
		if span.size() == 2 and span[0] > span[1] and _stamp(int(t["month"]), int(t["day"]), 0) <= span[1]:
			year -= 1
		var total := 0
		for s in (days[day]["projects"] as Dictionary).values():
			total += int(s)
		by_year[year] = int(by_year.get(year, 0)) + total
	var best := 0
	for s in by_year.values():
		best = maxi(best, s)
	return best


## How a holiday looks (art/holidays/<id>/look.tres), or null if it has no look.
static func look(id: String) -> HolidayLook:
	if id == "":
		return null
	if not _looks.has(id):
		var path := LOOK % id
		_looks[id] = load(path) as HolidayLook if ResourceLoader.exists(path) else null
	return _looks[id]


## A moment in the year that sorts in time order: (month, day) and minutes.
static func _stamp(month: int, day: int, minute: int) -> int:
	return (month * 32 + day) * 1440 + minute


## "MM-DD" or "MM-DD HH:MM" as a stamp; a bare day takes `minute`.
static func _parse(text: String, minute: int) -> int:
	var parts := text.strip_edges().split(" ")
	var md := parts[0].split("-")
	if md.size() != 2:
		return -1
	if parts.size() > 1:
		var hm := parts[1].split(":")
		minute = int(hm[0]) * 60 + (int(hm[1]) if hm.size() > 1 else 0)
	return _stamp(int(md[0]), int(md[1]), minute)


## (month, day) `by` days on from `from` in `year`.
static func _shift(year: int, from: Vector2i, by: int) -> Vector2i:
	var unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": from.x, "day": from.y, "hour": 12})
	var t := Time.get_date_dict_from_unix_time(unix + by * Stats.SECONDS_PER_DAY)
	return Vector2i(int(t["month"]), int(t["day"]))


static func _leap(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
