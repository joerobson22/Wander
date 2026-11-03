class_name Unlocks
extends RefCounted
## What it takes to unlock each animal and place: the "unlock" rule on it in
## data/animals.json and data/biomes.json. Whether you have one is worked out
## from what you've done each time it's asked, never stored, so changing a
## rule changes it for everyone at once. A rule is one of:
##   {} (or none)                     from the start
##   {"level": 3}                     reach level 3
##   {"hours": 20}                    focus for 20 hours in all
##   {"hours": 10, "place": "jungle"} focus for 10 hours in the Jungle
##   {"table": "cat"}                 find every gift in the cat table
##   {"all_tables": true}             find every gift there is (bar the holidays')
##   {"holiday": "easter", "minutes": 30}  focus for 30 minutes over one Easter
## `facts` is what's been done so far: {level, total_seconds,
## place_seconds: {place id: seconds}, found: {gift id: true},
## holiday_seconds: {holiday id: the most focused over one year's run of it}}.


## How far along a rule is: {kind ("start", "level", "hours", "table",
## "all_tables" or "holiday"), have, goal, done}. Hours and minutes count in
## seconds.
static func progress(rule: Dictionary, facts: Dictionary, gifts: Array) -> Dictionary:
	var kind := kind_of(rule)
	var have := 0
	var goal := 0
	match kind:
		"level":
			have = int(facts.get("level", 1))
			goal = int(rule["level"])
		"hours":
			goal = roundi(float(rule["hours"]) * 3600.0)
			if rule.has("place"):
				have = int(facts.get("place_seconds", {}).get(str(rule["place"]), 0))
			else:
				have = int(facts.get("total_seconds", 0))
		"holiday":
			goal = int(rule.get("minutes", 30)) * 60
			have = int(facts.get("holiday_seconds", {}).get(str(rule["holiday"]), 0))
		"table", "all_tables":
			var found: Dictionary = facts.get("found", {})
			for g in gifts:
				# Holiday gifts only come once a year, so finding every gift
				# leaves them out.
				if kind == "all_tables" and Content.table(g["table"]).has("holiday"):
					continue
				if kind == "all_tables" or g["table"] == str(rule["table"]):
					goal += 1
					if found.has(g["id"]):
						have += 1
	var done := kind == "start" or (goal > 0 and have >= goal)
	return {"kind": kind, "have": mini(have, goal) if goal > 0 else have, "goal": goal, "done": done}


static func kind_of(rule: Dictionary) -> String:
	if rule.has("holiday"):
		return "holiday"
	if rule.has("level"):
		return "level"
	if rule.has("hours"):
		return "hours"
	if rule.has("table"):
		return "table"
	if bool(rule.get("all_tables", false)):
		return "all_tables"
	return "start"


## The rule in words: "Reach level 3", "Focus for 10 hours in the jungle".
static func describe(rule: Dictionary) -> String:
	match kind_of(rule):
		"level":
			return Text.t("unlock.level", {"level": int(rule["level"])})
		"hours":
			var hours := _hours(float(rule["hours"]))
			if rule.has("place"):
				return Text.t("unlock.hours_in", {"hours": hours, "where": Content.biome(str(rule["place"])).get("where", "")})
			return Text.t("unlock.hours", {"hours": hours})
		"table":
			return Text.t("unlock.table", {"table": str(Content.table(str(rule["table"])).get("name", rule["table"])).to_lower()})
		"all_tables":
			return Text.t("unlock.all_tables")
		"holiday":
			return Text.t("unlock.holiday", {"minutes": int(rule.get("minutes", 30)), "when": Content.holiday(str(rule["holiday"])).get("when", "")})
	return Text.t("unlock.start")


## The level a rule unlocks at, or 0 if it isn't a level rule (1 for from
## the start), for laying out the level rewards.
static func level_of(rule: Dictionary) -> int:
	match kind_of(rule):
		"start":
			return 1
		"level":
			return int(rule["level"])
	return 0


## "10" for 10.0 hours, "2.5" for 2.5.
static func _hours(h: float) -> String:
	return str(int(h)) if is_equal_approx(h, roundf(h)) else str(snappedf(h, 0.1))


## Everything unlocked by a level (or there from the start, as level 1), in
## level order, places before animals within a level: [{level, type, id}].
static func level_rewards() -> Array:
	var out: Array = []
	for type in ["place", "animal"]:
		for thing in Content.biomes if type == "place" else Content.animals:
			var level := level_of(Content.unlock_rule(type, thing["id"]))
			if level > 0:
				out.append({"level": level, "type": type, "id": thing["id"]})
	# Stable on ties, so each level keeps the data files' order.
	var order := {}
	for i in out.size():
		order[out[i]["type"] + ":" + out[i]["id"]] = i
	out.sort_custom(func(x, y): return x["level"] < y["level"] if x["level"] != y["level"] else order[x["type"] + ":" + x["id"]] < order[y["type"] + ":" + y["id"]])
	return out


## Everything unlocked some other way (hours somewhere, finding gifts), places
## first, in the data files' order: [{type, id}].
static func other_rewards() -> Array:
	var out: Array = []
	for type in ["place", "animal"]:
		for thing in Content.biomes if type == "place" else Content.animals:
			if level_of(Content.unlock_rule(type, thing["id"])) == 0:
				out.append({"type": type, "id": thing["id"]})
	return out
