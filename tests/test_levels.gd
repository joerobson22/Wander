extends TestCase

var table: Dictionary


func _init() -> void:
	table = load_json("res://data/levels.json")


func test_thresholds_grow() -> void:
	eq(Levels.xp_to_reach(1, table), 0)
	eq(Levels.xp_to_reach(2, table), 60, "an hour of focus for level 2")
	eq(Levels.xp_to_reach(3, table), 140)
	eq(Levels.xp_to_reach(4, table), 240)
	for level in range(2, 30):
		check(Levels.xp_to_reach(level + 1, table) - Levels.xp_to_reach(level, table) > Levels.xp_to_reach(level, table) - Levels.xp_to_reach(level - 1, table), "level %d takes longer than the last" % level)


func test_level_and_progress() -> void:
	eq(Levels.level_for(0, table), 1)
	eq(Levels.level_for(59, table), 1)
	eq(Levels.level_for(60, table), 2)
	eq(Levels.progress(100, table), {"level": 2, "into": 40, "needed": 80})


func test_walk_xp_is_minutes_plus_gift_bonus() -> void:
	eq(Levels.walk_xp(25 * 60 + 59, "", table), 25)
	eq(Levels.walk_xp(25 * 60, "rare", table), 25 + int(table["gift_bonus"]["rare"]))
