class_name FocusSession
extends Resource
## One finished walk. Stats are always computed from these, never from a running counter.

@export var id: String = ""
@export var project_id: String = ""
@export var animal_id: String = ""
@export var start_unix: int = 0
@export var end_unix: int = 0
## Time actually walked, excluding pauses.
@export var focus_seconds: int = 0
## Empty when the walk was too short for a gift.
@export var gift_id: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id,
		"project_id": project_id,
		"animal_id": animal_id,
		"start_unix": start_unix,
		"end_unix": end_unix,
		"focus_seconds": focus_seconds,
		"gift_id": gift_id,
	}


static func from_dict(d: Dictionary) -> FocusSession:
	var s := FocusSession.new()
	s.id = str(d.get("id", ""))
	s.project_id = str(d.get("project_id", ""))
	s.animal_id = str(d.get("animal_id", ""))
	s.start_unix = int(d.get("start_unix", 0))
	s.end_unix = int(d.get("end_unix", 0))
	s.focus_seconds = int(d.get("focus_seconds", 0))
	s.gift_id = str(d.get("gift_id", ""))
	return s
