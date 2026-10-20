class_name WalkingIndicator
extends Control
## Three paw prints stepping in turn: "on a walk right now". Stands in for a
## friend's weekly time on the leaderboard while they're focusing.

var colour := UI.ACCENT
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(54, 22)
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Walking right now"


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var paw := Icons.texture("paw", 14, colour)
	for i in 3:
		# Each print fades in then out, one after another, left to right.
		var phase := fposmod(_time * 1.6 - i * 0.45, 1.8)
		var a := clampf(sin(phase / 1.8 * PI), 0.0, 1.0) if phase < 1.8 else 0.0
		var at := Vector2(4 + i * 17, 4 + (5 if i % 2 == 0 else 0))
		draw_texture(paw, at, Color(1, 1, 1, 0.15 + 0.85 * a))
