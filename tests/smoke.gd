extends SceneTree
## Smoke run: boots the real app, fills it with sample data and opens every
## screen, so script errors in UI code show up in CI.
##   godot --headless --path . -s tests/smoke.gd
## Optional: --shots=<dir> saves a screenshot per screen (needs a display).

var _steps: Array = []
var _shots_dir := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _content() -> Node:
	return root.get_node("Content")


func _app() -> Node:
	return root.get_node("App")


func _run() -> void:
	await process_frame
	var app := _app()
	app.state = GameState.new()
	app.state.profile["username"] = "Joe"
	var now: int = app.now()
	var animals := ["staffy", "tabby_cat", "snail", "bird", "bear", "rabbit"]
	for i in animals.size():
		var p := ProjectData.new()
		p.name = ["Dissertation", "Spanish", "Portfolio", "Statistics", "Guitar", "Reading"][i]
		p.animal_id = animals[i]
		p.colours = _content().animal_default_colours(animals[i])
		app.add_project(p)
		for d in 5:
			var s := FocusSession.new()
			s.project_id = p.id
			s.start_unix = now - d * 86400 - i * 3600
			s.focus_seconds = 1200 + 600 * ((i + d) % 4)
			app.state.sessions.append(s)
	app.complete_project(app.state.projects[5].id)
	for g in _content().gifts.slice(0, 20):
		app.state.inventory[g["id"]] = 1
	app.state.profile["cosmetics"]["hat"] = "bird_epic"

	for screen in ["home", "walks", "project_editor", "shelf", "wardrobe", "board", "stats", "settings"]:
		await _visit(screen, {})
	await _visit("project_editor", {"id": app.state.projects[0].id})

	app.start_walk(app.state.projects[1].id)
	await _visit("walk", {}, 60)
	app.state.active.start_unix -= 50 * 60
	await _visit("walk", {}, 30, "walk_50min")
	app.state.active.pause(app.now())
	await _visit("walk", {}, 10, "walk_paused")
	app.state.active.resume(app.now())
	var result: Dictionary = app.finish_walk()
	check(result["session"].focus_seconds >= 50 * 60, "walk length from timestamps")
	check(not result["gift"].is_empty(), "50 minute walk earns a gift")
	await _visit("end_walk", result, 20)

	print("SMOKE OK")
	quit(0)


func _visit(screen: String, params: Dictionary, frames: int = 15, shot_name: String = "") -> void:
	_app().go(screen, params)
	for i in frames:
		await process_frame
	if _shots_dir != "":
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [_shots_dir, shot_name if shot_name != "" else screen + ("_edit" if params.has("id") else "")])


func check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("SMOKE FAIL: " + msg)
		quit(1)
