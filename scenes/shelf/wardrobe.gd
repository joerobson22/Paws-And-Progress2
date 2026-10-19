extends Control
## Wardrobe: skin and hair tone, plus wearing epic and legendary gifts.

var params := {}

var _preview: WalkerView
var _preview_box: Control


func _ready() -> void:
	var col := UI.page(self)
	col.add_child(UI.header("Wardrobe"))

	_preview_box = PanelContainer.new()
	_preview_box.add_theme_stylebox_override("panel", UI.box(Color("#e5efe2"), Color.TRANSPARENT, 24))
	_preview_box.custom_minimum_size.y = 220
	var holder := Control.new()
	_preview_box.add_child(holder)
	_preview = WalkerView.new()
	holder.add_child(_preview)
	holder.resized.connect(func(): _preview.position = Vector2(holder.size.x * 0.5, holder.size.y - 10.0))
	col.add_child(_preview_box)

	var tones := UI.card()
	var t := UI.vbox(10)
	tones.add_child(t)
	t.add_child(UI.caption("Skin tone"))
	t.add_child(_swatches(WalkerView.SKIN_TONES, "skin_tone"))
	t.add_child(UI.caption("Hair colour"))
	t.add_child(_swatches(WalkerView.HAIR_TONES, "hair_tone"))
	col.add_child(tones)

	var wear := UI.card()
	var w := UI.vbox(10)
	wear.add_child(w)
	w.add_child(UI.caption("Wearables"))
	var any := false
	for slot in GameState.COSMETIC_SLOTS:
		var owned: Array = Content.gifts.filter(func(g): return g.get("slot", "") == slot and int(App.state.inventory.get(g["id"], 0)) > 0)
		if owned.is_empty():
			continue
		any = true
		w.add_child(UI.label(slot.capitalize(), 16, UI.INK, false, 800))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		row.add_child(_equip_button("Default", slot, ""))
		for g in owned:
			row.add_child(_equip_button(g["name"], slot, g["id"]))
		w.add_child(row)
	if not any:
		w.add_child(UI.para("Epic and legendary gifts can be worn. Take a long walk to find one.", 16, UI.INK_SOFT))
	col.add_child(wear)


func _swatches(colours: Array[Color], key: String) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	for i in colours.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(44, 44)
		var selected := int(App.state.profile[key]) == i
		var style := UI.box(colours[i], UI.FOREST if selected else Color.TRANSPARENT, 999)
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(s, style)
		b.pressed.connect(_set_profile.bind(key, i))
		row.add_child(b)
	return row


func _equip_button(text: String, slot: String, gift_id: String) -> Button:
	var on := str(App.state.profile["cosmetics"].get(slot, "")) == gift_id
	var b := UI.button(text, _equip.bind(slot, gift_id), UI.FOREST if on else UI.TRACK, UI.ON_FOREST if on else UI.INK)
	b.custom_minimum_size.y = 44
	return b


func _set_profile(key: String, value: int) -> void:
	App.state.profile[key] = value
	App.save()
	App.go("wardrobe")


func _equip(slot: String, gift_id: String) -> void:
	App.state.profile["cosmetics"][slot] = gift_id
	App.save()
	App.go("wardrobe")
