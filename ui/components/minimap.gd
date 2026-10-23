class_name Minimap
extends Control
## The little map of the app: five dots laid out like the screens (focus in
## the middle, one each side), with the one you're on filled in. The
## highlight glides with you as you swipe. Tap the map and it grows into big
## tiles from the bottom, each with an icon fading in for its screen (a home
## for focus, a present for gifts, a tick for completed, a person for your
## profile and a bar chart for stats); tap one to go there. Tapping anywhere
## else, or Esc, shrinks it back. The arrow keys move between screens too.

signal picked(cell: Vector2i)

## Sizes small and big: each tile, the gap between them, and the padding.
const CELL := Vector2(10.0, 46.0)
const GAP := Vector2(5.0, 8.0)
const PAD := Vector2(9.0, 12.0)
const ICONS := {"focus": "home", "gifts": "gift", "completed": "check", "profile": "user", "stats": "stats"}
const ICON_PX := 24

var cells: Dictionary = {}  # Vector2i -> name, for the icons
var open := false
var _at := Vector2.ZERO  # highlight position in cell units (animates)
## 0 small to 1 big (animates).
var _grow := 0.0
var _hover: Variant = null
## Where its bottom middle sits, in its parent.
var _dock := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Cursor.HOVER
	mouse_exited.connect(func(): _set_hover(null))
	_apply()


## Pins its bottom middle to `point`, so it grows upwards and outwards.
func dock(point: Vector2) -> void:
	_dock = point
	_apply()


## Moves the highlight to `cell`, gliding unless `instant`. Going somewhere
## (by swiping, the keys or a tap) shrinks the map back.
func show_cell(cell: Vector2i, instant: bool = false) -> void:
	if instant:
		_set_at(Vector2(cell))
	else:
		Motion.method(self, "at", _set_at, _at, Vector2(cell))
	shrink(instant)


func grow() -> void:
	if open:
		return
	open = true
	Audio.play("pop", 1.2, -10.0)
	Motion.method(self, "grow", _set_grow, _grow, 1.0, Motion.NORMAL)


func shrink(instant: bool = false) -> void:
	if not open:
		return
	open = false
	_set_hover(null)
	if instant:
		Motion.tween(self, "grow").kill()
		_set_grow(0.0)
	else:
		Motion.method(self, "grow", _set_grow, _grow, 0.0, Motion.NORMAL)


func _set_at(v: Vector2) -> void:
	_at = v
	queue_redraw()


func _set_grow(v: float) -> void:
	_grow = v
	_apply()


func _set_hover(cell: Variant) -> void:
	if cell != _hover:
		_hover = cell
		queue_redraw()


func _cell() -> float:
	return lerpf(CELL.x, CELL.y, _grow)


func _gap() -> float:
	return lerpf(GAP.x, GAP.y, _grow)


func _apply() -> void:
	var side := lerpf(PAD.x, PAD.y, _grow) * 2.0 + _cell() * 3.0 + _gap() * 2.0
	size = Vector2(side, side)
	position = Vector2(roundf(_dock.x - side * 0.5), _dock.y - side)
	queue_redraw()


func _cell_rect(cell: Vector2) -> Rect2:
	var c := _cell()
	var centre := size * 0.5 + cell * (c + _gap())
	return Rect2(centre - Vector2(c, c) * 0.5, Vector2(c, c))


func _draw() -> void:
	var bg := UI.with_shadow(UI.box(Color(UI.SURFACE, 0.92 + 0.08 * _grow), Color.TRANSPARENT, int(lerpf(16.0, 26.0, _grow))), 0.7 + 0.3 * _grow)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var radius := int(lerpf(3.0, 14.0, _grow))
	var tile := UI.LINE.lerp(UI.SURFACE_SOFT, _grow)
	for cell in cells:
		var shade := tile
		if open and cell == _hover:
			shade = tile.darkened(0.08) if not UI.dark else tile.lightened(0.1)
		draw_style_box(UI.box(shade, Color.TRANSPARENT, radius), _cell_rect(Vector2(cell)))
	draw_style_box(UI.box(UI.ACCENT, Color.TRANSPARENT, radius), _cell_rect(_at).grow(1.0))
	# The icons only show once it's mostly grown, fading in over the last part.
	var fade := clampf((_grow - 0.45) / 0.55, 0.0, 1.0)
	if fade <= 0.0:
		return
	var px := _cell() * float(ICON_PX) / CELL.y
	for cell in cells:
		var here: bool = Vector2(cell).distance_to(_at) < 0.5
		var ink := Color.WHITE if here else UI.INK_SOFT
		var icon := Icons.texture(ICONS.get(cells[cell], "paw"), ICON_PX, ink, 2.4)
		var centre := _cell_rect(Vector2(cell)).get_center()
		draw_texture_rect(icon, Rect2(centre - Vector2(px, px) * 0.5, Vector2(px, px)), false, Color(1, 1, 1, fade))


func _cell_at(p: Vector2) -> Variant:
	for cell in cells:
		if _cell_rect(Vector2(cell)).grow(_gap() * 0.5 + 1.0).has_point(p):
			return cell
	return null


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and open:
		_set_hover(_cell_at(e.position))
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if e.pressed:
			return
		if not open:
			grow()
			return
		var cell = _cell_at(e.position)
		if cell != null:
			if Vector2(cell).distance_to(_at) < 0.5:
				shrink()
			picked.emit(cell)


## While it's big, a tap anywhere else (or Esc) only shrinks it back, so
## nothing underneath gets tapped or swiped by accident.
func _input(e: InputEvent) -> void:
	if not open:
		return
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		shrink()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed \
			and not get_global_rect().has_point(e.position):
		get_viewport().set_input_as_handled()
		shrink()
