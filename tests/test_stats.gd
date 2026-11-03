extends TestCase

# 2026-10-19 is a Monday.
const MONDAY := 1792368000


## Day totals as the save keeps them, from [day after MONDAY, seconds,
## project (default "p"), place (default "lake")] entries.
func _days(entries: Array) -> Dictionary:
	var s := GameState.new()
	var monday := Stats.local_day(MONDAY, 0)
	for e in entries:
		s.log_focus(monday + int(e[0]), e[2] if e.size() > 2 else "p", "pet", e[3] if e.size() > 3 else "lake", int(e[1]))
	return s.days


func test_monday_is_weekday_zero() -> void:
	var day := Stats.local_day(MONDAY, 0)
	eq(Stats.weekday(day), 0)
	eq(Stats.week_start(day + 6), day)


func test_local_day_respects_timezone() -> void:
	# 23:30 UTC Sunday is already Monday in UTC+1.
	var monday := Stats.local_day(MONDAY, 0)
	eq(Stats.local_day(MONDAY - 1800, 0), monday - 1, "UTC: Sunday")
	eq(Stats.local_day(MONDAY - 1800, 60), monday, "UTC+1: Monday")


func test_daily_totals() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var d := _days([[0, 600], [0, 300, "b"], [3, 900], [-1, 50]])
	eq(Stats.daily_totals(d, monday), [900, 0, 0, 900, 0, 0, 0] as Array[int])


func test_week_total() -> void:
	var d := _days([[0, 1000], [1, 500], [7, 2000]])
	eq(Stats.week_total(d, Stats.local_day(MONDAY, 0)), 1500)


func test_streak() -> void:
	var d := _days([[0, 900], [1, 900], [2, 100], [3, 700], [4, 650]])
	var today := Stats.local_day(MONDAY, 0) + 4
	eq(Stats.current_streak(d, today), 2, "short day breaks it")
	eq(Stats.current_streak(d, today + 1), 2, "an empty today doesn't break it yet")
	eq(Stats.current_streak(d, today + 2), 0)


func test_short_walks_on_one_day_add_up() -> void:
	var d := _days([[0, 300], [0, 300, "b"]])
	eq(Stats.current_streak(d, Stats.local_day(MONDAY, 0)), 1, "two five minute walks make a work day")


func test_rest_day_after_three_days() -> void:
	# Work Mon-Wed, rest Thu, work Fri.
	var d := _days([[0, 900], [1, 900], [2, 900], [4, 900]])
	var monday := Stats.local_day(MONDAY, 0)
	eq(Stats.current_streak(d, monday + 4), 4, "rest day forgiven, not counted")
	eq(Stats.current_streak(d, monday + 3), 3, "the rest day itself is still pending")
	check(Stats.rest_day_ready(d, monday + 2), "three days banks a rest day")
	check(not Stats.rest_day_ready(d, monday + 1), "two days doesn't")
	check(not Stats.rest_day_ready(d, monday + 4), "a rest day was just used")
	# Two missed days in a row break it.
	eq(Stats.current_streak(d, monday + 6), 0)


func test_rest_day_needs_three_days_before_it() -> void:
	# Work Mon, Tue, miss Wed, work Thu.
	var d := _days([[0, 900], [1, 900], [3, 900]])
	eq(Stats.current_streak(d, Stats.local_day(MONDAY, 0) + 3), 1)


func test_rest_day_yesterday_keeps_streak_alive_today() -> void:
	var d := _days([[0, 900], [1, 900], [2, 900]])
	# Thursday missed, Friday not over yet.
	eq(Stats.current_streak(d, Stats.local_day(MONDAY, 0) + 4), 3)


func test_totals_by_project_pet_and_place() -> void:
	var s := GameState.new()
	s.log_focus(10, "a", "dog", "lake", 10)
	s.log_focus(10, "b", "cat", "jungle", 5)
	s.log_focus(11, "a", "cat", "jungle", 7)
	s.log_focus(11, "a", "dog", "jungle", 0)
	eq(s.project_seconds("a"), 17)
	eq(s.project_seconds("b"), 5)
	eq(s.pet_seconds("dog"), 10)
	eq(s.pet_seconds("cat"), 12)
	eq(s.total_seconds(), 22)
	eq(s.place_seconds(), {"lake": 10, "jungle": 12})
	eq(s.days.size(), 2, "nothing logged for a zero-length walk")


func test_walk_split_over_midnight() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	eq(Stats.split_by_day(MONDAY + 3600, 1800, 0), [[monday, 1800]], "all in one day")
	eq(Stats.split_by_day(MONDAY - 600, 1800, 0), [[monday - 1, 600], [monday, 1200]], "over midnight")
	eq(Stats.split_by_day(MONDAY - 600, 1800, 60), [[monday, 1800]], "UTC+1: already Monday")
	var long := Stats.split_by_day(MONDAY + 12 * 3600, 30 * 3600, 0)
	eq(long, [[monday, 12 * 3600], [monday + 1, 18 * 3600]], "a 30 hour walk")
	eq(Stats.split_by_day(MONDAY, 0, 0), [], "nothing to share")


func test_format_long() -> void:
	eq(Stats.format_long(0), "0m")
	eq(Stats.format_long(40 * 60), "40m")
	eq(Stats.format_long(312 * 3600 + 40 * 60), "1wk 6d 40m", "13 days, no hours")
	eq(Stats.format_long(31 * 86400 + 3600), "1mo 1d 1h")
	eq(Stats.format_long(400 * 86400), "1yr 1mo 5d")


func test_format_duration() -> void:
	eq(Stats.format_duration(59), "0m")
	eq(Stats.format_duration(3600 * 11 + 23 * 60), "11h 23m")


func test_ranked_puts_the_most_first_and_drops_zeros() -> void:
	eq(Stats.ranked({"a": 5, "b": 20, "c": 0, "d": 5}), [["b", 20], ["a", 5], ["d", 5]])
	eq(Stats.ranked({}), [])


func test_periods_start_on_their_first_day() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var d := Stats.day_date(Stats.month_start(monday + 3))
	eq([d["year"], d["month"], d["day"]], [2026, 10, 1])
	d = Stats.day_date(Stats.year_start(monday))
	eq([d["year"], d["month"], d["day"]], [2026, 1, 1])
	eq(Stats.period_start(monday + 3, "week"), monday)
	d = Stats.day_date(Stats.period_next(Stats.month_start(monday), "month"))
	eq([d["month"], d["day"]], [11, 1])
	d = Stats.day_date(Stats.period_next(Stats.date_day(2026, 12, 1), "month"))
	eq([d["year"], d["month"]], [2027, 1], "December rolls into January")
	d = Stats.day_date(Stats.period_before(Stats.date_day(2026, 1, 1), "month"))
	eq([d["year"], d["month"]], [2025, 12])


func test_period_buckets() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var days := _days([[0, 600, "a"], [2, 300, "b"], [-30, 100, "a"]])
	var month := Stats.period_buckets(days, Stats.month_start(monday), "month")
	eq(month.size(), 31, "October has 31 days")
	eq(month[18], {"a": 600}, "the 19th")
	eq(month[20], {"b": 300})
	var year := Stats.period_buckets(days, Stats.year_start(monday), "year")
	eq(year.size(), 12)
	eq(year[9], {"a": 600, "b": 300}, "October's bar")
	eq(year[8], {"a": 100}, "September's bar")
	eq(Stats.period_totals(days, Stats.year_start(monday), "year"), {"a": 700, "b": 300})
	eq(Stats.period_buckets(days, monday, "week", "pets")[0], {"pet": 600})
	eq(Stats.period_total(days, Stats.month_start(monday), "month"), 900)


func test_period_history_counts_back() -> void:
	var monday := Stats.local_day(MONDAY, 0)
	var days := _days([[0, 600], [-62, 100]])
	var months := Stats.period_history(days, monday, "month")
	eq(months.size(), 3, "October back to August")
	eq(months[0], Stats.month_start(monday))
	var d := Stats.day_date(months[2])
	eq([d["month"], d["day"]], [8, 1])
	eq(Stats.period_history(days, monday, "year").size(), 1)
