class_name GameState
extends RefCounted
## Everything that gets saved. SaveSystem turns this into JSON and back.

## Character slots, in the order the customise popup lists them (data/cosmetics.json).
const COSMETIC_SLOTS: Array[String] = [
	"hat", "hair", "face", "neckwear", "top", "gloves", "walking_stick", "trousers", "shoes",
]
const SHELF_SIZE := 3

var profile: Dictionary = default_profile()
var projects: Array[ProjectData] = []
var sessions: Array[FocusSession] = []
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
		"created_unix": 0,
		"skin_tone": 0,
		"hair_tone": 0,
		# slot -> equipped item id ("" = the slot's default look).
		"cosmetics": cosmetics,
		# Favourite gifts on the gift shelf, left to right ("" = empty spot).
		"shelf": empty_shelf(),
		"walks_since_epic": 0,
		# Totals carried over from a v1 save, which kept no session history.
		"legacy_total_seconds": 0,
		"legacy_longest_seconds": 0,
		"legacy_best_week_seconds": 0,
		# A new save slot asks for a name and where you study first.
		"setup_pending": false,
	}


static func default_settings() -> Dictionary:
	return {
		"sound": true,
		"ambience": true,
		"reduce_motion": false,
		"theme": "auto",
		"keep_screen_on": true,
		# 0 = open-ended walk.
		"walk_goal_seconds": 0,
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


func project_seconds(id: String) -> int:
	var total := 0
	var p := project(id)
	if p:
		total += p.legacy_seconds
	for s in sessions:
		if s.project_id == id:
			total += s.focus_seconds
	return total


## gift_id -> how many walks on this project brought that gift.
func project_gifts(id: String) -> Dictionary:
	var out := {}
	for s in sessions:
		if s.project_id == id and s.gift_id != "":
			out[s.gift_id] = int(out.get(s.gift_id, 0)) + 1
	return out


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
