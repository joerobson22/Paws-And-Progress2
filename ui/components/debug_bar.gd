class_name DebugBar
extends VBoxContainer
## Only in debug builds (runs from the editor, debug exports). On the focus
## screen, small, beside the home icon in the top left: a switch that
## unlocks every animal and place, and one that gives the window a phone's
## shape and lays the app out as on a phone (off: the window as it was).
## The walk also shows the buttons here that move it on.

## How far the walk's time buttons move it on, in minutes.
const STEPS := [5, 10, 30, 60]


## How big the switches are drawn, so they sit quietly beside the home icon.
const SCALE := 0.8
## Each switch's row height, before SCALE: two rows match the icon's height.
const ROW := 26


func _init() -> void:
	scale = Vector2(SCALE, SCALE)
	add_theme_constant_override("separation", 4)
	# Two switches, one under the other, with "DEBUG" by the first.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(UI.label(Text.t("debug.title"), 11, UI.INK_FAINT, false, 900))
	_switch(grid, Text.t("debug.unlock_all"), Text.t("debug.unlock_all_note"), App.debug_unlock_all(), "debug_unlock_all")
	grid.add_child(Control.new())
	_switch(grid, Text.t("debug.phone_size"), Text.t("debug.phone_size_note"), App.debug_phone_view(), "debug_phone_view")
	add_child(grid)


func _switch(grid: GridContainer, title: String, tip: String, on: bool, setting: String) -> void:
	var sw := Switch.new(on)
	sw.custom_minimum_size.y = ROW
	sw.accessibility_name = tip
	sw.toggled.connect(func(value: bool): App.set_setting(setting, value))
	grid.add_child(sw)
	var words := UI.label(title, 13, UI.INK_SOFT, false, 800)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(words)


## Small see-through buttons that add 5, 10, 30 or 60 minutes to the walk.
static func time_buttons() -> HBoxContainer:
	var row := UI.hbox(6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for minutes in STEPS:
		var b := Button.new()
		b.text = Text.t("debug.add_minutes", {"minutes": minutes})
		b.custom_minimum_size = Vector2(46, 32)
		b.add_theme_font_size_override("font_size", 13)
		UI.style_button(b, UI.GLASS, Color.WHITE, 999)
		b.pressed.connect(App.debug_add_minutes.bind(minutes))
		row.add_child(b)
	return row
