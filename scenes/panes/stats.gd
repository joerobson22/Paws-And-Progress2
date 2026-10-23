extends Pane
## Stats, below the focus screen. This week's focus as a bar per day, each
## bar split by project (tap a piece for that project's details), your past
## weeks beside it (tap one to chart it), your streak in the top right, and
## the friends leaderboard underneath.

const DAY_NAMES := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
const DAY_WORDS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

## The week being charted (its Monday as a day number); kept while the app runs.
var _week := -1
var _chart: _Chart
var _chart_title: Label
var _chart_total: Label
var _legend: HFlowContainer
var _weeks: Dictionary = {}  # week start -> history button


func build() -> void:
	var today := App.today()
	if _week < 0 or _week > Stats.week_start(today):
		_week = Stats.week_start(today)
	var col := page(1000 if wide else 680)

	var head := title_row("Stats")
	head.add_child(_streak())
	col.add_child(head)

	var chart_card := UI.card(UI.SURFACE, 20)
	chart_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c := UI.vbox(12)
	chart_card.add_child(c)
	var chart_head := UI.hbox(8)
	_chart_title = UI.label("", 20, UI.INK, true, 600)
	chart_head.add_child(_chart_title)
	chart_head.add_child(UI.spacer())
	_chart_total = UI.label("", 20, UI.ACCENT, true, 600)
	chart_head.add_child(_chart_total)
	c.add_child(chart_head)
	_chart = _Chart.new()
	_chart.custom_minimum_size.y = 230
	_chart.segment_tapped.connect(_show_project)
	c.add_child(_chart)
	_legend = HFlowContainer.new()
	_legend.add_theme_constant_override("h_separation", 8)
	_legend.add_theme_constant_override("v_separation", 8)
	c.add_child(_legend)

	var history := _history(today)
	if wide:
		var row := UI.hbox(16)
		history.custom_minimum_size = Vector2(230, 0)
		row.add_child(history)
		row.add_child(chart_card)
		col.add_child(row)
		# The history column scrolls within the chart's height.
		chart_card.resized.connect(func(): history.custom_minimum_size.y = chart_card.size.y)
	else:
		col.add_child(chart_card)
		col.add_child(history)

	col.add_child(UI.caption("Friends this week"))
	col.add_child(_leaderboard(today))
	_select_week(_week, false)


func _streak() -> Control:
	var sessions := App.state.sessions
	var days := Stats.current_streak(sessions, App.today(), App.tz_bias())
	var rest_ready := Stats.rest_day_ready(sessions, App.today(), App.tz_bias())
	var pill := UI.card(UI.SURFACE, 12, 20)
	var sb: StyleBoxFlat = pill.get_theme_stylebox("panel")
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UI.hbox(10)
	pill.add_child(row)
	row.add_child(UI.icon_rect("flame", 26, UI.FLAME if days > 0 else UI.INK_FAINT))
	var v := UI.vbox(0)
	v.add_child(UI.label("%d day%s" % [days, "" if days == 1 else "s"], 18, UI.INK, true, 600))
	if rest_ready:
		var rest := UI.hbox(4)
		rest.add_child(UI.icon_rect("moon", 12, UI.ACCENT))
		rest.add_child(UI.label("Rest day ready", 12, UI.ACCENT, false, 800))
		v.add_child(rest)
	else:
		v.add_child(UI.label("streak", 12, UI.INK_SOFT, false, 800))
	row.add_child(v)
	UI.ignore_mouse(pill)
	return pill


## Past weeks, newest first: a column beside the chart on wide screens, a
## sideways strip under it on phones.
func _history(today: int) -> Control:
	_weeks.clear()
	var totals := Stats.weekly_totals(App.state.sessions, App.tz_bias())
	# Past weeks with no focus at all are left out; this week always shows.
	var this_week := Stats.week_start(today)
	var weeks := Stats.week_history(App.state.sessions, today, App.tz_bias(), Stats.local_day(int(App.state.profile.get("created_unix", 0)), App.tz_bias())) \
		.filter(func(w): return w == this_week or int(totals.get(w, 0)) > 0)
	var best := 1
	for w in weeks:
		best = maxi(best, int(totals.get(w, 0)))
	var list: BoxContainer
	if wide:
		list = UI.vbox(8)
	else:
		list = UI.hbox(8)
	for w in weeks:
		var b := _week_button(w, int(totals.get(w, 0)), best, today)
		list.add_child(b)
		_weeks[w] = b
	var sc := ScrollContainer.new()
	if wide:
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size.y = 84
	sc.add_child(list)
	return sc


func _week_button(w: int, seconds: int, best: int, today: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0 if wide else 132, 70)
	b.clip_contents = true
	var v := UI.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.offset_bottom = -10
	var title := "This week" if w == Stats.week_start(today) else ("Last week" if w == Stats.week_start(today) - 7 else "%s – %s" % [Stats.format_day(w), Stats.format_day(w + 6)])
	v.add_child(UI.trimmed(title, 13, UI.INK_SOFT, false, 800))
	v.add_child(UI.label(Stats.format_duration(seconds), 17, UI.INK, true, 600))
	v.add_child(UI.progress_line(float(seconds) / best))
	b.add_child(v)
	UI.ignore_mouse(b)
	b.pressed.connect(_select_week.bind(w))
	return b


func _select_week(w: int, animate: bool = true) -> void:
	_week = w
	for week in _weeks:
		var b: Button = _weeks[week]
		UI.style_button(b, UI.ACCENT_SOFT if week == w else UI.SURFACE, UI.INK, 18, week != w)
	var today := App.today()
	var this_week := Stats.week_start(today)
	_chart_title.text = "This week" if w == this_week else "Week of %s" % Stats.format_day(w)
	_chart_total.text = Stats.format_duration(Stats.week_total(App.state.sessions, w, App.tz_bias()))
	_chart.set_days(Stats.daily_project_totals(App.state.sessions, w, App.tz_bias()), Stats.weekday(today) if w == this_week else -1, animate)

	for child in _legend.get_children():
		child.queue_free()
	var by_project := Stats.project_totals_in_week(App.state.sessions, w, App.tz_bias())
	var ids := by_project.keys()
	ids.sort_custom(func(a, b): return by_project[a] > by_project[b])
	if ids.is_empty():
		_legend.add_child(UI.label("No focus this week yet.", 14, UI.INK_FAINT, false, 700))
	for id in ids:
		_legend.add_child(_legend_chip(id, by_project[id]))


func _legend_chip(project_id: String, seconds: int) -> Control:
	var p := App.state.project(project_id)
	var b := UI.button("%s  %s" % [p.name if p else "Deleted project", Stats.format_duration(seconds)], _show_project.bind(project_id, -1), "quiet")
	b.custom_minimum_size.y = 34
	b.add_theme_font_size_override("font_size", 13)
	b.icon = Icons.texture("dot", 12, UI.series_colour(project_id))
	b.add_theme_constant_override("h_separation", 8)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state)
		sb.set_corner_radius_all(999)
		sb.content_margin_left = 12
		sb.content_margin_right = 14
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	b.disabled = p == null
	return b


## A project's panel in a popup; `day` (0-6) adds that day's time to it.
func _show_project(project_id: String, day: int) -> void:
	var p := App.state.project(project_id)
	if p == null:
		return
	var week := Stats.project_totals_in_week(App.state.sessions, _week, App.tz_bias())
	var extra := "%s this week" % Stats.format_duration(int(week.get(project_id, 0)))
	if day >= 0:
		var days := Stats.daily_project_totals(App.state.sessions, _week, App.tz_bias())
		extra = "%s on %s" % [Stats.format_duration(int(days[day].get(project_id, 0))), DAY_WORDS[day]]
	var m := Modal.open(560, true, 18)
	var top := UI.hbox(8)
	top.add_child(UI.spacer())
	top.add_child(UI.round_button("close", "Close", m.close.bind(null), UI.SURFACE_SOFT, UI.INK, 36, false))
	m.body.add_child(top)
	var panel := ProjectPanel.new(p, extra, false, true)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.body.add_child(panel)
	if not p.is_complete():
		m.body.add_child(UI.para("Still in progress. Its panel moves to Completed when you finish it.", 13, UI.INK_FAINT))


func _leaderboard(today: int) -> Control:
	var card := UI.card(UI.SURFACE, 10)
	var list := UI.vbox(0)
	card.add_child(list)
	var mine := Stats.week_total(App.state.sessions, Stats.week_start(today), App.tz_bias())
	var rows: Array = [{"name": "You", "weekly_seconds": mine, "walking": App.state.active != null, "look": {}, "me": true}]
	rows.append_array(App.friends)
	rows.sort_custom(func(a, b): return int(a["weekly_seconds"]) > int(b["weekly_seconds"]))
	for i in rows.size():
		if i > 0:
			list.add_child(UI.divider())
		list.add_child(_leader_row(i + 1, rows[i]))
	if App.friends.is_empty():
		list.add_child(UI.divider())
		var soon := UI.para("Friends join you here once accounts arrive: you'll see their weeks, and who's out walking right now.", 13, UI.INK_FAINT)
		var pad := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			pad.add_theme_constant_override("margin_" + side, 12)
		pad.add_child(soon)
		list.add_child(pad)
	return card


func _leader_row(rank: int, f: Dictionary) -> Control:
	var row := UI.hbox(12)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_child(row)
	var r := UI.label(str(rank), 15, UI.INK_FAINT, true, 600)
	r.custom_minimum_size.x = 18
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(r)
	var face := UI.character_portrait(f.get("look", {}), Vector2(44, 44), true)
	row.add_child(face)
	var who := UI.trimmed(str(f.get("name", "")), 16, UI.INK, false, 800 if f.get("me", false) else 700)
	who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(who)
	if f.get("walking", false):
		var walking := WalkingIndicator.new()
		walking.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(walking)
	else:
		var t := UI.label(Stats.format_duration(int(f.get("weekly_seconds", 0))), 16, UI.INK, true, 600)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(t)
	return pad


## The week's bars: one per day, stacked by project, tappable piece by piece.
class _Chart extends Control:
	signal segment_tapped(project_id: String, day: int)

	const DAYS := ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

	var days: Array[Dictionary] = []
	var today_index := -1
	var _grow := 1.0
	var _pieces: Array = []  # [Rect2, project_id, day]
	var _press := Press.new(self)
	var _tap_at := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		_press.tapped.connect(func():
			var hit := _piece_at(_tap_at)
			if not hit.is_empty():
				segment_tapped.emit(hit[1], hit[2]))

	func set_days(d: Array[Dictionary], today: int, animate: bool) -> void:
		days = d
		today_index = today
		if animate:
			Motion.method(self, "grow", _set_grow, 0.0, 1.0, Motion.SLOW)
		else:
			_set_grow(1.0)

	func _set_grow(v: float) -> void:
		_grow = v
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_tap_at = e.position
		_press.handle(e)

	func _piece_at(p: Vector2) -> Array:
		for piece in _pieces:
			if (piece[0] as Rect2).grow_individual(6, 1, 6, 1).has_point(p):
				return piece
		return []

	func _draw() -> void:
		_pieces.clear()
		var font := UI.font(false, 800)
		var area := Rect2(34, 8, size.x - 34, size.y - 8 - 28)
		var most := 0
		for d in days:
			var total := 0
			for s in d.values():
				total += int(s)
			most = maxi(most, total)
		var hours := maxi(1, ceili(most / 3600.0))
		var step := 1 if hours <= 6 else ceili(hours / 6.0)
		var h := 0
		while h <= hours:
			var y := area.end.y - area.size.y * h / float(hours)
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), UI.LINE, 1.0)
			draw_string(font, Vector2(0, y + 4), "%dh" % h if h > 0 else "0", HORIZONTAL_ALIGNMENT_LEFT, 30, 12, UI.INK_FAINT)
			h += step
		if days.size() != 7:
			return
		var col := area.size.x / 7.0
		var bar := minf(col * 0.58, 38.0)
		for i in 7:
			var x := area.position.x + col * (i + 0.5) - bar * 0.5
			var y := area.end.y
			var ids := days[i].keys()
			ids.sort_custom(func(a, b): return UI.SERIES.find(UI.series_colour(a)) < UI.SERIES.find(UI.series_colour(b)))
			for id in ids:
				var seg := area.size.y * float(days[i][id]) / (hours * 3600.0) * _grow
				if seg < 0.5:
					continue
				var r := Rect2(x, y - seg, bar, seg)
				var sb := UI.box(UI.series_colour(id), Color.TRANSPARENT, 2)
				draw_style_box(sb, r)
				_pieces.append([r, id, i])
				y -= seg + 2.0
			var day_colour := UI.ACCENT if i == today_index else UI.INK_SOFT
			draw_string(font, Vector2(area.position.x + col * i, size.y - 6), DAYS[i], HORIZONTAL_ALIGNMENT_CENTER, col, 12, day_colour)
