extends TestCase

var data: Dictionary
var tables: Array
var gifts: Array
var list: Array


func _init() -> void:
	data = load_json("res://data/achievements.json")
	tables = load_json("res://data/gifts.json")["tables"]
	gifts = load_json("res://data/gifts.json")["gifts"]
	list = Achievements.list(data, tables, gifts)


func _row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if r["id"] == id:
			return r
	return {}


func test_the_list() -> void:
	var hours := list.filter(func(a): return a["kind"] == "hours").map(func(a): return a["goal"])
	eq(hours, [10, 50, 100, 500, 1000, 10000], "the focus milestones")
	eq(_row(list, "focus_10000")["description"], "Focus for 10,000 hours in total")
	eq(_row(list, "all_gifts")["goal"], gifts.size(), "every gift")
	var dogs := _row(list, "table_dog")
	eq(dogs["name"], "Dog set")
	eq(dogs["animal"], "dog1", "shown by the table's own animal")
	eq(dogs["goal"], gifts.filter(func(g): return g["table"] == "dog").size())
	var with_gifts := {}
	for g in gifts:
		with_gifts[g["table"]] = true
	eq(list.filter(func(a): return a["kind"] == "table").size(), with_gifts.size(), "one per table with gifts")


func test_hours() -> void:
	var rows := Achievements.progress(list, 49 * 3600 + 3599, [], gifts)
	check(_row(rows, "focus_10")["earned"], "10 hours done")
	check(not _row(rows, "focus_50")["earned"], "49h59m isn't 50 hours")
	eq(_row(rows, "focus_50")["have"], 49)
	eq(_row(rows, "focus_10")["have"], 10, "progress stops at the goal")
	check(_row(Achievements.progress(list, 50 * 3600, [], gifts), "focus_50")["earned"], "50 hours exactly")


func test_gift_sets() -> void:
	var dogs: Array = gifts.filter(func(g): return g["table"] == "dog").map(func(g): return g["id"])
	var rows := Achievements.progress(list, 0, dogs, gifts)
	check(_row(rows, "table_dog")["earned"], "every dog gift")
	check(not _row(rows, "table_bear")["earned"], "but no bear gifts")
	eq(_row(rows, "all_gifts")["have"], dogs.size())
	check(not _row(rows, "all_gifts")["earned"])
	var one_short := dogs.slice(1)
	check(not _row(Achievements.progress(list, 0, one_short, gifts), "table_dog")["earned"], "one missing")
	var everything: Array = gifts.map(func(g): return g["id"])
	check(_row(Achievements.progress(list, 0, everything, gifts), "all_gifts")["earned"], "the full collection")


func test_showcase_order() -> void:
	# 120 hours and every dog gift: 10, 50 and 100 hours, and the dog set.
	var dogs := gifts.filter(func(g): return g["table"] == "dog").map(func(g): return g["id"])
	var rows := Achievements.progress(list, 120 * 3600, dogs, gifts)
	var shown := Achievements.showcase(rows)
	eq(shown.slice(0, 4).map(func(r): return r["id"]), ["focus_100", "focus_50", "focus_10", "table_dog"], "earned first, hardest won first")
	eq(shown.size(), rows.size(), "every achievement is still there")
	# Then the closest: 120 of 500 hours is further along than anything else.
	eq(shown[4]["id"], "focus_500", "then the one you're closest to")
	var shares: Array = shown.slice(4).map(func(r): return float(r["have"]) / r["goal"])
	var sorted := shares.duplicate()
	sorted.sort()
	sorted.reverse()
	eq(shares, sorted, "the rest by how far along they are")
