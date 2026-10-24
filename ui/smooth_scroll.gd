class_name SmoothScroll
extends Node
## Every scroll area glides: a turn of the mouse wheel eases the list to
## where it's going instead of jumping there, and turns in a row add up.
## Fingers, trackpads and the scrollbar still move it directly (and take
## over from a glide that's under way). Every ScrollContainer gets it as
## it's made, wherever it's made; the app shell adds one of these.

## How far one notch of the wheel goes, as a share of what's on show.
const NOTCH := 0.16
## How quickly a glide catches up: the higher, the snappier.
const CATCH_UP := 16.0

## Each gliding ScrollBar, to where it's going.
var _target: Dictionary = {}
## Each gliding ScrollBar, where the glide is (in fractions of a pixel,
## though the bar itself only takes whole ones).
var _pos: Dictionary = {}
## Each gliding ScrollBar's value as the glide last left it, so anything
## else moving it is noticed.
var _left: Dictionary = {}


func _ready() -> void:
	set_process(false)
	get_tree().node_added.connect(_on_added)
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		_on_added(n)


func _on_added(n: Node) -> void:
	if n is ScrollContainer and not n.has_meta("smooth_scroll"):
		n.set_meta("smooth_scroll", true)
		n.gui_input.connect(_on_input.bind(n))


## Takes a wheel turn before the ScrollContainer does, and glides instead.
## Like the ScrollContainer, the wheel goes sideways with Shift held, or
## when there's no scrolling down; and a list resting at its end lets the
## turn through to whatever it's inside.
func _on_input(e: InputEvent, sc: ScrollContainer) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var way := 0.0
	var sideways := false
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			way = -1.0
		MOUSE_BUTTON_WHEEL_DOWN:
			way = 1.0
		MOUSE_BUTTON_WHEEL_LEFT:
			way = -1.0
			sideways = true
		MOUSE_BUTTON_WHEEL_RIGHT:
			way = 1.0
			sideways = true
		_:
			return
	var v_bar := sc.get_v_scroll_bar()
	var h_bar := sc.get_h_scroll_bar()
	var can_down := sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and v_bar.visible
	var can_across := sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and h_bar.visible
	if not sideways and ((can_across and mb.shift_pressed) or not can_down):
		sideways = true
	if (sideways and not can_across) or (not sideways and not can_down):
		return
	var bar: ScrollBar = h_bar if sideways else v_bar
	var factor: float = mb.factor if mb.factor > 0.0 else 1.0
	var from: float = _target.get(bar, bar.value)
	var to := clampf(from + way * bar.page * NOTCH * factor, bar.min_value, maxf(bar.min_value, bar.max_value - bar.page))
	var gliding := _target.has(bar)
	# A turn while it's still gliding to its end is kept here, or the
	# ScrollContainer would jump the rest of the way.
	if is_equal_approx(to, from) and not gliding:
		return
	sc.accept_event()
	if not gliding:
		_pos[bar] = bar.value
		_left[bar] = bar.value
	_target[bar] = to
	set_process(true)


func _process(delta: float) -> void:
	var rate := CATCH_UP * (2.0 if Motion.reduced() else 1.0)
	var step := 1.0 - exp(-rate * delta)
	for bar in _target.keys():
		# Gone, hidden, or moved by something else: that wins.
		if not is_instance_valid(bar) or not bar.is_visible_in_tree() or absf(bar.value - _left[bar]) > 0.5:
			_stop(bar)
			continue
		var to: float = _target[bar]
		var at := lerpf(float(_pos[bar]), to, step)
		if absf(to - at) < 0.5:
			at = to
		bar.value = at
		_pos[bar] = at
		_left[bar] = bar.value
		if at == to:
			_stop(bar)
	if _target.is_empty():
		set_process(false)


func _stop(bar: ScrollBar) -> void:
	_target.erase(bar)
	_pos.erase(bar)
	_left.erase(bar)
