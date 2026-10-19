extends Control
## End of a walk: time walked and the gift, if one was earned.
## params: {"session": FocusSession, "gift": Dictionary} from App.finish_walk().

var params := {}


func _ready() -> void:
	var session: FocusSession = params.get("session")
	if session == null:
		App.go.call_deferred("home", {})
		return
	var project := App.state.project(session.project_id)
	var roll: Dictionary = params.get("gift", {})

	var col := UI.page(self, 620)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	col.add_child(spacer)

	var title := UI.label("Walk complete", 40, UI.INK, true, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var project_name := project.name if project else "your project"
	var summary := UI.para("%s spent on %s" % [Stats.format_duration(session.focus_seconds), project_name], 18, UI.INK_SOFT)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(summary)

	var card := UI.card()
	var c := UI.vbox(12)
	card.add_child(c)
	col.add_child(card)
	if project:
		c.add_child(UI.animal_portrait(project.animal_id, project.colours, Vector2(0, 170), Color("#e5efe2")))

	if roll.is_empty():
		var min_minutes := int(Content.drop_table.get("min_seconds", 600)) / 60
		var none := UI.para("Walk for at least %d minutes to get a gift." % min_minutes, 18, UI.INK_SOFT)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(none)
		if session.focus_seconds < 60:
			var short := UI.para("Walks under a minute aren't added to your stats.", 14, UI.INK_SOFT)
			short.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(short)
	else:
		var gift := Content.gift(roll["gift_id"])
		var rarity: String = roll["rarity"]
		var animal_name: String = Content.animal(gift.get("animal", "")).get("name", "")
		var from := UI.para("The %s found you something" % animal_name.to_lower(), 16, UI.INK_SOFT, 700)
		from.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(from)
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UI.box(Content.rarity_colour(rarity), Color.TRANSPARENT, 999))
		badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		badge.add_child(UI.label(Content.rarity_name(rarity).to_upper(), 13, UI.PAPER, false, 800))
		c.add_child(badge)
		var name := UI.label(gift.get("name", "?"), 32, UI.INK, true, 600)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(name)
		var desc := UI.para(gift.get("description", ""), 16, UI.INK_SOFT)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(desc)
		if gift.has("slot"):
			var wear := UI.para("You can wear this in the wardrobe.", 14, UI.FOREST, 800)
			wear.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(wear)

	var actions := UI.hbox(10)
	var home := UI.cta("Back to the cabin", App.go.bind("home", {}))
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(home)
	if project and not project.is_complete():
		actions.add_child(UI.button("Project finished", _complete.bind(project.id)))
	col.add_child(actions)


func _complete(id: String) -> void:
	App.complete_project(id)
	App.go("board")
