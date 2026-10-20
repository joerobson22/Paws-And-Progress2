extends Pane
## Your profile, above the focus screen: your character head to toe (tap it
## to change how they look), your account details, a few lifetime numbers,
## and the app's settings.


func build() -> void:
	var col := page(720)
	col.add_child(UI.title_row("Profile"))
	var p := App.state.profile

	var me := UI.card(UI.SURFACE, 20)
	var body: BoxContainer = UI.hbox(24) if wide else UI.vbox(16)
	me.add_child(body)
	col.add_child(me)

	var figure := UI.character_portrait({}, Vector2(220 if wide else 0, 300))
	figure.mouse_filter = Control.MOUSE_FILTER_STOP
	figure.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	figure.tooltip_text = "Customise your character"
	var press := Press.new(figure)
	figure.gui_input.connect(press.handle)
	press.tapped.connect(Customise.open)
	# A pencil in the corner says the figure can be tapped.
	var pencil := UI.panel(UI.SURFACE, 999, 8)
	pencil.add_child(UI.icon_rect("edit", 18, UI.INK))
	pencil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.add_child(pencil)
	figure.resized.connect(func():
		pencil.size = pencil.get_combined_minimum_size()
		pencil.position = Vector2(figure.size.x - pencil.size.x - 10, 10))
	body.add_child(figure)

	var info := UI.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	var name := str(p.get("username", ""))
	info.add_child(_field("Username", name if name != "" else "Add your name", name == "",
		_edit.bind("username", "Your name", "What should we call you?", 24)))
	info.add_child(UI.divider())
	var school := str(p.get("institution", ""))
	info.add_child(_field("School, college or university", school if school != "" else "Add where you study", school == "",
		_edit.bind("institution", "Where do you study?", "e.g. University of Leeds", 60)))
	info.add_child(UI.divider())
	var joined := int(p.get("created_unix", 0))
	info.add_child(_field("Joined", Stats.format_date(joined, App.tz_bias()) if joined > 0 else "Today", false, Callable()))
	body.add_child(info)

	var numbers := GridContainer.new()
	numbers.columns = 3
	numbers.add_theme_constant_override("h_separation", 12)
	var all_time := Stats.total_seconds(App.state.sessions) + int(p.get("legacy_total_seconds", 0))
	var gifts := 0
	for n in App.state.inventory.values():
		gifts += int(n)
	numbers.add_child(_number("Focused", Stats.format_duration(all_time)))
	numbers.add_child(_number("Gifts", str(gifts)))
	numbers.add_child(_number("Completed", str(App.state.completed_projects().size())))
	col.add_child(numbers)

	col.add_child(UI.caption("Settings"))
	var settings := UI.card(UI.SURFACE, 20)
	var s := UI.vbox(10)
	settings.add_child(s)
	s.add_child(_toggle("Sound effects", "Taps, pops, barks and the bong.", "sound"))
	s.add_child(UI.divider())
	s.add_child(_toggle("Ambience", "Water and birdsong while you walk.", "ambience"))
	s.add_child(UI.divider())
	s.add_child(_toggle("Reduce motion", "Gentler scenery and quicker, simpler animations.", "reduce_motion"))
	s.add_child(UI.divider())
	s.add_child(_toggle("Keep the screen on", "Stops your phone or laptop sleeping during a walk.", "keep_screen_on"))
	col.add_child(settings)

	var about := UI.para("Paws & Progress %s  ·  Fonts: Fredoka and Nunito (SIL Open Font License)" % ProjectSettings.get_setting("application/config/version", ""), 13, UI.INK_FAINT)
	about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(about)


## A labelled detail; tappable to edit when `on_tap` is given.
func _field(title: String, value: String, placeholder: bool, on_tap: Callable) -> Control:
	var row := UI.hbox(10)
	row.custom_minimum_size.y = 58
	var text := UI.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_child(UI.caption(title))
	text.add_child(UI.trimmed(value, 18, UI.INK_FAINT if placeholder else UI.INK, false, 800))
	row.add_child(text)
	if on_tap.is_valid():
		var b := UI.round_button("edit", "Edit %s" % title.to_lower(), on_tap, UI.SURFACE_SOFT, UI.INK, 38, false)
		row.add_child(b)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var press := Press.new(row)
		row.gui_input.connect(press.handle)
		press.tapped.connect(on_tap)
	return row


func _edit(key: String, title: String, placeholder: String, max_length: int) -> void:
	Modal.prompt(title, str(App.state.profile.get(key, "")), placeholder, max_length).closed.connect(func(text):
		if text is String:
			App.set_profile(key, text))


func _number(title: String, value: String) -> Control:
	var card := UI.card(UI.SURFACE, 14, 20)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(0)
	v.add_child(UI.caption(title))
	v.add_child(UI.trimmed(value, 22, UI.INK, true, 600))
	card.add_child(v)
	return card


func _toggle(title: String, detail: String, key: String) -> Control:
	var row := UI.hbox(16)
	var text := UI.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UI.label(title, 16, UI.INK, false, 800))
	text.add_child(UI.para(detail, 13))
	row.add_child(text)
	var sw := Switch.new(bool(App.state.settings.get(key, false)))
	sw.tooltip_text = title
	sw.toggled.connect(func(on: bool):
		App.set_setting(key, on)
		if key == "ambience":
			Audio.refresh(Audio.current_ambience()))
	row.add_child(sw)
	return row
