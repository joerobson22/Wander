extends TestCase

const TABLES := [{"id": "dog"}, {"id": "cat"}, {"id": "snail"}]
const GIFTS := [
	{"id": "dog_a", "table": "dog"},
	{"id": "dog_b", "table": "dog", "slot": "hat"},
	{"id": "cat_a", "table": "cat"},
	{"id": "cat_b", "table": "cat", "slot": "top"},
]


func test_nothing_found() -> void:
	var p := Collection.progress({}, GIFTS)
	eq(p, {"found": 0, "gifts": 4, "tables": 0, "total_tables": 2, "cosmetics": 0, "wearables": 2}, "a fresh start")


func test_discovered_counts_gifts_traded_away() -> void:
	var p := Collection.progress({"dog_a": 0, "cat_a": 3}, GIFTS)
	eq(p["found"], 2, "a gift you've had stays discovered")


func test_a_table_needs_every_gift() -> void:
	eq(Collection.progress({"dog_a": 1}, GIFTS)["tables"], 0, "one of the dog's two")
	eq(Collection.progress({"dog_a": 1, "dog_b": 1}, GIFTS)["tables"], 1, "both of the dog's")
	eq(Collection.progress({"dog_a": 0, "dog_b": 0, "cat_a": 1, "cat_b": 1}, GIFTS)["tables"], 2, "traded away still counts")
	eq(Collection.progress({}, GIFTS)["total_tables"], 2, "only tables with gifts count")


func test_cosmetics_are_wearable_gifts_you_have() -> void:
	eq(Collection.progress({"dog_b": 1, "cat_b": 0}, GIFTS)["cosmetics"], 1, "only the one you still have")
	eq(Collection.progress({"dog_a": 5}, GIFTS)["cosmetics"], 0, "a gift you can't wear")


func test_fraction() -> void:
	eq(Collection.fraction(1, 4), 0.25)
	eq(Collection.fraction(0, 0), 0.0, "nothing to have")
	eq(Collection.fraction(5, 4), 1.0, "never more than all of it")


const SORTABLE := [
	{"id": "cat_rare", "table": "cat", "rarity": "rare", "name": "Yarn"},
	{"id": "dog_common", "table": "dog", "rarity": "common", "name": "Bone"},
	{"id": "dog_epic", "table": "dog", "rarity": "epic", "name": "Collar"},
	{"id": "cat_common", "table": "cat", "rarity": "common", "name": "Mouse"},
]


func test_sort_gifts() -> void:
	var ids := ["cat_rare", "dog_common", "dog_epic", "cat_common"]
	eq(Collection.sort_gifts(ids, "rarity", false, SORTABLE, TABLES), ["dog_epic", "cat_rare", "dog_common", "cat_common"], "rarest first, then A-Z")
	eq(Collection.sort_gifts(ids, "name", false, SORTABLE, TABLES), ["dog_common", "dog_epic", "cat_common", "cat_rare"], "A-Z")
	eq(Collection.sort_gifts(ids, "animal", false, SORTABLE, TABLES), ["dog_common", "dog_epic", "cat_common", "cat_rare"], "pet type, commonest first")
	eq(Collection.sort_gifts(ids, "name", true, SORTABLE, TABLES), ["cat_rare", "cat_common", "dog_epic", "dog_common"], "reversed")
	eq(ids, ["cat_rare", "dog_common", "dog_epic", "cat_common"], "leaves the list it's given alone")
