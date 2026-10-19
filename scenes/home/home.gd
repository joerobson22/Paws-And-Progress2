extends Control
## The cabin: home hub with a greeting, shortcuts round the room, this week's
## total and the "up next" walk. Wide screens get a side column; phones stack.

var params := {}


func _ready() -> void:
	var wide := UI.is_wide(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28 if wide else 16)
	margin.add_theme_constant_override("margin_top", 8 if wide else 16)
	add_child(margin)

	if wide:
		var row := UI.hbox(24)
		margin.add_child(row)
		var cabin := _cabin()
		cabin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cabin)
		var aside := UI.vbox(16)
		aside.custom_minimum_size.x = 340
		aside.add_child(_week_card())
		aside.add_child(_up_next_card())
		row.add_child(aside)
	else:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		margin.add_child(scroll)
		var col := UI.vbox(12)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(col)
		var cabin := _cabin()
		cabin.custom_minimum_size.y = 300
		col.add_child(cabin)
		col.add_child(_up_next_card())
		col.add_child(_week_card())


func _greeting() -> String:
	var hour := int(Time.get_datetime_dict_from_system()["hour"])
	var part := "Good evening"
	if hour >= 5 and hour < 12:
		part = "Good morning"
	elif hour >= 12 and hour < 17:
		part = "Good afternoon"
	var name := str(App.state.profile.get("username", ""))
	return part + (", %s" % name if name != "" else "")


## Placeholder for the illustrated cabin: a warm panel with the room's
## hotspots as chips. Joe's cabin art drops in behind these later.
func _cabin() -> Control:
	var panel := PanelContainer.new()
	var b := UI.box(Color("#3a2a1e"), Color.TRANSPARENT, 28)
	b.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", b)
	var col := UI.vbox(10)
	panel.add_child(col)
	col.add_child(UI.label(_greeting(), 28, Color("#fff7ea"), true, 600))
	var next := _up_next_project()
	var sub := "The fire's lit."
	if next:
		sub = "The fire's lit and the %s is waiting by the door." % Content.animal(next.animal_id).get("name", "dog").to_lower()
	col.add_child(UI.para(sub, 15, Color("#f1e3cc"), 600))
	if App.imported_from_v1:
		col.add_child(UI.para("Welcome back! Your projects, gifts and totals came across from the original app.", 15, UI.APRICOT, 700))

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(filler)

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 10)
	col.add_child(chips)
	var gifts := 0
	for n in App.state.inventory.values():
		gifts += int(n)
	chips.add_child(_chip("Noticeboard  %d" % App.state.completed_projects().size(), "board"))
	chips.add_child(_chip("Gift shelf  %d" % gifts, "shelf"))
	chips.add_child(_chip("Wardrobe", "wardrobe"))
	chips.add_child(_chip("Armchair · stats", "stats"))
	var door := UI.cta("Door · go for a walk", App.go.bind("walks", {}))
	chips.add_child(door)
	return panel


func _chip(text: String, screen: String) -> Button:
	var b := UI.button(text, App.go.bind(screen, {}), Color(UI.PAPER, 0.94), UI.INK)
	b.custom_minimum_size.y = 44
	return b


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
	col.add_child(UI.cta("Start walking", _start.bind(p.id)))
	col.add_child(UI.button("Switch project", App.go.bind("walks", {}), UI.FOREST, Color("#dcebdd")))
	return card


func _start(project_id: String) -> void:
	App.start_walk(project_id)
	App.go("walk")
