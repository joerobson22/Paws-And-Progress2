extends TestCase

var table: Dictionary


func _init() -> void:
	table = load_json("res://data/levels.json")


func _session(seconds: int, gift_id: String = "") -> FocusSession:
	var s := FocusSession.new()
	s.focus_seconds = seconds
	s.gift_id = gift_id
	return s


func test_thresholds_grow() -> void:
	eq(Levels.xp_to_reach(1, table), 0)
	eq(Levels.xp_to_reach(2, table), 60, "an hour of focus for level 2")
	eq(Levels.xp_to_reach(3, table), 140)
	eq(Levels.xp_to_reach(4, table), 240)
	for level in range(2, 30):
		check(Levels.xp_to_reach(level + 1, table) - Levels.xp_to_reach(level, table) > Levels.xp_to_reach(level, table) - Levels.xp_to_reach(level - 1, table), "level %d takes longer than the last" % level)


func test_level_and_progress() -> void:
	eq(Levels.level_for(0, table), 1)
	eq(Levels.level_for(59, table), 1)
	eq(Levels.level_for(60, table), 2)
	eq(Levels.progress(100, table), {"level": 2, "into": 40, "needed": 80})


func test_walk_xp_is_minutes_plus_gift_bonus() -> void:
	eq(Levels.walk_xp(25 * 60 + 59, "", table), 25)
	eq(Levels.walk_xp(25 * 60, "rare", table), 25 + int(table["gift_bonus"]["rare"]))


func test_total_xp_from_the_log() -> void:
	var rarity := func(id: String) -> String: return "epic" if id == "x" else "common"
	var s := [_session(600, "y"), _session(3600, "x"), _session(90)]
	var expected := 10 + int(table["gift_bonus"]["common"]) + 60 + int(table["gift_bonus"]["epic"]) + 1
	eq(Levels.total_xp(s, 0, table, rarity), expected)
	eq(Levels.total_xp([], 7200, table, rarity), 120, "time carried over from v1 counts")


func test_unlocks() -> void:
	eq(Levels.unlock_level("place", "lake", table), 1, "lakeside from the start")
	eq(Levels.unlock_level("animal", "staffy", table), 1)
	eq(Levels.unlock_level("place", "forest", table), 3)
	var levels: Array = Levels.rewards(table).map(func(r): return int(r["level"]))
	var sorted := levels.duplicate()
	sorted.sort()
	eq(levels, sorted, "rewards in level order")


func test_rewards_name_real_things() -> void:
	var animals: Array = load_json("res://data/animals.json")["animals"].map(func(a): return a["id"])
	var places: Array = load_json("res://data/biomes.json")["biomes"].map(func(b): return b["id"])
	for r in Levels.rewards(table):
		check((animals if r["type"] == "animal" else places).has(r["id"]), "%s %s" % [r["type"], r["id"]])
	eq(places, ["lake", "forest", "jungle", "tundra", "desert", "beach", "moon"], "the seven places")
	var at_start := places.filter(func(id): return Levels.unlock_level("place", id, table) == 1)
	eq(at_start, ["lake"], "only lakeside to begin with")
