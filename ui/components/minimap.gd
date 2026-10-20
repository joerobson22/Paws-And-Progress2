class_name Minimap
extends Control
## The little map of the app: five dots laid out like the screens (focus in
## the middle, one each side), with the one you're on filled in. The
## highlight glides with you as you swipe. It only shows where you are:
## swipe, or use the arrow keys, to move.

const CELL := 10.0
const GAP := 5.0
const PAD := 9.0

var cells: Dictionary = {}  # Vector2i -> name
var _at := Vector2.ZERO  # highlight position in cell units (animates)


func _init() -> void:
	var side := PAD * 2.0 + CELL * 3.0 + GAP * 2.0
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
