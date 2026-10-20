extends Pane
## The middle of the app: a greeting, and under it the focus orb. Tap the orb
## (a soft bong) and the choose focus screen grows out of it. The sun or moon
## in the top right switches between light and dark.

var _orb: FocusOrb
var _greeting: Label
var _hint: Label
var _toggle: ThemeToggle
var _line := ""
## How many walks there had been when the greeting was picked: a new line
## each time you come home from one.
var _line_walks := -1


func build() -> void:
	_pick_line()
	_greeting = UI.label(_line, 30, UI.INK, true, 600)
	_greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_greeting.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_greeting)
	_orb = FocusOrb.new()
	_orb.tapped.connect(_on_tapped)
	add_child(_orb)
	_hint = UI.label("", 15, UI.INK_FAINT, false, 700)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_toggle = ThemeToggle.new()
	add_child(_toggle)
	_update_hint()
	_place()


func _pick_line() -> void:
	var walks := App.state.sessions.size()
	if _line != "" and walks == _line_walks:
		return
	_line_walks = walks
	var hour := int(Time.get_datetime_dict_from_system()["hour"])
	_line = Content.greeting(hour, str(App.state.profile.get("username", "")), App.rng)


func _place() -> void:
	if not is_instance_valid(_orb):
		return
	# Half the screen: the orb's diameter is half the short side, a little
	# more on narrow phones where width is the short side.
	var d := minf(size.x * 0.7, size.y * 0.5)
	_orb.size = Vector2(d, d)
	_orb.position = (size - _orb.size) * 0.5 + Vector2(0, size.y * 0.02)
	_hint.size = Vector2(size.x, 24)
	_hint.position = Vector2(0, _orb.position.y + d + 28)
	var w := minf(560.0, size.x - 48.0)
	_greeting.size = Vector2(w, 0)
	_greeting.size = Vector2(w, _greeting.get_combined_minimum_size().y)
	_greeting.position = Vector2((size.x - w) * 0.5, _orb.position.y - _greeting.size.y - 22.0)
	var insets := UI.safe_insets(self)
	_toggle.size = _toggle.custom_minimum_size
	_toggle.position = Vector2(size.x - _toggle.size.x - 18.0 - insets["right"], 18.0 + insets["top"])


func _update_hint() -> void:
	_hint.text = "Tap to adopt your first pet" if App.state.active_projects().is_empty() else "Tap to focus"


## Only the hint (and, after a walk, the greeting) depend on the game state.
func _on_state_changed() -> void:
	if is_instance_valid(_hint):
		_update_hint()


func _on_resized() -> void:
	_place()


func _on_shown() -> void:
	if is_instance_valid(_orb):
		_orb.running = true
	if is_instance_valid(_greeting) and App.state.sessions.size() != _line_walks:
		_pick_line()
		_greeting.text = _line
		_place()
		Motion.enter(_greeting, 0.1, 10.0)


func _on_hidden() -> void:
	if is_instance_valid(_orb):
		_orb.running = false


func _on_tapped() -> void:
	Audio.play("bong", 1.0, -4.0)
	Motion.pop(_orb, 0.06, 0.3)
	App.go("choose_focus", {"from": _orb.get_global_rect().get_center()})
