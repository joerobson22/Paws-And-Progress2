extends "res://tests/smoke.gd"
## Screenshots of the main screens in every UI style (UI.STYLES), light and
## dark, with a popup and the choose focus screen, to look over a style.
##   godot --path . -s tests/style_shots.gd -- --shots=<dir> [--styles=glass,pixel]
## Without --shots it only checks each style draws without script errors.

var _only: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--styles="):
			_only = Array(arg.trim_prefix("--styles=").split(","))
	super._initialize()


func _run() -> void:
	await process_frame
	await process_frame
	_fill_sample_data()
	var main := _main()
	var app := _app()
	app.state.settings["location"] = "off"
	app.set_setting("debug_hour", 12.0)
	await _wait(40)
	var styles: Array = _only if not _only.is_empty() else ["classic", "glass", "storybook", "pixel"]
	for style in styles:
		for mode in ["light", "dark"]:
			app.set_setting("debug_style", style)
			app.set_setting("debug_theme", mode)
			await _wait(30)
			check(str(_class("res://ui/ui.gd").style) == style, "the %s style is in use" % style)
			var tag := "%s_%s" % [style, mode]
			for pane in ["focus", "gifts", "projects", "stats", "profile"]:
				app.go(pane)
				await _wait(40)
				await _shot("%s_%s" % [tag, pane])
			# A popup: the accounts list, from the profile screen.
			_class("res://ui/components/account_switcher.gd").open()
			await _wait(30)
			await _shot("%s_popup" % tag)
			_close_modal()
			await _wait(20)
			app.go("focus")
			await _wait(30)
			app.go("choose_focus", {"from": main.size * 0.5})
			await _wait(60)
			await _shot("%s_choose_focus" % tag)
			app.go("home")
			await _wait(40)
	app.set_setting("debug_style", "classic")
	app.set_setting("debug_theme", "auto")
	app.set_setting("debug_hour", -1.0)
	await _wait(10)
	print("STYLE SHOTS FAIL" if _failed else "STYLE SHOTS OK")
	quit(1 if _failed else 0)
