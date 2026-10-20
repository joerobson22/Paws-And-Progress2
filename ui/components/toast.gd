class_name Toast
extends PanelContainer
## A short message that floats up from the bottom, waits, then fades away
## ("Moved to Completed"). Lives on the same layer as popups.


static func show_text(text: String, icon: String = "check") -> void:
	var t := Toast.new()
	var b := UI.box(UI.INK, Color.TRANSPARENT, 999)
	b.content_margin_left = 16
	b.content_margin_right = 20
	b.content_margin_top = 10
	b.content_margin_bottom = 10
	t.add_theme_stylebox_override("panel", b)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(8)
	if icon != "":
		row.add_child(UI.icon_rect(icon, 16, UI.BG))
	row.add_child(UI.label(text, 15, UI.BG, false, 800))
	t.add_child(row)
	var host: Node = Modal.layer if Modal.layer and is_instance_valid(Modal.layer) else (Engine.get_main_loop() as SceneTree).root
	host.add_child(t)
	t._run.call_deferred()


func _run() -> void:
	var view := get_viewport_rect().size
	size = get_combined_minimum_size()
	var rest := Vector2((view.x - size.x) * 0.5, view.y - size.y - 96.0 - UI.safe_insets(self)["bottom"])
	position = rest + Vector2(0, 16)
	modulate.a = 0.0
	var t := Motion.tween(self, "toast")
	t.set_parallel(true)
	t.tween_property(self, "position", rest, Motion.time(Motion.NORMAL))
	t.tween_property(self, "modulate:a", 1.0, Motion.time(Motion.NORMAL))
	t.chain().tween_interval(1.8)
	t.chain().tween_property(self, "modulate:a", 0.0, Motion.time(Motion.NORMAL))
	t.chain().tween_callback(queue_free)
