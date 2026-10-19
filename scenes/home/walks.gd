extends Control
## Choose a walk: pick who's coming (a project and its animal), where to and
## for how long, then head out.
## params: {"selected": project id} to keep a card picked after a rebuild.

var params := {}

## Walk lengths offered, in seconds; 0 is an open-ended walk.
const LENGTHS := [[1500, "25m"], [3600, "1h"], [7200, "2h"], [0, "Open"]]

var _selected: ProjectData


func _ready() -> void:
	Audio.ambience("cabin")
	var projects := App.state.active_projects()
	_selected = App.state.project(str(params.get("selected", "")))
	if (_selected == null or _selected.is_complete()) and not projects.is_empty():
		_selected = projects[0]

	var wide := UI.is_wide(self)
	var col := UI.page(self, 1220)
	var head := UI.header("Who's coming for a walk?")
	var filters := UI.hbox(8)
	filters.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if wide:
		filters.add_child(UI.pill_button("In progress · %d" % projects.size(), true, func(): pass))
		filters.add_child(UI.pill_button("Completed · %d" % App.state.completed_projects().size(), false, App.go.bind("board", {})))
		head.add_child(filters)
	col.add_child(head)

	var body: BoxContainer = UI.hbox(24) if wide else UI.vbox(16)
	col.add_child(body)

	var grid := GridContainer.new()
	grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_stretch_ratio = 1.6
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for p in projects:
		grid.add_child(_project_card(p))
	grid.add_child(_new_card(projects.is_empty()))
	body.add_child(grid)

	if _selected:
		var aside := _walk_options()
		if wide:
			aside.custom_minimum_size.x = 380
			aside.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		body.add_child(aside)


func _project_card(p: ProjectData) -> Control:
	var picked := _selected != null and p.id == _selected.id
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 140
	b.tooltip_text = p.name
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := UI.box(UI.PAPER if state == "normal" else UI.PAPER.darkened(0.03), UI.FOREST if picked else Color.TRANSPARENT, 24)
		sb.set_border_width_all(3)
		if not picked:
			sb.border_color = UI.PAPER
		if picked:
			sb.shadow_color = Color(UI.FOREST, 0.25)
			sb.shadow_size = 12
			sb.shadow_offset = Vector2(0, 6)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(App.go.bind("walks", {"selected": p.id}))

	var row := UI.hbox(16)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.offset_top = 18
	row.offset_bottom = -18
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var tint := UI.SAGE if p.kind != ProjectData.KIND_MODULE else Color("#e8e4ef")
	var portrait := UI.animal_portrait(p.animal_id, p.colours, Vector2(132, 104), tint)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse(portrait)
	row.add_child(portrait)

	var info := UI.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UI.hbox(6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if p.kind == ProjectData.KIND_MODULE:
		top.add_child(UI.tag("MODULE", Color("#e8e4ef"), Color("#4b3c78")))
	else:
		top.add_child(UI.tag("PROJECT", UI.SAGE, UI.FOREST))
	top.add_child(UI.spacer())
	if picked:
		var tick := TextureRect.new()
		tick.texture = Icons.texture("check", 14, UI.PAPER)
		tick.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tick.custom_minimum_size = Vector2(24, 24)
		var disc := UI.panel(UI.FOREST, 999, 0)
		disc.add_child(tick)
		top.add_child(disc)
	info.add_child(top)
	var name := UI.label(p.name, 22, UI.INK, true, 600)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	info.add_child(name)
	var animal_name: String = Content.animal(p.animal_id).get("name", "")
	var meta := UI.label("%s · %s walked" % [animal_name, Stats.format_duration(App.state.project_seconds(p.id))], 14, Color("#5c5246"), false, 700)
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.clip_text = true
	info.add_child(meta)
	row.add_child(info)
	_ignore_mouse(info)

	var edit := UI.icon_button("edit", "Edit %s" % p.name, App.go.bind("project_editor", {"id": p.id}), UI.TRACK, UI.INK, 40, 12)
	edit.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(edit)
	return b


func _new_card(first: bool) -> Control:
	var text := "Add your first project and pick its companion" if first else "New project, new companion"
	var b := UI.button(text, App.go.bind("project_editor", {}), UI.BG, Color("#5c5246"))
	b.icon = Icons.texture("plus", 20, Color("#5c5246"))
	b.add_theme_constant_override("h_separation", 12)
	b.custom_minimum_size.y = 140
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		sb.set_corner_radius_all(24)
		sb.set_border_width_all(3)
		sb.border_color = Color("#d3c2a2")
		sb.bg_color = UI.BG if state == "normal" else UI.PILL
		b.add_theme_stylebox_override(state, sb)
	return b


## The side panel: where, how long, the gift odds and the go button.
func _walk_options() -> Control:
	var card := UI.card(UI.PAPER, 24)
	var v := UI.vbox(20)
	card.add_child(v)
	var goal := int(App.state.settings.get("walk_goal_seconds", 3600))
	var biome_id := str(App.state.settings.get("walk_biome", "lake"))

	var where := UI.vbox(10)
	where.add_child(UI.caption("Where to?"))
	var places := GridContainer.new()
	places.columns = 3
	places.add_theme_constant_override("h_separation", 10)
	places.add_theme_constant_override("v_separation", 10)
	var hours := float(Stats.total_seconds(App.state.sessions) + int(App.state.profile.get("legacy_total_seconds", 0))) / 3600.0
	for b in Content.biomes:
		places.add_child(_place_tile(b, b["id"] == biome_id, hours >= float(b.get("unlock_hours", 0))))
	where.add_child(places)
	v.add_child(where)

	var length := UI.vbox(10)
	length.add_child(UI.caption("How long?"))
	var lengths := GridContainer.new()
	lengths.columns = 4
	lengths.add_theme_constant_override("h_separation", 8)
	for l in LENGTHS:
		var on: bool = l[0] == goal
		var b := UI.button(l[1], _set_goal.bind(l[0]), UI.FOREST if on else UI.TRACK, UI.ON_FOREST if on else UI.INK)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 48
		lengths.add_child(b)
	length.add_child(lengths)
	v.add_child(length)

	var odds := UI.vbox(10)
	var odds_at := goal if goal > 0 else 3600
	odds.add_child(UI.caption("Gift odds after %s" % _length_words(odds_at)))
	odds.add_child(UI.odds_bar(GiftRoller.percentages_for(odds_at, Content.drop_table)))
	v.add_child(odds)

	var animal_name: String = Content.animal(_selected.animal_id).get("name", "")
	var place: String = Content.biome(biome_id).get("walk_phrase", "by the lake")
	var go := UI.with_icon(UI.cta("Walk the %s %s" % [animal_name.to_lower(), place], _start), "play", UI.ON_APRICOT, 16)
	go.custom_minimum_size.y = 60
	go.add_theme_font_size_override("font_size", 18)
	v.add_child(go)
	return card


func _place_tile(b: Dictionary, picked: bool, unlocked: bool) -> Control:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(0, 84)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.disabled = not unlocked
	tile.tooltip_text = b.get("name", "") if unlocked else "Unlocks after %d hours of walks" % int(b.get("unlock_hours", 0))
	var sky := Color.from_string(str(b.get("swatch", "#7fb2c9")), Color("#7fb2c9"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := UI.box(sky if unlocked else UI.PILL, UI.FOREST if picked else Color.TRANSPARENT, 16)
		sb.set_border_width_all(3)
		if not picked:
			sb.border_color = Color.TRANSPARENT
		sb.set_content_margin_all(6)
		tile.add_theme_stylebox_override(state, sb)
	if unlocked:
		tile.pressed.connect(_set_biome.bind(b["id"]))
	var name_tag := UI.tag(b.get("name", ""), Color(UI.PAPER, 0.94), UI.INK)
	name_tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	name_tag.position = Vector2(6, 54)
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_tag)
	if not unlocked:
		tile.icon = Icons.texture("lock", 18, Color("#5c5246"))
		tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	return tile


func _length_words(seconds: int) -> String:
	if seconds % 3600 == 0:
		var h := seconds / 3600
		return "1 hour" if h == 1 else "%d hours" % h
	return "%d minutes" % (seconds / 60)


func _set_goal(seconds: int) -> void:
	App.set_setting("walk_goal_seconds", seconds)
	App.go("walks", {"selected": _selected.id})


func _set_biome(id: String) -> void:
	App.set_setting("walk_biome", id)
	App.go("walks", {"selected": _selected.id})


func _start() -> void:
	App.start_walk(_selected.id)
	App.go("walk")


static func _ignore_mouse(node: Node) -> void:
	for c in node.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)
