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
	# The track fits the switch's height if that's less (a small switch).
	var track_size := TRACK_SIZE * minf(1.0, size.y / TRACK_SIZE.y)
	var top := (size.y - track_size.y) * 0.5
	var left := size.x - track_size.x
	var track := StyleBoxFlat.new()
	track.bg_color = UI.NEUTRAL.lerp(UI.ACCENT, _t)
	UI.corners(track, 999)
	track.anti_aliasing = not UI.look("crisp")
	if UI.look("edge_buttons"):
		UI.edge(track)
	draw_style_box(track, Rect2(Vector2(left, top), track_size))
	# The knob is never see-through, and stays light on dark tracks in the
	# tried-out styles (as their boards drew it).
	var knob := Color(UI.SURFACE, 1.0) if UI.SURFACE.a > 0.9 else Color.WHITE
	if UI.dark and UI.style != "classic":
		knob = UI.INK
	if UI.look("corner") <= 0.0:
		# Square styles: a square knob, inside the track's outline.
		var inset := float(UI.look("edge")) + 1.0
		var side := track_size.y - inset * 2.0
		var kx := lerpf(left + inset, size.x - inset - side, _t)
		draw_rect(Rect2(Vector2(kx, top + inset), Vector2(side, side)), knob)
	else:
		var r := track_size.y * 0.5 - 4.0
		var x := lerpf(left + r + 4.0, size.x - r - 4.0, _t)
		draw_circle(Vector2(x, top + track_size.y * 0.5), r, knob, true, -1.0, true)
	if has_focus():
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(2)
		ring.border_color = UI.ACCENT
		UI.corners(ring, 999)
		draw_style_box(ring, Rect2(Vector2(left - 3, top - 3), track_size + Vector2(6, 6)))
