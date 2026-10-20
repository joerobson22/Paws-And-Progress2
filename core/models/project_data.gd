class_name ProjectData
extends Resource
## A project or education module. Each one has its own animal, recoloured per part.

const KIND_PROJECT := "project"
const KIND_MODULE := "module"

@export var id: String = ""
@export var name: String = ""
## The pet's own name ("Biscuit"); "" if it hasn't been given one.
@export var pet_name: String = ""
@export var animal_id: String = ""
## One colour per recolourable part of the animal, in the order the animal lists its parts.
@export var colours: Array[Color] = []
@export var kind: String = KIND_PROJECT
@export var created_unix: int = 0
## 0 while the project is still active.
@export var completed_unix: int = 0
@export var due_unix: int = 0
@export var tags: PackedStringArray = PackedStringArray()
@export var grade: String = ""
## Focus time imported from v1, which kept no per-session history.
@export var legacy_seconds: int = 0


func is_complete() -> bool:
	return completed_unix > 0


func to_dict() -> Dictionary:
	var cols: Array = []
	for c in colours:
		cols.append(c.to_html(false))
	return {
		"id": id,
		"name": name,
		"pet_name": pet_name,
		"animal_id": animal_id,
		"colours": cols,
		"kind": kind,
		"created_unix": created_unix,
		"completed_unix": completed_unix,
		"due_unix": due_unix,
		"tags": Array(tags),
		"grade": grade,
		"legacy_seconds": legacy_seconds,
	}


static func from_dict(d: Dictionary) -> ProjectData:
	var p := ProjectData.new()
	p.id = str(d.get("id", ""))
	p.name = str(d.get("name", ""))
	p.pet_name = str(d.get("pet_name", ""))
	p.animal_id = str(d.get("animal_id", ""))
	for c in d.get("colours", []):
		p.colours.append(Color.from_string(str(c), Color.WHITE))
	p.kind = str(d.get("kind", KIND_PROJECT))
	p.created_unix = int(d.get("created_unix", 0))
	p.completed_unix = int(d.get("completed_unix", 0))
	p.due_unix = int(d.get("due_unix", 0))
	p.tags = PackedStringArray(d.get("tags", []))
	p.grade = str(d.get("grade", ""))
	p.legacy_seconds = int(d.get("legacy_seconds", 0))
	return p
