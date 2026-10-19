class_name UI
extends RefCounted
## Shared palette, fonts, theme and small builders so screens stay short.
## Palette and type follow the "Modernised screen mockups" canvas:
## cream ground, forest green, apricot call-to-action, Fredoka + Nunito.

const BG := Color("#f3e9d6")
const PAPER := Color("#fffbf3")
const TRACK := Color("#efe4cf")
const PILL := Color("#e9dcc3")
const INK := Color("#2b2620")
const INK_SOFT := Color("#6b5f51")
const FOREST := Color("#2f5a3b")
const FOREST_LIGHT := Color("#3e6e4b")
const ON_FOREST := Color("#f6eedd")
const ON_FOREST_SOFT := Color("#bfd6c3")
const APRICOT := Color("#ffb869")
const ON_APRICOT := Color("#3a1f06")
const DANGER := Color("#a8432e")
const SAGE := Color("#e5efe2")
const LINE := Color("#d8c8aa")

const RADIUS := 16
const WIDE_BREAKPOINT := 900.0

static var _fonts: Dictionary = {}


## Gochi Hand, the handwriting on noticeboard polaroids.
static func hand_font() -> Font:
	if not _fonts.has("hand"):
		_fonts["hand"] = load("res://ui/fonts/GochiHand.ttf")
	return _fonts["hand"]


## Nunito (body) or Fredoka (display) at a given weight, cached.
static func font(display: bool = false, weight: int = 700) -> Font:
	var key := "%s_%d" % ["fredoka" if display else "nunito", weight]
	if not _fonts.has(key):
		var base: FontFile = load("res://ui/fonts/Fredoka.ttf" if display else "res://ui/fonts/Nunito.ttf")
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = fv
	return _fonts[key]


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(false, 700)
	t.default_font_size = 18

	t.set_color("font_color", "Label", INK)

	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", ON_FOREST)
	t.set_color("font_disabled_color", "Button", Color(ON_FOREST, 0.6))
	t.set_font("font", "Button", font(false, 800))
	t.set_stylebox("normal", "Button", box(FOREST))
	t.set_stylebox("hover", "Button", box(FOREST_LIGHT))
	t.set_stylebox("pressed", "Button", box(FOREST.darkened(0.15)))
	t.set_stylebox("hover_pressed", "Button", box(FOREST.darkened(0.15)))
	t.set_stylebox("focus", "Button", box(Color.TRANSPARENT, APRICOT))
	t.set_stylebox("disabled", "Button", box(FOREST.lerp(BG, 0.5)))

	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_stylebox("normal", "LineEdit", box(PAPER, PILL))
	t.set_stylebox("focus", "LineEdit", box(PAPER, FOREST))

	t.set_stylebox("panel", "PanelContainer", box(PAPER, Color.TRANSPARENT, 24))
	t.set_stylebox("panel", "Panel", box(PAPER, Color.TRANSPARENT, 24))
	return t


static func box(fill: Color, border: Color = Color.TRANSPARENT, radius: int = RADIUS) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.set_corner_radius_all(radius)
	b.content_margin_left = 20
	b.content_margin_right = 20
	b.content_margin_top = 12
	b.content_margin_bottom = 12
	b.anti_aliasing = true
	if border.a > 0.0:
		b.set_border_width_all(2)
		b.border_color = border
	return b


static func is_wide(c: Control) -> bool:
	return c.get_viewport_rect().size.x >= WIDE_BREAKPOINT


# --- Builders ----------------------------------------------------------------

static func label(text: String, size: int = 18, colour: Color = INK, display: bool = false, weight: int = 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(display, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


## A wrapping paragraph that fills the width it's given.
static func para(text: String, size: int = 16, colour: Color = INK_SOFT, weight: int = 600) -> Label:
	var l := label(text, size, colour, false, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 120
	return l


## Small uppercase section caption, like "THIS WEEK" on the mockups.
static func caption(text: String, colour: Color = INK_SOFT) -> Label:
	var l := label(text.to_upper(), 13, colour, false, 800)
	return l


static func button(text: String, on_press: Callable, fill: Color = FOREST, text_colour: Color = ON_FOREST) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	if fill != FOREST:
		b.add_theme_stylebox_override("normal", box(fill))
		b.add_theme_stylebox_override("hover", box(fill.darkened(0.06)))
		b.add_theme_stylebox_override("pressed", box(fill.darkened(0.14)))
		b.add_theme_stylebox_override("hover_pressed", box(fill.darkened(0.14)))
	if text_colour != ON_FOREST:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, text_colour)
	b.pressed.connect(on_press)
	return b


static func cta(text: String, on_press: Callable) -> Button:
	return button(text, on_press, APRICOT, ON_APRICOT)


static func quiet_button(text: String, on_press: Callable) -> Button:
	return button(text, on_press, TRACK, INK)


static func card(fill: Color = PAPER, padding: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	var b := box(fill, Color.TRANSPARENT, 24)
	b.set_content_margin_all(padding)
	b.shadow_color = Color(0.24, 0.16, 0.08, 0.10)
	b.shadow_size = 8
	b.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", b)
	return p


static func vbox(gap: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	return v


static func hbox(gap: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	return h


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## A horizontal progress track like the "79% of your record" bar.
static func progress(fraction: float, fill: Color = FOREST, height: int = 10) -> Control:
	var track := PanelContainer.new()
	var tb := box(TRACK, Color.TRANSPARENT, height / 2)
	tb.set_content_margin_all(0)
	track.add_theme_stylebox_override("panel", tb)
	track.custom_minimum_size.y = height
	var bar := Panel.new()
	var bb := box(fill, Color.TRANSPARENT, height / 2)
	bar.add_theme_stylebox_override("panel", bb)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track.add_child(bar)
	track.resized.connect(func(): bar.custom_minimum_size.x = track.size.x * clampf(fraction, 0.0, 1.0))
	return track


## A full-screen scrolling page with a centred, width-capped column, which
## reads well on a phone in portrait and on a wide desktop window alike.
static func page(parent: Control, max_width: int = 820) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gutter := 32 if is_wide(parent) else 16
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, gutter)
	scroll.add_child(margin)

	var column := vbox(16)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(column)
	var fit := func():
		column.custom_minimum_size.x = minf(max_width, parent.size.x - 2.0 * gutter)
	parent.resized.connect(fit)
	fit.call_deferred()
	return column


## Screen title, with a square back button and a line underneath if given.
static func header(title: String, on_back: Callable = Callable(), subtitle: String = "") -> HBoxContainer:
	var h := hbox(16)
	if on_back.is_valid():
		var back := icon_button("back", "Back", on_back)
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(back)
	var titles := vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := label(title, 32, INK, true, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(l)
	if subtitle != "":
		titles.add_child(label(subtitle, 14, INK_SOFT, false, 700))
	h.add_child(titles)
	return h


## A square button holding just an icon, like the mockups' back and sound buttons.
static func icon_button(icon: String, tip: String, on_press: Callable, fill: Color = PAPER,
		colour: Color = INK, side: int = 44, radius: int = 14) -> Button:
	var b := Button.new()
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(side, side)
	b.icon = Icons.texture(icon, 20, colour)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := box(fill if state == "normal" else fill.darkened(0.06 if state == "hover" else 0.12), Color.TRANSPARENT, radius)
		sb.set_content_margin_all(0)
		if fill == PAPER and state == "normal":
			sb.shadow_color = Color(0.24, 0.16, 0.08, 0.15)
			sb.shadow_size = 3
			sb.shadow_offset = Vector2(0, 1)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(on_press)
	return b


## Puts a leading icon on a text button.
static func with_icon(b: Button, icon: String, colour: Color, px: int = 16) -> Button:
	b.icon = Icons.texture(icon, px, colour)
	b.add_theme_constant_override("h_separation", 10)
	return b


## Round filter/segment pill: ink when selected, sand when not.
static func pill_button(text: String, selected: bool, on_press: Callable, height: int = 40) -> Button:
	var b := button(text, on_press, INK if selected else PILL, PAPER if selected else Color("#5c5246"))
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(state).duplicate()
		sb.set_corner_radius_all(999)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		b.add_theme_stylebox_override(state, sb)
	return b


## A small rounded tag, like "PROJECT" or a rarity name.
static func tag(text: String, fill: Color, colour: Color, size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var b := box(fill, Color.TRANSPARENT, 999)
	b.content_margin_left = 9
	b.content_margin_right = 9
	b.content_margin_top = 2
	b.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", b)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(text, size, colour, false, 800)
	p.add_child(l)
	return p


## A flat rounded panel with no shadow, for areas inside cards.
static func panel(fill: Color, radius: int = 18, padding: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var b := box(fill, Color.TRANSPARENT, radius)
	b.set_content_margin_all(padding)
	p.add_theme_stylebox_override("panel", b)
	return p


## Segmented bar of gift odds by rarity, with a legend underneath.
static func odds_bar(pct: Dictionary, on_dark: bool = false) -> VBoxContainer:
	var v := vbox(8)
	var bar := hbox(2)
	bar.custom_minimum_size.y = 12
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", 14)
	for r in GiftRoller.RARITIES:
		var share := int(pct.get(r, 0))
		if share <= 0:
			continue
		var seg := Panel.new()
		var sb := box(Content.rarity_colour(r), Color.TRANSPARENT, 3)
		seg.add_theme_stylebox_override("panel", sb)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = maxf(share, 1.5)
		bar.add_child(seg)
		var text_colour := Content.rarity_colour(r).lightened(0.5) if on_dark else Content.rarity_text_colour(r)
		legend.add_child(label("%s %d%%" % [Content.rarity_name(r), share], 13, text_colour, false, 800))
	v.add_child(bar)
	v.add_child(legend)
	return v


## Draws an animal portrait inside a fixed-size box (for cards and lists).
static func animal_portrait(animal_id: String, colours: Array[Color], box_size: Vector2, fill: Color = FOREST_LIGHT) -> Control:
	var frame := PanelContainer.new()
	var fb := box(fill, Color.TRANSPARENT, 16)
	fb.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fb)
	frame.custom_minimum_size = box_size
	frame.clip_contents = true
	var holder := Control.new()
	frame.add_child(holder)
	var view := AnimalView.new()
	view.animal_id = animal_id
	view.colours = colours
	holder.add_child(view)
	var place := func():
		# Big animals (bear, bernese) are drawn larger, so fit by their size too.
		var s := minf(holder.size.x / 150.0, holder.size.y / 95.0) / float(Content.animal(animal_id).get("size", 1.0))
		view.scale = Vector2(s, s)
		view.position = Vector2(holder.size.x * 0.45, holder.size.y * 0.88)
	holder.resized.connect(place)
	return frame
