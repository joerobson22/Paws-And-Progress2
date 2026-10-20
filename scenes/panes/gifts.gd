class_name GiftsPane
extends Pane
## Gifts, to the left of the focus screen. Your three favourites sit on the
## shelf near the top (the pencil beside it opens the shelf editor, where
## gifts are dragged on, along and off); underneath is every gift you've
## found, with how many you've had, in the order picked from the "Filter by"
## menu. Only the collection scrolls. Gifts on the shelf grow and glint under
## the pointer and are greyed out in the collection, so each is handled from
## one place. Tap any gift for a closer look and to trade it in; putting one
## on a full shelf sets the shelf wobbling until you tap the gift to swap out
## (anywhere else cancels).

const SORTS := [["rarity", "Rarity"], ["name", "A–Z"], ["animal", "Animal"]]

var _slots: Array[ShelfEditor.Slot] = []
## The gift waiting to go on a full shelf, while the shelf wobbles; "" if none.
var _swapping := ""


func build() -> void:
	_slots.clear()
	_swapping = ""
	var col := _frame(760)
	var found := _found()
	col.add_child(UI.title_row("Gifts", "%d of %d found" % [found.size(), Content.gifts.size()]))
	col.add_child(_shelf())
	if found.is_empty():
		var empty := UI.card(UI.SURFACE, 24)
		var v := UI.vbox(6)
		v.add_child(UI.label("No gifts yet", 20, UI.INK, true, 600))
		v.add_child(UI.para("Focus for %d minutes and your pet dives into the bushes to find you one." % floori(Content.drop_table.get("min_seconds", 600) / 60.0)))
		empty.add_child(v)
		col.add_child(empty)
		return

	var head := UI.hbox(8)
	var cap := UI.caption("Your collection")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	head.add_child(UI.spacer())
	var sort := Dropdown.new(SORTS, str(App.state.settings.get("gift_sort", "rarity")),
		bool(App.state.settings.get("gift_sort_reversed", false)), "Filter by")
	sort.chosen.connect(func(option: String, reversed: bool):
		App.state.settings["gift_sort"] = option
		App.set_setting("gift_sort_reversed", reversed))
	head.add_child(sort)
	col.add_child(head)

	# Only the collection scrolls, under everything above it.
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_top", 4)
	pad.add_theme_constant_override("margin_right", 6)
	# Room under the last row to scroll it clear of the minimap.
	pad.add_theme_constant_override("margin_bottom", 96 + int(UI.safe_insets(self)["bottom"]))
	scroll.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = clampi(int(col.custom_minimum_size.x / 100.0), 3, 7)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var shelf := App.state.shelf()
	for id in found:
		var tile := GiftTile.new(id, App.state.gift_count(id))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if shelf.has(id):
			tile.set_on_shelf()
		else:
			tile.tapped.connect(show_gift)
		grid.add_child(tile)
	pad.add_child(grid)


## A column filling the pane, centred and at most `max_width` wide, that
## doesn't scroll as a whole (unlike page()): the gifts screen scrolls just
## its collection.
func _frame(max_width: float) -> VBoxContainer:
	var insets := UI.safe_insets(self)
	var gutter := 32.0 if wide else 18.0
	var width := maxf(0.0, minf(max_width, size.x - 2.0 * gutter - insets["left"] - insets["right"]))
	var side := maxf(gutter, (size.x - width) * 0.5)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(side + insets["left"]))
	margin.add_theme_constant_override("margin_right", int(side + insets["right"]))
	margin.add_theme_constant_override("margin_top", 26 + int(insets["top"]))
	add_child(margin)
	var column := UI.vbox(18)
	column.custom_minimum_size.x = width
	margin.add_child(column)
	return column


## Gifts found so far, in the chosen order.
func _found() -> Array:
	var ids: Array = App.state.inventory.keys().filter(func(id): return not Content.gift(id).is_empty())
	return sort_gifts(ids, str(App.state.settings.get("gift_sort", "rarity")), bool(App.state.settings.get("gift_sort_reversed", false)))


## Rarity puts the rarest first; A–Z is by name; animal follows the cast,
## commonest first within each. `reversed` flips the whole order.
static func sort_gifts(ids: Array, by: String, reversed: bool) -> Array:
	var order := {}
	for i in Content.animals.size():
		order[Content.animals[i]["id"]] = i
	var key := func(id: String) -> Array:
		var g := Content.gift(id)
		var rarity := GiftRoller.RARITIES.find(g["rarity"])
		match by:
			"name":
				return [str(g["name"]).to_lower()]
			"animal":
				return [order.get(g["animal"], 99), rarity]
			_:
				return [-rarity, str(g["name"]).to_lower()]
	var out := ids.duplicate()
	out.sort_custom(func(a, b): return key.call(a) < key.call(b))
	if reversed:
		out.reverse()
	return out


## The shelf: no box round it, just a plank with three gifts standing on it
## and a pencil to rearrange them.
func _shelf() -> Control:
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
		slot.custom_minimum_size = Vector2(0, 112)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = shelf[i]
		if id != "" and App.state.gift_count(id) > 0:
			var tile := GiftTile.new(id, App.state.gift_count(id), true)
			tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tile.tapped.connect(_on_shelf_tapped.bind(i))
			slot.add_child(tile)
			slot.filled = true
		row.add_child(slot)
		_slots.append(slot)
	v.add_child(row)
	var plank := ShelfEditor.Plank.new()
	plank.custom_minimum_size.y = 18
	v.add_child(plank)
	return v


func _on_shelf_tapped(gift_id: String, index: int) -> void:
	if _swapping != "":
		var incoming := _swapping
		_stop_swapping()
		App.place_on_shelf(incoming, index)
		Toast.show_text("On your shelf")
	else:
		show_gift(gift_id)


# --- Swapping onto a full shelf ----------------------------------------------

## The shelf's full: its gifts wobble until you tap the one to swap out.
func _start_swapping(gift_id: String) -> void:
	_swapping = gift_id
	for slot in _slots:
		for tile in slot.get_children():
			var t := Motion.tween(tile, "wobble")
			t.set_loops()
			t.tween_property(tile, "rotation", 0.07, Motion.time(0.12))
			t.tween_property(tile, "rotation", -0.07, Motion.time(0.24))
			t.tween_property(tile, "rotation", 0.0, Motion.time(0.12))
	Toast.show_text("Tap a shelf gift to swap for %s" % Content.gift(gift_id).get("name", ""), "gift")


func _stop_swapping() -> void:
	_swapping = ""
	for slot in _slots:
		for tile in slot.get_children():
			# A new "wobble" tween replaces the looping one.
			Motion.tween(tile, "wobble").tween_property(tile, "rotation", 0.0, Motion.time(Motion.FAST))


## While the shelf wobbles, a tap anywhere but on a shelf gift cancels.
func _input(e: InputEvent) -> void:
	if _swapping == "" or not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	for slot in _slots:
		if slot.filled and slot.get_global_rect().has_point(e.position):
			return
	get_viewport().set_input_as_handled()
	_stop_swapping()


func _on_hidden() -> void:
	if _swapping != "":
		_stop_swapping()


# --- Gift popup --------------------------------------------------------------

## A closer look at one gift, with its trade-in. `fresh` celebrates a gift
## that's just arrived from a trade.
func show_gift(id: String, fresh: bool = false) -> void:
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
		get_tree().create_timer(Motion.time(Motion.NORMAL)).timeout.connect(func():
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
			var trade := UI.button("Trade in %d for %s" % [cost, UI.a(next_name)], _trade.bind(m, id), "accent")
			trade.icon = Icons.texture("trade", 18, Color.WHITE)
			trade.add_theme_constant_override("h_separation", 10)
			m.body.add_child(trade)
		else:
			m.body.add_child(UI.para("Trade in %d for %s gift: %d more to go." % [cost, UI.a(next_name), cost - count], 14, UI.INK_FAINT))
	else:
		m.body.add_child(UI.para("Legendary gifts can't be traded in.", 14, UI.INK_FAINT))

	var shelf := App.state.shelf()
	var on := shelf.find(id)
	if on >= 0:
		m.body.add_child(UI.button("Take off your shelf", func():
			App.remove_from_shelf(on)
			m.close(), "quiet"))
	elif count > 0:
		m.body.add_child(UI.button("Put on your shelf", func():
			m.close()
			var spot := shelf.find("")
			if spot >= 0:
				App.place_on_shelf(id, spot)
				Toast.show_text("On your shelf")
			else:
				_start_swapping(id), "quiet"))


func _trade(m: Modal, id: String) -> void:
	var new_id := App.trade_in(id)
	m.close()
	if new_id != "":
		show_gift(new_id, true)
