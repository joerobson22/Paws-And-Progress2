extends Pane
## Completed projects, to the right of the focus screen. Four headline
## numbers up top (how many you've finished, the focus time they took, the
## biggest by focus time and the longest from start to finish), then every
## finished project in a list of its own that scrolls, in the order picked
## from "Sort by". Tap the circled "?" in a project's top right to give it a
## grade (GCSE, A-Level or university); its badge then shows there instead,
## and tapping that changes it.

const SORTS := [
	["gifts", "Most gifts"], ["biggest", "Biggest"], ["longest", "Longest"],
	["grade", "Grade"], ["pet", "Pet type"], ["name", "A–Z"],
]
const SORT_KEY := "completed_sort"
## The least height the list gets: about one project panel.
const LIST_MIN := 170.0

## Which grading scale the picker opens on; remembered while the app runs.
var _scale := ""
var _list: VBoxContainer


func build() -> void:
	var col := frame(720)
	var done := App.state.completed_projects()
	col.add_child(title_row("Completed"))
	if done.is_empty():
		var empty := UI.card(UI.SURFACE, 24)
		var v := UI.vbox(6)
		v.add_child(UI.label("Nothing finished yet", 20, UI.INK, true, 600))
		v.add_child(UI.para("When a project's done, tap the green tick on the choose focus screen and it moves here, with everything your pet found along the way."))
		empty.add_child(v)
		col.add_child(empty)
		return
	var stats := _stats(done, col.custom_minimum_size.x)
	col.add_child(stats)

	var head := UI.hbox(8)
	var cap := UI.caption("Your projects")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	head.add_child(UI.spacer())
	var sort := Dropdown.for_setting(SORTS, SORT_KEY, SORTS[0][0], true)
	sort.chosen.connect(func(_by, _reversed):
		_fill_list()
		scroll.scroll_vertical = 0)
	head.add_child(sort)
	col.add_child(head)

	_list = UI.vbox(14)
	var inner := UI.vbox(14)
	inner.add_child(_list)
	var holder := UI.shadow_scroll(inner)
	# Pane keeps this list's place when the screen rebuilds (e.g. on grading).
	scroll = holder.get_child(0)
	col.add_child(holder)
	_fill_list()
	_make_room(holder, stats, inner)


## On a screen too short for the stats and a whole project under them, the
## stats go to the top of the list and scroll away with it, so there's
## always room for the list itself.
func _make_room(holder: Control, stats: Control, inner: VBoxContainer) -> void:
	await get_tree().process_frame
	if not is_instance_valid(holder) or holder.size.y >= LIST_MIN:
		return
	stats.get_parent().remove_child(stats)
	inner.add_child(stats)
	inner.move_child(stats, 0)


## The four headline numbers. Side by side on a wide screen, two by two on
## a phone so the times have room.
func _stats(done: Array[ProjectData], width: float) -> Control:
	var panel := StatPanel.new(4 if width >= 520.0 else 2)
	var total := 0
	var graded := 0
	var biggest: ProjectData = null
	var biggest_s := -1
	var longest: ProjectData = null
	var longest_s := -1
	for p in done:
		var s := App.state.project_seconds(p.id)
		total += s
		if p.grade != "":
			graded += 1
		if s > biggest_s:
			biggest = p
			biggest_s = s
		if _span(p) > longest_s:
			longest = p
			longest_s = _span(p)
	panel.add(StatPanel.badge("check", Content.rarity_colour("common")), "Finished",
		"%d graded" % graded, str(done.size()))
	panel.add(StatPanel.badge("clock", Content.rarity_colour("rare")), "Focus time",
		"across all of them", Stats.format_duration(total))
	panel.add(StatPanel.badge("trophy", Content.rarity_colour("epic")), "Biggest",
		biggest.name, Stats.format_duration(biggest_s))
	panel.add(StatPanel.badge("calendar", Content.rarity_colour("legendary")), "Longest",
		longest.name, span_text(longest_s))
	return panel


## Seconds from a project's start to its finish.
static func _span(p: ProjectData) -> int:
	return maxi(0, p.completed_unix - p.created_unix)


## "12 days" from a day on; under that, hours and minutes.
static func span_text(seconds: int) -> String:
	if seconds < 86400:
		return Stats.format_duration(seconds)
	var days := roundi(seconds / 86400.0)
	return "%d day%s" % [days, "" if days == 1 else "s"]


## Refills the list in the saved order, without rebuilding the rest.
func _fill_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var by := str(App.state.settings.get(SORT_KEY, SORTS[0][0]))
	var reversed := bool(App.state.settings.get(SORT_KEY + "_reversed", false))
	for p in sort_projects(App.state.completed_projects(), by, reversed):
		var panel := ProjectPanel.new(p, "", true)
		panel.grade_pressed.connect(_pick_grade)
		_list.add_child(panel)


## Most gifts, biggest (focus time) and longest (start to finish) put the
## most first; grade puts the best first (Content.grade_rank) with ungraded
## last; pet type follows the cast; A–Z is by name. Ties go newest first.
## `reversed` flips the whole order.
static func sort_projects(projects: Array, by: String, reversed: bool) -> Array:
	var order := {}
	for i in Content.animals.size():
		order[Content.animals[i]["id"]] = i
	var key := func(p: ProjectData) -> Array:
		var first: Array
		match by:
			"gifts":
				var n := 0
				for count in App.state.project_gifts(p.id).values():
					n += int(count)
				first = [-n]
			"biggest":
				first = [-App.state.project_seconds(p.id)]
			"longest":
				first = [-_span(p)]
			"grade":
				first = Content.grade_rank(p.grade)
			"pet":
				first = [order.get(p.animal_id, 99)]
			_:
				first = [p.name.to_lower()]
		return first + [-p.completed_unix, p.name.to_lower()]
	var keys := {}
	for p in projects:
		keys[p] = key.call(p)
	var out := projects.duplicate()
	out.sort_custom(func(a, b): return keys[a] < keys[b])
	if reversed:
		out.reverse()
	return out


func _pick_grade(project_id: String) -> void:
	var p := App.state.project(project_id)
	if p == null:
		return
	var current := Content.grade(p.grade)
	if _scale == "":
		_scale = current.get("scale", Content.grade_scales[0]["id"])
	var m := Modal.open(440)
	m.body.add_child(m.heading_row("Grade for %s" % p.name))
	var tabs := UI.hbox(6)
	var grid := HFlowContainer.new()
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var fill := func(scale_id: String):
		_scale = scale_id
		for c in tabs.get_children() + grid.get_children():
			c.get_parent().remove_child(c)
			c.queue_free()
		for s in Content.grade_scales:
			var tab := UI.pill_button(s["name"], s["id"] == scale_id, Callable())
			tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab.set_meta("scale", s["id"])
			tabs.add_child(tab)
		for s in Content.grade_scales:
			if s["id"] != scale_id:
				continue
			for g in s["grades"]:
				grid.add_child(_grade_choice("%s/%s" % [s["id"], g["id"]], p, m))
	m.body.add_child(tabs)
	m.body.add_child(grid)
	# The tabs are remade on each switch, so they're wired up as they arrive.
	tabs.child_entered_tree.connect(func(tab: Node):
		if tab is Button:
			tab.pressed.connect(func(): fill.call(tab.get_meta("scale"))))
	fill.call(_scale)
	if p.grade != "":
		m.body.add_child(UI.button("Remove grade", func():
			App.set_grade(p.id, "")
			m.close(), "quiet"))


func _grade_choice(ref: String, p: ProjectData, m: Modal) -> Control:
	var g := Content.grade(ref)
	var b := Button.new()
	b.custom_minimum_size = Vector2(66, 72)
	b.accessibility_name = g.get("name", "")
	var on := p.grade == ref
	UI.style_button(b, UI.ACCENT_SOFT if on else UI.SURFACE_SOFT, UI.INK, 18)
	if on:
		for state in ["normal", "hover"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(state)
			sb.set_border_width_all(2)
			sb.border_color = UI.ACCENT
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(UI.grade_badge(ref, 46))
	UI.ignore_mouse(centre)
	b.add_child(centre)
	b.pressed.connect(func():
		App.set_grade(p.id, ref)
		m.close()
		Toast.show_text("%s: %s" % [p.name, g.get("label", "")], "star"))
	return b
