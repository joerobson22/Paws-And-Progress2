class_name Minimap
extends Control
## The little map of the app: five dots laid out like the screens (focus in
## the middle, one each side), with the one you're on filled in. The
## highlight glides with you as you swipe; tap a dot to go there.

signal picked(cell: Vector2i)

const CELL := 10.0
const GAP := 5.0
const PAD := 9.0

var cells: Dictionary = {}  # Vector2i -> name, for tooltips
var _at := Vector2.ZERO  # highlight position in cell units (animates)


func _init() -> void:
	var side := PAD * 2.0 + CELL * 3.0 + GAP * 2.0
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Moves the highlight to `cell`, gliding unless `instant`.
func show_cell(cell: Vector2i, instant: bool = false) -> void:
	if instant:
		_set_at(Vector2(cell))
	else:
		Motion.method(self, "at", _set_at, _at, Vector2(cell))


func _set_at(v: Vector2) -> void:
	_at = v
	queue_redraw()


func _cell_rect(cell: Vector2) -> Rect2:
	var centre := size * 0.5 + cell * (CELL + GAP)
	return Rect2(centre - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL))


func _draw() -> void:
	var bg := UI.with_shadow(UI.box(Color(UI.SURFACE, 0.92), Color.TRANSPARENT, 16), 0.7)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	for cell in cells:
		var dot := UI.box(UI.LINE, Color.TRANSPARENT, 3)
		draw_style_box(dot, _cell_rect(Vector2(cell)))
	var on := UI.box(UI.ACCENT, Color.TRANSPARENT, 3)
	draw_style_box(on, _cell_rect(_at).grow(1.0))


func _cell_at(p: Vector2) -> Variant:
	for cell in cells:
		if _cell_rect(Vector2(cell)).grow(GAP * 0.5 + 1.0).has_point(p):
			return cell
	return null


func _get_tooltip(at_position: Vector2) -> String:
	var cell = _cell_at(at_position)
	return str(cells[cell]).capitalize() if cell != null else ""


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		var cell = _cell_at(e.position)
		if cell != null:
			picked.emit(cell)
		accept_event()
