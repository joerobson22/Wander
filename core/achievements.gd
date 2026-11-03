class_name Achievements
extends RefCounted
## The profile's achievements: total hours focused (10 up to 10,000), every
## gift found, and every gift in each gift table. What they are and what
## they're called is in data/achievements.json; whether you have one is
## worked out from your focus time and the gifts you've found, never stored.


## Every achievement in order: {id, name, description, kind ("hours",
## "all_gifts" or "table"), goal (hours, or gifts to find), icon, table, and
## animal (the one shown for a table)}.
static func list(data: Dictionary, tables: Array, gifts: Array) -> Array:
	var out := []
	for f in data.get("focus", []):
		var hours := int(f["hours"])
		out.append({"id": f["id"], "name": f["name"], "kind": "hours", "goal": hours, "icon": "clock", "table": "", "animal": "",
			"description": Text.t("achievements.hours_description", {"hours": grouped(hours)})})
	var all: Dictionary = data.get("all_gifts", {})
	out.append({"id": all.get("id", "all_gifts"), "name": all.get("name", Text.t("achievements.all_gifts_name")), "kind": "all_gifts",
		"goal": gifts.size(), "icon": "gift", "table": "", "animal": "", "description": Text.t("achievements.all_gifts_description")})
	var each: Dictionary = data.get("table_gifts", {})
	for t in tables:
		var count := gifts.filter(func(g): return g["table"] == t["id"]).size()
		if count == 0:
			continue
		out.append({"id": "table_%s" % t["id"], "name": Text.fill(str(each.get("name", Text.t("achievements.table_name"))), {"table": t["name"]}),
			"kind": "table", "goal": count, "icon": str(t.get("icon", "")), "table": t["id"], "animal": str(t.get("animal", "")),
			"description": Text.t("achievements.table_description", {"count": count, "table": str(t["name"]).to_lower()})})
	return out


## How far along each one is: the list again with "have" (whole hours, or
## gifts found, never more than the goal) and "earned" added. `found` is
## every gift id you've ever had.
static func progress(achievements: Array, focused_seconds: int, found: Array, gifts: Array) -> Array:
	var seen := {}
	for id in found:
		seen[id] = true
	var out := []
	for a in achievements:
		var have := 0
		match str(a["kind"]):
			"hours":
				have = floori(focused_seconds / 3600.0)
			"all_gifts":
				have = gifts.filter(func(g): return seen.has(g["id"])).size()
			"table":
				have = gifts.filter(func(g): return g["table"] == a["table"] and seen.has(g["id"])).size()
		var row: Dictionary = a.duplicate()
		row["have"] = mini(have, int(a["goal"]))
		row["earned"] = int(a["goal"]) > 0 and have >= int(a["goal"])
		out.append(row)
	return out


## The order to show them in where there's only room for some (the
## profile): the ones you've earned first, hardest won first (the full
## collection, then the most hours, then each table's set), then the ones
## you're closest to, by how much of the way there you are. Takes rows from
## progress().
static func showcase(rows: Array) -> Array:
	var effort := func(r: Dictionary) -> float:
		match str(r["kind"]):
			"all_gifts":
				return 1e9
			"hours":
				return 1e6 + float(r["goal"])
		return float(r["goal"])
	var earned := rows.filter(func(r): return r["earned"])
	var rest := rows.filter(func(r): return not r["earned"])
	earned.sort_custom(func(a, b): return effort.call(a) > effort.call(b))
	var share := func(r: Dictionary) -> float: return float(r["have"]) / maxf(1.0, float(r["goal"]))
	# Stable on ties, so equal shares keep the list's own order.
	var order := {}
	for i in rest.size():
		order[rest[i]["id"]] = i
	rest.sort_custom(func(a, b):
		var sa: float = share.call(a)
		var sb: float = share.call(b)
		return sa > sb if not is_equal_approx(sa, sb) else order[a["id"]] < order[b["id"]])
	return earned + rest


## 10000 as "10,000".
static func grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
