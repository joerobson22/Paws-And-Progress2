class_name Dropdown
extends Button
## A pill showing the current choice, like "Sort by: Rarity ↓". Tapping it
## drops a small menu underneath. Picking another choice applies it and
## closes the menu straight away. Picking the one already chosen reverses
## it: its arrow flips over, then the menu closes by itself and the new
## order applies (nothing in the menu can be tapped while the arrow turns).
## `sortable` off (e.g. a plain picker) drops the arrows and the reversing.

signal chosen(option: String, reversed: bool)

## How long the arrow takes to flip before a reversed order applies.
const FLIP := 0.25
const ARROW_PX := 14

var prefix := ""
var current := ""
var reversed := false
var sortable := true
var _options: Array = []  # [[id, label], ...]
var _menu: Control
var _flipping := false


func _init(options: Array, selected: String, is_reversed: bool = false, label_prefix: String = "Sort by", can_reverse: bool = true) -> void:
	_options = options
	current = selected
	reversed = is_reversed and can_reverse
	prefix = label_prefix
	sortable = can_reverse
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


## A sort menu that reads and saves its choice in the settings: `key` holds
## the option and `key`_reversed the direction. Saving tells the whole app
## the state changed; with `quiet` it only saves, for a screen that re-sorts
## its own list from `chosen` rather than rebuilding everything.
static func for_setting(options: Array, key: String, fallback: String, quiet: bool = false) -> Dropdown:
	var d := Dropdown.new(options, str(App.state.settings.get(key, fallback)), bool(App.state.settings.get(key + "_reversed", false)))
	d.chosen.connect(func(option: String, is_reversed: bool):
		App.state.settings[key] = option
		if quiet:
			App.state.settings[key + "_reversed"] = is_reversed
			App.save()
		else:
			App.set_setting(key + "_reversed", is_reversed))
	return d


func _label(id: String) -> String:
	for o in _options:
		if o[0] == id:
			return o[1]
	return id


static func _arrow(up: bool) -> Texture2D:
	return Icons.texture("sort_up" if up else "sort_down", ARROW_PX, Color.WHITE, 2.6)


func _refresh() -> void:
	text = "%s: %s" % [prefix, _label(current)]
	icon = _arrow(reversed) if sortable else null


func _open() -> void:
	if is_instance_valid(_menu):
		return
	var host: Control = Modal.layer if Modal.layer and is_instance_valid(Modal.layer) else get_tree().root.get_child(0)
	# A clear sheet behind the menu: tapping anywhere else closes it.
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and not _flipping:
			_close())
	host.add_child(_menu)
	var card := UI.card(UI.SURFACE, 6, 18)
	_menu.add_child(card)
	var list := UI.vbox(2)
	card.add_child(list)
	for o in _options:
		var on: bool = o[0] == current
		var b := UI.button(o[1], Callable(), "quiet" if on else "ghost")
		b.custom_minimum_size = Vector2(150, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		var arrow: TextureRect = null
		if on and sortable:
			# Its own picture rather than the button's icon, so it can turn.
			arrow = TextureRect.new()
			arrow.texture = _arrow(reversed)
			arrow.modulate = UI.INK
			arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arrow.custom_minimum_size = Vector2(ARROW_PX, ARROW_PX)
			b.add_child(arrow)
			b.resized.connect(func():
				arrow.size = arrow.custom_minimum_size
				arrow.position = Vector2(b.size.x - arrow.size.x - 14.0, (b.size.y - arrow.size.y) * 0.5)
				arrow.pivot_offset = arrow.size * 0.5)
		b.pressed.connect(_choose.bind(o[0], arrow))
		list.add_child(b)
	card.size = card.get_combined_minimum_size()
	var at := get_global_rect()
	# Under the pill, or above it when there's no room underneath.
	var y := at.end.y + 6.0
	if y + card.size.y > _menu.size.y - 8.0:
		y = maxf(8.0, at.position.y - 6.0 - card.size.y)
	card.position = Vector2(clampf(at.end.x - card.size.x, 8.0, _menu.size.x - card.size.x - 8.0), y)
	card.modulate.a = 0.0
	var t := Motion.tween(card, "menu")
	t.set_parallel(true)
	t.tween_property(card, "modulate:a", 1.0, Motion.time(Motion.FAST))
	t.tween_property(card, "position:y", card.position.y + 4.0, Motion.time(Motion.FAST)).from(card.position.y - 4.0)


func _choose(id: String, arrow: TextureRect) -> void:
	if _flipping:
		return
	if id != current:
		current = id
		reversed = false
		_apply()
		return
	if not sortable:
		_close()
		return
	# The same choice again: flip its arrow over, then reverse the order.
	reversed = not reversed
	_flipping = true
	UI.ignore_mouse(_menu)
	var t := Motion.tween(arrow, "flip")
	t.tween_property(arrow, "rotation", PI, Motion.time(FLIP))
	t.tween_callback(func():
		_flipping = false
		_apply())


func _apply() -> void:
	_refresh()
	_close()
	chosen.emit(current, reversed)


func _close() -> void:
	if is_instance_valid(_menu):
		var m := _menu
		_menu = null
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.ignore_mouse(m)
		Motion.fade(m, 0.0, Motion.FAST).tween_callback(m.queue_free)
