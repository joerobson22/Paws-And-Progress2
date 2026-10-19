extends Control
## Create or edit a project: name, type, animal and the animal's colours.
## params: {"id": String} to edit an existing project, empty to create one.

var params := {}

var _original: ProjectData
var _draft: ProjectData
var _preview_holder: VBoxContainer
var _colours_box: VBoxContainer
var _name_edit: LineEdit
var _kind_buttons := {}


func _ready() -> void:
	_original = App.state.project(str(params.get("id", "")))
	if params.get("draft") is ProjectData:
		_draft = params["draft"]
	elif _original:
		_draft = _original.duplicate(true)
	else:
		_draft = ProjectData.new()
		_draft.animal_id = Content.animals[0]["id"]
		_draft.colours = Content.animal_default_colours(_draft.animal_id)

	var wide := UI.is_wide(self)
	var col := UI.page(self, 1220)
	col.add_child(UI.header("Edit project" if _original else "New project", App.go.bind("walks", {"selected": params.get("id", "")})))
	var body: BoxContainer = UI.hbox(24) if wide else UI.vbox(16)
	col.add_child(body)

	# Left: the companion on a little hill, with a colour row per part.
	var stage := UI.panel(Color("#dce9d6"), 28, 20)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sv := UI.vbox(16)
	stage.add_child(sv)
	_preview_holder = UI.vbox()
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(_preview_holder)
	var swatches := UI.panel(Color(UI.PAPER, 0.94), 22, 16)
	_colours_box = UI.vbox(10)
	swatches.add_child(_colours_box)
	sv.add_child(swatches)
	body.add_child(stage)

	# Right: the details.
	var form := UI.card(UI.PAPER, 24)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_stretch_ratio = 1.15
	var f := UI.vbox(14)
	form.add_child(f)
	body.add_child(form)

	f.add_child(UI.label("Project or module", 14, UI.INK, false, 800))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "e.g. Dissertation, Spanish, Portfolio site"
	_name_edit.text = _draft.name
	_name_edit.custom_minimum_size.y = 48
	_name_edit.text_changed.connect(func(t): _draft.name = t)
	f.add_child(_name_edit)

	var kinds := UI.hbox(8)
	for k in [[ProjectData.KIND_PROJECT, "Project"], [ProjectData.KIND_MODULE, "Course module"]]:
		var b := UI.pill_button(k[1], false, _set_kind.bind(k[0]))
		_kind_buttons[k[0]] = b
		kinds.add_child(b)
	f.add_child(kinds)

	f.add_child(UI.label("Choose a companion", 14, UI.INK, false, 800))
	var grid := GridContainer.new()
	grid.columns = 6 if wide else 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for a in Content.animals:
		grid.add_child(_animal_choice(a))
	f.add_child(grid)
	var pace: String = Content.animal(_draft.animal_id).get("name", "")
	f.add_child(UI.para("Each companion walks at its own pace and brings its own four gifts. The %s is %s." % [pace.to_lower(), _pace_words(float(Content.animal(_draft.animal_id).get("walk_speed", 1.0)))], 13))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	f.add_child(spacer)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 10)
	actions.alignment = FlowContainer.ALIGNMENT_END
	if _original:
		actions.add_child(UI.button("Delete", _confirm_delete, UI.TRACK, UI.DANGER))
		actions.add_child(UI.quiet_button("Mark complete", _complete))
	else:
		actions.add_child(UI.quiet_button("Cancel", App.go.bind("walks", {})))
	actions.add_child(UI.button("Save" if _original else "Adopt and save", _save))
	f.add_child(actions)

	_refresh()


static func _pace_words(speed: float) -> String:
	if speed < 0.3:
		return "very, very slow"
	if speed < 0.7:
		return "a slow, steady walker"
	if speed > 1.05:
		return "always pulling ahead"
	return "an easy walking pace"


func _animal_choice(a: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = a["name"]
	var selected: bool = a["id"] == _draft.animal_id
	var style := UI.box(UI.SAGE if selected else Color("#f4ecdd"), UI.FOREST if selected else Color.TRANSPARENT, 16)
	style.set_border_width_all(3 if selected else 0)
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, style)
	var portrait := UI.animal_portrait(a["id"], Content.animal_default_colours(a["id"]), Vector2(64, 52), Color.TRANSPARENT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(portrait)
	b.pressed.connect(_pick_animal.bind(a["id"]))
	return b


func _pick_animal(id: String) -> void:
	if id == _draft.animal_id:
		return
	_draft.animal_id = id
	_draft.colours = Content.animal_default_colours(id)
	_draft.name = _name_edit.text
	# Reopen with the draft so the selection highlight moves.
	App.go("project_editor", {"id": params.get("id", ""), "draft": _draft})


func _set_kind(kind: String) -> void:
	_draft.kind = kind
	_refresh()


func _refresh() -> void:
	for k in _kind_buttons:
		var on: bool = k == _draft.kind
		var b: Button = _kind_buttons[k]
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(s).duplicate()
			sb.bg_color = UI.INK if on else UI.PILL
			b.add_theme_stylebox_override(s, sb)
		for s in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(s, UI.PAPER if on else Color("#5c5246"))

	_show_preview()

	for c in _colours_box.get_children():
		c.queue_free()
	var parts: Array = Content.animal(_draft.animal_id).get("parts", [])
	var grid := GridContainer.new()
	grid.columns = parts.size() + 1 if UI.is_wide(self) else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	_colours_box.add_child(grid)
	for i in parts.size():
		var row := UI.vbox(6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := UI.label(parts[i], 13, UI.INK, false, 800)
		row.add_child(l)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(0, 40)
		var round := UI.box(Color.TRANSPARENT, UI.LINE, 999)
		round.set_content_margin_all(4)
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			picker.add_theme_stylebox_override(st, round)
		picker.edit_alpha = false
		picker.color = _draft.colours[i] if i < _draft.colours.size() else Color.WHITE
		picker.color_changed.connect(_set_colour.bind(i))
		row.add_child(picker)
		grid.add_child(row)
	var reset := UI.quiet_button("Reset", func():
		_draft.colours = Content.animal_default_colours(_draft.animal_id)
		_refresh())
	reset.size_flags_vertical = Control.SIZE_SHRINK_END
	reset.custom_minimum_size.y = 40
	grid.add_child(reset)


func _set_colour(colour: Color, index: int) -> void:
	while _draft.colours.size() <= index:
		_draft.colours.append(Color.WHITE)
	_draft.colours[index] = colour
	# Update the preview only; rebuilding the pickers would close the open one.
	_show_preview()


func _show_preview() -> void:
	for c in _preview_holder.get_children():
		c.queue_free()
	var portrait := UI.animal_portrait(_draft.animal_id, _draft.colours, Vector2(0, 260), Color("#b9d1ae"))
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.add_child(portrait)


## Copies the draft into the saved project. False if it still needs a name.
func _apply() -> bool:
	_draft.name = _name_edit.text.strip_edges()
	if _draft.name == "":
		_name_edit.placeholder_text = "Give your project a name first"
		_name_edit.grab_focus()
		return false
	if _original:
		_original.name = _draft.name
		_original.kind = _draft.kind
		_original.animal_id = _draft.animal_id
		_original.colours = _draft.colours.duplicate()
		App.update_project(_original)
	else:
		App.add_project(_draft)
	return true


func _save() -> void:
	if _apply():
		App.go("walks")


func _complete() -> void:
	if _apply():
		App.complete_project(_original.id)
		App.go("board")


func _confirm_delete() -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = "Delete \"%s\"? Its walks stay in your stats." % _original.name
	d.ok_button_text = "Delete"
	d.confirmed.connect(func():
		App.delete_project(_original.id)
		App.go("walks"))
	add_child(d)
	d.popup_centered()
