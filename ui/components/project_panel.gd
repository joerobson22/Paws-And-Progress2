class_name ProjectPanel
extends PanelContainer
## A wide panel about one project: its animal top left with the total time
## underneath, the name alongside with the gifts it brought in a row below,
## the grade top right, and when it ran in muted text bottom right. Used on
## the completed screen and in the stats popups, so they always match.
## With `gradeable`, the top right is a button: a circled "?" until the
## project has a grade, then its grade badge; either asks for a grade
## (`grade_pressed`). Nothing else on the panel can be tapped. `flat` drops
## the shadow, for a panel sitting inside a popup.

signal grade_pressed(project_id: String)

var project_id := ""


func _init(p: ProjectData, extra: String = "", gradeable: bool = false, flat: bool = false) -> void:
	project_id = p.id
	var sb := UI.box(UI.SURFACE, Color.TRANSPARENT, 24)
	if not flat:
		UI.with_shadow(sb, 0.8)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := UI.hbox(14)
	add_child(row)

	var left := UI.vbox(6)
	left.add_child(UI.animal_portrait(p.animal_id, p.colours, Vector2(84, 72)))
	var time := UI.label(Stats.format_duration(App.state.project_seconds(p.id)), 15, UI.INK, true, 600)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(time)
	row.add_child(left)

	var right := UI.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var top := UI.hbox(10)
	var names := UI.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_child(UI.trimmed(p.name, 21, UI.INK, true, 600))
	names.add_child(UI.trimmed(Content.pet_label(p), 13, UI.INK_SOFT, false, 700))
	top.add_child(names)
	var graded := p.grade != "" and not Content.grade(p.grade).is_empty()
	var grade_button: _GradeButton = null
	if gradeable:
		grade_button = _GradeButton.new(p.grade if graded else "")
		grade_button.pressed.connect(func(): grade_pressed.emit(project_id))
		top.add_child(grade_button)
	elif graded:
		var badge := UI.grade_badge(p.grade, 42)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(badge)
	right.add_child(top)

	var gifts := App.state.project_gifts(p.id)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 6)
	var ids := gifts.keys()
	ids.sort_custom(func(a, b): return GiftRoller.RARITIES.find(Content.gift(a).get("rarity", "")) > GiftRoller.RARITIES.find(Content.gift(b).get("rarity", "")))
	for id in ids:
		flow.add_child(_gift_chip(id, gifts[id]))
	if ids.is_empty():
		flow.add_child(UI.label(Text.t("project.no_gifts"), 13, UI.INK_FAINT, false, 700))
	right.add_child(flow)

	right.add_child(UI.spacer(true))
	var bias := App.tz_bias()
	var when := Text.t("project.dates", {"from": Stats.format_date(p.created_unix, bias),
		"to": Stats.format_date(p.completed_unix, bias) if p.is_complete() else Text.t("project.now")})
	if extra != "":
		when = Text.t("project.extra_and_dates", {"extra": extra, "dates": when})
	var dates := UI.label(when, 12, UI.INK_FAINT, false, 700)
	dates.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dates.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(dates)
	UI.ignore_mouse(self)
	if grade_button:
		grade_button.mouse_filter = Control.MOUSE_FILTER_STOP


static func _gift_chip(gift_id: String, count: int) -> Control:
	var h := UI.hbox(3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := GiftArt.new(gift_id)
	art.custom_minimum_size = Vector2(26, 26)
	h.add_child(art)
	var n := UI.label(Text.t("gift.count", {"n": count}), 13, Content.rarity_text_colour(Content.gift(gift_id).get("rarity", "common")), false, 800)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	return h


## The grade corner: a "?" in a circle, or the grade's badge. It shades a
## little under the pointer.
class _GradeButton extends Button:
	const SIZE := 42.0
	var _shade := 0.0
	var _cover: Control

	func _init(grade_ref: String) -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Cursor.HOVER
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		if grade_ref == "":
			custom_minimum_size = Vector2(SIZE, SIZE)
			accessibility_name = Text.t("project.add_grade")
		else:
			var badge := UI.grade_badge(grade_ref, int(SIZE))
			badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			custom_minimum_size = badge.custom_minimum_size
			add_child(badge)
			accessibility_name = Text.t("project.change_grade", {"grade": badge.accessibility_name})
		_cover = Control.new()
		_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cover.draw.connect(_draw_shade)
		add_child(_cover)
		mouse_entered.connect(_shade_to.bind(1.0))
		mouse_exited.connect(_shade_to.bind(0.0))

	func _shade_to(v: float) -> void:
		Motion.method(self, "shade", _set_shade, _shade, v, Motion.FAST)

	func _set_shade(v: float) -> void:
		_shade = v
		queue_redraw()
		_cover.queue_redraw()

	func _draw() -> void:
		if get_child_count() > 1:
			return  # the badge draws itself
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.5
		draw_circle(c, r, UI.SURFACE_SOFT.lerp(UI.ACCENT_SOFT, _shade), true, -1.0, true)
		draw_arc(c, r, 0, TAU, 40, UI.LINE.lerp(UI.ACCENT, _shade), 2.0, true)
		var font := UI.font(true, 600)
		var fs := int(size.y * 0.5)
		var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK_SOFT.lerp(UI.ACCENT, _shade))

	## Over a badge, the shade is a soft darkening of the whole circle.
	func _draw_shade() -> void:
		if get_child_count() > 1 and _shade > 0.0:
			var r := minf(size.x, size.y) * 0.5
			var disc := UI.box(Color(0, 0, 0, 0.12 * _shade), Color.TRANSPARENT, int(r))
			_cover.draw_style_box(disc, Rect2(Vector2.ZERO, size))
