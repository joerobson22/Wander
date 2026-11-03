extends TestCase


func test_the_cast() -> void:
	var animals: Array = load_json("res://data/animals.json")["animals"]
	var ids: Array = animals.map(func(a): return a["id"])
	for id in ["dog1", "dog2", "dog3", "cat1", "cat2", "snail", "bird", "sheep", "pig", "rabbit", "bear", "tortoise"]:
		check(ids.has(id), "%s is in the core cast" % id)
	for id in ["elephant", "lion", "gorilla", "hyrax", "lizard", "spider", "snake", "eagle", "parakeet", "fox", "leopard", "tiger", "monkey", "giraffe", "red_panda", "rhino", "frog"]:
		check(ids.has(id), "%s is unlockable" % id)
	eq(ids.size(), 33)
	for a in animals:
		eq(a["parts"].size(), a["default_colours"].size(), "%s colours per part" % a["id"])


## Unlock rules and homes point at things that exist, or an animal could
## never unlock.
func test_unlock_rules_are_real() -> void:
	var places: Array = load_json("res://data/biomes.json")["biomes"].map(func(b): return b["id"])
	var tables: Array = load_json("res://data/gifts.json")["tables"].map(func(t): return t["id"])
	var things: Array = []
	for a in load_json("res://data/animals.json")["animals"]:
		check(places.has(a["home"]), "%s's home %s" % [a["id"], a["home"]])
		things.append([a["id"], a.get("unlock", {})])
	for b in load_json("res://data/biomes.json")["biomes"]:
		check(str(b.get("where", "")) != "", "%s says where it is" % b["id"])
		things.append([b["id"], b.get("unlock", {})])
	for t in things:
		var rule: Dictionary = t[1]
		check(rule.is_empty() or Unlocks.kind_of(rule) != "start", "%s has a rule the app knows" % t[0])
		if rule.has("place"):
			check(places.has(rule["place"]), "%s's rule names a real place" % t[0])
		if rule.has("table"):
			check(tables.has(rule["table"]), "%s's rule names a real table" % t[0])
	eq(places, ["lake", "farm", "forest", "beach", "city", "desert", "jungle", "tundra", "blossom", "safari", "moon"], "the places in picker order")
	eq(load_json("res://data/biomes.json")["biomes"][-1]["unlock"], {"all_tables": true}, "the Moon is the final reward")


func test_drop_tiers_ascend() -> void:
	var tiers: Array = load_json("res://data/drop_table.json")["tiers"]
	for i in range(1, tiers.size()):
		check(int(tiers[i]["min_seconds"]) > int(tiers[i - 1]["min_seconds"]))


func test_wearables_use_real_slots() -> void:
	var slots: Array = load_json("res://data/cosmetics.json")["slots"].map(func(x): return x["id"])
	eq(slots, Array(GameState.COSMETIC_SLOTS), "cosmetics.json lists the saved slots in order")
	for g in load_json("res://data/gifts.json")["gifts"]:
		if g.has("slot"):
			check(slots.has(g["slot"]), "%s slot %s" % [g["id"], g["slot"]])
			check(g.has("style"), "%s needs a style" % g["id"])
	for item in load_json("res://data/cosmetics.json")["items"]:
		check(slots.has(item["slot"]), "%s slot" % item["id"])
	for slot in slots:
		check(load_json("res://data/cosmetics.json")["items"].any(func(i): return i["slot"] == slot), "%s has a starter" % slot)


func test_grades_have_colours() -> void:
	var scales: Array = load_json("res://data/grades.json")["scales"]
	eq(scales.map(func(s): return s["id"]), ["gcse", "alevel", "uni"])
	eq(scales[0]["grades"].size(), 9, "GCSE 9 to 1")
	for scale in scales:
		for g in scale["grades"]:
			check(g.has("label") and g.has("colour") and g.has("ink"), "%s/%s" % [scale["id"], g["id"]])


func test_trade_costs() -> void:
	var r: Array = load_json("res://data/gifts.json")["rarities"]
	eq(r.map(func(x): return int(x.get("trade_in", 0))), [10, 5, 3, 0])


func test_every_animal_can_dive() -> void:
	for a in load_json("res://data/animals.json")["animals"]:
		check(a.has("dive") and a["dive"].has("hops") and a["dive"].has("seconds"), a["id"])


## Grades sort best first across scales: each scale spreads over the five
## university classes, and within one of those university comes first.
func test_grade_rank_orders_across_scales() -> void:
	var content: Node = load("res://core/content.gd").new()
	var refs := ["gcse/4", "", "alevel/a", "uni/upper_second", "gcse/9", "uni/first", "alevel/a_star", "gcse/8", "uni/fail"]
	refs.sort_custom(func(a, b): return content.grade_rank(a) < content.grade_rank(b))
	eq(refs, ["uni/first", "alevel/a_star", "gcse/9", "uni/upper_second", "alevel/a", "gcse/8", "gcse/4", "uni/fail", ""])
	content.free()


## Art is found by convention, so a typo'd path would silently show the placeholder.
func test_art_paths_are_well_formed() -> void:
	for a in load_json("res://data/animals.json")["animals"]:
		var dir: String = a["sprite_dir"]
		check(dir.begins_with("res://art/animals/") and dir.ends_with("/"), "%s sprite_dir %s" % [a["id"], dir])
		if ResourceLoader.exists(dir + "animal.tscn"):
			check(a["parts"].size() <= 3, "%s: the shader maps three colours" % a["id"])
	for b in load_json("res://data/biomes.json")["biomes"]:
		check(not b.has("layers"), "%s: its layers live in its scene, not biomes.json" % b["id"])
	check(ResourceLoader.exists("res://art/animal_colours.gdshader"))
	check(load("res://art/templates/animal/animal.tscn") is PackedScene, "the animal template loads")
	check(load("res://art/templates/scenery/tile.tscn") is PackedScene, "the scenery template loads")


## An item's art folder is named after the item and its files after limbs, or the art silently never shows.
func test_cosmetic_art_folders_match_items() -> void:
	var ids := {}
	for item in load_json("res://data/cosmetics.json")["items"]:
		ids[item["id"]] = true
	for g in load_json("res://data/gifts.json")["gifts"]:
		if g.has("slot"):
			ids[g["id"]] = true
	var stems := ["torso", "head", "arm_back", "arm_front", "leg_back", "leg_front"]
	for root in ["res://art/cosmetics/", "res://art/templates/cosmetics/"]:
		var dir := DirAccess.open(root)
		if dir == null:
			continue
		for folder in dir.get_directories():
			check(ids.has(folder), "%s%s isn't a cosmetic's id" % [root, folder])
			for file in DirAccess.get_files_at(root + folder):
				if file.get_extension() in ["png", "svg", "webp"]:
					var stem := file.get_basename().trim_suffix("_behind").trim_suffix("_sad")
					check(stems.has(stem), "%s%s/%s isn't a limb" % [root, folder, file])


## Every place's look is a scene you edit in Godot: one per place, named
## after it, each with layers and ground to walk on.
func test_every_place_has_a_scenery_scene() -> void:
	var ids := {}
	for b in load_json("res://data/biomes.json")["biomes"]:
		ids[b["id"]] = true
		var path := "res://art/scenery/%s/place.tscn" % b["id"]
		check(ResourceLoader.exists(path), "%s has %s" % [b["id"], path])
		if not ResourceLoader.exists(path):
			continue
		var place = (load(path) as PackedScene).instantiate()
		check(place is PlaceScenery, "%s's scene is a PlaceScenery" % b["id"])
		var layers: Array = place.layers()
		check(layers.size() >= 2, "%s has layers" % b["id"])
		check(layers.any(func(l): return l["kind"] == "ground"), "%s has ground to walk on" % b["id"])
		for layer in layers:
			check(SceneryLayer.KINDS.split(",").has(layer["kind"]), "%s: %s is a kind the walk draws" % [b["id"], layer["kind"]])
			if layer.has("art"):
				check(ResourceLoader.exists(layer["art"]), "%s art %s" % [b["id"], layer["art"]])
		place.free()
	for folder in DirAccess.get_directories_at("res://art/scenery/"):
		check(ids.has(folder), "art/scenery/%s isn't a place's id" % folder)


## A place's scene gives the walk the same layers it was made from.
func test_place_scene_layers_round_trip() -> void:
	var l := SceneryLayer.new()
	l.kind = "pines"
	l.parallax = 0.3
	l.y = 0.64
	l.height = 0.28
	l.colour = Color("#456f50")
	l.pattern = 13
	l.spacing = 52
	l.snow = true
	var d := l.to_layer()
	eq(d, {"kind": "pines", "parallax": 0.3, "y": 0.64, "height": 0.28, "colour": "#456f50", "seed": 13, "spacing": 52, "snow": true})
	check(l.art_tile() == null, "no sprites inside: drawn as its kind")
	var sprite := Sprite2D.new()
	l.add_child(sprite)
	var tile = l.art_tile()
	check(tile != null and tile["node"].get_child_count() == 1 and tile["width"] == l.tile_width, "sprites inside repeat as its art")
	tile["node"].free()
	l.free()


## The sound list and the motion settings open in the editor and load.
func test_editable_resources_load() -> void:
	var lib := load("res://assets/sounds/sounds.tres") as SoundLibrary
	check(lib != null and lib.sounds.size() > 20, "the sound list loads")
	var seen := {}
	for s in lib.sounds:
		check(not seen.has(s.id), "%s is listed once" % s.id)
		seen[s.id] = true
	check(lib.find("dog_bark") != null and lib.find("dog_bark").stream != null, "listed sounds keep their recordings")
	check(load("res://ui/motion.tres") is MotionStyle, "the motion settings load")
	check(load("res://art/walk/bush.tscn") is PackedScene, "the bush loads")
