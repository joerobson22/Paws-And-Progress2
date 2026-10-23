class_name ShelfEditor
extends Control
## Arranging the shelf, in a popup from the pencil on the gifts screen: the
## three spots stay along the top with every gift you've found scrolling
## below (in the order picked from "Sort by"). It's all drag and drop:
## drag a gift onto an empty spot to put it there, onto a full one to swap
## it in, along the shelf to move it, or off the shelf to take it down.
## Gifts already on the shelf are greyed out below. On a computer, gifts
## pick up as soon as you drag them; on a phone or tablet dragging scrolls
## the list, so press and hold one first. Tap any gift for a closer look. Every change saves
## straight away, and being a popup, none of it can move the app between
## screens.

const SORTS := [["rarity", "Rarity"], ["name", "A–Z"], ["animal", "Animal"]]

var modal: Modal
var _shelf_box: VBoxContainer
var _grid: GridContainer
var _slots: Array[Slot] = []
var _ghost: GiftArt
var _drag_id := ""
var _drag_from := -1
var _drag_source: Control
var _hover := -1
var _off_shelf := false
## The pointer while dragging, in viewport coordinates.
var _pointer := Vector2.ZERO


static func open() -> Modal:
	var m := Modal.open(560)
	var editor := ShelfEditor.new()
	editor.modal = m
	m.header.add_child(m.heading_row("Your shelf"))
	editor._shelf_box = UI.vbox(0)
	m.header.add_child(editor._shelf_box)
	var how := "Drag gifts onto the shelf, along it and off it." if _quick() \
		else "Hold a gift to pick it up, then drag it onto the shelf, along it or off it."
	m.header.add_child(UI.para(how + " Tap one for a closer look.", 13, UI.INK_SOFT))
	var head := UI.hbox(8)
	var cap := UI.caption("Your collection")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	head.add_child(UI.spacer())
	head.add_child(Dropdown.for_setting(SORTS, "gift_sort", "rarity"))
	m.header.add_child(head)
	editor._grid = GridContainer.new()
	editor._grid.add_theme_constant_override("h_separation", 10)
	editor._grid.add_theme_constant_override("v_separation", 10)
	m.body.add_child(editor._grid)
	# The editor itself lies over the whole popup, so the gift being dragged
	# draws on top of everything.
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(editor)
	editor.refresh()
	App.state_changed.connect(editor.refresh)
	return m


## Whether collection gifts pick up as soon as they're dragged: on a
## computer, where the list scrolls with the wheel. (The app turns mouse
## presses into touches, so it can't go by whether there's a touch screen.)
static func _quick() -> bool:
	return OS.has_feature("pc")


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


## Rebuilds the shelf and the collection from the saved state.
func refresh() -> void:
	for c in _shelf_box.get_children() + _grid.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_slots.clear()
	var row := UI.hbox(10)
	var shelf := App.state.shelf()
	for i in shelf.size():
		var slot := Slot.new()
		slot.custom_minimum_size = Vector2(0, 104)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = shelf[i]
		if id != "" and App.state.gift_count(id) > 0:
			var tile := GiftTile.new(id, App.state.gift_count(id), true)
			tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tile.draggable = true
			tile.quick_drag = true
			tile.lifted.connect(_lift.bind(i))
			tile.tapped.connect(GiftsPane.show_gift)
			slot.add_child(tile)
			slot.filled = true
		row.add_child(slot)
		_slots.append(slot)
	_shelf_box.add_child(row)
	var plank := Plank.new()
	plank.custom_minimum_size.y = 18
	_shelf_box.add_child(plank)

	_grid.columns = 5 if modal.body.custom_minimum_size.x >= 420.0 else 4
	# Found gifts you have at least one of: a traded-away gift can't go up.
	var ids: Array = App.state.inventory.keys().filter(func(gift): return not Content.gift(gift).is_empty() and App.state.gift_count(gift) > 0)
	for id in sort_gifts(ids, str(App.state.settings.get("gift_sort", "rarity")), bool(App.state.settings.get("gift_sort_reversed", false))):
		var tile := GiftTile.new(id, App.state.gift_count(id))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if shelf.has(id):
			tile.set_on_shelf()
		else:
			tile.draggable = true
			tile.quick_drag = _quick()
			tile.lifted.connect(_lift.bind(-1))
			tile.tapped.connect(GiftsPane.show_gift)
		_grid.add_child(tile)


# --- Dragging ----------------------------------------------------------------

func _lift(tile: GiftTile, from: int) -> void:
	if _drag_id != "":
		return
	_drag_id = tile.gift_id
	_drag_from = from
	_drag_source = tile
	tile.modulate.a = 0.3
	_ghost = GiftArt.new(_drag_id, 0.9)
	_ghost.size = Vector2(84, 84)
	_ghost.pivot_offset = _ghost.size * 0.5
	add_child(_ghost)
	_pointer = tile.press_point()
	_off_shelf = false
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
		# The release carries on to the list too, so it stops drag-scrolling.
		_pointer = e.position
		_update_hover()
		_drop()


func _move_ghost() -> void:
	_ghost.position = get_global_transform_with_canvas().affine_inverse() * _pointer - _ghost.size * 0.5


## Lights up the spot under the pointer. A shelf gift dragged away from the
## shelf shrinks and fades, to show it'll come down if you let go.
func _update_hover() -> void:
	var hit := -1
	for i in _slots.size():
		if _slots[i].get_global_rect().grow(10.0).has_point(_pointer):
			hit = i
	if hit != _hover:
		if _hover >= 0 and _hover < _slots.size():
			_slots[_hover].highlight = false
		_hover = hit
		if hit >= 0:
			_slots[hit].highlight = true
	var off := _drag_from >= 0 and not _shelf_box.get_global_rect().grow(10.0).has_point(_pointer)
	if off != _off_shelf:
		_off_shelf = off
		# The same key as dropping it, so a drop takes over from this.
		var t := Motion.tween(_ghost, "ghost")
		t.set_parallel(true)
		t.tween_property(_ghost, "modulate:a", 0.5 if off else 1.0, Motion.time(Motion.FAST))
		t.tween_property(_ghost, "scale", Vector2.ONE * (0.8 if off else 1.0), Motion.time(Motion.FAST))


func _drop() -> void:
	Gestures.claimed = false
	var id := _drag_id
	var from := _drag_from
	_drag_id = ""
	var ghost := _ghost
	var t := Motion.tween(ghost, "ghost")
	t.set_parallel(true)
	if _hover >= 0:
		# Onto a spot: an empty one takes it, a full one swaps it in (its gift
		# goes back to the collection, or along to where this one came from).
		var slot := _slots[_hover]
		var at := get_global_transform_with_canvas().affine_inverse() * slot.get_global_rect().get_center() - ghost.size * 0.5
		var target := _hover
		t.tween_property(ghost, "position", at, Motion.time(Motion.FAST))
		t.chain().tween_callback(func():
			ghost.queue_free()
			App.place_on_shelf(id, target))
		Audio.play("pop", 1.1, -4.0)
	elif from >= 0 and _off_shelf:
		# Dragged off the shelf: take it down.
		t.tween_property(ghost, "modulate:a", 0.0, Motion.time(Motion.FAST))
		t.tween_property(ghost, "scale", Vector2.ONE * 0.5, Motion.time(Motion.FAST))
		t.chain().tween_callback(func():
			ghost.queue_free()
			App.remove_from_shelf(from))
		Audio.play("pop", 0.7, -8.0)
	else:
		# Dropped nowhere: float back to where it came from.
		var source := _drag_source
		var home := get_global_transform_with_canvas().affine_inverse() * source.get_global_rect().get_center() - ghost.size * 0.5
		t.tween_property(ghost, "position", home, Motion.time(Motion.NORMAL))
		t.tween_property(ghost, "modulate:a", 0.0, Motion.time(Motion.NORMAL))
		t.chain().tween_callback(func():
			if is_instance_valid(source):
				source.modulate.a = 1.0
			ghost.queue_free())
	if _hover >= 0:
		_slots[_hover].highlight = false
	_hover = -1
	_off_shelf = false



## One spot on the shelf: dashed when empty, lit up while a gift hovers over it.
class Slot extends Control:
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
class Plank extends Control:
	func _draw() -> void:
		var b := UI.box(UI.SHELF, Color.TRANSPARENT, 7)
		b.shadow_color = Color(0, 0, 0, 0.08)
		b.shadow_size = 6
		b.shadow_offset = Vector2(0, 3)
		draw_style_box(b, Rect2(Vector2(0, 2), Vector2(size.x, 10)))
