class_name GiftShelf
extends VBoxContainer
## A shelf of three favourite gifts: no box round it, just the gifts standing
## on a soft plank, glowing in their rarity's colours. Empty spots show a
## dashed ring. On its own it's only to look at (your profile, a friend's);
## the shelf editor passes `setup` to make its gifts draggable. Every shelf
## in the app is one of these, so they all look alike.

var slots: Array[Slot] = []


## `ids` is a gift id per spot ("" for an empty one). `height` is how tall
## each spot is. `setup` is called with each gift's tile and its spot's
## index, to wire it up.
func _init(ids: Array, height: float, setup: Callable = Callable()) -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in ids.size():
		var slot := Slot.new()
		slot.custom_minimum_size = Vector2(0, height)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = ids[i]
		if id != "":
			var tile := GiftTile.new(id, -1, true, height - 12.0)
			tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			if setup.is_valid():
				setup.call(tile, i)
			slot.add_child(tile)
			slot.filled = true
		row.add_child(slot)
		slots.append(slot)
	add_child(row)
	var plank := Plank.new()
	plank.custom_minimum_size.y = 16
	add_child(plank)


## Your own shelf, leaving out any gift you've since traded every one of away.
static func mine() -> Array:
	return App.state.shelf().map(func(id): return id if id != "" and App.state.gift_count(id) > 0 else "")


## One spot on the shelf: a dashed ring when empty, lit up while a gift is
## dragged over it.
class Slot extends Control:
	var filled := false
	var highlight := false:
		set(v):
			highlight = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		if highlight:
			draw_style_box(UI.box(UI.ACCENT_SOFT, UI.ACCENT, 20), r)
		elif not filled:
			var c := r.get_center()
			var d := minf(r.size.x, r.size.y) * 0.62
			draw_arc(c, d * 0.5, 0, TAU, 40, UI.LINE, 2.0, true)
			var px := clampi(int(d * 0.3), 12, 20)
			draw_texture(Icons.texture("plus", px, UI.INK_FAINT), c - Vector2(px, px) * 0.5)


## The shelf itself: a soft plank under the three spots.
class Plank extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var b := UI.box(UI.SHELF, Color.TRANSPARENT, 7)
		b.shadow_color = Color(0, 0, 0, 0.08)
		b.shadow_size = 6
		b.shadow_offset = Vector2(0, 3)
		draw_style_box(b, Rect2(Vector2(0, 2), Vector2(size.x, 10)))
