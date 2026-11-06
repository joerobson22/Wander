extends TestCase

var table: Dictionary
var gifts: Array


func _init() -> void:
	table = load_json("res://data/drop_table.json")
	gifts = load_json("res://data/gifts.json")["gifts"]


func test_no_gift_under_ten_minutes() -> void:
	var rng := RandomNumberGenerator.new()
	eq(GiftRoller.roll(599, "dog", 0, table, gifts, rng), {})
	check(not GiftRoller.roll(600, "dog", 0, table, gifts, rng).is_empty(), "gift at exactly 10 minutes")


## The first tier with any weight for `rarity`.
func _first_tier_with(rarity: String) -> Dictionary:
	for tier in table["tiers"]:
		if float(tier["weights"].get(rarity, 0)) > 0.0:
			return tier
	return {}


## `rarity`'s share of a tier's weights, among those at least `floor_rarity`.
func _share(tier: Dictionary, rarity: String, floor_rarity: String = "common") -> float:
	var from := GiftRoller.RARITIES.find(floor_rarity)
	var total := 0.0
	for r in GiftRoller.RARITIES.slice(from):
		total += float(tier["weights"].get(r, 0))
	return float(tier["weights"].get(rarity, 0)) / total if GiftRoller.RARITIES.find(rarity) >= from else 0.0


func test_no_legendary_before_its_first_tier() -> void:
	var at := int(_first_tier_with("legendary")["min_seconds"])
	eq(GiftRoller.chances(at - 1, table)["legendary"], 0.0)
	check(GiftRoller.chances(at, table)["legendary"] > 0.0)


func test_gift_matches_table_and_rarity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 200:
		var r := GiftRoller.roll(4 * 3600, "bear", 0, table, gifts, rng)
		var g: Dictionary = gifts.filter(func(x): return x["id"] == r["gift_id"])[0]
		eq(g["table"], "bear")
		eq(g["rarity"], r["rarity"])


func test_distribution_roughly_matches_table() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for i in 20000:
		counts[GiftRoller.roll(1800, "dog", 0, table, gifts, rng)["rarity"]] += 1
	# Exactly on the 30 minute tier: its weights as they are.
	var tier: Dictionary = table["tiers"].filter(func(t): return int(t["min_seconds"]) == 1800)[0]
	check(absf(counts["common"] / 20000.0 - _share(tier, "common")) < 0.02, "common %s" % counts)
	check(absf(counts["epic"] / 20000.0 - _share(tier, "epic")) < 0.01, "epic %s" % counts)
	eq(counts["legendary"] > 0, _share(tier, "legendary") > 0.0, "legendary %s" % counts)


func test_guaranteed_rarity_drops_lower_ones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var counts := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	var at := int(table["guaranteed"]["rare"])
	for i in 20000:
		counts[GiftRoller.roll(at, "dog", 0, table, gifts, rng)["rarity"]] += 1
	# At least rare from here, so the tier's other weights share it all.
	var tier: Dictionary = table["tiers"].filter(func(t): return int(t["min_seconds"]) <= at).back()
	eq(counts["common"], 0, "no commons once rare is guaranteed")
	check(absf(counts["rare"] / 20000.0 - _share(tier, "rare", "rare")) < 0.02, "rare %s" % counts)
	check(absf(counts["legendary"] / 20000.0 - _share(tier, "legendary", "rare")) < 0.01, "legendary %s" % counts)


func test_min_rarity_follows_the_gift_button() -> void:
	var g: Dictionary = table["guaranteed"]
	eq(GiftRoller.min_rarity(599, table), "")
	eq(GiftRoller.min_rarity(600, table), "common")
	eq(GiftRoller.min_rarity(int(g["rare"]) - 1, table), "common")
	eq(GiftRoller.min_rarity(int(g["rare"]), table), "rare")
	eq(GiftRoller.min_rarity(int(g["epic"]), table), "epic")
	eq(GiftRoller.min_rarity(int(g["legendary"]), table), "legendary")
	var rng := RandomNumberGenerator.new()
	for i in 50:
		eq(GiftRoller.roll(int(g["legendary"]), "bird", 0, table, gifts, rng)["rarity"], "legendary")


func test_fill_grows_to_each_threshold() -> void:
	var g: Dictionary = table["guaranteed"]
	var start := int(table["min_seconds"])
	eq(GiftRoller.fill(start, table)["rare"], 0.0)
	eq(GiftRoller.fill(int(g["rare"]), table)["rare"], 1.0)
	check(GiftRoller.fill(int(g["rare"]), table)["epic"] < 1.0, "epic fills slower")
	check(GiftRoller.fill(int(g["rare"]), table)["legendary"] < GiftRoller.fill(int(g["rare"]), table)["epic"], "legendary slowest")
	eq(GiftRoller.fill(int(g["legendary"]) + 999, table)["legendary"], 1.0)


func test_trade_in() -> void:
	var inv := {"dog_common": 12}
	eq(GiftRoller.trade(inv, "dog_common", gifts, 10), "dog_rare")
	eq(inv, {"dog_common": 2, "dog_rare": 1})
	eq(GiftRoller.trade(inv, "dog_common", gifts, 10), "", "not enough left")
	inv["bear_epic"] = 6
	eq(GiftRoller.trade(inv, "bear_epic", gifts, 3), "bear_legendary")
	eq(GiftRoller.trade(inv, "bear_epic", gifts, 3), "bear_legendary2", "then the legendary you don't have yet")
	eq(inv["bear_epic"], 0, "stays listed at zero")
	inv["bear_legendary"] = 9
	eq(GiftRoller.trade(inv, "bear_legendary", gifts, 3), "", "legendaries can't be traded")
	eq(GiftRoller.trade(inv, "nope", gifts, 1), "")


func test_pity_guarantees_epic_or_better() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 100:
		var r := GiftRoller.roll(1800, "snail", int(table["pity_walks"]), table, gifts, rng)
		check(r["rarity"] == "epic" or r["rarity"] == "legendary", "pity gave %s" % r["rarity"])
		check(r["pity"])


func test_pity_counter() -> void:
	eq(GiftRoller.next_pity_count(3, 1800, "common", table), 4)
	eq(GiftRoller.next_pity_count(3, 900, "common", table), 3, "short walks don't count")
	eq(GiftRoller.next_pity_count(3, 1800, "epic", table), 0)


func test_every_table_has_a_gift_per_rarity() -> void:
	for t in load_json("res://data/gifts.json")["tables"]:
		# The holiday presents are all legendary, and no animal brings them.
		if t.get("holiday", "") == "any":
			continue
		for rarity in GiftRoller.RARITIES:
			var n := gifts.filter(func(g): return g["table"] == t["id"] and g["rarity"] == rarity).size()
			eq(n, 2 if rarity == "legendary" else 1, "%s %s" % [t["id"], rarity])
		var wearable := gifts.filter(func(g): return g["table"] == t["id"] and g.has("slot") and g["rarity"] == "legendary").size()
		eq(wearable, 2, "%s wearables are its legendaries" % t["id"])


## Only legendaries can be worn, and every slot gifts go in has as many.
func test_cosmetics_are_legendary_and_even() -> void:
	var per_slot := {}
	for g in gifts:
		if g.has("slot"):
			eq(g["rarity"], "legendary", "%s is wearable, so legendary" % g["id"])
			per_slot[g["slot"]] = int(per_slot.get(g["slot"], 0)) + 1
	var counts := per_slot.values()
	check(counts.min() == counts.max(), "every slot has as many cosmetics (%s)" % per_slot)


func test_animals_of_a_kind_share_a_table() -> void:
	var tables: Array = load_json("res://data/gifts.json")["tables"].map(func(t): return t["id"])
	var by_table := {}
	for a in load_json("res://data/animals.json")["animals"]:
		check(tables.has(a["table"]), "%s's table %s exists" % [a["id"], a["table"]])
		by_table[a["table"]] = by_table.get(a["table"], []) + [a["id"]]
	eq(by_table["dog"], ["dog1", "dog2"], "every dog brings dog gifts")
	eq(by_table["cat"], ["cat"], "the cat brings cat gifts")
	for t in ["lion", "tiger", "leopard"]:
		eq(by_table[t], [t], "the %s has its own" % t)
	for t in load_json("res://data/gifts.json")["tables"]:
		if t.get("holiday", "") == "any":
			continue
		check(by_table.has(t["id"]), "some animal brings %s gifts" % t["id"])
		check(by_table.get(t["id"], []).has(t["animal"]), "%s is shown by one of its own animals" % t["id"])


func test_odds_grow_steadily_between_tiers() -> void:
	var at_30 := GiftRoller.chances(1800, table)
	var between := GiftRoller.chances(2250, table)
	var at_45 := GiftRoller.chances(2699, table)
	check(between["rare"] > at_30["rare"] and at_45["rare"] > between["rare"], "rare grows through the half hour")
	eq(at_45["legendary"], 0.0, "but no legendary yet")
	var total := 0.0
	for r in GiftRoller.RARITIES:
		total += float(between[r])
	check(absf(total - 1.0) < 0.0001, "the chances add up")
	eq(GiftRoller.chances(599, table), {"common": 0.0, "rare": 0.0, "epic": 0.0, "legendary": 0.0}, "nothing before the first gift")
	eq(GiftRoller.chances(600, table)["common"], _share(table["tiers"][0], "common"))
