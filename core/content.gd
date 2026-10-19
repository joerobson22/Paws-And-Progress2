extends Node
## Autoload "Content": the data-driven game content from res://data/.
## New animals, gifts and biomes are data edits, not code changes.

var animals: Array = []
var gifts: Array = []
var rarities: Array = []
var drop_table: Dictionary = {}
var biomes: Array = []
var times_of_day: Dictionary = {}

var _animals_by_id: Dictionary = {}
var _gifts_by_id: Dictionary = {}
var _rarities_by_id: Dictionary = {}


func _init() -> void:
	var a := _load("res://data/animals.json")
	animals = a.get("animals", [])
	var g := _load("res://data/gifts.json")
	gifts = g.get("gifts", [])
	rarities = g.get("rarities", [])
	drop_table = _load("res://data/drop_table.json")
	var b := _load("res://data/biomes.json")
	biomes = b.get("biomes", [])
	times_of_day = b.get("times_of_day", {})
	for x in animals:
		_animals_by_id[x["id"]] = x
	for x in gifts:
		_gifts_by_id[x["id"]] = x
	for x in rarities:
		_rarities_by_id[x["id"]] = x


func animal(id: String) -> Dictionary:
	return _animals_by_id.get(id, animals[0] if not animals.is_empty() else {})


func animal_default_colours(id: String) -> Array[Color]:
	var out: Array[Color] = []
	for c in animal(id).get("default_colours", []):
		out.append(Color.from_string(c, Color.WHITE))
	return out


func gift(id: String) -> Dictionary:
	return _gifts_by_id.get(id, {})


func gifts_for(animal_id: String) -> Array:
	return gifts.filter(func(g): return g["animal"] == animal_id)


func rarity_colour(rarity_id: String) -> Color:
	return Color.from_string(_rarities_by_id.get(rarity_id, {}).get("colour", "#888888"), Color.GRAY)


func rarity_name(rarity_id: String) -> String:
	return _rarities_by_id.get(rarity_id, {}).get("name", rarity_id.capitalize())


func biome(id: String) -> Dictionary:
	for b in biomes:
		if b["id"] == id:
			return b
	return biomes[0] if not biomes.is_empty() else {}


## Which time-of-day palette applies at this local hour.
func time_of_day(hour: int) -> String:
	var best := ""
	var best_from := -1
	var latest := ""
	var latest_from := -1
	for key in times_of_day:
		var from := int(times_of_day[key]["from_hour"])
		if from <= hour and from > best_from:
			best = key
			best_from = from
		if from > latest_from:
			latest = key
			latest_from = from
	# Before the earliest start (e.g. 3am) it's still the latest period (night).
	return best if best != "" else latest


func _load(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("Content: couldn't read %s" % path)
		return {}
	return data
