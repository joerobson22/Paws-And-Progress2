class_name GiftsPane
extends Pane
## Gifts, to the left of the focus screen: your three favourites on the
## shelf, and three rings for how your collection's coming along (gifts
## discovered, animals whose whole gift table you've found, and cosmetics
## unlocked from gifts). Shelf gifts grow and glint under the pointer; tap one
## for a closer look and its trade-in. The pencil opens the shelf editor,
## with every gift you've found, where arranging the shelf is all drag and
## drop.

var _slots: Array[ShelfEditor.Slot] = []
var _rings: Array[ProgressRing] = []


func build() -> void:
	_slots.clear()
	_rings.clear()
	var col := page(760, 22)
	var counts := Collection.progress(App.state.inventory, Content.gifts, Content.animals)
	col.add_child(UI.title_row("Gifts", "%d of %d found" % [counts["found"], counts["gifts"]]))
	col.add_child(_shelf(col.custom_minimum_size.x))
	if counts["found"] == 0:
		var empty := UI.card(UI.SURFACE, 24)
		var v := UI.vbox(6)
		v.add_child(UI.label("No gifts yet", 20, UI.INK, true, 600))
		v.add_child(UI.para("Focus for %d minutes and your pet dives into the bushes to find you one." % floori(Content.drop_table.get("min_seconds", 600) / 60.0)))
		empty.add_child(v)
		col.add_child(empty)
	col.add_child(_progress(counts, col.custom_minimum_size.x))


## The rings fill up each time you come to the screen.
func _on_shown() -> void:
	for ring in _rings:
		ring.sweep()


## The shelf: no box round it, just a plank with three gifts standing on it
## and a pencil to arrange them.
func _shelf(width: float) -> Control:
	var v := UI.vbox(4)
	var head := UI.hbox(8)
	var cap := UI.caption("Your shelf")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	head.add_child(UI.spacer())
	head.add_child(UI.round_button("edit", "Arrange your shelf", ShelfEditor.open, UI.SURFACE, UI.INK, 34))
	v.add_child(head)
	var row := UI.hbox(10)
	var shelf := App.state.shelf()
	for i in shelf.size():
		var slot := ShelfEditor.Slot.new()
		# As tall as a spot is wide, up to a point, so the gifts are as big as fits.
		slot.custom_minimum_size = Vector2(0, clampf((width - 20.0) / 3.0, 104.0, 160.0))
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = shelf[i]
		if id != "" and App.state.gift_count(id) > 0:
			var tile := GiftTile.new(id, App.state.gift_count(id), true)
			tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tile.tapped.connect(show_gift)
			slot.add_child(tile)
			slot.filled = true
		row.add_child(slot)
		_slots.append(slot)
	v.add_child(row)
	var plank := ShelfEditor.Plank.new()
	plank.custom_minimum_size.y = 18
	v.add_child(plank)
	return v


## Three rings side by side: gifts in green, pets' gift tables in blue and
## cosmetics in purple (the common, rare and epic colours).
func _progress(counts: Dictionary, width: float) -> Control:
	var section := UI.vbox(10)
	section.add_child(UI.caption("Your collection"))
	var card := UI.card(UI.SURFACE, 18)
	var row := UI.hbox(10)
	card.add_child(row)
	section.add_child(card)
	var diameter := clampf((width - 56.0) / 3.0 - 12.0, 72.0, 124.0)
	var stats := [
		["Discovered", "%d of %d gifts" % [counts["found"], counts["gifts"]], counts["found"], counts["gifts"], "common",
			"Every gift you've ever found"],
		["Pet tables", "%d of %d complete" % [counts["tables"], counts["animals"]], counts["tables"], counts["animals"], "rare",
			"Animals whose gifts you've found every one of"],
		["Cosmetics", "%d of %d unlocked" % [counts["cosmetics"], counts["wearables"]], counts["cosmetics"], counts["wearables"], "epic",
			"Gifts you can wear, out of all of them (trading the last one away takes it off you)"],
	]
	for s in stats:
		var cell := UI.vbox(4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.tooltip_text = s[5]
		var ring := ProgressRing.new(Collection.fraction(s[2], s[3]), Content.rarity_colour(s[4]), diameter)
		_rings.append(ring)
		cell.add_child(ring)
		var name_label := UI.label(s[0], 15, UI.INK, false, 800)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)
		var sub := UI.label(s[1], 12, UI.INK_FAINT, false, 700)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(sub)
		row.add_child(cell)
	return section


# --- Gift popup --------------------------------------------------------------

## A closer look at one gift, with its trade-in. `fresh` celebrates a gift
## that's just arrived from a trade. Opened from the shelf here and from the
## shelf editor; putting gifts on and off the shelf is done by dragging them
## in the editor, not from here.
static func show_gift(id: String, fresh: bool = false) -> void:
	var g := Content.gift(id)
	if g.is_empty():
		return
	var count := App.state.gift_count(id)
	var rarity: String = g["rarity"]
	var m := Modal.open(400)
	m.body.add_child(m.heading_row(g["name"]))
	var art := GiftArt.new(id, 1.0)
	art.custom_minimum_size = Vector2(0, 170)
	m.body.add_child(art)
	if fresh:
		Audio.play("chime", 1.0, -4.0)
		art.get_tree().create_timer(Motion.time(Motion.NORMAL)).timeout.connect(func():
			if is_instance_valid(art):
				Motion.pop(art, 0.2, 0.5))

	var meta := UI.hbox(8)
	meta.add_child(UI.tag(Content.rarity_name(rarity).to_upper(), Content.rarity_colour(rarity), UI.ON_COLOUR))
	var animal_name: String = Content.animal(g["animal"]).get("name", "")
	meta.add_child(UI.label("from the %s" % animal_name.to_lower(), 14, UI.INK_SOFT, false, 700))
	if fresh:
		meta.add_child(UI.spacer())
		meta.add_child(UI.tag("NEW", UI.INK, UI.BG))
	m.body.add_child(meta)
	m.body.add_child(UI.para(g.get("description", ""), 16, UI.INK))
	if g.has("slot"):
		m.body.add_child(UI.para("Wearable (%s). Dress your character on your profile, above the focus screen." % Content.slot_name(g["slot"]).to_lower(), 14))
	m.body.add_child(UI.label("You have %d" % count, 15, UI.INK_SOFT, false, 800))

	var cost := Content.trade_cost(rarity)
	var next := Content.next_rarity(rarity)
	if cost > 0 and next != "":
		var next_name := Content.rarity_name(next).to_lower()
		if count >= cost:
			var trade := UI.button("Trade in %d for %s" % [cost, UI.a(next_name)], func(): _trade(m, id), "accent")
			trade.icon = Icons.texture("trade", 18, Color.WHITE)
			trade.add_theme_constant_override("h_separation", 10)
			m.body.add_child(trade)
		else:
			m.body.add_child(UI.para("Trade in %d for %s gift: %d more to go." % [cost, UI.a(next_name), cost - count], 14, UI.INK_FAINT))
	else:
		m.body.add_child(UI.para("Legendary gifts can't be traded in.", 14, UI.INK_FAINT))


## Trading away the last of a shelf gift takes it off the shelf too.
static func _trade(m: Modal, id: String) -> void:
	var new_id := App.trade_in(id)
	m.close()
	if new_id != "":
		show_gift(new_id, true)
