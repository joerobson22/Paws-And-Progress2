class_name FocusOrb
extends Control
## The living centre of the focus screen: soft, see-through circles of
## slightly different greens, each drifting round the middle at its own speed
## and direction, while the whole cluster slowly breathes in and out. It
## grows a little under the pointer and dips when pressed.
## Tapping it is how a focus session starts.

signal tapped

const HOVER_GROW := 1.07
const PRESS_GROW := 0.95

## [colour, opacity, radius, orbit, speed (radians/s), phase]; radius and
## orbit are fractions of the orb's radius.
const BLOBS := [
	["#4f9a80", 0.30, 0.86, 0.05, -0.11, 5.3],
	["#7fbf9f", 0.48, 0.76, 0.11, 0.21, 0.0],
	["#5fa88a", 0.36, 0.68, 0.17, -0.16, 1.7],
	["#8cc7c0", 0.40, 0.60, 0.19, -0.27, 4.4],
	["#a7d6be", 0.46, 0.56, 0.22, 0.32, 3.1],
	["#b5dfe0", 0.36, 0.44, 0.24, 0.47, 0.9],
	["#d3ecdf", 0.55, 0.34, 0.16, -0.38, 2.2],
]

## Paused while the focus screen is off to one side, to save battery.
var running := true:
	set(v):
		running = v
		set_process(v)
var _time := 0.0
var _press_at := Vector2.ZERO
var _pressing := false
var _hovered := false
## How big it's drawn, from the hover and press: 1 at rest.
var _grow := 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL


func _process(delta: float) -> void:
	_time += delta * (0.4 if Motion.reduced() else 1.0)
	queue_redraw()


func radius() -> float:
	return minf(size.x, size.y) * 0.5


func _draw() -> void:
	var c := size * 0.5
	var base := radius() * _grow
	var breathe := 1.0 + 0.045 * sin(_time * 0.55) + 0.02 * sin(_time * 1.27 + 1.0)
	# A faint halo so the orb sits softly on the page.
	for i in 6:
		draw_circle(c, base * breathe * (1.02 + i * 0.035), Color(0.38, 0.65, 0.52, 0.035), true, -1.0, true)
	for b in BLOBS:
		var angle: float = b[5] + _time * b[4]
		var wobble := 1.0 + 0.035 * sin(_time * 0.9 + b[5] * 2.0)
		var p: Vector2 = c + Vector2(cos(angle), sin(angle)) * base * b[3] * breathe
		draw_circle(p, base * b[2] * breathe * wobble, Color(Color.from_string(b[0], Color.WHITE), b[1]), true, -1.0, true)


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_hovered = true
			_grow_to(PRESS_GROW if _pressing else HOVER_GROW)
		NOTIFICATION_MOUSE_EXIT:
			_hovered = false
			_grow_to(1.0)


func _grow_to(v: float) -> void:
	Motion.method(self, "grow", _set_grow, _grow, v, Motion.FAST)


func _set_grow(v: float) -> void:
	_grow = v
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = true
			_press_at = e.position
			_grow_to(PRESS_GROW)
		elif _pressing:
			_pressing = false
			_grow_to(HOVER_GROW if _hovered else 1.0)
			if e.position.distance_to(_press_at) < Gestures.TAP_SLOP and _has_point(e.position):
				tapped.emit()
		accept_event()
	elif e.is_action_pressed("ui_accept"):
		accept_event()
		tapped.emit()
