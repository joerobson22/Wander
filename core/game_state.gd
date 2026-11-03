class_name GameState
extends RefCounted
## Everything that gets saved. SaveSystem turns this into JSON and back.

## Character slots, in the order the customise popup lists them (data/cosmetics.json).
const COSMETIC_SLOTS: Array[String] = [
	"hat", "hair", "face", "facial_hair", "neckwear", "top", "gloves", "walking_stick", "trousers", "shoes",
]
const SHELF_SIZE := 3

var profile: Dictionary = default_profile()
var projects: Array[ProjectData] = []
## Every pet ever adopted, rehomed ones too (they still show on projects).
var pets: Array[PetData] = []
## Focus time by local day (Stats.local_day): {day: {"projects": {project id:
## seconds}, "pets": {pet id: seconds}, "places": {place id: seconds}}}.
## Every stat is worked out from these; walks aren't kept one by one.
var days: Dictionary = {}
## Every XP point earned. Levels are worked out from it (Levels.level_for),
## so changing the level thresholds moves everyone's level at once.
var xp: int = 0
## gift_id -> how many the player has. A gift stays listed at 0 once traded
## away, so it still shows as found.
var inventory: Dictionary = {}
## The walk in progress, or null.
var active: SessionClock = null
var settings: Dictionary = default_settings()


static func default_profile() -> Dictionary:
	var cosmetics := {}
	for slot in COSMETIC_SLOTS:
		cosmetics[slot] = ""
	return {
		"username": "",
		"institution": "",
		# Date of birth, "YYYY-MM-DD" ("" for accounts made before it was asked).
		"dob": "",
		# When the privacy policy and terms were agreed to (0 = before they were asked).
		"agreed_unix": 0,
		"created_unix": 0,
		"skin_tone": 0,
		"hair_tone": 0,
		# A picked colour (hex) used instead of the swatch; "" for none.
		"skin_colour": "",
		"hair_colour": "",
		# slot -> equipped item id ("" = the slot's default look).
		"cosmetics": cosmetics,
		# Favourite gifts on the gift shelf, left to right ("" = empty spot).
		"shelf": empty_shelf(),
		"walks_since_epic": 0,
		# Walks finished, so the home screen can pick a new line after each.
		"walks": 0,
	}


static func default_settings() -> Dictionary:
	return {
		"sound": true,
		"ambience": true,
		"reduce_motion": false,
		# UI.VISIONS: colours for colour blindness.
		"vision": "off",
		"keep_screen_on": true,
		"walk_biome": "lake",
	}


static func empty_shelf() -> Array:
	var out := []
	out.resize(SHELF_SIZE)
	out.fill("")
	return out


func project(id: String) -> ProjectData:
	for p in projects:
		if p.id == id:
			return p
	return null


func active_projects() -> Array[ProjectData]:
	var out: Array[ProjectData] = []
	out.assign(projects.filter(func(p): return not p.is_complete()))
	return out


func completed_projects() -> Array[ProjectData]:
	var out: Array[ProjectData] = []
	out.assign(projects.filter(func(p): return p.is_complete()))
	return out


func pet(id: String) -> PetData:
	for p in pets:
		if p.id == id:
			return p
	return null


## The pets that are still yours (not rehomed), oldest first.
func active_pets() -> Array[PetData]:
	var out: Array[PetData] = []
	out.assign(pets.filter(func(p): return not p.is_rehomed()))
	return out


## Adds `seconds` of focus on a project, with a pet, in a place, to day `day`.
func log_focus(day: int, project_id: String, pet_id: String, place_id: String, seconds: int) -> void:
	if seconds <= 0:
		return
	if not days.has(day):
		days[day] = {"projects": {}, "pets": {}, "places": {}}
	var d: Dictionary = days[day]
	for part in [["projects", project_id], ["pets", pet_id], ["places", place_id]]:
		d[part[0]][part[1]] = int(d[part[0]].get(part[1], 0)) + seconds


func total_seconds() -> int:
	var total := 0
	for d in days.values():
		for s in d["projects"].values():
			total += int(s)
	return total


func project_seconds(id: String) -> int:
	var total := 0
	for d in days.values():
		total += int(d["projects"].get(id, 0))
	return total


## Seconds walked with a pet, ever.
func pet_seconds(id: String) -> int:
	var total := 0
	for d in days.values():
		total += int(d["pets"].get(id, 0))
	return total


## {place id: seconds} focused in each place, ever.
func place_seconds() -> Dictionary:
	var out := {}
	for d in days.values():
		for id in d["places"]:
			out[id] = int(out.get(id, 0)) + int(d["places"][id])
	return out


## gift_id -> how many walks on this project brought that gift.
func project_gifts(id: String) -> Dictionary:
	var p := project(id)
	return p.gifts if p else {}


func gift_count(gift_id: String) -> int:
	return int(inventory.get(gift_id, 0))


# --- Gift shelf --------------------------------------------------------------

func shelf() -> Array:
	var s: Array = profile.get("shelf", [])
	var out := empty_shelf()
	for i in mini(s.size(), SHELF_SIZE):
		out[i] = str(s[i])
	return out


## Puts a gift on the shelf at `index`. A gift already on the shelf moves
## there, swapping with whatever was in the way.
func place_on_shelf(gift_id: String, index: int) -> void:
	if index < 0 or index >= SHELF_SIZE:
		return
	var s := shelf()
	var from := s.find(gift_id)
	if from >= 0:
		s[from] = s[index]
	s[index] = gift_id
	profile["shelf"] = s


func remove_from_shelf(index: int) -> void:
	var s := shelf()
	if index >= 0 and index < SHELF_SIZE:
		s[index] = ""
	profile["shelf"] = s


## Drops shelf and wardrobe references to gifts the player no longer has.
func tidy_gift_references() -> void:
	var s := shelf()
	for i in s.size():
		if s[i] != "" and gift_count(s[i]) <= 0:
			s[i] = ""
	profile["shelf"] = s
	var cosmetics: Dictionary = profile["cosmetics"]
	for slot in cosmetics:
		var id := str(cosmetics[slot])
		if inventory.has(id) and gift_count(id) <= 0:
			cosmetics[slot] = ""
