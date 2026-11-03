class_name GiftRoller
extends RefCounted
## Rolls the end-of-walk gift from the data-driven drop table (data/drop_table.json),
## and trades gifts up a rarity.

const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]


## The odds for a walk of this length, or an empty Dictionary if it earns
## no gift. Between two tiers they blend from one to the next, so they grow
## steadily as the walk goes on; a rarity the earlier tier doesn't have
## stays out until the tier that brings it in (legendary from 45 minutes).
static func weights_for(seconds: int, table: Dictionary) -> Dictionary:
	if seconds < int(table.get("min_seconds", 600)):
		return {}
	var below: Dictionary = {}
	var above: Dictionary = {}
	for tier in table.get("tiers", []):
		if seconds >= int(tier["min_seconds"]):
			below = tier
		else:
			above = tier
			break
	if below.is_empty():
		return {}
	if above.is_empty():
		return below["weights"]
	var f := float(seconds - int(below["min_seconds"])) / float(int(above["min_seconds"]) - int(below["min_seconds"]))
	var out := {}
	for r in RARITIES:
		var from := float(below["weights"].get(r, 0))
		out[r] = 0.0 if from <= 0.0 else lerpf(from, float(above["weights"].get(r, 0)), f)
	return out


## The lowest rarity a walk this long is sure to bring, or "" for no gift.
static func min_rarity(seconds: int, table: Dictionary) -> String:
	if seconds < int(table.get("min_seconds", 600)):
		return ""
	var floor_rarity := "common"
	var guaranteed: Dictionary = table.get("guaranteed", {})
	for r in RARITIES:
		if guaranteed.has(r) and seconds >= int(guaranteed[r]):
			floor_rarity = r
	return floor_rarity


## How far the walk is towards guaranteeing each rarity (0..1), measured from
## the first gift. Drives the circles filling the walk screen's gift button.
static func fill(seconds: int, table: Dictionary) -> Dictionary:
	var start := int(table.get("min_seconds", 600))
	var guaranteed: Dictionary = table.get("guaranteed", {})
	var out := {}
	for r in RARITIES:
		if guaranteed.has(r):
			var at := int(guaranteed[r])
			out[r] = clampf(float(seconds - start) / maxf(1.0, at - start), 0.0, 1.0)
	return out


## The chance of each rarity (0..1, adding up to 1), with rarities below
## the guaranteed one at 0; all 0 before the walk earns a gift. The gift
## button draws these as its pie.
static func chances(seconds: int, table: Dictionary) -> Dictionary:
	var w := weights_for(seconds, table)
	var allowed := _from(min_rarity(seconds, table))
	var out := {}
	var total := 0.0
	for r in allowed:
		total += float(w.get(r, 0))
	for r in RARITIES:
		out[r] = 0.0 if total <= 0.0 or not allowed.has(r) else float(w.get(r, 0)) / total
	return out


static func is_pity_ready(seconds: int, walks_since_epic: int, table: Dictionary) -> bool:
	return seconds >= int(table.get("pity_min_seconds", 1800)) \
		and walks_since_epic >= int(table.get("pity_walks", 8))


## Returns {"rarity", "gift_id", "pity"} or an empty Dictionary when no gift is earned.
## The gift comes from `gift_table` (the walking animal's, Content.table_of);
## `gifts` is the list of gift dictionaries from data/gifts.json.
static func roll(seconds: int, gift_table: String, walks_since_epic: int, table: Dictionary,
		gifts: Array, rng: RandomNumberGenerator) -> Dictionary:
	var weights := weights_for(seconds, table)
	if weights.is_empty():
		return {}

	var pity := is_pity_ready(seconds, walks_since_epic, table)
	var floor_rarity := min_rarity(seconds, table)
	if pity and RARITIES.find(floor_rarity) < RARITIES.find("epic"):
		floor_rarity = "epic"
	var candidates := _from(floor_rarity)
	var total := 0.0
	for r in candidates:
		total += float(weights.get(r, 0))
	if total <= 0.0:
		weights = {floor_rarity: 1}

	var rarity := _weighted_pick(candidates, weights, rng)
	var pool: Array = gifts.filter(func(g): return g["table"] == gift_table and g["rarity"] == rarity)
	if pool.is_empty():
		return {}
	var gift: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return {"rarity": rarity, "gift_id": gift["id"], "pity": pity}


## Updates the pity counter after a walk.
static func next_pity_count(current: int, seconds: int, rolled_rarity: String, table: Dictionary) -> int:
	if rolled_rarity == "epic" or rolled_rarity == "legendary":
		return 0
	if seconds >= int(table.get("pity_min_seconds", 1800)):
		return current + 1
	return current


## Swaps `cost` of a gift for one of the next rarity from the same table,
## changing `inventory`. Returns the new gift's id, or "" if it can't trade.
static func trade(inventory: Dictionary, gift_id: String, gifts: Array, cost: int) -> String:
	if cost <= 0 or int(inventory.get(gift_id, 0)) < cost:
		return ""
	var found: Array = gifts.filter(func(candidate): return candidate["id"] == gift_id)
	if found.is_empty():
		return ""
	var g: Dictionary = found[0]
	var i := RARITIES.find(str(g["rarity"]))
	if i < 0 or i >= RARITIES.size() - 1:
		return ""
	var next: Array = gifts.filter(func(x): return x["table"] == g["table"] and x["rarity"] == RARITIES[i + 1])
	if next.is_empty():
		return ""
	var new_id: String = next[0]["id"]
	inventory[gift_id] = int(inventory[gift_id]) - cost
	inventory[new_id] = int(inventory.get(new_id, 0)) + 1
	return new_id


## The rarities from `rarity` upwards.
static func _from(rarity: String) -> Array[String]:
	var i := maxi(0, RARITIES.find(rarity))
	return RARITIES.slice(i)


static func _weighted_pick(candidates: Array[String], weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for r in candidates:
		total += float(weights.get(r, 0))
	var roll_value := rng.randf() * total
	for r in candidates:
		var w := float(weights.get(r, 0))
		if w <= 0.0:
			continue
		if roll_value < w:
			return r
		roll_value -= w
	# Floating point edge: fall back to the last candidate with any weight.
	for i in range(candidates.size() - 1, -1, -1):
		if float(weights.get(candidates[i], 0)) > 0.0:
			return candidates[i]
	return candidates[0]
