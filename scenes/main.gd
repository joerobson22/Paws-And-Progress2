extends Control
## App shell. Five panes are laid out like a plus sign with the focus screen
## in the middle: gifts to the left, completed projects to the right, your
## profile above and stats below. Swipe between them, use the arrow keys
## (Esc comes back to the middle), click the big faint arrows at the edges
## (computers), or open the minimap (bottom left on computers, bottom middle
## on phones) and pick one. Every pane is built once and kept, so each one
## is as you left it when you come back. Full-screen flows (choosing a focus, the walk, the end of a
## walk) open over everything through a growing circle.
## Screens ask to move with App.go(). A new save slot stays on the profile
## screen, with no map or arrows, until its profile is filled in.

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
	"ended": "res://scenes/walk/ended.gd",
}
## The UI is laid out for a short side of this many points; smaller windows
## (phones) get a smaller design size so text stays its intended size.
const DESIGN_SHORT_SIDE := 720.0
const PHONE_MIN_SHORT_SIDE := 360.0
## Computers: the window's short side in design units, whatever its size.
const DESKTOP_SHORT_SIDE := 600.0
const MIN_DESKTOP_SCALE := 0.75
## The minimap's gap from the bottom (and the left, on computers).
const MAP_INSET := 18.0
## A drag becomes a swipe once it moves this far...
const SWIPE_START := 16.0
## ...and goes through when let go past this much of the screen, or flicked.
const SWIPE_COMMIT := 0.22
const FLICK_SPEED := 1.6  # screens per second
## The wheel or trackpad moves to the next pane after this much turning in
## one go (a wheel notch is 1; a trackpad sends small amounts)...
const WHEEL_STEP := 1.0
## ...and a pause this long (seconds) between turns starts a fresh one.
const WHEEL_GAP := 0.25
## A trackpad's turn against a wheel's, so a small flick is enough.
const PAN_SCALE := 1.6
## How long the old colours take to fade into the new ones.
const PALETTE_FADE := 0.8

var _world := Control.new()
var _panes := {}  # Vector2i -> Pane
var _names := {}  # Vector2i -> pane name
var _at := Vector2i.ZERO
var _moving := false
var _flow_layer := Control.new()
var _flows: Array[CircleReveal] = []
var _modal_layer := Control.new()
## Holds the picture of the old colours while it fades out.
var _fade_layer := Control.new()
var _fading := 0
var _minimap: Minimap
var _arrows := {}  # Vector2i direction -> NavArrow
var _bg := ColorRect.new()
## The window settings last put in place, so only a change to them moves it.
var _window_applied := ""
## True while a new save slot keeps you on the profile screen.
var _locked := false

var _press := false
var _press_pos := Vector2.ZERO
var _swiping := false
var _target := Vector2i.ZERO
var _progress := 0.0
var _velocity := 0.0
var _last_time := 0
var _press_time := 0
var _synthetic := false
## The wheel or trackpad turn under way: when its last event came (usec),
## how far it has gone each way, and whether it can still move pane (no
## list took any of it, and it hasn't moved one yet).
var _wheel_at := 0
var _wheel_sum := Vector2.ZERO
var _wheel_free := false


func _ready() -> void:
	_apply_window()
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
	if App.setup_pending():
		_at = PANES["profile"][0]
	for pane_name in PANES:
		var cell: Vector2i = PANES[pane_name][0]
		var pane: Pane = load(PANES[pane_name][1]).new()
		pane.name = pane_name.capitalize()
		pane.visible = cell == _at
		pane.arrows = _ways_from(cell)
		_world.add_child(pane)
		_panes[cell] = pane
		_names[cell] = pane_name

	add_child(Cursor.new())
	add_child(SmoothScroll.new())
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var arrow := NavArrow.new(dir)
		arrow.pressed.connect(func(d: Vector2i): _go_cell(_at + d))
		add_child(arrow)
		_arrows[dir] = arrow
	_minimap = Minimap.new()
	_minimap.hover_grow = not App.phone_layout()
	_minimap.cells = _names
	_minimap.picked.connect(_go_cell)
	add_child(_minimap)

	for layer in [_fade_layer, _flow_layer, _modal_layer]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	# Flows and popups always draw on top, even over things lifted above
	# the fade between light and dark.
	_flow_layer.z_index = 2
	_modal_layer.z_index = 2
	Modal.layer = _modal_layer

	App.navigate.connect(_open)
	get_viewport().size_changed.connect(_fit_design_size)
	resized.connect(_layout)
	_layout()
	_panes[_at].show_pane()
	_minimap.show_cell(_at, true)
	_sync_lock(true)

	# Closing the app ends a walk; say so the next time it opens.
	if not App.ended_walk.is_empty():
		_open_flow("ended", App.ended_walk, true)
		App.ended_walk = {}
	if App.save_reset:
		App.save_reset = false
		Toast.show_text.call_deferred(Text.t("save.reset"), "gear")
	else:
		_maybe_ask_location()


## On phones the design size is the screen's own size in points, so text
## stays its intended size; the debug phone view does the same with a
## phone's width. On computers everything scales with the window: its short
## side is always DESKTOP_SHORT_SIDE design units, so a bigger window draws
## everything bigger (never below MIN_DESKTOP_SCALE).
func _fit_design_size() -> void:
	var window := get_window()
	var side: float
	if App.debug_phone_view():
		side = float(Display.PHONE.x)
	elif OS.has_feature("mobile"):
		var points := Vector2(DisplayServer.window_get_size()) / Display.screen_scale()
		side = clampf(minf(points.x, points.y), PHONE_MIN_SHORT_SIDE, DESIGN_SHORT_SIDE)
	else:
		var window_size := Vector2(DisplayServer.window_get_size())
		var short := maxf(1.0, minf(window_size.x, window_size.y))
		side = maxf(short / maxf(short / DESKTOP_SHORT_SIDE, MIN_DESKTOP_SCALE), PHONE_MIN_SHORT_SIDE)
	var target := Vector2i(roundi(side), roundi(side))
	if window.content_scale_size != target:
		window.content_scale_size = target


## Puts the window settings (and the debug phone view) in place, if they
## changed since last time.
func _apply_window() -> void:
	var s := App.state.settings
	var want := "%s|%s|%s" % [s.get("window_mode", ""), s.get("resolution", ""), App.debug_phone_view()]
	if want == _window_applied:
		return
	_window_applied = want
	Display.apply(get_window())
	if _minimap:
		_minimap.hover_grow = not App.phone_layout()
		_layout()


func _layout() -> void:
	for cell in _panes:
		var pane: Pane = _panes[cell]
		pane.position = Vector2(cell) * size
		pane.size = size
	if not _moving and not _swiping:
		_world.position = -Vector2(_at) * size
	var insets := UI.safe_insets(self)
	var floor_y: float = size.y - MAP_INSET - insets["bottom"]
	if App.phone_layout():
		# Phones: in the middle (of the part clear of the notch), for either thumb.
		_minimap.dock(Vector2((insets["left"] + size.x - insets["right"]) * 0.5, floor_y), true)
	else:
		_minimap.dock(Vector2(MAP_INSET + insets["left"], floor_y))
	for dir in _arrows:
		_arrows[dir].dock(size, insets)


## The ways on from `cell`: every way from the middle, and back to the
## middle from a screen at the side.
func _ways_from(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if PANES.values().any(func(p): return p[0] == cell + dir) and (cell == Vector2i.ZERO or cell + dir == Vector2i.ZERO):
			out.append(dir)
	return out


## The edge arrows show (computers only) once you've arrived on a screen,
## and hide while moving, during walks and while a popup is up.
func _process(_delta: float) -> void:
	var show := not App.phone_layout() and not _moving and not _swiping \
		and _flows.is_empty() and not Modal.is_open() and not _locked
	var ways: Array[Vector2i] = _ways_from(_at) if show else ([] as Array[Vector2i])
	for dir in _arrows:
		_arrows[dir].appear(ways.has(dir))


# --- Light and dark ----------------------------------------------------------

func _on_state_changed() -> void:
	_apply_window()
	_fit_design_size()
	_sync_lock()
	var want := UI.wants_dark(str(App.state.settings.get("theme", "auto")))
	if want != UI.dark:
		_switch_palette(want)


## Swaps light and dark without anything moving: the screen on show is
## rebuilt in the new colours exactly as it was (same layout, scroll and
## text, no entry animations), under a picture of the old colours that
## then fades away. What a pane keeps through a rebuild (the orb, the
## toggle) is lifted above the picture so it carries on moving.
func _switch_palette(dark: bool) -> void:
	# There's no picture to take when running without a display.
	var snapshot: Image = null
	if DisplayServer.get_name() != "headless":
		snapshot = get_viewport().get_texture().get_image()
	UI.set_dark(dark)
	theme = UI.build_theme()
	_bg.color = UI.BG
	_minimap.queue_redraw()
	for dir in _arrows:
		_arrows[dir].refresh()
	var lifted: Array[Node] = []
	Motion.still = true
	for cell in _panes:
		var pane: Pane = _panes[cell]
		if pane.shown:
			pane.rebuild()
			lifted.append_array(pane.keeps())
		else:
			pane.mark_dirty()
	if snapshot == null or snapshot.is_empty():
		_settle.call_deferred()
		return
	var cover := TextureRect.new()
	cover.texture = ImageTexture.create_from_image(snapshot)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(cover)
	_fading += 1
	for node in lifted:
		(node as CanvasItem).z_index = 1
	await _settle()
	Motion.fade(cover, 0.0, PALETTE_FADE).tween_callback(func():
		cover.queue_free()
		_fading -= 1
		if _fading == 0:
			for node in lifted:
				if is_instance_valid(node):
					(node as CanvasItem).z_index = 0)


## Some screens start animations a frame after they're built, so animations
## stay still until then.
func _settle() -> void:
	await get_tree().process_frame
	Motion.still = false


# --- Navigation --------------------------------------------------------------

## Hides the map while a new save slot keeps you on the profile screen
## (the arrows hide in _process), and brings it back after.
func _sync_lock(instant: bool = false) -> void:
	var locked := App.setup_pending()
	if locked == _locked:
		return
	_locked = locked
	_minimap.shrink(true)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	if instant:
		_minimap.modulate.a = 0.0 if locked else 1.0
	else:
		Motion.fade(_minimap, 0.0 if locked else 1.0, Motion.FAST)


## True if you can go to `cell`: anywhere, unless a new save slot is
## keeping you on the profile screen.
func _can_go(cell: Vector2i) -> bool:
	return _panes.has(cell) and (not _locked or cell == PANES["profile"][0])

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
	if not _can_go(cell) or _moving or cell == _at:
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
	_minimap.shrink(true)
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
	# The places' sounds stay with them.
	Audio.ambience("")
	_maybe_ask_location()
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


## Asks once, a moment after the focus screen shows, whether the places may
## follow the real sunrise, sunset and weather where you are.
func _maybe_ask_location() -> void:
	if Outdoors.asked():
		return
	await get_tree().create_timer(1.5).timeout
	if Outdoors.asked() or not _flows.is_empty() or Modal.is_open() or _at != Vector2i.ZERO:
		return
	var m := Modal.confirm(Text.t("weather_prompt.title"), Text.t("weather_prompt.body"),
		Text.t("weather_prompt.allow"), "accent", Text.t("weather_prompt.not_now"))
	Outdoors.set_enabled(await m.closed == true)


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


# --- Wheel and trackpad ------------------------------------------------------

## How far a wheel or trackpad event turns, down and right positive, or zero
## for anything else.
static func _wheel_turn(e: InputEvent) -> Vector2:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed:
		var f: float = mb.factor if mb.factor > 0.0 else 1.0
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				return Vector2(-f, 0) if mb.shift_pressed else Vector2(0, -f)
			MOUSE_BUTTON_WHEEL_DOWN:
				return Vector2(f, 0) if mb.shift_pressed else Vector2(0, f)
			MOUSE_BUTTON_WHEEL_LEFT:
				return Vector2(-f, 0)
			MOUSE_BUTTON_WHEEL_RIGHT:
				return Vector2(f, 0)
	var pan := e as InputEventPanGesture
	if pan:
		return pan.delta * PAN_SCALE
	return Vector2.ZERO


## A wheel or trackpad turn at `pos`. A list under the pointer that can
## still scroll that way takes it, and then the whole turn is the list's,
## however long a trackpad keeps it going: only a fresh turn (after a short
## pause) can move pane. Otherwise, once the turn has gone far enough one
## way, it moves one pane that way, as the arrow keys do, and the rest of
## the turn does nothing more.
func _on_wheel(turn: Vector2, pos: Vector2) -> void:
	var now := Time.get_ticks_usec()
	if now - _wheel_at > WHEEL_GAP * 1000000.0:
		_wheel_free = true
		_wheel_sum = Vector2.ZERO
	_wheel_at = now
	if not _wheel_free or not _flows.is_empty() or Modal.is_open() or _swiping:
		return
	var sideways := absf(turn.x) > absf(turn.y)
	var along := -(turn.x if sideways else turn.y)
	# A list that only scrolls sideways takes the wheel down too.
	if _moving or _scroll_blocks(pos, sideways, along) or (not sideways and _scroll_blocks(pos, true, along, true)):
		_wheel_free = false
		return
	_wheel_sum += turn
	var step := Vector2i.ZERO
	if absf(_wheel_sum.x) >= WHEEL_STEP and absf(_wheel_sum.x) > absf(_wheel_sum.y):
		step = Vector2i(1 if _wheel_sum.x > 0.0 else -1, 0)
	elif absf(_wheel_sum.y) >= WHEEL_STEP:
		step = Vector2i(0, 1 if _wheel_sum.y > 0.0 else -1)
	if step == Vector2i.ZERO:
		return
	_wheel_free = false
	if _can_go(_at + step):
		get_viewport().set_input_as_handled()
		_go_cell(_at + step)


# --- Swiping -----------------------------------------------------------------

func _input(e: InputEvent) -> void:
	if _synthetic:
		return
	var turn := _wheel_turn(e)
	if turn != Vector2.ZERO:
		_on_wheel(turn, e.position)
		return
	if not _flows.is_empty() or Modal.is_open() or _moving:
		_press = false
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			_swiping = false
			_press_pos = e.position
			_press_time = Time.get_ticks_usec()
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
		if step != Vector2i.ZERO and _can_go(_at + step):
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
	if not _can_go(target) or _scroll_blocks(pos, horizontal, along):
		# Not a swipe: leave this drag to whatever's under the finger.
		_press = false
		return
	_swiping = true
	_target = target
	_progress = 0.0
	_last_time = Time.get_ticks_usec()
	_cancel_gui_press()
	get_viewport().set_input_as_handled()
	var pane: Pane = _panes[target]
	pane.visible = true
	if not pane.shown:
		pane.show_pane()
	_update_swipe(pos)
	# The speed so far is the distance since the press over the time since;
	# measuring it from this instant instead would make every swipe a flick.
	_velocity = _progress / maxf((_last_time - _press_time) / 1000000.0, 0.016)


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
## With `only_sideways`, only lists that can't scroll down count.
func _scroll_blocks(pos: Vector2, horizontal: bool, along: float, only_sideways: bool = false) -> bool:
	var stack: Array[Node] = [_panes[_at]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var sc := n as ScrollContainer
		if sc == null or not sc.is_visible_in_tree() or not sc.get_global_rect().has_point(pos):
			continue
		if only_sideways and sc.get_v_scroll_bar().visible:
			continue
		var bar: ScrollBar = sc.get_v_scroll_bar()
		if horizontal:
			bar = sc.get_h_scroll_bar()
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
