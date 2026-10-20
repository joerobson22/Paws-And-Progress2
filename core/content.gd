extends Node
## Autoload "Content": the data-driven game content from res://data/.
## New animals, gifts, cosmetics, grades and biomes are data edits, not code changes.

var animals: Array = []
var gifts: Array = []
var rarities: Array = []
var drop_table: Dictionary = {}
var biomes: Array = []
var times_of_day: Dictionary = {}
var grade_scales: Array = []
var quotes: Array = []
## [{id, name}] in the order the customise popup lists them.
var cosmetic_slots: Array = []
## Starter wardrobe items; wearable gifts are cosmetics too (see cosmetic()).
var cosmetic_items: Array = []
var skin_tones: Array[Color] = []
var hair_tones: Array[Color] = []

var _animals_by_id: Dictionary = {}
var _gifts_by_id: Dictionary = {}
var _rarities_by_id: Dictionary = {}
var _items_by_id: Dictionary = {}


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
	grade_scales = _load("res://data/grades.json").get("scales", [])
	quotes = _load("res://data/quotes.json").get("quotes", [])
	var c := _load("res://data/cosmetics.json")
	cosmetic_slots = c.get("slots", [])
	cosmetic_items = c.get("items", [])
	for hex in c.get("skin_tones", []):
		skin_tones.append(Color.from_string(hex, Color.WHITE))
	for hex in c.get("hair_tones", []):
		hair_tones.append(Color.from_string(hex, Color.BLACK))
	for x in animals:
		_animals_by_id[x["id"]] = x
	for x in gifts:
		_gifts_by_id[x["id"]] = x
	for x in rarities:
		_rarities_by_id[x["id"]] = x
	for x in cosmetic_items:
		_items_by_id[x["id"]] = x


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


## A darker shade of the rarity colour that reads as text on a light background.
func rarity_text_colour(rarity_id: String) -> Color:
	return Color.from_string(_rarities_by_id.get(rarity_id, {}).get("text_colour", "#5e5e52"), Color.DIM_GRAY)


func rarity_name(rarity_id: String) -> String:
	return _rarities_by_id.get(rarity_id, {}).get("name", rarity_id.capitalize())


## How many of a gift of this rarity trade up for one of the next rarity; 0 = can't trade.
func trade_cost(rarity_id: String) -> int:
	return int(_rarities_by_id.get(rarity_id, {}).get("trade_in", 0))


## The rarity one step up, or "" for the top one.
func next_rarity(rarity_id: String) -> String:
	var i := GiftRoller.RARITIES.find(rarity_id)
	return GiftRoller.RARITIES[i + 1] if i >= 0 and i < GiftRoller.RARITIES.size() - 1 else ""


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


# --- Grades ------------------------------------------------------------------

## A grade from its saved reference ("gcse/9"), with "scale" and "scale_name"
## added; empty if there's no such grade.
func grade(ref: String) -> Dictionary:
	var bits := ref.split("/", true, 1)
	if bits.size() != 2:
		return {}
	for scale in grade_scales:
		if scale["id"] != bits[0]:
			continue
		for g in scale["grades"]:
			if g["id"] == bits[1]:
				var out: Dictionary = g.duplicate()
				out["scale"] = scale["id"]
				out["scale_name"] = scale["name"]
				out["ref"] = ref
				return out
	return {}


# --- Quotes ------------------------------------------------------------------

## The same quote for the same seed, so a walk keeps its quote across restarts.
func quote(seed: int) -> String:
	if quotes.is_empty():
		return ""
	return str(quotes[posmod(seed, quotes.size())])


# --- Cosmetics ---------------------------------------------------------------

func slot_name(slot: String) -> String:
	for s in cosmetic_slots:
		if s["id"] == slot:
			return s["name"]
	return slot.capitalize()


## A starter item or a wearable gift by id; empty if it's neither.
func cosmetic(id: String) -> Dictionary:
	if _items_by_id.has(id):
		return _items_by_id[id]
	var g := gift(id)
	return g if g.has("slot") else {}


## What the slot shows when nothing's picked: its first starter item.
func default_cosmetic(slot: String) -> Dictionary:
	for item in cosmetic_items:
		if item["slot"] == slot:
			return item
	return {}


## Everything that can be worn in a slot: the starters, then wearable gifts
## the player owns.
func cosmetic_options(slot: String, inventory: Dictionary) -> Array:
	var out: Array = cosmetic_items.filter(func(i): return i["slot"] == slot)
	for g in gifts:
		if g.get("slot", "") == slot and int(inventory.get(g["id"], 0)) > 0:
			out.append(g)
	return out


## The colour an item is drawn in: its own, else its rarity's for a gift.
func cosmetic_colour(item: Dictionary, fallback: Color) -> Color:
	if item.has("colour"):
		return Color.from_string(item["colour"], fallback)
	if item.has("rarity"):
		return rarity_colour(item["rarity"])
	return fallback


func _load(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("Content: couldn't read %s" % path)
		return {}
	return data
