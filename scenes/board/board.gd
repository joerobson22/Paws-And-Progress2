extends Control
## Noticeboard: a polaroid for every finished project.

var params := {}


func _ready() -> void:
	var col := UI.page(self, 1000)
	col.add_child(UI.header("Noticeboard"))
	var done := App.state.completed_projects()
	if done.is_empty():
		col.add_child(UI.para("Finished projects get pinned here with a polaroid of their animal.", 16, UI.INK_SOFT))
		return
	done.sort_custom(func(a, b): return a.completed_unix > b.completed_unix)

	var board := PanelContainer.new()
	var bb := UI.box(Color("#b98a5e"), Color.TRANSPARENT, 24)
	bb.set_content_margin_all(24)
	board.add_theme_stylebox_override("panel", bb)
	var grid := GridContainer.new()
	grid.columns = 4 if UI.is_wide(self) else 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	board.add_child(grid)
	col.add_child(board)

	for i in done.size():
		grid.add_child(_polaroid(done[i], i))


func _polaroid(p: ProjectData, index: int) -> Control:
	var frame := PanelContainer.new()
	var fb := UI.box(UI.PAPER, Color.TRANSPARENT, 4)
	fb.set_content_margin_all(10)
	fb.content_margin_bottom = 14
	fb.shadow_color = Color(0, 0, 0, 0.2)
	fb.shadow_size = 6
	frame.add_theme_stylebox_override("panel", fb)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A slight tilt so the board looks pinned by hand.
	frame.rotation_degrees = [-2.0, 1.5, -1.0, 2.0][index % 4]
	var v := UI.vbox(6)
	frame.add_child(v)
	v.add_child(UI.animal_portrait(p.animal_id, p.colours, Vector2(0, 110), Color("#cfe3ee")))
	v.add_child(UI.label(p.name, 17, UI.INK, true, 600))
	var date := Time.get_date_string_from_unix_time(p.completed_unix)
	v.add_child(UI.label("%s · %s" % [Stats.format_duration(App.state.project_seconds(p.id)), date], 13, UI.INK_SOFT))
	if p.grade != "":
		v.add_child(UI.label(p.grade, 13, UI.FOREST, false, 800))
	return frame
