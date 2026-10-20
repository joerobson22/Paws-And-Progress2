class_name SaveSystem
extends RefCounted
## Versioned JSON save with migrations, atomic writes, a backup copy, and
## import of a v1 `gamedata.save`.

const CURRENT_VERSION := 2
const SAVE_PATH := "user://save.json"

## v1 animal order (global.gd `animals`), mapped to the v2 cast.
## The guinea pig and Nigel aren't in v2; their projects move to the closest fit.
const V1_ANIMALS: Array[String] = [
	"dog1", "dog2", "dog3", "cat1", "guinea_pig1", "bear1",
	"rabbit", "dog4", "bird1", "snail", "dog5", "nigel",
]
const V1_TO_V2 := {
	"dog1": "staffy",
	"dog2": "spaniel",
	"dog3": "labrador",
	"cat1": "tabby_cat",
	"guinea_pig1": "rabbit",
	"bear1": "bear",
	"rabbit": "rabbit",
	"dog4": "cockapoo",
	"bird1": "bird",
	"snail": "snail",
	"dog5": "bernese",
	"nigel": "black_cat",
}
const V1_RARITIES: Array[String] = ["common", "rare", "epic"]
## v1's cosmetic slots in its save order, by their v2 names.
const V1_COSMETIC_SLOTS: Array[String] = [
	"hat", "hair", "face", "top", "neckwear", "gloves", "walking_stick", "trousers",
]
## Cosmetic slots renamed in save version 2.
const RENAMED_SLOTS_V2 := {"jumper": "top", "handwear": "gloves"}


# --- Serialisation -----------------------------------------------------------

static func to_dict(state: GameState) -> Dictionary:
	var projects: Array = []
	for p in state.projects:
		projects.append(p.to_dict())
	var sessions: Array = []
	for s in state.sessions:
		sessions.append(s.to_dict())
	return {
		"version": CURRENT_VERSION,
		"profile": state.profile,
		"projects": projects,
		"sessions": sessions,
		"inventory": state.inventory,
		"active": state.active.to_dict() if state.active else null,
		"settings": state.settings,
	}


static func from_dict(raw: Dictionary) -> GameState:
	var d := migrate(raw)
	var state := GameState.new()
	state.profile.merge(d.get("profile", {}), true)
	var cosmetics: Dictionary = GameState.default_profile()["cosmetics"]
	cosmetics.merge(state.profile.get("cosmetics", {}), true)
	state.profile["cosmetics"] = cosmetics
	for k in ["created_unix", "skin_tone", "hair_tone", "walks_since_epic",
			"legacy_total_seconds", "legacy_longest_seconds", "legacy_best_week_seconds"]:
		state.profile[k] = int(state.profile[k])
	state.profile["username"] = str(state.profile["username"])
	state.profile["institution"] = str(state.profile["institution"])
	state.profile["shelf"] = state.shelf()
	for p in d.get("projects", []):
		state.projects.append(ProjectData.from_dict(p))
	for s in d.get("sessions", []):
		state.sessions.append(FocusSession.from_dict(s))
	for gift_id in d.get("inventory", {}):
		state.inventory[gift_id] = int(d["inventory"][gift_id])
	var active = d.get("active")
	if active is Dictionary:
		state.active = SessionClock.from_dict(active)
	state.settings.merge(d.get("settings", {}), true)
	return state


## Upgrades an older save dictionary to CURRENT_VERSION, one step at a time.
static func migrate(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var version := int(out.get("version", 1))
	while version < CURRENT_VERSION:
		match version:
			1:
				out = _migrate_1_to_2(out)
			_:
				pass
		version += 1
		out["version"] = version
	return out


## Version 2 renamed the jumper and handwear slots to top and gloves.
static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	var profile: Dictionary = d.get("profile", {})
	var cosmetics: Dictionary = profile.get("cosmetics", {})
	for old in RENAMED_SLOTS_V2:
		if cosmetics.has(old):
			var new_slot: String = RENAMED_SLOTS_V2[old]
			if str(cosmetics.get(new_slot, "")) == "":
				cosmetics[new_slot] = cosmetics[old]
			cosmetics.erase(old)
	return d


# --- Files -------------------------------------------------------------------

## Writes to a temp file then swaps it in, keeping the previous save as .bak,
## so a crash mid-write can never leave a half-written save.
static func write(state: GameState, path: String = SAVE_PATH) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(state), "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path)


## Returns the saved state, falling back to the backup if the main file is
## damaged, or null when there's no save at all.
static func read(path: String = SAVE_PATH) -> GameState:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary:
			return from_dict(parsed)
		push_warning("Save file %s is damaged, trying backup" % candidate)
	return null


## Where v1 kept its save on desktop: a sibling of this app's user data folder.
static func v1_save_path() -> String:
	return OS.get_user_data_dir().get_base_dir().path_join("Paws-And-Progress").path_join("gamedata.save")


# --- v1 import ---------------------------------------------------------------

## Converts the text of a v1 `gamedata.save` (one JSON object per line: the
## player, then each project, then "END_PROJECTS") into a GameState.
static func import_v1(text: String, now: int) -> GameState:
	var state := GameState.new()
	state.profile["created_unix"] = now
	var lines := text.split("\n", false)
	if lines.is_empty():
		return state

	var player = JSON.parse_string(lines[0])
	if player is Dictionary:
		_import_v1_player(player, state, now)

	for i in range(1, lines.size()):
		var data = JSON.parse_string(lines[i])
		if data is String and data == "END_PROJECTS":
			break
		if data is Dictionary:
			state.projects.append(_import_v1_project(data, state.projects.size(), now))
	return state


static func _import_v1_player(g: Dictionary, state: GameState, now: int) -> void:
	var p := state.profile
	p["username"] = str(g.get("username", ""))
	p["legacy_total_seconds"] = int(g.get("totalFocusTime", 0))
	p["legacy_longest_seconds"] = int(g.get("longestFocusTime", 0))
	p["legacy_best_week_seconds"] = int(g.get("weeklyFocusPB", 0))
	p["skin_tone"] = int(g.get("skinColour", 0))
	p["hair_tone"] = int(g.get("hairColour", 0))
	var joined = g.get("dateJoined")
	if joined is Dictionary:
		p["created_unix"] = _unix_from_date(int(joined.get("year", 0)), int(joined.get("month", 0)), int(joined.get("day", 0)), now)

	# v1 stored cosmetics as style indices per slot; keep them as "v1:<index>"
	# until the wardrobe maps them to real item ids.
	var cosmetics: Array = g.get("cosmetics", [])
	for i in mini(cosmetics.size(), V1_COSMETIC_SLOTS.size()):
		if int(cosmetics[i]) > 0:
			p["cosmetics"][V1_COSMETIC_SLOTS[i]] = "v1:%d" % int(cosmetics[i])

	# v1 gifts: a flat array of counts, index = animal * 3 + rarity.
	var gifts: Array = g.get("gifts", [])
	for i in gifts.size():
		var count := int(gifts[i])
		var animal_index := i / 3
		if count <= 0 or animal_index >= V1_ANIMALS.size():
			continue
		var gift_id := "%s_%s" % [V1_TO_V2[V1_ANIMALS[animal_index]], V1_RARITIES[i % 3]]
		state.inventory[gift_id] = int(state.inventory.get(gift_id, 0)) + count

	state.settings["sound"] = not bool(g.get("audioMuted", false))


static func _import_v1_project(d: Dictionary, index: int, now: int) -> ProjectData:
	var p := ProjectData.new()
	p.id = "v1_%d" % index
	p.name = str(d.get("projectName", "Project"))
	var animal_index := int(d.get("animal", 0))
	p.animal_id = V1_TO_V2[V1_ANIMALS[clampi(animal_index, 0, V1_ANIMALS.size() - 1)]]
	for part in ["part1", "part2", "part3"]:
		p.colours.append(Color(float(d.get(part + "R", 1.0)), float(d.get(part + "G", 1.0)), float(d.get(part + "B", 1.0))))
	p.legacy_seconds = int(d.get("totalFocusTime", 0))
	p.created_unix = _unix_from_v1_date(str(d.get("dateStarted", "")), now)
	if bool(d.get("complete", false)):
		p.completed_unix = _unix_from_v1_date(str(d.get("dateFinished", "")), now)
	return p


## v1 dates are "d/m/yyyy" strings.
static func _unix_from_v1_date(s: String, fallback: int) -> int:
	var bits := s.split("/")
	if bits.size() != 3 or not bits[0].is_valid_int() or not bits[1].is_valid_int() or not bits[2].is_valid_int():
		return fallback
	return _unix_from_date(int(bits[2]), int(bits[1]), int(bits[0]), fallback)


static func _unix_from_date(year: int, month: int, day: int, fallback: int) -> int:
	if year < 1970 or month < 1 or month > 12 or day < 1 or day > 31:
		return fallback
	return Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 12, "minute": 0, "second": 0})
