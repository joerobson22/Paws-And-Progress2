class_name GiftTile
extends PanelContainer
## One gift: its picture filling the tile, with how many you've had on a
## tag overlapping its bottom-right corner. Tap it for details (`tapped`).
## In the collection it shades a little under the pointer; on the shelf
## (`plain`) it has no card or count, and grows with a glint instead.
## Where gifts can be dragged (the shelf editor), press and hold to pick one
## up, or with `quick_drag` just start dragging (`lifted` either way).

signal tapped(gift_id: String)
signal lifted(tile: GiftTile)

var gift_id := ""
var art: GiftArt
## Dragging picks it up straight away, without holding first.
var quick_drag := false
## Whether it can be picked up and dragged at all.
var draggable := false
var _plain := false
var _press := Press.new(self, true)
var _glint: Glint
var _drag_from := Vector2.ZERO
var _armed := false


## `plain` drops the card behind it and the count, for gifts on the shelf.
func _init(id: String, count: int, plain: bool = false) -> void:
	gift_id = id
	_plain = plain
	var g := Content.gift(id)
	var colour := Content.rarity_colour(g.get("rarity", "common"))
	var sb: StyleBox = StyleBoxEmpty.new()
	if not plain:
		sb = UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 20), 0.6)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	_press.tapped.connect(func(): tapped.emit(gift_id))
	_press.held.connect(func():
		if draggable:
			Motion.pop(self, 0.08)
			lifted.emit(self))
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = g.get("name", "")
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	resized.connect(func(): pivot_offset = size * 0.5)

	art = GiftArt.new(id)
	art.faded = count <= 0
	art.custom_minimum_size = Vector2(0, 84 if plain else 78)
	art.glow = 0.6 if plain else 0.0
	add_child(art)
	if plain:
		_glint = Glint.new(0.5, true)
		art.add_child(_glint)
		return
	# The count sits over the picture's corner. A PanelContainer stretches its
	# children, so the tag lives in its own holder.
	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corner)
	var badge := UI.tag("×%d" % count, colour if count > 0 else UI.SURFACE_SOFT, UI.ON_COLOUR if count > 0 else UI.INK_SOFT, 12)
	corner.add_child(badge)
	corner.resized.connect(func():
		badge.size = badge.get_combined_minimum_size()
		badge.position = corner.size - badge.size + Vector2(2, 2))


## Greyed out and left alone: for a collection gift that's already on the
## shelf (it's handled from there).
func set_on_shelf() -> void:
	art.faded = true
	modulate = Color(1, 1, 1, 0.55)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	tooltip_text = "%s (on your shelf)" % tooltip_text


## Where the finger went down, in viewport coordinates.
func press_point() -> Vector2:
	return get_global_transform_with_canvas() * _press.at


## Shelf gifts grow and glint; collection gifts shade, darker on a light
## page and lighter on a dark one.
func _hover(on: bool) -> void:
	if _plain:
		Motion.to(self, "scale", Vector2.ONE * (1.08 if on else 1.0), Motion.FAST)
		if on:
			_glint.shine()
	else:
		var shade := Color(1.12, 1.12, 1.12) if UI.dark else Color(0.93, 0.93, 0.95)
		Motion.to(self, "self_modulate", shade if on else Color.WHITE, Motion.FAST)


func _gui_input(e: InputEvent) -> void:
	_press.handle(e)
	if not draggable or not quick_drag:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_armed = e.pressed
		_drag_from = e.position
	elif e is InputEventMouseMotion and _armed and e.position.distance_to(_drag_from) >= Gestures.TAP_SLOP:
		_armed = false
		lifted.emit(self)
