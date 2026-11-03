class_name PetData
extends Resource
## A pet you've adopted. You pick a pet and a project separately for each
## walk, so a pet can walk for many projects and a project with many pets.

@export var id: String = ""
## Its own name ("Biscuit"); filled in with the animal's name when adopting.
@export var name: String = ""
@export var animal_id: String = ""
## One colour per recolourable part of the animal, in the order the animal lists its parts.
@export var colours: Array[Color] = []
@export var adopted_unix: int = 0
## When it last finished a walk; 0 if it never has.
@export var last_walked_unix: int = 0
## place id -> seconds it has walked there.
@export var places: Dictionary = {}
## When it was rehomed: it leaves your pets but still shows on the projects
## it walked for. 0 while it's yours.
@export var rehomed_unix: int = 0


func is_rehomed() -> bool:
	return rehomed_unix > 0


func to_dict() -> Dictionary:
	var cols: Array = []
	for c in colours:
		cols.append(c.to_html(false))
	return {
		"id": id,
		"name": name,
		"animal_id": animal_id,
		"colours": cols,
		"adopted_unix": adopted_unix,
		"last_walked_unix": last_walked_unix,
		"rehomed_unix": rehomed_unix,
		"places": places,
	}


static func from_dict(d: Dictionary) -> PetData:
	var p := PetData.new()
	p.id = str(d.get("id", ""))
	p.name = str(d.get("name", ""))
	p.animal_id = str(d.get("animal_id", ""))
	for c in d.get("colours", []):
		p.colours.append(Color.from_string(str(c), Color.WHITE))
	p.adopted_unix = int(d.get("adopted_unix", 0))
	p.last_walked_unix = int(d.get("last_walked_unix", 0))
	p.rehomed_unix = int(d.get("rehomed_unix", 0))
	var got = d.get("places", {})
	if got is Dictionary:
		for key in got:
			p.places[str(key)] = int(got[key])
	return p
