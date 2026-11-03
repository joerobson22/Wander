class_name ProjectData
extends Resource
## A project. Any of your pets can walk for it; it
## keeps how long each pet walked for it, and where.

@export var id: String = ""
@export var name: String = ""
@export var created_unix: int = 0
## 0 while the project is still active.
@export var completed_unix: int = 0
@export var grade: String = ""
## When a walk for it last finished; 0 if none has.
@export var last_walked_unix: int = 0
## pet id -> seconds walked with that pet for this project.
@export var pets: Dictionary = {}
## place id -> seconds walked there for this project.
@export var places: Dictionary = {}
## gift id -> how many of its walks brought that gift.
@export var gifts: Dictionary = {}


func is_complete() -> bool:
	return completed_unix > 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"created_unix": created_unix,
		"completed_unix": completed_unix,
		"grade": grade,
		"last_walked_unix": last_walked_unix,
		"pets": pets,
		"places": places,
		"gifts": gifts,
	}


static func from_dict(d: Dictionary) -> ProjectData:
	var p := ProjectData.new()
	p.id = str(d.get("id", ""))
	p.name = str(d.get("name", ""))
	p.created_unix = int(d.get("created_unix", 0))
	p.completed_unix = int(d.get("completed_unix", 0))
	p.grade = str(d.get("grade", ""))
	p.last_walked_unix = int(d.get("last_walked_unix", 0))
	for key in ["pets", "places", "gifts"]:
		var got = d.get(key, {})
		if got is Dictionary:
			var out: Dictionary = p.get(key)
			for k in got:
				out[str(k)] = int(got[k])
	return p
