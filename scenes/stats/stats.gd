extends Control
## Your week: headline numbers, hours per day and where the time went, with
## arrows to look back at earlier weeks.
## params: {"week": 0 for this week, -1 for last week, ...}

var params := {}

const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const DAY_WORDS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## Colours for the per-project split, in order of time spent.
const SPLIT := [Color("#2f5a3b"), Color("#7e4fd6"), Color("#d98b3a"), Color("#2f7bc2"), Color("#a8432e"), Color("#8c8c7e")]


func _ready() -> void:
	Audio.ambience("cabin")
	var s := App.state
	var bias := App.tz_bias()
	var today := App.today()
	var offset := mini(0, int(params.get("week", 0)))
	var week_start := Stats.week_start(today) + 7 * offset
	var daily := Stats.daily_totals(s.sessions, week_start, bias)
	var week := Stats.week_total(s.sessions, week_start, bias)
	var last_week := Stats.week_total(s.sessions, week_start - 7, bias)
	var best_week := maxi(Stats.best_week_total(s.sessions, bias), int(s.profile["legacy_best_week_seconds"]))
	var longest := maxi(Stats.longest_session(s.sessions), int(s.profile["legacy_longest_seconds"]))
	var all_time := Stats.total_seconds(s.sessions) + int(s.profile["legacy_total_seconds"])
	var wide := UI.is_wide(self)

	var col := UI.page(self, 1220)
	var head := UI.header("Your week" if offset == 0 else "Week of %s" % _date(week_start))
	var nav := UI.hbox(6)
	nav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nav.add_child(UI.icon_button("back", "Previous week", App.go.bind("stats", {"week": offset - 1}), UI.PAPER, UI.INK, 40, 999))
	var range_label := UI.label("%s – %s" % [_date(week_start), _date(week_start + 6)], 15, UI.INK, false, 800)
	range_label.custom_minimum_size.x = 120
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nav.add_child(range_label)
	var next := UI.icon_button("forward", "Next week", App.go.bind("stats", {"week": offset + 1}), UI.PAPER, UI.INK, 40, 999)
	next.disabled = offset >= 0
	next.modulate.a = 0.4 if offset >= 0 else 1.0
	nav.add_child(next)
	if wide:
		head.add_child(nav)
		var since := int(s.profile.get("created_unix", 0))
		if since > 0:
			var d := Time.get_datetime_dict_from_unix_time(since)
			head.add_child(UI.tag("Walking since %s %d" % [MONTHS[int(d["month"]) - 1], d["year"]], UI.PILL, Color("#5c5246"), 13))
	col.add_child(head)
	if not wide:
		col.add_child(nav)

	var tiles := GridContainer.new()
	tiles.columns = 4 if wide else 2
	tiles.add_theme_constant_override("h_separation", 14)
	tiles.add_theme_constant_override("v_separation", 14)
	var diff := week - last_week
	tiles.add_child(_tile("This week" if offset == 0 else "That week", Stats.format_duration(week),
		("+%s on the week before" if diff >= 0 else "%s less than the week before") % Stats.format_duration(absi(diff)), true))
	var to_beat := best_week - week
	tiles.add_child(_tile("Weekly record", Stats.format_duration(best_week),
		"%s to beat it" % Stats.format_duration(to_beat) if to_beat > 0 else "This is your record!"))
	tiles.add_child(_tile("Longest walk", Stats.format_duration(longest), _longest_detail()))
	tiles.add_child(_tile("All time", Stats.format_duration(all_time), "across %d projects" % s.projects.size()))
	col.add_child(tiles)

	var row: BoxContainer = UI.hbox(16) if wide else UI.vbox(16)
	col.add_child(row)
	var chart := UI.card(UI.PAPER, 22)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_stretch_ratio = 1.4
	var c := UI.vbox(14)
	chart.add_child(c)
	var chart_head := UI.hbox()
	chart_head.add_child(UI.label("Hours per day", 20, UI.INK, true, 600))
	chart_head.add_child(UI.spacer())
	var best_day := 0
	for i in 7:
		if daily[i] > daily[best_day]:
			best_day = i
	if daily[best_day] > 0:
		chart_head.add_child(UI.label("Best day: %s, %s" % [DAY_WORDS[best_day], Stats.format_duration(daily[best_day])], 13, UI.INK_SOFT, false, 800))
	c.add_child(chart_head)
	c.add_child(_bars(daily, Stats.weekday(today) if offset == 0 else -1))
	row.add_child(chart)
	row.add_child(_split(Stats.project_totals_in_week(s.sessions, week_start, bias)))


func _date(day: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day * Stats.SECONDS_PER_DAY)
	return "%d %s" % [d["day"], MONTHS[int(d["month"]) - 1]]


func _longest_detail() -> String:
	var best: FocusSession = null
	for x in App.state.sessions:
		if best == null or x.focus_seconds > best.focus_seconds:
			best = x
	if best == null:
		return "from the original app"
	var p := App.state.project(best.project_id)
	var who: String = Content.animal(best.animal_id if best.animal_id != "" else (p.animal_id if p else "")).get("name", "")
	return "with the %s" % who.to_lower()


func _tile(title: String, value: String, detail: String, highlight: bool = false) -> Control:
	var card := UI.card(UI.FOREST if highlight else UI.PAPER, 18)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(2)
	card.add_child(v)
	v.add_child(UI.caption(title, UI.ON_FOREST_SOFT if highlight else UI.INK_SOFT))
	v.add_child(UI.label(value, 30, UI.ON_FOREST if highlight else UI.INK, true, 600))
	v.add_child(UI.para(detail, 13, Color("#dcebdd") if highlight else UI.INK_SOFT, 700))
	return card


func _bars(daily: Array[int], today_index: int) -> Control:
	var top_hours := 1
	for d in daily:
		top_hours = maxi(top_hours, ceili(d / 3600.0))
	var top := top_hours * 3600

	var chart := UI.hbox(10)
	chart.custom_minimum_size.y = 220
	var axis := VBoxContainer.new()
	axis.custom_minimum_size.x = 26
	for h in range(top_hours, -1, -1):
		var l := UI.label("%dh" % h if h > 0 else "0", 12, UI.INK_SOFT, false, 700)
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP if h > 0 else VERTICAL_ALIGNMENT_BOTTOM
		axis.add_child(l)
	axis.add_child(UI.label(" ", 13))
	chart.add_child(axis)

	for i in 7:
		var col := UI.vbox(6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var area := Panel.new()
		var ab := UI.box(Color("#f6efe1"), Color.TRANSPARENT, 10)
		area.add_theme_stylebox_override("panel", ab)
		area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(area)
		var bar := Panel.new()
		bar.add_theme_stylebox_override("panel", UI.box(UI.FOREST if i == today_index or today_index < 0 else UI.FOREST.lerp(UI.BG, 0.45), Color.TRANSPARENT, 10))
		bar.mouse_filter = Control.MOUSE_FILTER_PASS
		area.add_child(bar)
		var fraction := float(daily[i]) / top
		area.resized.connect(func():
			var h := area.size.y * fraction
			bar.visible = h > 1.0
			bar.position = Vector2(0, area.size.y - h)
			bar.size = Vector2(area.size.x, h))
		area.tooltip_text = "%s: %s" % [DAY_WORDS[i], Stats.format_duration(daily[i])]
		var l := UI.label(DAY_NAMES[i], 13, UI.FOREST if i == today_index else UI.INK_SOFT, false, 800)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		chart.add_child(col)
	return chart


## "Where the time went": a split bar and a row per project.
func _split(by_project: Dictionary) -> Control:
	var card := UI.card(UI.PAPER, 22)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(14)
	card.add_child(v)
	v.add_child(UI.label("Where the time went", 20, UI.INK, true, 600))
	var ids := by_project.keys().filter(func(id): return App.state.project(id) != null and by_project[id] > 0)
	ids.sort_custom(func(a, b): return by_project[a] > by_project[b])
	if ids.is_empty():
		v.add_child(UI.para("No walks this week yet.", 15))
		return card

	var bar := UI.hbox(3)
	bar.custom_minimum_size.y = 14
	for i in ids.size():
		var seg := Panel.new()
		seg.add_theme_stylebox_override("panel", UI.box(SPLIT[i % SPLIT.size()], Color.TRANSPARENT, 4))
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = float(by_project[ids[i]])
		bar.add_child(seg)
	v.add_child(bar)

	for i in ids.size():
		var p := App.state.project(ids[i])
		var row := UI.hbox(10)
		var face := UI.animal_portrait(p.animal_id, p.colours, Vector2(44, 34), UI.SAGE)
		row.add_child(face)
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", UI.box(SPLIT[i % SPLIT.size()], Color.TRANSPARENT, 999))
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var name := UI.label(p.name, 15, UI.INK, false, 800)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.clip_text = true
		row.add_child(name)
		var t := UI.label(Stats.format_duration(by_project[ids[i]]), 15, UI.INK_SOFT, false, 700)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(t)
		v.add_child(row)
	return card
