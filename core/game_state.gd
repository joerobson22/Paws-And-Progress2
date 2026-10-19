class_name GameState
extends RefCounted
## Everything that gets saved. SaveSystem turns this into JSON and back.

const COSMETIC_SLOTS: Array[String] = [
	"hat", "hair", "face", "jumper", "neckwear", "handwear", "walking_stick", "trousers",
]

var profile: Dictionary = default_profile()
var projects: Array[ProjectData] = []
var sessions: Array[FocusSession] = []
## gift_id -> how many the player has.
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
		"created_unix": 0,
		"skin_tone": 0,
		"hair_tone": 0,
		# slot -> equipped item id ("" = default look).
		"cosmetics": cosmetics,
		"walks_since_epic": 0,
		# Totals carried over from a v1 save, which kept no session history.
		"legacy_total_seconds": 0,
		"legacy_longest_seconds": 0,
		"legacy_best_week_seconds": 0,
	}


static func default_settings() -> Dictionary:
	return {
		"sound": true,
		"ambience": true,
		"reduce_motion": false,
		"theme": "auto",
		"keep_screen_on": true,
		# Last walk length picked on the walks screen; 0 = open-ended.
		"walk_goal_seconds": 3600,
		"walk_biome": "lake",
	}


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


func project_seconds(id: String) -> int:
	var total := 0
	var p := project(id)
	if p:
		total += p.legacy_seconds
	for s in sessions:
		if s.project_id == id:
			total += s.focus_seconds
	return total
