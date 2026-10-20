class_name GiftTile
extends PanelContainer
## One gift: its picture filling the tile, with how many you've had on a
## tag overlapping its bottom-right corner. Tap it for details; press and hold
## to pick it up and drag it somewhere (the screen listens for `lifted`).
## Gifts on the shelf also slide: drag one sideways and it moves along the
## shelf straight away (`slid`).

signal tapped(gift_id: String)
signal lifted(tile: GiftTile)
signal slid(tile: GiftTile)

var gift_id := ""
var art: GiftArt
## True on the shelf: a sideways drag slides the gift along it.
var slides := false
var _press := Press.new(self, true)
var _slide_from := Vector2.ZERO
var _slide_armed := false


## `plain` drops the card behind it and the count, for gifts on the shelf.
func _init(id: String, count: int, plain: bool = false) -> void:
	gift_id = id
	var g := Content.gift(id)
	var colour := Content.rarity_colour(g.get("rarity", "common"))
	var sb: StyleBox = StyleBoxEmpty.new()
	if not plain:
		sb = UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 20), 0.6)
	sb.set_content_margin_all(6)
	add_theme_stylebox_override("panel", sb)
	_press.tapped.connect(func(): tapped.emit(gift_id))
	_press.held.connect(func():
		Motion.pop(self, 0.08)
		lifted.emit(self))
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = g.get("name", "")

	art = GiftArt.new(id)
	art.faded = count <= 0
	art.custom_minimum_size = Vector2(0, 84 if plain else 78)
	art.glow = 0.6 if plain else 0.0
	add_child(art)
	if plain:
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


## Where the finger went down, in viewport coordinates.
func press_point() -> Vector2:
	return get_global_transform_with_canvas() * _press.at


func _gui_input(e: InputEvent) -> void:
	_press.handle(e)
	if not slides:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_slide_armed = e.pressed
		if e.pressed:
			_slide_from = e.position
			# Sideways drags here move the gift, not the whole screen.
			Gestures.claimed = true
	elif e is InputEventMouseMotion and _slide_armed:
		var d: Vector2 = e.position - _slide_from
		if absf(d.x) >= Gestures.TAP_SLOP and absf(d.x) > absf(d.y):
			_slide_armed = false
			slid.emit(self)
