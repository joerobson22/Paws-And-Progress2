class_name RoundFrame
extends Control
## A filled rounded box, or a circle, that clips its children to its shape:
## the frame behind portraits and avatars.

var fill: Color = UI.ACCENT_SOFT:
	set(v):
		fill = v
		queue_redraw()
## A circle instead of a rounded box.
var circle := false
var radius := 18


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW


func _draw() -> void:
	if circle:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, fill, true, -1.0, true)
	else:
		var b := UI.box(fill, Color.TRANSPARENT, radius)
		draw_style_box(b, Rect2(Vector2.ZERO, size))
