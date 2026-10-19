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

	var col := UI.page(self)
	col.add_child(UI.header("Edit project" if _original else "New project", App.go.bind("walks", {})))

	_preview_holder = UI.vbox()
	col.add_child(_preview_holder)

	var form := UI.card()
	var f := UI.vbox(14)
	form.add_child(f)
	col.add_child(form)

	f.add_child(UI.caption("Name"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "e.g. Dissertation, Spanish, Portfolio site"
	_name_edit.text = _draft.name
	_name_edit.custom_minimum_size.y = 52
	_name_edit.text_changed.connect(func(t): _draft.name = t)
	f.add_child(_name_edit)

	f.add_child(UI.caption("Type"))
	var kinds := UI.hbox(8)
	for k in [[ProjectData.KIND_PROJECT, "Project"], [ProjectData.KIND_MODULE, "Course module"]]:
		var b := UI.button(k[1], _set_kind.bind(k[0]))
		_kind_buttons[k[0]] = b
		kinds.add_child(b)
	f.add_child(kinds)

	f.add_child(UI.caption("Animal"))
	var grid := GridContainer.new()
	grid.columns = 6 if UI.is_wide(self) else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for a in Content.animals:
		grid.add_child(_animal_choice(a))
	f.add_child(grid)

	f.add_child(UI.caption("Colours"))
	_colours_box = UI.vbox(8)
	f.add_child(_colours_box)

	var actions := UI.hbox(8)
	var save := UI.cta("Save", _save)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(save)
	if _original:
		actions.add_child(UI.button("Mark complete", _complete))
		actions.add_child(UI.button("Delete", _confirm_delete, UI.DANGER))
	col.add_child(actions)

	_refresh()


func _animal_choice(a: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(110, 96)
	b.tooltip_text = a["name"]
	var selected: bool = a["id"] == _draft.animal_id
	var style := UI.box(Color("#e5efe2") if selected else UI.TRACK, UI.FOREST if selected else Color.TRANSPARENT)
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(s, style)
	var portrait := UI.animal_portrait(a["id"], Content.animal_default_colours(a["id"]), Vector2(90, 60), Color.TRANSPARENT)
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
			b.add_theme_stylebox_override(s, UI.box(UI.FOREST if on else UI.TRACK))
		for s in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(s, UI.ON_FOREST if on else UI.INK)

	for c in _preview_holder.get_children():
		c.queue_free()
	_preview_holder.add_child(UI.animal_portrait(_draft.animal_id, _draft.colours, Vector2(0, 200), Color("#e5efe2")))

	for c in _colours_box.get_children():
		c.queue_free()
	var parts: Array = Content.animal(_draft.animal_id).get("parts", [])
	for i in parts.size():
		var row := UI.hbox()
		var l := UI.label(parts[i], 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(120, 44)
		picker.edit_alpha = false
		picker.color = _draft.colours[i] if i < _draft.colours.size() else Color.WHITE
		picker.color_changed.connect(_set_colour.bind(i))
		row.add_child(picker)
		_colours_box.add_child(row)
	_colours_box.add_child(UI.quiet_button("Reset colours", func():
		_draft.colours = Content.animal_default_colours(_draft.animal_id)
		_refresh()))


func _set_colour(colour: Color, index: int) -> void:
	while _draft.colours.size() <= index:
		_draft.colours.append(Color.WHITE)
	_draft.colours[index] = colour
	# Update the preview only; rebuilding the pickers would close the open one.
	for c in _preview_holder.get_children():
		c.queue_free()
	_preview_holder.add_child(UI.animal_portrait(_draft.animal_id, _draft.colours, Vector2(0, 200), Color("#e5efe2")))


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
