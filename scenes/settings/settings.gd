extends Control
## Settings: your name, sound, walk preferences and credits.

var params := {}

var _name_edit: LineEdit


func _ready() -> void:
	Audio.ambience("cabin")
	var col := UI.page(self, 720)
	col.add_child(UI.header("Settings", App.go.bind("home", {})))

	var you := _section(col, "You")
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "What should the cabin call you?"
	_name_edit.text = str(App.state.profile.get("username", ""))
	_name_edit.custom_minimum_size.y = 48
	_name_edit.max_length = 24
	_name_edit.text_changed.connect(_set_name)
	you.add_child(_row("Your name", "Used for the greeting in the cabin.", _name_edit))

	var sound := _section(col, "Sound")
	sound.add_child(_toggle("Sound effects", "Clicks, barks and the end-of-walk chime.", "sound"))
	sound.add_child(_divider())
	sound.add_child(_toggle("Ambience", "The fire in the cabin, and water and birdsong on walks.", "ambience"))

	var walks := _section(col, "Walks")
	walks.add_child(_toggle("Reduce motion", "Scenery scrolls gently instead of at walking pace.", "reduce_motion"))
	walks.add_child(_divider())
	walks.add_child(_toggle("Keep the screen on", "Stops your phone or laptop sleeping during a walk.", "keep_screen_on"))

	var about := _section(col, "About")
	about.add_child(UI.para("Paws & Progress %s" % ProjectSettings.get_setting("application/config/version", ""), 16, UI.INK, 800))
	about.add_child(UI.para("Fonts: Fredoka, Nunito and Gochi Hand, all under the SIL Open Font License.", 14))


func _section(parent: Control, title: String) -> VBoxContainer:
	parent.add_child(UI.caption(title))
	var card := UI.card()
	var v := UI.vbox(10)
	card.add_child(v)
	parent.add_child(card)
	return v


func _row(title: String, detail: String, control: Control) -> Control:
	var wide := UI.is_wide(self)
	var row: BoxContainer = UI.hbox(16) if wide else UI.vbox(8)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, 17, UI.INK, false, 800))
	text.add_child(UI.para(detail, 14))
	row.add_child(text)
	if wide:
		control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 260)
		control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


func _toggle(title: String, detail: String, key: String) -> Control:
	var row := UI.hbox(16)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, 17, UI.INK, false, 800))
	text.add_child(UI.para(detail, 14))
	row.add_child(text)
	var sw := Switch.new(bool(App.state.settings.get(key, false)))
	sw.tooltip_text = title
	sw.toggled.connect(_set_toggle.bind(key))
	row.add_child(sw)
	return row


func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color("#efe4cf")
	line.custom_minimum_size.y = 1
	return line


func _set_toggle(on: bool, key: String) -> void:
	App.set_setting(key, on)
	if key == "ambience":
		Audio.refresh("cabin")


func _set_name(text: String) -> void:
	App.state.profile["username"] = text.strip_edges()
	App.save()
