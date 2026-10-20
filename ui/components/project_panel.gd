class_name ProjectPanel
extends PanelContainer
## A wide panel about one project: its animal top left with the total time
## underneath, the name alongside with the gifts it brought in a row below,
## the grade badge top right, and when it ran in muted text bottom right.
## Used on the completed screen and in the stats popups, so they always match.

signal tapped(project_id: String)

var project_id := ""
var _press := Press.new(self)


func _init(p: ProjectData, extra: String = "") -> void:
	project_id = p.id
	var sb := UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 24), 0.8)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_press.tapped.connect(func():
		Motion.pop(self, 0.02, 0.25)
		tapped.emit(project_id))

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
	names.add_child(UI.trimmed(Content.animal(p.animal_id).get("name", ""), 13, UI.INK_SOFT, false, 700))
	top.add_child(names)
	if p.grade != "" and not Content.grade(p.grade).is_empty():
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
		flow.add_child(UI.label("No gifts yet", 13, UI.INK_FAINT, false, 700))
	right.add_child(flow)

	right.add_child(UI.spacer(true))
	var bias := App.tz_bias()
	var when := Stats.format_date(p.created_unix, bias) + " – " + \
		(Stats.format_date(p.completed_unix, bias) if p.is_complete() else "now")
	if extra != "":
		when = extra + "  ·  " + when
	var dates := UI.label(when, 12, UI.INK_FAINT, false, 700)
	dates.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dates.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(dates)
	UI.ignore_mouse(self)


static func _gift_chip(gift_id: String, count: int) -> Control:
	var h := UI.hbox(3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := GiftArt.new(gift_id)
	art.custom_minimum_size = Vector2(26, 26)
	h.add_child(art)
	var n := UI.label("×%d" % count, 13, Content.rarity_text_colour(Content.gift(gift_id).get("rarity", "common")), false, 800)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(n)
	h.tooltip_text = Content.gift(gift_id).get("name", "")
	return h


func _gui_input(e: InputEvent) -> void:
	_press.handle(e)
