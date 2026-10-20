class_name Levels
extends RefCounted
## XP and levels, from data/levels.json. Like every stat, XP is worked out
## from the walk log rather than kept as a running total, so it can never
## drift: minutes focused, plus a bonus for each walk's gift.


## XP for one walk of `seconds` that brought a gift of `rarity` ("" for none).
static func walk_xp(seconds: int, rarity: String, table: Dictionary) -> int:
	@warning_ignore("integer_division")
	var xp := (seconds / 60) * int(table.get("xp_per_minute", 1))
	return xp + int(table.get("gift_bonus", {}).get(rarity, 0))


## All the XP in a save. `rarity_of` turns a gift id into its rarity.
static func total_xp(sessions: Array, legacy_seconds: int, table: Dictionary, rarity_of: Callable) -> int:
	@warning_ignore("integer_division")
	var xp := (legacy_seconds / 60) * int(table.get("xp_per_minute", 1))
	for s in sessions:
		xp += walk_xp(s.focus_seconds, rarity_of.call(s.gift_id) if s.gift_id != "" else "", table)
	return xp


## Total XP needed to reach `level` (level 1 needs none).
static func xp_to_reach(level: int, table: Dictionary) -> int:
	var base := int(table.get("xp_base", 60))
	var growth := int(table.get("xp_growth", 20))
	var n := maxi(0, level - 1)
	# Sum of base + growth * k for k = 0 .. n - 1.
	@warning_ignore("integer_division")
	return n * base + growth * n * (n - 1) / 2


static func level_for(xp: int, table: Dictionary) -> int:
	var level := 1
	while xp >= xp_to_reach(level + 1, table):
		level += 1
	return level


## Where `xp` sits: {level, into: XP into this level, needed: XP the level takes}.
static func progress(xp: int, table: Dictionary) -> Dictionary:
	var level := level_for(xp, table)
	var start := xp_to_reach(level, table)
	return {"level": level, "into": xp - start, "needed": xp_to_reach(level + 1, table) - start}


## The level an animal or place ("animal" / "place") unlocks at; 1 if it's
## there from the start.
static func unlock_level(type: String, id: String, table: Dictionary) -> int:
	for r in table.get("rewards", []):
		if r["type"] == type and r["id"] == id:
			return int(r["level"])
	return 1


## Every reward in level order: [{level, type, id}].
static func rewards(table: Dictionary) -> Array:
	var out: Array = table.get("rewards", []).duplicate()
	out.sort_custom(func(a, b): return int(a["level"]) < int(b["level"]))
	return out
