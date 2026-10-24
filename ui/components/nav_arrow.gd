class_name NavArrow
extends Control
## A big, faint chevron at the edge of the screen pointing to the screen
## that way (computers only: phones swipe). Under the pointer it slides a
## little the way it points and darkens; a click goes there. The app shell
## puts one on each side that leads somewhere, and shows them once you've
## arrived on a screen.

signal pressed(dir: Vector2i)

## The chevron's length along the edge and how far it pokes in from it.
const LONG := 40.0
const DEEP := 20.0
## The tappable area: this long along the edge, and this deep into the screen.
const HIT := Vector2(64.0, 48.0)
## Gap between the screen's edge and the chevron.
const EDGE := 12.0
## Room a screen keeps clear along an edge that has an arrow.
const ROOM := EDGE + DEEP + 16.0
## How far it slides towards where it points under the pointer.
const SLIDE := 6.0

var dir := Vector2i.ZERO
var _hover := 0.0
## Whether it is showing, or on its way to.
var _shown := false
## One line with round ends and a round bend, so it stays evenly see-through.
var _line := Line2D.new()


func _init(direction: Vector2i) -> void:
	dir = direction
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Cursor.HOVER
	focus_mode = Control.FOCUS_NONE
	modulate.a = 0.0
	visible = false
	size = HIT if dir.y != 0 else Vector2(HIT.y, HIT.x)
	accessibility_name = Text.t({Vector2i.LEFT: "nav.left", Vector2i.RIGHT: "nav.right", Vector2i.UP: "nav.up", Vector2i.DOWN: "nav.down"}.get(dir, "nav.left"))
	mouse_entered.connect(_set_hover_target.bind(1.0))
	mouse_exited.connect(_set_hover_target.bind(0.0))
	_line.width = 5.0
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.antialiased = true
	add_child(_line)
	_set_hover(0.0)


## Pins it to its edge of a screen of `area`, `insets` in from the notch etc.
func dock(area: Vector2, insets: Dictionary) -> void:
	match dir:
		Vector2i.LEFT:
			position = Vector2(insets["left"], (area.y - size.y) * 0.5)
		Vector2i.RIGHT:
			position = Vector2(area.x - size.x - insets["right"], (area.y - size.y) * 0.5)
		Vector2i.UP:
			position = Vector2((area.x - size.x) * 0.5, insets["top"])
		Vector2i.DOWN:
			position = Vector2((area.x - size.x) * 0.5, area.y - size.y - insets["bottom"])


## Fades in (or out). Hidden ones can't be clicked.
func appear(on: bool) -> void:
	if on == _shown:
		return
	_shown = on
	if on:
		visible = true
	else:
		_set_hover_target(0.0, true)


## Fades a step towards showing or not each frame (quicker going), so a
## change of mind halfway carries on from where it is.
func _process(delta: float) -> void:
	var step := delta / maxf(Motion.time(Motion.FAST), 0.001)
	modulate.a = move_toward(modulate.a, 1.0 if _shown else 0.0, step * (1.0 if _shown else 1.6))
	if not _shown and modulate.a <= 0.0:
		visible = false


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not e.pressed and get_rect().has_point(e.position + position):
			pressed.emit(dir)


## Redraws the chevron: slid out by the hover, in the current colours.
func refresh() -> void:
	_set_hover(_hover)


func _set_hover_target(to: float, instant: bool = false) -> void:
	if instant:
		Motion.tween(self, "hover").kill()
		_set_hover(to)
	else:
		Motion.method(self, "hover", _set_hover, _hover, to, Motion.FAST)


func _set_hover(v: float) -> void:
	_hover = v
	var d := Vector2(dir)
	var across := Vector2(-d.y, d.x)
	# The tip points out of the screen, EDGE in from its edge, and slides
	# outwards on hover.
	var tip := size * 0.5 + d * ((size.x if dir.x != 0 else size.y) * 0.5 - EDGE - SLIDE + SLIDE * _hover)
	var back := tip - d * DEEP
	_line.points = PackedVector2Array([back + across * LONG * 0.5, tip, back - across * LONG * 0.5])
	var ink := UI.INK_SOFT.lerp(UI.INK, _hover)
	ink.a = 0.5
	_line.default_color = ink
