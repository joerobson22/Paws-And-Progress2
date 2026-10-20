class_name Dropdown
extends Button
## A pill showing the current choice, like "Filter by: Rarity ↓". Tapping it
## drops a small menu underneath; picking the choice that's already selected
## flips its direction instead.

signal chosen(option: String, reversed: bool)

var prefix := ""
var current := ""
var reversed := false
var _options: Array = []  # [[id, label], ...]
var _menu: Control


func _init(options: Array, selected: String, is_reversed: bool, label_prefix: String) -> void:
	_options = options
	current = selected
	reversed = is_reversed
	prefix = label_prefix
	UI.style_button(self, UI.SURFACE_SOFT, UI.INK, 999)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBoxFlat = get_theme_stylebox(state)
		sb.content_margin_left = 14
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
	add_theme_font_size_override("font_size", 13)
	add_theme_constant_override("h_separation", 6)
	icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	custom_minimum_size.y = 34
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pressed.connect(_open)
	_refresh()


func _label(id: String) -> String:
	for o in _options:
		if o[0] == id:
			return o[1]
	return id


func _refresh() -> void:
	text = "%s: %s" % [prefix, _label(current)]
	icon = Icons.texture("sort_up" if reversed else "sort_down", 14, Color.WHITE, 2.6)


func _open() -> void:
	if is_instance_valid(_menu):
		return
	var host: Control = Modal.layer if Modal.layer and is_instance_valid(Modal.layer) else get_tree().root.get_child(0)
	# A clear sheet behind the menu: tapping anywhere else closes it.
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close())
	host.add_child(_menu)
	var card := UI.card(UI.SURFACE, 6, 18)
	_menu.add_child(card)
	var list := UI.vbox(2)
	card.add_child(list)
	for o in _options:
		var on: bool = o[0] == current
		var b := UI.button(o[1], _choose.bind(o[0]), "quiet" if on else "ghost")
		b.custom_minimum_size = Vector2(150, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		if on:
			b.icon = Icons.texture("sort_up" if reversed else "sort_down", 14, Color.WHITE, 2.6)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		list.add_child(b)
	card.size = card.get_combined_minimum_size()
	var at := get_global_rect()
	card.position = Vector2(clampf(at.end.x - card.size.x, 8.0, _menu.size.x - card.size.x - 8.0), at.end.y + 6.0)
	card.modulate.a = 0.0
	var t := Motion.tween(card, "menu")
	t.set_parallel(true)
	t.tween_property(card, "modulate:a", 1.0, Motion.time(Motion.FAST))
	t.tween_property(card, "position:y", card.position.y + 4.0, Motion.time(Motion.FAST)).from(card.position.y - 4.0)


func _choose(id: String) -> void:
	if id == current:
		reversed = not reversed
	else:
		current = id
		reversed = false
	_refresh()
	_close()
	chosen.emit(current, reversed)


func _close() -> void:
	if is_instance_valid(_menu):
		var m := _menu
		_menu = null
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Motion.fade(m, 0.0, Motion.FAST).tween_callback(m.queue_free)
