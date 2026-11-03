class_name Stats
extends RefCounted
## Stats worked out from the focus time saved per day (GameState.days). Days
## are local calendar days, numbered by local_day(); weeks start on Monday.
## `bias_minutes` is the local UTC offset in minutes
## (Time.get_time_zone_from_system().bias), passed in so tests are deterministic.

const SECONDS_PER_DAY := 86400
## A day counts towards a streak with at least this much focus.
const STREAK_MIN_SECONDS := 600
## This many work days in a row earn one rest day: missing the next day
## doesn't break the streak.
const REST_DAY_AFTER := 3


static func local_day(unix: int, bias_minutes: int) -> int:
	return floori(float(unix + bias_minutes * 60) / SECONDS_PER_DAY)


## A walk's focus time shared out over the local days it fell on, from its
## start, as [[day, seconds], ...]. Pauses are taken as at the end, so a walk
## over midnight counts the right time each side unless it paused a lot.
static func split_by_day(start_unix: int, seconds: int, bias_minutes: int) -> Array:
	var out: Array = []
	var at := start_unix
	var left := seconds
	while left > 0:
		var day := local_day(at, bias_minutes)
		var midnight := (day + 1) * SECONDS_PER_DAY - bias_minutes * 60
		var part := mini(left, midnight - at)
		out.append([day, part])
		left -= part
		at += part
	return out


## 0 = Monday ... 6 = Sunday. Day 0 (1970-01-01) was a Thursday.
static func weekday(day: int) -> int:
	return posmod(day + 3, 7)


static func week_start(day: int) -> int:
	return day - weekday(day)


## Focus per day of the week beginning `week_start_day`, Monday first.
static func daily_totals(days: Dictionary, week_start_day: int) -> Array[int]:
	var totals: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for i in 7:
		totals[i] = _day_total(days, week_start_day + i)
	return totals


static func week_total(days: Dictionary, week_start_day: int) -> int:
	var total := 0
	for t in daily_totals(days, week_start_day):
		total += t
	return total


# --- Weeks, months and years ------------------------------------------------
# A period is "week", "month" or "year", named by its first day. A week's
# bars are its days, a month's its days too, and a year's its months.

## {year, month, day} for a local day number.
static func day_date(day: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(day * SECONDS_PER_DAY)


## The local day number of a date. Months past 12 roll into the next year.
static func date_day(year: int, month: int, day: int) -> int:
	year += floori((month - 1) / 12.0)
	month = posmod(month - 1, 12) + 1
	@warning_ignore("integer_division")
	return int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day})) / SECONDS_PER_DAY


static func month_start(day: int) -> int:
	var d := day_date(day)
	return date_day(d["year"], d["month"], 1)


static func year_start(day: int) -> int:
	return date_day(day_date(day)["year"], 1, 1)


## The first day of the period `day` falls in.
static func period_start(day: int, period: String) -> int:
	match period:
		"month":
			return month_start(day)
		"year":
			return year_start(day)
		_:
			return week_start(day)


## The first day of the period after the one starting on `start`.
static func period_next(start: int, period: String) -> int:
	var d := day_date(start)
	match period:
		"month":
			return date_day(d["year"], d["month"] + 1, 1)
		"year":
			return date_day(d["year"] + 1, 1, 1)
		_:
			return start + 7


## The first day of the period before the one starting on `start`.
static func period_before(start: int, period: String) -> int:
	return period_start(start - 1, period)


## The period's bars: one {id: seconds} per day (week, month) or per month
## (year), from the days' `part` ("projects", "pets" or "places").
static func period_buckets(days: Dictionary, start: int, period: String, part: String = "projects") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var end := period_next(start, period)
	if period == "year":
		for i in 12:
			out.append({})
	else:
		for i in end - start:
			out.append({})
	for day in days:
		var d := int(day)
		if d < start or d >= end:
			continue
		var i: int = int(day_date(d)["month"]) - 1 if period == "year" else d - start
		var totals: Dictionary = days[day].get(part, {})
		for id in totals:
			out[i][id] = int(out[i].get(id, 0)) + int(totals[id])
	return out


## {id: seconds} over the whole period.
static func period_totals(days: Dictionary, start: int, period: String, part: String = "projects") -> Dictionary:
	var out := {}
	for bucket in period_buckets(days, start, period, part):
		for id in bucket:
			out[id] = int(out.get(id, 0)) + int(bucket[id])
	return out


static func period_total(days: Dictionary, start: int, period: String) -> int:
	var total := 0
	for s in period_totals(days, start, period).values():
		total += int(s)
	return total


## {period start: seconds} for every period with any focus.
static func period_sums(days: Dictionary, period: String) -> Dictionary:
	var out := {}
	for day in days:
		var start := period_start(int(day), period)
		out[start] = int(out.get(start, 0)) + _day_total(days, int(day))
	return out


## Period starts from the current one back to the first with any focus (or
## `since_day`'s, whichever is earlier), newest first, at most `limit`.
static func period_history(days: Dictionary, today: int, period: String, since_day: int = 0) -> Array[int]:
	var first := period_start(today, period)
	for start in period_sums(days, period):
		first = mini(first, start)
	if since_day > 0:
		first = mini(first, period_start(since_day, period))
	var out: Array[int] = []
	var start := period_start(today, period)
	while start >= first and out.size() < 104:
		out.append(start)
		start = period_before(start, period)
	return out


## Days with at least `min_seconds` of focus, as a set {day: true}.
static func work_days(days: Dictionary, min_seconds: int = STREAK_MIN_SECONDS) -> Dictionary:
	var out := {}
	for day in days:
		if _day_total(days, int(day)) >= min_seconds:
			out[int(day)] = true
	return out


static func _day_total(days: Dictionary, day: int) -> int:
	var total := 0
	for s in days.get(day, {}).get("projects", {}).values():
		total += int(s)
	return total


## Work days in the streak ending today. A day with nothing yet doesn't break
## it until it's over, and one missed day is forgiven (a rest day) when the
## REST_DAY_AFTER days before it were all work days. Rest days don't add to
## the count.
static func current_streak(days: Dictionary, today: int) -> int:
	var work := work_days(days)
	var day := today if work.has(today) else today - 1
	var streak := 0
	while true:
		if work.has(day):
			streak += 1
		elif _run_ending(work, day - 1) < REST_DAY_AFTER:
			break
		day -= 1
	return streak


## True when a rest day is banked: the run of work days ending today (or
## yesterday, if today has nothing yet) is long enough to forgive a miss.
static func rest_day_ready(days: Dictionary, today: int) -> bool:
	var work := work_days(days)
	var day := today if work.has(today) else today - 1
	return _run_ending(work, day) >= REST_DAY_AFTER


## Consecutive work days ending on `day` (counting back), up to REST_DAY_AFTER.
static func _run_ending(work: Dictionary, day: int) -> int:
	var run := 0
	while run < REST_DAY_AFTER and work.has(day - run):
		run += 1
	return run


## {id: seconds} as [[id, seconds], ...], most first (ties by id, so the
## order never flickers), leaving out anything at zero.
static func ranked(totals: Dictionary) -> Array:
	var out: Array = []
	for id in totals:
		if int(totals[id]) > 0:
			out.append([str(id), int(totals[id])])
	out.sort_custom(func(a, b): return a[1] > b[1] if a[1] != b[1] else a[0] < b[0])
	return out


## Longer stretches in the biggest units that fit, leaving out any at
## zero: "1yr 2mo 3d 4h", "1wk 6d 40m", "0m" for nothing. A month is 30
## days and a year 365.
const LONG_UNITS := [["years", 365 * 86400], ["months", 30 * 86400], ["weeks", 7 * 86400], ["days", 86400], ["hours", 3600], ["minutes", 60]]


static func format_long(seconds: int) -> String:
	var parts: Array[String] = []
	var left := maxi(0, seconds)
	for unit in LONG_UNITS:
		@warning_ignore("integer_division")
		var n: int = left / int(unit[1])
		left -= n * int(unit[1])
		if n > 0:
			parts.append(Text.t("dates.long." + str(unit[0]), {"n": n}))
	return " ".join(parts) if not parts.is_empty() else Text.t("dates.long.minutes", {"n": 0})


static func format_duration(seconds: int) -> String:
	@warning_ignore("integer_division")
	var h := seconds / 3600
	@warning_ignore("integer_division")
	var m := (seconds / 60) % 60
	if h > 0:
		return Text.t("dates.hours_minutes", {"h": h, "m": "%02d" % m})
	return Text.t("dates.minutes", {"m": m})


## "3 Jan 2026" for a unix time, in local time.
static func format_date(unix: int, bias_minutes: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix + bias_minutes * 60)
	return Text.t("dates.date", {"day": d["day"], "month": Text.list("dates.months")[int(d["month"]) - 1], "year": d["year"]})


## "13 Oct" for a local day number.
static func format_day(day: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day * SECONDS_PER_DAY)
	return Text.t("dates.day", {"day": d["day"], "month": Text.list("dates.months")[int(d["month"]) - 1]})
