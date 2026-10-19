class_name Switch
extends Button
## On/off toggle drawn like a phone settings switch: forest when on.

const TRACK_SIZE := Vector2(52, 30)


func _init(on: bool = false) -> void:
	toggle_mode = true
	button_pressed = on
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(TRACK_SIZE.x, 44)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	toggled.connect(func(_on): queue_redraw())


func _draw() -> void:
	var top := (size.y - TRACK_SIZE.y) * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = UI.FOREST if button_pressed else UI.LINE
	track.set_corner_radius_all(int(TRACK_SIZE.y / 2))
	track.anti_aliasing = true
	draw_style_box(track, Rect2(Vector2(size.x - TRACK_SIZE.x, top), TRACK_SIZE))
	var r := TRACK_SIZE.y * 0.5 - 4.0
	var x := size.x - (r + 4.0 if button_pressed else TRACK_SIZE.x - r - 4.0)
	draw_circle(Vector2(x, top + TRACK_SIZE.y * 0.5), r, UI.PAPER, true, -1.0, true)
	if has_focus():
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(2)
		ring.border_color = UI.APRICOT
		ring.set_corner_radius_all(int(TRACK_SIZE.y / 2) + 3)
		draw_style_box(ring, Rect2(Vector2(size.x - TRACK_SIZE.x - 3, top - 3), TRACK_SIZE + Vector2(6, 6)))
