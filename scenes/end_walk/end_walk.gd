extends Control
## End of a walk, back at the cabin under the night sky: what you did, and
## the gift your animal found, glowing in its rarity's colour.
## params: {"session": FocusSession, "gift": Dictionary} from App.finish_walk().

var params := {}

const SKY_TOP := Color("#27406b")
const SKY_BOTTOM := Color("#14233f")
const ON_SKY_SOFT := Color("#b8c8e8")


func _ready() -> void:
	var session: FocusSession = params.get("session")
	if session == null:
		App.go.call_deferred("home", {})
		return
	var project := App.state.project(session.project_id)
	var roll: Dictionary = params.get("gift", {})
	Audio.ambience("night")
	if not roll.is_empty() and project:
		Audio.play(str(Content.animal(project.animal_id).get("sound", "")))

	var sky := _Sky.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sky)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	centre.add_child(margin)

	var wide := UI.is_wide(self)
	var body: BoxContainer = UI.hbox(48) if wide else UI.vbox(24)
	margin.add_child(body)
	var summary := _summary(session, project, roll)
	var gift_card := _gift_card(session, project, roll)
	if wide:
		summary.custom_minimum_size.x = 380
		gift_card.custom_minimum_size.x = 400
		summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		var w := minf(420.0, get_viewport_rect().size.x - 48.0)
		summary.custom_minimum_size.x = w
		gift_card.custom_minimum_size.x = w
	body.add_child(summary)
	body.add_child(gift_card)


func _summary(session: FocusSession, project: ProjectData, roll: Dictionary) -> Control:
	var v := UI.vbox(14)
	v.add_child(UI.caption("Back at the cabin", ON_SKY_SOFT))
	var long_enough := session.focus_seconds >= int(Content.drop_table.get("min_seconds", 600))
	var title := UI.label("Lovely walk!" if long_enough else "Short and sweet", 48, UI.PAPER, true, 600)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	var project_name := project.name if project else "your project"
	var animal_name := ""
	if project:
		animal_name = Content.animal(project.animal_id).get("name", "").to_lower()
	var line := "You spent %s on %s" % [Stats.format_duration(session.focus_seconds), project_name]
	if not roll.is_empty():
		line += ", and the %s found something on the way." % animal_name
	elif session.focus_seconds < 60:
		line += ". Walks under a minute aren't added to your stats."
	else:
		line += ". Walk for at least %d minutes and your companion brings back a gift." % (int(Content.drop_table.get("min_seconds", 600)) / 60)
	v.add_child(UI.para(line, 18, Color("#dce4f4"), 600))

	var tiles := GridContainer.new()
	tiles.columns = 2
	tiles.add_theme_constant_override("h_separation", 10)
	var week := Stats.week_total(App.state.sessions, Stats.week_start(App.today()), App.tz_bias())
	tiles.add_child(_tile("This week", Stats.format_duration(week)))
	if project:
		tiles.add_child(_tile("%s total" % project.name, Stats.format_duration(App.state.project_seconds(project.id))))
	v.add_child(tiles)

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	actions.add_child(UI.button("Back to the cabin", App.go.bind("home", {}), UI.PAPER, SKY_BOTTOM))
	if project and not project.is_complete():
		var done := UI.button("Project finished?", _complete.bind(project.id), Color(1, 1, 1, 0.0), UI.PAPER)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb: StyleBoxFlat = done.get_theme_stylebox(state).duplicate()
			sb.set_border_width_all(2)
			sb.border_color = Color(1, 1, 1, 0.3)
			sb.bg_color = Color(1, 1, 1, 0.0 if state == "normal" else 0.08)
			done.add_theme_stylebox_override(state, sb)
		actions.add_child(done)
	v.add_child(actions)
	return v


func _tile(title: String, value: String) -> Control:
	var p := UI.panel(Color(1, 1, 1, 0.08), 18, 14)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(0)
	var t := UI.label(title, 13, ON_SKY_SOFT, false, 700)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	v.add_child(t)
	v.add_child(UI.label(value, 26, UI.PAPER, true, 600))
	p.add_child(v)
	return p


func _gift_card(session: FocusSession, project: ProjectData, roll: Dictionary) -> Control:
	var card := PanelContainer.new()
	var glow := Content.rarity_colour(roll.get("rarity", "common")) if not roll.is_empty() else UI.FOREST
	var cb := UI.box(UI.PAPER, Color(glow, 0.35), 32)
	cb.set_border_width_all(8)
	cb.set_content_margin_all(28)
	cb.shadow_color = Color(glow, 0.45)
	cb.shadow_size = 40 if not roll.is_empty() else 0
	card.add_theme_stylebox_override("panel", cb)
	var v := UI.vbox(10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)

	if roll.is_empty():
		if project:
			v.add_child(UI.animal_portrait(project.animal_id, project.colours, Vector2(0, 170), UI.SAGE))
		var none := UI.para("No gift this time. Gifts start at %d minutes, and longer walks bring rarer ones." % (int(Content.drop_table.get("min_seconds", 600)) / 60), 16, Color("#5c5246"), 700)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(none)
		return card

	var gift := Content.gift(roll["gift_id"])
	var rarity: String = roll["rarity"]
	var badge := UI.tag("%s gift" % Content.rarity_name(rarity).to_upper(), glow, UI.PAPER if rarity != "legendary" else Color("#3a2600"), 13)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)

	var halo := _Halo.new()
	halo.colour = glow
	halo.custom_minimum_size = Vector2(0, 200)
	v.add_child(halo)

	var name := UI.label(gift.get("name", "?"), 30, UI.INK, true, 600)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name)
	var animal_name: String = Content.animal(gift.get("animal", "")).get("name", "")
	var desc := UI.para("From the %s. %s" % [animal_name.to_lower(), gift.get("description", "")], 15, Color("#5c5246"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)

	var row := UI.hbox(10)
	if gift.has("slot"):
		var wear := UI.button("Wear it now", _wear.bind(gift["id"], gift["slot"]), glow, UI.PAPER if rarity != "legendary" else Color("#3a2600"))
		wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(wear)
	var shelf := UI.quiet_button("Put on shelf", App.go.bind("shelf", {"selected": gift["id"]}))
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(shelf)
	v.add_child(row)
	return card


func _wear(gift_id: String, slot: String) -> void:
	App.state.profile["cosmetics"][slot] = gift_id
	App.save()
	App.go("wardrobe", {"slot": slot})


func _complete(id: String) -> void:
	App.complete_project(id)
	Audio.play("project_complete")
	App.go("board")


## Night sky gradient with a few stars and the hill the cabin sits on.
class _Sky extends Control:
	func _draw() -> void:
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
		var stars := [Vector2(0.22, 0.12), Vector2(0.82, 0.2), Vector2(0.66, 0.08), Vector2(0.4, 0.05), Vector2(0.92, 0.45), Vector2(0.08, 0.35)]
		for i in stars.size():
			draw_circle(stars[i] * size, 2.0 + (i % 3), Color("#cfe0ff"), true, -1.0, true)
		var hill := PackedVector2Array()
		for i in 33:
			var t := i / 32.0
			hill.append(Vector2(t * size.x, size.y - 70.0 + 50.0 * pow(2.0 * t - 1.0, 2.0)))
		hill.append(Vector2(size.x, size.y))
		hill.append(Vector2(0, size.y))
		draw_colored_polygon(hill, UI.FOREST)


## Soft disc behind the gift with a gift-box icon, tinted by rarity.
class _Halo extends Control:
	var colour := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		for i in 12:
			var t := 1.0 - i / 12.0
			draw_circle(c, r * t, UI.PAPER.lerp(colour, 0.08 + 0.18 * (1.0 - t)), true, -1.0, true)
		var icon := Icons.texture("gift", 96, colour.darkened(0.15))
		draw_texture(icon, c - Vector2(48, 48))
