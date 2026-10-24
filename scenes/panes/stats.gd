extends Pane
## Stats, below the focus screen. This week's focus as a bar per day, each
## bar split by project (tap a piece, or a project in the sideways strip
## under the chart, for that project's details), your past weeks beside it
## (tap one to chart it), your streak in the top right (a shield on the
## flame when you've earned a day off), and the friends leaderboard
## underneath. It all fits the screen; only the strips and the leaderboard
## scroll.

## Project names in the strip under the chart are cut to this many letters.
const CHIP_LETTERS := 10
## The least room across for the weeks to sit beside the chart.
const COLUMNS_FROM := 560.0


## The week being charted (its Monday as a day number); kept while the app runs.
var _week := -1
var _chart: _Chart
var _chart_title: Label
var _chart_total: Label
var _legend: HBoxContainer
var _weeks: Dictionary = {}  # week start -> history button
## The past weeks go in a column beside the chart (else a strip under it).
var _columns := false


func build() -> void:
	var today := App.today()
	if _week < 0 or _week > Stats.week_start(today):
		_week = Stats.week_start(today)
	# Computers always have the height for the weeks beside the chart, even
	# in the smallest window; phones put them in a strip under it.
	_columns = wide or (not App.phone_layout() and margins(1000)["width"] >= COLUMNS_FROM)
	var col := frame(1000 if _columns else 680, 14)

	var head := title_row(Text.t("stats.title"))
	head.add_child(_streak())
	col.add_child(head)

	var chart_card := UI.card(UI.SURFACE, 20)
	chart_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var c := UI.vbox(10)
	chart_card.add_child(c)
	var chart_head := UI.hbox(8)
	_chart_title = UI.label("", 20, UI.INK, true, 600)
	chart_head.add_child(_chart_title)
	chart_head.add_child(UI.spacer())
	_chart_total = UI.label("", 20, UI.ACCENT, true, 600)
	chart_head.add_child(_chart_total)
	c.add_child(chart_head)
	_chart = _Chart.new()
	_chart.custom_minimum_size.y = 100
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chart.segment_tapped.connect(_show_project)
	c.add_child(_chart)
	var strip := UI.scroll_area(true)
	strip.custom_minimum_size.y = 34
	var strip_room := MarginContainer.new()
	_legend = UI.hbox(8)
	strip_room.add_child(_legend)
	strip.add_child(strip_room)
	UI.clear_of_bar(strip, strip_room, 8)
	c.add_child(strip)

	# The chart gets the most room; the leaderboard the rest.
	var history := _history(today)
	if _columns:
		var row := UI.hbox(16)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.size_flags_stretch_ratio = 1.5
		# Narrower in a small window, so the chart keeps most of the width.
		history.custom_minimum_size.x = clampf(col.custom_minimum_size.x * 0.28, 180.0, 230.0)
		row.add_child(history)
		row.add_child(chart_card)
		col.add_child(row)
	else:
		chart_card.size_flags_stretch_ratio = 1.5
		col.add_child(chart_card)
		col.add_child(history)

	var mine := Stats.week_total(App.state.sessions, Stats.week_start(today), App.tz_bias())
	var board := Leaderboard.new(Friends.ranked(App.friends, mine, App.state.active != null))
	# At least a row and yours: a friend above you, then your pinned row.
	board.custom_minimum_size.y = 180 if _columns else 128
	col.add_child(board)
	_select_week(_week, false)


## Your streak: the flame with how many days, and a see-through blue
## shield over the flame's corner when you've earned a day off.
func _streak() -> Control:
	var sessions := App.state.sessions
	var days := Stats.current_streak(sessions, App.today(), App.tz_bias())
	var rest_ready := Stats.rest_day_ready(sessions, App.today(), App.tz_bias())
	var row := UI.hbox(8)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.accessibility_name = Text.count("stats.streak_rest" if rest_ready else "stats.streak", days)
	var flame := Control.new()
	flame.custom_minimum_size = Vector2(34, 34)
	flame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flame.add_child(UI.icon_rect("flame", 32, UI.FLAME if days > 0 else UI.INK_FAINT))
	if rest_ready:
		# A ring of page colour round the shield keeps it apart from the flame.
		var cut := UI.icon_rect("shield", 22, UI.BG)
		cut.position = Vector2(15, 14)
		flame.add_child(cut)
		var shield := UI.icon_rect("shield", 18, Color(Content.rarity_colour("rare"), 0.6))
		shield.position = Vector2(17, 16)
		flame.add_child(shield)
	row.add_child(flame)
	row.add_child(UI.label(Text.count("stats.days", days), 22, UI.INK, true, 600))
	UI.ignore_mouse(row)
	return row


## Past weeks, newest first: a column beside the chart on computers and
## wide screens, a sideways strip under it on phones.
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
	if _columns:
		list = UI.vbox(8)
	else:
		list = UI.hbox(8)
	for w in weeks:
		var b := _week_button(w, int(totals.get(w, 0)), best, today)
		list.add_child(b)
		_weeks[w] = b
	if _columns:
		# Scrolls without cutting the cards' shadows off at the sides.
		var holder := UI.shadow_scroll(list)
		holder.size_flags_horizontal = Control.SIZE_FILL
		return holder
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = 84
	sc.add_child(list)
	return sc


func _week_button(w: int, seconds: int, best: int, today: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0 if _columns else 132, 70)
	# The words clip, not the button, or its shadow would be cut off.
	var v := UI.vbox(2)
	v.clip_contents = true
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.offset_bottom = -10
	var title := Text.t("stats.this_week") if w == Stats.week_start(today) else (Text.t("stats.last_week") if w == Stats.week_start(today) - 7 else Text.t("stats.week_span", {"from": Stats.format_day(w), "to": Stats.format_day(w + 6)}))
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
	_chart_title.text = Text.t("stats.this_week") if w == this_week else Text.t("stats.week_of", {"day": Stats.format_day(w)})
	_chart_total.text = Stats.format_duration(Stats.week_total(App.state.sessions, w, App.tz_bias()))
	_chart.set_days(Stats.daily_project_totals(App.state.sessions, w, App.tz_bias()), Stats.weekday(today) if w == this_week else -1, animate)

	for child in _legend.get_children():
		child.queue_free()
	var by_project := Stats.project_totals_in_week(App.state.sessions, w, App.tz_bias())
	var ids := by_project.keys()
	ids.sort_custom(func(a, b): return by_project[a] > by_project[b])
	if ids.is_empty():
		_legend.add_child(UI.label(Text.t("stats.no_focus"), 14, UI.INK_FAINT, false, 700))
	for id in ids:
		_legend.add_child(_legend_chip(id, by_project[id]))


func _legend_chip(project_id: String, seconds: int) -> Control:
	var p := App.state.project(project_id)
	var title: String = p.name if p else Text.t("stats.deleted_project")
	if title.length() > CHIP_LETTERS:
		title = title.left(CHIP_LETTERS).strip_edges() + "..."
	var b := UI.button(Text.t("stats.chip", {"project": title, "time": Stats.format_duration(seconds)}), _show_project.bind(project_id, -1), "quiet")
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
	var extra := Text.t("stats.time_this_week", {"time": Stats.format_duration(int(week.get(project_id, 0)))})
	if day >= 0:
		var days := Stats.daily_project_totals(App.state.sessions, _week, App.tz_bias())
		extra = Text.t("stats.time_on_day", {"time": Stats.format_duration(int(days[day].get(project_id, 0))), "day": Text.list("dates.days_long")[day]})
	# The popup is the project's panel itself, with a close button in its corner.
	var m := Modal.open(560, true, 0)
	var panel := ProjectPanel.new(p, extra, false, true, m.close.bind(null))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.body.add_child(panel)


## The week's bars: one per day, stacked by project, tappable piece by piece.
class _Chart extends Control:
	signal segment_tapped(project_id: String, day: int)

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
			draw_string(font, Vector2(area.position.x + col * i, size.y - 6), Text.list("dates.days_short")[i], HORIZONTAL_ALIGNMENT_CENTER, col, 12, day_colour)
