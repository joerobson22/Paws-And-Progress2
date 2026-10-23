class_name DebugBar
extends VBoxContainer
## Only in debug builds (runs from the editor, debug exports). On the focus
## screen, in the top left: a switch that unlocks every animal and place,
## and one that shows the app at a phone's proportions (off: the desktop
## layout filling the window).
## The walk uses the other two pieces here: a picker to preview each kind
## of weather instead of the real one, and buttons that move the walk on.

## How far the walk's time buttons move it on, in minutes.
const STEPS := [5, 10, 30, 60]


func _init() -> void:
	add_theme_constant_override("separation", 4)
	# Two switches, one under the other, with "DEBUG" by the first.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(UI.label("DEBUG", 11, UI.INK_FAINT, false, 900))
	_switch(grid, "Unlock all", "Unlock every animal and place (debug builds only)", App.debug_unlock_all(), "debug_unlock_all")
	grid.add_child(Control.new())
	_switch(grid, "Phone size", "Show the app at a phone's proportions (debug builds only)", App.debug_phone_view(), "debug_phone_view")
	add_child(grid)


func _switch(grid: GridContainer, title: String, tip: String, on: bool, setting: String) -> void:
	var sw := Switch.new(on)
	sw.accessibility_name = tip
	sw.toggled.connect(func(value: bool): App.set_setting(setting, value))
	grid.add_child(sw)
	var words := UI.label(title, 13, UI.INK_SOFT, false, 800)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(words)


## A picker for the weather the places show: the real one, or any kind.
static func weather_picker() -> Dropdown:
	var options := [["live", "Live"]]
	for kind in Weather.KINDS:
		options.append([kind, Weather.look(kind, Content.weathers)["name"]])
	var pick := Dropdown.new(options, Outdoors.override if Outdoors.override != "" else "live", false, "Weather", false)
	pick.chosen.connect(func(option: String, _reversed: bool): Outdoors.override = "" if option == "live" else option)
	return pick


## Small see-through buttons that add 5, 10, 30 or 60 minutes to the walk.
static func time_buttons() -> HBoxContainer:
	var row := UI.hbox(6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for minutes in STEPS:
		var b := Button.new()
		b.text = "+%d" % minutes
		b.custom_minimum_size = Vector2(46, 32)
		b.add_theme_font_size_override("font_size", 13)
		UI.style_button(b, UI.GLASS, Color.WHITE, 999)
		b.pressed.connect(App.debug_add_minutes.bind(minutes))
		row.add_child(b)
	return row
