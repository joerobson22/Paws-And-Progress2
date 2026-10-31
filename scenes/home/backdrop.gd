class_name HomeBackdrop
extends Control
## The view behind the focus screen: a forest seen from a hilltop, in
## layers (art/home/backdrop.tscn, which you can edit). It follows the real
## time of day: the day sky by day and the starry one by night, crossfading
## over a twilight of about 40 minutes round sunrise and sunset, with the
## layers dimming to Night Brightness. The sun and moon cross the sky as in
## the walk (DayCycle). Sliding to another screen pans the layers by their
## parallax as the view fades away; it only shows on the focus screen.
## A wash of the app's background colour mutes it so the screen reads on top.

## How bright the layers are at night (each layer can set its own).
@export_range(0.0, 1.0) var night_brightness := 0.45
## How much of the app's background colour lies over the view.
@export_range(0.0, 1.0) var wash := 0.35
## How much wider than the screen the layers are drawn, so panning and
## drifting never show an edge.
@export var spare := 0.18
## Where the sun and moon set, from the top (0) to the bottom (1).
@export_range(0.0, 1.0) var horizon := 0.72
## How high they climb above it, as a share of the height.
@export_range(0.0, 1.0) var climb := 0.5

## The view's slide from the focus screen (the screens' offset), set by
## the app as you move between screens.
var pan := Vector2.ZERO
## For tests and the debug bar: 0 day to 1 night. Below 0 works it out.
var night_override := -1.0

var _layers: Array[BackdropLayer] = []
var _colours: Array[Color] = []
var _wash: ColorRect
var _age := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for c in $Layers.get_children():
		if c is BackdropLayer:
			_layers.append(c)
			_colours.append(c.modulate)
	for n in _all_pictures():
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		n.stretch_mode = TextureRect.STRETCH_SCALE
		n.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_wash = ColorRect.new()
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_wash)
	refresh()


func _all_pictures() -> Array[TextureRect]:
	var out: Array[TextureRect] = [$DaySky, $NightSky, $Sun, $Moon]
	out.append_array(_layers)
	return out


func _process(dt: float) -> void:
	_age += dt
	# Gone once you're a whole screen away.
	var away := clampf(maxf(absf(pan.x) / maxf(size.x, 1.0), absf(pan.y) / maxf(size.y, 1.0)), 0.0, 1.0)
	modulate.a = 1.0 - away
	visible = away < 1.0
	if visible:
		_layout()


## Works the time of day out again: the sky, the sun and moon and the
## layers' brightness. The app calls it every so often and on changes.
func refresh() -> void:
	if not is_inside_tree():
		return
	var night := night_override if night_override >= 0.0 else App.night()
	$NightSky.modulate.a = night
	for i in _layers.size():
		var dim := _layers[i].night_brightness if _layers[i].night_brightness >= 0.0 else night_brightness
		var b := lerpf(1.0, dim, night)
		var c := _colours[i]
		_layers[i].modulate = Color(c.r * b, c.g * b, c.b * b, c.a)
	_wash.color = Color(UI.BG, wash)
	_layout()


func _layout() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var look := App.sky_look()
	_cover($DaySky, view, Vector2.ZERO)
	_cover($NightSky, view, Vector2.ZERO)
	_place_light($Sun, float(look["sun"]), view)
	_place_light($Moon, float(look["moon"]), view)
	for l in _layers:
		var sway := sin(_age * 0.12 + l.get_index() * 1.7) * l.drift
		_cover(l, view, pan * l.parallax + Vector2(sway, 0))


## Scales `n` to cover the screen (and some spare either side), its bottom
## on the screen's bottom, shifted by `offset`.
func _cover(n: TextureRect, view: Vector2, offset: Vector2) -> void:
	if n.texture == null:
		return
	var tex := n.texture.get_size()
	var s := maxf(view.x * (1.0 + spare * 2.0) / tex.x, view.y / tex.y)
	n.size = tex * s
	n.position = Vector2((view.x - n.size.x) * 0.5, view.y - n.size.y) + offset


## The sun or moon `along` its arc (0 rising on the left, 1 setting on the
## right; below 0 it's down and hidden).
func _place_light(n: TextureRect, along: float, view: Vector2) -> void:
	n.visible = along >= 0.0
	if not n.visible:
		return
	var side := minf(view.x, view.y) * 0.26
	n.size = Vector2(side, side)
	var x := lerpf(0.08, 0.92, along) * view.x
	var y := view.y * horizon - sin(along * PI) * view.y * climb
	n.position = Vector2(x, y) - n.size * 0.5 + pan * 0.05
