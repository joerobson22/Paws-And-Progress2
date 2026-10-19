extends Control
## Stats: this week's daily bars, totals, records and per-project share.

var params := {}

const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


func _ready() -> void:
	var s := App.state
	var bias := App.tz_bias()
	var today := App.today()
	var week_start := Stats.week_start(today)
	var daily := Stats.daily_totals(s.sessions, week_start, bias)
	var week := Stats.week_total(s.sessions, week_start, bias)
	var legacy_total := int(s.profile["legacy_total_seconds"])
	var best_week := maxi(Stats.best_week_total(s.sessions, bias), int(s.profile["legacy_best_week_seconds"]))
	var longest := maxi(Stats.longest_session(s.sessions), int(s.profile["legacy_longest_seconds"]))

	var col := UI.page(self, 1000)
	col.add_child(UI.header("Stats"))

	var tiles := GridContainer.new()
	tiles.columns = 4 if UI.is_wide(self) else 2
	tiles.add_theme_constant_override("h_separation", 12)
	tiles.add_theme_constant_override("v_separation", 12)
	tiles.add_child(_tile("This week", Stats.format_duration(week)))
	tiles.add_child(_tile("Best week", Stats.format_duration(best_week)))
	tiles.add_child(_tile("Longest walk", Stats.format_duration(longest)))
	tiles.add_child(_tile("Streak", "%d days" % Stats.current_streak(s.sessions, today, bias)))
	col.add_child(tiles)

	var chart := UI.card()
	var c := UI.vbox(12)
	chart.add_child(c)
	c.add_child(UI.caption("This week, day by day"))
	c.add_child(_bars(daily, Stats.weekday(today)))
	col.add_child(chart)

	var share := UI.card()
	var sv := UI.vbox(10)
	share.add_child(sv)
	sv.add_child(UI.caption("All time"))
	sv.add_child(UI.label(Stats.format_duration(Stats.total_seconds(s.sessions) + legacy_total), 32, UI.INK, true, 600))
	var by_project := Stats.totals_by_project(s.sessions)
	for p in s.projects:
		by_project[p.id] = int(by_project.get(p.id, 0)) + p.legacy_seconds
	var total := 0
	for v in by_project.values():
		total += int(v)
	var ids := by_project.keys()
	ids.sort_custom(func(a, b): return by_project[a] > by_project[b])
	for id in ids:
		var p := s.project(id)
		if p == null or by_project[id] <= 0:
			continue
		var row := UI.hbox()
		var name := UI.label(p.name, 15)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(UI.label(Stats.format_duration(by_project[id]), 15, UI.INK_SOFT))
		sv.add_child(row)
		sv.add_child(UI.progress(float(by_project[id]) / total if total > 0 else 0.0, UI.FOREST, 8))
	col.add_child(share)


func _tile(title: String, value: String) -> Control:
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(4)
	card.add_child(v)
	v.add_child(UI.caption(title))
	v.add_child(UI.label(value, 28, UI.INK, true, 600))
	return card


func _bars(daily: Array[int], today_index: int) -> Control:
	var top := 3600
	for d in daily:
		top = maxi(top, d)
	var row := UI.hbox(10)
	row.custom_minimum_size.y = 200
	for i in 7:
		var col := UI.vbox(6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var area := Control.new()
		area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.add_child(area)
		var bar := Panel.new()
		bar.add_theme_stylebox_override("panel", UI.box(UI.FOREST if i == today_index else UI.FOREST.lerp(UI.BG, 0.45), Color.TRANSPARENT, 8))
		area.add_child(bar)
		var fraction := float(daily[i]) / top
		area.resized.connect(func():
			var h := maxf(4.0, area.size.y * fraction)
			bar.position = Vector2(0, area.size.y - h)
			bar.size = Vector2(area.size.x, h))
		bar.tooltip_text = Stats.format_duration(daily[i])
		var l := UI.label(DAY_NAMES[i], 13, UI.FOREST if i == today_index else UI.INK_SOFT, false, 800)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		row.add_child(col)
	return row
