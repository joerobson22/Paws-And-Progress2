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
	"settings": "res://scenes/settings/settings.gd",
}
## Tabs shown in the navigation, in order: [screen, label, icon].
const TABS := [
	["home", "Cabin", "home"], ["walks", "Walks", "walk"], ["shelf", "Shelf", "gift"],
	["wardrobe", "Wardrobe", "shirt"], ["board", "Noticeboard", "board"], ["stats", "Stats", "stats"],
]
## The UI is laid out for a short side of this many points; smaller windows
## (phones) get a smaller design size so text stays its intended size.
const DESIGN_SHORT_SIDE := 720.0
const PHONE_MIN_SHORT_SIDE := 360.0
## Screens that take over the whole window.
const FULL_SCREEN := ["walk", "end_walk"]

var _current_name := ""
var _current_params := {}
var _current: Control
var _layout := VBoxContainer.new()
var _holder := Control.new()
var _was_wide := false


func _ready() -> void:
	_fit_design_size()
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


## Phones report a short side of ~390 points, so a fixed 720 design size
## would draw everything at half size. Use the window's own size in points
## there, and the 720 design size (scaled up) on bigger screens.
func _fit_design_size() -> void:
	var window := get_window()
	var points := Vector2(DisplayServer.window_get_size()) / _screen_scale()
	var side := clampf(minf(points.x, points.y), PHONE_MIN_SHORT_SIDE, DESIGN_SHORT_SIDE)
	var target := Vector2i(roundi(side), roundi(side))
	if window.content_scale_size != target:
		window.content_scale_size = target


## Physical pixels per point: Retina/iOS report it directly; Android via DPI.
static func _screen_scale() -> float:
	if OS.get_name() == "Android":
		return maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	return maxf(1.0, DisplayServer.screen_get_scale())


func _on_resized() -> void:
	_fit_design_size()
	var wide := UI.is_wide(self)
	if wide != _was_wide:
		_was_wide = wide
		_open(_current_name, _current_params)


func _top_bar() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	var bar := UI.hbox(24)
	margin.add_child(bar)

	var brand := UI.hbox(10)
	var badge := TextureRect.new()
	badge.texture = Icons.texture("paw", 20, UI.BG)
	badge.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	badge.custom_minimum_size = Vector2(36, 36)
	var badge_bg := UI.panel(UI.FOREST, 11, 0)
	badge_bg.add_child(badge)
	badge_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(badge_bg)
	var logo := UI.label("Paws & Progress", 22, UI.INK, true, 600)
	logo.autowrap_mode = TextServer.AUTOWRAP_OFF
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand.add_child(logo)
	bar.add_child(brand)

	var pills := PanelContainer.new()
	var pb := UI.box(UI.PILL, Color.TRANSPARENT, 999)
	pb.set_content_margin_all(4)
	pills.add_theme_stylebox_override("panel", pb)
	pills.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UI.hbox(4)
	pills.add_child(row)
	for tab in TABS:
		var selected := _tab_selected(tab[0])
		var b := UI.button(tab[1], App.go.bind(tab[0], {}), UI.PAPER if selected else UI.PILL, UI.INK if selected else Color("#5c5246"))
		b.custom_minimum_size = Vector2(0, 38)
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(s).duplicate()
			sb.set_corner_radius_all(999)
			sb.content_margin_top = 6
			sb.content_margin_bottom = 6
			sb.content_margin_left = 16
			sb.content_margin_right = 16
			if selected and s == "normal":
				sb.shadow_color = Color(0.24, 0.16, 0.08, 0.15)
				sb.shadow_size = 2
				sb.shadow_offset = Vector2(0, 1)
			b.add_theme_stylebox_override(s, sb)
		b.add_theme_font_size_override("font_size", 14)
		row.add_child(b)
	bar.add_child(pills)

	bar.add_child(UI.spacer())
	var streak := Stats.current_streak(App.state.sessions, App.today(), App.tz_bias())
	if streak > 0:
		bar.add_child(_streak_chip(streak))
	var gear := UI.icon_button("gear", "Settings", App.go.bind("settings", {}), UI.PAPER, UI.INK, 40, 999)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(gear)
	return margin


func _streak_chip(days: int) -> Control:
	var chip := PanelContainer.new()
	var cb := UI.box(Color("#fbe3d2"), Color.TRANSPARENT, 999)
	cb.content_margin_top = 8
	cb.content_margin_bottom = 8
	cb.content_margin_left = 12
	cb.content_margin_right = 14
	chip.add_theme_stylebox_override("panel", cb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UI.hbox(6)
	var flame := TextureRect.new()
	flame.texture = Icons.texture("flame", 16, Color("#8a3b12"))
	flame.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(flame)
	row.add_child(UI.label("%d day streak" % days, 14, Color("#8a3b12"), false, 800))
	chip.add_child(row)
	return chip


func _tab_selected(screen: String) -> bool:
	return screen == _current_name or (screen == "walks" and _current_name == "project_editor")


func _tab_bar() -> Control:
	var panel := PanelContainer.new()
	var pb := UI.box(UI.PAPER, Color.TRANSPARENT, 0)
	pb.border_width_top = 1
	pb.border_color = Color("#e6d9c0")
	pb.content_margin_top = 8
	pb.content_margin_bottom = 20
	pb.content_margin_left = 6
	pb.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", pb)
	var row := UI.hbox(0)
	panel.add_child(row)
	# Phones get five tabs; the noticeboard lives on the cabin screen.
	for tab in TABS:
		if tab[0] == "board":
			continue
		var selected := _tab_selected(tab[0])
		var colour := UI.FOREST if selected else UI.INK_SOFT
		var b := Button.new()
		b.text = tab[1]
		b.icon = Icons.texture(tab[2], 22, colour)
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 52)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_constant_override("h_separation", 2)
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		for s in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(s, colour)
		b.pressed.connect(App.go.bind(tab[0], {}))
		row.add_child(b)
	return panel
