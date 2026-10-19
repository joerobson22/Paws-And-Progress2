extends Control
## App shell: background, navigation (top pills on wide screens, bottom tabs
## on phones) and the current screen. Screens ask to move with App.go().

const SCREENS := {
	"home": "res://scenes/home/home.gd",
	"walks": "res://scenes/home/walks.gd",
	"project_editor": "res://scenes/project_editor/project_editor.gd",
	"walk": "res://scenes/walk/walk.gd",
	"end_walk": "res://scenes/end_walk/end_walk.gd",
	"shelf": "res://scenes/shelf/shelf.gd",
	"wardrobe": "res://scenes/shelf/wardrobe.gd",
	"board": "res://scenes/board/board.gd",
	"stats": "res://scenes/stats/stats.gd",
}
## Tabs shown in the navigation, in order: [screen, label].
const TABS := [
	["home", "Cabin"], ["walks", "Walks"], ["shelf", "Shelf"],
	["wardrobe", "Wardrobe"], ["board", "Noticeboard"], ["stats", "Stats"],
]
## Screens that take over the whole window.
const FULL_SCREEN := ["walk", "end_walk"]

var _current_name := ""
var _current_params := {}
var _current: Control
var _layout := VBoxContainer.new()
var _holder := Control.new()
var _was_wide := false


func _ready() -> void:
	theme = UI.build_theme()
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.add_theme_constant_override("separation", 0)
	add_child(_layout)
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.clip_contents = true

	App.navigate.connect(_open)
	get_viewport().size_changed.connect(_on_resized)
	_was_wide = UI.is_wide(self)

	# A walk survives the app being closed: pick it straight back up.
	if App.state.active:
		_open("walk", {})
	else:
		_open("home", {})


func _open(screen: String, params: Dictionary) -> void:
	if not SCREENS.has(screen):
		push_error("Unknown screen %s" % screen)
		return
	_current_name = screen
	_current_params = params
	if _current:
		_current.queue_free()
	_current = load(SCREENS[screen]).new()
	_current.set("params", params)
	_current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rebuild_shell()
	_holder.add_child(_current)


func _rebuild_shell() -> void:
	for c in _layout.get_children():
		_layout.remove_child(c)
		if c != _holder:
			c.queue_free()
	var full := FULL_SCREEN.has(_current_name)
	var wide := UI.is_wide(self)
	if not full and wide:
		_layout.add_child(_top_bar())
	_layout.add_child(_holder)
	if not full and not wide:
		_layout.add_child(_tab_bar())


func _on_resized() -> void:
	var wide := UI.is_wide(self)
	if wide != _was_wide:
		_was_wide = wide
		_open(_current_name, _current_params)


func _top_bar() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	var bar := UI.hbox(24)
	margin.add_child(bar)

	var logo := UI.label("Paws & Progress", 22, UI.INK, true, 600)
	logo.autowrap_mode = TextServer.AUTOWRAP_OFF
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(logo)

	var pills := PanelContainer.new()
	var pb := UI.box(UI.PILL, Color.TRANSPARENT, 999)
	pb.set_content_margin_all(4)
	pills.add_theme_stylebox_override("panel", pb)
	var row := UI.hbox(4)
	pills.add_child(row)
	for tab in TABS:
		var selected: bool = tab[0] == _current_name or (tab[0] == "walks" and _current_name == "project_editor")
		var b := UI.button(tab[1], App.go.bind(tab[0], {}), UI.PAPER if selected else UI.PILL, UI.INK if selected else UI.INK_SOFT)
		b.custom_minimum_size = Vector2(0, 38)
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(s).duplicate()
			sb.set_corner_radius_all(999)
			sb.content_margin_top = 6
			sb.content_margin_bottom = 6
			sb.content_margin_left = 16
			sb.content_margin_right = 16
			b.add_theme_stylebox_override(s, sb)
		b.add_theme_font_size_override("font_size", 15)
		row.add_child(b)
	bar.add_child(pills)

	bar.add_child(UI.spacer())
	var streak := Stats.current_streak(App.state.sessions, App.today(), App.tz_bias())
	if streak > 0:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UI.box(Color("#fbe3d2"), Color.TRANSPARENT, 999))
		chip.add_child(UI.label("%d day streak" % streak, 15, Color("#8a3b12"), false, 800))
		bar.add_child(chip)
	return margin


func _tab_bar() -> Control:
	var panel := PanelContainer.new()
	var pb := UI.box(UI.PAPER, Color.TRANSPARENT, 0)
	pb.border_width_top = 1
	pb.border_color = Color("#e6d9c0")
	pb.content_margin_top = 6
	pb.content_margin_bottom = 18
	pb.content_margin_left = 4
	pb.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", pb)
	var row := UI.hbox(0)
	panel.add_child(row)
	# Phones get the five most-used tabs; the noticeboard lives on the cabin screen.
	for tab in TABS:
		if tab[0] == "board":
			continue
		var selected: bool = tab[0] == _current_name
		var b := UI.button(tab[1], App.go.bind(tab[0], {}), UI.PAPER, UI.FOREST if selected else UI.INK_SOFT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_size_override("font_size", 13)
		row.add_child(b)
	return panel
