extends Control
## Gift shelf: every animal's gifts, found or still a mystery.

var params := {}


func _ready() -> void:
	var col := UI.page(self, 1000)
	col.add_child(UI.header("Gift shelf"))
	var found := 0
	for g in Content.gifts:
		if int(App.state.inventory.get(g["id"], 0)) > 0:
			found += 1
	col.add_child(UI.para("%d of %d gifts found. Longer walks bring rarer gifts." % [found, Content.gifts.size()]))

	for a in Content.animals:
		var card := UI.card()
		var c := UI.vbox(10)
		card.add_child(c)
		c.add_child(UI.label(a["name"], 20, UI.INK, true, 600))
		var grid := GridContainer.new()
		grid.columns = 4 if UI.is_wide(self) else 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for g in Content.gifts_for(a["id"]):
			grid.add_child(_tile(g))
		c.add_child(grid)
		col.add_child(card)


func _tile(g: Dictionary) -> Control:
	var count := int(App.state.inventory.get(g["id"], 0))
	var rarity_colour := Content.rarity_colour(g["rarity"])
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", UI.box(UI.BG if count > 0 else UI.TRACK, rarity_colour if count > 0 else Color.TRANSPARENT))
	var v := UI.vbox(2)
	tile.add_child(v)
	v.add_child(UI.label(Content.rarity_name(g["rarity"]).to_upper(), 11, rarity_colour, false, 800))
	if count > 0:
		v.add_child(UI.label(g["name"], 16, UI.INK, false, 800))
		v.add_child(UI.label("×%d" % count if count > 1 else ("Wearable" if g.has("slot") else " "), 13, UI.INK_SOFT))
		tile.tooltip_text = g["description"]
	else:
		v.add_child(UI.label("???", 16, UI.INK_SOFT, false, 800))
		v.add_child(UI.label(" ", 13))
	return tile
