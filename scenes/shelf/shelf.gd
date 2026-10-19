extends Control
## Gift shelf: every gift as a tile, found or still a mystery, filterable by
## rarity, with the picked gift shown large alongside.
## params: {"rarity": filter id or "", "selected": gift id}

var params := {}


func _ready() -> void:
	Audio.ambience("cabin")
	var filter := str(params.get("rarity", ""))
	var found := 0
	var total := 0
	for g in Content.gifts:
		var n := int(App.state.inventory.get(g["id"], 0))
		found += 1 if n > 0 else 0
		total += n
	var wide := UI.is_wide(self)
	var selected := Content.gift(str(params.get("selected", "")))
	if selected.is_empty():
		for g in Content.gifts:
			if int(App.state.inventory.get(g["id"], 0)) > 0:
				selected = g
				break

	var col := UI.page(self, 1220)
	var head := UI.header("Gift shelf", Callable(), "%d of %d found · %d gifts in total" % [found, Content.gifts.size(), total])
	col.add_child(head)
	var filters: Container = UI.hbox(8) if wide else HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	filters.add_theme_constant_override("v_separation", 8)
	filters.add_child(UI.pill_button("All", filter == "", App.go.bind("shelf", {"selected": selected.get("id", "")})))
	for r in GiftRoller.RARITIES:
		filters.add_child(UI.pill_button(Content.rarity_name(r), filter == r, App.go.bind("shelf", {"rarity": r, "selected": selected.get("id", "")})))
	if wide:
		filters.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(filters)
	else:
		col.add_child(filters)

	var body: BoxContainer = UI.hbox(24) if wide else UI.vbox(16)
	col.add_child(body)
	var shelf := UI.card(UI.PAPER, 20)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 6 if wide else 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	shelf.add_child(grid)
	for g in Content.gifts:
		if filter == "" or g["rarity"] == filter:
			grid.add_child(_tile(g, g.get("id") == selected.get("id"), filter))

	if not selected.is_empty():
		var detail := _detail(selected)
		if wide:
			detail.custom_minimum_size.x = 340
			detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			body.add_child(shelf)
			body.add_child(detail)
		else:
			body.add_child(detail)
			body.add_child(shelf)
	else:
		body.add_child(shelf)


func _tile(g: Dictionary, picked: bool, filter: String) -> Control:
	var count := int(App.state.inventory.get(g["id"], 0))
	var colour := Content.rarity_colour(g["rarity"])
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 104)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = g["name"] if count > 0 else "Not found yet"
	var fill := UI.PAPER.lerp(colour, 0.14) if count > 0 else UI.TRACK
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := UI.box(fill if state == "normal" or state == "disabled" else fill.darkened(0.05), UI.INK if picked else Color.TRANSPARENT, 18)
		sb.set_border_width_all(3)
		if not picked:
			sb.border_color = Color.TRANSPARENT
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override(state, sb)
	b.disabled = count == 0
	b.pressed.connect(App.go.bind("shelf", {"rarity": filter, "selected": g["id"]}))

	var v := UI.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 10
	v.offset_bottom = -8
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var icon := TextureRect.new()
	icon.texture = Icons.texture("gift" if count > 0 else "lock", 36 if count > 0 else 22, colour.darkened(0.1) if count > 0 else Color("#b3a58c"))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size.y = 40
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var name := UI.label(g["name"] if count > 0 else "???", 12, UI.INK if count > 0 else Color("#8a7d68"), false, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name)
	if count > 1:
		var badge := UI.tag("×%d" % count, UI.INK, UI.PAPER, 11)
		badge.position = Vector2(6, 6)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	return b


func _detail(g: Dictionary) -> Control:
	var card := UI.card(UI.PAPER, 24)
	var v := UI.vbox(12)
	card.add_child(v)
	var colour := Content.rarity_colour(g["rarity"])
	var big := UI.panel(UI.PAPER.lerp(colour, 0.16), 24, 0)
	big.custom_minimum_size.y = 180
	var icon := TextureRect.new()
	icon.texture = Icons.texture("gift", 96, colour.darkened(0.1))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	big.add_child(icon)
	v.add_child(big)

	var meta := UI.hbox(8)
	meta.add_child(UI.tag(Content.rarity_name(g["rarity"]).to_upper(), colour, UI.PAPER if g["rarity"] != "legendary" else Color("#3a2600")))
	var animal_name: String = Content.animal(g.get("animal", "")).get("name", "")
	meta.add_child(UI.label("from the %s" % animal_name.to_lower(), 14, UI.INK_SOFT, false, 700))
	v.add_child(meta)
	v.add_child(UI.label(g["name"], 28, UI.INK, true, 600))
	v.add_child(UI.para(g.get("description", ""), 15))
	var count := int(App.state.inventory.get(g["id"], 0))
	v.add_child(UI.label("You have %d" % count, 14, UI.INK_SOFT, false, 800))
	if g.has("slot"):
		var on: bool = str(App.state.profile["cosmetics"].get(g["slot"], "")) == g["id"]
		if on:
			v.add_child(UI.quiet_button("Wearing it", App.go.bind("wardrobe", {"slot": g["slot"]})))
		else:
			v.add_child(UI.button("Wear it", _wear.bind(g["id"], g["slot"])))
	return card


func _wear(gift_id: String, slot: String) -> void:
	App.state.profile["cosmetics"][slot] = gift_id
	App.save()
	App.go("wardrobe", {"slot": slot})
