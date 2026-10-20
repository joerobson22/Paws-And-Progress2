extends Control
## App shell. Five panes are laid out like a plus sign with the focus screen
## in the middle: gifts to the left, completed projects to the right, your
## profile above and stats below. Swipe between them (or use the arrow keys,
## or tap the minimap). Every pane is built once and kept, so each one is as
## you left it when you come back. Full-screen flows (choosing a focus, the
## walk, the end of a walk) open over everything through a growing circle.
## Screens ask to move with App.go().

const PANES := {
	"focus": [Vector2i(0, 0), "res://scenes/panes/focus.gd"],
	"gifts": [Vector2i(-1, 0), "res://scenes/panes/gifts.gd"],
	"completed": [Vector2i(1, 0), "res://scenes/panes/completed.gd"],
	"profile": [Vector2i(0, -1), "res://scenes/panes/profile.gd"],
	"stats": [Vector2i(0, 1), "res://scenes/panes/stats.gd"],
}
const FLOWS := {
	"choose_focus": "res://scenes/choose_focus/choose_focus.gd",
	"walk": "res://scenes/walk/walk.gd",
	"finish": "res://scenes/walk/finish.gd",
}
## The UI is laid out for a short side of this many points; smaller windows
## (phones) get a smaller design size so text stays its intended size.
const DESIGN_SHORT_SIDE := 720.0
const PHONE_MIN_SHORT_SIDE := 360.0
## A drag becomes a swipe once it moves this far...
const SWIPE_START := 16.0
## ...and goes through when let go past this much of the screen, or flicked.
const SWIPE_COMMIT := 0.22
const FLICK_SPEED := 1.6  # screens per second

var _world := Control.new()
var _panes := {}  # Vector2i -> Pane
var _names := {}  # Vector2i -> pane name
var _at := Vector2i.ZERO
var _moving := false
var _flow_layer := Control.new()
var _flows: Array[CircleReveal] = []
var _modal_layer := Control.new()
var _minimap: Minimap
var _bg := ColorRect.new()

var _press := false
var _press_pos := Vector2.ZERO
var _swiping := false
var _target := Vector2i.ZERO
var _progress := 0.0
var _velocity := 0.0
var _last_time := 0
var _synthetic := false


func _ready() -> void:
	_fit_design_size()
	UI.set_dark(UI.wants_dark(str(App.state.settings.get("theme", "auto"))))
	theme = UI.build_theme()
	# Before the panes connect, so a palette change lands before they rebuild.
	App.state_changed.connect(_on_state_changed)
	_bg.color = UI.BG
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	for pane_name in PANES:
		var cell: Vector2i = PANES[pane_name][0]
		var pane: Pane = load(PANES[pane_name][1]).new()
		pane.name = pane_name.capitalize()
		pane.visible = cell == _at
		_world.add_child(pane)
		_panes[cell] = pane
		_names[cell] = pane_name

	_minimap = Minimap.new()
	_minimap.cells = _names
	_minimap.picked.connect(_go_cell)
	add_child(_minimap)

	for layer in [_flow_layer, _modal_layer]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	Modal.layer = _modal_layer

	App.navigate.connect(_open)
	get_viewport().size_changed.connect(_fit_design_size)
	resized.connect(_layout)
	_layout()
	_panes[_at].show_pane()
	_minimap.show_cell(_at, true)

	# A walk survives the app being closed: pick it straight back up.
	if App.state.active:
		_open_flow("walk", {}, true)


## Phones report a short side of ~390 points, so a fixed 720 design size
## would draw everything at half size. Use the window's own size in points
## there, and the 720 design size (scaled up) on bigger screens.
func _fit_design_size() -> void:
	var window := get_window()
	var points := Vector2(DisplayServer.window_get_size()) / _screen_scale()
	var side := clampf(minf(points.x, points.y), PHONE_MIN_SHORT_SIDE, DESIGN_SHORT_SIDE)
	var target := Vector2i(roundi(side), roundi(side))
	if window.content_scale_size != target:
		window.content_scale_size = target


## Physical pixels per point: Retina/iOS report it directly; Android via DPI.
static func _screen_scale() -> float:
	if OS.get_name() == "Android":
		return maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	return maxf(1.0, DisplayServer.screen_get_scale())


func _layout() -> void:
	for cell in _panes:
		var pane: Pane = _panes[cell]
		pane.position = Vector2(cell) * size
		pane.size = size
	if not _moving and not _swiping:
		_world.position = -Vector2(_at) * size
	var insets := UI.safe_insets(self)
	_minimap.position = Vector2(roundf((size.x - _minimap.size.x) * 0.5), size.y - _minimap.size.y - 18.0 - insets["bottom"])


# --- Light and dark ----------------------------------------------------------

func _on_state_changed() -> void:
	var want := UI.wants_dark(str(App.state.settings.get("theme", "auto")))
	if want != UI.dark:
		_switch_palette(want)


## Swaps light and dark: everything on screen is rebuilt in the new colours
## under a snapshot of the old ones, which then fades away.
func _switch_palette(dark: bool) -> void:
	# A picture of the screen as it was, to fade away over the new colours
	# (there's no picture to take when running without a display).
	var snapshot: Image = null
	if DisplayServer.get_name() != "headless":
		snapshot = get_viewport().get_texture().get_image()
	UI.set_dark(dark)
	theme = UI.build_theme()
	_bg.color = UI.BG
	_minimap.queue_redraw()
	for cell in _panes:
		var pane: Pane = _panes[cell]
		if pane.shown:
			pane.rebuild()
		else:
			pane.mark_dirty()
	if snapshot == null or snapshot.is_empty():
		return
	var cover := TextureRect.new()
	cover.texture = ImageTexture.create_from_image(snapshot)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_layer.add_child(cover)
	Motion.fade(cover, 0.0, Motion.SLOW).tween_callback(cover.queue_free)


# --- Navigation --------------------------------------------------------------

func _open(screen: String, params: Dictionary) -> void:
	if PANES.has(screen):
		_close_flows()
		_go_cell(PANES[screen][0])
	elif screen == "home":
		_close_flows()
	elif FLOWS.has(screen):
		_open_flow(screen, params, bool(params.get("instant", false)))
	else:
		push_error("Unknown screen %s" % screen)


## Slides to a pane. Panes off to the side only connect to the middle, so
## going from one side to another passes through the focus screen.
func _go_cell(cell: Vector2i) -> void:
	if not _panes.has(cell) or _moving or cell == _at:
		return
	if _at != Vector2i.ZERO and cell != Vector2i.ZERO:
		await _slide_to(Vector2i.ZERO, Motion.NORMAL * 0.75)
	await _slide_to(cell)


func _slide_to(cell: Vector2i, seconds: float = Motion.NORMAL + 0.06) -> void:
	var from := _at
	var pane: Pane = _panes[cell]
	pane.visible = true
	if not pane.shown:
		pane.show_pane()
	_at = cell
	_minimap.show_cell(cell)
	_moving = true
	await Motion.to(_world, "position", -Vector2(cell) * size, seconds).finished
	_moving = false
	if from != cell:
		_panes[from].hide_pane()
	_hide_others()


func _hide_others() -> void:
	for c in _panes:
		if c != _at:
			_panes[c].visible = false
			if _panes[c].shown:
				_panes[c].hide_pane()


func _open_flow(screen: String, params: Dictionary, instant: bool = false) -> void:
	var content: Control = load(FLOWS[screen]).new()
	content.set("params", params)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var reveal := CircleReveal.new()
	reveal.origin = params.get("from", size * 0.5)
	reveal.add_child(content)
	_flow_layer.add_child(reveal)
	var below := _flows.duplicate()
	_flows.append(reveal)
	Motion.fade(_minimap, 0.0, Motion.FAST)
	var t := reveal.open(instant)
	if t:
		await t.finished
	for f in below:
		_flows.erase(f)
		f.queue_free()
	# Nothing behind a full-screen flow needs drawing.
	if not _flows.is_empty():
		_world.visible = false
		_panes[_at].hide_pane()


## Back to the focus screen from any flow, shrinking the circle away.
func _close_flows() -> void:
	if _flows.is_empty():
		return
	var top: CircleReveal = _flows.back()
	for f in _flows:
		if f != top:
			f.queue_free()
	_flows.clear()
	if _at != Vector2i.ZERO:
		_at = Vector2i.ZERO
		_minimap.show_cell(_at, true)
		_layout()
	_world.visible = true
	_panes[_at].visible = true
	_panes[_at].show_pane()
	_hide_others()
	top.origin = size * 0.5
	top.close()
	Motion.fade(_minimap, 1.0)


func _go_back() -> void:
	if Modal.is_open():
		Modal.top().close(null)
	elif not _flows.is_empty():
		var content: Node = _flows.back().get_child(0)
		if content.has_method("go_back"):
			content.go_back()
	elif _at != Vector2i.ZERO:
		_go_cell(Vector2i.ZERO)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


# --- Swiping -----------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if _synthetic:
		return
	if not _flows.is_empty() or Modal.is_open() or _moving:
		_press = false
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			_swiping = false
			_press_pos = e.position
			Gestures.claimed = false
		else:
			if _swiping:
				get_viewport().set_input_as_handled()
				_end_swipe()
			_press = false
			Gestures.claimed = false
	elif e is InputEventMouseMotion and _press:
		if _swiping:
			get_viewport().set_input_as_handled()
			_update_swipe(e.position)
		elif not Gestures.claimed and e.position.distance_to(_press_pos) > SWIPE_START:
			_try_swipe(e.position)
	elif e is InputEventKey and e.pressed and not e.echo and not _typing():
		var step := Vector2i.ZERO
		match e.keycode:
			KEY_LEFT:
				step = Vector2i.LEFT
			KEY_RIGHT:
				step = Vector2i.RIGHT
			KEY_UP:
				step = Vector2i.UP
			KEY_DOWN:
				step = Vector2i.DOWN
		if step != Vector2i.ZERO and _panes.has(_at + step):
			get_viewport().set_input_as_handled()
			_go_cell(_at + step)


func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _try_swipe(pos: Vector2) -> void:
	var d := pos - _press_pos
	var horizontal := absf(d.x) > absf(d.y)
	var along := d.x if horizontal else d.y
	# The finger drags the screen: moving right brings in the pane on the left.
	var step := Vector2i(-signi(roundi(along)), 0) if horizontal else Vector2i(0, -signi(roundi(along)))
	var target := _at + step
	if not _panes.has(target) or _scroll_blocks(pos, horizontal, along):
		# Not a swipe: leave this drag to whatever's under the finger.
		_press = false
		return
	_swiping = true
	_target = target
	_progress = 0.0
	_velocity = 0.0
	_last_time = Time.get_ticks_usec()
	_cancel_gui_press()
	get_viewport().set_input_as_handled()
	var pane: Pane = _panes[target]
	pane.visible = true
	if not pane.shown:
		pane.show_pane()
	_update_swipe(pos)


func _update_swipe(pos: Vector2) -> void:
	var dir := Vector2(_target - _at)
	var dim := size.x if dir.x != 0.0 else size.y
	var along := (pos - _press_pos).dot(dir.abs())
	var progress := clampf(-along * (dir.x + dir.y) / dim, 0.0, 1.0)
	var now := Time.get_ticks_usec()
	var dt := maxf((now - _last_time) / 1000000.0, 0.001)
	_velocity = lerpf(_velocity, (progress - _progress) / dt, 0.35)
	_last_time = now
	_progress = progress
	_world.position = -(Vector2(_at) + dir * progress) * size


func _end_swipe() -> void:
	_swiping = false
	if _progress > SWIPE_COMMIT or _velocity > FLICK_SPEED:
		_slide_to(_target, Motion.NORMAL * maxf(0.4, 1.0 - _progress))
	else:
		var back := _target
		_moving = true
		await Motion.to(_world, "position", -Vector2(_at) * size, Motion.NORMAL * maxf(0.4, _progress * 2.0)).finished
		_moving = false
		if back != _at:
			_panes[back].hide_pane()
			_panes[back].visible = false


## True if a scroll area under the finger can still move that way, so the
## drag should scroll it rather than swipe to another pane.
func _scroll_blocks(pos: Vector2, horizontal: bool, along: float) -> bool:
	var stack: Array[Node] = [_panes[_at]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var sc := n as ScrollContainer
		if sc == null or not sc.is_visible_in_tree() or not sc.get_global_rect().has_point(pos):
			continue
		var bar: ScrollBar = sc.get_h_scroll_bar() if horizontal else sc.get_v_scroll_bar()
		var mode := sc.horizontal_scroll_mode if horizontal else sc.vertical_scroll_mode
		if mode == ScrollContainer.SCROLL_MODE_DISABLED:
			continue
		var value := bar.value
		var most := bar.max_value - bar.page
		# A few pixels' slack, so a page that only just overflows doesn't
		# have to be scrolled to its very end before you can swipe off it.
		if (along < 0.0 and value < most - 8.0) or (along > 0.0 and value > 8.0):
			return true
	return false


## Tells whatever the finger pressed that the press is over (by moving the
## pointer far away and letting go there), so a swipe never also taps.
func _cancel_gui_press() -> void:
	_synthetic = true
	var far := Vector2(-100000, -100000)
	var mm := InputEventMouseMotion.new()
	mm.position = far
	mm.global_position = far
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(mm, true)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = far
	mb.global_position = far
	get_viewport().push_input(mb, true)
	_synthetic = false
