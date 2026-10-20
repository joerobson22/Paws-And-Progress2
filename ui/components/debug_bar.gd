class_name DebugBar
extends VBoxContainer
## Only in debug builds (runs from the editor, debug exports): a switch that
## unlocks every animal and place, and a picker to preview each kind of
## weather instead of the real one. Sits in the focus screen's top left.


func _init() -> void:
	add_theme_constant_override("separation", 4)
	var row := UI.hbox(8)
	row.add_child(UI.label("DEBUG", 11, UI.INK_FAINT, false, 900))
	var unlock := Switch.new(App.debug_unlock_all())
	unlock.tooltip_text = "Unlock every animal and place (debug builds only)"
	unlock.toggled.connect(func(on: bool): App.set_setting("debug_unlock_all", on))
	row.add_child(unlock)
	row.add_child(UI.label("Unlock all", 13, UI.INK_SOFT, false, 800))
	add_child(row)
	var options := [["live", "Live"]]
	for kind in Weather.KINDS:
		options.append([kind, Weather.look(kind, Content.weathers)["name"]])
	var weather := Dropdown.new(options, Outdoors.override if Outdoors.override != "" else "live", false, "Weather")
	weather.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	weather.chosen.connect(func(option: String, _reversed: bool): Outdoors.override = "" if option == "live" else option)
	add_child(weather)
