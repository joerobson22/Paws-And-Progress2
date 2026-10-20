extends TestCase

const PATH := "user://test_save.json"


func _cleanup() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _sample() -> GameState:
	var s := GameState.new()
	s.profile["username"] = "joe"
	var p := ProjectData.new()
	p.id = "p1"
	p.name = "Dissertation"
	p.pet_name = "Biscuit"
	p.animal_id = "staffy"
	p.colours = [Color("#112233"), Color("#445566"), Color("#778899")]
	s.projects.append(p)
	var f := FocusSession.new()
	f.id = "s1"
	f.project_id = "p1"
	f.focus_seconds = 1234
	f.gift_id = "staffy_common"
	s.sessions.append(f)
	s.inventory["staffy_common"] = 2
	s.active = SessionClock.begin("p1", 500)
	return s


func test_round_trip() -> void:
	_cleanup()
	eq(SaveSystem.write(_sample(), PATH), OK)
	var back := SaveSystem.read(PATH)
	check(back != null)
	eq(back.profile["username"], "joe")
	eq(back.projects[0].name, "Dissertation")
	eq(back.projects[0].pet_name, "Biscuit")
	eq(back.projects[0].colours[1].to_html(false), "445566")
	eq(back.sessions[0].focus_seconds, 1234)
	eq(back.inventory["staffy_common"], 2)
	eq(back.active.start_unix, 500)
	_cleanup()


func test_damaged_save_falls_back_to_backup() -> void:
	_cleanup()
	SaveSystem.write(_sample(), PATH)
	SaveSystem.write(_sample(), PATH) # second write leaves a .bak
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var back := SaveSystem.read(PATH)
	check(back != null, "backup used")
	eq(back.projects.size(), 1)
	_cleanup()


func test_missing_save_is_null() -> void:
	_cleanup()
	check(SaveSystem.read(PATH) == null)


func test_old_saves_get_new_fields() -> void:
	var back := SaveSystem.from_dict({"version": 1, "profile": {"username": "x"}})
	eq(back.profile["walks_since_epic"], 0)
	eq(back.settings["sound"], true)
	check(back.profile["cosmetics"].has("hat"))


func test_v1_save_migrates_slots() -> void:
	var back := SaveSystem.from_dict({"version": 1, "profile": {"cosmetics": {"jumper": "staffy_epic", "handwear": "rabbit_epic", "hat": "bird_epic"}}})
	eq(back.profile["cosmetics"]["top"], "staffy_epic")
	eq(back.profile["cosmetics"]["gloves"], "rabbit_epic")
	eq(back.profile["cosmetics"]["hat"], "bird_epic")
	check(not back.profile["cosmetics"].has("jumper"), "old slot gone")
	eq(back.profile["shelf"], ["", "", ""])


func test_shelf_round_trip_and_moves() -> void:
	var s := _sample()
	s.place_on_shelf("staffy_common", 2)
	s.place_on_shelf("bear_rare", 0)
	eq(s.shelf(), ["bear_rare", "", "staffy_common"])
	s.place_on_shelf("staffy_common", 0)
	eq(s.shelf(), ["staffy_common", "", "bear_rare"], "moving swaps")
	s.remove_from_shelf(2)
	eq(s.shelf(), ["staffy_common", "", ""])
	var back := SaveSystem.from_dict(SaveSystem.to_dict(s))
	eq(back.shelf(), ["staffy_common", "", ""])


func test_traded_away_gifts_leave_shelf_and_wardrobe() -> void:
	var s := _sample()
	s.inventory["bear_epic"] = 0
	s.place_on_shelf("bear_epic", 1)
	s.place_on_shelf("staffy_common", 0)
	s.profile["cosmetics"]["walking_stick"] = "bear_epic"
	s.tidy_gift_references()
	eq(s.shelf(), ["staffy_common", "", ""])
	eq(s.profile["cosmetics"]["walking_stick"], "")


func test_import_v1() -> void:
	var player := {
		"username": "Joe", "totalFocusTime": 90000, "longestFocusTime": 7200, "weeklyFocusPB": 30000,
		"skinColour": 2, "hairColour": 1, "audioMuted": true,
		"cosmetics": [0, 3, 0, 1, 0, 0, 0, 0],
		"dateJoined": {"year": 2024, "month": 9, "day": 1},
		# dog1 common x2, nigel epic x1
		"gifts": [2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1],
	}
	var proj := {"projectName": "Maths", "animalName": "Tilly", "animal": 7, "totalFocusTime": 3600, "complete": false,
		"dateStarted": "5/10/2024", "dateFinished": "N/A",
		"part1R": 1.0, "part1G": 0.0, "part1B": 0.0, "part2R": 0.0, "part2G": 1.0, "part2B": 0.0, "part3R": 0.0, "part3G": 0.0, "part3B": 1.0}
	var done := proj.duplicate()
	done["projectName"] = "Physics"
	done["animal"] = 4
	done["complete"] = true
	done["dateFinished"] = "1/12/2024"
	var text := "\n".join([JSON.stringify(player), JSON.stringify(proj), JSON.stringify(done), JSON.stringify("END_PROJECTS")])

	var s := SaveSystem.import_v1(text, 1)
	eq(s.profile["username"], "Joe")
	eq(s.profile["legacy_total_seconds"], 90000)
	eq(s.profile["legacy_best_week_seconds"], 30000)
	eq(s.profile["cosmetics"]["hair"], "v1:3")
	eq(s.profile["cosmetics"]["top"], "v1:1", "v1 jumper slot is now top")
	eq(s.settings["sound"], false)
	eq(s.inventory, {"staffy_common": 2, "black_cat_epic": 1})
	eq(s.projects.size(), 2)
	eq(s.projects[0].name, "Maths")
	eq(s.projects[0].pet_name, "Tilly", "v1 animal names carry over")
	eq(s.projects[0].animal_id, "cockapoo")
	eq(s.projects[0].legacy_seconds, 3600)
	eq(s.projects[0].colours[0], Color(1, 0, 0))
	check(not s.projects[0].is_complete())
	eq(s.projects[1].animal_id, "rabbit", "guinea pig moves to rabbit")
	check(s.projects[1].is_complete())
	eq(Time.get_date_string_from_unix_time(s.projects[1].completed_unix), "2024-12-01")
	eq(s.project_seconds(s.projects[0].id), 3600)
