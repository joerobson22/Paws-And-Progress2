extends Control
## Choose a walk: every active project as a card with its animal.

var params := {}


func _ready() -> void:
	var col := UI.page(self, 1000)
	var head := UI.header("Choose a walk")
	head.add_child(UI.cta("New project", App.go.bind("project_editor", {})))
	col.add_child(head)

	var projects := App.state.active_projects()
	if projects.is_empty():
		col.add_child(UI.para("No projects yet. Each project or module gets its own animal, and every focus session is a walk with them.", 18, UI.INK_SOFT))
		return

	var grid := GridContainer.new()
	grid.columns = 3 if UI.is_wide(self) else 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	col.add_child(grid)
	for p in projects:
		grid.add_child(_project_card(p))


func _project_card(p: ProjectData) -> Control:
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UI.vbox(10)
	card.add_child(col)
	var portrait := UI.animal_portrait(p.animal_id, p.colours, Vector2(0, 120), Color("#e5efe2"))
	col.add_child(portrait)
	col.add_child(UI.label(p.name, 22, UI.INK, true, 600))
	var animal_name: String = Content.animal(p.animal_id).get("name", "")
	var kind := "Module" if p.kind == ProjectData.KIND_MODULE else "Project"
	col.add_child(UI.para("%s · %s · %s walked" % [kind, animal_name, Stats.format_duration(App.state.project_seconds(p.id))], 14))
	var row := UI.hbox(8)
	var walk := UI.cta("Walk", _start.bind(p.id))
	walk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(walk)
	row.add_child(UI.quiet_button("Edit", App.go.bind("project_editor", {"id": p.id})))
	col.add_child(row)
	return card


func _start(project_id: String) -> void:
	App.start_walk(project_id)
	App.go("walk")
