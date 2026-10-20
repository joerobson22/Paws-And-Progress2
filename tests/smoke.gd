extends SceneTree
## Smoke run: boots the real app, fills it with sample data and visits every
## pane, popup and full-screen flow (including a real swipe and a full walk
## with a gift), so script errors in UI code show up in CI.
##   godot --headless --path . -s tests/smoke.gd
## Optional: --shots=<dir> saves a screenshot per step (needs a display).

var _shots_dir := ""
var _failed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _app() -> Node:
	return root.get_node("App")


func _content() -> Node:
	return root.get_node("Content")


func _main() -> Node:
	return current_scene


func _run() -> void:
	await process_frame
	await process_frame
	_fill_sample_data()
	var main := _main()
	var app := _app()

	await _wait(20)
	await _shot("focus")

	# A real swipe: dragging right from the middle brings in the gifts on the left.
	await _drag(main.size * 0.5, main.size * Vector2(0.9, 0.5))
	await _wait(30)
	check(main._at == Vector2i(-1, 0), "swiping right opens gifts")
	await _shot("gifts")
	var gifts_pane: Node = main._panes[Vector2i(-1, 0)]
	gifts_pane.show_gift(_content().gifts[0]["id"])
	await _wait(25)
	await _shot("gifts_popup")
	_close_modal()
	await _wait(10)

	# Press and hold a gift, then drag it onto the empty middle shelf spot.
	var tile: Control = _find(gifts_pane, func(n): return _is(n, "gift_tile.gd") and n.gift_id == "staffy_rare")
	check(tile != null, "found a gift tile")
	if tile:
		# The headless window is small, so bring the tile into view first.
		gifts_pane.scroll.ensure_control_visible(tile)
		await _wait(5)
		var slot: Control = gifts_pane._slots[1]
		# Near the tile's corner: in the small headless window its middle is under the minimap.
		await _drag(tile.get_global_rect().position + Vector2(14, 14), slot.get_global_rect().get_center(), 12, 0.5)
		await _wait(30)
		check(app.state.shelf()[1] == "staffy_rare", "dragging a gift onto the shelf (shelf is %s)" % [app.state.shelf()])

	# Trading in ten commons for a rare.
	var rares: int = app.state.gift_count("staffy_rare")
	gifts_pane.show_gift("staffy_common")
	await _wait(20)
	gifts_pane._trade(_class("res://ui/modal.gd").top(), "staffy_common")
	await _wait(25)
	check(app.state.gift_count("staffy_common") == 2 and app.state.gift_count("staffy_rare") == rares + 1, "trade in")
	await _shot("trade_result")
	_close_modal()
	await _wait(10)

	# A drag the other way goes back to the middle; a short drag snaps back.
	await _drag(main.size * 0.5, main.size * Vector2(0.1, 0.5))
	await _wait(30)
	check(main._at == Vector2i.ZERO, "swiping left goes back to focus")
	await _drag(main.size * 0.5, main.size * Vector2(0.5, 0.58), 6)
	await _wait(30)
	check(main._at == Vector2i.ZERO, "a short drag snaps back")

	for pane in ["completed", "profile", "stats"]:
		app.go(pane)
		await _wait(50)
		check(main._at == main.PANES[pane][0], "go %s" % pane)
		await _shot(pane)

	app.go("completed")
	await _wait(50)
	main._panes[Vector2i(1, 0)]._pick_grade(app.state.completed_projects()[0].id)
	await _wait(25)
	await _shot("grade_picker")
	_close_modal()

	app.go("profile")
	await _wait(50)
	_class("res://scenes/customise/customise.gd").open()
	await _wait(25)
	await _shot("customise")
	_close_modal()

	app.go("stats")
	await _wait(50)
	main._panes[Vector2i(0, 1)]._show_project(app.state.projects[0].id, 0)
	await _wait(25)
	await _shot("stats_popup")
	_close_modal()
	main._panes[Vector2i(0, 1)]._select_week(main._panes[Vector2i(0, 1)]._week - 7)
	await _wait(10)

	app.go("focus")
	await _wait(50)
	# Tapping the orb opens the choose focus screen through a growing circle.
	var orb: Control = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "focus_orb.gd"))
	await _drag(orb.get_global_rect().get_center(), orb.get_global_rect().get_center(), 1)
	await _wait(12)
	check(main._flows.size() == 1, "tapping the orb opens choose focus")
	await _shot("reveal")
	await _wait(40)
	await _shot("choose_focus")
	var chooser: Node = main._flows.back().get_child(0)
	chooser._pets.go_to(2)
	await _wait(25)
	chooser._on_right()
	await _wait(25)
	await _shot("complete_confirm")
	_close_modal(false)
	await _wait(10)
	chooser._start_adopting()
	await _wait(30)
	await _shot("new_pet")
	chooser._animals.go_to(4)
	await _wait(25)
	chooser._name_edit.text = "Chemistry"
	chooser._pick_colour(0)
	await _wait(20)
	await _shot("colour_picker")
	_close_modal()
	var count: int = app.state.projects.size()
	chooser._adopt()
	await _wait(30)
	check(app.state.projects.size() == count + 1, "adopting adds a project")
	await _wait(150 if _shots_dir != "" else 10)

	app.start_walk(app.state.projects[1].id)
	app.go("walk", {"from": main.size * 0.5})
	await _wait(60)
	await _shot("walk")
	app.state.active.start_unix -= 50 * 60
	await _wait(30)
	await _shot("walk_50min")
	var walk: Node = main._flows.back().get_child(0)
	check(walk._gift.level() == 1, "50 minutes guarantees a rare gift")
	walk._on_gift_pressed()
	await _wait(80)
	await _shot("walk_dive")
	await _wait(300)
	check(main._flows.size() == 1 and main._flows[0].get_child(0).get("params").has("gift"), "dive ends on the finish screen")
	var result: Dictionary = main._flows[0].get_child(0).params
	check(result["session"].focus_seconds >= 50 * 60, "walk length from timestamps")
	check(result["gift"].get("rarity", "") in ["rare", "epic", "legendary"], "at least rare after 50 minutes")
	await _shot("finish")

	app.go("home")
	await _wait(60)
	check(main._flows.is_empty() and main._at == Vector2i.ZERO, "home closes the flow")

	if _failed:
		quit(1)
		return
	print("SMOKE OK")
	quit(0)


func _fill_sample_data() -> void:
	var app := _app()
	var content := _content()
	app.state = GameState.new()
	app.state.profile["username"] = "Joe"
	app.state.profile["institution"] = "University of Leeds"
	app.state.profile["created_unix"] = app.now() - 40 * 86400
	app.state.profile["cosmetics"]["hat"] = "bird_epic"
	app.state.profile["cosmetics"]["face"] = "face_glasses"
	var now: int = app.now()
	var animals := ["staffy", "tabby_cat", "snail", "bird", "bear", "rabbit"]
	var names := ["Dissertation", "Spanish", "Portfolio", "Statistics", "Guitar", "Reading"]
	for i in animals.size():
		var p := ProjectData.new()
		p.name = names[i]
		p.animal_id = animals[i]
		p.colours = content.animal_default_colours(animals[i])
		p.created_unix = now - 30 * 86400
		app.add_project(p)
		for d in 16:
			if (d + i) % 3 == 0:
				continue
			var s := FocusSession.new()
			s.project_id = p.id
			s.start_unix = now - d * 86400 - i * 3600
			s.focus_seconds = 900 + 600 * ((i + d) % 4)
			s.gift_id = "%s_%s" % [animals[i], ["common", "common", "rare", "epic"][(i + d) % 4]]
			app.state.sessions.append(s)
	app.complete_project(app.state.projects[5].id)
	app.complete_project(app.state.projects[4].id)
	app.state.projects[5].grade = "uni/first"
	app.state.projects[4].grade = "alevel/a_star"
	for g in content.gifts.slice(0, 24):
		app.state.inventory[g["id"]] = 1 + (hash(g["id"]) % 4)
	app.state.inventory["staffy_common"] = 12
	app.state.inventory["bird_epic"] = 1
	app.state.place_on_shelf("staffy_common", 0)
	app.state.place_on_shelf("bird_epic", 2)
	app.friends = [
		{"name": "Sam", "weekly_seconds": 9 * 3600, "walking": true, "look": {"skin_tone": 3, "hair_tone": 0, "cosmetics": {"hair": "hair_curly", "hat": "hat_beanie"}}},
		{"name": "Priya", "weekly_seconds": 6 * 3600 + 1200, "walking": false, "look": {"skin_tone": 2, "hair_tone": 0, "cosmetics": {"hair": "hair_long", "face": "face_smile"}}},
		{"name": "Alex", "weekly_seconds": 2 * 3600, "walking": false, "look": {"skin_tone": 0, "hair_tone": 3, "cosmetics": {"hair": "hair_bun", "hat": "hat_cap"}}},
	]
	app.state_changed.emit()


## Presses at `from`, optionally holds still for `hold` seconds, drags to
## `to` over a few frames and lets go.
func _drag(from: Vector2, to: Vector2, steps: int = 10, hold: float = 0.0) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	root.push_input(press, true)
	await process_frame
	if hold > 0.0:
		await create_timer(hold).timeout
	for i in steps:
		var m := InputEventMouseMotion.new()
		m.position = from.lerp(to, float(i + 1) / steps)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(m, true)
		# About a frame at 60fps, so swipe speeds are realistic.
		await create_timer(0.016).timeout
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	root.push_input(release, true)
	await process_frame


## Waits about this many frames' worth of time at 60fps (headless frames are
## much quicker than that, and animations run on real time).
## Whether `n` runs the script with this file name (named here rather than
## by class, for the same reason as _class()).
func _is(n: Node, script_file: String) -> bool:
	var s: Script = n.get_script()
	return s != null and s.resource_path.get_file() == script_file


## The first node under `node` (depth first) that `match` accepts.
func _find(node: Node, match: Callable) -> Node:
	for c in node.get_children():
		if match.call(c):
			return c
		var deeper := _find(c, match)
		if deeper:
			return deeper
	return null


func _wait(frames: int) -> void:
	await create_timer(frames / 60.0).timeout
	await process_frame


## UI classes depend on the autoloads, so they're loaded once the app is up
## rather than named in this script (which compiles before autoloads exist).
func _class(path: String) -> GDScript:
	return load(path)


func _close_modal(result: Variant = null) -> void:
	_class("res://ui/modal.gd").top().close(result)


func _shot(name: String) -> void:
	if _shots_dir == "":
		return
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_shots_dir, name])


func check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("SMOKE FAIL: " + msg)
		_failed = true
