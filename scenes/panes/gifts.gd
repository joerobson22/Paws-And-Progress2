extends Pane
## Gifts, to the left of the focus screen. Your three favourites sit on the
## shelf near the top; underneath is every gift you've found, with how many
## you've had, in the order picked from the "Filter by" menu. Press and hold
## a gift to pick it up, then drop it on the shelf; hold a shelf gift to move
## it along, or drag it off to take it down. Tap any gift for a closer look
## and to trade it in.

const SORTS := [["rarity", "Rarity"], ["name", "A–Z"], ["animal", "Animal"]]

var _slots: Array[_Slot] = []
var _shelf_card: Control
var _ghost: GiftArt
var _drag_id := ""
var _drag_from := -1
var _drag_source: Control
var _hover := -1
## The pointer while dragging, in viewport coordinates (from the events
## themselves, which also works for touch and for a consumed event).
var _pointer := Vector2.ZERO


func build() -> void:
	_slots.clear()
	_drag_id = ""
	var col := page(760)
	var found := _found()
	col.add_child(UI.title_row("Gifts", "%d of %d found" % [found.size(), Content.gifts.size()]))
	_shelf_card = _shelf()
	col.add_child(_shelf_card)
	if found.is_empty():
		var empty := UI.card(UI.SURFACE, 24)
		var v := UI.vbox(6)
		v.add_child(UI.label("No gifts yet", 20, UI.INK, true, 600))
		v.add_child(UI.para("Focus for %d minutes and your pet dives into the bushes to find you one." % (int(Content.drop_table.get("min_seconds", 600)) / 60)))
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
	var grid := GridContainer.new()
	grid.columns = clampi(int(col.custom_minimum_size.x / 100.0), 3, 7)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for id in found:
		var tile := GiftTile.new(id, App.state.gift_count(id))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.tapped.connect(show_gift)
		tile.lifted.connect(_lift.bind(-1))
		grid.add_child(tile)
	col.add_child(grid)


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


## The shelf: no box round it, just a plank with three gifts standing on it.
func _shelf() -> Control:
	var v := UI.vbox(0)
	var row := UI.hbox(10)
	var shelf := App.state.shelf()
	for i in shelf.size():
		var slot := _Slot.new()
		slot.custom_minimum_size = Vector2(0, 112)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = shelf[i]
		if id != "" and App.state.gift_count(id) > 0:
			var tile := GiftTile.new(id, App.state.gift_count(id), true)
			tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tile.tapped.connect(show_gift)
			tile.lifted.connect(_lift.bind(i))
			slot.add_child(tile)
			slot.filled = true
		row.add_child(slot)
		_slots.append(slot)
	v.add_child(row)
	var plank := _Plank.new()
	plank.custom_minimum_size.y = 18
	v.add_child(plank)
	return v


# --- Dragging ----------------------------------------------------------------

func _lift(tile: GiftTile, from: int) -> void:
	_drag_id = tile.gift_id
	_drag_from = from
	_drag_source = tile
	tile.modulate.a = 0.3
	_ghost = GiftArt.new(_drag_id, 0.9)
	_ghost.size = Vector2(84, 84)
	_ghost.pivot_offset = _ghost.size * 0.5
	_ghost.z_index = 20
	add_child(_ghost)
	_pointer = tile.press_point()
	_move_ghost()
	Motion.pop(_ghost, 0.15)
	Audio.play("pop", 0.85, -8.0)
	_update_hover()


func _input(e: InputEvent) -> void:
	if _drag_id == "":
		return
	if e is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		_pointer = e.position
		_move_ghost()
		_update_hover()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		get_viewport().set_input_as_handled()
		_pointer = e.position
		_update_hover()
		_drop()


func _move_ghost() -> void:
	_ghost.position = get_global_transform_with_canvas().affine_inverse() * _pointer - _ghost.size * 0.5


func _update_hover() -> void:
	var p := _pointer
	var hit := -1
	for i in _slots.size():
		if _slots[i].get_global_rect().grow(10.0).has_point(p):
			hit = i
	if hit != _hover:
		if _hover >= 0 and _hover < _slots.size():
			_slots[_hover].highlight = false
		_hover = hit
		if hit >= 0:
			_slots[hit].highlight = true


func _drop() -> void:
	Gestures.claimed = false
	var id := _drag_id
	var from := _drag_from
	_drag_id = ""
	var ghost := _ghost
	var t := Motion.tween(ghost, "drop")
	t.set_parallel(true)
	if _hover >= 0:
		var slot := _slots[_hover]
		var at := slot.get_global_rect().get_center() - get_global_rect().position - ghost.size * 0.5
		t.tween_property(ghost, "position", at, Motion.time(Motion.FAST))
		t.chain().tween_callback(App.place_on_shelf.bind(id, _hover))
		Audio.play("pop", 1.1, -4.0)
	elif from >= 0 and not _shelf_card.get_global_rect().has_point(_pointer):
		# Dragged off the shelf: take it down.
		t.tween_property(ghost, "modulate:a", 0.0, Motion.time(Motion.FAST))
		t.tween_property(ghost, "scale", Vector2.ONE * 0.6, Motion.time(Motion.FAST))
		t.chain().tween_callback(App.remove_from_shelf.bind(from))
	else:
		# Dropped nowhere: float back to where it came from.
		var source := _drag_source
		var home := source.get_global_rect().get_center() - get_global_rect().position - ghost.size * 0.5
		t.tween_property(ghost, "position", home, Motion.time(Motion.NORMAL))
		t.tween_property(ghost, "modulate:a", 0.0, Motion.time(Motion.NORMAL))
		t.chain().tween_callback(func():
			if is_instance_valid(source):
				source.modulate.a = 1.0
			ghost.queue_free())
	if _hover >= 0:
		_slots[_hover].highlight = false
	_hover = -1


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
			var spot := shelf.find("")
			App.place_on_shelf(id, spot if spot >= 0 else shelf.size() - 1)
			m.close()
			Toast.show_text("On your shelf"), "quiet"))


func _trade(m: Modal, id: String) -> void:
	var new_id := App.trade_in(id)
	m.close()
	if new_id != "":
		show_gift(new_id, true)


## One spot on the shelf: dashed when empty, lit up while a gift hovers over it.
class _Slot extends Control:
	var filled := false
	var highlight := false:
		set(v):
			highlight = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		if highlight:
			draw_style_box(UI.box(UI.ACCENT_SOFT, UI.ACCENT, 20), r)
		elif not filled:
			var c := r.get_center()
			var d := minf(r.size.x, r.size.y) * 0.62
			draw_arc(c, d * 0.5, 0, TAU, 40, UI.LINE, 2.0, true)
			var plus := Icons.texture("plus", 20, UI.INK_FAINT)
			draw_texture(plus, c - Vector2(10, 10))


## The shelf itself: a soft plank under the three spots.
class _Plank extends Control:
	func _draw() -> void:
		var b := UI.box(UI.SHELF, Color.TRANSPARENT, 7)
		b.shadow_color = Color(0, 0, 0, 0.08)
		b.shadow_size = 6
		b.shadow_offset = Vector2(0, 3)
		draw_style_box(b, Rect2(Vector2(0, 2), Vector2(size.x, 10)))
