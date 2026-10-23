extends Pane
## Completed projects, to the right of the focus screen: a panel for each,
## newest first. Tap the circled "?" in a panel's top right to give it a
## grade (GCSE, A-Level or university); its badge then shows there instead,
## and tapping that changes it.

## Which grading scale the picker opens on; remembered while the app runs.
var _scale := ""


func build() -> void:
	var col := page(720)
	var done := App.state.completed_projects()
	done.sort_custom(func(a, b): return a.completed_unix > b.completed_unix)
	col.add_child(title_row("Completed"))
	if done.is_empty():
		var empty := UI.card(UI.SURFACE, 24)
		var v := UI.vbox(6)
		v.add_child(UI.label("Nothing finished yet", 20, UI.INK, true, 600))
		v.add_child(UI.para("When a project's done, tap the green tick on the choose focus screen and it moves here, with everything your pet found along the way."))
		empty.add_child(v)
		col.add_child(empty)
		return
	for p in done:
		var panel := ProjectPanel.new(p, "", true)
		panel.grade_pressed.connect(_pick_grade)
		col.add_child(panel)


func _pick_grade(project_id: String) -> void:
	var p := App.state.project(project_id)
	if p == null:
		return
	var current := Content.grade(p.grade)
	if _scale == "":
		_scale = current.get("scale", Content.grade_scales[0]["id"])
	var m := Modal.open(440)
	m.body.add_child(m.heading_row("Grade for %s" % p.name))
	var tabs := UI.hbox(6)
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var fill := func(scale_id: String):
		_scale = scale_id
		for c in tabs.get_children() + grid.get_children():
			c.get_parent().remove_child(c)
			c.queue_free()
		for s in Content.grade_scales:
			var tab := UI.pill_button(s["name"], s["id"] == scale_id, Callable())
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.set_meta("scale", s["id"])
			tabs.add_child(tab)
		for s in Content.grade_scales:
			if s["id"] != scale_id:
				continue
			for g in s["grades"]:
				grid.add_child(_grade_choice("%s/%s" % [s["id"], g["id"]], p, m))
	m.body.add_child(tabs)
	m.body.add_child(grid)
	# The tabs are remade on each switch, so they're wired up as they arrive.
	tabs.child_entered_tree.connect(func(tab: Node):
		if tab is Button:
			tab.pressed.connect(func(): fill.call(tab.get_meta("scale"))))
	fill.call(_scale)
	if p.grade != "":
		m.body.add_child(UI.button("Remove grade", func():
			App.set_grade(p.id, "")
			m.close(), "quiet"))


func _grade_choice(ref: String, p: ProjectData, m: Modal) -> Control:
	var g := Content.grade(ref)
	var b := Button.new()
	b.custom_minimum_size = Vector2(66, 72)
	b.accessibility_name = g.get("name", "")
	var on := p.grade == ref
	UI.style_button(b, UI.ACCENT_SOFT if on else UI.SURFACE_SOFT, UI.INK, 18)
	if on:
		for state in ["normal", "hover"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(state)
			sb.set_border_width_all(2)
			sb.border_color = UI.ACCENT
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(UI.grade_badge(ref, 46))
	UI.ignore_mouse(centre)
	b.add_child(centre)
	b.pressed.connect(func():
		App.set_grade(p.id, ref)
		m.close()
		Toast.show_text("%s: %s" % [p.name, g.get("label", "")], "star"))
	return b
