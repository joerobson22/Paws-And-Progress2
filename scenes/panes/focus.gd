extends Pane
## The middle of the app: the focus orb. Tap it (a soft bong) and the choose
## focus screen grows out of it.

var _orb: FocusOrb
var _hint: Label


func build() -> void:
	_orb = FocusOrb.new()
	_orb.tapped.connect(_on_tapped)
	add_child(_orb)
	_hint = UI.label("", 15, UI.INK_FAINT, false, 700)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_update_hint()
	_place()


func _place() -> void:
	if not is_instance_valid(_orb):
		return
	# Half the screen: the orb's diameter is half the short side, a little
	# more on narrow phones where width is the short side.
	var d := minf(size.x * 0.7, size.y * 0.5)
	_orb.size = Vector2(d, d)
	_orb.position = (size - _orb.size) * 0.5 - Vector2(0, size.y * 0.03)
	_hint.size = Vector2(size.x, 24)
	_hint.position = Vector2(0, _orb.position.y + d + 28)


func _update_hint() -> void:
	_hint.text = "Tap to adopt your first pet" if App.state.active_projects().is_empty() else "Tap to focus"


## The orb doesn't change with the game state; only the hint might.
func _on_state_changed() -> void:
	if is_instance_valid(_hint):
		_update_hint()


func _on_resized() -> void:
	_place()


func _on_shown() -> void:
	if is_instance_valid(_orb):
		_orb.running = true


func _on_hidden() -> void:
	if is_instance_valid(_orb):
		_orb.running = false


func _on_tapped() -> void:
	Audio.play("bong", 1.0, -4.0)
	Motion.pop(_orb, 0.06, 0.3)
	App.go("choose_focus", {"from": _orb.get_global_rect().get_center()})
