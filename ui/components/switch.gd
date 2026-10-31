class_name Switch
extends Button
## On/off toggle drawn like a phone settings switch: green when on. The
## knob slides across and the track's colour fades, easing in and out.

const TRACK_SIZE := Vector2(52, 30)
const SLIDE := 0.25

## 0 off to 1 on, animated between the two.
var _t := 0.0


func _init(on: bool = false) -> void:
	toggle_mode = true
	button_pressed = on
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(TRACK_SIZE.x, 44)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_t = 1.0 if on else 0.0
	toggled.connect(func(now: bool):
		Motion.method(self, "slide", _set_t, _t, 1.0 if now else 0.0, SLIDE))


func _set_t(v: float) -> void:
	_t = v
	queue_redraw()


func _draw() -> void:
	var top := (size.y - TRACK_SIZE.y) * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = UI.NEUTRAL.lerp(UI.ACCENT, _t)
	track.set_corner_radius_all(int(TRACK_SIZE.y / 2))
	track.anti_aliasing = true
	draw_style_box(track, Rect2(Vector2(size.x - TRACK_SIZE.x, top), TRACK_SIZE))
	var r := TRACK_SIZE.y * 0.5 - 4.0
	var x := size.x - lerpf(TRACK_SIZE.x - r - 4.0, r + 4.0, _t)
	draw_circle(Vector2(x, top + TRACK_SIZE.y * 0.5), r, UI.SURFACE, true, -1.0, true)
	if has_focus():
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(2)
		ring.border_color = UI.ACCENT
		ring.set_corner_radius_all(int(TRACK_SIZE.y / 2) + 3)
		draw_style_box(ring, Rect2(Vector2(size.x - TRACK_SIZE.x - 3, top - 3), TRACK_SIZE + Vector2(6, 6)))
