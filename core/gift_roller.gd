class_name GiftRoller
extends RefCounted
## Rolls the end-of-walk gift from the data-driven drop table (data/drop_table.json).

const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]


## The odds for a walk of this length, or an empty Dictionary if it earns no gift.
static func weights_for(seconds: int, table: Dictionary) -> Dictionary:
	if seconds < int(table.get("min_seconds", 600)):
		return {}
	var best: Dictionary = {}
	for tier in table.get("tiers", []):
		if seconds >= int(tier["min_seconds"]):
			best = tier["weights"]
	return best


## Odds as whole percentages, for showing on the walk screen.
static func percentages_for(seconds: int, table: Dictionary) -> Dictionary:
	var w := weights_for(seconds, table)
	var out := {}
	var total := 0.0
	for r in RARITIES:
		total += float(w.get(r, 0))
	for r in RARITIES:
		out[r] = 0 if total <= 0.0 else roundi(100.0 * float(w.get(r, 0)) / total)
	return out


static func is_pity_ready(seconds: int, walks_since_epic: int, table: Dictionary) -> bool:
	return seconds >= int(table.get("pity_min_seconds", 1800)) \
		and walks_since_epic >= int(table.get("pity_walks", 8))


## Returns {"rarity", "gift_id", "pity"} or an empty Dictionary when no gift is earned.
## `gifts` is the list of gift dictionaries from data/gifts.json.
static func roll(seconds: int, animal_id: String, walks_since_epic: int, table: Dictionary,
		gifts: Array, rng: RandomNumberGenerator) -> Dictionary:
	var weights := weights_for(seconds, table)
	if weights.is_empty():
		return {}

	var pity := is_pity_ready(seconds, walks_since_epic, table)
	var candidates: Array[String] = RARITIES.duplicate()
	if pity:
		candidates = ["epic", "legendary"]
		if float(weights.get("epic", 0)) + float(weights.get("legendary", 0)) <= 0.0:
			weights = {"epic": 1}

	var rarity := _weighted_pick(candidates, weights, rng)
	var pool: Array = gifts.filter(func(g): return g["animal"] == animal_id and g["rarity"] == rarity)
	if pool.is_empty():
		return {}
	var gift: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return {"rarity": rarity, "gift_id": gift["id"], "pity": pity}


## Updates the pity counter after a walk.
static func next_pity_count(current: int, seconds: int, rolled_rarity: String, table: Dictionary) -> int:
	if rolled_rarity == "epic" or rolled_rarity == "legendary":
		return 0
	if seconds >= int(table.get("pity_min_seconds", 1800)):
		return current + 1
	return current


static func _weighted_pick(candidates: Array[String], weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for r in candidates:
		total += float(weights.get(r, 0))
	var roll_value := rng.randf() * total
	for r in candidates:
		var w := float(weights.get(r, 0))
		if w <= 0.0:
			continue
		if roll_value < w:
			return r
		roll_value -= w
	# Floating point edge: fall back to the last candidate with any weight.
	for i in range(candidates.size() - 1, -1, -1):
		if float(weights.get(candidates[i], 0)) > 0.0:
			return candidates[i]
	return candidates[0]
