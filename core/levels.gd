class_name Levels
extends RefCounted
## XP and levels, from data/levels.json. Each walk earns XP for its minutes
## focused plus a bonus for its gift, added to the saved total; your level is
## worked out from that total each time, so the thresholds can change freely.


## XP for one walk of `seconds` that brought a gift of `rarity` ("" for none).
static func walk_xp(seconds: int, rarity: String, table: Dictionary) -> int:
	@warning_ignore("integer_division")
	var xp := (seconds / 60) * int(table.get("xp_per_minute", 1))
	return xp + int(table.get("gift_bonus", {}).get(rarity, 0))


## Total XP needed to reach `level` (level 1 needs none).
static func xp_to_reach(level: int, table: Dictionary) -> int:
	var base := int(table.get("xp_base", 60))
	var growth := int(table.get("xp_growth", 20))
	var n := maxi(0, level - 1)
	# Sum of base + growth * k for k = 0 .. n - 1.
	@warning_ignore("integer_division")
	return n * base + growth * n * (n - 1) / 2


static func level_for(xp: int, table: Dictionary) -> int:
	var level := 1
	while xp >= xp_to_reach(level + 1, table):
		level += 1
	return level


## Where `xp` sits: {level, into: XP into this level, needed: XP the level takes}.
static func progress(xp: int, table: Dictionary) -> Dictionary:
	var level := level_for(xp, table)
	var start := xp_to_reach(level, table)
	return {"level": level, "into": xp - start, "needed": xp_to_reach(level + 1, table) - start}
