class_name AccountSwitcher
extends RefCounted
## The "Switch account" popup, opened from settings: every save slot on this
## device as a card, oldest first, with its face, name, total focus,
## achievements earned and a red bin to delete it. Tap a card anywhere else
## to carry on in that slot. The title stays at the top and the + for a new
## slot at the bottom while the cards scroll between them. A new slot opens
## on its profile screen, which you can't leave until it's filled in.

const CARD_HEIGHT := 64


static func open() -> Modal:
	var m := Modal.open(560)
	m.header.add_child(m.heading_row(Text.t("accounts.title")))
	var list := UI.vbox(10)
	m.body.add_child(list)
	_fill(list)
	var add := UI.round_button("plus", Text.t("accounts.new"), _add, UI.ACCENT, UI.ON_COLOUR, 52, false)
	add.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.footer.add_child(add)
	return m


## (Re)builds the cards, after a delete too.
static func _fill(list: VBoxContainer) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	var narrow := list.get_viewport_rect().size.x < 480.0 if list.is_inside_tree() else false
	for row in App.slots():
		list.add_child(_card(row, narrow, list))


## One slot: face | name | total focus | achievements | bin (a tick on the
## one you're in, which can't be deleted). The columns line up card to card.
static func _card(row: Dictionary, narrow: bool, list: VBoxContainer) -> Control:
	var current: bool = row["current"]
	var name := str(row["name"])
	var card := PanelContainer.new()
	card.custom_minimum_size.y = CARD_HEIGHT
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.accessibility_name = Text.t("accounts.switch_to", {"name": name if name != "" else Text.t("accounts.unnamed_lower")})
	var styles := {}
	for state in ["normal", "hover"]:
		var fill: Color = UI.SURFACE_SOFT if state == "normal" else (UI.button_styles(UI.SURFACE_SOFT, 18)["hover"] as StyleBoxFlat).bg_color
		var b := UI.box(fill, UI.ACCENT if current else Color.TRANSPARENT, 18)
		b.set_border_width_all(2)
		b.content_margin_left = 10
		b.content_margin_right = 12
		b.content_margin_top = 8
		b.content_margin_bottom = 8
		styles[state] = b
	card.add_theme_stylebox_override("panel", styles["normal"])
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", styles["hover"]))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", styles["normal"]))

	var line := UI.hbox(8 if narrow else 12)
	card.add_child(line)
	var face := UI.character_portrait(row["look"], Vector2.ONE * (38 if narrow else 44), true)
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(face)
	var name_label := UI.trimmed(name if name != "" else Text.t("accounts.unnamed"), 14 if narrow else 16,
		UI.INK if name != "" else UI.INK_FAINT, false, 800)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(name_label)
	var focused := Stats.format_duration(int(row["focused_seconds"]))
	line.add_child(_stat("clock", focused, 82 if narrow else 100, narrow, Text.t("accounts.focused", {"time": focused})))
	line.add_child(_stat("trophy", "%d%%" % int(row["achievements"]), 54 if narrow else 66, narrow,
		Text.t("accounts.achievements", {"percent": int(row["achievements"])})))
	UI.ignore_mouse(card)

	var end_size := 32 if narrow else 36
	if current:
		var here := UI.panel(UI.ACCENT, 999, 0)
		here.custom_minimum_size = Vector2.ONE * end_size
		here.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		here.accessibility_name = Text.t("accounts.current")
		here.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tick := UI.icon_rect("check", int(end_size * 0.5), UI.ON_COLOUR)
		tick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		here.add_child(tick)
		line.add_child(here)
	else:
		line.add_child(UI.round_button("bin", Text.t("accounts.delete", {"who": name if name != "" else Text.t("accounts.this_one")}),
			_delete.bind(row, list), UI.DANGER, UI.ON_COLOUR, end_size, false))
	Press.attach(card).tapped.connect(_switch.bind(row["id"]))
	return card


## An icon and a figure in a column of fixed width, so they line up down
## the cards.
static func _stat(icon: String, text: String, width: int, narrow: bool, label: String) -> Control:
	var box := UI.hbox(5)
	box.custom_minimum_size.x = width
	box.accessibility_name = label
	var i := UI.icon_rect(icon, 14 if narrow else 16, UI.INK_FAINT)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(i)
	var l := UI.label(text, 13 if narrow else 15, UI.INK, false, 700)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(l)
	return box


static func _switch(id: String) -> void:
	App.switch_slot(id)
	Modal.close_all()
	App.go("profile")


static func _add() -> void:
	App.add_slot()
	Modal.close_all()
	App.go("profile")


static func _delete(row: Dictionary, list: VBoxContainer) -> void:
	var name := str(row["name"])
	var who := Text.t("accounts.whose", {"name": name}) if name != "" else Text.t("accounts.this_one")
	var sure := Modal.confirm(Text.t("accounts.delete_title", {"who": who}),
		Text.t("accounts.delete_body"), Text.t("common.delete"))
	if await sure.closed == true and is_instance_valid(list):
		App.delete_slot(row["id"])
		_fill(list)
