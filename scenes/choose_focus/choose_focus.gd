extends Control
## Choose what to focus on. Swipe left and right through your pets (the one
## in the middle walks on the spot) and tap it to head out on a walk. At the
## bottom, the red bin deletes that pet and the green tick completes its
## project, each after a check. The + at the top switches to adopting a new
## pet: name it, scroll up and down through the animals and pick its three
## colours; the red cross cancels and the green + adopts it.
## params: {"from": where the opening circle grew from}

const COLOUR_ROLES := ["Primary", "Secondary", "Tertiary"]
## Quick picks in the colour popup: coat colours first, then a few brighter ones.
const SWATCHES := [
	Color("#2b2523"), Color("#4a3528"), Color("#6e5a4e"), Color("#8a6248"), Color("#a8683f"),
	Color("#c9a46a"), Color("#e2c48f"), Color("#f2e6d8"), Color("#9c9c9c"), Color("#5a5a5a"),
	Color("#b4533f"), Color("#d9822b"), Color("#e2c046"), Color("#7fae5a"), Color("#4f6f8f"),
]

## The pet last in the middle, so the screen reopens where you left it.
static var _remembered := ""

var params := {}

var _projects: Array[ProjectData] = []
var _adopting := false
var _draft: ProjectData
var _body := Control.new()
var _pets: Carousel
var _animals: Carousel
var _title: Label
var _meta: Label
var _name_edit: LineEdit
var _swatches: Array[Button] = []
var _left: Button
var _right: Button
var _new: Button


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.SAGE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var insets := UI.safe_insets(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16 + int(insets["left"]))
	margin.add_theme_constant_override("margin_right", 20 + int(insets["right"]))
	margin.add_theme_constant_override("margin_top", 14 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 24 + int(insets["bottom"]))
	add_child(margin)
	var col := UI.vbox(10)
	margin.add_child(col)

	var top := UI.hbox()
	top.add_child(UI.back_button(go_back))
	top.add_child(UI.spacer())
	_new = UI.square_button("plus", "New pet", _start_adopting, UI.SURFACE, UI.INK, 48, UI.SAGE)
	top.add_child(_new)
	col.add_child(top)

	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)

	var bottom := UI.hbox()
	_left = UI.round_button("bin", "Delete pet", _on_left, UI.DANGER, Color.WHITE, 56)
	_right = UI.round_button("check", "Complete project", _on_right, UI.SUCCESS, Color.WHITE, 56)
	bottom.add_child(_left)
	bottom.add_child(UI.spacer())
	bottom.add_child(_right)
	col.add_child(bottom)
	_show_pets("", false)


## Back to the focus screen, from either mode.
func go_back() -> void:
	App.go("home")


# --- Choosing ----------------------------------------------------------------

func _show_pets(select_id: String = "", animate: bool = true) -> void:
	_adopting = false
	_projects = App.state.active_projects()
	if select_id == "":
		select_id = _remembered
	var v := await _swap_body(animate)
	_new.disabled = false
	_set_icon(_left, "bin", "Delete pet")
	_set_icon(_right, "check", "Complete project")
	_left.disabled = _projects.is_empty()
	_right.disabled = _projects.is_empty()

	var cap := UI.caption("Choose your focus")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	if _projects.is_empty():
		v.add_child(_empty())
		return

	_pets = Carousel.new()
	_pets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pets.spacing = clampf(size.x * 0.44, 170.0, 300.0)
	v.add_child(_pets)
	_title = UI.label("", 30, UI.INK, true, 600)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_meta = UI.label("", 15, UI.INK_SOFT, false, 700)
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_meta)
	var hint := UI.label("Tap your pet to start walking", 14, UI.INK_FAINT, false, 700)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

	var items: Array[Control] = []
	var start := 0
	for i in _projects.size():
		items.append(_pet(_projects[i].animal_id, _projects[i].colours, 200.0))
		if _projects[i].id == select_id:
			start = i
	_pets.changed.connect(_on_pet_changed)
	_pets.activated.connect(_start_walk)
	_pets.set_items(items, start)
	_on_pet_changed(start)
	_pets.grab_focus.call_deferred()


func _empty() -> Control:
	var v := UI.vbox(12)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var add := UI.square_button("plus", "Adopt a pet", _start_adopting, UI.SURFACE, UI.INK, 96, UI.SAGE)
	add.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(add)
	var t := UI.label("No pets yet", 26, UI.INK, true, 600)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var p := UI.para("Adopt one for each thing you're working on: a module, a project, a skill.", 15)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size.x = minf(320.0, size.x - 48.0)
	v.add_child(p)
	return v


func _on_pet_changed(i: int) -> void:
	for j in _pets.items.size():
		(_pets.items[j].get_meta("view") as AnimalView).walking = j == i
	var p := _projects[i]
	_remembered = p.id
	_title.text = p.name
	var animal_name: String = Content.animal(p.animal_id).get("name", "")
	_meta.text = "%s · %s focused" % [animal_name, Stats.format_duration(App.state.project_seconds(p.id))]
	Motion.pop(_title, 0.04, 0.25)


func _start_walk(i: int) -> void:
	var p := _projects[i]
	var from := _pets.items[i].get_global_rect().get_center()
	App.start_walk(p.id)
	App.go("walk", {"from": from})


func _on_left() -> void:
	if _adopting:
		_show_pets()
		return
	var p := _projects[_pets.index]
	var animal_name: String = Content.animal(p.animal_id).get("name", "")
	Modal.confirm("Delete %s?" % p.name,
		"Your %s will go for good. Time you've already spent stays in your stats." % animal_name.to_lower(),
		"Delete", "danger").closed.connect(func(ok):
			if ok:
				var next := _neighbour_id(p.id)
				App.delete_project(p.id)
				Toast.show_text("%s deleted" % p.name, "bin")
				_show_pets(next))


func _on_right() -> void:
	if _adopting:
		_adopt()
		return
	var p := _projects[_pets.index]
	var animal_name: String = Content.animal(p.animal_id).get("name", "")
	Modal.confirm("Complete %s?" % p.name,
		"It moves to Completed with everything your %s found along the way. You can't undo this." % animal_name.to_lower(),
		"Complete", "success").closed.connect(func(ok):
			if ok:
				var next := _neighbour_id(p.id)
				App.complete_project(p.id)
				Audio.play("project_complete")
				Toast.show_text("%s moved to Completed" % p.name)
				_show_pets(next))


## The pet that should be in the middle once this one's gone.
func _neighbour_id(id: String) -> String:
	var i := -1
	for j in _projects.size():
		if _projects[j].id == id:
			i = j
	if i + 1 < _projects.size():
		return _projects[i + 1].id
	return _projects[i - 1].id if i > 0 else ""


# --- Adopting ----------------------------------------------------------------

func _start_adopting() -> void:
	if _adopting:
		return
	_adopting = true
	_draft = ProjectData.new()
	_draft.animal_id = Content.animals[0]["id"]
	_draft.colours = Content.animal_default_colours(_draft.animal_id)
	var v := await _swap_body(true)
	_new.disabled = true
	_set_icon(_left, "close", "Cancel")
	_set_icon(_right, "plus", "Adopt")
	_left.disabled = false
	_right.disabled = false

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "What are you focusing on?"
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.max_length = 40
	_name_edit.custom_minimum_size = Vector2(minf(420.0, size.x - 48.0), 52)
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_name_edit.add_theme_font_size_override("font_size", 18)
	_name_edit.text_submitted.connect(func(_t): _name_edit.release_focus())
	v.add_child(_name_edit)

	_animals = Carousel.new()
	_animals.vertical = true
	_animals.spacing = 150.0
	_animals.side_scale = 0.62
	_animals.reach = 1.7
	_animals.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_animals)
	_title = UI.label("", 24, UI.INK, true, 600)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	var hint := UI.label("Scroll for more animals", 13, UI.INK_FAINT, false, 700)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_swatches.clear()
	for k in COLOUR_ROLES.size():
		var cell := UI.vbox(4)
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = "%s colour" % COLOUR_ROLES[k]
		b.pressed.connect(_pick_colour.bind(k))
		cell.add_child(b)
		var l := UI.caption(COLOUR_ROLES[k])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		row.add_child(cell)
		_swatches.append(b)
	v.add_child(row)

	var items: Array[Control] = []
	for a in Content.animals:
		items.append(_pet(a["id"], Content.animal_default_colours(a["id"]), 150.0))
	_animals.changed.connect(_on_animal_changed)
	_animals.set_items(items, 0)
	_on_animal_changed(0)


func _on_animal_changed(i: int) -> void:
	var a: Dictionary = Content.animals[i]
	_draft.animal_id = a["id"]
	_draft.colours = Content.animal_default_colours(a["id"])
	for j in _animals.items.size():
		var view: AnimalView = _animals.items[j].get_meta("view")
		view.walking = j == i
		view.colours = Content.animal_default_colours(Content.animals[j]["id"]) if j != i else _draft.colours
	_title.text = a["name"]
	_refresh_swatches()


func _refresh_swatches() -> void:
	var parts: Array = Content.animal(_draft.animal_id).get("parts", [])
	for k in _swatches.size():
		var b := _swatches[k]
		b.visible = k < parts.size()
		var c := _draft.colours[k] if k < _draft.colours.size() else Color.WHITE
		UI.style_button(b, c, UI.INK, 999, true)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(state)
			sb.set_border_width_all(3)
			sb.border_color = UI.SURFACE


func _pick_colour(k: int) -> void:
	var start := _draft.colours[k]
	Modal.colour("%s colour" % COLOUR_ROLES[k], start, _set_colour.bind(k), SWATCHES)


func _set_colour(c: Color, k: int) -> void:
	_draft.colours[k] = c
	var view: AnimalView = _animals.items[_animals.index].get_meta("view")
	view.queue_redraw()
	_refresh_swatches()


func _adopt() -> void:
	var name := _name_edit.text.strip_edges()
	if name == "":
		_name_edit.placeholder_text = "Give it a name first"
		Motion.shake(_name_edit)
		_name_edit.grab_focus()
		return
	_draft.name = name
	App.add_project(_draft)
	Audio.play(str(Content.animal(_draft.animal_id).get("sound", "")), 1.0, -6.0)
	Toast.show_text("Say hello to your %s" % str(Content.animal(_draft.animal_id).get("name", "")).to_lower(), "paw")
	_show_pets(_draft.id)


# --- Pieces ------------------------------------------------------------------

## Fades the old content out and returns a fresh, empty column in its place.
func _swap_body(animate: bool) -> VBoxContainer:
	var old := _body.get_children()
	if animate and not old.is_empty():
		var t := Motion.tween(_body, "swap")
		t.tween_property(_body, "modulate:a", 0.0, Motion.time(Motion.FAST))
		await t.finished
	for c in old:
		_body.remove_child(c)
		c.queue_free()
	var v := UI.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(v)
	if animate:
		Motion.fade(_body, 1.0)
	else:
		_body.modulate.a = 1.0
	return v


func _set_icon(b: Button, icon: String, tip: String) -> void:
	b.icon = Icons.texture(icon, int(b.custom_minimum_size.x * 0.42), Color.WHITE, 2.6)
	b.tooltip_text = tip


## An animal standing on a soft shadow, for the carousels.
func _pet(animal_id: String, colours: Array[Color], height: float) -> Control:
	var stage := _Stage.new()
	stage.custom_minimum_size = Vector2(height * 1.25, height)
	var view := AnimalView.new()
	view.animal_id = animal_id
	view.colours = colours
	stage.add_child(view)
	stage.set_meta("view", view)
	var s := minf(stage.custom_minimum_size.x / 175.0, height / 105.0) / float(Content.animal(animal_id).get("size", 1.0))
	view.scale = Vector2(s, s)
	view.position = Vector2(stage.custom_minimum_size.x * 0.44, height * 0.86)
	return stage


class _Stage extends Control:
	func _draw() -> void:
		draw_set_transform(Vector2(size.x * 0.48, size.y * 0.87), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, size.x * 0.34, Color(0.18, 0.32, 0.24, 0.12), true, -1.0, true)
