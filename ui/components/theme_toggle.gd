class_name ThemeToggle
extends Button
## The round light/dark switch: a warm sun in light mode, a cool moon in
## dark mode. Tapping spins the icon over to the other one, then switches
## the whole app.

const SUN := Color("#f2a93b")
const MOON := Color("#93a6ff")

var _icon := TextureRect.new()


func _init() -> void:
	custom_minimum_size = Vector2(48, 48)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	UI.style_button(self, UI.SURFACE, UI.INK, 999, true)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		(get_theme_stylebox(state) as StyleBoxFlat).set_content_margin_all(0)
	_icon.texture = _texture(UI.dark)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	tooltip_text = "Switch to light mode" if UI.dark else "Switch to dark mode"
	pressed.connect(_flip)
	resized.connect(func(): _icon.pivot_offset = size * 0.5)


static func _texture(dark: bool) -> Texture2D:
	return Icons.texture("moon_fill", 24, MOON) if dark else Icons.texture("sun", 26, SUN, 2.4)


func _flip() -> void:
	disabled = true
	var to_dark := not UI.dark
	var t := Motion.tween(_icon, "flip")
	t.set_parallel(true)
	t.tween_property(_icon, "rotation", PI * 0.5, Motion.time(Motion.FAST))
	t.tween_property(_icon, "scale", Vector2.ONE * 0.3, Motion.time(Motion.FAST))
	t.chain().tween_callback(func(): _icon.texture = _texture(to_dark))
	t.chain().tween_property(_icon, "rotation", PI, Motion.time(Motion.FAST))
	t.parallel().tween_property(_icon, "scale", Vector2.ONE, Motion.time(Motion.FAST))
	t.chain().tween_callback(func(): App.set_setting("theme", "dark" if to_dark else "light"))
