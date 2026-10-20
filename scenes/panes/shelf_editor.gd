class_name ShelfEditor
extends Control
## Arranging the shelf, in a popup from the pencil on the gifts screen: the
## three spots stay along the top with every gift you have scrolling below.
## Drag a gift onto a spot to put it there (swapping out what was there),
## drag one along the shelf to swap places, or drag one off the shelf to
## take it down. Shelf gifts move as soon as you drag them; collection gifts
## need a press and hold first, so the list still scrolls. Every change
## saves straight away. Being a popup, none of this can move the app
## between screens.

var modal: Modal
var _shelf_box: VBoxContainer
var _grid: GridContainer
var _slots: Array[Slot] = []
var _ghost: GiftArt
var _drag_id := ""
var _drag_from := -1
var _drag_source: Control
var _hover := -1
## The pointer while dragging, in viewport coordinates.
var _pointer := Vector2.ZERO


static func open() -> Modal:
	var m := Modal.open(560)
	var editor := ShelfEditor.new()
	editor.modal = m
	m.header.add_child(m.heading_row("Your shelf"))
	editor._shelf_box = UI.vbox(0)
	m.header.add_child(editor._shelf_box)
	m.header.add_child(UI.para("Drag gifts onto the shelf or along it, and off it to take them down. Hold a gift below to pick it up.", 13, UI.INK_SOFT))
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
			slot.add_child(tile)
			slot.filled = true
		row.add_child(slot)
		_slots.append(slot)
	_shelf_box.add_child(row)
	var plank := Plank.new()
	plank.custom_minimum_size.y = 18
	_shelf_box.add_child(plank)

	_grid.columns = 5 if modal.body.custom_minimum_size.x >= 420.0 else 4
	var ids: Array = App.state.inventory.keys().filter(func(gift): return not Content.gift(gift).is_empty() and App.state.gift_count(gift) > 0)
	for id in GiftsPane.sort_gifts(ids, str(App.state.settings.get("gift_sort", "rarity")), bool(App.state.settings.get("gift_sort_reversed", false))):
		var tile := GiftTile.new(id, App.state.gift_count(id))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if shelf.has(id):
			tile.set_on_shelf()
		else:
			tile.draggable = true
			tile.lifted.connect(_lift.bind(-1))
		_grid.add_child(tile)


# --- Dragging ----------------------------------------------------------------

func _lift(tile: GiftTile, from: int) -> void:
	_drag_id = tile.gift_id
	_drag_from = from
	_drag_source = tile
	tile.modulate.a = 0.3
	_ghost = GiftArt.new(_drag_id, 0.9)
	_ghost.size = Vector2(84, 84)
	_ghost.pivot_offset = _ghost.size * 0.5
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
		var at := get_global_transform_with_canvas().affine_inverse() * slot.get_global_rect().get_center() - ghost.size * 0.5
		var target := _hover
		t.tween_property(ghost, "position", at, Motion.time(Motion.FAST))
		t.chain().tween_callback(func():
			ghost.queue_free()
			App.place_on_shelf(id, target))
		Audio.play("pop", 1.1, -4.0)
	elif from >= 0 and not _shelf_box.get_global_rect().has_point(_pointer):
		# Dragged off the shelf: take it down.
		t.tween_property(ghost, "modulate:a", 0.0, Motion.time(Motion.FAST))
		t.tween_property(ghost, "scale", Vector2.ONE * 0.6, Motion.time(Motion.FAST))
		t.chain().tween_callback(func():
			ghost.queue_free()
			App.remove_from_shelf(from))
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
