extends Pane
## The middle of the app: a greeting, and under it the focus orb. Tap the orb
## (a soft bong) and the choose focus screen grows out of it. A home icon
## in the top left marks it, as each screen's icon does. Behind it all is
## the hilltop view (HomeBackdrop, drawn by the app shell). Debug builds
## also get small switches beside the home icon (DebugBar).

## Room above the orb for the greeting, whose words sit at the bottom of it.
const GREETING_BOX := 160.0
const GREETING_SIZE := 24
## The gap between the greeting's last line and the orb.
const GREETING_GAP := 48.0

var _orb: FocusOrb
var _greeting: Label
var _hint: Label
## A soft pill behind the hint, so it reads over the view.
var _hint_pill: PanelContainer
var _home: Control
var _debug: DebugBar
var _sky_debug: Control
var _line := ""
## How many walks there had been when the greeting was picked: a new line
## each time you come home from one.
var _line_walks := -1


func build() -> void:
	_pick_line()
	_greeting = UI.label(_line, GREETING_SIZE, UI.INK, true, 600)
	_greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_greeting.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_greeting.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_greeting)
	if not is_instance_valid(_orb):
		_orb = FocusOrb.new()
		_orb.tapped.connect(_on_tapped)
		add_child(_orb)
	_hint_pill = PanelContainer.new()
	var pill := UI.box(Color(UI.BG, 0.8), Color.TRANSPARENT, 99)
	pill.content_margin_left = 16
	pill.content_margin_right = 16
	pill.content_margin_top = 4
	pill.content_margin_bottom = 4
	_hint_pill.add_theme_stylebox_override("panel", pill)
	_hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_pill)
	_hint = UI.label("", 15, UI.INK_SOFT, false, 700)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_pill.add_child(_hint)
	_home = UI.icon_tile(Minimap.ICONS["focus"])
	add_child(_home)
	if OS.is_debug_build():
		_debug = DebugBar.new()
		add_child(_debug)
		_sky_debug = DebugBar.sky_controls()
		add_child(_sky_debug)
	_update_hint()
	_place()


## The orb keeps drifting through a rebuild (it doesn't take its colours
## from the palette).
func keeps() -> Array[Node]:
	return [_orb]


func _pick_line() -> void:
	var walks := int(App.state.profile.get("walks", 0))
	if _line != "" and walks == _line_walks:
		return
	_line_walks = walks
	# The time of day the sky shows (the debug slider can move it).
	var hour := int(App.day_hour())
	_line = Content.greeting(hour, str(App.state.profile.get("username", "")), App.rng)


func _place() -> void:
	if not is_instance_valid(_orb):
		return
	# Half the screen: the orb's diameter is half the short side, a little
	# more on narrow phones where width is the short side.
	var d := minf(size.x * 0.7, size.y * 0.5)
	_orb.size = Vector2(d, d)
	_orb.position = (size - _orb.size) * 0.5 + Vector2(0, size.y * 0.02)
	_hint_pill.size = _hint_pill.get_combined_minimum_size()
	_hint_pill.position = Vector2((size.x - _hint_pill.size.x) * 0.5, _orb.position.y + d + 24)
	# The home icon sits where the other screens' title icons do.
	var insets := UI.safe_insets(self)
	_home.size = _home.custom_minimum_size
	_home.position = Vector2((32.0 if wide else 18.0) + insets["left"], float(Pane.EDGE_GAP) + insets["top"])
	if is_instance_valid(_debug):
		_debug.size = _debug.get_combined_minimum_size()
		_debug.position = Vector2(_home.position.x + _home.size.x + 12.0, _home.position.y)
		_sky_debug.size = _sky_debug.get_combined_minimum_size()
		var right: float = size.x - _sky_debug.size.x * DebugBar.SCALE - (32.0 if wide else 18.0) - insets["right"]
		var after_switches: float = _debug.position.x + _debug.size.x * DebugBar.SCALE + 16.0
		if right >= after_switches:
			_sky_debug.position = Vector2(right, _home.position.y)
		else:
			# No room beside the switches (a phone): under them.
			_sky_debug.position = Vector2(_debug.position.x, _debug.position.y + _debug.size.y * DebugBar.SCALE + 6.0)
	var w := minf(560.0, size.x - 48.0)
	var bottom := _orb.position.y - GREETING_GAP
	# Debug builds: clear of the sky controls in the top right, if the
	# greeting could reach up beside them.
	if is_instance_valid(_sky_debug) and _sky_debug.position.x > size.x * 0.5 \
			and bottom - GREETING_BOX < _sky_debug.position.y + _sky_debug.size.y * DebugBar.SCALE:
		w = minf(w, (_sky_debug.position.x - size.x * 0.5 - 16.0) * 2.0)
	# A tall box with the words at its bottom, rather than one measured to
	# fit: a wrapping label's measured height isn't stable across rebuilds,
	# and the words would jump when the colours change.
	_greeting.size = Vector2(w, GREETING_BOX)
	# (It can come out taller; its bottom is what stays put.)
	_greeting.position = Vector2((size.x - w) * 0.5, bottom - _greeting.size.y)


func _update_hint() -> void:
	_hint.text = Text.t("focus.hint_first_pet" if App.state.active_pets().is_empty() else "focus.hint")
	_place()


## Only the hint (and, after a walk, the greeting) depend on the game state,
## and in debug builds the sky controls.
func _on_state_changed() -> void:
	if is_instance_valid(_sky_debug):
		# The debug pills show what's picked, even when the look stays the
		# same (Light picked while Auto was already light).
		var fresh := DebugBar.sky_controls()
		add_child(fresh)
		move_child(fresh, _sky_debug.get_index())
		remove_child(_sky_debug)
		_sky_debug.queue_free()
		_sky_debug = fresh
	if is_instance_valid(_hint):
		_update_hint()



func _on_resized() -> void:
	_place()


func _on_shown() -> void:
	if is_instance_valid(_orb):
		_orb.running = true
	if is_instance_valid(_greeting) and int(App.state.profile.get("walks", 0)) != _line_walks:
		_pick_line()
		_greeting.text = _line
		_place()
		Motion.enter(_greeting, 0.1, 10.0)


func _on_hidden() -> void:
	if is_instance_valid(_orb):
		_orb.running = false


func _on_tapped() -> void:
	Audio.play("orb_tap", 1.0, -4.0, "bong")
	Motion.pop(_orb, 0.06, 0.3)
	App.go("choose_focus", {"from": _orb.get_global_rect().get_center()})
