class_name DebugBar
extends VBoxContainer
## Only in debug builds (runs from the editor, debug exports). On the focus
## screen, in the top left: a switch that unlocks every animal and place.
## The walk uses the other two pieces here: a picker to preview each kind
## of weather instead of the real one, and buttons that move the walk on.

## How far the walk's time buttons move it on, in minutes.
const STEPS := [5, 10, 30, 60]


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


## A picker for the weather the places show: the real one, or any kind.
static func weather_picker() -> Dropdown:
	var options := [["live", "Live"]]
	for kind in Weather.KINDS:
		options.append([kind, Weather.look(kind, Content.weathers)["name"]])
	var pick := Dropdown.new(options, Outdoors.override if Outdoors.override != "" else "live", false, "Weather")
	pick.tooltip_text = "Preview the weather (debug builds only)"
	pick.chosen.connect(func(option: String, _reversed: bool): Outdoors.override = "" if option == "live" else option)
	return pick


## Small see-through buttons that add 5, 10, 30 or 60 minutes to the walk.
static func time_buttons() -> HBoxContainer:
	var row := UI.hbox(6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for minutes in STEPS:
		var b := Button.new()
		b.text = "+%d" % minutes
		b.tooltip_text = "Add %d minutes to the walk (debug builds only)" % minutes
		b.custom_minimum_size = Vector2(46, 32)
		b.add_theme_font_size_override("font_size", 13)
		UI.style_button(b, UI.GLASS, Color.WHITE, 999)
		b.pressed.connect(App.debug_add_minutes.bind(minutes))
		row.add_child(b)
	return row
