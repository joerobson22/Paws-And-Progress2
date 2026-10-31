class_name Modal
extends Control
## A popup card over a dimmed backdrop, used for every popup in the app:
## confirmations, gift details, the grade picker, the character editor.
## They all open, look and close the same way. The app shell gives Modal a
## layer to live in (Modal.layer); popups stack, newest on top.

signal closed(result: Variant)

## How far the body's scroll reaches past it on each side (into the card's
## padding), so hovered buttons have room to grow.
const GROW_ROOM := Vector2(12, 4)

static var layer: Control
static var _stack: Array[Modal] = []

## Tapping the backdrop or pressing Escape closes it (with a null result).
var dismissible := true
## The card and the column inside it; fill `body` with content. Anything in
## `header` stays put above it while a long body scrolls, and anything in
## `footer` stays put below it.
var card: PanelContainer
var header: VBoxContainer
var body: VBoxContainer
var footer: VBoxContainer
var _backdrop: ColorRect
var _scroll: ScrollContainer
var _holder: Control
var _room: MarginContainer
var _max_width := 440.0
var _closing := false


static func is_open() -> bool:
	return not _stack.is_empty()


static func top() -> Modal:
	return _stack.back() if not _stack.is_empty() else null


## Closes every popup, newest first.
static func close_all() -> void:
	while top():
		top().close()


## Opens an empty popup; fill `body` and it animates in on the next frame.
static func open(max_width: float = 440.0, can_dismiss: bool = true, padding: int = 24) -> Modal:
	var m := Modal.new()
	m._max_width = max_width
	m.dismissible = can_dismiss
	m._build(padding)
	var host: Node = layer
	if host == null or not is_instance_valid(host):
		host = (Engine.get_main_loop() as SceneTree).root
	host.add_child(m)
	_stack.append(m)
	m._animate_in.call_deferred()
	return m


## A yes/no question. Closes with true or false. `tone` styles the yes
## button: "danger" (red), "success" (green) or "primary".
static func confirm(title: String, text: String, yes: String, tone: String = "danger", no: String = "") -> Modal:
	var m := open(400)
	m.body.add_child(m.heading(title))
	var p := UI.para(text, 16)
	m.body.add_child(p)
	var row := UI.hbox(10)
	var cancel := UI.button(no if no != "" else Text.t("common.cancel"), m.close.bind(false), "quiet")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	var ok := UI.button(yes, m.close.bind(true), tone)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	m.body.add_child(row)
	return m


## Asks for a line of text. Closes with the new text, or null if cancelled.
static func prompt(title: String, value: String, placeholder: String = "", max_length: int = 40) -> Modal:
	var m := open(420)
	m.body.add_child(m.heading(title))
	var edit := LineEdit.new()
	edit.text = value
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.custom_minimum_size.y = 50
	edit.select_all_on_focus = true
	m.body.add_child(edit)
	var row := UI.hbox(10)
	var cancel := UI.button(Text.t("common.cancel"), m.close.bind(null), "quiet")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	var save := UI.button(Text.t("common.save"), func(): m.close(edit.text.strip_edges()), "accent")
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(save)
	m.body.add_child(row)
	edit.text_submitted.connect(func(t): m.close(t.strip_edges()))
	edit.grab_focus.call_deferred()
	return m


## A colour picker: a wheel plus a row of natural animal colours. Calls
## `on_change` live as the colour moves; closes with the final colour.
static func colour(title: String, start: Color, on_change: Callable, swatches: Array = []) -> Modal:
	var m := open(400)
	m.body.add_child(m.heading(title))
	var picker := ColorPicker.new()
	picker.color = start
	picker.edit_alpha = false
	picker.picker_shape = ColorPicker.SHAPE_OKHSL_CIRCLE
	picker.sampler_visible = false
	picker.color_modes_visible = false
	picker.sliders_visible = false
	picker.hex_visible = false
	picker.presets_visible = false
	picker.can_add_swatches = false
	if picker.has_method("set_edit_intensity"):
		picker.set("edit_intensity", false)
	picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picker.color_changed.connect(on_change)
	m.body.add_child(picker)
	if not swatches.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		for c in swatches:
			var dot := Button.new()
			dot.custom_minimum_size = Vector2(34, 34)
			UI.style_button(dot, c, UI.INK, 999)
			dot.pressed.connect(func():
				picker.color = c
				on_change.call(c))
			flow.add_child(dot)
		m.body.add_child(flow)
	m.body.add_child(UI.button(Text.t("common.done"), func(): m.close(picker.color), "accent"))
	return m


## The body's scroll, e.g. to keep a list clear of its bar (UI.clear_of_bar).
func scroller() -> ScrollContainer:
	return _scroll


## The title line at the top of a popup.
func heading(text: String) -> Label:
	var l := UI.label(text, 24, UI.INK, true, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A title with a small round close button on the right.
func heading_row(text: String) -> HBoxContainer:
	var row := UI.hbox(10)
	var h := heading(text)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(h)
	var x := UI.ghost_button("close", Text.t("common.close"), close.bind(null))
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(x)
	return row


func close(result: Variant = null) -> void:
	if _closing:
		return
	_closing = true
	_stack.erase(self)
	closed.emit(result)
	# Let taps straight through while it fades away.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.ignore_mouse(card)
	var t := Motion.tween(self, "modal")
	t.set_parallel(true)
	t.tween_property(_backdrop, "modulate:a", 0.0, Motion.time(Motion.FAST))
	t.tween_property(card, "modulate:a", 0.0, Motion.time(Motion.FAST))
	t.tween_property(card, "scale", Vector2.ONE * 0.96, Motion.time(Motion.FAST))
	t.chain().tween_callback(queue_free)


func _build(padding: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = ColorRect.new()
	_backdrop.color = UI.SCRIM
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	card = PanelContainer.new()
	var b := UI.box(UI.SURFACE, Color.TRANSPARENT, 28)
	b.set_content_margin_all(padding)
	b.shadow_color = Color(0, 0, 0, 0.18)
	b.shadow_size = 30
	b.shadow_offset = Vector2(0, 10)
	card.add_theme_stylebox_override("panel", b)
	centre.add_child(card)
	var column := UI.vbox(16)
	card.add_child(column)
	header = UI.vbox(16)
	header.visible = false
	header.child_entered_tree.connect(func(_child): header.visible = true)
	header.minimum_size_changed.connect(_fit)
	column.add_child(header)
	# The scrolling part reaches GROW_ROOM out into the card's padding, with
	# the same room inside it round the body, so a button that grows under
	# the pointer isn't cut off at the scroll's edges.
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_holder)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = -GROW_ROOM.x
	_scroll.offset_right = GROW_ROOM.x
	_scroll.offset_top = -GROW_ROOM.y
	_scroll.offset_bottom = GROW_ROOM.y
	_holder.add_child(_scroll)
	_room = MarginContainer.new()
	_room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room.add_theme_constant_override("margin_left", int(GROW_ROOM.x))
	_room.add_theme_constant_override("margin_right", int(GROW_ROOM.x))
	_room.add_theme_constant_override("margin_top", int(GROW_ROOM.y))
	_room.add_theme_constant_override("margin_bottom", int(GROW_ROOM.y))
	_scroll.add_child(_room)
	body = UI.vbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room.add_child(body)
	body.minimum_size_changed.connect(_fit)
	footer = UI.vbox(16)
	footer.visible = false
	footer.child_entered_tree.connect(func(_child): footer.visible = true)
	footer.minimum_size_changed.connect(_fit)
	column.add_child(footer)
	resized.connect(_fit)


## Sizes the card to its content, scrolling inside when it's taller than the screen.
func _fit() -> void:
	if not is_inside_tree():
		return
	var view := get_viewport_rect().size
	var pad := card.get_theme_stylebox("panel").get_minimum_size()
	var w := minf(_max_width, view.x - 24.0) - pad.x
	_holder.custom_minimum_size.x = w
	body.custom_minimum_size.x = w
	header.custom_minimum_size.x = w
	footer.custom_minimum_size.x = w
	_holder.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, room())


## The most height the body gets before it scrolls: the screen less the
## card's padding, the header and the footer. Something no taller than this
## never makes the body scroll, so it can scroll inside itself instead.
func room() -> float:
	var pad := card.get_theme_stylebox("panel").get_minimum_size()
	var above := header.get_combined_minimum_size().y + 16.0 if header.visible else 0.0
	var below := footer.get_combined_minimum_size().y + 16.0 if footer.visible else 0.0
	return maxf(80.0, get_viewport_rect().size.y - 48.0 - pad.y - above - below)


## Scrolls the body so `target` (somewhere inside it) sits in the middle,
## gliding there as the popup opens.
func scroll_to(target: Control) -> void:
	# The card sizes itself over the next couple of frames.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(target):
		return
	var y := target.size.y * 0.5
	var n: Control = target
	while n != body and n != null:
		y += n.position.y
		n = n.get_parent() as Control
	y += GROW_ROOM.y
	var most := maxf(0.0, _room.size.y - _scroll.size.y)
	Motion.to(_scroll, "scroll_vertical", int(clampf(y - _scroll.size.y * 0.5, 0.0, most)), Motion.SLOW)


func _animate_in() -> void:
	_fit()
	card.pivot_offset = card.size * 0.5
	_backdrop.modulate.a = 0.0
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * 0.94
	var t := Motion.tween(self, "modal")
	t.set_parallel(true)
	t.tween_property(_backdrop, "modulate:a", 1.0, Motion.time(Motion.NORMAL))
	t.tween_property(card, "modulate:a", 1.0, Motion.time(Motion.NORMAL))
	t.tween_property(card, "scale", Vector2.ONE, Motion.time(Motion.NORMAL))
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)


func _on_backdrop_input(e: InputEvent) -> void:
	if dismissible and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		close(null)


func _unhandled_input(e: InputEvent) -> void:
	if top() == self and dismissible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close(null)
