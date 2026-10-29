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


## Grades sort best first across scales: each scale spreads over the five
## university classes, and within one of those university comes first.
func test_grade_rank_orders_across_scales() -> void:
	var content: Node = load("res://core/content.gd").new()
	var refs := ["gcse/4", "", "alevel/a", "uni/upper_second", "gcse/9", "uni/first", "alevel/a_star", "gcse/8", "uni/fail"]
	refs.sort_custom(func(a, b): return content.grade_rank(a) < content.grade_rank(b))
	eq(refs, ["uni/first", "alevel/a_star", "gcse/9", "uni/upper_second", "alevel/a", "gcse/8", "gcse/4", "uni/fail", ""])
	content.free()


## Art is found by convention, so a typo'd path would silently show the placeholder.
func test_art_paths_are_well_formed() -> void:
	for a in load_json("res://data/animals.json")["animals"]:
		var dir: String = a["sprite_dir"]
		check(dir.begins_with("res://art/animals/") and dir.ends_with("/"), "%s sprite_dir %s" % [a["id"], dir])
		if ResourceLoader.exists(dir + "animal.tscn"):
			check(a["parts"].size() <= 3, "%s: the shader maps three colours" % a["id"])
	for b in load_json("res://data/biomes.json")["biomes"]:
		for layer in b["layers"]:
			if layer.has("art"):
				check(ResourceLoader.exists(layer["art"]), "%s art %s" % [b["id"], layer["art"]])
	check(ResourceLoader.exists("res://art/animal_colours.gdshader"))
	check(load("res://art/templates/animal/animal.tscn") is PackedScene, "the animal template loads")
	check(load("res://art/templates/scenery/tile.tscn") is PackedScene, "the scenery template loads")


## An item's art folder is named after the item and its files after limbs, or the art silently never shows.
func test_cosmetic_art_folders_match_items() -> void:
	var ids := {}
	for item in load_json("res://data/cosmetics.json")["items"]:
		ids[item["id"]] = true
	for g in load_json("res://data/gifts.json")["gifts"]:
		if g.has("slot"):
			ids[g["id"]] = true
	var stems := ["torso", "head", "arm_back", "arm_front", "leg_back", "leg_front"]
	for root in ["res://art/cosmetics/", "res://art/templates/cosmetics/"]:
		var dir := DirAccess.open(root)
		if dir == null:
			continue
		for folder in dir.get_directories():
			check(ids.has(folder), "%s%s isn't a cosmetic's id" % [root, folder])
			for file in DirAccess.get_files_at(root + folder):
				if file.get_extension() in ["png", "svg", "webp"]:
					var stem := file.get_basename().trim_suffix("_behind").trim_suffix("_sad")
					check(stems.has(stem), "%s%s/%s isn't a limb" % [root, folder, file])
