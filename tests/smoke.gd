extends SceneTree
## Smoke run: boots the real app, fills it with sample data and visits every
## pane, popup and full-screen flow (including a real swipe, the arrow keys,
## a full walk with a gift, throwing the gift for the pet to fetch, a walk
## left running when the app closed, every kind of weather, and dark mode),
## so script errors in UI code show up in CI.
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


func _audio() -> Node:
	return root.get_node("Audio")


func _levels() -> GDScript:
	return _class("res://core/levels.gd")


func _main() -> Node:
	return current_scene


func _run() -> void:
	await process_frame
	await process_frame
	_fill_sample_data()
	var main := _main()
	var app := _app()
	# Answered, so the location question doesn't pop up mid-run (and nothing
	# goes out to the internet from CI); it's asked on purpose further down.
	app.state.settings["location"] = "off"

	await _wait(20)
	await _shot("focus")

	# The arrow keys move between screens and Esc comes back; so does tapping
	# a dot on the map.
	var map: Control = main._minimap
	await _drag(map.get_global_transform_with_canvas() * map._cell_rect(Vector2(0, 1)).get_center(),
		map.get_global_transform_with_canvas() * map._cell_rect(Vector2(0, 1)).get_center(), 1)
	await _wait(40)
	check(main._at == Vector2i(0, 1), "tapping the map's bottom dot opens stats")
	await _key(KEY_ESCAPE)
	await _wait(30)
	await _key(KEY_RIGHT)
	await _wait(30)
	check(main._at == Vector2i(1, 0), "right arrow opens completed")
	await _key(KEY_ESCAPE)
	await _wait(30)
	check(main._at == Vector2i.ZERO, "Esc comes back to the middle")

	# The orb grows under the pointer.
	var orb_rect: Rect2 = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "focus_orb.gd")).get_global_rect()
	var over := InputEventMouseMotion.new()
	over.position = orb_rect.get_center()
	over.global_position = over.position
	root.push_input(over, true)
	await _wait(20)
	var hovered: Node = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "focus_orb.gd"))
	check(hovered._grow > 1.03, "the orb grows on hover (%.2f)" % hovered._grow)
	over = over.duplicate()
	over.position = Vector2(4, main.size.y * 0.5)
	over.global_position = over.position
	root.push_input(over, true)
	await _wait(20)
	check(hovered._grow < 1.01, "and shrinks back")

	# Debug builds get an unlock-everything switch in the top left.
	var debug: Node = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "debug_bar.gd"))
	check(debug != null, "the debug bar shows in a debug build")
	if debug:
		var unlock: Button = _find(debug, func(n): return _is(n, "switch.gd"))
		unlock.button_pressed = true
		await _wait(10)
		check(app.is_unlocked("place", "moon") and app.is_unlocked("animal", "bear"), "the debug switch unlocks everything")
		await _shot("debug")
		unlock.button_pressed = false
		await _wait(10)
		check(not app.is_unlocked("place", "moon"), "and locks it all again")

	# The location question: asked once, a moment after the focus screen shows.
	app.state.settings.erase("location")
	main._maybe_ask_location()
	await _wait(110)
	check(_class("res://ui/modal.gd").is_open(), "asks about local sunrise and weather")
	await _shot("location_prompt")
	_close_modal(false)
	await _wait(20)
	check(app.state.settings.get("location") == "off" and not root.get_node("Outdoors").enabled(), "Not now leaves it off")

	# Every place draws cleanly round the clock, along a stretch of walk,
	# its front growth included.
	for b in _content().biomes:
		var scenery: Control = _class("res://scenes/walk/scenery.gd").new()
		scenery.biome = b
		root.add_child(scenery)
		scenery.size = main.size
		for hour in [6.2, 12.0, 18.4, 23.0]:
			scenery.clock = hour
			for scroll in [1234.0, 40000.0, 91000.0]:
				scenery.scroll = scroll
				await process_frame
			if hour == 12.0 or b["id"] == "jungle":
				await _shot("place_%s_%02d" % [b["id"], int(hour)])
		check(scenery.darkness() > 0.9, "%s is dark at 11pm" % b["id"])
		scenery.clock = 12.0
		check(scenery.darkness() == (1.0 if b.has("sky") else 0.0), "%s is light at midday unless it has its own sky" % b["id"])
		check(scenery.tint() == Color.WHITE, "%s is in full light at midday" % b["id"])
		if b["id"] == "jungle":
			check(scenery.front.get_child_count() >= 3, "the jungle has growth in front")
		# Every kind of weather, the way this place shows it.
		for kind in ["sunny", "partly", "cloudy", "rainy", "stormy", "snowy"]:
			scenery.weather = kind
			for scroll in [2000.0, 52000.0]:
				scenery.scroll = scroll
				await process_frame
		scenery.weather = "rainy"
		var dry: bool = b["id"] in ["desert", "moon"]
		check((scenery.weather_kind() == "sunny") == dry, "%s: rain shows as %s" % [b["id"], scenery.weather_kind()])
		if b["id"] == "tundra":
			check(scenery.weather_kind() == "snowy", "rain falls as snow in the tundra")
			scenery.weather = "stormy"
			check(scenery.weather_kind() == "blizzard" and scenery.ambience() == "wind", "a storm is a blizzard there")
		scenery.queue_free()
	await process_frame
	# The lake through a day, for the docs.
	var day: Control = _class("res://scenes/walk/scenery.gd").new()
	day.biome = _content().biome("lake")
	root.add_child(day)
	day.size = main.size
	day.scroll = 5000.0
	for hour in [5.5, 7.0, 12.0, 17.5, 18.6, 23.0]:
		day.clock = hour
		await _wait(2)
		await _shot("day_%04.1f" % hour)
	day.queue_free()
	await process_frame
	# Weather, for the docs: the lake in sun and cloud, cloud, rain and a
	# storm (caught mid-flash), the forest in snow, the tundra in a blizzard.
	for shot in [["lake", "partly"], ["lake", "cloudy"], ["lake", "rainy"], ["lake", "stormy"], ["forest", "snowy"], ["tundra", "stormy"]]:
		var w: Control = _class("res://scenes/walk/scenery.gd").new()
		w.biome = _content().biome(shot[0])
		root.add_child(w)
		w.size = main.size
		w.scroll = 7000.0
		w.clock = 13.0
		w.weather = shot[1]
		if shot[1] == "stormy" and shot[0] == "lake":
			w._time = 3 * w.STORM_EVERY + w._hash(3, 31.0) * 4.0 + 0.01
		await process_frame
		await process_frame
		if shot[1] == "stormy" and shot[0] == "lake":
			check(w._flash > 0.0 and w._bolt == 3, "lightning flashes in a storm")
			check(w.ambience() == "rain", "and it sounds like rain")
		await _shot("weather_%s_%s" % shot)
		w.queue_free()
	await process_frame

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
		# The headless window is small, so bring the tile into view first, and
		# press where it shows inside the scrolling collection.
		gifts_pane.scroll.ensure_control_visible(tile)
		await _wait(5)
		var slot: Control = gifts_pane._slots[1]
		var seen: Rect2 = tile.get_global_rect().intersection(gifts_pane.scroll.get_global_rect())
		await _drag(seen.position + Vector2(14, minf(14.0, seen.size.y * 0.5)), slot.get_global_rect().get_center(), 12, 0.5)
		await _wait(30)
		check(app.state.shelf()[1] == "staffy_rare", "dragging a gift onto the shelf (shelf is %s)" % [app.state.shelf()])

	# Only the collection scrolls: the shelf and the filter stay put.
	var shelf_y: float = gifts_pane._slots[0].get_global_rect().position.y
	gifts_pane.scroll.scroll_vertical = 400
	await _wait(5)
	check(gifts_pane._slots[0].get_global_rect().position.y == shelf_y, "the shelf doesn't scroll away")

	# A quick sideways drag on a shelf gift slides it along the shelf.
	var before: Array = app.state.shelf()
	var first: Control = _find(gifts_pane._slots[0], func(n): return _is(n, "gift_tile.gd"))
	check(first != null and first.slides, "shelf gifts slide")
	if first:
		await _drag(first.get_global_rect().get_center(), gifts_pane._slots[2].get_global_rect().get_center(), 10)
		await _wait(30)
		var after: Array = app.state.shelf()
		check(after[2] == before[0] and after[0] == before[2] and main._at == Vector2i(-1, 0),
			"sliding the first gift to the end swaps them, without leaving the screen (%s -> %s)" % [before, after])

	# The filter menu: picking an option sorts by it; picking it again reverses.
	var sort: Node = _find(gifts_pane, func(n): return _is(n, "dropdown.gd"))
	sort._open()
	await _wait(15)
	await _shot("gift_filter")
	sort._choose("name")
	await _wait(10)
	check(app.state.settings.get("gift_sort") == "name" and not app.state.settings.get("gift_sort_reversed"), "filter by A-Z")
	sort = _find(gifts_pane, func(n): return _is(n, "dropdown.gd"))
	sort._choose("name")
	await _wait(10)
	check(app.state.settings.get("gift_sort_reversed") == true, "choosing A-Z again reverses it")
	var shown := []
	for t in _all(gifts_pane, func(n): return _is(n, "gift_tile.gd") and n.get_parent() is GridContainer):
		shown.append(_content().gift(t.gift_id)["name"].to_lower())
	var sorted := shown.duplicate()
	sorted.sort()
	sorted.reverse()
	check(shown == sorted, "Z-A order on screen")
	sort = _find(gifts_pane, func(n): return _is(n, "dropdown.gd"))
	sort._choose("rarity")
	await _wait(10)

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
	var profile_pane: Node = main._panes[Vector2i(0, -1)]
	var modal_class := _class("res://ui/modal.gd")
	# Tapping the pencil opens the character popup; tapping the level badge
	# (bottom left of the picture) opens the rewards.
	var pencil: Button = _find(profile_pane, func(n): return n is Button and n.tooltip_text == "Customise your character")
	check(pencil != null, "a pencil on the character")
	if pencil:
		await _drag(pencil.get_global_rect().get_center(), pencil.get_global_rect().get_center(), 1)
		await _wait(25)
		check(modal_class.is_open(), "the pencil opens the customise popup")
		await _shot("customise")
		_close_modal()
		await _wait(15)
	var badge: Control = _find(profile_pane, func(n): return n is Control and n.tooltip_text == "Levels and rewards")
	var picture: Control = _find(profile_pane, func(n): return n is Control and n.tooltip_text == "Customise your character" and not n is Button)
	check(badge != null and picture != null, "a level badge on the character")
	if badge and picture:
		var b: Rect2 = badge.get_global_rect()
		var pic: Rect2 = picture.get_global_rect()
		check(b.get_center().x < pic.get_center().x and b.get_center().y > pic.get_center().y, "the badge sits bottom left")
		await _drag(b.get_center(), b.get_center(), 1)
		await _wait(25)
		check(modal_class.is_open(), "the badge opens the rewards")
		var rewards: Node = modal_class.top()
		var title_y: float = rewards.header.get_global_rect().position.y
		await _wait(50)
		check(rewards.header.get_child_count() == 2, "the title and your level sit above the list")
		check(rewards._scroll.scroll_vertical > 0, "it opens scrolled down to where you are (level %d)" % app.level())
		# The next reward to come is in view: the first one with a padlock.
		var next_up: Control = _find(rewards.body, func(n): return n is HBoxContainer and n.get_child_count() == 4)
		check(next_up != null and rewards._scroll.get_global_rect().encloses(next_up.get_global_rect()), "the next reward to come is in view")
		await _shot("rewards")
		rewards._scroll.scroll_vertical = 0
		await _wait(5)
		check(is_equal_approx(rewards.header.get_global_rect().position.y, title_y), "the title doesn't scroll")
		_close_modal()
		await _wait(15)
		await _drag(pic.position + Vector2(pic.size.x * 0.5, pic.size.y * 0.4), pic.position + Vector2(pic.size.x * 0.5, pic.size.y * 0.4), 1)
		await _wait(25)
		check(modal_class.is_open(), "tapping the character opens the customise popup")
		_close_modal()
		await _wait(15)
	profile_pane.open_settings()
	await _wait(25)
	await _shot("settings")
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
	# Places in the order they unlock; the project, then the pet, then a hint,
	# with its kind and time under the pet.
	var order: Array = chooser._places.keys()
	check(order[0] == "lake" and order.size() == _content().biomes.size(), "places start at the lakeside")
	for i in range(1, order.size()):
		check(_levels().unlock_level("place", order[i], _content().levels) >= _levels().unlock_level("place", order[i - 1], _content().levels), "places in unlock order")
	check(chooser._words.get_child(0) == chooser._title and chooser._title.text != "", "project title first")
	if main.size.y >= 600.0:
		check(chooser._words.get_rect().end.y < chooser._scenery.path_y() - chooser.PET_HEIGHT * 0.86, "words above the pets")
	check(chooser._under.text.contains("focused") and chooser._under.position.y > chooser._scenery.path_y(), "kind and time under the pet")
	var level: int = app.level()
	check(level > 1 and level < 15, "sample player is part way up (level %d)" % level)
	chooser._pick_place("beach")
	await _wait(50)
	check(app.state.settings.get("walk_biome") == "beach", "picking an unlocked place")
	await _shot("choose_beach")
	# In the jungle the growth stands in front of the pets, under the words,
	# and the scene holds still while you choose.
	app.state.settings["debug_unlock_all"] = true
	chooser._pick_place("jungle")
	await _wait(50)
	var growth: Control = chooser._scenery.front
	check(growth.get_parent() == chooser._pick and growth.get_index() > chooser._pets.get_index() and growth.get_index() < chooser._words.get_index(),
		"the place's growth is over the pets and under the words")
	var still: float = chooser._scenery.scroll
	await _wait(20)
	check(chooser._scenery.scroll == still, "the background holds still while you choose")
	await _shot("choose_jungle")
	chooser._pick_place("beach")
	app.state.settings["debug_unlock_all"] = false
	await _wait(50)
	chooser._pick_place("moon")
	await _wait(20)
	check(app.state.settings.get("walk_biome") == "beach", "a locked place can't be picked")
	await _shot("place_locked")
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
	var locked := -1
	for i in _content().animals.size():
		if not app.is_unlocked("animal", _content().animals[i]["id"]):
			locked = i
			break
	check(locked >= 0, "something's still locked at level %d" % level)
	chooser._animals.go_to(locked)
	await _wait(25)
	check(chooser._right.disabled, "a locked animal can't be adopted")
	check(chooser._swatch_row.modulate.a < 0.05, "a locked animal hides the colour buttons")
	await _shot("new_pet_locked")
	chooser._animals.go_to(1)
	await _wait(25)
	check(chooser._swatch_row.modulate.a > 0.95, "an open animal shows them again")
	chooser._name_edit.text = "Chemistry"
	chooser._pet_edit.text = "Bramble"
	await _shot("new_pet_named")
	chooser._pick_colour(0)
	await _wait(20)
	await _shot("colour_picker")
	_close_modal()
	var count: int = app.state.projects.size()
	chooser._adopt()
	await _wait(30)
	check(app.state.projects.size() == count + 1, "adopting adds a project")
	check(app.state.projects.back().pet_name == "Bramble", "adopting keeps the pet's name")
	await _wait(150 if _shots_dir != "" else 10)

	app.start_walk(app.state.projects[1].id)
	app.go("walk", {"from": main.size * 0.5})
	await _wait(60)
	var walk: Node = main._flows.back().get_child(0)
	walk._scenery.clock = 10.5
	await _wait(2)
	await _shot("walk")
	# Late in the evening the moon is out and the stars come through.
	walk._scenery.clock = 22.5
	await _wait(2)
	check(walk._scenery.is_dark() and walk._scenery.ambience() == "night", "the night chorus after dark")
	await _shot("walk_night")
	walk._scenery.clock = 10.5

	# The sound button turns the effects and the ambience off together.
	check(walk._sound_on(), "sound starts on")
	walk._toggle_sound()
	check(not app.state.settings.get("sound") and not app.state.settings.get("ambience"), "the sound button mutes everything")
	walk._toggle_sound()
	check(app.state.settings.get("sound") and app.state.settings.get("ambience"), "and turns it all back on")
	check(_find(walk, func(n): return _is(n, "dropdown.gd")) != null, "the debug weather picker is on the walk")

	# The debug time buttons move the walk on; the gift button's pie follows.
	var steps: Array = _find(walk, func(n): return n is Button and n.text == "+5").get_parent().get_children()
	check(steps.size() == 4, "+5, +10, +30 and +60 minute buttons")
	steps[0].pressed.emit()
	await _wait(30)
	check(walk._gift._reveal == 0.0 and absf(walk._gift._progress - 0.5) < 0.05, "five minutes in, the dark green is halfway round")
	await _shot("gift_5min")
	steps[0].pressed.emit()
	await _wait(10)
	check(walk._gift.level() == 0, "ten minutes earns a gift")
	await _wait(60)
	check(walk._gift._reveal == 1.0, "and the bright green fills in")
	steps[2].pressed.emit()
	await _wait(60)
	var pie: Dictionary = walk._gift.shown()
	check(pie["rare"] > 0.1 and pie["epic"] > 0.0 and pie["common"] > 0.5, "40 minutes: slices for the rarer gifts (%s)" % pie)
	await _shot("gift_40min")
	steps[1].pressed.emit()
	await _wait(60)
	await _shot("walk_50min")
	check(walk._gift.level() == 1, "50 minutes guarantees a rare gift")
	check(walk._gift.shown()["common"] < 0.01, "and common drops out of the pie")
	walk._on_gift_pressed()
	await _wait(80)
	await _shot("walk_dive")
	await _wait(300)
	check(main._flows.size() == 1 and main._flows[0].get_child(0).get("params").has("gift"), "dive ends on the finish screen")
	var result: Dictionary = main._flows[0].get_child(0).params
	check(result["session"].focus_seconds >= 50 * 60, "walk length from timestamps")
	check(result["gift"].get("rarity", "") in ["rare", "epic", "legendary"], "at least rare after 50 minutes")
	var finish: Node = main._flows[0].get_child(0)
	await _wait(40)
	await _shot("finish_zoom")
	await _wait(420)
	check(finish._home.modulate.a > 0.9, "the home button fades in at the end")
	check(finish._state == "ready", "the gift can be picked up")
	check(finish._scenery.front.get_index() > finish._front_actors.get_index(), "the growth stays in front of the pet")
	await _shot("finish")

	# Easter egg: hold the gift, flick it up into the distance, and wait for
	# the fetch.
	var gift_at: Vector2 = finish._gift_on_screen()
	await _drag(gift_at, gift_at + Vector2(30, -150), 4, 0.3)
	await _wait(20)
	check(finish._state in ["flying", "fetching"], "a flick throws the gift (state %s)" % finish._state)
	await _wait(30)
	await _shot("fetch")
	await _wait(400)
	check(finish._state == "ready" and finish._animal.held_gift == result["gift"]["gift_id"], "the pet brings the gift back")

	app.go("home")
	await _wait(60)
	check(main._flows.is_empty() and main._at == Vector2i.ZERO, "home closes the flow")

	# Closing the app mid-walk ends the walk: the next launch logs it up to
	# when the app was last open, with no gift, and shows focus ended.
	app.start_walk(app.state.projects[0].id, -1, "forest")
	app.state.active.start_unix -= 25 * 60
	app.state.active.last_seen_unix = app.now() - 2 * 60
	var logged: int = app.state.sessions.size()
	var ended: Dictionary = app._end_left_walk()
	var stopped: int = ended["session"].focus_seconds
	check(app.state.active == null and app.state.sessions.size() == logged + 1, "a walk left running is logged")
	check(stopped >= 22 * 60 and stopped <= 24 * 60, "up to when the app was last open (%ds)" % stopped)
	check(ended["session"].gift_id == "", "with no gift")
	main._open_flow("ended", ended, true)
	await _wait(170)
	var ended_screen: Node = main._flows.back().get_child(0)
	check(ended_screen._walker.sad > 0.9 and ended_screen._animal.sad > 0.9, "you and your pet look dejected")
	check(ended_screen._home.modulate.a > 0.5, "the way home shows")
	await _shot("ended")
	ended_screen.go_back()
	await _wait(60)
	check(main._flows.is_empty(), "home from focus ended")

	# In the jungle the leaves pass in front of you and your pet.
	app.start_walk(app.state.projects[0].id, -1, "jungle")
	app.go("walk", {"from": main.size * 0.5})
	await _wait(60)
	var jungle_walk: Node = main._flows.back().get_child(0)
	jungle_walk._scenery.clock = 10.5
	var front: Control = jungle_walk._scenery.front
	check(front.get_parent() == jungle_walk and front.get_index() > jungle_walk._actors.get_index(), "the jungle's growth is in front of the walker")
	await _wait(2)
	await _shot("walk_jungle")
	# Ending it early: no gift, and nothing glows where one would be.
	jungle_walk._on_gift_pressed()
	await _wait(20)
	_close_modal(true)
	await _wait(420)
	var empty_finish: Node = main._flows.back().get_child(0)
	check(_is(empty_finish, "finish.gd") and empty_finish._gift_id == "", "an early finish has no gift")
	check(not empty_finish._glow.visible, "and no glow where the gift would be")
	await _shot("finish_no_gift")
	app.go("home")
	await _wait(60)
	check(main._flows.is_empty(), "back home from the jungle")
	check(_audio().current_ambience() == "", "the jungle's sounds stop at home")

	# Dark mode: the sun in the corner switches the whole app.
	var toggle: Node = _find(main._panes[Vector2i.ZERO], func(n): return _is(n, "theme_toggle.gd"))
	toggle._flip()
	await _wait(60)
	check(_class("res://ui/ui.gd").dark, "the toggle switches to dark mode")
	check(app.state.settings.get("theme") == "dark", "dark mode is saved")
	await _shot("focus_dark")
	for pane in ["gifts", "stats", "profile"]:
		app.go(pane)
		await _wait(50)
		await _shot(pane + "_dark")
	main._panes[Vector2i(0, -1)].open_rewards()
	await _wait(50)
	await _shot("rewards_dark")
	_close_modal()
	app.go("focus")
	await _wait(50)
	_find(main._panes[Vector2i.ZERO], func(n): return _is(n, "theme_toggle.gd"))._flip()
	await _wait(60)
	check(not _class("res://ui/ui.gd").dark, "and back to light")

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
	var pets := ["Biscuit", "Mochi", "", "Pip", "Bruno", ""]
	for i in animals.size():
		var p := ProjectData.new()
		p.name = names[i]
		p.pet_name = pets[i]
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
			s.focus_seconds = 600 + 300 * ((i + d) % 4)
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


## Every node under `node` that `match` accepts, in tree order.
func _all(node: Node, match: Callable) -> Array:
	var out := []
	for c in node.get_children():
		if match.call(c):
			out.append(c)
		out.append_array(_all(c, match))
	return out


## The first node under `node` (depth first) that `match` accepts.
func _find(node: Node, match: Callable) -> Node:
	for c in node.get_children():
		if match.call(c):
			return c
		var deeper := _find(c, match)
		if deeper:
			return deeper
	return null


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)
		await process_frame


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
