extends TestCase


func test_cast_is_eleven_animals() -> void:
	var animals: Array = load_json("res://data/animals.json")["animals"]
	eq(animals.size(), 11)
	var families := {}
	for a in animals:
		families[a["family"]] = int(families.get(a["family"], 0)) + 1
		eq(a["parts"].size(), a["default_colours"].size(), "%s colours per part" % a["id"])
	eq(families, {"dog": 5, "cat": 2, "rabbit": 1, "snail": 1, "bird": 1, "bear": 1})


func test_v1_mapping_points_at_real_animals() -> void:
	var ids: Array = load_json("res://data/animals.json")["animals"].map(func(a): return a["id"])
	for v in SaveSystem.V1_TO_V2.values():
		check(ids.has(v), "%s missing" % v)


func test_drop_tiers_ascend() -> void:
	var tiers: Array = load_json("res://data/drop_table.json")["tiers"]
	for i in range(1, tiers.size()):
		check(int(tiers[i]["min_seconds"]) > int(tiers[i - 1]["min_seconds"]))


func test_wearables_use_real_slots() -> void:
	var slots: Array = load_json("res://data/cosmetics.json")["slots"].map(func(x): return x["id"])
	eq(slots, Array(GameState.COSMETIC_SLOTS), "cosmetics.json lists the saved slots in order")
	for g in load_json("res://data/gifts.json")["gifts"]:
		if g.has("slot"):
			check(slots.has(g["slot"]), "%s slot %s" % [g["id"], g["slot"]])
			check(g.has("style"), "%s needs a style" % g["id"])
	for item in load_json("res://data/cosmetics.json")["items"]:
		check(slots.has(item["slot"]), "%s slot" % item["id"])
	for slot in slots:
		check(load_json("res://data/cosmetics.json")["items"].any(func(i): return i["slot"] == slot), "%s has a starter" % slot)


func test_grades_have_colours() -> void:
	var scales: Array = load_json("res://data/grades.json")["scales"]
	eq(scales.map(func(s): return s["id"]), ["gcse", "alevel", "uni"])
	eq(scales[0]["grades"].size(), 9, "GCSE 9 to 1")
	for scale in scales:
		for g in scale["grades"]:
			check(g.has("label") and g.has("colour") and g.has("ink"), "%s/%s" % [scale["id"], g["id"]])


func test_trade_costs() -> void:
	var r: Array = load_json("res://data/gifts.json")["rarities"]
	eq(r.map(func(x): return int(x.get("trade_in", 0))), [10, 5, 3, 0])


func test_every_animal_can_dive() -> void:
	for a in load_json("res://data/animals.json")["animals"]:
		check(a.has("dive") and a["dive"].has("hops") and a["dive"].has("seconds"), a["id"])
