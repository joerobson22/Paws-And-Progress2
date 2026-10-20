class_name GiftTile
extends PanelContainer
## One gift in a grid: its picture, name, and how many you've had in the
## bottom-right corner. Tap it for details; press and hold to pick it up and
## drag it somewhere (the screen listens for `lifted`).

signal tapped(gift_id: String)
signal lifted(tile: GiftTile)

var gift_id := ""
var art: GiftArt
var _press := Press.new(self, true)


## `plain` drops the card behind it and the count, for gifts on the shelf.
func _init(id: String, count: int, show_name: bool = true, plain: bool = false) -> void:
	gift_id = id
	var g := Content.gift(id)
	var colour := Content.rarity_colour(g.get("rarity", "common"))
	var sb: StyleBox = UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 20), 0.6) if not plain else StyleBoxEmpty.new()
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)
	_press.tapped.connect(func(): tapped.emit(gift_id))
	_press.held.connect(func():
		Motion.pop(self, 0.08)
		lifted.emit(self))
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = g.get("name", "")

	var v := UI.vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	art = GiftArt.new(id)
	art.faded = count <= 0
	art.custom_minimum_size = Vector2(0, 54 if not plain else 64)
	art.glow = 0.6 if plain else 0.0
	v.add_child(art)
	# Name along the bottom, with the count in the bottom-right corner.
	var foot := UI.hbox(4)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	if show_name:
		var name := UI.trimmed(g.get("name", "?"), 12, UI.INK if count > 0 else UI.INK_FAINT, false, 800)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if plain else HORIZONTAL_ALIGNMENT_LEFT
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		foot.add_child(name)
	if not plain:
		foot.add_child(UI.tag("×%d" % count, colour if count > 0 else UI.SURFACE_SOFT, UI.SURFACE if count > 0 else UI.INK_SOFT, 11))


## Where the finger went down, in viewport coordinates.
func press_point() -> Vector2:
	return get_global_transform_with_canvas() * _press.at


func _gui_input(e: InputEvent) -> void:
	_press.handle(e)
