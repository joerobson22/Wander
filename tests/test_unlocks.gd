extends TestCase

const GIFTS := [
	{"id": "cat_a", "table": "cat"},
	{"id": "cat_b", "table": "cat"},
	{"id": "dog_a", "table": "dog"},
]


func _facts(more: Dictionary = {}) -> Dictionary:
	var out := {"level": 1, "total_seconds": 0, "place_seconds": {}, "found": {}}
	out.merge(more, true)
	return out


func test_from_the_start() -> void:
	var p := Unlocks.progress({}, _facts(), GIFTS)
	check(p["done"], "nothing to do")
	eq(p["kind"], "start")


func test_level() -> void:
	check(not Unlocks.progress({"level": 3}, _facts({"level": 2}), GIFTS)["done"])
	var p := Unlocks.progress({"level": 3}, _facts({"level": 3}), GIFTS)
	check(p["done"], "reached")
	eq([p["have"], p["goal"]], [3, 3])


func test_hours_in_a_place() -> void:
	var rule := {"hours": 10, "place": "jungle"}
	var some := _facts({"total_seconds": 50 * 3600, "place_seconds": {"jungle": 7 * 3600, "lake": 40 * 3600}})
	var p := Unlocks.progress(rule, some, GIFTS)
	check(not p["done"], "time elsewhere doesn't count")
	eq([p["have"], p["goal"]], [7 * 3600, 10 * 3600])
	check(Unlocks.progress(rule, _facts({"place_seconds": {"jungle": 10 * 3600}}), GIFTS)["done"], "exactly ten hours")
	eq(Unlocks.progress(rule, _facts({"place_seconds": {"jungle": 99 * 3600}}), GIFTS)["have"], 10 * 3600, "progress stops at the goal")


func test_hours_anywhere() -> void:
	check(Unlocks.progress({"hours": 2.5}, _facts({"total_seconds": 9000}), GIFTS)["done"], "two and a half hours")
	check(not Unlocks.progress({"hours": 2.5}, _facts({"total_seconds": 8999}), GIFTS)["done"])


func test_finishing_a_table() -> void:
	var rule := {"table": "cat"}
	var p := Unlocks.progress(rule, _facts({"found": {"cat_a": true, "dog_a": true}}), GIFTS)
	check(not p["done"], "one cat gift of two")
	eq([p["have"], p["goal"]], [1, 2])
	check(Unlocks.progress(rule, _facts({"found": {"cat_a": true, "cat_b": true}}), GIFTS)["done"], "every cat gift")


func test_every_table() -> void:
	var rule := {"all_tables": true}
	check(not Unlocks.progress(rule, _facts({"found": {"cat_a": true, "cat_b": true}}), GIFTS)["done"], "the dog's still missing")
	var p := Unlocks.progress(rule, _facts({"found": {"cat_a": true, "cat_b": true, "dog_a": true}}), GIFTS)
	check(p["done"], "everything")
	eq(p["goal"], 3)


func test_in_words() -> void:
	eq(Unlocks.describe({"level": 4}), "Reach level 4")
	eq(Unlocks.describe({"hours": 10, "place": "jungle"}), "Focus for 10 hours in the jungle")
	eq(Unlocks.describe({"hours": 2.5}), "Focus for 2.5 hours")
	eq(Unlocks.describe({"table": "red_panda"}), "Discover all red panda gifts")


func test_level_rewards_are_in_order() -> void:
	var rewards := Unlocks.level_rewards()
	var levels: Array = rewards.map(func(r): return int(r["level"]))
	var sorted := levels.duplicate()
	sorted.sort()
	eq(levels, sorted, "level order")
	var first := rewards.filter(func(r): return r["level"] == 1).map(func(r): return r["id"])
	eq(first, ["lake", "farm", "dog1", "cat1"], "lakeside, the farm, a dog and a cat to begin with")
	var others := Unlocks.other_rewards().map(func(r): return r["id"])
	check(others.has("moon") and others.has("gorilla") and others.has("lion"), "exploring rewards")
	eq(rewards.size() + others.size(), Content.animals.size() + Content.biomes.size(), "everything is one or the other")
