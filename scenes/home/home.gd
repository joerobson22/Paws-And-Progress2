extends Control
## The cabin: home hub with a greeting, shortcuts round the room, this week's
## total and the "up next" walk. Wide screens get a side column; phones stack.

var params := {}


func _ready() -> void:
	Audio.ambience("cabin")
	var wide := UI.is_wide(self)
	if wide:
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for side in ["left", "right", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 32)
		margin.add_theme_constant_override("margin_top", 8)
		add_child(margin)
		var row := UI.hbox(24)
		margin.add_child(row)
		var cabin := _cabin(true)
		cabin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cabin)
		var aside := UI.vbox(16)
		aside.custom_minimum_size.x = 340
		aside.add_child(_week_card())
		aside.add_child(_up_next_card())
		row.add_child(aside)
	else:
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		var col := UI.vbox(12)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(col)
		var cabin := _cabin(false)
		cabin.custom_minimum_size.y = 340
		col.add_child(cabin)
		var cards := MarginContainer.new()
		for side in ["left", "right"]:
			cards.add_theme_constant_override("margin_" + side, 16)
		cards.add_theme_constant_override("margin_top", 6)
		cards.add_theme_constant_override("margin_bottom", 16)
		var stack := UI.vbox(12)
		cards.add_child(stack)
		stack.add_child(_up_next_card())
		stack.add_child(_week_card())
		col.add_child(cards)


func _greeting() -> String:
	var hour := int(Time.get_datetime_dict_from_system()["hour"])
	var part := "Good evening"
	if hour >= 5 and hour < 12:
		part = "Good morning"
	elif hour >= 12 and hour < 17:
		part = "Good afternoon"
	var name := str(App.state.profile.get("username", ""))
	return part + (", %s" % name if name != "" else "")


## The cabin picture with the greeting, room controls and a pill on each
## piece of furniture that leads somewhere.
func _cabin(wide: bool) -> Control:
	var cabin := CabinView.new(28, not wide)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right"]:
		top.add_theme_constant_override("margin_" + side, 24 if wide else 20)
	top.add_theme_constant_override("margin_top", 22 if wide else 28)
	cabin.add_child(top)
	var row := UI.hbox(12)
	top.add_child(row)
	var words := UI.vbox(2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(UI.label(_greeting(), 28 if wide else 26, Color("#fff7ea"), true, 600))
	var next := _up_next_project()
	var sub := "The fire's lit."
	if next:
		sub = "The fire's lit and the %s is waiting by the door." % Content.animal(next.animal_id).get("name", "dog").to_lower()
	if not wide:
		var streak := Stats.current_streak(App.state.sessions, App.today(), App.tz_bias())
		sub = "%d day streak" % streak if streak > 0 else sub
	words.add_child(UI.para(sub, 15, Color("#f1e3cc"), 700))
	if App.imported_from_v1:
		words.add_child(UI.para("Welcome back! Your projects, gifts and totals came across from the original app.", 15, UI.APRICOT, 800))
	row.add_child(words)

	var sound_on: bool = App.state.settings.get("sound", true) or App.state.settings.get("ambience", true)
	row.add_child(_glass_button("sound" if sound_on else "mute", "Sound on or off", _toggle_sound, Color("#fff7ea")))
	if not wide:
		row.add_child(_glass_button("gear", "Settings", App.go.bind("settings", {}), Color("#fff7ea")))

	var gifts := 0
	for n in App.state.inventory.values():
		gifts += int(n)
	var done := App.state.completed_projects().size()
	if wide:
		cabin.add_hotspot(_hotspot("Noticeboard", str(done), "board", UI.FOREST, "board"), Vector2(0.20, 0.30))
		cabin.add_hotspot(_hotspot("Gift shelf", str(gifts), "gift", Color("#b5651d"), "shelf"), Vector2(0.21, 0.60))
		cabin.add_hotspot(_hotspot("Wardrobe", "", "shirt", Color("#6a4c93"), "wardrobe"), Vector2(0.59, 0.44))
		cabin.add_hotspot(_hotspot("Armchair · stats", "", "stats", Color("#2d6f8f"), "stats"), Vector2(0.57, 0.70))
		cabin.add_hotspot(_door("Door · go for a walk"), Vector2(0.80, 0.30))
	else:
		cabin.add_hotspot(_hotspot("Board", str(done), "", Color.TRANSPARENT, "board"), Vector2(0.20, 0.42))
		cabin.add_hotspot(_hotspot("Shelf", str(gifts), "", Color.TRANSPARENT, "shelf"), Vector2(0.22, 0.66))
		cabin.add_hotspot(_hotspot("Wardrobe", "", "", Color.TRANSPARENT, "wardrobe"), Vector2(0.59, 0.50))
		cabin.add_hotspot(_door("Walks"), Vector2(0.80, 0.42))
	return cabin


## Round pill on the cabin art: coloured icon disc, name and an optional count.
func _hotspot(text: String, count: String, icon: String, disc: Color, screen: String) -> Button:
	var b := UI.button(text + ("  " + count if count != "" else ""), App.go.bind(screen, {}), Color(UI.PAPER, 0.95), UI.INK)
	b.add_theme_font_size_override("font_size", 14 if icon != "" else 13)
	if icon != "":
		b.icon = _disc_icon(icon, disc, UI.PAPER)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		sb.set_corner_radius_all(999)
		sb.content_margin_left = 8 if icon != "" else 12
		sb.content_margin_right = 14 if icon != "" else 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.shadow_color = Color(0.08, 0.04, 0.02, 0.35)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 4)
		b.add_theme_stylebox_override(state, sb)
	b.custom_minimum_size = Vector2(0, 44 if icon != "" else 34)
	b.size = b.get_combined_minimum_size()
	return b


func _door(text: String) -> Button:
	var b := _hotspot(text, "", "play", UI.ON_APRICOT, "walks")
	b.icon = _disc_icon("play", UI.ON_APRICOT, UI.APRICOT)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		sb.bg_color = UI.APRICOT if state == "normal" else UI.APRICOT.darkened(0.08)
		sb.border_color = Color(UI.APRICOT, 0.4)
		sb.set_border_width_all(5)
		sb.expand_margin_left = 5
		sb.expand_margin_right = 5
		sb.expand_margin_top = 5
		sb.expand_margin_bottom = 5
		b.add_theme_stylebox_override(state, sb)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, UI.ON_APRICOT)
	return b


## An icon sitting in a filled circle, baked into one texture for a button.
func _disc_icon(icon: String, disc: Color, colour: Color) -> Texture2D:
	var px := 28
	var scale := 2
	var img := Image.create(px * scale, px * scale, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) * scale * 0.5
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(c.x - d, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(disc, a))
	var glyph := Icons.texture(icon, 15, colour).get_image()
	glyph.resize(15 * scale, 15 * scale)
	var off := Vector2i((px * scale - glyph.get_width()) / 2, (px * scale - glyph.get_height()) / 2)
	img.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), off)
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(px, px))
	return tex


## Square see-through button over the cabin art.
func _glass_button(icon: String, tip: String, on_press: Callable, colour: Color) -> Button:
	var b := UI.icon_button(icon, tip, on_press, Color(0.12, 0.08, 0.05, 0.45), colour)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		sb.set_border_width_all(1)
		sb.border_color = Color(1, 1, 1, 0.25)
		b.add_theme_stylebox_override(state, sb)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return b


func _toggle_sound() -> void:
	var on: bool = not (App.state.settings.get("sound", true) or App.state.settings.get("ambience", true))
	App.state.settings["sound"] = on
	App.set_setting("ambience", on)
	Audio.refresh("cabin")
	App.go("home")


func _week_card() -> Control:
	var s := App.state
	var bias := App.tz_bias()
	var week := Stats.week_total(s.sessions, Stats.week_start(App.today()), bias)
	var best := maxi(Stats.best_week_total(s.sessions, bias), int(s.profile["legacy_best_week_seconds"]))

	var card := UI.card()
	var col := UI.vbox(8)
	card.add_child(col)
	var top := UI.hbox()
	top.add_child(UI.caption("This week"))
	top.add_child(UI.spacer())
	var details := UI.button("Details", App.go.bind("stats", {}), UI.PAPER, UI.FOREST)
	details.custom_minimum_size.y = 0
	top.add_child(details)
	col.add_child(top)
	col.add_child(UI.label(Stats.format_duration(week), 40, UI.INK, true, 600))
	col.add_child(UI.progress(float(week) / best if best > 0 else 0.0))
	var foot := UI.hbox()
	var pct := roundi(100.0 * week / best) if best > 0 else 0
	foot.add_child(UI.label("%d%% of your record" % pct, 13, UI.INK_SOFT))
	foot.add_child(UI.spacer())
	foot.add_child(UI.label("Best: %s" % Stats.format_duration(best), 13, UI.INK_SOFT))
	col.add_child(foot)
	return card


## The project most recently walked, else the newest active one.
func _up_next_project() -> ProjectData:
	var active := App.state.active_projects()
	if active.is_empty():
		return null
	for i in range(App.state.sessions.size() - 1, -1, -1):
		var p := App.state.project(App.state.sessions[i].project_id)
		if p and not p.is_complete():
			return p
	return active[active.size() - 1]


func _up_next_card() -> Control:
	var card := UI.card(UI.FOREST)
	var col := UI.vbox(14)
	card.add_child(col)
	col.add_child(UI.caption("Up next", UI.ON_FOREST_SOFT))
	var p := _up_next_project()
	if p == null:
		col.add_child(UI.para("Give your first project an animal to walk with.", 18, UI.ON_FOREST, 700))
		col.add_child(UI.cta("New project", App.go.bind("project_editor", {})))
		return card

	var row := UI.hbox(14)
	row.add_child(UI.animal_portrait(p.animal_id, p.colours, Vector2(84, 64)))
	var info := UI.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.label(p.name, 20, UI.ON_FOREST, true, 600))
	var animal_name: String = Content.animal(p.animal_id).get("name", "")
	info.add_child(UI.para("with the %s · %s so far" % [animal_name.to_lower(), Stats.format_duration(App.state.project_seconds(p.id))], 14, Color("#cfe0d2"), 600))
	row.add_child(info)
	col.add_child(row)
	col.add_child(UI.with_icon(UI.cta("Walk with the %s" % animal_name.to_lower(), _start.bind(p.id)), "play", UI.ON_APRICOT, 14))
	col.add_child(UI.button("Switch project", App.go.bind("walks", {}), UI.FOREST, Color("#dcebdd")))
	return card


func _start(project_id: String) -> void:
	App.start_walk(project_id)
	App.go("walk")
