extends Control
## Choose what to focus on, standing in the place you're about to walk.
## The row of buttons at the top picks the place, in the order they unlock
## (locked ones are greyed out with a padlock and the level that unlocks
## them). Under it are the project and the pet's name; swipe left and right
## through your pets, which stand on the path with their kind and time
## underneath (the one in the middle walks on the spot), and tap one to head
## out. At the bottom, the red bin deletes that pet and the green tick
## completes its project, each after a check. The × at the top left goes back
## home, and the + at the top right switches to adopting a new pet: say what
## it's for, give it a name, scroll up and down through the animals (locked
## ones show the level they unlock at, and no colours) and pick its three
## colours. While adopting the bottom buttons go away, the × cancels and the
## + turns into a tick that adopts it.
## params: {"from": where the opening circle grew from}

const COLOUR_ROLES := ["Primary", "Secondary", "Tertiary"]
## Quick picks in the colour popup: coat colours first, then a few brighter ones.
const SWATCHES := [
	Color("#2b2523"), Color("#4a3528"), Color("#6e5a4e"), Color("#8a6248"), Color("#a8683f"),
	Color("#c9a46a"), Color("#e2c48f"), Color("#f2e6d8"), Color("#9c9c9c"), Color("#5a5a5a"),
	Color("#b4533f"), Color("#d9822b"), Color("#e2c046"), Color("#7fae5a"), Color("#4f6f8f"),
]
## How tall pets stand in the chooser.
const PET_HEIGHT := 200.0
## The scenery drifts by slowly behind the pets, in pixels a second.

## The pet last in the middle, so the screen reopens where you left it.
static var _remembered := ""

var params := {}

var _projects: Array[ProjectData] = []
var _adopting := false
var _draft: ProjectData
var _scenery: Scenery
var _shade := _Shade.new()
var _pick := Control.new()
var _adopt_layer := Control.new()
var _pets: Carousel
var _places: Dictionary = {}  # place id -> its button
var _place_name: Label
var _words: VBoxContainer
var _title: Label
var _pet_line: Label
## Under the pet: its kind and how long you've focused with it.
var _under: Label
var _animals: Carousel
var _animal_title: Label
var _animal_hint: Label
var _name_edit: LineEdit
var _pet_edit: LineEdit
var _swatches: Array[Button] = []
var _swatch_row: Control
var _close: Button
var _left: Button
var _right: Button
var _bottom: Control
## The + at the top right; a tick while adopting.
var _new: KnockoutButton


func _ready() -> void:
	_show_place(_place_id())
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for layer in [_pick, _adopt_layer]:
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	_adopt_layer.visible = false

	var insets := UI.safe_insets(self)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 12 + int(insets["left"]))
	top.add_theme_constant_override("margin_right", 18 + int(insets["right"]))
	top.add_theme_constant_override("margin_top", 14 + int(insets["top"]))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var row := UI.hbox()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	_close = UI.round_button("close", "Back", _on_close, Color.TRANSPARENT, UI.ON_DARK, 48, false)
	row.add_child(_close)
	row.add_child(UI.spacer())
	_new = KnockoutButton.new(48)
	_new.accessibility_name = "New pet"
	_new.pressed.connect(_on_new)
	row.add_child(_new)

	var bottom := MarginContainer.new()
	_bottom = bottom
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.add_theme_constant_override("margin_left", 16 + int(insets["left"]))
	bottom.add_theme_constant_override("margin_right", 16 + int(insets["right"]))
	bottom.add_theme_constant_override("margin_bottom", 22 + int(insets["bottom"]))
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var buttons := UI.hbox()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(buttons)
	_left = UI.round_button("bin", "Delete pet", _on_left, UI.DANGER, Color.WHITE, 56)
	_right = UI.round_button("check", "Complete project", _on_right, UI.SUCCESS, Color.WHITE, 56)
	buttons.add_child(_left)
	buttons.add_child(UI.spacer())
	buttons.add_child(_right)

	_build_pick()
	_style_top(false)
	resized.connect(_layout)
	_layout.call_deferred()
	Audio.ambience(_scenery.ambience())


## Back to the focus screen, from either mode.
func go_back() -> void:
	App.go("home")


## The × cancels adopting, or goes back home.
func _on_close() -> void:
	if _adopting:
		_show_mode(false)
	else:
		go_back()


## The + starts adopting; as a tick it adopts.
func _on_new() -> void:
	if _adopting:
		_adopt()
	else:
		_start_adopting()


# --- The place ---------------------------------------------------------------

## The saved place, or lakeside if that's somehow locked.
func _place_id() -> String:
	var id := str(App.state.settings.get("walk_biome", "lake"))
	return id if App.is_unlocked("place", id) and not Content.biome(id).is_empty() else "lake"


## Puts the place's scenery behind everything, fading over the old one.
func _show_place(id: String) -> void:
	var old := _scenery
	_scenery = Scenery.new()
	_scenery.biome = Content.biome(id)
	_scenery.scroll = old.scroll if old else App.rng.randf_range(0.0, 50000.0)
	_scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scenery)
	move_child(_scenery, 1 if old else 0)
	_attach_front()
	if old:
		_scenery.modulate.a = 0.0
		Motion.fade(_scenery, 1.0, Motion.SLOW).tween_callback(old.queue_free)
		Motion.to(old, "front_tint:a", 0.0, Motion.SLOW)
		Audio.ambience(_scenery.ambience())
	_layout()


## The place's front growth goes over the pets (a still scene, but you're
## standing in it) and under the words. Tall plants keep clear of the pet in
## the middle, the one you're choosing.
func _attach_front() -> void:
	if not is_instance_valid(_pets) or not is_instance_valid(_scenery):
		return
	if _scenery.front.get_parent() != _pick:
		_scenery.front_into(_pick)
	_pick.move_child(_scenery.front, _pets.get_index() + 1)


func _pick_place(id: String) -> void:
	var level := Levels.unlock_level("place", id, Content.levels)
	if not App.is_unlocked("place", id):
		Motion.shake(_places[id], 6.0)
		Toast.show_text("%s unlocks at level %d" % [Content.biome(id).get("name", ""), level], "lock")
		return
	if id == _place_id():
		return
	App.set_setting("walk_biome", id)
	_show_place(id)
	_refresh_places()


func _place_buttons() -> Control:
	var panel := UI.panel(UI.GLASS, 22, 6)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := UI.hbox(4)
	panel.add_child(row)
	_places.clear()
	for b in _places_in_order():
		var id: String = b["id"]
		var cell := UI.vbox(0)
		var button := Button.new()
		button.custom_minimum_size = Vector2(42, 42)
		button.accessibility_name = b["name"]
		button.pressed.connect(_pick_place.bind(id))
		cell.add_child(button)
		_places[id] = button
		if not App.is_unlocked("place", id):
			var lock := UI.icon_rect("lock", 12, Color.WHITE)
			lock.position = Vector2(27, 1)
			lock.size = Vector2(14, 14)
			button.add_child(lock)
			var lv := UI.label("Lv %d" % Levels.unlock_level("place", id, Content.levels), 10, UI.ON_DARK_SOFT, false, 800)
			lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.accessibility_name = "%s · unlocks at level %d" % [b["name"], Levels.unlock_level("place", id, Content.levels)]
			cell.add_child(lv)
		row.add_child(cell)
	_refresh_places()
	return panel


## The places in the order they unlock.
static func _places_in_order() -> Array:
	var out: Array = Content.biomes.duplicate()
	out.sort_custom(func(a, b): return Levels.unlock_level("place", a["id"], Content.levels) < Levels.unlock_level("place", b["id"], Content.levels))
	return out


func _refresh_places() -> void:
	var current := _place_id()
	for id in _places:
		var button: Button = _places[id]
		var unlocked := App.is_unlocked("place", id)
		var on: bool = id == current
		var fill := Color.WHITE if on else Color(1, 1, 1, 0.0)
		var ink := UI.ACCENT.darkened(0.2) if on else Color(1, 1, 1, 0.92 if unlocked else 0.35)
		UI.style_button(button, fill, ink, 14)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			(button.get_theme_stylebox(state) as StyleBoxFlat).set_content_margin_all(0)
		button.icon = Icons.texture(str(Content.biome(id).get("icon", "place_lake")), 22, Color.WHITE, 2.0)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _place_name:
		_place_name.text = str(Content.biome(current).get("name", "")).to_upper()


# --- Choosing ----------------------------------------------------------------

func _build_pick(select_id: String = "") -> void:
	for c in _pick.get_children():
		if c.is_in_group(Scenery.FRONT_GROUP):
			continue  # belongs to its scenery, which frees it
		_pick.remove_child(c)
		c.queue_free()
	_projects = App.state.active_projects()
	if select_id == "":
		select_id = _remembered

	var places := UI.vbox(4)
	places.name = "Places"
	places.mouse_filter = Control.MOUSE_FILTER_IGNORE
	places.add_child(_place_buttons())
	_place_name = _shadowed(UI.label("", 12, UI.ON_DARK, false, 900))
	_place_name.add_theme_constant_override("outline_size", 0)
	places.add_child(_place_name)
	_refresh_places()
	_pick.add_child(places)

	_words = UI.vbox(2)
	_words.name = "Words"
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pick.add_child(_words)
	_left.disabled = _projects.is_empty()
	_right.disabled = _projects.is_empty()
	_set_icon(_left, "bin", "Delete pet")
	_set_icon(_right, "check", "Complete project")
	if _projects.is_empty():
		_words.add_child(_shadowed(UI.label("No pets yet", 30, UI.ON_DARK, true, 600)))
		var p := _shadowed(UI.label("Tap the + to adopt one for something you're working on.", 15, UI.ON_DARK_SOFT, false, 700))
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_words.add_child(p)
		_pets = null
		_layout()
		return

	_title = _shadowed(UI.label("", 32, UI.ON_DARK, true, 600))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.add_child(_title)
	_pet_line = _shadowed(UI.label("", 22, UI.ON_DARK, true, 500))
	_words.add_child(_pet_line)
	_words.add_child(_shadowed(UI.label("Tap your pet to start walking", 13, UI.ON_DARK_SOFT, false, 700)))
	_under = _shadowed(UI.label("", 14, UI.ON_DARK, false, 800))
	_under.name = "Under"
	_pick.add_child(_under)

	_pets = Carousel.new()
	_pets.spacing = clampf(size.x * 0.44, 170.0, 300.0)
	_pick.add_child(_pets)
	var items: Array[Control] = []
	var start := 0
	for i in _projects.size():
		items.append(_pet(_projects[i].animal_id, _projects[i].colours, PET_HEIGHT))
		if _projects[i].id == select_id:
			start = i
	_pets.changed.connect(_on_pet_changed)
	_pets.activated.connect(_start_walk)
	_pets.set_items(items, start)
	# The pets stand at the back, under the growth and the words.
	_pick.move_child(_pets, 0)
	_attach_front()
	_on_pet_changed(start)
	_layout()
	_pets.grab_focus.call_deferred()


## Places along the top; the words in the sky; the pets with their feet on
## the scenery's path.
func _layout() -> void:
	if not is_instance_valid(_scenery):
		return
	var insets := UI.safe_insets(self)
	var places := _pick.get_node_or_null("Places") as Control
	if places:
		places.size = places.get_combined_minimum_size()
		places.position = Vector2((size.x - places.size.x) * 0.5, 72.0 + insets["top"])
	var path := _scenery.path_y()
	if is_instance_valid(_words):
		var w := minf(520.0, size.x - 40.0)
		_words.size = Vector2(w, 0)
		_words.size = Vector2(w, _words.get_combined_minimum_size().y)
		# Just under the place buttons.
		_words.position = Vector2((size.x - w) * 0.5, (places.position.y + places.size.y + 12.0) if places else 140.0)
	if is_instance_valid(_under):
		_under.size = Vector2(size.x, _under.get_combined_minimum_size().y)
		_under.position = Vector2(0, path + 16.0)
	_scenery.front_gap = Vector2(size.x * 0.5 - PET_HEIGHT * 0.8, size.x * 0.5 + PET_HEIGHT * 0.8)
	if is_instance_valid(_pets):
		var band := PET_HEIGHT * 1.15
		_pets.size = Vector2(size.x, band)
		_pets.position = Vector2(0, path - 0.36 * PET_HEIGHT - band * 0.5)


func _on_pet_changed(i: int) -> void:
	for j in _pets.items.size():
		(_pets.items[j].get_meta("view") as AnimalView).walking = j == i
	var p := _projects[i]
	_remembered = p.id
	_title.text = p.name
	_pet_line.text = Content.pet_called(p, true)
	_under.text = "%s · %s focused" % [Content.animal(p.animal_id).get("name", ""), Stats.format_duration(App.state.project_seconds(p.id))]
	Motion.pop(_title, 0.04, 0.25)
	_layout()


func _start_walk(i: int) -> void:
	var p := _projects[i]
	var from := _pets.items[i].get_global_rect().get_center()
	App.start_walk(p.id, -1, _place_id())
	App.go("walk", {"from": from})


func _on_left() -> void:
	var p := _projects[_pets.index]
	Modal.confirm("Delete %s?" % p.name,
		"%s will go for good. Time you've already spent stays in your stats." % Content.pet_called(p, true),
		"Delete", "danger").closed.connect(func(ok):
			if ok:
				var next := _neighbour_id(p.id)
				App.delete_project(p.id)
				Toast.show_text("%s deleted" % p.name, "bin")
				_build_pick(next))


func _on_right() -> void:
	var p := _projects[_pets.index]
	Modal.confirm("Complete %s?" % p.name,
		"It moves to Completed with everything %s found along the way. You can't undo this." % Content.pet_called(p),
		"Complete", "success").closed.connect(func(ok):
			if ok:
				var next := _neighbour_id(p.id)
				App.complete_project(p.id)
				Audio.play("project_complete")
				Toast.show_text("%s moved to Completed" % p.name)
				_build_pick(next))


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
	_draft = ProjectData.new()
	_build_adopt()
	_show_mode(true)


## Fades between choosing (scenery) and adopting (the form over a soft sheet).
func _show_mode(adopting: bool, select_id: String = "") -> void:
	_adopting = adopting
	var hide_layer := _pick if adopting else _adopt_layer
	var show_layer := _adopt_layer if adopting else _pick
	_new.set_tick(adopting)
	_new.accessibility_name = "Adopt" if adopting else "New pet"
	_close.accessibility_name = "Cancel" if adopting else "Back"
	if not adopting:
		_new.set_disabled_look(false)
		_build_pick(select_id)
	# The bin and the tick at the bottom are for the pets you have.
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in [_left, _right]:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE if adopting else Control.MOUSE_FILTER_STOP
	Motion.fade(_bottom, 0.0 if adopting else 1.0, Motion.FAST)
	_style_top(adopting)
	var t := Motion.tween(self, "mode")
	t.tween_property(hide_layer, "modulate:a", 0.0, Motion.time(Motion.FAST))
	t.tween_callback(func():
		hide_layer.visible = false
		show_layer.visible = true
		show_layer.modulate.a = 0.0)
	t.tween_property(show_layer, "modulate:a", 1.0, Motion.time(Motion.NORMAL))


func _build_adopt() -> void:
	for c in _adopt_layer.get_children():
		_adopt_layer.remove_child(c)
		c.queue_free()
	var sheet := ColorRect.new()
	sheet.color = Color(UI.BG, 0.93)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_adopt_layer.add_child(sheet)
	var insets := UI.safe_insets(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16 + int(insets["left"]))
	margin.add_theme_constant_override("margin_right", 16 + int(insets["right"]))
	margin.add_theme_constant_override("margin_top", 76 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 28 + int(insets["bottom"]))
	_adopt_layer.add_child(margin)
	var v := UI.vbox(8)
	margin.add_child(v)

	_name_edit = _field("What are you focusing on?", 40, 18)
	v.add_child(_name_edit)
	# Optional: a pet without a name goes by its kind ("your staffy").
	_pet_edit = _field("", 24, 16)
	_pet_edit.custom_minimum_size.y = 46
	v.add_child(_pet_edit)
	_name_edit.text_submitted.connect(func(_t): _pet_edit.grab_focus())
	_pet_edit.text_submitted.connect(func(_t): _pet_edit.release_focus())

	_animals = Carousel.new()
	_animals.vertical = true
	_animals.spacing = 150.0
	_animals.side_scale = 0.62
	_animals.reach = 1.7
	_animals.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Space the animals to the room there is, so the neighbours peek in above
	# and below on short windows too.
	_animals.resized.connect(func(): _animals.spacing = clampf(_animals.size.y * 0.36, 90.0, 150.0))
	v.add_child(_animals)
	_animal_title = UI.label("", 24, UI.INK, true, 600)
	_animal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_animal_title)
	_animal_hint = UI.label("", 13, UI.INK_FAINT, false, 700)
	_animal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_animal_hint)

	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_swatches.clear()
	for k in COLOUR_ROLES.size():
		var cell := UI.vbox(4)
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.accessibility_name = "%s colour" % COLOUR_ROLES[k]
		b.pressed.connect(_pick_colour.bind(k))
		cell.add_child(b)
		var l := UI.caption(COLOUR_ROLES[k])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		row.add_child(cell)
		_swatches.append(b)
	v.add_child(row)
	_swatch_row = row

	var items: Array[Control] = []
	var first_open := -1
	for i in Content.animals.size():
		var a: Dictionary = Content.animals[i]
		var level := Levels.unlock_level("animal", a["id"], Content.levels)
		var open := App.is_unlocked("animal", a["id"])
		items.append(_pet(a["id"], Content.animal_default_colours(a["id"]), 150.0, 0 if open else level))
		if open and first_open < 0:
			first_open = i
	_animals.changed.connect(_on_animal_changed)
	_animals.set_items(items, maxi(first_open, 0))
	_on_animal_changed(_animals.index)


func _on_animal_changed(i: int) -> void:
	var a: Dictionary = Content.animals[i]
	var open := App.is_unlocked("animal", a["id"])
	if open:
		_draft.animal_id = a["id"]
		_draft.colours = Content.animal_default_colours(a["id"])
	for j in _animals.items.size():
		var view: AnimalView = _animals.items[j].get_meta("view")
		var locked: bool = _animals.items[j].get_meta("locked", false)
		view.walking = j == i and not locked
		if j == i and open:
			view.colours = _draft.colours
		elif not locked:
			view.colours = Content.animal_default_colours(Content.animals[j]["id"])
	_animal_title.text = a["name"]
	if open:
		_animal_hint.text = "Scroll for more animals"
		_animal_hint.add_theme_color_override("font_color", UI.INK_FAINT)
		_pet_edit.placeholder_text = "Name your %s" % str(a["name"]).to_lower()
	else:
		_animal_hint.text = "Unlocks at level %d" % Levels.unlock_level("animal", a["id"], Content.levels)
		_animal_hint.add_theme_color_override("font_color", UI.INK_SOFT)
	_new.set_disabled_look(not open)
	# A locked animal can't be coloured in: the colour buttons fade away, but
	# keep their space so the scroller above doesn't jump.
	for b in _swatches:
		b.disabled = not open
		b.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	Motion.fade(_swatch_row, 1.0 if open else 0.0, Motion.FAST)
	_refresh_swatches()


func _refresh_swatches() -> void:
	var parts: Array = Content.animal(_draft.animal_id).get("parts", [])
	for k in _swatches.size():
		var b := _swatches[k]
		b.visible = k < parts.size()
		var c := _draft.colours[k] if k < _draft.colours.size() else Color.WHITE
		UI.style_button(b, c, UI.INK, 999, true)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
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
	var project_name := _name_edit.text.strip_edges()
	if project_name == "":
		_name_edit.placeholder_text = "Give it a name first"
		Motion.shake(_name_edit)
		_name_edit.grab_focus()
		return
	_draft.name = project_name
	_draft.pet_name = _pet_edit.text.strip_edges()
	App.add_project(_draft)
	Audio.play(str(Content.animal(_draft.animal_id).get("sound", "")), 1.0, -6.0)
	Toast.show_text("Say hello to %s" % Content.pet_called(_draft), "paw")
	_show_mode(false, _draft.id)


# --- Pieces ------------------------------------------------------------------

## The × reads white over scenery and ink over the adopt form, with a faint
## disc under the pointer. The + is white over scenery and green on the form.
func _style_top(on_form: bool) -> void:
	var ink := UI.INK if on_form else UI.ON_DARK
	UI.style_button(_close, Color.TRANSPARENT, ink, 999)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = _close.get_theme_stylebox(state)
		sb.set_content_margin_all(0)
		match state:
			"hover":
				sb.bg_color = Color(ink, 0.12)
			"pressed", "hover_pressed":
				sb.bg_color = Color(ink, 0.2)
	_close.icon = Icons.texture("close", 24, Color.WHITE, 3.0)
	_new.fill_colour = UI.SUCCESS if on_form else Color.WHITE


## Light text with a soft shadow, centred, so it reads over any scenery.
func _shadowed(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.32))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A centred text box for the adopt form.
func _field(placeholder: String, max_length: int, font_size: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.max_length = max_length
	e.custom_minimum_size = Vector2(minf(420.0, size.x - 48.0), 52)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.add_theme_font_size_override("font_size", font_size)
	return e


func _set_icon(b: Button, icon: String, tip: String) -> void:
	b.icon = Icons.texture(icon, int(b.custom_minimum_size.x * 0.42), Color.WHITE, 2.6)
	b.accessibility_name = tip


## An animal standing on a soft shadow, for the carousels. `locked_at` > 0
## greys it out with a padlock and the level it unlocks at.
func _pet(animal_id: String, colours: Array[Color], height: float, locked_at: int = 0) -> Control:
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
	if locked_at > 0:
		stage.set_meta("locked", true)
		var greys: Array[Color] = []
		for k in colours.size():
			greys.append(UI.NEUTRAL.lerp(UI.INK_FAINT, k * 0.3))
		view.colours = greys
		view.modulate.a = 0.75
		var badge := UI.panel(UI.SURFACE_SOFT, 999, 6)
		var row := UI.hbox(4)
		row.add_child(UI.icon_rect("lock", 14, UI.INK_SOFT))
		row.add_child(UI.label("Lv %d" % locked_at, 13, UI.INK_SOFT, false, 900))
		badge.add_child(row)
		stage.add_child(badge)
		badge.position = Vector2(stage.custom_minimum_size.x * 0.5 - 34.0, height * 0.12)
	return stage


class _Stage extends Control:
	func _draw() -> void:
		draw_set_transform(Vector2(size.x * 0.48, size.y * 0.87), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, size.x * 0.34, Color(0.0, 0.0, 0.0, 0.16), true, -1.0, true)


## A soft darkening at the top of the scenery so the place buttons and the
## pet's name stay readable in bright daylight.
class _Shade extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var dark := Color(0, 0, 0, 0.28)
		var clear := Color(0, 0, 0, 0)
		var h := size.y * 0.5
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, h), Vector2(0, h)]),
			PackedColorArray([dark, dark, clear, clear]))
