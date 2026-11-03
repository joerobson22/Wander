class_name Collection
extends RefCounted
## How the gift collection's coming along, for the rings on the gifts
## screen: gifts discovered, gift tables you've found every gift in,
## and the cosmetics that come from gifts (the starter clothes are everyone's
## from the start). Worked out from the inventory, never stored.


## {found, gifts}: gifts you've ever had, out of every gift.
## {tables, total_tables}: gift tables with every one of their gifts found,
## out of every table that has gifts.
## {cosmetics, wearables}: wearable gifts you have right now (trading the
## last one away takes it out of your wardrobe), out of every wearable gift.
static func progress(inventory: Dictionary, gifts: Array) -> Dictionary:
	var found := 0
	var wearing := 0
	var wearables := 0
	var complete := {}  # table id -> every gift found so far
	for g in gifts:
		var seen := inventory.has(g["id"])
		if seen:
			found += 1
		complete[g["table"]] = bool(complete.get(g["table"], true)) and seen
		if g.has("slot"):
			wearables += 1
			if int(inventory.get(g["id"], 0)) > 0:
				wearing += 1
	var tables := 0
	for id in complete:
		if complete[id]:
			tables += 1
	return {"found": found, "gifts": gifts.size(), "tables": tables, "total_tables": complete.size(),
		"cosmetics": wearing, "wearables": wearables}


## The ways a collection of gifts can be sorted, as [id, label] for a Dropdown.
static func sorts() -> Array:
	return [["rarity", Text.t("sort.rarity")], ["name", Text.t("sort.a_to_z")], ["animal", Text.t("sort.pet_type")]]


## `ids` sorted `by` one of sorts(): rarity puts the rarest first (then A–Z);
## A–Z is by name; pet type follows the gift tables' order, commonest first
## within each. `reversed` flips the whole order.
static func sort_gifts(ids: Array, by: String, reversed: bool, gifts: Array, tables: Array) -> Array:
	var info := {}
	for g in gifts:
		info[g["id"]] = g
	var cast := {}
	for i in tables.size():
		cast[tables[i]["id"]] = i
	var key := func(id: String) -> Array:
		var g: Dictionary = info.get(id, {})
		var name := str(g.get("name", id)).to_lower()
		var rarity := GiftRoller.RARITIES.find(str(g.get("rarity", "common")))
		match by:
			"name":
				return [name]
			"animal":
				return [cast.get(g.get("table", ""), 99), rarity, name]
			_:
				return [-rarity, name]
	var out := ids.duplicate()
	out.sort_custom(func(a, b): return key.call(a) < key.call(b))
	if reversed:
		out.reverse()
	return out


## `have` out of `total` as 0..1, and 0 when there's nothing to have.
static func fraction(have: int, total: int) -> float:
	return clampf(float(have) / total, 0.0, 1.0) if total > 0 else 0.0
