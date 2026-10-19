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

const RADIUS := 16
const WIDE_BREAKPOINT := 900.0

static var _fonts: Dictionary = {}


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
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)

	var column := vbox(16)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(column)
	var fit := func():
		column.custom_minimum_size.x = minf(max_width, parent.size.x - 40.0)
	parent.resized.connect(fit)
	fit.call_deferred()
	return column


static func header(title: String, on_back: Callable = Callable()) -> HBoxContainer:
	var h := hbox(16)
	if on_back.is_valid():
		var back := quiet_button("Back", on_back)
		back.custom_minimum_size.x = 96
		h.add_child(back)
	var l := label(title, 34, INK, true, 600)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


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
