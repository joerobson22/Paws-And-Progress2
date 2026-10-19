extends TestCase

var table: Dictionary
var gifts: Array


func _init() -> void:
	table = load_json("res://data/drop_table.json")
	gifts = load_json("res://data/gifts.json")["gifts"]


func test_no_gift_under_ten_minutes() -> void:
	var rng := RandomNumberGenerator.new()
	eq(GiftRoller.roll(599, "staffy", 0, table, gifts, rng), {})
	check(not GiftRoller.roll(600, "staffy", 0, table, gifts, rng).is_empty(), "gift at exactly 10 minutes")


func test_legendary_only_from_45_minutes() -> void:
	eq(GiftRoller.percentages_for(2699, table)["legendary"], 0)
	check(GiftRoller.percentages_for(2700, table)["legendary"] > 0)


func test_gift_matches_animal_and_rarity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 200:
		var r := GiftRoller.roll(4 * 3600, "bear", 0, table, gifts, rng)
		var g: Dictionary = gifts.filter(func(x): return x["id"] == r["gift_id"])[0]
		eq(g["animal"], "bear")
		eq(g["rarity"], r["rarity"])


func test_distribution_roughly_matches_table() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	for i in 20000:
		counts[GiftRoller.roll(3600, "staffy", 0, table, gifts, rng)["rarity"]] += 1
	# 1 hour tier is 60 / 32 / 6 / 2.
	check(absf(counts["common"] / 20000.0 - 0.60) < 0.02, "common %s" % counts)
	check(absf(counts["legendary"] / 20000.0 - 0.02) < 0.01, "legendary %s" % counts)


func test_pity_guarantees_epic_or_better() -> void:
	var rng := RandomNumberGenerator.new()
	for i in 100:
		var r := GiftRoller.roll(1800, "snail", int(table["pity_walks"]), table, gifts, rng)
		check(r["rarity"] == "epic" or r["rarity"] == "legendary", "pity gave %s" % r["rarity"])
		check(r["pity"])


func test_pity_counter() -> void:
	eq(GiftRoller.next_pity_count(3, 1800, "common", table), 4)
	eq(GiftRoller.next_pity_count(3, 900, "common", table), 3, "short walks don't count")
	eq(GiftRoller.next_pity_count(3, 1800, "epic", table), 0)


func test_every_animal_has_a_gift_per_rarity() -> void:
	for a in load_json("res://data/animals.json")["animals"]:
		for rarity in GiftRoller.RARITIES:
			var n := gifts.filter(func(g): return g["animal"] == a["id"] and g["rarity"] == rarity).size()
			eq(n, 1, "%s %s" % [a["id"], rarity])
		var wearable := gifts.filter(func(g): return g["animal"] == a["id"] and g.has("slot")).size()
		eq(wearable, 2, "%s wearables" % a["id"])
