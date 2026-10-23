class_name Leaderboard
extends PanelContainer
## The friends leaderboard: a card with a trophy and "Friends leaderboard"
## across the top, "See full" on the right, and everyone's week under it,
## most focus first. The heading stays put while the rows scroll. "See full"
## opens the whole list in a popup. Tapping a friend's face or name opens
## their profile; tapping yours goes to your profile screen.

var rows: Array


## `list` is rows from Friends.ranked(). `note` shows under the rows when
## there are no friends yet (and "See full" is left off).
func _init(list: Array, note: String = "") -> void:
	rows = list
	var b := UI.with_shadow(UI.box(UI.SURFACE, Color.TRANSPARENT, 24))
	b.content_margin_left = 20
	b.content_margin_right = 20
	b.content_margin_top = 16
	b.content_margin_bottom = 8
	add_theme_stylebox_override("panel", b)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := UI.vbox(6)
	add_child(column)

	var head := UI.hbox(10)
	head.custom_minimum_size.y = 34
	var trophy := UI.icon_rect("trophy", 22, UI.ACCENT)
	trophy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(trophy)
	var title := UI.trimmed("Friends leaderboard", 20, UI.INK, true, 600)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	if list.size() > 1:
		var full := UI.button("See full", open_full.bind(list), "quiet")
		full.custom_minimum_size = Vector2(0, 32)
		full.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		full.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb: StyleBoxFlat = full.get_theme_stylebox(state)
			sb.set_corner_radius_all(999)
			sb.content_margin_left = 14
			sb.content_margin_right = 14
			sb.content_margin_top = 2
			sb.content_margin_bottom = 2
		head.add_child(full)
	column.add_child(head)

	var sc := UI.scroll_area()
	sc.custom_minimum_size.y = 56
	column.add_child(sc)
	var list_box := _list(list)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if list.size() <= 1 and note != "":
		list_box.add_child(UI.divider())
		var words := UI.para(note, 13, UI.INK_FAINT)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_top", 10)
		pad.add_theme_constant_override("margin_bottom", 10)
		pad.add_child(words)
		list_box.add_child(pad)
	var room := MarginContainer.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.add_child(list_box)
	sc.add_child(room)
	UI.clear_of_bar(sc, room)


## Everyone in a popup titled "Friend leaderboard". The title stays at the
## top while the list scrolls.
static func open_full(list: Array) -> void:
	var m := Modal.open(480)
	m.header.add_child(m.heading_row("Friend leaderboard"))
	var room := MarginContainer.new()
	room.add_child(_list(list))
	m.body.add_child(room)
	UI.clear_of_bar(m.body.get_parent() as ScrollContainer, room)


## The rows, a line between each.
static func _list(list: Array) -> VBoxContainer:
	var box := UI.vbox(0)
	for i in list.size():
		if i > 0:
			box.add_child(UI.divider())
		box.add_child(row(i + 1, list[i]))
	return box


## One person: their place, their face and name (tap either for their
## profile), and their week, or paw prints while they're out on a walk.
static func row(rank: int, f: Dictionary) -> Control:
	var me: bool = f.get("me", false)
	var line := UI.hbox(12)
	line.custom_minimum_size.y = 56
	var r := UI.label(str(rank), 15, UI.INK_FAINT, true, 600)
	r.custom_minimum_size.x = 18
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(r)

	var who := UI.hbox(12)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.mouse_filter = Control.MOUSE_FILTER_STOP
	who.accessibility_name = "Your profile" if me else "%s's profile" % f.get("name", "")
	var face := UI.character_portrait(f.get("look", {}), Vector2(40, 40), true)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	who.add_child(face)
	var name_label := UI.trimmed(str(f.get("name", "")), 16, UI.INK, false, 800 if me else 700)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who.add_child(name_label)
	UI.ignore_mouse(face)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The name turns green under the pointer, to show it can be tapped.
	who.mouse_entered.connect(func(): name_label.add_theme_color_override("font_color", UI.ACCENT))
	who.mouse_exited.connect(func(): name_label.add_theme_color_override("font_color", UI.INK))
	Press.attach(who).tapped.connect(FriendProfile.open.bind(f))
	line.add_child(who)

	if f.get("walking", false):
		var walking := WalkingIndicator.new()
		walking.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(walking)
	else:
		var t := UI.label(Stats.format_duration(int(f.get("weekly_seconds", 0))), 16, UI.INK, true, 600)
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(t)
	return line
