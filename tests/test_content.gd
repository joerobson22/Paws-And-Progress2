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
