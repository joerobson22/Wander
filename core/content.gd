extends Node
## Autoload "Content": the data-driven game content from res://data/.
## New animals, gifts, cosmetics, grades and biomes are data edits, not code changes.

var animals: Array = []
var gifts: Array = []
## Gift tables: [{id, name, animal}]. Animals of a kind share one (gifts.json).
var tables: Array = []
var rarities: Array = []
var drop_table: Dictionary = {}
var biomes: Array = []
## The sky and light round the clock (see DayCycle).
var day_cycle: Dictionary = {}
## How each kind of weather looks (see Weather).
var weathers: Dictionary = {}
var grade_scales: Array = []
## What the profile's achievements are (see Achievements.list()).
var achievements: Dictionary = {}
## XP rules and level rewards (data/levels.json).
var levels: Dictionary = {}
## [{id, name}] in the order the customise popup lists them.
var cosmetic_slots: Array = []
## Starter wardrobe items; wearable gifts are cosmetics too (see cosmetic()).
var cosmetic_items: Array = []
var skin_tones: Array[Color] = []
var hair_tones: Array[Color] = []
## The customise popup's tabs: [{id, name, rows: [slot or "skin_tone"/"hair_tone"]}].
var cosmetic_sections: Array = []
## Days the app dresses up (data/holidays.json; see Holidays).
var holidays: Array = []

var _animals_by_id: Dictionary = {}
var _gifts_by_id: Dictionary = {}
var _tables_by_id: Dictionary = {}
var _rarities_by_id: Dictionary = {}
var _items_by_id: Dictionary = {}


func _init() -> void:
	var a := _load("res://data/animals.json")
	animals = a.get("animals", [])
	var g := _load("res://data/gifts.json")
	gifts = g.get("gifts", [])
	tables = g.get("tables", [])
	rarities = g.get("rarities", [])
	drop_table = _load("res://data/drop_table.json")
	var b := _load("res://data/biomes.json")
	biomes = b.get("biomes", [])
	_read_place_scenes()
	day_cycle = b.get("day_cycle", {})
	weathers = b.get("weathers", {})
	var keys: Array = day_cycle.get("keys", [])
	keys.sort_custom(func(x, y): return float(x["hour"]) < float(y["hour"]))
	grade_scales = _load("res://data/grades.json").get("scales", [])
	achievements = _load("res://data/achievements.json")
	levels = _load("res://data/levels.json")
	var c := _load("res://data/cosmetics.json")
	cosmetic_slots = c.get("slots", [])
	cosmetic_items = c.get("items", [])
	cosmetic_sections = c.get("sections", [])
	holidays = _load("res://data/holidays.json").get("holidays", [])
	for hex in c.get("skin_tones", []):
		skin_tones.append(Color.from_string(hex, Color.WHITE))
	for hex in c.get("hair_tones", []):
		hair_tones.append(Color.from_string(hex, Color.BLACK))
	for x in animals:
		_animals_by_id[x["id"]] = x
	for x in gifts:
		_gifts_by_id[x["id"]] = x
	for x in tables:
		_tables_by_id[x["id"]] = x
	for x in rarities:
		_rarities_by_id[x["id"]] = x
	for x in cosmetic_items:
		_items_by_id[x["id"]] = x


func animal(id: String) -> Dictionary:
	return _animals_by_id.get(id, animals[0] if not animals.is_empty() else {})


## A pet as you'd say it in a sentence: its name ("Biscuit"), or "your
## rabbit" if it hasn't got one ("Your rabbit" to start a sentence), or
## "your pet" with no pet at all.
func pet_called(p: PetData, start_of_sentence: bool = false) -> String:
	if p == null:
		return Text.t("pet.fallback_start" if start_of_sentence else "pet.fallback")
	if p.name != "":
		return p.name
	return Text.t("pet.your_kind_start" if start_of_sentence else "pet.your_kind",
		{"kind": str(animal(p.animal_id).get("name", "pet")).to_lower()})


func animal_default_colours(id: String) -> Array[Color]:
	var out: Array[Color] = []
	for c in animal(id).get("default_colours", []):
		out.append(Color.from_string(c, Color.WHITE))
	return out


func gift(id: String) -> Dictionary:
	return _gifts_by_id.get(id, {})


## A gift table by id: {id, name, animal (the one shown for it)}.
func table(id: String) -> Dictionary:
	return _tables_by_id.get(id, {})


## The gift table an animal brings gifts from.
func table_of(animal_id: String) -> String:
	return str(animal(animal_id).get("table", animal_id))


## Every gift in a table, commonest first.
func table_gifts(table_id: String) -> Array:
	return gifts.filter(func(g): return g["table"] == table_id)


## What it takes to unlock an animal or place ("animal" / "place"): its
## "unlock" rule from the data, {} for from the start (see Unlocks).
func unlock_rule(type: String, id: String) -> Dictionary:
	var thing := animal(id) if type == "animal" else biome(id)
	if thing.get("id", "") != id:
		return {}
	var rule = thing.get("unlock", {})
	return rule if rule is Dictionary else {}


func rarity_colour(rarity_id: String) -> Color:
	if UI.vision != "off" and UI.SAFE["rarities"].has(rarity_id):
		return Color(UI.SAFE["rarities"][rarity_id][0])
	return Color.from_string(_rarities_by_id.get(rarity_id, {}).get("colour", "#888888"), Color.GRAY)


## A darker shade of the rarity colour that reads as text on a light background.
func rarity_text_colour(rarity_id: String) -> Color:
	if UI.vision != "off" and UI.SAFE["rarities"].has(rarity_id):
		return Color(UI.SAFE["rarities"][rarity_id][1])
	return Color.from_string(_rarities_by_id.get(rarity_id, {}).get("text_colour", "#5e5e52"), Color.DIM_GRAY)


func rarity_name(rarity_id: String) -> String:
	return _rarities_by_id.get(rarity_id, {}).get("name", rarity_id.capitalize())


## How many of a gift of this rarity trade up for one of the next rarity; 0 = can't trade.
func trade_cost(rarity_id: String) -> int:
	return int(_rarities_by_id.get(rarity_id, {}).get("trade_in", 0))


## The rarity one step up, or "" for the top one.
func next_rarity(rarity_id: String) -> String:
	var i := GiftRoller.RARITIES.find(rarity_id)
	return GiftRoller.RARITIES[i + 1] if i >= 0 and i < GiftRoller.RARITIES.size() - 1 else ""


func gift_rarity(id: String) -> String:
	return str(gift(id).get("rarity", ""))


## Each place's look comes from its scene, art/scenery/<id>/place.tscn
## (made and changed in the Godot editor: see PlaceScenery), as its layers.
const PLACE_SCENE := "res://art/scenery/%s/place.tscn"


func _read_place_scenes() -> void:
	for b in biomes:
		var path := PLACE_SCENE % str(b["id"])
		if not ResourceLoader.exists(path):
			push_warning("Content: no scenery scene for %s (%s)" % [b["id"], path])
			b["layers"] = b.get("layers", [])
			continue
		var place := (load(path) as PackedScene).instantiate() as PlaceScenery
		if place == null:
			push_warning("Content: %s isn't a place's scenery" % path)
			continue
		b["layers"] = place.layers()
		place.free()


## A holiday by id (data/holidays.json), or {} for none.
func holiday(id: String) -> Dictionary:
	for h in holidays:
		if h["id"] == id:
			return h
	return {}


func biome(id: String) -> Dictionary:
	for b in biomes:
		if b["id"] == id:
			return b
	return biomes[0] if not biomes.is_empty() else {}


# --- Grades ------------------------------------------------------------------

## A grade from its saved reference ("gcse/9"), with "scale" and "scale_name"
## added; empty if there's no such grade.
func grade(ref: String) -> Dictionary:
	var bits := ref.split("/", true, 1)
	if bits.size() != 2:
		return {}
	for scale in grade_scales:
		if scale["id"] != bits[0]:
			continue
		for g in scale["grades"]:
			if g["id"] == bits[1]:
				var out: Dictionary = g.duplicate()
				out["scale"] = scale["id"]
				out["scale_name"] = scale["name"]
				out["ref"] = ref
				return out
	return {}


## Where a grade stands among every grade, best first, for sorting: [band,
## scale, place]. Each scale's grades are spread over the same five bands
## (the university classes), so a 9, an A* and a First share the top band;
## within a band university comes first, then A-Level, then GCSE. Anything
## without a grade sorts after all of them.
func grade_rank(ref: String) -> Array:
	var g := grade(ref)
	if g.is_empty():
		return [99, 99, 99]
	var order := ["uni", "alevel", "gcse"]
	for scale in grade_scales:
		if scale["id"] != g["scale"]:
			continue
		var place := 0
		for i in scale["grades"].size():
			if scale["grades"][i]["id"] == g["id"]:
				place = i
		var last := maxi(1, scale["grades"].size() - 1)
		var band := roundi(4.0 * place / last)
		var which := order.find(g["scale"])
		return [band, which if which >= 0 else order.size(), place]
	return [99, 99, 99]


# --- Quotes ------------------------------------------------------------------

## The same quote for the same key, so a walk keeps its quote across restarts.
func quote(key: int) -> String:
	var quotes := Text.list("quotes")
	if quotes.is_empty():
		return ""
	return str(quotes[posmod(key, quotes.size())])


## A line for the home screen at this hour: half the time a greeting for the
## time of day, otherwise an anytime line. On a holiday (an id from
## data/holidays.json) it's always one of that holiday's lines, if it has
## any. Lines needing a name are skipped when there isn't one.
func greeting(hour: int, username: String, rng: RandomNumberGenerator, holiday_id := "") -> String:
	var part := "night"
	if hour >= 5 and hour < 12:
		part = "morning"
	elif hour >= 12 and hour < 17:
		part = "afternoon"
	elif hour >= 17 and hour < 22:
		part = "evening"
	var pool: Array = Text.list("greetings." + part) if rng.randf() < 0.5 else Text.list("greetings.anytime")
	var festive: Array = Text.list("greetings.holidays." + holiday_id) if holiday_id != "" else []
	festive = festive.filter(func(l): return username != "" or not str(l).contains("{name}"))
	if not festive.is_empty():
		pool = festive
	pool = pool.filter(func(l): return username != "" or not str(l).contains("{name}"))
	if pool.is_empty():
		return Text.t("greetings.fallback")
	return Text.fill(str(pool[rng.randi_range(0, pool.size() - 1)]), {"name": username})


# --- Cosmetics ---------------------------------------------------------------

func slot_name(slot: String) -> String:
	for s in cosmetic_slots:
		if s["id"] == slot:
			return s["name"]
	return slot.capitalize()


## A starter item or a wearable gift by id; empty if it's neither.
func cosmetic(id: String) -> Dictionary:
	if _items_by_id.has(id):
		return _items_by_id[id]
	var g := gift(id)
	return g if g.has("slot") else {}


## What the slot shows when nothing's picked: its first starter item.
func default_cosmetic(slot: String) -> Dictionary:
	for item in cosmetic_items:
		if item["slot"] == slot:
			return item
	return {}


## Everything that can be worn in a slot: the starters, then wearable gifts
## the player owns.
func cosmetic_options(slot: String, inventory: Dictionary) -> Array:
	var out: Array = cosmetic_items.filter(func(i): return i["slot"] == slot)
	for g in gifts:
		if g.get("slot", "") == slot and int(inventory.get(g["id"], 0)) > 0:
			out.append(g)
	return out


## A look's skin colour: its own picked colour ("skin_colour", a hex) if it
## has one, else its swatch ("skin_tone").
func skin_of(look: Dictionary) -> Color:
	return _tone_of(look, "skin", skin_tones)


## A look's hair colour, the same way ("hair_colour", else "hair_tone").
func hair_of(look: Dictionary) -> Color:
	return _tone_of(look, "hair", hair_tones)


func _tone_of(look: Dictionary, which: String, tones: Array[Color]) -> Color:
	var own := str(look.get(which + "_colour", ""))
	if own != "":
		return Color.from_string(own, tones[0])
	return tones[clampi(int(look.get(which + "_tone", 0)), 0, tones.size() - 1)]


## The colour an item is drawn in: its own, else its rarity's for a gift.
func cosmetic_colour(item: Dictionary, fallback: Color) -> Color:
	if item.has("colour"):
		return Color.from_string(item["colour"], fallback)
	if item.has("rarity"):
		return rarity_colour(item["rarity"])
	return fallback


func _load(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("Content: couldn't read %s" % path)
		return {}
	return data
