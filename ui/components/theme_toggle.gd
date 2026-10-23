class_name ThemeToggle
extends Button
## The light/dark switch: a plain warm sun in light mode, a cool moon in
## dark mode, that swells a little under the pointer. Tapping spins the icon
## over to the other one, then the whole app fades into the new colours.
## Its colours don't come from the palette, so the focus screen keeps it
## (mid-hover, mid-spin) when the colours change.

const SUN := Color("#f2a93b")
const MOON := Color("#93a6ff")
const HOVER_GROW := 1.12

var _icon := TextureRect.new()


func _init() -> void:
	custom_minimum_size = Vector2(48, 48)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Cursor.HOVER
	# No backing at all, hovered or pressed: just the icon.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_icon.texture = _texture(UI.dark)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	accessibility_name = "Switch to light mode" if UI.dark else "Switch to dark mode"
	pressed.connect(_flip)
	mouse_entered.connect(func(): _hover(true))
	mouse_exited.connect(func(): _hover(false))
	resized.connect(func():
		pivot_offset = size * 0.5
		_icon.pivot_offset = size * 0.5)


## Shows the icon for the current mode, for when it was changed elsewhere.
func sync() -> void:
	if not disabled:
		_icon.texture = _texture(UI.dark)


static func _texture(dark: bool) -> Texture2D:
	return Icons.texture("moon_fill", 28, MOON) if dark else Icons.texture("sun", 30, SUN, 2.4)


## The swell is on the button and the spin on the icon, so the two never
## fight when you tap while hovering.
func _hover(on: bool) -> void:
	# A finger leaves no pointer behind to move off it, so no swell on phones.
	if OS.has_feature("mobile"):
		return
	Motion.to(self, "scale", Vector2.ONE * (HOVER_GROW if on else 1.0), Motion.FAST)


func _flip() -> void:
	disabled = true
	var to_dark := not UI.dark
	var t := Motion.tween(_icon, "flip")
	t.set_parallel(true)
	t.tween_property(_icon, "rotation", PI * 0.5, Motion.time(Motion.FAST))
	t.tween_property(_icon, "scale", Vector2.ONE * 0.3, Motion.time(Motion.FAST))
	# The new icon spins in from a quarter turn back, so it lands upright.
	t.chain().tween_callback(func():
		_icon.texture = _texture(to_dark)
		_icon.rotation = -PI * 0.5)
	t.chain().tween_property(_icon, "rotation", 0.0, Motion.time(Motion.FAST))
	t.parallel().tween_property(_icon, "scale", Vector2.ONE, Motion.time(Motion.FAST))
	t.chain().tween_callback(func():
		App.set_setting("theme", "dark" if to_dark else "light")
		disabled = false)
