class_name Pane
extends Control
## One of the five screens laid out round the focus screen. Each is built
## once and kept for as long as the app runs, so it's exactly as you left it
## when you swipe back. When the game state changes it rebuilds its content,
## keeping its scroll position; while it's off screen it just notes that it
## needs to, and does it when it's next shown.

## True while this pane is the one on screen (or sliding in).
var shown := false
var wide := false
var scroll: ScrollContainer

## Room kept clear under a screen's content for the minimap.
const BOTTOM_CLEAR := 96

var _dirty := true
var _resize_queued := false


func _ready() -> void:
	clip_contents = true
	App.state_changed.connect(_on_state_changed)
	resized.connect(_on_resized)


func show_pane() -> void:
	shown = true
	if _dirty:
		rebuild()
	_on_shown()


func hide_pane() -> void:
	shown = false
	_on_hidden()


func rebuild() -> void:
	_dirty = false
	wide = size.x >= UI.WIDE_BREAKPOINT
	var keep := scroll.scroll_vertical if is_instance_valid(scroll) else 0
	for c in get_children():
		remove_child(c)
		c.queue_free()
	scroll = null
	build()
	if keep > 0 and scroll:
		_restore_scroll(keep)


## Rebuild next time it's shown (e.g. after a switch to dark mode).
func mark_dirty() -> void:
	_dirty = true


## Subclasses add their content here.
func build() -> void:
	pass


func _on_shown() -> void:
	pass


func _on_hidden() -> void:
	pass


func _on_state_changed() -> void:
	if shown:
		rebuild()
	else:
		_dirty = true


func _on_resized() -> void:
	if not shown:
		_dirty = true
		return
	if not _resize_queued:
		_resize_queued = true
		_rebuild_after_resize.call_deferred()


func _rebuild_after_resize() -> void:
	_resize_queued = false
	if shown:
		rebuild()


func _restore_scroll(value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value


## A scrolling, centred column for the pane's content, clear of the notch at
## the top and the minimap at the bottom. Returns the column to fill. With
## `fill_height` the column is at least as tall as the screen, so a vertical
## spacer in it pushes what follows down to the bottom.
func page(max_width: float = 680.0, gap: int = 18, fill_height: bool = false) -> VBoxContainer:
	var insets := UI.safe_insets(self)
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gutter := 32 if wide else 18
	margin.add_theme_constant_override("margin_left", gutter + int(insets["left"]))
	margin.add_theme_constant_override("margin_right", gutter + int(insets["right"]))
	margin.add_theme_constant_override("margin_top", 26 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", BOTTOM_CLEAR + int(insets["bottom"]))
	scroll.add_child(margin)
	var column := UI.vbox(gap)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(column)
	column.custom_minimum_size.x = minf(max_width, size.x - 2.0 * gutter - insets["left"] - insets["right"])
	if fill_height:
		column.custom_minimum_size.y = maxf(0.0, size.y - 122.0 - insets["top"] - insets["bottom"])
	return column


## A column filling the pane exactly, centred and at most `max_width` wide,
## clear of the notch at the top and the minimap at the bottom. Unlike
## page() it never scrolls: whatever's in it has to fit, so give the parts
## that can give way SIZE_EXPAND_FILL, and put long lists in a
## UI.scroll_area() of their own. Returns the column to fill.
func frame(max_width: float = 680.0, gap: int = 18) -> VBoxContainer:
	var insets := UI.safe_insets(self)
	var gutter := 32.0 if wide else 18.0
	var width := maxf(0.0, minf(max_width, size.x - 2.0 * gutter - insets["left"] - insets["right"]))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.clip_contents = true
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(gutter + insets["left"]))
	margin.add_theme_constant_override("margin_right", int(gutter + insets["right"]))
	margin.add_theme_constant_override("margin_top", 26 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", BOTTOM_CLEAR + int(insets["bottom"]))
	add_child(margin)
	var column := UI.vbox(gap)
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.custom_minimum_size.x = width
	margin.add_child(column)
	return column


## The pane's title with its app-map icon beside it (UI.title_row).
func title_row(title: String) -> HBoxContainer:
	return UI.title_row(title, Minimap.ICONS.get(name.to_lower(), ""))
