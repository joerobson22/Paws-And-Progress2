class_name Achievements
extends RefCounted
## The profile's achievements: total hours focused (10 up to 10,000), every
## gift found, and every gift from each animal. What they are and what
## they're called is in data/achievements.json; whether you have one is
## worked out from the walk log and the gifts you've found, never stored.


## Every achievement in order: {id, name, description, kind ("hours",
## "all_gifts" or "animal"), goal (hours, or gifts to find), icon, animal}.
static func list(data: Dictionary, animals: Array, gifts: Array) -> Array:
	var out := []
	for f in data.get("focus", []):
		var hours := int(f["hours"])
		out.append({"id": f["id"], "name": f["name"], "kind": "hours", "goal": hours, "icon": "clock", "animal": "",
			"description": "Focus for %s hours in total" % _grouped(hours)})
	var all: Dictionary = data.get("all_gifts", {})
	out.append({"id": all.get("id", "all_gifts"), "name": all.get("name", "Full collection"), "kind": "all_gifts",
		"goal": gifts.size(), "icon": "gift", "animal": "", "description": "Find every gift"})
	var each: Dictionary = data.get("animal_gifts", {})
	for a in animals:
		var count := gifts.filter(func(g): return g["animal"] == a["id"]).size()
		if count == 0:
			continue
		out.append({"id": "animal_%s" % a["id"], "name": str(each.get("name", "{animal} set")).replace("{animal}", a["name"]),
			"kind": "animal", "goal": count, "icon": "", "animal": a["id"],
			"description": "Find all %d of the %s's gifts" % [count, str(a["name"]).to_lower()]})
	return out


## How far along each one is: the list again with "have" (whole hours, or
## gifts found, never more than the goal) and "earned" added. `found` is
## every gift id you've ever had.
static func progress(achievements: Array, focused_seconds: int, found: Array, gifts: Array) -> Array:
	var seen := {}
	for id in found:
		seen[id] = true
	var out := []
	for a in achievements:
		var have := 0
		match str(a["kind"]):
			"hours":
				have = floori(focused_seconds / 3600.0)
			"all_gifts":
				have = gifts.filter(func(g): return seen.has(g["id"])).size()
			"animal":
				have = gifts.filter(func(g): return g["animal"] == a["animal"] and seen.has(g["id"])).size()
		var row: Dictionary = a.duplicate()
		row["have"] = mini(have, int(a["goal"]))
		row["earned"] = int(a["goal"]) > 0 and have >= int(a["goal"])
		out.append(row)
	return out


## 10000 as "10,000".
static func _grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
