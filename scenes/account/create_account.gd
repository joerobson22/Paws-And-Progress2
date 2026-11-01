class_name CreateAccount
extends Control
## The create account screen: on a first launch and after Log out it covers
## the whole app. It asks for your name and where you study, and Create
## (which waits for both) starts the account and goes to the focus screen.
## "I have an account" under it lists the accounts on this device to log
## back into (AccountSwitcher); it only shows when there's one.

## As wide as this, or the screen less a 16px gutter each side.
const WIDTH := 420.0
const GUTTER := 16.0

var _name: LineEdit
var _school: LineEdit
var _create: Button
var _have: Button
var _col: VBoxContainer


## `own_backdrop`: draw the app's background colour behind it; otherwise it
## sits on the hilltop view the app keeps behind every screen.
func _init(name_text: String = "", school_text: String = "", own_backdrop: bool = true) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if own_backdrop:
		add_child(UI.backdrop())

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var col := UI.vbox(18)
	_col = col
	centre.add_child(col)
	resized.connect(func(): _col.custom_minimum_size.x = minf(WIDTH, size.x - GUTTER * 2.0))

	var mark := UI.icon_rect("paw", 44, UI.ACCENT)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(mark)
	var title := UI.label(Text.t("create.title"), 34, UI.INK, true, 600)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	# Ink, not the soft grey: it sits over the ground, not a card.
	var note := UI.para(Text.t("create.note"), 15, UI.INK)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)

	var card := UI.card(UI.SURFACE, 22)
	col.add_child(card)
	var form := UI.vbox(8)
	card.add_child(form)
	_name = _field(form, Text.t("create.name"), Text.t("profile.username_placeholder"), 24, name_text)
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	form.add_child(gap)
	_school = _field(form, Text.t("create.school"), Text.t("profile.school_placeholder"), 60, school_text)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 10
	form.add_child(gap2)
	_create = UI.button(Text.t("create.create"), _submit, "accent")
	form.add_child(_create)

	_have = UI.button(Text.t("create.have_account"), _open_accounts, "ghost")
	_have.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_have.add_theme_color_override("font_color", UI.ACCENT)
	_have.add_theme_color_override("font_hover_color", UI.ACCENT)
	_have.add_theme_font_size_override("font_size", 15)
	if not own_backdrop:
		# A soft pill behind it, as behind the focus screen's hint, so it
		# reads over the hilltop view.
		_have.custom_minimum_size.y = 38
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := (_have.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.bg_color = Color(UI.BG, 0.8)
			sb.set_corner_radius_all(99)
			sb.content_margin_left = 18
			sb.content_margin_right = 18
			_have.add_theme_stylebox_override(state, sb)
	col.add_child(_have)

	_name.text_changed.connect(func(_t): _refresh())
	_school.text_changed.connect(func(_t): _refresh())
	_name.text_submitted.connect(func(_t): _school.grab_focus())
	_school.text_submitted.connect(func(_t): _submit())
	_refresh()


func _ready() -> void:
	refresh_accounts()
	if not App.touch_screen():
		_name.grab_focus.call_deferred()


## What's typed so far, to carry over when the screen is rebuilt.
func typed() -> Array:
	return [_name.text, _school.text]


## A caption over a text box, in `form`.
func _field(form: Control, caption: String, placeholder: String, max_length: int, text: String) -> LineEdit:
	var cap := UI.caption(caption.to_upper())
	form.add_child(cap)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.text = text
	edit.custom_minimum_size.y = 50
	edit.accessibility_name = caption
	form.add_child(edit)
	return edit


func _ready_to_create() -> bool:
	return _name.text.strip_edges() != "" and _school.text.strip_edges() != ""


func _refresh() -> void:
	_create.disabled = not _ready_to_create()


## Shows "I have an account" only when there's one to log into.
func refresh_accounts() -> void:
	_have.visible = App.has_accounts()


func _submit() -> void:
	if not _ready_to_create():
		return
	App.create_account(_name.text, _school.text)
	App.go("focus")


func _open_accounts() -> void:
	AccountSwitcher.open().closed.connect(func(_r):
		if is_instance_valid(self):
			refresh_accounts())
