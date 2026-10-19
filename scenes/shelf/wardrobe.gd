extends Control
## Wardrobe: your walker with skin and hair tone on one side; on the other,
## a tab per clothing slot listing what you can wear and what's still to find.
## params: {"slot": the open tab}

var params := {}

const SLOT_NAMES := {
	"hat": "Hats", "hair": "Hair", "face": "Face", "jumper": "Jumpers", "neckwear": "Neckwear",
	"handwear": "Rings", "walking_stick": "Walking sticks", "trousers": "Trousers",
}


func _ready() -> void:
	Audio.ambience("cabin")
	var slots := _slots_with_items()
	var slot := str(params.get("slot", ""))
	if not slots.has(slot):
		slot = _first_equipped_slot(slots)

	var wide := UI.is_wide(self)
	var col := UI.page(self, 1220)
	col.add_child(UI.header("Wardrobe", Callable(), "Epic and legendary gifts can be worn on walks"))
	var body: BoxContainer = UI.hbox(24) if wide else UI.vbox(16)
	col.add_child(body)

	var left := _walker_panel(wide)
	body.add_child(left)
	var right := UI.card(UI.PAPER, 22)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.3
	var r := UI.vbox(16)
	right.add_child(r)
	body.add_child(right)

	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	for s in slots:
		tabs.add_child(UI.pill_button(SLOT_NAMES.get(s, s.capitalize()), s == slot, App.go.bind("wardrobe", {"slot": s}), 38))
	r.add_child(tabs)

	var grid := GridContainer.new()
	grid.columns = 4 if wide else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.add_child(_item("", slot))
	var legendary := {}
	for g in Content.gifts:
		if g.get("slot", "") != slot:
			continue
		grid.add_child(_item(g["id"], slot))
		if g["rarity"] == "legendary" and int(App.state.inventory.get(g["id"], 0)) == 0:
			legendary = g
	r.add_child(grid)
	if not legendary.is_empty():
		r.add_child(_legendary_hint(legendary))


## Slots that have at least one wearable gift in the content.
func _slots_with_items() -> Array:
	var out := []
	for s in GameState.COSMETIC_SLOTS:
		for g in Content.gifts:
			if g.get("slot", "") == s:
				out.append(s)
				break
	return out


func _first_equipped_slot(slots: Array) -> String:
	for s in slots:
		if str(App.state.profile["cosmetics"].get(s, "")) != "":
			return s
	return slots[0] if not slots.is_empty() else "hat"


func _walker_panel(wide: bool) -> Control:
	var panel := UI.panel(UI.SAGE, 28, 20)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(16)
	panel.add_child(v)
	var stage := Control.new()
	stage.custom_minimum_size.y = 300 if wide else 240
	var ground := _Ground.new()
	stage.add_child(ground)
	var walker := WalkerView.new()
	walker.scale = Vector2(1.8, 1.8)
	stage.add_child(walker)
	stage.resized.connect(func():
		walker.position = Vector2(stage.size.x * 0.5, stage.size.y - 24.0)
		ground.position = Vector2(stage.size.x * 0.5, stage.size.y - 20.0))
	v.add_child(stage)

	var tones := UI.panel(Color(UI.PAPER, 0.94), 22, 16)
	var t := UI.vbox(10)
	tones.add_child(t)
	t.add_child(_swatch_row("Skin", WalkerView.SKIN_TONES, "skin_tone"))
	t.add_child(_swatch_row("Hair", WalkerView.HAIR_TONES, "hair_tone"))
	v.add_child(tones)
	return panel


func _swatch_row(title: String, colours: Array[Color], key: String) -> Control:
	var row := UI.hbox(12)
	var l := UI.label(title, 14, UI.INK, false, 800)
	l.custom_minimum_size.x = 44
	row.add_child(l)
	var swatches := HFlowContainer.new()
	swatches.add_theme_constant_override("h_separation", 8)
	swatches.add_theme_constant_override("v_separation", 8)
	swatches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in colours.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(36, 36)
		b.tooltip_text = "%s %d" % [title, i + 1]
		var selected := int(App.state.profile[key]) == i
		var style := UI.box(colours[i], UI.INK if selected else Color.TRANSPARENT, 999)
		style.set_border_width_all(3)
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, style)
		b.pressed.connect(_set_profile.bind(key, i))
		swatches.add_child(b)
	row.add_child(swatches)
	return row


## One wardrobe card: worn, owned, or still to find (with who brings it).
func _item(gift_id: String, slot: String) -> Control:
	var g := Content.gift(gift_id)
	var owned := gift_id == "" or int(App.state.inventory.get(gift_id, 0)) > 0
	var wearing: bool = owned and str(App.state.profile["cosmetics"].get(slot, "")) == gift_id
	var colour := UI.FOREST if gift_id == "" else Content.rarity_colour(g["rarity"])
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not owned
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var fill := UI.BG if owned else UI.TRACK
		var sb := UI.box(fill if state in ["normal", "disabled"] else fill.darkened(0.04), UI.FOREST if wearing else Color.TRANSPARENT, 20)
		sb.set_border_width_all(3)
		if not wearing:
			sb.border_color = Color.TRANSPARENT
		b.add_theme_stylebox_override(state, sb)
	if owned:
		b.pressed.connect(_equip.bind(slot, gift_id))

	var v := UI.vbox(4)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 12
	v.offset_bottom = -10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var top := UI.hbox(4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wearing:
		top.add_child(UI.tag("WEARING", UI.FOREST, UI.PAPER, 11))
	top.add_child(UI.spacer())
	v.add_child(top)
	var icon := TextureRect.new()
	icon.texture = Icons.texture("shirt" if owned else "lock", 34 if owned else 22, colour if owned else Color("#b3a58c"))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var name := UI.label("Your own" if gift_id == "" else g["name"], 14, UI.INK if owned else Color("#8a7d68"), false, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	v.add_child(name)
	var sub := "Starter"
	if gift_id != "":
		var animal_name: String = Content.animal(g["animal"]).get("name", "")
		sub = "%s · %s" % [Content.rarity_name(g["rarity"]), animal_name] if owned else "Walk the %s" % animal_name.to_lower()
	var sl := UI.label(sub, 12, Content.rarity_text_colour(g.get("rarity", "common")) if owned and gift_id != "" else UI.INK_SOFT, false, 700)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.clip_text = true
	v.add_child(sl)
	for c in v.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _legendary_hint(g: Dictionary) -> Control:
	var p := UI.panel(Color("#fbf1d6"), 18, 14)
	var row := UI.hbox(12)
	p.add_child(row)
	var star := TextureRect.new()
	star.texture = Icons.texture("star", 28, Content.rarity_colour("legendary"))
	star.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(star)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label("Legendary: %s" % g["name"], 15, Color("#6b4a00"), false, 800))
	var animal_name: String = Content.animal(g["animal"]).get("name", "")
	text.add_child(UI.para("Only the %s finds it, and only on long walks." % animal_name.to_lower(), 14, Color("#6b5a33")))
	row.add_child(text)
	return p


func _set_profile(key: String, value: int) -> void:
	App.state.profile[key] = value
	App.save()
	App.go("wardrobe", params)


func _equip(slot: String, gift_id: String) -> void:
	App.state.profile["cosmetics"][slot] = gift_id
	App.save()
	App.go("wardrobe", {"slot": slot})


## Soft oval shadow the walker stands on.
class _Ground extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 110.0, Color("#b9d1ae"), true, -1.0, true)
